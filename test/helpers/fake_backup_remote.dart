import 'dart:typed_data';

import 'package:cove/features/backup/backup_scheduler.dart';
import 'package:cove/features/backup/drive_backup_remote.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// In-memory stand-in for Google Drive's appDataFolder.
class FakeBackupRemote implements BackupRemote {
  final Map<String, (RemoteBackupFile, Uint8List)> files = {};
  bool supported;
  String? email;
  Object? connectError;
  Object? uploadError;
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
    if (uploadError != null) throw uploadError!;
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

/// Records scheduling calls instead of talking to WorkManager.
class FakeBackupScheduler implements BackupScheduler {
  bool scheduled = false;
  TimeOfDay? time;
  bool? wifiOnly;
  int scheduleCalls = 0;
  int resetCalls = 0;
  int cancelCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedule({required TimeOfDay time, required bool wifiOnly, bool reset = false}) async {
    scheduleCalls++;
    if (reset) resetCalls++;
    scheduled = true;
    this.time = time;
    this.wifiOnly = wifiOnly;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    scheduled = false;
  }
}
