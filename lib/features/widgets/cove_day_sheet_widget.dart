import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../calendar/calendar_models.dart';
import '../habits/habit_schedule.dart';
import '../habits/habit_streak_calculator.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import '../routines/routine_controller.dart';
import '../routines/routine_models.dart';
import '../weather/weather_controller.dart';
import '../weather/weather_model.dart';

/// Kind of line rendered in **The Day Sheet** (`design/specs/18-widgets.md` §4).
enum DaySheetLineKind {
  event('event'),
  routine('routine'),
  task('task');

  final String wireValue;
  const DaySheetLineKind(this.wireValue);

  static DaySheetLineKind fromWire(String? raw) {
    switch (raw) {
      case 'routine':
        return DaySheetLineKind.routine;
      case 'task':
        return DaySheetLineKind.task;
      case 'event':
      default:
        return DaySheetLineKind.event;
    }
  }
}

/// A single scheduled line on **The Day Sheet** (`design/specs/18-widgets.md` §4).
///
/// Events and routines open in the app when tapped and have no "done" state.
/// Tasks due today tick when tapped (`WidgetTickKind.listItem`).
@immutable
class DaySheetLine {
  final String id;
  final DaySheetLineKind kind;
  final int startMinutes;
  final int endMinutes;
  final String timeLabel;
  final String title;
  final String subtitle;
  final bool isOver;
  final bool isCompleted;
  final String? listId;

  const DaySheetLine({
    required this.id,
    required this.kind,
    required this.startMinutes,
    required this.endMinutes,
    required this.timeLabel,
    required this.title,
    required this.subtitle,
    required this.isOver,
    this.isCompleted = false,
    this.listId,
  });

  bool get isTask => kind == DaySheetLineKind.task;

  bool get hasClockTime =>
      timeLabel.isNotEmpty && timeLabel != 'All day' && timeLabel != 'Today';

  String? get meridiemLabel {
    if (!hasClockTime) return null;
    return startMinutes < 720 ? 'AM' : 'PM';
  }

  DaySheetLine copyWith({
    bool? isOver,
    bool? isCompleted,
  }) {
    return DaySheetLine(
      id: id,
      kind: kind,
      startMinutes: startMinutes,
      endMinutes: endMinutes,
      timeLabel: timeLabel,
      title: title,
      subtitle: subtitle,
      isOver: isOver ?? this.isOver,
      isCompleted: isCompleted ?? this.isCompleted,
      listId: listId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.wireValue,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'timeLabel': timeLabel,
        'title': title,
        'subtitle': subtitle,
        'isOver': isOver,
        'isCompleted': isCompleted,
        if (listId != null) 'listId': listId,
      };

  factory DaySheetLine.fromJson(Map<String, dynamic> map) {
    return DaySheetLine(
      id: map['id'] as String? ?? '',
      kind: DaySheetLineKind.fromWire(map['kind'] as String?),
      startMinutes: (map['startMinutes'] as num?)?.toInt() ?? 0,
      endMinutes: (map['endMinutes'] as num?)?.toInt() ?? 60,
      timeLabel: map['timeLabel'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      isOver: map['isOver'] as bool? ?? false,
      isCompleted: map['isCompleted'] as bool? ?? false,
      listId: map['listId'] as String?,
    );
  }
}

/// A single habit dot in the base of **The Day Sheet** (`design/specs/18-widgets.md` §4).
///
/// Only the viewer's own habits (`isOwnedByViewer == true`) are tappable.
/// Partner habits (`isOwnedByViewer == false`) are drawn but not tappable.
@immutable
class DaySheetHabitDot {
  final String habitId;
  final String habitName;
  final bool isKeptToday;
  final bool isOwnedByViewer;

  const DaySheetHabitDot({
    required this.habitId,
    required this.habitName,
    required this.isKeptToday,
    required this.isOwnedByViewer,
  });

  DaySheetHabitDot copyWith({
    bool? isKeptToday,
  }) {
    return DaySheetHabitDot(
      habitId: habitId,
      habitName: habitName,
      isKeptToday: isKeptToday ?? this.isKeptToday,
      isOwnedByViewer: isOwnedByViewer,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'habitId': habitId,
        'habitName': habitName,
        'isKeptToday': isKeptToday,
        'isOwnedByViewer': isOwnedByViewer,
      };

  factory DaySheetHabitDot.fromJson(Map<String, dynamic> map) {
    return DaySheetHabitDot(
      habitId: map['habitId'] as String? ?? '',
      habitName: map['habitName'] as String? ?? '',
      isKeptToday: map['isKeptToday'] as bool? ?? false,
      isOwnedByViewer: map['isOwnedByViewer'] as bool? ?? true,
    );
  }
}

/// Computed state for **The Day Sheet** (`4×4`, `design/specs/18-widgets.md` §4).
@immutable
class DaySheetSummary {
  static const int maxVisibleLines = 4; // (literal) max lines rendered in 4x4 Day Sheet
  static const int maxVisibleHabitDots = 8; // (literal) max habit dots in base row

  final DateTime referenceDate;
  final int nowMinutes;
  final String dayNumber;
  final String monthName;
  final String weekdayCaps;
  final String? weatherLine;
  final String? firstHabitDueToday;
  final List<DaySheetLine> lines;
  final List<DaySheetHabitDot> habitDots;
  final double todaySpend;
  final CurrencyOption currency;
  final String checkinDateStr;

  const DaySheetSummary({
    required this.referenceDate,
    required this.nowMinutes,
    required this.dayNumber,
    required this.monthName,
    required this.weekdayCaps,
    required this.weatherLine,
    required this.firstHabitDueToday,
    required this.lines,
    required this.habitDots,
    required this.todaySpend,
    required this.currency,
    required this.checkinDateStr,
  });

  bool get isEmpty => lines.isEmpty;

  bool get hasBothMorningAndEveningLines {
    var hasMorning = false;
    var hasEvening = false;
    for (final line in lines) {
      final m = line.meridiemLabel;
      if (m == 'AM') hasMorning = true;
      if (m == 'PM') hasEvening = true;
      if (hasMorning && hasEvening) return true;
    }
    return false;
  }

  List<DaySheetLine> get visibleLines =>
      lines.take(maxVisibleLines).toList(growable: false);

  List<DaySheetLine> visibleLinesFor({int? maxLines}) =>
      lines.take(maxLines ?? maxVisibleLines).toList(growable: false);

  List<DaySheetHabitDot> get visibleHabitDots =>
      habitDots.take(maxVisibleHabitDots).toList(growable: false);

  /// Recomputes `isOver` on each line for a new clock time [now] (used during
  /// the 30-minute WorkManager background refresh without database access).
  DaySheetSummary atTime(DateTime now) {
    final minutes = (now.hour * 60 + now.minute).clamp(0, 1439);
    final updatedLines = lines.map((line) {
      if (line.isTask) {
        return line.copyWith(isOver: line.isCompleted);
      }
      return line.copyWith(isOver: line.endMinutes <= minutes);
    }).toList(growable: false);

    return DaySheetSummary(
      referenceDate: referenceDate,
      nowMinutes: minutes,
      dayNumber: dayNumber,
      monthName: monthName,
      weekdayCaps: weekdayCaps,
      weatherLine: weatherLine,
      firstHabitDueToday: firstHabitDueToday,
      lines: updatedLines,
      habitDots: habitDots,
      todaySpend: todaySpend,
      currency: currency,
      checkinDateStr: checkinDateStr,
    );
  }

  /// Applies an optimistic tick for either a task (`list_item`) or a viewer-owned
  /// habit (`habit_checkin`). Partner habits are never modified.
  DaySheetSummary withOptimisticTick({
    String? taskRecordId,
    bool? taskToDone,
    String? habitRecordId,
    bool? habitToDone,
  }) {
    var nextLines = lines;
    if (taskRecordId != null && taskToDone != null) {
      nextLines = lines.map((line) {
        if (line.isTask && line.id == taskRecordId) {
          return line.copyWith(
            isCompleted: taskToDone,
            isOver: taskToDone,
          );
        }
        return line;
      }).toList(growable: false);
    }

    var nextHabitDots = habitDots;
    var nextFirstHabit = firstHabitDueToday;
    if (habitRecordId != null && habitToDone != null) {
      nextHabitDots = habitDots.map((dot) {
        if (dot.habitId == habitRecordId && dot.isOwnedByViewer) {
          return dot.copyWith(isKeptToday: habitToDone);
        }
        return dot;
      }).toList(growable: false);
      nextFirstHabit = selectFirstHabitDueToday(nextHabitDots);
    }

    return DaySheetSummary(
      referenceDate: referenceDate,
      nowMinutes: nowMinutes,
      dayNumber: dayNumber,
      monthName: monthName,
      weekdayCaps: weekdayCaps,
      weatherLine: weatherLine,
      firstHabitDueToday: nextFirstHabit,
      lines: nextLines,
      habitDots: nextHabitDots,
      todaySpend: todaySpend,
      currency: currency,
      checkinDateStr: checkinDateStr,
    );
  }

  static String? selectFirstHabitDueToday(List<DaySheetHabitDot> dots) {
    if (dots.isEmpty) return null;
    for (final dot in dots) {
      if (!dot.isKeptToday && dot.habitName.trim().isNotEmpty) {
        return dot.habitName.trim();
      }
    }
    final first = dots.first.habitName.trim();
    return first.isEmpty ? null : first;
  }

  static String formatCompactClockTime(int minutes) {
    final m = minutes.clamp(0, 1439);
    final h24 = m ~/ 60;
    final min = m % 60;
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    final minStr = min.toString().padLeft(2, '0');
    return '$h12:$minStr';
  }

  /// Normalizes and sorts lines in chronological order by actual `startMinutes`.
  /// When a routine that starts before midnight (`startMinutes >= 18 * 60`) and
  /// runs past it also has a `startMinutes == 0` midnight-to-morning segment
  /// with the same title, coalesces them so the routine sits once at its
  /// pre-midnight start time (`endMinutes = 1440`).
  static List<DaySheetLine> normalizeAndSortLines(
    List<DaySheetLine> rawLines, {
    required int nowMinutes,
  }) {
    final preMidnightRoutineTitles = <String>{
      for (final l in rawLines)
        if (l.kind == DaySheetLineKind.routine && l.startMinutes >= 18 * 60)
          l.title.trim().toLowerCase(),
    };
    final result = <DaySheetLine>[];
    for (final l in rawLines) {
      final normTitle = l.title.trim().toLowerCase();
      if (l.kind == DaySheetLineKind.routine &&
          l.startMinutes == 0 &&
          preMidnightRoutineTitles.contains(normTitle)) {
        // Post-midnight continuation of a routine that started before midnight.
        continue;
      }
      if (l.kind == DaySheetLineKind.routine &&
          l.startMinutes >= 18 * 60 &&
          (l.endMinutes <= l.startMinutes + 1 ||
              rawLines.any(
                (other) =>
                    other.kind == DaySheetLineKind.routine &&
                    other.startMinutes == 0 &&
                    other.title.trim().toLowerCase() == normTitle,
              ))) {
        result.add(
          DaySheetLine(
            id: l.id,
            kind: l.kind,
            startMinutes: l.startMinutes,
            endMinutes: 1440,
            timeLabel: l.timeLabel,
            title: l.title,
            subtitle: l.subtitle,
            isOver: 1440 <= nowMinutes,
            isCompleted: l.isCompleted,
            listId: l.listId,
          ),
        );
      } else {
        result.add(l);
      }
    }
    result.sort((a, b) {
      final cmp = a.startMinutes.compareTo(b.startMinutes);
      if (cmp != 0) return cmp;
      return a.title.compareTo(b.title);
    });
    return result;
  }

  static String? formatWeatherLine(WeatherData? weather) {
    if (weather == null) return null;
    final temp = weather.temperatureC.round();
    final cond = weather.condition.trim().toLowerCase();
    if (cond.isEmpty) return '$temp°';
    return '$temp° · $cond';
  }

  static DaySheetSummary compute({
    required DateTime now,
    required List<LocalCalendarEvent> calendarEvents,
    required List<Routine> routines,
    required List<RoutineEvent> routineEvents,
    required List<LocalList> lists,
    required List<LocalListItem> listItems,
    required List<LocalHabit> habits,
    required List<LocalHabitCheckin> checkins,
    required List<LocalExpense> expenses,
    required String? currentUserId,
    required String myName,
    required String partnerName,
    required CurrencyOption currency,
    WeatherData? weather,
    String? weatherLineOverride,
    Set<String> optimisticallyCompletedTaskIds = const <String>{},
    Map<String, bool> optimisticHabitOverrides = const <String, bool>{},
  }) {
    final dayOnly = CalendarDateUtils.dateOnly(now);
    final nowMinutes = (now.hour * 60 + now.minute).clamp(0, 1439);
    final viewerId = currentUserId ?? 'local_user';
    final cleanPartner =
        partnerName.trim().isNotEmpty ? partnerName.trim() : 'Partner';

    final dayNumber = '${dayOnly.day}';
    final monthName = DateFormat('MMMM').format(dayOnly);
    final weekdayCaps = DateFormat('EEEE').format(dayOnly).toUpperCase();
    final weatherLine = weatherLineOverride ?? formatWeatherLine(weather);
    final todayDateStr = HabitStreakCalculator.formatDate(dayOnly);

    final lines = <DaySheetLine>[];

    // 1. Today's routines
    final matchingRoutineIds = <String>{
      for (final r in routines)
        if (r.days.contains(dayOnly.weekday)) r.id,
    };
    if (matchingRoutineIds.isNotEmpty) {
      final todayRoutineEvents = routineEvents
          .where((re) => matchingRoutineIds.contains(re.routineId))
          .toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      for (final re in todayRoutineEvents) {
        final start = re.startMinutes.clamp(0, 1439);
        final runsPastMidnight = re.endMinutes <= start;
        final end = runsPastMidnight
            ? 1440
            : re.endMinutes.clamp(start + 1, 1440);
        final note = re.notes?.trim();
        final subtitle = (note != null && note.isNotEmpty)
            ? note
            : 'Together · routine';
        lines.add(
          DaySheetLine(
            id: re.id,
            kind: DaySheetLineKind.routine,
            startMinutes: start,
            endMinutes: end,
            timeLabel: formatCompactClockTime(start),
            title: re.title,
            subtitle: subtitle,
            isOver: end <= nowMinutes,
          ),
        );
      }
    }

    // 2. Today's calendar events
    final projectedEvents = CalendarDateUtils.projectCalendarEvents(
      events: calendarEvents,
      startDate: dayOnly,
      endDate: dayOnly,
    );
    for (final entry in projectedEvents) {
      final raw = entry.event;
      final isAllDay = entry.isAllDay || raw.isAllDay;
      final int start;
      final int end;
      final String timeLabel;
      if (isAllDay) {
        start = 9 * 60;
        end = 24 * 60;
        timeLabel = 'All day';
      } else {
        final st = entry.startTime;
        final et = entry.endTime;
        start = (st.hour * 60 + st.minute).clamp(0, 1439);
        final rawEnd = et.hour * 60 + et.minute;
        end = (rawEnd > start ? rawEnd : start + 60).clamp(start + 1, 1440);
        timeLabel = formatCompactClockTime(start);
      }

      final createdBy = raw.createdBy;
      final String whoLabel;
      if (createdBy.isEmpty) {
        whoLabel = 'Together';
      } else if (createdBy == viewerId ||
          createdBy == 'me' ||
          createdBy == 'local_user') {
        whoLabel = 'Together';
      } else {
        whoLabel = cleanPartner;
      }

      final loc = raw.location?.trim();
      final desc = raw.description?.trim();
      final String subtitle;
      if (desc != null && desc.isNotEmpty) {
        subtitle = desc;
      } else if (loc != null && loc.isNotEmpty) {
        subtitle = '$whoLabel · $loc';
      } else {
        subtitle = whoLabel;
      }

      lines.add(
        DaySheetLine(
          id: raw.id,
          kind: DaySheetLineKind.event,
          startMinutes: start,
          endMinutes: end,
          timeLabel: timeLabel,
          title: entry.title,
          subtitle: subtitle,
          isOver: !isAllDay && end <= nowMinutes,
        ),
      );
    }

    // 3. Tasks due today
    final listNamesById = <String, String>{
      for (final l in lists)
        if (!l.isArchived) l.id: l.name,
    };
    for (final item in listItems) {
      if (item.dueDate == null) continue;
      if (!CalendarDateUtils.isSameDay(item.dueDate!, dayOnly)) continue;
      final isDone = item.isCompleted ||
          optimisticallyCompletedTaskIds.contains(item.id);
      final due = item.dueDate!;
      final hasExplicitTime = due.hour != 0 || due.minute != 0;
      final start = hasExplicitTime
          ? (due.hour * 60 + due.minute).clamp(0, 1439)
          : 12 * 60;
      final end = (start + 60).clamp(start + 1, 1440);
      final timeLabel =
          hasExplicitTime ? formatCompactClockTime(start) : 'Today';
      final listName = listNamesById[item.listId] ?? 'List';
      final createdByViewer = item.createdBy == viewerId ||
          item.createdBy == 'me' ||
          item.createdBy == 'local_user';
      final who = createdByViewer ? 'You' : cleanPartner;
      final notes = item.notes?.trim();
      final subtitle = (notes != null && notes.isNotEmpty)
          ? notes
          : '$who · $listName';

      lines.add(
        DaySheetLine(
          id: item.id,
          kind: DaySheetLineKind.task,
          startMinutes: start,
          endMinutes: end,
          timeLabel: timeLabel,
          title: item.title,
          subtitle: subtitle,
          isOver: isDone,
          isCompleted: isDone,
          listId: item.listId,
        ),
      );
    }

    final sortedLines = normalizeAndSortLines(
      lines,
      nowMinutes: nowMinutes,
    );

    // 4. Habits due today (never show another person's private habits)
    final visibleHabits = habits.where((h) {
      if (h.isArchived) return false;
      final isPrivate = h.targetDaysPerWeek < 0;
      if (isPrivate && h.createdBy != viewerId) {
        return false;
      }
      final sched = HabitSchedule.parse(
        h.cadence,
        targetDays: h.targetDaysPerWeek,
      );
      return sched.isDueOn(dayOnly);
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final keptHabitIdsToday = <String>{
      for (final c in checkins)
        if (c.checkinDate == todayDateStr) c.habitId,
    };

    final habitDots = <DaySheetHabitDot>[];
    for (final habit in visibleHabits) {
      final isOwned = habit.createdBy == viewerId ||
          habit.createdBy == 'me' ||
          habit.createdBy == 'local_user';
      var isKept = keptHabitIdsToday.contains(habit.id);
      if (isOwned && optimisticHabitOverrides.containsKey(habit.id)) {
        isKept = optimisticHabitOverrides[habit.id]!;
      }
      habitDots.add(
        DaySheetHabitDot(
          habitId: habit.id,
          habitName: habit.name,
          isKeptToday: isKept,
          isOwnedByViewer: isOwned,
        ),
      );
    }

    final firstHabitDueToday = selectFirstHabitDueToday(habitDots);

    // 5. Today's spend (non-transfer expenses on referenceDate, excluding any
    //    other person's private records).
    var todaySpend = 0.0;
    for (final exp in expenses) {
      if (exp.isTransfer) continue;
      if (!CalendarDateUtils.isSameDay(exp.expenseDate, dayOnly)) continue;
      if (exp.splitRatio < 0.0) {
        final isViewerPrivate = exp.paidBy == viewerId ||
            exp.paidBy == 'me' ||
            exp.paidBy == 'local_user';
        if (!isViewerPrivate) continue;
      }
      todaySpend += exp.amount;
    }

    return DaySheetSummary(
      referenceDate: dayOnly,
      nowMinutes: nowMinutes,
      dayNumber: dayNumber,
      monthName: monthName,
      weekdayCaps: weekdayCaps,
      weatherLine: weatherLine,
      firstHabitDueToday: firstHabitDueToday,
      lines: List<DaySheetLine>.unmodifiable(sortedLines),
      habitDots: habitDots,
      todaySpend: todaySpend,
      currency: currency,
      checkinDateStr: todayDateStr,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'referenceDate': referenceDate.toIso8601String(),
        'nowMinutes': nowMinutes,
        'dayNumber': dayNumber,
        'monthName': monthName,
        'weekdayCaps': weekdayCaps,
        if (weatherLine != null) 'weatherLine': weatherLine,
        if (firstHabitDueToday != null)
          'firstHabitDueToday': firstHabitDueToday,
        'lines': lines.map((l) => l.toJson()).toList(),
        'habitDots': habitDots.map((d) => d.toJson()).toList(),
        'todaySpend': todaySpend,
        'currencyCode': currency.code,
        'checkinDateStr': checkinDateStr,
      };

  factory DaySheetSummary.fromJson(Map<String, dynamic> map) {
    final referenceDate =
        DateTime.tryParse(map['referenceDate'] as String? ?? '') ??
            clock.now();
    final currencyCode = map['currencyCode'] as String? ?? 'INR';
    final currency = supportedCurrencies.firstWhere(
      (c) => c.code == currencyCode,
      orElse: () => supportedCurrencies.first,
    );
    final rawLines = map['lines'] as List<dynamic>? ?? const [];
    final rawDots = map['habitDots'] as List<dynamic>? ?? const [];
    final nowMinutes = (map['nowMinutes'] as num?)?.toInt() ?? 0;
    final parsedLines = normalizeAndSortLines(
      rawLines
          .whereType<Map<String, dynamic>>()
          .map(DaySheetLine.fromJson)
          .toList(),
      nowMinutes: nowMinutes,
    );
    return DaySheetSummary(
      referenceDate: referenceDate,
      nowMinutes: nowMinutes,
      dayNumber: map['dayNumber'] as String? ?? '${referenceDate.day}',
      monthName: map['monthName'] as String? ??
          DateFormat('MMMM').format(referenceDate),
      weekdayCaps: map['weekdayCaps'] as String? ??
          DateFormat('EEEE').format(referenceDate).toUpperCase(),
      weatherLine: map['weatherLine'] as String?,
      firstHabitDueToday: map['firstHabitDueToday'] as String?,
      lines: List<DaySheetLine>.unmodifiable(parsedLines),
      habitDots: rawDots
          .whereType<Map<String, dynamic>>()
          .map(DaySheetHabitDot.fromJson)
          .toList(growable: false),
      todaySpend: (map['todaySpend'] as num?)?.toDouble() ?? 0.0,
      currency: currency,
      checkinDateStr: map['checkinDateStr'] as String? ??
          HabitStreakCalculator.formatDate(referenceDate),
    );
  }
}

/// Optional reference-date override for deterministic Day Sheet tests & goldens.
final daySheetReferenceDateProvider = Provider<DateTime?>((ref) => null);

/// Computed provider for **The Day Sheet** (`design/specs/18-widgets.md` §4).
final daySheetSummaryProvider = Provider<DaySheetSummary>((ref) {
  final now = ref.watch(daySheetReferenceDateProvider) ?? clock.now();
  final calendarEvents =
      ref.watch(activeHomeCalendarEventsProvider).value ??
          const <LocalCalendarEvent>[];
  final routines =
      ref.watch(activeHomeRoutinesProvider).value ?? const <Routine>[];
  final routineEvents = ref.watch(activeHomeAllRoutineEventsProvider).value ??
      const <RoutineEvent>[];
  final lists =
      ref.watch(activeHomeListsProvider).value ?? const <LocalList>[];
  final listItems = ref.watch(activeHomeAllListItemsProvider).value ??
      const <LocalListItem>[];
  final habits =
      ref.watch(activeHomeHabitsProvider).value ?? const <LocalHabit>[];
  final checkins = ref.watch(activeHomeAllHabitCheckinsProvider).value ??
      const <LocalHabitCheckin>[];
  final expenses =
      ref.watch(activeHomeExpensesProvider).value ?? const <LocalExpense>[];
  final currentUser = ref.watch(authProvider).value;
  final userProfile = ref.watch(userProfileProvider);
  final partnerProfile = ref.watch(partnerProfileProvider);
  final currency = ref.watch(currencyPreferenceProvider);
  final weather = ref.watch(weatherProvider);

  return DaySheetSummary.compute(
    now: now,
    calendarEvents: calendarEvents,
    routines: routines,
    routineEvents: routineEvents,
    lists: lists,
    listItems: listItems,
    habits: habits,
    checkins: checkins,
    expenses: expenses,
    currentUserId: currentUser?.id,
    myName: userProfile.displayName,
    partnerName: partnerProfile.displayName,
    currency: currency,
    weather: weather,
  );
});

/// Provider-bound **Day Sheet** home-screen widget (`4×4`, `design/specs/18-widgets.md` §4).
class CoveDaySheetWidget extends ConsumerWidget {
  final VoidCallback? onOpenSheet;
  final void Function(DaySheetLine line)? onOpenLine;
  final void Function(DaySheetLine taskLine)? onTickTask;
  final void Function(DaySheetHabitDot habitDot)? onTickHabit;
  final VoidCallback? onOpenExpenses;

  const CoveDaySheetWidget({
    super.key,
    this.onOpenSheet,
    this.onOpenLine,
    this.onTickTask,
    this.onTickHabit,
    this.onOpenExpenses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(daySheetSummaryProvider);
    return CoveDaySheetCard(
      summary: summary,
      onOpenSheet: onOpenSheet,
      onOpenLine: onOpenLine,
      onTickTask: onTickTask,
      onTickHabit: onTickHabit,
      onOpenExpenses: onOpenExpenses,
    );
  }
}

/// Pure visual card for **The Day Sheet** (`4×4` home-screen widget, `design/specs/18-widgets.md` §4).
///
/// - **Masthead**: day number in Bodoni, month in italic, then weekday caps,
///   weather line, and the first habit due today.
/// - **Lines**: today's lines in time order (events, routines, tasks due today),
///   each with time, title, and a second line of who and context. Lines that are
///   over are dimmed.
/// - **Base**: `HABITS` with one dot per habit due today, and `TODAY` with
///   today's spend in Bodoni.
/// - **Taps**:
///   - Tap a task line -> ticks it ([onTickTask]).
///   - Tap a habit dot -> ticks today's check-in ([onTickHabit]), **only for
///     your own habits** (`dot.isOwnedByViewer == true`). Partner habit dots
///     are drawn but not tappable (`onTap: null`).
///   - Tap an event or routine line -> opens it in the app ([onOpenLine]).
class CoveDaySheetCard extends StatelessWidget {
  final DaySheetSummary summary;
  final VoidCallback? onOpenSheet;
  final void Function(DaySheetLine line)? onOpenLine;
  final void Function(DaySheetLine taskLine)? onTickTask;
  final void Function(DaySheetHabitDot habitDot)? onTickHabit;
  final VoidCallback? onOpenExpenses;

  static const double _kCardFillAlpha = 0.88; // (literal) 88% wallpaper card fill per 18-widgets.md
  static const double _kBorderWidth = 1.0; // (literal) 1dp hairline border
  static const double _kPadH = 22.0; // (literal) 22dp horizontal sheet padding
  static const double _kCompactPadH = 16.0; // (literal) 16dp horizontal padding on narrow resize
  static const double _kPadV = 18.0; // (literal) 18dp vertical sheet padding
  static const double _kCompactPadV = 12.0; // (literal) 12dp vertical padding on short resize
  static const double _kDayNumSize = 42.0; // (literal) 42sp Bodoni day numeral
  static const double _kMonthFontSize = 15.0; // (literal) 15sp italic month
  static const double _kMetaFontSize = 12.0; // (literal) 12sp weather/habit line
  static const double _kTimeColumnWidth = 54.0; // (literal) 54dp time column width
  static const double _kTimeColumnWithMeridiemWidth = 72.0; // (literal) 72dp time column width when AM/PM shown
  static const double _kTimeFontSize = 13.0; // (literal) 13sp Bodoni line time
  static const double _kMeridiemGap = 3.0; // (literal) 3dp gap between short time and AM/PM
  static const double _kLineTitleSize = 14.0; // (literal) 14sp line title
  static const double _kLineSubSize = 11.5; // (literal) 11.5sp line subtitle
  static const double _kDimmedTimeAlpha = 0.52; // (literal) dimmed time alpha when over
  static const double _kHabitDotSize = 10.0; // (literal) 10dp habit dot diameter
  static const double _kHabitDotGap = 6.0; // (literal) 6dp gap between habit dots
  static const double _kHabitDotStroke = 1.4; // (literal) 1.4dp outlined habit dot stroke
  static const double _kTodaySpendSize = 22.0; // (literal) 22sp Bodoni today spend
  static const double _kTaskCheckboxSize = 16.0; // (literal) 16dp task checkbox
  static const double _kTaskCheckboxRadius = 4.5; // (literal) 4.5dp task checkbox corner radius
  static const double _kTaskCheckIconSize = 11.0; // (literal) 11dp checkmark icon
  static const double _kTinyGap = 2.0; // (literal) 2dp tight vertical line gap
  static const double _kCompactWidthThreshold = 260.0; // (literal) 3-cell width threshold
  static const double _kSixLinesHeightThreshold = 520.0; // (literal) height threshold for 6 lines on tall stretch
  static const double _kFiveLinesHeightThreshold = 440.0; // (literal) height threshold for 5 lines on tall stretch
  static const double _kThreeLinesHeightThreshold = 340.0; // (literal) height threshold for 3 vs 4 lines
  static const double _kTwoLinesHeightThreshold = 290.0; // (literal) height threshold for 2 vs 3 lines
  static const double _kOneLineHeightThreshold = 240.0; // (literal) height threshold for 1 vs 2 lines

  const CoveDaySheetCard({
    super.key,
    required this.summary,
    this.onOpenSheet,
    this.onOpenLine,
    this.onTickTask,
    this.onTickHabit,
    this.onOpenExpenses,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final showMeridiem = summary.hasBothMorningAndEveningLines;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactWidth = constraints.maxWidth.isFinite &&
            constraints.maxWidth > 0 &&
            constraints.maxWidth < _kCompactWidthThreshold;
        final hasFiniteHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0;
        final maxLinesForHeight = !hasFiniteHeight
            ? DaySheetSummary.maxVisibleLines
            : (constraints.maxHeight < _kOneLineHeightThreshold
                ? 1
                : (constraints.maxHeight < _kTwoLinesHeightThreshold
                    ? 2
                    : (constraints.maxHeight < _kThreeLinesHeightThreshold
                        ? 3
                        : (constraints.maxHeight < _kFiveLinesHeightThreshold
                            ? DaySheetSummary.maxVisibleLines
                            : (constraints.maxHeight < _kSixLinesHeightThreshold
                                ? 5
                                : 6)))));
        final isShortHeight = hasFiniteHeight &&
            constraints.maxHeight < _kTwoLinesHeightThreshold;
        final visibleLines = summary.visibleLinesFor(
          maxLines: maxLinesForHeight,
        );

        return DefaultTextStyle.merge(
          style: const TextStyle(decoration: TextDecoration.none),
          child: Container(
            key: const ValueKey('cove_day_sheet_card'),
            width: double.infinity,
            height: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isCompactWidth ? _kCompactPadH : _kPadH,
              vertical: isShortHeight ? _kCompactPadV : _kPadV,
            ),
            decoration: CoveShape.decoration(
              CoveRadius.hero,
              color: cv.surfaceCard.withValues(alpha: _kCardFillAlpha),
              side: BorderSide(
                color: cv.lineStrong,
                width: _kBorderWidth,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Masthead
                GestureDetector(
                  key: const ValueKey('day_sheet_masthead'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpenSheet,
                  child: _buildMasthead(cv, isShortHeight: isShortHeight),
                ),
                SizedBox(
                  height: isShortHeight ? CoveSpace.sm : CoveSpace.md,
                ),
                Container(
                  height: _kBorderWidth,
                  color: cv.lineHairline,
                ),

                // 2. Today's lines in time order (or empty state)
                Expanded(
                  child: visibleLines.isEmpty
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onOpenSheet,
                          child: Center(
                            child: Text(
                              'Nothing booked today',
                              key: const ValueKey('day_sheet_empty_line'),
                              style: CoveType.slipTitle.copyWith(
                                fontSize: _kMonthFontSize,
                                fontStyle: FontStyle.italic,
                                color: cv.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < visibleLines.length; i++) ...[
                              Expanded(
                                child: _buildLineRow(
                                  cv,
                                  visibleLines[i],
                                  index: i,
                                  showMeridiem: showMeridiem,
                                ),
                              ),
                              if (i < visibleLines.length - 1)
                                Container(
                                  height: _kBorderWidth,
                                  color: cv.lineHairline,
                                ),
                            ],
                          ],
                        ),
                ),

                Container(
                  height: _kBorderWidth,
                  color: cv.lineHairline,
                ),
                SizedBox(
                  height: isShortHeight ? CoveSpace.sm : CoveSpace.md,
                ),

                // 3. Base: HABITS dots (left) and TODAY spend (right)
                _buildBaseRow(cv),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMasthead(CoveTokens cv, {bool isShortHeight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              summary.dayNumber,
              key: const ValueKey('day_sheet_day_number'),
              style: CoveType.heroFigure.copyWith(
                fontSize: _kDayNumSize,
                height: 0.95, // (literal) tight display line height
                color: cv.textPrimary,
              ),
            ),
            const SizedBox(height: CoveSpace.xs),
            Text(
              summary.monthName,
              key: const ValueKey('day_sheet_month_name'),
              style: CoveType.slipTitle.copyWith(
                fontSize: _kMonthFontSize,
                fontStyle: FontStyle.italic,
                color: cv.textSecondary,
                height: 1.15, // (literal) italic month line height
              ),
            ),
          ],
        ),
        const SizedBox(width: CoveSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                summary.weekdayCaps,
                key: const ValueKey('day_sheet_weekday_caps'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CoveType.capsCard.copyWith(
                  color: cv.textTertiary,
                ),
              ),
              if (summary.weatherLine != null &&
                  summary.weatherLine!.isNotEmpty) ...[
                const SizedBox(height: CoveSpace.xs),
                Text(
                  summary.weatherLine!,
                  key: const ValueKey('day_sheet_weather_line'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoveType.rowSub.copyWith(
                    fontSize: _kMetaFontSize,
                    color: cv.textSecondary,
                  ),
                ),
              ],
              if (!isShortHeight &&
                  summary.firstHabitDueToday != null &&
                  summary.firstHabitDueToday!.isNotEmpty) ...[
                const SizedBox(height: _kTinyGap),
                Text(
                  summary.firstHabitDueToday!,
                  key: const ValueKey('day_sheet_first_habit_line'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: CoveType.rowSub.copyWith(
                    fontSize: _kMetaFontSize,
                    color: cv.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLineRow(
    CoveTokens cv,
    DaySheetLine line, {
    required int index,
    required bool showMeridiem,
  }) {
    final isDimmed = line.isOver;
    final timeColor = isDimmed
        ? cv.accentText.withValues(alpha: _kDimmedTimeAlpha)
        : cv.accentText;
    final VoidCallback? onTap = line.isTask
        ? (onTickTask != null ? () => onTickTask!(line) : null)
        : (onOpenLine != null ? () => onOpenLine!(line) : onOpenSheet);
    final meridiem = showMeridiem ? line.meridiemLabel : null;

    return GestureDetector(
      key: ValueKey('day_sheet_line_${line.kind.wireValue}_${line.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: showMeridiem
                ? _kTimeColumnWithMeridiemWidth
                : _kTimeColumnWidth,
            child: meridiem != null
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          line.timeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CoveType.slipTitle.copyWith(
                            fontStyle: FontStyle.normal,
                            fontSize: _kTimeFontSize,
                            color: timeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: _kMeridiemGap),
                      Text(
                        meridiem,
                        maxLines: 1,
                        style: CoveType.capsCard.copyWith(
                          color: timeColor,
                        ),
                      ),
                    ],
                  )
                : Text(
                    line.timeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoveType.slipTitle.copyWith(
                      fontStyle: FontStyle.normal,
                      fontSize: _kTimeFontSize,
                      color: timeColor,
                    ),
                  ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  line.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoveType.rowTitle.copyWith(
                    fontSize: _kLineTitleSize,
                    color: isDimmed ? cv.textSecondary : cv.textPrimary,
                    decoration:
                        line.isCompleted ? TextDecoration.lineThrough : null,
                    height: 1.15, // (literal) compact row title height
                  ),
                ),
                const SizedBox(height: _kTinyGap),
                Text(
                  line.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoveType.rowSub.copyWith(
                    fontSize: _kLineSubSize,
                    color: cv.textTertiary,
                    height: 1.15, // (literal) compact row subtitle height
                  ),
                ),
              ],
            ),
          ),
          if (line.isTask) ...[
            const SizedBox(width: CoveSpace.sm),
            _buildTaskCheckbox(cv, isCompleted: line.isCompleted),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskCheckbox(CoveTokens cv, {required bool isCompleted}) {
    return Container(
      width: _kTaskCheckboxSize,
      height: _kTaskCheckboxSize,
      decoration: CoveShape.decoration(
        _kTaskCheckboxRadius,
        color: isCompleted ? cv.accentFill : Colors.transparent,
        side: BorderSide(
          color: isCompleted ? cv.accentFill : cv.lineStrong,
          width: _kHabitDotStroke,
        ),
      ),
      child: isCompleted
          ? Icon(
              Icons.check,
              size: _kTaskCheckIconSize,
              color: cv.textOnAccent,
            )
          : null,
    );
  }

  Widget _buildBaseRow(CoveTokens cv) {
    final visibleDots = summary.visibleHabitDots;
    final hasSpend = summary.todaySpend > 0;
    final spendText = hasSpend
        ? '${summary.currency.symbol}${formatCoveAmount(summary.todaySpend)}'
        : '—';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Left: HABITS + dots
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HABITS',
                style: CoveType.capsCard.copyWith(
                  color: cv.textTertiary,
                ),
              ),
              const SizedBox(height: CoveSpace.sm),
              if (visibleDots.isEmpty)
                Text(
                  '—',
                  key: const ValueKey('day_sheet_habits_empty'),
                  style: CoveType.rowSub.copyWith(
                    color: cv.textTertiary,
                  ),
                )
              else
                Wrap(
                  spacing: _kHabitDotGap,
                  runSpacing: _kHabitDotGap,
                  children: [
                    for (final dot in visibleDots)
                      _buildHabitDot(cv, dot),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(width: CoveSpace.md),

        // Right: TODAY + today's spend in Bodoni
        GestureDetector(
          key: const ValueKey('day_sheet_today_spend_tap'),
          behavior: HitTestBehavior.opaque,
          onTap: onOpenExpenses ?? onOpenSheet,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TODAY',
                style: CoveType.capsCard.copyWith(
                  color: cv.textTertiary,
                ),
              ),
              const SizedBox(height: _kTinyGap),
              Text(
                spendText,
                key: const ValueKey('day_sheet_today_spend_amount'),
                style: CoveType.slipTitle.copyWith(
                  fontSize: _kTodaySpendSize,
                  height: 1.05, // (literal) tight figure line height
                  color: hasSpend ? cv.accentText : cv.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHabitDot(CoveTokens cv, DaySheetHabitDot dot) {
    // Partner habit dots are drawn but NEVER tappable (`design/specs/18-widgets.md` §4).
    final VoidCallback? onTap =
        (dot.isOwnedByViewer && onTickHabit != null)
            ? () => onTickHabit!(dot)
            : null;

    return GestureDetector(
      key: ValueKey('day_sheet_habit_dot_${dot.habitId}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: _kHabitDotSize,
        height: _kHabitDotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: dot.isKeptToday ? cv.accentFill : Colors.transparent,
          border: Border.all(
            color: dot.isKeptToday ? cv.accentFill : cv.textTertiary,
            width: _kHabitDotStroke,
          ),
        ),
      ),
    );
  }
}
