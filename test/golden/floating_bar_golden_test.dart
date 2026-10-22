import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_floating_bar.dart';
import 'package:cove/core/widgets/cove_metric_card.dart';
import 'package:cove/core/widgets/cove_page_header.dart';
import 'package:cove/core/widgets/cove_round_button.dart';
import 'package:cove/core/widgets/cove_row.dart';
import 'package:cove/core/widgets/cove_section_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _FloatingBarScene extends StatelessWidget {
  final String title;
  final String readout;
  final CoveFloatingBarState barState;

  const _FloatingBarScene({
    required this.title,
    required this.readout,
    required this.barState,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: CoveSpace.barClearance + bottomInset,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CovePageHeader(
                  title: title,
                  readout: readout,
                  action: CoveRoundButton(
                    icon: Icons.notifications_none_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Notifications',
                    onPressed: () {},
                  ),
                ),
                const SizedBox(height: CoveSpace.md),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
                  child: CoveMetricGrid(
                    children: [
                      CoveMetricCard(
                        label: 'This month',
                        value: '₹38,420',
                        subtitle: 'Across 24 items',
                      ),
                      CoveMetricCard(
                        label: 'Upcoming',
                        value: '₹12,800',
                        subtitle: 'Due in 7 days',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CoveSpace.section),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const CoveSectionLabel.page(
                        label: 'Recent activity',
                        readout: '2 items',
                      ),
                      const SizedBox(height: CoveSpace.xs),
                      CoveRow(
                        title: 'Blue Tokai Coffee',
                        subtitle: 'Eating out · Today',
                        amount: '₹640',
                        onTap: () {},
                      ),
                      CoveRow(
                        title: 'BESCOM Electricity',
                        subtitle: 'Shared utility · 18 Oct',
                        amount: '₹3,420',
                        isLast: true,
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: CoveFloatingBar(
              state: barState,
              onSeatTap: (_) {},
              onAddTap: () {},
              onOverflowItemTap: (_) {},
            ),
          ),
        ],
      ),
    );
  }
}

double _measureUnconstrainedTextWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

void main() {
  testWidgets(
    'CoveFloatingBar golden matrix — rest state (Home · Money · [+] · Tasks · Calendar)',
    (tester) async {
      await goldenMatrix(
        tester,
        'floating_bar_rest',
        const _FloatingBarScene(
          title: 'Today',
          readout: '23 Oct',
          barState: CoveFloatingBarState.rest(selectedId: 'home'),
        ),
      );
    },
  );

  testWidgets(
    'CoveFloatingBar golden matrix — money state (Home detached; Expenses · Bills · More)',
    (tester) async {
      await goldenMatrix(
        tester,
        'floating_bar_money',
        const _FloatingBarScene(
          title: 'Expenses',
          readout: 'October',
          barState: CoveFloatingBarState.money(selectedId: 'expenses'),
        ),
      );
    },
  );

  testWidgets(
    'CoveFloatingBar golden matrix — tasks state (Home detached; Todo · Habits)',
    (tester) async {
      await goldenMatrix(
        tester,
        'floating_bar_tasks',
        const _FloatingBarScene(
          title: 'Lists',
          readout: '4 active',
          barState: CoveFloatingBarState.tasks(selectedId: 'todo'),
        ),
      );
    },
  );

  testWidgets(
    'CoveFloatingBar golden matrix — calendar state (Home detached; Day · Routines)',
    (tester) async {
      await goldenMatrix(
        tester,
        'floating_bar_calendar',
        const _FloatingBarScene(
          title: 'Calendar',
          readout: 'October',
          barState: CoveFloatingBarState.calendar(selectedId: 'day'),
        ),
      );
    },
  );

  testWidgets(
    'CoveFloatingBar golden matrix — more state (Money overflow open: EMIs, Year, Savings)',
    (tester) async {
      await goldenMatrix(
        tester,
        'floating_bar_more',
        const _FloatingBarScene(
          title: 'Expenses',
          readout: 'October',
          barState: CoveFloatingBarState.more(selectedId: 'emis'),
        ),
      );
    },
  );

  testWidgets(
    'CoveFloatingBar empirical label-fit audit across cover (320), phone (390 & 411) and wide (840)',
    (tester) async {
      final viewports = <String, Size>{
        'cover_320': const Size(320, 720),
        'phone_390': const Size(390, 844),
        'phone_411': const Size(411, 844),
        'wide_840': const Size(840, 844),
      };

      final statesToMeasure = <String, CoveFloatingBarState>{
        'rest': const CoveFloatingBarState.rest(selectedId: 'home'),
        'money_bills': const CoveFloatingBarState.money(
          selectedId: 'expenses',
          commitmentsLabel: 'Bills',
        ),
        'money_commitments': const CoveFloatingBarState.money(
          selectedId: 'expenses',
          commitmentsLabel: 'Commitments',
        ),
        'tasks': const CoveFloatingBarState.tasks(selectedId: 'todo'),
        'calendar': const CoveFloatingBarState.calendar(selectedId: 'day'),
        'more': const CoveFloatingBarState.more(selectedId: 'emis'),
      };

      for (final vpEntry in viewports.entries) {
        final vpName = vpEntry.key;
        final size = vpEntry.value;

        tester.view
          ..physicalSize = size * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        for (final stEntry in statesToMeasure.entries) {
          final stateName = stEntry.key;
          final barState = stEntry.value;

          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.0),
              ),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: coveThemeFor(Brightness.dark),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.bottomCenter,
                    child: CoveFloatingBar(state: barState),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final allSeatItems = <CoveFloatingBarItem>[
            if (barState.isHomeDetached) CoveFloatingBarState.homeItem,
            ...barState.categoryItems,
          ];

          for (final item in allSeatItems) {
            final seatBoxFinder = find.byKey(
              ValueKey('cove_bar_seat_box_${item.id}'),
            );
            final labelFinder = find.byKey(
              ValueKey('cove_bar_label_${item.id}'),
            );
            final seatWidth = tester.getSize(seatBoxFinder).width;
            final renderedLabelWidth = tester.getSize(labelFinder).width;
            final availableLabelWidth = seatWidth - (CoveSpace.xs * 2);
            final unconstrainedWidth = _measureUnconstrainedTextWidth(
              item.label,
              CoveType.capsCard,
            );
            expect(
              renderedLabelWidth,
              lessThanOrEqualTo(availableLabelWidth + 0.1),
              reason: '$vpName/$stateName/${item.id}',
            );
            if (stateName == 'money_commitments' && item.id == 'commitments') {
              // "Commitments" (93.8dp) overflows its seat at cover (39.3dp),
              // phone 390 (62.7dp), phone 411 (69.7dp), and wide/420 (86.0dp).
              expect(unconstrainedWidth, greaterThan(availableLabelWidth));
            }
            if (stateName == 'money_bills' && item.id == 'commitments') {
              // "Bills" (29.3dp) fits comfortably inside the seat at every width.
              expect(unconstrainedWidth, lessThanOrEqualTo(availableLabelWidth));
            }
          }

          if (barState.isMoreMenuOpen) {
            for (final item in CoveFloatingBarState.moneyOverflowItems) {
              final rowFinder = find.byKey(
                ValueKey('cove_bar_overflow_${item.id}'),
              );
              final labelFinder = find.byKey(
                ValueKey('cove_bar_overflow_label_${item.id}'),
              );
              final rowWidth = tester.getSize(rowFinder).width;
              final renderedLabelWidth = tester.getSize(labelFinder).width;
              final unconstrainedWidth = _measureUnconstrainedTextWidth(
                item.label,
                CoveType.rowTitle,
              );
              expect(rowWidth, greaterThan(150.0));
              expect(unconstrainedWidth, lessThanOrEqualTo(renderedLabelWidth));
            }
          }
        }
      }

      // Confirm empirically that "Commitments" overflows its seat at cover (320dp) and phone (411dp)
      final commitmentsWidth = _measureUnconstrainedTextWidth(
        'Commitments',
        CoveType.capsCard,
      );
      final billsWidth = _measureUnconstrainedTextWidth(
        'Bills',
        CoveType.capsCard,
      );
      expect(commitmentsWidth, greaterThan(59.0));
      expect(billsWidth, lessThan(48.0));
    },
  );
}
