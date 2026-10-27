import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../../sync/db/app_database.dart';
import '../expenses/expense_controller.dart';
import '../habits/habit_controller.dart';
import '../habits/habit_schedule.dart';
import '../routines/routine_models.dart';
import '../subscriptions/commitment_models.dart';

/// The six item kinds created through the unified Add flow (`design/specs/14-add-flow.md` §1).
enum AddKind {
  event,
  expense,
  task,
  habit,
  commitment,
  routine,
}

/// Ordered steps across all six Add flows (`design/specs/14-add-flow.md` §5).
enum AddStep {
  // Expense (7 steps)
  expenseAmount,
  expenseTitle,
  expenseWhen,
  expenseCategory,
  expenseWhoPaid,
  expensePaymentMethod,

  // Event (5 steps)
  eventTitle,
  eventDay,
  eventTime,
  eventLocation,

  // Task (3 or 4 steps)
  taskTitle,
  taskWhichList,
  taskNameTheList,
  taskByWhen,

  // Habit (4 steps)
  habitName,
  habitHowOften,
  habitVisibility,

  // Commitment (7 steps for monthly/quarterly/yearly, 9 steps for EMI)
  commitmentName,
  commitmentAmount,
  commitmentHowOften,
  commitmentEmiTotal,
  commitmentEmiPaid,
  commitmentWhenDue,
  commitmentPaidFrom,
  commitmentWhose,

  // Routine (5 steps)
  routineTitle,
  routineWhen,
  routineDuration,
  routineDays,

  // Shared final confirmation step
  review,
}

///Ambient context needed to compute dynamic step sequences and person options.
@immutable
class AddFlowContext {
  final DateTime anchor;
  final DateTime today;
  final bool hasPartner;
  final int listCount;
  final bool openedFromList;
  final String viewerUserId;
  final String partnerUserId;
  final String? activeListId;
  final String? routineId;
  final int? startMinutes;
  final bool presetEmi;
  final bool presetMonthly;
  final List<Routine> existingRoutines;
  final List<LocalRoutine> existingLocalRoutines;

  AddFlowContext({
    required DateTime anchor,
    required DateTime today,
    this.hasPartner = true,
    this.listCount = 0,
    this.openedFromList = false,
    this.viewerUserId = 'user_alex',
    this.partnerUserId = 'partner_user',
    this.activeListId,
    this.routineId,
    this.startMinutes,
    this.presetEmi = false,
    this.presetMonthly = false,
    this.existingRoutines = const [],
    this.existingLocalRoutines = const [],
  })  : anchor = _dateOnly(anchor),
        today = _dateOnly(today);

  AddFlowContext copyWith({
    DateTime? anchor,
    DateTime? today,
    bool? hasPartner,
    int? listCount,
    bool? openedFromList,
    String? viewerUserId,
    String? partnerUserId,
    String? activeListId,
    String? routineId,
    int? startMinutes,
    bool? presetEmi,
    bool? presetMonthly,
    List<Routine>? existingRoutines,
    List<LocalRoutine>? existingLocalRoutines,
  }) {
    return AddFlowContext(
      anchor: anchor ?? this.anchor,
      today: today ?? this.today,
      hasPartner: hasPartner ?? this.hasPartner,
      listCount: listCount ?? this.listCount,
      openedFromList: openedFromList ?? this.openedFromList,
      viewerUserId: viewerUserId ?? this.viewerUserId,
      partnerUserId: partnerUserId ?? this.partnerUserId,
      activeListId: activeListId ?? this.activeListId,
      routineId: routineId ?? this.routineId,
      startMinutes: startMinutes ?? this.startMinutes,
      presetEmi: presetEmi ?? this.presetEmi,
      presetMonthly: presetMonthly ?? this.presetMonthly,
      existingRoutines: existingRoutines ?? this.existingRoutines,
      existingLocalRoutines:
          existingLocalRoutines ?? this.existingLocalRoutines,
    );
  }
}

DateTime _dateOnly(DateTime d) {
  final l = d.toLocal();
  return DateTime(l.year, l.month, l.day);
}

const List<String> _weekdaysFull = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _weekdaysShort = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _monthsShort = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Returns the seven anchored dates for [kind] relative to [anchor] (`design/specs/14-add-flow.md` §4).
///
/// - [AddKind.expense]: 7 days ending at [anchor] (`anchor - 6` .. `anchor`).
/// - [AddKind.task] and [AddKind.event]: 7 days starting at [anchor] (`anchor` .. `anchor + 6`).
/// - [AddKind.habit], [AddKind.commitment], [AddKind.routine]: empty list (their frequency defines them).
List<DateTime> anchoredDays(AddKind kind, DateTime anchor) {
  final a = _dateOnly(anchor);
  switch (kind) {
    case AddKind.expense:
      return List<DateTime>.generate(
        7,
        (i) => DateTime(a.year, a.month, a.day - (6 - i)),
        growable: false,
      );
    case AddKind.event:
    case AddKind.task:
      return List<DateTime>.generate(
        7,
        (i) => DateTime(a.year, a.month, a.day + i),
        growable: false,
      );
    case AddKind.habit:
    case AddKind.commitment:
    case AddKind.routine:
      return const <DateTime>[];
  }
}

/// Formats [date] relative to [today] as `{Today | Yesterday | Tomorrow | EEEE}, d MMM`
/// — e.g. `'Today, 5 Oct'`, `'Yesterday, 4 Oct'`, `'Tomorrow, 6 Oct'`, `'Wednesday, 7 Oct'`.
String dayLabel(DateTime date, DateTime today) {
  final d = _dateOnly(date);
  final t = _dateOnly(today);
  final yesterday = DateTime(t.year, t.month, t.day - 1);
  final tomorrow = DateTime(t.year, t.month, t.day + 1);

  final String prefix;
  if (d == t) {
    prefix = 'Today';
  } else if (d == yesterday) {
    prefix = 'Yesterday';
  } else if (d == tomorrow) {
    prefix = 'Tomorrow';
  } else {
    prefix = _weekdaysFull[d.weekday - 1];
  }

  final monthName = _monthsShort[d.month - 1];
  return '$prefix, ${d.day} $monthName';
}

/// Computes the next billing date on or after [today] (`design/specs/14-add-flow.md` §3).
///
/// - **Month-day mode** ([dayOfMonth] `1..28`, [month] omitted and [nextDate] omitted):
///   returns the `[dayOfMonth]` of [today]'s month if `dayOfMonth >= today.day`,
///   otherwise the `[dayOfMonth]` of `today.month + 1`.
/// - **Next-date mode** ([month] `1..12` and [dayOfMonth] `1..28`, or [nextDate]):
///   returns the next occurrence of `(month, day)` on or after [today] (never before [today]).
DateTime nextBillingDate({
  required DateTime today,
  int? dayOfMonth,
  int? month,
  DateTime? nextDate,
}) {
  final t = _dateOnly(today);

  if (nextDate != null) {
    final candidate = _dateOnly(nextDate);
    if (!candidate.isBefore(t)) {
      return candidate;
    }
    final clampedDay = candidate.day.clamp(1, 28);
    final thisYear = DateTime(t.year, candidate.month, clampedDay);
    if (!thisYear.isBefore(t)) {
      return thisYear;
    }
    return DateTime(t.year + 1, candidate.month, clampedDay);
  }

  final clampedDay = (dayOfMonth ?? t.day).clamp(1, 28);

  if (month != null) {
    final clampedMonth = month.clamp(1, 12);
    final thisYear = DateTime(t.year, clampedMonth, clampedDay);
    if (!thisYear.isBefore(t)) {
      return thisYear;
    }
    return DateTime(t.year + 1, clampedMonth, clampedDay);
  }

  final thisMonth = DateTime(t.year, t.month, clampedDay);
  if (!thisMonth.isBefore(t)) {
    return thisMonth;
  }
  return DateTime(t.year, t.month + 1, clampedDay);
}

/// Returns the ordered steps for [draft] in [context] right now (`design/specs/14-add-flow.md` §5).
List<AddStep> stepsFor(AddDraft draft, AddFlowContext context) {
  return draft.stepsFor(context);
}

/// Shared interface implemented by all six immutable Add flow drafts.
abstract class AddDraft {
  const AddDraft();

  AddKind get kind;

  /// Ordered steps for this draft given [context].
  List<AddStep> stepsFor(AddFlowContext context);

  /// Whether [step] currently has a valid answer (or was explicitly skipped).
  bool isAnswered(AddStep step);

  /// Whether all required answers for this draft are present and valid.
  bool get isComplete;
}

// ============================================================================
// 1. EXPENSE DRAFT
// ============================================================================

/// Who paid for an expense (`you` or `partner`).
enum ExpensePayer {
  you,
  partner,
}

/// Plain value object holding the exact named arguments for `ExpenseController.logExpense`.
@immutable
class ExpenseCreateArgs {
  final String title;
  final double amount;
  final String? currency;
  final DateTime expenseDate;
  final String paidBy;
  final String category;
  final String? notes;
  final String? paymentMethod;
  final bool isTransfer;
  final ExpenseVisibility visibility;

  const ExpenseCreateArgs({
    required this.title,
    required this.amount,
    this.currency,
    required this.expenseDate,
    required this.paidBy,
    required this.category,
    this.notes,
    required this.paymentMethod,
    this.isTransfer = false,
    required this.visibility,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCreateArgs &&
          title == other.title &&
          amount == other.amount &&
          currency == other.currency &&
          expenseDate == other.expenseDate &&
          paidBy == other.paidBy &&
          category == other.category &&
          notes == other.notes &&
          paymentMethod == other.paymentMethod &&
          isTransfer == other.isTransfer &&
          visibility == other.visibility;

  @override
  int get hashCode => Object.hash(
        title,
        amount,
        currency,
        expenseDate,
        paidBy,
        category,
        notes,
        paymentMethod,
        isTransfer,
        visibility,
      );
}

const Object _sentinel = Object();

/// Immutable draft for `AddKind.expense` (`design/specs/14-add-flow.md` §5).
@immutable
class ExpenseDraft extends AddDraft {
  final int? amount;
  final String title;
  final DateTime? expenseDate;
  final String? category;
  final ExpensePayer payer;
  final bool splitHalfAndHalf;
  final bool isPrivate;
  final String? paymentMethod; // 'card' | 'upi' | 'cash' | null
  final bool paymentMethodSkipped;
  final String viewerUserId;
  final String partnerUserId;
  final bool hasPartner;

  const ExpenseDraft({
    this.amount,
    this.title = '',
    this.expenseDate,
    this.category,
    ExpensePayer payer = ExpensePayer.you,
    bool splitHalfAndHalf = true,
    this.isPrivate = false,
    this.paymentMethod,
    this.paymentMethodSkipped = false,
    this.viewerUserId = 'user_alex',
    this.partnerUserId = 'partner_user',
    this.hasPartner = true,
  })  : payer = (isPrivate || !hasPartner) ? ExpensePayer.you : payer,
        splitHalfAndHalf =
            (isPrivate || !hasPartner) ? false : splitHalfAndHalf;

  factory ExpenseDraft.initial(AddFlowContext context) {
    final now = clock.now().toLocal();
    final anchorLocal = context.anchor.toLocal();
    final todayLocal = context.today.toLocal();
    final isAnchorToday = anchorLocal.year == todayLocal.year &&
        anchorLocal.month == todayLocal.month &&
        anchorLocal.day == todayLocal.day;
    return ExpenseDraft(
      expenseDate: isAnchorToday ? now : anchorLocal,
      viewerUserId: context.viewerUserId,
      partnerUserId: context.partnerUserId,
      hasPartner: context.hasPartner,
    );
  }

  @override
  AddKind get kind => AddKind.expense;

  /// Available payer choices in [context].
  /// In a home with no partner, or when [isPrivate] is on, only [ExpensePayer.you] is available.
  List<ExpensePayer> availablePayers([AddFlowContext? context]) {
    final partnerExists = context?.hasPartner ?? hasPartner;
    if (!partnerExists || isPrivate) {
      return const <ExpensePayer>[ExpensePayer.you];
    }
    return const <ExpensePayer>[ExpensePayer.you, ExpensePayer.partner];
  }

  /// Whether the "Split it half and half" toggle is available.
  bool canToggleSplit([AddFlowContext? context]) {
    final partnerExists = context?.hasPartner ?? hasPartner;
    return partnerExists && !isPrivate;
  }

  /// Whether the "Keep it private" toggle is available (remains available even with no partner).
  bool canTogglePrivate([AddFlowContext? context]) => true;

  ExpenseVisibility get resolvedVisibility {
    if (isPrivate) return ExpenseVisibility.privateToMe;
    if (!hasPartner) return ExpenseVisibility.partnerCanSee;
    return splitHalfAndHalf
        ? ExpenseVisibility.shared
        : ExpenseVisibility.partnerCanSee;
  }

  String resolvedPaidBy({
    String? viewerUserId,
    String? partnerUserId,
    bool? hasPartner,
  }) {
    final vId = viewerUserId ?? this.viewerUserId;
    final pId = partnerUserId ?? this.partnerUserId;
    final partnerExists = hasPartner ?? this.hasPartner;
    if (isPrivate || !partnerExists) return vId;
    return payer == ExpensePayer.partner ? pId : vId;
  }

  ExpenseDraft copyWith({
    Object? amount = _sentinel,
    String? title,
    Object? expenseDate = _sentinel,
    Object? category = _sentinel,
    ExpensePayer? payer,
    bool? splitHalfAndHalf,
    bool? isPrivate,
    Object? paymentMethod = _sentinel,
    bool? paymentMethodSkipped,
    String? viewerUserId,
    String? partnerUserId,
    bool? hasPartner,
  }) {
    final nextHasPartner = hasPartner ?? this.hasPartner;
    final nextIsPrivate = isPrivate ?? this.isPrivate;

    final ExpensePayer nextPayer;
    final bool nextSplit;
    if (nextIsPrivate || !nextHasPartner) {
      // Turning private on (or having no partner) selects you and turns Split off.
      nextPayer = ExpensePayer.you;
      nextSplit = false;
    } else {
      nextPayer = payer ?? this.payer;
      nextSplit = splitHalfAndHalf ?? this.splitHalfAndHalf;
    }

    final String? nextPaymentMethod = identical(paymentMethod, _sentinel)
        ? this.paymentMethod
        : paymentMethod as String?;

    return ExpenseDraft(
      amount: identical(amount, _sentinel) ? this.amount : amount as int?,
      title: title ?? this.title,
      expenseDate: identical(expenseDate, _sentinel)
          ? this.expenseDate
          : expenseDate as DateTime?,
      category:
          identical(category, _sentinel) ? this.category : category as String?,
      payer: nextPayer,
      splitHalfAndHalf: nextSplit,
      isPrivate: nextIsPrivate,
      paymentMethod: nextPaymentMethod,
      paymentMethodSkipped: paymentMethodSkipped ??
          ( !identical(paymentMethod, _sentinel) && nextPaymentMethod == null
              ? true
              : this.paymentMethodSkipped),
      viewerUserId: viewerUserId ?? this.viewerUserId,
      partnerUserId: partnerUserId ?? this.partnerUserId,
      hasPartner: nextHasPartner,
    );
  }

  static const List<AddStep> _steps = <AddStep>[
    AddStep.expenseAmount,
    AddStep.expenseTitle,
    AddStep.expenseWhen,
    AddStep.expenseCategory,
    AddStep.expenseWhoPaid,
    AddStep.expensePaymentMethod,
    AddStep.review,
  ];

  @override
  List<AddStep> stepsFor(AddFlowContext context) => _steps;

  @override
  bool isAnswered(AddStep step) {
    switch (step) {
      case AddStep.expenseAmount:
        return amount != null && amount! > 0;
      case AddStep.expenseTitle:
        return title.trim().isNotEmpty;
      case AddStep.expenseWhen:
        return expenseDate != null;
      case AddStep.expenseCategory:
        return category != null && category!.trim().isNotEmpty;
      case AddStep.expenseWhoPaid:
        return true;
      case AddStep.expensePaymentMethod:
        return paymentMethod != null || paymentMethodSkipped;
      case AddStep.review:
        return isComplete;
      default:
        return false;
    }
  }

  @override
  bool get isComplete =>
      isAnswered(AddStep.expenseAmount) &&
      isAnswered(AddStep.expenseTitle) &&
      isAnswered(AddStep.expenseWhen) &&
      isAnswered(AddStep.expenseCategory) &&
      isAnswered(AddStep.expenseWhoPaid);

  ExpenseCreateArgs toCreateArgs({
    String? viewerUserId,
    String? partnerUserId,
    String? currency,
  }) {
    if (!isComplete) {
      throw StateError('ExpenseDraft is incomplete and cannot build args.');
    }
    final rawDate = expenseDate!.toLocal();
    final now = clock.now().toLocal();
    final isChosenDayToday = rawDate.year == now.year &&
        rawDate.month == now.month &&
        rawDate.day == now.day;
    final resolvedExpenseDate = isChosenDayToday
        ? now
        : DateTime(rawDate.year, rawDate.month, rawDate.day);

    return ExpenseCreateArgs(
      title: title.trim(),
      amount: amount!.toDouble(),
      currency: currency,
      expenseDate: resolvedExpenseDate,
      paidBy: resolvedPaidBy(
        viewerUserId: viewerUserId,
        partnerUserId: partnerUserId,
      ),
      category: category!.trim(),
      notes: null,
      paymentMethod: paymentMethod,
      isTransfer: false,
      visibility: resolvedVisibility,
    );
  }
}

// ============================================================================
// 2. EVENT DRAFT
// ============================================================================

/// Plain value object holding the exact named arguments for `CalendarController.createEvent`.
@immutable
class EventCreateArgs {
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String? location;
  final String? recurrence;

  const EventCreateArgs({
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.location,
    this.recurrence,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventCreateArgs &&
          title == other.title &&
          description == other.description &&
          startTime == other.startTime &&
          endTime == other.endTime &&
          isAllDay == other.isAllDay &&
          location == other.location &&
          recurrence == other.recurrence;

  @override
  int get hashCode => Object.hash(
        title,
        description,
        startTime,
        endTime,
        isAllDay,
        location,
        recurrence,
      );
}

/// Immutable draft for `AddKind.event` (`design/specs/14-add-flow.md` §5).
@immutable
class EventDraft extends AddDraft {
  final String title;
  final DateTime? day;
  final int hour;
  final int minute;
  final bool isAllDay;
  final String? location;
  final bool locationSkipped;

  const EventDraft({
    this.title = '',
    this.day,
    this.hour = 9,
    this.minute = 0,
    this.isAllDay = false,
    this.location,
    this.locationSkipped = false,
  });

  factory EventDraft.initial(AddFlowContext context) {
    return EventDraft(day: context.anchor);
  }

  @override
  AddKind get kind => AddKind.event;

  EventDraft copyWith({
    String? title,
    Object? day = _sentinel,
    int? hour,
    int? minute,
    bool? isAllDay,
    Object? location = _sentinel,
    bool? locationSkipped,
  }) {
    final String? nextLocation = identical(location, _sentinel)
        ? this.location
        : location as String?;
    return EventDraft(
      title: title ?? this.title,
      day: identical(day, _sentinel) ? this.day : day as DateTime?,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isAllDay: isAllDay ?? this.isAllDay,
      location: nextLocation,
      locationSkipped: locationSkipped ??
          (!identical(location, _sentinel) &&
                  (nextLocation == null || nextLocation.trim().isEmpty)
              ? true
              : this.locationSkipped),
    );
  }

  static const List<AddStep> _steps = <AddStep>[
    AddStep.eventTitle,
    AddStep.eventDay,
    AddStep.eventTime,
    AddStep.eventLocation,
    AddStep.review,
  ];

  @override
  List<AddStep> stepsFor(AddFlowContext context) => _steps;

  @override
  bool isAnswered(AddStep step) {
    switch (step) {
      case AddStep.eventTitle:
        return title.trim().isNotEmpty;
      case AddStep.eventDay:
        return day != null;
      case AddStep.eventTime:
        return isAllDay ||
            (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59);
      case AddStep.eventLocation:
        return (location != null && location!.trim().isNotEmpty) ||
            locationSkipped;
      case AddStep.review:
        return isComplete;
      default:
        return false;
    }
  }

  @override
  bool get isComplete =>
      isAnswered(AddStep.eventTitle) &&
      isAnswered(AddStep.eventDay) &&
      isAnswered(AddStep.eventTime);

  EventCreateArgs toCreateArgs() {
    if (!isComplete) {
      throw StateError('EventDraft is incomplete and cannot build args.');
    }
    final d = day!;
    final startDateTime = DateTime(
      d.year,
      d.month,
      d.day,
      isAllDay ? 0 : hour,
      isAllDay ? 0 : minute,
    );
    final endDateTime = isAllDay
        ? DateTime(d.year, d.month, d.day, 23, 59)
        : startDateTime.add(const Duration(hours: 1));
    final cleanLocation =
        (location == null || location!.trim().isEmpty) ? null : location!.trim();

    return EventCreateArgs(
      title: title.trim(),
      description: null,
      startTime: startDateTime,
      endTime: endDateTime,
      isAllDay: isAllDay,
      location: cleanLocation,
      recurrence: null,
    );
  }
}

// ============================================================================
// 3. TASK DRAFT
// ============================================================================

/// Plain value object holding the exact named arguments for `ListController.addItem`
/// (and optional `ListController.createList` when `newListName != null`).
@immutable
class TaskCreateArgs {
  final String? listId;
  final String? newListName;
  final String title;
  final String? notes;
  final DateTime? dueDate;

  const TaskCreateArgs({
    required this.listId,
    this.newListName,
    required this.title,
    this.notes,
    required this.dueDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskCreateArgs &&
          listId == other.listId &&
          newListName == other.newListName &&
          title == other.title &&
          notes == other.notes &&
          dueDate == other.dueDate;

  @override
  int get hashCode =>
      Object.hash(listId, newListName, title, notes, dueDate);
}

/// Immutable draft for `AddKind.task` (`design/specs/14-add-flow.md` §5).
@immutable
class TaskDraft extends AddDraft {
  final String title;
  final String? listId;
  final String? newListName;
  final DateTime? dueDate;
  final bool noParticularDay;
  final int listCount;
  final bool openedFromList;

  const TaskDraft({
    this.title = '',
    this.listId,
    this.newListName,
    this.dueDate,
    this.noParticularDay = false,
    this.listCount = 1,
    this.openedFromList = false,
  });

  factory TaskDraft.initial(AddFlowContext context) {
    return TaskDraft(
      dueDate: context.anchor,
      listId: context.activeListId,
      listCount: context.listCount,
      openedFromList: context.openedFromList,
    );
  }

  @override
  AddKind get kind => AddKind.task;

  TaskDraft copyWith({
    String? title,
    Object? listId = _sentinel,
    Object? newListName = _sentinel,
    Object? dueDate = _sentinel,
    bool? noParticularDay,
    int? listCount,
    bool? openedFromList,
  }) {
    final nextNoParticularDay = noParticularDay ?? this.noParticularDay;
    final DateTime? nextDueDate;
    if (nextNoParticularDay && identical(dueDate, _sentinel)) {
      nextDueDate = null;
    } else {
      nextDueDate = identical(dueDate, _sentinel)
          ? this.dueDate
          : dueDate as DateTime?;
    }

    return TaskDraft(
      title: title ?? this.title,
      listId: identical(listId, _sentinel) ? this.listId : listId as String?,
      newListName: identical(newListName, _sentinel)
          ? this.newListName
          : newListName as String?,
      dueDate: nextDueDate,
      noParticularDay:
          (!identical(dueDate, _sentinel) && nextDueDate != null)
              ? false
              : nextNoParticularDay,
      listCount: listCount ?? this.listCount,
      openedFromList: openedFromList ?? this.openedFromList,
    );
  }

  @override
  List<AddStep> stepsFor(AddFlowContext context) {
    if (context.openedFromList || context.listCount == 1) {
      return const <AddStep>[
        AddStep.taskTitle,
        AddStep.taskByWhen,
        AddStep.review,
      ];
    }
    if (context.listCount == 0) {
      return const <AddStep>[
        AddStep.taskTitle,
        AddStep.taskNameTheList,
        AddStep.taskByWhen,
        AddStep.review,
      ];
    }
    return const <AddStep>[
      AddStep.taskTitle,
      AddStep.taskWhichList,
      AddStep.taskByWhen,
      AddStep.review,
    ];
  }

  @override
  bool isAnswered(AddStep step) {
    switch (step) {
      case AddStep.taskTitle:
        return title.trim().isNotEmpty;
      case AddStep.taskWhichList:
        return listId != null && listId!.trim().isNotEmpty;
      case AddStep.taskNameTheList:
        return newListName != null && newListName!.trim().isNotEmpty;
      case AddStep.taskByWhen:
        return dueDate != null || noParticularDay;
      case AddStep.review:
        return isComplete;
      default:
        return false;
    }
  }

  @override
  bool get isComplete {
    if (!isAnswered(AddStep.taskTitle)) return false;
    if (!isAnswered(AddStep.taskByWhen)) return false;
    if (openedFromList || listCount == 1) {
      return true;
    }
    if (listCount == 0) {
      return isAnswered(AddStep.taskNameTheList);
    }
    return isAnswered(AddStep.taskWhichList);
  }

  TaskCreateArgs toCreateArgs({String? fallbackListId}) {
    if (!isComplete) {
      throw StateError('TaskDraft is incomplete and cannot build args.');
    }
    final cleanNewList =
        (newListName == null || newListName!.trim().isEmpty)
            ? null
            : newListName!.trim();
    return TaskCreateArgs(
      listId: listId ?? fallbackListId,
      newListName: cleanNewList,
      title: title.trim(),
      notes: null,
      dueDate: noParticularDay ? null : dueDate,
    );
  }
}

// ============================================================================
// 4. HABIT DRAFT
// ============================================================================

/// The four "How often?" options for a Habit (`design/specs/14-add-flow.md` §5).
enum HabitFrequencyOption {
  everyDay,
  weekdays,
  weekends,
  pickDays,
}

/// Plain value object holding the exact named arguments for `HabitController.createHabit`.
@immutable
class HabitCreateArgs {
  final String name;
  final String cadence;
  final int targetDaysPerWeek;
  final HabitVisibility visibility;

  const HabitCreateArgs({
    required this.name,
    required this.cadence,
    required this.targetDaysPerWeek,
    required this.visibility,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HabitCreateArgs &&
          name == other.name &&
          cadence == other.cadence &&
          targetDaysPerWeek == other.targetDaysPerWeek &&
          visibility == other.visibility;

  @override
  int get hashCode =>
      Object.hash(name, cadence, targetDaysPerWeek, visibility);
}

/// Immutable draft for `AddKind.habit` (`design/specs/14-add-flow.md` §5).
@immutable
class HabitDraft extends AddDraft {
  final String name;
  final HabitFrequencyOption? frequencyOption;
  final Set<int> customDays; // 1 = Mon .. 7 = Sun
  final HabitVisibility visibility;
  final bool hasPartner;

  HabitDraft({
    this.name = '',
    this.frequencyOption,
    Set<int> customDays = const <int>{1, 3, 5},
    this.visibility = HabitVisibility.shared,
    this.hasPartner = true,
  }) : customDays = Set<int>.unmodifiable(
          (customDays.where((d) => d >= 1 && d <= 7).toList()..sort()),
        );

  factory HabitDraft.initial(AddFlowContext context) {
    return HabitDraft(hasPartner: context.hasPartner);
  }

  @override
  AddKind get kind => AddKind.habit;

  /// Available visibility choices for [context].
  /// In a home with no partner, the partner-shared option is gone while private remains.
  List<HabitVisibility> availableVisibilities([AddFlowContext? context]) {
    final partnerExists = context?.hasPartner ?? hasPartner;
    if (!partnerExists) {
      return const <HabitVisibility>[HabitVisibility.privateToMe];
    }
    return const <HabitVisibility>[
      HabitVisibility.shared,
      HabitVisibility.privateToMe,
    ];
  }

  bool canTogglePrivate([AddFlowContext? context]) => true;

  /// Converts the selected [frequencyOption] and [customDays] into a [HabitSchedule]
  /// matching `HabitFormSheet`'s exact cadence and targetDaysPerWeek rules.
  HabitSchedule get schedule {
    final opt = frequencyOption ?? HabitFrequencyOption.everyDay;
    switch (opt) {
      case HabitFrequencyOption.everyDay:
        return const HabitSchedule(
          frequency: 'daily',
          daysOfWeek: <int>[1, 2, 3, 4, 5, 6, 7],
        );
      case HabitFrequencyOption.weekdays:
        return const HabitSchedule(
          frequency: 'custom',
          daysOfWeek: <int>[1, 2, 3, 4, 5],
        );
      case HabitFrequencyOption.weekends:
        return const HabitSchedule(
          frequency: 'custom',
          daysOfWeek: <int>[6, 7],
        );
      case HabitFrequencyOption.pickDays:
        return HabitSchedule(
          frequency: 'custom',
          daysOfWeek: customDays.toList(growable: false),
        );
    }
  }

  int get targetDaysPerWeek {
    final s = schedule;
    return s.frequency == 'daily' ? 7 : s.daysOfWeek.length;
  }

  HabitDraft copyWith({
    String? name,
    Object? frequencyOption = _sentinel,
    Set<int>? customDays,
    HabitVisibility? visibility,
    bool? hasPartner,
  }) {
    return HabitDraft(
      name: name ?? this.name,
      frequencyOption: identical(frequencyOption, _sentinel)
          ? this.frequencyOption
          : frequencyOption as HabitFrequencyOption?,
      customDays: customDays ?? this.customDays,
      visibility: visibility ?? this.visibility,
      hasPartner: hasPartner ?? this.hasPartner,
    );
  }

  static const List<AddStep> _steps = <AddStep>[
    AddStep.habitName,
    AddStep.habitHowOften,
    AddStep.habitVisibility,
    AddStep.review,
  ];

  @override
  List<AddStep> stepsFor(AddFlowContext context) => _steps;

  @override
  bool isAnswered(AddStep step) {
    switch (step) {
      case AddStep.habitName:
        return name.trim().isNotEmpty;
      case AddStep.habitHowOften:
        if (frequencyOption == null) return false;
        if (frequencyOption == HabitFrequencyOption.pickDays) {
          return customDays.isNotEmpty;
        }
        return true;
      case AddStep.habitVisibility:
        return true;
      case AddStep.review:
        return isComplete;
      default:
        return false;
    }
  }

  @override
  bool get isComplete =>
      isAnswered(AddStep.habitName) &&
      isAnswered(AddStep.habitHowOften) &&
      isAnswered(AddStep.habitVisibility);

  HabitCreateArgs toCreateArgs() {
    if (!isComplete) {
      throw StateError('HabitDraft is incomplete and cannot build args.');
    }
    final s = schedule;
    return HabitCreateArgs(
      name: name.trim(),
      cadence: s.toCadenceString(),
      targetDaysPerWeek: targetDaysPerWeek,
      visibility: visibility,
    );
  }
}

// ============================================================================
// 5. COMMITMENT DRAFT
// ============================================================================

/// The four "How often does it come?" choices for a Commitment (`design/specs/14-add-flow.md` §5).
enum CommitmentCycleOption {
  everyMonth,
  everyQuarter,
  everyYear,
  emi,
}

/// Whose a commitment is (`you`, `partner`, or `both` -> `'split'`).
enum CommitmentOwner {
  you,
  partner,
  both,
}

/// Plain value object holding the exact named arguments for `SubscriptionController.createSubscription`.
@immutable
class CommitmentCreateArgs {
  final String name;
  final double amount;
  final String? currency;
  final String billingCycle;
  final DateTime nextBillingDate;
  final String category;
  final bool isPrivate;
  final DateTime? endDate;
  final String paidBy;
  final String? financedThrough;
  final int? totalInstallments;
  final int? paidInstallments;

  const CommitmentCreateArgs({
    required this.name,
    required this.amount,
    this.currency,
    required this.billingCycle,
    required this.nextBillingDate,
    this.category = 'Other',
    required this.isPrivate,
    required this.endDate,
    required this.paidBy,
    required this.financedThrough,
    required this.totalInstallments,
    required this.paidInstallments,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommitmentCreateArgs &&
          name == other.name &&
          amount == other.amount &&
          currency == other.currency &&
          billingCycle == other.billingCycle &&
          nextBillingDate == other.nextBillingDate &&
          category == other.category &&
          isPrivate == other.isPrivate &&
          endDate == other.endDate &&
          paidBy == other.paidBy &&
          financedThrough == other.financedThrough &&
          totalInstallments == other.totalInstallments &&
          paidInstallments == other.paidInstallments;

  @override
  int get hashCode => Object.hash(
        name,
        amount,
        currency,
        billingCycle,
        nextBillingDate,
        category,
        isPrivate,
        endDate,
        paidBy,
        financedThrough,
        totalInstallments,
        paidInstallments,
      );
}

/// Immutable draft for `AddKind.commitment` (`design/specs/14-add-flow.md` §5).
@immutable
class CommitmentDraft extends AddDraft {
  final String name;
  final int? amount;
  final CommitmentCycleOption cycle;
  final int? totalInstallments;
  final int? paidInstallments;
  final int? dayOfMonth; // 1..28 (used for monthly/EMI and next-date day)
  final int? dueMonth; // 1..12 (used for quarterly/yearly next-date)
  final DateTime? nextDueDate; // optional explicit date for quarterly/yearly
  final String? paidFrom;
  final bool paidFromSkipped;
  final CommitmentOwner owner;
  final bool isPrivate;
  final DateTime? today;
  final String viewerUserId;
  final String partnerUserId;
  final bool hasPartner;

  const CommitmentDraft({
    this.name = '',
    this.amount,
    this.cycle = CommitmentCycleOption.everyMonth,
    this.totalInstallments,
    this.paidInstallments,
    this.dayOfMonth,
    this.dueMonth,
    this.nextDueDate,
    this.paidFrom,
    this.paidFromSkipped = false,
    CommitmentOwner owner = CommitmentOwner.you,
    this.isPrivate = false,
    this.today,
    this.viewerUserId = 'user_alex',
    this.partnerUserId = 'partner_user',
    this.hasPartner = true,
  }) : owner = (isPrivate || !hasPartner) ? CommitmentOwner.you : owner;

  factory CommitmentDraft.initial(AddFlowContext context) {
    return CommitmentDraft(
      cycle: context.presetEmi
          ? CommitmentCycleOption.emi
          : CommitmentCycleOption.everyMonth,
      paidInstallments: context.presetEmi ? 0 : null,
      dayOfMonth: context.anchor.day.clamp(1, 28),
      dueMonth: context.anchor.month,
      today: context.today,
      viewerUserId: context.viewerUserId,
      partnerUserId: context.partnerUserId,
      hasPartner: context.hasPartner,
    );
  }

  @override
  AddKind get kind => AddKind.commitment;

  bool get isEmi => cycle == CommitmentCycleOption.emi;

  String get billingCycle {
    switch (cycle) {
      case CommitmentCycleOption.everyMonth:
      case CommitmentCycleOption.emi:
        return 'monthly';
      case CommitmentCycleOption.everyQuarter:
        return 'every_3_months';
      case CommitmentCycleOption.everyYear:
        return 'annual';
    }
  }

  /// Available owner choices in [context].
  /// In a home with no partner, or when [isPrivate] is on, only [CommitmentOwner.you] is available.
  List<CommitmentOwner> availableOwners([AddFlowContext? context]) {
    final partnerExists = context?.hasPartner ?? hasPartner;
    if (!partnerExists || isPrivate) {
      return const <CommitmentOwner>[CommitmentOwner.you];
    }
    return const <CommitmentOwner>[
      CommitmentOwner.you,
      CommitmentOwner.partner,
      CommitmentOwner.both,
    ];
  }

  /// Whether the "Keep it private" toggle is available (remains available even with no partner).
  bool canTogglePrivate([AddFlowContext? context]) => true;

  String resolvedPaidBy({
    String? viewerUserId,
    String? partnerUserId,
    bool? hasPartner,
  }) {
    final vId = viewerUserId ?? this.viewerUserId;
    final pId = partnerUserId ?? this.partnerUserId;
    final partnerExists = hasPartner ?? this.hasPartner;
    if (isPrivate || !partnerExists) return vId;
    switch (owner) {
      case CommitmentOwner.you:
        return vId;
      case CommitmentOwner.partner:
        return pId;
      case CommitmentOwner.both:
        return 'split';
    }
  }

  DateTime resolveNextBillingDate(DateTime referenceToday) {
    final ref = _dateOnly(referenceToday);
    if (cycle == CommitmentCycleOption.everyMonth ||
        cycle == CommitmentCycleOption.emi) {
      return nextBillingDate(
        today: ref,
        dayOfMonth: (dayOfMonth ?? ref.day).clamp(1, 28),
      );
    }
    if (nextDueDate != null) {
      return nextBillingDate(
        today: ref,
        nextDate: nextDueDate,
      );
    }
    return nextBillingDate(
      today: ref,
      month: (dueMonth ?? ref.month).clamp(1, 12),
      dayOfMonth: (dayOfMonth ?? ref.day).clamp(1, 28),
    );
  }

  CommitmentDraft copyWith({
    String? name,
    Object? amount = _sentinel,
    CommitmentCycleOption? cycle,
    Object? totalInstallments = _sentinel,
    Object? paidInstallments = _sentinel,
    Object? dayOfMonth = _sentinel,
    Object? dueMonth = _sentinel,
    Object? nextDueDate = _sentinel,
    Object? paidFrom = _sentinel,
    bool? paidFromSkipped,
    CommitmentOwner? owner,
    bool? isPrivate,
    Object? today = _sentinel,
    String? viewerUserId,
    String? partnerUserId,
    bool? hasPartner,
  }) {
    final nextHasPartner = hasPartner ?? this.hasPartner;
    final nextIsPrivate = isPrivate ?? this.isPrivate;
    final nextCycle = cycle ?? this.cycle;

    final int? nextTotal = identical(totalInstallments, _sentinel)
        ? this.totalInstallments
        : totalInstallments as int?;
    final int? nextPaid = identical(paidInstallments, _sentinel)
        ? (nextCycle == CommitmentCycleOption.emi
            ? (this.paidInstallments ?? 0)
            : this.paidInstallments)
        : paidInstallments as int?;

    final String? nextPaidFrom = identical(paidFrom, _sentinel)
        ? this.paidFrom
        : paidFrom as String?;

    return CommitmentDraft(
      name: name ?? this.name,
      amount: identical(amount, _sentinel) ? this.amount : amount as int?,
      cycle: nextCycle,
      totalInstallments: nextTotal,
      paidInstallments: nextPaid,
      dayOfMonth: identical(dayOfMonth, _sentinel)
          ? this.dayOfMonth
          : dayOfMonth as int?,
      dueMonth:
          identical(dueMonth, _sentinel) ? this.dueMonth : dueMonth as int?,
      nextDueDate: identical(nextDueDate, _sentinel)
          ? this.nextDueDate
          : nextDueDate as DateTime?,
      paidFrom: nextPaidFrom,
      paidFromSkipped: paidFromSkipped ??
          (!identical(paidFrom, _sentinel) &&
                  (nextPaidFrom == null || nextPaidFrom.trim().isEmpty)
              ? true
              : this.paidFromSkipped),
      owner: (nextIsPrivate || !nextHasPartner)
          ? CommitmentOwner.you
          : (owner ?? this.owner),
      isPrivate: nextIsPrivate,
      today: identical(today, _sentinel) ? this.today : today as DateTime?,
      viewerUserId: viewerUserId ?? this.viewerUserId,
      partnerUserId: partnerUserId ?? this.partnerUserId,
      hasPartner: nextHasPartner,
    );
  }

  static const List<AddStep> _standardSteps = <AddStep>[
    AddStep.commitmentName,
    AddStep.commitmentAmount,
    AddStep.commitmentHowOften,
    AddStep.commitmentWhenDue,
    AddStep.commitmentPaidFrom,
    AddStep.commitmentWhose,
    AddStep.review,
  ];

  static const List<AddStep> _emiSteps = <AddStep>[
    AddStep.commitmentName,
    AddStep.commitmentAmount,
    AddStep.commitmentHowOften,
    AddStep.commitmentEmiTotal,
    AddStep.commitmentEmiPaid,
    AddStep.commitmentWhenDue,
    AddStep.commitmentPaidFrom,
    AddStep.commitmentWhose,
    AddStep.review,
  ];

  @override
  List<AddStep> stepsFor(AddFlowContext context) {
    return isEmi ? _emiSteps : _standardSteps;
  }

  @override
  bool isAnswered(AddStep step) {
    switch (step) {
      case AddStep.commitmentName:
        return name.trim().isNotEmpty;
      case AddStep.commitmentAmount:
        return amount != null && amount! > 0;
      case AddStep.commitmentHowOften:
        return true;
      case AddStep.commitmentEmiTotal:
        return totalInstallments != null && totalInstallments! >= 1;
      case AddStep.commitmentEmiPaid:
        return paidInstallments != null &&
            totalInstallments != null &&
            totalInstallments! >= 1 &&
            paidInstallments! >= 0 &&
            paidInstallments! < totalInstallments!;
      case AddStep.commitmentWhenDue:
        if (cycle == CommitmentCycleOption.everyMonth ||
            cycle == CommitmentCycleOption.emi) {
          return dayOfMonth != null && dayOfMonth! >= 1 && dayOfMonth! <= 28;
        }
        return nextDueDate != null ||
            (dueMonth != null &&
                dueMonth! >= 1 &&
                dueMonth! <= 12 &&
                dayOfMonth != null &&
                dayOfMonth! >= 1 &&
                dayOfMonth! <= 28);
      case AddStep.commitmentPaidFrom:
        return (paidFrom != null && paidFrom!.trim().isNotEmpty) ||
            paidFromSkipped;
      case AddStep.commitmentWhose:
        return true;
      case AddStep.review:
        return isComplete;
      default:
        return false;
    }
  }

  @override
  bool get isComplete {
    if (!isAnswered(AddStep.commitmentName)) return false;
    if (!isAnswered(AddStep.commitmentAmount)) return false;
    if (!isAnswered(AddStep.commitmentWhenDue)) return false;
    if (isEmi) {
      if (!isAnswered(AddStep.commitmentEmiTotal)) return false;
      if (!isAnswered(AddStep.commitmentEmiPaid)) return false;
    }
    return true;
  }

  CommitmentCreateArgs toCreateArgs({
    DateTime? today,
    String? viewerUserId,
    String? partnerUserId,
    String? currency,
  }) {
    if (!isComplete) {
      throw StateError('CommitmentDraft is incomplete and cannot build args.');
    }
    final refToday = _dateOnly(today ?? this.today ?? DateTime(2026, 10, 5));
    final resolvedNextDate = resolveNextBillingDate(refToday);

    DateTime? emiEndDate;
    if (isEmi) {
      final total = totalInstallments!;
      final paid = paidInstallments!;
      final remaining = (total - paid).clamp(0, total);
      final cycleMonths = getBillingCycleMonths(billingCycle);
      emiEndDate = DateTime(
        refToday.year,
        refToday.month + (remaining * cycleMonths),
        resolvedNextDate.day,
      );
    }

    final cleanPaidFrom =
        (paidFrom == null || paidFrom!.trim().isEmpty) ? null : paidFrom!.trim();

    return CommitmentCreateArgs(
      name: name.trim(),
      amount: amount!.toDouble(),
      currency: currency,
      billingCycle: billingCycle,
      nextBillingDate: resolvedNextDate,
      category: 'Other',
      isPrivate: isPrivate,
      endDate: emiEndDate,
      paidBy: resolvedPaidBy(
        viewerUserId: viewerUserId,
        partnerUserId: partnerUserId,
      ),
      financedThrough: cleanPaidFrom,
      totalInstallments: isEmi ? totalInstallments : null,
      paidInstallments: isEmi ? paidInstallments : null,
    );
  }
}

// ============================================================================
// 6. ROUTINE DRAFT
// ============================================================================

/// Produces the routine container name for a set of weekday numbers (`1=Mon..7=Sun`)
/// (`design/specs/14-add-flow.md` §5):
/// - `[1..7]` → `'Everyday'`
/// - `[1..5]` → `'Weekdays'`
/// - `[6, 7]` → `'Weekend'`
/// - otherwise short day names joined (e.g. `'Mon, Wed, Fri'`).
String routineNameForDays(Iterable<int> days) {
  final sorted = days.where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
  if (listEquals(sorted, const <int>[1, 2, 3, 4, 5, 6, 7])) {
    return 'Everyday';
  }
  if (listEquals(sorted, const <int>[1, 2, 3, 4, 5])) {
    return 'Weekdays';
  }
  if (listEquals(sorted, const <int>[6, 7])) {
    return 'Weekend';
  }
  return sorted.map((d) => _weekdaysShort[d - 1]).join(', ');
}

/// Finds an existing routine whose sorted `days` or `daysJson` matches [days].
String? findMatchingRoutineId({
  required Iterable<int> days,
  Iterable<Routine> routines = const <Routine>[],
  Iterable<LocalRoutine> localRoutines = const <LocalRoutine>[],
}) {
  final target = days.where((d) => d >= 1 && d <= 7).toSet().toList()..sort();
  if (target.isEmpty) return null;

  for (final r in routines) {
    final sorted = r.days.where((d) => d >= 1 && d <= 7).toSet().toList()
      ..sort();
    if (listEquals(sorted, target)) {
      return r.id;
    }
  }

  for (final lr in localRoutines) {
    try {
      final decoded = (jsonDecode(lr.daysJson) as List<dynamic>)
          .map((e) => (e as num).toInt())
          .where((d) => d >= 1 && d <= 7)
          .toSet()
          .toList()
        ..sort();
      if (listEquals(decoded, target)) {
        return lr.id;
      }
    } catch (_) {
      continue;
    }
  }

  return null;
}

/// Plain value object holding the exact arguments for `RoutineController.createRoutineEvent`
/// (and `RoutineController.createRoutine` when [existingRoutineId] is `null`).
@immutable
class RoutineCreateArgs {
  final String? existingRoutineId;
  final String? newRoutineName;
  final List<int> days;
  final String title;
  final int startMinutes;
  final int endMinutes;

  const RoutineCreateArgs({
    required this.existingRoutineId,
    required this.newRoutineName,
    required this.days,
    required this.title,
    required this.startMinutes,
    required this.endMinutes,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineCreateArgs &&
          existingRoutineId == other.existingRoutineId &&
          newRoutineName == other.newRoutineName &&
          listEquals(days, other.days) &&
          title == other.title &&
          startMinutes == other.startMinutes &&
          endMinutes == other.endMinutes;

  @override
  int get hashCode => Object.hash(
        existingRoutineId,
        newRoutineName,
        Object.hashAll(days),
        title,
        startMinutes,
        endMinutes,
      );
}

/// Immutable draft for `AddKind.routine` (`design/specs/14-add-flow.md` §5).
@immutable
class RoutineDraft extends AddDraft {
  static const List<int> allowedDurations = <int>[15, 30, 45, 60, 120];

  final String title;
  final int? startMinutes; // 0..1439
  final int? durationMinutes; // 15 | 30 | 45 | 60 | 120
  final Set<int> days; // 1 = Mon .. 7 = Sun

  RoutineDraft({
    this.title = '',
    this.startMinutes = 540, // 9:00 AM default
    this.durationMinutes,
    Set<int> days = const <int>{1, 2, 3, 4, 5},
  }) : days = Set<int>.unmodifiable(
          (days.where((d) => d >= 1 && d <= 7).toList()..sort()),
        );

  factory RoutineDraft.initial(AddFlowContext context) {
    Set<int> initialDays = const <int>{1, 2, 3, 4, 5};
    if (context.routineId != null) {
      var found = false;
      for (final r in context.existingRoutines) {
        if (r.id == context.routineId) {
          final valid = r.days.where((d) => d >= 1 && d <= 7).toSet();
          if (valid.isNotEmpty) {
            initialDays = valid;
          }
          found = true;
          break;
        }
      }
      if (!found) {
        for (final lr in context.existingLocalRoutines) {
          if (lr.id == context.routineId) {
            try {
              final decoded = (jsonDecode(lr.daysJson) as List<dynamic>)
                  .map((e) => (e as num).toInt())
                  .where((d) => d >= 1 && d <= 7)
                  .toSet();
              if (decoded.isNotEmpty) {
                initialDays = decoded;
              }
            } catch (_) {}
            break;
          }
        }
      }
    }
    return RoutineDraft(
      startMinutes: (context.startMinutes ?? 540).clamp(0, 1439),
      days: initialDays,
    );
  }

  @override
  AddKind get kind => AddKind.routine;

  int get resolvedEndMinutes {
    final start = (startMinutes ?? 540).clamp(0, 1439);
    final duration = durationMinutes ?? 30;
    return math.min(1439, start + duration);
  }

  RoutineDraft copyWith({
    String? title,
    Object? startMinutes = _sentinel,
    Object? durationMinutes = _sentinel,
    Set<int>? days,
  }) {
    return RoutineDraft(
      title: title ?? this.title,
      startMinutes: identical(startMinutes, _sentinel)
          ? this.startMinutes
          : startMinutes as int?,
      durationMinutes: identical(durationMinutes, _sentinel)
          ? this.durationMinutes
          : durationMinutes as int?,
      days: days ?? this.days,
    );
  }

  static const List<AddStep> _steps = <AddStep>[
    AddStep.routineTitle,
    AddStep.routineWhen,
    AddStep.routineDuration,
    AddStep.routineDays,
    AddStep.review,
  ];

  @override
  List<AddStep> stepsFor(AddFlowContext context) => _steps;

  @override
  bool isAnswered(AddStep step) {
    switch (step) {
      case AddStep.routineTitle:
        return title.trim().isNotEmpty;
      case AddStep.routineWhen:
        return startMinutes != null &&
            startMinutes! >= 0 &&
            startMinutes! <= 1439;
      case AddStep.routineDuration:
        return durationMinutes != null && durationMinutes! > 0;
      case AddStep.routineDays:
        return days.isNotEmpty;
      case AddStep.review:
        return isComplete;
      default:
        return false;
    }
  }

  @override
  bool get isComplete =>
      isAnswered(AddStep.routineTitle) &&
      isAnswered(AddStep.routineWhen) &&
      isAnswered(AddStep.routineDuration) &&
      isAnswered(AddStep.routineDays);

  RoutineCreateArgs toCreateArgs({
    Iterable<Routine> existingRoutines = const <Routine>[],
    Iterable<LocalRoutine> existingLocalRoutines = const <LocalRoutine>[],
  }) {
    if (!isComplete) {
      throw StateError('RoutineDraft is incomplete and cannot build args.');
    }
    final sortedDays = days.toList()..sort();
    final matchedId = findMatchingRoutineId(
      days: sortedDays,
      routines: existingRoutines,
      localRoutines: existingLocalRoutines,
    );

    return RoutineCreateArgs(
      existingRoutineId: matchedId,
      newRoutineName:
          matchedId == null ? routineNameForDays(sortedDays) : null,
      days: List<int>.unmodifiable(sortedDays),
      title: title.trim(),
      startMinutes: startMinutes!.clamp(0, 1439),
      endMinutes: resolvedEndMinutes,
    );
  }
}
