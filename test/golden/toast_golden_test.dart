import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_page_header.dart';
import 'package:cove/core/widgets/cove_round_button.dart';
import 'package:cove/core/widgets/cove_row.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:cove/core/widgets/cove_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _ToastShowcase extends StatelessWidget {
  const _ToastShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: CoveToastHost(
        autoDismiss: false,
        initialToast: CoveToastEntry(
          message: 'Expense removed · ₹640',
          undoLabel: 'Undo',
          onUndo: () {},
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CovePageHeader(
                title: 'Expenses',
                readout: 'October',
                action: CoveRoundButton(
                  icon: Icons.add_rounded,
                  variant: CoveRoundButtonVariant.gold,
                  semanticLabel: 'Add expense',
                  onPressed: () {},
                ),
              ),
              const SizedBox(height: CoveSpace.xl + CoveSpace.md),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoveSpace.gutter,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CoveSectionLabel.page(
                      label: 'Today',
                      readout: '2 items',
                    ),
                    const SizedBox(height: CoveSpace.xs),
                    CoveRow(
                      avatar: const CoveAvatar.row(
                        person: CovePerson.b,
                        nameOrInitial: 'Ananya',
                      ),
                      title: 'Nature’s Basket',
                      subtitle: 'Groceries · Today',
                      amount: '₹2,180',
                      onTap: () {},
                    ),
                    CoveRow(
                      avatar: const CoveAvatar.row(
                        person: CovePerson.both,
                      ),
                      title: 'BESCOM Electricity',
                      subtitle: 'Shared utility · Today',
                      amount: '₹3,420',
                      isLast: true,
                      onTap: () {},
                    ),
                    const SizedBox(height: CoveSpace.section),
                    const CoveSectionLabel.page(
                      label: 'Toast without Undo',
                    ),
                    const SizedBox(height: CoveSpace.md),
                    const CoveToast(
                      key: ValueKey('plain_toast'),
                      message: 'Commitment marked paid',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'CoveToast golden matrix (device-anchored position, Undo 48dp hit target, plain variant)',
    (tester) async {
      await goldenMatrix(
        tester,
        'toast',
        const _ToastShowcase(),
      );

      // 1. Active toast drawn pill is anchored at inset (0) + header (56) + CoveSpace.md (12) = 68dp
      final activeToastFinder = find.byKey(
        const ValueKey('active_toast_Expense removed · ₹640'),
      );
      final activePillFinder = find.descendant(
        of: activeToastFinder,
        matching: find.byKey(const ValueKey('cove_toast_pill')),
      );
      final activePillRect = tester.getRect(activePillFinder);
      expect(
        activePillRect.top,
        closeTo(CovePageHeader.kMinHeight + CoveSpace.md, 0.01),
      );

      // 2. Undo button exposes a 48dp (CoveSize.hit) tap target without growing the drawn pill height
      final plainToastFinder = find.byKey(const ValueKey('plain_toast'));
      final plainPillFinder = find.descendant(
        of: plainToastFinder,
        matching: find.byKey(const ValueKey('cove_toast_pill')),
      );
      expect(
        activePillRect.height,
        closeTo(tester.getSize(plainPillFinder).height, 0.01),
      );

      final undoFinder = find.descendant(
        of: activeToastFinder,
        matching: find.byKey(const ValueKey('cove_toast_undo')),
      );
      final undoSize = tester.getSize(undoFinder);
      expect(undoSize.height, equals(CoveSize.hit));
      expect(undoSize.width, greaterThanOrEqualTo(CoveSize.hit));
    },
  );

  testWidgets(
    'CoveToastHost replaces existing toast (never stacks) and respects WCAG 2.2.1 timing',
    (tester) async {
      final hostKey = GlobalKey<CoveToastHostState>();
      var undoCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: coveThemeFor(Brightness.dark),
          home: Scaffold(
            body: CoveToastHost(
              key: hostKey,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );

      // Show first toast, then immediately show second toast -> first is replaced
      hostKey.currentState!.show(
        CoveToastEntry(
          message: 'First toast',
          onUndo: () => undoCount++,
        ),
      );
      await tester.pump();
      expect(find.text('First toast'), findsOneWidget);

      hostKey.currentState!.show(
        CoveToastEntry(
          message: 'Second toast',
          onUndo: () => undoCount++,
        ),
      );
      await tester.pump();
      expect(find.text('First toast'), findsNothing);
      expect(find.text('Second toast'), findsOneWidget);

      // Verify WCAG 2.2.1 duration calculation: pause on focus and extend on screen reader
      expect(
        CoveToast.effectiveDurationFor(
          hasUndo: true,
          accessibleNavigation: false,
          hasFocus: true,
        ),
        isNull,
      );
      expect(
        CoveToast.effectiveDurationFor(
          hasUndo: true,
          accessibleNavigation: true,
          hasFocus: false,
        ),
        equals(CoveToast.kAccessibleUndoDuration),
      );
      expect(
        CoveToast.effectiveDurationFor(
          hasUndo: true,
          accessibleNavigation: false,
          hasFocus: false,
        ),
        equals(CoveToast.kDefaultDuration),
      );
    },
  );
}
