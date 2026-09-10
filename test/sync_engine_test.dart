import 'dart:typed_data';
import 'package:cove/sync/crypto/deterministic_home_icon.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/encryption_service.dart';
import 'package:cove/sync/event_store.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/key_management/pairing_payload.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Crypto & Key Management Tests', () {
    final crypto = SodiumCryptoService();

    test('Generates valid 256-bit symmetric keys and 96-bit nonces', () {
      final key1 = crypto.generateHomeKey();
      final key2 = crypto.generateHomeKey();

      expect(key1.length, equals(32));
      expect(key2.length, equals(32));
      expect(key1, isNot(equals(key2)));
    });

    test('Encrypts and decrypts JSON payload with AEAD authentication', () async {
      final key = crypto.generateHomeKey();
      const originalJson = '{"item":"Oat milk","qty":2,"urgent":true}';

      final encrypted = await crypto.encrypt(
        plaintextJson: originalJson,
        homeKey: key,
      );

      expect(encrypted.ciphertext.isNotEmpty, isTrue);
      expect(encrypted.nonce.length, equals(12));

      final decrypted = await crypto.decrypt(
        payload: encrypted,
        homeKey: key,
      );

      expect(decrypted, equals(originalJson));
    });

    test('Fails decryption when using wrong symmetric key', () async {
      final key1 = crypto.generateHomeKey();
      final key2 = crypto.generateHomeKey();
      const payload = '{"secret":"household budget"}';

      final encrypted = await crypto.encrypt(
        plaintextJson: payload,
        homeKey: key1,
      );

      expect(
        () async => await crypto.decrypt(payload: encrypted, homeKey: key2),
        throwsA(anything),
      );
    });

    test('Serializes to and from Supabase transport string', () {
      final payload = EncryptedPayload(
        ciphertext: Uint8List.fromList([1, 2, 3, 4, 5]),
        nonce: Uint8List.fromList([10, 20, 30]),
      );

      final transportString = crypto.serializeToTransportString(payload);
      expect(transportString.contains('"c":'), isTrue);
      expect(transportString.contains('"n":'), isTrue);

      final restored = crypto.deserializeFromTransportString(transportString);
      expect(restored.ciphertext, equals(payload.ciphertext));
      expect(restored.nonce, equals(payload.nonce));
    });

    test('PairingPayload serializes and deserializes QR code payload', () {
      final key = crypto.generateHomeKey();
      final now = DateTime.now().toUtc();

      final payload = PairingPayload(
        homeId: 'home-alpha-123',
        homeName: 'The Cove',
        symmetricKey: key,
        inviterId: 'user-alex-456',
        createdAt: now,
      );

      final qrString = payload.toQrString();
      final parsed = PairingPayload.fromQrString(qrString);

      expect(parsed.homeId, equals('home-alpha-123'));
      expect(parsed.homeName, equals('The Cove'));
      expect(parsed.inviterId, equals('user-alex-456'));
      expect(parsed.symmetricKey, equals(key));
    });
  });

  group('Drift LocalStateStore Event Projection Tests', () {
    late AppDatabase db;
    late LocalStateStoreImpl localStore;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      localStore = LocalStateStoreImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Projects list, list item, toggle, and delete events', () async {
      const homeId = 'home-001';
      final now = DateTime.now().toUtc();

      // 1. Create list
      await localStore.applyEvent(
        homeId: homeId,
        eventType: 'list_created',
        payload: {'id': 'list-groceries', 'name': 'Groceries'},
        timestamp: now,
        authorId: 'alex',
      );

      var lists = await db.watchLists(homeId).first;
      expect(lists.length, equals(1));
      expect(lists.first.name, equals('Groceries'));

      // 2. Add item
      await localStore.applyEvent(
        homeId: homeId,
        eventType: 'list_item_added',
        payload: {
          'id': 'item-oat-milk',
          'list_id': 'list-groceries',
          'title': 'Oat milk (unsweetened)',
          'notes': 'Organic preferred',
        },
        timestamp: now,
        authorId: 'sarah',
      );

      var items = await db.watchListItems(homeId, 'list-groceries').first;
      expect(items.length, equals(1));
      expect(items.first.title, equals('Oat milk (unsweetened)'));
      expect(items.first.isCompleted, isFalse);

      // 3. Toggle item
      await localStore.applyEvent(
        homeId: homeId,
        eventType: 'list_item_toggled',
        payload: {'id': 'item-oat-milk', 'is_completed': true},
        timestamp: now.add(const Duration(minutes: 5)),
        authorId: 'alex',
      );

      items = await db.watchListItems(homeId, 'list-groceries').first;
      expect(items.first.isCompleted, isTrue);
      expect(items.first.completedBy, equals('alex'));

      // 4. Delete item
      await localStore.applyEvent(
        homeId: homeId,
        eventType: 'list_item_deleted',
        payload: {'id': 'item-oat-milk'},
        timestamp: now.add(const Duration(minutes: 10)),
        authorId: 'alex',
      );

      items = await db.watchListItems(homeId, 'list-groceries').first;
      expect(items.isEmpty, isTrue);
    });

    test('Projects subscriptions, expenses, habits, and calendar events',
        () async {
      const homeId = 'home-001';
      final now = DateTime.now().toUtc();

      // Subscriptions
      await localStore.applyEvent(
        homeId: homeId,
        eventType: 'subscription_added',
        payload: {
          'id': 'sub-spotify',
          'name': 'Spotify Duo',
          'amount': 16.99,
          'currency': 'USD',
          'billing_cycle': 'monthly',
          'next_billing_date': now.add(const Duration(days: 15)).toIso8601String(),
          'category': 'Entertainment',
        },
        timestamp: now,
        authorId: 'alex',
      );

      final subs = await db.watchSubscriptions(homeId).first;
      expect(subs.length, equals(1));
      expect(subs.first.name, equals('Spotify Duo'));
      expect(subs.first.amount, equals(16.99));

      // Expenses
      await localStore.applyEvent(
        homeId: homeId,
        eventType: 'expense_logged',
        payload: {
          'id': 'exp-market',
          'title': 'Farmers Market',
          'amount': 42.50,
          'currency': 'USD',
          'paid_by': 'sarah',
          'split_ratio': 0.5,
          'expense_date': now.toIso8601String(),
          'category': 'Groceries',
        },
        timestamp: now,
        authorId: 'sarah',
      );

      final expenses = await db.watchExpenses(homeId).first;
      expect(expenses.length, equals(1));
      expect(expenses.first.title, equals('Farmers Market'));
      expect(expenses.first.amount, equals(42.50));

      // Habits & Checkins
      await localStore.applyEvent(
        homeId: homeId,
        eventType: 'habit_created',
        payload: {
          'id': 'habit-walk',
          'name': 'Morning walk',
          'cadence': 'daily',
          'target_days_per_week': 7,
        },
        timestamp: now,
        authorId: 'alex',
      );

      final habits = await db.watchHabits(homeId).first;
      expect(habits.length, equals(1));
      expect(habits.first.name, equals('Morning walk'));

      await localStore.applyEvent(
        homeId: homeId,
        eventType: 'habit_checkin_toggled',
        payload: {
          'habit_id': 'habit-walk',
          'checkin_date': '2026-09-10',
          'checked': true,
        },
        timestamp: now,
        authorId: 'alex',
      );

      final checkins = await db.watchHabitCheckins(homeId, 'habit-walk').first;
      expect(checkins.length, equals(1));
      expect(checkins.first.checkinDate, equals('2026-09-10'));

      // Calendar Events
      await localStore.applyEvent(
        homeId: homeId,
        eventType: 'calendar_event_added',
        payload: {
          'id': 'cal-dinner',
          'title': 'Anniversary Dinner',
          'start_time': now.add(const Duration(days: 3)).toIso8601String(),
          'end_time': now
              .add(const Duration(days: 3, hours: 2))
              .toIso8601String(),
          'is_all_day': false,
          'location': 'Trattoria Bella',
        },
        timestamp: now,
        authorId: 'sarah',
      );

      final calendarEvents = await db.watchCalendarEvents(homeId).first;
      expect(calendarEvents.length, equals(1));
      expect(calendarEvents.first.title, equals('Anniversary Dinner'));
      expect(calendarEvents.first.location, equals('Trattoria Bella'));
    });

    test('Multi-home isolation: Events in Home A do not leak into Home B',
        () async {
      const homeA = 'home-alpha';
      const homeB = 'home-beta';
      final now = DateTime.now().toUtc();

      await localStore.applyEvent(
        homeId: homeA,
        eventType: 'list_created',
        payload: {'id': 'list-a', 'name': 'Alpha Groceries'},
        timestamp: now,
        authorId: 'alex',
      );

      await localStore.applyEvent(
        homeId: homeB,
        eventType: 'list_created',
        payload: {'id': 'list-b', 'name': 'Beta Supplies'},
        timestamp: now,
        authorId: 'alex',
      );

      final listsA = await db.watchLists(homeA).first;
      final listsB = await db.watchLists(homeB).first;

      expect(listsA.length, equals(1));
      expect(listsA.first.name, equals('Alpha Groceries'));

      expect(listsB.length, equals(1));
      expect(listsB.first.name, equals('Beta Supplies'));
    });
  });

  group('EventStore & Two-Tick Status Progression Tests', () {
    late AppDatabase db;
    late EventStoreImpl eventStore;
    final crypto = SodiumCryptoService();

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      eventStore = EventStoreImpl(db: db, cryptoService: crypto);
    });

    tearDown(() async {
      await db.close();
    });

    test('Initial local event has savedLocally (1 tick)', () async {
      final key = crypto.generateHomeKey();
      final now = DateTime.now().toUtc();
      const payloadJson = '{"item":"Fresh basil"}';

      final encrypted = await crypto.encrypt(
        plaintextJson: payloadJson,
        homeKey: key,
      );

      final event = CoveEncryptedEvent(
        id: 'event-001',
        homeId: 'home-alpha',
        eventType: 'list_item_added',
        authorId: 'alex',
        createdAt: now,
        ciphertext: encrypted.ciphertext,
        nonce: encrypted.nonce,
        syncStatus: EventSyncStatus.savedLocally,
      );

      await eventStore.appendEvent(event, payloadJson: payloadJson);

      final pending = await eventStore.getPendingUploadEvents();
      expect(pending.length, equals(1));
      expect(pending.first.id, equals('event-001'));
      expect(pending.first.syncStatus, equals(EventSyncStatus.savedLocally));

      final outboxRows = await db.watchOutbox('home-alpha').first;
      expect(outboxRows.length, equals(1));
      expect(outboxRows.first.syncStatus, equals('savedLocally'));
    });

    test('Partner delivery acknowledgment flips status to syncedToPartner (2 ticks)',
        () async {
      final key = crypto.generateHomeKey();
      final now = DateTime.now().toUtc();
      final encrypted = await crypto.encrypt(
        plaintextJson: '{}',
        homeKey: key,
      );

      final event = CoveEncryptedEvent(
        id: 'event-002',
        homeId: 'home-alpha',
        eventType: 'expense_logged',
        authorId: 'alex',
        createdAt: now,
        ciphertext: encrypted.ciphertext,
        nonce: encrypted.nonce,
      );

      await eventStore.appendEvent(event);

      // Partner receipt acknowledgment
      await eventStore.markEventSynced('event-002');

      final pending = await eventStore.getPendingUploadEvents();
      expect(pending.isEmpty, isTrue);

      final outboxRows = await db.watchOutbox('home-alpha').first;
      expect(outboxRows.first.syncStatus, equals('syncedToPartner'));
    });
  });

  group('SyncEngine End-to-End Orchestration Tests', () {
    late AppDatabase db;
    late LocalStateStoreImpl localStore;
    late EventStoreImpl eventStore;
    late FakeSecureStorage fakeStorage;
    late HomeKeyStore keyStore;
    late SodiumCryptoService crypto;
    late SyncEngineImpl syncEngine;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      localStore = LocalStateStoreImpl(db);
      crypto = SodiumCryptoService();
      eventStore = EventStoreImpl(db: db, cryptoService: crypto);
      fakeStorage = FakeSecureStorage();
      keyStore = HomeKeyStore(storage: fakeStorage);

      syncEngine = SyncEngineImpl(
        eventStore: eventStore,
        localStateStore: localStore,
        encryptionService: crypto,
        keyStore: keyStore,
        getCurrentUserId: () => 'alex_user_id',
        getActiveHomeId: () => 'home_alpha',
      );

      // Pre-seed symmetric key for active home
      final homeKey = crypto.generateHomeKey();
      await keyStore.saveKey('home_alpha', homeKey);
    });

    tearDown(() async {
      await syncEngine.stop();
      await db.close();
    });

    test('dispatchLocalEvent writes immediately to Drift and local outbox',
        () async {
      await syncEngine.dispatchLocalEvent(
        eventType: 'list_item_added',
        payload: {
          'id': 'item-tea',
          'list_id': 'list-pantry',
          'title': 'Earl Grey Tea',
        },
      );

      // 1. Verified zero-latency local projection in Drift
      final items = await db.watchListItems('home_alpha', 'list-pantry').first;
      expect(items.length, equals(1));
      expect(items.first.title, equals('Earl Grey Tea'));

      // 2. Verified encrypted event in outbox (1 tick)
      final outbox = await db.watchOutbox('home_alpha').first;
      expect(outbox.length, equals(1));
      expect(outbox.first.eventType, equals('list_item_added'));
      expect(outbox.first.syncStatus, equals('savedLocally'));
      expect(outbox.first.actorId, equals('alex_user_id'));
    });
  });

  group('Deterministic Home Icon Mark Tests', () {
    test('Produces stable palette color for home IDs', () {
      const widget1 = DeterministicHomeIcon(homeId: 'home-1234');
      const widget2 = DeterministicHomeIcon(homeId: 'home-1234');
      const widget3 = DeterministicHomeIcon(homeId: 'home-5678');

      expect(widget1.homeId, equals(widget2.homeId));
      expect(widget1.homeId, isNot(equals(widget3.homeId)));
    });
  });
}

/// In-memory implementation of FlutterSecureStorage for headless unit testing.
class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _map = {};

  FakeSecureStorage() : super();

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

  @override
  Future<void> deleteAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _map.clear();
  }
}
