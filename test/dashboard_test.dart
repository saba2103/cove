import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/features/activity/activity_models.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/dashboard/dashboard_controller.dart';
import 'package:cove/features/dashboard/dashboard_models.dart';
import 'package:cove/features/dashboard/dashboard_screen.dart';
import 'package:cove/features/notifications/notification_controller.dart';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:drift/native.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() {
    return const PartnerProfileState(displayName: 'Sophia');
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

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  final testUser = CoveUser(
    id: 'user_1',
    email: 'alex@example.com',
    displayName: 'Alex Rivers',
    avatarUrl: null,
  );

  final testHome = LocalHome(
    id: 'home_1',
    name: 'Our Cove',
    currency: 'USD',
    createdAt: DateTime(2026, 1, 1),
    createdBy: 'user_1',
  );

  group('Dashboard Data Calculations', () {
    test('Correctly computes expenses total, upcoming items, lists and habits', () async {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final todayString = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final List<LocalExpense> expenses = [
        LocalExpense(
          id: 'exp_1',
          homeId: 'home_1',
          title: 'Groceries',
          amount: 142.50,
          currency: 'USD',
          category: 'groceries',
          expenseDate: todayDate,
          paidBy: 'user_1',
          splitRatio: 0.5,
          createdAt: now,
          isTransfer: false,
        ),
        LocalExpense(
          id: 'exp_2',
          homeId: 'home_1',
          title: 'Dinner',
          amount: 58.00,
          currency: 'USD',
          category: 'dining',
          expenseDate: todayDate,
          paidBy: 'user_2',
          splitRatio: 0.5,
          createdAt: now,
          isTransfer: false,
        ),
        // Prior month expense - should not be included in this month total
        LocalExpense(
          id: 'exp_3',
          homeId: 'home_1',
          title: 'Flight tickets',
          amount: 200.00,
          currency: 'USD',
          category: 'travel',
          expenseDate: DateTime(now.year, now.month - 1, 15),
          paidBy: 'user_1',
          splitRatio: 0.5,
          createdAt: now,
          isTransfer: false,
        ),
      ];

      final List<LocalSubscription> subscriptions = [
        LocalSubscription(
          id: 'sub_1',
          homeId: 'home_1',
          name: 'Claude Pro',
          amount: 20.0,
          currency: 'USD',
          billingCycle: 'monthly',
          nextBillingDate: todayDate.add(const Duration(days: 3)),
          category: 'Software',
          isPrivate: false,
          isActive: true,
          createdAt: now,
        ),
        LocalSubscription(
          id: 'sub_private',
          homeId: 'home_1',
          name: 'Private Gym',
          amount: 50.0,
          currency: 'USD',
          billingCycle: 'monthly',
          nextBillingDate: todayDate.add(const Duration(days: 2)),
          category: 'Health',
          isPrivate: true,
          isActive: true,
          createdAt: now,
        ),
      ];

      final List<LocalCalendarEvent> calendarEvents = [
        LocalCalendarEvent(
          id: 'cal_1',
          homeId: 'home_1',
          title: 'Architect Walkthrough',
          startTime: todayDate.add(const Duration(hours: 10)),
          endTime: todayDate.add(const Duration(hours: 11)),
          location: 'Cove Site',
          createdBy: 'user_1',
          isAllDay: false,
          createdAt: now,
        ),
      ];

      final List<LocalList> lists = [
        LocalList(
          id: 'list_1',
          homeId: 'home_1',
          name: 'Grocery',
          createdBy: 'user_1',
          createdAt: now,
          isArchived: false,
        ),
      ];

      final List<LocalListItem> listItems = [
        LocalListItem(
          id: 'item_1',
          homeId: 'home_1',
          listId: 'list_1',
          title: 'Oat Milk',
          isCompleted: false,
          createdBy: 'user_1',
          createdAt: now,
        ),
        LocalListItem(
          id: 'item_2',
          homeId: 'home_1',
          listId: 'list_1',
          title: 'Sourdough',
          isCompleted: true,
          createdBy: 'user_2',
          createdAt: now,
        ),
      ];

      final List<LocalHabit> habits = [
        LocalHabit(
          id: 'habit_1',
          homeId: 'home_1',
          name: 'Morning Espresso',
          cadence: 'daily',
          targetDaysPerWeek: 7,
          createdBy: 'user_1',
          createdAt: now,
          isArchived: false,
        ),
      ];

      final List<LocalHabitCheckin> checkins = [
        LocalHabitCheckin(
          id: 'checkin_1',
          homeId: 'home_1',
          habitId: 'habit_1',
          memberId: 'user_1',
          checkinDate: todayString,
          createdAt: now,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_1')),
          authProvider.overrideWith(() => FakeAuthNotifier(AsyncValue.data(testUser))),
          activeHomeExpensesProvider.overrideWith((ref) => Stream.value(expenses)),
          activeHomeSubscriptionsProvider.overrideWith((ref) => Stream.value(subscriptions)),
          activeHomeCalendarEventsProvider.overrideWith((ref) => Stream.value(calendarEvents)),
          activeHomeListsProvider.overrideWith((ref) => Stream.value(lists)),
          activeHomeAllListItemsProvider.overrideWith((ref) => Stream.value(listItems)),
          activeHomeHabitsProvider.overrideWith((ref) => Stream.value(habits)),
          activeHomeAllHabitCheckinsProvider.overrideWith((ref) => Stream.value(checkins)),
        ],
      );

      container.listen(dashboardDataProvider, (previous, next) {});
      await container.read(activeHomeExpensesProvider.future);
      await container.read(activeHomeSubscriptionsProvider.future);
      await container.read(activeHomeCalendarEventsProvider.future);
      await container.read(activeHomeListsProvider.future);
      await container.read(activeHomeAllListItemsProvider.future);
      await container.read(activeHomeHabitsProvider.future);
      await container.read(activeHomeAllHabitCheckinsProvider.future);

      final data = container.read(dashboardDataProvider);

      // 1. Shared expenses monthly total = 142.50 + 58.00 = 200.50
      expect(data.sharedExpensesTotal, 200.50);

      // 2. Upcoming items: calendar event + shared subscription (private subscription is omitted)
      expect(data.upcomingItems.length, 2);
      expect(data.upcomingItems[0].title, 'Architect Walkthrough');
      expect(data.upcomingItems[0].isSubscription, false);
      expect(data.upcomingItems[1].title, 'Claude Pro');
      expect(data.upcomingItems[1].isSubscription, true);

      // 3. Lists summary: Grocery has 1 open item
      expect(data.listsSummary.length, 1);
      expect(data.listsSummary[0].name, 'Grocery');
      expect(data.listsSummary[0].openCount, 1);

      // 4. Habits: Morning espresso checked in by user_1, not yet by partner
      expect(data.habitsStatus.length, 1);
      expect(data.habitsStatus[0].habitName, 'Morning Espresso');
      expect(data.habitsStatus[0].userCheckedInToday, true);
      expect(data.habitsStatus[0].partnerCheckedInToday, false);

      container.dispose();
    });
  });

  group('Dashboard Screen UI & Navigation', () {
    Widget createWidgetUnderTest({
      required ProviderContainer container,
      required ThemeData theme,
      DashboardData? initialData,
      List<FormattedActivityItem>? initialRecentActivity,
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: DashboardScreen(
              initialData: initialData,
              initialRecentActivity: initialRecentActivity,
            ),
          ),
        ),
      );
    }

    testWidgets('Renders editorial morning brief sections correctly in Dark theme', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);

      final List<FormattedActivityItem> sampleActivity = [
        FormattedActivityItem(
          id: 'act_1',
          homeId: 'home_1',
          actorId: 'user_1',
          actorName: 'Alex',
          actionText: 'added "Fresh basil" to Grocery',
          eventType: 'list_item_added',
          module: ActivityModule.lists,
          icon: Icons.checklist_rounded,
          timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
          timeAgo: '12m ago',
          syncStatus: CoveSyncStatus.syncedToPartner,
          isPrivate: false,
          isLocalActor: true,
        ),
      ];

      final testDashboardData = DashboardData(
        sharedExpensesTotal: 864.20,
        upcomingItems: [
          DashboardUpcomingItem(
            id: 'cal_1',
            title: 'Dinner at Buvette',
            date: todayDate.add(const Duration(hours: 19)),
            dateBadge: 'TODAY',
            subtitle: '7:00 PM · Grove St',
            isSubscription: false,
            icon: Icons.calendar_today_outlined,
          ),
          DashboardUpcomingItem(
            id: 'sub_1',
            title: 'Spotify Family',
            date: todayDate.add(const Duration(days: 5)),
            dateBadge: 'IN 5 DAYS',
            subtitle: 'from Subscriptions',
            isSubscription: true,
            amountFormatted: '\$19.99/mo',
            icon: Icons.subscriptions_outlined,
          ),
        ],
        listsSummary: [
          DashboardListSummary(
            listId: 'list_1',
            name: 'Grocery',
            openCount: 1,
          ),
        ],
        habitsStatus: [
          DashboardHabitStatus(
            habitId: 'habit_1',
            habitName: 'Morning walk',
            userCheckedInToday: true,
            partnerCheckedInToday: false,
          ),
        ],
        recentActivity: sampleActivity,
      );

      NotificationModule? navigatedModule;

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_1')),
          activeHomeProvider.overrideWith((ref) => Stream.value(testHome)),
          authProvider.overrideWith(() => FakeAuthNotifier(AsyncValue.data(testUser))),
          partnerProfileProvider.overrideWith(FakePartnerProfileNotifier.new),
        ],
      );

      // Listen to navigation events
      container.listen<NotificationModule?>(notificationNavigationProvider, (_, next) {
        if (next != null) navigatedModule = next;
      });

      await tester.pumpWidget(createWidgetUnderTest(
        container: container,
        theme: CoveTheme.darkTheme,
        initialData: testDashboardData,
        initialRecentActivity: sampleActivity,
      ));
      await tester.pumpAndSettle();

      // 1. Header greeting & footer
      expect(find.textContaining(', Alex'), findsOneWidget);
      expect(find.text('Your home, sorted together.'), findsOneWidget);
      expect(find.textContaining('Crafted with love'), findsNothing);

      // 2. Shared expenses total card
      expect(find.text('SHARED THIS MONTH'), findsOneWidget);
      expect(find.text('\$864.20'), findsOneWidget);

      // 3. Coming up section
      expect(find.text('COMING UP'), findsOneWidget);
      expect(find.text('Dinner at Buvette'), findsOneWidget);
      expect(find.text('Spotify Family'), findsOneWidget);

      // 4. Shared lists section
      expect(find.text('SHARED LISTS'), findsOneWidget);
      expect(find.text('Grocery'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // 5. Habits today
      expect(find.text('HABITS TODAY'), findsOneWidget);
      expect(find.text('Morning walk'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Sophia'), findsOneWidget);

      // 6. Recent activity
      expect(find.text('RECENT ACTIVITY'), findsOneWidget);
      expect(find.text('Alex added "Fresh basil" to Grocery'), findsOneWidget);

      // Test tap on shared expenses card triggers navigation
      await tester.tap(find.text('SHARED THIS MONTH'));
      await tester.pumpAndSettle();
      expect(navigatedModule, NotificationModule.expenses);

      // Test tap on coming up item triggers calendar navigation
      await tester.tap(find.text('Dinner at Buvette'));
      await tester.pumpAndSettle();
      expect(navigatedModule, NotificationModule.calendar);

      // Test tap on list pill triggers lists navigation
      await tester.tap(find.text('Grocery'));
      await tester.pumpAndSettle();
      expect(navigatedModule, NotificationModule.lists);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump();
    });

    testWidgets('Renders correctly in Light theme', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_1')),
          activeHomeProvider.overrideWith((ref) => Stream.value(testHome)),
          authProvider.overrideWith(() => FakeAuthNotifier(AsyncValue.data(testUser))),
          partnerProfileProvider.overrideWith(FakePartnerProfileNotifier.new),
        ],
      );

      await tester.pumpWidget(createWidgetUnderTest(
        container: container,
        theme: CoveTheme.lightTheme,
        initialData: DashboardData.empty(),
        initialRecentActivity: const [],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining(', Alex'), findsOneWidget);
      expect(find.text('\$0'), findsOneWidget);
      expect(find.text('Nothing scheduled'), findsOneWidget);
      expect(find.text('No activity yet'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await tester.pump();
    });
  });
}
