import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../sync/db/app_database.dart';
import '../../sync/key_management/home_key_store.dart';
import 'backup_crypto.dart';

/// Summary of what a snapshot contains, shown before confirming a restore.
class BackupSnapshotSummary {
  final List<String> homeNames;
  final int totalRows;
  final int homeKeyCount;

  const BackupSnapshotSummary({
    required this.homeNames,
    required this.totalRows,
    required this.homeKeyCount,
  });
}

/// Captures and restores the complete on-device state of Cove:
/// 1. Every Drift/SQLite table (generic raw rows, schema-tolerant)
/// 2. Home symmetric encryption keys (from [HomeKeyStore])
/// 3. Small `cove_*` preferences kept in secure storage (tab order, custom categories…)
///
/// The returned payload is plaintext and must only ever leave the device
/// sealed inside a [BackupCrypto] envelope.
class BackupSnapshotService {
  static const int payloadVersion = 1;

  /// Secure-storage keys that are captured separately or must never be copied.
  static const List<String> _excludedPrefPrefixes = [
    'cove_home_key_',
    'cove_registered_home_ids',
    'cove_backup_',
  ];

  final AppDatabase db;
  final HomeKeyStore keyStore;
  final FlutterSecureStorage prefsStorage;

  BackupSnapshotService({
    required this.db,
    required this.keyStore,
    FlutterSecureStorage? prefsStorage,
  }) : prefsStorage = prefsStorage ?? const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // EXPORT
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> export() async {
    final tables = <String, dynamic>{};

    // Read every table inside one transaction for a consistent point-in-time view.
    await db.transaction(() async {
      for (final table in db.allTables) {
        final name = table.actualTableName;
        final rows = await db.customSelect('SELECT * FROM "$name"').get();
        tables[name] = rows.map((r) => _encodeRow(r.data)).toList();
      }
    });

    // Home keys: union of registered ids and every home present in the DB.
    final homeIds = <String>{
      ...await keyStore.getAllHomeIds(),
      ...(await db.select(db.localHomes).get()).map((h) => h.id),
    };
    final homeKeys = <String, String>{};
    for (final id in homeIds) {
      final key = await keyStore.getKey(id);
      if (key != null) homeKeys[id] = base64Encode(key);
    }

    final prefs = <String, String>{};
    try {
      final all = await prefsStorage.readAll();
      all.forEach((k, v) {
        if (k.startsWith('cove_') && !_excludedPrefPrefixes.any(k.startsWith)) {
          prefs[k] = v;
        }
      });
    } catch (_) {
      // Preferences are best-effort; the database and keys are what matter.
    }

    return {
      'payloadVersion': payloadVersion,
      'schemaVersion': db.schemaVersion,
      'tables': tables,
      'homeKeys': homeKeys,
      'prefs': prefs,
    };
  }

  // ---------------------------------------------------------------------------
  // INSPECT
  // ---------------------------------------------------------------------------

  static BackupSnapshotSummary summarize(Map<String, dynamic> payload) {
    final tables = (payload['tables'] as Map?)?.cast<String, dynamic>() ?? const {};
    var total = 0;
    for (final rows in tables.values) {
      total += (rows as List).length;
    }
    final homes = (tables['local_homes'] as List?) ?? const [];
    return BackupSnapshotSummary(
      homeNames: homes
          .map((h) => (h as Map)['name']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList(),
      totalRows: total,
      homeKeyCount: ((payload['homeKeys'] as Map?) ?? const {}).length,
    );
  }

  /// Home ids contained in a payload (used to re-sync after restore).
  static List<String> homeIdsIn(Map<String, dynamic> payload) {
    final tables = (payload['tables'] as Map?)?.cast<String, dynamic>() ?? const {};
    final homes = (tables['local_homes'] as List?) ?? const [];
    return homes.map((h) => (h as Map)['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
  }

  // ---------------------------------------------------------------------------
  // RESTORE
  // ---------------------------------------------------------------------------

  /// Replaces all local data with the snapshot. Runs atomically: if anything
  /// fails, the database is left exactly as it was.
  Future<void> restore(Map<String, dynamic> payload) async {
    final payloadSchema = (payload['schemaVersion'] as num?)?.toInt() ?? 0;
    if (payloadSchema > db.schemaVersion) {
      throw const BackupFormatException(
        'This backup was made by a newer version of Cove. Update the app to restore it.',
      );
    }

    final tables = (payload['tables'] as Map?)?.cast<String, dynamic>();
    if (tables == null) {
      throw const BackupFormatException('This backup file is damaged or incomplete.');
    }

    await db.transaction(() async {
      for (final table in db.allTables) {
        final name = table.actualTableName;
        await db.customStatement('DELETE FROM "$name"');

        final rows = tables[name] as List?;
        if (rows == null || rows.isEmpty) continue;

        // Only write columns that exist in the current schema; columns added
        // after the backup was taken fall back to their defaults.
        final currentColumns = table.$columns.map((c) => c.name).toSet();
        for (final raw in rows) {
          final row = (raw as Map).cast<String, dynamic>();
          final cols = row.keys.where(currentColumns.contains).toList();
          if (cols.isEmpty) continue;
          final placeholders = List.filled(cols.length, '?').join(', ');
          final colList = cols.map((c) => '"$c"').join(', ');
          await db.customStatement(
            'INSERT OR REPLACE INTO "$name" ($colList) VALUES ($placeholders)',
            cols.map((c) => _decodeValue(row[c])).toList(),
          );
        }
      }
    });

    // Raw statements bypass Drift's change tracking; wake every stream query.
    db.markTablesUpdated(db.allTables);

    final homeKeys = (payload['homeKeys'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final entry in homeKeys.entries) {
      await keyStore.saveKey(entry.key, base64Decode(entry.value as String));
    }

    final prefs = (payload['prefs'] as Map?)?.cast<String, dynamic>() ?? const {};
    for (final entry in prefs.entries) {
      if (_excludedPrefPrefixes.any(entry.key.startsWith)) continue;
      try {
        await prefsStorage.write(key: entry.key, value: entry.value.toString());
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // VALUE ENCODING (SQLite raw values <-> JSON)
  // ---------------------------------------------------------------------------

  static const String _blobTag = r'$b64';

  static Map<String, dynamic> _encodeRow(Map<String, Object?> row) {
    return row.map((k, v) => MapEntry(k, v is Uint8List ? {_blobTag: base64Encode(v)} : v));
  }

  static Object? _decodeValue(Object? v) {
    if (v is Map && v.containsKey(_blobTag)) {
      return base64Decode(v[_blobTag] as String);
    }
    return v;
  }
}
