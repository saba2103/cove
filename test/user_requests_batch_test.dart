import 'package:cove/features/habits/habit_schedule.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HabitSchedule Unit Tests', () {
    test('Parses and formats daily schedule with and without time', () {
      final s1 = HabitSchedule.parse('daily');
      expect(s1.frequency, 'daily');
      expect(s1.daysOfWeek, [1, 2, 3, 4, 5, 6, 7]);
      expect(s1.timeOfDay, isNull);
      expect(s1.formatDisplayLabel(), 'Daily');

      final s2 = HabitSchedule.parse('daily@08:30');
      expect(s2.frequency, 'daily');
      expect(s2.timeOfDay, const TimeOfDay(hour: 8, minute: 30));
      expect(s2.formatDisplayLabel(), 'Daily • 8:30 AM');
      expect(s2.toCadenceString(), 'daily@08:30');
    });

    test('Parses and formats weekly schedule with single and multiple days', () {
      final s1 = HabitSchedule.parse('weekly:6@09:15');
      expect(s1.frequency, 'weekly');
      expect(s1.daysOfWeek, [6]);
      expect(s1.timeOfDay, const TimeOfDay(hour: 9, minute: 15));
      expect(s1.formatDisplayLabel(), 'Every Sat • 9:15 AM');
      expect(s1.toCadenceString(), 'weekly:6@09:15');

      final s2 = HabitSchedule.parse('weekly:1,5');
      expect(s2.frequency, 'weekly');
      expect(s2.daysOfWeek, [1, 5]);
      expect(s2.formatDisplayLabel(), 'Weekly (Mon, Fri)');
    });

    test('Parses and formats custom schedule with days and time', () {
      final s1 = HabitSchedule.parse('custom:1,3,5@18:00');
      expect(s1.frequency, 'custom');
      expect(s1.daysOfWeek, [1, 3, 5]);
      expect(s1.timeOfDay, const TimeOfDay(hour: 18, minute: 0));
      expect(s1.formatDisplayLabel(), 'Mon, Wed, Fri • 6:00 PM');
      expect(s1.toCadenceString(), 'custom:1,3,5@18:00');
    });
  });

  group('LocalStateStoreImpl Events for List and Habit modifications', () {
    late AppDatabase db;
    late LocalStateStoreImpl store;
    const testHomeId = 'test_home_123';
    const testAuthorId = 'user_1';

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      store = LocalStateStoreImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Handles list_renamed and list_deleted in LocalStateStore', () async {
      final now = DateTime.now();

      // Create list
      await store.applyEvent(
        eventType: 'list_created',
        homeId: testHomeId,
        authorId: testAuthorId,
        timestamp: now,
        payload: {
          'id': 'list_1',
          'name': 'Original Groceries',
        },
      );

      var lists = await db.select(db.localLists).get();
      expect(lists.length, 1);
      expect(lists.first.name, 'Original Groceries');

      // Add item to list
      await store.applyEvent(
        eventType: 'list_item_added',
        homeId: testHomeId,
        authorId: testAuthorId,
        timestamp: now,
        payload: {
          'id': 'item_1',
          'list_id': 'list_1',
          'title': 'Oat Milk',
        },
      );

      var items = await db.select(db.localListItems).get();
      expect(items.length, 1);
      expect(items.first.title, 'Oat Milk');

      // Rename list
      await store.applyEvent(
        eventType: 'list_renamed',
        homeId: testHomeId,
        authorId: testAuthorId,
        timestamp: now,
        payload: {
          'id': 'list_1',
          'name': 'Supermarket & Pantry',
        },
      );

      lists = await db.select(db.localLists).get();
      expect(lists.first.name, 'Supermarket & Pantry');

      // Update list item
      await store.applyEvent(
        eventType: 'list_item_updated',
        homeId: testHomeId,
        authorId: testAuthorId,
        timestamp: now,
        payload: {
          'id': 'item_1',
          'title': 'Organic Almond Milk',
          'notes': 'Unsweetened',
        },
      );

      items = await db.select(db.localListItems).get();
      expect(items.first.title, 'Organic Almond Milk');
      expect(items.first.notes, 'Unsweetened');

      // Delete list (should delete list and its items)
      await store.applyEvent(
        eventType: 'list_deleted',
        homeId: testHomeId,
        authorId: testAuthorId,
        timestamp: now,
        payload: {
          'id': 'list_1',
        },
      );

      lists = await db.select(db.localLists).get();
      expect(lists.isEmpty, isTrue);
      items = await db.select(db.localListItems).get();
      expect(items.isEmpty, isTrue);
    });

    test('Handles habit_updated in LocalStateStore', () async {
      final now = DateTime.now();

      // Create habit
      await store.applyEvent(
        eventType: 'habit_created',
        homeId: testHomeId,
        authorId: testAuthorId,
        timestamp: now,
        payload: {
          'id': 'habit_1',
          'name': 'Morning Jog',
          'cadence': 'daily',
          'target_days_per_week': 7,
          'is_private': false,
        },
      );

      var habits = await db.select(db.localHabits).get();
      expect(habits.length, 1);
      expect(habits.first.name, 'Morning Jog');
      expect(habits.first.cadence, 'daily');
      expect(habits.first.targetDaysPerWeek, 7);

      // Update habit to weekly on Saturday at 08:00
      await store.applyEvent(
        eventType: 'habit_updated',
        homeId: testHomeId,
        authorId: testAuthorId,
        timestamp: now,
        payload: {
          'id': 'habit_1',
          'name': 'Weekend Long Run',
          'cadence': 'weekly:6@08:00',
          'target_days_per_week': 1,
          'is_private': false,
        },
      );

      habits = await db.select(db.localHabits).get();
      expect(habits.first.name, 'Weekend Long Run');
      expect(habits.first.cadence, 'weekly:6@08:00');
      expect(habits.first.targetDaysPerWeek, 1);
    });
  });

  group('Currency Preference Symbols', () {
    test('Supported currencies include INR with rupee symbol', () {
      final inr = supportedCurrencies.firstWhere((c) => c.code == 'INR');
      expect(inr.symbol, '₹');
      expect(inr.name, 'Indian Rupee');

      final usd = supportedCurrencies.firstWhere((c) => c.code == 'USD');
      expect(usd.symbol, '\$');
    });
  });

  group('Grocery List Sync and Auto-Healing', () {
    test('ensureDefaultLists adds missing default lists without duplicating or dropping existing ones', () async {
      final db = AppDatabase(NativeDatabase.memory());
      const homeId = 'home_sync_test';
      const userId = 'user_1';

      // First run: all 3 created
      await db.ensureDefaultLists(homeId, userId);
      var lists = await db.getLists(homeId);
      expect(lists.length, 3);
      expect(lists.map((l) => l.name.toLowerCase()), containsAll(['grocery', 'travel', 'planning']));

      // Second run: no duplicates created
      await db.ensureDefaultLists(homeId, userId);
      lists = await db.getLists(homeId);
      expect(lists.length, 3);

      // Simulate case where partner only had 'travel' and 'planning' locally
      // Delete 'grocery' from local DB
      final groceryList = lists.firstWhere((l) => l.name.toLowerCase() == 'grocery');
      await (db.delete(db.localLists)..where((t) => t.id.equals(groceryList.id))).go();

      lists = await db.getLists(homeId);
      expect(lists.length, 2);

      // ensureDefaultLists auto-heals and recreates Grocery
      await db.ensureDefaultLists(homeId, userId);
      lists = await db.getLists(homeId);
      expect(lists.length, 3);
      expect(lists.map((l) => l.name.toLowerCase()), contains('grocery'));

      await db.close();
    });
  });

  group('Commitments Attribution and 50/50 Split Calculations', () {
    test('Calculates mine, partner, and split totals accurately with 50/50 distribution', () {
      const myUserId = 'user_alex';
      const partnerUserId = 'user_sarah';

      final commitments = [
        // Mine: 1 sub (100.0) + 1 EMI (500.0)
        (paidBy: 'me', createdBy: myUserId, amount: 100.0, isEmi: false),
        (paidBy: myUserId, createdBy: myUserId, amount: 500.0, isEmi: true),
        // Partner: 1 sub (50.0) + 1 EMI (200.0)
        (paidBy: partnerUserId, createdBy: partnerUserId, amount: 50.0, isEmi: false),
        (paidBy: 'partner_user', createdBy: partnerUserId, amount: 200.0, isEmi: true),
        // Split: 1 sub (80.0) + 1 EMI (400.0)
        (paidBy: 'split', createdBy: myUserId, amount: 80.0, isEmi: false),
        (paidBy: '50/50', createdBy: partnerUserId, amount: 400.0, isEmi: true),
      ];

      double mineAmount = 0.0;
      int mineSubs = 0;
      int mineEmis = 0;

      double partnerAmount = 0.0;
      int partnerSubs = 0;
      int partnerEmis = 0;

      double splitAmount = 0.0;
      int splitSubs = 0;
      int splitEmis = 0;

      for (final item in commitments) {
        final pb = item.paidBy.trim().toLowerCase();
        if (pb == 'split' || pb == '50/50') {
          splitAmount += item.amount;
          if (item.isEmi) {
            splitEmis++;
          } else {
            splitSubs++;
          }
        } else if (pb == partnerUserId || pb == 'partner_user') {
          partnerAmount += item.amount;
          if (item.isEmi) {
            partnerEmis++;
          } else {
            partnerSubs++;
          }
        } else {
          mineAmount += item.amount;
          if (item.isEmi) {
            mineEmis++;
          } else {
            mineSubs++;
          }
        }
      }

      // Unsplit verification
      expect(mineAmount, 600.0);
      expect(mineSubs, 1);
      expect(mineEmis, 1);

      expect(partnerAmount, 250.0);
      expect(partnerSubs, 1);
      expect(partnerEmis, 1);

      expect(splitAmount, 480.0);
      expect(splitSubs, 1);
      expect(splitEmis, 1);

      // 50/50 Split toggle calculation verification
      final effectiveMineAmount = mineAmount + (splitAmount / 2.0);
      final effectivePartnerAmount = partnerAmount + (splitAmount / 2.0);

      expect(effectiveMineAmount, 600.0 + 240.0); // 840.0
      expect(effectivePartnerAmount, 250.0 + 240.0); // 490.0
      expect(effectiveMineAmount + effectivePartnerAmount, mineAmount + partnerAmount + splitAmount); // 1330.0
    });
  });
}
