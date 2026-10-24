import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:workmanager/workmanager.dart';

import '../../sync/db/app_database.dart';
import '../../sync/key_management/home_key_store.dart';
import 'backup_service.dart';
import 'backup_snapshot_service.dart';
import 'drive_backup_remote.dart';

/// Schedules the nightly automatic backup. Abstracted for tests.
abstract class BackupScheduler {
  bool get isSupported;

  /// Must be called once at app start (before [schedule]).
  Future<void> initialize();

  /// Schedules (or reschedules) the nightly backup around [time] local time.
  /// When [reset] is false an existing schedule is kept as-is.
  Future<void> schedule({required TimeOfDay time, required bool wifiOnly, bool reset = false});

  Future<void> cancel();

  /// Time from [now] until the next occurrence of [time] (always > 0).
  static Duration delayUntil(TimeOfDay time, DateTime now) {
    var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    return next.difference(now);
  }
}

/// Android WorkManager implementation: a 24-hour periodic job anchored at the
/// chosen time, constrained to network (optionally Wi-Fi) and healthy battery.
/// Android may shift the exact moment (Doze, battery saver); the job catches
/// up as soon as constraints allow.
class WorkmanagerBackupScheduler implements BackupScheduler {
  static const String uniqueName = 'cove-nightly-backup';
  static const String taskName = 'coveNightlyBackup';

  static bool _initialized = false;

  @override
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> initialize() async {
    if (!isSupported || _initialized) return;
    await Workmanager().initialize(coveBackgroundDispatcher);
    _initialized = true;
  }

  @override
  Future<void> schedule({required TimeOfDay time, required bool wifiOnly, bool reset = false}) async {
    if (!isSupported) return;
    await initialize();
    await Workmanager().registerPeriodicTask(
      uniqueName,
      taskName,
      frequency: const Duration(hours: 24),
      initialDelay: BackupScheduler.delayUntil(time, clock.now()),
      constraints: Constraints(
        networkType: wifiOnly ? NetworkType.unmetered : NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: reset ? ExistingPeriodicWorkPolicy.replace : ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 30),
    );
  }

  @override
  Future<void> cancel() async {
    if (!isSupported) return;
    await initialize();
    await Workmanager().cancelByUniqueName(uniqueName);
  }
}

/// Runs one automatic backup outside the UI.
///
/// When the app is open, WorkManager may execute the task on the main isolate;
/// in that case the app's live database connection is reused (set by the
/// controller via [foregroundDatabase]) instead of opening a second one.
class BackgroundBackupRunner {
  static AppDatabase? foregroundDatabase;

  static Future<bool> run() async {
    final shared = foregroundDatabase;
    final db = shared ?? AppDatabase();
    try {
      final service = BackupService(
        snapshot: BackupSnapshotService(db: db, keyStore: HomeKeyStore()),
        remote: GoogleDriveBackupRemote(),
      );
      final result = await service.run(automatic: true);
      debugPrint('[NightlyBackup] ${result.outcome.name}'
          '${result.error != null ? ': ${result.error}' : ''}');
      // Only transient failures ask WorkManager to retry with backoff.
      return result.outcome != BackupRunOutcome.failed;
    } catch (e) {
      debugPrint('[NightlyBackup] Unexpected failure: $e');
      return false;
    } finally {
      if (shared == null) await db.close();
    }
  }
}

/// WorkManager entry point. Must be a top-level function.
@pragma('vm:entry-point')
void coveBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != WorkmanagerBackupScheduler.taskName) return true;
    return BackgroundBackupRunner.run();
  });
}
