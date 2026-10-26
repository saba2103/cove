import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/widgets.dart';
import 'package:cove/features/add/add_flow.dart';
import 'package:cove/features/activity/activity_read_status_controller.dart';
import 'package:cove/features/app_shell.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_screen.dart';
import 'package:cove/features/home/home_settings_screen.dart';
import 'package:cove/features/notifications/notification_controller.dart';
import 'package:cove/features/notifications/notification_service.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/today/today_controller.dart';
import 'package:cove/features/today/today_models.dart';
import 'package:cove/features/today/today_screen.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/providers/first_run_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

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
    return const UserProfileState(displayName: 'Alex', email: 'alex@example.com');
  }
}

class FakeWeatherNotifier extends WeatherNotifier {
  @override
  WeatherData? build() => null;

  @override
  Future<void> refreshWeather({bool force = false}) async {}
}

class FakeNotificationService extends NotificationService {
  @override
  Future<void> initializeLocalNotifications() async {}

  @override
  Future<void> initializeFcm({String? fallbackToken}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = CoveUser(
    id: 'user_alex',
    email: 'alex@example.com',
    displayName: 'Alex',
  );

  final testHome = LocalHome(
    id: 'home_123',
    name: 'Haven Sanctuary',
    createdAt: DateTime(2026, 1, 1),
    createdBy: 'user_alex',
    currency: 'USD',
  );

  List<Override> createBaseOverrides({
    TodayData? customTodayData,
    List<LocalList>? activeLists,
    List<LocalListItem>? allListItems,
    List<LocalSubscription>? subscriptions,
  }) {
    return [
      firstRunProvider(CoveScreen.today).overrideWithValue(false),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      authProvider.overrideWith(() => FakeAuthNotifier(AsyncValue.data(testUser))),
      activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_123')),
      activeHomeProvider.overrideWith((ref) => Stream.value(testHome)),
      userHomesProvider.overrideWith((ref) => Stream.value([testHome])),
      activeHomeHasPartnerProvider.overrideWith(FakeActivePartnerNotifier.new),
      partnerProfileProvider.overrideWith(FakePartnerProfileNotifier.new),
      userProfileProvider.overrideWith(FakeUserProfileNotifier.new),
      unreadActivityCountProvider.overrideWith((ref) => 0),
      weatherProvider.overrideWith(FakeWeatherNotifier.new),
      activeHomeCalendarEventsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeSubscriptionsProvider.overrideWith(
        (ref) => Stream.value(subscriptions ?? []),
      ),
      activeHomeHabitsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeAllHabitCheckinsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeListsProvider.overrideWith((ref) => Stream.value(activeLists ?? [])),
      activeHomeAllListItemsProvider.overrideWith((ref) => Stream.value(allListItems ?? [])),
      activeHomeExpensesProvider.overrideWith((ref) => Stream.value([])),
      if (customTodayData != null)
        todayDataProvider.overrideWithValue(customTodayData),
      coveEmitActionProvider.overrideWithValue((
        {required String eventType,
        required Map<String, dynamic> payload,
        String? targetHomeId}) async {}),
    ];
  }

  testWidgets('AppShell floating bar launches on TodayScreen and returns to TodayScreen from Calendar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: createBaseOverrides(),
        child: MaterialApp(
          theme: CoveTheme.darkTheme,
          home: const AppShell(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Default destination is Home -> TodayScreen
    expect(find.byType(TodayScreen), findsOneWidget);

    // Tap Calendar category in CoveFloatingBar
    await tester.tap(find.byKey(const ValueKey('cove_bar_seat_calendar')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CalendarScreen), findsOneWidget);

    // Tap detached Home circle to return to TodayScreen
    await tester.tap(find.byKey(const ValueKey('cove_bar_seat_home')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify TodayScreen is shown
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.textContaining('ON THE CALENDAR'), findsOneWidget);
    expect(find.textContaining('HABITS'), findsWidgets);
    expect(find.textContaining('THE LIST'), findsWidgets);
    expect(find.textContaining('SPENT TODAY'), findsWidgets);

    // Clean up
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Clicking home name in Today header opens HomeSettingsScreen (Our home)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: createBaseOverrides(),
        child: MaterialApp(
          theme: CoveTheme.darkTheme,
          home: const AppShell(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tap on the home name in the top left of TodayScreen
    final homeTitle = find.text('Haven Sanctuary');
    expect(homeTitle, findsOneWidget);
    await tester.tap(homeTitle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify HomeSettingsScreen (Our home) is pushed
    expect(find.byType(HomeSettingsScreen), findsOneWidget);

    // Clean up
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Today header avatar renders viewer initial and opens ProfileScreen on tap', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: createBaseOverrides(),
        child: MaterialApp(
          theme: CoveTheme.darkTheme,
          home: const AppShell(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Initial text 'A' in CoveAvatar.header
    expect(find.text('A'), findsWidgets);

    // Clean up
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('TodayScreen renders custom today habits, events, tasks and spend', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final sampleHabit = LocalHabit(
      id: 'habit_run',
      homeId: 'home_123',
      name: 'Morning Run',
      cadence: 'daily',
      targetDaysPerWeek: 7,
      isArchived: false,
      createdAt: now,
      createdBy: 'user_alex',
    );

    final todayData = TodayData(
      events: [
        TodayEventItem(
          id: 'ev_1',
          title: 'Farmers Market',
          startTime: DateTime(now.year, now.month, now.day, 10, 0),
          subtitle: '10:00 AM · Union Square',
        ),
      ],
      habits: [
        TodayHabitItem(
          habit: sampleHabit,
          habitId: 'habit_run',
          habitName: 'Morning Run',
          userCheckedInToday: false,
          partnerCheckedInToday: true,
          partnerAcknowledged: false,
          streak: 5,
          isPrivate: false,
          isOwnedByCurrentUser: true,
        ),
      ],
      focusTasks: [],
      todayExpenses: [],
      todaySpendTotal: 45.0,
      eventsOnlyCount: 1,
      listsSummary: const [],
      sharedMonthExpensesTotal: 0.0,
      userName: 'Alex',
      partnerName: 'Sophia',
      hasPartner: true,
      morningQuote: 'Two lives. One calm rhythm.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: createBaseOverrides(customTodayData: todayData),
        child: MaterialApp(
          theme: CoveTheme.darkTheme,
          home: const TodayScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify greeting contains user's name only
    expect(find.text('Alex'), findsOneWidget);
    expect(find.textContaining('& Sophia'), findsNothing);

    // Verify event is displayed
    expect(find.text('Farmers Market'), findsOneWidget);
    expect(find.textContaining('Union Square'), findsOneWidget);

    // Verify habit is displayed with streak & partner status
    expect(find.text('Morning Run'), findsOneWidget);
    expect(find.text('DAYS RUNNING'), findsOneWidget);
    expect(find.textContaining('Sophia checked in'), findsOneWidget);

    // Verify spend card
    expect(find.text('\$45'), findsWidgets);

    // Clean up
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Today focus tasks strictly ignore items from deleted or archived lists', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final activeList = LocalList(
      id: 'list_active',
      homeId: 'home_123',
      name: 'Groceries',
      isArchived: false,
      createdAt: now,
      createdBy: 'user_alex',
    );

    final activeItem = LocalListItem(
      id: 'item_1',
      homeId: 'home_123',
      listId: 'list_active',
      title: 'Organic Almond Milk',
      isCompleted: false,
      createdAt: now,
      createdBy: 'user_alex',
    );

    final deletedListItem = LocalListItem(
      id: 'item_2',
      homeId: 'home_123',
      listId: 'list_deleted_999',
      title: 'Old Task From Deleted List',
      isCompleted: false,
      createdAt: now,
      createdBy: 'user_alex',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: createBaseOverrides(
          activeLists: [activeList],
          allListItems: [activeItem, deletedListItem],
        ),
        child: MaterialApp(
          theme: CoveTheme.darkTheme,
          home: const TodayScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Focus tasks section renders active item
    expect(find.text('Organic Almond Milk'), findsOneWidget);
    expect(find.textContaining('GROCERIES'), findsWidgets);

    // Old task from deleted list is strictly NOT rendered
    expect(find.text('Old Task From Deleted List'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  group('TodayScreen commitments section (Due today / tomorrow)', () {
    final fixedNow = DateTime(2026, 10, 15, 10, 30);
    final todayDate = DateTime(2026, 10, 15);
    final tomorrowDate = DateTime(2026, 10, 16);
    final futureDate = DateTime(2026, 10, 28);

    LocalSubscription makeSub({
      required String id,
      required String name,
      required double amount,
      required DateTime nextBillingDate,
    }) {
      return LocalSubscription(
        id: id,
        homeId: 'home_123',
        name: name,
        amount: amount,
        currency: 'INR',
        billingCycle: 'monthly',
        nextBillingDate: nextBillingDate,
        category: 'Bills',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_alex',
        createdAt: DateTime(2026, 1, 1),
      );
    }

    Future<void> pumpTodayWithSubscriptions(
      WidgetTester tester,
      List<LocalSubscription> subs,
    ) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await withClock(Clock.fixed(fixedNow), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: createBaseOverrides(subscriptions: subs),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const TodayScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      });
    }

    testWidgets('items due today only: labels "DUE TODAY" and excludes future items', (tester) async {
      await pumpTodayWithSubscriptions(tester, [
        makeSub(
          id: 'sub_today',
          name: 'House Rent',
          amount: 25000,
          nextBillingDate: todayDate,
        ),
        makeSub(
          id: 'sub_future',
          name: 'Cloud Backup',
          amount: 199,
          nextBillingDate: futureDate,
        ),
      ]);

      expect(find.text('DUE TODAY'), findsOneWidget);
      expect(find.text('DUE TOMORROW'), findsNothing);
      expect(find.text('DUE TODAY AND TOMORROW'), findsNothing);
      expect(find.byType(CoveVoucher), findsOneWidget);
      expect(find.byKey(const ValueKey('today_voucher_sub_today')), findsOneWidget);
      expect(find.byKey(const ValueKey('today_voucher_sub_future')), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('items due tomorrow only: labels "DUE TOMORROW" and excludes future items', (tester) async {
      await pumpTodayWithSubscriptions(tester, [
        makeSub(
          id: 'sub_tomorrow',
          name: 'Apple One Family',
          amount: 365,
          nextBillingDate: tomorrowDate,
        ),
        makeSub(
          id: 'sub_future',
          name: 'Cloud Backup',
          amount: 199,
          nextBillingDate: futureDate,
        ),
      ]);

      expect(find.text('DUE TOMORROW'), findsOneWidget);
      expect(find.text('DUE TODAY'), findsNothing);
      expect(find.text('DUE TODAY AND TOMORROW'), findsNothing);
      expect(find.byType(CoveVoucher), findsOneWidget);
      expect(find.byKey(const ValueKey('today_voucher_sub_tomorrow')), findsOneWidget);
      expect(find.byKey(const ValueKey('today_voucher_sub_future')), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('items due both today and tomorrow: labels "DUE TODAY AND TOMORROW"', (tester) async {
      await pumpTodayWithSubscriptions(tester, [
        makeSub(
          id: 'sub_today',
          name: 'House Rent',
          amount: 25000,
          nextBillingDate: todayDate,
        ),
        makeSub(
          id: 'sub_tomorrow',
          name: 'Apple One Family',
          amount: 365,
          nextBillingDate: tomorrowDate,
        ),
        makeSub(
          id: 'sub_future',
          name: 'Cloud Backup',
          amount: 199,
          nextBillingDate: futureDate,
        ),
      ]);

      expect(find.text('DUE TODAY AND TOMORROW'), findsOneWidget);
      expect(find.text('DUE TODAY'), findsNothing);
      expect(find.text('DUE TOMORROW'), findsNothing);
      expect(find.byType(CoveVoucher), findsNWidgets(2));
      expect(find.byKey(const ValueKey('today_voucher_sub_today')), findsOneWidget);
      expect(find.byKey(const ValueKey('today_voucher_sub_tomorrow')), findsOneWidget);
      expect(find.byKey(const ValueKey('today_voucher_sub_future')), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('none due with next upcoming: renders no voucher and shows Next line', (tester) async {
      await pumpTodayWithSubscriptions(tester, [
        makeSub(
          id: 'sub_next',
          name: 'Apple One Family',
          amount: 365,
          nextBillingDate: DateTime(2026, 10, 20),
        ),
        makeSub(
          id: 'sub_later',
          name: 'Home Solar Panel Loan',
          amount: 8500,
          nextBillingDate: DateTime(2026, 10, 25),
        ),
      ]);

      expect(find.text('DUE TOMORROW'), findsOneWidget);
      expect(find.byType(CoveVoucher), findsNothing);
      expect(
        find.text('Nothing due tomorrow. Next: Apple One Family on Oct 20.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('none due at all: renders no voucher and shows "Nothing due."', (tester) async {
      await pumpTodayWithSubscriptions(tester, const []);

      expect(find.text('DUE TOMORROW'), findsOneWidget);
      expect(find.byType(CoveVoucher), findsNothing);
      expect(find.text('Nothing due.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'empty calendar, habits, spend, and list sections show quiet lines and never draw placeholder slips, while + on calendar opens Add for an event',
      (tester) async {
        await pumpTodayWithSubscriptions(tester, const []);

        expect(find.text('Nothing on the calendar today.'), findsOneWidget);
        expect(find.byType(CoveTicket), findsNothing);
        expect(find.text('No habits yet.'), findsOneWidget);
        expect(find.byType(CoveHabitCard), findsNothing);
        expect(find.text('Nothing spent today.'), findsOneWidget);
        expect(find.byType(CoveReceipt), findsNothing);
        expect(find.text('Nothing open on Grocery.'), findsOneWidget);
        expect(find.byType(CoveNote), findsNothing);

        final addEventBtn = find.byWidgetPredicate(
          (w) => w is CoveRoundButton && w.semanticLabel == 'Add event',
        );
        expect(addEventBtn, findsOneWidget);
        await tester.tap(addEventBtn);
        await tester.pumpAndSettle();
        expect(find.byType(AddFlow), findsOneWidget);
        expect(find.textContaining('EVENT'), findsWidgets);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
