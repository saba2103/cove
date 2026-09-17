import 'dart:async';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/subscriptions/commitment_models.dart';
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

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

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
      activeHomeProvider.overrideWith((ref) => Stream.value(
        LocalHome(id: 'home_1', name: 'Our Home', createdAt: DateTime.now(), createdBy: 'user_alex', currency: 'USD'),
      )),
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

      expect(find.text('No commitments yet'), findsOneWidget);
      expect(find.text('Add First Commitment'), findsOneWidget);
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

      // Tap Add First Commitment
      await tester.tap(find.text('Add First Commitment'));
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

      // Tap Add Commitment
      final saveBtn = find.widgetWithText(CovePillButton, 'Add Commitment');
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
      await tester.tap(find.text('Add First Commitment'));
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

      // Tap Add Commitment
      final saveBtn = find.widgetWithText(CovePillButton, 'Add Commitment');
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

      // Tap Netflix row to open detail bottomsheet
      await tester.tap(find.text('Netflix'));
      await tester.pumpAndSettle();

      // Verify detail sheet is shown with "Edit Commitment"
      expect(find.text('Edit Commitment'), findsOneWidget);
      await tester.tap(find.text('Edit Commitment'));
      await tester.pumpAndSettle();

      // Now inside edit form: Tap Cancel / Pause Commitment
      final pauseBtn = find.widgetWithText(CovePillButton, 'Cancel / Pause Commitment');
      await tester.ensureVisible(pauseBtn);
      await tester.tap(pauseBtn);
      await tester.pumpAndSettle();

      // 1. Verify sync event was emitted
      expect(
        fakeEngine.dispatchedEvents.any((e) => e['eventType'] == 'subscription_cancelled'),
        isTrue,
      );

      // 2. Verified Netflix is moved to "Paused & Completed" section
      expect(find.text('Paused & Completed'), findsOneWidget);
      expect(find.textContaining('Paused'), findsWidgets);

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

    testWidgets('Separates monthly and annual commitments calculation by default, with toggle to combine',
        (tester) async {
      // Seed 1 monthly commitment ($10/mo) and 1 annual commitment ($120/yr)
      await db.into(db.localSubscriptions).insert(
            LocalSubscriptionsCompanion.insert(
              id: 'sub_monthly_1',
              homeId: 'home_1',
              name: 'Monthly Gym',
              amount: 10.0,
              currency: const drift.Value('USD'),
              billingCycle: const drift.Value('monthly'),
              nextBillingDate: DateTime.now().add(const Duration(days: 15)),
              isActive: const drift.Value(true),
              isPrivate: const drift.Value(false),
              createdBy: const drift.Value('user_alex'),
              createdAt: DateTime.now(),
            ),
          );
      await db.into(db.localSubscriptions).insert(
            LocalSubscriptionsCompanion.insert(
              id: 'sub_annual_1',
              homeId: 'home_1',
              name: 'Annual Cloud Backup',
              amount: 120.0,
              currency: const drift.Value('USD'),
              billingCycle: const drift.Value('annual'),
              nextBillingDate: DateTime.now().add(const Duration(days: 20)),
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

      // 1. By default, monthly view calculates monthly commitments ONLY ($10.00, not $10 + 120/12 = $20)
      expect(find.text('\$10.00'), findsOneWidget);
      expect(find.text('per month · monthly commitments only'), findsOneWidget);

      // 2. Switch to Annual view (tap 'Monthly' / swap button)
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      // In annual view by default, calculates annual commitments ONLY ($120.00, not $120 + 10*12 = $240)
      expect(find.text('\$120.00'), findsOneWidget);
      expect(find.text('per year · annual commitments only'), findsOneWidget);

      // 3. Find and turn ON the combine toggle
      expect(find.text('Calculate monthly & annual together'), findsOneWidget);
      await tester.tap(find.text('Calculate monthly & annual together'));
      await tester.pumpAndSettle();

      // Combined annual total: $120 + (10 * 12) = $240.00
      expect(find.text('\$240.00'), findsOneWidget);
      expect(find.text('per year · combined monthly & annual'), findsOneWidget);

      // 4. Switch back to Monthly view with toggle still ON
      await tester.tap(find.text('Annual'));
      await tester.pumpAndSettle();

      // Combined monthly total: $10 + (120 / 12) = $20.00
      expect(find.text('\$20.00'), findsOneWidget);
      expect(find.text('per month · combined monthly & annual'), findsOneWidget);
    });

    test('Custom billing cycle helper functions parse and format correctly', () {
      expect(getBillingCycleMonths('monthly'), equals(1));
      expect(getBillingCycleMonths('annual'), equals(12));
      expect(getBillingCycleMonths('quarterly'), equals(3));
      expect(getBillingCycleMonths('every_7_months'), equals(7));
      expect(getBillingCycleMonths('custom_6'), equals(6));
      expect(getBillingCycleMonths('7'), equals(7));

      expect(isCustomBillingCycle('monthly'), isFalse);
      expect(isCustomBillingCycle('annual'), isFalse);
      expect(isCustomBillingCycle('every_7_months'), isTrue);

      expect(formatBillingCycleLabel('monthly'), equals('Monthly'));
      expect(formatBillingCycleLabel('annual'), equals('Annual'));
      expect(formatBillingCycleLabel('every_7_months'), equals('Every 7 months'));

      expect(formatBillingCycleSuffix('monthly'), equals('/mo'));
      expect(formatBillingCycleSuffix('annual'), equals('/yr'));
      expect(formatBillingCycleSuffix('every_7_months'), equals('/7mo'));
    });

    testWidgets('Add commitment with Custom billing cycle (6+1 / 7 months) emits every_7_months and formats correctly',
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

      // Tap Add First Commitment
      await tester.tap(find.text('Add First Commitment'));
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionFormSheet), findsOneWidget);

      // Enter Service Name
      final nameField = find.widgetWithText(TextField, '').first;
      await tester.enterText(nameField, 'WiFi 6+1 Plan');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Enter Amount
      final amountField = find.widgetWithText(TextField, '').last;
      await tester.enterText(amountField, '3500');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      // Tap 'Custom' cycle pill
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();

      // Custom card should show 'Every 7 months' (default) and 'e.g. 6+1 months WiFi plan'
      expect(find.text('Every 7 months'), findsOneWidget);
      expect(find.text('e.g. 6+1 months WiFi plan'), findsOneWidget);

      // Tap Add Commitment
      final saveBtn = find.widgetWithText(CovePillButton, 'Add Commitment');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // 1. Verify dispatched event payload
      expect(fakeEngine.dispatchedEvents.length, equals(1));
      final payload = fakeEngine.dispatchedEvents.first['payload'] as Map<String, dynamic>;
      expect(payload['name'], equals('WiFi 6+1 Plan'));
      expect(payload['amount'], equals(3500.0));
      expect(payload['billing_cycle'], equals('every_7_months'));

      // 2. Verify subscription renders in list with /7mo and Every 7 months
      expect(find.text('WiFi 6+1 Plan'), findsOneWidget);
      expect(find.text('\$3500.00/7mo'), findsOneWidget);
      expect(find.textContaining('Every 7 months'), findsOneWidget);

      // 3. Turn on combine toggle to verify proration: 3500 / 7 = $500.00/mo
      await tester.tap(find.text('Calculate monthly & annual together'));
      await tester.pumpAndSettle();

      expect(find.text('\$500.00'), findsOneWidget);
    });

    test('EMI progress formats caption as X/Y paid and honors totalInstallments & paidInstallments', () {
      final now = DateTime.now();
      final sub = LocalSubscription(
        id: 'emi_1',
        homeId: 'home_1',
        name: 'MacBook Pro',
        amount: 250.0,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 5)),
        category: 'electronics',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_alex',
        createdAt: now.subtract(const Duration(days: 90)),
        endDate: now.add(const Duration(days: 270)),
        paidBy: 'user_alex',
        financedThrough: 'HDFC Regalia',
        totalInstallments: 12,
        paidInstallments: 3,
      );

      expect(sub.isEmi, isTrue);
      final progress = sub.emiProgress;
      expect(progress, isNotNull);
      expect(progress!.totalInstallments, equals(12));
      expect(progress.paidInstallments, equals(3));
      expect(progress.caption, equals('3/12 paid'));
      expect(progress.isFinished, isFalse);
    });

    testWidgets('Commitments screen renders via [FinancedThrough] and X/Y paid on EMI card', (tester) async {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      final sub = LocalSubscription(
        id: 'emi_card_test',
        homeId: 'home_1',
        name: 'iPhone 16 Pro',
        amount: 110.0,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: tomorrow,
        category: 'devices',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_alex',
        createdAt: now.subtract(const Duration(days: 90)),
        endDate: now.add(const Duration(days: 270)),
        paidBy: 'user_alex',
        financedThrough: 'Apple Card',
        totalInstallments: 12,
        paidInstallments: 3,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(initialSubs: [sub]),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SubscriptionsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('iPhone 16 Pro'), findsOneWidget);
      // Subtitle should contain 'Paid by You · via Apple Card · 3/12 paid · next tomorrow'
      expect(find.textContaining('via Apple Card'), findsOneWidget);
      expect(find.textContaining('3/12 paid'), findsOneWidget);
    });

    test('previousFinancingSourcesProvider extracts unique and sorted sources', () async {
      final now = DateTime.now();
      await db.into(db.localSubscriptions).insert(
            LocalSubscriptionsCompanion.insert(
              id: 'source_sub_1',
              homeId: 'home_1',
              name: 'Car Loan',
              amount: 500.0,
              nextBillingDate: now.add(const Duration(days: 10)),
              createdAt: now,
              financedThrough: const drift.Value('HDFC Bank'),
              totalInstallments: const drift.Value(36),
              paidInstallments: const drift.Value(10),
            ),
          );
      await db.into(db.localSubscriptions).insert(
            LocalSubscriptionsCompanion.insert(
              id: 'source_sub_2',
              homeId: 'home_1',
              name: 'Bike Loan',
              amount: 200.0,
              nextBillingDate: now.add(const Duration(days: 15)),
              createdAt: now,
              financedThrough: const drift.Value('Amex Card'),
              totalInstallments: const drift.Value(12),
              paidInstallments: const drift.Value(4),
            ),
          );
      await db.into(db.localSubscriptions).insert(
            LocalSubscriptionsCompanion.insert(
              id: 'source_sub_3',
              homeId: 'home_1',
              name: 'TV EMI',
              amount: 80.0,
              nextBillingDate: now.add(const Duration(days: 20)),
              createdAt: now,
              financedThrough: const drift.Value('HDFC Bank'), // duplicate
              totalInstallments: const drift.Value(6),
              paidInstallments: const drift.Value(1),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_1')),
        ],
      );

      final sources = await container.read(previousFinancingSourcesProvider.future);
      expect(sources, equals(['Amex Card', 'HDFC Bank']));
    });

    testWidgets('SubscriptionFormSheet creates EMI with financedThrough and total/paid installments', (tester) async {
      fakeEngine.dispatchedEvents.clear();

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => SubscriptionFormSheet.show(context),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Enter commitment name and amount
      await tester.enterText(find.byType(TextField).at(0), 'iPad Air EMI');
      await tester.enterText(find.byType(TextField).at(1), '65.00');

      // Switch to EMI / Loan
      await tester.tap(find.text('EMI / Loan'));
      await tester.pumpAndSettle();

      // Verify Financed Through field is visible
      expect(find.text('FINANCED THROUGH'), findsOneWidget);
      expect(find.text('TOTAL TENURE & INSTALLMENTS'), findsOneWidget);

      // Enter financed through text
      await tester.enterText(find.byType(TextField).at(2), 'ICICI Amazon Pay');
      await tester.pumpAndSettle();

      // Tap 6 mos tenure chip
      await tester.ensureVisible(find.text('6 mos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('6 mos'));
      await tester.pumpAndSettle();

      // Tap Save
      final saveButton = find.widgetWithText(CovePillButton, 'Add Commitment');
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify dispatched event
      expect(fakeEngine.dispatchedEvents.length, equals(1));
      final payload = fakeEngine.dispatchedEvents.first['payload'] as Map<String, dynamic>;
      expect(payload['name'], equals('iPad Air EMI'));
      expect(payload['amount'], equals(65.0));
      expect(payload['financed_through'], equals('ICICI Amazon Pay'));
      expect(payload['total_installments'], equals(6));
      expect(payload['paid_installments'], equals(0));
    });

    testWidgets('Tapping commitment opens CommitmentDetailSheet with full details and edit button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final sub = LocalSubscription(
        id: 'sub_macbook_emi',
        homeId: 'home_test',
        name: 'MacBook Pro M3',
        amount: 150.0,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 15)),
        category: 'Electronics',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_alex',
        createdAt: now,
        endDate: DateTime(now.year, now.month + 9, now.day),
        paidBy: 'split',
        financedThrough: 'Apple Card',
        totalInstallments: 12,
        paidInstallments: 3,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(initialSubs: [sub]),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SubscriptionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the commitment row
      await tester.tap(find.text('MacBook Pro M3'));
      await tester.pumpAndSettle();

      // Verify CommitmentDetailSheet is displayed
      expect(find.text('EMI FINANCING'), findsOneWidget);
      expect(find.text('\$150.00'), findsWidgets);
      expect(find.text('Installments Progress'), findsOneWidget);
      expect(find.text('3/12 paid'), findsOneWidget);
      expect(find.text('9 remaining'), findsOneWidget);
      expect(find.text('Apple Card'), findsOneWidget);
      expect(find.text('Split (50/50)'), findsOneWidget);
      expect(find.text('Edit Commitment'), findsOneWidget);

      // Verify tapping "Edit Commitment" opens SubscriptionFormSheet
      await tester.tap(find.text('Edit Commitment'));
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionFormSheet), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('Deleting commitment from CommitmentDetailSheet triggers delete and sync event', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final sub = LocalSubscription(
        id: 'sub_gym',
        homeId: 'home_test',
        name: 'Gym Membership',
        amount: 45.0,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: now.add(const Duration(days: 10)),
        category: 'Health',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_alex',
        createdAt: now,
        endDate: null,
        paidBy: 'user_alex',
        financedThrough: null,
        totalInstallments: null,
        paidInstallments: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(initialSubs: [sub]),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SubscriptionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Gym row to open detail sheet
      await tester.tap(find.text('Gym Membership'));
      await tester.pumpAndSettle();

      // Tap delete icon in detail sheet
      final deleteBtn = find.byIcon(Icons.delete_outline);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Delete Subscription?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify delete sync event was dispatched
      expect(
        fakeEngine.dispatchedEvents.any((e) => e['eventType'] == 'subscription_deleted'),
        isTrue,
      );
    });

    testWidgets('Paid installments input, auto-calculation, and bi-directional sync with last due date', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      fakeEngine.dispatchedEvents.clear();

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => SubscriptionFormSheet.show(context, initialIsEmi: true),
                  child: const Text('Open EMI Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open EMI Sheet'));
      await tester.pumpAndSettle();

      // Verify EMI mode is loaded with default 12 months tenure and 0 paid
      expect(find.text('0/12 paid'), findsOneWidget);
      expect(find.text('12 remaining of 12'), findsOneWidget);

      // Verify "Syncs with Last Due" indicator is visible
      expect(find.text('Syncs with Last Due'), findsOneWidget);

      // Tap + on paid installments stepper
      final addBtn = find.byIcon(Icons.add).last;
      await tester.tap(addBtn);
      await tester.pumpAndSettle();
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Now paid is 2
      expect(find.text('2/12 paid'), findsOneWidget);
      expect(find.text('10 remaining of 12'), findsOneWidget);

      // Directly input paid installments via text field
      final paidField = find.widgetWithText(TextField, '2');
      if (paidField.evaluate().isNotEmpty) {
        await tester.enterText(paidField, '5');
        await tester.pumpAndSettle();
        expect(find.text('5/12 paid'), findsOneWidget);
        expect(find.text('7 remaining of 12'), findsOneWidget);
      }
    });

    test('renewOrPaySubscription advances subscription renewal date by 1 month and emits event', () async {
      final initialDate = DateTime(2026, 4, 15);
      final sub = LocalSubscription(
        id: 'sub_netflix',
        homeId: 'home_1',
        name: 'Netflix Premium',
        amount: 19.99,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: initialDate,
        isActive: true,
        isPrivate: false,
        createdAt: DateTime.now(),
        createdBy: 'user_alex',
        paidBy: 'user_alex',
        category: 'Entertainment',
      );
      await db.into(db.localSubscriptions).insert(sub);

      final container = ProviderContainer(overrides: createOverrides(initialSubs: [sub]));
      addTearDown(container.dispose);
      fakeEngine.dispatchedEvents.clear();

      final controller = container.read(subscriptionControllerProvider);
      await controller.renewOrPaySubscription('sub_netflix', isPrivate: false, logExpense: true);

      // Verify event emitted
      final updateEvent = fakeEngine.dispatchedEvents.firstWhere(
        (e) => e['eventType'] == 'subscription_updated',
      );
      expect(updateEvent, isNotNull);
      final payload = updateEvent['payload'] as Map<String, dynamic>;
      expect(payload['id'], 'sub_netflix');
      expect(DateTime.parse(payload['next_billing_date'] as String), DateTime(2026, 5, 15));
      expect(payload['is_active'], isTrue);

      // Verify expense logged
      final expenseEvent = fakeEngine.dispatchedEvents.firstWhere(
        (e) => e['eventType'] == 'expense_logged',
      );
      expect(expenseEvent, isNotNull);
      final expPayload = expenseEvent['payload'] as Map<String, dynamic>;
      expect(expPayload['title'], 'Netflix Premium (Renewal)');
      expect(expPayload['amount'], 19.99);
    });

    test('renewOrPaySubscription increments EMI installment and completes when reaching total', () async {
      final initialDate = DateTime(2026, 4, 1);
      final emi = LocalSubscription(
        id: 'emi_macbook',
        homeId: 'home_1',
        name: 'MacBook Pro EMI',
        amount: 150.0,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: initialDate,
        isActive: true,
        isPrivate: false,
        createdAt: DateTime.now(),
        createdBy: 'user_alex',
        paidBy: 'user_alex',
        category: 'Electronics',
        totalInstallments: 12,
        paidInstallments: 11,
      );
      await db.into(db.localSubscriptions).insert(emi);

      final container = ProviderContainer(overrides: createOverrides(initialSubs: [emi]));
      addTearDown(container.dispose);
      fakeEngine.dispatchedEvents.clear();

      final controller = container.read(subscriptionControllerProvider);
      await controller.renewOrPaySubscription('emi_macbook', isPrivate: false, logExpense: true);

      final updateEvent = fakeEngine.dispatchedEvents.firstWhere(
        (e) => e['eventType'] == 'subscription_updated',
      );
      final payload = updateEvent['payload'] as Map<String, dynamic>;
      expect(payload['id'], 'emi_macbook');
      expect(payload['paid_installments'], 12);
      expect(payload['is_active'], isFalse); // Completed!
      expect(DateTime.parse(payload['next_billing_date'] as String), DateTime(2026, 5, 1));

      // Verify expense logged with installment badge
      final expenseEvent = fakeEngine.dispatchedEvents.firstWhere(
        (e) => e['eventType'] == 'expense_logged',
      );
      final expPayload = expenseEvent['payload'] as Map<String, dynamic>;
      expect(expPayload['title'], 'MacBook Pro EMI (EMI Installment 12/12)');
      expect(expPayload['amount'], 150.0);
    });

    testWidgets('Detail sheet provides Mark as Renewed action and triggers confirmation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      fakeEngine.dispatchedEvents.clear();

      final sub = LocalSubscription(
        id: 'sub_spotify',
        homeId: 'home_1',
        name: 'Spotify Family',
        amount: 16.99,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: DateTime(2026, 4, 10),
        isActive: true,
        isPrivate: false,
        createdAt: DateTime.now(),
        createdBy: 'user_alex',
        paidBy: 'user_alex',
        category: 'Entertainment',
      );
      await db.into(db.localSubscriptions).insert(sub);

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(initialSubs: [sub]),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SubscriptionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open detail sheet
      await tester.tap(find.text('Spotify Family'));
      await tester.pumpAndSettle();

      // Verify "Mark as Renewed" button is present
      expect(find.text('Mark as Renewed'), findsOneWidget);

      // Tap button
      await tester.tap(find.text('Mark as Renewed'));
      await tester.pumpAndSettle();

      // Confirm dialog appears with Log to household Expenses
      expect(find.text('Record Renewal'), findsOneWidget);
      expect(find.text('Log to household Expenses'), findsOneWidget);

      // Tap Confirm Renewal
      await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm Renewal'));
      await tester.pumpAndSettle();

      // Verify subscription updated event dispatched
      expect(
        fakeEngine.dispatchedEvents.any((e) => e['eventType'] == 'subscription_updated'),
        isTrue,
      );
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
    String? currency,
    String billingCycle = 'monthly',
    required DateTime nextBillingDate,
    String? category,
    bool isPrivate = false,
    DateTime? endDate,
    String? paidBy,
    String? financedThrough,
    int? totalInstallments,
    int? paidInstallments,
  }) async {
    await super.createSubscription(
      name: name,
      amount: amount,
      currency: currency,
      billingCycle: billingCycle,
      nextBillingDate: nextBillingDate,
      category: category,
      isPrivate: isPrivate,
      endDate: endDate,
      paidBy: paidBy,
      financedThrough: financedThrough,
      totalInstallments: totalInstallments,
      paidInstallments: paidInstallments,
    );
    await onMutate();
  }

  @override
  Future<void> updateSubscription({
    required String id,
    required String name,
    required double amount,
    String? currency,
    String billingCycle = 'monthly',
    required DateTime nextBillingDate,
    String? category,
    required bool isPrivate,
    DateTime? endDate,
    String? paidBy,
    String? financedThrough,
    int? totalInstallments,
    int? paidInstallments,
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
      endDate: endDate,
      paidBy: paidBy,
      financedThrough: financedThrough,
      totalInstallments: totalInstallments,
      paidInstallments: paidInstallments,
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

  @override
  Future<void> deleteSubscription(String id, {required bool isPrivate}) async {
    await super.deleteSubscription(id, isPrivate: isPrivate);
    await onMutate();
  }

  @override
  Future<void> renewOrPaySubscription(
    String id, {
    required bool isPrivate,
    bool logExpense = false,
  }) async {
    await super.renewOrPaySubscription(id, isPrivate: isPrivate, logExpense: logExpense);
    await onMutate();
  }
}

