import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/home/home_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/key_management/pairing_approval_sheet.dart';
import 'package:cove/sync/key_management/pairing_crypto.dart';
import 'package:cove/sync/key_management/pairing_qr_view.dart';
import 'package:cove/sync/key_management/pairing_relay.dart';
import 'package:cove/sync/key_management/pairing_wordlist.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: deprecated_member_use
import 'package:sodium_libs/sodium_libs.dart';

import 'golden/golden_harness.dart';

final DateTime _kFixedNow = DateTime.utc(2026, 10, 26, 12, 0, 0);

class _FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  final CoveUser _user;
  _FakeAuthNotifier(this._user);

  @override
  AsyncValue<CoveUser?> build() => AsyncData(_user);

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void signInWithDemoUser([
    String name = 'Saba',
    String email = 'saba@cove.local',
  ]) {}

  @override
  Future<void> signOut() async {}
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  final UserProfileState _profile;
  _FakeUserProfileNotifier(this._profile);

  @override
  UserProfileState build() => _profile;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  PartnerProfileState _state = const PartnerProfileState(
    displayName: 'Partner',
    hasCustomName: false,
  );

  @override
  PartnerProfileState build() => _state;

  @override
  Future<void> setPartnerFromSync({
    required String name,
    String? avatarUrl,
    String? userId,
  }) async {
    _state = PartnerProfileState(
      displayName: name,
      avatarUrl: avatarUrl,
      hasCustomName: true,
      userId: userId,
    );
    state = _state;
  }
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() =>
      const CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee');
}

class _MemoryActiveHomeNotifier extends ActiveHomeNotifier {
  String? _current;
  _MemoryActiveHomeNotifier([this._current]);

  @override
  String? build() => _current;

  @override
  Future<void> setActiveHome(String homeId) async {
    _current = homeId;
    state = homeId;
  }
}

class _MemoryHomeKeyStore extends Fake implements HomeKeyStore {
  final Map<String, Uint8List> keys = <String, Uint8List>{};
  int saveKeyCalls = 0;

  @override
  Future<Uint8List?> getKey(String homeId) async => keys[homeId];

  @override
  Future<bool> hasKey(String homeId) async => keys.containsKey(homeId);

  @override
  Future<void> saveKey(String homeId, Uint8List key) async {
    saveKeyCalls++;
    keys[homeId] = Uint8List.fromList(key);
  }

  @override
  Future<void> removeKey(String homeId) async {
    keys.remove(homeId);
  }
}

class _NoOpSyncEngine extends Fake implements SyncEngineImpl {
  String? startedHomeId;
  List<int>? startedHomeKey;

  @override
  Future<void> start({
    String? activeHomeId,
    List<int>? activeHomeKey,
  }) async {
    startedHomeId = activeHomeId;
    startedHomeKey = activeHomeKey;
  }

  @override
  Future<void> stop() async {}
}

class _TestClientRig {
  final AppDatabase db;
  final _MemoryHomeKeyStore keyStore;
  final _NoOpSyncEngine syncEngine;
  final ProviderContainer container;

  _TestClientRig._({
    required this.db,
    required this.keyStore,
    required this.syncEngine,
    required this.container,
  });

  HomeController get homeController => container.read(homeControllerProvider);

  static _TestClientRig create({
    required CoveUser user,
    required InMemoryPairingRelay relay,
  }) {
    final db = AppDatabase(NativeDatabase.memory());
    final keyStore = _MemoryHomeKeyStore();
    final syncEngine = _NoOpSyncEngine();
    final profile = UserProfileState(
      displayName: user.displayName ?? 'User',
      email: user.email,
    );

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        homeKeyStoreProvider.overrideWithValue(keyStore),
        pairingRelayProvider.overrideWithValue(relay),
        syncEngineProvider.overrideWithValue(syncEngine),
        supabaseClientProvider.overrideWithValue(null),
        authProvider.overrideWith(() => _FakeAuthNotifier(user)),
        userProfileProvider.overrideWith(
          () => _FakeUserProfileNotifier(profile),
        ),
        partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
        currencyPreferenceProvider.overrideWith(_FakeCurrencyNotifier.new),
        activeHomeIdProvider.overrideWith(_MemoryActiveHomeNotifier.new),
        coveEmitActionProvider.overrideWithValue(
          ({
            required String eventType,
            required Map<String, dynamic> payload,
            String? targetHomeId,
          }) async {},
        ),
      ],
    );

    return _TestClientRig._(
      db: db,
      keyStore: keyStore,
      syncEngine: syncEngine,
      container: container,
    );
  }

  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await PairingCrypto.ensureInitialized();
    await loadCoveFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PartnerProfileNotifier.resetCache();
  });

  group('4.3c SAS word list & libsodium sealed-box interoperability', () {
    test(
      'kPairingWordList contains 2,048 distinct uppercase words and 22-bit SHA-256 derivation is deterministic',
      () {
        expect(kPairingWordList.length, 2048);
        expect(kPairingWordList.toSet().length, 2048);
        expect(kPairingWordList, contains('AMBER'));
        expect(kPairingWordList, contains('HARBOUR'));

        final kp = PairingCrypto.generateKeyPair(
          seed: Uint8List.fromList(List<int>.generate(32, (i) => i + 1)),
        );
        addTearDown(kp.dispose);
        const code = '482910';

        final preimage = Uint8List.fromList([
          ...kp.publicKey,
          ...utf8.encode(code),
        ]);
        final digest = PairingCrypto.sha256Bytes(preimage);
        final bits22 = (digest[0] << 14) | (digest[1] << 6) | (digest[2] >> 2);
        final expectedIdx1 = (bits22 >> 11) & 0x7FF;
        final expectedIdx2 = bits22 & 0x7FF;

        final derived = PairingCrypto.deriveVerificationWords(
          joinerPublicKey: kp.publicKey,
          code: code,
        );
        expect(derived.word1Index, expectedIdx1);
        expect(derived.word2Index, expectedIdx2);
        expect(
          derived.formatted,
          '${kPairingWordList[expectedIdx1]} · ${kPairingWordList[expectedIdx2]}',
        );
      },
    );

    test(
      'a box sealed by our code opens with libsodium sealOpen directly, and the reverse',
      () {
        final Sodium sodium = PairingCrypto.sodium;
        final plaintext = Uint8List.fromList(
          utf8.encode('{"homeId":"home_1","key":"secret_32_byte_material"}'),
        );

        // 1. Sealed by PairingCrypto.cryptoBoxSeal -> opened directly by sodium.crypto.box.sealOpen
        final KeyPair rawLibKeyPair = sodium.crypto.box.keyPair();
        addTearDown(rawLibKeyPair.dispose);

        final sealedByOurCode = PairingCrypto.cryptoBoxSeal(
          plaintext: plaintext,
          recipientPublicKey: rawLibKeyPair.publicKey,
        );
        expect(
          sealedByOurCode.length,
          plaintext.length + sodium.crypto.box.sealBytes,
        );

        final openedByDirectLibsodium = sodium.crypto.box.sealOpen(
          cipherText: sealedByOurCode,
          publicKey: rawLibKeyPair.publicKey,
          secretKey: rawLibKeyPair.secretKey,
        );
        expect(openedByDirectLibsodium, equals(plaintext));

        // 2. Sealed directly by sodium.crypto.box.seal -> opened by PairingCrypto.cryptoBoxSealOpen
        final ourKeyPair = PairingCrypto.generateKeyPair();
        addTearDown(ourKeyPair.dispose);

        final sealedByDirectLibsodium = sodium.crypto.box.seal(
          message: plaintext,
          publicKey: ourKeyPair.publicKey,
        );
        final openedByOurCode = PairingCrypto.cryptoBoxSealOpen(
          sealedBox: sealedByDirectLibsodium,
          recipientKeyPair: ourKeyPair,
        );
        expect(openedByOurCode, equals(plaintext));

        // 3. 6-digit code comes from libsodium randombytes and is always 6 digits (100000..999999)
        for (var i = 0; i < 20; i++) {
          final code = PairingCrypto.generateSixDigitCode();
          expect(code.length, 6);
          final parsed = int.parse(code);
          expect(parsed, inInclusiveRange(100000, 999999));
        }
      },
    );
  });

  group('4.3c Approved-code invite flow & tighter server rules', () {
    late InMemoryPairingRelay fakeServer;
    late _TestClientRig clientA;
    late _TestClientRig clientB;

    setUp(() {
      fakeServer = InMemoryPairingRelay();
      clientA = _TestClientRig.create(
        user: const CoveUser(
          id: 'user_a_saba',
          email: 'saba@cove.local',
          displayName: 'Saba',
        ),
        relay: fakeServer,
      );
      clientB = _TestClientRig.create(
        user: const CoveUser(
          id: 'user_b_ancy',
          email: 'ancy@cove.local',
          displayName: 'Ancy',
        ),
        relay: fakeServer,
      );
    });

    tearDown(() async {
      await clientA.dispose();
      await clientB.dispose();
    });

    test(
      '1. end to end with two fake clients and a fake server: A creates, B requests, the words match, A approves, B opens the sealed key',
      () async {
        await withClock(Clock.fixed(_kFixedNow), () async {
          final payloadA = await clientA.homeController.createHome(
            name: 'The Nest',
            description: 'Bengaluru',
          );
          final code = await clientA.homeController.createPairingCode(
            homeId: payloadA.homeId,
          );
          expect(code.length, 6);

          // B submits a join request with the 6-digit code
          final sessionB =
              await clientB.homeController.submitPairingJoinRequest(code);
          addTearDown(sessionB.keyPair.dispose);

          // A sees B's pending request on the server
          final pendingForA = await fakeServer.listPendingRequestsForCode(code);
          expect(pendingForA, hasLength(1));
          final requestOnA = pendingForA.single;

          // The two verification words match on both phones
          final shownPublicKeyOnA = Uint8List.fromList(
            requestOnA.joinerPublicKeyBytes,
          );
          final wordsOnA = PairingCrypto.deriveVerificationWords(
            joinerPublicKey: shownPublicKeyOnA,
            code: requestOnA.code,
          );
          final wordsOnB = sessionB.verificationWords;
          expect(wordsOnA.formatted, equals(wordsOnB.formatted));
          expect(wordsOnA.formatted, contains(' · '));

          // A approves ("Let them in"), sealing to the exact in-memory key it showed words for
          await clientA.homeController.approvePairingRequest(
            request: requestOnA,
            shownPublicKey: shownPublicKeyOnA,
          );

          // Code is single-use once approved: another join request is rejected
          await expectLater(
            () => clientB.homeController.submitPairingJoinRequest(code),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('already been used'),
              ),
            ),
          );

          // B opens the sealed payload, saves the home key, and joins
          await clientB.homeController.completeApprovedPairingJoin(sessionB);

          final keyOnB = await clientB.keyStore.getKey(payloadA.homeId);
          expect(keyOnB, isNotNull);
          expect(keyOnB, equals(payloadA.symmetricKey));
          expect(
            clientB.container.read(activeHomeIdProvider),
            equals(payloadA.homeId),
          );

          // Done request is cleaned up after completion
          expect(await fakeServer.getRequestById(sessionB.request.id), isNull);
        });
      },
    );

    test(
      '2. a swapped public key -> the words differ, and if the row changes after showing words, A declines automatically with "This request changed. Ask them to try again."',
      () async {
        await withClock(Clock.fixed(_kFixedNow), () async {
          final payloadA = await clientA.homeController.createHome(
            name: 'The Nest',
          );
          final code = await clientA.homeController.createPairingCode(
            homeId: payloadA.homeId,
          );

          final joinerKeyPair = PairingCrypto.generateKeyPair(
            seed: Uint8List.fromList(List<int>.filled(32, 11)),
          );
          final mitmKeyPair = PairingCrypto.generateKeyPair(
            seed: Uint8List.fromList(List<int>.filled(32, 22)),
          );
          addTearDown(joinerKeyPair.dispose);
          addTearDown(mitmKeyPair.dispose);

          final sessionB =
              await clientB.homeController.submitPairingJoinRequest(
            code,
            keyPairOverride: joinerKeyPair,
          );

          // Case A: Server swaps the public key BEFORE A views the request -> the words differ!
          fakeServer.swapJoinerPublicKeyOnServerForTest(
            requestId: sessionB.request.id,
            replacementPublicKeyBase64: mitmKeyPair.publicKeyBase64,
          );

          final swappedRequestOnA =
              (await fakeServer.listPendingRequestsForCode(code)).single;
          expect(
            swappedRequestOnA.verificationWords.formatted,
            isNot(equals(sessionB.verificationWords.formatted)),
          );

          // Case B: Server swaps the public key AFTER A has already shown the words for B's key
          // -> when A taps "Let them in", approvePairingRequest re-reads the row just before
          // sealing, detects the key changed from `shownPublicKey`, declines automatically,
          // and says "This request changed. Ask them to try again."
          final shownPublicKeyInMemory = Uint8List.fromList(
            joinerKeyPair.publicKey,
          );
          await expectLater(
            () => clientA.homeController.approvePairingRequest(
              request: sessionB.request,
              shownPublicKey: shownPublicKeyInMemory,
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                equals('This request changed. Ask them to try again.'),
              ),
            ),
          );

          final declinedRow = await fakeServer.getRequestById(
            sessionB.request.id,
          );
          expect(declinedRow?.status, equals('declined'));
          expect(declinedRow?.sealedPayload, isNull);
          expect(await clientB.keyStore.getKey(payloadA.homeId), isNull);
        });
      },
    );

    test(
      '3. Not them -> B never gets a key',
      () async {
        await withClock(Clock.fixed(_kFixedNow), () async {
          final payloadA = await clientA.homeController.createHome(
            name: 'The Nest',
          );
          final code = await clientA.homeController.createPairingCode(
            homeId: payloadA.homeId,
          );

          final sessionB =
              await clientB.homeController.submitPairingJoinRequest(code);
          addTearDown(sessionB.keyPair.dispose);
          final pendingForA = await fakeServer.listPendingRequestsForCode(code);
          expect(pendingForA, hasLength(1));

          // A taps "Not them" (declines)
          await clientA.homeController.declinePairingRequest(
            pendingForA.single.id,
          );

          final declinedRow = await fakeServer.getRequestById(
            sessionB.request.id,
          );
          expect(declinedRow?.status, 'declined');
          expect(declinedRow?.sealedPayload, isNull);

          await expectLater(
            () => clientB.homeController.completeApprovedPairingJoin(sessionB),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('declined'),
              ),
            ),
          );

          expect(clientB.keyStore.saveKeyCalls, 0);
          expect(await clientB.keyStore.getKey(payloadA.homeId), isNull);
        });
      },
    );

    test(
      '4. an expired code -> rejected',
      () async {
        late String code;
        late String homeId;

        await withClock(Clock.fixed(_kFixedNow), () async {
          final payloadA = await clientA.homeController.createHome(
            name: 'The Nest',
          );
          homeId = payloadA.homeId;
          code = await clientA.homeController.createPairingCode(
            homeId: homeId,
          );
        });

        await withClock(
          Clock.fixed(_kFixedNow.add(const Duration(minutes: 10, seconds: 1))),
          () async {
            await expectLater(
              () => clientB.homeController.submitPairingJoinRequest(code),
              throwsA(
                isA<StateError>().having(
                  (e) => e.message,
                  'message',
                  contains('expired'),
                ),
              ),
            );
            expect(fakeServer.requests, isEmpty);
            expect(await clientB.keyStore.getKey(homeId), isNull);
          },
        );
      },
    );

    test(
      '5. a fourth request on a code -> rejected (at most 3 requests allowed)',
      () async {
        await withClock(Clock.fixed(_kFixedNow), () async {
          final payloadA = await clientA.homeController.createHome(
            name: 'The Nest',
          );
          final code = await clientA.homeController.createPairingCode(
            homeId: payloadA.homeId,
          );

          final r1 =
              await clientB.homeController.submitPairingJoinRequest(code);
          final r2 =
              await clientB.homeController.submitPairingJoinRequest(code);
          final r3 =
              await clientB.homeController.submitPairingJoinRequest(code);
          addTearDown(r1.keyPair.dispose);
          addTearDown(r2.keyPair.dispose);
          addTearDown(r3.keyPair.dispose);
          expect({r1.request.id, r2.request.id, r3.request.id}, hasLength(3));

          await expectLater(
            () => clientB.homeController.submitPairingJoinRequest(code),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('Too many join requests'),
              ),
            ),
          );
          expect(fakeServer.requests.length, 3);
        });
      },
    );

    test(
      '6. nothing written to the server ever contains the key (scan every write in the fake)',
      () async {
        await withClock(Clock.fixed(_kFixedNow), () async {
          final payloadA = await clientA.homeController.createHome(
            name: 'The Nest',
            description: 'Bengaluru',
          );
          final homeKey = payloadA.symmetricKey;
          final keyBase64 = base64Encode(homeKey);
          final keyBase64Url = base64UrlEncode(homeKey);
          final keyBase64NoPad = keyBase64.replaceAll('=', '');
          final keyHex = homeKey
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          final qrJson = payloadA.toQrString();

          final code = await clientA.homeController.createPairingCode(
            homeId: payloadA.homeId,
          );
          final sessionB =
              await clientB.homeController.submitPairingJoinRequest(code);
          addTearDown(sessionB.keyPair.dispose);
          final pendingOnA =
              (await fakeServer.listPendingRequestsForCode(code)).single;
          await clientA.homeController.approvePairingRequest(
            request: pendingOnA,
            shownPublicKey: pendingOnA.joinerPublicKeyBytes,
          );
          await clientB.homeController.completeApprovedPairingJoin(sessionB);

          expect(fakeServer.writeLog, isNotEmpty);

          for (final entry in fakeServer.writeLog) {
            final serialized = entry.toJsonString();

            if (entry.table == 'pairing_codes') {
              expect(entry.payload.containsKey('payload'), isFalse);
            }

            expect(serialized.contains(keyBase64), isFalse);
            expect(serialized.contains(keyBase64Url), isFalse);
            expect(serialized.contains(keyBase64NoPad), isFalse);
            expect(
              serialized.toLowerCase().contains(keyHex.toLowerCase()),
              isFalse,
            );
            expect(serialized.contains(qrJson), isFalse);

            final sealedStr = entry.payload['sealed_payload'] as String?;
            if (sealedStr != null && sealedStr.isNotEmpty) {
              final rawSealed = base64Decode(sealedStr);
              expect(_containsSubsequence(rawSealed, homeKey), isFalse);
            }
          }
        });
      },
    );

    test(
      '7. tighter server rules: inviter-only code read, lookup_pairing_code, immutable request fields, role transitions, delete policy, and 5/hour rate limits',
      () async {
        await withClock(Clock.fixed(_kFixedNow), () async {
          final payloadA = await clientA.homeController.createHome(
            name: 'The Nest',
          );
          final code1 = await clientA.homeController.createPairingCode(
            homeId: payloadA.homeId,
          );
          final code2 = await clientA.homeController.createPairingCode(
            homeId: payloadA.homeId,
          );

          // Rule A: Only the inviter can read their own pairing_codes row directly.
          expect(
            await fakeServer.getOwnPairingCode(
              code: code1,
              inviterId: 'user_a_saba',
            ),
            isNotNull,
          );
          expect(
            await fakeServer.getOwnPairingCode(
              code: code1,
              inviterId: 'user_b_ancy',
            ),
            isNull,
          );

          // Joiner checks a code only via lookupPairingCode, which returns home_name, inviter_name, status
          final lookup = await fakeServer.lookupPairingCode(
            code: code1,
            callerUserId: 'user_b_ancy',
          );
          expect(lookup, isNotNull);
          expect(lookup!.homeName, equals('The Nest'));
          expect(lookup.inviterName, equals('Saba'));
          expect(lookup.status, equals('open'));

          // Rule B: Immutability trigger on pairing_requests & role transition rules
          final s1 =
              await clientB.homeController.submitPairingJoinRequest(code1);
          addTearDown(s1.keyPair.dispose);

          // code, joiner_id, and joiner_public_key are immutable after insert
          await expectLater(
            () => fakeServer.updateRequestWithTriggerChecks(
              requestId: s1.request.id,
              actorUserId: 'user_b_ancy',
              newCode: code2,
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('code is immutable'),
              ),
            ),
          );
          await expectLater(
            () => fakeServer.updateRequestWithTriggerChecks(
              requestId: s1.request.id,
              actorUserId: 'user_b_ancy',
              newJoinerId: 'user_c_outsider',
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('joiner_id is immutable'),
              ),
            ),
          );
          await expectLater(
            () => fakeServer.updateRequestWithTriggerChecks(
              requestId: s1.request.id,
              actorUserId: 'user_b_ancy',
              newJoinerPublicKey: 'swapped_pk',
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('joiner_public_key is immutable'),
              ),
            ),
          );

          // Joiner may only change status to 'done', never 'approved' or 'sealed_payload'
          await expectLater(
            () => fakeServer.updateRequestWithTriggerChecks(
              requestId: s1.request.id,
              actorUserId: 'user_b_ancy',
              newStatus: 'approved',
              newSealedPayload: 'forged_blob',
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('joiner may only change status to done'),
              ),
            ),
          );

          // Inviter may not change status to 'done'
          await expectLater(
            () => fakeServer.updateRequestWithTriggerChecks(
              requestId: s1.request.id,
              actorUserId: 'user_a_saba',
              newStatus: 'done',
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('inviter may only set status to approved or declined'),
              ),
            ),
          );

          // Rule C: Delete policy: only the joiner or the code's inviter, never anyone else
          await expectLater(
            () => fakeServer.deleteRequest(
              requestId: s1.request.id,
              actorUserId: 'user_c_outsider',
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('only the joiner or the code\'s inviter'),
              ),
            ),
          );
          await expectLater(
            () => fakeServer.deletePairingCode(
              code: code1,
              actorUserId: 'user_b_ancy',
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('only the code\'s inviter'),
              ),
            ),
          );

          // Rule D: Rate limit — at most 5 pairing requests per user per hour
          // (Joiner B already made 1 request on code1; make 2 more on code1 and 2 on code2 = 5 total)
          final s2 =
              await clientB.homeController.submitPairingJoinRequest(code1);
          final s3 =
              await clientB.homeController.submitPairingJoinRequest(code1);
          final s4 =
              await clientB.homeController.submitPairingJoinRequest(code2);
          final s5 =
              await clientB.homeController.submitPairingJoinRequest(code2);
          addTearDown(s2.keyPair.dispose);
          addTearDown(s3.keyPair.dispose);
          addTearDown(s4.keyPair.dispose);
          addTearDown(s5.keyPair.dispose);

          // 6th pairing request within the hour is rejected even though code2 only has 2 requests
          await expectLater(
            () => clientB.homeController.submitPairingJoinRequest(code2),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('at most 5 requests per hour'),
              ),
            ),
          );

          // Rule E: Failed lookup rate limit — at most 5 failed lookups per user per hour
          for (var i = 0; i < 5; i++) {
            final miss = await fakeServer.lookupPairingCode(
              code: '00000$i',
              callerUserId: 'user_c_outsider',
            );
            expect(miss, isNull);
          }
          // 6th lookup within the hour is rate-limited
          await expectLater(
            () => fakeServer.lookupPairingCode(
              code: code2,
              callerUserId: 'user_c_outsider',
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('Too many failed code lookups'),
              ),
            ),
          );
        });
      },
    );

    testWidgets(
      'PairingQrView surfaces PairingApprovalSheet, seals to the in-memory key on Let them in, and shows "This request changed. Ask them to try again." if the row key changed before sealing',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await withClock(Clock.fixed(_kFixedNow), () async {
          final payloadA = await clientA.homeController.createHome(
            name: 'The Nest',
          );

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: clientA.container,
              child: MaterialApp(
                theme: CoveTheme.darkTheme,
                home: Scaffold(
                  body: PairingQrView(payload: payloadA),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final code = clientA.homeController.cachedPairingCodeFor(
            payloadA.homeId,
          );
          expect(code, isNotNull);

          // 1. B submits a request, then a hostile server swaps the row's key while A is viewing the sheet
          final sSwapped =
              await clientB.homeController.submitPairingJoinRequest(code!);
          addTearDown(sSwapped.keyPair.dispose);
          await tester.pumpAndSettle();

          expect(find.byType(PairingApprovalSheet), findsOneWidget);
          expect(
            find.text(sSwapped.verificationWords.formatted),
            findsOneWidget,
          );

          final mitmKp = PairingCrypto.generateKeyPair(
            seed: Uint8List.fromList(List<int>.filled(32, 99)),
          );
          addTearDown(mitmKp.dispose);
          fakeServer.swapJoinerPublicKeyOnServerForTest(
            requestId: sSwapped.request.id,
            replacementPublicKeyBase64: mitmKp.publicKeyBase64,
          );

          // A taps "Let them in" -> re-read detects the key changed, declines automatically,
          // and shows "This request changed. Ask them to try again."
          await tester.tap(find.text('Let them in'));
          await tester.pumpAndSettle();

          expect(
            find.text('This request changed. Ask them to try again.'),
            findsOneWidget,
          );
          final declined = await fakeServer.getRequestById(sSwapped.request.id);
          expect(declined?.status, equals('declined'));
          expect(declined?.sealedPayload, isNull);

          // 2. B submits a fresh request without tampering -> A taps "Let them in" and B joins
          final sessionB =
              await clientB.homeController.submitPairingJoinRequest(code);
          addTearDown(sessionB.keyPair.dispose);
          await tester.pumpAndSettle();

          expect(find.byType(PairingApprovalSheet), findsOneWidget);
          expect(
            find.text(sessionB.verificationWords.formatted),
            findsOneWidget,
          );

          await tester.tap(find.text('Let them in'));
          await tester.pumpAndSettle();

          await clientB.homeController.completeApprovedPairingJoin(sessionB);
          expect(
            await clientB.keyStore.getKey(payloadA.homeId),
            equals(payloadA.symmetricKey),
          );
        });
      },
    );
  });
}

bool _containsSubsequence(List<int> haystack, List<int> needle) {
  if (needle.isEmpty || haystack.length < needle.length) return false;
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}
