import 'dart:convert';
import 'dart:math';
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
    await loadCoveFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PartnerProfileNotifier.resetCache();
  });

  group('4.3c SAS word list & sealed-box crypto primitives', () {
    test(
      'kPairingWordList contains 2,048 distinct uppercase words and 22-bit SHA-256 derivation is deterministic',
      () {
        expect(kPairingWordList.length, 2048);
        expect(kPairingWordList.toSet().length, 2048);
        expect(kPairingWordList, contains('AMBER'));
        expect(kPairingWordList, contains('HARBOUR'));

        final kp = PairingCrypto.generateKeyPair(random: Random(42));
        const code = '482910';

        // Compute expected indices directly from SHA-256(pk || utf8(code))
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
  });

  group('4.3c Approved-code invite flow (two fake clients + fake server)', () {
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
          // A creates the home and generates a keyless 6-digit pairing code
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

          // A sees B's pending request on the server
          final pendingForA = await fakeServer.listPendingRequestsForCode(code);
          expect(pendingForA, hasLength(1));
          final requestOnA = pendingForA.single;

          // The two verification words match on both phones
          final wordsOnA = requestOnA.verificationWords;
          final wordsOnB = sessionB.verificationWords;
          expect(wordsOnA.formatted, equals(wordsOnB.formatted));
          expect(wordsOnA.formatted, contains(' · '));

          // A approves ("Let them in") -> seals the payload to B's public key
          await clientA.homeController.approvePairingRequest(
            request: requestOnA,
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
      '2. a swapped public key -> the words differ (and B cannot open a payload sealed to the swapped key)',
      () async {
        await withClock(Clock.fixed(_kFixedNow), () async {
          final payloadA = await clientA.homeController.createHome(
            name: 'The Nest',
          );
          final code = await clientA.homeController.createPairingCode(
            homeId: payloadA.homeId,
          );

          // Choose a deterministic joiner keypair and a distinct MITM keypair
          final joinerKeyPair = PairingCrypto.generateKeyPair(
            random: Random(101),
          );
          final mitmKeyPair = PairingCrypto.generateKeyPair(
            random: Random(202),
          );

          final sessionB =
              await clientB.homeController.submitPairingJoinRequest(
            code,
            keyPairOverride: joinerKeyPair,
          );

          // Hostile server swaps B's public key on the pending request row
          fakeServer.swapJoinerPublicKeyForTest(
            requestId: sessionB.request.id,
            replacementPublicKeyBase64: mitmKeyPair.publicKeyBase64,
          );

          final pendingForA = await fakeServer.listPendingRequestsForCode(code);
          final mitmRequestOnA = pendingForA.single;

          // The words on A's phone do NOT match the words on B's phone
          expect(
            mitmRequestOnA.verificationWords.formatted,
            isNot(equals(sessionB.verificationWords.formatted)),
          );

          // Even if A mistakenly approved the swapped key, B's secret key cannot open it
          await clientA.homeController.approvePairingRequest(
            request: mitmRequestOnA,
          );
          await expectLater(
            () => clientB.homeController.completeApprovedPairingJoin(sessionB),
            throwsA(anything),
          );
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
          final pendingForA = await fakeServer.listPendingRequestsForCode(code);
          expect(pendingForA, hasLength(1));

          // A taps "Not them" (declines)
          await clientA.homeController.declinePairingRequest(
            pendingForA.single.id,
          );

          // Request has no sealed_payload and B is rejected when trying to complete
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

        // Advance clock past the 10-minute expiry window
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

          // First 3 requests on the code succeed
          final r1 =
              await clientB.homeController.submitPairingJoinRequest(code);
          final r2 =
              await clientB.homeController.submitPairingJoinRequest(code);
          final r3 =
              await clientB.homeController.submitPairingJoinRequest(code);
          expect({r1.request.id, r2.request.id, r3.request.id}, hasLength(3));

          // 4th request on the same code is rejected
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
          final pendingOnA =
              (await fakeServer.listPendingRequestsForCode(code)).single;
          await clientA.homeController.approvePairingRequest(
            request: pendingOnA,
          );
          await clientB.homeController.completeApprovedPairingJoin(sessionB);

          expect(fakeServer.writeLog, isNotEmpty);

          for (final entry in fakeServer.writeLog) {
            final serialized = entry.toJsonString();

            // `pairing_codes` writes must never have a `payload` column
            if (entry.table == 'pairing_codes') {
              expect(entry.payload.containsKey('payload'), isFalse);
            }

            // No write may contain the home key in Base64, Base64Url, unpadded Base64, Hex, or QR JSON
            expect(serialized.contains(keyBase64), isFalse);
            expect(serialized.contains(keyBase64Url), isFalse);
            expect(serialized.contains(keyBase64NoPad), isFalse);
            expect(
              serialized.toLowerCase().contains(keyHex.toLowerCase()),
              isFalse,
            );
            expect(serialized.contains(qrJson), isFalse);

            // Also scan any base64-decoded `sealed_payload` bytes to ensure the raw 32-byte key
            // does not appear as a contiguous byte subsequence inside the ciphertext.
            final sealedStr = entry.payload['sealed_payload'] as String?;
            if (sealedStr != null && sealedStr.isNotEmpty) {
              final rawSealed = base64Decode(sealedStr);
              expect(_containsSubsequence(rawSealed, homeKey), isFalse);
            }
          }
        });
      },
    );

    testWidgets(
      'PairingQrView surfaces PairingApprovalSheet when B requests to join and approves on Let them in',
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

          // B submits a join request with the code
          final sessionB =
              await clientB.homeController.submitPairingJoinRequest(code!);
          await tester.pumpAndSettle();

          // A's PairingQrView automatically transitions to PairingApprovalSheet
          expect(find.byType(PairingApprovalSheet), findsOneWidget);
          expect(find.text('Ancy wants to join The Nest.'), findsOneWidget);
          expect(
            find.text('Do these words match on their phone?'),
            findsOneWidget,
          );
          expect(
            find.text(sessionB.verificationWords.formatted),
            findsOneWidget,
          );
          expect(find.text('Let them in'), findsOneWidget);
          expect(find.text('Not them'), findsOneWidget);

          // A taps "Let them in"
          await tester.tap(find.text('Let them in'));
          await tester.pumpAndSettle();

          // B opens the sealed key and joins
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
