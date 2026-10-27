import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/routines/routine_screen.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/providers/first_run_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden_harness.dart';

final _kFixedDate = DateTime(2026, 10, 15, 10, 30);

const _kSabaUser = CoveUser(
  id: 'user_saba',
  email: 'saba@cove.app',
  displayName: 'Saba',
);

const _kSabaProfile = UserProfileState(
  displayName: 'Saba',
  email: 'saba@cove.app',
  hasCustomName: true,
);

const _kAncyPartnerProfile = PartnerProfileState(
  displayName: 'Ancy',
  userId: 'user_ancy',
  hasCustomName: true,
);

final _kHome = LocalHome(
  id: 'home_1',
  name: 'Our Home',
  currency: 'INR',
  createdBy: 'user_saba',
  createdAt: _kFixedDate,
);

final _kRoutines = <Routine>[
  Routine(
    id: 'routine_everyday',
    homeId: 'home_1',
    name: 'Everyday',
    days: const [1, 2, 3, 4, 5, 6, 7],
    createdAt: _kFixedDate,
  ),
  Routine(
    id: 'routine_weekdays',
    homeId: 'home_1',
    name: 'Weekdays',
    days: const [1, 2, 3, 4, 5],
    createdAt: _kFixedDate,
  ),
  Routine(
    id: 'routine_weekend',
    homeId: 'home_1',
    name: 'Weekend',
    days: const [6, 7],
    createdAt: _kFixedDate,
  ),
];

final _kEverydayEvents = <RoutineEvent>[
  RoutineEvent(
    id: 'ev_every_1',
    routineId: 'routine_everyday',
    homeId: 'home_1',
    title: 'Coffee together',
    startMinutes: 390, // 6:30 AM
    endMinutes: 420, // 7:00 AM
    owner: 'both',
    createdAt: _kFixedDate,
  ),
  RoutineEvent(
    id: 'ev_every_2',
    routineId: 'routine_everyday',
    homeId: 'home_1',
    title: 'Walk · Lyla & Cabo',
    startMinutes: 420, // 7:00 AM
    endMinutes: 465, // 7:45 AM
    owner: 'user_saba',
    createdAt: _kFixedDate,
  ),
  RoutineEvent(
    id: 'ev_every_3',
    routineId: 'routine_everyday',
    homeId: 'home_1',
    title: 'Morning stretch',
    startMinutes: 420, // 7:00 AM
    endMinutes: 465, // 7:45 AM
    owner: 'user_ancy',
    createdAt: _kFixedDate,
  ),
];

final _kWeekdaysEvents = <RoutineEvent>[
  RoutineEvent(
    id: 'ev_wd_1',
    routineId: 'routine_weekdays',
    homeId: 'home_1',
    title: 'Coffee together',
    startMinutes: 390, // 6:30 AM
    endMinutes: 420, // 7:00 AM
    owner: 'both',
    createdAt: _kFixedDate,
  ),
  RoutineEvent(
    id: 'ev_wd_2',
    routineId: 'routine_weekdays',
    homeId: 'home_1',
    title: 'Walk · Lyla & Cabo',
    startMinutes: 420, // 7:00 AM
    endMinutes: 465, // 7:45 AM
    owner: 'user_saba',
    createdAt: _kFixedDate,
  ),
  RoutineEvent(
    id: 'ev_wd_3',
    routineId: 'routine_weekdays',
    homeId: 'home_1',
    title: 'Yoga',
    startMinutes: 420, // 7:00 AM
    endMinutes: 465, // 7:45 AM
    owner: 'user_ancy',
    createdAt: _kFixedDate,
  ),
  RoutineEvent(
    id: 'ev_wd_4',
    routineId: 'routine_weekdays',
    homeId: 'home_1',
    title: 'Breakfast',
    startMinutes: 480, // 8:00 AM
    endMinutes: 510, // 8:30 AM
    owner: 'both',
    createdAt: _kFixedDate,
  ),
  RoutineEvent(
    id: 'ev_wd_5',
    routineId: 'routine_weekdays',
    homeId: 'home_1',
    title: 'Work',
    startMinutes: 540, // 9:00 AM
    endMinutes: 750, // 12:30 PM
    owner: 'user_saba',
    createdAt: _kFixedDate,
  ),
  RoutineEvent(
    id: 'ev_wd_6',
    routineId: 'routine_weekdays',
    homeId: 'home_1',
    title: 'Deep work',
    startMinutes: 570, // 9:30 AM
    endMinutes: 750, // 12:30 PM
    owner: 'user_ancy',
    createdAt: _kFixedDate,
  ),
];

final _kWeekendEvents = <RoutineEvent>[
  RoutineEvent(
    id: 'ev_wk_1',
    routineId: 'routine_weekend',
    homeId: 'home_1',
    title: 'Long run',
    startMinutes: 420, // 7:00 AM
    endMinutes: 480, // 8:00 AM
    owner: 'user_saba',
    createdAt: _kFixedDate,
  ),
  RoutineEvent(
    id: 'ev_wk_2',
    routineId: 'routine_weekend',
    homeId: 'home_1',
    title: 'Pilates',
    startMinutes: 420, // 7:00 AM
    endMinutes: 480, // 8:00 AM
    owner: 'user_ancy',
    createdAt: _kFixedDate,
  ),
  RoutineEvent(
    id: 'ev_wk_3',
    routineId: 'routine_weekend',
    homeId: 'home_1',
    title: 'Slow breakfast',
    startMinutes: 510, // 8:30 AM
    endMinutes: 570, // 9:30 AM
    owner: 'both',
    createdAt: _kFixedDate,
  ),
  RoutineEvent(
    id: 'ev_wk_4',
    routineId: 'routine_weekend',
    homeId: 'home_1',
    title: 'Farmers market',
    startMinutes: 600, // 10:00 AM
    endMinutes: 690, // 11:30 AM
    owner: 'both',
    createdAt: _kFixedDate,
  ),
];

final _kAllEvents = <RoutineEvent>[
  ..._kEverydayEvents,
  ..._kWeekdaysEvents,
  ..._kWeekendEvents,
];

class _StubAppDatabase extends Fake implements AppDatabase {
  @override
  Future<void> close() async {}
}

class _FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncData(_kSabaUser);

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void signInWithDemoUser([
    String name = 'Saba',
    String email = 'saba@cove.app',
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
  UserProfileState build() => _kSabaProfile;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => _kAncyPartnerProfile;
}

class _FixedSelectedRoutineNotifier extends SelectedRoutineNotifier {
  final String _initialId;
  _FixedSelectedRoutineNotifier(this._initialId);

  @override
  String? build() => _initialId;
}

class _NoopRoutineController extends RoutineController {
  _NoopRoutineController(super.ref);

  @override
  Future<void> seedDefaultRoutinesIfEmpty() async {}
}

List<Override> _buildOverrides({required String selectedRoutineId}) {
  final stubDb = _StubAppDatabase();
  return <Override>[
    appDatabaseProvider.overrideWithValue(stubDb),
    authProvider.overrideWith(_FakeAuthNotifier.new),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    activeHomeProvider.overrideWith((ref) => Stream.value(_kHome)),
    activeHomeHasPartnerProvider.overrideWith(
      _FakeActiveHomePartnerNotifier.new,
    ),
    userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
    partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
    routineControllerProvider.overrideWith(_NoopRoutineController.new),
    selectedRoutineIdProvider.overrideWith(
      () => _FixedSelectedRoutineNotifier(selectedRoutineId),
    ),
    activeHomeRoutinesProvider.overrideWith(
      (ref) => Stream.value(_kRoutines),
    ),
    activeHomeAllRoutineEventsProvider.overrideWith(
      (ref) => Stream.value(_kAllEvents),
    ),
    routineEventsProvider('routine_everyday').overrideWith(
      (ref) => Stream.value(_kEverydayEvents),
    ),
    routineEventsProvider('routine_weekdays').overrideWith(
      (ref) => Stream.value(_kWeekdaysEvents),
    ),
    routineEventsProvider('routine_weekend').overrideWith(
      (ref) => Stream.value(_kWeekendEvents),
    ),
    firstRunProvider(CoveScreen.routines).overrideWithValue(
      FirstRunState.inUse,
    ),
  ];
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Batch 4.7d — Routine Lanes Goldens (3 widths × 2 modes)', () {
    testWidgets('1. Everyday routine lanes (routines_47d_everyday)', (
      tester,
    ) async {
      await goldenMatrix(
        tester,
        'routines_47d_everyday',
        const RoutineScreen(),
        overrides: _buildOverrides(selectedRoutineId: 'routine_everyday'),
      );
    });

    testWidgets('2. Weekdays routine lanes (routines_47d_weekdays)', (
      tester,
    ) async {
      await goldenMatrix(
        tester,
        'routines_47d_weekdays',
        const RoutineScreen(),
        overrides: _buildOverrides(selectedRoutineId: 'routine_weekdays'),
      );
    });

    testWidgets('3. Weekend routine lanes (routines_47d_weekend)', (
      tester,
    ) async {
      await goldenMatrix(
        tester,
        'routines_47d_weekend',
        const RoutineScreen(),
        overrides: _buildOverrides(selectedRoutineId: 'routine_weekend'),
      );
    });

    testWidgets(
      '4. Weekdays with one person faded, shared gold stays (routines_47d_one_person_faded)',
      (tester) async {
        await goldenMatrix(
          tester,
          'routines_47d_one_person_faded',
          const RoutineScreen(
            initialFocusedLane: RoutineLaneFocus.yours,
          ),
          overrides: _buildOverrides(selectedRoutineId: 'routine_weekdays'),
        );
      },
    );
  });
}
