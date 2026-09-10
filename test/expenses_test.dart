import 'dart:async';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_grouped_list.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/expenses/expense_form_sheet.dart';
import 'package:cove/features/expenses/expenses_screen.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/drift.dart';
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

  const partnerUser = CoveUser(
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
    ValueNotifier<List<LocalExpense>>? expensesNotifier,
  }) {
    final effectiveExpensesNotifier = expensesNotifier ?? ValueNotifier<List<LocalExpense>>([]);
    final effectiveUser = user ?? testUser;

    Future<void> reload() async {
      final expenses = await db.getExpenses('home_1', currentUserId: effectiveUser.id);
      effectiveExpensesNotifier.value = expenses;
    }

    db.getExpenses('home_1', currentUserId: effectiveUser.id).then((expenses) {
      effectiveExpensesNotifier.value = expenses;
    });

    return [
      appDatabaseProvider.overrideWithValue(db),
      homeKeyStoreProvider.overrideWithValue(keyStore),
      sodiumCryptoServiceProvider.overrideWithValue(crypto),
      syncEngineProvider.overrideWithValue(fakeEngine),
      authProvider.overrideWith(() => FakeAuthNotifier(AsyncData(effectiveUser))),
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
      expenseControllerProvider.overrideWith((ref) => _TestExpenseController(ref, onMutate: reload)),
      activeHomeExpensesProvider.overrideWith((ref) {
        final controller = StreamController<List<LocalExpense>>();
        controller.add(effectiveExpensesNotifier.value);
        void listener() {
          if (!controller.isClosed) {
            controller.add(effectiveExpensesNotifier.value);
          }
        }
        effectiveExpensesNotifier.addListener(listener);
        ref.onDispose(() {
          effectiveExpensesNotifier.removeListener(listener);
          controller.close();
        });
        return controller.stream;
      }),
      activeHomeOutboxProvider.overrideWith((ref) => Stream.value([])),
    ];
  }

  group('Expenses Feature Tests', () {
    testWidgets('Empty state renders correctly with Log First Expense button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ExpensesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No expenses recorded yet'), findsOneWidget);
      expect(find.text('Log First Expense'), findsOneWidget);
      expect(find.byType(CovePillButton), findsOneWidget);
    });

    testWidgets('Logging a SHARED expense emits sync event and updates list & monthly total',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ExpensesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open bottom sheet
      await tester.tap(find.text('Log First Expense'));
      await tester.pumpAndSettle();

      expect(find.byType(ExpenseFormSheet), findsOneWidget);

      // Enter merchant title
      final textFields = find.descendant(
        of: find.byType(ExpenseFormSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(textFields.at(0), 'Farmers Market Produce');
      await tester.pump();

      // Enter amount
      await tester.enterText(textFields.at(1), '42.50');
      await tester.pump();

      // Tap Log Expense
      final logBtn = find.widgetWithText(CovePillButton, 'Log Expense');
      await tester.ensureVisible(logBtn);
      await tester.tap(logBtn);
      await tester.pumpAndSettle();

      // 1. Verify dispatchLocalEvent was called with expense_logged
      expect(fakeEngine.dispatchedEvents.length, equals(1));
      expect(fakeEngine.dispatchedEvents.first['eventType'], equals('expense_logged'));
      final payload = fakeEngine.dispatchedEvents.first['payload'] as Map<String, dynamic>;
      expect(payload['title'], equals('Farmers Market Produce'));
      expect(payload['amount'], equals(42.50));
      expect(payload['visibility'], equals('shared'));
      expect(payload['split_ratio'], equals(0.5));

      // 2. Verify hero total & row in ExpensesScreen
      expect(find.text('Farmers Market Produce'), findsOneWidget);
      expect(find.text('\$42.50'), findsWidgets);
      expect(find.byType(CoveSyncTick), findsOneWidget);
    });

    testWidgets('Logging a PARTNER-CAN-SEE expense emits sync event with visibility metadata',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ExpensesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log First Expense'));
      await tester.pumpAndSettle();

      final textFields = find.descendant(
        of: find.byType(ExpenseFormSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(textFields.at(0), 'Vintage Acoustic Guitar');
      await tester.pump();

      await tester.enterText(textFields.at(1), '350.00');
      await tester.pump();

      // Select Partner-can-see visibility
      await tester.tap(find.text('Partner sees'));
      await tester.pump();

      // Submit
      final logBtn = find.widgetWithText(CovePillButton, 'Log Expense');
      await tester.ensureVisible(logBtn);
      await tester.tap(logBtn);
      await tester.pumpAndSettle();

      // Verify emitted event
      expect(fakeEngine.dispatchedEvents.length, equals(1));
      final payload = fakeEngine.dispatchedEvents.first['payload'] as Map<String, dynamic>;
      expect(payload['visibility'], equals('partner_can_see'));
      expect(payload['split_ratio'], equals(0.0)); // 0.0 means unshared personal

      // In the UI, it displays "Partner sees" tag, and shared monthly total remains $0.00
      expect(find.text('Vintage Acoustic Guitar'), findsOneWidget);
      expect(find.text('Partner sees'), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget); // Shared pool total excludes partner_can_see
    });

    testWidgets('STRUCTURAL PRIVACY: Logging a PRIVATE-TO-ME expense NEVER emits to sync engine',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ExpensesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log First Expense'));
      await tester.pumpAndSettle();

      final textFields = find.descendant(
        of: find.byType(ExpenseFormSheet),
        matching: find.byType(TextField),
      );
      await tester.enterText(textFields.at(0), 'Secret Anniversary Gift');
      await tester.pump();

      await tester.enterText(textFields.at(1), '120.00');
      await tester.pump();

      // Select Private to me
      await tester.tap(find.text('Private'));
      await tester.pump();

      // Submit
      final logBtn = find.widgetWithText(CovePillButton, 'Log Expense');
      await tester.ensureVisible(logBtn);
      await tester.tap(logBtn);
      await tester.pumpAndSettle();

      // ZERO events emitted to sync engine!
      expect(fakeEngine.dispatchedEvents.isEmpty, isTrue);

      // Rendered locally for Alex with "Private" tag
      expect(find.text('Secret Anniversary Gift'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget); // Excluded from shared total
    });

    testWidgets('PARTNER VIEW: Partner NEVER receives or sees private expense', (tester) async {
      // Alex creates a private expense directly in SQLite
      await db.into(db.localExpenses).insert(
            LocalExpensesCompanion.insert(
              id: 'exp_private_1',
              homeId: 'home_1',
              title: 'Alex Secret Ring Purchase',
              amount: 850.00,
              paidBy: 'user_alex',
              splitRatio: const Value(-1.0), // private to Alex
              expenseDate: DateTime.now(),
              createdAt: DateTime.now(),
            ),
          );

      // Alex also has a shared expense
      await db.into(db.localExpenses).insert(
            LocalExpensesCompanion.insert(
              id: 'exp_shared_1',
              homeId: 'home_1',
              title: 'Weekly Groceries',
              amount: 65.00,
              paidBy: 'user_alex',
              splitRatio: const Value(0.5),
              expenseDate: DateTime.now(),
              createdAt: DateTime.now(),
            ),
          );

      // Sarah (partner) opens Cove
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(user: partnerUser),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ExpensesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sarah sees Weekly Groceries
      expect(find.text('Weekly Groceries'), findsOneWidget);
      expect(find.text('\$65.00'), findsWidgets);

      // Sarah NEVER sees the private expense
      expect(find.text('Alex Secret Ring Purchase'), findsNothing);
      expect(find.text('\$850.00'), findsNothing);
    });

    testWidgets('Category breakdown list aggregates current month spend without charts',
        (tester) async {
      final now = DateTime.now();
      // Insert multiple expenses across categories
      await db.into(db.localExpenses).insert(
            LocalExpensesCompanion.insert(
              id: 'exp_cat_1',
              homeId: 'home_1',
              title: 'Whole Foods Market',
              amount: 150.00,
              paidBy: 'user_alex',
              splitRatio: const Value(0.5),
              category: const Value('Groceries'),
              expenseDate: now,
              createdAt: now,
            ),
          );

      await db.into(db.localExpenses).insert(
            LocalExpensesCompanion.insert(
              id: 'exp_cat_2',
              homeId: 'home_1',
              title: 'Trader Joes',
              amount: 50.00,
              paidBy: 'user_alex',
              splitRatio: const Value(0.5),
              category: const Value('Groceries'),
              expenseDate: now,
              createdAt: now,
            ),
          );

      await db.into(db.localExpenses).insert(
            LocalExpensesCompanion.insert(
              id: 'exp_cat_3',
              homeId: 'home_1',
              title: 'Electric & Gas Bill',
              amount: 80.00,
              paidBy: 'user_alex',
              splitRatio: const Value(0.5),
              category: const Value('Home & Utilities'),
              expenseDate: now,
              createdAt: now,
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ExpensesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Category breakdown section is present
      expect(find.text('CATEGORY BREAKDOWN'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('\$200.00'), findsOneWidget); // 150 + 50 in category breakdown
      expect(find.text('Home & Utilities'), findsOneWidget);
      expect(find.text('\$80.00'), findsWidgets);

      // Verify plain list structure using CoveGroupedRow
      expect(find.byType(CoveGroupedRow), findsWidgets);
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

class _TestExpenseController extends ExpenseController {
  final Future<void> Function() onMutate;

  _TestExpenseController(super.ref, {required this.onMutate});

  @override
  Future<String> logExpense({
    required String title,
    required double amount,
    String currency = 'USD',
    DateTime? expenseDate,
    required String paidBy,
    String? category,
    String? notes,
    ExpenseVisibility visibility = ExpenseVisibility.shared,
  }) async {
    final res = await super.logExpense(
      title: title,
      amount: amount,
      currency: currency,
      expenseDate: expenseDate,
      paidBy: paidBy,
      category: category,
      notes: notes,
      visibility: visibility,
    );
    await onMutate();
    return res;
  }

  @override
  Future<void> deleteExpense(String id, {required ExpenseVisibility visibility}) async {
    await super.deleteExpense(id, visibility: visibility);
    await onMutate();
  }
}
