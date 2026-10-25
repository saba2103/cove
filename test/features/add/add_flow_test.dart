import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/slips/cove_band.dart';
import 'package:cove/core/widgets/slips/cove_habit_card.dart';
import 'package:cove/core/widgets/slips/cove_note.dart';
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
import 'package:cove/features/subscriptions/subscription_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../golden/golden_harness.dart';

class _SpyExpenseController extends ExpenseController {
  final List<ExpenseCreateArgs> calls = <ExpenseCreateArgs>[];
  bool shouldFail = false;
  Completer<void>? inFlightCompleter;

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
    calls.add(
      ExpenseCreateArgs(
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
      ),
    );
    return 'exp-created-${calls.length}';
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
      })> addedItems = <({
    String listId,
    String title,
    String? notes,
    DateTime? dueDate,
    String? listName,
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
  }) async {
    addedItems.add((
      listId: listId,
      title: title,
      notes: notes,
      dueDate: dueDate,
      listName: listName,
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
      })> createdEvents = <({
    String routineId,
    String title,
    int startMinutes,
    int endMinutes,
  })>[];
  final List<String> callOrder = <String>[];
  bool shouldFailCreateRoutineEvent = false;

  _SpyRoutineController(super.ref);

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
      activeHomeExpensesProvider.overrideWith(
        (ref) => Stream<List<LocalExpense>>.value(const <LocalExpense>[]),
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
        await tester.tap(find.bySemanticsLabel('Back'));
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

        // Step 4 of 5: Where?
        expect(find.text('Where?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Toit',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 5 of 5: Review
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

        // Commit on Step 5
        await tester.tap(find.bySemanticsLabel('Add event'));
        await tester.pumpAndSettle();

        expect(spyCalendar.calls, hasLength(2));
        final allDayCall = spyCalendar.calls.last;
        expect(allDayCall.title, equals('Diwali holiday'));
        expect(allDayCall.isAllDay, isTrue);
        expect(allDayCall.location, isNull);
        expect(allDayCall.startTime, equals(DateTime(2026, 10, 6, 0, 0)));
        expect(allDayCall.endTime, equals(DateTime(2026, 10, 6, 23, 59)));
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

        // Step 3 of 4: By when? -> tap Tomorrow, 6 Oct
        expect(find.text('By when?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Tomorrow, 6 Oct'));
        await tester.pumpAndSettle();

        // Step 4 of 4: Review -> CoveNote
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

        // --- Case B: 1 list -> Which list? skipped (3 steps); No particular day -> dueDate null ---
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

        // Directly on By when? (Step 2 of 3 — Which list skipped)
        expect(find.text('By when?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('No particular day'));
        await tester.pumpAndSettle();

        // Step 3 of 3: Review -> CoveNote with "No particular day"
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

        // Step 1 of 4: What needs doing?
        expect(find.text('What needs doing?'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Fix kitchen tap',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 2 of 4: Name the list
        expect(find.text('Name the list'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('add_flow_text_input')),
          'Repairs',
        );
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 3 of 4: By when?
        expect(find.text('By when?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Today, 5 Oct'));
        await tester.pumpAndSettle();

        // Step 4 of 4: Review -> CoveNote
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
        expect(find.text('Does this look right?'), findsOneWidget);
        final habitCard = tester.widget<CoveHabitCard>(
          find.byType(CoveHabitCard),
        );
        expect(habitCard.title, 'Morning walk');
        expect(habitCard.daysRunning, 0);
        expect(habitCard.isDoneToday, isFalse);
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

        // Step 4 of 7: When is the next one due? (AddNextDatePicker)
        expect(find.text('When is the next one due?'), findsWidgets);
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

        // Step 4 of 5: Which days? -> default Mon-Fri {1, 2, 3, 4, 5}
        expect(find.text('Which days?'), findsOneWidget);
        await tester.tap(find.bySemanticsLabel('Next'));
        await tester.pumpAndSettle();

        // Step 5 of 5: Review -> CoveBand
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
}
