import 'dart:async';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_grouped_list.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/expenses/expense_form_sheet.dart';
import 'package:cove/features/expenses/expenses_screen.dart';
import 'package:cove/features/expenses/monthly_budget_controller.dart';
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
    MonthlyBudgetNotifier.storage = fakeStorage;
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

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
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

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
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

      await tester.enterText(textFields.at(1), '450.00');
      await tester.pump();

      // Tap 'Partner sees' pill
      await tester.ensureVisible(find.text('Partner sees'));
      await tester.tap(find.text('Partner sees'));
      await tester.pumpAndSettle();

      // Tap Log Expense
      final logBtn = find.widgetWithText(CovePillButton, 'Log Expense');
      await tester.ensureVisible(logBtn);
      await tester.tap(logBtn);
      await tester.pumpAndSettle();

      // Verify event was emitted with split_ratio = 0.0 and visibility = partner_can_see
      expect(fakeEngine.dispatchedEvents.length, equals(1));
      final payload = fakeEngine.dispatchedEvents.first['payload'] as Map<String, dynamic>;
      expect(payload['visibility'], equals('partner_can_see'));
      expect(payload['split_ratio'], equals(0.0));

      // In the UI, it displays "Partner sees" tag, and shared monthly total remains $0.00
      expect(find.text('Vintage Acoustic Guitar'), findsOneWidget);
      expect(find.text('Partner sees'), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget); // Shared pool total excludes partner_can_see

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
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
      await tester.ensureVisible(find.text('Private'));
      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();

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

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
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

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
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
      expect(find.text('Groceries'), findsWidgets);
      expect(find.text('\$200.00'), findsOneWidget); // 150 + 50 in category breakdown
      expect(find.text('Home & Utilities'), findsWidgets);
      expect(find.text('\$80.00'), findsWidgets);

      // Verify plain list structure using CoveGroupedRow
      expect(find.byType(CoveGroupedRow), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Transfer logging and UI separation test', (tester) async {
      final now = DateTime.now();

      // Insert 1 normal expense ($100) and 1 transfer ($250)
      await db.into(db.localExpenses).insert(
            LocalExpensesCompanion.insert(
              id: 'exp_regular_1',
              homeId: 'home_1',
              title: 'Dinner at Italian Place',
              amount: 100.00,
              paidBy: 'user_alex',
              splitRatio: const Value(0.5),
              category: const Value('Dining Out'),
              expenseDate: now,
              createdAt: now,
              isTransfer: const Value(false),
            ),
          );

      await db.into(db.localExpenses).insert(
            LocalExpensesCompanion.insert(
              id: 'exp_transfer_1',
              homeId: 'home_1',
              title: 'Rent Share Reimbursement',
              amount: 250.00,
              paidBy: 'user_alex',
              splitRatio: const Value(0.5),
              category: const Value('Transfer'),
              expenseDate: now,
              createdAt: now,
              isTransfer: const Value(true),
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

      // Verify that by default, the combined total ($350.00) is NOT shown anywhere
      expect(find.text('\$350.00'), findsNothing);
      // Expenditure amount appears in hero card, category, and ledger
      expect(find.text('\$100.00'), findsWidgets);
      // Transfer amount appears only once (in ledger row, not hero card yet)
      expect(find.text('\$250.00'), findsOneWidget);

      // Verify that Category Breakdown has Dining Out ($100.00)
      expect(find.text('Dining Out'), findsWidgets);

      // Both transactions appear in the ledger
      expect(find.text('Dinner at Italian Place'), findsOneWidget);
      expect(find.text('Rent Share Reimbursement'), findsOneWidget);

      // The transfer row has the Transfer badge and directional subtitle
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.textContaining('transferred to'), findsOneWidget);

      // Now tap the Transfers segmented switcher on the hero card
      await tester.tap(find.text('Transfers').first);
      await tester.pumpAndSettle();

      // Now the hero card also displays the transfer total ($250.00) alongside the ledger row (2 occurrences)
      expect(find.text('\$250.00'), findsNWidgets(2));

      // Verify controller logging a transfer directly
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ExpensesScreen)),
      );
      final controller = container.read(expenseControllerProvider);
      final newTransferId = await controller.logExpense(
        title: 'UPI to Partner',
        amount: 75.00,
        paidBy: 'user_alex',
        isTransfer: true,
      );

      expect(newTransferId, isNotEmpty);
      final inserted = await (db.select(db.localExpenses)..where((t) => t.id.equals(newTransferId))).getSingle();
      expect(inserted.isTransfer, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Monthly budget shows Set target prompt, opens sheet, sets budget, and tracks remaining amount', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      fakeEngine.dispatchedEvents.clear();

      // Seed an expense of $400
      final now = DateTime.now();
      await db.into(db.localExpenses).insert(
            LocalExpensesCompanion.insert(
              id: 'exp_groceries',
              homeId: 'home_1',
              title: 'Whole Foods Market',
              amount: 400.0,
              paidBy: 'user_alex',
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

      // 1. Initial state: "Set monthly budget target" prompt is visible
      expect(find.text('Set monthly budget target'), findsOneWidget);

      // 2. Tap prompt to open MonthlyBudgetSheet
      await tester.tap(find.text('Set monthly budget target'));
      await tester.pumpAndSettle();

      expect(find.text('Set Monthly Budget'), findsOneWidget);
      expect(find.text('Save Budget'), findsOneWidget);

      // Enter 1000 into budget text field
      final inputField = find.byType(TextField);
      await tester.enterText(inputField, '1000');
      await tester.pumpAndSettle();

      // Tap Save Budget
      await tester.tap(find.widgetWithText(CovePillButton, 'Save Budget'));
      await tester.pumpAndSettle();

      // 3. Verify budget card appears with $600.00 remaining of $1,000.00
      expect(find.text('MONTHLY BUDGET'), findsOneWidget);
      expect(find.text('\$600.00 remaining'), findsOneWidget);
      expect(find.text('\$400.00 spent'), findsOneWidget);
      expect(find.text('Target: \$1,000.00 (40%)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Monthly budget triggers SHOT UP · OVER BUDGET warning when spend exceeds budget', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      fakeEngine.dispatchedEvents.clear();

      // Seed an expense of $1250
      final now = DateTime.now();
      await db.into(db.localExpenses).insert(
            LocalExpensesCompanion.insert(
              id: 'exp_rent',
              homeId: 'home_1',
              title: 'Apartment Rent',
              amount: 1250.0,
              paidBy: 'user_alex',
              expenseDate: now,
              createdAt: now,
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...createOverrides(),
            monthlyBudgetProvider.overrideWith(() => _TestMonthlyBudgetNotifier(1000.0)),
          ],
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ExpensesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "SHOT UP · OVER BUDGET" alert banner and overshoot amount
      expect(find.text('SHOT UP · OVER BUDGET'), findsOneWidget);
      expect(find.text('Shot up by \$250.00'), findsOneWidget);
      expect(find.text('\$1,250.00 spent'), findsOneWidget);
      expect(find.text('Target: \$1,000.00 (100%)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    test('Monthly budget syncs across devices via monthly_budget_updated event', () async {
      fakeEngine.dispatchedEvents.clear();
      await fakeEngine.localStateStore.applyEvent(
        homeId: 'home_1',
        eventType: 'monthly_budget_updated',
        payload: {
          'home_id': 'home_1',
          'amount': 2500.0,
        },
        timestamp: DateTime.now().toUtc(),
        authorId: 'user_sarah',
      );

      final val = await fakeStorage.read(key: 'cove_monthly_budget_home_1');
      expect(val, equals('2500.0'));

      // Clear budget
      await fakeEngine.localStateStore.applyEvent(
        homeId: 'home_1',
        eventType: 'monthly_budget_cleared',
        payload: {
          'home_id': 'home_1',
        },
        timestamp: DateTime.now().toUtc(),
        authorId: 'user_sarah',
      );

      final clearedVal = await fakeStorage.read(key: 'cove_monthly_budget_home_1');
      expect(clearedVal == null, isTrue);
    });
  });
}

class _TestMonthlyBudgetNotifier extends MonthlyBudgetNotifier {
  final double? initial;
  _TestMonthlyBudgetNotifier(this.initial);

  @override
  double? build() => initial;
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
    String? currency,
    DateTime? expenseDate,
    required String paidBy,
    String? category,
    String? notes,
    String? paymentMethod,
    bool isTransfer = false,
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
      paymentMethod: paymentMethod,
      isTransfer: isTransfer,
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
