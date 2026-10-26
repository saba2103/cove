import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_floating_bar.dart';
import 'package:cove/core/widgets/cove_pill_input.dart';
import 'package:cove/features/activity/activity_controller.dart';
import 'package:cove/features/activity/activity_read_status_controller.dart';
import 'package:cove/features/activity/activity_screen.dart';
import 'package:cove/features/add/add_flow.dart';
import 'package:cove/features/app_shell.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_screen.dart';
import 'package:cove/features/expenses/expenses_screen.dart';
import 'package:cove/features/habits/habits_screen.dart';
import 'package:cove/features/home/home_settings_screen.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/lists/lists_screen.dart';
import 'package:cove/features/notifications/notification_controller.dart';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:cove/features/notifications/notification_service.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/profile_screen.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/reminders/reminder_controller.dart';
import 'package:cove/features/reminders/reminder_models.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/routines/routine_screen.dart';
import 'package:cove/features/subscriptions/commitments_helicopter_screen.dart';
import 'package:cove/features/subscriptions/emi_tracker_screen.dart';
import 'package:cove/features/subscriptions/subscriptions_screen.dart';
import 'package:cove/features/today/today_screen.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/providers/first_run_provider.dart';
import 'package:cove/sync/sync_engine.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden/golden_harness.dart';

class FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  final AsyncValue<CoveUser?> initial;

  FakeAuthNotifier(this.initial);

  @override
  AsyncValue<CoveUser?> build() => initial;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void signInWithDemoUser([
    String name = 'Alex',
    String email = 'alex@cove.local',
  ]) {}

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

class FakeActivePartnerNotifier extends ActiveHomePartnerNotifier {
  @override
  bool build() => true;
}

class FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() {
    return const PartnerProfileState(displayName: 'Sophia');
  }
}

class FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() {
    return const UserProfileState(
      displayName: 'Alex',
      email: 'alex@example.com',
    );
  }
}

class FakeWeatherNotifier extends WeatherNotifier {
  @override
  WeatherData? build() => null;

  @override
  Future<void> refreshWeather({bool force = false}) async {}
}

class FakeNotificationService extends NotificationService {
  FakeNotificationService({
    super.onNavigate,
    NotificationModule? initialPending,
  }) {
    if (initialPending != null) {
      onNotificationTapped(
        CoveNotificationPayload(
          homeId: 'home_123',
          module: initialPending,
          eventType: 'generic',
          title: 'Test',
          body: 'Test',
        ),
      );
    }
  }

  @override
  Future<void> initializeLocalNotifications() async {}

  @override
  Future<void> initializeFcm({String? fallbackToken}) async {}
}

class _StubAppDatabase extends Fake implements AppDatabase {
  @override
  Future<int> purgeOrphanedAndArchivedListItems([String? activeHomeId]) async =>
      0;

  @override
  Future<int> clearProfileActivityEvents() async => 0;

  @override
  Future<void> close() async {}
}

class _StubSyncEngine extends Fake implements SyncEngineImpl {
  @override
  void Function(CoveNotificationPayload payload)? onInboundActivityReceived;

  @override
  SyncConnectionState get currentState => SyncConnectionState.connected;

  @override
  Stream<SyncConnectionState> get connectionState =>
      Stream.value(SyncConnectionState.connected);

  @override
  Future<void> start({String? activeHomeId, List<int>? activeHomeKey}) async {}

  @override
  Future<void> stop() async {}
}

class _StubRoutineController extends RoutineController {
  _StubRoutineController(super.ref);

  @override
  Future<void> seedDefaultRoutinesIfEmpty() async {}
}

class _StubListController extends ListController {
  _StubListController(super.ref);

  @override
  Future<void> ensureDefaultLists() async {}
}

class _FakeActivityReadStatusNotifier extends ActivityReadNotifier {
  @override
  ActivityReadState build() => const ActivityReadState();

  @override
  Future<void> markAllAsRead() async {}
}

class _FakeReminderNotifier extends ReminderNotifier {
  @override
  List<CheckinReminder> build() => const [];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadCoveFonts();
  });

  final fixedNow = DateTime(2026, 10, 15, 10, 30);

  const testUser = CoveUser(
    id: 'user_alex',
    email: 'alex@example.com',
    displayName: 'Alex',
  );

  final testHome = LocalHome(
    id: 'home_123',
    name: 'Haven Sanctuary',
    createdAt: DateTime(2026, 1, 1),
    createdBy: 'user_alex',
    currency: 'INR',
  );

  final sampleList = LocalList(
    id: 'list_1',
    homeId: 'home_123',
    name: 'Groceries',
    isArchived: false,
    createdAt: fixedNow,
    createdBy: 'user_alex',
  );

  final sampleListItems = <LocalListItem>[
    LocalListItem(
      id: 'item_1',
      homeId: 'home_123',
      listId: 'list_1',
      title: 'Organic Almond Milk',
      isCompleted: false,
      createdAt: fixedNow,
      createdBy: 'user_alex',
    ),
    LocalListItem(
      id: 'item_2',
      homeId: 'home_123',
      listId: 'list_1',
      title: 'Sourdough Bread',
      isCompleted: true,
      completedBy: 'user_alex',
      completedAt: fixedNow,
      createdAt: fixedNow,
      createdBy: 'user_alex',
    ),
  ];

  final sampleExpenses = <LocalExpense>[
    LocalExpense(
      id: 'exp_1',
      homeId: 'home_123',
      title: 'Farmer Market Basket',
      amount: 1240,
      currency: 'INR',
      category: 'Groceries',
      paidBy: 'user_alex',
      splitRatio: 0.5,
      isTransfer: false,
      expenseDate: fixedNow,
      createdAt: fixedNow,
    ),
  ];

  final sampleSubscriptions = <LocalSubscription>[
    LocalSubscription(
      id: 'sub_1',
      homeId: 'home_123',
      name: 'Home Broadband',
      amount: 999,
      currency: 'INR',
      billingCycle: 'monthly',
      nextBillingDate: DateTime(2026, 10, 16),
      category: 'Utilities',
      isActive: true,
      isPrivate: false,
      createdBy: 'user_alex',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  final sampleHabits = <LocalHabit>[
    LocalHabit(
      id: 'hab_1',
      homeId: 'home_123',
      name: 'Morning Walk',
      cadence: 'daily',
      targetDaysPerWeek: 7,
      isArchived: false,
      createdAt: DateTime(2026, 1, 1),
      createdBy: 'user_alex',
    ),
    LocalHabit(
      id: 'hab_2',
      homeId: 'home_123',
      name: 'Evening Journal',
      cadence: 'daily',
      targetDaysPerWeek: -7,
      isArchived: false,
      createdAt: DateTime(2026, 1, 1),
      createdBy: 'user_alex',
    ),
  ];

  final sampleRoutines = <Routine>[
    Routine(
      id: 'routine_1',
      homeId: 'home_123',
      name: 'Weekdays',
      days: const [1, 2, 3, 4, 5],
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  List<Override> createBaseOverrides() {
    final stubDb = _StubAppDatabase();
    final stubSync = _StubSyncEngine();
    return [
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      for (final screen in CoveScreen.values)
        firstRunProvider(screen).overrideWithValue(FirstRunState.inUse),
      appDatabaseProvider.overrideWithValue(stubDb),
      syncEngineProvider.overrideWithValue(stubSync),
      authProvider.overrideWith(
        () => FakeAuthNotifier(const AsyncValue.data(testUser)),
      ),
      activeHomeIdProvider.overrideWith(
        () => FakeActiveHomeNotifier('home_123'),
      ),
      activeHomeProvider.overrideWith((ref) => Stream.value(testHome)),
      userHomesProvider.overrideWith((ref) => Stream.value([testHome])),
      activeHomeHasPartnerProvider.overrideWith(FakeActivePartnerNotifier.new),
      partnerProfileProvider.overrideWith(FakePartnerProfileNotifier.new),
      userProfileProvider.overrideWith(FakeUserProfileNotifier.new),
      activityReadStatusProvider.overrideWith(
        _FakeActivityReadStatusNotifier.new,
      ),
      activityFeedProvider.overrideWith((ref) => Stream.value(const [])),
      unreadActivityCountProvider.overrideWith((ref) => 0),
      checkinRemindersProvider.overrideWith(_FakeReminderNotifier.new),
      weatherProvider.overrideWith(FakeWeatherNotifier.new),
      activeHomeCalendarEventsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeSubscriptionsProvider.overrideWith(
        (ref) => Stream.value(sampleSubscriptions),
      ),
      activeHomeHabitsProvider.overrideWith(
        (ref) => Stream.value(sampleHabits),
      ),
      activeHomeAllHabitCheckinsProvider.overrideWith(
        (ref) => Stream.value([]),
      ),
      activeHomeListsProvider.overrideWith(
        (ref) => Stream.value([sampleList]),
      ),
      activeHomeListItemsProvider.overrideWith(
        (ref, listId) => Stream.value(sampleListItems),
      ),
      activeHomeAllListItemsProvider.overrideWith(
        (ref) => Stream.value(sampleListItems),
      ),
      activeHomeExpensesProvider.overrideWith(
        (ref) => Stream.value(sampleExpenses),
      ),
      activeHomeRoutinesProvider.overrideWith(
        (ref) => Stream.value(sampleRoutines),
      ),
      activeHomeAllRoutineEventsProvider.overrideWith(
        (ref) => Stream.value([]),
      ),
      routineEventsProvider('routine_1').overrideWith(
        (ref) => Stream.value(const []),
      ),
      routineControllerProvider.overrideWith(
        (ref) => _StubRoutineController(ref),
      ),
      listControllerProvider.overrideWith(
        (ref) => _StubListController(ref),
      ),
      activeHomeOutboxProvider.overrideWith((ref) => Stream.value([])),
      coveEmitActionProvider.overrideWithValue((
        {required String eventType,
        required Map<String, dynamic> payload,
        String? targetHomeId}) async {}),
    ];
  }

  Widget createWidgetUnderTest({List<Override>? overrides}) {
    return ProviderScope(
      overrides: overrides ?? createBaseOverrides(),
      child: MaterialApp(
        theme: CoveTheme.darkTheme,
        home: const AppShell(),
      ),
    );
  }

  group('CoveFloatingBar Navigation & Back Rules (3.13)', () {
    testWidgets(
      '1. App launches with Home -> TodayScreen as default surface',
      (tester) async {
        tester.view.physicalSize = const Size(411, 891);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(TodayScreen), findsOneWidget);
        expect(find.byType(CoveFloatingBar), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '2. Tapping categories opens first destination, detaches Home, switches seats without pushing routes, and Home returns to Today',
      (tester) async {
        tester.view.physicalSize = const Size(411, 891);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final nav = tester.state<NavigatorState>(find.byType(Navigator));
        expect(nav.canPop(), isFalse);

        // Money -> Expenses -> Bills -> Home
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_money')));
        await tester.pumpAndSettle();
        expect(find.byType(ExpensesScreen), findsOneWidget);
        expect(find.text('Bills'), findsOneWidget);
        expect(nav.canPop(), isFalse);

        await tester.tap(
          find.byKey(const ValueKey('cove_bar_seat_commitments')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SubscriptionsScreen), findsOneWidget);
        expect(nav.canPop(), isFalse);

        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_home')));
        await tester.pumpAndSettle();
        expect(find.byType(TodayScreen), findsOneWidget);

        // Tasks -> Todo -> Habits -> Home (Habits has no back button)
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_tasks')));
        await tester.pumpAndSettle();
        expect(find.byType(ListsScreen), findsOneWidget);
        expect(nav.canPop(), isFalse);

        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_habits')));
        await tester.pumpAndSettle();
        expect(find.byType(HabitsScreen), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(nav.canPop(), isFalse);

        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_home')));
        await tester.pumpAndSettle();
        expect(find.byType(TodayScreen), findsOneWidget);

        // Calendar -> Day -> Routines -> Home (Routines has no back button)
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_calendar')));
        await tester.pumpAndSettle();
        expect(find.byType(CalendarScreen), findsOneWidget);
        expect(nav.canPop(), isFalse);

        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_routines')));
        await tester.pumpAndSettle();
        expect(find.byType(RoutineScreen), findsOneWidget);
        expect(find.byIcon(Icons.arrow_back), findsNothing);
        expect(nav.canPop(), isFalse);

        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_home')));
        await tester.pumpAndSettle();
        expect(find.byType(TodayScreen), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '3. More menu has two items (EMIs, The year; no Savings) and pushed pages have no floating bar',
      (tester) async {
        tester.view.physicalSize = const Size(411, 891);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Money -> More -> EMIs
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_money')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_more')));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('cove_bar_more_menu')), findsOneWidget);
        expect(find.text('EMIs'), findsOneWidget);
        expect(find.text('The year'), findsOneWidget);
        expect(find.text('Savings'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('cove_bar_overflow_emis')));
        await tester.pumpAndSettle();
        expect(find.byType(EmiTrackerScreen), findsOneWidget);
        expect(find.byType(CoveFloatingBar), findsNothing);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(ExpensesScreen), findsOneWidget);
        expect(find.byType(CoveFloatingBar), findsOneWidget);

        // Money -> More -> The year
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_more')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cove_bar_overflow_year')));
        await tester.pumpAndSettle();
        expect(find.byType(CommitmentsHelicopterScreen), findsOneWidget);
        expect(find.byType(CoveFloatingBar), findsNothing);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Return to Home and check header-pushed pages (Activity, Our home, Settings) have no bar
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_home')));
        await tester.pumpAndSettle();

        // Notifications -> ActivityScreen (no bar)
        await tester.tap(find.bySemanticsLabel('Notifications'));
        await tester.pumpAndSettle();
        expect(find.byType(ActivityScreen), findsOneWidget);
        expect(find.byType(CoveFloatingBar), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Home name -> HomeSettingsScreen (no bar)
        await tester.tap(find.text('Haven Sanctuary'));
        await tester.pumpAndSettle();
        expect(find.byType(HomeSettingsScreen), findsOneWidget);
        expect(find.byType(CoveFloatingBar), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Avatar -> ProfileScreen (no bar)
        await tester.tap(find.text('A').first);
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.byType(CoveFloatingBar), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '4. Centre + opens AddFlow with today as anchor, and on Calendar · Day passes the selected day',
      (tester) async {
        tester.view.physicalSize = const Size(411, 891);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await withClock(Clock.fixed(fixedNow), () async {
          await tester.pumpWidget(createWidgetUnderTest());
          await tester.pumpAndSettle();

          // On Home, tap + orb -> anchor is fixedNow (Oct 15, 2026)
          await tester.tap(find.byKey(const ValueKey('cove_bar_add_orb')));
          await tester.pumpAndSettle();
          expect(find.byType(AddFlow), findsOneWidget);
          final homeFlow = tester.widget<AddFlow>(find.byType(AddFlow));
          expect(homeFlow.anchor?.year, 2026);
          expect(homeFlow.anchor?.month, 10);
          expect(homeFlow.anchor?.day, 15);

          // Close AddFlow
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // Switch to Calendar -> Day, select Oct 18, and tap + orb
          await tester.tap(
            find.byKey(const ValueKey('cove_bar_seat_calendar')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(CalendarScreen), findsOneWidget);

          await tester.tap(
            find.byKey(const ValueKey('calendar_day_2026_10_18')),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(const ValueKey('cove_bar_add_orb')));
          await tester.pumpAndSettle();
          expect(find.byType(AddFlow), findsOneWidget);
          final dayFlow = tester.widget<AddFlow>(find.byType(AddFlow));
          expect(dayFlow.anchor?.year, 2026);
          expect(dayFlow.anchor?.month, 10);
          expect(dayFlow.anchor?.day, 18);

          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();
        });

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '5. Android back: from any category destination -> Home; from Home -> double-press exit',
      (tester) async {
        tester.view.physicalSize = const Size(411, 891);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool popSystemCalled = false;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'SystemNavigator.pop') {
              popSystemCalled = true;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Check every category destination returns to Home on Android back:
        // 1) Money -> Bills
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_money')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('cove_bar_seat_commitments')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(SubscriptionsScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TodayScreen), findsOneWidget);

        // 2) Tasks -> Habits
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_tasks')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_habits')));
        await tester.pumpAndSettle();
        expect(find.byType(HabitsScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TodayScreen), findsOneWidget);

        // 3) Calendar -> Routines
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_calendar')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_routines')));
        await tester.pumpAndSettle();
        expect(find.byType(RoutineScreen), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(TodayScreen), findsOneWidget);

        // 4) On Home: first back shows 'Press back again to exit', second back exits
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(find.text('Press back again to exit'), findsOneWidget);
        expect(popSystemCalled, isFalse);

        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(popSystemCalled, isTrue);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '6. Cold launch and in-app notification tap route directly to destination and dismiss pushed routes',
      (tester) async {
        tester.view.physicalSize = const Size(411, 891);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeNotif = FakeNotificationService(
          initialPending: NotificationModule.subscriptions,
        );
        final overrides = createBaseOverrides();
        overrides[0] = notificationServiceProvider.overrideWithValue(fakeNotif);

        await tester.pumpWidget(createWidgetUnderTest(overrides: overrides));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Opens directly to SubscriptionsScreen (Money -> Bills)
        expect(find.byType(SubscriptionsScreen), findsOneWidget);

        // Push EMIs page via More menu
        await tester.tap(find.byKey(const ValueKey('cove_bar_seat_more')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('cove_bar_overflow_emis')));
        await tester.pumpAndSettle();
        expect(find.byType(EmiTrackerScreen), findsOneWidget);

        // Tap notification for Expenses -> pops EmiTrackerScreen and switches to ExpensesScreen
        fakeNotif.onNotificationTapped(
          const CoveNotificationPayload(
            homeId: 'home_123',
            module: NotificationModule.expenses,
            eventType: 'expense_logged',
            title: 'Expenses',
            body: 'New expense logged',
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.byType(EmiTrackerScreen), findsNothing);
        expect(find.byType(ExpensesScreen), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '7. Every bar destination scrolls to the end at 320 / 411 / 840 and the last item is fully above CoveFloatingBar',
      (tester) async {
        final widths = <double>[320, 411, 840];

        Future<void> scrollVerticalToEnd(WidgetTester tester) async {
          final scrollables = tester
              .widgetList<Scrollable>(
                find.descendant(
                  of: find.byType(AppShell),
                  matching: find.byType(Scrollable),
                ),
              )
              .where((s) => s.axisDirection == AxisDirection.down)
              .toList();
          expect(scrollables, isNotEmpty);
          for (final scrollable in scrollables) {
            final state = tester.state<ScrollableState>(
              find.byWidget(scrollable),
            );
            if (state.position.hasContentDimensions &&
                state.position.maxScrollExtent > 0) {
              state.position.jumpTo(state.position.maxScrollExtent);
            }
          }
          await tester.pumpAndSettle();
        }

        void assertAboveBar(
          WidgetTester tester,
          Finder lastItemFinder,
          String description,
        ) {
          expect(
            lastItemFinder,
            findsWidgets,
            reason: '$description: last item should be present',
          );
          final barTop = tester.getTopLeft(find.byType(CoveFloatingBar)).dy;
          final itemBottom = tester.getBottomLeft(lastItemFinder.last).dy;
          expect(
            itemBottom,
            lessThanOrEqualTo(barTop),
            reason:
                '$description: last item bottom ($itemBottom) must be <= CoveFloatingBar top ($barTop)',
          );
        }

        await withClock(Clock.fixed(fixedNow), () async {
          for (final width in widths) {
            tester.view.physicalSize = Size(width, 720);
            tester.view.devicePixelRatio = 1.0;

            await tester.pumpWidget(createWidgetUnderTest());
            await tester.pumpAndSettle();

            // At 320dp (< 360dp), icons only; at >= 360dp, labels shown
            if (width < 360) {
              expect(
                find.byKey(const ValueKey('cove_bar_label_home')),
                findsNothing,
              );
            } else {
              expect(
                find.byKey(const ValueKey('cove_bar_label_home')),
                findsOneWidget,
              );
            }

            // 1. Home -> TodayScreen
            expect(find.byType(TodayScreen), findsOneWidget);
            await scrollVerticalToEnd(tester);
            assertAboveBar(
              tester,
              find.text('Encrypted on your phones, never on ours'),
              'TodayScreen @ ${width.toInt()}dp',
            );

            // 2. Money -> Expenses (ExpensesScreen)
            await tester.tap(find.byKey(const ValueKey('cove_bar_seat_money')));
            await tester.pumpAndSettle();
            expect(find.byType(ExpensesScreen), findsOneWidget);
            await scrollVerticalToEnd(tester);
            assertAboveBar(
              tester,
              find.text('Farmer Market Basket'),
              'ExpensesScreen @ ${width.toInt()}dp',
            );

            // 3. Money -> Bills (SubscriptionsScreen)
            await tester.tap(
              find.byKey(const ValueKey('cove_bar_seat_commitments')),
            );
            await tester.pumpAndSettle();
            expect(find.byType(SubscriptionsScreen), findsOneWidget);
            await scrollVerticalToEnd(tester);
            assertAboveBar(
              tester,
              find.text('Home Broadband'),
              'SubscriptionsScreen @ ${width.toInt()}dp',
            );

            // 4. Tasks -> Todo (ListsScreen)
            await tester.tap(find.byKey(const ValueKey('cove_bar_seat_home')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('cove_bar_seat_tasks')));
            await tester.pumpAndSettle();
            expect(find.byType(ListsScreen), findsOneWidget);
            await scrollVerticalToEnd(tester);
            assertAboveBar(
              tester,
              find.text('Sourdough Bread'),
              'ListsScreen last item @ ${width.toInt()}dp',
            );
            assertAboveBar(
              tester,
              find.byType(CovePillInput),
              'ListsScreen input bar @ ${width.toInt()}dp',
            );

            // 5. Tasks -> Habits (HabitsScreen)
            await tester.tap(
              find.byKey(const ValueKey('cove_bar_seat_habits')),
            );
            await tester.pumpAndSettle();
            expect(find.byType(HabitsScreen), findsOneWidget);
            await scrollVerticalToEnd(tester);
            assertAboveBar(
              tester,
              find.text('Evening Journal'),
              'HabitsScreen @ ${width.toInt()}dp',
            );

            // 6. Calendar -> Day (CalendarScreen)
            await tester.tap(find.byKey(const ValueKey('cove_bar_seat_home')));
            await tester.pumpAndSettle();
            await tester.tap(
              find.byKey(const ValueKey('cove_bar_seat_calendar')),
            );
            await tester.pumpAndSettle();
            expect(find.byType(CalendarScreen), findsOneWidget);
            await scrollVerticalToEnd(tester);
            assertAboveBar(
              tester,
              find.byIcon(Icons.autorenew_rounded),
              'CalendarScreen @ ${width.toInt()}dp',
            );

            // 7. Calendar -> Routines (RoutineScreen)
            await tester.tap(
              find.byKey(const ValueKey('cove_bar_seat_routines')),
            );
            await tester.pumpAndSettle();
            expect(find.byType(RoutineScreen), findsOneWidget);
            await scrollVerticalToEnd(tester);
            assertAboveBar(
              tester,
              find.text('11 PM'),
              'RoutineScreen @ ${width.toInt()}dp',
            );

            await tester.pumpWidget(const SizedBox());
          }
        });

        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  });
}
