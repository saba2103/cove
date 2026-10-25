import 'package:cove/features/notifications/notification_copy.dart';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpecRowSent {
  final String description;
  final DecryptedEvent event;
  final NotificationContext Function(NotificationContext base)? customizeCtx;
  final String expectedTitle;
  final String expectedBody;
  final String? expectedBatchKey;
  final NotificationModule expectedGroupKey;
  final String? expectedBatchLine;
  final bool expectedCanStartCard;

  const _SpecRowSent({
    required this.description,
    required this.event,
    required this.expectedTitle,
    required this.expectedBody,
    required this.expectedGroupKey,
    this.customizeCtx,
    this.expectedBatchKey,
    this.expectedBatchLine,
    this.expectedCanStartCard = true,
  });
}

class _SpecRowSilent {
  final String description;
  final DecryptedEvent event;
  final NotificationContext Function(NotificationContext base)? customizeCtx;

  const _SpecRowSilent({
    required this.description,
    required this.event,
    this.customizeCtx,
  });
}

void main() {
  // Fixed clock: Thursday, 5 Nov 2026.
  // - Two days out: Saturday, 7 Nov 2026 -> "Saturday" / "Saturday, 7:30 PM"
  // - Eight days out (from Friday, 6 Nov 2026): Saturday, 14 Nov 2026 -> "Sat 14 Nov" / "Sat 14 Nov, 7:30 PM"
  final fixedToday = DateTime(2026, 11, 5, 10, 0);
  final fixedTodayForEightDaysOut = DateTime(2026, 11, 6, 10, 0);

  NotificationContext baseCtx({
    String partnerName = 'Ancy',
    String homeName = 'Indiranagar',
    String currencySymbol = '₹',
    DateTime? today,
    String viewerUserId = 'viewer_saba',
    int? untickedItemsLeft,
    int? habitStreak,
    bool createdByViewer = false,
    String? listId,
    String? listName,
    String? itemTitle,
    String? habitName,
    DateTime? eventStartTime,
    bool? eventIsAllDay,
    DateTime? previousEventStartTime,
    bool? previousEventIsAllDay,
    bool? calendarDateOrTimeChanged,
    String? billingCycle,
    DateTime? endDate,
    bool isPrivate = false,
  }) {
    return NotificationContext(
      partnerName: partnerName,
      homeName: homeName,
      currencySymbol: currencySymbol,
      today: today ?? fixedToday,
      viewerUserId: viewerUserId,
      untickedItemsLeft: untickedItemsLeft,
      habitStreak: habitStreak,
      createdByViewer: createdByViewer,
      listId: listId,
      listName: listName,
      itemTitle: itemTitle,
      habitName: habitName,
      eventStartTime: eventStartTime,
      eventIsAllDay: eventIsAllDay,
      previousEventStartTime: previousEventStartTime,
      previousEventIsAllDay: previousEventIsAllDay,
      calendarDateOrTimeChanged: calendarDateOrTimeChanged,
      billingCycle: billingCycle,
      endDate: endDate,
      isPrivate: isPrivate,
    );
  }

  group('15-notifications.md §2 — What is sent (table-driven)', () {
    final rows = <_SpecRowSent>[
      // Row 1: list_item_added -> list name | Ancy added {item}
      const _SpecRowSent(
        description: '§2.1 list_item_added — verbatim item and list name',
        event: DecryptedEvent(
          id: 'e1',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'list_item_added',
          payload: {
            'list_id': 'list_groceries',
            'list_name': 'Groceries',
            'title': 'Coffee beans — dark roast',
          },
        ),
        expectedTitle: 'Groceries',
        expectedBody: 'Ancy added Coffee beans — dark roast',
        expectedBatchKey: 'list_groceries',
        expectedGroupKey: NotificationModule.lists,
        expectedBatchLine: '+ Coffee beans — dark roast',
      ),

      // Row 2a: list_item_toggled -> done (five left)
      _SpecRowSent(
        description: '§2.2a list_item_toggled → done (five left)',
        event: const DecryptedEvent(
          id: 'e2a',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'list_item_toggled',
          payload: {
            'list_id': 'list_groceries',
            'list_name': 'Groceries',
            'title': 'Curd, 500g',
            'is_completed': true,
          },
        ),
        customizeCtx: (b) => baseCtx(untickedItemsLeft: 5),
        expectedTitle: 'Groceries',
        expectedBody: 'Ancy ticked off Curd, 500g — five left',
        expectedBatchKey: 'list_groceries',
        expectedGroupKey: NotificationModule.lists,
        expectedBatchLine: '✓ Curd, 500g',
      ),

      // Row 2b: list_item_toggled -> done (nothing left at 0)
      _SpecRowSent(
        description: '§2.2b list_item_toggled → done (nothing left at 0)',
        event: const DecryptedEvent(
          id: 'e2b',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'list_item_toggled',
          payload: {
            'list_id': 'list_groceries',
            'list_name': 'Groceries',
            'title': 'Curd, 500g',
            'is_completed': true,
          },
        ),
        customizeCtx: (b) => baseCtx(untickedItemsLeft: 0),
        expectedTitle: 'Groceries',
        expectedBody: 'Ancy ticked off Curd, 500g — nothing left',
        expectedBatchKey: 'list_groceries',
        expectedGroupKey: NotificationModule.lists,
        expectedBatchLine: '✓ Curd, 500g',
      ),

      // Row 2c: list_item_toggled -> done (eleven left -> 11 left)
      _SpecRowSent(
        description: '§2.2c list_item_toggled → done (11 left — digits beyond 10)',
        event: const DecryptedEvent(
          id: 'e2c',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'list_item_toggled',
          payload: {
            'list_id': 'list_groceries',
            'list_name': 'Groceries',
            'title': 'Curd, 500g',
            'is_completed': true,
          },
        ),
        customizeCtx: (b) => baseCtx(untickedItemsLeft: 11),
        expectedTitle: 'Groceries',
        expectedBody: 'Ancy ticked off Curd, 500g — 11 left',
        expectedBatchKey: 'list_groceries',
        expectedGroupKey: NotificationModule.lists,
        expectedBatchLine: '✓ Curd, 500g',
      ),

      // Row 3: list_created -> Shared lists | Ancy started a new list — {name}
      const _SpecRowSent(
        description: '§2.3 list_created',
        event: DecryptedEvent(
          id: 'e3',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'list_created',
          payload: {
            'id': 'list_coorg',
            'name': 'Coorg trip',
          },
        ),
        expectedTitle: 'Shared lists',
        expectedBody: 'Ancy started a new list — Coorg trip',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.lists,
        expectedBatchLine: null,
      ),

      // Row 4: expense_logged -> Expenses | Ancy logged {amount} for {title}
      const _SpecRowSent(
        description: '§2.4 expense_logged — Indian formatted amount & verbatim title',
        event: DecryptedEvent(
          id: 'e4',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'expense_logged',
          payload: {
            'id': 'exp_1',
            'amount': 24000,
            'title': 'Rent — November',
          },
        ),
        expectedTitle: 'Expenses',
        expectedBody: 'Ancy logged ₹24,000 for Rent — November',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.expenses,
        expectedBatchLine: null,
      ),

      // Row 5a: habit_checkin_toggled -> kept (streak = 1 -> no "days running")
      _SpecRowSent(
        description: '§2.5a habit_checkin_toggled → kept (streak of 1 — no "days running")',
        event: const DecryptedEvent(
          id: 'e5a',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'habit_checkin_toggled',
          payload: {
            'habit_id': 'hab_1',
            'habit_name': 'Read before bed',
            'checked': true,
          },
        ),
        customizeCtx: (b) => baseCtx(habitStreak: 1),
        expectedTitle: 'Read before bed',
        expectedBody: 'Ancy kept it.',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.habits,
        expectedBatchLine: null,
      ),

      // Row 5b: habit_checkin_toggled -> kept (streak = 23 -> Twenty-three days running.)
      _SpecRowSent(
        description: '§2.5b habit_checkin_toggled → kept (streak of 23 — Twenty-three days running.)',
        event: const DecryptedEvent(
          id: 'e5b',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'habit_checkin_toggled',
          payload: {
            'habit_id': 'hab_1',
            'habit_name': 'Read before bed',
            'checked': true,
          },
        ),
        customizeCtx: (b) => baseCtx(habitStreak: 23),
        expectedTitle: 'Read before bed',
        expectedBody: 'Ancy kept it. Twenty-three days running.',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.habits,
        expectedBatchLine: null,
      ),

      // Row 5c: habit_checkin_toggled -> kept (streak = 100 -> digits beyond 99)
      _SpecRowSent(
        description: '§2.5c habit_checkin_toggled → kept (streak of 100 — digits beyond 99)',
        event: const DecryptedEvent(
          id: 'e5c',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'habit_checkin_toggled',
          payload: {
            'habit_id': 'hab_1',
            'habit_name': 'Read before bed',
            'checked': true,
          },
        ),
        customizeCtx: (b) => baseCtx(habitStreak: 100),
        expectedTitle: 'Read before bed',
        expectedBody: 'Ancy kept it. 100 days running.',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.habits,
        expectedBatchLine: null,
      ),

      // Row 6: habit_created -> Habits | Ancy added a habit — {name}
      const _SpecRowSent(
        description: '§2.6 habit_created',
        event: DecryptedEvent(
          id: 'e6',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'habit_created',
          payload: {
            'id': 'hab_2',
            'name': 'Evening walk',
          },
        ),
        expectedTitle: 'Habits',
        expectedBody: 'Ancy added a habit — Evening walk',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.habits,
        expectedBatchLine: null,
      ),

      // Row 7a: calendar_event_added -> two days out (within next 6 days)
      const _SpecRowSent(
        description: '§2.7a calendar_event_added — two days out (Saturday, 7:30 PM)',
        event: DecryptedEvent(
          id: 'e7a',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'calendar_event_added',
          payload: {
            'id': 'cal_1',
            'title': 'Dinner with Amma',
            'start_time': '2026-11-07T19:30:00',
            'is_all_day': false,
          },
        ),
        expectedTitle: 'Dinner with Amma',
        expectedBody: 'Ancy put it in for Saturday, 7:30 PM',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.calendar,
        expectedBatchLine: null,
      ),

      // Row 7b: calendar_event_added -> eight days out (Sat 14 Nov, 7:30 PM)
      _SpecRowSent(
        description: '§2.7b calendar_event_added — eight days out (Sat 14 Nov, 7:30 PM)',
        event: const DecryptedEvent(
          id: 'e7b',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'calendar_event_added',
          payload: {
            'id': 'cal_2',
            'title': 'Dentist appointment',
            'start_time': '2026-11-14T19:30:00',
            'is_all_day': false,
          },
        ),
        customizeCtx: (b) => baseCtx(today: fixedTodayForEightDaysOut),
        expectedTitle: 'Dentist appointment',
        expectedBody: 'Ancy put it in for Sat 14 Nov, 7:30 PM',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.calendar,
        expectedBatchLine: null,
      ),

      // Row 7c: calendar_event_added -> all-day event (no time)
      const _SpecRowSent(
        description: '§2.7c calendar_event_added — all-day two days out (Saturday)',
        event: DecryptedEvent(
          id: 'e7c',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'calendar_event_added',
          payload: {
            'id': 'cal_3',
            'title': 'Diwali cleaning',
            'start_time': '2026-11-07T00:00:00',
            'is_all_day': true,
          },
        ),
        expectedTitle: 'Diwali cleaning',
        expectedBody: 'Ancy put it in for Saturday',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.calendar,
        expectedBatchLine: null,
      ),

      // Row 7d: calendar_event_added -> all-day eight days out (Sat 14 Nov)
      _SpecRowSent(
        description: '§2.7d calendar_event_added — all-day eight days out (Sat 14 Nov)',
        event: const DecryptedEvent(
          id: 'e7d',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'calendar_event_added',
          payload: {
            'id': 'cal_4',
            'title': 'Coorg weekend',
            'start_time': '2026-11-14T00:00:00',
            'is_all_day': true,
          },
        ),
        customizeCtx: (b) => baseCtx(today: fixedTodayForEightDaysOut),
        expectedTitle: 'Coorg weekend',
        expectedBody: 'Ancy put it in for Sat 14 Nov',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.calendar,
        expectedBatchLine: null,
      ),

      // Row 8: calendar_event_updated, date or time changed -> Ancy moved it to {when}
      _SpecRowSent(
        description: '§2.8 calendar_event_updated — date or time changed',
        event: const DecryptedEvent(
          id: 'e8',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'calendar_event_updated',
          payload: {
            'id': 'cal_1',
            'title': 'Dinner with Amma',
            'start_time': '2026-11-14T19:30:00',
            'previous_start_time': '2026-11-07T19:30:00',
            'is_all_day': false,
          },
        ),
        customizeCtx: (b) => baseCtx(today: fixedTodayForEightDaysOut),
        expectedTitle: 'Dinner with Amma',
        expectedBody: 'Ancy moved it to Sat 14 Nov, 7:30 PM',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.calendar,
        expectedBatchLine: null,
      ),

      // Row 9: calendar_event_deleted -> event title | Ancy cancelled it — {day}
      const _SpecRowSent(
        description: '§2.9a calendar_event_deleted — within six days ({day} without time)',
        event: DecryptedEvent(
          id: 'e9a',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'calendar_event_deleted',
          payload: {
            'id': 'cal_1',
            'title': 'Dinner with Amma',
            'start_time': '2026-11-07T19:30:00',
          },
        ),
        expectedTitle: 'Dinner with Amma',
        expectedBody: 'Ancy cancelled it — Saturday',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.calendar,
        expectedBatchLine: null,
      ),

      _SpecRowSent(
        description: '§2.9b calendar_event_deleted — eight days out ({day} without time)',
        event: const DecryptedEvent(
          id: 'e9b',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'calendar_event_deleted',
          payload: {
            'id': 'cal_2',
            'title': 'Dentist appointment',
            'start_time': '2026-11-14T19:30:00',
          },
        ),
        customizeCtx: (b) => baseCtx(today: fixedTodayForEightDaysOut),
        expectedTitle: 'Dentist appointment',
        expectedBody: 'Ancy cancelled it — Sat 14 Nov',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.calendar,
        expectedBatchLine: null,
      ),

      // Row 10: subscription_added -> Commitments | Ancy added {name} — {amount} {a month / a year / every 3 months}
      const _SpecRowSent(
        description: '§2.10a subscription_added — monthly',
        event: DecryptedEvent(
          id: 'e10a',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'subscription_added',
          payload: {
            'id': 'sub_1',
            'name': 'Netflix',
            'amount': 649,
            'billing_cycle': 'monthly',
          },
        ),
        expectedTitle: 'Commitments',
        expectedBody: 'Ancy added Netflix — ₹649 a month',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.subscriptions,
        expectedBatchLine: null,
      ),

      const _SpecRowSent(
        description: '§2.10b subscription_added — yearly',
        event: DecryptedEvent(
          id: 'e10b',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'subscription_added',
          payload: {
            'id': 'sub_2',
            'name': 'Amazon Prime',
            'amount': 1499,
            'billing_cycle': 'yearly',
          },
        ),
        expectedTitle: 'Commitments',
        expectedBody: 'Ancy added Amazon Prime — ₹1,499 a year',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.subscriptions,
        expectedBatchLine: null,
      ),

      const _SpecRowSent(
        description: '§2.10c subscription_added — every 3 months',
        event: DecryptedEvent(
          id: 'e10c',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'subscription_added',
          payload: {
            'id': 'sub_3',
            'name': 'Water purifier filter',
            'amount': 1800,
            'billing_cycle': 'every_3_months',
          },
        ),
        expectedTitle: 'Commitments',
        expectedBody: 'Ancy added Water purifier filter — ₹1,800 every 3 months',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.subscriptions,
        expectedBatchLine: null,
      ),

      // Row 11: subscription_added, EMI -> Commitments | Ancy added an EMI — {amount} a month to {Mon YYYY of the last instalment}
      const _SpecRowSent(
        description: '§2.11 subscription_added (EMI) — last-instalment month from end_date',
        event: DecryptedEvent(
          id: 'e11',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'subscription_added',
          payload: {
            'id': 'sub_emi_1',
            'name': 'Washing machine',
            'amount': 4200,
            'billing_cycle': 'monthly',
            'end_date': '2026-08-05T00:00:00',
          },
        ),
        expectedTitle: 'Commitments',
        expectedBody: 'Ancy added an EMI — ₹4,200 a month to Aug 2026',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.subscriptions,
        expectedBatchLine: null,
      ),

      // Row 12: subscription_cancelled -> Commitments | Ancy paused {name} — {amount} {a month…} back
      const _SpecRowSent(
        description: '§2.12 subscription_cancelled — says "paused"',
        event: DecryptedEvent(
          id: 'e12',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'subscription_cancelled',
          payload: {
            'id': 'sub_1',
            'name': 'Netflix',
            'amount': 649,
            'billing_cycle': 'monthly',
          },
        ),
        expectedTitle: 'Commitments',
        expectedBody: 'Ancy paused Netflix — ₹649 a month back',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.subscriptions,
        expectedBatchLine: null,
      ),

      // Row 13: member_joined -> the home's name | Ancy joined. You are both in.
      const _SpecRowSent(
        description: '§2.13 member_joined — home name title & "Ancy joined. You are both in."',
        event: DecryptedEvent(
          id: 'e13',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'member_joined',
          payload: {},
        ),
        expectedTitle: 'Indiranagar',
        expectedBody: 'Ancy joined. You are both in.',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.home,
        expectedBatchLine: null,
      ),

      // Row 14a: check-in reminder (with label)
      const _SpecRowSent(
        description: '§2.14a checkin_reminder — with custom reminder label',
        event: DecryptedEvent(
          id: 'e14a',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'checkin_reminder',
          payload: {
            'label': 'Sunday tea',
          },
        ),
        expectedTitle: 'Sunday tea',
        expectedBody: 'A quiet moment, together.',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.activity,
        expectedBatchLine: null,
      ),

      // Row 14b: check-in reminder (default label 'Evening')
      const _SpecRowSent(
        description: '§2.14b checkin_reminder — default label Evening',
        event: DecryptedEvent(
          id: 'e14b',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'checkin_reminder',
          payload: {},
        ),
        expectedTitle: 'Evening',
        expectedBody: 'A quiet moment, together.',
        expectedBatchKey: null,
        expectedGroupKey: NotificationModule.activity,
        expectedBatchLine: null,
      ),

      // §3/§5: list_item_deleted — ride-along line, canStartCard: false
      const _SpecRowSent(
        description: '§3/§5 list_item_deleted — ride-along line (− item), canStartCard: false',
        event: DecryptedEvent(
          id: 'e15',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'list_item_deleted',
          payload: {
            'list_id': 'list_groceries',
            'list_name': 'Groceries',
            'title': 'Dishwasher tablets',
          },
        ),
        expectedTitle: 'Groceries',
        expectedBody: '',
        expectedBatchKey: 'list_groceries',
        expectedGroupKey: NotificationModule.lists,
        expectedBatchLine: '− Dishwasher tablets',
        expectedCanStartCard: false,
      ),
    ];

    for (final row in rows) {
      test(row.description, () {
        final base = baseCtx();
        final ctx = row.customizeCtx != null ? row.customizeCtx!(base) : base;
        final result = composeNotification(row.event, ctx);

        expect(result, isNotNull, reason: 'Expected copy for ${row.description}');
        expect(result!.title, row.expectedTitle);
        expect(result.body, row.expectedBody);
        expect(result.batchKey, row.expectedBatchKey);
        expect(result.groupKey, row.expectedGroupKey);
        expect(result.batchLine, row.expectedBatchLine);
        expect(result.canStartCard, row.expectedCanStartCard);
      });
    }
  });

  group('15-notifications.md §3 — What is never sent (table-driven)', () {
    final silentRows = <_SpecRowSilent>[
      // Bullet 1: An item put back on a list (toggled to not done) · an item edited ·
      // a list renamed, archived, deleted or reordered · completed items cleared
      const _SpecRowSilent(
        description: '§3.1a list_item_toggled to not done (put back on a list)',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'list_item_toggled',
          payload: {
            'list_id': 'list_1',
            'list_name': 'Groceries',
            'title': 'Milk',
            'is_completed': false,
          },
        ),
      ),
      const _SpecRowSilent(
        description: '§3.1b list_item_updated (item edited)',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'list_item_updated',
          payload: {'list_id': 'list_1', 'title': 'Whole milk'},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.1c list_renamed',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'list_renamed',
          payload: {'id': 'list_1', 'name': 'Weekly groceries'},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.1d list_archived',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'list_archived',
          payload: {'id': 'list_1'},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.1e list_deleted',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'list_deleted',
          payload: {'id': 'list_1'},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.1f list_reordered',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'list_reordered',
          payload: {'id': 'list_1'},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.1g list_completed_cleared',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'list_completed_cleared',
          payload: {'list_id': 'list_1'},
        ),
      ),

      // Bullet 2: An expense changed or removed
      const _SpecRowSilent(
        description: '§3.2a expense_updated (expense changed)',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'expense_updated',
          payload: {'id': 'exp_1', 'title': 'Coffee', 'amount': 300},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.2b expense_deleted (expense removed)',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'expense_deleted',
          payload: {'id': 'exp_1', 'title': 'Coffee'},
        ),
      ),

      // Bullet 3: A habit unchecked · a habit cheered ("saw that you kept it") ·
      // a habit edited or removed
      const _SpecRowSilent(
        description: '§3.3a habit_checkin_toggled unchecked',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'habit_checkin_toggled',
          payload: {
            'habit_name': 'Read before bed',
            'checked': false,
          },
        ),
      ),
      const _SpecRowSilent(
        description: '§3.3b habit_checkin_acknowledged (habit cheered)',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'habit_checkin_acknowledged',
          payload: {'habit_name': 'Read before bed'},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.3c habit_updated (habit edited)',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'habit_updated',
          payload: {'id': 'hab_1', 'name': 'Read 20 pages'},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.3d habit_deleted (habit removed)',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'habit_deleted',
          payload: {'id': 'hab_1', 'name': 'Read before bed'},
        ),
      ),

      // Bullet 4: A commitment changed, restarted or deleted
      const _SpecRowSilent(
        description: '§3.4a subscription_updated (commitment changed)',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'subscription_updated',
          payload: {'id': 'sub_1', 'name': 'Netflix', 'amount': 799},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.4b subscription_restarted (commitment restarted)',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'subscription_restarted',
          payload: {'id': 'sub_1', 'name': 'Netflix', 'amount': 649},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.4c subscription_deleted (commitment deleted)',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'subscription_deleted',
          payload: {'id': 'sub_1', 'name': 'Netflix'},
        ),
      ),

      // Bullet 5: A profile, name, avatar, currency, budget, anniversary or home setting changed
      const _SpecRowSilent(
        description: '§3.5a member_profile_updated',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'member_profile_updated',
          payload: {'display_name': 'Ancy'},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.5b home_updated (currency / budget / anniversary / home setting)',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'home_updated',
          payload: {'currency': 'INR', 'monthly_budget': 50000},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.5c home_settings_updated',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'home_settings_updated',
          payload: {'anniversary': '2021-02-14'},
        ),
      ),

      // Bullet 6: Routines, roadmap items and check-in reminder edits, in any form
      const _SpecRowSilent(
        description: '§3.6a routine_created',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'routine_created',
          payload: {'name': 'Weekdays'},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.6b routine_block_added',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'routine_block_added',
          payload: {'title': 'Morning coffee'},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.6c roadmap_item_added',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'roadmap_item_added',
          payload: {'title': 'Buy a sofa'},
        ),
      ),
      const _SpecRowSilent(
        description: '§3.6d checkin_reminder_updated',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'checkin_reminder_updated',
          payload: {'label': 'Night'},
        ),
      ),

      // Bullet 7: Anything about a private record
      const _SpecRowSilent(
        description: '§3.7a private record via payload is_private: true',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'expense_logged',
          payload: {
            'title': 'Surprise gift',
            'amount': 1500,
            'is_private': true,
          },
        ),
      ),
      _SpecRowSilent(
        description: '§3.7b private record via NotificationContext.isPrivate: true',
        event: const DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'habit_checkin_toggled',
          payload: {
            'habit_name': 'Journal',
            'checked': true,
          },
        ),
        customizeCtx: (b) => baseCtx(isPrivate: true),
      ),

      // Bullet 8: Anything the user did themselves on another device
      _SpecRowSilent(
        description: '§3.8a event created by viewer (createdByViewer: true)',
        event: const DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'expense_logged',
          payload: {'title': 'Coffee', 'amount': 250},
        ),
        customizeCtx: (b) => baseCtx(createdByViewer: true),
      ),
      const _SpecRowSilent(
        description: '§3.8b event actorId matches viewerUserId',
        event: DecryptedEvent(
          actorId: 'viewer_saba',
          eventType: 'expense_logged',
          payload: {'title': 'Coffee', 'amount': 250},
        ),
      ),

      // Calendar update where neither date nor time changed
      const _SpecRowSilent(
        description: '§2/§3 calendar_event_updated where date and time did not change',
        event: DecryptedEvent(
          actorId: 'partner_ancy',
          eventType: 'calendar_event_updated',
          payload: {
            'title': 'Dinner with Amma',
            'start_time': '2025-11-08T19:30:00',
            'previous_start_time': '2025-11-08T19:30:00',
            'is_all_day': false,
            'previous_is_all_day': false,
          },
        ),
      ),
    ];

    for (final row in silentRows) {
      test(row.description, () {
        final base = baseCtx();
        final ctx = row.customizeCtx != null ? row.customizeCtx!(base) : base;
        final result = composeNotification(row.event, ctx);
        expect(result, isNull, reason: 'Expected null for ${row.description}');
      });
    }

    test('§3 removal (list_item_deleted) returns ride-along line (− item) but canStartCard is false', () {
      const event = DecryptedEvent(
        id: 'e_del_1',
        homeId: 'h1',
        actorId: 'partner_ancy',
        eventType: 'list_item_deleted',
        payload: {
          'list_id': 'list_groceries',
          'list_name': 'Groceries',
          'title': 'Dishwasher tablets',
        },
      );

      final result = composeNotification(event, baseCtx());
      expect(result, isNotNull);
      expect(result!.title, 'Groceries');
      expect(result.batchKey, 'list_groceries');
      expect(result.groupKey, NotificationModule.lists);
      expect(result.batchLine, '− Dishwasher tablets');
      expect(result.canStartCard, isFalse);
    });
  });

  group('15-notifications.md §4 — Fallback & number formatting helpers', () {
    test('composeFallbackNotification uses home name and partner name', () {
      final fallback = composeFallbackNotification(
        homeName: 'Indiranagar',
        partnerName: 'Ancy',
      );
      expect(fallback.title, 'Indiranagar');
      expect(fallback.body, 'Ancy made a change. Open to see it.');
      expect(fallback.groupKey, NotificationModule.activity);
      expect(fallback.batchKey, isNull);
    });

    test('formatStreakCount uses words up to 99 and digits from 100', () {
      expect(formatStreakCount(2), 'Two');
      expect(formatStreakCount(12), 'Twelve');
      expect(formatStreakCount(20), 'Twenty');
      expect(formatStreakCount(23), 'Twenty-three');
      expect(formatStreakCount(99), 'Ninety-nine');
      expect(formatStreakCount(100), '100');
      expect(formatStreakCount(145), '145');
    });
  });
}
