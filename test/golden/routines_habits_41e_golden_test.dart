import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/habits/habit_form_sheet.dart';
import 'package:cove/features/habits/habits_screen.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/routines/routine_event_form_sheet.dart';
import 'package:cove/features/routines/routine_form_sheet.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

final _kFixedDate = DateTime(2026, 10, 15, 10, 30);

const _kAlexUser = CoveUser(
  id: 'user_alex',
  email: 'alex@cove.test',
  displayName: 'Alex',
);

const _kAlexProfile = UserProfileState(
  displayName: 'Alex',
  email: 'alex@cove.test',
  hasCustomName: true,
);

const _kSarahPartnerProfile = PartnerProfileState(
  displayName: 'Sarah',
  userId: 'user_sarah',
);

final _kSeedRoutine = Routine(
  id: 'routine_1',
  homeId: 'home_1',
  name: 'Weekday (Mon – Fri)',
  days: const [1, 2, 3, 4, 5],
  createdAt: _kFixedDate,
);

final _kSeedRoutineEvent = RoutineEvent(
  id: 'rev_1',
  routineId: 'routine_1',
  homeId: 'home_1',
  title: 'Morning Pour-Over & Stretch',
  startMinutes: 450, // 7:30 AM
  endMinutes: 510, // 8:30 AM
  category: 'Fitness',
  notes: '15g coffee, 250ml water, 15m mobility',
  createdAt: _kFixedDate,
);

final _kSeedHabits = <LocalHabit>[
  LocalHabit(
    id: 'habit_1',
    homeId: 'home_1',
    name: 'Morning Walk Together',
    cadence: 'daily',
    targetDaysPerWeek: 7,
    isArchived: false,
    createdAt: _kFixedDate,
    createdBy: 'user_alex',
  ),
  LocalHabit(
    id: 'habit_2',
    homeId: 'home_1',
    name: 'Evening Reading (30m)',
    cadence: 'daily',
    targetDaysPerWeek: 7,
    isArchived: false,
    createdAt: _kFixedDate,
    createdBy: 'user_sarah',
  ),
  LocalHabit(
    id: 'habit_3',
    homeId: 'home_1',
    name: 'Journaling & Breathwork',
    cadence: 'custom:1,3,5@07:30',
    targetDaysPerWeek: -3,
    isArchived: false,
    createdAt: _kFixedDate,
    createdBy: 'user_alex',
  ),
];

final _kSeedHabitCheckins = <LocalHabitCheckin>[
  LocalHabitCheckin(
    id: 'chk_1',
    homeId: 'home_1',
    habitId: 'habit_1',
    checkinDate: '2026-10-15',
    memberId: 'user_alex',
    createdAt: _kFixedDate,
  ),
  LocalHabitCheckin(
    id: 'chk_1_ack',
    homeId: 'home_1',
    habitId: 'habit_1',
    checkinDate: '2026-10-15',
    memberId: 'ack:user_sarah',
    createdAt: _kFixedDate,
  ),
  LocalHabitCheckin(
    id: 'chk_2',
    homeId: 'home_1',
    habitId: 'habit_2',
    checkinDate: '2026-10-15',
    memberId: 'user_sarah',
    createdAt: _kFixedDate,
  ),
];

class _StubAppDatabase extends Fake implements AppDatabase {
  @override
  Future<void> close() async {}
}

class _FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncData(_kAlexUser);

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

class _FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  @override
  String? build() => 'home_1';

  @override
  void setActiveHome(String homeId) => state = homeId;
}

class _FakeActiveHomePartnerNotifier extends Notifier<bool>
    implements ActiveHomePartnerNotifier {
  @override
  bool build() => true;

  @override
  void setHasPartner(bool hasPartner) => state = hasPartner;
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => _kAlexProfile;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => _kSarahPartnerProfile;
}

List<Override> _createOverrides() {
  final stubDb = _StubAppDatabase();
  return [
    appDatabaseProvider.overrideWithValue(stubDb),
    authProvider.overrideWith(_FakeAuthNotifier.new),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    activeHomeHasPartnerProvider.overrideWith(
      _FakeActiveHomePartnerNotifier.new,
    ),
    userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
    partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
    activeHomeOutboxProvider.overrideWith(
      (ref) => Stream.value(const <LocalOutboxEvent>[]),
    ),
    activeHomeHabitsProvider.overrideWith(
      (ref) => Stream.value(_kSeedHabits),
    ),
    activeHomeAllHabitCheckinsProvider.overrideWith(
      (ref) => Stream.value(_kSeedHabitCheckins),
    ),
  ];
}

Widget _sheetHost(Widget sheet) {
  return Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: sheet,
    ),
  );
}

const Set<String> _kKnownLegacyOverflows = {};

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Batch 4.1e Routines & Habits Goldens (3 widths × 2 modes)', () {
    testWidgets('routines_41e_routine_event_form_sheet', (tester) async {
      await goldenMatrix(
        tester,
        'routines_41e_routine_event_form_sheet',
        _sheetHost(
          RoutineEventFormSheet(
            routineId: 'routine_1',
            event: _kSeedRoutineEvent,
          ),
        ),
        overrides: _createOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('routines_41e_routine_form_sheet', (tester) async {
      await goldenMatrix(
        tester,
        'routines_41e_routine_form_sheet',
        _sheetHost(
          RoutineFormSheet(
            routine: _kSeedRoutine,
          ),
        ),
        overrides: _createOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('routines_41e_habits_screen', (tester) async {
      await goldenMatrix(
        tester,
        'routines_41e_habits_screen',
        HabitsScreen(
          initialHabits: _kSeedHabits,
          initialCheckins: _kSeedHabitCheckins,
          currentUser: _kAlexUser,
        ),
        overrides: _createOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });

    testWidgets('routines_41e_habit_form_sheet', (tester) async {
      await goldenMatrix(
        tester,
        'routines_41e_habit_form_sheet',
        _sheetHost(
          HabitFormSheet(
            existing: _kSeedHabits[2],
          ),
        ),
        overrides: _createOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: _kKnownLegacyOverflows,
      );
    });
  });
}
