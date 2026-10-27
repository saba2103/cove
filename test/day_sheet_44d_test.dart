import 'dart:convert';
import 'dart:io';

import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/features/widgets/cove_day_sheet_widget.dart';
import 'package:cove/features/widgets/cove_widget_service.dart';
import 'package:cove/features/widgets/cove_widget_tick_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> _values = <String, String>{};

  _MemorySecureStorage([Map<String, String>? initial]) {
    if (initial != null) {
      _values.addAll(initial);
    }
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _values[key];
  }
}

class _RecordingWidgetBridge implements CoveWidgetPlatformBridge {
  final List<String> renderedKeys = <String>[];
  final Map<String, Object?> savedData = <String, Object?>{};
  final List<String> updatedProviders = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<String> renderFlutterWidget(
    Widget widget, {
    required String key,
    required Size logicalSize,
  }) async {
    renderedKeys.add(key);
    return '/tmp/home_widget/$key.png';
  }

  @override
  Future<bool?> saveWidgetData<T>(String id, T? data) async {
    savedData[id] = data;
    return true;
  }

  @override
  Future<bool?> updateWidget({
    required String androidName,
    required String qualifiedAndroidName,
  }) async {
    updatedProviders.add(qualifiedAndroidName);
    return true;
  }

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() async => null;

  @override
  Stream<Uri?> get widgetClicked => const Stream<Uri?>.empty();
}

const CurrencyOption _kInr = CurrencyOption(
  code: 'INR',
  symbol: '₹',
  name: 'Indian Rupee',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('4.4d — The Day Sheet (18-widgets.md §4)', () {
    test(
      '1. DaySheetSummary.compute orders events, routines, and tasks in time order, dims lines that are over, and excludes partner private habits and expenses',
      () {
        final oct5 = DateTime(2026, 10, 5, 11, 30); // Monday 11:30 AM

        final summary = DaySheetSummary.compute(
          now: oct5,
          calendarEvents: [
            LocalCalendarEvent(
              id: 'ev_dentist',
              homeId: 'home_1',
              title: 'Dentist — Dr. Nair',
              location: 'Indiranagar',
              startTime: DateTime(2026, 10, 5, 10, 0),
              endTime: DateTime(2026, 10, 5, 11, 0),
              isAllDay: false,
              createdBy: 'user_saba',
              createdAt: DateTime(2026, 10, 1),
            ),
            LocalCalendarEvent(
              id: 'ev_dinner',
              homeId: 'home_1',
              title: 'Dinner w/ Riya',
              location: 'Permit Room',
              startTime: DateTime(2026, 10, 5, 20, 0),
              endTime: DateTime(2026, 10, 5, 22, 0),
              isAllDay: false,
              createdBy: 'user_saba',
              createdAt: DateTime(2026, 10, 1),
            ),
          ],
          routines: [
            Routine(
              id: 'routine_mon',
              homeId: 'home_1',
              name: 'Monday Evening',
              days: const [DateTime.monday],
              createdAt: DateTime(2026, 10, 1),
            ),
          ],
          routineEvents: [
            RoutineEvent(
              id: 're_recycling',
              routineId: 'routine_mon',
              homeId: 'home_1',
              title: 'Take out recycling',
              startMinutes: 18 * 60 + 30,
              endMinutes: 19 * 60,
              notes: 'Ancy · dry waste day',
              createdAt: DateTime(2026, 10, 1),
            ),
          ],
          lists: [
            LocalList(
              id: 'list_home',
              homeId: 'home_1',
              name: 'Home',
              createdBy: 'user_saba',
              isArchived: false,
              createdAt: DateTime(2026, 10, 1),
            ),
          ],
          listItems: [
            LocalListItem(
              id: 'task_plumber',
              homeId: 'home_1',
              listId: 'list_home',
              title: 'Call plumber for sink',
              isCompleted: false,
              dueDate: DateTime(2026, 10, 5, 14, 0),
              createdBy: 'user_saba',
              createdAt: DateTime(2026, 10, 4),
            ),
          ],
          habits: [
            LocalHabit(
              id: 'habit_read',
              homeId: 'home_1',
              name: 'Read 20 pages',
              cadence: 'DAILY',
              targetDaysPerWeek: 7,
              createdBy: 'user_saba',
              isArchived: false,
              createdAt: DateTime(2026, 10, 1),
            ),
            LocalHabit(
              id: 'habit_stretch',
              homeId: 'home_1',
              name: 'Evening stretch',
              cadence: 'DAILY',
              targetDaysPerWeek: 7,
              createdBy: 'user_ancy',
              isArchived: false,
              createdAt: DateTime(2026, 10, 2),
            ),
            LocalHabit(
              id: 'habit_partner_private',
              homeId: 'home_1',
              name: 'Partner secret journal',
              cadence: 'DAILY',
              targetDaysPerWeek: -7, // private
              createdBy: 'user_ancy',
              isArchived: false,
              createdAt: DateTime(2026, 10, 3),
            ),
          ],
          checkins: [
            LocalHabitCheckin(
              id: 'chk_1',
              homeId: 'home_1',
              habitId: 'habit_stretch',
              memberId: 'user_ancy',
              checkinDate: '2026-10-05',
              createdAt: DateTime(2026, 10, 5, 8, 0),
            ),
          ],
          expenses: [
            LocalExpense(
              id: 'exp_shared',
              homeId: 'home_1',
              title: 'Groceries',
              amount: 1540.0,
              currency: 'INR',
              paidBy: 'user_saba',
              splitRatio: 0.5,
              expenseDate: DateTime(2026, 10, 5, 9, 0),
              isTransfer: false,
              createdAt: DateTime(2026, 10, 5, 9, 0),
            ),
            LocalExpense(
              id: 'exp_my_private',
              homeId: 'home_1',
              title: 'Coffee',
              amount: 300.0,
              currency: 'INR',
              paidBy: 'user_saba',
              splitRatio: -1.0, // viewer's own private expense
              expenseDate: DateTime(2026, 10, 5, 10, 0),
              isTransfer: false,
              createdAt: DateTime(2026, 10, 5, 10, 0),
            ),
            LocalExpense(
              id: 'exp_partner_private',
              homeId: 'home_1',
              title: 'Surprise gift',
              amount: 4500.0,
              currency: 'INR',
              paidBy: 'user_ancy',
              splitRatio: -1.0, // partner's private expense — MUST NOT SHOW
              expenseDate: DateTime(2026, 10, 5, 10, 30),
              isTransfer: false,
              createdAt: DateTime(2026, 10, 5, 10, 30),
            ),
          ],
          currentUserId: 'user_saba',
          myName: 'Saba',
          partnerName: 'Ancy',
          currency: _kInr,
          weather: WeatherData(
            cityName: 'Bengaluru',
            temperatureC: 28.2,
            apparentTemperatureC: 29.0,
            condition: 'Clear',
            weatherCode: 0,
            isDay: true,
            updatedAt: oct5,
            latitude: 12.97,
            longitude: 77.59,
          ),
        );

        expect(summary.dayNumber, '5');
        expect(summary.monthName, 'October');
        expect(summary.weekdayCaps, 'MONDAY');
        expect(summary.weatherLine, '28° · clear');
        expect(summary.firstHabitDueToday, 'Read 20 pages');

        // Time-ordered lines: 10:00 Dentist (over), 2:00 task, 6:30 routine, 8:00 Dinner
        expect(
          summary.lines.map((l) => (l.kind, l.timeLabel, l.title, l.isOver)),
          [
            (DaySheetLineKind.event, '10:00', 'Dentist — Dr. Nair', true),
            (DaySheetLineKind.task, '2:00', 'Call plumber for sink', false),
            (DaySheetLineKind.routine, '6:30', 'Take out recycling', false),
            (DaySheetLineKind.event, '8:00', 'Dinner w/ Riya', false),
          ],
        );

        // Partner private habit is excluded; viewer habit isOwnedByViewer=true, partner shared habit isOwnedByViewer=false
        expect(
          summary.habitDots.map(
            (d) => (d.habitId, d.isOwnedByViewer, d.isKeptToday),
          ),
          [
            ('habit_read', true, false),
            ('habit_stretch', false, true),
          ],
        );

        // Today's spend includes shared (1540) + viewer's own private (300) = 1840, excludes partner's private (4500)
        expect(summary.todaySpend, 1840.0);
      },
    );

    testWidgets(
      '2. Partner habit dots are not tappable; viewer habit dots and task lines tick; event and routine lines open the app',
      (tester) async {
        final tappedLines = <DaySheetLine>[];
        final tickedTasks = <DaySheetLine>[];
        final tickedHabits = <DaySheetHabitDot>[];

        final summary = DaySheetSummary(
          referenceDate: DateTime(2026, 10, 5, 11, 30),
          nowMinutes: 11 * 60 + 30,
          dayNumber: '5',
          monthName: 'October',
          weekdayCaps: 'MONDAY',
          weatherLine: '28° · clear',
          firstHabitDueToday: 'Read 20 pages',
          lines: const [
            DaySheetLine(
              id: 'ev_dentist',
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
            ),
            DaySheetLine(
              id: 're_recycling',
              kind: DaySheetLineKind.routine,
              startMinutes: 18 * 60 + 30,
              endMinutes: 19 * 60,
              timeLabel: '6:30',
              title: 'Take out recycling',
              subtitle: 'Ancy · dry waste day',
              isOver: false,
            ),
          ],
          habitDots: const [
            DaySheetHabitDot(
              habitId: 'habit_mine',
              habitName: 'Read 20 pages',
              isKeptToday: false,
              isOwnedByViewer: true,
            ),
            DaySheetHabitDot(
              habitId: 'habit_partner',
              habitName: 'Evening stretch',
              isKeptToday: false,
              isOwnedByViewer: false,
            ),
          ],
          todaySpend: 1840.0,
          currency: _kInr,
          checkinDateStr: '2026-10-05',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: CoveTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 360,
                  height: 360,
                  child: CoveDaySheetCard(
                    summary: summary,
                    onOpenLine: tappedLines.add,
                    onTickTask: tickedTasks.add,
                    onTickHabit: tickedHabits.add,
                  ),
                ),
              ),
            ),
          ),
        );

        // Partner habit dot GestureDetector has null onTap
        final partnerDotGesture = tester.widget<GestureDetector>(
          find.byKey(const ValueKey('day_sheet_habit_dot_habit_partner')),
        );
        expect(partnerDotGesture.onTap, isNull);

        // Tapping partner habit dot does nothing
        await tester.tap(
          find.byKey(const ValueKey('day_sheet_habit_dot_habit_partner')),
        );
        await tester.pump();
        expect(tickedHabits, isEmpty);

        // Tapping viewer's own habit dot ticks it
        await tester.tap(
          find.byKey(const ValueKey('day_sheet_habit_dot_habit_mine')),
        );
        await tester.pump();
        expect(tickedHabits.map((d) => d.habitId), ['habit_mine']);

        // Tapping task line ticks it (does not call onOpenLine)
        await tester.tap(
          find.byKey(const ValueKey('day_sheet_line_task_task_plumber')),
        );
        await tester.pump();
        expect(tickedTasks.map((l) => l.id), ['task_plumber']);
        expect(tappedLines, isEmpty);

        // Tapping event and routine lines opens them in the app
        await tester.tap(
          find.byKey(const ValueKey('day_sheet_line_event_ev_dentist')),
        );
        await tester.tap(
          find.byKey(const ValueKey('day_sheet_line_routine_re_recycling')),
        );
        await tester.pump();
        expect(tappedLines.map((l) => (l.kind, l.id)), [
          (DaySheetLineKind.event, 'ev_dentist'),
          (DaySheetLineKind.routine, 're_recycling'),
        ]);
      },
    );

    test(
      '3. Reuses 4.4c tick path for Day Sheet tasks and viewer habits, and refuses partner habits',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('day_sheet_44d_');
        addTearDown(() async {
          try {
            await tempDir.delete(recursive: true);
          } catch (_) {}
        });
        final dbFile = File('${tempDir.path}/cove_test.sqlite');

        final seedDb = AppDatabase(NativeDatabase(dbFile));
        await seedDb.into(seedDb.localHomes).insert(
              LocalHomesCompanion.insert(
                id: 'home_1',
                name: 'The Nest',
                currency: const Value('INR'),
                createdBy: 'user_saba',
                createdAt: DateTime(2026, 10, 1),
              ),
            );
        await seedDb.into(seedDb.localLists).insert(
              LocalListsCompanion.insert(
                id: 'list_home',
                homeId: 'home_1',
                name: 'Home',
                createdBy: 'user_saba',
                createdAt: DateTime(2026, 10, 1),
              ),
            );
        await seedDb.into(seedDb.localListItems).insert(
              LocalListItemsCompanion.insert(
                id: 'task_plumber',
                homeId: 'home_1',
                listId: 'list_home',
                title: 'Call plumber for sink',
                createdBy: 'user_saba',
                createdAt: DateTime(2026, 10, 5),
              ),
            );
        await seedDb.into(seedDb.localHabits).insert(
              LocalHabitsCompanion.insert(
                id: 'habit_mine',
                homeId: 'home_1',
                name: 'Read 20 pages',
                cadence: const Value('DAILY'),
                targetDaysPerWeek: const Value(7),
                createdBy: 'user_saba',
                createdAt: DateTime(2026, 10, 1),
              ),
            );
        await seedDb.into(seedDb.localHabits).insert(
              LocalHabitsCompanion.insert(
                id: 'habit_partner',
                homeId: 'home_1',
                name: 'Evening stretch',
                cadence: const Value('DAILY'),
                targetDaysPerWeek: const Value(7),
                createdBy: 'user_ancy',
                createdAt: DateTime(2026, 10, 1),
              ),
            );
        await seedDb.close();

        final keyBytes = List<int>.generate(32, (i) => i + 1);
        final storage = _MemorySecureStorage({
          'cove_home_key_home_1': base64Encode(keyBytes),
        });
        final keyStore = HomeKeyStore(storage: storage);
        var pushedCount = 0;

        // 1. Tick task from Day Sheet
        final taskResult = await CoveWidgetTickService.handleWidgetTick(
          kind: WidgetTickKind.listItem,
          recordId: 'task_plumber',
          toDone: true,
          databaseFile: dbFile,
          keyStoreOverride: keyStore,
          viewerUserIdOverride: 'user_saba',
          onSyncPushOverride: () async {
            pushedCount++;
          },
        );
        expect(taskResult.outcome, WidgetTickOutcome.appliedInBackground);
        expect(taskResult.wroteToDatabase, isTrue);

        // 2. Tick viewer's own habit from Day Sheet
        final habitResult = await CoveWidgetTickService.handleWidgetTick(
          kind: WidgetTickKind.habitCheckin,
          recordId: 'habit_mine',
          toDone: true,
          checkinDate: '2026-10-05',
          databaseFile: dbFile,
          keyStoreOverride: keyStore,
          viewerUserIdOverride: 'user_saba',
          onSyncPushOverride: () async {
            pushedCount++;
          },
        );
        expect(habitResult.outcome, WidgetTickOutcome.appliedInBackground);
        expect(habitResult.wroteToDatabase, isTrue);

        // 3. Attempting to tick partner's habit is refused
        final partnerHabitResult = await CoveWidgetTickService.handleWidgetTick(
          kind: WidgetTickKind.habitCheckin,
          recordId: 'habit_partner',
          toDone: true,
          checkinDate: '2026-10-05',
          databaseFile: dbFile,
          keyStoreOverride: keyStore,
          viewerUserIdOverride: 'user_saba',
          onSyncPushOverride: () async {
            pushedCount++;
          },
        );
        expect(
          partnerHabitResult.outcome,
          WidgetTickOutcome.missingKeyOrRecord,
        );
        expect(partnerHabitResult.wroteToDatabase, isFalse);

        final verifyDb = AppDatabase(NativeDatabase(dbFile));
        final outbox = await verifyDb.select(verifyDb.localOutboxEvents).get();
        expect(
          outbox.map((e) => e.eventType),
          ['list_item_toggled', 'habit_checkin_toggled'],
        );
        expect(pushedCount, 2);
        await verifyDb.close();
      },
    );

    test(
      '4. CoveWidgetService.renderAndPushDaySheet saves hit metadata and CoveDaySheetWidgetProvider binds task/habit ticks and disables partner habit hit views',
      () async {
        final bridge = _RecordingWidgetBridge();
        final service = CoveWidgetService(bridge: bridge);

        final summary = DaySheetSummary(
          referenceDate: DateTime(2026, 10, 5, 11, 30),
          nowMinutes: 11 * 60 + 30,
          dayNumber: '5',
          monthName: 'October',
          weekdayCaps: 'MONDAY',
          weatherLine: '28° · clear',
          firstHabitDueToday: 'Read 20 pages',
          lines: const [
            DaySheetLine(
              id: 'task_plumber',
              kind: DaySheetLineKind.task,
              startMinutes: 14 * 60,
              endMinutes: 15 * 60,
              timeLabel: '2:00',
              title: 'Call plumber for sink',
              subtitle: 'You · Home',
              isOver: false,
            ),
            DaySheetLine(
              id: 'ev_dinner',
              kind: DaySheetLineKind.event,
              startMinutes: 20 * 60,
              endMinutes: 22 * 60,
              timeLabel: '8:00',
              title: 'Dinner w/ Riya',
              subtitle: 'Together · Permit Room',
              isOver: false,
            ),
          ],
          habitDots: const [
            DaySheetHabitDot(
              habitId: 'habit_mine',
              habitName: 'Read 20 pages',
              isKeptToday: false,
              isOwnedByViewer: true,
            ),
            DaySheetHabitDot(
              habitId: 'habit_partner',
              habitName: 'Evening stretch',
              isKeptToday: true,
              isOwnedByViewer: false,
            ),
          ],
          todaySpend: 1840.0,
          currency: _kInr,
          checkinDateStr: '2026-10-05',
        );

        await service.renderAndPushDaySheet(summary: summary, force: true);

        expect(
          bridge.renderedKeys,
          containsAll([
            CoveWidgetService.sheetDarkKey,
            CoveWidgetService.sheetLightKey,
          ]),
        );
        expect(bridge.savedData['cove_widget_sheet_row_0_kind'], 'task');
        expect(bridge.savedData['cove_widget_sheet_row_0_id'], 'task_plumber');
        expect(bridge.savedData['cove_widget_sheet_row_1_kind'], 'event');
        expect(bridge.savedData['cove_widget_sheet_row_1_id'], 'ev_dinner');
        expect(bridge.savedData['cove_widget_sheet_habit_0_id'], 'habit_mine');
        expect(bridge.savedData['cove_widget_sheet_habit_0_owned'], true);
        expect(
          bridge.savedData['cove_widget_sheet_habit_1_id'],
          'habit_partner',
        );
        expect(bridge.savedData['cove_widget_sheet_habit_1_owned'], false);
        expect(
          bridge.updatedProviders,
          contains('com.app.cove.widgets.CoveDaySheetWidgetProvider'),
        );

        // Verify Kotlin provider hides hit view for non-owned (partner) habits
        final providerKt = File(
          'android/app/src/main/kotlin/com/app/cove/widgets/CoveDaySheetWidgetProvider.kt',
        ).readAsStringSync();
        expect(providerKt, contains('kind=list_item'));
        expect(providerKt, contains('kind=habit_checkin'));
        expect(providerKt, contains('if (habitId.isNullOrEmpty() || !isOwned)'));
      },
    );
  });
}
