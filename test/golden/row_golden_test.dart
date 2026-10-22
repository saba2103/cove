import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_row.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _RowShowcase extends StatelessWidget {
  const _RowShowcase();

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
              'Rows',
              style: CoveType.title.copyWith(color: cv.textPrimary),
            ),
            const SizedBox(height: CoveSpace.lg),

            // Section 1: Avatar rows (Person A, Person B, Shared Both, Pressed plate)
            const CoveSectionLabel.page(
              label: 'With Avatar & Hit Plate',
              readout: '4 items',
            ),
            const SizedBox(height: CoveSpace.xs),
            CoveRow(
              key: const ValueKey('row_person_a'),
              avatar: const CoveAvatar.row(
                person: CovePerson.a,
                nameOrInitial: 'Saba',
              ),
              title: 'Blue Tokai Coffee',
              subtitle: 'Eating out · Today',
              amount: '₹640',
              onTap: () {},
            ),
            CoveRow(
              key: const ValueKey('row_person_b_pressed'),
              avatar: const CoveAvatar.row(
                person: CovePerson.b,
                nameOrInitial: 'Ananya',
              ),
              title: 'Nature’s Basket',
              subtitle: 'Groceries · Pressed hit plate',
              amount: '₹2,180',
              isPressed: true,
              onTap: () {},
            ),
            CoveRow(
              key: const ValueKey('row_person_both'),
              avatar: const CoveAvatar.row(
                person: CovePerson.both,
              ),
              title: 'BESCOM Electricity',
              subtitle: 'Shared utility · 18 Oct',
              amount: '₹3,420',
              onTap: () {},
            ),
            CoveRow(
              key: const ValueKey('row_single_line_avatar'),
              avatar: const CoveAvatar.row(
                person: CovePerson.a,
                nameOrInitial: 'Saba',
              ),
              title: 'Single-line row with avatar',
              amount: '₹950',
              isLast: true,
              onTap: () {},
            ),

            const SizedBox(height: CoveSpace.section),

            // Section 2: No-avatar rows & semantic money.more / money.less tones
            const CoveSectionLabel.page(
              label: 'No Avatar & Signed Deltas',
              readout: '3 items',
            ),
            const SizedBox(height: CoveSpace.xs),
            CoveRow(
              key: const ValueKey('row_no_avatar'),
              title: 'No avatar starts at gutter',
              subtitle: 'Divider aligns to 0dp text edge',
              amount: '₹12,500',
              onTap: () {},
            ),
            CoveRow(
              key: const ValueKey('row_money_more'),
              title: 'Eating out vs September',
              subtitle: 'Spending up',
              amount: '+₹2,400',
              amountTone: CoveRowAmountTone.more,
              onTap: () {},
            ),
            CoveRow(
              key: const ValueKey('row_money_less_last'),
              title: 'Travel vs September',
              subtitle: 'Spending down · Last row (no divider)',
              amount: '−₹1,800',
              amountTone: CoveRowAmountTone.less,
              isLast: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  testWidgets(
    'CoveRow golden matrix (avatar, no-avatar, pressed hit plate, divider inset, last row, money tones)',
    (tester) async {
      await goldenMatrix(
        tester,
        'row',
        const _RowShowcase(),
      );

      // 1. Every standard row (with avatar, without avatar, 1-line, 2-line, last) is 52dp (CoveSize.row)
      for (final key in const [
        ValueKey('row_person_a'),
        ValueKey('row_person_b_pressed'),
        ValueKey('row_person_both'),
        ValueKey('row_single_line_avatar'),
        ValueKey('row_no_avatar'),
        ValueKey('row_money_more'),
        ValueKey('row_money_less_last'),
      ]) {
        expect(
          tester.getSize(find.byKey(key)).height,
          equals(CoveSize.row),
          reason: '$key should have height CoveSize.row (52.0)',
        );
      }

      // 2. Pressed hit plate bleeds -CoveSpace.hitPlate (-12dp) past the row's left & right edges
      final pressedRowFinder = find.byKey(const ValueKey('row_person_b_pressed'));
      final pressedRowRect = tester.getRect(pressedRowFinder);
      final plateFinder = find.descendant(
        of: pressedRowFinder,
        matching: find.byType(AnimatedContainer),
      );
      final plateRect = tester.getRect(plateFinder);
      expect(
        pressedRowRect.left - plateRect.left,
        closeTo(CoveSpace.hitPlate, 0.01),
      );
      expect(
        plateRect.right - pressedRowRect.right,
        closeTo(CoveSpace.hitPlate, 0.01),
      );

      // 3. Divider is inset to the text edge (28dp avatar + 12dp gap = 40dp) when avatar is present
      final avatarRowFinder = find.byKey(const ValueKey('row_person_a'));
      final avatarRowRect = tester.getRect(avatarRowFinder);
      final avatarDividerFinder = find.descendant(
        of: avatarRowFinder,
        matching: find.byType(ColoredBox),
      );
      final avatarDividerRect = tester.getRect(avatarDividerFinder);
      expect(
        avatarDividerRect.left - avatarRowRect.left,
        closeTo(CoveSize.avatarRow + CoveSpace.md, 0.01),
      );

      // 4. Divider starts at 0dp (the gutter text edge) when no avatar is present
      final noAvatarRowFinder = find.byKey(const ValueKey('row_no_avatar'));
      final noAvatarRowRect = tester.getRect(noAvatarRowFinder);
      final noAvatarDividerFinder = find.descendant(
        of: noAvatarRowFinder,
        matching: find.byType(ColoredBox),
      );
      final noAvatarDividerRect = tester.getRect(noAvatarDividerFinder);
      expect(
        noAvatarDividerRect.left - noAvatarRowRect.left,
        closeTo(0.0, 0.01),
      );

      // 5. Last row has no divider underneath
      final lastRowFinder = find.byKey(const ValueKey('row_money_less_last'));
      expect(
        find.descendant(
          of: lastRowFinder,
          matching: find.byType(ColoredBox),
        ),
        findsNothing,
      );
    },
  );
}
