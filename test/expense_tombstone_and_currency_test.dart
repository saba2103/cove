import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Tombstone & Idempotent Sync Ledger Tests', () {
    test('LocalAppliedEvents records and recognizes applied events', () async {
      final db = AppDatabase(NativeDatabase.memory());

      expect(await db.hasAppliedEvent('evt_test_1'), isFalse);

      await db.recordAppliedEvent('evt_test_1');
      expect(await db.hasAppliedEvent('evt_test_1'), isTrue);
      expect(await db.hasAppliedEvent('evt_test_2'), isFalse);
    });

    test('LocalDeletedTombstones records entity deletions', () async {
      final db = AppDatabase(NativeDatabase.memory());

      expect(await db.isTombstoned('exp_101'), isFalse);

      await db.recordTombstone('exp_101', 'expense');
      expect(await db.isTombstoned('exp_101'), isTrue);
      expect(await db.isTombstoned('exp_102'), isFalse);
    });

    test('LocalStateStore drops replayed expense_logged when tombstone exists', () async {
      final db = AppDatabase(NativeDatabase.memory());

      final store = LocalStateStoreImpl(db);
      const homeId = 'home_test_1';
      const expenseId = 'exp_replayed_1';

      // 1. Initial expense_logged inserts expense
      await store.applyEvent(
        eventId: 'evt_log_1',
        homeId: homeId,
        eventType: 'expense_logged',
        payload: {
          'id': expenseId,
          'title': 'Electricity Bill',
          'amount': 1500.0,
          'currency': 'INR',
          'paid_by': 'user_1',
        },
        timestamp: DateTime.now(),
        authorId: 'user_1',
      );

      var expenses = await db.getExpenses(homeId);
      expect(expenses.length, 1);
      expect(expenses.first.id, expenseId);

      // 2. expense_deleted deletes row and tombstones it
      await store.applyEvent(
        eventId: 'evt_del_1',
        homeId: homeId,
        eventType: 'expense_deleted',
        payload: {'id': expenseId},
        timestamp: DateTime.now(),
        authorId: 'user_1',
      );

      expenses = await db.getExpenses(homeId);
      expect(expenses, isEmpty);
      expect(await db.isTombstoned(expenseId), isTrue);

      // 3. Simulated pull-to-refresh replay of old expense_logged
      await store.applyEvent(
        eventId: 'evt_log_1_replay',
        homeId: homeId,
        eventType: 'expense_logged',
        payload: {
          'id': expenseId,
          'title': 'Electricity Bill',
          'amount': 1500.0,
          'currency': 'INR',
          'paid_by': 'user_1',
        },
        timestamp: DateTime.now(),
        authorId: 'user_1',
      );

      // Expense must NOT be resurrected!
      expenses = await db.getExpenses(homeId);
      expect(expenses, isEmpty);
    });
  });

  group('Currency Retention & Protection Tests', () {
    test('LocalStateStore prevents remote EUR event from overriding user-selected INR', () async {
      final db = AppDatabase(NativeDatabase.memory());

      final store = LocalStateStoreImpl(db);
      const homeId = 'home_test_currency';

      // Setup home with INR
      await db.into(db.localHomes).insert(
            LocalHomesCompanion.insert(
              id: homeId,
              name: 'Our Home',
              currency: const drift.Value('INR'),
              createdAt: DateTime.now(),
              createdBy: 'user_1',
            ),
          );

      // Set user's explicit preference to INR
      CurrencyNotifier.cachedInitialCurrency = 'INR';

      // Simulate incoming remote event with EUR (e.g. from historical Supabase event)
      await store.applyEvent(
        eventId: 'evt_currency_eur',
        homeId: homeId,
        eventType: 'home_currency_updated',
        payload: {
          'id': homeId,
          'currency': 'EUR',
        },
        timestamp: DateTime.now(),
        authorId: 'remote_actor',
      );

      final home = await (db.select(db.localHomes)..where((t) => t.id.equals(homeId))).getSingle();
      expect(home.currency, 'INR'); // Kept INR!
    });
  });
}
