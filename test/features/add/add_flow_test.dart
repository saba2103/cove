import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_checkbox.dart';
import 'package:cove/core/widgets/slips/cove_band.dart';
import 'package:cove/core/widgets/slips/cove_habit_card.dart';
import 'package:cove/core/widgets/slips/cove_note.dart';
import 'package:cove/core/widgets/slips/cove_receipt.dart';
import 'package:cove/core/widgets/slips/cove_voucher.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/add/add_flow.dart';
import 'package:cove/features/add/widgets/add_step_pieces.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/habits/habit_controller.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/routines/routine_screen.dart';
import 'package:cove/features/subscriptions/emi_tracker_screen.dart';
import 'package:cove/features/subscriptions/subscription_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../golden/golden_harness.dart';

class _SpyExpenseController extends ExpenseController {
  final List<ExpenseCreateArgs> calls = <ExpenseCreateArgs>[];
  bool shouldFail = false;
  Completer<void>? inFlightCompleter;
  void Function(String id, ExpenseCreateArgs args)? onLogged;

  _SpyExpenseController(super.ref);

  @override
  Future<String> logExpense({
    required String title,
    required double amount,
    String? currency,
    DateTime? expenseDate,
    required String paidBy,
    String? category,
    String? notes,
    String? paymentMethod,
    bool isTransfer = false,
    ExpenseVisibility visibility = ExpenseVisibility.shared,
  }) async {
    if (inFlightCompleter != null) {
      await inFlightCompleter!.future;
    }
    if (shouldFail) {
      throw StateError('Simulated logExpense failure');
    }
    final args = ExpenseCreateArgs(
      title: title,
      amount: amount,
      currency: currency,
      expenseDate: expenseDate!,
      paidBy: paidBy,
      category: category!,
      notes: notes,
      paymentMethod: paymentMethod,
      isTransfer: isTransfer,
      visibility: visibility,
    );
    calls.add(args);
    final id = 'exp-created-${calls.length}';
    onLogged?.call(id, args);
    return id;
  }
}

class _SpyCalendarController extends CalendarController {
  final List<EventCreateArgs> calls = <EventCreateArgs>[];
  bool shouldFail = false;

  _SpyCalendarController(super.ref);

  @override
  Future<String> createEvent({
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    String? location,
    String? recurrence,
    String owner = 'both',
  }) async {
    if (shouldFail) {
      throw StateError('Simulated createEvent failure');
    }
    calls.add(
      EventCreateArgs(
        title: title,
        description: description,
        startTime: startTime,
        endTime: endTime,
        isAllDay: isAllDay,
        location: location,
        recurrence: recurrence,
        owner: owner,
      ),
    );
    return 'evt-created-${calls.length}';
  }
}

class _SpyListController extends ListController {
  final List<String> createdListNames = <String>[];
  final List<
      ({
        String listId,
        String title,
        String? notes,
        DateTime? dueDate,
        String? listName,
        String? owner,
      })> addedItems = <({
    String listId,
    String title,
    String? notes,
    DateTime? dueDate,
    String? listName,
    String? owner,
  })>[];
  final List<String> callOrder = <String>[];

  _SpyListController(super.ref);

  @override
  Future<String> createList({required String name}) async {
    createdListNames.add(name);
    callOrder.add('createList:$name');
    return 'created_list_${createdListNames.length}';
  }

  @override
  Future<String> addItem({
    required String listId,
    required String title,
    String? notes,
    DateTime? dueDate,
    String? listName,
    String? owner,
  }) async {
    addedItems.add((
      listId: listId,
      title: title,
      notes: notes,
      dueDate: dueDate,
      listName: listName,
      owner: owner,
    ));
    callOrder.add('addItem:$listId:$title');
    return 'item_${addedItems.length}';
  }
}

class _SpyHabitController extends HabitController {
  final List<HabitCreateArgs> calls = <HabitCreateArgs>[];

  _SpyHabitController(super.ref);

  @override
  Future<String> createHabit({
    required String name,
    String cadence = 'daily',
    int targetDaysPerWeek = 7,
    HabitVisibility visibility = HabitVisibility.shared,
  }) async {
    calls.add(
      HabitCreateArgs(
        name: name,
        cadence: cadence,
        targetDaysPerWeek: targetDaysPerWeek,
        visibility: visibility,
      ),
    );
    return 'habit_${calls.length}';
  }
}

class _SpySubscriptionController extends SubscriptionController {
  final List<CommitmentCreateArgs> calls = <CommitmentCreateArgs>[];

  _SpySubscriptionController(super.ref);

  @override
  Future<void> createSubscription({
    required String name,
    required double amount,
    String? currency,
    String billingCycle = 'monthly',
    required DateTime nextBillingDate,
    String? category,
    bool isPrivate = false,
    DateTime? endDate,
    String? paidBy,
    String? financedThrough,
    int? totalInstallments,
    int? paidInstallments,
  }) async {
    calls.add(
      CommitmentCreateArgs(
        name: name,
        amount: amount,
        currency: currency,
        billingCycle: billingCycle,
        nextBillingDate: nextBillingDate,
        category: category ?? 'Other',
        isPrivate: isPrivate,
        endDate: endDate,
        paidBy: paidBy!,
        financedThrough: financedThrough,
        totalInstallments: totalInstallments,
        paidInstallments: paidInstallments,
      ),
    );
  }
}

class _SpyRoutineController extends RoutineController {
  final List<({String name, List<int> days})> createdRoutines =
      <({String name, List<int> days})>[];
  final List<
      ({
        String routineId,
        String title,
        int startMinutes,
        int endMinutes,
        String owner,
      })> createdEvents = <({
    String routineId,
    String title,
    int startMinutes,
    int endMinutes,
    String owner,
  })>[];
  final List<String> callOrder = <String>[];
  bool shouldFailCreateRoutineEvent = false;

  _SpyRoutineController(super.ref);

  @override
  Future<void> seedDefaultRoutinesIfEmpty() async {}

  @override
  Future<String> createRoutine({
    required String name,
    required List<int> days,
  }) async {
    final sorted = List<int>.from(days)..sort();
    createdRoutines.add((name: name, days: sorted));
    final id = 'created_routine_${createdRoutines.length}';
    callOrder.add('createRoutine:$name:${sorted.join(",")}->$id');
    return id;
  }

  @override
  Future<String> createRoutineEvent({
    required String routineId,
    required String title,
    required int startMinutes,
    required int endMinutes,
    String? category,
    String? notes,
    String owner = 'both',
  }) async {
    if (shouldFailCreateRoutineEvent) {
      callOrder.add('createRoutineEvent_FAILED:$routineId:$title');
      throw StateError('Simulated createRoutineEvent failure');
    }
    createdEvents.add((
      routineId: routineId,
      title: title,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      owner: owner,
    ));
    callOrder.add('createRoutineEvent:$routineId:$title:$startMinutes-$endMinutes');
    return 'routine_event_${createdEvents.length}';
  }
}

class _StubAuthNotifier extends AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncValue.data(
        CoveUser(id: 'user_saba', email: 'saba@cove.app', displayName: 'Saba'),
      );
}

class _StubUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState(
        displayName: 'Saba',
        email: 'saba@cove.app',
      );
}

class _StubPartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => const PartnerProfileState(
        displayName: 'Ancy',
        userId: 'user_ancy',
        hasCustomName: true,
      );
}

class _StubCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() => const CurrencyOption(
        code: 'INR',
        symbol: '₹',
        name: 'Indian Rupee',
      );
}

class _StubCustomCategoriesNotifier extends CustomCategoriesNotifier {
  @override
  List<String> build() => const <String>[];
}

void main() {
  final fixedNow = DateTime(2026, 10, 5, 10, 30);
  final fixedToday = DateTime(2026, 10, 5);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AddAgainPreferenceNotifier.cachedInitialAgain = null;
  });

  List<Override> buildOverrides({
    required _SpyExpenseController Function(Ref ref) expenseBuilder,
    required _SpyCalendarController Function(Ref ref) calendarBuilder,
    _SpyListController Function(Ref ref)? listBuilder,
    _SpyHabitController Function(Ref ref)? habitBuilder,
    _SpySubscriptionController Function(Ref ref)? subscriptionBuilder,
    _SpyRoutineController Function(Ref ref)? routineBuilder,
    List<LocalList> lists = const <LocalList>[],
    List<LocalSubscription> subscriptions = const <LocalSubscription>[],
    List<Routine> routines = const <Routine>[],
    Stream<List<LocalExpense>> Function()? expensesStreamBuilder,
  }) {
    return <Override>[
      authProvider.overrideWith(_StubAuthNotifier.new),
      activeHomeProvider.overrideWith(
        (ref) => Stream<LocalHome?>.value(
          LocalHome(
            id: 'home_1',
            name: 'Our Home',
            currency: 'INR',
            createdBy: 'user_saba',
            createdAt: fixedToday,
          ),
        ),
      ),
      activeHomeListsProvider.overrideWith(
        (ref) => Stream<List<LocalList>>.value(lists),
      ),
      activeHomeAllListItemsProvider.overrideWith(
        (ref) => Stream<List<LocalListItem>>.value(const <LocalListItem>[]),
      ),
      activeHomeHabitsProvider.overrideWith(
        (ref) => Stream<List<LocalHabit>>.value(const <LocalHabit>[]),
      ),
      activeHomeSubscriptionsProvider.overrideWith(
        (ref) => Stream<List<LocalSubscription>>.value(subscriptions),
      ),
      activeHomeRoutinesProvider.overrideWith(
        (ref) => Stream<List<Routine>>.value(routines),
      ),
      activeHomeAllRoutineEventsProvider.overrideWith(
        (ref) => Stream<List<RoutineEvent>>.value(const <RoutineEvent>[]),
      ),
      for (final r in routines)
        routineEventsProvider(r.id).overrideWith(
          (ref) => Stream<List<RoutineEvent>>.value(const <RoutineEvent>[]),
        ),
      activeHomeExpensesProvider.overrideWith(
        (ref) =>
            expensesStreamBuilder != null
                ? expensesStreamBuilder()
                : Stream<List<LocalExpense>>.value(const <LocalExpense>[]),
      ),
      activeHomeCalendarEventsProvider.overrideWith(
        (ref) => Stream<List<LocalCalendarEvent>>.value(
          const <LocalCalendarEvent>[],
        ),
      ),
      userProfileProvider.overrideWith(_StubUserProfileNotifier.new),
      partnerProfileProvider.overrideWith(_StubPartnerProfileNotifier.new),
      currencyPreferenceProvider.overrideWith(_StubCurrencyNotifier.new),
      customCategoriesProvider.overrideWith(_StubCustomCategoriesNotifier.new),
      expenseControllerProvider.overrideWith(expenseBuilder),
      calendarControllerProvider.overrideWith(calendarBuilder),
      if (listBuilder != null) listControllerProvider.overrideWith(listBuilder),
      if (habitBuilder != null)
        habitControllerProvider.overrideWith(habitBuilder),
      if (subscriptionBuilder != null)
        subscriptionControllerProvider.overrideWith(subscriptionBuilder),
      if (routineBuilder != null)
        routineControllerProvider.overrideWith(routineBuilder),
    ];
  }

  testWidgets(
    '1. Walk an expense through all 7 steps; Add calls logExpense once with the draft args; picker tiles open their flows and Back returns to picker',
    (tester) async {
      await loadCoveFonts();
      late _SpyExpenseController spyExpense;
      _SpyCalendarController? spyCalendar;

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(
              expenseBuilder: (ref) =>
                  spyExpense = _SpyExpenseController(ref),
              calendarBuilder: (ref) =>
                  spyCalendar = _SpyCalendarController(ref),
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: ElevatedButton(
                      onPressed: () => AddFlow.show(context),
                      child: const Text('Open Add'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open picker
        await tester.tap(find.text('Open Add'));
        await tester.pumpAndSettle();

        // Tapping Commitment opens Commitment Step 1, and Back returns to picker
        await tester.tap(
          find.byKey(const ValueKey('add_picker_tile_commitment')),
        );
        await tester.pumpAndSettle();
        expect(find.text('What is it?'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byType(AddFlow),
            matching: find.bySemanticsLabel('Back'),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Expense tile -> Step 1 of 7: How much?
        await tester.tap(
          find.byKey(const ValueKey('add_picker_tile_expense')),
        );
        await tester.pumpAndSettle();
        expect(find.text('How much?'), findsOneWidget);

        // Enter 2140 via keypad
        await tester.tap(find.bySemanticsLabel('2'));
        await tester.tap(find.bySemanticsLabel('1'));
        await tester.tap(find.bySemanticsLabel('4'));
        await tester.tap(find.bySemanticsLabel('0'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 7: What for?
        expect(find.text('What for?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          "Namdhari's",
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 3 of 7: When? (tap Today, 5 Oct -> auto-advances to Step 4)
        expect(find.text('When?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Today, 5 Oct'));
        await tester.pumpAndSettle();

        // Step 4 of 7: Which category? (tap Groceries -> auto-advances to Step 5)
        expect(find.text('Which category?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Groceries'));
        await tester.pumpAndSettle();

        // Step 5 of 7: Who paid? (defaults to Saba + Split it half and half)
        expect(find.text('Who paid?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 6 of 7: On what? (tap Card -> auto-advances to Step 7 Review)
        expect(find.text('On what?'), findsOneWidget);
        expect(find.text('Saba · split'), findsOneWidget);
        expect(find.text('Both'), findsNothing);
        await tester.tap(find.bySemanticsLabel('Card'));
        await tester.pumpAndSettle();

        // Step 7 of 7: Does this look right?
        expect(find.text('Does this look right?'), findsOneWidget);
        expect(find.text('Add expense'), findsOneWidget);
        expect(find.bySemanticsLabel('Back'), findsOneWidget);
        expect(find.byType(AddCrumbs), findsOneWidget);

        // Tap Add expense
        await tester.tap(find.bySemanticsLabel('Add expense'));
        await tester.pumpAndSettle();

        // Verify logExpense was called once with the exact draft args
        final expectedDraft = ExpenseDraft(
          amount: 2140,
          title: "Namdhari's",
          expenseDate: fixedToday,
          category: 'Groceries',
          payer: ExpensePayer.you,
          splitHalfAndHalf: true,
          isPrivate: false,
          paymentMethod: 'card',
          viewerUserId: 'user_saba',
          partnerUserId: 'user_ancy',
          hasPartner: true,
        );
        final expectedArgs = expectedDraft.toCreateArgs(
          viewerUserId: 'user_saba',
          partnerUserId: 'user_ancy',
          currency: 'INR',
        );

        expect(spyExpense.calls, hasLength(1));
        expect(spyExpense.calls.single, equals(expectedArgs));
        expect(spyCalendar?.calls ?? const <EventCreateArgs>[], isEmpty);

        // Added confirmation state is shown with ADDED stamp, no back button, and no crumbs
        expect(find.text('Added.'), findsOneWidget);
        expect(find.text('ADDED'), findsOneWidget);
        expect(find.bySemanticsLabel('Back'), findsNothing);
        expect(find.byType(AddCrumbs), findsNothing);
        expect(find.bySemanticsLabel('Close'), findsOneWidget);
        expect(find.byType(AddProgressSegments), findsOneWidget);
        expect(find.text('Add another'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
      });
    },
  );

  testWidgets(
    '2. Walk an event: createEvent gets start + 1 hour as endTime; All day uses the form all-day times (00:00 to 23:59)',
    (tester) async {
      await loadCoveFonts();
      late _SpyCalendarController spyCalendar;

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(
              expenseBuilder: (ref) => _SpyExpenseController(ref),
              calendarBuilder: (ref) =>
                  spyCalendar = _SpyCalendarController(ref),
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(initialKind: AddKind.event),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 of 5: What is it? (picker was skipped because kind was provided)
        expect(find.text('What is it?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Dinner with Meera',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 5: Which day? (tap Today, 5 Oct -> auto-advances to Step 3)
        expect(find.text('Which day?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Today, 5 Oct'));
        await tester.pumpAndSettle();

        // Step 3 of 5: What time? Select 8 PM : 30
        expect(find.text('What time?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('PM'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel("8 o'clock"));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('30 minutes'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 4 of 6: Where?
        expect(find.text('Where?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Toit',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 5 of 6: Whose is it?
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 6 of 6: Review
        expect(find.text('Does this look right?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Add event'));
        await tester.pumpAndSettle();

        expect(spyCalendar.calls, hasLength(1));
        final firstCall = spyCalendar.calls.first;
        expect(firstCall.title, equals('Dinner with Meera'));
        expect(firstCall.location, equals('Toit'));
        expect(firstCall.isAllDay, isFalse);
        expect(firstCall.startTime, equals(DateTime(2026, 10, 5, 20, 30)));
        expect(
          firstCall.endTime,
          equals(firstCall.startTime.add(const Duration(hours: 1))),
        );
        expect(firstCall.owner, equals('both'));

        // Now tap "Add another" and walk an All day event
        await tester.tap(find.bySemanticsLabel('Add another'));
        await tester.pumpAndSettle();

        expect(find.text('What is it?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Diwali holiday',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Tomorrow, 6 Oct'));
        await tester.pumpAndSettle();

        // Toggle All day on Step 3
        await tester.tap(find.bySemanticsLabel('All day'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Skip location on Step 4
        await tester.tap(find.bySemanticsLabel('Skip'));
        await tester.pumpAndSettle();

        // Step 5 of 6: Whose is it? -> select Saba (auto-advances to Review)
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Saba'));
        await tester.pumpAndSettle();

        // Commit on Step 6
        await tester.tap(find.bySemanticsLabel('Add event'));
        await tester.pumpAndSettle();

        expect(spyCalendar.calls, hasLength(2));
        final allDayCall = spyCalendar.calls.last;
        expect(allDayCall.title, equals('Diwali holiday'));
        expect(allDayCall.isAllDay, isTrue);
        expect(allDayCall.location, isNull);
        expect(allDayCall.startTime, equals(DateTime(2026, 10, 6, 0, 0)));
        expect(allDayCall.endTime, equals(DateTime(2026, 10, 6, 23, 59)));
        expect(allDayCall.owner, equals('user_saba'));
      });
    },
  );

  testWidgets(
    '3. Tapping a crumb goes to that step and keeps later answers; tapping a slip field goes to that step and Next returns to review',
    (tester) async {
      await loadCoveFonts();
      late _SpyExpenseController spyExpense;

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final prefilledDraft = ExpenseDraft(
          amount: 2140,
          title: "Namdhari's",
          expenseDate: fixedToday,
          category: 'Groceries',
          payer: ExpensePayer.you,
          splitHalfAndHalf: true,
          isPrivate: false,
          paymentMethod: 'card',
          viewerUserId: 'user_saba',
          partnerUserId: 'user_ancy',
          hasPartner: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(
              expenseBuilder: (ref) =>
                  spyExpense = _SpyExpenseController(ref),
              calendarBuilder: (ref) => _SpyCalendarController(ref),
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: Scaffold(
                body: AddFlow(
                  initialKind: AddKind.expense,
                  initialDraft: prefilledDraft,
                  initialStepIndex: 4, // Step 5: Who paid?
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Who paid?'), findsOneWidget);

        // Tap crumb "₹2,140" -> goes back to Step 1 (How much?), keeping later answers
        await tester.tap(find.bySemanticsLabel('Change ₹2,140'));
        await tester.pumpAndSettle();
        expect(find.text('How much?'), findsOneWidget);

        // Append a '5' -> 21,405 and tap Next -> goes to Step 2 with "Namdhari's" still intact!
        await tester.tap(find.bySemanticsLabel('5'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        expect(find.text('What for?'), findsOneWidget);
        expect(find.text("Namdhari's"), findsOneWidget);

        // Jump to Review via Next / pre-answered steps
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        expect(find.text('Does this look right?'), findsOneWidget);

        // Tap slip field "Change title" on the review receipt -> jumps to Step 2 (What for?)
        await tester.tap(find.bySemanticsLabel('Change title'));
        await tester.pumpAndSettle();
        expect(find.text('What for?'), findsOneWidget);

        // Update title to "Big Basket" and tap Next -> returns straight to Review!
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Big Basket',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        expect(find.text('Does this look right?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Add expense'));
        await tester.pumpAndSettle();

        expect(spyExpense.calls, hasLength(1));
        expect(spyExpense.calls.single.amount, equals(21405));
        expect(spyExpense.calls.single.title, equals('Big Basket'));
        expect(spyExpense.calls.single.category, equals('Groceries'));
        expect(spyExpense.calls.single.paymentMethod, equals('card'));
      });
    },
  );

  testWidgets(
    '4. A failing controller keeps the draft on review and shows the error toast',
    (tester) async {
      await loadCoveFonts();
      late _SpyExpenseController spyExpense;

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final prefilledDraft = ExpenseDraft(
          amount: 540,
          title: 'Blue Tokai',
          expenseDate: fixedToday,
          category: 'Eating out',
          payer: ExpensePayer.you,
          splitHalfAndHalf: true,
          isPrivate: false,
          paymentMethod: 'upi',
          viewerUserId: 'user_saba',
          partnerUserId: 'user_ancy',
          hasPartner: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(
              expenseBuilder: (ref) => spyExpense = _SpyExpenseController(ref)
                ..shouldFail = true,
              calendarBuilder: (ref) => _SpyCalendarController(ref),
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: Scaffold(
                body: AddFlow(
                  initialKind: AddKind.expense,
                  initialDraft: prefilledDraft,
                  initialStepIndex: 6, // Review step
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Does this look right?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Add expense'));
        await tester.pumpAndSettle();

        // Error toast is shown, draft stays on review, Add expense remains enabled
        expect(
          find.byKey(const ValueKey('add_flow_error_toast')),
          findsOneWidget,
        );
        expect(find.text('Does this look right?'), findsOneWidget);
        expect(find.text('Added.'), findsNothing);
        expect(find.text('Blue Tokai'), findsWidgets);

        // Now allow the controller to succeed and tap Add expense again
        spyExpense.shouldFail = false;
        await tester.tap(find.bySemanticsLabel('Add expense'));
        await tester.pumpAndSettle();

        expect(spyExpense.calls, hasLength(1));
        expect(find.text('Added.'), findsOneWidget);
      });
    },
  );

  testWidgets(
    '5. Tapping Add twice fast calls logExpense once; after Added there is no back button and no crumb; Who paid crumb shows payer + split/private (never Both)',
    (tester) async {
      await loadCoveFonts();
      late _SpyExpenseController spyExpense;
      final completer = Completer<void>();

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final prefilledDraft = ExpenseDraft(
          amount: 2140,
          title: "Namdhari's",
          expenseDate: fixedToday,
          category: 'Groceries',
          payer: ExpensePayer.partner,
          splitHalfAndHalf: true,
          isPrivate: false,
          paymentMethod: 'upi',
          viewerUserId: 'user_saba',
          partnerUserId: 'user_ancy',
          hasPartner: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(
              expenseBuilder: (ref) => spyExpense = _SpyExpenseController(ref)
                ..inFlightCompleter = completer,
              calendarBuilder: (ref) => _SpyCalendarController(ref),
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: Scaffold(
                body: AddFlow(
                  initialKind: AddKind.expense,
                  initialDraft: prefilledDraft,
                  initialStepIndex: 6, // Review step
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Who paid crumb shows "Ancy · split", never "Both"
        expect(find.text('Ancy · split'), findsOneWidget);
        expect(find.text('Both'), findsNothing);

        // Toggle privacy via the foot chip -> crumb becomes "Saba · private"
        await tester.tap(find.text('Both can see it'));
        await tester.pumpAndSettle();
        expect(find.text('Saba · private'), findsOneWidget);
        expect(find.text('Both'), findsNothing);

        // Tap Add expense twice fast (same frame + next frame while write is in flight)
        await tester.tap(find.bySemanticsLabel('Add expense'));
        await tester.tap(find.bySemanticsLabel('Add expense'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Add expense'));
        await tester.pump();

        // Complete the in-flight write
        completer.complete();
        await tester.pumpAndSettle();

        expect(spyExpense.calls, hasLength(1));

        // After Added: no back button and no crumb; close and full progress bar remain
        expect(find.text('Added.'), findsOneWidget);
        expect(find.bySemanticsLabel('Back'), findsNothing);
        expect(find.byType(AddCrumbs), findsNothing);
        expect(find.bySemanticsLabel('Close'), findsOneWidget);
        expect(find.byType(AddProgressSegments), findsOneWidget);
      });
    },
  );

  testWidgets(
    '6. At 320dp the review body scrolls to show the slip date line, visibility line, and "Tap anything above to change it."',
    (tester) async {
      await loadCoveFonts();

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = CoveWidth.cover * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final prefilledDraft = ExpenseDraft(
          amount: 2140,
          title: "Namdhari's",
          expenseDate: fixedToday,
          category: 'Groceries',
          payer: ExpensePayer.you,
          splitHalfAndHalf: true,
          isPrivate: false,
          paymentMethod: 'upi',
          viewerUserId: 'user_saba',
          partnerUserId: 'user_ancy',
          hasPartner: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(
              expenseBuilder: (ref) => _SpyExpenseController(ref),
              calendarBuilder: (ref) => _SpyCalendarController(ref),
            ),
            child: MediaQuery(
              data: const MediaQueryData(
                size: CoveWidth.cover,
                textScaler: TextScaler.linear(1.0),
              ),
              child: MaterialApp(
                theme: CoveTheme.darkTheme,
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: AddFlow(
                      initialKind: AddKind.expense,
                      initialDraft: prefilledDraft,
                      initialStepIndex: 6, // Review step
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final scrollFinder =
            find.byKey(const ValueKey('add_flow_step_scroll'));
        expect(scrollFinder, findsOneWidget);

        // Scroll the review body to the bottom
        await tester.drag(scrollFinder, const Offset(0, -300));
        await tester.pumpAndSettle();

        final scrollRect = tester.getRect(scrollFinder);
        final dateRect = tester.getRect(find.text('MON 5 OCT'));
        final visibilityRect = tester.getRect(find.text('BOTH CAN SEE IT'));
        final hintRect = tester.getRect(
          find.text('Tap anything above to change it.'),
        );

        // All three are visible inside the scroll viewport
        expect(dateRect.top, greaterThanOrEqualTo(scrollRect.top));
        expect(dateRect.bottom, lessThanOrEqualTo(scrollRect.bottom));
        expect(visibilityRect.top, greaterThanOrEqualTo(scrollRect.top));
        expect(visibilityRect.bottom, lessThanOrEqualTo(scrollRect.bottom));
        expect(hintRect.top, greaterThanOrEqualTo(scrollRect.top));
        expect(hintRect.bottom, lessThanOrEqualTo(scrollRect.bottom));
      });
    },
  );

  testWidgets(
    '7. Walk Task through multi-list (Which list), single-list (No particular day -> dueDate null), and zero-lists (Name the list creates one first); review is CoveNote',
    (tester) async {
      await loadCoveFonts();

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        // --- Case A: 2 lists (>1 list, not opened from a list) -> Which list? step ---
        late _SpyListController spyListA;
        final twoLists = <LocalList>[
          LocalList(
            id: 'list_grocery',
            homeId: 'home_1',
            name: 'Grocery',
            isArchived: false,
            createdAt: fixedToday,
            createdBy: 'user_saba',
          ),
          LocalList(
            id: 'list_home',
            homeId: 'home_1',
            name: 'Home',
            isArchived: false,
            createdAt: fixedToday,
            createdBy: 'user_saba',
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              listBuilder: (ref) => spyListA = _SpyListController(ref),
              lists: twoLists,
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(initialKind: AddKind.task),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 of 4: What needs doing?
        expect(find.text('What needs doing?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Gas cylinder',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 4: Which list?
        expect(find.text('Which list?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Home'));
        await tester.pumpAndSettle();

        // Step 3 of 5: By when? -> tap Tomorrow, 6 Oct
        expect(find.text('By when?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Tomorrow, 6 Oct'));
        await tester.pumpAndSettle();

        // Step 4 of 5: Whose is it? -> default Either of you
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 5 of 5: Review -> CoveNote
        expect(find.text('Does this look right?'), findsOneWidget);
        expect(find.byType(CoveNote), findsOneWidget);
        expect(find.text('COVE · HOME'), findsOneWidget);
        expect(find.text('By Tomorrow, 6 Oct'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Add task'));
        await tester.pumpAndSettle();

        expect(find.text('Added.'), findsOneWidget);
        expect(spyListA.createdListNames, isEmpty);
        expect(spyListA.addedItems, hasLength(1));
        expect(spyListA.addedItems.single.listId, 'list_home');
        expect(spyListA.addedItems.single.title, 'Gas cylinder');
        expect(spyListA.addedItems.single.dueDate, DateTime(2026, 10, 6));
        expect(spyListA.addedItems.single.owner, 'either');

        // --- Case B: 1 list -> Which list? skipped (4 steps); No particular day -> dueDate null ---
        late _SpyListController spyListB;
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('scope_b'),
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              listBuilder: (ref) => spyListB = _SpyListController(ref),
              lists: <LocalList>[twoLists.first],
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(
                  key: ValueKey('task_case_b'),
                  initialKind: AddKind.task,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('What needs doing?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Buy milk',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Directly on By when? (Step 2 of 4 — Which list skipped)
        expect(find.text('By when?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('No particular day'));
        await tester.pumpAndSettle();

        // Step 3 of 4: Whose is it? -> select Both of you (auto-advances to Review)
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Both of you'));
        await tester.pumpAndSettle();

        // Step 4 of 4: Review -> CoveNote with "No particular day"
        expect(find.text('Does this look right?'), findsOneWidget);
        expect(find.byType(CoveNote), findsOneWidget);
        expect(find.text('No particular day'), findsWidgets);

        await tester.tap(find.bySemanticsLabel('Add task'));
        await tester.pumpAndSettle();

        expect(spyListB.createdListNames, isEmpty);
        expect(spyListB.addedItems, hasLength(1));
        expect(spyListB.addedItems.single.listId, 'list_grocery');
        expect(spyListB.addedItems.single.title, 'Buy milk');
        expect(spyListB.addedItems.single.dueDate, isNull);
        expect(spyListB.addedItems.single.owner, 'both');

        // --- Case C: 0 lists -> Name the list creates one first through ListController ---
        late _SpyListController spyListC;
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('scope_c'),
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              listBuilder: (ref) => spyListC = _SpyListController(ref),
              lists: const <LocalList>[],
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(
                  key: ValueKey('task_case_c'),
                  initialKind: AddKind.task,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 of 5: What needs doing?
        expect(find.text('What needs doing?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Fix kitchen tap',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 5: Name the list
        expect(find.text('Name the list'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Repairs',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 3 of 5: By when?
        expect(find.text('By when?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Today, 5 Oct'));
        await tester.pumpAndSettle();

        // Step 4 of 5: Whose is it?
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 5 of 5: Review -> CoveNote
        expect(find.text('Does this look right?'), findsOneWidget);
        expect(find.text('COVE · REPAIRS'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Add task'));
        await tester.pumpAndSettle();

        expect(
          spyListC.callOrder,
          <String>[
            'createList:Repairs',
            'addItem:created_list_1:Fix kitchen tap',
          ],
        );
        expect(spyListC.addedItems.single.listId, 'created_list_1');
        expect(spyListC.addedItems.single.listName, 'Repairs');
        expect(spyListC.addedItems.single.dueDate, fixedToday);
      });
    },
  );

  testWidgets(
    '8. Walk Habit through all 4 steps: Pick the days reveals week toggles on the same page; cadence & target come from HabitSchedule; Who can see it -> visibility; review is CoveHabitCard in no-history state',
    (tester) async {
      await loadCoveFonts();
      late _SpyHabitController spyHabit;

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              habitBuilder: (ref) => spyHabit = _SpyHabitController(ref),
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(initialKind: AddKind.habit),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 of 4: What is the habit?
        expect(find.text('What is the habit?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Morning walk',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 4: How often?
        expect(find.text('How often?'), findsOneWidget);
        expect(find.byType(AddWeekToggles), findsNothing);

        // Tap "Pick the days" -> stays on How often? and reveals week toggles
        await tester.tap(find.bySemanticsLabel('Pick the days'));
        await tester.pumpAndSettle();
        expect(find.text('How often?'), findsOneWidget);
        expect(find.byType(AddWeekToggles), findsOneWidget);

        // Default customDays is {1, 3, 5} (Mon, Wed, Fri). Toggle Tuesday (selected -> true) => {1, 2, 3, 5}
        await tester.tap(find.bySemanticsLabel('Tuesday'));
        await tester.pumpAndSettle();

        // Tap Next to advance to Step 3
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 3 of 4: Who can see it?
        expect(find.text('Who can see it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Only you'));
        await tester.pumpAndSettle();

        // Step 4 of 4: Review -> CoveHabitCard in its no-history state
        // (no checkbox, no 21-cell grid, no DAYS RUNNING count)
        expect(find.text('Does this look right?'), findsOneWidget);
        final habitCard = tester.widget<CoveHabitCard>(
          find.byType(CoveHabitCard),
        );
        expect(habitCard.title, 'Morning walk');
        expect(habitCard.daysRunning, 0);
        expect(habitCard.isDoneToday, isFalse);
        expect(habitCard.showCheckbox, isFalse);
        expect(habitCard.showHistory, isFalse);
        expect(find.byType(CoveCheckbox), findsNothing);
        expect(find.text('DAYS RUNNING'), findsNothing);
        expect(habitCard.resolveCells(), everyElement(isFalse));
        expect(find.text('ONLY YOU CAN SEE IT'), findsOneWidget);

        // Tap Add habit
        await tester.tap(find.bySemanticsLabel('Add habit'));
        await tester.pumpAndSettle();

        expect(find.text('Added.'), findsOneWidget);
        expect(spyHabit.calls, hasLength(1));
        expect(
          spyHabit.calls.single,
          const HabitCreateArgs(
            name: 'Morning walk',
            cadence: 'custom:1,2,3,5',
            targetDaysPerWeek: 4,
            visibility: HabitVisibility.privateToMe,
          ),
        );
      });
    },
  );

  testWidgets(
    '9. Walk Commitment through monthly, quarterly, yearly, and EMI (3 of 12 paid) paths; Paid from shows real financedThrough values; Both of you -> split; private selects you; review is CoveVoucher (punched for EMI)',
    (tester) async {
      await loadCoveFonts();

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final existingSubs = <LocalSubscription>[
          LocalSubscription(
            id: 'sub_1',
            homeId: 'home_1',
            name: 'ACT Fibernet',
            amount: 1180,
            currency: 'INR',
            billingCycle: 'monthly',
            nextBillingDate: DateTime(2026, 10, 15),
            category: 'Utilities',
            isActive: true,
            isPrivate: false,
            financedThrough: 'BOB',
            createdAt: fixedToday,
          ),
          LocalSubscription(
            id: 'sub_2',
            homeId: 'home_1',
            name: 'Netflix',
            amount: 649,
            currency: 'INR',
            billingCycle: 'monthly',
            nextBillingDate: DateTime(2026, 10, 20),
            category: 'Entertainment',
            isActive: true,
            isPrivate: false,
            financedThrough: 'HDFC Regalia',
            createdAt: fixedToday,
          ),
        ];

        // --- Path A: Monthly commitment + real financedThrough chip + Both of you -> 'split' ---
        late _SpySubscriptionController spySubA;
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('sub_scope_a'),
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              subscriptionBuilder: (ref) =>
                  spySubA = _SpySubscriptionController(ref),
              subscriptions: existingSubs,
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(
                  key: ValueKey('commitment_a'),
                  initialKind: AddKind.commitment,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 of 7: What is it?
        expect(find.text('What is it?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Spotify Duo',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 7: How much, each time?
        expect(find.text('How much, each time?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('1'));
        await tester.tap(find.bySemanticsLabel('4'));
        await tester.tap(find.bySemanticsLabel('9'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 3 of 7: How often does it come? -> Every month (no EMI steps)
        expect(find.text('How often does it come?'), findsOneWidget);
        await tester.tap(
          find.bySemanticsLabel('Every month, twelve times a year'),
        );
        await tester.pumpAndSettle();

        // Step 4 of 7: Which day of the month? -> Day 8
        expect(find.text('Which day of the month?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Day 8'));
        await tester.pumpAndSettle();

        // Step 5 of 7: Paid from? -> real financedThrough suggestions BOB & HDFC Regalia
        expect(find.text('Paid from?'), findsOneWidget);
        expect(find.bySemanticsLabel('BOB'), findsOneWidget);
        expect(find.bySemanticsLabel('HDFC Regalia'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('BOB'));
        await tester.pumpAndSettle();

        // Step 6 of 7: Whose is it? -> tap Both of you
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Both of you'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 7 of 7: Review -> un-punched CoveVoucher
        expect(find.text('Does this look right?'), findsOneWidget);
        final voucherA = tester.widget<CoveVoucher>(find.byType(CoveVoucher));
        expect(voucherA.title, 'Spotify Duo');
        expect(voucherA.totalInstallments, isNull);
        expect(voucherA.paidFrom, 'BOB');
        expect(voucherA.whose, 'Both of you');

        await tester.tap(find.bySemanticsLabel('Add commitment'));
        await tester.pumpAndSettle();

        expect(find.text('Added.'), findsOneWidget);
        expect(spySubA.calls, hasLength(1));
        expect(spySubA.calls.single.name, 'Spotify Duo');
        expect(spySubA.calls.single.amount, 149.0);
        expect(spySubA.calls.single.billingCycle, 'monthly');
        expect(spySubA.calls.single.nextBillingDate, DateTime(2026, 10, 8));
        expect(spySubA.calls.single.financedThrough, 'BOB');
        expect(spySubA.calls.single.paidBy, 'split');
        expect(spySubA.calls.single.isPrivate, isFalse);
        expect(spySubA.calls.single.totalInstallments, isNull);

        // --- Path B: Quarterly commitment + next-date picker + private selects you ---
        late _SpySubscriptionController spySubB;
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('sub_scope_b'),
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              subscriptionBuilder: (ref) =>
                  spySubB = _SpySubscriptionController(ref),
              subscriptions: existingSubs,
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(
                  key: ValueKey('commitment_b'),
                  initialKind: AddKind.commitment,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Water purifier service',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('1'));
        await tester.tap(find.bySemanticsLabel('2'));
        await tester.tap(find.bySemanticsLabel('0'));
        await tester.tap(find.bySemanticsLabel('0'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsLabel('Every quarter, four times a year'),
        );
        await tester.pumpAndSettle();

        // Step 4 of 7: When is the next one due? (AddNextDatePicker without duplicated hint)
        expect(find.text('When is the next one due?'), findsOneWidget);
        expect(find.byType(AddNextDatePicker), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Month Nov'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Day 15'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 5 of 7: Paid from? -> Skip
        expect(find.text('Paid from?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Skip'));
        await tester.pumpAndSettle();

        // Step 6 of 7: Whose is it? -> select partner (Ancy), then toggle Keep it private -> selects you
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Ancy'));
        await tester.pump();
        await tester.tap(find.text('Keep it private'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Review
        expect(find.text('Does this look right?'), findsOneWidget);
        expect(find.text('COVE · EVERY QUARTER'), findsOneWidget);
        expect(find.text('ONLY YOU CAN SEE IT'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Add commitment'));
        await tester.pumpAndSettle();

        expect(spySubB.calls, hasLength(1));
        expect(spySubB.calls.single.billingCycle, 'every_3_months');
        expect(spySubB.calls.single.nextBillingDate, DateTime(2026, 11, 15));
        expect(spySubB.calls.single.financedThrough, isNull);
        expect(spySubB.calls.single.paidBy, 'user_saba');
        expect(spySubB.calls.single.isPrivate, isTrue);

        // --- Path C: Yearly commitment ---
        late _SpySubscriptionController spySubC;
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('sub_scope_c'),
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              subscriptionBuilder: (ref) =>
                  spySubC = _SpySubscriptionController(ref),
              subscriptions: existingSubs,
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(
                  key: ValueKey('commitment_c'),
                  initialKind: AddKind.commitment,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Car insurance',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('9'));
        await tester.tap(find.bySemanticsLabel('5'));
        await tester.tap(find.bySemanticsLabel('0'));
        await tester.tap(find.bySemanticsLabel('0'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsLabel('Every year, once, on a date'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AddNextDatePicker), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Month Oct'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Day 20'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Skip'));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        expect(find.text('COVE · EVERY YEAR'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Add commitment'));
        await tester.pumpAndSettle();

        expect(spySubC.calls, hasLength(1));
        expect(spySubC.calls.single.billingCycle, 'annual');
        expect(spySubC.calls.single.nextBillingDate, DateTime(2026, 10, 20));

        // --- Path D: EMI commitment with 3 of 12 paid (9 steps, punched CoveVoucher) ---
        late _SpySubscriptionController spySubD;
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('sub_scope_d'),
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              subscriptionBuilder: (ref) =>
                  spySubD = _SpySubscriptionController(ref),
              subscriptions: existingSubs,
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(
                  key: ValueKey('commitment_d'),
                  initialKind: AddKind.commitment,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 of 9: What is it?
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'AC — the instalment',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 9: How much, each time? -> 3974
        await tester.tap(find.bySemanticsLabel('3'));
        await tester.tap(find.bySemanticsLabel('9'));
        await tester.tap(find.bySemanticsLabel('7'));
        await tester.tap(find.bySemanticsLabel('4'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 3 of 9: How often does it come? -> It ends — an EMI
        await tester.tap(
          find.bySemanticsLabel('It ends — an EMI, a number of instalments'),
        );
        await tester.pumpAndSettle();

        // Step 4 of 9: How many instalments in all? -> 12
        expect(find.text('How many instalments in all?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('1'));
        await tester.tap(find.bySemanticsLabel('2'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 5 of 9: How many are paid already? -> 3
        expect(find.text('How many are paid already?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('3'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 6 of 9: Which day of the month? -> Day 5
        expect(find.text('Which day of the month?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Day 5'));
        await tester.pumpAndSettle();

        // Step 7 of 9: Paid from? -> HDFC Regalia
        expect(find.text('Paid from?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('HDFC Regalia'));
        await tester.pumpAndSettle();

        // Step 8 of 9: Whose is it? -> default Saba
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 9 of 9: Review -> punched CoveVoucher with 3 of 12 paid
        expect(find.text('Does this look right?'), findsOneWidget);
        final voucherD = tester.widget<CoveVoucher>(find.byType(CoveVoucher));
        expect(voucherD.isEmi, isTrue);
        expect(voucherD.totalInstallments, 12);
        expect(voucherD.paidInstallments, 3);
        expect(find.text('3 OF 12 PAID'), findsOneWidget);
        expect(find.text('9 LEFT'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Add commitment'));
        await tester.pumpAndSettle();

        expect(find.text('Added.'), findsOneWidget);
        expect(spySubD.calls, hasLength(1));
        expect(spySubD.calls.single.name, 'AC — the instalment');
        expect(spySubD.calls.single.amount, 3974.0);
        expect(spySubD.calls.single.billingCycle, 'monthly');
        expect(spySubD.calls.single.nextBillingDate, DateTime(2026, 10, 5));
        expect(spySubD.calls.single.endDate, DateTime(2026, 10 + 9, 5));
        expect(spySubD.calls.single.totalInstallments, 12);
        expect(spySubD.calls.single.paidInstallments, 3);
        expect(spySubD.calls.single.financedThrough, 'HDFC Regalia');
        expect(spySubD.calls.single.paidBy, 'user_saba');
      });
    },
  );

  testWidgets(
    '10. Walk Routine into an existing routine set and into a new set (reporting what the user is left with if the second call fails); review is CoveBand',
    (tester) async {
      await loadCoveFonts();

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final existingRoutines = <Routine>[
          Routine(
            id: 'routine_weekdays_1',
            homeId: 'home_1',
            name: 'Weekday rhythm',
            days: const <int>[1, 2, 3, 4, 5],
            createdAt: fixedToday,
          ),
        ];

        // --- Case A: Existing routine set (Mon-Fri matches routine_weekdays_1) ---
        late _SpyRoutineController spyRoutineA;
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('routine_scope_a'),
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              routineBuilder: (ref) => spyRoutineA = _SpyRoutineController(ref),
              routines: existingRoutines,
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(
                  key: ValueKey('routine_a'),
                  initialKind: AddKind.routine,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 of 5: What is it?
        expect(find.text('What is it?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Morning tea',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 5: When, usually? -> tap 8 o'clock (8:00 AM => 480)
        expect(find.text('When, usually?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel("8 o'clock"));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 3 of 5: For how long? -> 30 min (auto-advances to Step 4)
        expect(find.text('For how long?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('30 min'));
        await tester.pumpAndSettle();

        // Step 4 of 6: Which days? -> default Mon-Fri {1, 2, 3, 4, 5}
        expect(find.text('Which days?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 5 of 6: Whose is it? -> default Both of you
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 6 of 6: Review -> CoveBand
        expect(find.text('Does this look right?'), findsOneWidget);
        final bandA = tester.widget<CoveBand>(find.byType(CoveBand));
        expect(bandA.title, 'Morning tea');
        expect(bandA.startMinutes, 480);
        expect(bandA.endMinutes, 510);
        expect(bandA.days, const <int>{1, 2, 3, 4, 5});

        await tester.tap(find.bySemanticsLabel('Add routine'));
        await tester.pumpAndSettle();

        expect(find.text('Added.'), findsOneWidget);
        expect(spyRoutineA.createdRoutines, isEmpty);
        expect(spyRoutineA.createdEvents, hasLength(1));
        expect(spyRoutineA.createdEvents.single.routineId, 'routine_weekdays_1');
        expect(spyRoutineA.createdEvents.single.title, 'Morning tea');
        expect(spyRoutineA.createdEvents.single.startMinutes, 480);
        expect(spyRoutineA.createdEvents.single.endMinutes, 510);
        expect(spyRoutineA.createdEvents.single.owner, 'both');

        // --- Case B: New routine set (Mon, Wed, Fri) + second-call failure reporting & retry ---
        late _SpyRoutineController spyRoutineB;
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('routine_scope_b'),
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              routineBuilder: (ref) => spyRoutineB = _SpyRoutineController(ref)
                ..shouldFailCreateRoutineEvent = true,
              routines: existingRoutines,
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(
                  key: ValueKey('routine_b'),
                  initialKind: AddKind.routine,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Evening stretch',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Default 9:00 AM (540)
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Duration: 45 min -> endMinutes = 585
        await tester.tap(find.bySemanticsLabel('45 min'));
        await tester.pumpAndSettle();

        // Which days? Default is {1, 2, 3, 4, 5}. Toggle Tuesday and Thursday off -> {1, 3, 5}
        await tester.tap(find.bySemanticsLabel('Tuesday'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Thursday'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 5 of 6: Whose is it?
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Review -> first Add routine attempt fails on createRoutineEvent after createRoutine succeeded
        expect(find.byType(CoveBand), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Add routine'));
        await tester.pumpAndSettle();

        // Reports what the user is left with ('Mon, Wed, Fri' routine set created) and does not leave an empty set silently
        expect(spyRoutineB.createdRoutines, hasLength(1));
        expect(spyRoutineB.createdRoutines.single.name, 'Mon, Wed, Fri');
        expect(spyRoutineB.createdRoutines.single.days, const <int>[1, 3, 5]);
        expect(spyRoutineB.createdEvents, isEmpty);
        expect(
          find.byKey(const ValueKey('add_flow_error_toast')),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Created the "Mon, Wed, Fri" routine set, but could not add "Evening stretch"',
          ),
          findsWidgets,
        );
        expect(find.text('Added.'), findsNothing);

        // Retry succeeds and reuses the created routine set without creating a duplicate empty set
        spyRoutineB.shouldFailCreateRoutineEvent = false;
        await tester.tap(find.bySemanticsLabel('Add routine'));
        await tester.pumpAndSettle();

        expect(find.text('Added.'), findsOneWidget);
        expect(spyRoutineB.createdRoutines, hasLength(1));
        expect(spyRoutineB.createdEvents, hasLength(1));
        expect(
          spyRoutineB.createdEvents.single.routineId,
          'created_routine_1',
        );
        expect(spyRoutineB.createdEvents.single.title, 'Evening stretch');
        expect(spyRoutineB.createdEvents.single.startMinutes, 540);
        expect(spyRoutineB.createdEvents.single.endMinutes, 585);
      });
    },
  );

  testWidgets(
    '11. Again (expense): after adding an expense, picker shows Again from DB record; deleting it removes the row; Again leaves amount empty and Next lands on review',
    (tester) async {
      await loadCoveFonts();
      final dbExpenses = <LocalExpense>[];
      final expensesStreamController =
          StreamController<List<LocalExpense>>.broadcast();
      addTearDown(expensesStreamController.close);

      void emitExpenses() {
        expensesStreamController.add(
          List<LocalExpense>.unmodifiable(dbExpenses),
        );
      }

      late _SpyExpenseController spyExpense;

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final overrides = buildOverrides(
          expenseBuilder: (ref) {
            spyExpense = _SpyExpenseController(ref)
              ..onLogged = (id, args) {
                final splitRatio =
                    args.visibility == ExpenseVisibility.privateToMe
                        ? -1.0
                        : (args.visibility == ExpenseVisibility.partnerCanSee
                            ? 0.0
                            : 0.5);
                dbExpenses.add(
                  LocalExpense(
                    id: id,
                    homeId: 'home_1',
                    title: args.title,
                    amount: args.amount,
                    currency: args.currency ?? 'INR',
                    paidBy: args.paidBy,
                    splitRatio: splitRatio,
                    expenseDate: args.expenseDate,
                    category: args.category,
                    paymentMethod: args.paymentMethod,
                    isTransfer: args.isTransfer,
                    createdAt: args.expenseDate,
                  ),
                );
                emitExpenses();
              };
            return spyExpense;
          },
          calendarBuilder: _SpyCalendarController.new,
          expensesStreamBuilder: () async* {
            yield List<LocalExpense>.unmodifiable(dbExpenses);
            yield* expensesStreamController.stream;
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('again_expense_scope'),
            overrides: overrides,
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(key: ValueKey('add_flow_1')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially no Again row on the picker
        expect(find.byKey(const ValueKey('add_picker_again_row')), findsNothing);

        // 1. Add an expense through AddFlow
        await tester.tap(find.byKey(const ValueKey('add_picker_tile_expense')));
        await tester.pumpAndSettle();

        for (final key in ['2', '1', '4', '0']) {
          await tester.tap(find.bySemanticsLabel(key));
          await tester.pump();
        }
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          "Namdhari's",
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 3: When? -> Today, 5 Oct
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 4: Which category? -> Groceries
        await tester.tap(find.bySemanticsLabel('Groceries'));
        await tester.pumpAndSettle();

        // Step 5: Who paid? -> Saba (split)
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 6: On what? -> Card
        await tester.tap(find.bySemanticsLabel('Card'));
        await tester.pumpAndSettle();

        // Step 7: Review -> Add expense
        expect(find.text('Does this look right?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Add expense'));
        await tester.pumpAndSettle();
        expect(find.text('Added.'), findsOneWidget);

        // Verify local preferences stored {kind: expense, id: exp-created-1}
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(AddAgainPreferenceNotifier.kindPreferenceKey),
          'expense',
        );
        expect(
          prefs.getString(AddAgainPreferenceNotifier.idPreferenceKey),
          'exp-created-1',
        );

        // 2. Reopen the picker: shows Again with title, category, and amount from the DB record
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('again_expense_scope_reopened'),
            overrides: overrides,
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(key: ValueKey('add_flow_2')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('add_picker_again_row')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            "Again: Namdhari's · Groceries, last ₹2,140",
          ),
          findsOneWidget,
        );
        expect(find.text('last ₹2,140'), findsOneWidget);

        // Verify values are read live from the DB record (not cached):
        // mutate the DB record's amount and confirm the picker reflects it, then restore
        dbExpenses[0] = dbExpenses[0].copyWith(amount: 2350);
        emitExpenses();
        await tester.pumpAndSettle();
        expect(find.text('last ₹2,350'), findsOneWidget);

        dbExpenses[0] = dbExpenses[0].copyWith(amount: 2140);
        emitExpenses();
        await tester.pumpAndSettle();
        expect(find.text('last ₹2,140'), findsOneWidget);

        // 3. Tap Again: starts expense with everything carried except amount,
        // lands on step 1 with the carried line, and Next goes straight to review
        await tester.tap(find.byKey(const ValueKey('add_picker_again_row')));
        await tester.pumpAndSettle();

        expect(find.text('How much?'), findsOneWidget);
        expect(
          find.text("Namdhari's · Groceries · Card — last time ₹2,140"),
          findsOneWidget,
        );
        // Amount is empty (₹0), so Next is disabled until an amount is entered
        expect(find.bySemanticsLabel('₹0'), findsOneWidget);
        expect(
          tester.widget<AddStepFoot>(find.byType(AddStepFoot)).enabled,
          isFalse,
        );

        // Enter new amount ₹1,850 and tap Next -> lands straight on Review!
        for (final key in ['1', '8', '5', '0']) {
          await tester.tap(find.bySemanticsLabel(key));
          await tester.pump();
        }
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        expect(find.text('Does this look right?'), findsOneWidget);
        expect(find.text("Namdhari's"), findsWidgets);
        expect(find.text('Groceries'), findsWidgets);
        expect(find.text('₹1,850'), findsWidgets);

        // 4. Deleting that expense from the database removes the Again row from the picker
        dbExpenses.clear();
        emitExpenses();
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('again_expense_scope_after_delete'),
            overrides: overrides,
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(key: ValueKey('add_flow_3')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('add_picker_again_row')), findsNothing);
      });
    },
  );

  testWidgets(
    '12. Again: habits, commitments, and routines never become Again',
    (tester) async {
      await loadCoveFonts();

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final overrides = buildOverrides(
          expenseBuilder: _SpyExpenseController.new,
          calendarBuilder: _SpyCalendarController.new,
          habitBuilder: _SpyHabitController.new,
          subscriptionBuilder: _SpySubscriptionController.new,
          routineBuilder: _SpyRoutineController.new,
        );

        // 1. Add a Habit -> never becomes Again
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('habit_no_again'),
            overrides: overrides,
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(initialKind: AddKind.habit),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Read 20 pages',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Every day'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Both of you'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Add habit'));
        await tester.pumpAndSettle();
        expect(find.text('Added.'), findsOneWidget);

        final prefsAfterHabit = await SharedPreferences.getInstance();
        expect(
          prefsAfterHabit.getString(
            AddAgainPreferenceNotifier.kindPreferenceKey,
          ),
          isNull,
        );
        expect(
          prefsAfterHabit.getString(AddAgainPreferenceNotifier.idPreferenceKey),
          isNull,
        );

        // 2. Add a Commitment -> never becomes Again
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('commitment_no_again'),
            overrides: overrides,
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(initialKind: AddKind.commitment),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Rent',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        for (final key in ['1', '0', '0', '0']) {
          await tester.tap(find.bySemanticsLabel(key));
          await tester.pump();
        }
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsLabel('Every month, twelve times a year'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Day 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Skip'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Add commitment'));
        await tester.pumpAndSettle();
        expect(find.text('Added.'), findsOneWidget);

        final prefsAfterCommitment = await SharedPreferences.getInstance();
        expect(
          prefsAfterCommitment.getString(
            AddAgainPreferenceNotifier.kindPreferenceKey,
          ),
          isNull,
        );
        expect(
          prefsAfterCommitment.getString(
            AddAgainPreferenceNotifier.idPreferenceKey,
          ),
          isNull,
        );

        // 3. Add a Routine -> never becomes Again
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('routine_no_again'),
            overrides: overrides,
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(initialKind: AddKind.routine),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Morning walk',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('30 min'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Add routine'));
        await tester.pumpAndSettle();
        expect(find.text('Added.'), findsOneWidget);

        final prefsAfterRoutine = await SharedPreferences.getInstance();
        expect(
          prefsAfterRoutine.getString(
            AddAgainPreferenceNotifier.kindPreferenceKey,
          ),
          isNull,
        );
        expect(
          prefsAfterRoutine.getString(
            AddAgainPreferenceNotifier.idPreferenceKey,
          ),
          isNull,
        );
      });
    },
  );

  testWidgets(
    '13. Expense time & receipt avatar: today uses clock.now() and shows time on receipt; another day stays at 00:00 and hides time on receipt; receipt avatar shows profile initial, never "Y"',
    (tester) async {
      await loadCoveFonts();
      late _SpyExpenseController spyExpense;

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        // --- Case A: Chosen day is today (Mon, 5 Oct) -> expenseDate = clock.now() (10:30 AM) ---
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('exp_time_today'),
            overrides: buildOverrides(
              expenseBuilder: (ref) =>
                  spyExpense = _SpyExpenseController(ref),
              calendarBuilder: _SpyCalendarController.new,
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(
                  key: ValueKey('flow_today'),
                  initialKind: AddKind.expense,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final key in ['4', '5', '0']) {
          await tester.tap(find.bySemanticsLabel(key));
          await tester.pump();
        }
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Subko Coffee',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Tap Today, 5 Oct
        await tester.tap(find.bySemanticsLabel('Today, 5 Oct'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Eating out'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('UPI'));
        await tester.pumpAndSettle();

        // Review receipt: shows time 10:30 AM, text "Paid by You · UPI", avatar initial "S" (never "Y")
        expect(find.text('Does this look right?'), findsOneWidget);
        final todayReceipt = tester.widget<CoveReceipt>(
          find.byType(CoveReceipt),
        );
        expect(todayReceipt.subtitle, equals('10:30 AM'));
        expect(todayReceipt.footerDate, equals('MON 5 OCT'));
        expect(find.text('10:30 AM'), findsOneWidget);
        expect(find.text('MON 5 OCT'), findsOneWidget);
        expect(find.text('Paid by You · UPI'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(CoveReceipt),
            matching: find.text('S'),
          ),
          findsWidgets,
        );
        expect(
          find.descendant(
            of: find.byType(CoveAvatar),
            matching: find.text('Y'),
          ),
          findsNothing,
        );

        await tester.tap(find.bySemanticsLabel('Add expense'));
        await tester.pumpAndSettle();

        expect(spyExpense.calls, hasLength(1));
        expect(spyExpense.calls.single.expenseDate, equals(fixedNow));

        // --- Case B: Chosen day is another day (Sun, 4 Oct) -> expenseDate = 00:00 (midnight), receipt omits time ---
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('exp_time_other_day'),
            overrides: buildOverrides(
              expenseBuilder: (ref) =>
                  spyExpense = _SpyExpenseController(ref),
              calendarBuilder: _SpyCalendarController.new,
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: AddFlow(
                  key: ValueKey('flow_other_day'),
                  initialKind: AddKind.expense,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final key in ['8', '2', '0']) {
          await tester.tap(find.bySemanticsLabel(key));
          await tester.pump();
        }
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Sunday Market',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Tap Yesterday, 4 Oct (yesterday, not today)
        await tester.tap(find.bySemanticsLabel('Yesterday, 4 Oct'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Groceries'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Cash'));
        await tester.pumpAndSettle();

        // Review receipt: subtitle is empty (no time at 00:00) and footerDate is "SUN 4 OCT", never "12:00 AM"
        expect(find.text('Does this look right?'), findsOneWidget);
        final receipt = tester.widget<CoveReceipt>(find.byType(CoveReceipt));
        expect(receipt.subtitle, isEmpty);
        expect(receipt.footerDate, equals('SUN 4 OCT'));
        expect(find.textContaining('12:00 AM'), findsNothing);

        await tester.tap(find.bySemanticsLabel('Add expense'));
        await tester.pumpAndSettle();

        expect(spyExpense.calls, hasLength(1));
        expect(
          spyExpense.calls.single.expenseDate,
          equals(DateTime(2026, 10, 4, 0, 0)),
        );
      });
    },
  );

  testWidgets(
    '14. Routine context: RoutineScreen Add button passes selected routineId (preselects Which days, still asked and matched/created); tapping an hour row passes routineId and hour * 60',
    (tester) async {
      await loadCoveFonts();
      late _SpyRoutineController spyRoutine;

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final weekendRoutine = Routine(
          id: 'routine_weekend',
          homeId: 'home_1',
          name: 'Weekend Flow',
          days: const <int>[6, 7], // Sat, Sun
          createdAt: fixedToday,
        );
        final weekdayRoutine = Routine(
          id: 'routine_weekday',
          homeId: 'home_1',
          name: 'Weekday Focus',
          days: const <int>[1, 2, 3, 4, 5],
          createdAt: fixedToday,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              routineBuilder: (ref) =>
                  spyRoutine = _SpyRoutineController(ref),
              routines: <Routine>[weekendRoutine, weekdayRoutine],
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const RoutineScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // First routine tab is "Weekend Flow" (days {6, 7}).
        // Tap header "Add Event" button -> opens AddFlow with routineId: 'routine_weekend'
        await tester.tap(find.bySemanticsLabel('Add Event'));
        await tester.pumpAndSettle();

        // Step 1 of 5: What is it?
        expect(find.text('What is it?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Farmers market',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 5: When, usually? -> default 9:00 AM (540)
        expect(find.text('When, usually?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 3 of 5: For how long? -> 30 min (auto-advances to Step 4)
        expect(find.text('For how long?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('30 min'));
        await tester.pumpAndSettle();

        // Step 4 of 6: Which days? is STILL asked and preselected to Weekend Flow's days {6, 7}
        expect(find.text('Which days?'), findsOneWidget);
        final weekToggles = tester.widget<AddWeekToggles>(
          find.byType(AddWeekToggles),
        );
        expect(weekToggles.selectedDays, equals(const <int>{6, 7}));

        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 5 of 6: Whose is it?
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 6 of 6: Review -> matches existing 'routine_weekend' set
        expect(find.text('Does this look right?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Add routine'));
        await tester.pumpAndSettle();

        expect(spyRoutine.createdRoutines, isEmpty);
        expect(spyRoutine.createdEvents, hasLength(1));
        expect(spyRoutine.createdEvents.single.routineId, 'routine_weekend');
        expect(spyRoutine.createdEvents.single.title, 'Farmers market');
        expect(spyRoutine.createdEvents.single.startMinutes, 540);
        expect(spyRoutine.createdEvents.single.endMinutes, 570);

        // Close the sheet
        await tester.tap(find.bySemanticsLabel('Done'));
        await tester.pumpAndSettle();

        // Now tap an hour row on RoutineScreen (e.g. 7 AM -> hour 7 => startMinutes = 420)
        await tester.tap(find.text('7 AM'));
        await tester.pumpAndSettle();

        expect(find.text('What is it?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Long run',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 6: When, usually? is preselected to 7:00 AM (420 min)
        expect(find.text('When, usually?'), findsOneWidget);
        final clockFace = tester.widget<AddClockFace>(
          find.byType(AddClockFace),
        );
        expect(clockFace.hour, equals(7));
        expect(clockFace.minute, equals(0));
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 3 of 6: For how long? -> 45 min
        await tester.tap(find.bySemanticsLabel('45 min'));
        await tester.pumpAndSettle();

        // Step 4 of 6: Which days? is preselected to {6, 7}; toggle Friday (5) on so it creates a new set {5, 6, 7}
        expect(find.text('Which days?'), findsOneWidget);
        expect(
          tester.widget<AddWeekToggles>(find.byType(AddWeekToggles)).selectedDays,
          equals(const <int>{6, 7}),
        );
        await tester.tap(find.bySemanticsLabel('Friday'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 5 of 6: Whose is it?
        expect(find.text('Whose is it?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        await tester.tap(find.bySemanticsLabel('Add routine'));
        await tester.pumpAndSettle();

        expect(spyRoutine.createdRoutines, hasLength(1));
        expect(spyRoutine.createdRoutines.single.days, const <int>[5, 6, 7]);
        expect(spyRoutine.createdEvents, hasLength(2));
        expect(
          spyRoutine.createdEvents.last.routineId,
          'created_routine_1',
        );
        expect(spyRoutine.createdEvents.last.startMinutes, 420);
        expect(spyRoutine.createdEvents.last.endMinutes, 465);
      });
    },
  );

  testWidgets(
    '15. "Add Loan or EMI" on EmiTrackerScreen opens commitment flow with cycle preselected to EMI (9 steps from the start, cycle still shown and changeable)',
    (tester) async {
      await loadCoveFonts();
      _SpySubscriptionController? spySub;

      await withClock(Clock.fixed(fixedNow), () async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: buildOverrides(
              expenseBuilder: _SpyExpenseController.new,
              calendarBuilder: _SpyCalendarController.new,
              subscriptionBuilder: (ref) =>
                  spySub = _SpySubscriptionController(ref),
            ),
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const EmiTrackerScreen(initialSubscriptions: []),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "Add Loan or EMI" button on EmiTrackerScreen
        await tester.tap(find.text('Add Loan or EMI'));
        await tester.pumpAndSettle();

        // Step 1 shows 9 steps from the start (EMI steps present from step 1)
        expect(
          find.text('COMMITMENT · 1 OF 9', findRichText: true),
          findsOneWidget,
        );
        expect(
          tester.widget<AddProgressSegments>(find.byType(AddProgressSegments)).totalSteps,
          equals(9),
        );
        expect(find.text('What is it?'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Washing machine',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 9: How much, each time?
        expect(
          find.text('COMMITMENT · 2 OF 9', findRichText: true),
          findsOneWidget,
        );
        for (final key in ['2', '5', '0', '0']) {
          await tester.tap(find.bySemanticsLabel(key));
          await tester.pump();
        }
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 3 of 9: How often does it come? -> still shown, preselected to EMI, and changeable!
        expect(
          find.text('COMMITMENT · 3 OF 9', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('How often does it come?'), findsOneWidget);
        final choiceList = tester.widget<AddChoiceList<CommitmentCycleOption>>(
          find.byType(AddChoiceList<CommitmentCycleOption>),
        );
        expect(choiceList.selectedValue, equals(CommitmentCycleOption.emi));

        // Verify it is changeable (e.g. tap Every month -> changes to 7 steps; go back and re-select EMI)
        await tester.tap(
          find.bySemanticsLabel('Every month, twelve times a year'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('COMMITMENT · 4 OF 7', findRichText: true),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(
            of: find.byType(AddFlow),
            matching: find.bySemanticsLabel('Back'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsLabel('It ends — an EMI, a number of instalments'),
        );
        await tester.pumpAndSettle();

        // Step 4 of 9: How many instalments in all?
        expect(
          find.text('COMMITMENT · 4 OF 9', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('How many instalments in all?'), findsOneWidget);
        expect(spySub?.calls ?? const <CommitmentCreateArgs>[], isEmpty);
      });
    },
  );
}
