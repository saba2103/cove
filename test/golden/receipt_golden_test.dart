import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/utils/cove_currency_formatter.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_max_width.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:cove/core/widgets/slips/cove_receipt.dart';
import 'package:cove/core/widgets/slips/cove_slip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _ThreeItemReceiptShowcase extends StatelessWidget {
  const _ThreeItemReceiptShowcase();

  static final List<CoveReceiptItem> _items = <CoveReceiptItem>[
    CoveReceiptItem(
      payer: CovePerson.b,
      nameOrInitial: 'Ancy',
      title: 'Diwali gifts — Amma, Appa',
      subtitle: 'Gifts · HDFC Regalia',
      amount: '₹${formatCoveAmount(2491)}',
      onTap: () {},
    ),
    CoveReceiptItem(
      payer: CovePerson.a,
      nameOrInitial: 'Saba',
      title: "Namdhari's — the big run",
      subtitle: 'Groceries · BOB',
      amount: '₹${formatCoveAmount(2640)}',
      onTap: () {},
    ),
    CoveReceiptItem(
      payer: CovePerson.a,
      nameOrInitial: 'Saba',
      title: 'Auto to the market',
      subtitle: 'Fuel · Cash',
      amount: '₹${formatCoveAmount(500)}',
      onTap: () {},
    ),
  ];

  static final CoveReceiptSplit _split = CoveReceiptSplit(
    viewerName: 'You',
    viewerAmount: '₹${formatCoveAmount(3140)}',
    partnerName: 'Ancy',
    partnerAmount: '₹${formatCoveAmount(2491)}',
    viewerShare: 3140 / 5631,
  );

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
                const CoveSectionLabel.page(
                  label: 'Three items · Ink',
                  readout: '3 purchases',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveReceipt(
                  key: const ValueKey('receipt_3_ink'),
                  variant: CoveSlipVariant.ink,
                  recordId: 'receipt-2026-10-21-day',
                  title: 'Wednesday',
                  items: _items,
                  totalAmount: '₹${formatCoveAmount(5631)}',
                  split: _split,
                  footerDate: 'WEDNESDAY, OCT 21',
                ),
                const SizedBox(height: CoveSpace.md),
                const CoveSectionLabel.page(
                  label: 'Three items · Paper',
                  readout: '3 purchases',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveReceipt(
                  key: const ValueKey('receipt_3_paper'),
                  variant: CoveSlipVariant.paper,
                  recordId: 'receipt-2026-10-21-day',
                  title: 'Wednesday',
                  items: _items,
                  totalAmount: '₹${formatCoveAmount(5631)}',
                  split: _split,
                  footerDate: 'WEDNESDAY, OCT 21',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OneItemReceiptShowcase extends StatelessWidget {
  const _OneItemReceiptShowcase();

  static final List<CoveReceiptItem> _items = <CoveReceiptItem>[
    CoveReceiptItem(
      payer: CovePerson.both,
      title: 'Flat white & almond croissant',
      subtitle: 'Eating out · UPI',
      amount: '₹${formatCoveAmount(640)}',
      onTap: () {},
    ),
  ];

  static final CoveReceiptSplit _split = CoveReceiptSplit(
    viewerName: 'You',
    viewerAmount: '₹${formatCoveAmount(320)}',
    partnerName: 'Ancy',
    partnerAmount: '₹${formatCoveAmount(320)}',
    viewerShare: 0.5,
  );

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
                const CoveSectionLabel.page(
                  label: 'One item · Ink',
                  readout: '1 purchase',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveReceipt(
                  key: const ValueKey('receipt_1_ink'),
                  variant: CoveSlipVariant.ink,
                  recordId: 'expense-blue-tokai-01',
                  title: 'Blue Tokai Coffee',
                  subtitle: 'SINGLE PURCHASE',
                  items: _items,
                  totalAmount: '₹${formatCoveAmount(640)}',
                  split: _split,
                  footerDate: 'WEDNESDAY, OCT 21',
                ),
                const SizedBox(height: CoveSpace.md),
                const CoveSectionLabel.page(
                  label: 'One item · Paper',
                  readout: '1 purchase',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveReceipt(
                  key: const ValueKey('receipt_1_paper'),
                  variant: CoveSlipVariant.paper,
                  recordId: 'expense-blue-tokai-01',
                  title: 'Blue Tokai Coffee',
                  subtitle: 'SINGLE PURCHASE',
                  items: _items,
                  totalAmount: '₹${formatCoveAmount(640)}',
                  split: _split,
                  footerDate: 'WEDNESDAY, OCT 21',
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
    'CoveReceipt golden matrix (3-item & 1-item, paper & ink, both brightnesses, deterministic barcode, cover width)',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await goldenMatrix(
          tester,
          'receipt',
          const _ThreeItemReceiptShowcase(),
        );

        // 1. Semantics for 3-item receipt per design/specs/10-paper-objects.md
        final threeItemSem = tester.getSemantics(
          find.byKey(const ValueKey('receipt_3_ink')),
        );
        expect(
          threeItemSem.label,
          equals('Receipt, Wednesday, total ₹5,631, 3 items'),
        );

        await goldenMatrix(
          tester,
          'receipt_single',
          const _OneItemReceiptShowcase(),
        );

        // 2. Semantics for 1-item receipt
        final oneItemSem = tester.getSemantics(
          find.byKey(const ValueKey('receipt_1_ink')),
        );
        expect(
          oneItemSem.label,
          equals('Receipt, Blue Tokai Coffee, total ₹640, 1 item'),
        );

        // 3. Deterministic barcode derivation from recordId
        final barsRun1 = CoveReceipt.computeBarcodeBars('receipt-2026-10-21-day');
        final barsRun2 = CoveReceipt.computeBarcodeBars('receipt-2026-10-21-day');
        final barsOther = CoveReceipt.computeBarcodeBars('expense-blue-tokai-01');
        expect(barsRun1.length, equals(barsRun2.length));
        for (var i = 0; i < barsRun1.length; i++) {
          expect(barsRun1[i].heightFactor, equals(barsRun2[i].heightFactor));
          expect(barsRun1[i].width, equals(barsRun2[i].width));
        }
        expect(
          barsRun1.map((b) => '${b.width}:${b.heightFactor}').join(','),
          isNot(
            equals(
              barsOther.map((b) => '${b.width}:${b.heightFactor}').join(','),
            ),
          ),
        );

        // 4. At cover width (320dp), confirm item amounts and total figures do not wrap
        tester.view
          ..physicalSize = CoveWidth.cover * 2
          ..devicePixelRatio = 2.0;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: CoveWidth.cover,
              textScaler: TextScaler.linear(1.0),
            ),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: coveThemeFor(Brightness.dark),
              home: const _ThreeItemReceiptShowcase(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final amountText in ['₹2,491', '₹2,640', '₹500']) {
          for (final element in find.text(amountText).evaluate()) {
            final box = element.renderObject! as RenderBox;
            expect(
              box.size.height,
              lessThanOrEqualTo(24.0),
              reason: 'Item amount $amountText wrapped at 320dp cover width',
            );
          }
        }
        final totalBox = find
            .text('₹5,631')
            .evaluate()
            .first
            .renderObject! as RenderBox;
        expect(
          totalBox.size.height,
          lessThanOrEqualTo(42.0),
          reason: 'Total ₹5,631 wrapped at 320dp cover width',
        );
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}
