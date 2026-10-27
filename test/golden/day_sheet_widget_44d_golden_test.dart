import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/widgets/cove_day_sheet_widget.dart';
import 'package:cove/features/widgets/cove_widget_service.dart';
import 'package:cove/sync/db/app_database.dart';
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

final DaySheetSummary _kFourRoutinesOrderedSummary = DaySheetSummary.compute(
  now: DateTime(2026, 10, 27, 12, 50), // Tuesday 12:50 PM
  calendarEvents: const <LocalCalendarEvent>[],
  routines: <Routine>[
    Routine(
      id: 'r_daily',
      homeId: 'home_1',
      name: 'Everyday',
      days: const [1, 2, 3, 4, 5, 6, 7],
      createdAt: DateTime(2026, 10, 1),
    ),
  ],
  routineEvents: <RoutineEvent>[
    // Post-midnight continuation of Sleep (00:00..06:00) + pre-midnight start (11:00 PM)
    RoutineEvent(
      id: 're_sleep_midnight_tail',
      routineId: 'r_daily',
      homeId: 'home_1',
      title: 'Sleep',
      startMinutes: 0,
      endMinutes: 6 * 60,
      createdAt: DateTime(2026, 10, 1),
    ),
    RoutineEvent(
      id: 're_walk_morning',
      routineId: 'r_daily',
      homeId: 'home_1',
      title: 'Walk',
      startMinutes: 10 * 60, // 10:00 AM
      endMinutes: 10 * 60 + 30,
      createdAt: DateTime(2026, 10, 1),
    ),
    RoutineEvent(
      id: 're_lyla_cabo_food',
      routineId: 'r_daily',
      homeId: 'home_1',
      title: 'Lyla Cabo food',
      startMinutes: 19 * 60 + 30, // 7:30 PM
      endMinutes: 20 * 60,
      notes: 'Ancy · routine',
      createdAt: DateTime(2026, 10, 1),
    ),
    RoutineEvent(
      id: 're_walk_evening',
      routineId: 'r_daily',
      homeId: 'home_1',
      title: 'Walk',
      startMinutes: 21 * 60, // 9:00 PM
      endMinutes: 21 * 60 + 30,
      createdAt: DateTime(2026, 10, 1),
    ),
    RoutineEvent(
      id: 're_sleep_start',
      routineId: 'r_daily',
      homeId: 'home_1',
      title: 'Sleep',
      startMinutes: 23 * 60, // 11:00 PM (starts before midnight, runs past it)
      endMinutes: 6 * 60, // 6:00 AM next day
      createdAt: DateTime(2026, 10, 1),
    ),
  ],
  lists: const <LocalList>[],
  listItems: const <LocalListItem>[],
  habits: const <LocalHabit>[],
  checkins: const <LocalHabitCheckin>[],
  expenses: const <LocalExpense>[],
  currentUserId: 'user_saba',
  myName: 'Saba',
  partnerName: 'Ancy',
  currency: _kInr,
  weatherLineOverride: '25° · mainly clear',
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

  // Verify circular corners and unshrunk typography at every size.
  expect(find.byType(FittedBox), findsNothing);
  final cardContainer = tester.widget<Container>(
    find.byKey(const ValueKey('cove_day_sheet_card')),
  );
  final boxDeco = cardContainer.decoration! as BoxDecoration;
  expect(
    boxDeco.borderRadius,
    const BorderRadius.all(Radius.circular(CoveRadius.hero)),
  );
  expect(tester.getSize(find.byType(CoveDaySheetCard)), widgetSize);
  final weekdayText = tester.widget<Text>(find.text(summary.weekdayCaps));
  expect(weekdayText.style?.fontSize, CoveType.capsCard.fontSize);

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

      testWidgets('day_sheet_widget.smallest.$modeName', (tester) async {
        await _pumpDaySheetGolden(
          tester,
          goldenName: 'day_sheet_widget.smallest.$modeName',
          brightness: brightness,
          summary: _kFullDaySheetSummary,
          surfaceSize: const Size(232, 252),
          widgetSize: const Size(200, 220),
        );
      });

      testWidgets('day_sheet_widget.stretch_tall_wide.$modeName', (
        tester,
      ) async {
        await _pumpDaySheetGolden(
          tester,
          goldenName: 'day_sheet_widget.stretch_tall_wide.$modeName',
          brightness: brightness,
          summary: _kFullDaySheetSummary,
          surfaceSize: const Size(467, 514),
          widgetSize: const Size(435, 482),
        );
      });

      testWidgets('day_sheet_widget.four_routines_order.$modeName', (
        tester,
      ) async {
        expect(
          _kFourRoutinesOrderedSummary.lines.map(
            (l) => (l.timeLabel, l.meridiemLabel, l.title, l.isOver),
          ),
          [
            ('10:00', 'AM', 'Walk', true),
            ('7:30', 'PM', 'Lyla Cabo food', false),
            ('9:00', 'PM', 'Walk', false),
            ('11:00', 'PM', 'Sleep', false),
          ],
        );
        expect(
          _kFourRoutinesOrderedSummary.hasBothMorningAndEveningLines,
          isTrue,
        );
        await _pumpDaySheetGolden(
          tester,
          goldenName: 'day_sheet_widget.four_routines_order.$modeName',
          brightness: brightness,
          summary: _kFourRoutinesOrderedSummary,
        );
      });
    }
  });
}
