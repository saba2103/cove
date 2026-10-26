import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_seed_card.dart';
import 'package:cove/core/widgets/cove_starter_row.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/add/add_flow.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden/golden_harness.dart';

final DateTime _kFixedDate = DateTime(2026, 10, 21, 9, 41); // Wednesday

const CoveUser _kSabaUser = CoveUser(
  id: 'user_1',
  email: 'saba@cove.local',
  displayName: 'Saba',
);

const UserProfileState _kSabaProfile = UserProfileState(
  displayName: 'Saba',
  email: 'saba@cove.local',
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

class _TestActiveHomeNotifier extends ActiveHomeNotifier {
  @override
  String? build() => 'home_1';
}

class _FakeActivePartnerNotifier extends ActiveHomePartnerNotifier {
  final bool _hasPartner;
  _FakeActivePartnerNotifier([this._hasPartner = false]);

  @override
  bool build() => _hasPartner;
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

class _NoSeedRoutineController extends RoutineController {
  _NoSeedRoutineController(super.ref);

  @override
  Future<void> seedDefaultRoutinesIfEmpty() async {}
}

class _NoSeedListController extends ListController {
  _NoSeedListController(super.ref);

  @override
  Future<void> ensureDefaultLists() async {}
}

class _ConfigurablePartnerProfileNotifier extends PartnerProfileNotifier {
  final PartnerProfileState _initial;
  _ConfigurablePartnerProfileNotifier(this._initial);

  @override
  PartnerProfileState build() => _initial;
}

Stream<T> _notifierStream<T>(Ref ref, ValueNotifier<T> notifier) {
  final controller = StreamController<T>();
  controller.add(notifier.value);
  void listener() {
    if (!controller.isClosed) {
      controller.add(notifier.value);
    }
  }

  notifier.addListener(listener);
  ref.onDispose(() {
    notifier.removeListener(listener);
    controller.close();
  });
  return controller.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await loadCoveFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PartnerProfileNotifier.resetCache();
  });

  List<Override> buildOverrides({
    PartnerProfileState partnerProfile = const PartnerProfileState(
      displayName: 'Partner',
      hasCustomName: false,
    ),
    ValueNotifier<List<LocalExpense>>? expensesNotifier,
    ValueNotifier<List<LocalCalendarEvent>>? eventsNotifier,
    ValueNotifier<List<Routine>>? routinesNotifier,
    ValueNotifier<List<RoutineEvent>>? routineEventsNotifier,
  }) {
    final stubDb = _StubAppDatabase();
    final effectiveExpenses =
        expensesNotifier ?? ValueNotifier<List<LocalExpense>>(const []);
    final effectiveEvents =
        eventsNotifier ?? ValueNotifier<List<LocalCalendarEvent>>(const []);
    final effectiveRoutines =
        routinesNotifier ?? ValueNotifier<List<Routine>>(const []);
    final effectiveRoutineEvents =
        routineEventsNotifier ?? ValueNotifier<List<RoutineEvent>>(const []);

    return [
      appDatabaseProvider.overrideWithValue(stubDb),
      authProvider.overrideWith(_FakeAuthNotifier.new),
      activeHomeIdProvider.overrideWith(_TestActiveHomeNotifier.new),
      activeHomeProvider.overrideWith((ref) => Stream.value(_kSeedHome)),
      userHomesProvider.overrideWith((ref) => Stream.value([_kSeedHome])),
      activeHomeHasPartnerProvider.overrideWith(_FakeActivePartnerNotifier.new),
      partnerProfileProvider.overrideWith(
        () => _ConfigurablePartnerProfileNotifier(partnerProfile),
      ),
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
      activeHomeExpensesProvider.overrideWith(
        (ref) => _notifierStream(ref, effectiveExpenses),
      ),
      activeHomeSubscriptionsProvider
          .overrideWith((ref) => Stream.value(const [])),
      activeHomeCalendarEventsProvider.overrideWith(
        (ref) => _notifierStream(ref, effectiveEvents),
      ),
      activeHomeListsProvider.overrideWith((ref) => Stream.value(const [])),
      activeHomeAllListItemsProvider
          .overrideWith((ref) => Stream.value(const [])),
      activeHomeHabitsProvider.overrideWith((ref) => Stream.value(const [])),
      activeHomeAllHabitCheckinsProvider
          .overrideWith((ref) => Stream.value(const [])),
      activeHomeRoutinesProvider.overrideWith(
        (ref) => _notifierStream(ref, effectiveRoutines),
      ),
      activeHomeAllRoutineEventsProvider.overrideWith(
        (ref) => _notifierStream(ref, effectiveRoutineEvents),
      ),
      routineEventsProvider.overrideWith(
        (ref, routineId) => _notifierStream(ref, effectiveRoutineEvents).map(
          (list) => list.where((e) => e.routineId == routineId).toList(),
        ),
      ),
      routineControllerProvider
          .overrideWith((ref) => _NoSeedRoutineController(ref)),
      listControllerProvider.overrideWith((ref) => _NoSeedListController(ref)),
      activeHomeOutboxProvider.overrideWith((ref) => Stream.value(const [])),
    ];
  }

  Widget wrapScreen(
    Widget child, {
    required List<Override> overrides,
    Key? scopeKey,
  }) {
    return ProviderScope(
      key: scopeKey,
      overrides: overrides,
      child: MaterialApp(
        theme: CoveTheme.darkTheme,
        home: Scaffold(body: child),
      ),
    );
  }

  group('4.2b — Today first-run', () {
    testWidgets(
      'renders exact spec copy with "your partner" before partner joins '
      'and "{partner}" when partner is named, and opens AddFlow from button + starter rows',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await withClock(Clock.fixed(_kFixedDate), () async {
          // 1. Before partner joins: "your partner can add to it too"
          await tester.pumpWidget(
            wrapScreen(
              const TodayScreen(),
              scopeKey: const ValueKey('scope_no_partner'),
              overrides: buildOverrides(),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsOneWidget);
          expect(find.text('Your first day in Cove'), findsOneWidget);
          expect(
            find.text(
              'Nothing here is made up. The page fills as the two of you put '
              'things in it — one line is enough to start.',
            ),
            findsOneWidget,
          );
          expect(find.text('Add the first thing'), findsOneWidget);
          expect(find.text('Or try one of these:'), findsOneWidget);
          expect(find.byType(CoveStarterRow), findsNWidgets(3));
          expect(find.text('Log what you spent today'), findsOneWidget);
          expect(find.text('a coffee, the auto, the groceries'), findsOneWidget);
          expect(find.text('Start the grocery list'), findsOneWidget);
          expect(find.text('your partner can add to it too'), findsOneWidget);
          expect(find.text('Put something on the calendar'), findsOneWidget);
          expect(find.text('the thing you keep forgetting'), findsOneWidget);
          expect(
            find.text('The letter writes itself once there is a day to read.'),
            findsOneWidget,
          );
          expect(find.text('Come back tomorrow morning.'), findsOneWidget);

          // Metric figures are em-dashes with exact first-run subtitles
          expect(find.text('—'), findsNWidgets(4));
          expect(find.text('nothing yet'), findsOneWidget);
          expect(find.text('nothing on'), findsOneWidget);
          expect(find.text('none kept yet'), findsOneWidget);
          expect(find.text('nothing on it'), findsOneWidget);

          // 2. With named partner "Ancy": "Ancy can add to it too"
          await tester.pumpWidget(
            wrapScreen(
              const TodayScreen(),
              scopeKey: const ValueKey('scope_ancy'),
              overrides: buildOverrides(
                partnerProfile: const PartnerProfileState(
                  displayName: 'Ancy',
                  hasCustomName: true,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Ancy can add to it too'), findsOneWidget);

          // 3. Tapping seed button "Add the first thing" opens Add picker (initialKind == null)
          await tester.tap(find.text('Add the first thing'));
          await tester.pumpAndSettle();
          expect(find.byType(AddFlow), findsOneWidget);
          expect(
            tester.widget<AddFlow>(find.byType(AddFlow)).initialKind,
            isNull,
          );
          expect(
            find.byKey(const ValueKey('add_picker_tile_expense')),
            findsOneWidget,
          );
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // 4. Tapping starter row 1 opens Add · expense
          await tester.tap(find.text('Log what you spent today'));
          await tester.pumpAndSettle();
          expect(find.byType(AddFlow), findsOneWidget);
          expect(
            tester.widget<AddFlow>(find.byType(AddFlow)).initialKind,
            AddKind.expense,
          );
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // 5. Tapping starter row 2 opens Add · task
          await tester.tap(find.text('Start the grocery list'));
          await tester.pumpAndSettle();
          expect(find.byType(AddFlow), findsOneWidget);
          expect(
            tester.widget<AddFlow>(find.byType(AddFlow)).initialKind,
            AddKind.task,
          );
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // 6. Tapping starter row 3 opens Add · event
          await tester.tap(find.text('Put something on the calendar'));
          await tester.pumpAndSettle();
          expect(find.byType(AddFlow), findsOneWidget);
          expect(
            tester.widget<AddFlow>(find.byType(AddFlow)).initialKind,
            AddKind.event,
          );
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();
        });
      },
    );

    testWidgets(
      'leaves first-run after its first record and does not return after delete',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final expensesNotifier = ValueNotifier<List<LocalExpense>>(const []);

        await withClock(Clock.fixed(_kFixedDate), () async {
          await tester.pumpWidget(
            wrapScreen(
              const TodayScreen(),
              overrides: buildOverrides(expensesNotifier: expensesNotifier),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Your first day in Cove'), findsOneWidget);

          // Add first record (an expense)
          expensesNotifier.value = [
            LocalExpense(
              id: 'exp_1',
              homeId: 'home_1',
              title: 'Coffee',
              amount: 180.0,
              currency: 'INR',
              category: 'Dining',
              paidBy: 'user_1',
              splitRatio: 0.5,
              isTransfer: false,
              expenseDate: _kFixedDate,
              createdAt: _kFixedDate,
            ),
          ];
          await tester.pumpAndSettle();

          expect(find.text('Your first day in Cove'), findsNothing);
          expect(find.byType(CoveSeedCard), findsNothing);

          // Delete that record -> Today stays out of first-run
          expensesNotifier.value = const [];
          await tester.pumpAndSettle();

          expect(find.text('Your first day in Cove'), findsNothing);
          expect(find.byType(CoveSeedCard), findsNothing);
          expect(find.text('Nothing spent today.'), findsOneWidget);
        });
      },
    );
  });

  group('4.2b — Calendar first-run', () {
    testWidgets(
      'renders exact spec copy, updates weekday on day selection, '
      'opens AddFlow anchored to selected date, and leaves first-run permanently after first record',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final eventsNotifier =
            ValueNotifier<List<LocalCalendarEvent>>(const []);

        await withClock(Clock.fixed(_kFixedDate), () async {
          await tester.pumpWidget(
            wrapScreen(
              CalendarScreen(initialSelectedDate: _kFixedDate),
              overrides: buildOverrides(eventsNotifier: eventsNotifier),
            ),
          );
          await tester.pumpAndSettle();

          // Today is Wednesday, Oct 21
          expect(find.byType(CoveSeedCard), findsOneWidget);
          expect(find.text('An empty Wednesday'), findsOneWidget);
          expect(
            find.text(
              'Events, spending, habits and list lines all land on a date. '
              'Put one here and the day starts holding things.',
            ),
            findsOneWidget,
          );
          expect(find.text('Add to today'), findsOneWidget);
          expect(find.text('Nothing is due this month either.'), findsOneWidget);
          expect(find.text('—'), findsNWidgets(4));

          // Tapping "Add to today" opens Add picker anchored to today (Oct 21)
          await tester.tap(find.text('Add to today'));
          await tester.pumpAndSettle();
          expect(find.byType(AddFlow), findsOneWidget);
          final addToday = tester.widget<AddFlow>(find.byType(AddFlow));
          expect(addToday.initialKind, isNull);
          expect(addToday.anchor?.year, 2026);
          expect(addToday.anchor?.month, 10);
          expect(addToday.anchor?.day, 21);
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // Select Thursday (22) in the date strip -> "An empty Thursday" and "Add to Thursday"
          await tester.tap(find.text('22'));
          await tester.pumpAndSettle();
          expect(find.text('An empty Thursday'), findsOneWidget);
          expect(find.text('Add to Thursday'), findsOneWidget);

          // Tapping "Add to Thursday" opens Add picker anchored to Oct 22
          await tester.tap(find.text('Add to Thursday'));
          await tester.pumpAndSettle();
          expect(find.byType(AddFlow), findsOneWidget);
          final addThu = tester.widget<AddFlow>(find.byType(AddFlow));
          expect(addThu.initialKind, isNull);
          expect(addThu.anchor?.day, 22);
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // Insert a calendar event -> leaves first-run
          eventsNotifier.value = [
            LocalCalendarEvent(
              id: 'evt_1',
              homeId: 'home_1',
              title: 'Dinner',
              startTime: _kFixedDate,
              endTime: _kFixedDate.add(const Duration(hours: 1)),
              isAllDay: false,
              createdBy: 'user_1',
              createdAt: _kFixedDate,
            ),
          ];
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);
          expect(find.text('An empty Thursday'), findsNothing);

          // Delete the calendar event -> stays in post-first-run empty state
          eventsNotifier.value = const [];
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);
          expect(
            find.text('Nothing on the calendar for this day.'),
            findsOneWidget,
          );
        });
      },
    );
  });

  group('4.2b — Routines first-run', () {
    testWidgets(
      'renders exact spec copy with "your partner\'s" before join and "{partner}\'s" when named, '
      'opens Add · routine from seed button, and leaves first-run permanently after first block',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final routinesNotifier = ValueNotifier<List<Routine>>(const []);
        final routineEventsNotifier =
            ValueNotifier<List<RoutineEvent>>(const []);

        await withClock(Clock.fixed(_kFixedDate), () async {
          // 1. Before partner joins: "Yours on the left, your partner's on the right."
          await tester.pumpWidget(
            wrapScreen(
              const RoutineScreen(),
              scopeKey: const ValueKey('routines_no_partner'),
              overrides: buildOverrides(
                routinesNotifier: routinesNotifier,
                routineEventsNotifier: routineEventsNotifier,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsOneWidget);
          expect(find.text('Two days, not yet drawn'), findsOneWidget);
          expect(
            find.text(
              'A routine is the shape a day repeats — the walk, the standing '
              'call, lights out. Add a few and the sky fills in behind them.',
            ),
            findsOneWidget,
          );
          expect(find.text('Add a routine'), findsOneWidget);
          expect(
            find.text("Yours on the left, your partner's on the right."),
            findsOneWidget,
          );
          expect(find.text('EVERYDAY'), findsOneWidget);
          expect(find.text('WEEKDAYS'), findsOneWidget);
          expect(find.text('Nothing repeats yet.'), findsNWidgets(2));

          // 2. With named partner "Ancy": "Yours on the left, Ancy's on the right."
          await tester.pumpWidget(
            wrapScreen(
              const RoutineScreen(),
              scopeKey: const ValueKey('routines_ancy'),
              overrides: buildOverrides(
                partnerProfile: const PartnerProfileState(
                  displayName: 'Ancy',
                  hasCustomName: true,
                ),
                routinesNotifier: routinesNotifier,
                routineEventsNotifier: routineEventsNotifier,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text("Yours on the left, Ancy's on the right."),
            findsOneWidget,
          );

          // 3. Tapping "Add a routine" opens Add · routine
          await tester.tap(find.text('Add a routine'));
          await tester.pumpAndSettle();
          expect(find.byType(AddFlow), findsOneWidget);
          expect(
            tester.widget<AddFlow>(find.byType(AddFlow)).initialKind,
            AddKind.routine,
          );
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // 4. Add a routine + routine block -> leaves first-run
          routinesNotifier.value = [
            Routine(
              id: 'rt_1',
              homeId: 'home_1',
              name: 'Everyday',
              days: const [1, 2, 3, 4, 5, 6, 7],
              createdAt: _kFixedDate,
            ),
          ];
          routineEventsNotifier.value = [
            RoutineEvent(
              id: 're_1',
              routineId: 'rt_1',
              homeId: 'home_1',
              title: 'Morning walk',
              startMinutes: 420,
              endMinutes: 450,
              category: 'Health',
              createdAt: _kFixedDate,
            ),
          ];
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);
          expect(find.text('Two days, not yet drawn'), findsNothing);
          expect(find.text('Morning walk'), findsOneWidget);

          // 5. Delete the routine block -> does NOT return to first-run
          routineEventsNotifier.value = const [];
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);
          expect(find.text('Two days, not yet drawn'), findsNothing);
        });
      },
    );
  });
}
