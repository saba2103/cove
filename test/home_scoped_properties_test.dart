import 'dart:async';
import 'package:cove/features/expenses/monthly_budget_controller.dart';
import 'package:cove/features/profile/home_metadata_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/reminders/reminder_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeActiveHomeNotifier extends ActiveHomeNotifier {
  final String? initial;
  FakeActiveHomeNotifier(this.initial);

  @override
  String? build() => initial;
}

class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _map = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _map[key] = value;
    } else {
      _map.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _map[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _map.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeSecureStorage storage;
  late LocalStateStoreImpl localStateStore;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    storage = FakeSecureStorage();
    localStateStore = LocalStateStoreImpl(db, storage: storage);
  });

  tearDown(() async {
    await db.close();
  });

  group('Home-Scoped Properties Database Projections', () {
    test('home_created and home_updated project monthlyBudget, anniversaryDate, and currency into SQLite', () async {
      final now = DateTime.now().toUtc();
      final anniversary = DateTime(2022, 6, 15);

      await localStateStore.applyEvent(
        eventId: 'evt_home_1',
        homeId: 'home_alpha',
        authorId: 'user_1',
        eventType: 'home_created',
        payload: {
          'id': 'home_alpha',
          'name': 'Alpha Sanctuary',
          'currency': 'EUR',
          'monthly_budget': 1500.0,
          'anniversary_date': anniversary.toIso8601String(),
        },
        timestamp: now,
      );

      var home = await (db.select(db.localHomes)..where((t) => t.id.equals('home_alpha'))).getSingleOrNull();
      expect(home, isNotNull);
      expect(home!.name, 'Alpha Sanctuary');
      expect(home.currency, 'EUR');
      expect(home.monthlyBudget, 1500.0);
      expect(home.anniversaryDate, anniversary);

      // Now partner edits the home details
      final updatedAnniversary = DateTime(2021, 9, 20);
      await localStateStore.applyEvent(
        eventId: 'evt_home_2',
        homeId: 'home_alpha',
        authorId: 'user_2',
        eventType: 'home_updated',
        payload: {
          'id': 'home_alpha',
          'name': 'Alpha Nest',
          'anniversary_date': updatedAnniversary.toIso8601String(),
          'monthly_budget': 2000.0,
        },
        timestamp: now.add(const Duration(minutes: 5)),
      );

      home = await (db.select(db.localHomes)..where((t) => t.id.equals('home_alpha'))).getSingleOrNull();
      expect(home!.name, 'Alpha Nest');
      expect(home.currency, 'EUR'); // Retained
      expect(home.monthlyBudget, 2000.0);
      expect(home.anniversaryDate, updatedAnniversary);
    });

    test('home_currency_updated immediately updates LocalHomes.currency in SQLite without suppression', () async {
      await db.into(db.localHomes).insert(
        LocalHomesCompanion.insert(
          id: 'home_curr',
          name: 'Home Currency',
          currency: const drift.Value('USD'),
          createdAt: DateTime.now().toUtc(),
          createdBy: 'user_1',
        ),
      );

      await localStateStore.applyEvent(
        eventId: 'evt_curr_1',
        homeId: 'home_curr',
        authorId: 'user_2',
        eventType: 'home_currency_updated',
        payload: {
          'id': 'home_curr',
          'currency': 'INR',
        },
        timestamp: DateTime.now().toUtc(),
      );

      final home = await (db.select(db.localHomes)..where((t) => t.id.equals('home_curr'))).getSingleOrNull();
      expect(home!.currency, 'INR');
    });

    test('home_anniversary_updated updates LocalHomes.anniversaryDate in SQLite', () async {
      await db.into(db.localHomes).insert(
        LocalHomesCompanion.insert(
          id: 'home_anni',
          name: 'Home Anniversary',
          createdAt: DateTime.now().toUtc(),
          createdBy: 'user_1',
        ),
      );

      final date = DateTime(2020, 10, 5);
      await localStateStore.applyEvent(
        eventId: 'evt_anni_1',
        homeId: 'home_anni',
        authorId: 'user_2',
        eventType: 'home_anniversary_updated',
        payload: {
          'id': 'home_anni',
          'anniversary_date': date.toIso8601String(),
        },
        timestamp: DateTime.now().toUtc(),
      );

      final home = await (db.select(db.localHomes)..where((t) => t.id.equals('home_anni'))).getSingleOrNull();
      expect(home!.anniversaryDate, date);
    });

    test('monthly_budget_updated and cleared persist to LocalHomes.monthlyBudget in SQLite', () async {
      await db.into(db.localHomes).insert(
        LocalHomesCompanion.insert(
          id: 'home_budg',
          name: 'Home Budget',
          createdAt: DateTime.now().toUtc(),
          createdBy: 'user_1',
        ),
      );

      await localStateStore.applyEvent(
        eventId: 'evt_budg_1',
        homeId: 'home_budg',
        authorId: 'user_2',
        eventType: 'monthly_budget_updated',
        payload: {
          'home_id': 'home_budg',
          'amount': 3250.0,
        },
        timestamp: DateTime.now().toUtc(),
      );

      var home = await (db.select(db.localHomes)..where((t) => t.id.equals('home_budg'))).getSingleOrNull();
      expect(home!.monthlyBudget, 3250.0);

      // Clear budget
      await localStateStore.applyEvent(
        eventId: 'evt_budg_2',
        homeId: 'home_budg',
        authorId: 'user_2',
        eventType: 'monthly_budget_cleared',
        payload: {
          'home_id': 'home_budg',
        },
        timestamp: DateTime.now().toUtc(),
      );

      home = await (db.select(db.localHomes)..where((t) => t.id.equals('home_budg'))).getSingleOrNull();
      expect(home!.monthlyBudget, isNull);
    });

    test('checkin_reminder sync events perform full SQLite CRUD', () async {
      await localStateStore.applyEvent(
        eventId: 'evt_rem_1',
        homeId: 'home_rem',
        authorId: 'user_2',
        eventType: 'checkin_reminder_added',
        payload: {
          'id': 'rem_test_1',
          'home_id': 'home_rem',
          'hour': 21,
          'minute': 15,
          'message': 'Evening cuddle & check-in',
          'is_enabled': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
        timestamp: DateTime.now().toUtc(),
      );

      var reminders = await db.getCheckinReminders('home_rem');
      expect(reminders.length, 1);
      expect(reminders.first.id, 'rem_test_1');
      expect(reminders.first.hour, 21);
      expect(reminders.first.minute, 15);
      expect(reminders.first.message, 'Evening cuddle & check-in');
      expect(reminders.first.isEnabled, isTrue);

      // Toggle
      await localStateStore.applyEvent(
        eventId: 'evt_rem_2',
        homeId: 'home_rem',
        authorId: 'user_2',
        eventType: 'checkin_reminder_toggled',
        payload: {
          'id': 'rem_test_1',
          'home_id': 'home_rem',
          'is_enabled': false,
        },
        timestamp: DateTime.now().toUtc(),
      );

      reminders = await db.getCheckinReminders('home_rem');
      expect(reminders.first.isEnabled, isFalse);

      // Delete
      await localStateStore.applyEvent(
        eventId: 'evt_rem_3',
        homeId: 'home_rem',
        authorId: 'user_2',
        eventType: 'checkin_reminder_deleted',
        payload: {
          'id': 'rem_test_1',
          'home_id': 'home_rem',
        },
        timestamp: DateTime.now().toUtc(),
      );

      reminders = await db.getCheckinReminders('home_rem');
      expect(reminders.isEmpty, isTrue);
    });
  });

  group('Reactive Controller Synchronization Tests', () {
    test('MonthlyBudgetNotifier streams from active home in DB and updates DB on setBudget/clearBudget', () async {
      await db.into(db.localHomes).insert(
        LocalHomesCompanion.insert(
          id: 'home_test_budg',
          name: 'Budget Test Home',
          monthlyBudget: const drift.Value(1200.0),
          createdAt: DateTime.now().toUtc(),
          createdBy: 'user_1',
        ),
      );

      final emittedEvents = <Map<String, dynamic>>[];

      final homeObj = LocalHome(
        id: 'home_test_budg',
        name: 'Budget Test Home',
        currency: 'USD',
        monthlyBudget: 1200.0,
        createdAt: DateTime.now().toUtc(),
        createdBy: 'user_1',
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_test_budg')),
          activeHomeProvider.overrideWith((ref) => Stream.value(homeObj)),
          coveEmitActionProvider.overrideWithValue(({
            required String eventType,
            required Map<String, dynamic> payload,
            String? targetHomeId,
            bool isPrivate = false,
          }) async {
            emittedEvents.add({
              'eventType': eventType,
              'payload': payload,
              'targetHomeId': targetHomeId,
            });
          }),
        ],
      );
      addTearDown(container.dispose);

      container.listen(monthlyBudgetProvider, (_, _) {});
      await pumpEventQueue();
      expect(container.read(monthlyBudgetProvider), 1200.0);

      // Set new budget via notifier
      await container.read(monthlyBudgetProvider.notifier).setBudget(2500.0);
      expect(container.read(monthlyBudgetProvider), 2500.0);

      // Verify DB was updated
      var home = await (db.select(db.localHomes)..where((t) => t.id.equals('home_test_budg'))).getSingleOrNull();
      expect(home!.monthlyBudget, 2500.0);

      // Verify sync event was emitted
      expect(emittedEvents.any((e) => e['eventType'] == 'monthly_budget_updated' && e['payload']['amount'] == 2500.0), isTrue);

      // Clear budget
      await container.read(monthlyBudgetProvider.notifier).clearBudget();
      expect(container.read(monthlyBudgetProvider), isNull);

      home = await (db.select(db.localHomes)..where((t) => t.id.equals('home_test_budg'))).getSingleOrNull();
      expect(home!.monthlyBudget, isNull);
      expect(emittedEvents.any((e) => e['eventType'] == 'monthly_budget_cleared'), isTrue);
    });

    test('CurrencyNotifier streams from active home in DB and updates DB on setCurrency', () async {
      await db.into(db.localHomes).insert(
        LocalHomesCompanion.insert(
          id: 'home_test_curr',
          name: 'Currency Test Home',
          currency: const drift.Value('EUR'),
          createdAt: DateTime.now().toUtc(),
          createdBy: 'user_1',
        ),
      );

      final emittedEvents = <Map<String, dynamic>>[];

      final homeObj = LocalHome(
        id: 'home_test_curr',
        name: 'Currency Test Home',
        currency: 'EUR',
        createdAt: DateTime.now().toUtc(),
        createdBy: 'user_1',
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_test_curr')),
          activeHomeProvider.overrideWith((ref) => Stream.value(homeObj)),
          coveEmitActionProvider.overrideWithValue(({
            required String eventType,
            required Map<String, dynamic> payload,
            String? targetHomeId,
            bool isPrivate = false,
          }) async {
            emittedEvents.add({
              'eventType': eventType,
              'payload': payload,
            });
          }),
        ],
      );
      addTearDown(container.dispose);

      container.listen(currencyPreferenceProvider, (_, _) {});
      await pumpEventQueue();
      expect(container.read(currencyPreferenceProvider).code, 'EUR');

      // Set new currency
      await container.read(currencyPreferenceProvider.notifier).setCurrency(
        supportedCurrencies.firstWhere((c) => c.code == 'GBP'),
      );
      expect(container.read(currencyPreferenceProvider).code, 'GBP');

      final home = await (db.select(db.localHomes)..where((t) => t.id.equals('home_test_curr'))).getSingleOrNull();
      expect(home!.currency, 'GBP');
      expect(emittedEvents.any((e) => e['eventType'] == 'home_currency_updated' && e['payload']['currency'] == 'GBP'), isTrue);
    });

    test('HomeMetadataNotifier streams anniversaryDate from DB and updates DB on setAnniversaryDate', () async {
      final anni = DateTime(2019, 5, 20);
      await db.into(db.localHomes).insert(
        LocalHomesCompanion.insert(
          id: 'home_test_anni',
          name: 'Anniversary Test Home',
          anniversaryDate: drift.Value(anni),
          createdAt: DateTime.now().toUtc(),
          createdBy: 'user_1',
        ),
      );

      final emittedEvents = <Map<String, dynamic>>[];

      final homeObj = LocalHome(
        id: 'home_test_anni',
        name: 'Anniversary Test Home',
        currency: 'USD',
        anniversaryDate: anni,
        createdAt: DateTime.now().toUtc(),
        createdBy: 'user_1',
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_test_anni')),
          activeHomeProvider.overrideWith((ref) => Stream.value(homeObj)),
          coveEmitActionProvider.overrideWithValue(({
            required String eventType,
            required Map<String, dynamic> payload,
            String? targetHomeId,
            bool isPrivate = false,
          }) async {
            emittedEvents.add({
              'eventType': eventType,
              'payload': payload,
            });
          }),
        ],
      );
      addTearDown(container.dispose);

      container.listen(homeMetadataProvider, (_, _) {});
      await pumpEventQueue();
      expect(container.read(homeMetadataProvider).anniversaryDate, anni);

      final newAnni = DateTime(2018, 4, 10);
      await container.read(homeMetadataProvider.notifier).setAnniversaryDate(newAnni);
      expect(container.read(homeMetadataProvider).anniversaryDate, newAnni);

      final home = await (db.select(db.localHomes)..where((t) => t.id.equals('home_test_anni'))).getSingleOrNull();
      expect(home!.anniversaryDate, newAnni);
      expect(emittedEvents.any((e) => e['eventType'] == 'home_anniversary_updated'), isTrue);
    });

    test('ReminderNotifier streams check-in reminders from DB and performs CRUD', () async {
      await db.into(db.localHomes).insert(
        LocalHomesCompanion.insert(
          id: 'home_test_rem',
          name: 'Reminder Test Home',
          createdAt: DateTime.now().toUtc(),
          createdBy: 'user_1',
        ),
      );

      final emittedEvents = <Map<String, dynamic>>[];

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_test_rem')),
          coveEmitActionProvider.overrideWithValue(({
            required String eventType,
            required Map<String, dynamic> payload,
            String? targetHomeId,
            bool isPrivate = false,
          }) async {
            emittedEvents.add({
              'eventType': eventType,
              'payload': payload,
            });
          }),
        ],
      );
      addTearDown(container.dispose);

      container.listen(checkinRemindersProvider, (_, _) {});
      await pumpEventQueue();
      await Future.delayed(const Duration(milliseconds: 50));

      // Add a custom reminder
      await container.read(checkinRemindersProvider.notifier).addReminder(
        hour: 22,
        minute: 0,
        message: 'Sleep sanctuary time',
      );

      var remindersInDb = await db.getCheckinReminders('home_test_rem');
      expect(remindersInDb.any((r) => r.hour == 22 && r.message == 'Sleep sanctuary time'), isTrue);
      expect(emittedEvents.any((e) => e['eventType'] == 'checkin_reminder_added'), isTrue);

      final added = remindersInDb.firstWhere((r) => r.hour == 22);

      // Toggle
      await container.read(checkinRemindersProvider.notifier).toggleReminder(added.id, false);
      remindersInDb = await db.getCheckinReminders('home_test_rem');
      expect(remindersInDb.firstWhere((r) => r.id == added.id).isEnabled, isFalse);
      expect(emittedEvents.any((e) => e['eventType'] == 'checkin_reminder_toggled'), isTrue);

      // Delete
      await container.read(checkinRemindersProvider.notifier).deleteReminder(added.id);
      remindersInDb = await db.getCheckinReminders('home_test_rem');
      expect(remindersInDb.any((r) => r.id == added.id), isFalse);
      expect(emittedEvents.any((e) => e['eventType'] == 'checkin_reminder_deleted'), isTrue);
    });
  });
}
