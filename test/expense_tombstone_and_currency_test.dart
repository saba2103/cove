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

    test('LocalStateStore drops replayed list_created and list_item_added when tombstone exists', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final store = LocalStateStoreImpl(db);
      const homeId = 'home_test_lists';
      const listId = 'list_groceries_1';
      const itemId = 'item_milk_1';

      // 1. Create list and add item
      await store.applyEvent(
        eventId: 'evt_list_create_1',
        homeId: homeId,
        eventType: 'list_created',
        payload: {'id': listId, 'name': 'Grocery'},
        timestamp: DateTime.now(),
        authorId: 'user_1',
      );
      await store.applyEvent(
        eventId: 'evt_item_add_1',
        homeId: homeId,
        eventType: 'list_item_added',
        payload: {'id': itemId, 'list_id': listId, 'title': 'Organic Milk'},
        timestamp: DateTime.now(),
        authorId: 'user_1',
      );

      var lists = await db.getLists(homeId);
      expect(lists.length, 1);
      expect(lists.first.id, listId);

      // 2. Delete list
      await store.applyEvent(
        eventId: 'evt_list_del_1',
        homeId: homeId,
        eventType: 'list_deleted',
        payload: {'id': listId},
        timestamp: DateTime.now(),
        authorId: 'user_1',
      );

      lists = await db.getLists(homeId);
      expect(lists, isEmpty);
      expect(await db.isTombstoned(listId), isTrue);
      expect(await db.isTombstoned(itemId), isTrue);

      // 3. Historical replay of list_created must NOT resurrect list
      await store.applyEvent(
        eventId: 'evt_list_create_replay',
        homeId: homeId,
        eventType: 'list_created',
        payload: {'id': listId, 'name': 'Grocery'},
        timestamp: DateTime.now(),
        authorId: 'user_1',
      );
      lists = await db.getLists(homeId);
      expect(lists, isEmpty);

      // 4. Historical replay of list_item_added must NOT auto-heal/resurrect parent list or insert item
      await store.applyEvent(
        eventId: 'evt_item_add_replay',
        homeId: homeId,
        eventType: 'list_item_added',
        payload: {'id': itemId, 'list_id': listId, 'title': 'Organic Milk', 'list_name': 'Grocery'},
        timestamp: DateTime.now(),
        authorId: 'user_1',
      );
      lists = await db.getLists(homeId);
      expect(lists, isEmpty);
      final items = await (db.select(db.localListItems)..where((t) => t.id.equals(itemId))).get();
      expect(items, isEmpty);
    });

    test('ensureDefaultLists does not resurrect tombstoned default lists', () async {
      final db = AppDatabase(NativeDatabase.memory());
      const homeId = 'home_test_defaults';
      const userId = 'user_1';

      // 1. Initial creation of default lists
      await db.ensureDefaultLists(homeId, userId);
      var lists = await db.getLists(homeId);
      expect(lists.map((l) => l.name), containsAll(['Grocery', 'Travel', 'Planning']));

      // 2. Tombstone 'Travel' list
      final travelList = lists.firstWhere((l) => l.name == 'Travel');
      await db.recordTombstone(travelList.id, 'list');
      await db.recordTombstone('default_travel_$homeId', 'list');
      await db.recordTombstone('default_name_travel_$homeId', 'list');
      await (db.delete(db.localLists)..where((t) => t.id.equals(travelList.id))).go();

      lists = await db.getLists(homeId);
      expect(lists.any((l) => l.name == 'Travel'), isFalse);

      // 3. ensureDefaultLists runs (e.g. on pull-to-refresh or app launch)
      await db.ensureDefaultLists(homeId, userId);
      lists = await db.getLists(homeId);

      // Travel must NOT be resurrected!
      expect(lists.any((l) => l.name == 'Travel'), isFalse);
      expect(lists.any((l) => l.name == 'Grocery'), isTrue);
      expect(lists.any((l) => l.name == 'Planning'), isTrue);
    });

    test('LocalStateStore drops replayed subscription_added when tombstoned', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final store = LocalStateStoreImpl(db);
      const homeId = 'home_test_subs';
      const subId = 'sub_netflix_1';

      await store.applyEvent(
        eventId: 'evt_sub_add_1',
        homeId: homeId,
        eventType: 'subscription_added',
        payload: {
          'id': subId,
          'name': 'Netflix',
          'amount': 15.99,
          'currency': 'USD',
        },
        timestamp: DateTime.now(),
        authorId: 'user_1',
      );

      var subs = await (db.select(db.localSubscriptions)..where((t) => t.homeId.equals(homeId))).get();
      expect(subs.length, 1);

      // Delete subscription
      await store.applyEvent(
        eventId: 'evt_sub_del_1',
        homeId: homeId,
        eventType: 'subscription_deleted',
        payload: {'id': subId},
        timestamp: DateTime.now(),
        authorId: 'user_1',
      );

      subs = await (db.select(db.localSubscriptions)..where((t) => t.homeId.equals(homeId))).get();
      expect(subs, isEmpty);
      expect(await db.isTombstoned(subId), isTrue);

      // Replay subscription_added
      await store.applyEvent(
        eventId: 'evt_sub_add_replay',
        homeId: homeId,
        eventType: 'subscription_added',
        payload: {
          'id': subId,
          'name': 'Netflix',
          'amount': 15.99,
          'currency': 'USD',
        },
        timestamp: DateTime.now(),
        authorId: 'user_1',
      );

      subs = await (db.select(db.localSubscriptions)..where((t) => t.homeId.equals(homeId))).get();
      expect(subs, isEmpty);
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
