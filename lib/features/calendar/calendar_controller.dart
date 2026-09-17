import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';

class CalendarController {
  final Ref ref;

  CalendarController(this.ref);

  String? get _activeHomeId => ref.read(activeHomeIdProvider);
  CoveUser? get _currentUser => ref.read(authProvider).value;

  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = (random.hashCode & 0x7FFFFFFF).toRadixString(16).padLeft(8, '0');
    final p1 = (DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    return '$p1-$hash-4000-8000-${DateTime.now().microsecond.toRadixString(16).padLeft(12, '0')}';
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
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final db = ref.read(appDatabaseProvider);
    final event = await (db.select(db.localCalendarEvents)..where((t) => t.id.equals(id))).getSingleOrNull();

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'calendar_event_deleted',
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
