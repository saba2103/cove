import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/utils/cove_currency_formatter.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_max_width.dart';
import 'package:cove/core/widgets/slips/cove_dial.dart';
import 'package:cove/core/widgets/slips/cove_receipt.dart';
import 'package:cove/core/widgets/slips/cove_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _DialShowcase extends StatelessWidget {
  const _DialShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: CoveSpace.md),
        child: CoveMaxWidth(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Large share category (Groceries, 68% share, 14 purchases)
                CoveDial(
                  key: const ValueKey('dial_large'),
                  variant: CoveSlipVariant.paper,
                  title: 'Groceries',
                  category: CoveCategory.groceries,
                  amount: '₹${formatCoveAmount(12400)}',
                  share: 0.68,
                  purchaseCount: 14,
                  items: [
                    CoveReceiptItem(
                      payer: CovePerson.a,
                      nameOrInitial: 'Saba',
                      title: "Namdhari's Fresh",
                      subtitle: '15 Oct · UPI',
                      amount: '₹${formatCoveAmount(1840)}',
                    ),
                    CoveReceiptItem(
                      payer: CovePerson.b,
                      nameOrInitial: 'Ancy',
                      title: 'Subko Cacao & Bakery',
                      subtitle: '12 Oct · Card',
                      amount: '₹${formatCoveAmount(650)}',
                    ),
                  ],
                ),
                const SizedBox(height: CoveSpace.md),

                // 2. Small share category (Travel — tightest light contrast 3.17:1, 12% share)
                CoveDial(
                  key: const ValueKey('dial_small'),
                  variant: CoveSlipVariant.paper,
                  title: 'Travel',
                  category: CoveCategory.travel,
                  amount: '₹${formatCoveAmount(2180)}',
                  share: 0.12,
                  purchaseCount: 2,
                  items: [
                    CoveReceiptItem(
                      payer: CovePerson.a,
                      nameOrInitial: 'Saba',
                      title: 'Airport cab',
                      subtitle: '10 Oct · UPI',
                      amount: '₹${formatCoveAmount(1280)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialZeroShowcase extends StatelessWidget {
  const _DialZeroShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: CoveSpace.md),
        child: CoveMaxWidth(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 3. Zero share category (0%, ₹0, 0 purchases)
                CoveDial(
                  key: const ValueKey('dial_zero'),
                  variant: CoveSlipVariant.paper,
                  title: 'Gifts',
                  category: CoveCategory.gifts,
                  amount: '₹${formatCoveAmount(0)}',
                  share: 0.0,
                  purchaseCount: 0,
                ),
                const SizedBox(height: CoveSpace.md),

                // Small share companion for comparison in the same frame
                CoveDial(
                  key: const ValueKey('dial_small_companion'),
                  variant: CoveSlipVariant.paper,
                  title: 'Travel',
                  category: CoveCategory.travel,
                  amount: '₹${formatCoveAmount(2180)}',
                  share: 0.12,
                  purchaseCount: 2,
                  items: [
                    CoveReceiptItem(
                      payer: CovePerson.a,
                      nameOrInitial: 'Saba',
                      title: 'Airport cab',
                      subtitle: '10 Oct · UPI',
                      amount: '₹${formatCoveAmount(1280)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'CoveDial golden matrix (large share, small share, and 0% share on paper across both app brightnesses)',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await goldenMatrix(
          tester,
          'dial',
          const _DialShowcase(),
        );

        // Verify semantics contract:
        // "Category, Groceries, ₹12,400 this month, 31% of spending, 14 purchases"
        final largeSem = tester.getSemantics(
          find.byKey(const ValueKey('dial_large')),
        );
        expect(
          largeSem.label,
          equals(
            'Category, Groceries, ₹12,400 this month, 68% of spending, 14 purchases',
          ),
        );

        final smallSem = tester.getSemantics(
          find.byKey(const ValueKey('dial_small')),
        );
        expect(
          smallSem.label,
          equals(
            'Category, Travel, ₹2,180 this month, 12% of spending, 2 purchases',
          ),
        );

        await goldenMatrix(
          tester,
          'dial_zero',
          const _DialZeroShowcase(),
        );

        final zeroSem = tester.getSemantics(
          find.byKey(const ValueKey('dial_zero')),
        );
        expect(
          zeroSem.label,
          equals(
            'Category, Gifts, ₹0 this month, 0% of spending, 0 purchases',
          ),
        );

        // Verify category colours on paper always come from CoveTokens.light,
        // never from context.cv (identical in dark and light mode).
        for (final cat in CoveCategory.values) {
          expect(
            CoveDial.colorForCategory(cat, variant: CoveSlipVariant.paper),
            isNot(equals(CoveDial.colorForCategory(cat, variant: CoveSlipVariant.ink))),
          );
        }
        expect(
          CoveDial.colorForCategory(
            CoveCategory.travel,
            variant: CoveSlipVariant.paper,
          ),
          equals(CoveTokens.light.categoryTravel),
        );
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}
