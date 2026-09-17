import 'package:intl/intl.dart';
import '../../sync/db/app_database.dart';

class HabitStreakResult {
  final int currentStreak;
  final int bestStreak;
  final bool isCheckedToday;
  final bool hasAcknowledgmentToday;
  final String? acknowledgedBy;

  const HabitStreakResult({
    required this.currentStreak,
    required this.bestStreak,
    required this.isCheckedToday,
    this.hasAcknowledgmentToday = false,
    this.acknowledgedBy,
  });
}

class HabitStreakCalculator {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  /// Formats a [DateTime] into standard `YYYY-MM-DD` checkin key.
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Calculates the streak statistics for a habit based on its check-in history.
  ///
  /// Supports:
  /// - `daily`: consecutive days checked in. If today is not checked in, checks if yesterday was checked in to preserve streak.
  /// - `weekly`: consecutive weeks completed.
  /// - `custom`: target days per week.
  static HabitStreakResult calculate({
    required LocalHabit habit,
    required List<LocalHabitCheckin> checkins,
    DateTime? referenceDate,
    String? currentUserId,
  }) {
    final now = referenceDate ?? DateTime.now();
    final todayStr = formatDate(now);
    final yesterdayStr = formatDate(now.subtract(const Duration(days: 1)));

    // Separate real check-ins from acknowledgments (which have memberId starting with 'ack:')
    final validCheckins = <LocalHabitCheckin>[];
    final ackCheckins = <LocalHabitCheckin>[];

    for (final c in checkins) {
      if (c.memberId.startsWith('ack:')) {
        ackCheckins.add(c);
      } else {
        validCheckins.add(c);
      }
    }

    // Set of distinct dates checked in by the habit creator
    final checkedDates = validCheckins.map((c) => c.checkinDate).toSet();
    final isCheckedToday = checkedDates.contains(todayStr);

    // Check acknowledgments for today
    bool hasAckToday = false;
    String? ackBy;
    for (final a in ackCheckins) {
      if (a.checkinDate == todayStr) {
        hasAckToday = true;
        ackBy = a.memberId.replaceFirst('ack:', '');
        break;
      }
    }

    if (checkedDates.isEmpty) {
      return HabitStreakResult(
        currentStreak: 0,
        bestStreak: 0,
        isCheckedToday: false,
        hasAcknowledgmentToday: false,
      );
    }

    final cadence = habit.cadence.toLowerCase();
    if (cadence.startsWith('weekly')) {
      return _calculateWeeklyStreak(
        checkedDates: checkedDates,
        now: now,
        isCheckedToday: isCheckedToday,
        hasAckToday: hasAckToday,
        ackBy: ackBy,
      );
    }

    // Daily & Custom days-per-week streak calculation
    return _calculateDailyStreak(
      checkedDates: checkedDates,
      now: now,
      todayStr: todayStr,
      yesterdayStr: yesterdayStr,
      isCheckedToday: isCheckedToday,
      hasAckToday: hasAckToday,
      ackBy: ackBy,
    );
  }

  static HabitStreakResult _calculateDailyStreak({
    required Set<String> checkedDates,
    required DateTime now,
    required String todayStr,
    required String yesterdayStr,
    required bool isCheckedToday,
    required bool hasAckToday,
    required String? ackBy,
  }) {
    // 1. Current Streak:
    // If today is checked in, count backwards from today.
    // If today is not checked in, check if yesterday is checked in to keep streak alive.
    int currentStreak = 0;
    DateTime cursor = isCheckedToday ? now : now.subtract(const Duration(days: 1));

    while (checkedDates.contains(formatDate(cursor))) {
      currentStreak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // 2. Best Streak:
    // Parse all dates, sort chronologically, find longest consecutive sequence.
    final sortedDates = checkedDates.map((s) => DateTime.tryParse(s)).whereType<DateTime>().toList()
      ..sort();

    int bestStreak = 0;
    int run = 0;
    DateTime? prevDate;

    for (final d in sortedDates) {
      if (prevDate == null) {
        run = 1;
      } else {
        final diff = d.difference(prevDate).inDays;
        if (diff == 1) {
          run++;
        } else if (diff > 1) {
          run = 1;
        }
      }
      if (run > bestStreak) {
        bestStreak = run;
      }
      prevDate = d;
    }

    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }

    return HabitStreakResult(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      isCheckedToday: isCheckedToday,
      hasAcknowledgmentToday: hasAckToday,
      acknowledgedBy: ackBy,
    );
  }

  static HabitStreakResult _calculateWeeklyStreak({
    required Set<String> checkedDates,
    required DateTime now,
    required bool isCheckedToday,
    required bool hasAckToday,
    required String? ackBy,
  }) {
    final weeks = <int>{};
    for (final dateStr in checkedDates) {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) {
        weeks.add(_isoWeekNumber(dt));
      }
    }

    final currentWeek = _isoWeekNumber(now);

    int currentStreak = 0;
    DateTime cursor = weeks.contains(currentWeek) ? now : now.subtract(const Duration(days: 7));

    while (weeks.contains(_isoWeekNumber(cursor))) {
      currentStreak++;
      cursor = cursor.subtract(const Duration(days: 7));
    }

    final sortedWeeks = weeks.toList()..sort();
    int bestStreak = 0;
    int run = 0;
    int? prev;

    for (final w in sortedWeeks) {
      if (prev == null) {
        run = 1;
      } else {
        if (w == prev + 1 || (prev % 100 >= 52 && w % 100 == 1 && (w ~/ 100) == (prev ~/ 100) + 1)) {
          run++;
        } else {
          run = 1;
        }
      }
      if (run > bestStreak) bestStreak = run;
      prev = w;
    }

    if (currentStreak > bestStreak) bestStreak = currentStreak;

    return HabitStreakResult(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      isCheckedToday: isCheckedToday,
      hasAcknowledgmentToday: hasAckToday,
      acknowledgedBy: ackBy,
    );
  }

  static int _isoWeekNumber(DateTime date) {
    final dayOfYear = int.parse(DateFormat('D').format(date));
    final woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    return date.year * 100 + woy;
  }
}
