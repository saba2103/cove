import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/widgets/cove_day_arc_widget.dart';
import 'package:cove/features/widgets/cove_widget_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingWidgetBridge implements CoveWidgetPlatformBridge {
  final List<String> renderedKeys = <String>[];
  final Map<String, Size> renderedSizes = <String, Size>{};
  final Map<String, Object?> savedData = <String, Object?>{};
  final List<String> updatedProviders = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<String> renderFlutterWidget(
    Widget widget, {
    required String key,
    required Size logicalSize,
    double? pixelRatio,
  }) async {
    renderedKeys.add(key);
    renderedSizes[key] = logicalSize;
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

class _NoopScheduler implements WidgetRefreshScheduler {
  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedulePeriodicRefresh() async {}

  @override
  Future<void> cancel() async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('4.4b — The Day Arc', () {
    final routines = <Routine>[
      Routine(
        id: 'r_weekday',
        homeId: 'home_1',
        name: 'Weekday',
        days: const [1, 2, 3, 4, 5],
        createdAt: DateTime(2026, 9, 1),
      ),
    ];

    final routineEvents = <RoutineEvent>[
      RoutineEvent(
        id: 're_walk',
        routineId: 'r_weekday',
        homeId: 'home_1',
        title: 'Morning walk',
        startMinutes: 8 * 60 + 30,
        endMinutes: 9 * 60 + 30,
        category: 'fitness',
        createdAt: DateTime(2026, 9, 1),
      ),
      RoutineEvent(
        id: 're_lights_out',
        routineId: 'r_weekday',
        homeId: 'home_1',
        title: 'Lights out',
        startMinutes: 21 * 60 + 30,
        endMinutes: 22 * 60 + 30,
        category: 'rest',
        createdAt: DateTime(2026, 9, 1),
      ),
    ];

    final events = <LocalCalendarEvent>[
      LocalCalendarEvent(
        id: 'ev_solo',
        homeId: 'home_1',
        title: 'Design sync',
        description: 'solo-partner',
        startTime: DateTime(2026, 10, 5, 11, 0),
        endTime: DateTime(2026, 10, 5, 12, 0),
        isAllDay: false,
        createdAt: DateTime(2026, 10, 1),
        createdBy: 'user_2',
      ),
      LocalCalendarEvent(
        id: 'ev_lunch',
        homeId: 'home_1',
        title: 'Lunch at home',
        description: 'shared',
        startTime: DateTime(2026, 10, 5, 13, 30),
        endTime: DateTime(2026, 10, 5, 15, 0),
        isAllDay: false,
        createdAt: DateTime(2026, 10, 1),
        createdBy: 'user_1',
      ),
    ];

    final habits = <LocalHabit>[
      LocalHabit(
        id: 'h_7am',
        homeId: 'home_1',
        name: 'Hydrate',
        cadence: 'daily@07:00',
        targetDaysPerWeek: 7,
        isArchived: false,
        createdAt: DateTime(2026, 9, 1),
        createdBy: 'user_1',
      ),
      LocalHabit(
        id: 'h_6pm',
        homeId: 'home_1',
        name: 'Stretch',
        cadence: 'daily@18:00',
        targetDaysPerWeek: 7,
        isArchived: false,
        createdAt: DateTime(2026, 9, 1),
        createdBy: 'user_1',
      ),
      LocalHabit(
        id: 'h_partner_private',
        homeId: 'home_1',
        name: 'Private meditation',
        cadence: 'daily@09:00',
        targetDaysPerWeek: -7, // private to partner
        isArchived: false,
        createdAt: DateTime(2026, 9, 1),
        createdBy: 'user_2',
      ),
    ];

    final checkins = <LocalHabitCheckin>[
      LocalHabitCheckin(
        id: 'chk_1',
        homeId: 'home_1',
        habitId: 'h_7am',
        checkinDate: '2026-10-05',
        memberId: 'user_1',
        createdAt: DateTime(2026, 10, 5, 7, 5),
      ),
    ];

    test(
      '1. DayArcSummary computes solid vs faint arcs, rim habit dots (excluding partner private), and current/next centre across the day',
      () {
        final morning = DayArcSummary.compute(
          referenceDate: DateTime(2026, 10, 5, 8, 10),
          events: events,
          routines: routines,
          routineEvents: routineEvents,
          habits: habits,
          checkins: checkins,
          currentUserId: 'user_1',
          partnerName: 'Ancy',
        );

        expect(morning.bands, hasLength(4));
        final soloBand = morning.bands.firstWhere((b) => b.id.contains('ev_solo'));
        final lunchBand = morning.bands.firstWhere(
          (b) => b.id.contains('ev_lunch'),
        );
        expect(soloBand.strength, DayArcStrength.faint);
        expect(lunchBand.strength, DayArcStrength.solid);

        // Partner's private habit is never shown.
        expect(morning.habitDots, hasLength(2));
        expect(morning.habitDots[0].habitId, 'h_7am');
        expect(morning.habitDots[0].isKept, isTrue);
        expect(morning.habitDots[1].habitId, 'h_6pm');
        expect(morning.habitDots[1].isKept, isFalse);

        // Morning (8:10 AM) -> next is 8:30 Morning walk
        expect(morning.centerTimeLabel, '8:30');
        expect(morning.centerTitle, 'Morning walk');

        // Midday (1:30 PM) -> current is 1:30 Lunch at home
        final midday = morning.atTime(DateTime(2026, 10, 5, 13, 30));
        expect(midday.centerTimeLabel, '1:30');
        expect(midday.centerTitle, 'Lunch at home');

        // Night (9:15 PM) -> next is 9:30 Lights out
        final night = morning.atTime(DateTime(2026, 10, 5, 21, 15));
        expect(night.centerTimeLabel, '9:30');
        expect(night.centerTitle, 'Lights out');

        // Empty day -> "Nothing booked today"
        final empty = DayArcSummary.compute(
          referenceDate: DateTime(2026, 10, 5, 9, 41),
          events: const [],
          routines: const [],
          routineEvents: const [],
          habits: const [],
          checkins: const [],
        );
        expect(empty.centerTimeLabel, isNull);
        expect(empty.centerTitle, 'Nothing booked today');
      },
    );

    test(
      '2. CoveWidgetService renders Day Arc bitmaps and advances the now hairline on background refresh',
      () async {
        final bridge = _RecordingWidgetBridge();
        final service = CoveWidgetService(
          bridge: bridge,
          scheduler: _NoopScheduler(),
        );

        final morning = DayArcSummary.compute(
          referenceDate: DateTime(2026, 10, 5, 8, 10),
          events: events,
          routines: routines,
          routineEvents: routineEvents,
          habits: habits,
          checkins: checkins,
          currentUserId: 'user_1',
          partnerName: 'Ancy',
        );

        await service.renderAndPushDayArc(summary: morning);
        expect(
          bridge.renderedKeys,
          containsAll([
            CoveWidgetService.arcDarkKey,
            CoveWidgetService.arcLightKey,
          ]),
        );
        expect(
          bridge.renderedSizes[CoveWidgetService.arcDarkKey],
          const Size(176, 176),
        );
        expect(
          bridge.updatedProviders,
          contains('com.app.cove.widgets.CoveDayArcWidgetProvider'),
        );

        bridge.renderedKeys.clear();
        await service.runBackgroundRefresh(
          nowOverride: DateTime(2026, 10, 5, 13, 30),
        );
        expect(
          bridge.renderedKeys,
          containsAll([
            CoveWidgetService.arcDarkKey,
            CoveWidgetService.arcLightKey,
          ]),
        );
      },
    );

    testWidgets(
      '3. CoveDayArcCard renders centre time and title or empty voice and invokes onTap',
      (tester) async {
        var tapped = false;
        final midday = DayArcSummary.compute(
          referenceDate: DateTime(2026, 10, 5, 13, 30),
          events: events,
          routines: routines,
          routineEvents: routineEvents,
          habits: habits,
          checkins: checkins,
          currentUserId: 'user_1',
          partnerName: 'Ancy',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: CoveTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 176,
                  height: 176,
                  child: CoveDayArcCard(
                    summary: midday,
                    onTap: () => tapped = true,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('1:30'), findsOneWidget);
        expect(find.text('Lunch at home'), findsOneWidget);

        await tester.tap(find.byType(CoveDayArcCard));
        expect(tapped, isTrue);
      },
    );
  });
}
