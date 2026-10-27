import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/calendar/calendar_controller.dart';
import '../features/expenses/expense_controller.dart';
import '../features/habits/habit_controller.dart';
import '../features/lists/list_controller.dart';
import '../features/routines/routine_controller.dart';
import '../features/subscriptions/subscription_controller.dart';
import 'db/app_database.dart';
import 'providers/active_home_provider.dart';
import 'providers/cove_sync_providers.dart';

/// Entity kinds supported by [PendingDeleteService].
enum PendingDeleteKind {
  expense('expense'),
  listItem('list_item'),
  habit('habit'),
  event('event'),
  commitment('commitment'),
  routineEvent('routine_event');

  final String wireValue;
  const PendingDeleteKind(this.wireValue);

  static PendingDeleteKind? fromWire(String? raw) {
    for (final kind in PendingDeleteKind.values) {
      if (kind.wireValue == raw || kind.name == raw) {
        return kind;
      }
    }
    return null;
  }
}

/// Durable pending-delete record persisted in `SharedPreferences` as
/// `{kind, id, at}`.
@immutable
class PendingDeleteRecord {
  final PendingDeleteKind kind;
  final String id;
  final DateTime at;

  const PendingDeleteRecord({
    required this.kind,
    required this.id,
    required this.at,
  });

  String get compositeKey => '${kind.wireValue}:$id';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind.wireValue,
        'id': id,
        'at': at.toUtc().toIso8601String(),
      };

  static PendingDeleteRecord? fromJson(Map<String, dynamic> json) {
    final kind = PendingDeleteKind.fromWire(json['kind'] as String?);
    final id = json['id'] as String?;
    final atRaw = json['at'];
    if (kind == null || id == null || id.isEmpty) return null;

    DateTime? parsedAt;
    if (atRaw is String) {
      parsedAt = DateTime.tryParse(atRaw)?.toUtc();
    } else if (atRaw is int) {
      parsedAt = DateTime.fromMillisecondsSinceEpoch(atRaw, isUtc: true);
    }
    if (parsedAt == null) return null;

    return PendingDeleteRecord(
      kind: kind,
      id: id,
      at: parsedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingDeleteRecord &&
          runtimeType == other.runtimeType &&
          kind == other.kind &&
          id == other.id &&
          at == other.at;

  @override
  int get hashCode => Object.hash(kind, id, at);
}

/// Reactive state of active pending deletes so stream/list providers can filter
/// hidden records immediately without any database write.
class PendingDeleteStateNotifier extends Notifier<List<PendingDeleteRecord>> {
  @override
  List<PendingDeleteRecord> build() => const <PendingDeleteRecord>[];

  void setAll(List<PendingDeleteRecord> records) {
    state = List<PendingDeleteRecord>.unmodifiable(records);
  }

  void upsert(PendingDeleteRecord record) {
    final next = <PendingDeleteRecord>[
      for (final existing in state)
        if (existing.compositeKey != record.compositeKey) existing,
      record,
    ];
    state = List<PendingDeleteRecord>.unmodifiable(next);
  }

  void remove(PendingDeleteKind kind, String id) {
    final targetKey = '${kind.wireValue}:$id';
    if (!state.any((r) => r.compositeKey == targetKey)) return;
    state = List<PendingDeleteRecord>.unmodifiable(
      state.where((r) => r.compositeKey != targetKey),
    );
  }
}

final pendingDeleteRecordsProvider =
    NotifierProvider<PendingDeleteStateNotifier, List<PendingDeleteRecord>>(
  PendingDeleteStateNotifier.new,
);

/// Exposes the set of currently hidden record IDs for a given [PendingDeleteKind].
final pendingDeleteIdsProvider =
    Provider.family<Set<String>, PendingDeleteKind>((ref, kind) {
  final records = ref.watch(pendingDeleteRecordsProvider);
  if (records.isEmpty) return const <String>{};
  final ids = <String>{
    for (final r in records)
      if (r.kind == kind) r.id,
  };
  return ids;
});

/// Filters a list stream by [pendingDeleteIdsProvider] for [kind] without
/// invalidating the enclosing [StreamProvider] (avoiding `AsyncLoading` flashes
/// or tearing down the underlying Drift stream when a delete is scheduled or
/// undone).
Stream<List<T>> watchWithoutPendingDeletes<T>({
  required Ref ref,
  required PendingDeleteKind kind,
  required Stream<List<T>> source,
  required String Function(T item) idOf,
}) {
  List<T>? latestItems;
  var hasLatest = false;
  late final StreamController<List<T>> controller;
  StreamSubscription<List<T>>? sub;

  List<T> filterItems(List<T> items, Set<String> pendingIds) {
    if (pendingIds.isEmpty) return items;
    return items
        .where((item) => !pendingIds.contains(idOf(item)))
        .toList(growable: false);
  }

  controller = StreamController<List<T>>(
    sync: true,
    onListen: () {
      sub = source.listen(
        (items) {
          latestItems = items;
          hasLatest = true;
          if (!controller.isClosed) {
            final pendingIds = ref.read(pendingDeleteIdsProvider(kind));
            controller.add(filterItems(items, pendingIds));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
        onDone: () {
          if (!controller.isClosed) {
            controller.close();
          }
        },
      );
    },
    onPause: () {
      sub?.pause();
    },
    onResume: () {
      sub?.resume();
      if (hasLatest && !controller.isClosed) {
        final pendingIds = ref.read(pendingDeleteIdsProvider(kind));
        controller.add(filterItems(latestItems as List<T>, pendingIds));
      }
    },
    onCancel: () async {
      await sub?.cancel();
      sub = null;
    },
  );

  ref.listen<Set<String>>(
    pendingDeleteIdsProvider(kind),
    (previous, next) {
      if (hasLatest && !controller.isClosed) {
        controller.add(filterItems(latestItems as List<T>, next));
      }
    },
  );

  ref.onDispose(() {
    sub?.cancel();
    sub = null;
    if (!controller.isClosed) {
      controller.close();
    }
  });

  return controller.stream;
}

/// Overrides whether the current container is running in a background isolate.
/// Background isolates never schedule or emit deletes.
final isBackgroundIsolateProvider = Provider<bool>((ref) => false);

final pendingDeleteServiceProvider = Provider<PendingDeleteService>((ref) {
  final isBg = ref.watch(isBackgroundIsolateProvider);
  final service = PendingDeleteService(
    ref,
    isBackgroundIsolate: isBg,
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Coordinates deferred Delete-with-Undo across all 6 undoable entity kinds:
/// expenses, list items, habits, calendar events, commitments, and routine events.
///
/// Contract:
/// 1. [scheduleDelete] hides the record locally at once via [pendingDeleteRecordsProvider]
///    (no database write) and records `{kind, id, at}` in `SharedPreferences`.
/// 2. [undoDelete] removes the pending delete and cancels its timer; the record
///    reappears unchanged with its original ID and zero sync events emitted.
/// 3. When the toast duration expires, [commitDelete] emits the real delete
///    through the existing feature controller.
/// 4. On app start, [flushExpiredOnAppStart] emits any pending delete older
///    than the toast duration.
/// 5. Background isolates never emit deletes.
class PendingDeleteService {
  static const String prefKey = 'cove_pending_deletes_v1';
  static const Duration defaultToastDuration = Duration(seconds: 5);

  static bool _processMarkedBackgroundIsolate = false;

  /// Marks the current Dart isolate as a background isolate so no instance of
  /// [PendingDeleteService] ever emits deletes in this isolate.
  static void markAsBackgroundIsolate([bool value = true]) {
    _processMarkedBackgroundIsolate = value;
  }

  @visibleForTesting
  static void resetBackgroundIsolateMarkForTest() {
    _processMarkedBackgroundIsolate = false;
  }

  final Ref ref;
  final SharedPreferences? _prefsOverride;
  final bool isBackgroundIsolate;

  final Map<String, Timer> _timers = <String, Timer>{};
  final Set<String> _committingKeys = <String>{};
  final Map<String, ExpenseVisibility> _cachedExpenseVisibilities =
      <String, ExpenseVisibility>{};
  final Map<String, LocalHabit> _cachedHabits = <String, LocalHabit>{};
  final Map<String, bool> _cachedCommitmentIsPrivate = <String, bool>{};
  bool _disposed = false;

  PendingDeleteService(
    this.ref, {
    SharedPreferences? sharedPreferences,
    this.isBackgroundIsolate = false,
  }) : _prefsOverride = sharedPreferences;

  bool get _effectiveIsBackgroundIsolate {
    if (isBackgroundIsolate || _processMarkedBackgroundIsolate) {
      return true;
    }
    final debugName = Isolate.current.debugName?.toLowerCase() ?? '';
    if (debugName.contains('background') ||
        debugName.contains('workmanager') ||
        debugName.contains('fcm')) {
      return true;
    }
    return false;
  }

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  /// Reads all persisted `{kind, id, at}` entries from [prefs].
  static List<PendingDeleteRecord> readAllSync(SharedPreferences prefs) {
    final raw = prefs.getString(prefKey);
    if (raw == null || raw.isEmpty) return const <PendingDeleteRecord>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <PendingDeleteRecord>[];
      final results = <PendingDeleteRecord>[];
      for (final item in decoded) {
        if (item is Map) {
          final parsed = PendingDeleteRecord.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          );
          if (parsed != null) {
            results.add(parsed);
          }
        }
      }
      return results;
    } catch (_) {
      return const <PendingDeleteRecord>[];
    }
  }

  Future<void> _writeAll(
    SharedPreferences prefs,
    List<PendingDeleteRecord> records,
  ) async {
    final encoded = jsonEncode(records.map((r) => r.toJson()).toList());
    await prefs.setString(prefKey, encoded);
  }

  /// Hides the record locally at once (filtering providers with no DB write),
  /// persists `{kind, id, at}` in `SharedPreferences`, and schedules the real
  /// delete when [duration] expires.
  Future<PendingDeleteRecord?> scheduleDelete({
    required PendingDeleteKind kind,
    required String id,
    Duration duration = defaultToastDuration,
    ExpenseVisibility? expenseVisibility,
    LocalHabit? habit,
    bool? commitmentIsPrivate,
  }) async {
    if (_disposed || _effectiveIsBackgroundIsolate) {
      return null;
    }

    final record = PendingDeleteRecord(
      kind: kind,
      id: id,
      at: clock.now().toUtc(),
    );
    final key = record.compositeKey;

    if (expenseVisibility != null) {
      _cachedExpenseVisibilities[id] = expenseVisibility;
    }
    if (habit != null) {
      _cachedHabits[id] = habit;
    }
    if (commitmentIsPrivate != null) {
      _cachedCommitmentIsPrivate[id] = commitmentIsPrivate;
    }

    // 1. Cancel any prior timer for this key and hide immediately in memory.
    _timers.remove(key)?.cancel();
    ref.read(pendingDeleteRecordsProvider.notifier).upsert(record);

    // 2. Schedule expiry timer to emit the real delete when the toast expires.
    _timers[key] = Timer(duration, () {
      _timers.remove(key);
      if (!_disposed) {
        unawaited(commitDelete(kind: kind, id: id));
      }
    });

    // 3. Persist `{kind, id, at}` in local preferences.
    final prefs = await _prefs();
    final existing = readAllSync(prefs);
    final updated = <PendingDeleteRecord>[
      for (final r in existing)
        if (r.compositeKey != key) r,
      record,
    ];
    await _writeAll(prefs, updated);

    return record;
  }

  /// Cancels a pending delete and restores visibility of the original record
  /// without emitting any sync event or touching SQLite.
  Future<void> undoDelete({
    required PendingDeleteKind kind,
    required String id,
  }) async {
    final key = '${kind.wireValue}:$id';
    _timers.remove(key)?.cancel();
    _committingKeys.remove(key);
    _cachedExpenseVisibilities.remove(id);
    _cachedHabits.remove(id);
    _cachedCommitmentIsPrivate.remove(id);

    if (!_disposed) {
      ref.read(pendingDeleteRecordsProvider.notifier).remove(kind, id);
    }

    final prefs = await _prefs();
    final existing = readAllSync(prefs);
    final updated = existing
        .where((r) => r.compositeKey != key)
        .toList(growable: false);
    await _writeAll(prefs, updated);
  }

  /// Emits the real delete through the existing feature controller and clears
  /// the pending delete entry from preferences and memory.
  Future<void> commitDelete({
    required PendingDeleteKind kind,
    required String id,
    bool allowFromStartupFlush = false,
  }) async {
    if (_disposed || _effectiveIsBackgroundIsolate) {
      return;
    }

    final key = '${kind.wireValue}:$id';
    if (_committingKeys.contains(key)) {
      return;
    }

    _timers.remove(key)?.cancel();

    final prefs = await _prefs();
    final persisted = readAllSync(prefs);
    final inMemory = ref
        .read(pendingDeleteRecordsProvider)
        .any((r) => r.compositeKey == key);
    final inPrefs = persisted.any((r) => r.compositeKey == key);

    if (!allowFromStartupFlush && !inMemory && !inPrefs) {
      return;
    }

    _committingKeys.add(key);
    try {
      // Remove from durable preferences first so concurrent flushes cannot double-emit.
      if (inPrefs) {
        final remaining = persisted
            .where((r) => r.compositeKey != key)
            .toList(growable: false);
        await _writeAll(prefs, remaining);
      }

      await _dispatchControllerDelete(kind: kind, id: id);
    } finally {
      _committingKeys.remove(key);
      _cachedExpenseVisibilities.remove(id);
      _cachedHabits.remove(id);
      _cachedCommitmentIsPrivate.remove(id);
      if (!_disposed) {
        ref.read(pendingDeleteRecordsProvider.notifier).remove(kind, id);
      }
    }
  }

  /// On app start, emits any pending delete older than [toastDuration] and
  /// re-arms timers for any pending delete still within its toast window.
  ///
  /// Background isolates never emit deletes.
  Future<int> flushExpiredOnAppStart({
    Duration toastDuration = defaultToastDuration,
  }) async {
    if (_disposed || _effectiveIsBackgroundIsolate) {
      return 0;
    }

    final prefs = await _prefs();
    final persisted = readAllSync(prefs);
    if (persisted.isEmpty) {
      return 0;
    }

    // Hydrate all persisted pending deletes into reactive state first so UI stays consistent.
    ref.read(pendingDeleteRecordsProvider.notifier).setAll(persisted);

    final now = clock.now().toUtc();
    final expired = <PendingDeleteRecord>[];
    for (final record in persisted) {
      final age = now.difference(record.at.toUtc());
      if (age >= toastDuration) {
        expired.add(record);
      } else {
        final remaining = toastDuration - age;
        final key = record.compositeKey;
        _timers.remove(key)?.cancel();
        _timers[key] = Timer(remaining, () {
          _timers.remove(key);
          if (!_disposed) {
            unawaited(commitDelete(kind: record.kind, id: record.id));
          }
        });
      }
    }

    var emittedCount = 0;
    for (final record in expired) {
      await commitDelete(
        kind: record.kind,
        id: record.id,
        allowFromStartupFlush: true,
      );
      emittedCount++;
    }
    return emittedCount;
  }

  Future<void> _dispatchControllerDelete({
    required PendingDeleteKind kind,
    required String id,
  }) async {
    if (_effectiveIsBackgroundIsolate) return;

    final db = ref.read(appDatabaseProvider);

    switch (kind) {
      case PendingDeleteKind.expense:
        var visibility = _cachedExpenseVisibilities[id];
        if (visibility == null) {
          try {
            final exp = await (db.select(db.localExpenses)
                  ..where((t) => t.id.equals(id)))
                .getSingleOrNull();
            if (exp != null) {
              visibility =
                  ExpenseVisibilityExtension.fromSplitRatio(exp.splitRatio);
            }
          } catch (_) {}
        }
        await ref.read(expenseControllerProvider).deleteExpense(
              id,
              visibility: visibility ?? ExpenseVisibility.shared,
            );
        break;

      case PendingDeleteKind.listItem:
        await ref.read(listControllerProvider).deleteItem(itemId: id);
        break;

      case PendingDeleteKind.habit:
        var habit = _cachedHabits[id];
        if (habit == null) {
          try {
            habit = await (db.select(db.localHabits)
                  ..where((t) => t.id.equals(id)))
                .getSingleOrNull();
          } catch (_) {}
        }
        if (habit != null) {
          await ref.read(habitControllerProvider).deleteHabit(habit);
        } else {
          final fallbackHomeId = ref.read(activeHomeIdProvider) ?? 'local_home';
          await ref.read(habitControllerProvider).deleteHabit(
                LocalHabit(
                  id: id,
                  homeId: fallbackHomeId,
                  name: '',
                  cadence: 'daily',
                  targetDaysPerWeek: 7,
                  isArchived: false,
                  createdAt: clock.now(),
                  createdBy: 'local_user',
                ),
              );
        }
        break;

      case PendingDeleteKind.event:
        await ref.read(calendarControllerProvider).deleteEvent(id);
        break;

      case PendingDeleteKind.commitment:
        var isPrivate = _cachedCommitmentIsPrivate[id];
        if (isPrivate == null) {
          try {
            final sub = await (db.select(db.localSubscriptions)
                  ..where((t) => t.id.equals(id)))
                .getSingleOrNull();
            if (sub != null) {
              isPrivate = sub.isPrivate;
            }
          } catch (_) {}
        }
        await ref.read(subscriptionControllerProvider).deleteSubscription(
              id,
              isPrivate: isPrivate ?? false,
            );
        break;

      case PendingDeleteKind.routineEvent:
        await ref.read(routineControllerProvider).deleteRoutineEvent(id);
        break;
    }

    final recordKind = switch (kind) {
      PendingDeleteKind.expense => 'expense',
      PendingDeleteKind.listItem => 'task',
      PendingDeleteKind.habit => 'habit',
      PendingDeleteKind.event => 'event',
      PendingDeleteKind.commitment => 'commitment',
      PendingDeleteKind.routineEvent => 'routine_event',
    };
    try {
      await db.deletePetTagsForRecord(recordKind, id);
    } catch (_) {}
  }

  void dispose() {
    _disposed = true;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }
}
