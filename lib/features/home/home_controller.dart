import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/uuid_generator.dart';
import '../../sync/crypto/sodium_crypto_service.dart';
import '../../sync/db/app_database.dart';
import '../../sync/key_management/home_key_store.dart';
import '../../sync/key_management/pairing_crypto.dart';
import '../../sync/key_management/pairing_payload.dart';
import '../../sync/key_management/pairing_relay.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';

class _SessionPairingCode {
  final String code;
  final DateTime expiresAt;

  const _SessionPairingCode({
    required this.code,
    required this.expiresAt,
  });
}

/// Ephemeral client-side state held by the joiner (B) after submitting a
/// 6-digit code join request and while waiting for the inviter (A) to approve.
class PendingPairingJoinSession {
  final PairingRequestRecord request;
  final PairingBoxKeyPair keyPair;
  final PairingVerificationWords verificationWords;

  const PendingPairingJoinSession({
    required this.request,
    required this.keyPair,
    required this.verificationWords,
  });
}

class HomeController {
  final Ref ref;
  final Map<String, _SessionPairingCode> _cachedPairingCodes =
      <String, _SessionPairingCode>{};
  final ValueNotifier<int> pairingCodeRevision = ValueNotifier<int>(0);

  HomeController(this.ref);

  AppDatabase get _db => ref.read(appDatabaseProvider);
  HomeKeyStore get _keyStore => ref.read(homeKeyStoreProvider);
  SodiumCryptoService get _crypto => ref.read(sodiumCryptoServiceProvider);
  PairingRelay? get _pairingRelay => ref.read(pairingRelayProvider);

  String _currentUserId({String fallback = 'local_user'}) {
    final supabase = ref.read(supabaseClientProvider);
    final user = ref.read(authProvider).value;
    return supabase?.auth.currentUser?.id ?? user?.id ?? fallback;
  }

  /// Returns the pairing code created in this session for [homeId] only until
  /// its `expires_at` timestamp; otherwise returns `null`.
  String? cachedPairingCodeFor(String homeId) {
    final entry = _cachedPairingCodes[homeId];
    if (entry == null) return null;
    if (!clock.now().toUtc().isBefore(entry.expiresAt)) {
      _cachedPairingCodes.remove(homeId);
      return null;
    }
    return entry.code;
  }

  void _bumpPairingCodeRevision() {
    Future.microtask(() {
      pairingCodeRevision.value++;
    });
  }

  @visibleForTesting
  void cachePairingCodeForTest({
    required String homeId,
    required String code,
    required DateTime expiresAt,
  }) {
    _cachedPairingCodes[homeId] = _SessionPairingCode(
      code: code,
      expiresAt: expiresAt.toUtc(),
    );
    _bumpPairingCodeRevision();
  }

  /// Creates a new shared household, generates its 256-bit encryption key,
  /// saves it to secure storage, and returns the PairingPayload for the QR code.
  Future<PairingPayload> createHome({
    required String name,
    String? description,
    String? currency,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    final userId = _currentUserId();
    final now = clock.now().toUtc();
    final homeId = _generateUuid();

    // 1. Generate 256-bit symmetric encryption key
    final symmetricKey = _crypto.generateHomeKey();

    // 2. Persist symmetric key securely on-device
    await _keyStore.saveKey(homeId, symmetricKey);

    // 3. Insert into local Drift database
    final initialCurrency =
        currency ?? ref.read(currencyPreferenceProvider).code;
    await _db.into(_db.localHomes).insertOnConflictUpdate(
          LocalHomesCompanion.insert(
            id: homeId,
            name: name,
            description: drift.Value(description),
            icon: const drift.Value(null), // Deterministic icon mark
            currency: drift.Value(initialCurrency),
            createdAt: now,
            createdBy: userId,
          ),
        );

    // 4. Insert into Supabase if connected
    if (supabase != null) {
      try {
        await supabase.from('homes').insert({
          'id': homeId,
          'name': name,
          'description': description,
          'icon': null,
          'created_at': now.toIso8601String(),
          'created_by': userId,
        });

        await supabase.from('home_members').insert({
          'home_id': homeId,
          'user_id': userId,
          'joined_at': now.toIso8601String(),
        });
        debugPrint(
          '[HomeController] Home and membership successfully saved to Supabase: $homeId',
        );
      } catch (e) {
        debugPrint('[HomeController] Error saving home to Supabase: $e');
      }
    }

    // 5. Set as active Home
    ref.read(activeHomeIdProvider.notifier).setActiveHome(homeId);

    // 6. Start Sync Engine with this home
    final engine = ref.read(syncEngineProvider);
    await engine.start(activeHomeId: homeId, activeHomeKey: symmetricKey);

    final userProfile = ref.read(userProfileProvider);

    return PairingPayload(
      homeId: homeId,
      homeName: name,
      symmetricKey: symmetricKey,
      inviterId: userId,
      inviterName: userProfile.displayName,
      inviterAvatar: userProfile.avatarUrl,
      createdAt: now,
    );
  }

  /// Joins a Home using a scanned or pasted Pairing QR string.
  Future<void> joinHomeFromQr(String qrString) async {
    final payload = PairingPayload.fromQrString(qrString);
    final supabase = ref.read(supabaseClientProvider);
    final userId = _currentUserId();
    final now = clock.now().toUtc();

    // 1. Save imported symmetric key securely on-device
    await _keyStore.saveKey(payload.homeId, payload.symmetricKey);

    // 2. Store home record in local Drift projections
    await _db.into(_db.localHomes).insertOnConflictUpdate(
          LocalHomesCompanion.insert(
            id: payload.homeId,
            name: payload.homeName,
            createdAt: payload.createdAt,
            createdBy: payload.inviterId,
          ),
        );

    // 3. Set partner profile immediately from inviter payload
    if (payload.inviterName != null &&
        payload.inviterName!.trim().isNotEmpty &&
        payload.inviterName!.trim() != 'Partner') {
      await ref.read(partnerProfileProvider.notifier).setPartnerFromSync(
            name: payload.inviterName!.trim(),
            avatarUrl: payload.inviterAvatar,
            userId: payload.inviterId,
          );
    }

    // 4. Add membership in Supabase if connected
    if (supabase != null) {
      try {
        final userProfile = ref.read(userProfileProvider);
        await supabase.from('home_members').upsert({
          'home_id': payload.homeId,
          'user_id': userId,
          'joined_at': now.toUtc().toIso8601String(),
          'display_name': userProfile.displayName,
          'avatar_url': userProfile.avatarUrl,
        });
        debugPrint(
          '[HomeController] Partner successfully added to Supabase home_members: ${payload.homeId}',
        );
      } catch (e) {
        debugPrint(
          '[HomeController] Error adding partner to Supabase home_members: $e',
        );
      }
    }

    // 5. Set as active Home
    ref.read(activeHomeIdProvider.notifier).setActiveHome(payload.homeId);

    // 6. Start Sync Engine
    final engine = ref.read(syncEngineProvider);
    await engine.start(
      activeHomeId: payload.homeId,
      activeHomeKey: payload.symmetricKey,
    );

    // 7. Broadcast joiner's profile so inviter gets our display name immediately
    final userProfile = ref.read(userProfileProvider);
    final emitAction = ref.read(coveEmitActionProvider);
    unawaited(
      emitAction(
        eventType: 'member_profile_updated',
        payload: {
          'display_name': userProfile.displayName,
          'avatar_url': userProfile.avatarUrl,
          'user_id': userId,
        },
        targetHomeId: payload.homeId,
      ),
    );
  }

  /// Retrieves an existing pairing payload for a Home (to show QR code again).
  Future<PairingPayload?> getPairingPayload(String homeId) async {
    final Uint8List? key;
    try {
      key = await _keyStore.getKey(homeId);
    } catch (_) {
      return null;
    }
    if (key == null) return null;

    final home = await (_db.select(_db.localHomes)
          ..where((t) => t.id.equals(homeId)))
        .getSingleOrNull();
    if (home == null) return null;

    final user = ref.read(authProvider).value;
    final userProfile = ref.read(userProfileProvider);
    return PairingPayload(
      homeId: home.id,
      homeName: home.name,
      symmetricKey: key,
      inviterId: user?.id ?? home.createdBy,
      inviterName: userProfile.displayName,
      inviterAvatar: userProfile.avatarUrl,
      createdAt: home.createdAt,
    );
  }

  /// Leaves a home, cleans up keys and local data.
  Future<void> leaveHome(String homeId) async {
    _cachedPairingCodes.remove(homeId);
    _bumpPairingCodeRevision();
    await _keyStore.removeKey(homeId);

    final supabase = ref.read(supabaseClientProvider);
    final user = ref.read(authProvider).value;
    if (supabase != null && user != null) {
      try {
        await supabase
            .from('home_members')
            .delete()
            .match({'home_id': homeId, 'user_id': user.id});
      } catch (_) {}
    }

    await (_db.delete(_db.localHomes)..where((t) => t.id.equals(homeId))).go();

    // If leaving active home, switch to remaining home if any
    final remainingHomes = await _db.select(_db.localHomes).get();
    if (remainingHomes.isNotEmpty) {
      ref
          .read(activeHomeIdProvider.notifier)
          .setActiveHome(remainingHomes.first.id);
    } else {
      ref.read(activeHomeIdProvider.notifier).setActiveHome('');
    }
  }

  /// Ensures a locally stored home and current user membership exist in Supabase.
  /// Self-heals any connection dropouts or delayed initial inserts.
  Future<void> ensureHomeSyncedToSupabase(String homeId) async {
    if (!await _keyStore.hasKey(homeId)) {
      return;
    }

    final supabase = ref.read(supabaseClientProvider);
    if (supabase == null) return;

    final home = await (_db.select(_db.localHomes)
          ..where((t) => t.id.equals(homeId)))
        .getSingleOrNull();
    if (home == null) return;

    final user = ref.read(authProvider).value;
    final userId = supabase.auth.currentUser?.id ?? user?.id;
    if (userId == null) return;

    try {
      await supabase.from('homes').upsert({
        'id': home.id,
        'name': home.name,
        'description': home.description,
        'icon': home.icon,
        'created_at': home.createdAt.toIso8601String(),
        'created_by': home.createdBy,
      });

      final userProfile = ref.read(userProfileProvider);
      await supabase.from('home_members').upsert({
        'home_id': home.id,
        'user_id': userId,
        'joined_at': clock.now().toUtc().toIso8601String(),
        'display_name': userProfile.displayName,
        'avatar_url': userProfile.avatarUrl,
      });
      debugPrint(
        '[HomeController] Verified/synced home and membership to Supabase: $homeId',
      );
    } catch (e) {
      debugPrint(
        '[HomeController] Error ensuring home synced to Supabase: $e',
      );
    }
  }

  /// Generates a 6-digit pairing code using `libsodium`'s `randombytes` and
  /// stores a keyless row in `pairing_codes` (`code`, `home_id`, `inviter_id`,
  /// `expires_at` = now + 10 min, `status = 'open'`). Never writes a payload or
  /// home key to the server, and never touches `homes.description`.
  Future<String> createPairingCode({
    required String homeId,
  }) async {
    final code = PairingCrypto.generateSixDigitCode();
    final now = clock.now().toUtc();
    final expiresAt = now.add(const Duration(minutes: 10));
    final inviterId = _currentUserId();
    final userProfile = ref.read(userProfileProvider);
    final home = await (_db.select(_db.localHomes)
          ..where((t) => t.id.equals(homeId)))
        .getSingleOrNull();

    final relay = _pairingRelay;
    if (relay != null) {
      unawaited(
        relay.cleanupDoneAndExpired(
          nowUtc: now,
          actorUserId: inviterId,
        ),
      );
      try {
        await relay.insertPairingCode(
          PairingCodeRecord(
            code: code,
            homeId: homeId,
            inviterId: inviterId,
            expiresAt: expiresAt,
            status: 'open',
            createdAt: now,
            homeName: home?.name,
            inviterName: userProfile.displayName,
          ),
        );
      } catch (e) {
        debugPrint('[HomeController] Error creating keyless pairing code: $e');
      }
    }

    _cachedPairingCodes[homeId] = _SessionPairingCode(
      code: code,
      expiresAt: expiresAt,
    );
    _bumpPairingCodeRevision();
    return code;
  }

  /// Watches pending join requests (`status = 'pending'`) for [code].
  Stream<List<PairingRequestRecord>> watchPendingRequestsForCode(String code) {
    final relay = _pairingRelay;
    if (relay == null) return Stream.value(const <PairingRequestRecord>[]);
    return relay.watchPendingRequestsForCode(code);
  }

  /// Approves [request] on the inviter's phone (**Let them in**):
  /// 1. Uses [shownPublicKey] (the exact in-memory public key for which the two
  ///    SAS words were derived and shown on screen).
  /// 2. Re-reads the `pairing_requests` row just before sealing. If the row's
  ///    public key (or `code` / `joiner_id`) changed, declines automatically
  ///    and throws `"This request changed. Ask them to try again."`.
  /// 3. Seals the pairing payload to that same in-memory [shownPublicKey]
  ///    using `sodium.crypto.box.seal` (`crypto_box_seal`) and writes only the
  ///    sealed blob (`status = 'approved'`), marking the code single-use.
  Future<void> approvePairingRequest({
    required PairingRequestRecord request,
    Uint8List? shownPublicKey,
    PairingPayload? payloadOverride,
  }) async {
    final relay = _pairingRelay;
    if (relay == null) {
      throw StateError('Pairing service is not connected.');
    }

    final inviterId = _currentUserId();
    // Hold the exact public key that was used to derive the two words on screen.
    final pinnedPublicKey = Uint8List.fromList(
      shownPublicKey ?? request.joinerPublicKeyBytes,
    );

    // Re-read the row just before sealing to verify nothing changed since the words were shown.
    final freshRow = await relay.getRequestById(request.id);
    if (freshRow == null ||
        freshRow.status != 'pending' ||
        freshRow.code != request.code ||
        freshRow.joinerId != request.joinerId ||
        !_bytesEqual(freshRow.joinerPublicKeyBytes, pinnedPublicKey)) {
      await relay.declineRequest(
        requestId: request.id,
        actorUserId: inviterId,
      );
      throw StateError('This request changed. Ask them to try again.');
    }

    PairingPayload? payload = payloadOverride;
    if (payload == null) {
      final codeRow = await relay.getOwnPairingCode(
        code: request.code,
        inviterId: inviterId,
      );
      if (codeRow == null) {
        throw StateError('Pairing code ${request.code} was not found.');
      }
      payload = await getPairingPayload(codeRow.homeId);
    }
    if (payload == null) {
      throw StateError('Missing home key; cannot approve join request.');
    }

    final plaintextBytes = Uint8List.fromList(utf8.encode(payload.toQrString()));
    // Seal strictly to the in-memory key for which the words were shown.
    final sealedBytes = PairingCrypto.cryptoBoxSeal(
      plaintext: plaintextBytes,
      recipientPublicKey: pinnedPublicKey,
    );
    final sealedPayloadBase64 = base64Encode(sealedBytes);

    await relay.approveRequest(
      requestId: request.id,
      code: request.code,
      sealedPayload: sealedPayloadBase64,
      actorUserId: inviterId,
    );
  }

  /// Declines [request] on the inviter's phone (**Not them**):
  /// sets `status = 'declined'` with no sealed payload so the joiner never
  /// receives a key.
  Future<void> declinePairingRequest(String requestId) async {
    final relay = _pairingRelay;
    if (relay == null) {
      throw StateError('Pairing service is not connected.');
    }
    await relay.declineRequest(
      requestId: requestId,
      actorUserId: _currentUserId(),
    );
  }

  /// Joiner step 1 (`17-invite-and-keys.md` §1 step 2–3):
  /// Generates a fresh X25519 keypair via `sodium.crypto.box.keyPair()`,
  /// submits a `pairing_requests` row for [rawCode], and derives the two
  /// verification words (`AMBER · HARBOUR`).
  Future<PendingPairingJoinSession> submitPairingJoinRequest(
    String rawCode, {
    PairingBoxKeyPair? keyPairOverride,
  }) async {
    final code = rawCode.replaceAll(RegExp(r'\s+'), '').trim();
    if (code.length != 6 || int.tryParse(code) == null) {
      throw const FormatException('Pairing code must be 6 digits.');
    }

    final relay = _pairingRelay;
    if (relay == null) {
      throw StateError('Authentication service is not connected.');
    }

    final joinerId = _currentUserId(fallback: 'local_joiner');
    final user = ref.read(authProvider).value;
    final userProfile = ref.read(userProfileProvider);
    final joinerName = userProfile.displayName.trim().isNotEmpty
        ? userProfile.displayName.trim()
        : (user?.displayName ?? 'Partner');

    final keyPair = keyPairOverride ?? PairingCrypto.generateKeyPair();
    final verificationWords = PairingCrypto.deriveVerificationWords(
      joinerPublicKey: keyPair.publicKey,
      code: code,
    );

    final request = await relay.submitJoinRequest(
      code: code,
      joinerId: joinerId,
      joinerName: joinerName,
      joinerPublicKey: keyPair.publicKeyBase64,
    );

    return PendingPairingJoinSession(
      request: request,
      keyPair: keyPair,
      verificationWords: verificationWords,
    );
  }

  /// Joiner step 2 (`17-invite-and-keys.md` §1 step 6):
  /// Opens the approved `sealed_payload` with [session.keyPair] using
  /// `sodium.crypto.box.sealOpen`, imports the home key via [joinHomeFromQr],
  /// marks the request `'done'`, and cleans up done/expired rows.
  Future<void> completeApprovedPairingJoin(
    PendingPairingJoinSession session,
  ) async {
    final relay = _pairingRelay;
    if (relay == null) {
      throw StateError('Authentication service is not connected.');
    }

    final latest = await relay.getRequestById(session.request.id);
    if (latest == null) {
      throw StateError('Join request is no longer available.');
    }
    if (latest.status == 'declined') {
      throw StateError('Join request was declined by the home owner.');
    }
    if (latest.status != 'approved' ||
        latest.sealedPayload == null ||
        latest.sealedPayload!.isEmpty) {
      throw StateError('Join request has not been approved yet.');
    }

    final sealedBytes = Uint8List.fromList(base64Decode(latest.sealedPayload!));
    final openedBytes = PairingCrypto.cryptoBoxSealOpen(
      sealedBox: sealedBytes,
      recipientKeyPair: session.keyPair,
    );
    final qrString = utf8.decode(openedBytes);

    await joinHomeFromQr(qrString);
    final joinerId = _currentUserId(fallback: session.request.joinerId);
    await relay.markRequestDone(
      requestId: session.request.id,
      actorUserId: joinerId,
    );
    await relay.cleanupDoneAndExpired(
      nowUtc: clock.now().toUtc(),
      actorUserId: joinerId,
    );
  }

  /// Waits for [session] to be approved or declined on the inviter's phone,
  /// then completes the join upon approval.
  Future<void> waitForApprovedPairingJoin(
    PendingPairingJoinSession session, {
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final relay = _pairingRelay;
    if (relay == null) {
      throw StateError('Authentication service is not connected.');
    }

    await for (final record
        in relay.watchRequestById(session.request.id).timeout(timeout)) {
      if (record == null) {
        throw StateError('Join request was cancelled or expired.');
      }
      if (record.status == 'declined') {
        throw StateError('Join request was declined by the home owner.');
      }
      if (record.status == 'approved' &&
          record.sealedPayload != null &&
          record.sealedPayload!.isEmpty == false) {
        await completeApprovedPairingJoin(session);
        return;
      }
    }
    throw StateError('Join request closed before approval.');
  }

  /// Joins a home using a 6-digit pairing code (`17-invite-and-keys.md` §1):
  /// submits a join request with a fresh keypair, surfaces the two verification
  /// words via [onSessionCreated], and awaits the inviter's approval.
  Future<void> joinHomeFromCode(
    String rawCode, {
    ValueChanged<PendingPairingJoinSession>? onSessionCreated,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final session = await submitPairingJoinRequest(rawCode);
    onSessionCreated?.call(session);
    await waitForApprovedPairingJoin(session, timeout: timeout);
  }

  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  String _generateUuid() => generateCoveUuid();
}

final homeControllerProvider = Provider<HomeController>((ref) {
  return HomeController(ref);
});
