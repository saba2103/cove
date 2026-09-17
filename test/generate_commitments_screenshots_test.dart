import 'dart:io';
import 'dart:ui' as ui;
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/theme/theme_provider.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/subscriptions/subscriptions_screen.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _map = {};

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
  }) async => _map[key];
}

class _TestSyncEngine extends SyncEngineImpl {
  _TestSyncEngine({
    required super.eventStore,
    required super.localStateStore,
    required super.encryptionService,
    required super.keyStore,
  });

  @override
  Future<void> start({String? activeHomeId, List<int>? activeHomeKey}) async {}

  @override
  Future<void> flushOutbox() async {}

  @override
  Future<void> dispatchLocalEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    String? homeId,
  }) async {}
}

class _StaticThemeNotifier extends ThemeModeNotifier {
  final ThemeMode _mode;
  _StaticThemeNotifier(this._mode);
  @override
  ThemeMode build() => _mode;
}

class _StaticCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() => supportedCurrencies.firstWhere((c) => c.code == 'INR');
}

class _FakeActiveHomePartnerNotifier extends ActiveHomePartnerNotifier {
  @override
  bool build() => true;
}

class _FakeActiveHomeNotifier extends Notifier<String?> implements ActiveHomeNotifier {
  @override
  String? build() => 'home_1';
  @override
  void setActiveHome(String homeId) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;

    Future<void> loadFontFromFile(String family, String path) async {
      final file = File(path);
      if (file.existsSync()) {
        final loader = FontLoader(family);
        final bytes = file.readAsBytesSync();
        loader.addFont(Future.value(ByteData.sublistView(bytes)));
        await loader.load();
      }
    }

    await loadFontFromFile('GeneralSans', 'assets/fonts/GeneralSans-Regular.ttf');
    await loadFontFromFile('GeneralSans', 'assets/fonts/GeneralSans-Medium.ttf');
    await loadFontFromFile('GeneralSans', 'assets/fonts/GeneralSans-Semibold.ttf');
    await loadFontFromFile('GeneralSans', 'assets/fonts/GeneralSans-Bold.ttf');
    await loadFontFromFile('BodoniModa', 'assets/fonts/BodoniModa-Medium.ttf');
  });

  testWidgets('Capture Commitments Screen in Dark Theme',
      skip: true,
      (WidgetTester tester) async {
    // Phone viewport: 412 x 892 pt
    tester.view.physicalSize = const Size(412 * 2.5, 892 * 2.5);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();

    final testSubs = [
      LocalSubscription(
        id: 'sub_netflix',
        homeId: 'home_1',
        name: 'Netflix Premium',
        amount: 649.0,
        currency: 'INR',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 4)),
        category: 'streaming',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_alex',
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      LocalSubscription(
        id: 'emi_car',
        homeId: 'home_1',
        name: 'Car Loan (HDFC)',
        amount: 15400.0,
        currency: 'INR',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 6)),
        endDate: now.add(const Duration(days: 840)), // ~28 months left of 36
        category: 'finance',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_alex',
        createdAt: now.subtract(const Duration(days: 240)), // ~8 months elapsed
      ),
      LocalSubscription(
        id: 'emi_macbook',
        homeId: 'home_1',
        name: 'MacBook Pro M3 EMI',
        amount: 8200.0,
        currency: 'INR',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 14)),
        endDate: now.add(const Duration(days: 240)), // 8 months left of 12
        category: 'hardware',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_sarah',
        createdAt: now.subtract(const Duration(days: 120)), // 4 months elapsed
      ),
      LocalSubscription(
        id: 'sub_spotify',
        homeId: 'home_1',
        name: 'Spotify Duo',
        amount: 179.0,
        currency: 'INR',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 21)),
        category: 'streaming',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_sarah',
        createdAt: now.subtract(const Duration(days: 90)),
      ),
    ];

    final db = AppDatabase(NativeDatabase.memory());
    final fakeStorage = _FakeSecureStorage();
    final keyStore = HomeKeyStore(storage: fakeStorage);
    final crypto = SodiumCryptoService();
    final localStore = LocalStateStoreImpl(db);
    final eventStore = EventStoreImpl(db: db, cryptoService: crypto);
    final fakeEngine = _TestSyncEngine(
      eventStore: eventStore,
      localStateStore: localStore,
      encryptionService: crypto,
      keyStore: keyStore,
    );

    const artifactDir = '/Users/saba/.gemini/antigravity/brain/0ec1480b-ee13-4012-8b4f-09d7fa81bb3d';

    // 1. Dark Theme
    final darkKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith(() => _StaticThemeNotifier(ThemeMode.dark)),
          currencyPreferenceProvider.overrideWith(() => _StaticCurrencyNotifier()),
          appDatabaseProvider.overrideWithValue(db),
          homeKeyStoreProvider.overrideWithValue(keyStore),
          sodiumCryptoServiceProvider.overrideWithValue(crypto),
          syncEngineProvider.overrideWithValue(fakeEngine),
          activeHomeIdProvider.overrideWith(() => _FakeActiveHomeNotifier()),
          activeHomeOutboxProvider.overrideWith((ref) => Stream.value([])),
          activeHomeHasPartnerProvider.overrideWith(() => _FakeActiveHomePartnerNotifier()),
        ],
        child: RepaintBoundary(
          key: darkKey,
          child: MaterialApp(
            theme: CoveTheme.lightTheme,
            darkTheme: CoveTheme.darkTheme,
            themeMode: ThemeMode.dark,
            debugShowCheckedModeBanner: false,
            home: SubscriptionsScreen(initialSubscriptions: testSubs),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final darkBoundary = darkKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image darkImage = await darkBoundary.toImage(pixelRatio: 2.5);
    final darkByteData = await darkImage.toByteData(format: ui.ImageByteFormat.png);
    File('$artifactDir/commitments_dark.png').writeAsBytesSync(darkByteData!.buffer.asUint8List());

    await db.close();
  });

  testWidgets('Capture Commitments Screen in Light Theme',
      skip: true,
      (WidgetTester tester) async {
    // Phone viewport: 412 x 892 pt
    tester.view.physicalSize = const Size(412 * 2.5, 892 * 2.5);
    tester.view.devicePixelRatio = 2.5;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();

    final testSubs = [
      LocalSubscription(
        id: 'sub_netflix',
        homeId: 'home_1',
        name: 'Netflix Premium',
        amount: 649.0,
        currency: 'INR',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 4)),
        category: 'streaming',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_alex',
        createdAt: now.subtract(const Duration(days: 60)),
      ),
      LocalSubscription(
        id: 'emi_car',
        homeId: 'home_1',
        name: 'Car Loan (HDFC)',
        amount: 15400.0,
        currency: 'INR',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 6)),
        endDate: now.add(const Duration(days: 840)),
        category: 'finance',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_alex',
        createdAt: now.subtract(const Duration(days: 240)),
      ),
      LocalSubscription(
        id: 'emi_macbook',
        homeId: 'home_1',
        name: 'MacBook Pro M3 EMI',
        amount: 8200.0,
        currency: 'INR',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 14)),
        endDate: now.add(const Duration(days: 240)),
        category: 'hardware',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_sarah',
        createdAt: now.subtract(const Duration(days: 120)),
      ),
      LocalSubscription(
        id: 'sub_spotify',
        homeId: 'home_1',
        name: 'Spotify Duo',
        amount: 179.0,
        currency: 'INR',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 21)),
        category: 'streaming',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_sarah',
        createdAt: now.subtract(const Duration(days: 90)),
      ),
    ];

    final db = AppDatabase(NativeDatabase.memory());
    final fakeStorage = _FakeSecureStorage();
    final keyStore = HomeKeyStore(storage: fakeStorage);
    final crypto = SodiumCryptoService();
    final localStore = LocalStateStoreImpl(db);
    final eventStore = EventStoreImpl(db: db, cryptoService: crypto);
    final fakeEngine = _TestSyncEngine(
      eventStore: eventStore,
      localStateStore: localStore,
      encryptionService: crypto,
      keyStore: keyStore,
    );

    const artifactDir = '/Users/saba/.gemini/antigravity/brain/0ec1480b-ee13-4012-8b4f-09d7fa81bb3d';

    // 2. Light Theme
    final lightKey = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeModeProvider.overrideWith(() => _StaticThemeNotifier(ThemeMode.light)),
          currencyPreferenceProvider.overrideWith(() => _StaticCurrencyNotifier()),
          appDatabaseProvider.overrideWithValue(db),
          homeKeyStoreProvider.overrideWithValue(keyStore),
          sodiumCryptoServiceProvider.overrideWithValue(crypto),
          syncEngineProvider.overrideWithValue(fakeEngine),
          activeHomeIdProvider.overrideWith(() => _FakeActiveHomeNotifier()),
          activeHomeOutboxProvider.overrideWith((ref) => Stream.value([])),
          activeHomeHasPartnerProvider.overrideWith(() => _FakeActiveHomePartnerNotifier()),
        ],
        child: RepaintBoundary(
          key: lightKey,
          child: MaterialApp(
            theme: CoveTheme.lightTheme,
            darkTheme: CoveTheme.darkTheme,
            themeMode: ThemeMode.light,
            debugShowCheckedModeBanner: false,
            home: SubscriptionsScreen(initialSubscriptions: testSubs),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final lightBoundary = lightKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image lightImage = await lightBoundary.toImage(pixelRatio: 2.5);
    final lightByteData = await lightImage.toByteData(format: ui.ImageByteFormat.png);
    File('$artifactDir/commitments_light.png').writeAsBytesSync(lightByteData!.buffer.asUint8List());

    await db.close();
  });
}
