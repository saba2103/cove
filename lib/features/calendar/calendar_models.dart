import 'package:clock/clock.dart';
import 'package:intl/intl.dart';
import '../../sync/db/app_database.dart';
import '../habits/habit_schedule.dart';
import '../habits/habit_streak_calculator.dart';
import '../reminders/reminder_models.dart';
import '../routines/routine_models.dart';
import '../subscriptions/commitment_models.dart';

/// The 5 layers carrying dated household information on the calendar.
enum CalendarLayer {
  all('All', 'ALL'),
  events('Events', 'EVENT'),
  commitments('Commitments', 'RENEWAL'),
  money('Money', 'EXPENSE'),
  rhythms('Habits', 'HABIT'),
  tasks('Tasks', 'TASK');

  final String label;
  final String microLabel;

  const CalendarLayer(this.label, this.microLabel);
}

/// Unified model representing any dated entity on the shared calendar.
sealed class CalendarEntry {
  final DateTime date;

  const CalendarEntry(this.date);

  String get id;
  String get title;
  CalendarLayer get layer;
  bool get isAllDay;
  DateTime get startTime;
}

/// A calendar event created by either partner.
class CalendarEventEntry extends CalendarEntry {
  final LocalCalendarEvent event;
  final DateTime occurrenceStartTime;
  final DateTime occurrenceEndTime;

  CalendarEventEntry(
    this.event, {
    DateTime? occurrenceStartTime,
    DateTime? occurrenceEndTime,
  })  : occurrenceStartTime = occurrenceStartTime ?? event.startTime,
        occurrenceEndTime = occurrenceEndTime ?? event.endTime,
        super(occurrenceStartTime ?? event.startTime);

  @override
  String get id => occurrenceStartTime == event.startTime
      ? event.id
      : '${event.id}_${DateFormat('yyyyMMdd').format(occurrenceStartTime)}';

  @override
  String get title => event.title;

  @override
  CalendarLayer get layer => CalendarLayer.events;

  @override
  bool get isAllDay => event.isAllDay;

  @override
  DateTime get startTime => occurrenceStartTime;

  DateTime get endTime => occurrenceEndTime;
  String? get location => event.location;
  String? get description => event.description;
  String get createdBy => event.createdBy;
  String? get recurrence => event.recurrence;
  bool get isRecurring =>
      event.recurrence != null &&
      event.recurrence!.isNotEmpty &&
      event.recurrence != 'none';
}

/// An inline auto-surfaced subscription renewal from the Subscriptions module.
class CalendarSubscriptionEntry extends CalendarEntry {
  final LocalSubscription subscription;

  CalendarSubscriptionEntry({
    required this.subscription,
    required DateTime renewalDate,
  }) : super(renewalDate);

  @override
  String get id => 'sub_renewal_${subscription.id}_${DateFormat('yyyyMMdd').format(date)}';

  @override
  String get title => subscription.name;

  @override
  CalendarLayer get layer => CalendarLayer.commitments;

  @override
  bool get isAllDay => true;

  @override
  DateTime get startTime => date;

  double get amount => subscription.amount;
  String get currency => subscription.currency;
  String? get category => subscription.category;
}

/// A logged expense entry on the calendar.
class CalendarExpenseEntry extends CalendarEntry {
  final LocalExpense expense;
  final String payerName;
  final bool isCurrentUser;

  CalendarExpenseEntry({
    required this.expense,
    required this.payerName,
    this.isCurrentUser = false,
  }) : super(CalendarDateUtils.dateOnly(expense.expenseDate));

  @override
  String get id => 'expense_${expense.id}';

  @override
  String get title => expense.title;

  @override
  CalendarLayer get layer => CalendarLayer.money;

  @override
  bool get isAllDay => true;

  @override
  DateTime get startTime => expense.expenseDate;

  double get amount => expense.amount;
  String? get category => expense.category;
  String? get paymentMethod => expense.paymentMethod;
  String get paidBy => expense.paidBy;
}

/// A habit due on this date.
class CalendarHabitEntry extends CalendarEntry {
  final LocalHabit habit;
  final bool isDue;
  final int streak;
  final bool userCheckedIn;
  final bool partnerCheckedIn;
  final bool isPrivate;

  CalendarHabitEntry({
    required this.habit,
    required DateTime date,
    required this.isDue,
    required this.streak,
    required this.userCheckedIn,
    required this.partnerCheckedIn,
    required this.isPrivate,
  }) : super(CalendarDateUtils.dateOnly(date));

  @override
  String get id => 'habit_${habit.id}_${DateFormat('yyyyMMdd').format(date)}';

  @override
  String get title => habit.name;

  @override
  CalendarLayer get layer => CalendarLayer.rhythms;

  @override
  bool get isAllDay => true;

  @override
  DateTime get startTime => date;
}

/// A task / list item with a due date.
class CalendarTaskEntry extends CalendarEntry {
  final LocalListItem item;
  final String listName;
  final DateTime dueDate;

  CalendarTaskEntry({
    required this.item,
    required this.listName,
    required this.dueDate,
  }) : super(CalendarDateUtils.dateOnly(dueDate));

  @override
  String get id => 'task_${item.id}';

  @override
  String get title => item.title;

  @override
  CalendarLayer get layer => CalendarLayer.tasks;

  @override
  bool get isAllDay => true;

  @override
  DateTime get startTime => dueDate;

  bool get isCompleted => item.isCompleted;
  String get listId => item.listId;
  String? get notes => item.notes;
}

/// A routine block occurring on this date.
class CalendarRoutineEntry extends CalendarEntry {
  final RoutineEvent routineEvent;
  final Routine routine;
  final DateTime occurrenceStartTime;
  final DateTime occurrenceEndTime;

  CalendarRoutineEntry({
    required this.routineEvent,
    required this.routine,
    required DateTime date,
    required this.occurrenceStartTime,
    required this.occurrenceEndTime,
  }) : super(CalendarDateUtils.dateOnly(date));

  @override
  String get id => 'routine_${routineEvent.id}_${DateFormat('yyyyMMdd').format(date)}';

  @override
  String get title => routineEvent.title;

  @override
  CalendarLayer get layer => CalendarLayer.tasks;

  @override
  bool get isAllDay => false;

  @override
  DateTime get startTime => occurrenceStartTime;

  DateTime get endTime => occurrenceEndTime;
  int get startMinutes => routineEvent.startMinutes;
  int get endMinutes => routineEvent.endMinutes;
  String? get category => routineEvent.category;
  String? get notes => routineEvent.notes;
  String get formattedTimeRange => routineEvent.formattedTimeRange;
}

/// A scheduled check-in reminder on this date.
class CalendarReminderEntry extends CalendarEntry {
  final CheckinReminder reminder;
  final DateTime occurrenceTime;

  CalendarReminderEntry({
    required this.reminder,
    required DateTime date,
    required this.occurrenceTime,
  }) : super(CalendarDateUtils.dateOnly(date));

  @override
  String get id => 'reminder_${reminder.id}_${DateFormat('yyyyMMdd').format(date)}';

  @override
  String get title => reminder.message;

  @override
  CalendarLayer get layer => CalendarLayer.tasks;

  @override
  bool get isAllDay => false;

  @override
  DateTime get startTime => occurrenceTime;

  int get hour => reminder.hour;
  int get minute => reminder.minute;
  String get formattedTime => reminder.formattedTime;
}

class CalendarDateUtils {
  static final DateFormat _dayOfWeekFormat = DateFormat('EEE');
  static final DateFormat _monthFormat = DateFormat('MMM');
  static final DateFormat _fullMonthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat _timeFormat = DateFormat('h:mm a');
  static final DateFormat _dateHeadingFormat = DateFormat('EEEE, MMM d');

  static String formatDayOfWeek(DateTime date) => _dayOfWeekFormat.format(date);
  static String formatMonth(DateTime date) => _monthFormat.format(date);
  static String formatMonthYear(DateTime date) => _fullMonthYearFormat.format(date);
  static String formatTime(DateTime date) => _timeFormat.format(date);
  static String formatDateHeading(DateTime date) => _dateHeadingFormat.format(date);

  /// Strips time components for clean day comparisons.
  static DateTime dateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  /// Returns true if two dates represent the exact same calendar day.
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Returns the start of the week (Monday) for the given date.
  static DateTime startOfWeek(DateTime date) {
    final clean = dateOnly(date);
    return clean.subtract(Duration(days: clean.weekday - 1));
  }

  /// Returns 7 dates (Monday through Sunday) for the week containing [date].
  static List<DateTime> getWeekDays(DateTime date) {
    final monday = startOfWeek(date);
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  /// Generates the days of a month including padding days for a Monday-first grid.
  static List<DateTime?> getMonthGridDays(int year, int month) {
    final firstOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingPadding = (firstOfMonth.weekday - 1); // Monday=1 -> 0 padding

    final List<DateTime?> days = [];
    for (int i = 0; i < leadingPadding; i++) {
      days.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      days.add(DateTime(year, month, d));
    }
    // Optional trailing padding to complete the last row
    while (days.length % 7 != 0) {
      days.add(null);
    }
    return days;
  }

  /// Relative date label like "Today · Sep 10", "Tomorrow · Sep 11", or "Thursday · Sep 12"
  static String getRelativeDateLabel(DateTime date, {DateTime? now}) {
    final ref = dateOnly(now ?? clock.now());
    final target = dateOnly(date);
    final diff = target.difference(ref).inDays;

    final formatted = DateFormat('MMM d').format(target);
    if (diff == 0) {
      return 'Today · $formatted';
    } else if (diff == 1) {
      return 'Tomorrow · $formatted';
    } else if (diff == -1) {
      return 'Yesterday · $formatted';
    } else {
      return '${DateFormat('EEEE').format(target)} · $formatted';
    }
  }

  /// Projects upcoming subscription renewals from their [nextBillingDate] and [billingCycle]
  /// up to [endDate].
  static List<CalendarSubscriptionEntry> projectSubscriptions({
    required List<LocalSubscription> subscriptions,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final List<CalendarSubscriptionEntry> entries = [];
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);

    for (final sub in subscriptions) {
      if (!sub.isActive) continue;

      DateTime cursor = dateOnly(sub.nextBillingDate);
      final cycle = sub.billingCycle.toLowerCase();
      final months = getBillingCycleMonths(sub.billingCycle);

      // If cursor is before start, advance it to on or after start
      while (cursor.isBefore(start)) {
        if (cycle == 'weekly') {
          cursor = cursor.add(const Duration(days: 7));
        } else {
          cursor = DateTime(cursor.year, cursor.month + months, cursor.day);
        }
      }

      // Collect occurrences up to end
      while (!cursor.isAfter(end)) {
        entries.add(CalendarSubscriptionEntry(
          subscription: sub,
          renewalDate: cursor,
        ));

        if (cycle == 'weekly') {
          cursor = cursor.add(const Duration(days: 7));
        } else {
          cursor = DateTime(cursor.year, cursor.month + months, cursor.day);
        }
      }
    }

    return entries;
  }

  /// Projects regular and recurring events between [startDate] and [endDate].
  static List<CalendarEventEntry> projectCalendarEvents({
    required List<LocalCalendarEvent> events,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final List<CalendarEventEntry> entries = [];
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);

    for (final event in events) {
      final rec = event.recurrence?.toLowerCase().trim();
      final hasRecurrence = rec != null && rec.isNotEmpty && rec != 'none';

      if (!hasRecurrence) {
        final evDate = dateOnly(event.startTime);
        if (!evDate.isBefore(start) && !evDate.isAfter(end)) {
          entries.add(CalendarEventEntry(event));
        }
        continue;
      }

      // Handle recurring event
      final duration = event.endTime.difference(event.startTime);
      DateTime cursor = event.startTime;

      // Advance cursor to on or near start if it starts before start
      int safety = 0;
      while (dateOnly(cursor).isBefore(start) && safety < 1000) {
        safety++;
        cursor = _nextRecurrence(cursor, rec);
      }

      safety = 0;
      while (!dateOnly(cursor).isAfter(end) && safety < 1000) {
        safety++;
        entries.add(CalendarEventEntry(
          event,
          occurrenceStartTime: cursor,
          occurrenceEndTime: cursor.add(duration),
        ));
        cursor = _nextRecurrence(cursor, rec);
      }
    }

    return entries;
  }

  static DateTime _nextRecurrence(DateTime current, String rec) {
    switch (rec) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'biweekly':
      case 'bi-weekly':
        return current.add(const Duration(days: 14));
      case 'monthly':
        final nextMonth = current.month == 12 ? 1 : current.month + 1;
        final nextYear = current.month == 12 ? current.year + 1 : current.year;
        final maxDay = DateTime(nextYear, nextMonth + 1, 0).day;
        final day = current.day > maxDay ? maxDay : current.day;
        return DateTime(nextYear, nextMonth, day, current.hour, current.minute);
      case 'yearly':
      case 'annual':
        final nextYear = current.year + 1;
        final maxDay = DateTime(nextYear, current.month + 1, 0).day;
        final day = current.day > maxDay ? maxDay : current.day;
        return DateTime(nextYear, current.month, day, current.hour, current.minute);
      default:
        return current.add(const Duration(days: 7));
    }
  }

  /// Projects logged expenses between [startDate] and [endDate].
  static List<CalendarExpenseEntry> projectExpenses({
    required List<LocalExpense> expenses,
    required DateTime startDate,
    required DateTime endDate,
    String? currentUserId,
    String partnerName = 'Partner',
  }) {
    final List<CalendarExpenseEntry> entries = [];
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);

    for (final exp in expenses) {
      final expDate = dateOnly(exp.expenseDate);
      if (!expDate.isBefore(start) && !expDate.isAfter(end)) {
        final isMe = currentUserId != null && exp.paidBy == currentUserId;
        final payer = isMe ? 'You' : partnerName;
        entries.add(CalendarExpenseEntry(
          expense: exp,
          payerName: payer,
          isCurrentUser: isMe,
        ));
      }
    }

    return entries;
  }

  /// Projects habits due between [startDate] and [endDate].
  static List<CalendarHabitEntry> projectHabits({
    required List<LocalHabit> habits,
    required List<LocalHabitCheckin> checkins,
    required String currentUserId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final List<CalendarHabitEntry> entries = [];
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);

    int daysCount = end.difference(start).inDays + 1;
    if (daysCount > 1000) daysCount = 1000;
    if (daysCount < 0) return entries;

    for (int i = 0; i < daysCount; i++) {
      final currentDay = start.add(Duration(days: i));
      final dayString = DateFormat('yyyy-MM-dd').format(currentDay);

      for (final h in habits) {
        if (h.isArchived) continue;
        final sched = HabitSchedule.parse(h.cadence, targetDays: h.targetDaysPerWeek);
        if (!sched.isDueOn(currentDay)) continue;

        final userChecked = checkins.any((c) =>
            c.habitId == h.id &&
            c.memberId == currentUserId &&
            c.checkinDate == dayString);

        final partnerChecked = checkins.any((c) =>
            c.habitId == h.id &&
            c.memberId != currentUserId &&
            c.checkinDate == dayString);

        final streak = HabitStreakCalculator.calculate(
          habit: h,
          checkins: checkins,
          referenceDate: currentDay,
          currentUserId: h.createdBy,
        );

        final isPrivate = h.targetDaysPerWeek < 0;

        entries.add(CalendarHabitEntry(
          habit: h,
          date: currentDay,
          isDue: true,
          streak: streak.currentStreak,
          userCheckedIn: userChecked,
          partnerCheckedIn: partnerChecked,
          isPrivate: isPrivate,
        ));
      }
    }

    return entries;
  }

  /// Projects list tasks between [startDate] and [endDate].
  ///
  /// Per `design/screens/calendar.md`:
  /// - A task with a due date appears on its due date.
  /// - A task with no due date appears on the day it was **added** (`createdAt`).
  /// - When ticked, it also appears on the day it was **struck** (`completedAt`).
  static List<CalendarTaskEntry> projectTasks({
    required List<LocalListItem> items,
    required Map<String, String> listNames,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final List<CalendarTaskEntry> entries = [];
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);

    for (final item in items) {
      final listName = listNames[item.listId] ?? 'List';
      final primaryDate = dateOnly(item.dueDate ?? item.createdAt);
      if (!primaryDate.isBefore(start) && !primaryDate.isAfter(end)) {
        entries.add(CalendarTaskEntry(
          item: item,
          listName: listName,
          dueDate: primaryDate,
        ));
      }

      if (item.isCompleted && item.completedAt != null) {
        final struckDate = dateOnly(item.completedAt!);
        if (struckDate != primaryDate &&
            !struckDate.isBefore(start) &&
            !struckDate.isAfter(end)) {
          entries.add(CalendarTaskEntry(
            item: item,
            listName: listName,
            dueDate: struckDate,
          ));
        }
      }
    }

    return entries;
  }

  /// Projects routine blocks between [startDate] and [endDate].
  static List<CalendarRoutineEntry> projectRoutines({
    required List<Routine> routines,
    required List<RoutineEvent> routineEvents,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final List<CalendarRoutineEntry> entries = [];
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);

    final routineMap = {for (final r in routines) r.id: r};
    int daysCount = end.difference(start).inDays + 1;
    if (daysCount > 1000) daysCount = 1000;
    if (daysCount < 0) return entries;

    for (int i = 0; i < daysCount; i++) {
      final currentDay = start.add(Duration(days: i));
      final weekday = currentDay.weekday; // 1=Mon .. 7=Sun

      for (final ev in routineEvents) {
        final parentRoutine = routineMap[ev.routineId];
        if (parentRoutine == null) continue;
        if (!parentRoutine.days.contains(weekday)) continue;

        final startMinutes = ev.startMinutes;
        final endMinutes = ev.endMinutes;
        final startTime = currentDay.add(Duration(minutes: startMinutes));
        final endTime = currentDay.add(Duration(minutes: endMinutes));

        entries.add(CalendarRoutineEntry(
          routineEvent: ev,
          routine: parentRoutine,
          date: currentDay,
          occurrenceStartTime: startTime,
          occurrenceEndTime: endTime,
        ));
      }
    }

    return entries;
  }

  /// Projects check-in reminders between [startDate] and [endDate].
  static List<CalendarReminderEntry> projectReminders({
    required List<CheckinReminder> reminders,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final List<CalendarReminderEntry> entries = [];
    final start = dateOnly(startDate);
    final end = dateOnly(endDate);

    int daysCount = end.difference(start).inDays + 1;
    if (daysCount > 1000) daysCount = 1000;
    if (daysCount < 0) return entries;

    for (int i = 0; i < daysCount; i++) {
      final currentDay = start.add(Duration(days: i));
      for (final rem in reminders) {
        if (!rem.isEnabled) continue;
        final remTime = DateTime(
          currentDay.year,
          currentDay.month,
          currentDay.day,
          rem.hour,
          rem.minute,
        );
        entries.add(CalendarReminderEntry(
          reminder: rem,
          date: currentDay,
          occurrenceTime: remTime,
        ));
      }
    }

    return entries;
  }
}
