import 'dart:io';

import 'package:cove/sync/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'drift/generated/schema.dart';
import 'drift/generated/schema_v11.dart' as v11;

void main() {
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('Drift schema & migration safety', () {
    test('schema snapshot ratchet: AppDatabase.schemaVersion has a matching snapshot in drift_schemas/', () async {
      final schemaDir = Directory('drift_schemas');
      expect(
        schemaDir.existsSync(),
        isTrue,
        reason: 'drift_schemas/ directory must exist at the repo root.',
      );

      final versionPattern = RegExp(r'drift_schema_v(\d+)\.json$');
      final snapshotVersions = schemaDir
          .listSync()
          .whereType<File>()
          .map((f) => versionPattern.firstMatch(f.path))
          .whereType<RegExpMatch>()
          .map((m) => int.parse(m.group(1)!))
          .toList()
        ..sort();

      expect(
        snapshotVersions,
        isNotEmpty,
        reason: 'No drift_schema_vN.json files found in drift_schemas/.',
      );

      final newestSnapshot = snapshotVersions.last;
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        db.schemaVersion,
        lessThanOrEqualTo(newestSnapshot),
        reason: 'AppDatabase.schemaVersion (${db.schemaVersion}) is ahead of the newest '
            'snapshot in drift_schemas/ (v$newestSnapshot). Run:\n'
            '  dart run drift_dev schema dump lib/sync/db/app_database.dart drift_schemas/\n'
            '  dart run drift_dev schema generate --data-classes --companions drift_schemas/ test/drift/generated/\n'
            '  dart run drift_dev schema steps drift_schemas/ test/drift/generated/schema_steps.dart',
      );
      expect(
        GeneratedHelper.versions,
        contains(db.schemaVersion),
        reason: 'test/drift/generated/schema.dart does not include v${db.schemaVersion}. '
            'Regenerate test/drift/generated/ via drift_dev schema generate.',
      );
    });

    test('SchemaVerifier validates v11 schema matches the snapshot', () async {
      final connection = await verifier.startAt(11);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(
        db,
        11,
        options: const ValidationOptions(validateDropped: true),
      );
    });

    test('data-preserving migration from v11 to current schemaVersion preserves every column across all 17 tables', () async {
      // Timestamps at whole-second precision (Drift stores DateTime as Unix seconds by default).
      final t1 = DateTime.utc(2026, 9, 19, 8, 30, 15);
      final t2 = DateTime.utc(2026, 10, 22, 14, 45, 0);
      final t3 = DateTime.utc(2027, 3, 15, 0, 0, 0);
      int sec(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

      final schema = await verifier.schemaAt(11);

      // 1. Populate v11 database with realistic rows in all 17 tables.
      // Every column with a default is given a NON-DEFAULT value, and every
      // nullable column is populated, so any dropped, renamed, or silently
      // defaulted column fails this test.
      final oldDb = v11.DatabaseAtV11(schema.newConnection());
      expect(oldDb.allTables.length, 17);

      await oldDb.batch((b) {
        b.insert(
          oldDb.localHomes,
          v11.LocalHomesCompanion.insert(
            id: 'home_cove_1',
            name: 'Bandra Sanctuary',
            description: const Value('Saba & Ancy household'),
            icon: const Value('house_heart'),
            currency: const Value('INR'), // non-default (default is 'USD')
            monthlyBudget: const Value(85000.50),
            anniversaryDate: Value(sec(t1)),
            createdAt: sec(t1),
            createdBy: 'user_saba',
          ),
        );

        b.insert(
          oldDb.localLists,
          v11.LocalListsCompanion.insert(
            id: 'list_groceries_1',
            homeId: 'home_cove_1',
            name: 'Farmers Market',
            isArchived: const Value(1), // non-default (default is 0)
            createdAt: sec(t1),
            createdBy: 'user_saba',
          ),
        );

        b.insert(
          oldDb.localListItems,
          v11.LocalListItemsCompanion.insert(
            id: 'item_coffee_1',
            homeId: 'home_cove_1',
            listId: 'list_groceries_1',
            title: 'Blue Tokai Attikan Estate 250g',
            notes: const Value('Whole beans, medium-dark roast'),
            dueDate: Value(sec(t2)),
            isCompleted: const Value(1), // non-default (default is 0)
            completedAt: Value(sec(t2)),
            completedBy: const Value('user_ancy'),
            createdAt: sec(t1),
            createdBy: 'user_saba',
          ),
        );

        b.insert(
          oldDb.localSubscriptions,
          v11.LocalSubscriptionsCompanion.insert(
            id: 'sub_car_loan_1',
            homeId: 'home_cove_1',
            name: 'Home Solar EMI',
            amount: 14250.75,
            currency: const Value('INR'), // non-default (default is 'USD')
            billingCycle: const Value('annual'), // non-default (default is 'monthly')
            nextBillingDate: sec(t2),
            category: const Value('Utilities'),
            isActive: const Value(0), // non-default (default is 1)
            isPrivate: const Value(1), // non-default (default is 0)
            createdBy: const Value('user_saba'),
            createdAt: sec(t1),
            endDate: Value(sec(t3)),
            paidBy: const Value('user_ancy'),
            financedThrough: const Value('HDFC Regalia'),
            totalInstallments: const Value(24),
            paidInstallments: const Value(9),
          ),
        );

        b.insert(
          oldDb.localExpenses,
          v11.LocalExpensesCompanion.insert(
            id: 'exp_dinner_1',
            homeId: 'home_cove_1',
            title: 'Bastian Bandra Dinner',
            amount: 6420.25,
            currency: const Value('INR'), // non-default (default is 'USD')
            paidBy: 'user_saba',
            splitRatio: const Value(0.65), // non-default (default is 0.5)
            expenseDate: sec(t2),
            category: const Value('Dining'),
            paymentMethod: const Value('upi'),
            isTransfer: const Value(1), // non-default (default is 0)
            createdAt: sec(t2),
          ),
        );

        b.insert(
          oldDb.localHabits,
          v11.LocalHabitsCompanion.insert(
            id: 'habit_read_1',
            homeId: 'home_cove_1',
            name: 'Evening Reading',
            cadence: const Value('weekly'), // non-default (default is 'daily')
            targetDaysPerWeek: const Value(4), // non-default (default is 7)
            isArchived: const Value(1), // non-default (default is 0)
            createdAt: sec(t1),
            createdBy: 'user_ancy',
          ),
        );

        b.insert(
          oldDb.localHabitCheckins,
          v11.LocalHabitCheckinsCompanion.insert(
            id: 'checkin_1',
            homeId: 'home_cove_1',
            habitId: 'habit_read_1',
            checkinDate: '2026-10-21',
            memberId: 'user_ancy',
            createdAt: sec(t2),
          ),
        );

        b.insert(
          oldDb.localCalendarEvents,
          v11.LocalCalendarEventsCompanion.insert(
            id: 'cal_anniv_1',
            homeId: 'home_cove_1',
            title: 'Alibaug Weekend Trip',
            description: const Value('Ferry from Mandwa jetty'),
            startTime: sec(t2),
            endTime: sec(t3),
            isAllDay: const Value(1), // non-default (default is 0)
            location: const Value('Alibaug, Maharashtra'),
            createdAt: sec(t1),
            createdBy: 'user_saba',
            recurrence: const Value('yearly'),
          ),
        );

        b.insert(
          oldDb.localOutboxEvents,
          v11.LocalOutboxEventsCompanion.insert(
            id: 'outbox_evt_1',
            homeId: 'home_cove_1',
            actorId: 'user_saba',
            eventType: 'expense_added',
            payloadJson: '{"id":"exp_dinner_1","amount":6420.25}',
            encryptedPayload: 'nonce_b64:ciphertext_b64',
            createdAt: sec(t2),
            syncStatus: const Value('syncedToPartner'), // non-default (default is 'savedLocally')
            retryCount: const Value(3), // non-default (default is 0)
            lastAttemptAt: Value(sec(t2)),
          ),
        );

        b.insert(
          oldDb.localActivityEvents,
          v11.LocalActivityEventsCompanion.insert(
            id: 'activity_evt_1',
            homeId: 'home_cove_1',
            actorId: 'user_ancy',
            eventType: 'habit_checked_in',
            payloadJson: '{"habitId":"habit_read_1","date":"2026-10-21"}',
            createdAt: sec(t2),
            syncStatus: const Value('syncedToPartner'), // non-default (default is 'savedLocally')
            isPrivate: const Value(1), // non-default (default is 0)
          ),
        );

        b.insert(
          oldDb.localNotificationPreferences,
          v11.LocalNotificationPreferencesCompanion.insert(
            id: const Value('custom_prefs'), // non-default (default is 'default')
            muteSubscriptions: const Value(1), // non-default (default is 0)
            muteLists: const Value(1),
            muteExpenses: const Value(1),
            muteHabits: const Value(1),
            muteCalendar: const Value(1),
            updatedAt: sec(t2),
          ),
        );

        b.insert(
          oldDb.localRoadmapItems,
          v11.LocalRoadmapItemsCompanion.insert(
            id: 'roadmap_1',
            homeId: 'home_cove_1',
            title: 'Refinance Home Loan',
            description: const Value('Compare SBI vs HDFC rates'),
            isCompleted: const Value(1), // non-default (default is 0)
            createdAt: sec(t1),
            createdBy: 'user_saba',
            completedAt: Value(sec(t2)),
          ),
        );

        b.insert(
          oldDb.localRoutines,
          v11.LocalRoutinesCompanion.insert(
            id: 'routine_weekday_1',
            homeId: 'home_cove_1',
            name: 'Weekday Reset',
            daysJson: '[1,2,3,4,5]',
            createdAt: sec(t1),
          ),
        );

        b.insert(
          oldDb.localRoutineEvents,
          v11.LocalRoutineEventsCompanion.insert(
            id: 'routine_evt_1',
            routineId: 'routine_weekday_1',
            homeId: 'home_cove_1',
            title: 'Brew Morning Pourover',
            startMinutes: 450,
            endMinutes: 470,
            category: const Value('Morning'),
            notes: const Value('15g coffee to 250g water at 93C'),
            createdAt: sec(t1),
          ),
        );

        b.insert(
          oldDb.localAppliedEvents,
          v11.LocalAppliedEventsCompanion.insert(
            id: 'applied_evt_1',
            appliedAt: sec(t2),
          ),
        );

        b.insert(
          oldDb.localDeletedTombstones,
          v11.LocalDeletedTombstonesCompanion.insert(
            id: 'tombstone_1',
            entityType: 'expense',
            deletedAt: sec(t2),
          ),
        );

        b.insert(
          oldDb.localCheckinReminders,
          v11.LocalCheckinRemindersCompanion.insert(
            id: 'reminder_1',
            homeId: 'home_cove_1',
            hour: 21,
            minute: 15,
            message: 'Log today expenses & check in on habits',
            isEnabled: const Value(0), // non-default (default is 1)
            createdAt: sec(t1),
          ),
        );
      });
      await oldDb.close();

      // 2. Run migration from v11 to current AppDatabase.schemaVersion and validate schema.
      final migratedDb = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(
        migratedDb,
        migratedDb.schemaVersion,
        options: const ValidationOptions(validateDropped: true),
      );
      await migratedDb.close();

      // 3. Re-open with AppDatabase and verify every row and every field survived intact.
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);

      final homes = await db.select(db.localHomes).get();
      expect(homes, [
        LocalHome(
          id: 'home_cove_1',
          name: 'Bandra Sanctuary',
          description: 'Saba & Ancy household',
          icon: 'house_heart',
          currency: 'INR',
          monthlyBudget: 85000.50,
          anniversaryDate: t1.toLocal(),
          createdAt: t1.toLocal(),
          createdBy: 'user_saba',
        ),
      ]);

      final lists = await db.select(db.localLists).get();
      expect(lists, [
        LocalList(
          id: 'list_groceries_1',
          homeId: 'home_cove_1',
          name: 'Farmers Market',
          isArchived: true,
          createdAt: t1.toLocal(),
          createdBy: 'user_saba',
        ),
      ]);

      final listItems = await db.select(db.localListItems).get();
      expect(listItems, [
        LocalListItem(
          id: 'item_coffee_1',
          homeId: 'home_cove_1',
          listId: 'list_groceries_1',
          title: 'Blue Tokai Attikan Estate 250g',
          notes: 'Whole beans, medium-dark roast',
          dueDate: t2.toLocal(),
          isCompleted: true,
          completedAt: t2.toLocal(),
          completedBy: 'user_ancy',
          createdAt: t1.toLocal(),
          createdBy: 'user_saba',
        ),
      ]);

      final subscriptions = await db.select(db.localSubscriptions).get();
      expect(subscriptions, [
        LocalSubscription(
          id: 'sub_car_loan_1',
          homeId: 'home_cove_1',
          name: 'Home Solar EMI',
          amount: 14250.75,
          currency: 'INR',
          billingCycle: 'annual',
          nextBillingDate: t2.toLocal(),
          category: 'Utilities',
          isActive: false,
          isPrivate: true,
          createdBy: 'user_saba',
          createdAt: t1.toLocal(),
          endDate: t3.toLocal(),
          paidBy: 'user_ancy',
          financedThrough: 'HDFC Regalia',
          totalInstallments: 24,
          paidInstallments: 9,
        ),
      ]);

      final expenses = await db.select(db.localExpenses).get();
      expect(expenses, [
        LocalExpense(
          id: 'exp_dinner_1',
          homeId: 'home_cove_1',
          title: 'Bastian Bandra Dinner',
          amount: 6420.25,
          currency: 'INR',
          paidBy: 'user_saba',
          splitRatio: 0.65,
          expenseDate: t2.toLocal(),
          category: 'Dining',
          paymentMethod: 'upi',
          isTransfer: true,
          createdAt: t2.toLocal(),
        ),
      ]);

      final habits = await db.select(db.localHabits).get();
      expect(habits, [
        LocalHabit(
          id: 'habit_read_1',
          homeId: 'home_cove_1',
          name: 'Evening Reading',
          cadence: 'weekly',
          targetDaysPerWeek: 4,
          isArchived: true,
          createdAt: t1.toLocal(),
          createdBy: 'user_ancy',
        ),
      ]);

      final checkins = await db.select(db.localHabitCheckins).get();
      expect(checkins, [
        LocalHabitCheckin(
          id: 'checkin_1',
          homeId: 'home_cove_1',
          habitId: 'habit_read_1',
          checkinDate: '2026-10-21',
          memberId: 'user_ancy',
          createdAt: t2.toLocal(),
        ),
      ]);

      final calendarEvents = await db.select(db.localCalendarEvents).get();
      expect(calendarEvents, [
        LocalCalendarEvent(
          id: 'cal_anniv_1',
          homeId: 'home_cove_1',
          title: 'Alibaug Weekend Trip',
          description: 'Ferry from Mandwa jetty',
          startTime: t2.toLocal(),
          endTime: t3.toLocal(),
          isAllDay: true,
          location: 'Alibaug, Maharashtra',
          createdAt: t1.toLocal(),
          createdBy: 'user_saba',
          recurrence: 'yearly',
        ),
      ]);

      final outboxEvents = await db.select(db.localOutboxEvents).get();
      expect(outboxEvents, [
        LocalOutboxEvent(
          id: 'outbox_evt_1',
          homeId: 'home_cove_1',
          actorId: 'user_saba',
          eventType: 'expense_added',
          payloadJson: '{"id":"exp_dinner_1","amount":6420.25}',
          encryptedPayload: 'nonce_b64:ciphertext_b64',
          createdAt: t2.toLocal(),
          syncStatus: 'syncedToPartner',
          retryCount: 3,
          lastAttemptAt: t2.toLocal(),
        ),
      ]);

      final activityEvents = await db.select(db.localActivityEvents).get();
      expect(activityEvents, [
        LocalActivityEvent(
          id: 'activity_evt_1',
          homeId: 'home_cove_1',
          actorId: 'user_ancy',
          eventType: 'habit_checked_in',
          payloadJson: '{"habitId":"habit_read_1","date":"2026-10-21"}',
          createdAt: t2.toLocal(),
          syncStatus: 'syncedToPartner',
          isPrivate: true,
        ),
      ]);

      final notifPrefs = await db.select(db.localNotificationPreferences).get();
      expect(notifPrefs, [
        LocalNotificationPreference(
          id: 'custom_prefs',
          muteSubscriptions: true,
          muteLists: true,
          muteExpenses: true,
          muteHabits: true,
          muteCalendar: true,
          updatedAt: t2.toLocal(),
        ),
      ]);

      final roadmapItems = await db.select(db.localRoadmapItems).get();
      expect(roadmapItems, [
        LocalRoadmapItem(
          id: 'roadmap_1',
          homeId: 'home_cove_1',
          title: 'Refinance Home Loan',
          description: 'Compare SBI vs HDFC rates',
          isCompleted: true,
          createdAt: t1.toLocal(),
          createdBy: 'user_saba',
          completedAt: t2.toLocal(),
        ),
      ]);

      final routines = await db.select(db.localRoutines).get();
      expect(routines, [
        LocalRoutine(
          id: 'routine_weekday_1',
          homeId: 'home_cove_1',
          name: 'Weekday Reset',
          daysJson: '[1,2,3,4,5]',
          createdAt: t1.toLocal(),
        ),
      ]);

      final routineEvents = await db.select(db.localRoutineEvents).get();
      expect(routineEvents, [
        LocalRoutineEvent(
          id: 'routine_evt_1',
          routineId: 'routine_weekday_1',
          homeId: 'home_cove_1',
          title: 'Brew Morning Pourover',
          startMinutes: 450,
          endMinutes: 470,
          category: 'Morning',
          notes: '15g coffee to 250g water at 93C',
          createdAt: t1.toLocal(),
        ),
      ]);

      final appliedEvents = await db.select(db.localAppliedEvents).get();
      expect(appliedEvents, [
        LocalAppliedEvent(
          id: 'applied_evt_1',
          appliedAt: t2.toLocal(),
        ),
      ]);

      final tombstones = await db.select(db.localDeletedTombstones).get();
      expect(tombstones, [
        LocalDeletedTombstone(
          id: 'tombstone_1',
          entityType: 'expense',
          deletedAt: t2.toLocal(),
        ),
      ]);

      final reminders = await db.select(db.localCheckinReminders).get();
      expect(reminders, [
        LocalCheckinReminder(
          id: 'reminder_1',
          homeId: 'home_cove_1',
          hour: 21,
          minute: 15,
          message: 'Log today expenses & check in on habits',
          isEnabled: false,
          createdAt: t1.toLocal(),
        ),
      ]);
    });
  });
}
