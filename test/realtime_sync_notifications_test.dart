import 'dart:convert';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:cove/features/notifications/notification_service.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/encryption_service.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocalStateStoreImpl localStateStore;
  late EventStoreImpl eventStore;
  late SodiumCryptoService cryptoService;
  late HomeKeyStore keyStore;
  late SyncEngineImpl syncEngine;
  late NotificationService notificationService;

  const testHomeId = 'home-realtime-test-123';
  const myUserId = 'user-local-me';
  const partnerUserId = 'user-partner-you';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    localStateStore = LocalStateStoreImpl(db);
    cryptoService = SodiumCryptoService();
    eventStore = EventStoreImpl(db: db, cryptoService: cryptoService);
    keyStore = HomeKeyStore(storage: FakeSecureStorage());

    // Generate and store symmetric key for the test home
    final homeKey = cryptoService.generateHomeKey();
    await keyStore.saveKey(testHomeId, homeKey);

    syncEngine = SyncEngineImpl(
      eventStore: eventStore,
      localStateStore: localStateStore,
      encryptionService: cryptoService,
      keyStore: keyStore,
      getCurrentUserId: () => myUserId,
      getActiveHomeId: () => testHomeId,
    );

    notificationService = NotificationService(
      syncEngine: syncEngine,
      appDatabase: db,
      getCurrentUserId: () => myUserId,
    );

    // Wire sync engine callback to notification service
    syncEngine.onInboundActivityReceived = (payload) {
      notificationService.handleIncomingMessage(payload.toMap());
    };

    await syncEngine.start(
      activeHomeId: testHomeId,
      activeHomeKey: homeKey,
    );
  });

  tearDown(() async {
    await syncEngine.stop();
    notificationService.dispose();
    await db.close();
  });

  group('Realtime Sync & Inbound Activity Notifications', () {
    test('Inbound partner expense event updates local database and triggers notification', () async {
      final homeKey = (await keyStore.getKey(testHomeId))!;
      final expensePayload = {
        'id': 'exp-realtime-1',
        'title': 'Dinner Groceries',
        'amount': 450.0,
        'paid_by': partnerUserId,
        'split': 'equal',
        'date': DateTime.now().toIso8601String(),
        'is_shared': true,
      };

      final encrypted = await cryptoService.encrypt(
        plaintextJson: jsonEncode(expensePayload),
        homeKey: homeKey,
      );

      final transportPayload = cryptoService.serializeToTransportString(
        EncryptedPayload(ciphertext: encrypted.ciphertext, nonce: encrypted.nonce),
      );

      final inboundRecord = {
        'id': 'event-exp-001',
        'home_id': testHomeId,
        'actor_id': partnerUserId,
        'event_type': 'expense_logged',
        'encrypted_payload': transportPayload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      CoveNotificationPayload? receivedNotif;
      final sub = notificationService.onNotificationReceived.listen((n) {
        receivedNotif = n;
      });

      // Invoke inbound event handler directly
      await syncEngine.handleInboundEvent(inboundRecord);

      await Future.delayed(const Duration(milliseconds: 50));

      // Verify the expense was applied to SQLite
      final expenses = await db.watchExpenses(testHomeId).first;
      expect(expenses.any((e) => e.id == 'exp-realtime-1'), isTrue);

      // Verify notification was emitted with rich details
      expect(receivedNotif, isNotNull);
      expect(receivedNotif!.module, equals(NotificationModule.expenses));
      expect(receivedNotif!.eventType, equals('expense_logged'));
      expect(receivedNotif!.title, contains('Expenses'));
      expect(receivedNotif!.body, contains('Dinner Groceries'));
      expect(receivedNotif!.body, contains('450.00'));

      await sub.cancel();
    });

    test('Duplicate inbound event is processed only once (deduplication)', () async {
      final homeKey = (await keyStore.getKey(testHomeId))!;
      final habitPayload = {
        'id': 'habit-realtime-1',
        'title': 'Morning Run',
        'schedule_type': 'daily',
        'is_shared': true,
      };

      final encrypted = await cryptoService.encrypt(
        plaintextJson: jsonEncode(habitPayload),
        homeKey: homeKey,
      );

      final transportPayload = cryptoService.serializeToTransportString(
        EncryptedPayload(ciphertext: encrypted.ciphertext, nonce: encrypted.nonce),
      );

      final inboundRecord = {
        'id': 'event-habit-dup-001',
        'home_id': testHomeId,
        'actor_id': partnerUserId,
        'event_type': 'habit_created',
        'encrypted_payload': transportPayload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      int notifCount = 0;
      final sub = notificationService.onNotificationReceived.listen((_) {
        notifCount++;
      });

      // First delivery (e.g. from WebSocket broadcast)
      await syncEngine.handleInboundEvent(inboundRecord);
      // Second duplicate delivery (e.g. from Postgres CDC or periodic poller)
      await syncEngine.handleInboundEvent(inboundRecord);

      await Future.delayed(const Duration(milliseconds: 50));

      // Notification count should strictly be 1
      expect(notifCount, equals(1));

      await sub.cancel();
    });

    test('Self-authored events are ignored and never trigger inbound notification', () async {
      final homeKey = (await keyStore.getKey(testHomeId))!;
      final encrypted = await cryptoService.encrypt(
        plaintextJson: jsonEncode({'title': 'My own item'}),
        homeKey: homeKey,
      );

      final transportPayload = cryptoService.serializeToTransportString(
        EncryptedPayload(ciphertext: encrypted.ciphertext, nonce: encrypted.nonce),
      );

      final selfRecord = {
        'id': 'event-self-001',
        'home_id': testHomeId,
        'actor_id': myUserId, // Self
        'event_type': 'list_item_added',
        'encrypted_payload': transportPayload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      bool notifReceived = false;
      final sub = notificationService.onNotificationReceived.listen((_) {
        notifReceived = true;
      });

      await syncEngine.handleInboundEvent(selfRecord);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(notifReceived, isFalse);
      await sub.cancel();
    });

    test('Muted module in local preferences suppresses notification banner', () async {
      // Mute expenses locally
      await db.saveNotificationPreferences(
        muteSubscriptions: false,
        muteLists: false,
        muteExpenses: true,
        muteHabits: false,
        muteCalendar: false,
      );

      final homeKey = (await keyStore.getKey(testHomeId))!;
      final encrypted = await cryptoService.encrypt(
        plaintextJson: jsonEncode({
          'id': 'exp-muted-1',
          'title': 'Coffee',
          'amount': 50.0,
          'paid_by': partnerUserId,
          'split': 'equal',
          'date': DateTime.now().toUtc().toIso8601String(),
          'is_shared': true,
        }),
        homeKey: homeKey,
      );

      final transportPayload = cryptoService.serializeToTransportString(
        EncryptedPayload(ciphertext: encrypted.ciphertext, nonce: encrypted.nonce),
      );

      final inboundRecord = {
        'id': 'event-exp-muted-001',
        'home_id': testHomeId,
        'actor_id': partnerUserId,
        'event_type': 'expense_logged',
        'encrypted_payload': transportPayload,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      bool notifReceived = false;
      final sub = notificationService.onNotificationReceived.listen((_) {
        notifReceived = true;
      });

      await syncEngine.handleInboundEvent(inboundRecord);
      await Future.delayed(const Duration(milliseconds: 50));

      // Notification is muted, so banner is suppressed
      expect(notifReceived, isFalse);

      // BUT SQLite database was still updated in background (silent sync)
      final expenses = await db.watchExpenses(testHomeId).first;
      expect(expenses.any((e) => e.id == 'exp-muted-1'), isTrue);

      await sub.cancel();
    });
  });
}
