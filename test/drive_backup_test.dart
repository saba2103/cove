import 'dart:convert';
import 'dart:typed_data';

import 'package:cove/features/backup/backup_crypto.dart';
import 'package:cove/features/backup/backup_scheduler.dart';
import 'package:cove/features/backup/backup_service.dart';
import 'package:cove/features/backup/drive_backup_remote.dart';
import 'package:cove/features/backup/backup_snapshot_service.dart';
import 'package:cove/features/backup/drive_backup_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_backup_remote.dart';

/// Cheap Argon2id profile so tests stay fast (production uses 19 MiB / t=2).
BackupKdfParams fastKdf() => BackupKdfParams.generate(memoryKiB: 256, iterations: 1);

Uint8List homeKey(int seed) => Uint8List.fromList(List.generate(32, (i) => (i + seed) % 256));

Future<void> seedHome(AppDatabase db, {String id = 'home-1', String name = 'Haven'}) async {
  await db.into(db.localHomes).insert(LocalHomesCompanion.insert(
        id: id,
        name: name,
        createdAt: DateTime.utc(2026, 9, 1),
        createdBy: 'user-alex',
      ));
  await db.into(db.localExpenses).insert(LocalExpensesCompanion.insert(
        id: 'exp-$id',
        homeId: id,
        title: 'Groceries',
        amount: 1234.5,
        paidBy: 'user-alex',
        expenseDate: DateTime.utc(2026, 10, 1),
        createdAt: DateTime.utc(2026, 10, 1),
      ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  // ===========================================================================
  group('BackupCrypto', () {
    final payload = {
      'tables': {'local_homes': [{'id': 'h1', 'name': 'Haven'}]},
      'homeKeys': {'h1': base64Encode(homeKey(1))},
    };

    Future<(Uint8List, BackupKdfParams)> kek(String passphrase) async {
      final params = fastKdf();
      return (await BackupCrypto.deriveKey(passphrase, params), params);
    }

    test('seal → open round-trips the payload with the right passphrase', () async {
      final (key, params) = await kek('correct horse battery');
      final bytes = BackupCrypto.seal(
        payload: payload,
        kek: key,
        kdf: params,
        schemaVersion: 11,
        appVersion: '1.0.0-alpha.1',
      );

      final opened = await BackupCrypto.open(envelopeBytes: bytes, passphrase: 'correct horse battery');
      expect(opened.payload, payload);
      expect(opened.kek, key);
      expect(opened.envelope.schemaVersion, 11);
    });

    test('the envelope never contains plaintext data or keys', () async {
      final (key, params) = await kek('correct horse battery');
      final bytes = BackupCrypto.seal(
        payload: payload, kek: key, kdf: params, schemaVersion: 11, appVersion: 'x');
      final text = utf8.decode(bytes);
      expect(text.contains('Haven'), isFalse);
      expect(text.contains(base64Encode(homeKey(1))), isFalse);
    });

    test('wrong passphrase is rejected with BackupWrongPassphraseException', () async {
      final (key, params) = await kek('correct horse battery');
      final bytes = BackupCrypto.seal(
        payload: payload, kek: key, kdf: params, schemaVersion: 11, appVersion: 'x');

      expect(
        () => BackupCrypto.open(envelopeBytes: bytes, passphrase: 'wrong passphrase'),
        throwsA(isA<BackupWrongPassphraseException>()),
      );
    });

    test('tampered ciphertext is detected', () async {
      final (key, params) = await kek('correct horse battery');
      final bytes = BackupCrypto.seal(
        payload: payload, kek: key, kdf: params, schemaVersion: 11, appVersion: 'x');
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final ct = base64Decode(json['data']['ct'] as String);
      ct[ct.length ~/ 2] ^= 0xFF;
      json['data']['ct'] = base64Encode(ct);
      final tampered = Uint8List.fromList(utf8.encode(jsonEncode(json)));

      expect(
        () => BackupCrypto.open(envelopeBytes: tampered, passphrase: 'correct horse battery'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('non-backup files and newer formats are rejected', () {
      expect(
        () => BackupEnvelope.fromBytes(Uint8List.fromList(utf8.encode('hello'))),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        () => BackupEnvelope.fromBytes(Uint8List.fromList(utf8.encode(jsonEncode({'format': 'cove-backup', 'v': 99})))),
        throwsA(isA<BackupFormatException>().having((e) => e.message, 'message', contains('newer version'))),
      );
    });
  });

  // ===========================================================================
  group('BackupSnapshotService', () {
    late AppDatabase source;
    late AppDatabase target;

    setUp(() {
      source = AppDatabase(NativeDatabase.memory());
      target = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await source.close();
      await target.close();
    });

    test('export → restore reproduces every row, home key and pref on a fresh device', () async {
      await seedHome(source);
      final sourceKeys = HomeKeyStore();
      await sourceKeys.saveKey('home-1', homeKey(7));
      const prefs = FlutterSecureStorage();
      await prefs.write(key: 'cove_custom_expense_categories_v1', value: '["Pets"]');
      await prefs.write(key: 'unrelated_key', value: 'ignored');

      final payload = await BackupSnapshotService(db: source, keyStore: sourceKeys).export();
      expect((payload['homeKeys'] as Map).keys, ['home-1']);
      expect((payload['prefs'] as Map).containsKey('unrelated_key'), isFalse);
      expect((payload['prefs'] as Map).keys.any((k) => k.toString().startsWith('cove_home_key_')), isFalse);

      // Simulate a brand-new phone.
      FlutterSecureStorage.setMockInitialValues({});
      final targetKeys = HomeKeyStore();
      await BackupSnapshotService(db: target, keyStore: targetKeys).restore(payload);

      final homes = await target.select(target.localHomes).get();
      expect(homes.single.name, 'Haven');
      expect(homes.single.createdAt.toUtc(), DateTime.utc(2026, 9, 1));
      final expenses = await target.select(target.localExpenses).get();
      expect(expenses.single.amount, 1234.5);
      expect(await targetKeys.getKey('home-1'), homeKey(7));
      expect(await const FlutterSecureStorage().read(key: 'cove_custom_expense_categories_v1'), '["Pets"]');
    });

    test('restore fully replaces existing local data', () async {
      await seedHome(source, id: 'home-1', name: 'Haven');
      await seedHome(target, id: 'home-stale', name: 'Stale');

      final payload = await BackupSnapshotService(db: source, keyStore: HomeKeyStore()).export();
      await BackupSnapshotService(db: target, keyStore: HomeKeyStore()).restore(payload);

      final homes = await target.select(target.localHomes).get();
      expect(homes.map((h) => h.id), ['home-1']);
      final expenses = await target.select(target.localExpenses).get();
      expect(expenses.map((e) => e.homeId), ['home-1']);
    });

    test('restore notifies reactive streams (AuthGate sees homes appear)', () async {
      await seedHome(source);
      final payload = await BackupSnapshotService(db: source, keyStore: HomeKeyStore()).export();

      final emissions = <int>[];
      final sub = target.watchHomes().listen((h) => emissions.add(h.length));
      await pumpEventQueue();
      await BackupSnapshotService(db: target, keyStore: HomeKeyStore()).restore(payload);
      await pumpEventQueue();
      await sub.cancel();

      expect(emissions.first, 0);
      expect(emissions.last, 1);
    });

    test('columns unknown to the current schema are ignored; newer schemas are refused', () async {
      await seedHome(source);
      final payload = await BackupSnapshotService(db: source, keyStore: HomeKeyStore()).export();
      ((payload['tables'] as Map)['local_homes'] as List).first['column_from_the_future'] = 'x';
      await BackupSnapshotService(db: target, keyStore: HomeKeyStore()).restore(payload);
      expect((await target.select(target.localHomes).get()).length, 1);

      payload['schemaVersion'] = target.schemaVersion + 1;
      expect(
        () => BackupSnapshotService(db: target, keyStore: HomeKeyStore()).restore(payload),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('summarize reports homes, row count and key count', () async {
      await seedHome(source);
      final keys = HomeKeyStore();
      await keys.saveKey('home-1', homeKey(1));
      final payload = await BackupSnapshotService(db: source, keyStore: keys).export();
      final summary = BackupSnapshotService.summarize(payload);
      expect(summary.homeNames, ['Haven']);
      expect(summary.totalRows, 2);
      expect(summary.homeKeyCount, 1);
      expect(BackupSnapshotService.homeIdsIn(payload), ['home-1']);
    });
  });

  // ===========================================================================
  group('DriveBackupController (end-to-end with fake Drive)', () {
    late FakeBackupRemote remote;
    late FakeBackupScheduler scheduler;

    ProviderContainer makeContainer(AppDatabase db) {
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        backupRemoteProvider.overrideWithValue(remote),
        backupSchedulerProvider.overrideWithValue(scheduler),
        backupKdfFactoryProvider.overrideWithValue(fastKdf),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    Future<DriveBackupController> ready(ProviderContainer c) async {
      c.read(driveBackupProvider);
      await pumpEventQueue();
      return c.read(driveBackupProvider.notifier);
    }

    setUp(() {
      remote = FakeBackupRemote();
      scheduler = FakeBackupScheduler();
    });

    test('starts honest: not connected, no passphrase, no backup', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = makeContainer(db);
      await ready(c);
      final s = c.read(driveBackupProvider);
      expect(s.isLoaded, isTrue);
      expect(s.isConnected, isFalse);
      expect(s.hasPassphrase, isFalse);
      expect(s.lastBackupAt, isNull);
    });

    test('backup requires a passphrase', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = makeContainer(db);
      final ctrl = await ready(c);
      await ctrl.connect();
      expect(await ctrl.backupNow(), isFalse);
      expect(c.read(driveBackupProvider).errorMessage, contains('passphrase'));
      expect(remote.files, isEmpty);
    });

    test('short passphrases are rejected', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = makeContainer(db);
      final ctrl = await ready(c);
      expect(await ctrl.setPassphrase('short'), isFalse);
      expect(c.read(driveBackupProvider).hasPassphrase, isFalse);
    });

    test('connect → passphrase → backup uploads an encrypted file and records real status', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedHome(db);
      final c = makeContainer(db);
      await c.read(homeKeyStoreProvider).saveKey('home-1', homeKey(3));
      final ctrl = await ready(c);

      expect(await ctrl.connect(), isTrue);
      expect(c.read(driveBackupProvider).accountEmail, 'alex@gmail.com');
      expect(await ctrl.setPassphrase('our cove passphrase'), isTrue);
      expect(await ctrl.backupNow(), isTrue);

      final s = c.read(driveBackupProvider);
      expect(remote.files.length, 1);
      expect(s.lastBackupAt, isNotNull);
      expect(s.lastBackupSizeBytes, remote.files.values.single.$2.length);
      expect(s.errorMessage, isNull);

      // Status survives an app restart.
      final c2 = makeContainer(db);
      await ready(c2);
      final s2 = c2.read(driveBackupProvider);
      expect(s2.isConnected, isTrue);
      expect(s2.hasPassphrase, isTrue);
      expect(s2.lastBackupAt, isNotNull);
    });

    test('keeps only the newest ${DriveBackupController.retainCount} backups', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = makeContainer(db);
      final ctrl = await ready(c);
      await ctrl.connect();
      await ctrl.setPassphrase('our cove passphrase');
      for (var i = 0; i < DriveBackupController.retainCount + 2; i++) {
        expect(await ctrl.backupNow(), isTrue);
      }
      expect(remote.files.length, DriveBackupController.retainCount);
      expect(remote.files.containsKey('file-0'), isFalse);
      expect(remote.files.containsKey('file-1'), isFalse);
    });

    test('new phone: restore with passphrase brings back data, home key and active home', () async {
      // Phone A makes a backup.
      final phoneA = AppDatabase(NativeDatabase.memory());
      addTearDown(phoneA.close);
      await seedHome(phoneA);
      final a = makeContainer(phoneA);
      await a.read(homeKeyStoreProvider).saveKey('home-1', homeKey(9));
      final ctrlA = await ready(a);
      await ctrlA.connect();
      await ctrlA.setPassphrase('our cove passphrase');
      await ctrlA.backupNow();

      // Phone B: empty database and empty keychain.
      FlutterSecureStorage.setMockInitialValues({});
      final phoneB = AppDatabase(NativeDatabase.memory());
      addTearDown(phoneB.close);
      final b = makeContainer(phoneB);
      final ctrlB = await ready(b);

      final backups = await ctrlB.listBackups();
      expect(backups.length, 1);

      await expectLater(
        ctrlB.openBackup(backups.first.id, 'not the passphrase'),
        throwsA(isA<BackupWrongPassphraseException>()),
      );

      final opened = await ctrlB.openBackup(backups.first.id, 'our cove passphrase');
      expect(BackupSnapshotService.summarize(opened.payload).homeNames, ['Haven']);
      expect(await ctrlB.restore(opened), isTrue);

      expect((await phoneB.select(phoneB.localHomes).get()).single.name, 'Haven');
      expect((await phoneB.select(phoneB.localExpenses).get()).single.amount, 1234.5);
      expect(await b.read(homeKeyStoreProvider).getKey('home-1'), homeKey(9));
      expect(b.read(activeHomeIdProvider), 'home-1');

      // Phone B can keep backing up with the same passphrase, no re-entry needed.
      final s = b.read(driveBackupProvider);
      expect(s.hasPassphrase, isTrue);
      expect(await ctrlB.backupNow(), isTrue);
      final newest = (await remote.list()).first;
      final reopened = await BackupCrypto.open(
        envelopeBytes: await remote.download(newest.id),
        passphrase: 'our cove passphrase',
      );
      expect(BackupSnapshotService.summarize(reopened.payload).homeNames, ['Haven']);
    });

    test('connection failures surface a readable error', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      remote.connectError = Exception('SocketException: Failed host lookup');
      final c = makeContainer(db);
      final ctrl = await ready(c);
      expect(await ctrl.connect(), isFalse);
      final s = c.read(driveBackupProvider);
      expect(s.isConnected, isFalse);
      expect(s.errorMessage, contains('No connection'));
      expect(s.isBusy, isFalse);
    });
  });

  // ===========================================================================
  group('Nightly automatic backup: BackupService', () {
    late AppDatabase db;
    late FakeBackupRemote remote;
    late DateTime now;
    const storage = FlutterSecureStorage();

    BackupService service() => BackupService(
          snapshot: BackupSnapshotService(db: db, keyStore: HomeKeyStore()),
          remote: remote,
          storage: storage,
          clock: () => now,
        );

    Future<void> configure() async {
      final params = fastKdf();
      final kek = await BackupCrypto.deriveKey('our cove passphrase', params);
      await storage.write(key: BackupKeys.kek, value: base64Encode(kek));
      await storage.write(key: BackupKeys.kdf, value: jsonEncode(params.toJson()));
      await storage.write(key: BackupKeys.connected, value: 'true');
    }

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      remote = FakeBackupRemote();
      now = DateTime(2026, 10, 22, 2, 0);
      await seedHome(db);
    });

    tearDown(() => db.close());

    test('does nothing until Drive and passphrase are set up', () async {
      final r = await service().run(automatic: true);
      expect(r.outcome, BackupRunOutcome.notConfigured);
      expect(remote.files, isEmpty);
      expect(await storage.read(key: BackupKeys.autoLastOutcome), 'notConfigured');
    });

    test('respects the user turning nightly backup off', () async {
      await configure();
      await storage.write(key: BackupKeys.autoEnabled, value: 'false');
      expect((await service().run(automatic: true)).outcome, BackupRunOutcome.notConfigured);
      expect(remote.files, isEmpty);
    });

    test('uploads when configured, then skips unchanged data the next night', () async {
      await configure();
      final first = await service().run(automatic: true);
      expect(first.outcome, BackupRunOutcome.uploaded);
      expect(remote.files.length, 1);

      now = now.add(const Duration(days: 1));
      final second = await service().run(automatic: true);
      expect(second.outcome, BackupRunOutcome.skippedUnchanged);
      expect(remote.files.length, 1, reason: 'identical data must not consume a retention slot');
      expect(DateTime.parse((await storage.read(key: BackupKeys.lastAt))!), now.toUtc());
    });

    test('uploads again the next night when data changed', () async {
      await configure();
      await service().run(automatic: true);
      await seedHome(db, id: 'home-2', name: 'Cabin');

      now = now.add(const Duration(days: 1));
      expect((await service().run(automatic: true)).outcome, BackupRunOutcome.uploaded);
      expect(remote.files.length, 2);
    });

    test('skips when a backup already ran in the last 20 hours', () async {
      await configure();
      await service().run(automatic: false); // manual backup in the evening
      await seedHome(db, id: 'home-2', name: 'Cabin');

      now = now.add(const Duration(hours: 5));
      expect((await service().run(automatic: true)).outcome, BackupRunOutcome.skippedRecent);
      expect(remote.files.length, 1);
    });

    test('lost Drive access pauses nightly backup with a visible message, without throwing', () async {
      await configure();
      remote.uploadError = const BackupAuthException('Reconnect Google Drive to continue.');
      final r = await service().run(automatic: true);
      expect(r.outcome, BackupRunOutcome.needsReconnect);
      expect(await storage.read(key: BackupKeys.autoError), contains('reconnect Google Drive'));

      // Once access is back, the message clears.
      remote.uploadError = null;
      now = now.add(const Duration(days: 1));
      expect((await service().run(automatic: true)).outcome, BackupRunOutcome.uploaded);
      expect(await storage.read(key: BackupKeys.autoError), isNull);
    });

    test('network failures are reported as retryable, never thrown', () async {
      await configure();
      remote.uploadError = Exception('SocketException: Network is unreachable');
      final r = await service().run(automatic: true);
      expect(r.outcome, BackupRunOutcome.failed);
      expect(r.isSuccess, isFalse);
    });

    test('manual backups always upload, even if nothing changed', () async {
      await configure();
      await service().run(automatic: false);
      await service().run(automatic: false);
      expect(remote.files.length, 2);
    });

    test('fingerprint ignores preference ordering', () {
      final a = {'schemaVersion': 11, 'tables': {}, 'homeKeys': {}, 'prefs': {'a': '1', 'b': '2'}};
      final b = {'schemaVersion': 11, 'tables': {}, 'homeKeys': {}, 'prefs': {'b': '2', 'a': '1'}};
      expect(BackupService.fingerprint(a), BackupService.fingerprint(b));
    });
  });

  // ===========================================================================
  group('Nightly automatic backup: scheduling', () {
    test('delayUntil targets the next occurrence of the chosen time', () {
      const twoAm = TimeOfDay(hour: 2, minute: 0);
      expect(BackupScheduler.delayUntil(twoAm, DateTime(2026, 10, 22, 0, 30)), const Duration(hours: 1, minutes: 30));
      expect(BackupScheduler.delayUntil(twoAm, DateTime(2026, 10, 22, 2, 0)), const Duration(hours: 24));
      expect(BackupScheduler.delayUntil(twoAm, DateTime(2026, 10, 22, 23, 0)), const Duration(hours: 3));
    });

    test('time encoding round-trips and rejects junk', () {
      const t = TimeOfDay(hour: 3, minute: 5);
      expect(DriveBackupState.encodeTime(t), '03:05');
      expect(DriveBackupState.decodeTime('03:05'), t);
      expect(DriveBackupState.decodeTime('25:00'), isNull);
      expect(DriveBackupState.decodeTime('nope'), isNull);
    });

    late FakeBackupRemote remote;
    late FakeBackupScheduler scheduler;

    ProviderContainer makeContainer(AppDatabase db) {
      final c = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWithValue(db),
        backupRemoteProvider.overrideWithValue(remote),
        backupSchedulerProvider.overrideWithValue(scheduler),
        backupKdfFactoryProvider.overrideWithValue(fastKdf),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      remote = FakeBackupRemote();
      scheduler = FakeBackupScheduler();
    });

    test('nightly job is scheduled (2 AM, Wi-Fi) only once backup is fully set up', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = makeContainer(db);
      c.read(driveBackupProvider);
      await pumpEventQueue();
      final ctrl = c.read(driveBackupProvider.notifier);

      expect(scheduler.scheduled, isFalse);
      expect(c.read(driveBackupProvider).isAutoActive, isFalse);

      await ctrl.connect();
      expect(scheduler.scheduled, isFalse, reason: 'no passphrase yet');

      await ctrl.setPassphrase('our cove passphrase');
      expect(scheduler.scheduled, isTrue);
      expect(scheduler.time, const TimeOfDay(hour: 2, minute: 0));
      expect(scheduler.wifiOnly, isTrue);
      expect(c.read(driveBackupProvider).isAutoActive, isTrue);
    });

    test('changing time / network reschedules; turning off cancels; settings persist', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = makeContainer(db);
      c.read(driveBackupProvider);
      await pumpEventQueue();
      final ctrl = c.read(driveBackupProvider.notifier);
      await ctrl.connect();
      await ctrl.setPassphrase('our cove passphrase');

      await ctrl.setAutoTime(const TimeOfDay(hour: 3, minute: 30));
      expect(scheduler.time, const TimeOfDay(hour: 3, minute: 30));
      expect(scheduler.resetCalls, 1);

      await ctrl.setAutoWifiOnly(false);
      expect(scheduler.wifiOnly, isFalse);
      expect(scheduler.resetCalls, 2);

      await ctrl.setAutoEnabled(false);
      expect(scheduler.scheduled, isFalse);

      // App restart: preferences reload, job stays cancelled.
      scheduler = FakeBackupScheduler();
      final c2 = makeContainer(db);
      c2.read(driveBackupProvider);
      await pumpEventQueue();
      final s = c2.read(driveBackupProvider);
      expect(s.autoEnabled, isFalse);
      expect(s.autoTime, const TimeOfDay(hour: 3, minute: 30));
      expect(s.autoWifiOnly, isFalse);
      expect(scheduler.scheduled, isFalse);
      expect(scheduler.cancelCalls, 1);
    });

    test('app launch re-registers the job without resetting its timer', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = makeContainer(db);
      c.read(driveBackupProvider);
      await pumpEventQueue();
      final ctrl = c.read(driveBackupProvider.notifier);
      await ctrl.connect();
      await ctrl.setPassphrase('our cove passphrase');

      scheduler = FakeBackupScheduler();
      final c2 = makeContainer(db);
      c2.read(driveBackupProvider);
      await pumpEventQueue();
      expect(scheduler.scheduled, isTrue);
      expect(scheduler.resetCalls, 0);
    });

    test('Settings reflects the outcome of the last nightly run after refresh', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final c = makeContainer(db);
      c.read(driveBackupProvider);
      await pumpEventQueue();
      final ctrl = c.read(driveBackupProvider.notifier);
      await ctrl.connect();
      await ctrl.setPassphrase('our cove passphrase');

      // Simulate the background worker running while the app was closed.
      final worker = BackupService(
        snapshot: c.read(backupSnapshotServiceProvider),
        remote: remote,
        storage: c.read(backupSecureStorageProvider),
      );
      await worker.run(automatic: true);

      await ctrl.refresh();
      final s = c.read(driveBackupProvider);
      expect(s.autoLastOutcome, BackupRunOutcome.uploaded);
      expect(s.autoLastRunAt, isNotNull);
      expect(s.lastBackupAt, isNotNull);
      expect(remote.files.length, 1);
    });
  });
}
