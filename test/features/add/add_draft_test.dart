import 'package:clock/clock.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/habits/habit_controller.dart';
import 'package:cove/features/habits/habit_schedule.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixedNow = DateTime(2026, 10, 10, 9, 30);
  final fixedToday = DateTime(2026, 10, 10);

  T runWithFixedClock<T>(T Function() body) {
    return withClock(Clock.fixed(fixedNow), body);
  }

  group('1. Anchored days & dayLabel', () {
    test(
      'Expense anchored days end at the anchor; task and event days start at it; a calendar anchor three days out shifts all three',
      () => runWithFixedClock(() {
        final anchor = fixedToday; // Sat 10 Oct 2026

        final expenseDays = anchoredDays(AddKind.expense, anchor);
        expect(expenseDays, hasLength(7));
        expect(expenseDays.first, DateTime(2026, 10, 4));
        expect(expenseDays.last, anchor);
        expect(expenseDays, <DateTime>[
          DateTime(2026, 10, 4),
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 6),
          DateTime(2026, 10, 7),
          DateTime(2026, 10, 8),
          DateTime(2026, 10, 9),
          DateTime(2026, 10, 10),
        ]);

        final taskDays = anchoredDays(AddKind.task, anchor);
        final eventDays = anchoredDays(AddKind.event, anchor);
        expect(taskDays, hasLength(7));
        expect(eventDays, hasLength(7));
        expect(taskDays.first, anchor);
        expect(taskDays.last, DateTime(2026, 10, 16));
        expect(eventDays, taskDays);

        // Habit, commitment, and routine have no anchored date strip.
        expect(anchoredDays(AddKind.habit, anchor), isEmpty);
        expect(anchoredDays(AddKind.commitment, anchor), isEmpty);
        expect(anchoredDays(AddKind.routine, anchor), isEmpty);

        // Calendar anchor three days out shifts all three by +3 days.
        final calendarAnchor = DateTime(2026, 10, 13); // Tue 13 Oct 2026
        final shiftedExpenseDays =
            anchoredDays(AddKind.expense, calendarAnchor);
        final shiftedTaskDays = anchoredDays(AddKind.task, calendarAnchor);
        final shiftedEventDays = anchoredDays(AddKind.event, calendarAnchor);

        expect(shiftedExpenseDays.first, DateTime(2026, 10, 7));
        expect(shiftedExpenseDays.last, calendarAnchor);
        expect(shiftedTaskDays.first, calendarAnchor);
        expect(shiftedTaskDays.last, DateTime(2026, 10, 19));
        expect(shiftedEventDays.first, calendarAnchor);
        expect(shiftedEventDays.last, DateTime(2026, 10, 19));
      }),
    );

    test(
      'dayLabel formats Today, Yesterday, Tomorrow, and weekday names with d MMM',
      () => runWithFixedClock(() {
        final today = DateTime(2026, 10, 5); // Monday, 5 Oct 2026
        expect(dayLabel(DateTime(2026, 10, 5), today), 'Today, 5 Oct');
        expect(dayLabel(DateTime(2026, 10, 4), today), 'Yesterday, 4 Oct');
        expect(dayLabel(DateTime(2026, 10, 6), today), 'Tomorrow, 6 Oct');
        expect(dayLabel(DateTime(2026, 10, 7), today), 'Wednesday, 7 Oct');
        expect(dayLabel(DateTime(2026, 9, 29), today), 'Tuesday, 29 Sep');
      }),
    );
  });

  group('2. Expense who/split/private combinations', () {
    test(
      'produces every (paidBy, visibility) combination ExpenseFormSheet creates and none it cannot',
      () => runWithFixedClock(() {
        const myId = 'user_saba';
        const partnerId = 'user_ancy';

        // Explicit list of valid (paidBy, visibility) pairs for an expense:
        // - paidBy is either viewer (myId) or partner (partnerId) — never 'split'.
        // - visibility is shared (split on), partnerCanSee (split off), or
        //   privateToMe (private on, which selects viewer, turns split off, and
        //   disables the partner tile).
        const expectedCombinations = <(String, ExpenseVisibility)>[
          (myId, ExpenseVisibility.shared),
          (partnerId, ExpenseVisibility.shared),
          (myId, ExpenseVisibility.partnerCanSee),
          (partnerId, ExpenseVisibility.partnerCanSee),
          (myId, ExpenseVisibility.privateToMe),
        ];

        final baseDraft = ExpenseDraft(
          amount: 2140,
          title: "Namdhari's",
          expenseDate: fixedToday,
          category: 'Groceries',
          viewerUserId: myId,
          partnerUserId: partnerId,
          hasPartner: true,
        );

        final produced = <(String, ExpenseVisibility)>{};

        for (final payer in ExpensePayer.values) {
          for (final split in <bool>[true, false]) {
            for (final priv in <bool>[false, true]) {
              final draft = baseDraft.copyWith(
                payer: payer,
                splitHalfAndHalf: split,
                isPrivate: priv,
              );
              final args = draft.toCreateArgs();
              produced.add((args.paidBy, args.visibility));

              if (priv) {
                // Private selects you, turns Split off, and disables the partner tile.
                expect(draft.payer, ExpensePayer.you);
                expect(draft.splitHalfAndHalf, isFalse);
                expect(draft.availablePayers(), <ExpensePayer>[
                  ExpensePayer.you,
                ]);
                expect(draft.canToggleSplit(), isFalse);
              }
            }
          }
        }

        expect(produced, unorderedEquals(expectedCombinations));
        expect(
          produced.any((pair) => pair.$1 == 'split'),
          isFalse,
          reason: 'ExpenseFormSheet never sets paidBy to "split".',
        );
        expect(
          produced.contains((partnerId, ExpenseVisibility.privateToMe)),
          isFalse,
          reason:
              'Private expenses belong to the viewer device only and disable partner selection.',
        );
      }),
    );
  });

  group('3. Habit frequency options and HabitSchedule round-trip', () {
    test(
      'each How-often option produces the exact cadence and targetDaysPerWeek of HabitFormSheet and round-trips through HabitSchedule',
      () => runWithFixedClock(() {
        HabitCreateArgs buildFromHabitFormRule({
          required String frequency,
          required Set<int> selectedDays,
        }) {
          final schedule = HabitSchedule(
            frequency: frequency,
            daysOfWeek: selectedDays.toList(),
          );
          final cadenceString = schedule.toCadenceString();
          final effectiveTarget =
              frequency == 'daily' ? 7 : selectedDays.length;
          return HabitCreateArgs(
            name: 'Read twenty pages',
            cadence: cadenceString,
            targetDaysPerWeek: effectiveTarget,
            visibility: HabitVisibility.shared,
          );
        }

        final cases = <(
          HabitFrequencyOption,
          Set<int>,
          String,
          Set<int>,
          String,
          int,
        )>[
          (
            HabitFrequencyOption.everyDay,
            <int>{1, 2, 3, 4, 5, 6, 7},
            'daily',
            <int>{1, 2, 3, 4, 5, 6, 7},
            'daily',
            7,
          ),
          (
            HabitFrequencyOption.weekdays,
            <int>{1, 2, 3, 4, 5},
            'custom',
            <int>{1, 2, 3, 4, 5},
            'custom:1,2,3,4,5',
            5,
          ),
          (
            HabitFrequencyOption.weekends,
            <int>{6, 7},
            'custom',
            <int>{6, 7},
            'custom:6,7',
            2,
          ),
          (
            HabitFrequencyOption.pickDays,
            <int>{1, 3, 5},
            'custom',
            <int>{1, 3, 5},
            'custom:1,3,5',
            3,
          ),
        ];

        for (final (
              option,
              customDays,
              formFreq,
              formDays,
              expectedCadence,
              expectedTarget
            ) in cases) {
          final draft = HabitDraft(
            name: 'Read twenty pages',
            frequencyOption: option,
            customDays: customDays,
            visibility: HabitVisibility.shared,
          );
          expect(draft.isComplete, isTrue);

          final args = draft.toCreateArgs();
          final expectedFromForm = buildFromHabitFormRule(
            frequency: formFreq,
            selectedDays: formDays,
          );

          expect(args, expectedFromForm);
          expect(args.cadence, expectedCadence);
          expect(args.targetDaysPerWeek, expectedTarget);

          // Parse back via HabitSchedule.parse (both ways).
          final parsed = HabitSchedule.parse(
            args.cadence,
            targetDays: args.targetDaysPerWeek,
          );
          expect(parsed.frequency, formFreq);
          expect(parsed.daysOfWeek.toSet(), formDays);
          expect(parsed.toCadenceString(), args.cadence);
        }
      }),
    );
  });

  group('4. Commitment nextBillingDate and EMI invariants', () {
    test(
      'monthly on the 8th when today is the 10th -> 8th of next month; on the 10th -> today; quarterly/yearly never before today; EMI requires total >= 1 and paid < total',
      () => runWithFixedClock(() {
        final today = DateTime(2026, 10, 10);

        // Monthly on the 8th when today is the 10th -> 8 Nov 2026.
        final dueOn8th = CommitmentDraft(
          name: 'Rent',
          amount: 28000,
          cycle: CommitmentCycleOption.everyMonth,
          dayOfMonth: 8,
          today: today,
        ).toCreateArgs(today: today);
        expect(dueOn8th.nextBillingDate, DateTime(2026, 11, 8));
        expect(dueOn8th.billingCycle, 'monthly');

        // Monthly on the 10th when today is the 10th -> 10 Oct 2026 (today).
        final dueOn10th = CommitmentDraft(
          name: 'BESCOM electricity',
          amount: 1850,
          cycle: CommitmentCycleOption.everyMonth,
          dayOfMonth: 10,
          today: today,
        ).toCreateArgs(today: today);
        expect(dueOn10th.nextBillingDate, DateTime(2026, 10, 10));

        // Quarterly / yearly next-date never before today.
        final quarterlyPastInYear = CommitmentDraft(
          name: 'Water filter service',
          amount: 1200,
          cycle: CommitmentCycleOption.everyQuarter,
          dueMonth: 3, // March (already passed in 2026)
          dayOfMonth: 15,
          today: today,
        ).toCreateArgs(today: today);
        expect(quarterlyPastInYear.billingCycle, 'every_3_months');
        expect(quarterlyPastInYear.nextBillingDate, DateTime(2027, 3, 15));
        expect(quarterlyPastInYear.nextBillingDate.isBefore(today), isFalse);

        final yearlySameDayToday = CommitmentDraft(
          name: 'Insurance',
          amount: 12000,
          cycle: CommitmentCycleOption.everyYear,
          dueMonth: 10,
          dayOfMonth: 10,
          today: today,
        ).toCreateArgs(today: today);
        expect(yearlySameDayToday.billingCycle, 'annual');
        expect(yearlySameDayToday.nextBillingDate, today);

        final yearlyYesterday = CommitmentDraft(
          name: 'Domain renewal',
          amount: 1500,
          cycle: CommitmentCycleOption.everyYear,
          dueMonth: 10,
          dayOfMonth: 9,
          today: today,
        ).toCreateArgs(today: today);
        expect(yearlyYesterday.nextBillingDate, DateTime(2027, 10, 9));
        expect(yearlyYesterday.nextBillingDate.isBefore(today), isFalse);

        // EMI requires total >= 1 and paid < total.
        const emiZeroTotal = CommitmentDraft(
          name: 'MacBook EMI',
          amount: 8500,
          cycle: CommitmentCycleOption.emi,
          totalInstallments: 0,
          paidInstallments: 0,
          dayOfMonth: 5,
        );
        expect(emiZeroTotal.isAnswered(AddStep.commitmentEmiTotal), isFalse);
        expect(emiZeroTotal.isComplete, isFalse);

        const emiPaidEqualsTotal = CommitmentDraft(
          name: 'MacBook EMI',
          amount: 8500,
          cycle: CommitmentCycleOption.emi,
          totalInstallments: 12,
          paidInstallments: 12,
          dayOfMonth: 5,
        );
        expect(emiPaidEqualsTotal.isAnswered(AddStep.commitmentEmiPaid), isFalse);
        expect(emiPaidEqualsTotal.isComplete, isFalse);

        const emiPaidExceedsTotal = CommitmentDraft(
          name: 'MacBook EMI',
          amount: 8500,
          cycle: CommitmentCycleOption.emi,
          totalInstallments: 12,
          paidInstallments: 15,
          dayOfMonth: 5,
        );
        expect(emiPaidExceedsTotal.isAnswered(AddStep.commitmentEmiPaid), isFalse);
        expect(emiPaidExceedsTotal.isComplete, isFalse);

        final validEmi = CommitmentDraft(
          name: 'MacBook EMI',
          amount: 8500,
          cycle: CommitmentCycleOption.emi,
          totalInstallments: 12,
          paidInstallments: 3,
          dayOfMonth: 5,
          today: today,
        );
        expect(validEmi.isComplete, isTrue);
        final emiArgs = validEmi.toCreateArgs(today: today);
        expect(emiArgs.totalInstallments, 12);
        expect(emiArgs.paidInstallments, 3);
        expect(emiArgs.nextBillingDate, DateTime(2026, 11, 5));
        expect(emiArgs.endDate, DateTime(2026, 10 + 9, 5));
      }),
    );
  });

  group('5. Routine matching, naming, and endMinutes cap', () {
    test(
      'Mon-Fri finds an existing routine whose daysJson is "[1,2,3,4,5]", produces Everyday / Weekdays / Weekend / "Mon, Wed, Fri" when none matches, and caps endMinutes at 1439',
      () => runWithFixedClock(() {
        final existingLocal = <LocalRoutine>[
          LocalRoutine(
            id: 'routine_weekdays_1',
            homeId: 'home_1',
            name: 'Morning rhythm',
            daysJson: '[1,2,3,4,5]',
            createdAt: fixedNow,
          ),
        ];

        final draftMatching = RoutineDraft(
          title: 'Brew filter coffee',
          startMinutes: 7 * 60 + 30,
          durationMinutes: 30,
          days: const <int>{1, 2, 3, 4, 5},
        );
        final matchedArgs = draftMatching.toCreateArgs(
          existingLocalRoutines: existingLocal,
        );
        expect(matchedArgs.existingRoutineId, 'routine_weekdays_1');
        expect(matchedArgs.newRoutineName, isNull);
        expect(matchedArgs.days, const <int>[1, 2, 3, 4, 5]);
        expect(matchedArgs.startMinutes, 450);
        expect(matchedArgs.endMinutes, 480);

        // When no existing routine matches, a new name is produced:
        expect(
          RoutineDraft(
            title: 'Stretch',
            startMinutes: 480,
            durationMinutes: 15,
            days: const <int>{1, 2, 3, 4, 5, 6, 7},
          ).toCreateArgs().newRoutineName,
          'Everyday',
        );
        expect(
          RoutineDraft(
            title: 'Brew filter coffee',
            startMinutes: 450,
            durationMinutes: 30,
            days: const <int>{1, 2, 3, 4, 5},
          ).toCreateArgs().newRoutineName,
          'Weekdays',
        );
        expect(
          RoutineDraft(
            title: 'Long walk',
            startMinutes: 540,
            durationMinutes: 60,
            days: const <int>{6, 7},
          ).toCreateArgs().newRoutineName,
          'Weekend',
        );
        expect(
          RoutineDraft(
            title: 'Water balcony plants',
            startMinutes: 510,
            durationMinutes: 15,
            days: const <int>{1, 3, 5},
          ).toCreateArgs().newRoutineName,
          'Mon, Wed, Fri',
        );

        // endMinutes caps at 1439 (23:59).
        final lateRoutine = RoutineDraft(
          title: 'Night reading',
          startMinutes: 23 * 60 + 30, // 1410 (23:30)
          durationMinutes: 120,
          days: const <int>{1, 2, 3, 4, 5, 6, 7},
        ).toCreateArgs();
        expect(lateRoutine.startMinutes, 1410);
        expect(lateRoutine.endMinutes, 1439);
      }),
    );
  });

  group('6. Step counts & solo-home partner/private behavior', () {
    test(
      'expense has 7, event 5, task 3 or 4, habit 4, commitment 7 or 9 (EMI), routine 5; in a home with no partner, partner options are gone but private toggle remains',
      () => runWithFixedClock(() {
        final ctxWithPartner = AddFlowContext(
          anchor: fixedToday,
          today: fixedToday,
          hasPartner: true,
          listCount: 2,
          openedFromList: false,
        );

        // Expense: 7 steps
        final expense = ExpenseDraft.initial(ctxWithPartner);
        expect(stepsFor(expense, ctxWithPartner), hasLength(7));

        // Event: 5 steps
        final event = EventDraft.initial(ctxWithPartner);
        expect(stepsFor(event, ctxWithPartner), hasLength(5));

        // Task: 4 steps when listCount > 1 && !openedFromList, or listCount == 0 && !openedFromList
        final taskMultiList = TaskDraft.initial(ctxWithPartner);
        expect(stepsFor(taskMultiList, ctxWithPartner), <AddStep>[
          AddStep.taskTitle,
          AddStep.taskWhichList,
          AddStep.taskByWhen,
          AddStep.review,
        ]);
        expect(stepsFor(taskMultiList, ctxWithPartner), hasLength(4));

        final ctxZeroLists = ctxWithPartner.copyWith(listCount: 0);
        final taskZeroLists = TaskDraft.initial(ctxZeroLists);
        expect(stepsFor(taskZeroLists, ctxZeroLists), <AddStep>[
          AddStep.taskTitle,
          AddStep.taskNameTheList,
          AddStep.taskByWhen,
          AddStep.review,
        ]);
        expect(stepsFor(taskZeroLists, ctxZeroLists), hasLength(4));

        // Task: 3 steps when listCount == 1 or openedFromList == true
        final ctxOneList = ctxWithPartner.copyWith(listCount: 1);
        expect(
          stepsFor(TaskDraft.initial(ctxOneList), ctxOneList),
          hasLength(3),
        );
        final ctxOpenedFromList = ctxWithPartner.copyWith(
          listCount: 3,
          openedFromList: true,
        );
        expect(
          stepsFor(TaskDraft.initial(ctxOpenedFromList), ctxOpenedFromList),
          hasLength(3),
        );

        // Habit: 4 steps
        final habit = HabitDraft.initial(ctxWithPartner);
        expect(stepsFor(habit, ctxWithPartner), hasLength(4));

        // Commitment: 7 steps for monthly / quarterly / yearly, 9 for EMI
        final commitmentMonthly = CommitmentDraft.initial(ctxWithPartner);
        expect(stepsFor(commitmentMonthly, ctxWithPartner), hasLength(7));
        expect(
          stepsFor(
            commitmentMonthly.copyWith(cycle: CommitmentCycleOption.everyQuarter),
            ctxWithPartner,
          ),
          hasLength(7),
        );
        expect(
          stepsFor(
            commitmentMonthly.copyWith(cycle: CommitmentCycleOption.everyYear),
            ctxWithPartner,
          ),
          hasLength(7),
        );
        final commitmentEmi = commitmentMonthly.copyWith(
          cycle: CommitmentCycleOption.emi,
        );
        expect(stepsFor(commitmentEmi, ctxWithPartner), hasLength(9));

        // Routine: 5 steps
        final routine = RoutineDraft.initial(ctxWithPartner);
        expect(stepsFor(routine, ctxWithPartner), hasLength(5));

        // Solo home (hasPartner == false): partner options are gone, private toggle remains.
        final soloCtx = ctxWithPartner.copyWith(hasPartner: false);

        final soloExpense = ExpenseDraft.initial(soloCtx).copyWith(
          amount: 500,
          title: 'Coffee beans',
          category: 'Groceries',
        );
        expect(stepsFor(soloExpense, soloCtx), hasLength(7));
        expect(
          soloExpense.availablePayers(soloCtx),
          <ExpensePayer>[ExpensePayer.you],
        );
        expect(soloExpense.canToggleSplit(soloCtx), isFalse);
        expect(soloExpense.canTogglePrivate(soloCtx), isTrue);
        expect(
          soloExpense.copyWith(isPrivate: true).toCreateArgs().visibility,
          ExpenseVisibility.privateToMe,
        );

        final soloCommitment = CommitmentDraft.initial(soloCtx).copyWith(
          name: 'iCloud',
          amount: 75,
        );
        expect(stepsFor(soloCommitment, soloCtx), hasLength(7));
        expect(
          soloCommitment.availableOwners(soloCtx),
          <CommitmentOwner>[CommitmentOwner.you],
        );
        expect(soloCommitment.canTogglePrivate(soloCtx), isTrue);
        expect(
          soloCommitment
              .copyWith(isPrivate: true)
              .toCreateArgs(today: fixedToday)
              .isPrivate,
          isTrue,
        );

        final soloHabit = HabitDraft.initial(soloCtx);
        expect(stepsFor(soloHabit, soloCtx), hasLength(4));
        expect(
          soloHabit.availableVisibilities(soloCtx),
          <HabitVisibility>[HabitVisibility.privateToMe],
        );
        expect(soloHabit.canTogglePrivate(soloCtx), isTrue);
      }),
    );

    test(
      'EventDraft and TaskDraft toCreateArgs and isAnswered behave as specified',
      () => runWithFixedClock(() {
        final timedEvent = EventDraft(
          title: '  Dinner with Meera & Rohan  ',
          day: DateTime(2026, 10, 15),
          hour: 20,
          minute: 30,
          isAllDay: false,
          location: '  Toit, Indiranagar  ',
        );
        expect(timedEvent.isComplete, isTrue);
        expect(timedEvent.isAnswered(AddStep.eventLocation), isTrue);
        final timedArgs = timedEvent.toCreateArgs();
        expect(timedArgs.title, 'Dinner with Meera & Rohan');
        expect(timedArgs.startTime, DateTime(2026, 10, 15, 20, 30));
        expect(timedArgs.endTime, DateTime(2026, 10, 15, 21, 30));
        expect(timedArgs.isAllDay, isFalse);
        expect(timedArgs.location, 'Toit, Indiranagar');

        final allDayEvent = timedEvent.copyWith(
          isAllDay: true,
          location: null,
        );
        expect(allDayEvent.isAnswered(AddStep.eventLocation), isTrue);
        final allDayArgs = allDayEvent.toCreateArgs();
        expect(allDayArgs.startTime, DateTime(2026, 10, 15, 0, 0));
        expect(allDayArgs.endTime, DateTime(2026, 10, 15, 23, 59));
        expect(allDayArgs.isAllDay, isTrue);
        expect(allDayArgs.location, isNull);

        final taskWithDay = TaskDraft(
          title: '  Call the plumber  ',
          listId: 'list_home',
          dueDate: DateTime(2026, 10, 12),
          listCount: 2,
          openedFromList: false,
        );
        expect(taskWithDay.isComplete, isTrue);
        final taskArgs = taskWithDay.toCreateArgs();
        expect(taskArgs.listId, 'list_home');
        expect(taskArgs.title, 'Call the plumber');
        expect(taskArgs.dueDate, DateTime(2026, 10, 12));

        final taskNoDay = taskWithDay.copyWith(noParticularDay: true);
        expect(taskNoDay.isAnswered(AddStep.taskByWhen), isTrue);
        expect(taskNoDay.toCreateArgs().dueDate, isNull);
      }),
    );
  });
}
