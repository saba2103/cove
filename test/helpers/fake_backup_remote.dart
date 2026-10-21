import 'dart:typed_data';

import 'package:cove/features/backup/drive_backup_remote.dart';

/// In-memory stand-in for Google Drive's appDataFolder.
class FakeBackupRemote implements BackupRemote {
  final Map<String, (RemoteBackupFile, Uint8List)> files = {};
  bool supported;
  String? email;
  Object? connectError;
  int connectCalls = 0;
  int _counter = 0;

  FakeBackupRemote({this.supported = true, this.email = 'alex@gmail.com'});

  @override
  bool get isSupported => supported;

  @override
  Future<String?> connect() async {
    connectCalls++;
    if (connectError != null) throw connectError!;
    return email;
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<RemoteBackupFile> upload(Uint8List bytes, {required DateTime createdAt, String? deviceLabel}) async {
    final id = 'file-${_counter++}';
    // Guarantee strictly increasing timestamps for ordering.
    final stamped = createdAt.add(Duration(milliseconds: _counter));
    final meta = RemoteBackupFile(id: id, createdAt: stamped, sizeBytes: bytes.length, deviceLabel: deviceLabel);
    files[id] = (meta, Uint8List.fromList(bytes));
    return meta;
  }

  @override
  Future<List<RemoteBackupFile>> list() async {
    return files.values.map((e) => e.$1).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Uint8List> download(String fileId) async {
    final entry = files[fileId];
    if (entry == null) throw StateError('No such file $fileId');
    return entry.$2;
  }

  @override
  Future<void> delete(String fileId) async {
    files.remove(fileId);
  }
}
