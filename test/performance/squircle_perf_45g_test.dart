import 'dart:async' show unawaited;
import 'dart:convert' show jsonEncode;
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/activity/activity_read_status_controller.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/expense_detail_sheet.dart';
import 'package:cove/features/expenses/expenses_screen.dart';
import 'package:cove/features/expenses/monthly_budget_controller.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/lists/lists_screen.dart';
import 'package:cove/features/notifications/notification_controller.dart';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/reminders/reminder_controller.dart';
import 'package:cove/features/reminders/reminder_models.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/today/today_controller.dart';
import 'package:cove/features/today/today_models.dart';
import 'package:cove/features/today/today_screen.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/providers/first_run_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../golden/golden_harness.dart';

final _kFixedDate = DateTime(2026, 10, 15, 10, 30);
final _kFixedCreatedAt = DateTime(2026, 10, 1, 9, 0);

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
  anniversaryDate: DateTime(2023, 6, 15),
  createdAt: _kFixedCreatedAt,
  createdBy: 'user_alex',
);

final _kSeedLists = <LocalList>[
  LocalList(
    id: 'list_1',
    homeId: 'home_1',
    name: 'Groceries',
    isArchived: false,
    createdAt: _kFixedCreatedAt,
    createdBy: 'user_alex',
  ),
];

final _k50ListItems = List<LocalListItem>.generate(
  50,
  (i) => LocalListItem(
    id: 'item_$i',
    homeId: 'home_1',
    listId: 'list_1',
    title: 'Grocery item #${i + 1} — fresh organic produce & pantry goods',
    notes: i % 2 == 0 ? 'Aisle ${(i % 8) + 1} · Pick ripe ones' : null,
    dueDate: i % 3 == 0 ? _kFixedDate : null,
    isCompleted: false,
    createdAt: _kFixedCreatedAt,
    createdBy: i.isEven ? 'user_alex' : 'user_sarah',
  ),
);

const _kCategories = <String>[
  'Groceries',
  'Eating out',
  'Home & Utilities',
  'Fuel',
  'Health',
  'Travel',
  'Gifts',
  'Pets',
];

final _kFullMonthExpenses = List<LocalExpense>.generate(
  45,
  (i) {
    final day = (i % 28) + 1;
    return LocalExpense(
      id: 'exp_$i',
      homeId: 'home_1',
      title: 'Purchase #${i + 1} at ${_kCategories[i % _kCategories.length]}',
      amount: 350.0 + (i * 125.0),
      currency: 'INR',
      paidBy: i.isEven ? 'user_alex' : 'user_sarah',
      splitRatio: 0.5,
      expenseDate: DateTime(2026, 10, day, 12, (i * 7) % 60),
      category: _kCategories[i % _kCategories.length],
      paymentMethod: i.isEven ? 'upi' : 'card',
      isTransfer: false,
      createdAt: DateTime(2026, 10, day, 12, 0),
    );
  },
);

final _kSeedHabits = List<LocalHabit>.generate(
  6,
  (i) => LocalHabit(
    id: 'habit_$i',
    homeId: 'home_1',
    name: 'Daily Ritual #${i + 1}',
    cadence: 'daily',
    targetDaysPerWeek: 7,
    isArchived: false,
    createdAt: _kFixedCreatedAt,
    createdBy: i.isEven ? 'user_alex' : 'user_sarah',
  ),
);

final _kSeedTodayData = TodayData(
  events: List<TodayEventItem>.generate(
    5,
    (i) => TodayEventItem(
      id: 'cal_$i',
      title: 'Shared Plan #${i + 1}',
      startTime: DateTime(2026, 10, 15, 9 + i * 2, 0),
      endTime: DateTime(2026, 10, 15, 10 + i * 2, 0),
      location: 'Bandra West',
    ),
  ),
  eventsOnlyCount: 5,
  habits: List<TodayHabitItem>.generate(
    6,
    (i) => TodayHabitItem(
      habit: _kSeedHabits[i],
      habitId: 'habit_$i',
      habitName: 'Daily Ritual #${i + 1}',
      userCheckedInToday: i.isEven,
      partnerCheckedInToday: true,
      partnerAcknowledged: i.isEven,
      streak: 7 + i,
      isPrivate: false,
      isOwnedByCurrentUser: i.isEven,
    ),
  ),
  focusTasks: List<TodayListItem>.generate(
    8,
    (i) => TodayListItem(
      item: _k50ListItems[i],
      id: 'item_$i',
      title: _k50ListItems[i].title,
      listId: 'list_1',
      listName: 'Groceries',
      isCompleted: false,
    ),
  ),
  listsSummary: const [
    TodayListSummary(listId: 'list_1', name: 'Groceries', openCount: 40),
  ],
  todayExpenses: List<TodayExpenseItem>.generate(
    6,
    (i) => TodayExpenseItem(
      id: 'exp_$i',
      title: _kFullMonthExpenses[i].title,
      amount: _kFullMonthExpenses[i].amount,
      category: _kFullMonthExpenses[i].category ?? 'Groceries',
      paymentMethod: 'upi',
      payerName: i.isEven ? 'You' : 'Sarah',
      isCurrentUser: i.isEven,
      expenseDate: _kFixedDate,
    ),
  ),
  todaySpendTotal: 4250.0,
  sharedMonthExpensesTotal: 48650.0,
  hasPartner: true,
  userName: 'Alex',
  partnerName: 'Sarah',
  morningQuote: 'Small shared rituals build a quiet sanctuary.',
);

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
  Future<int> purgeOrphanedAndArchivedListItems([String? activeHomeId]) async =>
      0;

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
  void signInWithDemoUser([String name = 'Alex', String email = 'a@b.c']) {}
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

List<Override> _buildOverrides() {
  final fakeStorage = _FakeSecureStorage();
  final keyStore = HomeKeyStore(storage: fakeStorage);
  final stubDb = _StubAppDatabase();
  return [
    for (final screen in CoveScreen.values)
      firstRunProvider(screen).overrideWithValue(FirstRunState.inUse),
    appDatabaseProvider.overrideWithValue(stubDb),
    homeKeyStoreProvider.overrideWithValue(keyStore),
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
    activeHomeExpensesProvider
        .overrideWith((ref) => Stream.value(_kFullMonthExpenses)),
    activeHomeSubscriptionsProvider
        .overrideWith((ref) => Stream.value(const <LocalSubscription>[])),
    activeHomeCalendarEventsProvider
        .overrideWith((ref) => Stream.value(const <LocalCalendarEvent>[])),
    activeHomeListsProvider.overrideWith((ref) => Stream.value(_kSeedLists)),
    activeHomeAllListItemsProvider
        .overrideWith((ref) => Stream.value(_k50ListItems)),
    activeHomeListItemsProvider('list_1')
        .overrideWith((ref) => Stream.value(_k50ListItems)),
    activeHomeHabitsProvider.overrideWith((ref) => Stream.value(_kSeedHabits)),
    activeHomeAllHabitCheckinsProvider
        .overrideWith((ref) => Stream.value(const <LocalHabitCheckin>[])),
    activeHomeRoutinesProvider
        .overrideWith((ref) => Stream.value(const <Routine>[])),
    activeHomeAllRoutineEventsProvider
        .overrideWith((ref) => Stream.value(const <RoutineEvent>[])),
    routineControllerProvider.overrideWith((ref) => _StubRoutineController(ref)),
    listControllerProvider.overrideWith((ref) => _StubListController(ref)),
    activeHomeOutboxProvider
        .overrideWith((ref) => Stream.value(const <LocalOutboxEvent>[])),
    todayDataProvider.overrideWithValue(_kSeedTodayData),
    coveEmitActionProvider.overrideWithValue(
      ({
        required String eventType,
        required Map<String, dynamic> payload,
        String? targetHomeId,
      }) async {},
    ),
  ];
}

ScrollPosition? _findMainVerticalScroll(Element root) {
  ScrollPosition? best;
  void visit(Element el) {
    if (el is StatefulElement && el.state is ScrollableState) {
      final s = el.state as ScrollableState;
      final pos = s.position;
      if (pos.axis == Axis.vertical &&
          pos.hasPixels &&
          pos.maxScrollExtent > 0) {
        if (best == null || pos.maxScrollExtent > best!.maxScrollExtent) {
          best = pos;
        }
      }
    }
    el.visitChildren(visit);
  }

  root.visitChildren(visit);
  return best;
}

Map<String, double> _stats(List<double> samples) {
  final sorted = List<double>.from(samples)..sort();
  double pct(double p) {
    final idx = ((sorted.length - 1) * p).round().clamp(0, sorted.length - 1);
    return double.parse(sorted[idx].toStringAsFixed(2));
  }

  return {
    'p50_ms': pct(0.50),
    'p90_ms': pct(0.90),
    'worst_ms': double.parse(sorted.last.toStringAsFixed(2)),
  };
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('4.5g frame-time benchmark across Lists, Expenses, Today, and Detail Sheet (10x)', (
    tester,
  ) async {
    await loadCoveFonts();
    tester.view
      ..physicalSize = CoveWidth.phone * 2
      ..devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final boundaryKey = GlobalKey();
    final navKey = GlobalKey<NavigatorState>();
    final activeScreen = ValueNotifier<Widget>(const SizedBox.shrink());

    await withClock(Clock.fixed(_kFixedDate), () async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _buildOverrides(),
          child: RepaintBoundary(
            key: boundaryKey,
            child: MediaQuery(
              data: const MediaQueryData(
                size: CoveWidth.phone,
                textScaler: TextScaler.linear(1.0),
              ),
              child: MaterialApp(
                navigatorKey: navKey,
                debugShowCheckedModeBanner: false,
                theme: CoveTheme.darkTheme,
                home: ValueListenableBuilder<Widget>(
                  valueListenable: activeScreen,
                  builder: (context, child, _) => Scaffold(
                    backgroundColor: context.cv.surfaceCanvas,
                    body: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<double> pumpAndMeasureFrame(Duration delta) async {
        final sw = Stopwatch()..start();
        await tester.pump(delta);
        // Also force layer tree scene build to include shape clip/border path generation in the paint layer tree
        final boundary = boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        final layer = boundary.debugLayer! as OffsetLayer;
        final builder = ui.SceneBuilder();
        layer.addToScene(builder);
        final scene = builder.build();
        scene.dispose();
        sw.stop();
        return sw.elapsedMicroseconds / 1000.0;
      }

      Future<Map<String, double>> measureScroll(Widget screen) async {
        activeScreen.value = screen;
        await tester.pumpAndSettle();
        final navEl = navKey.currentContext! as Element;
        final pos = _findMainVerticalScroll(navEl)!;
        final maxExtent = pos.maxScrollExtent;
        const steps = 40;
        // Warmup full scroll pass down and back up so all lazy sliver/reorderable children are built & JIT-warmed
        for (var i = 1; i <= steps; i++) {
          pos.jumpTo(maxExtent * (i / steps));
          await pumpAndMeasureFrame(const Duration(milliseconds: 16));
        }
        for (var i = steps - 1; i >= 0; i--) {
          pos.jumpTo(maxExtent * (i / steps));
          await pumpAndMeasureFrame(const Duration(milliseconds: 16));
        }

        final frameTimes = <double>[];
        for (var i = 1; i <= steps; i++) {
          pos.jumpTo(maxExtent * (i / steps));
          frameTimes.add(
            await pumpAndMeasureFrame(const Duration(milliseconds: 16)),
          );
        }
        for (var i = steps - 1; i >= 0; i--) {
          pos.jumpTo(maxExtent * (i / steps));
          frameTimes.add(
            await pumpAndMeasureFrame(const Duration(milliseconds: 16)),
          );
        }
        return _stats(frameTimes);
      }

      Future<Map<String, double>> measureDetailSheet10x() async {
        activeScreen.value = ExpensesScreen(
          initialExpenses: _kFullMonthExpenses,
        );
        await tester.pumpAndSettle();
        final ctx = navKey.currentContext!;
        // Warmup 1 open/close before timing 10 open/close cycles
        unawaited(ExpenseDetailSheet.show(ctx, _kFullMonthExpenses[0]));
        for (var f = 0; f < 4; f++) {
          await pumpAndMeasureFrame(const Duration(milliseconds: 32));
        }
        Navigator.of(ctx).pop();
        for (var f = 0; f < 4; f++) {
          await pumpAndMeasureFrame(const Duration(milliseconds: 32));
        }

        final frameTimes = <double>[];
        for (var i = 0; i < 10; i++) {
          unawaited(ExpenseDetailSheet.show(ctx, _kFullMonthExpenses[i % 10]));
          for (var f = 0; f < 8; f++) {
            frameTimes.add(
              await pumpAndMeasureFrame(const Duration(milliseconds: 32)),
            );
          }
          Navigator.of(ctx).pop();
          for (var f = 0; f < 8; f++) {
            frameTimes.add(
              await pumpAndMeasureFrame(const Duration(milliseconds: 32)),
            );
          }
        }
        return _stats(frameTimes);
      }

      SquirclePathCache.clear();
      final listsWidget = ListsScreen(
        initialLists: _kSeedLists,
        initialItems: _k50ListItems,
      );
      final expensesWidget = ExpensesScreen(
        initialExpenses: _kFullMonthExpenses,
      );
      const todayWidget = TodayScreen();

      // Warmup first-run JIT across all 4 flows before recording steady-state frame times
      await measureScroll(listsWidget);
      SquirclePathCache.resetStats();

      final listsStats = await measureScroll(listsWidget);
      final expensesStats = await measureScroll(expensesWidget);
      final todayStats = await measureScroll(todayWidget);
      final sheetStats = await measureDetailSheet10x();

      final summary = {
        'lists_50_items': listsStats,
        'expenses_full_month': expensesStats,
        'today': todayStats,
        'detail_sheet_10x': sheetStats,
        'cache_hits': SquirclePathCache.hits,
        'cache_misses': SquirclePathCache.misses,
        'cache_entries': SquirclePathCache.length,
      };
      // ignore: avoid_print
      print('PERF_45G_SUMMARY:${jsonEncode(summary)}');

      expect(listsStats['p90_ms']!, lessThan(16.0));
      expect(expensesStats['p90_ms']!, lessThan(16.0));
      expect(todayStats['p90_ms']!, lessThan(16.0));
      expect(sheetStats['p90_ms']!, lessThan(16.0));
      expect(SquirclePathCache.hits, greaterThan(500));
    });
  });
}
