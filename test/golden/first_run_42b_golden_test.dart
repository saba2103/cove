import 'package:clock/clock.dart';
import 'package:cove/features/activity/activity_read_status_controller.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_screen.dart';
import 'package:cove/features/expenses/monthly_budget_controller.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/notifications/notification_controller.dart';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/reminders/reminder_controller.dart';
import 'package:cove/features/reminders/reminder_models.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/routines/routine_screen.dart';
import 'package:cove/features/today/today_screen.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/providers/first_run_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

const Set<String> _kNoOverflows = <String>{};

final DateTime _kFixedDate = DateTime(2026, 10, 21, 9, 41);

const CoveUser _kSabaUser = CoveUser(
  id: 'user_1',
  email: 'saba@cove.local',
  displayName: 'Saba',
);

const UserProfileState _kSabaProfile = UserProfileState(
  displayName: 'Saba',
  email: 'saba@cove.local',
);

const PartnerProfileState _kAncyPartnerProfile = PartnerProfileState(
  displayName: 'Ancy',
  hasCustomName: true,
);

final LocalHome _kSeedHome = LocalHome(
  id: 'home_1',
  name: 'The Nest',
  description: 'Bengaluru',
  currency: 'INR',
  createdAt: _kFixedDate,
  createdBy: 'user_1',
);

class _StubAppDatabase extends Fake implements AppDatabase {
  @override
  Future<int> purgeOrphanedAndArchivedListItems([String? activeHomeId]) async =>
      0;

  @override
  Future<int> clearProfileActivityEvents() async => 0;

  @override
  Future<void> close() async {}
}

class _FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncData(_kSabaUser);

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

class _FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  @override
  String? build() => 'home_1';

  @override
  void setActiveHome(String homeId) => state = homeId;
}

class _FakeActivePartnerNotifier extends ActiveHomePartnerNotifier {
  @override
  bool build() => false;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => _kAncyPartnerProfile;
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => _kSabaProfile;
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() =>
      const CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee');
}

class _FakeMonthlyBudgetNotifier extends MonthlyBudgetNotifier {
  @override
  double? build() => null;
}

class _FakeWeatherNotifier extends WeatherNotifier {
  @override
  WeatherData? build() => WeatherData(
        temperatureC: 24.0,
        apparentTemperatureC: 25.0,
        condition: 'Mainly clear',
        weatherCode: 1,
        isDay: true,
        cityName: 'Bengaluru',
        latitude: 12.9716,
        longitude: 77.5946,
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

List<Override> _createFirstRunOverrides() {
  final stubDb = _StubAppDatabase();
  return [
    for (final screen in CoveScreen.values)
      firstRunProvider(screen).overrideWithValue(FirstRunState.firstRun),
    appDatabaseProvider.overrideWithValue(stubDb),
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
    notificationPreferencesProvider
        .overrideWith(_FakeNotificationPrefsNotifier.new),
    activityReadStatusProvider
        .overrideWith(_FakeActivityReadStatusNotifier.new),
    unreadActivityCountProvider.overrideWith((ref) => 0),
    checkinRemindersProvider.overrideWith(_FakeReminderNotifier.new),
    activeHomeExpensesProvider.overrideWith((ref) => Stream.value(const [])),
    activeHomeSubscriptionsProvider
        .overrideWith((ref) => Stream.value(const [])),
    activeHomeCalendarEventsProvider
        .overrideWith((ref) => Stream.value(const [])),
    activeHomeListsProvider.overrideWith((ref) => Stream.value(const [])),
    activeHomeAllListItemsProvider
        .overrideWith((ref) => Stream.value(const [])),
    activeHomeHabitsProvider.overrideWith((ref) => Stream.value(const [])),
    activeHomeAllHabitCheckinsProvider
        .overrideWith((ref) => Stream.value(const [])),
    activeHomeRoutinesProvider
        .overrideWith((ref) => Stream.value(const <Routine>[])),
    activeHomeAllRoutineEventsProvider
        .overrideWith((ref) => Stream.value(const <RoutineEvent>[])),
    routineControllerProvider.overrideWith((ref) => _StubRoutineController(ref)),
    listControllerProvider.overrideWith((ref) => _StubListController(ref)),
    activeHomeOutboxProvider.overrideWith((ref) => Stream.value(const [])),
  ];
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('4.2b First-Run Screen Goldens (Today, Calendar, Routines)', () {
    testWidgets('first_run_42b_today_screen', (tester) async {
      await goldenMatrix(
        tester,
        'first_run_42b_today_screen',
        const TodayScreen(),
        overrides: _createFirstRunOverrides(),
        clock: Clock.fixed(_kFixedDate),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kNoOverflows,
      );
    });

    testWidgets('first_run_42b_calendar_screen', (tester) async {
      await goldenMatrix(
        tester,
        'first_run_42b_calendar_screen',
        CalendarScreen(initialSelectedDate: _kFixedDate),
        overrides: _createFirstRunOverrides(),
        clock: Clock.fixed(_kFixedDate),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kNoOverflows,
      );
    });

    testWidgets('first_run_42b_routine_screen', (tester) async {
      await goldenMatrix(
        tester,
        'first_run_42b_routine_screen',
        const RoutineScreen(),
        overrides: _createFirstRunOverrides(),
        clock: Clock.fixed(_kFixedDate),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kNoOverflows,
      );
    });
  });
}
