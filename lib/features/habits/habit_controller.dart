import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/uuid_generator.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import 'habit_streak_calculator.dart';

enum HabitVisibility {
  shared,
  privateToMe,
}

class HabitController {
  final Ref ref;

  HabitController(this.ref);

  AppDatabase get _db => ref.read(appDatabaseProvider);
  String? get _activeHomeId => ref.read(activeHomeIdProvider);
  CoveUser? get _currentUser => ref.read(authProvider).value;

  /// Creates a new habit.
  ///
  /// CRITICAL PRIVACY ARCHITECTURE:
  /// - [HabitVisibility.shared]:
  ///   Emits `habit_created` through [coveEmitActionProvider], end-to-end encrypted with the Home key.
  /// - [HabitVisibility.privateToMe]:
  ///   Writes DIRECTLY to local SQLite with negative targetDaysPerWeek.
  ///   NEVER emitted to sync engine, NEVER encrypted with the Home key.
  ///   The partner's device receives 0 bytes.
  Future<String> createHabit({
    required String name,
    String cadence = 'daily', // 'daily' | 'weekly' | 'custom'
    int targetDaysPerWeek = 7,
    HabitVisibility visibility = HabitVisibility.shared,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final user = _currentUser;
    final userId = user?.id ?? 'local_user';
    final now = DateTime.now().toUtc();
    final id = _generateUuid();

    final isPrivate = visibility == HabitVisibility.privateToMe;
    final effectiveTarget = isPrivate ? -targetDaysPerWeek.abs() : targetDaysPerWeek.abs();

    if (isPrivate) {
      // Direct local SQLite write ONLY - zero cloud or sync knowledge!
      await _db.into(_db.localHabits).insertOnConflictUpdate(
            LocalHabitsCompanion.insert(
              id: id,
              homeId: homeId,
              name: name.trim(),
              cadence: Value(cadence),
              targetDaysPerWeek: Value(effectiveTarget),
              isArchived: const Value(false),
              createdAt: now,
              createdBy: userId,
            ),
          );
      await _db.recordActivityEvent(
        LocalActivityEventsCompanion.insert(
          id: 'habit_created_${id}_${now.millisecondsSinceEpoch}',
          homeId: homeId,
          actorId: userId,
          eventType: 'habit_created',
          payloadJson: jsonEncode({
            'id': id,
            'home_id': homeId,
            'name': name.trim(),
            'cadence': cadence,
            'target_days_per_week': targetDaysPerWeek,
            'is_private': true,
            'created_by': userId,
            'created_at': now.toIso8601String(),
          }),
          createdAt: now,
          syncStatus: const Value('savedLocally'),
          isPrivate: const Value(true),
        ),
      );
      return id;
    }

    // Shared habit: Emit through sync engine
    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'habit_created',
      payload: {
        'id': id,
        'home_id': homeId,
        'name': name.trim(),
        'cadence': cadence,
        'target_days_per_week': targetDaysPerWeek,
        'is_private': false,
        'created_by': userId,
        'created_at': now.toIso8601String(),
      },
    );

    return id;
  }

  /// Toggles a habit check-in for a specific date (defaults to today).
  ///
  /// STRICT ACTOR ENFORCEMENT:
  /// A user can ONLY emit check-in events for habits they own (`habit.createdBy == currentUser.id`).
  Future<void> toggleCheckin({
    required LocalHabit habit,
    DateTime? date,
    required bool checked,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final user = _currentUser;
    final userId = user?.id ?? 'local_user';

    // Strict actor check in controller:
    if (habit.createdBy != userId) {
      throw StateError(
          'Actor violation: You can only check in for your own habits.');
    }

    final targetDate = date ?? DateTime.now();
    final checkinDateStr = HabitStreakCalculator.formatDate(targetDate);
    final now = DateTime.now().toUtc();
    final isPrivate = habit.targetDaysPerWeek < 0;

    if (isPrivate) {
      // Local SQLite only
      final checkinId = '${habit.id}-$checkinDateStr-$userId';
      if (checked) {
        await _db.into(_db.localHabitCheckins).insertOnConflictUpdate(
              LocalHabitCheckinsCompanion.insert(
                id: checkinId,
                homeId: homeId,
                habitId: habit.id,
                checkinDate: checkinDateStr,
                memberId: userId,
                createdAt: now,
              ),
            );
      } else {
        await (_db.delete(_db.localHabitCheckins)
              ..where((t) =>
                  t.habitId.equals(habit.id) &
                  t.checkinDate.equals(checkinDateStr) &
                  t.memberId.equals(userId)))
            .go();
      }
      return;
    }

    // Shared habit: Emit via sync engine
    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'habit_checkin_toggled',
      payload: {
        'habit_id': habit.id,
        'habit_name': habit.name,
        'name': habit.name,
        'title': habit.name,
        'checkin_date': checkinDateStr,
        'checked': checked,
        'home_id': homeId,
      },
    );
  }

  /// Leaves a quiet acknowledgment tap on a partner's completed check-in.
  Future<void> acknowledgeCheckin({
    required LocalHabit habit,
    DateTime? date,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final user = _currentUser;
    final userId = user?.id ?? 'local_user';
    final targetDate = date ?? DateTime.now();
    final checkinDateStr = HabitStreakCalculator.formatDate(targetDate);

    // Cannot acknowledge a private habit (since it's only on device)
    if (habit.targetDaysPerWeek < 0) return;

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'habit_checkin_acknowledged',
      payload: {
        'habit_id': habit.id,
        'habit_name': habit.name,
        'name': habit.name,
        'title': habit.name,
        'checkin_date': checkinDateStr,
        'owner_id': habit.createdBy,
        'actor_id': userId,
        'home_id': homeId,
      },
    );
  }

  /// Updates an existing habit.
  Future<void> updateHabit({
    required LocalHabit habit,
    required String name,
    required String cadence,
    required int targetDaysPerWeek,
    required HabitVisibility visibility,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final isPrivate = visibility == HabitVisibility.privateToMe;
    final effectiveTarget = isPrivate ? -targetDaysPerWeek.abs() : targetDaysPerWeek.abs();

    if (isPrivate) {
      await (_db.update(_db.localHabits)..where((t) => t.id.equals(habit.id))).write(
        LocalHabitsCompanion(
          name: Value(name.trim()),
          cadence: Value(cadence),
          targetDaysPerWeek: Value(effectiveTarget),
        ),
      );
      return;
    }

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'habit_updated',
      payload: {
        'id': habit.id,
        'home_id': habit.homeId,
        'name': name.trim(),
        'title': name.trim(),
        'cadence': cadence,
        'target_days_per_week': targetDaysPerWeek,
        'is_private': false,
      },
    );
  }

  /// Deletes or archives a habit.
  Future<void> deleteHabit(LocalHabit habit) async {
    final isPrivate = habit.targetDaysPerWeek < 0;

    if (isPrivate) {
      await _db.deleteHabit(habit.id);
      return;
    }

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'habit_deleted',
      payload: {
        'id': habit.id,
        'habit_id': habit.id,
        'home_id': habit.homeId,
        'name': habit.name,
        'title': habit.name,
      },
    );
  }

  String _generateUuid() => generateCoveUuid();
}

final habitControllerProvider = Provider<HabitController>((ref) {
  return HabitController(ref);
});
