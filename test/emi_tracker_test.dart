import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/subscriptions/emi_tracker_screen.dart';
import 'package:cove/features/subscriptions/subscriptions_screen.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCurrencyNotifier extends CurrencyNotifier {
  final CurrencyOption _opt;
  FakeCurrencyNotifier(this._opt);

  @override
  CurrencyOption build() => _opt;
}

void main() {
  LocalSubscription createMockEmi({
    required String id,
    required String name,
    required double amount,
    required int totalInstallments,
    required int paidInstallments,
    String? financedThrough,
    bool isPrivate = false,
  }) {
    return LocalSubscription(
      id: id,
      homeId: 'home_1',
      name: name,
      amount: amount,
      currency: 'USD',
      billingCycle: 'monthly',
      nextBillingDate: DateTime(2026, 10, 1),
      category: 'gadgets',
      isActive: true,
      isPrivate: isPrivate,
      createdBy: 'user_1',
      createdAt: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      paidBy: 'user_1',
      financedThrough: financedThrough,
      totalInstallments: totalInstallments,
      paidInstallments: paidInstallments,
    );
  }

  Widget buildTestWidget({
    List<LocalSubscription>? subscriptions,
  }) {
    return ProviderScope(
      overrides: [
        currencyPreferenceProvider.overrideWith(
          () => FakeCurrencyNotifier(const CurrencyOption(
            code: 'USD',
            symbol: '\$',
            name: 'US Dollar',
          )),
        ),
      ],
      child: MaterialApp(
        theme: CoveTheme.darkTheme,
        home: EmiTrackerScreen(
          initialSubscriptions: subscriptions,
        ),
      ),
    );
  }

  group('EmiTrackerScreen', () {
    testWidgets('Renders empty state when no EMIs exist', (tester) async {
      await tester.pumpWidget(buildTestWidget(subscriptions: []));
      await tester.pumpAndSettle();

      expect(find.text('No EMIs or loans active'), findsOneWidget);
      expect(find.text('Add Loan or EMI'), findsOneWidget);
    });

    testWidgets('Calculates total outstanding, paid total, and renders EMI cards', (tester) async {
      final emi1 = createMockEmi(
        id: 'emi_1',
        name: 'MacBook Pro',
        amount: 200.0,
        totalInstallments: 10,
        paidInstallments: 4, // 6 remaining * 200 = 1200 outstanding, 800 paid
        financedThrough: 'Apple Card',
      );
      final emi2 = createMockEmi(
        id: 'emi_2',
        name: 'Car Loan',
        amount: 500.0,
        totalInstallments: 20,
        paidInstallments: 8, // 12 remaining * 500 = 6000 outstanding, 4000 paid
        financedThrough: 'Chase',
      );

      await tester.pumpWidget(buildTestWidget(subscriptions: [emi1, emi2]));
      await tester.pumpAndSettle();

      // Total outstanding: 1200 + 6000 = 7200
      expect(find.text('\$7,200'), findsOneWidget);
      // Total monthly: 200 + 500 = 700
      expect(find.text('Monthly: \$700/mo'), findsOneWidget);
      // Paid total: 800 + 4000 = 4800
      expect(find.textContaining('Paid: \$4,800'), findsOneWidget);
      // Active count badge
      expect(find.text('2 active loans'), findsOneWidget);

      // Card 1
      expect(find.text('MacBook Pro'), findsOneWidget);
      expect(find.text('Apple Card'), findsOneWidget);
      expect(find.text('\$1,200'), findsOneWidget); // Outstanding for emi1
      expect(find.text('\$800'), findsOneWidget); // Paid for emi1
      expect(find.text('4/10 mo'), findsOneWidget);

      // Card 2
      expect(find.text('Car Loan'), findsOneWidget);
      expect(find.text('Chase'), findsOneWidget);
      expect(find.text('\$6,000'), findsOneWidget); // Outstanding for emi2
      expect(find.text('\$4,000'), findsOneWidget); // Paid for emi2
      expect(find.text('8/20 mo'), findsOneWidget);
    });

    testWidgets('Toggles universal progress mode between Tenure Paid and EMI Share', (tester) async {
      final emi = createMockEmi(
        id: 'emi_1',
        name: 'MacBook Pro',
        amount: 200.0,
        totalInstallments: 10,
        paidInstallments: 4,
        financedThrough: 'Apple Financial',
      );

      await tester.pumpWidget(buildTestWidget(subscriptions: [emi]));
      await tester.pumpAndSettle();

      // Default is Tenure Paid mode
      expect(find.text('4 of 10 months paid'), findsOneWidget);
      expect(find.text('40% tenure done'), findsOneWidget);

      // Tap 'EMI Share'
      await tester.tap(find.text('EMI Share'));
      await tester.pumpAndSettle();

      // Now should show relative EMI share
      expect(find.text('100.0% of monthly EMI total'), findsOneWidget);
      expect(find.text('\$200 / \$200'), findsOneWidget);

      // Switch back to 'Tenure Paid'
      await tester.tap(find.text('Tenure Paid'));
      await tester.pumpAndSettle();

      expect(find.text('4 of 10 months paid'), findsOneWidget);
    });

    testWidgets('Toggles sort order between Descending and Ascending', (tester) async {
      final emiSmall = createMockEmi(
        id: 'emi_1',
        name: 'Small EMI',
        amount: 100.0,
        totalInstallments: 5,
        paidInstallments: 4, // 1 rem * 100 = 100 outstanding
      );
      final emiBig = createMockEmi(
        id: 'emi_2',
        name: 'Big EMI',
        amount: 1000.0,
        totalInstallments: 10,
        paidInstallments: 2, // 8 rem * 1000 = 8000 outstanding
      );

      await tester.pumpWidget(buildTestWidget(subscriptions: [emiSmall, emiBig]));
      await tester.pumpAndSettle();

      // Default is High → Low (Big EMI first)
      expect(find.text('High → Low'), findsOneWidget);
      var smallPos = tester.getTopLeft(find.text('Small EMI')).dy;
      var bigPos = tester.getTopLeft(find.text('Big EMI')).dy;
      expect(bigPos, lessThan(smallPos));

      // Tap to sort Low → High
      await tester.tap(find.text('High → Low'));
      await tester.pumpAndSettle();

      expect(find.text('Low → High'), findsOneWidget);
      smallPos = tester.getTopLeft(find.text('Small EMI')).dy;
      bigPos = tester.getTopLeft(find.text('Big EMI')).dy;
      expect(smallPos, lessThan(bigPos));
    });

    testWidgets('AppBar icon in SubscriptionsScreen navigates to EmiTrackerScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyPreferenceProvider.overrideWith(
              () => FakeCurrencyNotifier(const CurrencyOption(
                code: 'USD',
                symbol: '\$',
                name: 'US Dollar',
              )),
            ),
          ],
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const SubscriptionsScreen(
              initialSubscriptions: [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the EMI Outstanding icon button
      final emiButton = find.byTooltip('EMI Outstanding');
      expect(emiButton, findsOneWidget);

      await tester.tap(emiButton);
      await tester.pumpAndSettle();

      expect(find.byType(EmiTrackerScreen), findsOneWidget);
      expect(find.text('EMI Outstanding'), findsOneWidget);
    });
  });
}
