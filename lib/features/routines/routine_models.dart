import 'dart:convert';
import 'package:flutter/material.dart';
import '../../sync/db/app_database.dart';

class Routine {
  final String id;
  final String homeId;
  final String name;
  final List<int> days; // 1=Mon .. 7=Sun
  final DateTime createdAt;

  const Routine({
    required this.id,
    required this.homeId,
    required this.name,
    required this.days,
    required this.createdAt,
  });

  factory Routine.fromLocal(LocalRoutine local) {
    List<int> parsedDays = [];
    try {
      final decoded = jsonDecode(local.daysJson);
      if (decoded is List) {
        parsedDays = decoded.map((e) => int.tryParse(e.toString()) ?? 1).toList();
      }
    } catch (_) {
      parsedDays = [1, 2, 3, 4, 5];
    }
    parsedDays.sort();
    return Routine(
      id: local.id,
      homeId: local.homeId,
      name: local.name,
      days: parsedDays,
      createdAt: local.createdAt,
    );
  }

  String get daysSummary {
    if (days.isEmpty) return 'No days';
    if (days.length == 7) return 'Every day';
    if (_listEquals(days, [1, 2, 3, 4, 5])) return 'Mon – Fri';
    if (_listEquals(days, [6, 7])) return 'Sat, Sun';

    const dayLabels = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return days.map((d) => dayLabels[d] ?? '').where((s) => s.isNotEmpty).join(', ');
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class RoutineEvent {
  final String id;
  final String routineId;
  final String homeId;
  final String title;
  final int startMinutes; // 0..1439
  final int endMinutes;   // 0..1439
  final String? category;
  final String? notes;
  final DateTime createdAt;

  const RoutineEvent({
    required this.id,
    required this.routineId,
    required this.homeId,
    required this.title,
    required this.startMinutes,
    required this.endMinutes,
    this.category,
    this.notes,
    required this.createdAt,
  });

  factory RoutineEvent.fromLocal(LocalRoutineEvent local) {
    return RoutineEvent(
      id: local.id,
      routineId: local.routineId,
      homeId: local.homeId,
      title: local.title,
      startMinutes: local.startMinutes,
      endMinutes: local.endMinutes,
      category: local.category,
      notes: local.notes,
      createdAt: local.createdAt,
    );
  }

  int get durationMinutes {
    if (endMinutes >= startMinutes) {
      return endMinutes - startMinutes;
    }
    return (1440 - startMinutes) + endMinutes; // wraps past midnight
  }

  String get formattedTimeRange {
    return '${formatMinutes(startMinutes)} – ${formatMinutes(endMinutes)}';
  }

  static String formatMinutes(int minutes) {
    final normalized = minutes % 1440;
    final hour = normalized ~/ 60;
    final min = normalized % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMin = min.toString().padLeft(2, '0');
    return '$displayHour:$displayMin $period';
  }

  Color get categoryColor {
    final cat = (category ?? 'general').toLowerCase().trim();
    switch (cat) {
      case 'work':
      case 'focus':
        return const Color(0xFF6B8AFD); // Blue
      case 'fitness':
      case 'workout':
      case 'exercise':
        return const Color(0xFFE57373); // Coral Red
      case 'health':
      case 'wellness':
        return const Color(0xFF4DB6AC); // Teal
      case 'meals':
      case 'food':
      case 'breakfast':
      case 'lunch':
      case 'dinner':
        return const Color(0xFFFFB74D); // Amber
      case 'sleep':
      case 'rest':
        return const Color(0xFF9575CD); // Deep Purple
      case 'study':
      case 'reading':
      case 'learning':
        return const Color(0xFF81C784); // Green
      case 'household':
      case 'chores':
        return const Color(0xFFFF8A65); // Warm Orange
      case 'leisure':
      case 'hobby':
      case 'relax':
        return const Color(0xFFBA68C8); // Violet
      default:
        return const Color(0xFF90A4AE); // Blue Grey
    }
  }
}
