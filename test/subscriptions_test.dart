import 'dart:async';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/subscriptions/subscription_controller.dart';
import 'package:cove/features/subscriptions/subscription_form_sheet.dart';
import 'package:cove/features/subscriptions/subscriptions_screen.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
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

class FakeTrackingSyncEngine extends SyncEngineImpl {
  final List<Map<String, dynamic>> dispatchedEvents = [];

  FakeTrackingSyncEngine({
    required super.eventStore,
    required super.localStateStore,
    required super.encryptionService,
    required super.keyStore,
  });

  @override
  Future<void> start({String? activeHomeId, List<int>? activeHomeKey}) async {}

  @override
  Future<void> flushOutbox() async {}

  @override
  Future<void> dispatchLocalEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    String? homeId,
  }) async {
    dispatchedEvents.add({
      'eventType': eventType,
      'payload': payload,
      'homeId': homeId,
    });
    await localStateStore.applyEvent(
      homeId: homeId ?? 'home_1',
      eventType: eventType,
      payload: payload,
      timestamp: DateTime.now().toUtc(),
      authorId: 'user_alex',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeSecureStorage fakeStorage;
  late HomeKeyStore keyStore;
  late SodiumCryptoService crypto;
  late FakeTrackingSyncEngine fakeEngine;

  const testUser = CoveUser(
    id: 'user_alex',
    email: 'alex@cove.test',
    displayName: 'Alex',
  );

  final partnerUser = const CoveUser(
    id: 'user_sarah',
    email: 'sarah@cove.test',
    displayName: 'Sarah',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fakeStorage = FakeSecureStorage();
    keyStore = HomeKeyStore(storage: fakeStorage);
    crypto = SodiumCryptoService();
    final localStore = LocalStateStoreImpl(db);
    final eventStore = EventStoreImpl(db: db, cryptoService: crypto);
    fakeEngine = FakeTrackingSyncEngine(
      eventStore: eventStore,
      localStateStore: localStore,
      encryptionService: crypto,
      keyStore: keyStore,
    );

    // Seed active home
    await db.into(db.localHomes).insert(
          LocalHomesCompanion.insert(
            id: 'home_1',
            name: 'Our Home',
            createdAt: DateTime.now(),
            createdBy: 'user_alex',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  List<Override> createOverrides({
    CoveUser? user,
    List<LocalSubscription>? initialSubs,
    ValueNotifier<List<LocalSubscription>>? notifier,
  }) {
    final subNotifier = notifier ?? ValueNotifier<List<LocalSubscription>>(initialSubs ?? []);

    Future<void> reload() async {
      final list = await db.getSubscriptions('home_1', currentUserId: (user ?? testUser).id);
      subNotifier.value = list;
    }

    if (initialSubs == null) {
      db.getSubscriptions('home_1', currentUserId: (user ?? testUser).id).then((l) {
        subNotifier.value = l;
      });
    }

    return [
      appDatabaseProvider.overrideWithValue(db),
      homeKeyStoreProvider.overrideWithValue(keyStore),
      sodiumCryptoServiceProvider.overrideWithValue(crypto),
      syncEngineProvider.overrideWithValue(fakeEngine),
      authProvider.overrideWith(() => FakeAuthNotifier(AsyncData(user ?? testUser))),
      activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_1')),
      coveEmitActionProvider.overrideWithValue(
        ({required String eventType, required Map<String, dynamic> payload, String? targetHomeId}) async {
          await fakeEngine.dispatchLocalEvent(
            eventType: eventType,
            payload: payload,
            homeId: targetHomeId ?? 'home_1',
          );
          await reload();
        },
      ),
      subscriptionControllerProvider.overrideWith((ref) {
        return _TestSubscriptionController(ref, onMutate: reload);
      }),
      activeHomeSubscriptionsProvider.overrideWith((ref) {
        final controller = StreamController<List<LocalSubscription>>();
        controller.add(subNotifier.value);
        void listener() {
          if (!controller.isClosed) {
            controller.add(subNotifier.value);
          }
        }
        subNotifier.addListener(listener);
        ref.onDispose(() {
          subNotifier.removeListener(listener);
          controller.close();
        });
        return controller.stream;
      }),
      activeHomeOutboxProvider.overrideWith((ref) => Stream.value([])),
    ];
  }

  group('Subscriptions Feature Tests', () {
    testWidgets('Empty state renders correctly with Add button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SubscriptionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No recurring subscriptions'), findsOneWidget);
      expect(find.text('Add First Subscription'), findsOneWidget);
      expect(find.byType(CovePillButton), findsOneWidget);
    });

    testWidgets('Adding a SHARED subscription emits sync event and updates list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SubscriptionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Add First Subscription
      await tester.tap(find.text('Add First Subscription'));
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionFormSheet), findsOneWidget);

      // Enter Service Name
      final nameField = find.widgetWithText(TextField, '').first;
      await tester.enterText(nameField, 'Spotify Duo');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Enter Amount
      final amountField = find.widgetWithText(TextField, '').last;
      await tester.enterText(amountField, '16.99');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Tap Add Subscription
      final saveBtn = find.widgetWithText(CovePillButton, 'Add Subscription');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // 1. Verify dispatchLocalEvent was triggered with subscription_added
      expect(fakeEngine.dispatchedEvents.length, equals(1));
      expect(fakeEngine.dispatchedEvents.first['eventType'], equals('subscription_added'));
      final payload = fakeEngine.dispatchedEvents.first['payload'] as Map<String, dynamic>;
      expect(payload['name'], equals('Spotify Duo'));
      expect(payload['amount'], equals(16.99));
      expect(payload['is_private'], isFalse);

      // 2. Verify subscription renders in list with Bodoni Moda total
      expect(find.text('Spotify Duo'), findsOneWidget);
      expect(find.text('\$16.99.00'), findsNothing);
      expect(find.text('\$16.99/mo'), findsOneWidget);
      expect(find.text('\$16.99'), findsOneWidget); // Hero total
      expect(find.byType(CoveSyncTick), findsOneWidget);
    });

    testWidgets('STRUCTURAL PRIVACY: Adding a PRIVATE-TO-ME subscription NEVER emits to sync engine',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SubscriptionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Form Sheet
      await tester.tap(find.text('Add First Subscription'));
      await tester.pumpAndSettle();

      // Fill name & amount
      final nameField = find.widgetWithText(TextField, '').first;
      await tester.enterText(nameField, 'Secret Book Club');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      final amountField = find.widgetWithText(TextField, '').last;
      await tester.enterText(amountField, '25.00');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Select "Private to Me"
      final privatePill = find.text('Private to Me');
      await tester.ensureVisible(privatePill);
      await tester.tap(privatePill);
      await tester.pumpAndSettle();

      // Tap Add Subscription
      final saveBtn = find.widgetWithText(CovePillButton, 'Add Subscription');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // CRITICAL ASSERTION:
      // ZERO events dispatched to SyncEngine / outbox!
      expect(fakeEngine.dispatchedEvents.length, equals(0));

      // 1. Appears for the owner Alex with the Private tag
      expect(find.text('Secret Book Club'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      // 2. Default shared hero total remains $0.00 (excluded from shared burn!)
      expect(find.text('\$0.00'), findsOneWidget);
      expect(find.text('0 shared commitments • 1 private'), findsOneWidget);

      // 3. Toggle "Include private" adds it to viewed total
      await tester.tap(find.text('Include private'));
      await tester.pumpAndSettle();
      expect(find.text('\$25.00'), findsOneWidget);
    });

    testWidgets('PARTNER VIEW: Partner NEVER receives or sees private subscription',
        (tester) async {
      // Alex creates a private subscription directly in database
      await db.into(db.localSubscriptions).insert(
            LocalSubscriptionsCompanion.insert(
              id: 'sub_private_alex',
              homeId: 'home_1',
              name: 'Surprise Anniversary Gift Box',
              amount: 50.0,
              currency: const drift.Value('USD'),
              billingCycle: const drift.Value('monthly'),
              nextBillingDate: DateTime.now().add(const Duration(days: 10)),
              isActive: const drift.Value(true),
              isPrivate: const drift.Value(true),
              createdBy: const drift.Value('user_alex'),
              createdAt: DateTime.now(),
            ),
          );

      // Alex also has a shared subscription
      await db.into(db.localSubscriptions).insert(
            LocalSubscriptionsCompanion.insert(
              id: 'sub_shared_wifi',
              homeId: 'home_1',
              name: 'Home Fiber',
              amount: 70.0,
              currency: const drift.Value('USD'),
              billingCycle: const drift.Value('monthly'),
              nextBillingDate: DateTime.now().add(const Duration(days: 5)),
              isActive: const drift.Value(true),
              isPrivate: const drift.Value(false),
              createdBy: const drift.Value('user_alex'),
              createdAt: DateTime.now(),
            ),
          );

      // Now Sarah (partner) views the app
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(user: partnerUser),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SubscriptionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sarah sees the shared fiber internet
      expect(find.text('Home Fiber'), findsOneWidget);
      expect(find.text('\$70.00'), findsOneWidget);

      // STRICT PRIVACY CHECK: Sarah NEVER sees the private subscription!
      expect(find.text('Surprise Anniversary Gift Box'), findsNothing);
      expect(find.text('Private'), findsNothing);
      expect(find.text('1 shared commitments'), findsOneWidget);
    });

    testWidgets('Cancelling a subscription deactivates it without deleting history',
        (tester) async {
      // Seed an active shared subscription
      await db.into(db.localSubscriptions).insert(
            LocalSubscriptionsCompanion.insert(
              id: 'sub_netflix',
              homeId: 'home_1',
              name: 'Netflix',
              amount: 15.0,
              currency: const drift.Value('USD'),
              billingCycle: const drift.Value('monthly'),
              nextBillingDate: DateTime.now().add(const Duration(days: 4)),
              isActive: const drift.Value(true),
              isPrivate: const drift.Value(false),
              createdBy: const drift.Value('user_alex'),
              createdAt: DateTime.now(),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SubscriptionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Netflix'), findsOneWidget);
      expect(find.text('\$15.00'), findsOneWidget);

      // Tap Netflix row to edit
      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();

      // Tap Cancel / Pause Subscription
      final pauseBtn = find.widgetWithText(CovePillButton, 'Cancel / Pause Subscription');
      await tester.ensureVisible(pauseBtn);
      await tester.tap(pauseBtn);
      await tester.pumpAndSettle();

      // 1. Verify sync event was emitted
      expect(
        fakeEngine.dispatchedEvents.any((e) => e['eventType'] == 'subscription_cancelled'),
        isTrue,
      );

      // 2. Verified Netflix is moved to "Paused & Cancelled" section
      expect(find.text('Paused & Cancelled'), findsOneWidget);
      expect(find.text('Paused'), findsOneWidget);

      // 3. Hero total becomes $0.00 since active count is 0
      expect(find.text('\$0.00'), findsOneWidget);
      expect(find.text('0 shared commitments'), findsOneWidget);
    });

    testWidgets('Upcoming renewal (within 7 days) gets highlighted with champagne styling',
        (tester) async {
      // Seed sub renewing in 3 days
      await db.into(db.localSubscriptions).insert(
            LocalSubscriptionsCompanion.insert(
              id: 'sub_soon',
              homeId: 'home_1',
              name: 'Electricity',
              amount: 85.0,
              currency: const drift.Value('USD'),
              billingCycle: const drift.Value('monthly'),
              nextBillingDate: DateTime.now().add(const Duration(days: 3)),
              isActive: const drift.Value(true),
              isPrivate: const drift.Value(false),
              createdBy: const drift.Value('user_alex'),
              createdAt: DateTime.now(),
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SubscriptionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified categorized under "Renewing this week"
      expect(find.text('Renewing this week'), findsOneWidget);
      expect(find.text('Electricity'), findsOneWidget);
    });
  });
}

class FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  final AsyncValue<CoveUser?> initial;

  FakeAuthNotifier(this.initial);

  @override
  AsyncValue<CoveUser?> build() => initial;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void signInWithDemoUser([String name = 'Alex', String email = 'alex@cove.local']) {}

  @override
  Future<void> signOut() async {}
}

class FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  final String? initial;

  FakeActiveHomeNotifier(this.initial);

  @override
  String? build() => initial;

  @override
  void setActiveHome(String homeId) {
    state = homeId;
  }
}

class _TestSubscriptionController extends SubscriptionController {
  final Future<void> Function() onMutate;

  _TestSubscriptionController(super.ref, {required this.onMutate});

  @override
  Future<void> createSubscription({
    required String name,
    required double amount,
    String currency = 'USD',
    String billingCycle = 'monthly',
    required DateTime nextBillingDate,
    String? category,
    bool isPrivate = false,
  }) async {
    await super.createSubscription(
      name: name,
      amount: amount,
      currency: currency,
      billingCycle: billingCycle,
      nextBillingDate: nextBillingDate,
      category: category,
      isPrivate: isPrivate,
    );
    await onMutate();
  }

  @override
  Future<void> updateSubscription({
    required String id,
    required String name,
    required double amount,
    String currency = 'USD',
    String billingCycle = 'monthly',
    required DateTime nextBillingDate,
    String? category,
    required bool isPrivate,
  }) async {
    await super.updateSubscription(
      id: id,
      name: name,
      amount: amount,
      currency: currency,
      billingCycle: billingCycle,
      nextBillingDate: nextBillingDate,
      category: category,
      isPrivate: isPrivate,
    );
    await onMutate();
  }

  @override
  Future<void> cancelSubscription(String id, {required bool isPrivate}) async {
    await super.cancelSubscription(id, isPrivate: isPrivate);
    await onMutate();
  }

  @override
  Future<void> reactivateSubscription(String id, {required bool isPrivate}) async {
    await super.reactivateSubscription(id, isPrivate: isPrivate);
    await onMutate();
  }
}

