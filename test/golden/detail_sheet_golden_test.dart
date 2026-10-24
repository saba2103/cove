import 'dart:math' as math;

import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/utils/cove_currency_formatter.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_detail_sheet.dart';
import 'package:cove/core/widgets/cove_metric_card.dart';
import 'package:cove/core/widgets/cove_page_header.dart';
import 'package:cove/core/widgets/cove_round_button.dart';
import 'package:cove/core/widgets/slips/cove_habit_card.dart';
import 'package:cove/core/widgets/slips/cove_receipt.dart';
import 'package:cove/core/widgets/slips/cove_slip.dart';
import 'package:cove/core/widgets/slips/cove_voucher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _DetailSheetBackdropShowcase extends StatelessWidget {
  final String pageTitle;
  final String pageReadout;
  final CoveDetailSheet detailSheet;

  const _DetailSheetBackdropShowcase({
    required this.pageTitle,
    required this.pageReadout,
    required this.detailSheet,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    final backgroundPage = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CovePageHeader(
          title: pageTitle,
          readout: pageReadout,
          actions: [
            CoveRoundButton(
              icon: Icons.add_rounded,
              variant: CoveRoundButtonVariant.gold,
              semanticLabel: 'Add',
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          backgroundPage,
          ColoredBox(color: cv.surfaceScrim),
          Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: CoveSize.maxContent),
              child: detailSheet,
            ),
          ),
        ],
      ),
    );
  }
}

/// Half-filled 24dp split circle glyph matching `design/screens/detail-sheets.png`.
class _HalfSplitGlyph extends StatelessWidget {
  const _HalfSplitGlyph();

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    return CustomPaint(
      size: const Size.square(CoveDetailSheet.kMeaningGlyphSize),
      painter: _HalfSplitGlyphPainter(
        fillColor: cv.accentTint,
        strokeColor: cv.accentTint,
      ),
    );
  }
}

class _HalfSplitGlyphPainter extends CustomPainter {
  final Color fillColor;
  final Color strokeColor;

  const _HalfSplitGlyphPainter({
    required this.fillColor,
    required this.strokeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final deflated = rect.deflate(1.5);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawArc(deflated, math.pi / 2.0, math.pi, true, fillPaint);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(deflated, strokePaint);
  }

  @override
  bool shouldRepaint(_HalfSplitGlyphPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeColor != strokeColor;
}

CoveDetailSheet _buildExpenseDetailSheet({
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  return CoveDetailSheet(
    key: const ValueKey('detail_sheet_expense'),
    kindGlyph: const Text('₹'),
    kindLabel: 'EXPENSE',
    contextLabel: 'EATING OUT',
    slip: CoveReceipt(
      key: const ValueKey('expense_slip'),
      variant: CoveSlipVariant.paper,
      recordId: 'expense-toit-2026-10-05',
      title: 'Toit',
      subtitle: 'INDIRANAGAR · 8:40 PM',
      items: [
        CoveReceiptItem(
          payer: CovePerson.b,
          nameOrInitial: 'Ancy',
          title: 'Dinner & craft beer',
          subtitle: 'Eating out · HDFC Regalia',
          amount: '₹${formatCoveAmount(1450)}',
        ),
      ],
      totalAmount: '₹${formatCoveAmount(1450)}',
      split: CoveReceiptSplit(
        viewerName: 'You',
        viewerAmount: '₹${formatCoveAmount(725)}',
        partnerName: 'Ancy',
        partnerAmount: '₹${formatCoveAmount(725)}',
        viewerShare: 0.5,
      ),
      footerDate: 'MON 5 OCT',
    ),
    meaningPanel: const CoveDetailMeaningPanel(
      glyph: _HalfSplitGlyph(),
      title: '₹725 is your half',
      subtitle: 'Ancy paid',
    ),
    editVerb: CoveDetailVerb(
      label: 'Edit',
      icon: Icons.edit_outlined,
      onPressed: onEdit ?? () {},
    ),
    menuItems: [
      CoveDetailMenuItem(
        label: 'Delete this expense',
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
        onSelected: onDelete ?? () {},
      ),
    ],
  );
}

CoveDetailSheet _buildHabitDetailSheet() {
  const cells = <bool>[
    true, true, true, false, true, true, true,
    true, true, false, true, true, true, true,
    true, true, true, true, true, true, true,
  ];
  return CoveDetailSheet(
    key: const ValueKey('detail_sheet_habit'),
    kindGlyph: const Icon(Icons.repeat_rounded),
    kindLabel: 'HABIT',
    contextLabel: 'EVERY MORNING',
    slip: CoveHabitCard(
      key: const ValueKey('habit_slip'),
      variant: CoveSlipVariant.paper,
      title: 'Morning walk',
      cadence: 'Every morning · Cubbon Park loop',
      isDoneToday: true,
      history21: cells,
      daysRunning: 23,
      onToggle: (_) {},
    ),
    meaningPanel: CoveDetailMeaningPanel.icon(
      icon: Icons.local_fire_department_outlined,
      title: '23 days running',
      subtitle: 'Best 31 · Every morning',
    ),
    editVerb: CoveDetailVerb(
      label: 'Edit',
      icon: Icons.edit_outlined,
      onPressed: () {},
    ),
    secondaryVerb: CoveDetailVerb(
      label: 'Undo check-in',
      icon: Icons.undo_rounded,
      onPressed: () {},
    ),
    menuItems: [
      CoveDetailMenuItem(
        label: 'Delete this habit',
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
        onSelected: () {},
      ),
    ],
  );
}

CoveDetailSheet _buildEmiDetailSheet() {
  return CoveDetailSheet(
    key: const ValueKey('detail_sheet_emi'),
    kindGlyph: const Icon(Icons.event_repeat_rounded),
    kindLabel: 'COMMITMENT',
    contextLabel: 'EVERY MONTH',
    slip: CoveVoucher(
      key: const ValueKey('emi_slip'),
      variant: CoveSlipVariant.paper,
      title: 'Car loan — HDFC',
      amount: '₹${formatCoveAmount(18450)}',
      dueDay: '22',
      dueMonth: 'OCT',
      dueMonthSemantic: 'October',
      state: CoveVoucherState.due,
      totalInstallments: 48,
      paidInstallments: 12,
    ),
    meaningPanel: CoveDetailMeaningPanel.icon(
      icon: Icons.donut_large_outlined,
      title: '12 of 48 paid',
      subtitle: 'Ends Oct 2029 · ₹6,64,200 left',
    ),
    editVerb: CoveDetailVerb(
      label: 'Edit',
      icon: Icons.edit_outlined,
      onPressed: () {},
    ),
    secondaryVerb: CoveDetailVerb(
      label: 'Mark paid',
      icon: Icons.check_circle_outline_rounded,
      onPressed: () {},
    ),
    menuItems: [
      CoveDetailMenuItem(
        label: 'Foreclose this EMI',
        onSelected: () {},
      ),
      CoveDetailMenuItem(
        label: 'Delete this commitment',
        isDestructive: true,
        onSelected: () {},
      ),
    ],
  );
}

void main() {
  testWidgets(
    'CoveDetailSheet golden matrix (expense, habit, and EMI fillings in both modes)',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await goldenMatrix(
          tester,
          'detail_sheet_expense',
          _DetailSheetBackdropShowcase(
            pageTitle: 'Expenses',
            pageReadout: 'October',
            detailSheet: _buildExpenseDetailSheet(),
          ),
        );

        await goldenMatrix(
          tester,
          'detail_sheet_habit',
          _DetailSheetBackdropShowcase(
            pageTitle: 'Habits',
            pageReadout: 'Today',
            detailSheet: _buildHabitDetailSheet(),
          ),
        );

        await goldenMatrix(
          tester,
          'detail_sheet_emi',
          _DetailSheetBackdropShowcase(
            pageTitle: 'Commitments',
            pageReadout: 'October',
            detailSheet: _buildEmiDetailSheet(),
          ),
        );
      } finally {
        semanticsHandle.dispose();
      }
    },
  );

  testWidgets(
    'CoveDetailSheet kind line wraps and never ellipsizes at 320dp cover width with "COMMITMENT · EVERY MONTH" and "EXPENSE · EATING OUT"',
    (tester) async {
      tester.view
        ..physicalSize = CoveWidth.cover * 2
        ..devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final sheet in <CoveDetailSheet>[
        _buildEmiDetailSheet(),
        _buildExpenseDetailSheet(),
      ]) {
        final expectedText =
            '${sheet.kindLabel} · ${sheet.contextLabel}';

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: CoveWidth.cover,
              textScaler: TextScaler.linear(1.0),
            ),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: coveThemeFor(Brightness.dark),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: sheet,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. No ✓ in the kind line
        expect(find.byIcon(Icons.check), findsNothing);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        expect(find.text('✓'), findsNothing);

        // 2. Kind text matches full expected string and never ellipsizes
        final kindTextFinder = find.byKey(
          const ValueKey('cove_detail_sheet_kind_text'),
        );
        expect(kindTextFinder, findsOneWidget);
        final textWidget = tester.widget<Text>(kindTextFinder);
        expect(
          textWidget.textSpan!.toPlainText(),
          equals(expectedText),
        );
        expect(textWidget.maxLines, isNull);
        expect(textWidget.overflow, isNot(equals(TextOverflow.ellipsis)));

        final renderParagraph =
            tester.renderObject<RenderParagraph>(kindTextFinder);
        expect(
          renderParagraph.didExceedMaxLines,
          isFalse,
          reason: '$expectedText must never be truncated or ellipsized',
        );
        final painter = TextPainter(
          text: renderParagraph.text,
          textDirection: TextDirection.ltr,
          textScaler: renderParagraph.textScaler,
        )..layout(maxWidth: renderParagraph.size.width);
        final lines = painter.computeLineMetrics();
        expect(
          lines.length,
          greaterThanOrEqualTo(2),
          reason:
              'At 320dp cover width, "$expectedText" must wrap onto a second line (width: ${renderParagraph.size.width})',
        );
      }
    },
  );

  testWidgets(
    'CoveDetailSheet semantics read slip state first, then meaning panel, and overflow menu dispatches actions',
    (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        var deleted = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: coveThemeFor(Brightness.dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: _buildExpenseDetailSheet(
                  onDelete: () => deleted = true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final slipSem = tester.getSemantics(
          find.byKey(const ValueKey('expense_slip')),
        );
        final meaningSem = tester.getSemantics(
          find.byKey(const ValueKey('cove_detail_sheet_meaning_panel')),
        );
        expect(
          slipSem.label,
          equals('Receipt, Toit, total ₹1,450, 1 item'),
        );
        expect(
          meaningSem.label,
          equals('₹725 is your half, Ancy paid'),
        );

        // Verify traversal order: slip appears before meaning panel in semantics traversal
        final orderedLabels = <String>[];
        void collectLabels(SemanticsNode node) {
          if (node.label.isNotEmpty) {
            orderedLabels.add(node.label);
          }
          node.visitChildren((child) {
            collectLabels(child);
            return true;
          });
        }

        collectLabels(
          tester.getSemantics(find.byType(Scaffold)),
        );
        final slipIdx = orderedLabels.indexWhere(
          (l) => l.contains('Receipt, Toit, total ₹1,450, 1 item'),
        );
        final meaningIdx = orderedLabels.indexWhere(
          (l) => l.contains('₹725 is your half, Ancy paid'),
        );
        expect(slipIdx, isNonNegative);
        expect(meaningIdx, greaterThan(slipIdx));

        // Open ⋯ menu and select destructive action
        await tester.tap(
          find.byKey(const ValueKey('cove_detail_sheet_menu_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Delete this expense'), findsOneWidget);
        await tester.tap(find.text('Delete this expense'));
        await tester.pumpAndSettle();
        expect(deleted, isTrue);
      } finally {
        semanticsHandle.dispose();
      }
    },
  );
}
