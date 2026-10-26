import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/monthly_budget_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/widgets/cove_ledger_widget.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

final DateTime _kOct5 = DateTime(2026, 10, 5, 9, 41);
final Clock _kLedgerClock = Clock.fixed(_kOct5);

const CoveUser _kSabaUser = CoveUser(
  id: 'user_1',
  email: 'saba@cove.local',
  displayName: 'Saba',
);

const UserProfileState _kSabaProfile = UserProfileState(
  displayName: 'Saba',
  email: 'saba@cove.local',
);

const PartnerProfileState _kAncyProfile = PartnerProfileState(
  displayName: 'Ancy',
  hasCustomName: true,
);

final LocalHome _kSeedHome = LocalHome(
  id: 'home_1',
  name: 'The Nest',
  description: 'Bengaluru',
  currency: 'INR',
  createdAt: DateTime(2026, 9, 1, 9, 0),
  createdBy: 'user_1',
);

class _FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncData(_kSabaUser);

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void signInWithDemoUser([
    String name = 'Saba',
    String email = 'saba@cove.local',
  ]) {}

  @override
  Future<void> signOut() async {}
}

class _FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  @override
  String? build() => 'home_1';

  @override
  void setActiveHome(String homeId) => state = homeId;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => _kAncyProfile;
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => _kSabaProfile;
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() =>
      const CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee');
}

class _FakeMonthlyBudgetNotifier extends MonthlyBudgetNotifier {
  @override
  double? build() => 85000.0;
}

final List<LocalExpense> _kOctoberExpenses = <LocalExpense>[
  LocalExpense(
    id: 'exp_oct_you',
    homeId: 'home_1',
    title: 'Rent & Groceries',
    amount: 28940.0,
    currency: 'INR',
    paidBy: 'user_1',
    splitRatio: 0.5,
    expenseDate: DateTime(2026, 10, 3, 10, 0),
    category: 'Home',
    paymentMethod: 'upi',
    isTransfer: false,
    createdAt: DateTime(2026, 10, 3, 10, 0),
  ),
  LocalExpense(
    id: 'exp_oct_ancy',
    homeId: 'home_1',
    title: 'Utilities & Market',
    amount: 23240.0,
    currency: 'INR',
    paidBy: 'user_2',
    splitRatio: 0.5,
    expenseDate: DateTime(2026, 10, 4, 18, 0),
    category: 'Groceries',
    paymentMethod: 'card',
    isTransfer: false,
    createdAt: DateTime(2026, 10, 4, 18, 0),
  ),
];

final List<LocalExpense> _kSeptemberExpenses = <LocalExpense>[
  LocalExpense(
    id: 'exp_sep_by_day_5',
    homeId: 'home_1',
    title: 'September early spend',
    amount: 56300.0,
    currency: 'INR',
    paidBy: 'user_1',
    splitRatio: 0.5,
    expenseDate: DateTime(2026, 9, 4, 12, 0),
    category: 'Home',
    paymentMethod: 'upi',
    isTransfer: false,
    createdAt: DateTime(2026, 9, 4, 12, 0),
  ),
];

final List<LocalSubscription> _kSeedCommitments = <LocalSubscription>[
  LocalSubscription(
    id: 'sub_spotify',
    homeId: 'home_1',
    name: 'Spotify Duo',
    amount: 249.0,
    currency: 'INR',
    billingCycle: 'monthly',
    nextBillingDate: DateTime(2026, 10, 6), // Tomorrow relative to Oct 5
    category: 'Subscription',
    isActive: true,
    isPrivate: false,
    paidBy: 'user_1',
    createdAt: DateTime(2026, 9, 6),
  ),
];

List<Override> _buildOverrides({
  required List<LocalExpense> expenses,
  required List<LocalSubscription> subscriptions,
}) {
  return <Override>[
    authProvider.overrideWith(_FakeAuthNotifier.new),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    activeHomeProvider.overrideWith((ref) => Stream.value(_kSeedHome)),
    userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
    partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
    currencyPreferenceProvider.overrideWith(_FakeCurrencyNotifier.new),
    monthlyBudgetProvider.overrideWith(_FakeMonthlyBudgetNotifier.new),
    activeHomeExpensesProvider.overrideWith((ref) => Stream.value(expenses)),
    activeHomeSubscriptionsProvider.overrideWith(
      (ref) => Stream.value(subscriptions),
    ),
  ];
}

Future<void> _pumpLedgerGolden(
  WidgetTester tester, {
  required String goldenName,
  required Brightness brightness,
  required List<LocalExpense> expenses,
  required List<LocalSubscription> subscriptions,
}) async {
  await loadCoveFonts();
  const surfaceSize = Size(411, 208);

  await withClock(_kLedgerClock, () async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      originalOnError?.call(details);
    };
    try {
      tester.view
        ..physicalSize = surfaceSize * 2
        ..devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final theme = coveThemeFor(brightness);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _buildOverrides(
            expenses: expenses,
            subscriptions: subscriptions,
          ),
          child: MediaQuery(
            data: const MediaQueryData(
              size: surfaceSize,
              textScaler: TextScaler.linear(1.0),
            ),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: Builder(
                builder: (context) => ColoredBox(
                  color: context.cv.surfaceCanvas,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 379,
                      height: 176,
                      child: CoveLedgerWidget(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/$goldenName.png'),
      );
    } finally {
      FlutterError.onError = originalOnError;
    }
  });
}

void main() {
  group('4.4a — The Ledger Home-Screen Widget Goldens', () {
    testWidgets('ledger_widget.dark', (tester) async {
      await _pumpLedgerGolden(
        tester,
        goldenName: 'ledger_widget.dark',
        brightness: Brightness.dark,
        expenses: [..._kOctoberExpenses, ..._kSeptemberExpenses],
        subscriptions: _kSeedCommitments,
      );
    });

    testWidgets('ledger_widget.light', (tester) async {
      await _pumpLedgerGolden(
        tester,
        goldenName: 'ledger_widget.light',
        brightness: Brightness.light,
        expenses: [..._kOctoberExpenses, ..._kSeptemberExpenses],
        subscriptions: _kSeedCommitments,
      );
    });

    testWidgets('ledger_widget.empty_month', (tester) async {
      await _pumpLedgerGolden(
        tester,
        goldenName: 'ledger_widget.empty_month',
        brightness: Brightness.dark,
        expenses: _kSeptemberExpenses,
        subscriptions: _kSeedCommitments,
      );
    });

    testWidgets('ledger_widget.first_month', (tester) async {
      await _pumpLedgerGolden(
        tester,
        goldenName: 'ledger_widget.first_month',
        brightness: Brightness.dark,
        expenses: _kOctoberExpenses,
        subscriptions: _kSeedCommitments,
      );
    });

    testWidgets('ledger_widget.no_commitments', (tester) async {
      await _pumpLedgerGolden(
        tester,
        goldenName: 'ledger_widget.no_commitments',
        brightness: Brightness.dark,
        expenses: [..._kOctoberExpenses, ..._kSeptemberExpenses],
        subscriptions: const [],
      );
    });
  });
}
