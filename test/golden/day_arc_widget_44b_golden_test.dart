import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/widgets/cove_day_arc_widget.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

const CoveUser _kSabaUser = CoveUser(
  id: 'user_1',
  email: 'saba@cove.local',
  displayName: 'Saba',
);

const PartnerProfileState _kAncyProfile = PartnerProfileState(
  displayName: 'Ancy',
  hasCustomName: true,
);

final LocalHome _kSeedHome = LocalHome(
  id: 'home_1',
  name: 'The Nest',
  description: 'Bengaluru',
  currency: 'INR',
  createdAt: DateTime(2026, 9, 1, 9, 0),
  createdBy: 'user_1',
);

class _FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncData(_kSabaUser);

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void signInWithDemoUser([
    String name = 'Saba',
    String email = 'saba@cove.local',
  ]) {}

  @override
  Future<void> signOut() async {}
}

class _FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  @override
  String? build() => _kSeedHome.id;

  @override
  void setActiveHome(String homeId) => state = homeId;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => _kAncyProfile;
}

final List<Routine> _kSeedRoutines = <Routine>[
  Routine(
    id: 'routine_weekday',
    homeId: 'home_1',
    name: 'Weekday',
    days: const [1, 2, 3, 4, 5],
    createdAt: DateTime(2026, 9, 1),
  ),
];

final List<RoutineEvent> _kSeedRoutineEvents = <RoutineEvent>[
  RoutineEvent(
    id: 're_morning',
    routineId: 'routine_weekday',
    homeId: 'home_1',
    title: 'Morning walk',
    startMinutes: 8 * 60 + 30, // 8:30 AM (510)
    endMinutes: 9 * 60 + 30, // 9:30 AM (570)
    category: 'fitness',
    createdAt: DateTime(2026, 9, 1),
  ),
  RoutineEvent(
    id: 're_evening',
    routineId: 'routine_weekday',
    homeId: 'home_1',
    title: 'Dinner together',
    startMinutes: 18 * 60 + 45, // 6:45 PM (1125)
    endMinutes: 20 * 60 + 15, // 8:15 PM (1215)
    category: 'meals',
    createdAt: DateTime(2026, 9, 1),
  ),
  RoutineEvent(
    id: 're_night',
    routineId: 'routine_weekday',
    homeId: 'home_1',
    title: 'Lights out',
    startMinutes: 21 * 60 + 30, // 9:30 PM (1290)
    endMinutes: 22 * 60 + 30, // 10:30 PM (1350)
    category: 'rest',
    createdAt: DateTime(2026, 9, 1),
  ),
];

final List<LocalCalendarEvent> _kSeedCalendarEvents = <LocalCalendarEvent>[
  LocalCalendarEvent(
    id: 'ev_solo_partner',
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

final List<LocalHabit> _kSeedHabits = <LocalHabit>[
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
    id: 'h_830am',
    homeId: 'home_1',
    name: 'Vitamins',
    cadence: 'daily@08:30',
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
    id: 'h_10pm',
    homeId: 'home_1',
    name: 'Journal',
    cadence: 'daily@22:00',
    targetDaysPerWeek: 7,
    isArchived: false,
    createdAt: DateTime(2026, 9, 1),
    createdBy: 'user_2',
  ),
];

List<LocalHabitCheckin> _checkinsForIds(List<String> habitIds) {
  return habitIds
      .map(
        (id) => LocalHabitCheckin(
          id: 'chk_$id',
          homeId: 'home_1',
          habitId: id,
          checkinDate: '2026-10-05',
          memberId: 'user_1',
          createdAt: DateTime(2026, 10, 5, 8, 0),
        ),
      )
      .toList();
}

List<Override> _buildOverrides({
  required DateTime now,
  required List<Routine> routines,
  required List<RoutineEvent> routineEvents,
  required List<LocalCalendarEvent> events,
  required List<LocalHabit> habits,
  required List<LocalHabitCheckin> checkins,
}) {
  return <Override>[
    authProvider.overrideWith(_FakeAuthNotifier.new),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    activeHomeProvider.overrideWith((ref) => Stream.value(_kSeedHome)),
    partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
    dayArcReferenceDateProvider.overrideWithValue(now),
    activeHomeRoutinesProvider.overrideWith((ref) => Stream.value(routines)),
    activeHomeAllRoutineEventsProvider.overrideWith(
      (ref) => Stream.value(routineEvents),
    ),
    activeHomeCalendarEventsProvider.overrideWith(
      (ref) => Stream.value(events),
    ),
    activeHomeHabitsProvider.overrideWith((ref) => Stream.value(habits)),
    activeHomeAllHabitCheckinsProvider.overrideWith(
      (ref) => Stream.value(checkins),
    ),
  ];
}

Future<void> _pumpDayArcGolden(
  WidgetTester tester, {
  required String goldenName,
  required Brightness brightness,
  required DateTime now,
  required List<Routine> routines,
  required List<RoutineEvent> routineEvents,
  required List<LocalCalendarEvent> events,
  required List<LocalHabit> habits,
  required List<LocalHabitCheckin> checkins,
}) async {
  await loadCoveFonts();
  const surfaceSize = Size(208, 208);

  await withClock(Clock.fixed(now), () async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      originalOnError?.call(details);
    };
    try {
      tester.view
        ..physicalSize = surfaceSize * 2
        ..devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      final theme = coveThemeFor(brightness);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _buildOverrides(
            now: now,
            routines: routines,
            routineEvents: routineEvents,
            events: events,
            habits: habits,
            checkins: checkins,
          ),
          child: MediaQuery(
            data: const MediaQueryData(
              size: surfaceSize,
              textScaler: TextScaler.linear(1.0),
            ),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: Builder(
                builder: (context) => ColoredBox(
                  color: context.cv.surfaceCanvas,
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 176,
                      height: 176,
                      child: CoveDayArcWidget(),
                    ),
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
    } finally {
      FlutterError.onError = originalOnError;
    }
  });
}

void main() {
  group('4.4b — The Day Arc Home-Screen Widget Goldens', () {
    for (final mode in const [
      ('dark', Brightness.dark),
      ('light', Brightness.light),
    ]) {
      final modeName = mode.$1;
      final brightness = mode.$2;

      testWidgets('day_arc_widget.morning.$modeName', (tester) async {
        await _pumpDayArcGolden(
          tester,
          goldenName: 'day_arc_widget.morning.$modeName',
          brightness: brightness,
          now: DateTime(2026, 10, 5, 8, 10), // 8:10 AM -> next 8:30 Morning walk
          routines: _kSeedRoutines,
          routineEvents: _kSeedRoutineEvents,
          events: _kSeedCalendarEvents,
          habits: _kSeedHabits,
          checkins: _checkinsForIds(const ['h_7am']),
        );
      });

      testWidgets('day_arc_widget.midday.$modeName', (tester) async {
        await _pumpDayArcGolden(
          tester,
          goldenName: 'day_arc_widget.midday.$modeName',
          brightness: brightness,
          now: DateTime(2026, 10, 5, 13, 30), // 1:30 PM -> 1:30 Lunch at home
          routines: _kSeedRoutines,
          routineEvents: _kSeedRoutineEvents,
          events: _kSeedCalendarEvents,
          habits: _kSeedHabits,
          checkins: _checkinsForIds(const ['h_7am', 'h_830am']),
        );
      });

      testWidgets('day_arc_widget.night.$modeName', (tester) async {
        await _pumpDayArcGolden(
          tester,
          goldenName: 'day_arc_widget.night.$modeName',
          brightness: brightness,
          now: DateTime(2026, 10, 5, 21, 15), // 9:15 PM -> next 9:30 Lights out
          routines: _kSeedRoutines,
          routineEvents: _kSeedRoutineEvents,
          events: _kSeedCalendarEvents,
          habits: _kSeedHabits,
          checkins: _checkinsForIds(const ['h_7am', 'h_830am', 'h_6pm']),
        );
      });

      testWidgets('day_arc_widget.empty_day.$modeName', (tester) async {
        await _pumpDayArcGolden(
          tester,
          goldenName: 'day_arc_widget.empty_day.$modeName',
          brightness: brightness,
          now: DateTime(2026, 10, 5, 9, 41),
          routines: const [],
          routineEvents: const [],
          events: const [],
          habits: const [],
          checkins: const [],
        );
      });
    }
  });
}
