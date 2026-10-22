import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_page_header.dart';
import 'package:cove/core/widgets/cove_round_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _PageHeaderShowcase extends StatelessWidget {
  const _PageHeaderShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    Widget buildHeaderSlot({
      required String label,
      required Widget header,
    }) {
      return Container(
        decoration: BoxDecoration(
          color: cv.surfaceCard,
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.card),
          ),
          border: Border.all(color: cv.lineHairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: CoveSpace.gutter,
                right: CoveSpace.gutter,
                top: CoveSpace.sm,
              ),
              child: Text(
                label.toUpperCase(),
                style: CoveType.capsCard.copyWith(color: cv.textTertiary),
              ),
            ),
            header,
            const SizedBox(height: CoveSpace.md),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: CoveSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Primary destination with Gold Add action
            buildHeaderSlot(
              label: '1 · Title + Gold Add Action',
              header: CovePageHeader(
                key: const ValueKey('header_commitments'),
                title: 'Commitments',
                action: CoveRoundButton(
                  key: const ValueKey('btn_add_commitments'),
                  icon: Icons.add_rounded,
                  variant: CoveRoundButtonVariant.gold,
                  semanticLabel: 'Add commitment',
                  onPressed: () {},
                ),
              ),
            ),
            const SizedBox(height: CoveSpace.sm),

            // 2. Destination with baseline-aligned readout + Gold Add action
            buildHeaderSlot(
              label: '2 · Title + Baseline Readout + Gold Add',
              header: CovePageHeader(
                key: const ValueKey('header_expenses'),
                title: 'Money',
                readout: 'October · ₹38,420',
                action: CoveRoundButton(
                  icon: Icons.add_rounded,
                  variant: CoveRoundButtonVariant.gold,
                  semanticLabel: 'Add transaction',
                  onPressed: () {},
                ),
              ),
            ),
            const SizedBox(height: CoveSpace.sm),

            // 3. Destination with Ghost action
            buildHeaderSlot(
              label: '3 · Title + Ghost Action',
              header: CovePageHeader(
                key: const ValueKey('header_today'),
                title: 'Today',
                readout: '22 Oct',
                action: CoveRoundButton(
                  icon: Icons.notifications_none_rounded,
                  variant: CoveRoundButtonVariant.ghost,
                  semanticLabel: 'Notifications',
                  onPressed: () {},
                ),
              ),
            ),
            const SizedBox(height: CoveSpace.sm),

            // 4. Detail destination: Leading Back + Title + 28dp "What if…" pill
            buildHeaderSlot(
              label: '4 · Back + Title + 28dp EMI "What if…" Pill',
              header: CovePageHeader(
                key: const ValueKey('header_emi_rest'),
                leading: CoveRoundButton(
                  key: const ValueKey('btn_back_emi'),
                  icon: Icons.arrow_back_rounded,
                  variant: CoveRoundButtonVariant.ghost,
                  semanticLabel: 'Back',
                  onPressed: () {},
                ),
                title: 'Home Loan',
                trailingPill: CoveHeaderPill(
                  key: const ValueKey('pill_what_if_rest'),
                  label: 'What if…',
                  onPressed: () {},
                ),
              ),
            ),
            const SizedBox(height: CoveSpace.sm),

            // 5. Detail destination: Active "What if…" pill + wrapping title
            buildHeaderSlot(
              label: '5 · Active "What if…" Pill + Wrapping Title',
              header: CovePageHeader(
                key: const ValueKey('header_wrapped'),
                leading: CoveRoundButton(
                  icon: Icons.arrow_back_rounded,
                  variant: CoveRoundButtonVariant.ghost,
                  semanticLabel: 'Back',
                  onPressed: () {},
                ),
                title: 'Home Loan EMI Schedule',
                trailingPill: CoveHeaderPill(
                  key: const ValueKey('pill_what_if_active'),
                  label: 'What if…',
                  isActive: true,
                  onPressed: () {},
                ),
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
    'CovePageHeader golden matrix (title, readout, gold/ghost action, back, What if pill, wrap)',
    (tester) async {
      await goldenMatrix(
        tester,
        'page_header',
        const _PageHeaderShowcase(),
      );

      // 1. Single-line header is 56dp tall (20dp top + 36dp line box)
      final commitmentsRect = tester.getRect(
        find.byKey(const ValueKey('header_commitments')),
      );
      expect(commitmentsRect.height, equals(CovePageHeader.kMinHeight));

      // 2. Trailing CoveRoundButton's 40dp drawn circle is flush to the 20dp gutter
      final addButtonFinder = find.byKey(const ValueKey('btn_add_commitments'));
      final drawnCircleFinder = find.descendant(
        of: addButtonFinder,
        matching: find.byType(DecoratedBox),
      );
      final drawnCircleRect = tester.getRect(drawnCircleFinder.first);
      expect(
        commitmentsRect.right - drawnCircleRect.right,
        closeTo(CoveSpace.gutter, 0.01),
      );

      // 3. Leading CoveRoundButton's 40dp drawn circle is flush to the 20dp left gutter
      final emiHeaderRect = tester.getRect(
        find.byKey(const ValueKey('header_emi_rest')),
      );
      final backButtonFinder = find.byKey(const ValueKey('btn_back_emi'));
      final backCircleFinder = find.descendant(
        of: backButtonFinder,
        matching: find.byType(DecoratedBox),
      );
      final backCircleRect = tester.getRect(backCircleFinder.first);
      expect(
        backCircleRect.left - emiHeaderRect.left,
        closeTo(CoveSpace.gutter, 0.01),
      );

      // 4. Title and readout share an alphabetic baseline and 12dp gap
      final titleFinder = find.text('Money');
      final readoutFinder = find.text('October · ₹38,420');
      final titleRect = tester.getRect(titleFinder);
      final readoutRect = tester.getRect(readoutFinder);
      expect(
        readoutRect.left - titleRect.right,
        closeTo(CoveSpace.md, 0.01),
      );
      final titleParagraph = tester.renderObject<RenderParagraph>(titleFinder);
      final readoutParagraph = tester.renderObject<RenderParagraph>(
        readoutFinder,
      );
      final titleBaseline =
          titleRect.top +
          titleParagraph.computeDistanceToActualBaseline(
            TextBaseline.alphabetic,
          );
      final readoutBaseline =
          readoutRect.top +
          readoutParagraph.computeDistanceToActualBaseline(
            TextBaseline.alphabetic,
          );
      expect(titleBaseline, closeTo(readoutBaseline, 0.01));

      // 5. EMI "What if…" pill is 28dp tall (drawn container)
      final pillFinder = find.byKey(const ValueKey('pill_what_if_rest'));
      final pillAnimatedContainer = find.descendant(
        of: pillFinder,
        matching: find.byType(AnimatedContainer),
      );
      expect(
        tester.getSize(pillAnimatedContainer).height,
        equals(CoveHeaderPill.kHeight),
      );
    },
  );

  testWidgets(
    'CovePageHeader grows cleanly beyond 56dp when title wraps at cover width',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: coveThemeFor(Brightness.dark),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: CovePageHeader(
                key: const ValueKey('wrap_test_header'),
                title: 'Household Recurring Commitments',
                action: CoveRoundButton(
                  icon: Icons.add_rounded,
                  variant: CoveRoundButtonVariant.gold,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(
        find.byKey(const ValueKey('wrap_test_header')),
      );
      expect(rect.height, greaterThan(CovePageHeader.kMinHeight));
    },
  );
}
