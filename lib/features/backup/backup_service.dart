import 'dart:convert';

import 'package:clock/clock.dart' as pkg_clock;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' show SHA256Digest;

import '../changelog/changelog_models.dart';
import 'backup_crypto.dart';
import 'backup_snapshot_service.dart';
import 'drive_backup_remote.dart';

/// Hardware-backed storage for the passphrase-derived key and backup status.
/// Shared by the foreground controller and the background (nightly) worker.
const FlutterSecureStorage kBackupSecureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// Secure-storage keys used by the backup system (all excluded from snapshots
/// via the `cove_backup_` prefix).
class BackupKeys {
  static const kek = 'cove_backup_kek';
  static const kdf = 'cove_backup_kdf';
  static const connected = 'cove_backup_connected';
  static const email = 'cove_backup_email';
  static const lastAt = 'cove_backup_last_at';
  static const lastSize = 'cove_backup_last_size';
  static const lastHash = 'cove_backup_last_hash';

  // Nightly automatic backup
  static const autoEnabled = 'cove_backup_auto_enabled'; // 'true' | 'false' | absent (= on once set up)
  static const autoTime = 'cove_backup_auto_time'; // 'HH:mm', local time
  static const autoWifiOnly = 'cove_backup_auto_wifi_only'; // 'true' | 'false'
  static const autoLastRunAt = 'cove_backup_auto_last_run_at';
  static const autoLastOutcome = 'cove_backup_auto_last_outcome';
  static const autoError = 'cove_backup_auto_error';
}

enum BackupRunOutcome {
  /// A new encrypted backup was uploaded.
  uploaded,

  /// Nothing changed since the last backup; no upload needed.
  skippedUnchanged,

  /// A backup already ran recently (e.g. a manual one this evening).
  skippedRecent,

  /// Drive or passphrase not set up, or automatic backup turned off.
  notConfigured,

  /// Google Drive access must be re-granted from the app.
  needsReconnect,

  /// Transient failure (network, Drive error). Safe to retry.
  failed,
}

class BackupRunResult {
  final BackupRunOutcome outcome;
  final DateTime at;
  final int? sizeBytes;
  final Object? error;

  const BackupRunResult(this.outcome, {required this.at, this.sizeBytes, this.error});

  bool get isSuccess =>
      outcome == BackupRunOutcome.uploaded ||
      outcome == BackupRunOutcome.skippedUnchanged ||
      outcome == BackupRunOutcome.skippedRecent;
}

/// Platform-agnostic backup pipeline: snapshot → fingerprint → seal → upload → prune.
/// Has no Riverpod/UI dependencies so it can run in a background isolate.
class BackupService {
  /// Number of most recent backups kept in Drive; older ones are pruned.
  static const int retainCount = 10;

  /// Automatic runs are skipped if any backup succeeded within this window.
  static const Duration recentWindow = Duration(hours: 20);

  final BackupSnapshotService snapshot;
  final BackupRemote remote;
  final FlutterSecureStorage storage;
  final DateTime Function() clock;

  BackupService({
    required this.snapshot,
    required this.remote,
    FlutterSecureStorage? storage,
    DateTime Function()? clock,
  })  : storage = storage ?? kBackupSecureStorage,
        clock = clock ?? pkg_clock.clock.now;

  /// Runs one backup.
  ///
  /// - Manual runs ([automatic] = false) always upload and surface errors to
  ///   the caller by throwing.
  /// - Automatic runs never throw; they skip when not configured, when a
  ///   backup ran recently, or when nothing changed, and record their outcome
  ///   so Settings can show it.
  Future<BackupRunResult> run({required bool automatic}) async {
    final now = clock();
    if (!automatic) {
      return _upload(now: now, skipIfUnchanged: false);
    }

    BackupRunResult result;
    try {
      result = await _automaticRun(now);
    } on BackupAuthException catch (e) {
      result = BackupRunResult(BackupRunOutcome.needsReconnect, at: now, error: e);
    } catch (e) {
      result = BackupRunResult(BackupRunOutcome.failed, at: now, error: e);
    }
    await _recordAutoRun(result);
    return result;
  }

  Future<BackupRunResult> _automaticRun(DateTime now) async {
    final enabled = await storage.read(key: BackupKeys.autoEnabled);
    final connected = await storage.read(key: BackupKeys.connected);
    final kek = await storage.read(key: BackupKeys.kek);
    if (enabled == 'false' || connected != 'true' || kek == null) {
      return BackupRunResult(BackupRunOutcome.notConfigured, at: now);
    }

    final lastRaw = await storage.read(key: BackupKeys.lastAt);
    final last = lastRaw != null ? DateTime.tryParse(lastRaw) : null;
    if (last != null && now.toUtc().difference(last.toUtc()) < recentWindow) {
      return BackupRunResult(BackupRunOutcome.skippedRecent, at: now);
    }

    return _upload(now: now, skipIfUnchanged: true);
  }

  Future<BackupRunResult> _upload({required DateTime now, required bool skipIfUnchanged}) async {
    final kekRaw = await storage.read(key: BackupKeys.kek);
    final kdfRaw = await storage.read(key: BackupKeys.kdf);
    if (kekRaw == null || kdfRaw == null) {
      throw const BackupFormatException('Set a recovery passphrase first.');
    }
    final kek = base64Decode(kekRaw);
    final kdf = BackupKdfParams.fromJson(jsonDecode(kdfRaw) as Map<String, dynamic>);

    final payload = await snapshot.export();
    final hash = fingerprint(payload);

    if (skipIfUnchanged && hash == await storage.read(key: BackupKeys.lastHash)) {
      // Data is identical to the newest backup; refresh the timestamp only so
      // "Last Backup" reflects that the backup is current.
      await storage.write(key: BackupKeys.lastAt, value: now.toUtc().toIso8601String());
      return BackupRunResult(BackupRunOutcome.skippedUnchanged, at: now);
    }

    final bytes = BackupCrypto.seal(
      payload: payload,
      kek: kek,
      kdf: kdf,
      schemaVersion: snapshot.db.schemaVersion,
      appVersion: kCoveCurrentAppVersion,
      createdAt: now,
    );

    await remote.upload(bytes, createdAt: now, deviceLabel: kIsWeb ? 'web' : defaultTargetPlatform.name);
    await _prune();

    await storage.write(key: BackupKeys.lastAt, value: now.toUtc().toIso8601String());
    await storage.write(key: BackupKeys.lastSize, value: bytes.length.toString());
    await storage.write(key: BackupKeys.lastHash, value: hash);
    return BackupRunResult(BackupRunOutcome.uploaded, at: now, sizeBytes: bytes.length);
  }

  Future<void> _prune() async {
    try {
      final files = await remote.list();
      for (final stale in files.skip(retainCount)) {
        await remote.delete(stale.id);
      }
    } catch (e) {
      debugPrint('[BackupService] Prune skipped: $e');
    }
  }

  Future<void> _recordAutoRun(BackupRunResult result) async {
    try {
      await storage.write(key: BackupKeys.autoLastRunAt, value: result.at.toUtc().toIso8601String());
      await storage.write(key: BackupKeys.autoLastOutcome, value: result.outcome.name);
      if (result.outcome == BackupRunOutcome.needsReconnect) {
        await storage.write(
          key: BackupKeys.autoError,
          value: 'Automatic backup paused — reconnect Google Drive.',
        );
      } else if (result.isSuccess || result.outcome == BackupRunOutcome.notConfigured) {
        await storage.delete(key: BackupKeys.autoError);
      }
      // Transient failures keep any previous message; WorkManager retries.
    } catch (_) {}
  }

  /// Stable SHA-256 over the snapshot content, used to skip unchanged backups.
  static String fingerprint(Map<String, dynamic> payload) {
    final prefs = (payload['prefs'] as Map?)?.cast<String, dynamic>() ?? const {};
    final sortedPrefs = {for (final k in (prefs.keys.toList()..sort())) k: prefs[k]};
    final canonical = jsonEncode({
      'schemaVersion': payload['schemaVersion'],
      'tables': payload['tables'],
      'homeKeys': payload['homeKeys'],
      'prefs': sortedPrefs,
    });
    final digest = SHA256Digest().process(Uint8List.fromList(utf8.encode(canonical)));
    return base64Encode(digest);
  }
}
