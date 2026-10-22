import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_round_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _RoundButtonShowcase extends StatelessWidget {
  const _RoundButtonShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    Widget buildStateRow({
      required String label,
      required String subtitle,
      required List<Widget> buttons,
    }) {
      return Container(
        padding: const EdgeInsets.all(CoveSpace.gutter),
        decoration: BoxDecoration(
          color: cv.surfaceCard,
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.card),
          ),
          border: Border.all(color: cv.lineHairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                  ),
                  const SizedBox(height: CoveSpace.xs),
                  Text(
                    subtitle,
                    style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: CoveSpace.md),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: buttons,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: Padding(
        padding: const EdgeInsets.all(CoveSpace.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COVE ROUND BUTTON',
              style: CoveType.capsPage.copyWith(color: cv.accentText),
            ),
            const SizedBox(height: CoveSpace.xs),
            Text(
              'Circular Actions',
              style: CoveType.title.copyWith(color: cv.textPrimary),
            ),
            const SizedBox(height: CoveSpace.lg),

            // 1. Gold variant (Add) — rest & pressed
            buildStateRow(
              label: 'Gold variant (Add)',
              subtitle: '40dp drawn · 48dp hit · rest & pressed',
              buttons: [
                CoveRoundButton(
                  key: const ValueKey('gold_rest'),
                  icon: Icons.add_rounded,
                  variant: CoveRoundButtonVariant.gold,
                  semanticLabel: 'Add',
                  onPressed: () {},
                ),
                const SizedBox(width: CoveSpace.sm),
                CoveRoundButton(
                  key: const ValueKey('gold_pressed'),
                  icon: Icons.add_rounded,
                  variant: CoveRoundButtonVariant.gold,
                  isPressed: true,
                  semanticLabel: 'Add (pressed)',
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.md),

            // 2. Ghost variant (Back, Close, Actions) — rest & pressed
            buildStateRow(
              label: 'Ghost variant',
              subtitle: '1dp line.strong · rest & pressed',
              buttons: [
                CoveRoundButton(
                  key: const ValueKey('ghost_back'),
                  icon: Icons.arrow_back_rounded,
                  variant: CoveRoundButtonVariant.ghost,
                  semanticLabel: 'Back',
                  onPressed: () {},
                ),
                const SizedBox(width: CoveSpace.xs),
                CoveRoundButton(
                  key: const ValueKey('ghost_close'),
                  icon: Icons.close_rounded,
                  variant: CoveRoundButtonVariant.ghost,
                  semanticLabel: 'Close',
                  onPressed: () {},
                ),
                const SizedBox(width: CoveSpace.xs),
                CoveRoundButton(
                  key: const ValueKey('ghost_pressed'),
                  icon: Icons.tune_rounded,
                  variant: CoveRoundButtonVariant.ghost,
                  isPressed: true,
                  semanticLabel: 'Filter (pressed)',
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.md),

            // 3. Inline stepper chevrons (24dp sibling, no 48dp hit expansion)
            buildStateRow(
              label: 'Inline stepper chevrons',
              subtitle: '24dp drawn · 24dp hit · rest & pressed',
              buttons: [
                CoveRoundButton.stepper(
                  key: const ValueKey('stepper_prev'),
                  icon: Icons.chevron_left_rounded,
                  semanticLabel: 'Previous',
                  onPressed: () {},
                ),
                const SizedBox(width: CoveSpace.sm),
                CoveRoundButton.stepper(
                  key: const ValueKey('stepper_next'),
                  icon: Icons.chevron_right_rounded,
                  semanticLabel: 'Next',
                  onPressed: () {},
                ),
                const SizedBox(width: CoveSpace.sm),
                CoveRoundButton.stepper(
                  key: const ValueKey('stepper_pressed'),
                  icon: Icons.chevron_right_rounded,
                  isPressed: true,
                  semanticLabel: 'Next (pressed)',
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'CoveRoundButton golden matrix (gold, ghost, pressed, stepper)',
    (tester) async {
      await goldenMatrix(
        tester,
        'round_button',
        const _RoundButtonShowcase(),
      );

      // Verify 48dp hit target and 40dp drawn circle on standard button
      final goldFinder = find.byKey(const ValueKey('gold_rest'));
      expect(
        tester.getSize(goldFinder),
        equals(const Size(CoveSize.hit, CoveSize.hit)),
      );
      final drawnDecoratedBoxes = find.descendant(
        of: goldFinder,
        matching: find.byType(DecoratedBox),
      );
      expect(
        tester.getSize(drawnDecoratedBoxes.first),
        equals(const Size(CoveSize.buttonRound, CoveSize.buttonRound)),
      );

      // Verify 24dp stepper sibling does not carry the 48dp target
      final stepperFinder = find.byKey(const ValueKey('stepper_prev'));
      expect(
        tester.getSize(stepperFinder),
        equals(const Size(24.0, 24.0)),
      );
    },
  );

  testWidgets(
    'CoveRoundButton responds to taps inside the 48dp outer hit expansion ring',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: coveThemeFor(Brightness.dark),
          home: Scaffold(
            body: Center(
              child: CoveRoundButton(
                key: const ValueKey('hit_test_btn'),
                icon: Icons.add_rounded,
                variant: CoveRoundButtonVariant.gold,
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      final rect = tester.getRect(find.byKey(const ValueKey('hit_test_btn')));
      expect(rect.size, equals(const Size(CoveSize.hit, CoveSize.hit)));

      // Tap 2dp inside the top-left corner of the 48dp hit box (outside the 40dp circle)
      await tester.tapAt(rect.topLeft + const Offset(2, 2));
      await tester.pump();
      expect(tapped, isTrue);
    },
  );
}
