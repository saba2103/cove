import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/activity/activity_read_status_controller.dart';
import 'package:cove/features/app_shell.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/home/about_cove_screen.dart';
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
  }) {
    return [
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
      activeHomeSubscriptionsProvider.overrideWith((ref) => Stream.value([])),
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

  testWidgets('AppShell header has Today icon button and clicking it navigates to TodayScreen', (tester) async {
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

    // Verify Today button icon is present in AppBar
    final todayButton = find.byTooltip('Today');
    expect(todayButton, findsOneWidget);
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);

    // Tap Today button
    await tester.tap(todayButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify TodayScreen is shown
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('TODAY\'S FLOW'), findsOneWidget);
    expect(find.textContaining('DAILY RHYTHMS'), findsOneWidget);
    expect(find.textContaining('FOCUS TASKS'), findsOneWidget);
    expect(find.textContaining('TODAY\'S SPEND'), findsOneWidget);

    // Clean up
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Clicking Cove name in top-left opens AboutCoveScreen', (tester) async {
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

    // Tap on the home name in the top left
    final homeTitle = find.text('Haven Sanctuary');
    expect(homeTitle, findsOneWidget);
    await tester.tap(homeTitle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Verify AboutCoveScreen is pushed
    expect(find.byType(AboutCoveScreen), findsOneWidget);
    expect(find.text('About Sanctuary'), findsOneWidget);
    expect(find.text('MEMBERS OF THIS COVE'), findsOneWidget);
    expect(find.text('THE COVE PHILOSOPHY'), findsOneWidget);
    expect(find.text('A private digital sanctuary crafted exclusively for two people.'), findsOneWidget);

    // Clean up
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Profile avatar has inverted colors (accent fill, dark green initial)', (tester) async {
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

    // Find the header CircleAvatar
    final circleAvatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar).first);
    expect(circleAvatar.backgroundColor, CoveColors.dark.accentPrimary);

    // Initial text 'A'
    final initialText = tester.widget<Text>(find.descendant(
      of: find.byType(CircleAvatar).first,
      matching: find.text('A'),
    ));
    expect(initialText.style?.color, CoveColors.dark.surfaceRow);

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

    // Verify greeting contains partner name
    expect(find.textContaining('Alex & Sophia'), findsOneWidget);

    // Verify event is displayed
    expect(find.text('Farmers Market'), findsOneWidget);
    expect(find.text('10:00 AM · Union Square'), findsOneWidget);

    // Verify habit is displayed with streak & partner status
    expect(find.text('Morning Run'), findsOneWidget);
    expect(find.textContaining('5d streak 🔥'), findsOneWidget);
    expect(find.textContaining('Sophia checked in ✓'), findsOneWidget);

    // Verify spend card
    expect(find.text('\$45.00'), findsOneWidget);

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
    expect(find.text('Groceries'), findsOneWidget);

    // Old task from deleted list is strictly NOT rendered
    expect(find.text('Old Task From Deleted List'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });
}
