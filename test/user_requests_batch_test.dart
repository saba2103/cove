import 'package:cove/core/utils/cove_currency_formatter.dart';
import 'package:cove/features/habits/habit_schedule.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/subscriptions/commitment_projection_utils.dart';
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

    test('Formats amounts using 1,00,00,000 Indian comma system without .00 and with decimals up to 2 places when non-zero', () {
      // Whole numbers or numbers ending in .00: NO decimals
      expect(formatCoveAmount(10000000), equals('1,00,00,000'));
      expect(formatCoveAmount(10000000.00), equals('1,00,00,000'));
      expect(formatCoveAmount(15400), equals('15,400'));
      expect(formatCoveAmount(15400.0), equals('15,400'));
      expect(formatCoveAmount(500), equals('500'));
      expect(formatCoveAmount(500.00), equals('500'));
      expect(formatCoveAmount(0), equals('0'));
      expect(formatCoveAmount(0.00), equals('0'));

      // Non-zero decimals: show up to 2 decimal places
      expect(formatCoveAmount(1234567.89), equals('12,34,567.89'));
      expect(formatCoveAmount(12.5), equals('12.5'));
      expect(formatCoveAmount(12.50), equals('12.5'));
      expect(formatCoveAmount(100.25), equals('100.25'));
      expect(formatCoveAmount(100 / 3), equals('33.33')); // 33.333333333333336 rounded to 2 places
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

  group('Commitments Strict Calendar and Overdue Classification', () {
    test('Correctly classifies overdue, this week, this month, next month, and later', () {
      // Reference simulated "today": September 18, 2026
      final today = DateTime(2026, 9, 18);
      final in7Days = today.add(const Duration(days: 7)); // September 25, 2026
      final nextMonthYear = today.month == 12 ? today.year + 1 : today.year;
      final nextMonthValue = today.month == 12 ? 1 : today.month + 1; // October 2026

      String classify(DateTime nextBillingDate) {
        final ren = DateTime(nextBillingDate.year, nextBillingDate.month, nextBillingDate.day);
        if (ren.isBefore(today)) {
          return 'overdue';
        } else if (ren.year == today.year && ren.month == today.month) {
          if (ren.isBefore(in7Days) || ren.isAtSameMomentAs(in7Days)) {
            return 'this_week';
          } else {
            return 'this_month';
          }
        } else if (ren.year == nextMonthYear && ren.month == nextMonthValue) {
          return 'next_month';
        } else {
          return 'later';
        }
      }

      // 1. Past due date not marked as paid -> overdue
      expect(classify(DateTime(2026, 9, 10)), 'overdue');
      expect(classify(DateTime(2026, 8, 31)), 'overdue');
      expect(classify(DateTime(2026, 9, 17)), 'overdue');

      // 2. Due today or within 7 days in current month -> this_week
      expect(classify(DateTime(2026, 9, 18)), 'this_week'); // today
      expect(classify(DateTime(2026, 9, 21)), 'this_week'); // in 3 days
      expect(classify(DateTime(2026, 9, 25)), 'this_week'); // exactly in 7 days

      // 3. Later in the current month -> this_month
      expect(classify(DateTime(2026, 9, 26)), 'this_month');
      expect(classify(DateTime(2026, 9, 30)), 'this_month');

      // 4. Next month 5th -> MUST be next_month, NOT this_month!
      expect(classify(DateTime(2026, 10, 5)), 'next_month');
      expect(classify(DateTime(2026, 10, 20)), 'next_month');

      // 5. Beyond next month -> later
      expect(classify(DateTime(2026, 11, 1)), 'later');
      expect(classify(DateTime(2026, 12, 15)), 'later');
      expect(classify(DateTime(2027, 3, 1)), 'later');
    });
  });

  group('Commitments Helicopter Projection Tests', () {
    test('Projects monthly and annual commitments correctly across 12 months', () {
      final subs = [
        // 1. Monthly subscription (Netflix, 649, renews 15th)
        LocalSubscription(
          id: 'sub_netflix',
          homeId: 'home_1',
          name: 'Netflix',
          amount: 649.0,
          currency: 'INR',
          billingCycle: 'monthly',
          nextBillingDate: DateTime(2026, 9, 15),
          isActive: true,
          isPrivate: false,
          createdAt: DateTime(2026, 1, 1),
          paidBy: 'me',
        ),
        // 2. Annual subscription (Disney+, 1499, renews Nov 20)
        LocalSubscription(
          id: 'sub_disney',
          homeId: 'home_1',
          name: 'Disney+ Hotstar',
          amount: 1499.0,
          currency: 'INR',
          billingCycle: 'annual',
          nextBillingDate: DateTime(2026, 11, 20),
          isActive: true,
          isPrivate: false,
          createdAt: DateTime(2025, 11, 20),
          paidBy: 'partner',
        ),
        // 3. EMI with 6 installments ending in October 2026 (5000/mo)
        LocalSubscription(
          id: 'emi_phone',
          homeId: 'home_1',
          name: 'iPhone EMI',
          amount: 5000.0,
          currency: 'INR',
          billingCycle: 'monthly',
          nextBillingDate: DateTime(2026, 9, 10),
          endDate: DateTime(2026, 10, 10),
          totalInstallments: 6,
          paidInstallments: 4,
          isActive: true,
          isPrivate: false,
          createdAt: DateTime(2026, 5, 10),
          paidBy: 'split',
        ),
      ];

      final projections = CommitmentProjectionUtils.projectYear(
        subscriptions: subs,
        year: 2026,
      );

      // Verify all 12 months are projected
      expect(projections.length, 12);

      // September 2026:
      // Netflix (649, sub) + iPhone EMI (5000, emi). Disney+ is NOT in Sept!
      final sept = projections[9]!;
      expect(sept.subsCount, 1);
      expect(sept.emisCount, 1);
      expect(sept.totalAmount, 649.0 + 5000.0);

      // October 2026:
      // Netflix (649, sub) + iPhone EMI (5000, emi, final installment).
      final oct = projections[10]!;
      expect(oct.subsCount, 1);
      expect(oct.emisCount, 1);
      expect(oct.totalAmount, 649.0 + 5000.0);

      // November 2026:
      // Netflix (649, sub) + Disney+ (1499, annual sub). iPhone EMI has ended (0 EMIs)!
      final nov = projections[11]!;
      expect(nov.subsCount, 2); // Netflix + Disney+
      expect(nov.emisCount, 0); // iPhone EMI ended
      expect(nov.totalAmount, 649.0 + 1499.0);

      // December 2026:
      // Netflix (649, sub) only. Disney+ is NOT in Dec, iPhone EMI is finished.
      final dec = projections[12]!;
      expect(dec.subsCount, 1);
      expect(dec.emisCount, 0);
      expect(dec.totalAmount, 649.0);

      // Attribution filtering in November
      final allNov = nov.filterByAttribution(tabIndex: 0, currentUserId: 'user_me', partnerUserId: 'user_partner');
      expect(allNov.length, 2);

      final mineNov = nov.filterByAttribution(tabIndex: 1, currentUserId: 'user_me', partnerUserId: 'user_partner');
      expect(mineNov.length, 1);
      expect(mineNov.first.name, 'Netflix');

      final partnerNov = nov.filterByAttribution(tabIndex: 2, currentUserId: 'user_me', partnerUserId: 'user_partner');
      expect(partnerNov.length, 1);
      expect(partnerNov.first.name, 'Disney+ Hotstar');

      // Split filtering in September
      final splitSept = sept.filterByAttribution(tabIndex: 3, currentUserId: 'user_me', partnerUserId: 'user_partner');
      expect(splitSept.length, 1);
      expect(splitSept.first.name, 'iPhone EMI');

      // Breakdown counts and amounts in September:
      // Netflix (649, Mine, 1 sub, 0 emi)
      // iPhone EMI (5000, Split, 0 sub, 1 emi)
      expect(sept.mineSubsCount('user_me', 'user_partner'), 1);
      expect(sept.mineEmisCount('user_me', 'user_partner'), 0);
      expect(sept.allocationMine('user_me', 'user_partner'), 649.0);

      expect(sept.partnerSubsCount('user_me', 'user_partner'), 0);
      expect(sept.partnerEmisCount('user_me', 'user_partner'), 0);
      expect(sept.allocationPartner('user_me', 'user_partner'), 0.0);

      expect(sept.splitSubsCount(), 0);
      expect(sept.splitEmisCount(), 1);
      expect(sept.allocationSplit(), 5000.0);

      // When 50/50 Separate toggle is ON:
      // Mine shows 649.0 (1 sub · 0 EMIs)
      // Partner shows 0.0 (0 subs · 0 EMIs)
      // 50/50 shows 5000.0 (0 subs · 1 EMI)
      final pureMine = sept.allocationMine('user_me', 'user_partner');
      final purePartner = sept.allocationPartner('user_me', 'user_partner');
      final split = sept.allocationSplit();
      expect(pureMine, 649.0);
      expect(purePartner, 0.0);
      expect(split, 5000.0);

      // When 50/50 Separate toggle is OFF:
      // Split is absorbed 50/50 into Mine and Partner:
      final absorbedMine = pureMine + (split / 2.0);
      final absorbedPartner = purePartner + (split / 2.0);
      expect(absorbedMine, 649.0 + 2500.0); // 3149.0
      expect(absorbedPartner, 0.0 + 2500.0); // 2500.0
      expect(absorbedMine + absorbedPartner, sept.totalAmount);
    });
  });
}
