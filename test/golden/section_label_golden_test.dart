import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _SectionLabelShowcase extends StatelessWidget {
  const _SectionLabelShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(CoveSpace.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Section Labels',
              style: CoveType.title.copyWith(color: cv.textPrimary),
            ),
            const SizedBox(height: CoveSpace.lg),

            // 1. Page-level label (CoveType.capsPage, 12sp, followed by hairline rule)
            const CoveSectionLabel.page(
              key: ValueKey('page_label_plain'),
              label: 'Due this week',
            ),
            const SizedBox(height: CoveSpace.md),
            Text(
              'Page-level section heading on the scroll surface (12sp / .15em / w700).',
              style: CoveType.rowSub.copyWith(color: cv.textSecondary),
            ),
            const SizedBox(height: CoveSpace.section),

            // 2. Page-level label + baseline-aligned right-hand readout
            const CoveSectionLabel.page(
              key: ValueKey('page_label_readout'),
              label: 'Recurring commitments',
              readout: '3 items · ₹18,400',
            ),
            const SizedBox(height: CoveSpace.md),
            Text(
              'Page-level label with right-hand readout on the same baseline.',
              style: CoveType.rowSub.copyWith(color: cv.textSecondary),
            ),
            const SizedBox(height: CoveSpace.section),

            // 3. Card-interior label (CoveType.capsCard, 11sp, no hairline rule)
            Container(
              padding: const EdgeInsets.all(CoveSpace.gutter),
              decoration: BoxDecoration(
                color: cv.surfaceCard,
                borderRadius: const BorderRadius.all(
                  Radius.circular(CoveRadius.card),
                ),
                border: Border.all(color: cv.lineHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CoveSectionLabel.card(
                    key: ValueKey('card_label_plain'),
                    label: 'Remaining this month',
                  ),
                  const SizedBox(height: CoveSpace.sm),
                  Text(
                    '₹42,600',
                    style: CoveType.cardFigure.copyWith(color: cv.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CoveSpace.md),

            // 4. Card-interior label + baseline-aligned right-hand readout
            Container(
              padding: const EdgeInsets.all(CoveSpace.gutter),
              decoration: BoxDecoration(
                color: cv.surfaceCard,
                borderRadius: const BorderRadius.all(
                  Radius.circular(CoveRadius.card),
                ),
                border: Border.all(color: cv.lineHairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CoveSectionLabel.card(
                    key: ValueKey('card_label_readout'),
                    label: 'Household split',
                    readout: 'October',
                  ),
                  const SizedBox(height: CoveSpace.sm),
                  Text(
                    '₹38,420',
                    style: CoveType.cardFigure.copyWith(color: cv.textPrimary),
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
    'CoveSectionLabel golden matrix (page, card, with and without baseline readout)',
    (tester) async {
      await goldenMatrix(
        tester,
        'section_label',
        const _SectionLabelShowcase(),
      );

      // 1. Page-level label renders uppercase at 12sp (CoveType.capsPage) with hairline rule
      final pageLabelText = tester.widget<Text>(find.text('DUE THIS WEEK'));
      expect(pageLabelText.style?.fontSize, equals(CoveType.capsPage.fontSize));
      expect(
        pageLabelText.style?.fontWeight,
        equals(CoveType.capsPage.fontWeight),
      );
      expect(
        pageLabelText.style?.letterSpacing,
        equals(CoveType.capsPage.letterSpacing),
      );

      final pagePlainFinder = find.byKey(const ValueKey('page_label_plain'));
      final pageRuleFinder = find.descendant(
        of: pagePlainFinder,
        matching: find.byType(ColoredBox),
      );
      expect(pageRuleFinder, findsOneWidget);
      final pageRuleRect = tester.getRect(pageRuleFinder);
      final pagePlainRect = tester.getRect(pagePlainFinder);
      expect(pageRuleRect.height, equals(1.0));
      expect(pageRuleRect.width, closeTo(pagePlainRect.width, 0.01));

      // 2. Card-interior label renders uppercase at 11sp (CoveType.capsCard) with no hairline rule
      final cardLabelText = tester.widget<Text>(
        find.text('REMAINING THIS MONTH'),
      );
      expect(cardLabelText.style?.fontSize, equals(CoveType.capsCard.fontSize));
      expect(
        cardLabelText.style?.fontWeight,
        equals(CoveType.capsCard.fontWeight),
      );
      expect(
        cardLabelText.style?.letterSpacing,
        equals(CoveType.capsCard.letterSpacing),
      );

      final cardPlainFinder = find.byKey(const ValueKey('card_label_plain'));
      expect(
        find.descendant(
          of: cardPlainFinder,
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );

      // 3. Page-level label and right-hand readout share an alphabetic baseline
      final recLabelFinder = find.text('RECURRING COMMITMENTS');
      final recReadoutFinder = find.text('3 items · ₹18,400');
      final recLabelRect = tester.getRect(recLabelFinder);
      final recReadoutRect = tester.getRect(recReadoutFinder);
      final recLabelPara = tester.renderObject<RenderParagraph>(recLabelFinder);
      final recReadoutPara = tester.renderObject<RenderParagraph>(
        recReadoutFinder,
      );
      final recLabelBaseline =
          recLabelRect.top +
          recLabelPara.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      final recReadoutBaseline =
          recReadoutRect.top +
          recReadoutPara.computeDistanceToActualBaseline(
            TextBaseline.alphabetic,
          );
      expect(recLabelBaseline, closeTo(recReadoutBaseline, 0.01));
    },
  );
}
