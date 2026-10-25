import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/add/add_flow.dart';
import 'package:cove/features/add/widgets/add_step_pieces.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
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
        (ref) => Stream<List<LocalList>>.value(const <LocalList>[]),
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
    ];
  }

  testWidgets(
    '1. Walk an expense through all 7 steps; Add calls logExpense once with the draft args; Coming in 3.12e/f toast works',
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

        // Tapping Habit shows "Coming in 3.12e/f" toast and stays on picker
        await tester.tap(
          find.byKey(const ValueKey('add_picker_tile_habit')),
        );
        await tester.pump();
        expect(find.text('Coming in 3.12e/f'), findsWidgets);

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
}
