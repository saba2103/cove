import 'dart:convert';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime(2026, 11, 14, 19, 15, 0);

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    NotificationDetailDispatcher.resetState();
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
}
