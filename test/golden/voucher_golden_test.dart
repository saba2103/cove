import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/utils/cove_currency_formatter.dart';
import 'package:cove/core/widgets/cove_max_width.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:cove/core/widgets/slips/cove_slip.dart';
import 'package:cove/core/widgets/slips/cove_voucher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _VoucherShowcase extends StatelessWidget {
  final CoveSlipVariant variant;

  const _VoucherShowcase({required this.variant});

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final tag = variant == CoveSlipVariant.ink ? 'Ink' : 'Paper';

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
                CoveSectionLabel.page(
                  label: 'Due tomorrow · $tag',
                  readout: 'due state',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveVoucher(
                  key: ValueKey('voucher_due_${variant.name}'),
                  variant: variant,
                  title: 'AC — the instalment',
                  amount: '₹${formatCoveAmount(3974)}',
                  dueDay: '22',
                  dueMonth: 'OCT',
                  dueMonthSemantic: 'October',
                  state: CoveVoucherState.due,
                  onTap: () {},
                ),
                const SizedBox(height: CoveSpace.md),
                CoveSectionLabel.page(
                  label: 'Settled · $tag',
                  readout: 'paid state',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveVoucher(
                  key: ValueKey('voucher_paid_${variant.name}'),
                  variant: variant,
                  title: 'AC instalment',
                  amount: '₹${formatCoveAmount(3974)}',
                  dueDay: '22',
                  dueMonth: 'OCT',
                  dueMonthSemantic: 'October',
                  state: CoveVoucherState.paid,
                  onTap: () {},
                ),
                const SizedBox(height: CoveSpace.md),
                CoveSectionLabel.page(
                  label: 'Punched EMI · $tag',
                  readout: '12 of 48 paid',
                ),
                const SizedBox(height: CoveSpace.sm),
                CoveVoucher(
                  key: ValueKey('voucher_emi_${variant.name}'),
                  variant: variant,
                  title: 'Car loan — HDFC',
                  amount: '₹${formatCoveAmount(18450)}',
                  dueDay: '22',
                  dueMonth: 'OCT',
                  dueMonthSemantic: 'October',
                  state: CoveVoucherState.due,
                  totalInstallments: 48,
                  paidInstallments: 12,
                  onTap: () {},
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
    'CoveVoucher golden matrix (due, paid, and EMI punched states in ink & paper across both brightnesses)',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await goldenMatrix(
          tester,
          'voucher',
          const _VoucherShowcase(variant: CoveSlipVariant.ink),
        );

        // 1. "DUE" is never rendered inside the 64dp due circle
        expect(find.text('DUE'), findsNothing);

        // 2. Semantics read out state and EMI progress per design/specs/10-paper-objects.md
        final dueSem = tester.getSemantics(
          find.byKey(const ValueKey('voucher_due_ink')),
        );
        expect(
          dueSem.label,
          equals('Voucher, AC — the instalment, ₹3,974, due 22 October, due'),
        );

        final paidSem = tester.getSemantics(
          find.byKey(const ValueKey('voucher_paid_ink')),
        );
        expect(
          paidSem.label,
          equals('Voucher, AC instalment, ₹3,974, due 22 October, paid'),
        );

        final emiSem = tester.getSemantics(
          find.byKey(const ValueKey('voucher_emi_ink')),
        );
        expect(
          emiSem.label,
          equals(
            'Voucher, Car loan — HDFC, ₹18,450, due 22 October, due, EMI, 12 of 48 paid',
          ),
        );
        expect(emiSem.label, contains('12 of 48 paid'));

        await goldenMatrix(
          tester,
          'voucher_paper',
          const _VoucherShowcase(variant: CoveSlipVariant.paper),
        );
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}
