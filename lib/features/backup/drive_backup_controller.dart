import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import 'backup_crypto.dart';
import 'backup_scheduler.dart';
import 'backup_service.dart';
import 'backup_snapshot_service.dart';
import 'drive_backup_remote.dart';

/// What the backup system is busy doing (drives button spinners).
enum DriveBackupActivity { idle, connecting, settingPassphrase, backingUp, restoring }

class DriveBackupState {
  /// Default nightly window: 2:00 AM local time.
  static const TimeOfDay defaultAutoTime = TimeOfDay(hour: 2, minute: 0);

  final bool isSupported;
  final bool isLoaded;
  final bool isConnected;
  final String? accountEmail;
  final bool hasPassphrase;
  final DateTime? lastBackupAt;
  final int? lastBackupSizeBytes;
  final DriveBackupActivity activity;
  final String? errorMessage;

  /// User preference for nightly backup (on by default once set up).
  final bool autoEnabled;
  final TimeOfDay autoTime;
  final bool autoWifiOnly;
  final DateTime? autoLastRunAt;
  final BackupRunOutcome? autoLastOutcome;
  final String? autoError;

  const DriveBackupState({
    this.isSupported = true,
    this.isLoaded = false,
    this.isConnected = false,
    this.accountEmail,
    this.hasPassphrase = false,
    this.lastBackupAt,
    this.lastBackupSizeBytes,
    this.activity = DriveBackupActivity.idle,
    this.errorMessage,
    this.autoEnabled = true,
    this.autoTime = defaultAutoTime,
    this.autoWifiOnly = true,
    this.autoLastRunAt,
    this.autoLastOutcome,
    this.autoError,
  });

  bool get isBusy => activity != DriveBackupActivity.idle;

  /// Backup is fully set up (Drive connected + passphrase).
  bool get isConfigured => isConnected && hasPassphrase;

  /// Nightly backup will actually run.
  bool get isAutoActive => isSupported && isConfigured && autoEnabled;

  DriveBackupState copyWith({
    bool? isSupported,
    bool? isLoaded,
    bool? isConnected,
    String? Function()? accountEmail,
    bool? hasPassphrase,
    DateTime? Function()? lastBackupAt,
    int? Function()? lastBackupSizeBytes,
    DriveBackupActivity? activity,
    String? Function()? errorMessage,
    bool? autoEnabled,
    TimeOfDay? autoTime,
    bool? autoWifiOnly,
    DateTime? Function()? autoLastRunAt,
    BackupRunOutcome? Function()? autoLastOutcome,
    String? Function()? autoError,
  }) {
    return DriveBackupState(
      isSupported: isSupported ?? this.isSupported,
      isLoaded: isLoaded ?? this.isLoaded,
      isConnected: isConnected ?? this.isConnected,
      accountEmail: accountEmail != null ? accountEmail() : this.accountEmail,
      hasPassphrase: hasPassphrase ?? this.hasPassphrase,
      lastBackupAt: lastBackupAt != null ? lastBackupAt() : this.lastBackupAt,
      lastBackupSizeBytes: lastBackupSizeBytes != null ? lastBackupSizeBytes() : this.lastBackupSizeBytes,
      activity: activity ?? this.activity,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      autoEnabled: autoEnabled ?? this.autoEnabled,
      autoTime: autoTime ?? this.autoTime,
      autoWifiOnly: autoWifiOnly ?? this.autoWifiOnly,
      autoLastRunAt: autoLastRunAt != null ? autoLastRunAt() : this.autoLastRunAt,
      autoLastOutcome: autoLastOutcome != null ? autoLastOutcome() : this.autoLastOutcome,
      autoError: autoError != null ? autoError() : this.autoError,
    );
  }

  static String encodeTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static TimeOfDay? decodeTime(String? raw) {
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return TimeOfDay(hour: h, minute: m);
  }
}

// --- DEPENDENCY PROVIDERS (overridable in tests) ---

final backupRemoteProvider = Provider<BackupRemote>((ref) => GoogleDriveBackupRemote());

/// Hardware-backed storage for the passphrase-derived key and backup status.
final backupSecureStorageProvider = Provider<FlutterSecureStorage>((ref) => kBackupSecureStorage);

final backupSnapshotServiceProvider = Provider<BackupSnapshotService>((ref) {
  return BackupSnapshotService(
    db: ref.watch(appDatabaseProvider),
    keyStore: ref.watch(homeKeyStoreProvider),
  );
});

final backupSchedulerProvider = Provider<BackupScheduler>((ref) => WorkmanagerBackupScheduler());

/// Argon2id cost profile for new passphrases (lowered in tests).
final backupKdfFactoryProvider = Provider<BackupKdfParams Function()>((ref) {
  return () => BackupKdfParams.generate();
});

/// Real Google Drive backup & restore controller.
class DriveBackupController extends Notifier<DriveBackupState> {
  /// Number of most recent backups kept in Drive; older ones are pruned.
  static const int retainCount = BackupService.retainCount;
  static const int minPassphraseLength = 8;

  BackupRemote get _remote => ref.read(backupRemoteProvider);
  FlutterSecureStorage get _storage => ref.read(backupSecureStorageProvider);
  BackupScheduler get _scheduler => ref.read(backupSchedulerProvider);

  BackupService _service() => BackupService(
        snapshot: ref.read(backupSnapshotServiceProvider),
        remote: _remote,
        storage: _storage,
      );

  @override
  DriveBackupState build() {
    final supported = ref.read(backupRemoteProvider).isSupported;
    // Let a nightly run that WorkManager executes on the main isolate reuse
    // the app's live database connection.
    BackgroundBackupRunner.foregroundDatabase = ref.read(appDatabaseProvider);
    Future.microtask(() => refresh(syncSchedule: true));
    return DriveBackupState(isSupported: supported);
  }

  /// Reloads persisted status (e.g. after a nightly run in the background).
  /// With [syncSchedule], also makes sure the WorkManager job matches settings.
  Future<void> refresh({bool syncSchedule = false}) async {
    try {
      final keys = [
        BackupKeys.connected,
        BackupKeys.email,
        BackupKeys.kek,
        BackupKeys.lastAt,
        BackupKeys.lastSize,
        BackupKeys.autoEnabled,
        BackupKeys.autoTime,
        BackupKeys.autoWifiOnly,
        BackupKeys.autoLastRunAt,
        BackupKeys.autoLastOutcome,
        BackupKeys.autoError,
      ];
      final v = await Future.wait(keys.map((k) => _storage.read(key: k)));
      DateTime? parse(String? raw) => raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
      state = state.copyWith(
        isLoaded: true,
        isConnected: v[0] == 'true',
        accountEmail: () => v[1],
        hasPassphrase: v[2] != null,
        lastBackupAt: () => parse(v[3]),
        lastBackupSizeBytes: () => v[4] != null ? int.tryParse(v[4]!) : null,
        autoEnabled: v[5] != 'false',
        autoTime: DriveBackupState.decodeTime(v[6]) ?? DriveBackupState.defaultAutoTime,
        autoWifiOnly: v[7] != 'false',
        autoLastRunAt: () => parse(v[8]),
        autoLastOutcome: () => BackupRunOutcome.values.where((o) => o.name == v[9]).firstOrNull,
        autoError: () => v[10],
      );
      if (syncSchedule) await _syncSchedule(reset: false);
    } catch (e) {
      debugPrint('[DriveBackup] Failed to load status: $e');
      state = state.copyWith(isLoaded: true);
    }
  }

  void clearError() => state = state.copyWith(errorMessage: () => null);

  // ---------------------------------------------------------------------------
  // NIGHTLY SCHEDULE
  // ---------------------------------------------------------------------------

  Future<void> _syncSchedule({required bool reset}) async {
    try {
      if (state.isAutoActive) {
        await _scheduler.schedule(time: state.autoTime, wifiOnly: state.autoWifiOnly, reset: reset);
      } else {
        await _scheduler.cancel();
      }
    } catch (e) {
      debugPrint('[DriveBackup] Scheduling failed: $e');
    }
  }

  Future<void> setAutoEnabled(bool enabled) async {
    await _storage.write(key: BackupKeys.autoEnabled, value: enabled.toString());
    state = state.copyWith(autoEnabled: enabled);
    await _syncSchedule(reset: true);
  }

  Future<void> setAutoTime(TimeOfDay time) async {
    await _storage.write(key: BackupKeys.autoTime, value: DriveBackupState.encodeTime(time));
    state = state.copyWith(autoTime: time);
    await _syncSchedule(reset: true);
  }

  Future<void> setAutoWifiOnly(bool wifiOnly) async {
    await _storage.write(key: BackupKeys.autoWifiOnly, value: wifiOnly.toString());
    state = state.copyWith(autoWifiOnly: wifiOnly);
    await _syncSchedule(reset: true);
  }

  // ---------------------------------------------------------------------------
  // CONNECTION
  // ---------------------------------------------------------------------------

  Future<bool> connect() async {
    if (state.isBusy) return false;
    state = state.copyWith(activity: DriveBackupActivity.connecting, errorMessage: () => null);
    try {
      final email = await _remote.connect();
      await _storage.write(key: BackupKeys.connected, value: 'true');
      if (email != null) await _storage.write(key: BackupKeys.email, value: email);
      await _storage.delete(key: BackupKeys.autoError);
      state = state.copyWith(
        isConnected: true,
        accountEmail: () => email,
        autoError: () => null,
        activity: DriveBackupActivity.idle,
      );
      await _syncSchedule(reset: false);
      return true;
    } catch (e) {
      state = state.copyWith(activity: DriveBackupActivity.idle, errorMessage: () => _friendly(e));
      return false;
    }
  }

  Future<void> disconnect() async {
    await _remote.disconnect();
    await _storage.delete(key: BackupKeys.connected);
    await _storage.delete(key: BackupKeys.email);
    state = state.copyWith(isConnected: false, accountEmail: () => null, errorMessage: () => null);
    await _syncSchedule(reset: false);
  }

  // ---------------------------------------------------------------------------
  // RECOVERY PASSPHRASE
  // ---------------------------------------------------------------------------

  /// Sets (or replaces) the recovery passphrase used for all future backups.
  /// Existing backups remain locked with the passphrase they were made with.
  Future<bool> setPassphrase(String passphrase) async {
    if (passphrase.length < minPassphraseLength) {
      state = state.copyWith(
        errorMessage: () => 'Use at least $minPassphraseLength characters.',
      );
      return false;
    }
    state = state.copyWith(activity: DriveBackupActivity.settingPassphrase, errorMessage: () => null);
    try {
      final params = ref.read(backupKdfFactoryProvider)();
      final kek = await BackupCrypto.deriveKey(passphrase, params);
      await _storeKek(kek, params);
      // A new passphrase means the next backup must upload even if data is unchanged.
      await _storage.delete(key: BackupKeys.lastHash);
      state = state.copyWith(hasPassphrase: true, activity: DriveBackupActivity.idle);
      await _syncSchedule(reset: false);
      return true;
    } catch (e) {
      state = state.copyWith(activity: DriveBackupActivity.idle, errorMessage: () => _friendly(e));
      return false;
    }
  }

  Future<void> _storeKek(Uint8List kek, BackupKdfParams params) async {
    await _storage.write(key: BackupKeys.kek, value: base64Encode(kek));
    await _storage.write(key: BackupKeys.kdf, value: jsonEncode(params.toJson()));
  }

  // ---------------------------------------------------------------------------
  // BACKUP
  // ---------------------------------------------------------------------------

  Future<bool> backupNow() async {
    if (state.isBusy) return false;
    state = state.copyWith(activity: DriveBackupActivity.backingUp, errorMessage: () => null);
    try {
      final result = await _service().run(automatic: false);
      await _storage.delete(key: BackupKeys.autoError);
      state = state.copyWith(
        lastBackupAt: () => result.at,
        lastBackupSizeBytes: () => result.sizeBytes ?? state.lastBackupSizeBytes,
        autoError: () => null,
        activity: DriveBackupActivity.idle,
      );
      return true;
    } catch (e) {
      state = state.copyWith(activity: DriveBackupActivity.idle, errorMessage: () => _friendly(e));
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // RESTORE
  // ---------------------------------------------------------------------------

  /// Lists backups in Drive, prompting for Drive access if needed.
  Future<List<RemoteBackupFile>> listBackups() async {
    if (!state.isConnected) {
      final ok = await connect();
      if (!ok) throw BackupAuthException(state.errorMessage ?? 'Google Drive is not connected.');
    }
    return _remote.list();
  }

  /// Downloads and decrypts a backup without touching local data.
  Future<OpenedBackup> openBackup(String fileId, String passphrase) async {
    final bytes = await _remote.download(fileId);
    return BackupCrypto.open(envelopeBytes: bytes, passphrase: passphrase);
  }

  /// Replaces local data with [opened] and re-syncs from the server.
  Future<bool> restore(OpenedBackup opened) async {
    if (state.isBusy) return false;
    state = state.copyWith(activity: DriveBackupActivity.restoring, errorMessage: () => null);
    try {
      await ref.read(backupSnapshotServiceProvider).restore(opened.payload);

      // Keep backing up with the same passphrase on this device.
      await _storeKek(opened.kek, opened.envelope.kdf);
      await _storage.write(key: BackupKeys.lastAt, value: opened.envelope.createdAt.toUtc().toIso8601String());
      await _storage.delete(key: BackupKeys.lastHash);

      final homeIds = BackupSnapshotService.homeIdsIn(opened.payload);
      if (homeIds.isNotEmpty) {
        final current = ref.read(activeHomeIdProvider);
        if (current == null || !homeIds.contains(current)) {
          ref.read(activeHomeIdProvider.notifier).setActiveHome(homeIds.first);
        }
        final engine = ref.read(syncEngineProvider);
        for (final id in homeIds) {
          engine.resyncAfterRestore(id).ignore();
        }
      }

      state = state.copyWith(
        hasPassphrase: true,
        lastBackupAt: () => opened.envelope.createdAt.toLocal(),
        activity: DriveBackupActivity.idle,
      );
      await _syncSchedule(reset: false);
      return true;
    } catch (e) {
      state = state.copyWith(activity: DriveBackupActivity.idle, errorMessage: () => _friendly(e));
      return false;
    }
  }

  static String _friendly(Object e) {
    if (e is BackupAuthException ||
        e is BackupFormatException ||
        e is BackupWrongPassphraseException) {
      return e.toString();
    }
    final text = e.toString();
    if (text.contains('SocketException') || text.contains('ClientException')) {
      return 'No connection to Google Drive. Check your internet and try again.';
    }
    return 'Something went wrong: $text';
  }
}

final driveBackupProvider =
    NotifierProvider<DriveBackupController, DriveBackupState>(DriveBackupController.new);
