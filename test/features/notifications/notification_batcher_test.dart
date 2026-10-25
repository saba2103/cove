import 'package:cove/features/notifications/notification_batcher.dart';
import 'package:cove/features/notifications/notification_copy.dart';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final t0 = DateTime(2026, 11, 5, 18, 0, 0);

  NotificationContext baseCtx({int? untickedItemsLeft}) => NotificationContext(
        partnerName: 'Ancy',
        homeName: 'Indiranagar',
        currencySymbol: '₹',
        today: t0,
        viewerUserId: 'viewer_saba',
        untickedItemsLeft: untickedItemsLeft,
      );

  NotificationCopy addCopy({
    required String item,
    String listId = 'list_groceries',
    String listName = 'Groceries',
  }) =>
      composeNotification(
        DecryptedEvent(
          id: 'evt_add_$item',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'list_item_added',
          payload: {
            'list_id': listId,
            'list_name': listName,
            'title': item,
          },
        ),
        baseCtx(),
      )!;

  NotificationCopy tickCopy({
    required String item,
    int untickedLeft = 3,
    String listId = 'list_groceries',
    String listName = 'Groceries',
  }) =>
      composeNotification(
        DecryptedEvent(
          id: 'evt_tick_$item',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'list_item_toggled',
          payload: {
            'list_id': listId,
            'list_name': listName,
            'title': item,
            'is_completed': true,
          },
        ),
        baseCtx(untickedItemsLeft: untickedLeft),
      )!;

  NotificationCopy removeCopy({
    required String item,
    String listId = 'list_groceries',
    String listName = 'Groceries',
  }) =>
      composeNotification(
        DecryptedEvent(
          id: 'evt_del_$item',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'list_item_deleted',
          payload: {
            'list_id': listId,
            'list_name': listName,
            'title': item,
          },
        ),
        baseCtx(),
      )!;

  group('15-notifications.md §5 — NotificationBatcher (fixed clock)', () {
    test('1. one add → plain card', () {
      final batcher = NotificationBatcher();
      final d1 = batcher.offer(
        addCopy(item: 'Coffee beans — dark roast'),
        t0,
      );

      expect(d1.kind, BatchDecisionKind.showNew);
      expect(d1.isShowNew, isTrue);
      expect(d1.isPlainCard, isTrue);
      expect(d1.id, isNotNull);
      expect(d1.title, 'Groceries');
      expect(d1.body, 'Ancy added Coffee beans — dark roast');
      expect(d1.lines, isEmpty);
      expect(d1.onlyAlertOnce, isFalse);
      expect(d1.batchKey, 'list_groceries');
      expect(d1.groupKey, NotificationModule.lists);
    });

    test('2. add then tick at +30s → the same id, "Ancy made two changes", two lines in order', () {
      final batcher = NotificationBatcher();
      final d1 = batcher.offer(
        addCopy(item: 'Coffee beans — dark roast'),
        t0,
      );
      final d2 = batcher.offer(
        tickCopy(item: 'Curd, 500g'),
        t0.add(const Duration(seconds: 30)),
      );

      expect(d2.kind, BatchDecisionKind.replace);
      expect(d2.isReplace, isTrue);
      expect(d2.id, equals(d1.id));
      expect(d2.tag, equals(d1.tag));
      expect(d2.title, 'Groceries');
      expect(d2.body, 'Ancy made two changes');
      expect(d2.lines, <String>[
        '+ Coffee beans — dark roast',
        '✓ Curd, 500g',
      ]);
      expect(d2.onlyAlertOnce, isTrue);
    });

    test('3. four changes including a removal → "four changes", four lines', () {
      final batcher = NotificationBatcher();

      final d1 = batcher.offer(
        addCopy(item: 'Coffee beans — dark roast'),
        t0,
      );
      final d2 = batcher.offer(
        tickCopy(item: 'Curd, 500g'),
        t0.add(const Duration(seconds: 15)),
      );
      final d3 = batcher.offer(
        removeCopy(item: 'Dishwasher tablets'),
        t0.add(const Duration(seconds: 40)),
      );
      final d4 = batcher.offer(
        addCopy(item: 'Coriander'),
        t0.add(const Duration(seconds: 75)),
      );

      expect(d2.id, equals(d1.id));

      // The removal at +40s rides along into the open batch as a replace
      expect(d3.kind, BatchDecisionKind.rideAlong);
      expect(d3.isRideAlong, isTrue);
      expect(d3.isReplace, isTrue);
      expect(d3.id, equals(d1.id));
      expect(d3.body, 'Ancy made three changes');

      // Fourth change at +75s
      expect(d4.kind, BatchDecisionKind.replace);
      expect(d4.id, equals(d1.id));
      expect(d4.title, 'Groceries');
      expect(d4.body, 'Ancy made four changes');
      expect(d4.lines, <String>[
        '+ Coffee beans — dark roast',
        '✓ Curd, 500g',
        '− Dishwasher tablets',
        '+ Coriander',
      ]);
      expect(d4.onlyAlertOnce, isTrue);
    });

    test('4. a change at +91s → a new card with a new id', () {
      final batcher = NotificationBatcher();

      final d1 = batcher.offer(
        addCopy(item: 'Coffee beans — dark roast'),
        t0,
      );
      final d2 = batcher.offer(
        tickCopy(item: 'Curd, 500g'),
        t0.add(const Duration(seconds: 30)),
      );
      expect(d2.id, equals(d1.id));

      // +91s from the batch's first change (t0): window has closed
      final d3 = batcher.offer(
        addCopy(item: 'Sourdough bread'),
        t0.add(const Duration(seconds: 91)),
      );

      expect(d3.kind, BatchDecisionKind.showNew);
      expect(d3.isPlainCard, isTrue);
      expect(d3.id, isNotNull);
      expect(d3.id, isNot(equals(d1.id)));
      expect(d3.title, 'Groceries');
      expect(d3.body, 'Ancy added Sourdough bread');
      expect(d3.lines, isEmpty);
      expect(d3.onlyAlertOnce, isFalse);
    });

    test('5. a removal with no open batch → drop', () {
      final batcher = NotificationBatcher();

      // Removal when no batch has ever opened
      final dropInitial = batcher.offer(
        removeCopy(item: 'Dishwasher tablets'),
        t0,
      );
      expect(dropInitial.kind, BatchDecisionKind.drop);
      expect(dropInitial.isDrop, isTrue);
      expect(dropInitial.shouldShow, isFalse);
      expect(dropInitial.id, isNull);

      // Open a batch at t0, let it expire at +91s, then offer a removal
      batcher.offer(addCopy(item: 'Milk'), t0);
      final dropAfterExpiry = batcher.offer(
        removeCopy(item: 'Dishwasher tablets'),
        t0.add(const Duration(seconds: 91)),
      );
      expect(dropAfterExpiry.kind, BatchDecisionKind.drop);
      expect(dropAfterExpiry.isDrop, isTrue);
      expect(dropAfterExpiry.id, isNull);
    });

    test('6. Groceries and Coorg trip interleaved → two independent batches', () {
      final batcher = NotificationBatcher();

      final g1 = batcher.offer(
        addCopy(
          item: 'Coffee beans — dark roast',
          listId: 'list_groceries',
          listName: 'Groceries',
        ),
        t0,
      );
      final c1 = batcher.offer(
        addCopy(
          item: 'Rain jackets',
          listId: 'list_coorg',
          listName: 'Coorg trip',
        ),
        t0.add(const Duration(seconds: 10)),
      );
      final g2 = batcher.offer(
        tickCopy(
          item: 'Curd, 500g',
          listId: 'list_groceries',
          listName: 'Groceries',
        ),
        t0.add(const Duration(seconds: 20)),
      );
      final c2 = batcher.offer(
        tickCopy(
          item: 'Torch batteries',
          listId: 'list_coorg',
          listName: 'Coorg trip',
        ),
        t0.add(const Duration(seconds: 35)),
      );

      // Distinct notification IDs and tags
      expect(g1.id, isNot(equals(c1.id)));
      expect(g2.id, equals(g1.id));
      expect(c2.id, equals(c1.id));

      // Groceries batch has only Groceries items
      expect(g2.title, 'Groceries');
      expect(g2.body, 'Ancy made two changes');
      expect(g2.lines, <String>[
        '+ Coffee beans — dark roast',
        '✓ Curd, 500g',
      ]);

      // Coorg trip batch has only Coorg trip items
      expect(c2.title, 'Coorg trip');
      expect(c2.body, 'Ancy made two changes');
      expect(c2.lines, <String>[
        '+ Rain jackets',
        '✓ Torch batteries',
      ]);
    });

    test('7. closeBatch → the next change starts fresh', () {
      final batcher = NotificationBatcher();

      final d1 = batcher.offer(
        addCopy(item: 'Coffee beans — dark roast'),
        t0,
      );
      final d2 = batcher.offer(
        tickCopy(item: 'Curd, 500g'),
        t0.add(const Duration(seconds: 20)),
      );
      expect(d2.id, equals(d1.id));

      // User opens the Groceries list in the app at +25s
      final closedId = batcher.closeBatch('list_groceries');
      expect(closedId, equals(d1.id));

      // Next change at +40s (still within the original 90s, but batch was closed)
      // starts a brand-new plain card with a new ID
      final d3 = batcher.offer(
        addCopy(item: 'Ghee'),
        t0.add(const Duration(seconds: 40)),
      );
      expect(d3.kind, BatchDecisionKind.showNew);
      expect(d3.isPlainCard, isTrue);
      expect(d3.id, isNot(equals(d1.id)));
      expect(d3.title, 'Groceries');
      expect(d3.body, 'Ancy added Ghee');
      expect(d3.lines, isEmpty);
    });

    test('8. state round-trips through JSON mid-batch (and SharedPreferences)', () async {
      SharedPreferences.setMockInitialValues({});

      final batcherIsolate1 = NotificationBatcher();
      final d1 = batcherIsolate1.offer(
        addCopy(item: 'Coffee beans — dark roast'),
        t0,
      );
      final d2 = batcherIsolate1.offer(
        tickCopy(item: 'Curd, 500g'),
        t0.add(const Duration(seconds: 25)),
      );
      expect(d2.id, equals(d1.id));
      expect(d2.body, 'Ancy made two changes');

      // Round-trip through toJson / fromJson
      final jsonMap = batcherIsolate1.toJson();
      final batcherFromMap = NotificationBatcher.fromJson(jsonMap);
      final d3FromMap = batcherFromMap.offer(
        removeCopy(item: 'Dishwasher tablets'),
        t0.add(const Duration(seconds: 50)),
      );
      expect(d3FromMap.kind, BatchDecisionKind.rideAlong);
      expect(d3FromMap.id, equals(d1.id));
      expect(d3FromMap.body, 'Ancy made three changes');
      expect(d3FromMap.lines, <String>[
        '+ Coffee beans — dark roast',
        '✓ Curd, 500g',
        '− Dishwasher tablets',
      ]);

      // Also verify round-trip through local preferences helper across background isolates
      await NotificationBatcherPreferences.save(batcherFromMap);
      final batcherIsolate2 = await NotificationBatcherPreferences.load();
      final d4FromPrefs = batcherIsolate2.offer(
        addCopy(item: 'Filter paper'),
        t0.add(const Duration(seconds: 80)),
      );
      expect(d4FromPrefs.kind, BatchDecisionKind.replace);
      expect(d4FromPrefs.id, equals(d1.id));
      expect(d4FromPrefs.body, 'Ancy made four changes');
      expect(d4FromPrefs.lines, <String>[
        '+ Coffee beans — dark roast',
        '✓ Curd, 500g',
        '− Dishwasher tablets',
        '+ Filter paper',
      ]);

      // And after +91s on the restored batcher, the next card gets a fresh ID > d1.id
      final d5AfterWindow = batcherIsolate2.offer(
        addCopy(item: 'Bananas'),
        t0.add(const Duration(seconds: 91)),
      );
      expect(d5AfterWindow.kind, BatchDecisionKind.showNew);
      expect(d5AfterWindow.id, isNot(equals(d1.id)));
    });

    test('Non-list events never batch — each event is its own plain card', () {
      final batcher = NotificationBatcher();

      final exp1 = composeNotification(
        const DecryptedEvent(
          id: 'exp_1',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'expense_logged',
          payload: {'title': 'Coffee', 'amount': 250},
        ),
        baseCtx(),
      )!;
      final exp2 = composeNotification(
        const DecryptedEvent(
          id: 'exp_2',
          homeId: 'h1',
          actorId: 'partner_ancy',
          eventType: 'expense_logged',
          payload: {'title': 'Cab home', 'amount': 420},
        ),
        baseCtx(),
      )!;

      final d1 = batcher.offer(exp1, t0);
      final d2 = batcher.offer(exp2, t0.add(const Duration(seconds: 5)));

      expect(d1.kind, BatchDecisionKind.showNew);
      expect(d2.kind, BatchDecisionKind.showNew);
      expect(d1.id, isNot(equals(d2.id)));
      expect(d2.body, 'Ancy logged ₹420 for Cab home');
      expect(d2.lines, isEmpty);
    });
  });
}
