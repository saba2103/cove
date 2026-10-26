import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/widgets/cove_slip_widget.dart';
import 'package:cove/features/widgets/cove_widget_service.dart';
import 'package:cove/features/widgets/cove_widget_tick_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/key_management/pairing_crypto.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWidgetBridge implements CoveWidgetPlatformBridge {
  final Map<String, Size> renderedSizes = <String, Size>{};
  final Map<String, Widget> renderedWidgets = <String, Widget>{};
  final Map<String, Object?> savedData = <String, Object?>{};
  final List<String> updatedProviders = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<String> renderFlutterWidget(
    Widget widget, {
    required String key,
    required Size logicalSize,
  }) async {
    renderedSizes[key] = logicalSize;
    renderedWidgets[key] = widget;
    return '/tmp/$key.png';
  }

  @override
  Future<bool?> saveWidgetData<T>(String id, T? data) async {
    savedData[id] = data;
    return true;
  }

  @override
  Future<bool?> updateWidget({
    required String androidName,
    required String qualifiedAndroidName,
  }) async {
    updatedProviders.add(qualifiedAndroidName);
    return true;
  }

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() async => null;

  @override
  Stream<Uri?> get widgetClicked => const Stream<Uri?>.empty();
}

class _NoopRefreshScheduler implements WidgetRefreshScheduler {
  @override
  bool get isSupported => true;
  @override
  Future<void> cancel() async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<void> schedulePeriodicRefresh() async {}
}

AppDatabase _openWriterDatabaseOnFile(File file) {
  return AppDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute('PRAGMA busy_timeout = 5000;');
      },
    ),
  );
}

Future<void> _downgradeDatabaseToSchemaVersion10(AppDatabase db) async {
  await db.customStatement(
    'ALTER TABLE local_homes DROP COLUMN monthly_budget;',
  );
  await db.customStatement(
    'ALTER TABLE local_homes DROP COLUMN anniversary_date;',
  );
  await db.customStatement(
    'DROP TABLE IF EXISTS local_checkin_reminders;',
  );
  await db.customStatement('PRAGMA user_version = 10;');
}

Future<void> _seedSlipHousehold(
  AppDatabase db, {
  required DateTime now,
}) async {
  await db.into(db.localHomes).insertOnConflictUpdate(
        LocalHomesCompanion.insert(
          id: 'home-indiranagar',
          name: 'Indiranagar',
          createdBy: 'user-ancy',
          currency: const Value('INR'),
          createdAt: now,
        ),
      );
  await db.into(db.localLists).insertOnConflictUpdate(
        LocalListsCompanion.insert(
          id: 'list-groceries',
          homeId: 'home-indiranagar',
          name: 'Groceries',
          createdAt: now,
          createdBy: 'user-ancy',
        ),
      );
  await db.into(db.localListItems).insertOnConflictUpdate(
        LocalListItemsCompanion.insert(
          id: 'item-curd',
          homeId: 'home-indiranagar',
          listId: 'list-groceries',
          title: 'Curd, 500g',
          isCompleted: const Value(false),
          createdAt: now,
          createdBy: 'user-ancy',
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime(2026, 10, 5, 9, 41);
  // 32-byte test symmetric home key in base64url.
  final testHomeKeyBase64 = base64Url.encode(List<int>.filled(32, 7));

  setUpAll(() async {
    await PairingCrypto.ensureInitialized();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'cove_home_key_home-indiranagar': testHomeKeyBase64,
    });
    SlipSelectedListIdNotifier.cachedInitialListId = null;
    IsolateNameServer.removePortNameMapping(
      CoveWidgetTickService.mainIsolatePortName,
    );
  });

  tearDown(() {
    IsolateNameServer.removePortNameMapping(
      CoveWidgetTickService.mainIsolatePortName,
    );
  });

  group('4.4c Real Temporary SQLite File Guarantees (§ Ticking)', () {
    test(
      '1. the app alive → the app applies it, the background opens no connection',
      () async {
        await withClock(Clock.fixed(fixedNow), () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'cove_44c_alive_',
          );
          addTearDown(() async {
            if (tempDir.existsSync()) {
              await tempDir.delete(recursive: true);
            }
          });
          final dbFile = File('${tempDir.path}/cove_db.sqlite');

          final writerDb = _openWriterDatabaseOnFile(dbFile);
          addTearDown(writerDb.close);
          await _seedSlipHousehold(writerDb, now: fixedNow);

          final prefs = await SharedPreferences.getInstance();
          final keyStore = HomeKeyStore();
          final mainTickService = CoveWidgetTickService(
            appDatabase: writerDb,
            homeKeyStore: keyStore,
            sharedPreferences: prefs,
            getCurrentUserId: () => 'user-saba',
          );
          addTearDown(mainTickService.dispose);

          mainTickService.registerMainIsolatePort();
          expect(
            IsolateNameServer.lookupPortByName(
              CoveWidgetTickService.mainIsolatePortName,
            ),
            isNotNull,
          );

          var bgConnectionsOpened = 0;
          var optimisticRenderCalled = false;

          final bgResult = await CoveWidgetTickService.handleWidgetTick(
            kind: WidgetTickKind.listItem,
            recordId: 'item-curd',
            databaseFile: dbFile,
            sharedPreferencesOverride: prefs,
            keyStoreOverride: keyStore,
            viewerUserIdOverride: 'user-saba',
            onBackgroundDatabaseOpened: () => bgConnectionsOpened += 1,
            onOptimisticRender: (_) async {
              optimisticRenderCalled = true;
            },
          );

          // Background forwarded to the live app after receiving 'received'
          // within 1s and opened ZERO database connections.
          expect(bgResult.outcome, WidgetTickOutcome.forwardedToMainIsolate);
          expect(bgConnectionsOpened, 0);
          expect(optimisticRenderCalled, isTrue);

          await mainTickService.waitForForwardedTick();

          // The live app applied the tick via ListController.toggleItem.
          final item = await (writerDb.select(writerDb.localListItems)
                ..where((t) => t.id.equals('item-curd')))
              .getSingle();
          expect(item.isCompleted, isTrue);
          expect(item.completedBy, 'user-saba');

          final outbox =
              await writerDb.select(writerDb.localOutboxEvents).get();
          expect(outbox, hasLength(1));
          expect(outbox.single.eventType, 'list_item_toggled');

          final unapplied =
              await WidgetTickIntentLog(prefs).getUnappliedIntents();
          expect(unapplied, isEmpty);
        });
      },
    );

    test(
      '2. the app dead → the background applies it once; the outbox has exactly one event',
      () async {
        await withClock(Clock.fixed(fixedNow), () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'cove_44c_dead_',
          );
          addTearDown(() async {
            if (tempDir.existsSync()) {
              await tempDir.delete(recursive: true);
            }
          });
          final dbFile = File('${tempDir.path}/cove_db.sqlite');

          // Seed the database file and close the app's writer connection so the
          // app is completely dead.
          final seedDb = _openWriterDatabaseOnFile(dbFile);
          await _seedSlipHousehold(seedDb, now: fixedNow);
          await seedDb.close();

          expect(
            IsolateNameServer.lookupPortByName(
              CoveWidgetTickService.mainIsolatePortName,
            ),
            isNull,
          );

          final prefs = await SharedPreferences.getInstance();
          final keyStore = HomeKeyStore();
          var bgConnectionsOpened = 0;
          var syncPushAttempted = false;

          final bgResult = await CoveWidgetTickService.handleWidgetTick(
            kind: WidgetTickKind.listItem,
            recordId: 'item-curd',
            databaseFile: dbFile,
            sharedPreferencesOverride: prefs,
            keyStoreOverride: keyStore,
            viewerUserIdOverride: 'user-saba',
            onBackgroundDatabaseOpened: () => bgConnectionsOpened += 1,
            onSyncPushOverride: () async {
              syncPushAttempted = true;
            },
          );

          expect(bgResult.outcome, WidgetTickOutcome.appliedInBackground);
          expect(bgResult.wroteToDatabase, isTrue);
          expect(bgConnectionsOpened, 1);
          expect(syncPushAttempted, isTrue);

          final unapplied =
              await WidgetTickIntentLog(prefs).getUnappliedIntents();
          expect(unapplied, isEmpty);

          // Re-open the SQLite file to verify the background write & outbox.
          final inspectDb = _openWriterDatabaseOnFile(dbFile);
          addTearDown(inspectDb.close);

          final item = await (inspectDb.select(inspectDb.localListItems)
                ..where((t) => t.id.equals('item-curd')))
              .getSingle();
          expect(item.isCompleted, isTrue);
          expect(item.completedBy, 'user-saba');

          final outbox =
              await inspectDb.select(inspectDb.localOutboxEvents).get();
          expect(outbox, hasLength(1));
          expect(outbox.single.eventType, 'list_item_toggled');
        });
      },
    );

    test(
      '3. the app starting while the background writes → both succeed, nothing lost, and migrations still run',
      () async {
        await withClock(Clock.fixed(fixedNow), () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'cove_44c_concurrent_',
          );
          addTearDown(() async {
            if (tempDir.existsSync()) {
              await tempDir.delete(recursive: true);
            }
          });
          final dbFile = File('${tempDir.path}/cove_db.sqlite');

          // Seed household + two open items, then close.
          final seedDb = _openWriterDatabaseOnFile(dbFile);
          await _seedSlipHousehold(seedDb, now: fixedNow);
          await seedDb.into(seedDb.localListItems).insert(
                LocalListItemsCompanion.insert(
                  id: 'item-tablets',
                  homeId: 'home-indiranagar',
                  listId: 'list-groceries',
                  title: 'Dishwasher tablets',
                  isCompleted: const Value(false),
                  createdAt: fixedNow.add(const Duration(minutes: 1)),
                  createdBy: 'user-saba',
                ),
              );
          await seedDb.close();

          final prefs = await SharedPreferences.getInstance();
          final keyStore = HomeKeyStore();
          AppDatabase? mainAppDb;
          addTearDown(() async {
            await mainAppDb?.close();
          });

          // Launch the background tick; while it is inside its write transaction
          // on its own unshared writable connection, start the main app's
          // AppDatabase on the exact same SQLite file and perform an app write.
          Future<void>? concurrentAppStartupFuture;
          final bgFuture = CoveWidgetTickService.handleWidgetTick(
            kind: WidgetTickKind.listItem,
            recordId: 'item-curd',
            databaseFile: dbFile,
            sharedPreferencesOverride: prefs,
            keyStoreOverride: keyStore,
            viewerUserIdOverride: 'user-saba',
            onInsideWriteTransaction: () async {
              mainAppDb = _openWriterDatabaseOnFile(dbFile);
              concurrentAppStartupFuture = () async {
                final versionRow = await mainAppDb!
                    .customSelect('PRAGMA user_version;')
                    .getSingle();
                expect(
                  versionRow.read<int>('user_version'),
                  AppDatabase.currentSchemaVersion,
                );
                await mainAppDb!.into(mainAppDb!.localListItems).insert(
                      LocalListItemsCompanion.insert(
                        id: 'item-coffee',
                        homeId: 'home-indiranagar',
                        listId: 'list-groceries',
                        title: 'Coffee beans — dark roast',
                        isCompleted: const Value(false),
                        createdAt: fixedNow.add(const Duration(minutes: 2)),
                        createdBy: 'user-ancy',
                      ),
                    );
              }();
              // Yield briefly so the main app connection contends with the
              // background transaction using SQLite's busy_timeout = 5000.
              await Future<void>.delayed(const Duration(milliseconds: 25));
            },
          );

          final bgResult = await bgFuture;
          expect(bgResult.outcome, WidgetTickOutcome.appliedInBackground);
          expect(concurrentAppStartupFuture, isNotNull);
          await concurrentAppStartupFuture;

          // Also verify that if a pre-migration database file (user_version 10)
          // is opened by the main app after a background tick attempt, Drift's
          // migration to version 11 runs cleanly and nothing is lost.
          final migFile = File('${tempDir.path}/cove_mig.sqlite');
          final preMigDb = _openWriterDatabaseOnFile(migFile);
          await _seedSlipHousehold(preMigDb, now: fixedNow);
          await _downgradeDatabaseToSchemaVersion10(preMigDb);
          await preMigDb.close();

          final migratedAppDb = _openWriterDatabaseOnFile(migFile);
          addTearDown(migratedAppDb.close);
          final migVer = await migratedAppDb
              .customSelect('PRAGMA user_version;')
              .getSingle();
          expect(
            migVer.read<int>('user_version'),
            AppDatabase.currentSchemaVersion,
          );

          // Verify both the background tick and the concurrent foreground insert
          // succeeded on dbFile without losing anything.
          final allItems =
              await mainAppDb!.select(mainAppDb!.localListItems).get();
          expect(
            allItems.map((i) => i.id).toSet(),
            equals({'item-curd', 'item-tablets', 'item-coffee'}),
          );
          final curd = allItems.firstWhere((i) => i.id == 'item-curd');
          expect(curd.isCompleted, isTrue);

          final outbox =
              await mainAppDb!.select(mainAppDb!.localOutboxEvents).get();
          expect(outbox, hasLength(1));
        });
      },
    );

    test(
      '4. a crash after the write but before "applied" is marked → app start doesn\'t apply it twice',
      () async {
        await withClock(Clock.fixed(fixedNow), () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'cove_44c_crash_',
          );
          addTearDown(() async {
            if (tempDir.existsSync()) {
              await tempDir.delete(recursive: true);
            }
          });
          final dbFile = File('${tempDir.path}/cove_db.sqlite');

          final seedDb = _openWriterDatabaseOnFile(dbFile);
          await _seedSlipHousehold(seedDb, now: fixedNow);
          await seedDb.close();

          final prefs = await SharedPreferences.getInstance();
          final keyStore = HomeKeyStore();

          // Simulate a crash immediately after the SQLite transaction commits
          // but before the intent is marked applied in SharedPreferences.
          await expectLater(
            () => CoveWidgetTickService.handleWidgetTick(
              kind: WidgetTickKind.listItem,
              recordId: 'item-curd',
              databaseFile: dbFile,
              sharedPreferencesOverride: prefs,
              keyStoreOverride: keyStore,
              viewerUserIdOverride: 'user-saba',
              simulateCrashBeforeMarkingApplied: true,
            ),
            throwsA(isA<StateError>()),
          );

          // Intent is still unapplied in the durable log.
          final unappliedBeforeStart =
              await WidgetTickIntentLog(prefs).getUnappliedIntents();
          expect(unappliedBeforeStart, hasLength(1));

          // Now the app starts and replays unapplied intents.
          final appDb = _openWriterDatabaseOnFile(dbFile);
          addTearDown(appDb.close);

          final mainTickService = CoveWidgetTickService(
            appDatabase: appDb,
            homeKeyStore: keyStore,
            sharedPreferences: prefs,
            getCurrentUserId: () => 'user-saba',
          );
          addTearDown(mainTickService.dispose);

          final replayResults =
              await mainTickService.replayUnappliedIntentsOnAppStart();
          expect(replayResults, hasLength(1));
          expect(
            replayResults.single.outcome,
            WidgetTickOutcome.noopAlreadyInState,
          );
          expect(replayResults.single.wroteToDatabase, isFalse);

          // Intent is now marked applied, and the outbox has strictly ONE event
          // (never applied twice).
          final unappliedAfterStart =
              await WidgetTickIntentLog(prefs).getUnappliedIntents();
          expect(unappliedAfterStart, isEmpty);

          final outbox = await appDb.select(appDb.localOutboxEvents).get();
          expect(outbox, hasLength(1));
        });
      },
    );

    test(
      '5. a schema-version mismatch → the background refuses; the app applies it on start',
      () async {
        await withClock(Clock.fixed(fixedNow), () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'cove_44c_schema_',
          );
          addTearDown(() async {
            if (tempDir.existsSync()) {
              await tempDir.delete(recursive: true);
            }
          });
          final dbFile = File('${tempDir.path}/cove_db.sqlite');

          // Create a database at schema version 10 (pre-v11 migration).
          final seedDb = _openWriterDatabaseOnFile(dbFile);
          await _seedSlipHousehold(seedDb, now: fixedNow);
          await _downgradeDatabaseToSchemaVersion10(seedDb);
          await seedDb.close();

          final prefs = await SharedPreferences.getInstance();
          final keyStore = HomeKeyStore();
          var bgConnectionsOpened = 0;

          final bgResult = await CoveWidgetTickService.handleWidgetTick(
            kind: WidgetTickKind.listItem,
            recordId: 'item-curd',
            databaseFile: dbFile,
            sharedPreferencesOverride: prefs,
            keyStoreOverride: keyStore,
            viewerUserIdOverride: 'user-saba',
            onBackgroundDatabaseOpened: () => bgConnectionsOpened += 1,
          );

          // Background refused to touch the mismatched schema file.
          expect(bgResult.outcome, WidgetTickOutcome.refusedSchemaMismatch);
          expect(bgResult.wroteToDatabase, isFalse);
          expect(bgConnectionsOpened, 0);

          // Intent remains safely queued in the durable log.
          final unappliedBeforeStart =
              await WidgetTickIntentLog(prefs).getUnappliedIntents();
          expect(unappliedBeforeStart, hasLength(1));

          // Verify the item on disk was not modified while at user_version 10.
          final roCheck = AppDatabase.readOnly(file: dbFile);
          final pendingItem = await (roCheck.select(roCheck.localListItems)
                ..where((t) => t.id.equals('item-curd')))
              .getSingle();
          expect(pendingItem.isCompleted, isFalse);
          await roCheck.close();

          // Now the app starts, runs Drift migrations (10 -> 11), and replays
          // the unapplied intent.
          final appDb = _openWriterDatabaseOnFile(dbFile);
          addTearDown(appDb.close);

          final verRow =
              await appDb.customSelect('PRAGMA user_version;').getSingle();
          expect(
            verRow.read<int>('user_version'),
            AppDatabase.currentSchemaVersion,
          );

          final mainTickService = CoveWidgetTickService(
            appDatabase: appDb,
            homeKeyStore: keyStore,
            sharedPreferences: prefs,
            getCurrentUserId: () => 'user-saba',
          );
          addTearDown(mainTickService.dispose);

          final replayResults =
              await mainTickService.replayUnappliedIntentsOnAppStart();
          expect(replayResults, hasLength(1));
          expect(
            replayResults.single.outcome,
            WidgetTickOutcome.appliedOnAppStart,
          );
          expect(replayResults.single.wroteToDatabase, isTrue);

          final itemAfterStart = await (appDb.select(appDb.localListItems)
                ..where((t) => t.id.equals('item-curd')))
              .getSingle();
          expect(itemAfterStart.isCompleted, isTrue);

          final outbox = await appDb.select(appDb.localOutboxEvents).get();
          expect(outbox, hasLength(1));

          final unappliedAfterStart =
              await WidgetTickIntentLog(prefs).getUnappliedIntents();
          expect(unappliedAfterStart, isEmpty);
        });
      },
    );

    test(
      '6. ticking an already-ticked item → no write',
      () async {
        await withClock(Clock.fixed(fixedNow), () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'cove_44c_already_ticked_',
          );
          addTearDown(() async {
            if (tempDir.existsSync()) {
              await tempDir.delete(recursive: true);
            }
          });
          final dbFile = File('${tempDir.path}/cove_db.sqlite');

          final seedDb = _openWriterDatabaseOnFile(dbFile);
          await _seedSlipHousehold(seedDb, now: fixedNow);
          await (seedDb.update(seedDb.localListItems)
                ..where((t) => t.id.equals('item-curd')))
              .write(
            LocalListItemsCompanion(
              isCompleted: const Value(true),
              completedAt: Value(fixedNow),
              completedBy: const Value('user-ancy'),
            ),
          );
          await seedDb.close();

          final prefs = await SharedPreferences.getInstance();
          final keyStore = HomeKeyStore();

          final bgResult = await CoveWidgetTickService.handleWidgetTick(
            kind: WidgetTickKind.listItem,
            recordId: 'item-curd',
            toDone: true,
            databaseFile: dbFile,
            sharedPreferencesOverride: prefs,
            keyStoreOverride: keyStore,
            viewerUserIdOverride: 'user-saba',
          );

          expect(bgResult.outcome, WidgetTickOutcome.noopAlreadyInState);
          expect(bgResult.wroteToDatabase, isFalse);

          // Intent is marked applied and ZERO outbox events were written.
          final unapplied =
              await WidgetTickIntentLog(prefs).getUnappliedIntents();
          expect(unapplied, isEmpty);

          final inspectDb = _openWriterDatabaseOnFile(dbFile);
          addTearDown(inspectDb.close);
          final outbox =
              await inspectDb.select(inspectDb.localOutboxEvents).get();
          expect(outbox, isEmpty);
        });
      },
    );
  });

  group('4.4c The Slip Widget (§2 & § Sizes)', () {
    test(
      'defaults to the most-used list and supports explicit list selection',
      () {
        final lists = <LocalList>[
          LocalList(
            id: 'list-travel',
            homeId: 'home-indiranagar',
            name: 'Travel',
            isArchived: false,
            createdAt: fixedNow,
            createdBy: 'user-ancy',
          ),
          LocalList(
            id: 'list-groceries',
            homeId: 'home-indiranagar',
            name: 'Groceries',
            isArchived: false,
            createdAt: fixedNow.add(const Duration(minutes: 1)),
            createdBy: 'user-ancy',
          ),
        ];

        final items = <LocalListItem>[
          LocalListItem(
            id: 't-1',
            homeId: 'home-indiranagar',
            listId: 'list-travel',
            title: 'Passports',
            isCompleted: false,
            createdAt: fixedNow,
            createdBy: 'user-saba',
          ),
          LocalListItem(
            id: 'g-1',
            homeId: 'home-indiranagar',
            listId: 'list-groceries',
            title: 'Curd, 500g',
            isCompleted: false,
            createdAt: fixedNow,
            createdBy: 'user-ancy',
          ),
          LocalListItem(
            id: 'g-2',
            homeId: 'home-indiranagar',
            listId: 'list-groceries',
            title: 'Dishwasher tablets',
            isCompleted: false,
            createdAt: fixedNow.add(const Duration(minutes: 1)),
            createdBy: 'user-saba',
          ),
          LocalListItem(
            id: 'g-3',
            homeId: 'home-indiranagar',
            listId: 'list-groceries',
            title: 'Coffee beans — dark roast',
            isCompleted: false,
            createdAt: fixedNow.add(const Duration(minutes: 2)),
            createdBy: 'user-ancy',
          ),
        ];

        // Default: most-used list is Groceries (3 items vs 1 item).
        final defaultSummary = SlipSummary.compute(
          lists: lists,
          allItems: items,
          selectedListId: null,
          homeCreatedBy: 'user-ancy',
          currentUserId: 'user-saba',
          myName: 'Saba',
          partnerName: 'Ancy',
        );
        expect(defaultSummary.listId, 'list-groceries');
        expect(defaultSummary.listName, 'Groceries');
        expect(defaultSummary.openCount, 3);
        expect(defaultSummary.openItems.first.person, CovePerson.a);
        expect(defaultSummary.openItems.first.actorInitial, 'A');
        expect(defaultSummary.openItems[1].person, CovePerson.b);
        expect(defaultSummary.openItems[1].actorInitial, 'S');

        // Explicit choice: Travel.
        final chosenSummary = SlipSummary.compute(
          lists: lists,
          allItems: items,
          selectedListId: 'list-travel',
          homeCreatedBy: 'user-ancy',
          currentUserId: 'user-saba',
          myName: 'Saba',
          partnerName: 'Ancy',
        );
        expect(chosenSummary.listId, 'list-travel');
        expect(chosenSummary.listName, 'Travel');
        expect(chosenSummary.openCount, 1);
      },
    );

    testWidgets(
      'renders 3 rows at 4-cell width, 2 rows at 3-cell width (<240dp), and empty state',
      (tester) async {
        final summary = SlipSummary(
          listId: 'list-groceries',
          listName: 'Groceries',
          openCount: 5,
          openItems: const [
            SlipItemRow(
              id: 'item-1',
              title: 'Curd, 500g',
              createdBy: 'user-ancy',
              person: CovePerson.b,
              actorInitial: 'A',
            ),
            SlipItemRow(
              id: 'item-2',
              title: 'Dishwasher tablets',
              createdBy: 'user-saba',
              person: CovePerson.a,
              actorInitial: 'S',
            ),
            SlipItemRow(
              id: 'item-3',
              title: 'Coffee beans — dark roast',
              createdBy: 'user-ancy',
              person: CovePerson.b,
              actorInitial: 'A',
            ),
            SlipItemRow(
              id: 'item-4',
              title: 'Sourdough loaf',
              createdBy: 'user-saba',
              person: CovePerson.a,
              actorInitial: 'S',
            ),
            SlipItemRow(
              id: 'item-5',
              title: 'Black pepper',
              createdBy: 'user-ancy',
              person: CovePerson.b,
              actorInitial: 'A',
            ),
          ],
        );

        String? openedListId;
        String? tickedItemId;

        // 4-cell width (379x176): shows 3 rows and "+2 more · tap to tick".
        await tester.pumpWidget(
          MaterialApp(
            theme: CoveTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 379,
                  height: 176,
                  child: CoveSlipCard(
                    summary: summary,
                    onTapOpenList: (id) => openedListId = id,
                    onTickItem: (id) => tickedItemId = id,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Groceries'), findsOneWidget);
        expect(find.text('5 OPEN'), findsOneWidget);
        expect(find.text('Curd, 500g'), findsOneWidget);
        expect(find.text('Dishwasher tablets'), findsOneWidget);
        expect(find.text('Coffee beans — dark roast'), findsOneWidget);
        expect(find.text('Sourdough loaf'), findsNothing);
        expect(find.text('+2 more · tap to tick'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('cove_slip_row_1')));
        expect(tickedItemId, 'item-2');

        await tester.tap(find.byKey(const ValueKey('cove_slip_header')));
        expect(openedListId, 'list-groceries');

        // 3-cell compact width (200x176): shows 2 rows and "+3 more · tap to tick".
        await tester.pumpWidget(
          MaterialApp(
            theme: CoveTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 176,
                  child: CoveSlipCard(summary: summary),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Curd, 500g'), findsOneWidget);
        expect(find.text('Dishwasher tablets'), findsOneWidget);
        expect(find.text('Coffee beans — dark roast'), findsNothing);
        expect(find.text('+3 more · tap to tick'), findsOneWidget);

        // Empty state: "Groceries is empty".
        const emptySummary = SlipSummary(
          listId: 'list-groceries',
          listName: 'Groceries',
          openCount: 0,
          openItems: [],
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 379,
                  height: 176,
                  child: CoveSlipCard(summary: emptySummary),
                ),
              ),
            ),
          ),
        );

        expect(find.text('Groceries is empty'), findsOneWidget);
        expect(find.text('0 OPEN'), findsOneWidget);
      },
    );

    test(
      'renderAndPushSlip & renderOptimisticSlipTick push dark/light + compact bitmaps and hit-area IDs',
      () async {
        final bridge = _FakeWidgetBridge();
        final service = CoveWidgetService(
          bridge: bridge,
          scheduler: _NoopRefreshScheduler(),
        );

        const summary = SlipSummary(
          listId: 'list-groceries',
          listName: 'Groceries',
          openCount: 3,
          openItems: [
            SlipItemRow(
              id: 'item-1',
              title: 'Curd, 500g',
              createdBy: 'user-ancy',
              person: CovePerson.b,
              actorInitial: 'A',
            ),
            SlipItemRow(
              id: 'item-2',
              title: 'Dishwasher tablets',
              createdBy: 'user-saba',
              person: CovePerson.a,
              actorInitial: 'S',
            ),
          ],
        );

        await service.renderAndPushSlip(summary: summary);

        expect(
          bridge.renderedSizes.keys,
          containsAll(<String>[
            CoveWidgetService.slipDarkKey,
            CoveWidgetService.slipLightKey,
            CoveWidgetService.slipCompactDarkKey,
            CoveWidgetService.slipCompactLightKey,
          ]),
        );
        expect(
          bridge.savedData[CoveWidgetService.slipListIdKey],
          'list-groceries',
        );
        expect(bridge.savedData[CoveWidgetService.slipRow0IdKey], 'item-1');
        expect(bridge.savedData[CoveWidgetService.slipRow1IdKey], 'item-2');
        expect(bridge.savedData[CoveWidgetService.slipRow2IdKey], isNull);

        // Optimistic tick immediately re-renders the Slip with item-1 ticked.
        final optimistic = await service.renderOptimisticSlipTick('item-1');
        expect(optimistic, isNotNull);
        expect(optimistic!.openItems.first.isTicked, isTrue);
        expect(optimistic.openCount, 1);
      },
    );

    testWidgets(
      'SlipListPickerSheet displays list choices with MOST USED badge and persists choice',
      (tester) async {
        final lists = <LocalList>[
          LocalList(
            id: 'list-groceries',
            homeId: 'home-indiranagar',
            name: 'Groceries',
            isArchived: false,
            createdAt: fixedNow,
            createdBy: 'user-ancy',
          ),
          LocalList(
            id: 'list-travel',
            homeId: 'home-indiranagar',
            name: 'Travel',
            isArchived: false,
            createdAt: fixedNow.add(const Duration(minutes: 1)),
            createdBy: 'user-ancy',
          ),
        ];
        final items = <LocalListItem>[
          LocalListItem(
            id: 'g-1',
            homeId: 'home-indiranagar',
            listId: 'list-groceries',
            title: 'Curd, 500g',
            isCompleted: false,
            createdAt: fixedNow,
            createdBy: 'user-ancy',
          ),
          LocalListItem(
            id: 'g-2',
            homeId: 'home-indiranagar',
            listId: 'list-groceries',
            title: 'Dishwasher tablets',
            isCompleted: false,
            createdAt: fixedNow,
            createdBy: 'user-saba',
          ),
        ];

        final container = ProviderContainer(
          overrides: [
            activeHomeListsProvider.overrideWith((_) => Stream.value(lists)),
            activeHomeAllListItemsProvider.overrideWith(
              (_) => Stream.value(items),
            ),
            activeHomeIdProvider.overrideWith(
              () => _TestActiveHomeIdNotifier('home-indiranagar'),
            ),
            authProvider.overrideWith(
              () => _TestAuthNotifier(
                const CoveUser(id: 'user-saba', email: 'saba@cove.local'),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: const Scaffold(
                body: SlipListPickerSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('THE SLIP · CHOOSE A LIST'), findsOneWidget);
        expect(find.text('MOST USED'), findsOneWidget);
        expect(find.text('Groceries'), findsOneWidget);
        expect(find.text('Travel'), findsOneWidget);

        await tester.tap(
          find.byKey(const ValueKey('slip_list_option_list-travel')),
        );
        await tester.pumpAndSettle();

        expect(container.read(slipSelectedListIdProvider), 'list-travel');
        expect(container.read(slipSummaryProvider).listName, 'Travel');
      },
    );
  });
}

class _TestActiveHomeIdNotifier extends ActiveHomeNotifier {
  final String _id;
  _TestActiveHomeIdNotifier(this._id);
  @override
  String? build() => _id;
}

class _TestAuthNotifier extends AuthNotifier {
  final CoveUser _user;
  _TestAuthNotifier(this._user);
  @override
  AsyncValue<CoveUser?> build() => AsyncData(_user);
}
