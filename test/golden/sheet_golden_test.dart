import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_metric_card.dart';
import 'package:cove/core/widgets/cove_page_header.dart';
import 'package:cove/core/widgets/cove_round_button.dart';
import 'package:cove/core/widgets/cove_row.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:cove/core/widgets/cove_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _SheetShowcase extends StatelessWidget {
  const _SheetShowcase();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    final backgroundPage = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CovePageHeader(
          title: 'Expenses',
          readout: 'October',
          actions: [
            CoveRoundButton(
              icon: Icons.add_rounded,
              variant: CoveRoundButtonVariant.gold,
              semanticLabel: 'Add expense',
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: CoveSpace.md),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
          child: CoveMetricGrid(
            children: [
              CoveMetricCard(
                label: 'Spent this month',
                value: '₹38,420',
                subtitle: 'Across 24 expenses',
              ),
              CoveMetricCard(
                label: 'Shared split',
                value: '₹19,210',
                subtitle: 'Each partner’s share',
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: CoveSheetBackdrop(
        background: backgroundPage,
        sheet: CoveSheet(
          key: const ValueKey('primary_sheet'),
          title: 'Blue Tokai Coffee',
          onClose: () {},
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoveSectionLabel.card(
                label: 'Expense detail · Identical 32/40 radii when stacked',
              ),
            ],
          ),
        ),
        stackedSheet: CoveSheet(
          key: const ValueKey('stacked_sheet'),
          title: 'Paid by',
          onClose: () {},
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoveRow(
                avatar: const CoveAvatar.row(
                  person: CovePerson.a,
                  nameOrInitial: 'Saba',
                ),
                title: 'Saba',
                subtitle: 'Home creator',
                amount: '₹640',
                onTap: () {},
              ),
              CoveRow(
                avatar: const CoveAvatar.row(
                  person: CovePerson.b,
                  nameOrInitial: 'Ananya',
                ),
                title: 'Ananya',
                subtitle: 'Partner',
                amount: '₹0',
                onTap: () {},
              ),
              CoveRow(
                avatar: const CoveAvatar.row(
                  person: CovePerson.both,
                ),
                title: 'Split equally',
                subtitle: '₹320 each',
                amount: '₹640',
                isLast: true,
                onTap: () {},
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
    'CoveSheet golden matrix (scrim, 36x4 handle, 32dp top / 40dp bottom radii, sheet over sheet)',
    (tester) async {
      await goldenMatrix(
        tester,
        'sheet',
        const _SheetShowcase(),
      );

      // 1. Verify grab handle is 36 x 4 and horizontally centred on both sheets
      final handles = find.byKey(const ValueKey('cove_sheet_grab_handle'));
      expect(handles, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final handleSize = tester.getSize(handles.at(i));
        expect(
          handleSize,
          equals(
            const Size(
              CoveSheet.kGrabHandleWidth,
              CoveSheet.kGrabHandleHeight,
            ),
          ),
        );
      }

      // 2. Verify both primary and stacked sheet use CoveRadius.sheet (32) top & CoveRadius.device (40) bottom
      for (final sheetKey in const [
        ValueKey('primary_sheet'),
        ValueKey('stacked_sheet'),
      ]) {
        final containerFinder = find.descendant(
          of: find.byKey(sheetKey),
          matching: find.byType(Container),
        );
        final sheetContainer = tester.widget<Container>(containerFinder.first);
        final decoration = sheetContainer.decoration! as BoxDecoration;
        expect(
          decoration.borderRadius,
          equals(
            const BorderRadius.only(
              topLeft: Radius.circular(CoveRadius.sheet),
              topRight: Radius.circular(CoveRadius.sheet),
              bottomLeft: Radius.circular(CoveRadius.device),
              bottomRight: Radius.circular(CoveRadius.device),
            ),
          ),
        );
      }
    },
  );

  testWidgets(
    'CoveSheet dismisses on scrim tap and drag unless isMidCommit is true',
    (tester) async {
      var dismissedCount = 0;

      // 1. Dismissable (isMidCommit: false)
      await tester.pumpWidget(
        MaterialApp(
          theme: coveThemeFor(Brightness.dark),
          home: Scaffold(
            body: CoveSheetBackdrop(
              background: const SizedBox.expand(),
              onScrimTap: () => dismissedCount++,
              sheet: CoveSheet(
                key: const ValueKey('test_sheet'),
                title: 'Add Expense',
                onDismiss: () => dismissedCount++,
                child: const SizedBox(height: 120),
              ),
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(20, 20));
      await tester.pump();
      expect(dismissedCount, equals(1));

      await tester.drag(
        find.byKey(const ValueKey('test_sheet')),
        const Offset(0, 120),
      );
      await tester.pump();
      expect(dismissedCount, greaterThanOrEqualTo(2));

      // 2. Mid-commit (isMidCommit: true) blocks both scrim tap and drag dismissal
      final countBeforeMidCommit = dismissedCount;
      await tester.pumpWidget(
        MaterialApp(
          theme: coveThemeFor(Brightness.dark),
          home: Scaffold(
            body: CoveSheetBackdrop(
              background: const SizedBox.expand(),
              isMidCommit: true,
              onScrimTap: () => dismissedCount++,
              sheet: CoveSheet(
                key: const ValueKey('test_sheet_locked'),
                title: 'Saving…',
                isMidCommit: true,
                onDismiss: () => dismissedCount++,
                child: const SizedBox(height: 120),
              ),
            ),
          ),
        ),
      );

      await tester.tapAt(const Offset(20, 20));
      await tester.drag(
        find.byKey(const ValueKey('test_sheet_locked')),
        const Offset(0, 120),
      );
      await tester.pump();
      expect(dismissedCount, equals(countBeforeMidCommit));
    },
  );
}
