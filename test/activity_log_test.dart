import 'dart:convert';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_empty_state.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/features/activity/activity_formatter.dart';
import 'package:cove/features/activity/activity_models.dart';
import 'package:cove/features/activity/activity_read_status_controller.dart';
import 'package:cove/features/activity/activity_screen.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

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
  final List<Map<String, dynamic>> dispatchedEvents = [];

  FakeTrackingSyncEngine({
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
  }) async {
    dispatchedEvents.add({
      'eventType': eventType,
      'payload': payload,
      'homeId': homeId,
    });
    await localStateStore.applyEvent(
      homeId: homeId ?? 'home_1',
      eventType: eventType,
      payload: payload,
      timestamp: DateTime.now().toUtc(),
      authorId: 'user_alex',
    );
  }
}

class FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  final AsyncValue<CoveUser?> initial;

  FakeAuthNotifier(this.initial);

  @override
  AsyncValue<CoveUser?> build() => initial;

  @override
  Future<void> signInWithGoogle() async {}



  @override
  void signInWithDemoUser([String name = 'Alex', String email = 'alex@cove.local']) {}

  @override
  Future<void> signOut() async {}
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeTrackingSyncEngine fakeSyncEngine;
  late LocalStateStoreImpl localStateStore;
  late FakeSecureStorage secureStorage;
  late HomeKeyStore homeKeyStore;

  const homeId = 'home_1';
  const userIdAlex = 'user_alex';
  const userIdSarah = 'user_sarah';

  final alexUser = const CoveUser(
    id: userIdAlex,
    email: 'alex@example.com',
    displayName: 'Alex',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    localStateStore = LocalStateStoreImpl(db);
    final cryptoService = SodiumCryptoService();
    secureStorage = FakeSecureStorage();
    homeKeyStore = HomeKeyStore(storage: secureStorage);

    fakeSyncEngine = FakeTrackingSyncEngine(
      eventStore: EventStoreImpl(db: db, cryptoService: cryptoService),
      localStateStore: localStateStore,
      encryptionService: cryptoService,
      keyStore: homeKeyStore,
    );

    // Default active home
    await db.into(db.localHomes).insert(
          LocalHomesCompanion.insert(
            id: homeId,
            name: 'Our Home',
            createdAt: DateTime.now().toUtc(),
            createdBy: userIdAlex,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidgetUnderTest({
    required Widget child,
    ThemeMode themeMode = ThemeMode.dark,
    CoveUser? currentUser,
  }) {
    return ProviderScope(
      overrides: [
        syncEngineProvider.overrideWithValue(fakeSyncEngine),
        coveEmitActionProvider.overrideWithValue(
          ({required String eventType, required Map<String, dynamic> payload, String? targetHomeId}) async {
            await fakeSyncEngine.dispatchLocalEvent(
              eventType: eventType,
              payload: payload,
              homeId: targetHomeId ?? homeId,
            );
          },
        ),
        appDatabaseProvider.overrideWithValue(db),
        activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier(homeId)),
        authProvider.overrideWith(
          () => FakeAuthNotifier(AsyncValue.data(currentUser ?? alexUser)),
        ),
        unreadActivityCountProvider.overrideWithValue(0),
      ],
      child: MaterialApp(
        theme: CoveTheme.lightTheme,
        darkTheme: CoveTheme.darkTheme,
        themeMode: themeMode,
        home: child,
      ),
    );
  }

  group('Activity Log Feature Tests', () {
    testWidgets('1. Empty state renders correctly for a home with no activity',
        (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          child: const ActivityScreen(initialActivities: []),
        ),
      );
      await tester.pump();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.byType(CoveEmptyState), findsOneWidget);
      expect(find.text('No activity yet'), findsOneWidget);
      expect(
        find.text(
          'As you and your partner use Cove, your shared activity and updates will appear here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('2. Event translations format into human-readable plain language',
        (tester) async {
      final now = DateTime.now().toUtc();

      // Formatter unit checks
      final listAddEvent = LocalActivityEvent(
        id: 'act_1',
        homeId: homeId,
        actorId: userIdAlex,
        eventType: 'list_item_added',
        payloadJson: jsonEncode({'title': 'Oat milk', 'list_name': 'Groceries'}),
        createdAt: now.subtract(const Duration(minutes: 5)),
        syncStatus: 'syncedToPartner',
        isPrivate: false,
      );
      final formattedListAdd = ActivityFormatter.format(
        rawEvent: listAddEvent,
        currentUserId: userIdAlex,
      );
      expect(formattedListAdd.actorName, 'You');
      expect(formattedListAdd.actionText, "added 'Oat milk' to Groceries");
      expect(formattedListAdd.module, ActivityModule.lists);

      final partnerCheckEvent = LocalActivityEvent(
        id: 'act_2',
        homeId: homeId,
        actorId: userIdSarah,
        eventType: 'list_item_toggled',
        payloadJson: jsonEncode({'title': 'Bread', 'list_name': 'Groceries', 'is_completed': true}),
        createdAt: now.subtract(const Duration(minutes: 10)),
        syncStatus: 'syncedToPartner',
        isPrivate: false,
      );
      final formattedPartnerCheck = ActivityFormatter.format(
        rawEvent: partnerCheckEvent,
        currentUserId: userIdAlex,
        partnerName: 'Sarah',
      );
      expect(formattedPartnerCheck.actorName, 'Sarah');
      expect(formattedPartnerCheck.actionText, "checked off 'Bread' in Groceries");

      final expenseEvent = LocalActivityEvent(
        id: 'act_3',
        homeId: homeId,
        actorId: userIdAlex,
        eventType: 'expense_logged',
        payloadJson: jsonEncode({'amount': 42.50, 'category': 'Groceries'}),
        createdAt: now.subtract(const Duration(hours: 1)),
        syncStatus: 'syncedToPartner',
        isPrivate: false,
      );
      final formattedExpense = ActivityFormatter.format(
        rawEvent: expenseEvent,
        currentUserId: userIdAlex,
      );
      expect(formattedExpense.actionText, 'logged \$42.50 under Groceries');

      final subEvent = LocalActivityEvent(
        id: 'act_4',
        homeId: homeId,
        actorId: userIdAlex,
        eventType: 'subscription_added',
        payloadJson: jsonEncode({'name': 'Spotify', 'amount': 19.99, 'billing_cycle': 'monthly'}),
        createdAt: now.subtract(const Duration(days: 1)),
        syncStatus: 'syncedToPartner',
        isPrivate: false,
      );
      final formattedSub = ActivityFormatter.format(
        rawEvent: subEvent,
        currentUserId: userIdAlex,
      );
      expect(formattedSub.actionText, "added 'Spotify' commitment (\$19.99/monthly)");

      final habitEvent = LocalActivityEvent(
        id: 'act_5',
        homeId: homeId,
        actorId: userIdSarah,
        eventType: 'habit_checkin_toggled',
        payloadJson: jsonEncode({'habit_name': 'Morning Walk', 'checked': true}),
        createdAt: now.subtract(const Duration(hours: 2)),
        syncStatus: 'syncedToPartner',
        isPrivate: false,
      );
      final formattedHabit = ActivityFormatter.format(
        rawEvent: habitEvent,
        currentUserId: userIdAlex,
      );
      expect(formattedHabit.actionText, "checked in on 'Morning Walk'");

      final calEvent = LocalActivityEvent(
        id: 'act_6',
        homeId: homeId,
        actorId: userIdAlex,
        eventType: 'calendar_event_added',
        payloadJson: jsonEncode({'title': 'Friday Dinner Date'}),
        createdAt: now.subtract(const Duration(hours: 4)),
        syncStatus: 'syncedToPartner',
        isPrivate: false,
      );
      final formattedCal = ActivityFormatter.format(
        rawEvent: calEvent,
        currentUserId: userIdAlex,
      );
      expect(formattedCal.actionText, "scheduled 'Friday Dinner Date'");
    });

    testWidgets('3. Module filter pills filter feed entries correctly',
        (tester) async {
      final now = DateTime.now().toUtc();

      final sampleItems = [
        FormattedActivityItem(
          id: 'list_1',
          homeId: homeId,
          actorId: userIdAlex,
          actorName: 'You',
          actionText: "added 'Coffee Beans' to Groceries",
          eventType: 'list_item_added',
          module: ActivityModule.lists,
          icon: Icons.checklist_rounded,
          timestamp: now.subtract(const Duration(minutes: 5)),
          timeAgo: '5m ago',
          syncStatus: CoveSyncStatus.syncedToPartner,
          isPrivate: false,
          isLocalActor: true,
        ),
        FormattedActivityItem(
          id: 'exp_1',
          homeId: homeId,
          actorId: userIdAlex,
          actorName: 'You',
          actionText: 'logged \$35.00 under Dining Out',
          eventType: 'expense_logged',
          module: ActivityModule.expenses,
          icon: Icons.account_balance_wallet_outlined,
          timestamp: now.subtract(const Duration(minutes: 15)),
          timeAgo: '15m ago',
          syncStatus: CoveSyncStatus.syncedToPartner,
          isPrivate: false,
          isLocalActor: true,
        ),
        FormattedActivityItem(
          id: 'sub_1',
          homeId: homeId,
          actorId: userIdAlex,
          actorName: 'You',
          actionText: "added 'Netflix' subscription (\$15.99/monthly)",
          eventType: 'subscription_added',
          module: ActivityModule.subscriptions,
          icon: Icons.autorenew_rounded,
          timestamp: now.subtract(const Duration(hours: 1)),
          timeAgo: '1h ago',
          syncStatus: CoveSyncStatus.syncedToPartner,
          isPrivate: false,
          isLocalActor: true,
        ),
      ];

      await tester.pumpWidget(
        createWidgetUnderTest(
          child: ActivityScreen(initialActivities: sampleItems),
        ),
      );
      await tester.pump();

      // Initially All is selected: all 3 items present
      expect(find.textContaining("Coffee Beans"), findsOneWidget);
      expect(find.textContaining("logged \$35.00"), findsOneWidget);
      expect(find.textContaining("Netflix"), findsOneWidget);

      // Tap 'Expenses' filter pill
      await tester.tap(find.text('Expenses'));
      await tester.pump();

      // Only expense visible
      expect(find.textContaining("logged \$35.00"), findsOneWidget);
      expect(find.textContaining("Coffee Beans"), findsNothing);
      expect(find.textContaining("Netflix"), findsNothing);

      // Tap 'Commitments' filter pill
      await tester.tap(find.text('Commitments'));
      await tester.pump();

      expect(find.textContaining("Netflix"), findsOneWidget);
      expect(find.textContaining("logged \$35.00"), findsNothing);

      // Tap 'Calendar' filter pill (empty)
      await tester.tap(find.text('Calendar'));
      await tester.pump();

      expect(find.text('No activity found in Calendar.'), findsOneWidget);
    });

    testWidgets('4. Structural privacy: Private-to-me items only appear for owner',
        (tester) async {
      final now = DateTime.now().toUtc();

      // 1. Alex logs a shared expense and a private expense
      await db.recordActivityEvent(
        LocalActivityEventsCompanion.insert(
          id: 'shared_exp',
          homeId: homeId,
          actorId: userIdAlex,
          eventType: 'expense_logged',
          payloadJson: jsonEncode({'amount': 60.00, 'category': 'Groceries'}),
          createdAt: now.subtract(const Duration(minutes: 10)),
          syncStatus: const drift.Value('syncedToPartner'),
          isPrivate: const drift.Value(false),
        ),
      );

      await db.recordActivityEvent(
        LocalActivityEventsCompanion.insert(
          id: 'private_exp',
          homeId: homeId,
          actorId: userIdAlex,
          eventType: 'expense_logged',
          payloadJson: jsonEncode({'amount': 15.00, 'title': 'Secret Gift'}),
          createdAt: now.subtract(const Duration(minutes: 5)),
          syncStatus: const drift.Value('savedLocally'),
          isPrivate: const drift.Value(true),
        ),
      );

      // Verify at database query level
      final alexDbEvents = await db.getActivityEvents(homeId, currentUserId: userIdAlex);
      expect(alexDbEvents.any((e) => e.id == 'private_exp'), isTrue,
          reason: 'Owner must receive their own private event from DB');

      final sarahDbEvents = await db.getActivityEvents(homeId, currentUserId: userIdSarah);
      expect(sarahDbEvents.any((e) => e.id == 'private_exp'), isFalse,
          reason: 'Partner DB query must strictly exclude private events owned by Alex');

      // Verify at UI level for owner
      final alexUiItems = alexDbEvents.map((r) => ActivityFormatter.format(rawEvent: r, currentUserId: userIdAlex)).toList();
      await tester.pumpWidget(
        createWidgetUnderTest(
          currentUser: alexUser,
          child: ActivityScreen(initialActivities: alexUiItems),
        ),
      );
      await tester.pump();

      expect(find.textContaining('logged \$60.00'), findsOneWidget);
      expect(find.textContaining('Secret Gift'), findsOneWidget);
      expect(find.text('Private to you'), findsOneWidget);

      // Verify at UI level for partner (Sarah)
      final sarahUiItems = sarahDbEvents.map((r) => ActivityFormatter.format(rawEvent: r, currentUserId: userIdSarah, partnerName: 'Alex')).toList();
      await tester.pumpWidget(
        createWidgetUnderTest(
          currentUser: const CoveUser(id: userIdSarah, email: 'sarah@example.com', displayName: 'Sarah'),
          child: ActivityScreen(initialActivities: sarahUiItems),
        ),
      );
      await tester.pump();

      expect(find.textContaining('logged \$60.00'), findsOneWidget);
      expect(find.textContaining('Secret Gift'), findsNothing);
      expect(find.text('Private to you'), findsNothing);
    });

    testWidgets('5. Local events show CoveSyncTick indicator while partner events do not',
        (tester) async {
      final now = DateTime.now().toUtc();

      final alexAct = FormattedActivityItem(
        id: 'alex_act',
        homeId: homeId,
        actorId: userIdAlex,
        actorName: 'You',
        actionText: "scheduled 'Dentist Appointment'",
        eventType: 'calendar_event_added',
        module: ActivityModule.calendar,
        icon: Icons.calendar_today_rounded,
        timestamp: now.subtract(const Duration(minutes: 20)),
        timeAgo: '20m ago',
        syncStatus: CoveSyncStatus.syncedToPartner,
        isPrivate: false,
        isLocalActor: true,
      );

      final sarahAct = FormattedActivityItem(
        id: 'sarah_act',
        homeId: homeId,
        actorId: userIdSarah,
        actorName: 'Sarah',
        actionText: "added 'Apples' to Groceries",
        eventType: 'list_item_added',
        module: ActivityModule.lists,
        icon: Icons.checklist_rounded,
        timestamp: now.subtract(const Duration(minutes: 10)),
        timeAgo: '10m ago',
        syncStatus: CoveSyncStatus.syncedToPartner,
        isPrivate: false,
        isLocalActor: false,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          currentUser: alexUser,
          child: ActivityScreen(initialActivities: [alexAct, sarahAct]),
        ),
      );
      await tester.pump();

      // Exactly one sync tick rendered for Alex's local event
      expect(find.byType(CoveSyncTick), findsOneWidget);
    });

    testWidgets('6. Dual-theme verification: renders correctly in light and dark themes',
        (tester) async {
      final sample = FormattedActivityItem(
        id: 'act_theme',
        homeId: homeId,
        actorId: userIdAlex,
        actorName: 'You',
        actionText: "added 'Champagne' to Groceries",
        eventType: 'list_item_added',
        module: ActivityModule.lists,
        icon: Icons.checklist_rounded,
        timestamp: DateTime.now(),
        timeAgo: 'Just now',
        syncStatus: CoveSyncStatus.syncedToPartner,
        isPrivate: false,
        isLocalActor: true,
      );

      // Dark Theme
      await tester.pumpWidget(
        createWidgetUnderTest(
          themeMode: ThemeMode.dark,
          child: ActivityScreen(initialActivities: [sample]),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Champagne'), findsOneWidget);

      // Light Theme
      await tester.pumpWidget(
        createWidgetUnderTest(
          themeMode: ThemeMode.light,
          child: ActivityScreen(initialActivities: [sample]),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Champagne'), findsOneWidget);
    });

    testWidgets('7. Tapping activity item opens detail bottomsheet',
        (tester) async {
      final sample = FormattedActivityItem(
        id: 'act_tap_test',
        homeId: homeId,
        actorId: userIdAlex,
        actorName: 'You',
        actionText: "logged ₹4,500.00 for 'Groceries' (Food)",
        eventType: 'expense_logged',
        module: ActivityModule.expenses,
        icon: Icons.receipt_long_rounded,
        timestamp: DateTime.now(),
        timeAgo: 'Just now',
        syncStatus: CoveSyncStatus.syncedToPartner,
        isPrivate: false,
        isLocalActor: true,
        entityId: 'expense_123',
        targetTitle: 'Groceries',
        rawPayload: {
          'title': 'Groceries',
          'amount': 4500.0,
          'currency': 'INR',
          'category': 'Food',
        },
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          themeMode: ThemeMode.dark,
          child: ActivityScreen(initialActivities: [sample]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining("logged ₹4,500.00 for 'Groceries' (Food)"), findsOneWidget);

      // Tap the activity item
      await tester.tap(find.textContaining("logged ₹4,500.00 for 'Groceries' (Food)"));
      await tester.pumpAndSettle();

      // Bottomsheet opens
      expect(find.byType(BottomSheet), findsOneWidget);

      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    test('member_profile_updated is not recorded in activity log and clearProfileActivityEvents purges existing', () async {
      // 1. Manually insert a legacy member_profile_updated event
      await db.into(db.localActivityEvents).insert(
        LocalActivityEventsCompanion.insert(
          id: 'legacy_profile_1',
          homeId: 'home_1',
          actorId: 'user_alex',
          eventType: 'member_profile_updated',
          payloadJson: jsonEncode({'display_name': 'Alex Custom'}),
          createdAt: DateTime.now(),
        ),
      );

      // Verify it is in raw table
      var allRows = await db.select(db.localActivityEvents).get();
      expect(allRows.any((r) => r.eventType == 'member_profile_updated'), isTrue);

      // Verify watchActivityEvents and getActivityEvents query filters it out
      var queryRows = await db.getActivityEvents('home_1');
      expect(queryRows.any((r) => r.eventType == 'member_profile_updated'), isFalse);

      // 2. Call clearProfileActivityEvents()
      final clearedCount = await db.clearProfileActivityEvents();
      expect(clearedCount, equals(1));

      // Verify it was purged from the raw table
      allRows = await db.select(db.localActivityEvents).get();
      expect(allRows.any((r) => r.eventType == 'member_profile_updated'), isFalse);

      // 3. Applying new member_profile_updated event does NOT record in localActivityEvents
      await localStateStore.applyEvent(
        homeId: 'home_1',
        eventType: 'member_profile_updated',
        payload: {
          'user_id': 'user_partner',
          'display_name': 'Partner Name',
          'avatar_url': null,
        },
        timestamp: DateTime.now(),
        authorId: 'user_partner',
      );

      allRows = await db.select(db.localActivityEvents).get();
      expect(allRows.any((r) => r.eventType == 'member_profile_updated'), isFalse);
    });

    testWidgets('ActivityScreen renders CoveActorAvatar for local actor and partner actor', (tester) async {
      final alexAct = FormattedActivityItem(
        id: 'act_alex',
        homeId: 'home_1',
        actorId: 'user_alex',
        actorName: 'You',
        actionText: 'added an item',
        eventType: 'list_item_added',
        module: ActivityModule.lists,
        icon: Icons.add_circle_outline,
        timestamp: DateTime.now(),
        timeAgo: 'Just now',
        syncStatus: CoveSyncStatus.syncedToPartner,
        isPrivate: false,
        isLocalActor: true,
      );

      final sarahAct = FormattedActivityItem(
        id: 'act_sarah',
        homeId: 'home_1',
        actorId: 'user_sarah',
        actorName: 'Sarah',
        actionText: 'logged an expense',
        eventType: 'expense_logged',
        module: ActivityModule.expenses,
        icon: Icons.receipt_long_rounded,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        timeAgo: '5m ago',
        syncStatus: CoveSyncStatus.syncedToPartner,
        isPrivate: false,
        isLocalActor: false,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          child: ActivityScreen(initialActivities: [alexAct, sarahAct]),
        ),
      );
      await tester.pumpAndSettle();

      // Both activities are displayed
      expect(find.textContaining('added an item'), findsOneWidget);
      expect(find.textContaining('logged an expense'), findsOneWidget);

      // Verify CoveActorAvatar displays the initials for Sarah ('S')
      expect(find.text('S'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}

