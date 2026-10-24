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
                actions: [
                  CoveRoundButton(
                    key: const ValueKey('btn_add_commitments'),
                    icon: Icons.add_rounded,
                    variant: CoveRoundButtonVariant.gold,
                    semanticLabel: 'Add commitment',
                    onPressed: () {},
                  ),
                ],
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
                actions: [
                  CoveRoundButton(
                    icon: Icons.add_rounded,
                    variant: CoveRoundButtonVariant.gold,
                    semanticLabel: 'Add transaction',
                    onPressed: () {},
                  ),
                ],
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
                actions: [
                  CoveRoundButton(
                    icon: Icons.notifications_none_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Notifications',
                    onPressed: () {},
                  ),
                ],
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
            const SizedBox(height: CoveSpace.sm),

            // 6. Calendar: Month + Year + Three 40dp Actions (2 ghost chevrons + gold add)
            buildHeaderSlot(
              label: '6 · Three Actions (Month Chevrons + Gold Add)',
              header: CovePageHeader(
                key: const ValueKey('header_calendar'),
                title: 'October',
                readout: '2026',
                actions: [
                  CoveRoundButton(
                    key: const ValueKey('btn_cal_prev'),
                    icon: Icons.chevron_left_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Previous month',
                    onPressed: () {},
                  ),
                  CoveRoundButton(
                    key: const ValueKey('btn_cal_next'),
                    icon: Icons.chevron_right_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Next month',
                    onPressed: () {},
                  ),
                  CoveRoundButton(
                    key: const ValueKey('btn_cal_add'),
                    icon: Icons.add_rounded,
                    variant: CoveRoundButtonVariant.gold,
                    semanticLabel: 'Add',
                    onPressed: () {},
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
                actions: [
                  CoveRoundButton(
                    icon: Icons.add_rounded,
                    variant: CoveRoundButtonVariant.gold,
                    onPressed: () {},
                  ),
                ],
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

  testWidgets(
    'Calendar header at 320dp: "October" + "2026" + three 40dp buttons fits without wrapping or ellipsizing',
    (tester) async {
      await loadCoveFonts();
      await tester.pumpWidget(
        MaterialApp(
          theme: coveThemeFor(Brightness.dark),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: CovePageHeader(
                key: const ValueKey('cal_320_header'),
                title: 'October',
                readout: '2026',
                actions: [
                  CoveRoundButton(
                    key: const ValueKey('cal_320_prev'),
                    icon: Icons.chevron_left_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Previous month',
                    onPressed: () {},
                  ),
                  CoveRoundButton(
                    key: const ValueKey('cal_320_next'),
                    icon: Icons.chevron_right_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Next month',
                    onPressed: () {},
                  ),
                  CoveRoundButton(
                    key: const ValueKey('cal_320_add'),
                    icon: Icons.add_rounded,
                    variant: CoveRoundButtonVariant.gold,
                    semanticLabel: 'Add',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final headerRect = tester.getRect(
        find.byKey(const ValueKey('cal_320_header')),
      );
      final titleFinder = find.text('October');
      final readoutFinder = find.text('2026');
      final titleRect = tester.getRect(titleFinder);
      final readoutRect = tester.getRect(readoutFinder);
      final titleParagraph = tester.renderObject<RenderParagraph>(titleFinder);

      final prevCircle = find.descendant(
        of: find.byKey(const ValueKey('cal_320_prev')),
        matching: find.byType(DecoratedBox),
      );
      final nextCircle = find.descendant(
        of: find.byKey(const ValueKey('cal_320_next')),
        matching: find.byType(DecoratedBox),
      );
      final addCircle = find.descendant(
        of: find.byKey(const ValueKey('cal_320_add')),
        matching: find.byType(DecoratedBox),
      );
      final prevRect = tester.getRect(prevCircle.first);
      final nextRect = tester.getRect(nextCircle.first);
      final addRect = tester.getRect(addCircle.first);

      // Header stays single-line (56dp tall)
      expect(headerRect.height, equals(CovePageHeader.kMinHeight));

      // Title "October" does not wrap (36dp single line box) or ellipsize
      expect(titleRect.height, equals(36.0));
      expect(titleParagraph.didExceedMaxLines, isFalse);
      expect(
        titleRect.width,
        closeTo(titleParagraph.getMaxIntrinsicWidth(double.infinity), 0.01),
      );

      // Three 40dp drawn circles separated by CoveSpace.sm (8dp), flush to 20dp gutter
      expect(prevRect.width, equals(CoveSize.buttonRound));
      expect(nextRect.width, equals(CoveSize.buttonRound));
      expect(addRect.width, equals(CoveSize.buttonRound));
      expect(nextRect.left - prevRect.right, closeTo(CoveSpace.sm, 0.01));
      expect(addRect.left - nextRect.right, closeTo(CoveSpace.sm, 0.01));
      expect(headerRect.right - addRect.right, closeTo(CoveSpace.gutter, 0.01));
      expect(readoutRect.left - titleRect.right, closeTo(CoveSpace.md, 0.01));

      // Every header action has a full 48x48 hit target
      expect(
        tester.getSize(find.byKey(const ValueKey('cal_320_prev'))),
        equals(const Size(CoveSize.hit, CoveSize.hit)),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('cal_320_next'))),
        equals(const Size(CoveSize.hit, CoveSize.hit)),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('cal_320_add'))),
        equals(const Size(CoveSize.hit, CoveSize.hit)),
      );
    },
  );
}
