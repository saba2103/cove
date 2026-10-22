import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_metric_card.dart';
import 'package:cove/core/widgets/cove_page_header.dart';
import 'package:cove/core/widgets/cove_round_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _MetricCardShowcase extends StatelessWidget {
  const _MetricCardShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CovePageHeader(
              title: 'Commitments',
              readout: 'October',
              action: CoveRoundButton(
                icon: Icons.add_rounded,
                variant: CoveRoundButtonVariant.gold,
                semanticLabel: 'Add commitment',
                onPressed: () {},
              ),
            ),
            const SizedBox(height: CoveSpace.md),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
              child: CoveMetricGrid(
                key: ValueKey('metric_grid'),
                children: [
                  CoveMetricCard(
                    key: ValueKey('card_monthly'),
                    label: 'Monthly outflow',
                    value: '₹38,420',
                    subtitle: 'Across 9 commitments',
                  ),
                  CoveMetricCard(
                    key: ValueKey('card_due_soon'),
                    label: 'Due in 7 days',
                    value: '₹12,800',
                    subtitle: '3 items upcoming',
                  ),
                  CoveMetricCard(
                    key: ValueKey('card_vs_last'),
                    label: 'vs September',
                    value: '−₹2,150',
                    subtitle: '5.3% lower this month',
                    valueTone: CoveMetricValueTone.moneyLess,
                  ),
                  CoveMetricCard(
                    key: ValueKey('card_overdue'),
                    label: 'Needs attention',
                    value: '1 overdue',
                    subtitle: 'BESCOM · ₹3,420',
                    valueTone: CoveMetricValueTone.alert,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'CoveMetricCard golden matrix (2x2 grid, 12dp padding & gap, 20dp radius, centred at wide)',
    (tester) async {
      await goldenMatrix(
        tester,
        'metric_card',
        const _MetricCardShowcase(),
      );

      // 1. Horizontal & vertical grid gap between the 2-per-row cards is CoveSpace.md (12dp)
      final card1Rect = tester.getRect(
        find.byKey(const ValueKey('card_monthly')),
      );
      final card2Rect = tester.getRect(
        find.byKey(const ValueKey('card_due_soon')),
      );
      final card3Rect = tester.getRect(
        find.byKey(const ValueKey('card_vs_last')),
      );
      expect(
        card2Rect.left - card1Rect.right,
        closeTo(CoveSpace.md, 0.01),
      );
      expect(
        card3Rect.top - card1Rect.bottom,
        closeTo(CoveSpace.md, 0.01),
      );

      // 2. Paired cards in the same row have equal width and equal height
      expect(card1Rect.width, closeTo(card2Rect.width, 0.01));
      expect(card1Rect.height, closeTo(card2Rect.height, 0.01));

      // 3. At wide width (840dp), CoveMetricGrid does not grow past CoveSize.maxContent (420dp) and centres
      final row1SpanWidth = card2Rect.right - card1Rect.left;
      expect(row1SpanWidth, lessThanOrEqualTo(CoveSize.maxContent + 0.01));
      final screenRect = tester.getRect(find.byType(Scaffold));
      expect(
        (card1Rect.left + card2Rect.right) / 2,
        closeTo(screenRect.center.dx, 0.01),
      );
    },
  );
}
