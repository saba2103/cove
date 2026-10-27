import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../reminders/reminder_controller.dart';
import '../routines/routine_controller.dart';
import 'calendar_models.dart';

class CalendarWindow {
  final DateTime startDate;
  final DateTime endDate;

  const CalendarWindow({
    required this.startDate,
    required this.endDate,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarWindow &&
          runtimeType == other.runtimeType &&
          CalendarDateUtils.isSameDay(startDate, other.startDate) &&
          CalendarDateUtils.isSameDay(endDate, other.endDate);

  @override
  int get hashCode =>
      CalendarDateUtils.dateOnly(startDate).hashCode ^
      CalendarDateUtils.dateOnly(endDate).hashCode;
}

/// Unified provider that watches all 5 layers and projects them into a dated map.
final unifiedCalendarEntriesProvider =
    Provider.family<Map<DateTime, List<CalendarEntry>>, CalendarWindow>((ref, window) {
  final events = ref.watch(activeHomeCalendarEventsProvider).value ?? [];
  final subscriptions = ref.watch(activeHomeSubscriptionsProvider).value ?? [];
  final expenses = ref.watch(activeHomeExpensesProvider).value ?? [];
  final habits = ref.watch(activeHomeHabitsProvider).value ?? [];
  final checkins = ref.watch(activeHomeAllHabitCheckinsProvider).value ?? [];
  final lists = ref.watch(activeHomeListsProvider).value ?? [];
  final listItems = ref.watch(activeHomeAllListItemsProvider).value ?? [];
  final routines = ref.watch(activeHomeRoutinesProvider).value ?? [];
  final routineEvents = ref.watch(activeHomeAllRoutineEventsProvider).value ?? [];
  final reminders = ref.watch(checkinRemindersProvider);
  final partnerName = ref.watch(partnerProfileProvider).displayName;
  final currentUserId = ref.watch(authProvider).value?.id ?? 'local_user';

  final listNamesMap = {for (final l in lists) l.id: l.name};

  final projectedEvents = CalendarDateUtils.projectCalendarEvents(
    events: events,
    startDate: window.startDate,
    endDate: window.endDate,
  );

  final projectedSubs = CalendarDateUtils.projectSubscriptions(
    subscriptions: subscriptions,
    startDate: window.startDate,
    endDate: window.endDate,
  );

  final projectedExpenses = CalendarDateUtils.projectExpenses(
    expenses: expenses,
    startDate: window.startDate,
    endDate: window.endDate,
    currentUserId: currentUserId,
    partnerName: partnerName,
  );

  final projectedHabits = CalendarDateUtils.projectHabits(
    habits: habits,
    checkins: checkins,
    currentUserId: currentUserId,
    startDate: window.startDate,
    endDate: window.endDate,
  );

  final projectedTasks = CalendarDateUtils.projectTasks(
    items: listItems,
    listNames: listNamesMap,
    startDate: window.startDate,
    endDate: window.endDate,
  );

  final projectedRoutines = CalendarDateUtils.projectRoutines(
    routines: routines,
    routineEvents: routineEvents,
    startDate: window.startDate,
    endDate: window.endDate,
  );

  final projectedReminders = CalendarDateUtils.projectReminders(
    reminders: reminders,
    startDate: window.startDate,
    endDate: window.endDate,
  );

  final all = <CalendarEntry>[
    ...projectedEvents,
    ...projectedSubs,
    ...projectedExpenses,
    ...projectedHabits,
    ...projectedTasks,
    ...projectedRoutines,
    ...projectedReminders,
  ];

  final Map<DateTime, List<CalendarEntry>> map = {};
  for (final entry in all) {
    final d = CalendarDateUtils.dateOnly(entry.date);
    map.putIfAbsent(d, () => []).add(entry);
  }

  for (final list in map.values) {
    list.sort((a, b) {
      if (a.isAllDay && !b.isAllDay) return -1;
      if (!a.isAllDay && b.isAllDay) return 1;
      final timeComp = a.startTime.compareTo(b.startTime);
      if (timeComp != 0) return timeComp;
      return a.title.compareTo(b.title);
    });
  }

  return map;
});

class CalendarController {
  final Ref ref;

  CalendarController(this.ref);

  String? get _activeHomeId => ref.read(activeHomeIdProvider);
  CoveUser? get _currentUser => ref.read(authProvider).value;

  String _generateUuid() {
    final random = clock.now().microsecondsSinceEpoch.toString();
    final hash = (random.hashCode & 0x7FFFFFFF).toRadixString(16).padLeft(8, '0');
    final p1 = (clock.now().millisecondsSinceEpoch & 0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    return '$p1-$hash-4000-8000-${clock.now().microsecond.toRadixString(16).padLeft(12, '0')}';
  }

  /// Creates a calendar event and emits `calendar_event_added`.
  Future<String> createEvent({
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    String? location,
    String? recurrence,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final user = _currentUser;
    final userId = user?.id ?? 'local_user';
    final id = _generateUuid();

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'calendar_event_added',
      payload: {
        'id': id,
        'home_id': homeId,
        'title': title,
        'description': description,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'is_all_day': isAllDay,
        'location': location,
        'created_by': userId,
        'recurrence': recurrence,
      },
    );

    return id;
  }

  /// Updates an existing calendar event and emits `calendar_event_updated`.
  Future<void> updateEvent({
    required String id,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    String? location,
    String? recurrence,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'calendar_event_updated',
      payload: {
        'id': id,
        'home_id': homeId,
        'title': title,
        'description': description,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'is_all_day': isAllDay,
        'location': location,
        'recurrence': recurrence,
      },
    );
  }

  /// Deletes a calendar event and emits `calendar_event_deleted`.
  Future<void> deleteEvent(String id) async {
    final db = ref.read(appDatabaseProvider);
    LocalCalendarEvent? event;
    try {
      event = await (db.select(db.localCalendarEvents)..where((t) => t.id.equals(id))).getSingleOrNull();
    } catch (_) {}

    final homeId = _activeHomeId ?? event?.homeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'calendar_event_deleted',
      targetHomeId: homeId,
      payload: {
        'id': id,
        'home_id': homeId,
        if (event != null) 'title': event.title,
      },
    );
  }
}

final calendarControllerProvider = Provider<CalendarController>((ref) {
  return CalendarController(ref);
});
