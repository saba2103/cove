import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/features/widgets/cove_slip_widget.dart';
import 'package:cove/features/widgets/cove_widget_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

const SlipSummary _kGroceriesSlipSummary = SlipSummary(
  listId: 'list_groceries',
  listName: 'Groceries',
  openCount: 5,
  openItems: <SlipItemRow>[
    SlipItemRow(
      id: 'item_curd',
      title: 'Curd, 500g',
      createdBy: 'user_ancy',
      person: CovePerson.b,
      actorInitial: 'A',
    ),
    SlipItemRow(
      id: 'item_tablets',
      title: 'Dishwasher tablets',
      createdBy: 'user_saba',
      person: CovePerson.a,
      actorInitial: 'S',
    ),
    SlipItemRow(
      id: 'item_coffee',
      title: 'Coffee beans — dark roast',
      createdBy: 'user_ancy',
      person: CovePerson.b,
      actorInitial: 'A',
    ),
    SlipItemRow(
      id: 'item_sourdough',
      title: 'Sourdough loaf',
      createdBy: 'user_saba',
      person: CovePerson.a,
      actorInitial: 'S',
    ),
    SlipItemRow(
      id: 'item_pepper',
      title: 'Black pepper',
      createdBy: 'user_ancy',
      person: CovePerson.b,
      actorInitial: 'A',
    ),
  ],
);

const SlipSummary _kEmptySlipSummary = SlipSummary(
  listId: 'list_groceries',
  listName: 'Groceries',
  openCount: 0,
  openItems: <SlipItemRow>[],
);

Future<void> _pumpSlipGolden(
  WidgetTester tester, {
  required String goldenName,
  required Brightness brightness,
  required SlipSummary summary,
  Size surfaceSize = const Size(411, 208),
  Size widgetSize = CoveWidgetService.slipFullLogicalSize,
}) async {
  await loadCoveFonts();
  tester.view
    ..physicalSize = surfaceSize * 2
    ..devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final theme = coveThemeFor(brightness);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: surfaceSize,
        textScaler: const TextScaler.linear(1.0),
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Builder(
          builder: (context) => ColoredBox(
            color: context.cv.surfaceCanvas,
            child: Center(
              child: SizedBox(
                width: widgetSize.width,
                height: widgetSize.height,
                child: CoveSlipCard(summary: summary),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$goldenName.png'),
  );
}

void main() {
  group('4.4c — The Slip Home-Screen Widget Goldens (18-widgets.md §2)', () {
    for (final mode in const [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      final modeName = mode.$1;
      final brightness = mode.$2;

      testWidgets('slip_widget.full.$modeName', (tester) async {
        await _pumpSlipGolden(
          tester,
          goldenName: 'slip_widget.full.$modeName',
          brightness: brightness,
          summary: _kGroceriesSlipSummary,
        );
      });

      testWidgets('slip_widget.compact_3cell.$modeName', (tester) async {
        await _pumpSlipGolden(
          tester,
          goldenName: 'slip_widget.compact_3cell.$modeName',
          brightness: brightness,
          summary: _kGroceriesSlipSummary,
          surfaceSize: const Size(232, 208),
          widgetSize: CoveWidgetService.slipCompactLogicalSize,
        );
      });

      testWidgets('slip_widget.optimistic_tick.$modeName', (tester) async {
        await _pumpSlipGolden(
          tester,
          goldenName: 'slip_widget.optimistic_tick.$modeName',
          brightness: brightness,
          summary: _kGroceriesSlipSummary.withOptimisticTick('item_curd'),
        );
      });

      testWidgets('slip_widget.empty.$modeName', (tester) async {
        await _pumpSlipGolden(
          tester,
          goldenName: 'slip_widget.empty.$modeName',
          brightness: brightness,
          summary: _kEmptySlipSummary,
        );
      });
    }
  });
}
