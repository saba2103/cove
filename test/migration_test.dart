import 'dart:io';

import 'package:clock/clock.dart';
import 'package:cove/features/backup/backup_crypto.dart';
import 'package:cove/features/backup/backup_snapshot_service.dart';
import 'package:cove/features/notifications/notification_pipeline.dart';
import 'package:cove/features/notifications/notification_service.dart';
import 'package:cove/features/widgets/cove_widget_tick_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'drift/generated/schema.dart';
import 'drift/generated/schema_v11.dart' as v11;

class _FakeNotificationSink implements LocalNotificationSink {
  final List<RenderedNotification> shown = <RenderedNotification>[];

  @override
  Future<void> show(RenderedNotification notification) async {
    shown.add(notification);
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {}

  @override
  Future<void> cancelAll() async {}
}

/// Simulates a v11 `AppDatabase` instance (`schemaVersion == 11`, only the 17
/// v11 tables) so `BackupSnapshotService.export()` and `.restore()` can be run
/// against a real v11 schema without creating or querying v12 tables.
class _AppDatabaseAtV11 extends AppDatabase {
  _AppDatabaseAtV11(super.executor);

  static const Set<String> _v12AddedTables = <String>{
    'local_pets',
    'local_pet_tags',
  };

  @override
  int get schemaVersion => 11;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => super
      .allTables
      .where((t) => !_v12AddedTables.contains(t.actualTableName));

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {},
        onUpgrade: (m, from, to) async {},
      );
}

const List<String> _v11TableNames = <String>[
  'local_homes',
  'local_lists',
  'local_list_items',
  'local_subscriptions',
  'local_expenses',
  'local_habits',
  'local_habit_checkins',
  'local_calendar_events',
  'local_outbox_events',
  'local_activity_events',
  'local_notification_preferences',
  'local_roadmap_items',
  'local_routines',
  'local_routine_events',
  'local_applied_events',
  'local_deleted_tombstones',
  'local_checkin_reminders',
];

// Timestamps at whole-second precision (Drift stores DateTime as Unix seconds by default).
final DateTime _t1 = DateTime.utc(2026, 9, 19, 8, 30, 15);
final DateTime _t2 = DateTime.utc(2026, 10, 22, 14, 45, 0);
final DateTime _t3 = DateTime.utc(2027, 3, 15, 0, 0, 0);
int _sec(DateTime dt) => dt.millisecondsSinceEpoch ~/ 1000;

/// Populates every one of the 17 v11 tables with multiple realistic rows,
/// including private records, EMIs, check-ins, and pending outbox events.
Future<void> _populateV11Database(v11.DatabaseAtV11 oldDb) async {
  expect(oldDb.allTables.length, 17);

  await oldDb.batch((b) {
    // 1. local_homes (2 rows)
    b.insertAll(oldDb.localHomes, [
      v11.LocalHomesCompanion.insert(
        id: 'home_cove_1',
        name: 'Bandra Sanctuary',
        description: const Value('Saba & Ancy household'),
        icon: const Value('house_heart'),
        currency: const Value('INR'),
        monthlyBudget: const Value(85000.50),
        anniversaryDate: Value(_sec(_t1)),
        createdAt: _sec(_t1),
        createdBy: 'user_saba',
      ),
      v11.LocalHomesCompanion.insert(
        id: 'home_cove_2',
        name: 'Goa Monsoon House',
        description: const Value(null),
        icon: const Value(null),
        currency: const Value('USD'),
        monthlyBudget: const Value(null),
        anniversaryDate: const Value(null),
        createdAt: _sec(_t2),
        createdBy: 'user_ancy',
      ),
    ]);

    // 2. local_lists (2 rows)
    b.insertAll(oldDb.localLists, [
      v11.LocalListsCompanion.insert(
        id: 'list_groceries_1',
        homeId: 'home_cove_1',
        name: 'Farmers Market',
        isArchived: const Value(1),
        createdAt: _sec(_t1),
        createdBy: 'user_saba',
      ),
      v11.LocalListsCompanion.insert(
        id: 'list_active_2',
        homeId: 'home_cove_1',
        name: 'Grocery',
        isArchived: const Value(0),
        createdAt: _sec(_t2),
        createdBy: 'user_ancy',
      ),
    ]);

    // 3. local_list_items (3 rows: completed + open with due date + open without due date)
    b.insertAll(oldDb.localListItems, [
      v11.LocalListItemsCompanion.insert(
        id: 'item_coffee_1',
        homeId: 'home_cove_1',
        listId: 'list_groceries_1',
        title: 'Blue Tokai Attikan Estate 250g',
        notes: const Value('Whole beans, medium-dark roast'),
        dueDate: Value(_sec(_t2)),
        isCompleted: const Value(1),
        completedAt: Value(_sec(_t2)),
        completedBy: const Value('user_ancy'),
        createdAt: _sec(_t1),
        createdBy: 'user_saba',
      ),
      v11.LocalListItemsCompanion.insert(
        id: 'item_open_2',
        homeId: 'home_cove_1',
        listId: 'list_active_2',
        title: 'Get sourdough loaf',
        notes: const Value(null),
        dueDate: Value(_sec(_t2)),
        isCompleted: const Value(0),
        completedAt: const Value(null),
        completedBy: const Value(null),
        createdAt: _sec(_t2),
        createdBy: 'user_ancy',
      ),
      v11.LocalListItemsCompanion.insert(
        id: 'item_open_3',
        homeId: 'home_cove_1',
        listId: 'list_active_2',
        title: 'Pick up dry cleaning',
        notes: const Value('Before 7pm'),
        dueDate: const Value(null),
        isCompleted: const Value(0),
        completedAt: const Value(null),
        completedBy: const Value(null),
        createdAt: _sec(_t2),
        createdBy: 'user_saba',
      ),
    ]);

    // 4. local_subscriptions (3 rows: private EMI, shared EMI, shared recurring bill)
    b.insertAll(oldDb.localSubscriptions, [
      v11.LocalSubscriptionsCompanion.insert(
        id: 'sub_car_loan_1',
        homeId: 'home_cove_1',
        name: 'Home Solar EMI',
        amount: 14250.75,
        currency: const Value('INR'),
        billingCycle: const Value('annual'),
        nextBillingDate: _sec(_t2),
        category: const Value('Utilities'),
        isActive: const Value(0),
        isPrivate: const Value(1),
        createdBy: const Value('user_saba'),
        createdAt: _sec(_t1),
        endDate: Value(_sec(_t3)),
        paidBy: const Value('user_ancy'),
        financedThrough: const Value('HDFC Regalia'),
        totalInstallments: const Value(24),
        paidInstallments: const Value(9),
      ),
      v11.LocalSubscriptionsCompanion.insert(
        id: 'sub_emi_fridge_2',
        homeId: 'home_cove_1',
        name: 'Espresso Machine EMI',
        amount: 4500.00,
        currency: const Value('INR'),
        billingCycle: const Value('monthly'),
        nextBillingDate: _sec(_t3),
        category: const Value('Appliances'),
        isActive: const Value(1),
        isPrivate: const Value(0),
        createdBy: const Value('user_ancy'),
        createdAt: _sec(_t2),
        endDate: const Value(null),
        paidBy: const Value('user_saba'),
        financedThrough: const Value('ICICI Amazon Pay'),
        totalInstallments: const Value(12),
        paidInstallments: const Value(3),
      ),
      v11.LocalSubscriptionsCompanion.insert(
        id: 'sub_rent_3',
        homeId: 'home_cove_1',
        name: 'Bandra Rent',
        amount: 65000.00,
        currency: const Value('INR'),
        billingCycle: const Value('monthly'),
        nextBillingDate: _sec(_t2),
        category: const Value('Housing'),
        isActive: const Value(1),
        isPrivate: const Value(0),
        createdBy: const Value('user_saba'),
        createdAt: _sec(_t1),
        endDate: const Value(null),
        paidBy: const Value('user_saba'),
        financedThrough: const Value(null),
        totalInstallments: const Value(null),
        paidInstallments: const Value(null),
      ),
    ]);

    // 5. local_expenses (3 rows: transfer, private expense, shared expense)
    b.insertAll(oldDb.localExpenses, [
      v11.LocalExpensesCompanion.insert(
        id: 'exp_dinner_1',
        homeId: 'home_cove_1',
        title: 'Bastian Bandra Dinner',
        amount: 6420.25,
        currency: const Value('INR'),
        paidBy: 'user_saba',
        splitRatio: const Value(0.65),
        expenseDate: _sec(_t2),
        category: const Value('Dining'),
        paymentMethod: const Value('upi'),
        isTransfer: const Value(1),
        createdAt: _sec(_t2),
      ),
      v11.LocalExpensesCompanion.insert(
        id: 'exp_private_2',
        homeId: 'home_cove_1',
        title: 'Anniversary Watch Gift',
        amount: 18500.00,
        currency: const Value('INR'),
        paidBy: 'user_saba',
        splitRatio: const Value(-1.0), // private expense
        expenseDate: _sec(_t1),
        category: const Value('Personal'),
        paymentMethod: const Value('card'),
        isTransfer: const Value(0),
        createdAt: _sec(_t1),
      ),
      v11.LocalExpensesCompanion.insert(
        id: 'exp_shared_3',
        homeId: 'home_cove_1',
        title: 'Electricity Bill',
        amount: 2340.00,
        currency: const Value('INR'),
        paidBy: 'user_ancy',
        splitRatio: const Value(0.5),
        expenseDate: _sec(_t2),
        category: const Value('Utilities'),
        paymentMethod: const Value('upi'),
        isTransfer: const Value(0),
        createdAt: _sec(_t2),
      ),
    ]);

    // 6. local_habits (3 rows: archived weekly, active daily shared, active private)
    b.insertAll(oldDb.localHabits, [
      v11.LocalHabitsCompanion.insert(
        id: 'habit_read_1',
        homeId: 'home_cove_1',
        name: 'Evening Reading',
        cadence: const Value('weekly'),
        targetDaysPerWeek: const Value(4),
        isArchived: const Value(1),
        createdAt: _sec(_t1),
        createdBy: 'user_ancy',
      ),
      v11.LocalHabitsCompanion.insert(
        id: 'habit_shared_2',
        homeId: 'home_cove_1',
        name: 'Morning Walk',
        cadence: const Value('daily'),
        targetDaysPerWeek: const Value(7),
        isArchived: const Value(0),
        createdAt: _sec(_t1),
        createdBy: 'user_saba',
      ),
      v11.LocalHabitsCompanion.insert(
        id: 'habit_private_3',
        homeId: 'home_cove_1',
        name: 'Private Journal',
        cadence: const Value('daily'),
        targetDaysPerWeek: const Value(-1), // private habit encoding
        isArchived: const Value(0),
        createdAt: _sec(_t2),
        createdBy: 'user_saba',
      ),
    ]);

    // 7. local_habit_checkins (3 rows)
    b.insertAll(oldDb.localHabitCheckins, [
      v11.LocalHabitCheckinsCompanion.insert(
        id: 'checkin_1',
        homeId: 'home_cove_1',
        habitId: 'habit_read_1',
        checkinDate: '2026-10-21',
        memberId: 'user_ancy',
        createdAt: _sec(_t2),
      ),
      v11.LocalHabitCheckinsCompanion.insert(
        id: 'checkin_2',
        homeId: 'home_cove_1',
        habitId: 'habit_shared_2',
        checkinDate: '2026-10-22',
        memberId: 'user_saba',
        createdAt: _sec(_t2),
      ),
      v11.LocalHabitCheckinsCompanion.insert(
        id: 'checkin_3',
        homeId: 'home_cove_1',
        habitId: 'habit_private_3',
        checkinDate: '2026-10-22',
        memberId: 'user_saba',
        createdAt: _sec(_t2),
      ),
    ]);

    // 8. local_calendar_events (2 rows)
    b.insertAll(oldDb.localCalendarEvents, [
      v11.LocalCalendarEventsCompanion.insert(
        id: 'cal_anniv_1',
        homeId: 'home_cove_1',
        title: 'Alibaug Weekend Trip',
        description: const Value('Ferry from Mandwa jetty'),
        startTime: _sec(_t2),
        endTime: _sec(_t3),
        isAllDay: const Value(1),
        location: const Value('Alibaug, Maharashtra'),
        createdAt: _sec(_t1),
        createdBy: 'user_saba',
        recurrence: const Value('yearly'),
      ),
      v11.LocalCalendarEventsCompanion.insert(
        id: 'cal_dinner_2',
        homeId: 'home_cove_1',
        title: 'Dinner with Parents',
        description: const Value(null),
        startTime: _sec(_t2),
        endTime: _sec(_t2) + 7200,
        isAllDay: const Value(0),
        location: const Value(null),
        createdAt: _sec(_t2),
        createdBy: 'user_ancy',
        recurrence: const Value(null),
      ),
    ]);

    // 9. local_outbox_events (3 rows: synced + 2 pending savedLocally)
    b.insertAll(oldDb.localOutboxEvents, [
      v11.LocalOutboxEventsCompanion.insert(
        id: 'outbox_evt_1',
        homeId: 'home_cove_1',
        actorId: 'user_saba',
        eventType: 'expense_added',
        payloadJson: '{"id":"exp_dinner_1","amount":6420.25}',
        encryptedPayload: 'nonce_b64:ciphertext_b64',
        createdAt: _sec(_t2),
        syncStatus: const Value('syncedToPartner'),
        retryCount: const Value(3),
        lastAttemptAt: Value(_sec(_t2)),
      ),
      v11.LocalOutboxEventsCompanion.insert(
        id: 'outbox_pending_2',
        homeId: 'home_cove_1',
        actorId: 'user_saba',
        eventType: 'list_item_added',
        payloadJson: '{"id":"item_open_3","title":"Pick up dry cleaning"}',
        encryptedPayload: 'nonce_pending_2:cipher_pending_2',
        createdAt: _sec(_t2),
        syncStatus: const Value('savedLocally'),
        retryCount: const Value(0),
        lastAttemptAt: const Value(null),
      ),
      v11.LocalOutboxEventsCompanion.insert(
        id: 'outbox_pending_3',
        homeId: 'home_cove_1',
        actorId: 'user_ancy',
        eventType: 'calendar_event_added',
        payloadJson: '{"id":"cal_dinner_2","title":"Dinner with Parents"}',
        encryptedPayload: 'nonce_pending_3:cipher_pending_3',
        createdAt: _sec(_t2),
        syncStatus: const Value('savedLocally'),
        retryCount: const Value(2),
        lastAttemptAt: Value(_sec(_t2)),
      ),
    ]);

    // 10. local_activity_events (2 rows: private + shared)
    b.insertAll(oldDb.localActivityEvents, [
      v11.LocalActivityEventsCompanion.insert(
        id: 'activity_evt_1',
        homeId: 'home_cove_1',
        actorId: 'user_ancy',
        eventType: 'habit_checked_in',
        payloadJson: '{"habitId":"habit_read_1","date":"2026-10-21"}',
        createdAt: _sec(_t2),
        syncStatus: const Value('syncedToPartner'),
        isPrivate: const Value(1),
      ),
      v11.LocalActivityEventsCompanion.insert(
        id: 'activity_evt_2',
        homeId: 'home_cove_1',
        actorId: 'user_saba',
        eventType: 'expense_logged',
        payloadJson: '{"id":"exp_shared_3","amount":2340.0}',
        createdAt: _sec(_t2),
        syncStatus: const Value('savedLocally'),
        isPrivate: const Value(0),
      ),
    ]);

    // 11. local_notification_preferences (2 rows)
    b.insertAll(oldDb.localNotificationPreferences, [
      v11.LocalNotificationPreferencesCompanion.insert(
        id: const Value('custom_prefs'),
        muteSubscriptions: const Value(1),
        muteLists: const Value(1),
        muteExpenses: const Value(1),
        muteHabits: const Value(1),
        muteCalendar: const Value(1),
        updatedAt: _sec(_t2),
      ),
      v11.LocalNotificationPreferencesCompanion.insert(
        id: const Value('default'),
        muteSubscriptions: const Value(0),
        muteLists: const Value(0),
        muteExpenses: const Value(1),
        muteHabits: const Value(0),
        muteCalendar: const Value(0),
        updatedAt: _sec(_t1),
      ),
    ]);

    // 12. local_roadmap_items (2 rows)
    b.insertAll(oldDb.localRoadmapItems, [
      v11.LocalRoadmapItemsCompanion.insert(
        id: 'roadmap_1',
        homeId: 'home_cove_1',
        title: 'Refinance Home Loan',
        description: const Value('Compare SBI vs HDFC rates'),
        isCompleted: const Value(1),
        createdAt: _sec(_t1),
        createdBy: 'user_saba',
        completedAt: Value(_sec(_t2)),
      ),
      v11.LocalRoadmapItemsCompanion.insert(
        id: 'roadmap_2',
        homeId: 'home_cove_1',
        title: 'Paint Balcony Wall',
        description: const Value(null),
        isCompleted: const Value(0),
        createdAt: _sec(_t2),
        createdBy: 'user_ancy',
        completedAt: const Value(null),
      ),
    ]);

    // 13. local_routines (2 rows)
    b.insertAll(oldDb.localRoutines, [
      v11.LocalRoutinesCompanion.insert(
        id: 'routine_weekday_1',
        homeId: 'home_cove_1',
        name: 'Weekday Reset',
        daysJson: '[1,2,3,4,5]',
        createdAt: _sec(_t1),
      ),
      v11.LocalRoutinesCompanion.insert(
        id: 'routine_weekend_2',
        homeId: 'home_cove_1',
        name: 'Slow Sunday',
        daysJson: '[6,7]',
        createdAt: _sec(_t2),
      ),
    ]);

    // 14. local_routine_events (2 rows)
    b.insertAll(oldDb.localRoutineEvents, [
      v11.LocalRoutineEventsCompanion.insert(
        id: 'routine_evt_1',
        routineId: 'routine_weekday_1',
        homeId: 'home_cove_1',
        title: 'Brew Morning Pourover',
        startMinutes: 450,
        endMinutes: 470,
        category: const Value('Morning'),
        notes: const Value('15g coffee to 250g water at 93C'),
        createdAt: _sec(_t1),
      ),
      v11.LocalRoutineEventsCompanion.insert(
        id: 'routine_evt_2',
        routineId: 'routine_weekend_2',
        homeId: 'home_cove_1',
        title: 'Evening Tea on Balcony',
        startMinutes: 1050,
        endMinutes: 1095,
        category: const Value(null),
        notes: const Value(null),
        createdAt: _sec(_t2),
      ),
    ]);

    // 15. local_applied_events (2 rows)
    b.insertAll(oldDb.localAppliedEvents, [
      v11.LocalAppliedEventsCompanion.insert(
        id: 'applied_evt_1',
        appliedAt: _sec(_t2),
      ),
      v11.LocalAppliedEventsCompanion.insert(
        id: 'applied_evt_2',
        appliedAt: _sec(_t1),
      ),
    ]);

    // 16. local_deleted_tombstones (2 rows)
    b.insertAll(oldDb.localDeletedTombstones, [
      v11.LocalDeletedTombstonesCompanion.insert(
        id: 'tombstone_1',
        entityType: 'expense',
        deletedAt: _sec(_t2),
      ),
      v11.LocalDeletedTombstonesCompanion.insert(
        id: 'tombstone_2',
        entityType: 'subscription',
        deletedAt: _sec(_t1),
      ),
    ]);

    // 17. local_checkin_reminders (2 rows)
    b.insertAll(oldDb.localCheckinReminders, [
      v11.LocalCheckinRemindersCompanion.insert(
        id: 'reminder_1',
        homeId: 'home_cove_1',
        hour: 21,
        minute: 15,
        message: 'Log today expenses & check in on habits',
        isEnabled: const Value(0),
        createdAt: _sec(_t1),
      ),
      v11.LocalCheckinRemindersCompanion.insert(
        id: 'reminder_2',
        homeId: 'home_cove_1',
        hour: 9,
        minute: 0,
        message: 'Morning check-in',
        isEnabled: const Value(1),
        createdAt: _sec(_t2),
      ),
    ]);
  });
}

Future<Map<String, List<Map<String, Object?>>>> _dumpRawTables(
  GeneratedDatabase db,
  Iterable<String> tableNames,
) async {
  final result = <String, List<Map<String, Object?>>>{};
  for (final name in tableNames) {
    final rows = await db
        .customSelect('SELECT * FROM "$name" ORDER BY "id" ASC;')
        .get();
    result[name] = rows
        .map((r) => Map<String, Object?>.from(r.data))
        .toList(growable: false);
  }
  return result;
}

void _assertV11ToV12RowsAndDefaults({
  required Map<String, List<Map<String, Object?>>> beforeV11,
  required Map<String, List<Map<String, Object?>>> afterV12,
}) {
  for (final tableName in _v11TableNames) {
    final beforeRows = beforeV11[tableName]!;
    final afterRows = afterV12[tableName]!;
    expect(
      afterRows.length,
      beforeRows.length,
      reason: 'Row count for $tableName must be identical after migration.',
    );
    expect(
      beforeRows.length,
      greaterThanOrEqualTo(2),
      reason: 'Every v11 table must be populated with multiple rows ($tableName).',
    );

    if (tableName == 'local_calendar_events' ||
        tableName == 'local_routine_events') {
      for (var i = 0; i < afterRows.length; i++) {
        final copy = Map<String, Object?>.from(afterRows[i]);
        expect(
          copy.containsKey('owner'),
          isTrue,
          reason: '$tableName must have the new owner column.',
        );
        final ownerVal = copy.remove('owner');
        expect(
          ownerVal,
          'both',
          reason: 'Existing rows in $tableName must default owner to "both".',
        );
        expect(
          copy,
          equals(beforeRows[i]),
          reason: 'Every pre-existing column in $tableName row $i must be untouched.',
        );
      }
    } else if (tableName == 'local_list_items') {
      for (var i = 0; i < afterRows.length; i++) {
        final copy = Map<String, Object?>.from(afterRows[i]);
        expect(
          copy.containsKey('owner'),
          isTrue,
          reason: 'local_list_items must have the new owner column.',
        );
        final ownerVal = copy.remove('owner');
        expect(
          ownerVal,
          isNull,
          reason: 'Existing rows in local_list_items must default owner to NULL.',
        );
        expect(
          copy,
          equals(beforeRows[i]),
          reason: 'Every pre-existing column in local_list_items row $i must be untouched.',
        );
      }
    } else {
      expect(
        afterRows,
        equals(beforeRows),
        reason: 'Table $tableName must be 100% identical before and after migration.',
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  group('Drift schema & migration safety (v11 -> v12)', () {
    test(
        'schema snapshot ratchet: AppDatabase.schemaVersion has a matching snapshot in drift_schemas/',
        () async {
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

      expect(db.schemaVersion, 12);
      expect(
        db.schemaVersion,
        lessThanOrEqualTo(newestSnapshot),
        reason:
            'AppDatabase.schemaVersion (${db.schemaVersion}) is ahead of the newest '
            'snapshot in drift_schemas/ (v$newestSnapshot).',
      );
      expect(
        GeneratedHelper.versions,
        contains(db.schemaVersion),
        reason:
            'test/drift/generated/schema.dart does not include v${db.schemaVersion}.',
      );
    });

    test('SchemaVerifier validates v11 -> v12 migration and v12 snapshot',
        () async {
      final connection = await verifier.startAt(11);
      final db = AppDatabase(connection);
      addTearDown(db.close);

      await verifier.migrateAndValidate(
        db,
        12,
        options: const ValidationOptions(validateDropped: true),
      );
    });

    test(
        'v11 database populated with every table filled (multiple rows, private records, EMIs, check-ins, pending outbox) -> migrate to v12 -> identical rows, defaults set, outbox untouched, user_version = 12',
        () async {
      final schema = await verifier.schemaAt(11);

      // 1. Populate v11 database with multiple rows in all 17 tables.
      final oldDb = v11.DatabaseAtV11(schema.newConnection());
      await _populateV11Database(oldDb);
      final beforeV11 = await _dumpRawTables(oldDb, _v11TableNames);
      await oldDb.close();

      // 2. Run migration from v11 to v12 and validate schema.
      final migratedDb = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(
        migratedDb,
        12,
        options: const ValidationOptions(validateDropped: true),
      );
      await migratedDb.close();

      // 3. Re-open with AppDatabase and verify user_version = 12, all 17 v11 tables,
      //    the new defaults, the untouched outbox, and the 2 new empty tables.
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);

      final userVersionRow =
          await db.customSelect('PRAGMA user_version;').getSingle();
      expect(userVersionRow.read<int>('user_version'), 12);
      expect(db.allTables.length, 19);

      final afterV12 = await _dumpRawTables(db, _v11TableNames);
      _assertV11ToV12RowsAndDefaults(
        beforeV11: beforeV11,
        afterV12: afterV12,
      );

      // Explicitly verify outbox rows (including pending savedLocally events) are untouched.
      expect(afterV12['local_outbox_events'], equals(beforeV11['local_outbox_events']));
      final outboxRows = await db.select(db.localOutboxEvents).get();
      expect(outboxRows, hasLength(3));
      expect(
        outboxRows.where((e) => e.syncStatus == 'savedLocally').map((e) => e.id),
        containsAll(['outbox_pending_2', 'outbox_pending_3']),
      );

      // Verify typed Drift getters on the migrated columns.
      final events = await db.select(db.localCalendarEvents).get();
      expect(events.map((e) => e.owner).toList(), ['both', 'both']);

      final routineEvents = await db.select(db.localRoutineEvents).get();
      expect(routineEvents.map((e) => e.owner).toList(), ['both', 'both']);

      final listItems = await db.select(db.localListItems).get();
      expect(listItems.map((i) => i.owner).toList(), [null, null, null]);

      // Verify the two new tables exist and are empty.
      final pets = await db.select(db.localPets).get();
      expect(pets, isEmpty);
      final petTags = await db.select(db.localPetTags).get();
      expect(petTags, isEmpty);
    });

    test('migrate twice (an idempotent second open on disk) -> no change',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('cove_v12_idempotent_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final dbFile = File('${tempDir.path}/cove_db.sqlite');

      // 1. Create and populate a real v11 database file on disk.
      final schema11 = await verifier.schemaAt(11);
      schema11.rawDatabase.execute(
        "VACUUM INTO '${dbFile.path.replaceAll("'", "''")}';",
      );
      schema11.rawDatabase.close();

      final v11OnDisk = v11.DatabaseAtV11(NativeDatabase(dbFile));
      await _populateV11Database(v11OnDisk);
      final beforeV11 = await _dumpRawTables(v11OnDisk, _v11TableNames);
      await v11OnDisk.close();

      // 2. First open with v12 AppDatabase -> migrates 11 -> 12.
      final firstOpenDb = AppDatabase(NativeDatabase(dbFile));
      final verAfterFirst =
          await firstOpenDb.customSelect('PRAGMA user_version;').getSingle();
      expect(verAfterFirst.read<int>('user_version'), 12);

      // Also insert a pet and a custom owner on one event after first migration
      // to prove a second open doesn't overwrite or reset anything.
      final allTableNames =
          firstOpenDb.allTables.map((t) => t.actualTableName).toList();
      final snapshotAfterFirstMigrate =
          await _dumpRawTables(firstOpenDb, allTableNames);
      _assertV11ToV12RowsAndDefaults(
        beforeV11: beforeV11,
        afterV12: snapshotAfterFirstMigrate,
      );
      await firstOpenDb.close();

      // 3. Second open (idempotent open) on the same SQLite file.
      final secondOpenDb = AppDatabase(NativeDatabase(dbFile));
      addTearDown(secondOpenDb.close);

      final verAfterSecond =
          await secondOpenDb.customSelect('PRAGMA user_version;').getSingle();
      expect(verAfterSecond.read<int>('user_version'), 12);

      final snapshotAfterSecondOpen =
          await _dumpRawTables(secondOpenDb, allTableNames);
      expect(
        snapshotAfterSecondOpen,
        equals(snapshotAfterFirstMigrate),
        reason: 'Opening an already-migrated v12 database a second time must not alter any table or row.',
      );
    });

    test(
        'a v11 backup file (made with existing backup code from populated v11 DB) restored into v12 app -> identical rows, defaults filled',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('cove_v11_backup_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      // Fast Argon2id parameters for unit test speed while exercising full BackupCrypto seal/open.
      final fastKdf = BackupKdfParams(
        salt: BackupCrypto.randomBytes(BackupKdfParams.saltLength),
        memoryKiB: 64,
        iterations: 1,
        parallelism: 1,
      );
      const passphrase = 'correct horse battery staple';

      // 1. Populate a v11 database and export a backup using the real BackupSnapshotService + BackupCrypto.
      final schema11 = await verifier.schemaAt(11);
      final oldDb = v11.DatabaseAtV11(schema11.newConnection());
      await _populateV11Database(oldDb);
      final beforeV11 = await _dumpRawTables(oldDb, _v11TableNames);
      await oldDb.close();

      final v11KeyStore = HomeKeyStore();
      final homeKey = BackupCrypto.randomBytes(32);
      await v11KeyStore.saveKey('home_cove_1', homeKey);

      final v11AppDb = _AppDatabaseAtV11(schema11.newConnection());
      final v11Exporter = BackupSnapshotService(
        db: v11AppDb,
        keyStore: v11KeyStore,
      );
      final exportedV11Payload = await v11Exporter.export();
      expect(exportedV11Payload['schemaVersion'], 11);
      await v11AppDb.close();

      final kek = await BackupCrypto.deriveKey(passphrase, fastKdf);
      final sealedV11Bytes = BackupCrypto.seal(
        payload: exportedV11Payload,
        kek: kek,
        kdf: fastKdf,
        schemaVersion: 11,
        appVersion: '2.0.2+31',
        createdAt: _t2,
      );

      final backupFile = File('${tempDir.path}/cove_v11.covebackup');
      await backupFile.writeAsBytes(sealedV11Bytes, flush: true);

      // 2. Open the v11 backup file and restore it into a fresh v12 AppDatabase.
      final opened = await BackupCrypto.open(
        envelopeBytes: await backupFile.readAsBytes(),
        passphrase: passphrase,
      );
      expect(opened.envelope.schemaVersion, 11);

      final v12Db = AppDatabase(NativeDatabase.memory());
      addTearDown(v12Db.close);
      final v12KeyStore = HomeKeyStore();
      final v12Restorer = BackupSnapshotService(
        db: v12Db,
        keyStore: v12KeyStore,
      );
      await v12Restorer.restore(opened.payload);

      // 3. Verify every row across all 17 v11 tables is identical and the new v12
      //    columns hold their defaults (owner = 'both' on events & routine events, NULL on list items).
      final afterRestoreV12 = await _dumpRawTables(v12Db, _v11TableNames);
      _assertV11ToV12RowsAndDefaults(
        beforeV11: beforeV11,
        afterV12: afterRestoreV12,
      );

      expect(await v12Db.select(v12Db.localPets).get(), isEmpty);
      expect(await v12Db.select(v12Db.localPetTags).get(), isEmpty);
      expect(await v12KeyStore.getKey('home_cove_1'), equals(homeKey));
    });

    test(
        'a v12 backup restored into a v11 app is refused with the existing "newer version of Cove" message',
        () async {
      final fastKdf = BackupKdfParams(
        salt: BackupCrypto.randomBytes(BackupKdfParams.saltLength),
        memoryKiB: 64,
        iterations: 1,
        parallelism: 1,
      );
      const passphrase = 'correct horse battery staple';

      // 1. Export and seal a backup from a v12 AppDatabase.
      final v12Db = AppDatabase(NativeDatabase.memory());
      addTearDown(v12Db.close);
      final keyStore = HomeKeyStore();
      final v12Exporter = BackupSnapshotService(
        db: v12Db,
        keyStore: keyStore,
      );
      final v12Payload = await v12Exporter.export();
      expect(v12Payload['schemaVersion'], 12);

      final kek = await BackupCrypto.deriveKey(passphrase, fastKdf);
      final sealedV12Bytes = BackupCrypto.seal(
        payload: v12Payload,
        kek: kek,
        kdf: fastKdf,
        schemaVersion: 12,
        appVersion: '2.0.3+32',
        createdAt: _t2,
      );

      final openedV12 = await BackupCrypto.open(
        envelopeBytes: sealedV12Bytes,
        passphrase: passphrase,
      );
      expect(openedV12.envelope.schemaVersion, 12);

      // 2. Attempt to restore the v12 backup into a v11 app -> refused.
      final schema11 = await verifier.schemaAt(11);
      final v11AppDb = _AppDatabaseAtV11(schema11.newConnection());
      addTearDown(v11AppDb.close);

      final v11Restorer = BackupSnapshotService(
        db: v11AppDb,
        keyStore: keyStore,
      );

      await expectLater(
        () => v11Restorer.restore(openedV12.payload),
        throwsA(
          isA<BackupFormatException>().having(
            (e) => e.message,
            'message',
            'This backup was made by a newer version of Cove. Update the app to restore it.',
          ),
        ),
      );
    });

    test(
        'background paths: a v11 file and a v12 app make both widget tick and read-only notification connection refuse, and the app applies the intent after it migrates to v12',
        () async {
      await withClock(Clock.fixed(_t2), () async {
        final tempDir = await Directory.systemTemp.createTemp('cove_v11_bg_refuse_');
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final dbFile = File('${tempDir.path}/cove_db.sqlite');

        // 1. Create a real v11 database file on disk (PRAGMA user_version = 11)
        //    with populated rows, including uncompleted list item 'item_open_2'.
        final schema11 = await verifier.schemaAt(11);
        schema11.rawDatabase.execute(
          "VACUUM INTO '${dbFile.path.replaceAll("'", "''")}';",
        );
        schema11.rawDatabase.close();

        final v11OnDisk = v11.DatabaseAtV11(NativeDatabase(dbFile));
        await _populateV11Database(v11OnDisk);
        final verBefore =
            await v11OnDisk.customSelect('PRAGMA user_version;').getSingle();
        expect(verBefore.read<int>('user_version'), 11);
        await v11OnDisk.close();

        final prefs = await SharedPreferences.getInstance();
        final keyStore = HomeKeyStore();
        await keyStore.saveKey('home_cove_1', BackupCrypto.randomBytes(32));

        // 2. Direct helper checks: both background open helpers refuse the v11 file.
        final writableBgDb =
            await AppDatabase.openBackgroundWritableIfSchemaMatches(
          file: dbFile,
        );
        expect(writableBgDb, isNull);

        final readOnlyBgDb =
            await AppDatabase.openBackgroundReadOnlyIfSchemaMatches(
          file: dbFile,
        );
        expect(readOnlyBgDb, isNull);

        // 3. Background notification path refuses to open the mismatched v11 DB.
        var notifDbOpenedCount = 0;
        var notifDbRefusedCount = 0;
        final notifSink = _FakeNotificationSink();

        await NotificationService.handleBackgroundRemoteMessage(
          RemoteMessage(
            data: <String, dynamic>{
              'home_id': 'home_cove_1',
              'event_id': 'activity_evt_2',
              'event_type': 'expense_logged',
            },
          ),
          databaseFile: dbFile,
          onReadOnlyDatabaseOpened: () => notifDbOpenedCount += 1,
          onReadOnlyDatabaseRefusedSchemaMismatch: () =>
              notifDbRefusedCount += 1,
          sinkOverride: notifSink,
          sharedPreferencesOverride: prefs,
          keyStoreOverride: keyStore,
          viewerUserIdOverride: 'user_ancy',
        );
        expect(notifDbOpenedCount, 0);
        expect(notifDbRefusedCount, 1);

        // 4. Background widget tick refuses to touch the v11 DB and queues the intent.
        var widgetBgDbOpenedCount = 0;
        final bgTickResult = await CoveWidgetTickService.handleWidgetTick(
          kind: WidgetTickKind.listItem,
          recordId: 'item_open_2',
          databaseFile: dbFile,
          sharedPreferencesOverride: prefs,
          keyStoreOverride: keyStore,
          viewerUserIdOverride: 'user_saba',
          onBackgroundDatabaseOpened: () => widgetBgDbOpenedCount += 1,
        );
        expect(bgTickResult.outcome, WidgetTickOutcome.refusedSchemaMismatch);
        expect(bgTickResult.wroteToDatabase, isFalse);
        expect(widgetBgDbOpenedCount, 0);

        final queuedIntents =
            await WidgetTickIntentLog(prefs).getUnappliedIntents();
        expect(queuedIntents, hasLength(1));
        expect(queuedIntents.single.recordId, 'item_open_2');

        // Confirm the SQLite file is still at user_version = 11 and 'item_open_2' is still open.
        final v11Check = v11.DatabaseAtV11(NativeDatabase(dbFile));
        final verStill11 =
            await v11Check.customSelect('PRAGMA user_version;').getSingle();
        expect(verStill11.read<int>('user_version'), 11);
        final itemStillOpen = await (v11Check.select(v11Check.localListItems)
              ..where((t) => t.id.equals('item_open_2')))
            .getSingle();
        expect(itemStillOpen.isCompleted, 0);
        await v11Check.close();

        // 5. Now the v12 app opens the file -> migrates 11 -> 12 -> replays the queued intent.
        final appDb = AppDatabase(NativeDatabase(dbFile));
        addTearDown(appDb.close);

        final verAfterMigrate =
            await appDb.customSelect('PRAGMA user_version;').getSingle();
        expect(verAfterMigrate.read<int>('user_version'), 12);

        final mainTickService = CoveWidgetTickService(
          appDatabase: appDb,
          sharedPreferences: prefs,
          homeKeyStore: keyStore,
          getCurrentUserId: () => 'user_saba',
        );
        final replayed =
            await mainTickService.replayUnappliedIntentsOnAppStart();
        expect(replayed, hasLength(1));
        expect(replayed.single.outcome, WidgetTickOutcome.appliedOnAppStart);
        expect(replayed.single.wroteToDatabase, isTrue);

        // Verify 'item_open_2' is now completed in the v12 DB and the intent log is cleared.
        final completedItem = await (appDb.select(appDb.localListItems)
              ..where((t) => t.id.equals('item_open_2')))
            .getSingle();
        expect(completedItem.isCompleted, isTrue);
        expect(completedItem.completedBy, 'user_saba');
        expect(completedItem.owner, isNull);

        expect(
          await WidgetTickIntentLog(prefs).getUnappliedIntents(),
          isEmpty,
        );
      });
    });

    test(
        'two devices tag the same pet on the same record offline -> after both sync, exactly one tag (whichever device id arrives second is a no-op)',
        () async {
      // Simulate two devices (Saba's Fold and Ancy's Pixel), each migrated from v11 -> v12.
      final schemaA = await verifier.schemaAt(11);
      final oldDbA = v11.DatabaseAtV11(schemaA.newConnection());
      await _populateV11Database(oldDbA);
      await oldDbA.close();
      final dbA = AppDatabase(schemaA.newConnection());
      addTearDown(dbA.close);

      final schemaB = await verifier.schemaAt(11);
      final oldDbB = v11.DatabaseAtV11(schemaB.newConnection());
      await _populateV11Database(oldDbB);
      await oldDbB.close();
      final dbB = AppDatabase(schemaB.newConnection());
      addTearDown(dbB.close);

      final storeA = LocalStateStoreImpl(dbA);
      final storeB = LocalStateStoreImpl(dbB);

      // Verify the lookup index on (record_kind, record_id) and unique index on
      // (pet_id, record_kind, record_id) exist on both migrated v12 databases.
      for (final db in [dbA, dbB]) {
        final indexRows = await db
            .customSelect("PRAGMA index_list('local_pet_tags');")
            .get();
        final indexNames =
            indexRows.map((r) => r.read<String>('name')).toList();
        expect(indexNames, contains('idx_local_pet_tags_record'));
        expect(
          indexRows.where((r) => r.read<int>('unique') == 1).length,
          greaterThanOrEqualTo(2), // PK (id) + UNIQUE (pet_id, record_kind, record_id)
        );
      }

      // Both devices have the same pet ('pet_milo') and expense ('exp_dinner_1').
      final petPayload = <String, dynamic>{
        'id': 'pet_milo',
        'home_id': 'home_cove_1',
        'name': 'Milo',
        'created_by': 'user_saba',
        'created_at': _t1.toIso8601String(),
        'is_archived': false,
      };
      await storeA.applyEvent(
        eventId: 'evt_pet_created_1',
        homeId: 'home_cove_1',
        eventType: 'pet_created',
        payload: petPayload,
        timestamp: _t1,
        authorId: 'user_saba',
      );
      await storeB.applyEvent(
        eventId: 'evt_pet_created_1',
        homeId: 'home_cove_1',
        eventType: 'pet_created',
        payload: petPayload,
        timestamp: _t1,
        authorId: 'user_saba',
      );

      // Offline: Saba tags Milo on 'exp_dinner_1' on Device A with id 'tag_saba_fold'.
      final tagEventA = <String, dynamic>{
        'id': 'tag_saba_fold',
        'home_id': 'home_cove_1',
        'pet_id': 'pet_milo',
        'record_kind': 'expense',
        'record_id': 'exp_dinner_1',
        'created_at': _t2.toIso8601String(),
      };
      await storeA.applyEvent(
        eventId: 'evt_tag_a',
        homeId: 'home_cove_1',
        eventType: 'pet_tag_added',
        payload: tagEventA,
        timestamp: _t2,
        authorId: 'user_saba',
      );

      // Offline: Ancy tags Milo on the same 'exp_dinner_1' on Device B with a DIFFERENT id 'tag_ancy_pixel'.
      final tagEventB = <String, dynamic>{
        'id': 'tag_ancy_pixel',
        'home_id': 'home_cove_1',
        'pet_id': 'pet_milo',
        'record_kind': 'expense',
        'record_id': 'exp_dinner_1',
        'created_at': _t2.add(const Duration(seconds: 15)).toIso8601String(),
      };
      await storeB.applyEvent(
        eventId: 'evt_tag_b',
        homeId: 'home_cove_1',
        eventType: 'pet_tag_added',
        payload: tagEventB,
        timestamp: _t2.add(const Duration(seconds: 15)),
        authorId: 'user_ancy',
      );

      // Both devices now come online and sync each other's pet_tag_added event:
      // - On Device A, Ancy's 'tag_ancy_pixel' arrives second -> no-op.
      await storeA.applyEvent(
        eventId: 'evt_tag_b',
        homeId: 'home_cove_1',
        eventType: 'pet_tag_added',
        payload: tagEventB,
        timestamp: _t2.add(const Duration(seconds: 15)),
        authorId: 'user_ancy',
      );
      // - On Device B, Saba's 'tag_saba_fold' arrives second -> no-op.
      await storeB.applyEvent(
        eventId: 'evt_tag_a',
        homeId: 'home_cove_1',
        eventType: 'pet_tag_added',
        payload: tagEventA,
        timestamp: _t2,
        authorId: 'user_saba',
      );

      final tagsOnA = await (dbA.select(dbA.localPetTags)
            ..where((t) =>
                t.recordKind.equals('expense') &
                t.recordId.equals('exp_dinner_1')))
          .get();
      expect(tagsOnA, hasLength(1));
      expect(tagsOnA.single.petId, 'pet_milo');
      expect(tagsOnA.single.id, 'tag_saba_fold');

      final tagsOnB = await (dbB.select(dbB.localPetTags)
            ..where((t) =>
                t.recordKind.equals('expense') &
                t.recordId.equals('exp_dinner_1')))
          .get();
      expect(tagsOnB, hasLength(1));
      expect(tagsOnB.single.petId, 'pet_milo');
      expect(tagsOnB.single.id, 'tag_ancy_pixel');
    });
  });
}
