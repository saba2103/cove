import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/features/activity/activity_detail_sheet.dart';
import 'package:cove/features/activity/activity_models.dart';
import 'package:cove/features/activity/activity_read_status_controller.dart';
import 'package:cove/features/activity/activity_screen.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/backup/drive_backup_controller.dart';
import 'package:cove/features/calendar/calendar_screen.dart';
import 'package:cove/features/expenses/category_detail_sheet.dart';
import 'package:cove/features/expenses/expense_detail_sheet.dart';
import 'package:cove/features/expenses/expenses_screen.dart';
import 'package:cove/features/expenses/monthly_budget_controller.dart';
import 'package:cove/features/habits/habit_detail_sheet.dart';
import 'package:cove/features/habits/habits_screen.dart';
import 'package:cove/features/home/home_settings_screen.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/lists/list_item_detail_sheet.dart';
import 'package:cove/features/lists/lists_screen.dart';
import 'package:cove/features/notifications/notification_controller.dart';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:cove/features/profile/home_metadata_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/profile_screen.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/reminders/reminder_controller.dart';
import 'package:cove/features/reminders/reminder_models.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/routines/routine_screen.dart';
import 'package:cove/features/subscriptions/commitment_detail_sheet.dart';
import 'package:cove/features/subscriptions/commitments_helicopter_screen.dart';
import 'package:cove/features/subscriptions/emi_tracker_screen.dart';
import 'package:cove/features/subscriptions/subscriptions_screen.dart';
import 'package:cove/features/today/today_controller.dart';
import 'package:cove/features/today/today_models.dart';
import 'package:cove/features/today/today_screen.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_backup_remote.dart';
import 'golden_harness.dart';

// ---------------------------------------------------------------------------
// Deterministic Seed Data (Fixed Date, Fixed Amounts, Two Fixed People)
// ---------------------------------------------------------------------------

final _kFixedDate = DateTime(2026, 10, 15, 10, 30);
final _kFixedCreatedAt = DateTime(2026, 1, 10, 9, 0);
final _kFixedAnniversary = DateTime(2023, 6, 15);
final _kFixedEndDate = DateTime(2027, 6, 15);

const _kAlexUser = CoveUser(
  id: 'user_alex',
  email: 'alex@cove.test',
  displayName: 'Alex',
);

const _kAlexProfile = UserProfileState(
  displayName: 'Alex',
  email: 'alex@cove.test',
  hasCustomName: true,
);

const _kSarahPartnerProfile = PartnerProfileState(
  displayName: 'Sarah',
  userId: 'user_sarah',
);

final _kSeedHome = LocalHome(
  id: 'home_1',
  name: 'Our Home',
  description: 'Alex & Sarah Sanctuary',
  icon: 'cottage',
  currency: 'INR',
  monthlyBudget: 85000.0,
  anniversaryDate: _kFixedAnniversary,
  createdAt: _kFixedCreatedAt,
  createdBy: 'user_alex',
);

const _kSeedHomeMetadata = HomeMetadataState(
  homeId: 'home_1',
  formattedTogetherDuration: 'Together for 3 years, 4 months',
);

final _kSeedBackupState = DriveBackupState(
  isLoaded: true,
  isConnected: true,
  accountEmail: 'alex@cove.test',
  hasPassphrase: true,
  lastBackupAt: _kFixedDate,
  lastBackupSizeBytes: 48 * 1024,
  autoEnabled: true,
  autoTime: const TimeOfDay(hour: 2, minute: 0),
  autoWifiOnly: true,
  autoLastRunAt: _kFixedDate,
);

final _kSeedExpenses = <LocalExpense>[
  LocalExpense(
    id: 'exp_1',
    homeId: 'home_1',
    title: 'Farmers Market Produce',
    amount: 1450.50,
    currency: 'INR',
    paidBy: 'user_alex',
    splitRatio: 0.5,
    expenseDate: _kFixedDate,
    category: 'Groceries',
    paymentMethod: 'upi',
    isTransfer: false,
    createdAt: _kFixedDate,
  ),
  LocalExpense(
    id: 'exp_2',
    homeId: 'home_1',
    title: 'Electricity & Fiber Internet',
    amount: 3200.0,
    currency: 'INR',
    paidBy: 'user_sarah',
    splitRatio: 0.5,
    expenseDate: DateTime(2026, 10, 12, 18, 0),
    category: 'Home & Utilities',
    paymentMethod: 'card',
    isTransfer: false,
    createdAt: DateTime(2026, 10, 12, 18, 0),
  ),
];

final _kSeedSubscriptions = <LocalSubscription>[
  LocalSubscription(
    id: 'sub_1',
    homeId: 'home_1',
    name: 'Apple One Family',
    amount: 365.0,
    currency: 'INR',
    billingCycle: 'monthly',
    nextBillingDate: DateTime(2026, 10, 20),
    category: 'Entertainment',
    isActive: true,
    isPrivate: false,
    createdBy: 'user_alex',
    createdAt: _kFixedCreatedAt,
    paidBy: 'split',
    financedThrough: 'HDFC Regalia',
  ),
  LocalSubscription(
    id: 'sub_emi_1',
    homeId: 'home_1',
    name: 'Home Solar Panel Loan',
    amount: 8500.0,
    currency: 'INR',
    billingCycle: 'monthly',
    nextBillingDate: DateTime(2026, 10, 25),
    category: 'Home & Utilities',
    isActive: true,
    isPrivate: false,
    createdBy: 'user_alex',
    createdAt: _kFixedCreatedAt,
    endDate: _kFixedEndDate,
    paidBy: 'user_alex',
    financedThrough: 'SBI Home Finance',
    totalInstallments: 12,
    paidInstallments: 6,
  ),
];

final _kSeedCalendarEvents = <LocalCalendarEvent>[
  LocalCalendarEvent(
    id: 'cal_1',
    homeId: 'home_1',
    title: 'Dinner with Sarah at Bastian',
    description: 'Table reserved for 8:00 PM',
    startTime: DateTime(2026, 10, 15, 20, 0),
    endTime: DateTime(2026, 10, 15, 22, 0),
    isAllDay: false,
    location: 'Bandra West',
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_alex',
  ),
];

final _kSeedLists = <LocalList>[
  LocalList(
    id: 'list_1',
    homeId: 'home_1',
    name: 'Groceries',
    isArchived: false,
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_alex',
  ),
  LocalList(
    id: 'list_2',
    homeId: 'home_1',
    name: 'Weekend Errands',
    isArchived: false,
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_sarah',
  ),
];

final _kSeedListItems = <LocalListItem>[
  LocalListItem(
    id: 'item_1',
    homeId: 'home_1',
    listId: 'list_1',
    title: 'Sourdough country loaf',
    notes: 'From Subko Cacao',
    dueDate: _kFixedDate,
    isCompleted: false,
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_alex',
  ),
  LocalListItem(
    id: 'item_2',
    homeId: 'home_1',
    listId: 'list_1',
    title: 'Organic oat milk (2 cartons)',
    isCompleted: true,
    completedAt: _kFixedDate,
    completedBy: 'user_sarah',
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_sarah',
  ),
];

final _kSeedHabits = <LocalHabit>[
  LocalHabit(
    id: 'habit_1',
    homeId: 'home_1',
    name: 'Morning Walk Together',
    cadence: 'daily',
    targetDaysPerWeek: 7,
    isArchived: false,
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_alex',
  ),
  LocalHabit(
    id: 'habit_2',
    homeId: 'home_1',
    name: 'Evening Reading (30m)',
    cadence: 'daily',
    targetDaysPerWeek: 7,
    isArchived: false,
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_sarah',
  ),
];

final _kSeedHabitCheckins = <LocalHabitCheckin>[
  LocalHabitCheckin(
    id: 'chk_1',
    homeId: 'home_1',
    habitId: 'habit_1',
    checkinDate: '2026-10-15',
    memberId: 'user_alex',
    createdAt: _kFixedDate,
  ),
  LocalHabitCheckin(
    id: 'chk_2',
    homeId: 'home_1',
    habitId: 'habit_1',
    checkinDate: '2026-10-15',
    memberId: 'user_sarah',
    createdAt: _kFixedDate,
  ),
];

final _kSeedRoutines = <Routine>[
  Routine(
    id: 'routine_1',
    homeId: 'home_1',
    name: 'Weekday (Mon – Fri)',
    days: const [],
    createdAt: _kFixedCreatedAt,
  ),
  Routine(
    id: 'routine_2',
    homeId: 'home_1',
    name: 'Weekend Slow Morning',
    days: const [],
    createdAt: _kFixedCreatedAt,
  ),
];

final _kSeedRoutineEvents = <RoutineEvent>[
  RoutineEvent(
    id: 'rev_1',
    routineId: 'routine_1',
    homeId: 'home_1',
    title: 'Morning Pour-Over & Stretch',
    startMinutes: 60, // 1:00 AM (visible in top viewport without scrolling)
    endMinutes: 135, // 2:15 AM
    category: 'Wellness',
    notes: '15g coffee, 250ml water',
    createdAt: _kFixedCreatedAt,
  ),
  RoutineEvent(
    id: 'rev_2',
    routineId: 'routine_1',
    homeId: 'home_1',
    title: 'Deep Focus Block',
    startMinutes: 180, // 3:00 AM
    endMinutes: 300, // 5:00 AM
    category: 'Work',
    createdAt: _kFixedCreatedAt,
  ),
];

final _kSeedActivities = <FormattedActivityItem>[
  FormattedActivityItem(
    id: 'act_1',
    homeId: 'home_1',
    actorId: 'user_alex',
    actorName: 'You',
    actionText: 'logged ₹1,450.50 for Farmers Market Produce',
    detailSubtitle: 'Groceries · Shared 50/50',
    eventType: 'expense_logged',
    module: ActivityModule.expenses,
    icon: Icons.receipt_long_outlined,
    timestamp: _kFixedDate,
    timeAgo: '2h ago',
    syncStatus: CoveSyncStatus.syncedToPartner,
    isPrivate: false,
    isLocalActor: true,
    entityId: 'exp_1',
  ),
  FormattedActivityItem(
    id: 'act_2',
    homeId: 'home_1',
    actorId: 'user_sarah',
    actorName: 'Sarah',
    actionText: "checked off 'Organic oat milk (2 cartons)' in Groceries",
    eventType: 'list_item_toggled',
    module: ActivityModule.lists,
    icon: Icons.check_circle_outline_rounded,
    timestamp: _kFixedDate.subtract(const Duration(hours: 3)),
    timeAgo: '5h ago',
    syncStatus: CoveSyncStatus.syncedToPartner,
    isPrivate: false,
    isLocalActor: false,
    entityId: 'item_2',
  ),
];

final _kSeedTodayData = TodayData(
  events: [
    TodayEventItem(
      id: 'cal_1',
      title: 'Dinner with Sarah at Bastian',
      startTime: DateTime(2026, 10, 15, 20, 0),
      endTime: DateTime(2026, 10, 15, 22, 0),
      location: 'Bandra West',
    ),
  ],
  eventsOnlyCount: 1,
  habits: [
    TodayHabitItem(
      habit: _kSeedHabits[0],
      habitId: 'habit_1',
      habitName: 'Morning Walk Together',
      userCheckedInToday: true,
      partnerCheckedInToday: true,
      partnerAcknowledged: true,
      streak: 12,
      isPrivate: false,
      isOwnedByCurrentUser: true,
    ),
    TodayHabitItem(
      habit: _kSeedHabits[1],
      habitId: 'habit_2',
      habitName: 'Evening Reading (30m)',
      userCheckedInToday: false,
      partnerCheckedInToday: true,
      partnerAcknowledged: false,
      streak: 5,
      isPrivate: false,
      isOwnedByCurrentUser: false,
    ),
  ],
  focusTasks: [
    TodayListItem(
      item: _kSeedListItems[0],
      id: 'item_1',
      title: 'Sourdough country loaf',
      listId: 'list_1',
      listName: 'Groceries',
      isCompleted: false,
    ),
  ],
  listsSummary: const [
    TodayListSummary(listId: 'list_1', name: 'Groceries', openCount: 1),
    TodayListSummary(listId: 'list_2', name: 'Weekend Errands', openCount: 0),
  ],
  todayExpenses: [
    TodayExpenseItem(
      id: 'exp_1',
      title: 'Farmers Market Produce',
      amount: 1450.50,
      category: 'Groceries',
      paymentMethod: 'upi',
      payerName: 'You',
      isCurrentUser: true,
      expenseDate: _kFixedDate,
    ),
  ],
  todaySpendTotal: 1450.50,
  sharedMonthExpensesTotal: 4650.50,
  hasPartner: true,
  userName: 'Alex',
  partnerName: 'Sarah',
  morningQuote: 'Small shared rituals build a quiet sanctuary.',
);

// ---------------------------------------------------------------------------
// Provider Stubs (Following test/expenses_test.dart & test/subscriptions_test.dart)
// ---------------------------------------------------------------------------

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
  }) async =>
      _map[key];
}

class _StubAppDatabase extends Fake implements AppDatabase {
  @override
  Future<int> purgeOrphanedAndArchivedListItems([String? activeHomeId]) async => 0;

  @override
  Future<int> clearProfileActivityEvents() async => 0;

  @override
  Future<void> close() async {}
}

class _FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncData(_kAlexUser);

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

class _FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  @override
  String? build() => 'home_1';

  @override
  void setActiveHome(String homeId) => state = homeId;
}

class _FakeActivePartnerNotifier extends ActiveHomePartnerNotifier {
  @override
  bool build() => true;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => _kSarahPartnerProfile;
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => _kAlexProfile;
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() =>
      const CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee');
}

class _FakeMonthlyBudgetNotifier extends MonthlyBudgetNotifier {
  @override
  double? build() => 85000.0;
}

class _FakeWeatherNotifier extends WeatherNotifier {
  @override
  WeatherData? build() => WeatherData(
        temperatureC: 27.0,
        apparentTemperatureC: 28.0,
        condition: 'Mainly clear',
        weatherCode: 1,
        isDay: true,
        cityName: 'Mumbai',
        latitude: 19.0760,
        longitude: 72.8777,
        updatedAt: _kFixedDate,
      );

  @override
  Future<void> refreshWeather({bool force = false}) async {}
}

class _FakeNotificationPrefsNotifier extends NotificationPreferencesNotifier {
  @override
  NotificationPreferences build() => const NotificationPreferences();
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

List<Override> _createGoldenOverrides() {
  final fakeStorage = _FakeSecureStorage();
  final keyStore = HomeKeyStore(storage: fakeStorage);
  final stubDb = _StubAppDatabase();

  return [
    appDatabaseProvider.overrideWithValue(stubDb),
    homeKeyStoreProvider.overrideWithValue(keyStore),
    backupRemoteProvider.overrideWithValue(FakeBackupRemote()),
    authProvider.overrideWith(_FakeAuthNotifier.new),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    activeHomeProvider.overrideWith((ref) => Stream.value(_kSeedHome)),
    userHomesProvider.overrideWith((ref) => Stream.value([_kSeedHome])),
    activeHomeHasPartnerProvider.overrideWith(_FakeActivePartnerNotifier.new),
    partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
    userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
    currencyPreferenceProvider.overrideWith(_FakeCurrencyNotifier.new),
    monthlyBudgetProvider.overrideWith(_FakeMonthlyBudgetNotifier.new),
    weatherProvider.overrideWith(_FakeWeatherNotifier.new),
    notificationPreferencesProvider.overrideWith(_FakeNotificationPrefsNotifier.new),
    activityReadStatusProvider.overrideWith(_FakeActivityReadStatusNotifier.new),
    unreadActivityCountProvider.overrideWith((ref) => 0),
    checkinRemindersProvider.overrideWith(_FakeReminderNotifier.new),
    activeHomeExpensesProvider.overrideWith((ref) => Stream.value(_kSeedExpenses)),
    activeHomeSubscriptionsProvider.overrideWith((ref) => Stream.value(_kSeedSubscriptions)),
    activeHomeCalendarEventsProvider.overrideWith((ref) => Stream.value(_kSeedCalendarEvents)),
    activeHomeListsProvider.overrideWith((ref) => Stream.value(_kSeedLists)),
    activeHomeAllListItemsProvider.overrideWith((ref) => Stream.value(_kSeedListItems)),
    activeHomeListItemsProvider('list_1').overrideWith(
      (ref) => Stream.value(_kSeedListItems.where((i) => i.listId == 'list_1').toList()),
    ),
    activeHomeListItemsProvider('list_2').overrideWith(
      (ref) => Stream.value(_kSeedListItems.where((i) => i.listId == 'list_2').toList()),
    ),
    activeHomeHabitsProvider.overrideWith((ref) => Stream.value(_kSeedHabits)),
    activeHomeAllHabitCheckinsProvider.overrideWith((ref) => Stream.value(_kSeedHabitCheckins)),
    activeHomeRoutinesProvider.overrideWith((ref) => Stream.value(_kSeedRoutines)),
    activeHomeAllRoutineEventsProvider.overrideWith((ref) => Stream.value(_kSeedRoutineEvents)),
    routineEventsProvider('routine_1').overrideWith((ref) => Stream.value(_kSeedRoutineEvents)),
    routineEventsProvider('routine_2').overrideWith((ref) => Stream.value(const [])),
    routineControllerProvider.overrideWith((ref) => _StubRoutineController(ref)),
    listControllerProvider.overrideWith((ref) => _StubListController(ref)),
    activeHomeOutboxProvider.overrideWith((ref) => Stream.value(const [])),
    todayDataProvider.overrideWithValue(_kSeedTodayData),
    coveEmitActionProvider.overrideWithValue(
      ({required String eventType, required Map<String, dynamic> payload, String? targetHomeId}) async {},
    ),
  ];
}

/// Explicit allow-list of `<screen>.<width>` pairs known to overflow in the
/// pre-revamp v1 layouts (Phase 3 overflow backlog). Any overflow on a pair
/// not in this set fails the test immediately.
const Set<String> _kKnownLegacyOverflows = {};

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Baseline Screen Goldens (14 screens x 3 widths x 2 modes = 84 goldens)', () {
    testWidgets('today_screen', (tester) async {
      await goldenMatrix(
        tester,
        'today_screen',
        const TodayScreen(),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('calendar_screen', (tester) async {
      await goldenMatrix(
        tester,
        'calendar_screen',
        CalendarScreen(
          initialEvents: _kSeedCalendarEvents,
          initialSubscriptions: _kSeedSubscriptions,
          initialSelectedDate: _kFixedDate,
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('expenses_screen', (tester) async {
      await goldenMatrix(
        tester,
        'expenses_screen',
        ExpensesScreen(initialExpenses: _kSeedExpenses),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('subscriptions_screen', (tester) async {
      await goldenMatrix(
        tester,
        'subscriptions_screen',
        const SubscriptionsScreen(),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('emi_tracker_screen', (tester) async {
      await goldenMatrix(
        tester,
        'emi_tracker_screen',
        EmiTrackerScreen(initialSubscriptions: _kSeedSubscriptions),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('commitments_helicopter_screen', (tester) async {
      await goldenMatrix(
        tester,
        'commitments_helicopter_screen',
        CommitmentsHelicopterScreen(
          subscriptions: _kSeedSubscriptions,
          initialYear: 2026,
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('routine_screen', (tester) async {
      await goldenMatrix(
        tester,
        'routine_screen',
        const RoutineScreen(),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('activity_screen', (tester) async {
      await goldenMatrix(
        tester,
        'activity_screen',
        ActivityScreen(initialActivities: _kSeedActivities),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('home_settings_screen', (tester) async {
      await goldenMatrix(
        tester,
        'home_settings_screen',
        const HomeSettingsScreen(),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('profile_screen', (tester) async {
      await goldenMatrix(
        tester,
        'profile_screen',
        ProfileScreen(
          initialProfile: _kAlexProfile,
          initialHome: _kSeedHome,
          initialHomes: [_kSeedHome],
          initialHomeMetadata: _kSeedHomeMetadata,
          initialDriveBackupState: _kSeedBackupState,
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('expense_detail_sheet', (tester) async {
      await goldenMatrix(
        tester,
        'expense_detail_sheet',
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ExpenseDetailSheet(expense: _kSeedExpenses.first),
          ),
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('list_item_detail_sheet', (tester) async {
      await goldenMatrix(
        tester,
        'list_item_detail_sheet',
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ListItemDetailSheet(
              item: _kSeedListItems.first,
              listName: _kSeedLists.first.name,
            ),
          ),
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('habit_detail_sheet', (tester) async {
      await goldenMatrix(
        tester,
        'habit_detail_sheet',
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: HabitDetailSheet(
              habit: _kSeedHabits.first,
              checkins: _kSeedHabitCheckins,
            ),
          ),
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('category_detail_sheet', (tester) async {
      final totalMonthSpend = _kSeedExpenses.fold<double>(
        0.0,
        (acc, e) => acc + e.amount,
      );
      await goldenMatrix(
        tester,
        'category_detail_sheet',
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CategoryDetailSheet(
              initialCategoryName: 'Groceries',
              allExpenses: _kSeedExpenses,
              totalMonthSpend: totalMonthSpend,
            ),
          ),
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('commitment_detail_sheet', (tester) async {
      await goldenMatrix(
        tester,
        'commitment_detail_sheet',
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CommitmentDetailSheet(
              subscription: _kSeedSubscriptions.first,
            ),
          ),
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('commitment_detail_sheet_emi', (tester) async {
      await goldenMatrix(
        tester,
        'commitment_detail_sheet_emi',
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CommitmentDetailSheet(
              subscription: _kSeedSubscriptions[1],
            ),
          ),
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('activity_detail_sheet', (tester) async {
      await goldenMatrix(
        tester,
        'activity_detail_sheet',
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CalendarEventDetailSheet(
              event: _kSeedCalendarEvents.first,
            ),
          ),
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('lists_screen', (tester) async {
      await goldenMatrix(
        tester,
        'lists_screen',
        ListsScreen(
          initialLists: _kSeedLists,
          initialItems: _kSeedListItems,
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('habits_screen', (tester) async {
      await goldenMatrix(
        tester,
        'habits_screen',
        HabitsScreen(
          initialHabits: _kSeedHabits,
          initialCheckins: _kSeedHabitCheckins,
          currentUser: _kAlexUser,
        ),
        overrides: _createGoldenOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });
  });
}
