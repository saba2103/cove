import 'package:flutter/material.dart';

/// Models the frequency, days of the week, and optional time-of-day for a habit.
///
/// Encodes schedule into a compact, backwards-compatible string stored in `LocalHabits.cadence`:
/// - `daily` or `daily@08:30`
/// - `weekly:6@09:00` (Weekly on Saturday at 09:00) or `weekly:6`
/// - `custom:1,3,5@08:00` (Mon, Wed, Fri at 08:00) or `custom:1,3,5`
class HabitSchedule {
  final String frequency; // 'daily' | 'weekly' | 'custom'
  final List<int> daysOfWeek; // 1 = Mon, 7 = Sun
  final TimeOfDay? timeOfDay;

  const HabitSchedule({
    required this.frequency,
    this.daysOfWeek = const [],
    this.timeOfDay,
  });

  /// Parse from stored cadence string and fallback target days
  factory HabitSchedule.parse(String cadence, {int targetDays = 7}) {
    final raw = cadence.trim();
    if (raw.isEmpty) {
      return const HabitSchedule(frequency: 'daily', daysOfWeek: [1, 2, 3, 4, 5, 6, 7]);
    }

    String freqPart = raw;
    TimeOfDay? time;

    // Check for @HH:mm
    if (raw.contains('@')) {
      final atParts = raw.split('@');
      freqPart = atParts[0];
      if (atParts.length > 1 && atParts[1].contains(':')) {
        final timeParts = atParts[1].split(':');
        final h = int.tryParse(timeParts[0]);
        final m = int.tryParse(timeParts[1]);
        if (h != null && m != null) {
          time = TimeOfDay(hour: h, minute: m);
        }
      }
    }

    if (freqPart.startsWith('daily')) {
      return HabitSchedule(
        frequency: 'daily',
        daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
        timeOfDay: time,
      );
    }

    if (freqPart.startsWith('weekly')) {
      final days = <int>[];
      if (freqPart.contains(':')) {
        final daysStr = freqPart.split(':')[1];
        for (final s in daysStr.split(',')) {
          final d = int.tryParse(s.trim());
          if (d != null && d >= 1 && d <= 7) days.add(d);
        }
      }
      if (days.isEmpty) days.add(1); // Default Monday
      return HabitSchedule(
        frequency: 'weekly',
        daysOfWeek: days,
        timeOfDay: time,
      );
    }

    // Custom
    final days = <int>[];
    if (freqPart.contains(':')) {
      final daysStr = freqPart.split(':')[1];
      for (final s in daysStr.split(',')) {
        final d = int.tryParse(s.trim());
        if (d != null && d >= 1 && d <= 7) days.add(d);
      }
    }
    if (days.isEmpty) {
      final count = targetDays.abs().clamp(1, 7);
      for (int i = 1; i <= count; i++) {
        days.add(i);
      }
    }

    return HabitSchedule(
      frequency: 'custom',
      daysOfWeek: days,
      timeOfDay: time,
    );
  }

  /// Encodes this schedule into a cadence string for database persistence.
  String toCadenceString() {
    String base;
    if (frequency == 'daily') {
      base = 'daily';
    } else if (frequency == 'weekly') {
      final sorted = List<int>.from(daysOfWeek)..sort();
      final daysStr = sorted.isNotEmpty ? sorted.join(',') : '1';
      base = 'weekly:$daysStr';
    } else {
      final sorted = List<int>.from(daysOfWeek)..sort();
      final daysStr = sorted.isNotEmpty ? sorted.join(',') : '1,3,5';
      base = 'custom:$daysStr';
    }

    if (timeOfDay != null) {
      final hh = timeOfDay!.hour.toString().padLeft(2, '0');
      final mm = timeOfDay!.minute.toString().padLeft(2, '0');
      return '$base@$hh:$mm';
    }
    return base;
  }

  /// Formats human-readable time e.g. "8:30 AM"
  String? formatTime(BuildContext? context) {
    if (timeOfDay == null) return null;
    final hour = timeOfDay!.hour;
    final minute = timeOfDay!.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:$minute $period';
  }

  /// Formats human-readable label e.g. "Every Sat • 9:00 AM" or "Mon, Wed, Fri • 8:00 AM"
  String formatDisplayLabel({int? targetDays}) {
    final timeStr = formatTime(null);
    final suffix = timeStr != null ? ' • $timeStr' : '';

    if (frequency == 'daily') {
      return 'Daily$suffix';
    }

    final dayNamesShort = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };

    if (frequency == 'weekly') {
      if (daysOfWeek.length == 1) {
        final dayName = dayNamesShort[daysOfWeek.first] ?? 'Mon';
        return 'Every $dayName$suffix';
      } else if (daysOfWeek.isNotEmpty) {
        final sorted = List<int>.from(daysOfWeek)..sort();
        final names = sorted.map((d) => dayNamesShort[d]).join(', ');
        return 'Weekly ($names)$suffix';
      }
      return 'Weekly$suffix';
    }

    // Custom
    if (daysOfWeek.isNotEmpty && daysOfWeek.length < 7) {
      final sorted = List<int>.from(daysOfWeek)..sort();
      final names = sorted.map((d) => dayNamesShort[d]).join(', ');
      return '$names$suffix';
    }

    final days = (targetDays ?? daysOfWeek.length).abs();
    return '$days days / week$suffix';
  }
}
