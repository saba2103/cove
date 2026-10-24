import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/utils/cove_currency_formatter.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_detail_sheet.dart';
import 'package:cove/core/widgets/cove_metric_card.dart';
import 'package:cove/core/widgets/cove_page_header.dart';
import 'package:cove/core/widgets/cove_round_button.dart';
import 'package:cove/core/widgets/slips/cove_dial.dart';
import 'package:cove/core/widgets/slips/cove_habit_card.dart';
import 'package:cove/core/widgets/slips/cove_receipt.dart';
import 'package:cove/core/widgets/slips/cove_slip.dart';
import 'package:cove/core/widgets/slips/cove_voucher.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/category_detail_sheet.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/expenses/expense_detail_sheet.dart';
import 'package:cove/features/habits/habit_detail_sheet.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    'CoveDetailSheet kind line never ellipsizes or overflows at 320dp cover width with "COMMITMENT · EVERY MONTH" and "EXPENSE · EATING OUT"',
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
        expect(tester.takeException(), isNull);

        // 1. No ✓ in the kind line
        expect(find.byIcon(Icons.check), findsNothing);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        expect(find.text('✓'), findsNothing);

        // 2. Kind text matches full expected string and never ellipsizes or overflows
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

  testWidgets(
    'ExpenseDetailSheet renders shared 50/50, shared custom split, and private meaning panels using computeExpenseShare',
    (tester) async {
      final fixedDate = DateTime(2026, 10, 15, 19, 30);
      final seedHome = LocalHome(
        id: 'home_1',
        name: 'Our Home',
        currency: 'INR',
        createdAt: fixedDate,
        createdBy: 'user_alex',
      );

      LocalExpense makeExpense({
        required double splitRatio,
        required String paidBy,
      }) {
        return LocalExpense(
          id: 'exp_test',
          homeId: 'home_1',
          title: 'Toit',
          amount: 1450.0,
          currency: 'INR',
          category: 'Eating out',
          paidBy: paidBy,
          splitRatio: splitRatio,
          expenseDate: fixedDate,
          paymentMethod: '[Card] Craft beer & pizza',
          isTransfer: false,
          createdAt: fixedDate,
        );
      }

      Widget buildHarness(LocalExpense expense) {
        return ProviderScope(
          overrides: [
            activeHomeProvider.overrideWith((ref) => Stream.value(seedHome)),
            currencyPreferenceProvider.overrideWith(_TestCurrencyNotifier.new),
            authProvider.overrideWith(_TestAuthNotifier.new),
            partnerProfileProvider.overrideWith(
              _TestPartnerProfileNotifier.new,
            ),
          ],
          child: MaterialApp(
            theme: coveThemeFor(Brightness.dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: ExpenseDetailSheet(expense: expense),
              ),
            ),
          ),
        );
      }

      // 1. 50/50 shared expense paid by partner -> "₹725 is your half" + "Ancy paid"
      await tester.pumpWidget(
        buildHarness(makeExpense(splitRatio: 0.5, paidBy: 'user_partner')),
      );
      await tester.pumpAndSettle();
      expect(find.text('₹725 is your half'), findsOneWidget);
      expect(find.text('Ancy paid'), findsOneWidget);

      // 2. 70/30 custom shared expense paid by viewer -> "₹1,015 is your share" + "You paid"
      await tester.pumpWidget(
        buildHarness(makeExpense(splitRatio: 0.7, paidBy: 'user_alex')),
      );
      await tester.pumpAndSettle();
      expect(find.text('₹1,015 is your share'), findsOneWidget);
      expect(find.text('You paid'), findsOneWidget);

      // 3. Private expense (splitRatio <= 0) -> "Yours alone" + "Not part of the shared total"
      for (final ratio in <double>[-1.0, 0.0]) {
        final share = computeExpenseShare(
          makeExpense(splitRatio: ratio, paidBy: 'user_alex'),
          currentUserId: 'user_alex',
        );
        expect(share.isShared, isFalse);

        await tester.pumpWidget(
          buildHarness(makeExpense(splitRatio: ratio, paidBy: 'user_alex')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Yours alone'), findsOneWidget);
        expect(find.text('Not part of the shared total'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'HabitDetailSheet renders meaning panel, Check in / Undo check-in verb, and overflow menu items',
    (tester) async {
      final fixedDate = DateTime(2026, 10, 15, 10, 30);
      final habit = LocalHabit(
        id: 'habit_1',
        homeId: 'home_1',
        name: 'Morning Walk Together',
        cadence: 'daily',
        targetDaysPerWeek: 7,
        isArchived: false,
        createdAt: fixedDate,
        createdBy: 'user_alex',
      );
      final checkins = <LocalHabitCheckin>[
        LocalHabitCheckin(
          id: 'chk_1',
          homeId: 'home_1',
          habitId: 'habit_1',
          checkinDate: '2026-10-14',
          memberId: 'user_alex',
          createdAt: fixedDate,
        ),
        LocalHabitCheckin(
          id: 'chk_2',
          homeId: 'home_1',
          habitId: 'habit_1',
          checkinDate: '2026-10-15',
          memberId: 'user_alex',
          createdAt: fixedDate,
        ),
      ];

      await withClock(Clock.fixed(fixedDate), () async {
        // 1. Checked-in viewer habit -> "2 days running", "Best 2 · Daily", and "Undo check-in" verb
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_TestAuthNotifier.new),
              partnerProfileProvider.overrideWith(
                _TestPartnerProfileNotifier.new,
              ),
            ],
            child: MaterialApp(
              theme: coveThemeFor(Brightness.dark),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: HabitDetailSheet(
                    habit: habit,
                    checkins: checkins,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 days running'), findsOneWidget);
        expect(find.text('Best 2 · Daily'), findsOneWidget);
        expect(find.text('Edit'), findsOneWidget);
        expect(find.text('Undo check-in'), findsOneWidget);

        // 2. Partner habit -> Edit only in verb row; "Cheer Ancy" and "Delete this habit" in ⋯ menu
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_TestAuthNotifier.new),
              partnerProfileProvider.overrideWith(
                _TestPartnerProfileNotifier.new,
              ),
            ],
            child: MaterialApp(
              theme: coveThemeFor(Brightness.dark),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: HabitDetailSheet(
                    habit: habit,
                    checkins: checkins,
                    isPartnerHabit: true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Undo check-in'), findsNothing);
        expect(find.text('Check in'), findsNothing);

        await tester.tap(
          find.byKey(const ValueKey('cove_detail_sheet_menu_button')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Cheer Ancy'), findsOneWidget);
        expect(find.text('Delete this habit'), findsOneWidget);
      });
    },
  );

  testWidgets(
    'CategoryDetailSheet renders paper CoveDial, meaning panel, and Edit verb',
    (tester) async {
      final fixedDate = DateTime(2026, 10, 15, 19, 30);
      final expenses = <LocalExpense>[
        LocalExpense(
          id: 'exp_1',
          homeId: 'home_1',
          title: 'Farmers Market Produce',
          amount: 1450.0,
          currency: 'INR',
          paidBy: 'user_alex',
          splitRatio: 0.5,
          expenseDate: fixedDate,
          category: 'Groceries',
          paymentMethod: 'upi',
          isTransfer: false,
          createdAt: fixedDate,
        ),
        LocalExpense(
          id: 'exp_2',
          homeId: 'home_1',
          title: 'Subko Sourdough & Milk',
          amount: 550.0,
          currency: 'INR',
          paidBy: 'user_partner',
          splitRatio: 0.5,
          expenseDate: fixedDate,
          category: 'Groceries',
          paymentMethod: 'card',
          isTransfer: false,
          createdAt: fixedDate,
        ),
        LocalExpense(
          id: 'exp_3',
          homeId: 'home_1',
          title: 'Electricity & Fiber Internet',
          amount: 2000.0,
          currency: 'INR',
          paidBy: 'user_partner',
          splitRatio: 0.5,
          expenseDate: fixedDate,
          category: 'Home & Utilities',
          paymentMethod: 'card',
          isTransfer: false,
          createdAt: fixedDate,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currencyPreferenceProvider.overrideWith(_TestCurrencyNotifier.new),
            authProvider.overrideWith(_TestAuthNotifier.new),
            partnerProfileProvider.overrideWith(
              _TestPartnerProfileNotifier.new,
            ),
          ],
          child: MaterialApp(
            theme: coveThemeFor(Brightness.dark),
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: CategoryDetailSheet(
                  initialCategoryName: 'Groceries',
                  allExpenses: expenses,
                  totalMonthSpend: 4000.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CoveDial), findsOneWidget);
      expect(find.text('₹2,000 this month'), findsOneWidget);
      expect(find.text('2 purchases · 50% of spending'), findsOneWidget);
      expect(find.text('Farmers Market Produce'), findsOneWidget);
      expect(find.text('Subko Sourdough & Milk'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
    },
  );
}

class _TestAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncData(
        CoveUser(
          id: 'user_alex',
          email: 'alex@cove.test',
          displayName: 'Alex',
        ),
      );

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void signInWithDemoUser([
    String name = 'Alex',
    String email = 'alex@cove.local',
  ]) {}

  @override
  Future<void> signOut() async {}
}

class _TestCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() =>
      const CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee');
}

class _TestPartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => const PartnerProfileState(
        displayName: 'Ancy',
        userId: 'user_partner',
      );
}
