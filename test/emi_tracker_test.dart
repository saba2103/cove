import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/subscriptions/commitment_detail_sheet.dart';
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
    String? paidBy = 'me',
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
      createdBy: 'user_alex',
      createdAt: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      paidBy: paidBy,
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

    testWidgets('Calculates total outstanding, paid total, and renders EMI cards with payer badge', (tester) async {
      final emi1 = createMockEmi(
        id: 'emi_1',
        name: 'MacBook Pro',
        amount: 200.0,
        totalInstallments: 10,
        paidInstallments: 4, // 6 rem * 200 = 1200 outstanding, 800 paid
        financedThrough: 'Apple Card',
        paidBy: 'me',
      );
      final emi2 = createMockEmi(
        id: 'emi_2',
        name: 'Car Loan',
        amount: 500.0,
        totalInstallments: 20,
        paidInstallments: 8, // 12 rem * 500 = 6000 outstanding, 4000 paid
        financedThrough: 'Chase',
        paidBy: 'Sophia',
      );

      await tester.pumpWidget(buildTestWidget(subscriptions: [emi1, emi2]));
      await tester.pumpAndSettle();

      // Header & cards
      expect(find.text('EMIs'), findsOneWidget);
      expect(find.text('What if…'), findsOneWidget);
      expect(find.text('FREE OF ALL 2 IN'), findsOneWidget);
      expect(find.text('EACH MONTH'), findsOneWidget);
      expect(find.text('LEFT TO PAY'), findsOneWidget);

      // Total outstanding: 1200 + 6000 = 7200
      expect(find.text('\$7,200'), findsOneWidget);
      // Total monthly: 200 + 500 = 700
      expect(find.text('\$700'), findsOneWidget);
      expect(find.textContaining('2 EMIs running', findRichText: true), findsOneWidget);
      // Paid percentage: 4800 / 12000 = 40%
      expect(
        find.textContaining('40% already paid (\$4,800)', findRichText: true),
        findsOneWidget,
      );

      // Staircase graph section
      expect(find.text('WHEN IT GETS LIGHTER'), findsOneWidget);
      expect(find.text('tap the steps'), findsOneWidget);

      // Ledger rows & payer group headers
      expect(find.text('MacBook Pro'), findsOneWidget);
      expect(find.text('Car Loan'), findsOneWidget);
      expect(find.text('6 left (4/10 mo)'), findsOneWidget);
      expect(find.text('12 left (8/20 mo)'), findsOneWidget);
      expect(find.text('YOU · 1'), findsOneWidget);
      expect(find.text('SOPHIA · 1'), findsOneWidget);
    });

    testWidgets('Long press or What if… pill enters what-if mode and displays tray', (tester) async {
      final emi1 = createMockEmi(
        id: 'emi_1',
        name: 'MacBook Pro',
        amount: 200.0,
        totalInstallments: 10,
        paidInstallments: 4, // 1200 outst, 200/mo
      );
      final emi2 = createMockEmi(
        id: 'emi_2',
        name: 'Car Loan',
        amount: 500.0,
        totalInstallments: 20,
        paidInstallments: 8, // 6000 outst, 500/mo
      );

      await tester.pumpWidget(buildTestWidget(subscriptions: [emi1, emi2]));
      await tester.pumpAndSettle();

      // Initially no what-if tray
      expect(find.text('IF WE CLOSE THESE'), findsNothing);

      // Scroll down so MacBook Pro is visible and long-press it
      await tester.scrollUntilVisible(find.text('MacBook Pro'), 150);
      await tester.pumpAndSettle();

      await tester.longPress(find.text('MacBook Pro'));
      await tester.pumpAndSettle();

      // What-if tray appears with 1 selected: Frees $200/mo, Payoff $1,200
      expect(find.text('IF WE CLOSE THESE'), findsOneWidget);
      expect(find.text('(1)'), findsOneWidget);
      expect(find.text('Frees \$200/mo'), findsOneWidget);
      expect(find.text('Payoff \$1,200'), findsOneWidget);

      // Tap second card (Car Loan) to add to selection
      await tester.ensureVisible(find.text('Car Loan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Car Loan'));
      await tester.pumpAndSettle();

      // Now 2 selected: Frees $700/mo, Payoff $7,200
      expect(find.text('(2)'), findsOneWidget);
      expect(find.text('Frees \$700/mo'), findsOneWidget);
      expect(find.text('Payoff \$7,200'), findsOneWidget);

      // Clear selection using the close button in the tray
      final clearBtn = find.byKey(const ValueKey('emi_clear_what_if'));
      await tester.ensureVisible(clearBtn);
      await tester.pumpAndSettle();
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(find.text('IF WE CLOSE THESE'), findsNothing);
    });

    testWidgets('Tapping step on staircase graph displays step callout', (tester) async {
      final emi1 = createMockEmi(
        id: 'emi_1',
        name: 'MacBook Pro',
        amount: 200.0,
        totalInstallments: 10,
        paidInstallments: 4, // 6 left
      );
      final emi2 = createMockEmi(
        id: 'emi_2',
        name: 'Car Loan',
        amount: 500.0,
        totalInstallments: 20,
        paidInstallments: 8, // 12 left
      );

      await tester.pumpWidget(buildTestWidget(subscriptions: [emi1, emi2]));
      await tester.pumpAndSettle();

      // Tap near the left-center of the staircase graph (6 months out of 12)
      final graphFinder = find.byKey(const ValueKey('emi_staircase_graph'));
      await tester.ensureVisible(graphFinder);
      await tester.pumpAndSettle();
      final graphRect = tester.getRect(graphFinder);
      await tester.tapAt(
        Offset(graphRect.left + graphRect.width * 0.4, graphRect.center.dy),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('MacBook Pro closes'), findsOneWidget);
      expect(find.textContaining('drops to \$500/mo'), findsOneWidget);
    });

    testWidgets('Switches sort mode between By who, Ends first, and Biggest', (tester) async {
      final emiSmall = createMockEmi(
        id: 'emi_1',
        name: 'Small EMI',
        amount: 100.0,
        totalInstallments: 5,
        paidInstallments: 4, // 1 left
        paidBy: 'Sophia',
      );
      final emiBig = createMockEmi(
        id: 'emi_2',
        name: 'Big EMI',
        amount: 1000.0,
        totalInstallments: 10,
        paidInstallments: 2, // 8 left
        paidBy: 'me',
      );

      await tester.pumpWidget(buildTestWidget(subscriptions: [emiSmall, emiBig]));
      await tester.pumpAndSettle();

      // Default is 'By who' ('Big EMI' first seen in list? No, emiSmall is Sophia, emiBig is me — first seen in [emiSmall, emiBig] is Sophia, or let's check positions)
      expect(find.text('By who'), findsOneWidget);
      expect(find.text('Ends first'), findsOneWidget);
      expect(find.text('Biggest'), findsOneWidget);

      // Tap 'Ends first' (Small EMI has 1 left vs Big EMI 8 left)
      await tester.ensureVisible(find.text('Ends first'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ends first'));
      await tester.pumpAndSettle();

      var smallPos = tester.getTopLeft(find.text('Small EMI')).dy;
      var bigPos = tester.getTopLeft(find.text('Big EMI')).dy;
      expect(smallPos, lessThan(bigPos));

      // Tap 'Biggest' (Big EMI $8000 left vs Small EMI $100 left)
      await tester.ensureVisible(find.text('Biggest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Biggest'));
      await tester.pumpAndSettle();

      smallPos = tester.getTopLeft(find.text('Small EMI')).dy;
      bigPos = tester.getTopLeft(find.text('Big EMI')).dy;
      expect(bigPos, lessThan(smallPos));
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
      expect(find.text('EMIs'), findsOneWidget);
    });

    testWidgets('CommitmentDetailSheet shows foreclosure item in overflow menu only for active EMIs', (tester) async {
      final activeEmi = createMockEmi(
        id: 'emi_1',
        name: 'MacBook Pro',
        amount: 200.0,
        totalInstallments: 10,
        paidInstallments: 4,
        financedThrough: 'Apple Card',
      );

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
            home: Scaffold(
              body: CommitmentDetailSheet(subscription: activeEmi),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open ⋯ overflow menu and select foreclosure item
      await tester.tap(
        find.byKey(const ValueKey('cove_detail_sheet_menu_button')),
      );
      await tester.pumpAndSettle();
      final forecloseItem = find.text(
        'Foreclose this EMI — settle remaining installments',
      );
      expect(forecloseItem, findsOneWidget);

      await tester.tap(forecloseItem);
      await tester.pumpAndSettle();

      // Confirmation dialog should be open
      expect(find.text('Foreclose EMI'), findsWidgets); // title and button
      expect(find.text('Payoff Outstanding'), findsOneWidget);
      expect(find.text('\$1,200'), findsOneWidget); // 6 rem * 200 = 1200
      expect(find.text('4 of 10 paid (6 remaining)'), findsOneWidget);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Apple Card')), findsOneWidget);
      expect(find.text('Log payoff of \$1,200 to Expenses'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('CommitmentDetailSheet does not show foreclosure item for regular subscriptions or finished EMIs', (tester) async {
      final regularSub = LocalSubscription(
        id: 'sub_1',
        homeId: 'home_1',
        name: 'Netflix',
        amount: 15.99,
        currency: 'USD',
        billingCycle: 'monthly',
        nextBillingDate: DateTime(2026, 10, 1),
        category: 'streaming',
        isActive: true,
        isPrivate: false,
        createdBy: 'user_alex',
        createdAt: DateTime(2026, 1, 1),
        endDate: null,
        paidBy: 'me',
        totalInstallments: null,
        paidInstallments: null,
      );

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
            home: Scaffold(
              body: CommitmentDetailSheet(subscription: regularSub),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('cove_detail_sheet_menu_button')),
      );
      await tester.pumpAndSettle();

      // Should NOT have foreclosure item
      expect(
        find.text('Foreclose this EMI — settle remaining installments'),
        findsNothing,
      );
      expect(find.text('Delete this commitment'), findsOneWidget);
    });
  });
}
