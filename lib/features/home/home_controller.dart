import 'dart:async';
import 'dart:math';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/uuid_generator.dart';
import '../../sync/crypto/sodium_crypto_service.dart';
import '../../sync/db/app_database.dart';
import '../../sync/key_management/home_key_store.dart';
import '../../sync/key_management/pairing_payload.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';

class HomeController {
  final Ref ref;

  HomeController(this.ref);

  AppDatabase get _db => ref.read(appDatabaseProvider);
  HomeKeyStore get _keyStore => ref.read(homeKeyStoreProvider);
  SodiumCryptoService get _crypto => ref.read(sodiumCryptoServiceProvider);

  /// Creates a new shared household, generates its 256-bit encryption key,
  /// saves it to secure storage, and returns the PairingPayload for the QR code.
  Future<PairingPayload> createHome({
    required String name,
    String? description,
    String? currency,
  }) async {
    final supabase = ref.read(supabaseClientProvider);
    final user = ref.read(authProvider).value;
    final userId = supabase?.auth.currentUser?.id ?? user?.id ?? 'local_user';
    final now = DateTime.now().toUtc();
    final homeId = _generateUuid();

    // 1. Generate 256-bit symmetric encryption key
    final symmetricKey = _crypto.generateHomeKey();

    // 2. Persist symmetric key securely on-device
    await _keyStore.saveKey(homeId, symmetricKey);

    // 3. Insert into local Drift database
    final initialCurrency = currency ?? ref.read(currencyPreferenceProvider).code;
    await _db.into(_db.localHomes).insertOnConflictUpdate(
          LocalHomesCompanion.insert(
            id: homeId,
            name: name,
            description: drift.Value(description),
            icon: drift.Value(null), // Deterministic icon mark
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
        debugPrint('[HomeController] Home and membership successfully saved to Supabase: $homeId');
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
    final user = ref.read(authProvider).value;
    final userId = supabase?.auth.currentUser?.id ?? user?.id ?? 'local_user';
    final now = DateTime.now().toUtc();

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
        debugPrint('[HomeController] Partner successfully added to Supabase home_members: ${payload.homeId}');
      } catch (e) {
        debugPrint('[HomeController] Error adding partner to Supabase home_members: $e');
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
    unawaited(emitAction(
      eventType: 'member_profile_updated',
      payload: {
        'display_name': userProfile.displayName,
        'avatar_url': userProfile.avatarUrl,
        'user_id': userId,
      },
      targetHomeId: payload.homeId,
    ));
  }

  /// Retrieves an existing pairing payload for a Home (to show QR code again).
  Future<PairingPayload?> getPairingPayload(String homeId) async {
    final key = await _keyStore.getKey(homeId);
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
        'joined_at': DateTime.now().toUtc().toIso8601String(),
        'display_name': userProfile.displayName,
        'avatar_url': userProfile.avatarUrl,
      });
      debugPrint('[HomeController] Verified/synced home and membership to Supabase: $homeId');
    } catch (e) {
      debugPrint('[HomeController] Error ensuring home synced to Supabase: $e');
    }
  }

  /// Generates a random 6-digit pairing code, stores it ephemerally with 10-min TTL,
  /// and returns the code string.
  Future<String> createPairingCode({
    required String homeId,
    required PairingPayload payload,
  }) async {
    final rng = Random();
    final code = (100000 + rng.nextInt(900000)).toString();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(const Duration(minutes: 10));
    final payloadJson = payload.toQrString();

    final supabase = ref.read(supabaseClientProvider);
    if (supabase != null) {
      bool storedInTable = false;
      try {
        await supabase.from('pairing_codes').upsert({
          'code': code,
          'home_id': homeId,
          'payload': payloadJson,
          'created_at': now.toIso8601String(),
          'expires_at': expiresAt.toIso8601String(),
        });
        storedInTable = true;
      } catch (_) {
        // pairing_codes table not migrated yet
      }

      if (!storedInTable) {
        try {
          final pairingTag = 'pairing:$code:${expiresAt.millisecondsSinceEpoch}:$payloadJson';
          await supabase.from('homes').update({
            'description': pairingTag,
          }).eq('id', homeId);
        } catch (e) {
          debugPrint('[HomeController] Error saving ephemeral pairing code to homes: $e');
        }
      }
    }

    return code;
  }

  /// Joins a home using an ephemeral 6-digit pairing code.
  Future<void> joinHomeFromCode(String rawCode) async {
    final code = rawCode.replaceAll(RegExp(r'\s+'), '').trim();
    if (code.length != 6) {
      throw const FormatException('Pairing code must be 6 digits.');
    }

    final supabase = ref.read(supabaseClientProvider);
    if (supabase == null) {
      throw Exception('Authentication service is not connected.');
    }

    String? payloadJson;
    String? matchedHomeId;

    // 1. Try lookup in pairing_codes table
    try {
      final res = await supabase
          .from('pairing_codes')
          .select('code, home_id, payload, expires_at')
          .eq('code', code)
          .maybeSingle();

      if (res != null) {
        final expiresAtStr = res['expires_at'] as String?;
        if (expiresAtStr != null) {
          final expiresAt = DateTime.tryParse(expiresAtStr);
          if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
            throw Exception('Pairing code has expired. Please request a new code.');
          }
        }
        payloadJson = res['payload'] as String?;
        matchedHomeId = res['home_id'] as String?;

        unawaited(supabase.from('pairing_codes').delete().eq('code', code));
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('expired')) rethrow;
    }

    // 2. Fallback: Lookup in homes table by description tag
    if (payloadJson == null) {
      try {
        final rows = await supabase
            .from('homes')
            .select('id, description')
            .like('description', 'pairing:$code:%');

        if (rows.isNotEmpty) {
          for (final row in rows) {
            final desc = row['description'] as String? ?? '';
            if (desc.startsWith('pairing:$code:')) {
              final parts = desc.split(':');
              if (parts.length >= 4) {
                final expiresMs = int.tryParse(parts[2]);
                if (expiresMs != null && DateTime.now().millisecondsSinceEpoch > expiresMs) {
                  throw Exception('Pairing code has expired. Please request a new code.');
                }
                final prefix = 'pairing:$code:${parts[2]}:';
                payloadJson = desc.substring(prefix.length);
                matchedHomeId = row['id'] as String?;
                break;
              }
            }
          }
        }
      } catch (e) {
        if (e is Exception && e.toString().contains('expired')) rethrow;
      }
    }

    if (payloadJson == null) {
      throw Exception('Invalid or expired 6-digit code. Please check your partner\'s screen.');
    }

    await joinHomeFromQr(payloadJson);

    if (matchedHomeId != null) {
      unawaited(supabase.from('homes').update({'description': null}).eq('id', matchedHomeId));
    }
  }

  String _generateUuid() => generateCoveUuid();
}

final homeControllerProvider = Provider<HomeController>((ref) {
  return HomeController(ref);
});
