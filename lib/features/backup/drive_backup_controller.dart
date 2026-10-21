import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../changelog/changelog_models.dart';
import 'backup_crypto.dart';
import 'backup_snapshot_service.dart';
import 'drive_backup_remote.dart';

/// What the backup system is busy doing (drives button spinners).
enum DriveBackupActivity { idle, connecting, settingPassphrase, backingUp, restoring }

class DriveBackupState {
  final bool isSupported;
  final bool isLoaded;
  final bool isConnected;
  final String? accountEmail;
  final bool hasPassphrase;
  final DateTime? lastBackupAt;
  final int? lastBackupSizeBytes;
  final DriveBackupActivity activity;
  final String? errorMessage;

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
  });

  bool get isBusy => activity != DriveBackupActivity.idle;

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
    );
  }
}

// --- DEPENDENCY PROVIDERS (overridable in tests) ---

final backupRemoteProvider = Provider<BackupRemote>((ref) => GoogleDriveBackupRemote());

/// Hardware-backed storage for the passphrase-derived key and backup status.
final backupSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final backupSnapshotServiceProvider = Provider<BackupSnapshotService>((ref) {
  return BackupSnapshotService(
    db: ref.watch(appDatabaseProvider),
    keyStore: ref.watch(homeKeyStoreProvider),
  );
});

/// Argon2id cost profile for new passphrases (lowered in tests).
final backupKdfFactoryProvider = Provider<BackupKdfParams Function()>((ref) {
  return () => BackupKdfParams.generate();
});

/// Real Google Drive backup & restore controller.
class DriveBackupController extends Notifier<DriveBackupState> {
  /// Number of most recent backups kept in Drive; older ones are pruned.
  static const int retainCount = 10;
  static const int minPassphraseLength = 8;

  static const _kKek = 'cove_backup_kek';
  static const _kKdf = 'cove_backup_kdf';
  static const _kConnected = 'cove_backup_connected';
  static const _kEmail = 'cove_backup_email';
  static const _kLastAt = 'cove_backup_last_at';
  static const _kLastSize = 'cove_backup_last_size';

  BackupRemote get _remote => ref.read(backupRemoteProvider);
  FlutterSecureStorage get _storage => ref.read(backupSecureStorageProvider);

  @override
  DriveBackupState build() {
    final supported = ref.read(backupRemoteProvider).isSupported;
    Future.microtask(_load);
    return DriveBackupState(isSupported: supported);
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        _storage.read(key: _kConnected),
        _storage.read(key: _kEmail),
        _storage.read(key: _kKek),
        _storage.read(key: _kLastAt),
        _storage.read(key: _kLastSize),
      ]);
      state = state.copyWith(
        isLoaded: true,
        isConnected: values[0] == 'true',
        accountEmail: () => values[1],
        hasPassphrase: values[2] != null,
        lastBackupAt: () => values[3] != null ? DateTime.tryParse(values[3]!)?.toLocal() : null,
        lastBackupSizeBytes: () => values[4] != null ? int.tryParse(values[4]!) : null,
      );
    } catch (e) {
      debugPrint('[DriveBackup] Failed to load status: $e');
      state = state.copyWith(isLoaded: true);
    }
  }

  void clearError() => state = state.copyWith(errorMessage: () => null);

  // ---------------------------------------------------------------------------
  // CONNECTION
  // ---------------------------------------------------------------------------

  Future<bool> connect() async {
    if (state.isBusy) return false;
    state = state.copyWith(activity: DriveBackupActivity.connecting, errorMessage: () => null);
    try {
      final email = await _remote.connect();
      await _storage.write(key: _kConnected, value: 'true');
      if (email != null) await _storage.write(key: _kEmail, value: email);
      state = state.copyWith(
        isConnected: true,
        accountEmail: () => email,
        activity: DriveBackupActivity.idle,
      );
      return true;
    } catch (e) {
      state = state.copyWith(activity: DriveBackupActivity.idle, errorMessage: () => _friendly(e));
      return false;
    }
  }

  Future<void> disconnect() async {
    await _remote.disconnect();
    await _storage.delete(key: _kConnected);
    await _storage.delete(key: _kEmail);
    state = state.copyWith(isConnected: false, accountEmail: () => null, errorMessage: () => null);
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
      state = state.copyWith(hasPassphrase: true, activity: DriveBackupActivity.idle);
      return true;
    } catch (e) {
      state = state.copyWith(activity: DriveBackupActivity.idle, errorMessage: () => _friendly(e));
      return false;
    }
  }

  Future<void> _storeKek(Uint8List kek, BackupKdfParams params) async {
    await _storage.write(key: _kKek, value: base64Encode(kek));
    await _storage.write(key: _kKdf, value: jsonEncode(params.toJson()));
  }

  Future<(Uint8List, BackupKdfParams)?> _readKek() async {
    final kek = await _storage.read(key: _kKek);
    final kdf = await _storage.read(key: _kKdf);
    if (kek == null || kdf == null) return null;
    return (
      base64Decode(kek),
      BackupKdfParams.fromJson(jsonDecode(kdf) as Map<String, dynamic>),
    );
  }

  // ---------------------------------------------------------------------------
  // BACKUP
  // ---------------------------------------------------------------------------

  Future<bool> backupNow() async {
    if (state.isBusy) return false;
    state = state.copyWith(activity: DriveBackupActivity.backingUp, errorMessage: () => null);
    try {
      final keyMaterial = await _readKek();
      if (keyMaterial == null) {
        throw const BackupFormatException('Set a recovery passphrase first.');
      }
      final (kek, kdf) = keyMaterial;

      final snapshot = ref.read(backupSnapshotServiceProvider);
      final payload = await snapshot.export();
      final now = DateTime.now();
      final bytes = BackupCrypto.seal(
        payload: payload,
        kek: kek,
        kdf: kdf,
        schemaVersion: snapshot.db.schemaVersion,
        appVersion: kCoveCurrentAppVersion,
        createdAt: now,
      );

      await _remote.upload(bytes, createdAt: now, deviceLabel: _deviceLabel());
      await _pruneOldBackups();

      await _storage.write(key: _kLastAt, value: now.toUtc().toIso8601String());
      await _storage.write(key: _kLastSize, value: bytes.length.toString());
      state = state.copyWith(
        lastBackupAt: () => now,
        lastBackupSizeBytes: () => bytes.length,
        activity: DriveBackupActivity.idle,
      );
      return true;
    } catch (e) {
      state = state.copyWith(activity: DriveBackupActivity.idle, errorMessage: () => _friendly(e));
      return false;
    }
  }

  Future<void> _pruneOldBackups() async {
    try {
      final files = await _remote.list();
      for (final stale in files.skip(retainCount)) {
        await _remote.delete(stale.id);
      }
    } catch (e) {
      debugPrint('[DriveBackup] Prune skipped: $e');
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
      await _storage.write(key: _kLastAt, value: opened.envelope.createdAt.toUtc().toIso8601String());

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
      return true;
    } catch (e) {
      state = state.copyWith(activity: DriveBackupActivity.idle, errorMessage: () => _friendly(e));
      return false;
    }
  }

  static String _deviceLabel() => kIsWeb ? 'web' : defaultTargetPlatform.name;

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
