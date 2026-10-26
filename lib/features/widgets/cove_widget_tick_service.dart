import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/uuid_generator.dart';
import '../../sync/crypto/sodium_crypto_service.dart';
import '../../sync/db/app_database.dart';
import '../../sync/db/local_state_store_impl.dart';
import '../../sync/event_store_impl.dart';
import '../../sync/key_management/home_key_store.dart';
import '../../sync/key_management/pairing_crypto.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../../sync/sync_engine_impl.dart';
import '../auth/auth_controller.dart';
import '../habits/habit_controller.dart';
import '../habits/habit_streak_calculator.dart';
import '../lists/list_controller.dart';

/// Kind of record targeted by a home-screen widget tick (`design/specs/18-widgets.md` § Ticking).
enum WidgetTickKind {
  listItem('list_item'),
  habitCheckin('habit_checkin');

  final String wireValue;
  const WidgetTickKind(this.wireValue);

  static WidgetTickKind? fromWire(String? raw) {
    switch (raw) {
      case 'list_item':
        return WidgetTickKind.listItem;
      case 'habit_checkin':
        return WidgetTickKind.habitCheckin;
      default:
        return null;
    }
  }
}

/// Durable widget tick intent persisted in `SharedPreferences` *before* any
/// database or isolate action (`design/specs/18-widgets.md` § Ticking rule 1).
@immutable
class WidgetTickIntent {
  final String id;
  final WidgetTickKind kind;
  final String recordId;
  final bool toDone;
  final DateTime at;
  final bool applied;
  final String? checkinDate;

  const WidgetTickIntent({
    required this.id,
    required this.kind,
    required this.recordId,
    required this.toDone,
    required this.at,
    this.applied = false,
    this.checkinDate,
  });

  WidgetTickIntent copyWith({
    bool? applied,
  }) {
    return WidgetTickIntent(
      id: id,
      kind: kind,
      recordId: recordId,
      toDone: toDone,
      at: at,
      applied: applied ?? this.applied,
      checkinDate: checkinDate,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.wireValue,
        'recordId': recordId,
        'toDone': toDone,
        'at': at.toUtc().toIso8601String(),
        'applied': applied,
        if (checkinDate != null) 'checkinDate': checkinDate,
      };

  factory WidgetTickIntent.fromJson(Map<String, dynamic> map) {
    final kind =
        WidgetTickKind.fromWire(map['kind'] as String?) ?? WidgetTickKind.listItem;
    return WidgetTickIntent(
      id: map['id'] as String,
      kind: kind,
      recordId: map['recordId'] as String,
      toDone: map['toDone'] as bool? ?? true,
      at: DateTime.tryParse(map['at'] as String? ?? '')?.toUtc() ??
          clock.now().toUtc(),
      applied: map['applied'] as bool? ?? false,
      checkinDate: map['checkinDate'] as String?,
    );
  }
}

/// Durable intent log in `SharedPreferences` (`design/specs/18-widgets.md` § Ticking).
class WidgetTickIntentLog {
  static const String prefKey = 'cove_widget_tick_intents_v1';

  final SharedPreferences? _prefsOverride;

  const WidgetTickIntentLog([this._prefsOverride]);

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  /// Appends a tick intent to the durable log in local preferences *before*
  /// anything else.
  Future<WidgetTickIntent> appendIntent({
    required WidgetTickKind kind,
    required String recordId,
    bool toDone = true,
    DateTime? at,
    String? id,
    String? checkinDate,
  }) async {
    final prefs = await _prefs();
    final existing = readAllSync(prefs);
    final intentId = id ?? generateCoveUuid();

    for (final item in existing) {
      if (item.id == intentId) {
        return item;
      }
    }

    final intent = WidgetTickIntent(
      id: intentId,
      kind: kind,
      recordId: recordId,
      toDone: toDone,
      at: (at ?? clock.now()).toUtc(),
      applied: false,
      checkinDate: checkinDate,
    );

    final updated = <WidgetTickIntent>[...existing, intent];
    await _writeAll(prefs, updated);
    return intent;
  }

  Future<List<WidgetTickIntent>> getAllIntents() async {
    final prefs = await _prefs();
    return readAllSync(prefs);
  }

  Future<List<WidgetTickIntent>> getUnappliedIntents() async {
    final all = await getAllIntents();
    return all.where((i) => !i.applied).toList(growable: false);
  }

  Future<void> markApplied(String intentId) async {
    final prefs = await _prefs();
    final all = readAllSync(prefs);
    var changed = false;
    final updated = all.map((intent) {
      if (intent.id == intentId && !intent.applied) {
        changed = true;
        return intent.copyWith(applied: true);
      }
      return intent;
    }).toList(growable: false);
    if (changed) {
      await _writeAll(prefs, updated);
    }
  }

  /// Returns the set of `list_item` record IDs that have an unapplied
  /// `toDone == true` intent in [prefs], used for immediate optimistic
  /// widget rendering.
  static Set<String> pendingCompletedListItemIdsSync(SharedPreferences prefs) {
    final intents = readAllSync(prefs);
    final ids = <String>{};
    for (final intent in intents) {
      if (!intent.applied && intent.kind == WidgetTickKind.listItem) {
        if (intent.toDone) {
          ids.add(intent.recordId);
        } else {
          ids.remove(intent.recordId);
        }
      }
    }
    return ids;
  }

  static List<WidgetTickIntent> readAllSync(SharedPreferences prefs) {
    final raw = prefs.getString(prefKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(WidgetTickIntent.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeAll(
    SharedPreferences prefs,
    List<WidgetTickIntent> intents,
  ) async {
    final encoded = jsonEncode(intents.map((i) => i.toJson()).toList());
    await prefs.setString(prefKey, encoded);
  }
}

/// Outcome of handling a home-screen widget tick (`design/specs/18-widgets.md` § Ticking).
enum WidgetTickOutcome {
  forwardedToMainIsolate,
  appliedInBackground,
  appliedOnAppStart,
  noopAlreadyInState,
  refusedSchemaMismatch,
  missingKeyOrRecord,
}

@immutable
class WidgetTickResult {
  final WidgetTickOutcome outcome;
  final WidgetTickIntent intent;
  final bool wroteToDatabase;

  const WidgetTickResult({
    required this.outcome,
    required this.intent,
    required this.wroteToDatabase,
  });
}

/// Coordinates safe home-screen widget ticks across the live main isolate and
/// the background widget callback isolate (`design/specs/18-widgets.md` § Ticking).
class CoveWidgetTickService {
  static const String mainIsolatePortName = 'cove_widget_tick_main_port';
  static const Duration mainIsolateReceiptTimeout = Duration(seconds: 1);
  static const Duration backgroundSyncPushBudget = Duration(seconds: 8);

  final AppDatabase? _appDatabaseOverride;
  final HomeKeyStore? _homeKeyStoreOverride;
  final SupabaseClient? _supabaseClientOverride;
  final SharedPreferences? _sharedPreferencesOverride;
  final String Function()? getCurrentUserId;
  final Future<void> Function(WidgetTickIntent intent)? onAfterMainApply;

  ReceivePort? _mainIsolateReceivePort;
  StreamSubscription<dynamic>? _mainIsolatePortSubscription;
  Future<void>? _inFlightMainApply;

  CoveWidgetTickService({
    AppDatabase? appDatabase,
    HomeKeyStore? homeKeyStore,
    SupabaseClient? supabaseClient,
    SharedPreferences? sharedPreferences,
    this.getCurrentUserId,
    this.onAfterMainApply,
  })  : _appDatabaseOverride = appDatabase,
        _homeKeyStoreOverride = homeKeyStore,
        _supabaseClientOverride = supabaseClient,
        _sharedPreferencesOverride = sharedPreferences;

  /// Registers the main isolate's receive port in [IsolateNameServer] so
  /// background widget tick callbacks can forward intents when the app is alive.
  void registerMainIsolatePort() {
    if (_mainIsolateReceivePort != null) {
      IsolateNameServer.removePortNameMapping(mainIsolatePortName);
      IsolateNameServer.registerPortWithName(
        _mainIsolateReceivePort!.sendPort,
        mainIsolatePortName,
      );
      return;
    }

    final port = ReceivePort();
    _mainIsolateReceivePort = port;
    IsolateNameServer.removePortNameMapping(mainIsolatePortName);
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      mainIsolatePortName,
    );

    _mainIsolatePortSubscription = port.listen((dynamic message) {
      if (message is Map) {
        final replyPort = message['reply_port'];
        // Immediately acknowledge receipt so the background isolate's 1-second
        // timer succeeds and it opens no database connection.
        if (replyPort is SendPort) {
          replyPort.send('received');
        }
        final rawIntent = message['intent'];
        if (rawIntent is Map) {
          final intent = WidgetTickIntent.fromJson(
            rawIntent.map((k, v) => MapEntry(k.toString(), v)),
          );
          final previous = _inFlightMainApply;
          final completer = Completer<void>();
          _inFlightMainApply = completer.future;
          () async {
            if (previous != null) {
              try {
                await previous;
              } catch (_) {}
            }
            try {
              await applyIntentOnMainIsolate(intent);
              if (onAfterMainApply != null) {
                await onAfterMainApply!(intent);
              }
            } finally {
              completer.complete();
            }
          }();
        }
      }
    });
  }

  /// Unregisters the main isolate port from [IsolateNameServer].
  void unregisterMainIsolatePort() {
    IsolateNameServer.removePortNameMapping(mainIsolatePortName);
    _mainIsolatePortSubscription?.cancel();
    _mainIsolatePortSubscription = null;
    _mainIsolateReceivePort?.close();
    _mainIsolateReceivePort = null;
  }

  void dispose() {
    unregisterMainIsolatePort();
  }

  /// Waits for any forwarded intent currently being applied on the main isolate.
  @visibleForTesting
  Future<void> waitForForwardedTick() async {
    final inFlight = _inFlightMainApply;
    if (inFlight != null) {
      await inFlight;
    }
  }

  /// Applies a single [intent] idempotently using the main isolate's database
  /// and normal controllers (`ListController` / `HabitController`).
  Future<WidgetTickResult> applyIntentOnMainIsolate(
    WidgetTickIntent intent,
  ) async {
    final db = _appDatabaseOverride;
    if (db == null) {
      throw StateError(
        'CoveWidgetTickService requires an AppDatabase on the main isolate.',
      );
    }
    final log = WidgetTickIntentLog(_sharedPreferencesOverride);
    final applied = await _applyIntentThroughController(
      db: db,
      intent: intent,
      intentLog: log,
      keyStore: _homeKeyStoreOverride ?? HomeKeyStore(),
      supabaseClient: _supabaseClientOverride,
      currentUserId: getCurrentUserId?.call() ?? 'local_user',
      isBackground: false,
      simulateCrashBeforeMarkingApplied: false,
    );
    return applied;
  }

  /// Replays all unapplied intents from the durable intent log on app start
  /// (`design/specs/18-widgets.md` § Ticking rule 4).
  ///
  /// Applying is idempotent: if a record is already in the wanted state (for
  /// example after a background crash right after writing to SQLite), it is
  /// marked applied without writing a second time.
  Future<List<WidgetTickResult>> replayUnappliedIntentsOnAppStart() async {
    final db = _appDatabaseOverride;
    if (db == null) return const [];
    final log = WidgetTickIntentLog(_sharedPreferencesOverride);
    final unapplied = await log.getUnappliedIntents();
    if (unapplied.isEmpty) return const [];

    final results = <WidgetTickResult>[];
    for (final intent in unapplied) {
      final res = await _applyIntentThroughController(
        db: db,
        intent: intent,
        intentLog: log,
        keyStore: _homeKeyStoreOverride ?? HomeKeyStore(),
        supabaseClient: _supabaseClientOverride,
        currentUserId: getCurrentUserId?.call() ?? 'local_user',
        isBackground: false,
        simulateCrashBeforeMarkingApplied: false,
      );
      if (res.outcome == WidgetTickOutcome.appliedInBackground) {
        results.add(
          WidgetTickResult(
            outcome: WidgetTickOutcome.appliedOnAppStart,
            intent: res.intent,
            wroteToDatabase: res.wroteToDatabase,
          ),
        );
      } else {
        results.add(res);
      }
      if (onAfterMainApply != null) {
        await onAfterMainApply!(intent);
      }
    }
    return results;
  }

  /// Entry point for a widget tick (`design/specs/18-widgets.md` § Ticking):
  ///
  /// 1. Appends `{id, kind, recordId, toDone, at}` to the durable intent log in
  ///    local preferences *before* anything else, and invokes [onOptimisticRender]
  ///    so the widget re-renders straight away with the tick shown.
  /// 2. If the main app is alive (its port is registered in [IsolateNameServer]
  ///    and it sends a `'received'` receipt within 1 second), the main app
  ///    applies the intent through the normal controller and the background
  ///    opens **no** database connection.
  /// 3. If the main app isn't alive, opens its **own unshared, writable**
  ///    connection (`busy_timeout = 5000`, `enableMigrations: false`), verifies
  ///    `PRAGMA user_version == AppDatabase.currentSchemaVersion` (refuses to
  ///    run on mismatch), applies the tick idempotently through the same
  ///    controller code in one transaction for the record and its outbox event,
  ///    marks the intent applied, and attempts a sync push within an 8-second
  ///    budget.
  static Future<WidgetTickResult> handleWidgetTick({
    required WidgetTickKind kind,
    required String recordId,
    bool toDone = true,
    String? intentId,
    String? checkinDate,
    File? databaseFile,
    Future<File> Function()? resolveDatabaseFile,
    SharedPreferences? sharedPreferencesOverride,
    HomeKeyStore? keyStoreOverride,
    SupabaseClient? supabaseClientOverride,
    String? viewerUserIdOverride,
    VoidCallback? onBackgroundDatabaseOpened,
    Future<void> Function(WidgetTickIntent intent)? onOptimisticRender,
    Future<void> Function()? onSyncPushOverride,
    Duration? receiptTimeoutOverride,
    Duration? syncPushBudgetOverride,
    @visibleForTesting bool simulateCrashBeforeMarkingApplied = false,
    @visibleForTesting Future<void> Function()? onInsideWriteTransaction,
  }) async {
    final log = WidgetTickIntentLog(sharedPreferencesOverride);

    // Rule 1: The tick becomes an intent first, appended to a durable intent log
    // in local preferences *before* anything else.
    final intent = await log.appendIntent(
      id: intentId,
      kind: kind,
      recordId: recordId,
      toDone: toDone,
      checkinDate: checkinDate,
    );

    // Re-render the widget straight away with the tick shown.
    if (onOptimisticRender != null) {
      try {
        await onOptimisticRender(intent);
      } catch (_) {}
    }

    // Rule 2: If the app is alive (its port is registered and it sends a receipt
    // within 1 second), the app applies the intent through the normal controller.
    final mainPort = IsolateNameServer.lookupPortByName(mainIsolatePortName);
    if (mainPort != null) {
      final gotReceipt = await _forwardIntentWithReceipt(
        mainPort: mainPort,
        intent: intent,
        timeout: receiptTimeoutOverride ?? mainIsolateReceiptTimeout,
      );
      if (gotReceipt) {
        return WidgetTickResult(
          outcome: WidgetTickOutcome.forwardedToMainIsolate,
          intent: intent.copyWith(applied: true),
          wroteToDatabase: false,
        );
      }
      // Stale port mapping (main isolate died without unregistering): clean up
      // and fall through to the background apply path.
      IsolateNameServer.removePortNameMapping(mainIsolatePortName);
    }

    // Rule 3: Background isolate applies it on its own unshared, writable
    // connection (`busy_timeout 5000`, no migrations, refuses if `user_version`
    // doesn't match `schemaVersion`).
    try {
      await PairingCrypto.ensureInitialized();
    } catch (_) {}

    final bgDb = await AppDatabase.openBackgroundWritableIfSchemaMatches(
      file: databaseFile,
      resolveFile: resolveDatabaseFile,
    );
    if (bgDb == null) {
      return WidgetTickResult(
        outcome: WidgetTickOutcome.refusedSchemaMismatch,
        intent: intent,
        wroteToDatabase: false,
      );
    }

    onBackgroundDatabaseOpened?.call();

    try {
      final prefs =
          sharedPreferencesOverride ?? await SharedPreferences.getInstance();
      final resolvedUserId = viewerUserIdOverride ??
          prefs.getString('cove_last_authenticated_user_id') ??
          'local_user';

      final result = await _applyIntentThroughController(
        db: bgDb,
        intent: intent,
        intentLog: log,
        keyStore: keyStoreOverride ?? HomeKeyStore(),
        supabaseClient: supabaseClientOverride,
        currentUserId: resolvedUserId,
        isBackground: true,
        simulateCrashBeforeMarkingApplied: simulateCrashBeforeMarkingApplied,
        onSyncPushOverride: onSyncPushOverride,
        syncPushBudget: syncPushBudgetOverride ?? backgroundSyncPushBudget,
        onInsideWriteTransaction: onInsideWriteTransaction,
      );
      return result;
    } finally {
      await bgDb.close();
    }
  }

  static Future<bool> _forwardIntentWithReceipt({
    required SendPort mainPort,
    required WidgetTickIntent intent,
    required Duration timeout,
  }) async {
    final replyPort = ReceivePort();
    try {
      mainPort.send(<String, dynamic>{
        'intent': intent.toJson(),
        'reply_port': replyPort.sendPort,
      });
      final ack = await replyPort.first.timeout(timeout);
      return ack == 'received';
    } catch (_) {
      return false;
    } finally {
      replyPort.close();
    }
  }

  /// Shared controller execution path used by both the live app and the
  /// background isolate (`design/specs/18-widgets.md` § Ticking rules 2–5).
  static Future<WidgetTickResult> _applyIntentThroughController({
    required AppDatabase db,
    required WidgetTickIntent intent,
    required WidgetTickIntentLog intentLog,
    required HomeKeyStore keyStore,
    required SupabaseClient? supabaseClient,
    required String currentUserId,
    required bool isBackground,
    required bool simulateCrashBeforeMarkingApplied,
    Future<void> Function()? onSyncPushOverride,
    Duration syncPushBudget = backgroundSyncPushBudget,
    Future<void> Function()? onInsideWriteTransaction,
  }) async {
    switch (intent.kind) {
      case WidgetTickKind.listItem:
        final item = await (db.select(db.localListItems)
              ..where((t) => t.id.equals(intent.recordId)))
            .getSingleOrNull();
        if (item == null) {
          await intentLog.markApplied(intent.id);
          return WidgetTickResult(
            outcome: WidgetTickOutcome.missingKeyOrRecord,
            intent: intent.copyWith(applied: true),
            wroteToDatabase: false,
          );
        }

        // Rule 4: Idempotent check — if the record is already in the wanted
        // state, mark it applied without writing.
        if (item.isCompleted == intent.toDone) {
          await intentLog.markApplied(intent.id);
          return WidgetTickResult(
            outcome: WidgetTickOutcome.noopAlreadyInState,
            intent: intent.copyWith(applied: true),
            wroteToDatabase: false,
          );
        }

        // Rule 5: Never generate a key from the background. Require an existing
        // home key in HomeKeyStore.
        final hasKey = await keyStore.hasKey(item.homeId);
        if (!hasKey) {
          return WidgetTickResult(
            outcome: WidgetTickOutcome.missingKeyOrRecord,
            intent: intent,
            wroteToDatabase: false,
          );
        }

        final container = _buildScopedControllerContainer(
          db: db,
          homeId: item.homeId,
          currentUserId: currentUserId,
          keyStore: keyStore,
          supabaseClient: supabaseClient,
        );
        try {
          await db.transaction(() async {
            if (onInsideWriteTransaction != null) {
              await onInsideWriteTransaction();
            }
            await container.read(listControllerProvider).toggleItem(
                  itemId: item.id,
                  isCompleted: intent.toDone,
                  itemTitle: item.title,
                );
          });

          if (simulateCrashBeforeMarkingApplied) {
            throw StateError('Simulated crash after DB write before markApplied');
          }

          await intentLog.markApplied(intent.id);

          if (isBackground) {
            await _trySyncPushWithBudget(
              container: container,
              budget: syncPushBudget,
              onSyncPushOverride: onSyncPushOverride,
            );
          }
        } finally {
          container.dispose();
        }

        return WidgetTickResult(
          outcome: WidgetTickOutcome.appliedInBackground,
          intent: intent.copyWith(applied: true),
          wroteToDatabase: true,
        );

      case WidgetTickKind.habitCheckin:
        final habit = await (db.select(db.localHabits)
              ..where((t) => t.id.equals(intent.recordId)))
            .getSingleOrNull();
        if (habit == null) {
          await intentLog.markApplied(intent.id);
          return WidgetTickResult(
            outcome: WidgetTickOutcome.missingKeyOrRecord,
            intent: intent.copyWith(applied: true),
            wroteToDatabase: false,
          );
        }

        // Partner habits are never tappable (`design/specs/18-widgets.md` §4).
        if (habit.createdBy != currentUserId) {
          await intentLog.markApplied(intent.id);
          return WidgetTickResult(
            outcome: WidgetTickOutcome.missingKeyOrRecord,
            intent: intent.copyWith(applied: true),
            wroteToDatabase: false,
          );
        }

        final dateStr = intent.checkinDate ??
            HabitStreakCalculator.formatDate(intent.at.toLocal());
        final existingCheckin = await (db.select(db.localHabitCheckins)
              ..where((t) =>
                  t.habitId.equals(habit.id) &
                  t.checkinDate.equals(dateStr) &
                  t.memberId.equals(currentUserId)))
            .getSingleOrNull();
        final isAlreadyChecked = existingCheckin != null;

        // Rule 4: Idempotent check — if the check-in is already in the wanted
        // state, mark it applied without writing.
        if (isAlreadyChecked == intent.toDone) {
          await intentLog.markApplied(intent.id);
          return WidgetTickResult(
            outcome: WidgetTickOutcome.noopAlreadyInState,
            intent: intent.copyWith(applied: true),
            wroteToDatabase: false,
          );
        }

        final isPrivate = habit.targetDaysPerWeek < 0;
        if (!isPrivate) {
          final hasKey = await keyStore.hasKey(habit.homeId);
          if (!hasKey) {
            return WidgetTickResult(
              outcome: WidgetTickOutcome.missingKeyOrRecord,
              intent: intent,
              wroteToDatabase: false,
            );
          }
        }

        final targetDate = DateTime.tryParse(dateStr) ?? intent.at.toLocal();
        final container = _buildScopedControllerContainer(
          db: db,
          homeId: habit.homeId,
          currentUserId: currentUserId,
          keyStore: keyStore,
          supabaseClient: supabaseClient,
        );
        try {
          await db.transaction(() async {
            if (onInsideWriteTransaction != null) {
              await onInsideWriteTransaction();
            }
            await container.read(habitControllerProvider).toggleCheckin(
                  habit: habit,
                  date: targetDate,
                  checked: intent.toDone,
                );
          });

          if (simulateCrashBeforeMarkingApplied) {
            throw StateError('Simulated crash after DB write before markApplied');
          }

          await intentLog.markApplied(intent.id);

          if (isBackground && !isPrivate) {
            await _trySyncPushWithBudget(
              container: container,
              budget: syncPushBudget,
              onSyncPushOverride: onSyncPushOverride,
            );
          }
        } finally {
          container.dispose();
        }

        return WidgetTickResult(
          outcome: WidgetTickOutcome.appliedInBackground,
          intent: intent.copyWith(applied: true),
          wroteToDatabase: true,
        );
    }
  }

  static ProviderContainer _buildScopedControllerContainer({
    required AppDatabase db,
    required String homeId,
    required String currentUserId,
    required HomeKeyStore keyStore,
    required SupabaseClient? supabaseClient,
  }) {
    final crypto = SodiumCryptoService();
    final eventStore = EventStoreImpl(db: db, cryptoService: crypto);
    final localStateStore = LocalStateStoreImpl(db);
    final syncEngine = SyncEngineImpl(
      eventStore: eventStore,
      localStateStore: localStateStore,
      encryptionService: crypto,
      keyStore: keyStore,
      supabaseClient: supabaseClient,
      getCurrentUserId: () => currentUserId,
      getActiveHomeId: () => homeId,
    );

    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        homeKeyStoreProvider.overrideWithValue(keyStore),
        sodiumCryptoServiceProvider.overrideWithValue(crypto),
        localStateStoreProvider.overrideWithValue(localStateStore),
        eventStoreProvider.overrideWithValue(eventStore),
        supabaseClientProvider.overrideWithValue(supabaseClient),
        syncEngineProvider.overrideWithValue(syncEngine),
        activeHomeIdProvider.overrideWith(
          () => _FixedActiveHomeIdNotifier(homeId),
        ),
        authProvider.overrideWith(
          () => _FixedAuthNotifier(
            CoveUser(id: currentUserId, email: '$currentUserId@cove.local'),
          ),
        ),
      ],
    );
  }

  static Future<void> _trySyncPushWithBudget({
    required ProviderContainer container,
    required Duration budget,
    Future<void> Function()? onSyncPushOverride,
  }) async {
    try {
      if (onSyncPushOverride != null) {
        await onSyncPushOverride().timeout(budget);
      } else {
        await container
            .read(syncEngineProvider)
            .flushOutbox()
            .timeout(budget);
      }
    } catch (_) {
      // If the push fails or times out, the outbox entry waits for the app
      // (`design/specs/18-widgets.md` § Ticking rule 3).
    }
  }
}

class _FixedActiveHomeIdNotifier extends ActiveHomeNotifier {
  final String _fixedHomeId;
  _FixedActiveHomeIdNotifier(this._fixedHomeId);

  @override
  String? build() => _fixedHomeId;
}

class _FixedAuthNotifier extends AuthNotifier {
  final CoveUser _user;
  _FixedAuthNotifier(this._user);

  @override
  AsyncValue<CoveUser?> build() => AsyncData(_user);
}

final coveWidgetTickServiceProvider = Provider<CoveWidgetTickService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final keyStore = ref.watch(homeKeyStoreProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final service = CoveWidgetTickService(
    appDatabase: db,
    homeKeyStore: keyStore,
    supabaseClient: supabase,
    getCurrentUserId: () =>
        ref.read(authProvider).value?.id ??
        supabase?.auth.currentUser?.id ??
        'local_user',
  );
  ref.onDispose(service.dispose);
  return service;
});
