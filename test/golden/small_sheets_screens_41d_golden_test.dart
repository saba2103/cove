import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_controller.dart';
import 'package:cove/features/calendar/calendar_models.dart';
import 'package:cove/features/calendar/views/calendar_month_view.dart';
import 'package:cove/features/expenses/monthly_budget_controller.dart';
import 'package:cove/features/expenses/monthly_budget_sheet.dart';
import 'package:cove/features/lists/create_list_dialog.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/reminders/reminder_controller.dart';
import 'package:cove/features/reminders/reminder_models.dart';
import 'package:cove/features/reminders/reminders_screen.dart';
import 'package:cove/features/roadmap/roadmap_controller.dart';
import 'package:cove/features/roadmap/roadmap_screen.dart';
import 'package:cove/features/subscriptions/commitment_projection_utils.dart';
import 'package:cove/features/subscriptions/month_commitments_sheet.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/features/weather/widgets/dashboard_weather_badge.dart';
import 'package:cove/features/weather/widgets/weather_detail_sheet.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

final _kFixedDate = DateTime(2026, 10, 22, 10, 30);

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

final _kWeatherData = WeatherData(
  cityName: 'Bengaluru',
  temperatureC: 24.0,
  apparentTemperatureC: 25.0,
  weatherCode: 1,
  isDay: true,
  condition: 'Mainly Clear',
  updatedAt: _kFixedDate,
  latitude: 12.9716,
  longitude: 77.5946,
  isLiveGps: true,
);

final _kSeedReminders = <CheckinReminder>[
  CheckinReminder(
    id: 'rem_1',
    hour: 20,
    minute: 30,
    message: 'A quiet moment for us • Check in on our sanctuary',
    isEnabled: true,
    createdAt: _kFixedDate,
  ),
  CheckinReminder(
    id: 'rem_2',
    hour: 9,
    minute: 0,
    message: 'Morning coffee alignment & today’s rhythm',
    isEnabled: false,
    createdAt: _kFixedDate,
  ),
];

final _kSeedRoadmapItems = <LocalRoadmapItem>[
  LocalRoadmapItem(
    id: 'wish_1',
    homeId: 'home_1',
    title: 'Shared Spotify evening queue',
    description: 'Link our favourite playlists for dinner prep',
    isCompleted: false,
    createdBy: 'user_alex',
    createdAt: DateTime(2026, 10, 12),
  ),
  LocalRoadmapItem(
    id: 'wish_2',
    homeId: 'home_1',
    title: 'Anniversary countdown slip',
    description: 'A warm paper keepsake on Today',
    isCompleted: false,
    createdBy: 'user_sarah',
    createdAt: DateTime(2026, 10, 15),
  ),
  LocalRoadmapItem(
    id: 'wish_3',
    homeId: 'home_1',
    title: 'Encrypted Google Drive backup',
    description: 'Nightly zero-knowledge backup',
    isCompleted: true,
    completedAt: DateTime(2026, 10, 18),
    createdBy: 'user_alex',
    createdAt: DateTime(2026, 10, 1),
  ),
];

final _kSubNetflix = LocalSubscription(
  id: 'sub_1',
  homeId: 'home_1',
  name: 'Netflix 4K',
  amount: 649.0,
  currency: 'INR',
  billingCycle: 'monthly',
  nextBillingDate: DateTime(2026, 10, 15),
  category: 'Streaming',
  isActive: true,
  isPrivate: false,
  createdBy: 'user_alex',
  paidBy: 'split',
  createdAt: _kFixedDate,
);

final _kSubCarEmi = LocalSubscription(
  id: 'sub_2',
  homeId: 'home_1',
  name: 'Car Loan EMI',
  amount: 18500.0,
  currency: 'INR',
  billingCycle: 'monthly',
  nextBillingDate: DateTime(2026, 10, 5),
  category: 'Finance',
  isActive: true,
  isPrivate: false,
  createdBy: 'user_alex',
  paidBy: 'user_alex',
  financedThrough: 'HDFC Bank',
  totalInstallments: 36,
  paidInstallments: 12,
  createdAt: _kFixedDate,
);

final _kSubGym = LocalSubscription(
  id: 'sub_3',
  homeId: 'home_1',
  name: 'Pilates Studio',
  amount: 4200.0,
  currency: 'INR',
  billingCycle: 'yearly',
  nextBillingDate: DateTime(2026, 10, 22),
  category: 'Health',
  isActive: true,
  isPrivate: false,
  createdBy: 'user_sarah',
  paidBy: 'user_sarah',
  createdAt: _kFixedDate,
);

final _kMonthSummary = MonthCommitmentSummary(
  year: 2026,
  month: 10,
  items: [
    ProjectedCommitmentItem(
      subscription: _kSubCarEmi,
      projectedDate: DateTime(2026, 10, 5),
      amount: 18500.0,
      isEmi: true,
      isAnnual: false,
    ),
    ProjectedCommitmentItem(
      subscription: _kSubNetflix,
      projectedDate: DateTime(2026, 10, 15),
      amount: 649.0,
      isEmi: false,
      isAnnual: false,
    ),
    ProjectedCommitmentItem(
      subscription: _kSubGym,
      projectedDate: DateTime(2026, 10, 22),
      amount: 4200.0,
      isEmi: false,
      isAnnual: true,
    ),
  ],
);

final _kCalendarEvent = LocalCalendarEvent(
  id: 'ev_1',
  homeId: 'home_1',
  title: 'Dinner at Sienna',
  startTime: DateTime(2026, 10, 22, 19, 30),
  endTime: DateTime(2026, 10, 22, 21, 30),
  isAllDay: false,
  recurrence: 'none',
  createdBy: 'user_alex',
  createdAt: _kFixedDate,
);

class _StubAppDatabase extends Fake implements AppDatabase {
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
  double? build() => 75000.0;
}

class _FakeReminderNotifier extends ReminderNotifier {
  @override
  List<CheckinReminder> build() => _kSeedReminders;
}

class _FakeWeatherNotifier extends WeatherNotifier {
  @override
  WeatherData? build() => _kWeatherData;
}

List<Override> _createOverrides() {
  final stubDb = _StubAppDatabase();

  return [
    appDatabaseProvider.overrideWithValue(stubDb),
    authProvider.overrideWith(_FakeAuthNotifier.new),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
    userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
    currencyPreferenceProvider.overrideWith(_FakeCurrencyNotifier.new),
    monthlyBudgetProvider.overrideWith(_FakeMonthlyBudgetNotifier.new),
    checkinRemindersProvider.overrideWith(_FakeReminderNotifier.new),
    activeHomeRoadmapProvider.overrideWith(
      (ref) => Stream.value(_kSeedRoadmapItems),
    ),
    weatherProvider.overrideWith(_FakeWeatherNotifier.new),
    unifiedCalendarEntriesProvider.overrideWith((ref, window) {
      return {
        DateTime(2026, 10, 22): [
          CalendarEventEntry(_kCalendarEvent),
          CalendarSubscriptionEntry(
            subscription: _kSubGym,
            renewalDate: DateTime(2026, 10, 22),
          ),
        ],
        DateTime(2026, 10, 15): [
          CalendarSubscriptionEntry(
            subscription: _kSubNetflix,
            renewalDate: DateTime(2026, 10, 15),
          ),
        ],
      };
    }),
  ];
}

const Set<String> _kKnownLegacyOverflows = {};

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('4.1d before/after golden: monthly_budget_sheet', (tester) async {
    await goldenMatrix(
      tester,
      'small_41d_monthly_budget_sheet',
      const Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: MonthlyBudgetSheet(),
        ),
      ),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1d before/after golden: month_commitments_sheet',
      (tester) async {
    await goldenMatrix(
      tester,
      'small_41d_month_commitments_sheet',
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: MonthCommitmentsSheet(summary: _kMonthSummary),
        ),
      ),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1d before/after golden: reminders_screen', (tester) async {
    await goldenMatrix(
      tester,
      'small_41d_reminders_screen',
      const RemindersScreen(),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1d before/after golden: roadmap_screen', (tester) async {
    await goldenMatrix(
      tester,
      'small_41d_roadmap_screen',
      const RoadmapScreen(),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1d before/after golden: weather_detail_sheet', (tester) async {
    await goldenMatrix(
      tester,
      'small_41d_weather_detail_sheet',
      Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: WeatherDetailSheet(weather: _kWeatherData),
        ),
      ),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1d before/after golden: dashboard_weather_badge',
      (tester) async {
    await goldenMatrix(
      tester,
      'small_41d_dashboard_weather_badge',
      const Scaffold(
        body: Center(
          child: DashboardWeatherBadge(),
        ),
      ),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1d before/after golden: calendar_month_view', (tester) async {
    await goldenMatrix(
      tester,
      'small_41d_calendar_month_view',
      Scaffold(
        body: CalendarMonthView(
          events: [_kCalendarEvent],
          subscriptions: [_kSubNetflix, _kSubCarEmi, _kSubGym],
          outboxEvents: const [],
          selectedDate: DateTime(2026, 10, 22),
          onSelectDate: (_) {},
          onAddEvent: () {},
        ),
      ),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });

  testWidgets('4.1d before/after golden: create_list_dialog', (tester) async {
    await goldenMatrix(
      tester,
      'small_41d_create_list_dialog',
      const Scaffold(
        body: Center(
          child: CreateListDialog(),
        ),
      ),
      overrides: _createOverrides(),
      wrap: wrapInAppShellConstraint,
      allowedOverflows: _kKnownLegacyOverflows,
    );
  });
}
