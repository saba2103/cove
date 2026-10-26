import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/core/widgets/cove_seed_card.dart';
import 'package:cove/core/widgets/cove_starter_row.dart';
import 'package:cove/features/activity/activity_controller.dart';
import 'package:cove/features/activity/activity_models.dart';
import 'package:cove/features/activity/activity_read_status_controller.dart';
import 'package:cove/features/activity/activity_screen.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/add/add_flow.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/expenses_screen.dart';
import 'package:cove/features/expenses/monthly_budget_controller.dart';
import 'package:cove/features/expenses/monthly_budget_sheet.dart';
import 'package:cove/features/home/home_settings_screen.dart';
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
import 'package:cove/features/subscriptions/subscriptions_screen.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/key_management/pairing_qr_view.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/providers/first_run_provider.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden/golden_harness.dart';

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

final LocalHome _kSeedHome = LocalHome(
  id: 'home_1',
  name: 'The Nest',
  description: 'Bengaluru',
  currency: 'INR',
  createdAt: _kFixedDate,
  createdBy: 'user_1',
);

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

class _FakeHomeKeyStore extends Fake implements HomeKeyStore {
  final Map<String, Uint8List> _keys = <String, Uint8List>{
    'home_1': Uint8List.fromList(List<int>.filled(32, 7)),
  };

  @override
  Future<Uint8List?> getKey(String homeId) async => _keys[homeId];

  @override
  Future<bool> hasKey(String homeId) async => _keys.containsKey(homeId);

  @override
  Future<void> saveKey(String homeId, Uint8List key) async {
    _keys[homeId] = key;
  }

  @override
  Future<void> removeKey(String homeId) async {
    _keys.remove(homeId);
  }
}

Stream<T> _notifierStream<T>(Ref ref, ValueNotifier<T> notifier) {
  final controller = StreamController<T>.broadcast();
  Future.microtask(() {
    if (!controller.isClosed) {
      controller.add(notifier.value);
    }
  });
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

  late AppDatabase db;
  late _FakeHomeKeyStore fakeKeyStore;

  setUpAll(() async {
    await loadCoveFonts();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PartnerProfileNotifier.resetCache();
    fakeKeyStore = _FakeHomeKeyStore();
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.localHomes).insert(
          LocalHomesCompanion.insert(
            id: 'home_1',
            name: 'The Nest',
            description: const Value('Bengaluru'),
            createdAt: _kFixedDate,
            createdBy: 'user_1',
          ),
        );
  });

  List<Override> buildOverrides({
    PartnerProfileState partnerProfile = const PartnerProfileState(
      displayName: 'Partner',
      hasCustomName: false,
    ),
    bool hasPartner = false,
    ValueNotifier<List<LocalExpense>>? expensesNotifier,
    ValueNotifier<List<LocalSubscription>>? subscriptionsNotifier,
    ValueNotifier<List<FormattedActivityItem>>? activitiesNotifier,
    Stream<FirstRunCounts> Function(Ref ref)? customCountsStream,
  }) {
    final effectiveExpenses =
        expensesNotifier ?? ValueNotifier<List<LocalExpense>>(const []);
    final effectiveSubscriptions = subscriptionsNotifier ??
        ValueNotifier<List<LocalSubscription>>(const []);
    final effectiveActivities = activitiesNotifier ??
        ValueNotifier<List<FormattedActivityItem>>(const []);

    return [
      appDatabaseProvider.overrideWithValue(db),
      homeKeyStoreProvider.overrideWithValue(fakeKeyStore),
      if (customCountsStream != null)
        firstRunDbCountsStreamProvider('home_1').overrideWith(
          (ref) => customCountsStream(ref),
        ),
      authProvider.overrideWith(_FakeAuthNotifier.new),
      activeHomeIdProvider.overrideWith(_TestActiveHomeNotifier.new),
      activeHomeProvider.overrideWith((ref) => Stream.value(_kSeedHome)),
      userHomesProvider.overrideWith((ref) => Stream.value([_kSeedHome])),
      activeHomeHasPartnerProvider.overrideWith(
        () => _FakeActivePartnerNotifier(hasPartner),
      ),
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
      activityFeedProvider.overrideWith(
        (ref) => _notifierStream(ref, effectiveActivities),
      ),
      unreadActivityCountProvider.overrideWith((ref) => 0),
      checkinRemindersProvider.overrideWith(_FakeReminderNotifier.new),
      activeHomeExpensesProvider.overrideWith(
        (ref) => _notifierStream(ref, effectiveExpenses),
      ),
      activeHomeSubscriptionsProvider.overrideWith(
        (ref) => _notifierStream(ref, effectiveSubscriptions),
      ),
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

  group('No flash on launch (4.2c)', () {
    testWidgets(
      'with counts delayed 500ms and a home that has data, the seed card is never in the widget tree at any frame',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await db.into(db.localExpenses).insert(
              LocalExpensesCompanion.insert(
                id: 'exp_1',
                homeId: 'home_1',
                title: 'Coffee',
                amount: 180.0,
                paidBy: 'user_1',
                expenseDate: _kFixedDate,
                createdAt: _kFixedDate,
              ),
            );
        await db.into(db.localSubscriptions).insert(
              LocalSubscriptionsCompanion.insert(
                id: 'sub_1',
                homeId: 'home_1',
                name: 'Rent',
                amount: 32000.0,
                billingCycle: const Value('monthly'),
                nextBillingDate: _kFixedDate,
                createdAt: _kFixedDate,
              ),
            );
        await db.into(db.localActivityEvents).insert(
              LocalActivityEventsCompanion.insert(
                id: 'act_1',
                homeId: 'home_1',
                actorId: 'user_2',
                eventType: 'expense_logged',
                payloadJson: '{}',
                createdAt: _kFixedDate,
              ),
            );

        final seededCounts = await db.getFirstRunCounts('home_1');

        final screens = <Widget>[
          const ExpensesScreen(),
          const SubscriptionsScreen(),
          const ActivityScreen(),
          const HomeSettingsScreen(),
        ];

        await withClock(Clock.fixed(_kFixedDate), () async {
          for (var i = 0; i < screens.length; i++) {
            await tester.pumpWidget(
              wrapScreen(
                screens[i],
                scopeKey: ValueKey('delayed_42c_scope_$i'),
                overrides: buildOverrides(
                  hasPartner: true,
                  customCountsStream: (_) => Stream<FirstRunCounts>.fromFuture(
                    Future<FirstRunCounts>.delayed(
                      const Duration(milliseconds: 500),
                      () => seededCounts,
                    ),
                  ),
                ),
              ),
            );

            expect(find.byType(CoveSeedCard), findsNothing);
            for (var ms = 0; ms < 600; ms += 100) {
              await tester.pump(const Duration(milliseconds: 100));
              expect(find.byType(CoveSeedCard), findsNothing);
            }
          }
        });
      },
    );
  });

  group('4.2c Expenses first-run state', () {
    testWidgets(
      'renders exact spec copy, opens MonthlyBudgetSheet on Not set card, opens AddFlow(expense), and leaves first run after first expense (surviving delete)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final expensesNotifier = ValueNotifier<List<LocalExpense>>(const []);

        await withClock(Clock.fixed(_kFixedDate), () async {
          await tester.pumpWidget(
            wrapScreen(
              const ExpensesScreen(),
              overrides: buildOverrides(expensesNotifier: expensesNotifier),
            ),
          );
          await tester.pumpAndSettle();

          // Frame & metric cards
          expect(find.text('October · nothing yet'), findsOneWidget);
          expect(find.text('—'), findsOneWidget);
          expect(find.text('this month'), findsOneWidget);
          expect(find.text('Not set'), findsOneWidget);
          expect(find.text('tap to set one'), findsOneWidget);

          // Seed card
          expect(find.byType(CoveSeedCard), findsOneWidget);
          expect(find.text('No money has moved'), findsOneWidget);
          expect(
            find.text(
              'Log one purchase and this page starts working: the pace, the '
              'projection, who paid what, and a dial of where it went.',
            ),
            findsOneWidget,
          );
          expect(find.text('Log an expense'), findsOneWidget);
          expect(
            find.text('A budget makes the rest of it mean something.'),
            findsOneWidget,
          );

          // Quiet lines
          expect(find.text('EVERY DAY THIS MONTH'), findsOneWidget);
          expect(
            find.text(
              'The chart needs a few days before it can say anything useful.',
            ),
            findsOneWidget,
          );
          expect(find.text('WHERE IT WENT'), findsOneWidget);
          expect(
            find.text(
              'Categories appear as you use them — nothing to set up first.',
            ),
            findsOneWidget,
          );

          // Tap "Not set" budget card -> opens MonthlyBudgetSheet
          await tester.tap(
            find.byKey(const ValueKey('expenses_first_run_budget_card')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(MonthlyBudgetSheet), findsOneWidget);
          Navigator.of(tester.element(find.byType(MonthlyBudgetSheet))).pop();
          await tester.pumpAndSettle();

          // Tap "Log an expense" -> opens AddFlow(kind: AddKind.expense)
          await tester.tap(find.text('Log an expense'));
          await tester.pumpAndSettle();
          final addFlow = tester.widget<AddFlow>(find.byType(AddFlow));
          expect(addFlow.initialKind, AddKind.expense);
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // Seed first expense into database -> leaves first run
          final sampleExpense = LocalExpense(
            id: 'exp_1',
            homeId: 'home_1',
            title: 'Groceries',
            amount: 420.0,
            currency: 'INR',
            category: 'Groceries',
            paidBy: 'user_1',
            splitRatio: 0.5,
            isTransfer: false,
            expenseDate: _kFixedDate,
            createdAt: _kFixedDate,
          );
          await db.into(db.localExpenses).insert(
                LocalExpensesCompanion.insert(
                  id: sampleExpense.id,
                  homeId: sampleExpense.homeId,
                  title: sampleExpense.title,
                  amount: sampleExpense.amount,
                  paidBy: sampleExpense.paidBy,
                  expenseDate: sampleExpense.expenseDate,
                  createdAt: sampleExpense.createdAt,
                ),
              );
          expensesNotifier.value = [sampleExpense];
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);
          expect(find.text('No money has moved'), findsNothing);

          // Delete that expense -> stays in-use (renders normal empty state, never returns to first run)
          await db.delete(db.localExpenses).go();
          expensesNotifier.value = const [];
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);
          expect(find.text('No expenses recorded yet'), findsOneWidget);
        });
      },
    );
  });

  group('4.2c Commitments first-run state', () {
    testWidgets(
      'renders exact spec copy, starter rows open AddFlow with monthly / EMI / no preset, and leaves first run after first commitment (surviving delete)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1300);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final subsNotifier =
            ValueNotifier<List<LocalSubscription>>(const []);

        await withClock(Clock.fixed(_kFixedDate), () async {
          await tester.pumpWidget(
            wrapScreen(
              const SubscriptionsScreen(),
              overrides: buildOverrides(subscriptionsNotifier: subsNotifier),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('nothing yet'), findsOneWidget);
          expect(find.byType(CoveSeedCard), findsOneWidget);
          expect(find.text('Nothing renews yet'), findsOneWidget);
          expect(
            find.text(
              'Rent, the EMIs, the subscriptions you forget about. Add them '
              'once and Cove counts them down for you.',
            ),
            findsOneWidget,
          );
          expect(find.text('Add a commitment'), findsOneWidget);
          expect(
            find.text('Start with rent — it is the one you already know.'),
            findsOneWidget,
          );

          expect(find.byType(CoveStarterRow), findsNWidgets(3));
          expect(find.text('Rent or maintenance'), findsOneWidget);
          expect(find.text('the one that never changes'), findsOneWidget);
          expect(find.text('An EMI you are paying off'), findsOneWidget);
          expect(find.text('so you can see when it ends'), findsOneWidget);
          expect(find.text('A subscription'), findsOneWidget);
          expect(find.text('the ones that renew quietly'), findsOneWidget);

          expect(find.text('THE RUNWAY'), findsOneWidget);
          expect(
            find.text(
              'The runway draws itself once there is something to pay off.',
            ),
            findsOneWidget,
          );

          // 1. Seed card button -> AddFlow(commitment)
          await tester.tap(find.text('Add a commitment'));
          await tester.pumpAndSettle();
          var addFlow = tester.widget<AddFlow>(find.byType(AddFlow));
          expect(addFlow.initialKind, AddKind.commitment);
          expect(addFlow.presetMonthly, isFalse);
          expect(addFlow.presetEmi, isFalse);
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // 2. Starter row 1 ("Rent or maintenance") -> monthly preset
          await tester.tap(find.text('Rent or maintenance'));
          await tester.pumpAndSettle();
          addFlow = tester.widget<AddFlow>(find.byType(AddFlow));
          expect(addFlow.initialKind, AddKind.commitment);
          expect(addFlow.presetMonthly, isTrue);
          expect(addFlow.presetEmi, isFalse);
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // 3. Starter row 2 ("An EMI you are paying off") -> EMI preset
          await tester.tap(find.text('An EMI you are paying off'));
          await tester.pumpAndSettle();
          addFlow = tester.widget<AddFlow>(find.byType(AddFlow));
          expect(addFlow.initialKind, AddKind.commitment);
          expect(addFlow.presetEmi, isTrue);
          expect(addFlow.presetMonthly, isFalse);
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // 4. Starter row 3 ("A subscription") -> no preset
          await tester.tap(find.text('A subscription'));
          await tester.pumpAndSettle();
          addFlow = tester.widget<AddFlow>(find.byType(AddFlow));
          expect(addFlow.initialKind, AddKind.commitment);
          expect(addFlow.presetMonthly, isFalse);
          expect(addFlow.presetEmi, isFalse);
          Navigator.of(tester.element(find.byType(AddFlow))).pop();
          await tester.pumpAndSettle();

          // Seed first commitment -> leaves first run
          final sampleSub = LocalSubscription(
            id: 'sub_1',
            homeId: 'home_1',
            name: 'House Rent',
            amount: 32000.0,
            currency: 'INR',
            billingCycle: 'monthly',
            nextBillingDate: _kFixedDate,
            category: 'Rent',
            isActive: true,
            isPrivate: false,
            createdAt: _kFixedDate,
          );
          await db.into(db.localSubscriptions).insert(
                LocalSubscriptionsCompanion.insert(
                  id: sampleSub.id,
                  homeId: sampleSub.homeId,
                  name: sampleSub.name,
                  amount: sampleSub.amount,
                  billingCycle: Value(sampleSub.billingCycle),
                  nextBillingDate: sampleSub.nextBillingDate,
                  createdAt: sampleSub.createdAt,
                ),
              );
          subsNotifier.value = [sampleSub];
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);
          expect(find.text('Nothing renews yet'), findsNothing);

          // Delete that commitment -> stays in-use (renders normal empty state)
          await db.delete(db.localSubscriptions).go();
          subsNotifier.value = const [];
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);
          expect(find.text('No commitments yet'), findsOneWidget);
        });
      },
    );
  });

  group('4.2c Activity first-run state', () {
    testWidgets(
      'renders exact spec copy with partner fallback and custom name, has no seed button, and leaves first run after first activity event (surviving delete)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final activitiesNotifier =
            ValueNotifier<List<FormattedActivityItem>>(const []);

        await withClock(Clock.fixed(_kFixedDate), () async {
          // 1. Before partner has joined -> "your partner"
          await tester.pumpWidget(
            wrapScreen(
              const ActivityScreen(),
              scopeKey: const ValueKey('activity_no_partner'),
              overrides: buildOverrides(activitiesNotifier: activitiesNotifier),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsOneWidget);
          expect(find.byType(CovePillButton), findsNothing);
          expect(find.text('Nothing has happened yet'), findsOneWidget);
          expect(
            find.text(
              'When your partner adds something, ticks something off or marks '
              'a bill paid, it shows up here.',
            ),
            findsOneWidget,
          );
          expect(
            find.text('Cove never sends a notification you did not ask for.'),
            findsOneWidget,
          );
          expect(find.text('TODAY'), findsOneWidget);
          expect(find.text('Quiet.'), findsOneWidget);

          // 2. With partner name Ancy -> "When Ancy adds something..."
          await tester.pumpWidget(
            wrapScreen(
              const ActivityScreen(),
              scopeKey: const ValueKey('activity_with_ancy'),
              overrides: buildOverrides(
                partnerProfile: const PartnerProfileState(
                  displayName: 'Ancy',
                  hasCustomName: true,
                ),
                activitiesNotifier: activitiesNotifier,
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            find.text(
              'When Ancy adds something, ticks something off or marks a bill '
              'paid, it shows up here.',
            ),
            findsOneWidget,
          );

          // 3. Seed first activity event -> leaves first run
          await db.into(db.localActivityEvents).insert(
                LocalActivityEventsCompanion.insert(
                  id: 'act_1',
                  homeId: 'home_1',
                  actorId: 'user_1',
                  eventType: 'expense_logged',
                  payloadJson: '{}',
                  createdAt: _kFixedDate,
                ),
              );
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);

          // 4. Delete that activity event -> stays in-use (renders normal empty state)
          await db.delete(db.localActivityEvents).go();
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);
          expect(find.text('No activity yet'), findsOneWidget);
        });
      },
    );
  });

  group('4.2c Our home first-run state', () {
    testWidgets(
      'uses real home name, city and creation time, and real pairing code; Send a key opens PairingQrView; leaves first run once partner joins (surviving delete)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await withClock(Clock.fixed(_kFixedDate), () async {
          await tester.pumpWidget(
            wrapScreen(
              const HomeSettingsScreen(),
              overrides: buildOverrides(),
            ),
          );
          await tester.pumpAndSettle();

          // Real home name, city and creation time
          expect(find.text('The Nest'), findsOneWidget);
          expect(find.text('Bengaluru · made this morning'), findsOneWidget);

          // Two people: Saba / you, and Invite / your partner
          expect(find.text('Saba'), findsOneWidget);
          expect(find.text('you'), findsOneWidget);
          expect(find.text('Invite'), findsOneWidget);
          expect(find.text('your partner'), findsOneWidget);

          // Seed card copy
          expect(find.byType(CoveSeedCard), findsOneWidget);
          expect(find.text('A home with one person in it'), findsOneWidget);
          expect(
            find.text(
              'Cove only becomes itself when there are two of you. Send a key '
              '— everything you add before your partner joins is waiting for '
              'them.',
            ),
            findsOneWidget,
          );
          expect(find.text('Send a key'), findsOneWidget);

          // Real pairing code generated via HomeController
          expect(find.textContaining('Or share a code · '), findsOneWidget);

          // Tap "Send a key" -> opens PairingQrView
          await tester.tap(find.text('Send a key'));
          await tester.pumpAndSettle();
          expect(find.byType(PairingQrView), findsOneWidget);
          Navigator.of(tester.element(find.byType(PairingQrView))).pop();
          await tester.pumpAndSettle();

          // Partner joins (a second actor record in the home) -> leaves first run
          await db.into(db.localActivityEvents).insert(
                LocalActivityEventsCompanion.insert(
                  id: 'act_partner_1',
                  homeId: 'home_1',
                  actorId: 'user_partner',
                  eventType: 'member_profile_updated',
                  payloadJson: '{}',
                  createdAt: _kFixedDate,
                ),
              );
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);
          expect(find.text('WHO LIVES HERE'), findsOneWidget);

          // Delete that record -> stays in-use (never returns to first run)
          await db.delete(db.localActivityEvents).go();
          await tester.pumpAndSettle();

          expect(find.byType(CoveSeedCard), findsNothing);
          expect(find.text('WHO LIVES HERE'), findsOneWidget);
        });
      },
    );
  });
}
