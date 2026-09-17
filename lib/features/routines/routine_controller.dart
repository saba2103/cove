import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/uuid_generator.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import 'routine_models.dart';

final activeHomeRoutinesProvider = StreamProvider<List<Routine>>((ref) {
  final homeId = ref.watch(activeHomeIdProvider);
  if (homeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchRoutines(homeId).map((list) => list.map(Routine.fromLocal).toList());
});

class SelectedRoutineNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? id) => state = id;
}

final selectedRoutineIdProvider =
    NotifierProvider<SelectedRoutineNotifier, String?>(SelectedRoutineNotifier.new);

final routineEventsProvider = StreamProvider.family<List<RoutineEvent>, String>((ref, routineId) {
  if (routineId.isEmpty) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchRoutineEvents(routineId).map((list) => list.map(RoutineEvent.fromLocal).toList());
});

final routineControllerProvider = Provider<RoutineController>((ref) => RoutineController(ref));

class RoutineController {
  final Ref ref;

  RoutineController(this.ref);

  String? get _activeHomeId => ref.read(activeHomeIdProvider);
  CoveUser? get _currentUser => ref.read(authProvider).value;

  String _generateUuid() => generateCoveUuid();

  Future<void> seedDefaultRoutinesIfEmpty() async {
    final homeId = _activeHomeId;
    if (homeId == null) return;
    final db = ref.read(appDatabaseProvider);
    final existing = await db.getRoutines(homeId);
    if (existing.isNotEmpty) return;

    // Seed default routines: Weekday, Saturday, Sunday
    await createRoutine(
      name: 'Weekday (Mon – Fri)',
      days: [1, 2, 3, 4, 5],
    );
    await createRoutine(
      name: 'Saturday',
      days: [6],
    );
    await createRoutine(
      name: 'Sunday',
      days: [7],
    );
  }

  Future<String> createRoutine({
    required String name,
    required List<int> days,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final user = _currentUser;
    final userId = user?.id ?? 'local_user';
    final id = _generateUuid();
    final sortedDays = List<int>.from(days)..sort();

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'routine_created',
      payload: {
        'id': id,
        'home_id': homeId,
        'name': name.trim(),
        'days_json': jsonEncode(sortedDays),
        'created_by': userId,
      },
    );

    return id;
  }

  Future<void> updateRoutine({
    required String id,
    required String name,
    required List<int> days,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final sortedDays = List<int>.from(days)..sort();
    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'routine_updated',
      payload: {
        'id': id,
        'home_id': homeId,
        'name': name.trim(),
        'days_json': jsonEncode(sortedDays),
      },
    );
  }

  Future<void> deleteRoutine(String id) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'routine_deleted',
      payload: {
        'id': id,
        'home_id': homeId,
      },
    );
  }

  Future<String> createRoutineEvent({
    required String routineId,
    required String title,
    required int startMinutes,
    required int endMinutes,
    String? category,
    String? notes,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final user = _currentUser;
    final userId = user?.id ?? 'local_user';
    final id = _generateUuid();

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'routine_event_created',
      payload: {
        'id': id,
        'routine_id': routineId,
        'home_id': homeId,
        'title': title.trim(),
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
        'category': category?.trim(),
        'notes': notes?.trim(),
        'created_by': userId,
      },
    );

    return id;
  }

  Future<void> updateRoutineEvent({
    required String id,
    required String routineId,
    required String title,
    required int startMinutes,
    required int endMinutes,
    String? category,
    String? notes,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'routine_event_updated',
      payload: {
        'id': id,
        'routine_id': routineId,
        'home_id': homeId,
        'title': title.trim(),
        'start_minutes': startMinutes,
        'end_minutes': endMinutes,
        'category': category?.trim(),
        'notes': notes?.trim(),
      },
    );
  }

  Future<void> deleteRoutineEvent(String id) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'routine_event_deleted',
      payload: {
        'id': id,
        'home_id': homeId,
      },
    );
  }
}
