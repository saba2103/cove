import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/notifications/notification_controller.dart';
import 'package:cove/features/notifications/notification_copy.dart';
import 'package:cove/features/notifications/notification_detail_dispatcher.dart';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:cove/features/notifications/notification_pipeline.dart';
import 'package:cove/features/notifications/notification_service.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/reminders/reminder_controller.dart';
import 'package:cove/features/reminders/reminder_models.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNotificationSink implements LocalNotificationSink {
  final List<RenderedNotification> shown = <RenderedNotification>[];
  final List<({int id, String? tag})> cancelled = <({int id, String? tag})>[];
  int cancelAllCount = 0;

  @override
  Future<void> show(RenderedNotification notification) async {
    shown.add(notification);
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelled.add((id: id, tag: tag));
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount += 1;
  }
}

class _FixedActiveHomeNotifier extends ActiveHomeNotifier {
  final String? initialHomeId;
  _FixedActiveHomeNotifier(this.initialHomeId);

  @override
  String? build() => initialHomeId;
}

Future<void> _seedHousehold(AppDatabase db) async {
  final now = DateTime(2026, 11, 14, 18, 30);
  await db.into(db.localHomes).insert(
        LocalHomesCompanion.insert(
          id: 'home-indiranagar',
          name: 'Indiranagar',
          createdBy: 'user-ancy',
          currency: const Value('INR'),
          createdAt: now,
        ),
      );
  await db.into(db.localActivityEvents).insert(
        LocalActivityEventsCompanion.insert(
          id: 'ev-profile-ancy',
          homeId: 'home-indiranagar',
          actorId: 'user-ancy',
          eventType: 'member_profile_updated',
          payloadJson: jsonEncode(<String, dynamic>{
            'display_name': 'Ancy',
            'actor_name': 'Ancy',
          }),
          createdAt: now,
        ),
      );
  await db.into(db.localLists).insert(
        LocalListsCompanion.insert(
          id: 'list-groceries',
          homeId: 'home-indiranagar',
          name: 'Groceries',
          createdBy: 'user-ancy',
          createdAt: now,
        ),
      );
}

AppDatabase _openWriterDatabaseOnFile(File file) {
  return AppDatabase(
    driftDatabase(
      name: 'cove_db',
      native: DriftNativeOptions(
        databasePath: () async => file.path,
        tempDirectoryPath: () async => file.parent.path,
        setup: (db) {
          db.execute('PRAGMA busy_timeout = 5000;');
        },
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime(2026, 11, 14, 19, 15, 0);

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    IsolateNameServer.removePortNameMapping(
      NotificationService.mainIsolatePortName,
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NotificationDetailDispatcher.resetState();
  });

  tearDown(() {
    IsolateNameServer.removePortNameMapping(
      NotificationService.mainIsolatePortName,
    );
  });

  group('NotificationPipeline (3.14c)', () {
    test(
        'happy path for one expense renders §1 copy with ic_stat_cove and accentFill',
        () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final seedDb = AppDatabase(NativeDatabase.memory());
        addTearDown(seedDb.close);
        await _seedHousehold(seedDb);

        final sink = FakeNotificationSink();
        final prefs = await SharedPreferences.getInstance();

        final pipeline = NotificationPipeline(
          database: seedDb,
          sink: sink,
          sharedPreferences: prefs,
          getViewerUserId: () => 'user-saba',
          decryptEvent: ({
            required String homeId,
            required String eventId,
            required String eventType,
            required Map<String, dynamic> data,
          }) async {
            return DecryptedEvent(
              id: eventId,
              homeId: homeId,
              eventType: eventType,
              actorId: 'user-ancy',
              payload: <String, dynamic>{
                'id': 'exp-coffee-1',
                'title': 'Coffee beans — dark roast',
                'amount': 820,
              },
            );
          },
        );

        final message = RemoteMessage(
          data: <String, dynamic>{
            'home_id': 'home-indiranagar',
            'event_id': 'ev-exp-1',
            'event_type': 'expense_added',
          },
        );

        final result = await pipeline.handleRemoteMessage(message);

        expect(result.kind, PipelineOutcomeKind.shown);
        expect(sink.shown, hasLength(1));

        final card = sink.shown.single;
        expect(card.title, 'Expenses');
        expect(card.body, 'Ancy logged ₹820 for Coffee beans — dark roast');
        expect(card.icon, '@drawable/ic_stat_cove');
        expect(card.color, CoveTokens.dark.accentFill);
        expect(card.groupKey, 'cove_group_expenses');
        expect(card.onlyAlertOnce, isFalse);
        expect(card.usesInboxStyle, isFalse);
        expect(card.isFallback, isFalse);
        expect(card.tapPayload.module, NotificationModule.expenses);
        expect(card.tapPayload.eventId, 'ev-exp-1');
      });
    });

    test(
        'decrypt failure shows §4 fallback within budget and logs reason with no content',
        () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final seedDb = AppDatabase(NativeDatabase.memory());
        addTearDown(seedDb.close);
        await _seedHousehold(seedDb);

        final sink = FakeNotificationSink();
        final prefs = await SharedPreferences.getInstance();
        final loggedReasons =
            <({FallbackReason reason, String homeId, String eventId})>[];

        final pipeline = NotificationPipeline(
          database: seedDb,
          sink: sink,
          sharedPreferences: prefs,
          getViewerUserId: () => 'user-saba',
          onFallbackLogged: (reason, homeId, eventId) {
            loggedReasons.add(
              (reason: reason, homeId: homeId, eventId: eventId),
            );
          },
          decryptEvent: ({
            required String homeId,
            required String eventId,
            required String eventType,
            required Map<String, dynamic> data,
          }) async {
            throw const NotificationPipelineException(
              FallbackReason.decryptFailed,
            );
          },
        );

        final result = await pipeline.handleRemoteMessage(
          RemoteMessage(
            data: <String, dynamic>{
              'home_id': 'home-indiranagar',
              'event_id': 'ev-corrupt-1',
              'event_type': 'expense_added',
            },
          ),
        );

        expect(result.kind, PipelineOutcomeKind.fallbackShown);
        expect(result.fallbackReason, FallbackReason.decryptFailed);
        expect(pipeline.fallbackCounts[FallbackReason.decryptFailed], 1);
        expect(loggedReasons, [
          (
            reason: FallbackReason.decryptFailed,
            homeId: 'home-indiranagar',
            eventId: 'ev-corrupt-1',
          ),
        ]);

        expect(sink.shown, hasLength(1));
        final card = sink.shown.single;
        expect(card.isFallback, isTrue);
        expect(card.title, 'Indiranagar');
        expect(card.body, 'Ancy made a change. Open to see it.');
        expect(card.tapPayload.module, NotificationModule.activity);
        expect(card.icon, '@drawable/ic_stat_cove');
        expect(card.color, CoveTokens.dark.accentFill);
      });
    });

    test('timeout shows §4 fallback within budget', () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final seedDb = AppDatabase(NativeDatabase.memory());
        addTearDown(seedDb.close);
        await _seedHousehold(seedDb);

        final sink = FakeNotificationSink();
        final prefs = await SharedPreferences.getInstance();

        final pipeline = NotificationPipeline(
          database: seedDb,
          sink: sink,
          sharedPreferences: prefs,
          budget: const Duration(milliseconds: 40),
          getViewerUserId: () => 'user-saba',
          decryptEvent: ({
            required String homeId,
            required String eventId,
            required String eventType,
            required Map<String, dynamic> data,
          }) async {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            return const DecryptedEvent(
              id: 'ev-slow-1',
              homeId: 'home-indiranagar',
              eventType: 'expense_added',
              actorId: 'user-ancy',
              payload: <String, dynamic>{'title': 'Too late', 'amount': 100},
            );
          },
        );

        final result = await pipeline.handleRemoteMessage(
          RemoteMessage(
            data: <String, dynamic>{
              'home_id': 'home-indiranagar',
              'event_id': 'ev-slow-1',
              'event_type': 'expense_added',
            },
          ),
        );

        expect(result.kind, PipelineOutcomeKind.fallbackShown);
        expect(result.fallbackReason, FallbackReason.timeout);
        expect(pipeline.fallbackCounts[FallbackReason.timeout], 1);

        expect(sink.shown, hasLength(1));
        final card = sink.shown.single;
        expect(card.isFallback, isTrue);
        expect(card.title, 'Indiranagar');
        expect(card.body, 'Ancy made a change. Open to see it.');
        expect(card.tapPayload.module, NotificationModule.activity);
      });
    });

    test(
        'list batch across two background invocations restores state from preferences',
        () async {
      final seedDb = AppDatabase(NativeDatabase.memory());
      addTearDown(seedDb.close);
      await _seedHousehold(seedDb);

      final prefs = await SharedPreferences.getInstance();
      final sinkInvocation1 = FakeNotificationSink();

      // Background invocation 1 at t = 0s
      await withClock(Clock.fixed(fixedNow), () async {
        final pipeline1 = NotificationPipeline(
          database: seedDb,
          sink: sinkInvocation1,
          sharedPreferences: prefs,
          getViewerUserId: () => 'user-saba',
          decryptEvent: ({
            required String homeId,
            required String eventId,
            required String eventType,
            required Map<String, dynamic> data,
          }) async {
            return DecryptedEvent(
              id: eventId,
              homeId: homeId,
              eventType: eventType,
              actorId: 'user-ancy',
              payload: <String, dynamic>{
                'id': 'item-1',
                'list_id': 'list-groceries',
                'title': 'Coffee beans — dark roast',
              },
            );
          },
        );

        final res1 = await pipeline1.handleRemoteMessage(
          RemoteMessage(
            data: <String, dynamic>{
              'home_id': 'home-indiranagar',
              'event_id': 'ev-list-1',
              'event_type': 'list_item_added',
            },
          ),
        );

        expect(res1.kind, PipelineOutcomeKind.shown);
        expect(sinkInvocation1.shown, hasLength(1));
        final firstCard = sinkInvocation1.shown.single;
        expect(firstCard.title, 'Groceries');
        expect(firstCard.body, 'Ancy added Coffee beans — dark roast');
        expect(firstCard.onlyAlertOnce, isFalse);
        expect(firstCard.inboxLines, isEmpty);
      });

      // Background invocation 2 (fresh pipeline instance, 25s later, state from SharedPreferences)
      final sinkInvocation2 = FakeNotificationSink();
      await withClock(
        Clock.fixed(fixedNow.add(const Duration(seconds: 25))),
        () async {
          final pipeline2 = NotificationPipeline(
            database: seedDb,
            sink: sinkInvocation2,
            sharedPreferences: prefs,
            getViewerUserId: () => 'user-saba',
            decryptEvent: ({
              required String homeId,
              required String eventId,
              required String eventType,
              required Map<String, dynamic> data,
            }) async {
              return DecryptedEvent(
                id: eventId,
                homeId: homeId,
                eventType: eventType,
                actorId: 'user-ancy',
                payload: <String, dynamic>{
                  'id': 'item-2',
                  'list_id': 'list-groceries',
                  'title': 'Curd, 500g',
                  'is_completed': true,
                  'unticked_left': 3,
                },
              );
            },
          );

          final res2 = await pipeline2.handleRemoteMessage(
            RemoteMessage(
              data: <String, dynamic>{
                'home_id': 'home-indiranagar',
                'event_id': 'ev-list-2',
                'event_type': 'list_item_toggled',
              },
            ),
          );

          expect(res2.kind, PipelineOutcomeKind.shown);
          expect(sinkInvocation2.shown, hasLength(1));

          final firstCard = sinkInvocation1.shown.single;
          final secondCard = sinkInvocation2.shown.single;
          expect(secondCard.id, firstCard.id);
          expect(secondCard.tag, 'list-groceries');
          expect(secondCard.title, 'Groceries');
          expect(secondCard.body, 'Ancy made two changes');
          expect(secondCard.onlyAlertOnce, isTrue);
          expect(secondCard.usesInboxStyle, isTrue);
          expect(secondCard.inboxLines, <String>[
            '+ Coffee beans — dark roast',
            '✓ Curd, 500g',
          ]);
          expect(secondCard.isBatch, isTrue);
          expect(secondCard.tapPayload.module, NotificationModule.lists);
          expect(secondCard.tapPayload.listId, 'list-groceries');
          expect(secondCard.tapPayload.isBatch, isTrue);
        },
      );
    });

    test(
        'message with a notification block is ignored so we do not show a duplicate',
        () async {
      final seedDb = AppDatabase(NativeDatabase.memory());
      addTearDown(seedDb.close);
      await _seedHousehold(seedDb);

      final sink = FakeNotificationSink();
      var decryptCalled = false;

      final pipeline = NotificationPipeline(
        database: seedDb,
        sink: sink,
        getViewerUserId: () => 'user-saba',
        decryptEvent: ({
          required String homeId,
          required String eventId,
          required String eventType,
          required Map<String, dynamic> data,
        }) async {
          decryptCalled = true;
          throw StateError('Should not be called');
        },
      );

      final legacyMessage = RemoteMessage(
        notification: const RemoteNotification(
          title: 'Legacy server push',
          body: 'Displayed by Android OS directly',
        ),
        data: <String, dynamic>{
          'home_id': 'home-indiranagar',
          'event_id': 'ev-legacy-1',
          'event_type': 'expense_added',
        },
      );

      final result = await pipeline.handleRemoteMessage(legacyMessage);

      expect(result.kind, PipelineOutcomeKind.ignoredNotificationBlock);
      expect(decryptCalled, isFalse);
      expect(sink.shown, isEmpty);
    });

    test('nothing in the pipeline writes to the database (strictly read-only)',
        () async {
      await withClock(Clock.fixed(fixedNow), () async {
        // Set up an in-memory database, seed it, then wrap its executor in
        // ReadOnlyQueryExecutor to prove the pipeline never issues any write.
        final baseExecutor = NativeDatabase.memory();
        final writableDb = AppDatabase(baseExecutor);
        await _seedHousehold(writableDb);

        // Also seed a decrypted activity event in localActivityEvents so the
        // pipeline exercises ReadOnlyEventDecryptor + buildContextFromReadOnlyDatabase.
        await writableDb.into(writableDb.localActivityEvents).insert(
              LocalActivityEventsCompanion.insert(
                id: 'ev-readonly-1',
                homeId: 'home-indiranagar',
                actorId: 'user-ancy',
                eventType: 'expense_added',
                payloadJson: jsonEncode(<String, dynamic>{
                  'id': 'exp-readonly-1',
                  'title': 'Coffee beans — dark roast',
                  'amount': 820,
                }),
                createdAt: fixedNow,
              ),
            );

        final readOnlyExecutor = ReadOnlyQueryExecutor(baseExecutor);
        final readOnlyDb = AppDatabase(readOnlyExecutor);
        addTearDown(writableDb.close);

        final sink = FakeNotificationSink();
        final prefs = await SharedPreferences.getInstance();

        final pipeline = NotificationPipeline(
          database: readOnlyDb,
          sink: sink,
          sharedPreferences: prefs,
          getViewerUserId: () => 'user-saba',
        );

        final outboxBefore =
            await writableDb.select(writableDb.localOutboxEvents).get();
        final expensesBefore =
            await writableDb.select(writableDb.localExpenses).get();
        final eventsBefore =
            await writableDb.select(writableDb.localActivityEvents).get();

        final result = await pipeline.handleRemoteMessage(
          RemoteMessage(
            data: <String, dynamic>{
              'home_id': 'home-indiranagar',
              'event_id': 'ev-readonly-1',
              'event_type': 'expense_added',
            },
          ),
        );

        expect(result.kind, PipelineOutcomeKind.shown);
        expect(sink.shown, hasLength(1));
        expect(
          sink.shown.single.body,
          'Ancy logged ₹820 for Coffee beans — dark roast',
        );

        // Assert zero write attempts and positive read queries on the read-only executor.
        expect(readOnlyExecutor.writeAttempts, 0);
        expect(readOnlyExecutor.selectCount, greaterThan(0));

        // Assert database tables and outbox are completely untouched.
        final outboxAfter =
            await writableDb.select(writableDb.localOutboxEvents).get();
        final expensesAfter =
            await writableDb.select(writableDb.localExpenses).get();
        final eventsAfter =
            await writableDb.select(writableDb.localActivityEvents).get();

        expect(outboxAfter, isEmpty);
        expect(outboxAfter.length, outboxBefore.length);
        expect(expensesAfter.length, expensesBefore.length);
        expect(eventsAfter.length, eventsBefore.length);

        // And verify ReadOnlyQueryExecutor actively rejects any accidental write.
        await expectLater(
          () => readOnlyDb.into(readOnlyDb.localOutboxEvents).insert(
                LocalOutboxEventsCompanion.insert(
                  id: 'forbidden-write',
                  homeId: 'home-indiranagar',
                  actorId: 'user-ancy',
                  eventType: 'expense_added',
                  payloadJson: '{}',
                  encryptedPayload: '{}',
                  createdAt: fixedNow,
                ),
              ),
          throwsA(isA<StateError>()),
        );
        expect(readOnlyExecutor.writeAttempts, 1);
      });
    });

    test(
        'opening a list calls closeBatch(listId) and cancels its active notification card',
        () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final prefs = await SharedPreferences.getInstance();
        final batcher = await NotificationBatcherPreferences.load(prefs);

        final decision = batcher.offer(
          const NotificationCopy(
            title: 'Groceries',
            body: 'Ancy added Coffee beans — dark roast',
            groupKey: NotificationModule.lists,
            batchKey: 'list-groceries',
            partnerName: 'Ancy',
            batchLine: '+ Coffee beans — dark roast',
          ),
          fixedNow,
        );
        await NotificationBatcherPreferences.save(batcher, prefs);

        final sink = FakeNotificationSink();
        final service = NotificationService(notificationSink: sink);
        await service.onListOpened('list-groceries');

        expect(sink.cancelled, [
          (id: decision.id!, tag: 'list-groceries'),
        ]);

        final reloaded = await NotificationBatcherPreferences.load(prefs);
        expect(reloaded.activeNotificationIdForList('list-groceries'), isNull);
      });
    });

    testWidgets(
        'tapping a batch notification routes through NotificationDetailDispatcher to open that list',
        (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedHousehold(db);

      final prefs = await SharedPreferences.getInstance();
      final batcher = await NotificationBatcherPreferences.load(prefs);
      final decision = batcher.offer(
        const NotificationCopy(
          title: 'Groceries',
          body: 'Ancy added Coffee beans — dark roast',
          groupKey: NotificationModule.lists,
          batchKey: 'list-groceries',
          partnerName: 'Ancy',
          batchLine: '+ Coffee beans — dark roast',
        ),
        fixedNow,
      );
      await NotificationBatcherPreferences.save(batcher, prefs);

      final sink = FakeNotificationSink();
      final service = NotificationService(notificationSink: sink);

      late WidgetRef capturedRef;
      late BuildContext capturedContext;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            notificationServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                capturedRef = ref;
                capturedContext = context;
                return const Scaffold(body: SizedBox.shrink());
              },
            ),
          ),
        ),
      );

      final batchPayload = CoveNotificationPayload(
        homeId: 'home-indiranagar',
        module: NotificationModule.lists,
        eventType: 'list_item_toggled',
        title: 'Groceries',
        body: 'Ancy made two changes',
        listId: 'list-groceries',
        isBatch: true,
        payload: const <String, dynamic>{
          'list_id': 'list-groceries',
          'list_name': 'Groceries',
          'is_batch': true,
        },
      );

      await NotificationDetailDispatcher.openDetailForNotification(
        capturedContext,
        capturedRef,
        batchPayload,
        delay: Duration.zero,
      );
      await tester.pump();

      expect(capturedRef.read(selectedListIdProvider), 'list-groceries');
      expect(sink.cancelled, [
        (id: decision.id!, tag: 'list-groceries'),
      ]);
    });

    test(
        'local check-in reminders use §2 copy (Evening / A quiet moment, together.)',
        () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedHousehold(db);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            activeHomeIdProvider.overrideWith(
              () => _FixedActiveHomeNotifier('home-indiranagar'),
            ),
          ],
        );
        addTearDown(container.dispose);

        final sink = FakeNotificationSink();
        final notifier = container.read(checkinRemindersProvider.notifier);

        final defaultReminder = CheckinReminder(
          id: 'rem-default',
          hour: 20,
          minute: 30,
          message: kDefaultWarmPresets.first,
          createdAt: fixedNow,
        );
        await notifier.previewNotification(defaultReminder, sink: sink);

        expect(sink.shown, hasLength(1));
        expect(sink.shown.first.title, 'Evening');
        expect(sink.shown.first.body, 'A quiet moment, together.');
        expect(sink.shown.first.icon, '@drawable/ic_stat_cove');
        expect(sink.shown.first.color, CoveTokens.dark.accentFill);

        final customReminder = CheckinReminder(
          id: 'rem-custom',
          hour: 21,
          minute: 0,
          message: 'Sunday balcony tea',
          createdAt: fixedNow,
        );
        await notifier.previewNotification(customReminder, sink: sink);

        expect(sink.shown, hasLength(2));
        expect(sink.shown.last.title, 'Sunday balcony tea');
        expect(sink.shown.last.body, 'A quiet moment, together.');
      });
    });
  });

  group('Real SQLite File & Isolate Concurrency Guarantees (3.14c)', () {
    test(
        '(a) Writer connection open (as the main app) -> run the background read path -> the writer can still insert, update and delete afterwards',
        () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final tempDir = await Directory.systemTemp.createTemp('cove_314c_a_');
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final dbFile = File('${tempDir.path}/cove_db.sqlite');

        final writerDb = _openWriterDatabaseOnFile(dbFile);
        addTearDown(writerDb.close);

        await _seedHousehold(writerDb);
        await writerDb.into(writerDb.localActivityEvents).insert(
              LocalActivityEventsCompanion.insert(
                id: 'ev-file-a-1',
                homeId: 'home-indiranagar',
                actorId: 'user-ancy',
                eventType: 'expense_logged',
                payloadJson: jsonEncode(<String, dynamic>{
                  'id': 'exp-file-a-1',
                  'title': 'Coffee beans — dark roast',
                  'amount': 820,
                }),
                createdAt: fixedNow,
              ),
            );

        // Verify the database's journal mode is untouched ('delete').
        final journalRow =
            await writerDb.customSelect('PRAGMA journal_mode;').getSingle();
        expect(journalRow.read<String>('journal_mode'), 'delete');

        // Ensure no main isolate port is registered so the background path opens
        // its own unshared OpenMode.readOnly connection against the same file.
        final bgSink = FakeNotificationSink();
        final prefs = await SharedPreferences.getInstance();
        var readOnlyOpenedCount = 0;

        final bgResult = await NotificationService.handleBackgroundRemoteMessage(
          RemoteMessage(
            data: <String, dynamic>{
              'home_id': 'home-indiranagar',
              'event_id': 'ev-file-a-1',
              'event_type': 'expense_logged',
            },
          ),
          databaseFile: dbFile,
          onReadOnlyDatabaseOpened: () => readOnlyOpenedCount += 1,
          sinkOverride: bgSink,
          sharedPreferencesOverride: prefs,
          viewerUserIdOverride: 'user-saba',
        );

        expect(readOnlyOpenedCount, 1);
        expect(bgResult.kind, PipelineOutcomeKind.shown);
        expect(bgSink.shown, hasLength(1));
        expect(
          bgSink.shown.single.body,
          'Ancy logged ₹820 for Coffee beans — dark roast',
        );

        // Afterwards, the writer connection can still INSERT, UPDATE, and DELETE.
        await writerDb.into(writerDb.localExpenses).insert(
              LocalExpensesCompanion.insert(
                id: 'exp-after-bg-read',
                homeId: 'home-indiranagar',
                title: 'Filter coffee powder',
                amount: 340,
                paidBy: 'user-saba',
                expenseDate: fixedNow,
                createdAt: fixedNow,
              ),
            );

        var inserted = await (writerDb.select(writerDb.localExpenses)
              ..where((t) => t.id.equals('exp-after-bg-read')))
            .getSingleOrNull();
        expect(inserted, isNotNull);
        expect(inserted!.amount, 340);

        await (writerDb.update(writerDb.localExpenses)
              ..where((t) => t.id.equals('exp-after-bg-read')))
            .write(const LocalExpensesCompanion(amount: Value(410)));

        var updated = await (writerDb.select(writerDb.localExpenses)
              ..where((t) => t.id.equals('exp-after-bg-read')))
            .getSingleOrNull();
        expect(updated, isNotNull);
        expect(updated!.amount, 410);

        final deletedCount = await (writerDb.delete(writerDb.localExpenses)
              ..where((t) => t.id.equals('exp-after-bg-read')))
            .go();
        expect(deletedCount, 1);

        final afterDelete = await (writerDb.select(writerDb.localExpenses)
              ..where((t) => t.id.equals('exp-after-bg-read')))
            .getSingleOrNull();
        expect(afterDelete, isNull);
      });
    });

    test(
        '(b) The background read path opened first -> open the main AppDatabase -> its migrations run and it can write, both while the reader is open and after it closes',
        () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final tempDir = await Directory.systemTemp.createTemp('cove_314c_b_');
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final dbFile = File('${tempDir.path}/cove_db.sqlite');

        // 1. Open the background read-only connection FIRST before the main
        //    AppDatabase has ever opened or migrated the file.
        final readerDb = AppDatabase.readOnly(file: dbFile);
        var readerClosed = false;
        addTearDown(() async {
          if (!readerClosed) {
            await readerDb.close();
          }
        });

        // Trigger the reader connection to open by running the pipeline on it.
        final bgSink = FakeNotificationSink();
        final prefs = await SharedPreferences.getInstance();
        final preMigrationPipeline = NotificationPipeline(
          database: readerDb,
          sink: bgSink,
          sharedPreferences: prefs,
          getViewerUserId: () => 'user-saba',
          decryptEvent: ({
            required String homeId,
            required String eventId,
            required String eventType,
            required Map<String, dynamic> data,
          }) async {
            return DecryptedEvent(
              id: eventId,
              homeId: homeId,
              eventType: eventType,
              actorId: 'user-ancy',
              payload: const <String, dynamic>{
                'id': 'exp-pre-1',
                'title': 'Sourdough loaf',
                'amount': 260,
                'actor_name': 'Ancy',
                'currency': 'INR',
              },
            );
          },
        );

        final preRes = await preMigrationPipeline.handleRemoteMessage(
          RemoteMessage(
            data: <String, dynamic>{
              'home_id': 'home-indiranagar',
              'event_id': 'ev-pre-1',
              'event_type': 'expense_logged',
            },
          ),
        );
        expect(preRes.kind, PipelineOutcomeKind.shown);

        // 2. While the reader is STILL OPEN, open the main AppDatabase on the same file.
        final writerDb = _openWriterDatabaseOnFile(dbFile);
        addTearDown(writerDb.close);

        // Verify migrations ran (user_version == schemaVersion) and writer can
        // insert, update, and delete WHILE the reader is open.
        await _seedHousehold(writerDb);
        final versionRow =
            await writerDb.customSelect('PRAGMA user_version;').getSingle();
        expect(
          versionRow.read<int>('user_version'),
          writerDb.schemaVersion,
        );

        await writerDb.into(writerDb.localExpenses).insert(
              LocalExpensesCompanion.insert(
                id: 'exp-while-reader-open',
                homeId: 'home-indiranagar',
                title: 'Avocados',
                amount: 250,
                paidBy: 'user-ancy',
                expenseDate: fixedNow,
                createdAt: fixedNow,
              ),
            );
        await (writerDb.update(writerDb.localExpenses)
              ..where((t) => t.id.equals('exp-while-reader-open')))
            .write(const LocalExpensesCompanion(amount: Value(275)));
        expect(
          (await (writerDb.select(writerDb.localExpenses)
                    ..where((t) => t.id.equals('exp-while-reader-open')))
                  .getSingle())
              .amount,
          275,
        );
        await (writerDb.delete(writerDb.localExpenses)
              ..where((t) => t.id.equals('exp-while-reader-open')))
            .go();

        // Reader can also read the migrated tables while open.
        final homeFromReader = await (readerDb.select(readerDb.localHomes)
              ..where((t) => t.id.equals('home-indiranagar')))
            .getSingleOrNull();
        expect(homeFromReader?.name, 'Indiranagar');

        // 3. Close the reader connection and verify the writer STILL works
        //    after the reader closes.
        await readerDb.close();
        readerClosed = true;

        await writerDb.into(writerDb.localExpenses).insert(
              LocalExpensesCompanion.insert(
                id: 'exp-after-reader-closed',
                homeId: 'home-indiranagar',
                title: 'Olive oil',
                amount: 950,
                paidBy: 'user-saba',
                expenseDate: fixedNow,
                createdAt: fixedNow,
              ),
            );
        await (writerDb.update(writerDb.localExpenses)
              ..where((t) => t.id.equals('exp-after-reader-closed')))
            .write(const LocalExpensesCompanion(amount: Value(990)));
        expect(
          (await (writerDb.select(writerDb.localExpenses)
                    ..where((t) => t.id.equals('exp-after-reader-closed')))
                  .getSingle())
              .amount,
          990,
        );
        final deletedAfterClose = await (writerDb.delete(writerDb.localExpenses)
              ..where((t) => t.id.equals('exp-after-reader-closed')))
            .go();
        expect(deletedAfterClose, 1);
      });
    });

    test(
        '(c) Main port registered -> the background handler forwards and opens no connection',
        () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final tempDir = await Directory.systemTemp.createTemp('cove_314c_c_');
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final dbFile = File('${tempDir.path}/cove_db.sqlite');

        final writerDb = _openWriterDatabaseOnFile(dbFile);
        addTearDown(writerDb.close);
        await _seedHousehold(writerDb);
        await writerDb.into(writerDb.localActivityEvents).insert(
              LocalActivityEventsCompanion.insert(
                id: 'ev-forward-1',
                homeId: 'home-indiranagar',
                actorId: 'user-ancy',
                eventType: 'expense_logged',
                payloadJson: jsonEncode(<String, dynamic>{
                  'id': 'exp-forward-1',
                  'title': 'Coffee beans — dark roast',
                  'amount': 820,
                }),
                createdAt: fixedNow,
              ),
            );

        final mainSink = FakeNotificationSink();
        final mainService = NotificationService(
          appDatabase: writerDb,
          notificationSink: mainSink,
          getCurrentUserId: () => 'user-saba',
          getPartnerName: () => 'Ancy',
          getCurrencySymbol: () => '₹',
        );
        addTearDown(mainService.dispose);

        // Register the main isolate's ReceivePort with IsolateNameServer.
        mainService.registerMainIsolatePort();
        expect(
          IsolateNameServer.lookupPortByName(
            NotificationService.mainIsolatePortName,
          ),
          isNotNull,
        );

        final bgSink = FakeNotificationSink();
        var bgReadOnlyOpenCount = 0;

        final bgResult = await NotificationService.handleBackgroundRemoteMessage(
          RemoteMessage(
            data: <String, dynamic>{
              'home_id': 'home-indiranagar',
              'event_id': 'ev-forward-1',
              'event_type': 'expense_logged',
            },
          ),
          databaseFile: dbFile,
          onReadOnlyDatabaseOpened: () => bgReadOnlyOpenCount += 1,
          sinkOverride: bgSink,
        );

        // Background handler forwarded to main isolate and opened NO database connection.
        expect(bgResult.kind, PipelineOutcomeKind.forwardedToMainIsolate);
        expect(bgReadOnlyOpenCount, 0);
        expect(bgSink.shown, isEmpty);

        // Wait for the main isolate's async handleIncomingMessage to complete
        // (since 'received' was sent immediately before processing).
        await mainService.waitForForwardedMessage();

        // Main isolate received the forwarded data and ran the pipeline with its
        // own database and providers.
        expect(mainSink.shown, hasLength(1));
        expect(mainSink.shown.single.title, 'Expenses');
        expect(
          mainSink.shown.single.body,
          'Ancy logged ₹820 for Coffee beans — dark roast',
        );
      });
    });

    test(
        '(d) The read-only connection rejects a write at the SQLite level, not just in Dart',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('cove_314c_d_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final dbFile = File('${tempDir.path}/cove_db.sqlite');

      // Initialize the database file schema via a normal writer connection, then close it.
      final writerDb = _openWriterDatabaseOnFile(dbFile);
      await _seedHousehold(writerDb);
      await writerDb.close();

      // Open the raw SQLite read-only executor (`OpenMode.readOnly`) directly,
      // bypassing the Dart `ReadOnlyQueryExecutor` wrapper so SQL statements reach
      // the SQLite C engine itself.
      final rawSqliteReadOnlyDb = AppDatabase(
        AppDatabase.openReadOnlySqliteExecutor(file: dbFile),
      );
      addTearDown(rawSqliteReadOnlyDb.close);

      // Reads succeed at the SQLite level.
      final homes =
          await rawSqliteReadOnlyDb.select(rawSqliteReadOnlyDb.localHomes).get();
      expect(homes, hasLength(1));
      expect(homes.single.name, 'Indiranagar');

      // Writes are rejected by SQLite itself with SqliteException (SQLITE_READONLY = 8).
      await expectLater(
        () => rawSqliteReadOnlyDb.into(rawSqliteReadOnlyDb.localExpenses).insert(
              LocalExpensesCompanion.insert(
                id: 'exp-sqlite-readonly',
                homeId: 'home-indiranagar',
                title: 'Forbidden SQLite write',
                amount: 100,
                paidBy: 'user-ancy',
                expenseDate: fixedNow,
                createdAt: fixedNow,
              ),
            ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.resultCode,
            'resultCode (SQLITE_READONLY)',
            8,
          ),
        ),
      );

      await expectLater(
        () => rawSqliteReadOnlyDb.customStatement(
          "UPDATE local_homes SET name = 'Mutated' WHERE id = 'home-indiranagar';",
        ),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.resultCode,
            'resultCode (SQLITE_READONLY)',
            8,
          ),
        ),
      );
    });

    test(
        '(e) Stale port mapping (ReceivePort closed without unregistering) -> removes stale mapping, falls back to read-only path, and shows notification',
        () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final tempDir = await Directory.systemTemp.createTemp('cove_314c_e_');
        addTearDown(() async {
          IsolateNameServer.removePortNameMapping(
            NotificationService.mainIsolatePortName,
          );
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final dbFile = File('${tempDir.path}/cove_db.sqlite');

        final writerDb = _openWriterDatabaseOnFile(dbFile);
        addTearDown(writerDb.close);
        await _seedHousehold(writerDb);
        await writerDb.into(writerDb.localActivityEvents).insert(
              LocalActivityEventsCompanion.insert(
                id: 'ev-stale-port-1',
                homeId: 'home-indiranagar',
                actorId: 'user-ancy',
                eventType: 'expense_logged',
                payloadJson: jsonEncode(<String, dynamic>{
                  'id': 'exp-stale-port-1',
                  'title': 'Coffee beans — dark roast',
                  'amount': 820,
                }),
                createdAt: fixedNow,
              ),
            );

        // Register a port and close its ReceivePort WITHOUT unregistering from
        // IsolateNameServer (simulating a stale mapping after the main isolate died).
        final staleReceivePort = ReceivePort();
        IsolateNameServer.removePortNameMapping(
          NotificationService.mainIsolatePortName,
        );
        IsolateNameServer.registerPortWithName(
          staleReceivePort.sendPort,
          NotificationService.mainIsolatePortName,
        );
        staleReceivePort.close();

        // Confirm the stale port mapping is still registered before delivery.
        expect(
          IsolateNameServer.lookupPortByName(
            NotificationService.mainIsolatePortName,
          ),
          isNotNull,
        );

        final bgSink = FakeNotificationSink();
        final prefs = await SharedPreferences.getInstance();
        var bgReadOnlyOpenCount = 0;
        var staleFallbackCalled = false;

        final bgResult = await NotificationService.handleBackgroundRemoteMessage(
          RemoteMessage(
            data: <String, dynamic>{
              'home_id': 'home-indiranagar',
              'event_id': 'ev-stale-port-1',
              'event_type': 'expense_logged',
            },
          ),
          databaseFile: dbFile,
          onStalePortFallback: () async {
            staleFallbackCalled = true;
          },
          onReadOnlyDatabaseOpened: () => bgReadOnlyOpenCount += 1,
          sinkOverride: bgSink,
          sharedPreferencesOverride: prefs,
          viewerUserIdOverride: 'user-saba',
        );

        // Stale port mapping was removed after no 'received' receipt arrived.
        expect(
          IsolateNameServer.lookupPortByName(
            NotificationService.mainIsolatePortName,
          ),
          isNull,
        );
        expect(staleFallbackCalled, isTrue);

        // Background fell back to the read-only path and showed the notification.
        expect(bgReadOnlyOpenCount, 1);
        expect(bgResult.kind, PipelineOutcomeKind.shown);
        expect(bgSink.shown, hasLength(1));
        expect(bgSink.shown.single.title, 'Expenses');
        expect(
          bgSink.shown.single.body,
          'Ancy logged ₹820 for Coffee beans — dark roast',
        );
      });
    });

    test(
        '(f) Live main isolate that receipts -> one notification, shown by the main isolate only, never twice',
        () async {
      await withClock(Clock.fixed(fixedNow), () async {
        final tempDir = await Directory.systemTemp.createTemp('cove_314c_f_');
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final dbFile = File('${tempDir.path}/cove_db.sqlite');

        final writerDb = _openWriterDatabaseOnFile(dbFile);
        addTearDown(writerDb.close);
        await _seedHousehold(writerDb);
        await writerDb.into(writerDb.localActivityEvents).insert(
              LocalActivityEventsCompanion.insert(
                id: 'ev-live-receipt-1',
                homeId: 'home-indiranagar',
                actorId: 'user-ancy',
                eventType: 'expense_logged',
                payloadJson: jsonEncode(<String, dynamic>{
                  'id': 'exp-live-receipt-1',
                  'title': 'Coffee beans — dark roast',
                  'amount': 820,
                }),
                createdAt: fixedNow,
              ),
            );

        final mainSink = FakeNotificationSink();
        final mainService = NotificationService(
          appDatabase: writerDb,
          notificationSink: mainSink,
          getCurrentUserId: () => 'user-saba',
          getPartnerName: () => 'Ancy',
          getCurrencySymbol: () => '₹',
        );
        addTearDown(mainService.dispose);
        mainService.registerMainIsolatePort();

        final bgSink = FakeNotificationSink();
        final prefs = await SharedPreferences.getInstance();
        var bgReadOnlyOpenCount = 0;

        final bgResult = await NotificationService.handleBackgroundRemoteMessage(
          RemoteMessage(
            data: <String, dynamic>{
              'home_id': 'home-indiranagar',
              'event_id': 'ev-live-receipt-1',
              'event_type': 'expense_logged',
            },
          ),
          databaseFile: dbFile,
          onReadOnlyDatabaseOpened: () => bgReadOnlyOpenCount += 1,
          sinkOverride: bgSink,
          sharedPreferencesOverride: prefs,
          viewerUserIdOverride: 'user-saba',
        );

        await mainService.waitForForwardedMessage();

        // Main isolate acknowledged with 'received', so background returned
        // forwardedToMainIsolate without opening any DB or showing anything.
        expect(bgResult.kind, PipelineOutcomeKind.forwardedToMainIsolate);
        expect(bgReadOnlyOpenCount, 0);
        expect(bgSink.shown, isEmpty);

        // Exactly one notification was shown across both isolates — by the
        // main isolate only, never twice.
        expect(mainSink.shown, hasLength(1));
        expect(mainSink.shown.length + bgSink.shown.length, 1);
        expect(mainSink.shown.single.title, 'Expenses');
        expect(
          mainSink.shown.single.body,
          'Ancy logged ₹820 for Coffee beans — dark roast',
        );
      });
    });
  });
}
