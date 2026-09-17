import 'dart:async';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_toggle_switch.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/notifications/notification_controller.dart';
import 'package:cove/features/notifications/notification_formatter.dart';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:cove/features/notifications/notification_service.dart';
import 'package:cove/features/profile/profile_screen.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSecureStorage extends FlutterSecureStorage {
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
  }) async {
    return _map[key];
  }
}

class FakeTrackingSyncEngine extends SyncEngineImpl {
  final List<String?> pulledHomeIds = [];

  FakeTrackingSyncEngine({
    required super.eventStore,
    required super.localStateStore,
    required super.encryptionService,
    required super.keyStore,
  });

  @override
  Future<void> pullLatestEvents({String? homeId}) async {
    pulledHomeIds.add(homeId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeTrackingSyncEngine syncEngine;
  late HomeKeyStore keyStore;
  late SodiumCryptoService cryptoService;
  late LocalStateStoreImpl localStateStore;
  late EventStoreImpl eventStore;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    keyStore = HomeKeyStore(storage: FakeSecureStorage());
    cryptoService = SodiumCryptoService();
    localStateStore = LocalStateStoreImpl(db);
    eventStore = EventStoreImpl(db: db, cryptoService: cryptoService);

    syncEngine = FakeTrackingSyncEngine(
      eventStore: eventStore,
      localStateStore: localStateStore,
      encryptionService: cryptoService,
      keyStore: keyStore,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Partner Notifications: Blind Derivation & Collapse Keys', () {
    test('Generic text derivation is strictly blind without payload dependency', () {
      // Lists
      expect(
        CoveNotificationPayload.genericMessageForEventType('list_item_added'),
        'New item added to shared lists',
      );
      expect(
        CoveNotificationPayload.genericMessageForEventType('list_item_toggled'),
        'A list item was updated',
      );

      // Expenses
      expect(
        CoveNotificationPayload.genericMessageForEventType('expense_logged'),
        'New expense logged',
      );

      // Subscriptions
      expect(
        CoveNotificationPayload.genericMessageForEventType('subscription_added'),
        'New subscription added',
      );

      // Habits
      expect(
        CoveNotificationPayload.genericMessageForEventType('habit_checkin_toggled'),
        'Partner checked in on a habit',
      );

      // Calendar
      expect(
        CoveNotificationPayload.genericMessageForEventType('calendar_event_added'),
        'New calendar event scheduled',
      );

      // Home
      expect(
        CoveNotificationPayload.genericMessageForEventType('member_joined'),
        'A partner joined your Home',
      );
    });

    test('Module resolution maps event_type to correct NotificationModule', () {
      expect(
        CoveNotificationPayload.moduleForEventType('list_item_added'),
        NotificationModule.lists,
      );
      expect(
        CoveNotificationPayload.moduleForEventType('expense_logged'),
        NotificationModule.expenses,
      );
      expect(
        CoveNotificationPayload.moduleForEventType('subscription_added'),
        NotificationModule.subscriptions,
      );
      expect(
        CoveNotificationPayload.moduleForEventType('habit_checkin_toggled'),
        NotificationModule.habits,
      );
      expect(
        CoveNotificationPayload.moduleForEventType('calendar_event_added'),
        NotificationModule.calendar,
      );
    });

    test('Anti-spam collapse key groups rapid updates per home and module', () {
      const payload1 = CoveNotificationPayload(
        homeId: 'home_nordic_42',
        module: NotificationModule.lists,
        eventType: 'list_item_added',
        eventId: 'e1',
        title: 'Shared Lists',
        body: 'New item added to shared lists',
      );

      const payload2 = CoveNotificationPayload(
        homeId: 'home_nordic_42',
        module: NotificationModule.lists,
        eventType: 'list_item_toggled',
        eventId: 'e2',
        title: 'Shared Lists',
        body: 'A list item was updated',
      );

      const payloadExpense = CoveNotificationPayload(
        homeId: 'home_nordic_42',
        module: NotificationModule.expenses,
        eventType: 'expense_logged',
        eventId: 'e3',
        title: 'Expenses',
        body: 'New expense logged',
      );

      // Same home + module share identical collapseKey
      expect(payload1.collapseKey, 'home_nordic_42_lists');
      expect(payload2.collapseKey, 'home_nordic_42_lists');
      expect(payload1.collapseKey, equals(payload2.collapseKey));

      // Different module in same home gets distinct collapseKey
      expect(payloadExpense.collapseKey, 'home_nordic_42_expenses');
      expect(payloadExpense.collapseKey, isNot(equals(payload1.collapseKey)));
    });
  });

  group('Enriched Push & In-App Notifications', () {
    test('Expense notifications format detailed amounts, titles, categories, and payment methods', () {
      final res = NotificationFormatter.format(
        eventType: 'expense_logged',
        payload: {
          'amount': 250.0,
          'currency': 'INR',
          'title': 'Coffee',
          'category': 'Food & Dining',
          'payment_method': 'upi',
        },
        actorName: 'Sophia',
      );

      expect(res.title, 'Sophia • Expenses');
      expect(res.body, "Logged ₹250 for 'Coffee' (Food & Dining • UPI)");
    });

    test('Shared list notifications format item name, list name, and completion status', () {
      final addRes = NotificationFormatter.format(
        eventType: 'list_item_added',
        payload: {
          'title': 'Oat Milk',
          'list_name': 'Groceries',
        },
        actorName: 'Sophia',
      );
      expect(addRes.title, 'Sophia • Groceries');
      expect(addRes.body, "Added 'Oat Milk' to Groceries");

      final checkRes = NotificationFormatter.format(
        eventType: 'list_item_toggled',
        payload: {
          'title': 'Oat Milk',
          'is_completed': true,
          'list_name': 'Groceries',
        },
        actorName: 'Sophia',
      );
      expect(checkRes.title, 'Sophia • Groceries');
      expect(checkRes.body, "Completed 'Oat Milk' in Groceries");
    });

    test('Habit check-in notifications include streak counters and cheering', () {
      final habitRes = NotificationFormatter.format(
        eventType: 'habit_checkin_toggled',
        payload: {
          'habit_name': 'Morning Run',
          'checked': true,
          'streak': 5,
        },
        actorName: 'Sophia',
      );
      expect(habitRes.title, 'Sophia • Habits');
      expect(habitRes.body, "Checked in on 'Morning Run' (5-day streak! 🔥)");

      final cheerRes = NotificationFormatter.format(
        eventType: 'habit_checkin_acknowledged',
        payload: {
          'habit_name': 'Morning Run',
        },
        actorName: 'Sophia',
      );
      expect(cheerRes.title, 'Sophia • Habits');
      expect(cheerRes.body, "Acknowledged your check-in on 'Morning Run'! 🙌");
    });

    test('Calendar notifications format event title and scheduled time', () {
      final calRes = NotificationFormatter.format(
        eventType: 'calendar_event_added',
        payload: {
          'title': 'Dinner with parents',
          'start_time': '2026-09-20T19:30:00.000Z',
        },
        actorName: 'Sophia',
      );
      expect(calRes.title, 'Sophia • Calendar');
      expect(calRes.body, contains("Scheduled 'Dinner with parents' for"));
    });

    test('Commitment notifications format subscription name, cost, and frequency', () {
      final subRes = NotificationFormatter.format(
        eventType: 'subscription_added',
        payload: {
          'name': 'Netflix',
          'amount': 649.0,
          'currency': 'INR',
          'billing_cycle': 'monthly',
        },
        actorName: 'Sophia',
      );
      expect(subRes.title, 'Sophia • Commitments');
      expect(subRes.body, "Added subscription 'Netflix' (₹649 / monthly)");
    });

    test('CoveNotificationPayload.fromDecrypted creates enriched instance', () {
      final payload = CoveNotificationPayload.fromDecrypted(
        homeId: 'home-1',
        actorId: 'user-2',
        eventType: 'list_item_added',
        eventId: 'e-100',
        payload: {
          'title': 'Avocados',
          'list_name': 'Groceries',
        },
        actorName: 'Alex',
      );

      expect(payload.title, 'Alex • Groceries');
      expect(payload.body, "Added 'Avocados' to Groceries");
      expect(payload.payload?['title'], 'Avocados');
      expect(payload.actorName, 'Alex');
    });
  });

  group('Drift Database Notification Preferences Storage', () {
    test('Default preferences have all modules unmuted', () async {
      final prefs = await db.getNotificationPreferences();
      expect(prefs, isNull);

      const defaultModel = NotificationPreferences();
      expect(defaultModel.muteSubscriptions, isFalse);
      expect(defaultModel.muteLists, isFalse);
      expect(defaultModel.muteExpenses, isFalse);
      expect(defaultModel.muteHabits, isFalse);
      expect(defaultModel.muteCalendar, isFalse);
    });

    test('Saving preferences persists and updates values correctly', () async {
      await db.saveNotificationPreferences(
        muteSubscriptions: false,
        muteLists: true,
        muteExpenses: false,
        muteHabits: true,
        muteCalendar: false,
      );

      final row = await db.getNotificationPreferences();
      expect(row, isNotNull);
      expect(row!.muteLists, isTrue);
      expect(row.muteHabits, isTrue);
      expect(row.muteSubscriptions, isFalse);
      expect(row.muteExpenses, isFalse);
      expect(row.muteCalendar, isFalse);

      final model = NotificationPreferences(
        muteSubscriptions: row.muteSubscriptions,
        muteLists: row.muteLists,
        muteExpenses: row.muteExpenses,
        muteHabits: row.muteHabits,
        muteCalendar: row.muteCalendar,
      );

      expect(model.isMuted(NotificationModule.lists), isTrue);
      expect(model.isMuted(NotificationModule.habits), isTrue);
      expect(model.isMuted(NotificationModule.expenses), isFalse);
      expect(model.isMuted(NotificationModule.subscriptions), isFalse);
      expect(model.isMuted(NotificationModule.calendar), isFalse);
    });
  });

  group('NotificationService: Silent Sync Wake & Local Preference Filtering', () {
    test('Incoming message for UNMUTED module triggers silent wake AND emits banner', () async {
      final service = NotificationService(
        syncEngine: syncEngine,
        appDatabase: db,
        getCurrentUserId: () => 'user_test',
      );

      // Mute nothing
      await service.savePreferences(const NotificationPreferences());

      final receivedEvents = <CoveNotificationPayload>[];
      final sub = service.onNotificationReceived.listen(receivedEvents.add);

      final result = await service.handleIncomingMessage({
        'home_id': 'home_alpha',
        'event_type': 'list_item_added',
        'event_id': 'evt_1',
      });

      await pumpEventQueue();

      expect(result, isNotNull);
      expect(result!.module, NotificationModule.lists);
      expect(result.body, "Added 'an item' to shared lists");

      // Sync engine was woken silently
      expect(syncEngine.pulledHomeIds, contains('home_alpha'));

      // Banner event was emitted
      expect(receivedEvents.length, 1);
      expect(receivedEvents.first.module, NotificationModule.lists);

      await sub.cancel();
      service.dispose();
    });

    test('Incoming message for MUTED module triggers silent wake BUT suppresses banner', () async {
      final service = NotificationService(
        syncEngine: syncEngine,
        appDatabase: db,
        getCurrentUserId: () => 'user_test',
      );

      // Mute Lists locally
      await service.savePreferences(const NotificationPreferences(muteLists: true));

      final receivedEvents = <CoveNotificationPayload>[];
      final sub = service.onNotificationReceived.listen(receivedEvents.add);

      final result = await service.handleIncomingMessage({
        'home_id': 'home_alpha',
        'event_type': 'list_item_added',
        'event_id': 'evt_2',
      });

      await pumpEventQueue();

      // Banner suppressed (returns null)
      expect(result, isNull);
      expect(receivedEvents, isEmpty);

      // Sync engine was STILL woken silently to project data in background!
      expect(syncEngine.pulledHomeIds, contains('home_alpha'));

      await sub.cancel();
      service.dispose();
    });

    test('Incoming message for member_profile_updated triggers silent wake BUT suppresses notification banner', () async {
      final service = NotificationService(
        syncEngine: syncEngine,
        appDatabase: db,
        getCurrentUserId: () => 'user_test',
      );

      await service.savePreferences(const NotificationPreferences());

      final receivedEvents = <CoveNotificationPayload>[];
      final sub = service.onNotificationReceived.listen(receivedEvents.add);

      final result = await service.handleIncomingMessage({
        'home_id': 'home_alpha',
        'event_type': 'member_profile_updated',
        'event_id': 'evt_profile_1',
      });

      await pumpEventQueue();

      // Profile updates are suppressed (returns null, no banner)
      expect(result, isNull);
      expect(receivedEvents, isEmpty);

      // Sync engine was still woken silently to pull & apply profile changes
      expect(syncEngine.pulledHomeIds, contains('home_alpha'));

      await sub.cancel();
      service.dispose();
    });

    test('Notification tap dispatches deep linking navigation module', () async {
      final service = NotificationService(
        syncEngine: syncEngine,
        appDatabase: db,
        getCurrentUserId: () => 'user_test',
      );

      final navigationEvents = <NotificationModule>[];
      final sub = service.onNavigateToModule.listen(navigationEvents.add);

      const payload = CoveNotificationPayload(
        homeId: 'home_alpha',
        module: NotificationModule.expenses,
        eventType: 'expense_logged',
        eventId: 'evt_3',
        title: 'Expenses',
        body: 'New expense logged',
      );

      service.onNotificationTapped(payload);
      await pumpEventQueue();

      expect(navigationEvents.length, 1);
      expect(navigationEvents.first, NotificationModule.expenses);

      await sub.cancel();
      service.dispose();
    });
  });

  group('ProfileScreen: Partner Notifications Preferences UI', () {
    Widget createTestWidget({
      required Widget child,
      ThemeMode themeMode = ThemeMode.dark,
    }) {
      final home = LocalHome(
        id: 'home_test',
        name: 'Our Home',
        currency: 'USD',
        createdAt: DateTime.now().toUtc(),
        createdBy: 'test_user_1',
      );

      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          syncEngineProvider.overrideWithValue(syncEngine),
          activeHomeIdProvider.overrideWith(
            () => _FakeActiveHomeNotifier('home_test'),
          ),
          userHomesProvider.overrideWith((ref) => Stream.value([home])),
          activeHomeProvider.overrideWith((ref) => Stream.value(home)),
          rawNotificationPreferencesProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
          partnerProfileProvider.overrideWith(
            () => _FakePartnerProfileNotifier(),
          ),
          authProvider.overrideWith(
            () => _FakeAuthNotifier(
              const CoveUser(
                id: 'test_user_1',
                email: 'partner@cove.local',
                displayName: 'Saba',
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: CoveTheme.lightTheme,
          darkTheme: CoveTheme.darkTheme,
          themeMode: themeMode,
          home: child,
        ),
      );
    }

    testWidgets('Renders PARTNER NOTIFICATIONS section with 5 module toggles in Dark Theme',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestWidget(
          child: const ProfileScreen(),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header & subtitle
      expect(find.text('PARTNER NOTIFICATIONS'), findsOneWidget);
      expect(find.text('Quietly grouped'), findsOneWidget);

      // 5 Modules
      expect(find.text('Shared Lists'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Commitments'), findsOneWidget);
      expect(find.text('Habits & Rhythms'), findsOneWidget);
      expect(find.text('Shared Calendar'), findsOneWidget);

      // Verify toggle switches exist
      expect(find.byType(CoveToggleSwitch), findsWidgets);
    });

    testWidgets('Renders PARTNER NOTIFICATIONS section correctly in Light Theme',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestWidget(
          child: const ProfileScreen(),
          themeMode: ThemeMode.light,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('PARTNER NOTIFICATIONS'), findsOneWidget);
      expect(find.text('Shared Lists'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
    });

    testWidgets('Toggling a notification switch updates local preferences',
        (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestWidget(
          child: const ProfileScreen(),
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final switches = find.byType(CoveToggleSwitch);
      expect(switches, findsNWidgets(5));

      await tester.tap(switches.at(0), warnIfMissed: false);
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      LocalNotificationPreference? prefs;
      await tester.runAsync(() async {
        prefs = await db.getNotificationPreferences();
      });
      expect(prefs, isNotNull);
      expect(prefs!.muteLists, isTrue);
    });
  });
}

class _FakeAuthNotifier extends AuthNotifier {
  final CoveUser? _initialUser;
  _FakeAuthNotifier([this._initialUser]);

  @override
  AsyncValue<CoveUser?> build() => AsyncValue.data(_initialUser);
}

class _FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  final String? initial;
  _FakeActiveHomeNotifier([this.initial]);

  @override
  String? build() => initial;

  @override
  void setActiveHome(String homeId) {
    state = homeId;
  }
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() {
    return const PartnerProfileState();
  }
}

