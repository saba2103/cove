import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/widgets/cove_day_sheet_widget.dart';
import 'package:cove/features/widgets/cove_widget_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

const CurrencyOption _kInr = CurrencyOption(
  code: 'INR',
  symbol: '₹',
  name: 'Indian Rupee',
);

final DaySheetSummary _kFullDaySheetSummary = DaySheetSummary(
  referenceDate: DateTime(2026, 10, 5, 11, 30),
  nowMinutes: 11 * 60 + 30,
  dayNumber: '5',
  monthName: 'October',
  weekdayCaps: 'MONDAY',
  weatherLine: '28° · clear',
  firstHabitDueToday: 'Read 20 pages',
  lines: const <DaySheetLine>[
    DaySheetLine(
      id: 'event_dentist',
      kind: DaySheetLineKind.event,
      startMinutes: 10 * 60,
      endMinutes: 11 * 60,
      timeLabel: '10:00',
      title: 'Dentist — Dr. Nair',
      subtitle: 'Together · Indiranagar',
      isOver: true,
    ),
    DaySheetLine(
      id: 'task_plumber',
      kind: DaySheetLineKind.task,
      startMinutes: 14 * 60,
      endMinutes: 15 * 60,
      timeLabel: '2:00',
      title: 'Call plumber for sink',
      subtitle: 'You · Home',
      isOver: false,
      isCompleted: false,
      listId: 'list_home',
    ),
    DaySheetLine(
      id: 'routine_recycling',
      kind: DaySheetLineKind.routine,
      startMinutes: 18 * 60 + 30,
      endMinutes: 19 * 60,
      timeLabel: '6:30',
      title: 'Take out recycling',
      subtitle: 'Ancy · dry waste day',
      isOver: false,
    ),
    DaySheetLine(
      id: 'event_dinner',
      kind: DaySheetLineKind.event,
      startMinutes: 20 * 60,
      endMinutes: 22 * 60,
      timeLabel: '8:00',
      title: 'Dinner w/ Riya',
      subtitle: 'Together · Permit Room',
      isOver: false,
    ),
  ],
  habitDots: const <DaySheetHabitDot>[
    DaySheetHabitDot(
      habitId: 'habit_read',
      habitName: 'Read 20 pages',
      isKeptToday: true,
      isOwnedByViewer: true,
    ),
    DaySheetHabitDot(
      habitId: 'habit_meditate',
      habitName: 'Meditate',
      isKeptToday: false,
      isOwnedByViewer: true,
    ),
    DaySheetHabitDot(
      habitId: 'habit_stretch',
      habitName: 'Evening stretch',
      isKeptToday: true,
      isOwnedByViewer: false,
    ),
    DaySheetHabitDot(
      habitId: 'habit_water',
      habitName: '2L water',
      isKeptToday: false,
      isOwnedByViewer: false,
    ),
  ],
  todaySpend: 1840.0,
  currency: _kInr,
  checkinDateStr: '2026-10-05',
);

final DaySheetSummary _kEmptyDaySheetSummary = DaySheetSummary(
  referenceDate: DateTime(2026, 10, 5, 9, 41),
  nowMinutes: 9 * 60 + 41,
  dayNumber: '5',
  monthName: 'October',
  weekdayCaps: 'MONDAY',
  weatherLine: '28° · clear',
  firstHabitDueToday: null,
  lines: const <DaySheetLine>[],
  habitDots: const <DaySheetHabitDot>[],
  todaySpend: 0.0,
  currency: _kInr,
  checkinDateStr: '2026-10-05',
);

Future<void> _pumpDaySheetGolden(
  WidgetTester tester, {
  required String goldenName,
  required Brightness brightness,
  required DaySheetSummary summary,
  Size surfaceSize = const Size(411, 392),
  Size widgetSize = CoveWidgetService.sheetLogicalSize,
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
                child: CoveDaySheetCard(summary: summary),
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
  group('4.4d — The Day Sheet Home-Screen Widget Goldens (18-widgets.md §4)', () {
    for (final mode in const [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      final modeName = mode.$1;
      final brightness = mode.$2;

      testWidgets('day_sheet_widget.full_day.$modeName', (tester) async {
        await _pumpDaySheetGolden(
          tester,
          goldenName: 'day_sheet_widget.full_day.$modeName',
          brightness: brightness,
          summary: _kFullDaySheetSummary,
        );
      });

      testWidgets('day_sheet_widget.empty_day.$modeName', (tester) async {
        await _pumpDaySheetGolden(
          tester,
          goldenName: 'day_sheet_widget.empty_day.$modeName',
          brightness: brightness,
          summary: _kEmptyDaySheetSummary,
        );
      });
    }
  });
}
