import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Metadata for one backup file stored remotely.
class RemoteBackupFile {
  final String id;
  final DateTime createdAt;
  final int sizeBytes;
  final String? deviceLabel;

  const RemoteBackupFile({
    required this.id,
    required this.createdAt,
    required this.sizeBytes,
    this.deviceLabel,
  });
}

/// Raised when the user cancels Google authorization or it is unavailable.
class BackupAuthException implements Exception {
  final String message;
  const BackupAuthException(this.message);
  @override
  String toString() => message;
}

/// Storage backend for encrypted backups. Abstracted so tests can use a fake.
abstract class BackupRemote {
  /// Whether this platform supports the remote at all.
  bool get isSupported;

  /// Interactive authorization (must be triggered by a user tap).
  /// Returns the connected account email when it can be determined.
  Future<String?> connect();

  /// Revokes local authorization.
  Future<void> disconnect();

  Future<RemoteBackupFile> upload(Uint8List bytes, {required DateTime createdAt, String? deviceLabel});

  /// Newest first.
  Future<List<RemoteBackupFile>> list();

  Future<Uint8List> download(String fileId);

  Future<void> delete(String fileId);
}

/// Google Drive `appDataFolder` implementation.
///
/// Uses the `drive.appdata` scope: a hidden, app-private folder in the user's
/// own Drive. Cove cannot see any other Drive files, and the user cannot
/// accidentally edit backups. Only authorization (not Google authentication)
/// is requested, so no server client id is required.
class GoogleDriveBackupRemote implements BackupRemote {
  static const List<String> scopes = [drive.DriveApi.driveAppdataScope];
  static const String _fileFields = 'id,name,createdTime,size,appProperties';

  static Future<void>? _initFuture;

  @override
  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance.initialize();
  }

  /// Returns a token silently when possible, otherwise (if [interactive])
  /// shows the Google consent sheet.
  Future<String> _accessToken({bool interactive = false}) async {
    if (!isSupported) {
      throw const BackupAuthException('Google Drive backup is available in the Android app.');
    }
    await _ensureInitialized();
    final client = GoogleSignIn.instance.authorizationClient;
    try {
      final silent = await client.authorizationForScopes(scopes);
      if (silent != null) return silent.accessToken;
      if (!interactive) {
        throw const BackupAuthException('Reconnect Google Drive to continue.');
      }
      final granted = await client.authorizeScopes(scopes);
      return granted.accessToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const BackupAuthException('Google Drive access was not granted.');
      }
      throw BackupAuthException(
        'Google Drive is not available: ${e.description ?? e.code.name}',
      );
    }
  }

  Future<T> _withApi<T>(Future<T> Function(drive.DriveApi api) action, {bool interactive = false}) async {
    var token = await _accessToken(interactive: interactive);
    for (var attempt = 0; attempt < 2; attempt++) {
      final httpClient = _BearerClient(token);
      try {
        return await action(drive.DriveApi(httpClient));
      } on drive.DetailedApiRequestError catch (e) {
        // Stale cached token: clear it and retry once with a fresh one.
        if (e.status == 401 && attempt == 0) {
          await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: token);
          token = await _accessToken(interactive: interactive);
          continue;
        }
        rethrow;
      } finally {
        httpClient.close();
      }
    }
    throw const BackupAuthException('Reconnect Google Drive to continue.');
  }

  @override
  Future<String?> connect() {
    return _withApi((api) async {
      try {
        final about = await api.about.get($fields: 'user(emailAddress)');
        return about.user?.emailAddress;
      } catch (_) {
        return null; // Authorized, but account email is not exposed for this scope.
      }
    }, interactive: true);
  }

  @override
  Future<void> disconnect() async {
    if (!isSupported) return;
    await _ensureInitialized();
    try {
      final authz = await GoogleSignIn.instance.authorizationClient.authorizationForScopes(scopes);
      if (authz != null) {
        await GoogleSignIn.instance.authorizationClient.clearAuthorizationToken(accessToken: authz.accessToken);
      }
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}
  }

  @override
  Future<RemoteBackupFile> upload(Uint8List bytes, {required DateTime createdAt, String? deviceLabel}) {
    return _withApi((api) async {
      final stamp = createdAt.toUtc().toIso8601String().replaceAll(':', '-');
      final file = drive.File()
        ..name = 'cove-backup-$stamp.cove'
        ..parents = ['appDataFolder']
        ..mimeType = 'application/octet-stream'
        ..appProperties = {
          'createdAt': createdAt.toUtc().toIso8601String(),
          'device': ?deviceLabel,
        };
      final created = await api.files.create(
        file,
        uploadMedia: drive.Media(Stream<List<int>>.value(bytes), bytes.length),
        $fields: _fileFields,
      );
      return _toRemote(created) ??
          RemoteBackupFile(id: created.id ?? '', createdAt: createdAt, sizeBytes: bytes.length);
    });
  }

  @override
  Future<List<RemoteBackupFile>> list() {
    return _withApi((api) async {
      final result = await api.files.list(
        spaces: 'appDataFolder',
        orderBy: 'createdTime desc',
        pageSize: 100,
        $fields: 'files($_fileFields)',
      );
      return (result.files ?? const <drive.File>[])
          .map(_toRemote)
          .whereType<RemoteBackupFile>()
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  @override
  Future<Uint8List> download(String fileId) {
    return _withApi((api) async {
      final media = await api.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final builder = BytesBuilder(copy: false);
      await for (final chunk in media.stream) {
        builder.add(chunk);
      }
      return builder.takeBytes();
    });
  }

  @override
  Future<void> delete(String fileId) {
    return _withApi((api) => api.files.delete(fileId));
  }

  static RemoteBackupFile? _toRemote(drive.File f) {
    final id = f.id;
    if (id == null) return null;
    final created = DateTime.tryParse(f.appProperties?['createdAt'] ?? '') ??
        f.createdTime ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return RemoteBackupFile(
      id: id,
      createdAt: created.toLocal(),
      sizeBytes: int.tryParse(f.size ?? '') ?? 0,
      deviceLabel: f.appProperties?['device'],
    );
  }
}

class _BearerClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();

  _BearerClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
