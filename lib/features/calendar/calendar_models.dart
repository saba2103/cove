import 'package:intl/intl.dart';
import '../../sync/db/app_database.dart';
import '../subscriptions/commitment_models.dart';

/// Unified model representing either an actual calendar event or a surfaced subscription renewal.
sealed class CalendarEntry {
  final DateTime date;

  const CalendarEntry(this.date);

  String get id;
  String get title;
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

  bool get isAllDay => event.isAllDay;
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

  double get amount => subscription.amount;
  String get currency => subscription.currency;
  String? get category => subscription.category;
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
    final ref = dateOnly(now ?? DateTime.now());
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
}
