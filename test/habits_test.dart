import 'dart:async';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_checkbox.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/habits/habit_controller.dart';
import 'package:cove/features/habits/habit_form_sheet.dart';
import 'package:cove/features/habits/habit_streak_calculator.dart';
import 'package:cove/features/habits/habits_screen.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _map = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _map[key] = value;
    } else {
      _map.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _map[key];
  }
}

class FakeTrackingSyncEngine extends SyncEngineImpl {
  final List<Map<String, dynamic>> dispatchedEvents = [];
  String currentActorId = 'user_alex';

  FakeTrackingSyncEngine({
    required super.eventStore,
    required super.localStateStore,
    required super.encryptionService,
    required super.keyStore,
  });

  @override
  Future<void> start({String? activeHomeId, List<int>? activeHomeKey}) async {}

  @override
  Future<void> flushOutbox() async {}

  @override
  Future<void> dispatchLocalEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    String? homeId,
  }) async {
    dispatchedEvents.add({
      'eventType': eventType,
      'payload': payload,
      'homeId': homeId,
    });
    await localStateStore.applyEvent(
      homeId: homeId ?? 'home_1',
      eventType: eventType,
      payload: payload,
      timestamp: DateTime.now().toUtc(),
      authorId: currentActorId,
    );
  }
}

class FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  final AsyncValue<CoveUser?> initial;

  FakeAuthNotifier(this.initial);

  @override
  AsyncValue<CoveUser?> build() => initial;

  @override
  Future<void> signInWithGoogle() async {}



  @override
  void signInWithDemoUser([String name = 'Alex', String email = 'alex@cove.local']) {}

  @override
  Future<void> signOut() async {}
}

class FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  final String? initial;

  FakeActiveHomeNotifier(this.initial);

  @override
  String? build() => initial;

  @override
  void setActiveHome(String homeId) {
    state = homeId;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeTrackingSyncEngine fakeSyncEngine;
  late LocalStateStoreImpl localStateStore;
  late FakeSecureStorage secureStorage;
  late HomeKeyStore homeKeyStore;

  const homeId = 'home_1';
  const userIdAlex = 'user_alex';
  const userIdSarah = 'user_sarah';

  final alexUser = const CoveUser(
    id: userIdAlex,
    email: 'alex@example.com',
    displayName: 'Alex',
  );

  final sarahUser = const CoveUser(
    id: userIdSarah,
    email: 'sarah@example.com',
    displayName: 'Sarah',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    localStateStore = LocalStateStoreImpl(db);
    final cryptoService = SodiumCryptoService();
    secureStorage = FakeSecureStorage();
    homeKeyStore = HomeKeyStore(storage: secureStorage);

    fakeSyncEngine = FakeTrackingSyncEngine(
      eventStore: EventStoreImpl(db: db, cryptoService: cryptoService),
      localStateStore: localStateStore,
      encryptionService: cryptoService,
      keyStore: homeKeyStore,
    );

    await db.into(db.localHomes).insertOnConflictUpdate(
          LocalHomesCompanion.insert(
            id: homeId,
            name: 'Our Home',
            createdAt: DateTime.now().toUtc(),
            createdBy: userIdAlex,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  List<Override> createOverrides({
    CoveUser? user,
    ValueNotifier<List<LocalHabit>>? habitsNotifier,
    ValueNotifier<List<LocalHabitCheckin>>? checkinsNotifier,
  }) {
    final effectiveUser = user ?? alexUser;
    fakeSyncEngine.currentActorId = effectiveUser.id;
    final effectiveHabitsNotifier = habitsNotifier ?? ValueNotifier<List<LocalHabit>>([]);
    final effectiveCheckinsNotifier = checkinsNotifier ?? ValueNotifier<List<LocalHabitCheckin>>([]);

    Future<void> reload() async {
      final habits = await db.getHabits(homeId, currentUserId: effectiveUser.id);
      effectiveHabitsNotifier.value = habits;
      final checkins = await db.getAllHabitCheckins(homeId);
      effectiveCheckinsNotifier.value = checkins;
    }

    if (habitsNotifier == null) {
      db.getHabits(homeId, currentUserId: effectiveUser.id).then((h) {
        effectiveHabitsNotifier.value = h;
      });
    }
    if (checkinsNotifier == null) {
      db.getAllHabitCheckins(homeId).then((c) {
        effectiveCheckinsNotifier.value = c;
      });
    }

    return [
      appDatabaseProvider.overrideWithValue(db),
      activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier(homeId)),
      syncEngineProvider.overrideWithValue(fakeSyncEngine),
      authProvider.overrideWith(() => FakeAuthNotifier(AsyncData(effectiveUser))),
      coveEmitActionProvider.overrideWithValue(
        ({required String eventType, required Map<String, dynamic> payload, String? targetHomeId}) async {
          await fakeSyncEngine.dispatchLocalEvent(
            eventType: eventType,
            payload: payload,
            homeId: targetHomeId ?? homeId,
          );
          await reload();
        },
      ),
      habitControllerProvider.overrideWith((ref) => _TestHabitController(ref, onMutate: reload)),
      activeHomeHabitsProvider.overrideWith((ref) {
        final controller = StreamController<List<LocalHabit>>();
        controller.add(effectiveHabitsNotifier.value);
        void listener() {
          if (!controller.isClosed) {
            controller.add(effectiveHabitsNotifier.value);
          }
        }
        effectiveHabitsNotifier.addListener(listener);
        ref.onDispose(() {
          effectiveHabitsNotifier.removeListener(listener);
          controller.close();
        });
        return controller.stream;
      }),
      activeHomeAllHabitCheckinsProvider.overrideWith((ref) {
        final controller = StreamController<List<LocalHabitCheckin>>();
        controller.add(effectiveCheckinsNotifier.value);
        void listener() {
          if (!controller.isClosed) {
            controller.add(effectiveCheckinsNotifier.value);
          }
        }
        effectiveCheckinsNotifier.addListener(listener);
        ref.onDispose(() {
          effectiveCheckinsNotifier.removeListener(listener);
          controller.close();
        });
        return controller.stream;
      }),
      partnerProfileProvider.overrideWith(() => FakePartnerProfileNotifier()),
      activeHomeOutboxProvider.overrideWith((ref) => Stream.value([])),
    ];
  }

  Widget createWidgetUnderTest({
    required Widget child,
    CoveUser? user,
    ValueNotifier<List<LocalHabit>>? habitsNotifier,
    ValueNotifier<List<LocalHabitCheckin>>? checkinsNotifier,
  }) {
    return ProviderScope(
      overrides: createOverrides(
        user: user,
        habitsNotifier: habitsNotifier,
        checkinsNotifier: checkinsNotifier,
      ),
      child: MaterialApp(
        theme: CoveTheme.darkTheme,
        home: child,
      ),
    );
  }

  group('Habit Tracking Tests', () {
    testWidgets('1. Empty state renders correctly with Create First Habit button',
        (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(child: const HabitsScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Habits & Rhythms'), findsOneWidget);
      expect(find.text('No Habits Logged'), findsOneWidget);
      expect(find.text('Create First Habit'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('2. Logging a SHARED habit emits habit_created and updates list',
        (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(child: const HabitsScreen()),
      );
      await tester.pumpAndSettle();

      // Open creation sheet via "+ New" button
      await tester.tap(find.widgetWithText(CovePillButton, '+ New'));
      await tester.pumpAndSettle();

      expect(find.byType(HabitFormSheet), findsOneWidget);
      expect(find.text('New Habit or Rhythm'), findsOneWidget);

      // Enter name
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Morning Walk');
      await tester.pump();

      // Submit
      final createButton = find.widgetWithText(CovePillButton, 'Create Habit');
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // 1. Verify dispatchLocalEvent was called
      expect(fakeSyncEngine.dispatchedEvents.length, equals(1));
      expect(fakeSyncEngine.dispatchedEvents.first['eventType'], equals('habit_created'));
      final payload = fakeSyncEngine.dispatchedEvents.first['payload'] as Map<String, dynamic>;
      expect(payload['name'], equals('Morning Walk'));
      expect(payload['cadence'], equals('daily'));

      // 2. Verify UI update
      expect(find.text('YOUR SHARED RHYTHMS'), findsOneWidget);
      expect(find.text('Morning Walk'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('3. STRUCTURAL PRIVACY: Private habit NEVER emits to sync engine',
        (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(child: const HabitsScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CovePillButton, '+ New'));
      await tester.pumpAndSettle();

      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Meditation & Breathwork');
      await tester.pump();

      // Select 'Private to Me'
      await tester.tap(find.text('Private to Me'));
      await tester.pump();

      await tester.tap(find.widgetWithText(CovePillButton, 'Create Habit'));
      await tester.pumpAndSettle();

      // ZERO sync engine events emitted!
      expect(fakeSyncEngine.dispatchedEvents, isEmpty);

      // But habit is visible in user's UI under PRIVATE TO YOU
      expect(find.text('PRIVATE TO YOU'), findsOneWidget);
      expect(find.text('Meditation & Breathwork'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets(
        '4. PARTNER VIEW: Partner cannot see private habits and gets read-only view for shared habits',
        (tester) async {
      // Alex creates 1 shared habit and 1 private habit
      final now = DateTime.now().toUtc();
      await db.into(db.localHabits).insert(
            LocalHabitsCompanion.insert(
              id: 'habit_alex_shared',
              homeId: homeId,
              name: 'Drink 2L Water',
              cadence: const Value('daily'),
              targetDaysPerWeek: const Value(7),
              isArchived: const Value(false),
              createdAt: now,
              createdBy: userIdAlex,
            ),
          );

      await db.into(db.localHabits).insert(
            LocalHabitsCompanion.insert(
              id: 'habit_alex_private',
              homeId: homeId,
              name: 'Private Journaling',
              cadence: const Value('daily'),
              targetDaysPerWeek: const Value(-7), // Private
              isArchived: const Value(false),
              createdAt: now,
              createdBy: userIdAlex,
            ),
          );

      // View as Sarah (Partner)
      await tester.pumpWidget(
        createWidgetUnderTest(
          child: const HabitsScreen(),
          user: sarahUser,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Private habit MUST NOT appear for partner
      expect(find.text('Private Journaling'), findsNothing);
      expect(find.text('PRIVATE TO YOU'), findsNothing);

      // 2. Shared habit appears in PARTNER'S RHYTHMS as Read-only
      expect(find.text("PARTNER'S RHYTHMS"), findsOneWidget);
      expect(find.text('Read-only'), findsOneWidget);
      expect(find.text('Drink 2L Water'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets(
        '5. STRICT ACTOR ENFORCEMENT: A partner CANNOT check in someone else\'s habit',
        (tester) async {
      final now = DateTime.now().toUtc();
      final todayStr = HabitStreakCalculator.formatDate(now);

      // Habit owned by Alex
      await db.into(db.localHabits).insert(
            LocalHabitsCompanion.insert(
              id: 'habit_alex',
              homeId: homeId,
              name: 'Guitar Practice',
              cadence: const Value('daily'),
              targetDaysPerWeek: const Value(7),
              isArchived: const Value(false),
              createdAt: now,
              createdBy: userIdAlex,
            ),
          );

      // Sarah attempts to apply check-in event for Alex's habit
      await localStateStore.applyEvent(
        homeId: homeId,
        eventType: 'habit_checkin_toggled',
        payload: {
          'habit_id': 'habit_alex',
          'checkin_date': todayStr,
          'checked': true,
        },
        timestamp: now,
        authorId: userIdSarah, // NOT the owner!
      );

      // Verify that no check-in row was inserted into localHabitCheckins
      final checkins = await db.getAllHabitCheckins(homeId);
      expect(checkins, isEmpty,
          reason: 'Check-in event by non-owner must be rejected by local_state_store');
    });

    testWidgets(
        '6. User can check in their own habit and quiet acknowledge can be left by partner',
        (tester) async {
      final now = DateTime.now().toUtc();

      // 1. Create habit owned by Alex
      await db.into(db.localHabits).insert(
            LocalHabitsCompanion.insert(
              id: 'habit_walk',
              homeId: homeId,
              name: 'Morning Walk',
              cadence: const Value('daily'),
              targetDaysPerWeek: const Value(7),
              isArchived: const Value(false),
              createdAt: now.subtract(const Duration(days: 10)),
              createdBy: userIdAlex,
            ),
          );

      // View as Alex
      await tester.pumpWidget(
        createWidgetUnderTest(
          child: const HabitsScreen(),
          user: alexUser,
        ),
      );
      await tester.pumpAndSettle();

      // Alex checks in today by tapping the checkbox
      final checkboxFinder = find.byType(CoveCheckbox).first;
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      // Verify sync event emitted
      expect(fakeSyncEngine.dispatchedEvents.length, 1);
      final checkinEvent = fakeSyncEngine.dispatchedEvents.first;
      expect(checkinEvent['eventType'], 'habit_checkin_toggled');
      expect(checkinEvent['payload']['habit_id'], 'habit_walk');
      expect(checkinEvent['payload']['checked'], true);

      // Now view as Sarah (Partner)
      final sarahHabits = await db.getHabits(homeId, currentUserId: sarahUser.id);
      final sarahCheckins = await db.getAllHabitCheckins(homeId);

      await tester.pumpWidget(
        createWidgetUnderTest(
          child: HabitsScreen(
            initialHabits: sarahHabits,
            initialCheckins: sarahCheckins,
            currentUser: sarahUser,
          ),
          user: sarahUser,
          habitsNotifier: ValueNotifier(sarahHabits),
          checkinsNotifier: ValueNotifier(sarahCheckins),
        ),
      );
      await tester.pumpAndSettle();

      // Sarah sees it completed today and taps the quiet acknowledgment button
      expect(find.text('Daily • Completed today'), findsOneWidget);
      final heartButton = find.byIcon(Icons.favorite_border);
      expect(heartButton, findsOneWidget);

      await tester.tap(heartButton);
      await tester.pumpAndSettle();

      // Check acknowledgment event
      expect(fakeSyncEngine.dispatchedEvents.length, 2);
      final ackEvent = fakeSyncEngine.dispatchedEvents.last;
      expect(ackEvent['eventType'], 'habit_checkin_acknowledged');
      expect(ackEvent['payload']['habit_id'], 'habit_walk');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    test('7. Deterministic Streak Calculator verifies daily and weekly chains',
        () {
      final now = DateTime(2026, 9, 10);
      final habitDaily = LocalHabit(
        id: 'h1',
        homeId: homeId,
        name: 'Daily Yoga',
        cadence: 'daily',
        targetDaysPerWeek: 7,
        isArchived: false,
        createdAt: now.subtract(const Duration(days: 30)),
        createdBy: userIdAlex,
      );

      final checkins = [
        LocalHabitCheckin(
          id: 'c1',
          homeId: homeId,
          habitId: 'h1',
          checkinDate: '2026-09-10', // today
          memberId: userIdAlex,
          createdAt: now,
        ),
        LocalHabitCheckin(
          id: 'c2',
          homeId: homeId,
          habitId: 'h1',
          checkinDate: '2026-09-09', // yesterday
          memberId: userIdAlex,
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        LocalHabitCheckin(
          id: 'c3',
          homeId: homeId,
          habitId: 'h1',
          checkinDate: '2026-09-08', // 2 days ago
          memberId: userIdAlex,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ];

      final result = HabitStreakCalculator.calculate(
        habit: habitDaily,
        checkins: checkins,
        referenceDate: now,
      );

      expect(result.currentStreak, 3);
      expect(result.bestStreak, 3);
      expect(result.isCheckedToday, true);
    });
  });
}

class _TestHabitController extends HabitController {
  final Future<void> Function() onMutate;

  _TestHabitController(super.ref, {required this.onMutate});

  @override
  Future<String> createHabit({
    required String name,
    String cadence = 'daily',
    int targetDaysPerWeek = 7,
    HabitVisibility visibility = HabitVisibility.shared,
  }) async {
    final res = await super.createHabit(
      name: name,
      cadence: cadence,
      targetDaysPerWeek: targetDaysPerWeek,
      visibility: visibility,
    );
    await onMutate();
    return res;
  }

  @override
  Future<void> toggleCheckin({
    required LocalHabit habit,
    DateTime? date,
    required bool checked,
  }) async {
    await super.toggleCheckin(
      habit: habit,
      date: date,
      checked: checked,
    );
    await onMutate();
  }

  @override
  Future<void> acknowledgeCheckin({
    required LocalHabit habit,
    DateTime? date,
  }) async {
    await super.acknowledgeCheckin(
      habit: habit,
      date: date,
    );
    await onMutate();
  }

  @override
  Future<void> deleteHabit(LocalHabit habit) async {
    await super.deleteHabit(habit);
    await onMutate();
  }
}

class FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() {
    return const PartnerProfileState();
  }
}

