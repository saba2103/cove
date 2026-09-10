import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/features/app_shell.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/auth/auth_gate.dart';
import 'package:cove/features/auth/sign_in_screen.dart';
import 'package:cove/features/home/create_home_screen.dart';
import 'package:cove/features/home/home_settings_screen.dart';
import 'package:cove/features/home/home_switcher_sheet.dart';
import 'package:cove/features/home/join_home_screen.dart';
import 'package:cove/features/home/onboarding_choice_screen.dart';
import 'package:cove/sync/crypto/deterministic_home_icon.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/key_management/pairing_payload.dart';
import 'package:cove/sync/key_management/pairing_qr_view.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _map = {};

  FakeSecureStorage() : super();

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _map[key] = value;
    } else {
      _map.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _map[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _map.remove(key);
  }

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _map.clear();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeSecureStorage fakeStorage;
  late HomeKeyStore keyStore;
  late SodiumCryptoService crypto;
  late FakeSyncEngineImpl fakeEngine;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fakeStorage = FakeSecureStorage();
    keyStore = HomeKeyStore(storage: fakeStorage);
    crypto = SodiumCryptoService();
    final localStore = LocalStateStoreImpl(db);
    final eventStore = EventStoreImpl(db: db, cryptoService: crypto);
    fakeEngine = FakeSyncEngineImpl(
      eventStore: eventStore,
      localStateStore: localStore,
      encryptionService: crypto,
      keyStore: keyStore,
    );
  });

  tearDown(() async {
    await db.close();
  });

  List<Override> createOverrides({
    CoveUser? user,
    List<LocalHome>? homes,
    String? activeHomeId,
  }) {
    return [
      appDatabaseProvider.overrideWithValue(db),
      homeKeyStoreProvider.overrideWithValue(keyStore),
      sodiumCryptoServiceProvider.overrideWithValue(crypto),
      syncEngineProvider.overrideWithValue(fakeEngine),
      if (user != null)
        authProvider.overrideWith(() => FakeAuthNotifier(AsyncData(user)))
      else
        authProvider.overrideWith(() => FakeAuthNotifier(const AsyncData(null))),
      if (homes != null) ...[
        userHomesProvider.overrideWith((ref) => Stream.value(homes)),
        activeHomeProvider.overrideWith((ref) {
          final activeId = ref.watch(activeHomeIdProvider);
          if (activeId == null) return Stream.value(homes.firstOrNull);
          return Stream.value(homes.firstWhere(
            (h) => h.id == activeId,
            orElse: () => homes.first,
          ));
        }),
      ],
      if (activeHomeId != null)
        activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier(activeHomeId)),
    ];
  }

  group('Sign In Screen Tests', () {
    testWidgets('Renders wordmark, brand mark motif, button and encryption reassurance',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SignInScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Brand wordmark and motif
      expect(find.text('Cove'), findsOneWidget);
      expect(find.text('A private, shared home operating system.'), findsOneWidget);

      // Single action button
      expect(find.text('Sign in with Google'), findsOneWidget);

      // Footnote privacy reassurance
      expect(
        find.text('End-to-end encrypted on-device. Zero cloud knowledge.'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping Sign In triggers authentication', (tester) async {
      final authNotifier = FakeAuthNotifier(const AsyncData(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            homeKeyStoreProvider.overrideWithValue(keyStore),
            sodiumCryptoServiceProvider.overrideWithValue(crypto),
            authProvider.overrideWith(() => authNotifier),
          ],
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SignInScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      // Verified sign in method was called
      expect(authNotifier.signInCalled, isTrue);
    });
  });

  group('AuthGate State Transitions', () {
    testWidgets('Shows SignInScreen when user is unauthenticated', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(user: null),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const AuthGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsOneWidget);
      expect(find.byType(OnboardingChoiceScreen), findsNothing);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('Shows OnboardingChoiceScreen when authenticated but in 0 homes',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(
            user: const CoveUser(id: 'user_1', email: 'user@cove.test', displayName: 'Alex'),
            homes: [],
          ),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const AuthGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(OnboardingChoiceScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
    });

    testWidgets('Shows AppShell when authenticated with active home', (tester) async {
      final home = LocalHome(
        id: 'home_1',
        name: 'Our Cozy Cove',
        createdAt: DateTime.now(),
        createdBy: 'user_1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(
            user: const CoveUser(id: 'user_1', email: 'user@cove.test', displayName: 'Alex'),
            homes: [home],
            activeHomeId: 'home_1',
          ),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const AuthGate(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(OnboardingChoiceScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
    });
  });

  group('Onboarding Flow Tests', () {
    testWidgets('OnboardingChoiceScreen presents Create and Join options', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(
            user: const CoveUser(id: 'user_1', email: 'user@cove.test'),
          ),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const OnboardingChoiceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Welcome'), findsOneWidget);
      expect(find.text('Create a Home'), findsNWidgets(2));
      expect(find.text('Join a Home'), findsOneWidget);
      expect(find.text('Scan QR Code to Join'), findsOneWidget);
    });

    testWidgets('CreateHomeScreen defaults to "Our Home" and creates home with PairingQrView',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(
            user: const CoveUser(id: 'user_alex', email: 'alex@cove.test', displayName: 'Alex'),
          ),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const CreateHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check default home name (both preview title and text input field)
      expect(find.text('Our Home'), findsNWidgets(2));
      expect(find.byType(DeterministicHomeIcon), findsOneWidget);

      // Scroll and tap create button
      final createButton = find.text('Create Home & Generate Key');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Verified QR code presentation appears
      expect(find.byType(PairingQrView), findsOneWidget);
      expect(find.text('Pair with Partner'), findsOneWidget);

      // Verify that the home was stored in local SQLite database
      final homes = await (db.select(db.localHomes).get());
      expect(homes.length, equals(1));
      expect(homes.first.name, equals('Our Home'));

      // Verify symmetric key was saved in secure storage
      final storedKey = await keyStore.getKey(homes.first.id);
      expect(storedKey, isNotNull);
      expect(storedKey!.length, equals(32));
    });

    testWidgets('JoinHomeScreen manual entry parses QR payload and joins home',
        (tester) async {
      final key = crypto.generateHomeKey();
      final payload = PairingPayload(
        homeId: 'home_partner_456',
        homeName: 'The Sunny Nest',
        symmetricKey: key,
        inviterId: 'partner_sam',
        createdAt: DateTime.now().toUtc(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(
            user: const CoveUser(id: 'user_alex', email: 'alex@cove.test', displayName: 'Alex'),
          ),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const JoinHomeScreen(initialShowManualInput: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter the serialized QR payload JSON
      final inputField = find.byType(TextField);
      await tester.enterText(inputField, payload.toQrString());
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Scroll and tap Join button
      final joinButton = find.widgetWithText(CovePillButton, 'Join with Code');
      await tester.ensureVisible(joinButton);
      await tester.tap(joinButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify home was added to Drift database
      final homes = await (db.select(db.localHomes).get());
      expect(homes.length, equals(1));
      expect(homes.first.id, equals('home_partner_456'));
      expect(homes.first.name, equals('The Sunny Nest'));

      // Verify encryption key was safely imported
      final importedKey = await keyStore.getKey('home_partner_456');
      expect(importedKey, equals(key));
    });
  });

  group('Conditional Home Switcher Tests', () {
    testWidgets('When user has ONLY 1 home: Switcher affordance is strictly hidden',
        (tester) async {
      final singleHome = LocalHome(
        id: 'home_single',
        name: 'Our Sanctuary',
        createdAt: DateTime.now(),
        createdBy: 'user_1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(
            user: const CoveUser(id: 'user_1', email: 'alex@cove.test'),
            homes: [singleHome],
            activeHomeId: 'home_single',
          ),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: Scaffold(
              appBar: AppBar(
                title: const HomeSwitcherAppBarTitle(),
              ),
              body: const Center(child: Text('Content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title is rendered
      expect(find.text('Our Sanctuary'), findsOneWidget);

      // NO dropdown chevron arrow must be rendered
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);

      // Tapping title should NOT open bottom sheet
      await tester.tap(find.text('Our Sanctuary'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeSwitcherSheet), findsNothing);
    });

    testWidgets('When user has MORE than 1 home: Switcher affordance appears and switches active home',
        (tester) async {
      final home1 = LocalHome(
        id: 'home_primary',
        name: 'Primary Haven',
        createdAt: DateTime.now(),
        createdBy: 'user_1',
      );
      final home2 = LocalHome(
        id: 'home_cabin',
        name: 'Mountain Cabin',
        createdAt: DateTime.now(),
        createdBy: 'user_1',
      );

      final activeNotifier = FakeActiveHomeNotifier('home_primary');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            homeKeyStoreProvider.overrideWithValue(keyStore),
            sodiumCryptoServiceProvider.overrideWithValue(crypto),
            authProvider.overrideWith(() => FakeAuthNotifier(
                const AsyncData(CoveUser(id: 'user_1', email: 'alex@cove.test')))),
            userHomesProvider.overrideWith((ref) => Stream.value([home1, home2])),
            activeHomeProvider.overrideWith((ref) => Stream.value(home1)),
            activeHomeIdProvider.overrideWith(() => activeNotifier),
          ],
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: Scaffold(
              appBar: AppBar(
                title: const HomeSwitcherAppBarTitle(),
              ),
              body: const Center(child: Text('Content')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified dropdown chevron is visible when multiple homes exist
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      // Tapping title opens bottom sheet
      await tester.tap(find.text('Primary Haven'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeSwitcherSheet), findsOneWidget);
      expect(find.text('Mountain Cabin'), findsOneWidget);

      // Select second home
      await tester.tap(find.text('Mountain Cabin'));
      await tester.pumpAndSettle();

      // Verified active home was switched
      expect(activeNotifier.state, equals('home_cabin'));
    });
  });

  group('Home Settings Stub Tests', () {
    testWidgets('Renders home name, member list, and actions', (tester) async {
      final home = LocalHome(
        id: 'home_123',
        name: 'Sweet Home',
        createdAt: DateTime.now(),
        createdBy: 'user_alex',
      );

      // Seed local home
      await db.into(db.localHomes).insert(
            LocalHomesCompanion.insert(
              id: 'home_123',
              name: 'Sweet Home',
              createdAt: DateTime.now(),
              createdBy: 'user_alex',
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(
            user: const CoveUser(id: 'user_alex', email: 'alex@cove.test', displayName: 'Alex'),
            homes: [home],
            activeHomeId: 'home_123',
          ),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const HomeSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Settings'), findsOneWidget);
      expect(find.text('MEMBERS'), findsOneWidget);
      expect(find.text('View / Regenerate Invite QR'), findsOneWidget);
      expect(find.text('Leave Home'), findsOneWidget);
    });
  });
}

class FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  final AsyncValue<CoveUser?> initial;
  bool signInCalled = false;

  FakeAuthNotifier(this.initial);

  @override
  AsyncValue<CoveUser?> build() => initial;

  @override
  Future<void> signInWithGoogle() async {
    signInCalled = true;
    state = AsyncData(CoveUser.demo());
  }

  @override
  void signInWithDemoUser([String name = 'Alex', String email = 'alex@cove.local']) {
    signInCalled = true;
    state = AsyncData(CoveUser(
      id: 'demo-user-${name.toLowerCase()}',
      email: email,
      displayName: name,
    ));
  }

  @override
  Future<void> signOut() async {
    state = const AsyncData(null);
  }
}

class FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  final String? initial;

  FakeActiveHomeNotifier(this.initial);

  @override
  String? build() => initial;

  @override
  void setActiveHome(String homeId) {
    state = homeId;
  }
}

class FakeSyncEngineImpl extends SyncEngineImpl {
  FakeSyncEngineImpl({
    required super.eventStore,
    required super.localStateStore,
    required super.encryptionService,
    required super.keyStore,
  });

  @override
  Future<void> start({String? activeHomeId, List<int>? activeHomeKey}) async {
    // No-op in test: avoid starting background periodic flush timer
  }

  @override
  Future<void> flushOutbox() async {}
}
