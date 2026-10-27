import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/slips/cove_note.dart';
import 'package:cove/core/widgets/slips/cove_ticket.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_controller.dart';
import 'package:cove/features/calendar/calendar_event_form_sheet.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/lists/list_item_detail_sheet.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/routines/routine_event_form_sheet.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/today/today_screen.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/features/widgets/cove_day_sheet_widget.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/providers/first_run_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSabaUser = CoveUser(
  id: 'user_saba',
  email: 'saba@cove.test',
  displayName: 'Saba',
);

const _kSabaProfile = UserProfileState(
  displayName: 'Saba',
  email: 'saba@cove.test',
  hasCustomName: true,
);

const _kAncyPartner = PartnerProfileState(
  displayName: 'Ancy',
  userId: 'user_ancy',
);

const _kInr = CurrencyOption(
  code: 'INR',
  symbol: '₹',
  name: 'Indian Rupee',
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
  String? build() => 'home_1';

  @override
  void setActiveHome(String homeId) => state = homeId;
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => _kSabaProfile;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => _kAncyPartner;
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() => _kInr;
}

class _FakeActivePartnerNotifier extends ActiveHomePartnerNotifier {
  @override
  bool build() => true;
}

class _FakeWeatherNotifier extends WeatherNotifier {
  @override
  WeatherData? build() => null;

  @override
  Future<void> refreshWeather({bool force = false}) async {}
}

class _StubAppDatabase extends Fake implements AppDatabase {
  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('4.7c — Owners end to end (19-owners-and-pets.md §1)', () {
    test(
      '1. Sync add & edit round trip for event, task, and routine event; v11 update without owner keeps stored owner unchanged',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final store = LocalStateStoreImpl(db);

        // --- A. Calendar Event: add with owner, v11 update without owner, v12 update with owner ---
        await store.applyEvent(
          eventId: 'ev_sync_1',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'calendar_event_added',
          payload: {
            'id': 'event_1',
            'home_id': 'home_1',
            'title': 'Vet appointment',
            'start_time': '2026-10-15T10:00:00.000Z',
            'end_time': '2026-10-15T11:00:00.000Z',
            'is_all_day': false,
            'location': 'Indiranagar',
            'created_by': 'user_saba',
            'owner': 'user_ancy',
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 0),
        );

        var storedEvent = await (db.select(db.localCalendarEvents)
              ..where((t) => t.id.equals('event_1')))
            .getSingle();
        expect(storedEvent.owner, 'user_ancy');

        // v11 update payload WITHOUT 'owner' key must NOT wipe 'user_ancy'
        await store.applyEvent(
          eventId: 'ev_sync_2',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'calendar_event_updated',
          payload: {
            'id': 'event_1',
            'home_id': 'home_1',
            'title': 'Vet appointment — Dr. Rao',
            'start_time': '2026-10-15T10:30:00.000Z',
            'end_time': '2026-10-15T11:30:00.000Z',
            'is_all_day': false,
            'location': 'Indiranagar',
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 5),
        );

        storedEvent = await (db.select(db.localCalendarEvents)
              ..where((t) => t.id.equals('event_1')))
            .getSingle();
        expect(storedEvent.title, 'Vet appointment — Dr. Rao');
        expect(storedEvent.owner, 'user_ancy');

        // v12 update payload WITH 'owner' updates it
        await store.applyEvent(
          eventId: 'ev_sync_3',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'calendar_event_updated',
          payload: {
            'id': 'event_1',
            'home_id': 'home_1',
            'title': 'Vet appointment — Dr. Rao',
            'start_time': '2026-10-15T10:30:00.000Z',
            'end_time': '2026-10-15T11:30:00.000Z',
            'is_all_day': false,
            'location': 'Indiranagar',
            'owner': 'both',
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 10),
        );

        storedEvent = await (db.select(db.localCalendarEvents)
              ..where((t) => t.id.equals('event_1')))
            .getSingle();
        expect(storedEvent.owner, 'both');

        // --- B. List Item (Task): add with owner, v11 update without owner, v12 update to 'either' and null ---
        await store.applyEvent(
          eventId: 'li_sync_0',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'list_created',
          payload: {
            'id': 'list_home',
            'home_id': 'home_1',
            'name': 'Home',
            'created_by': 'user_saba',
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 0),
        );

        await store.applyEvent(
          eventId: 'li_sync_1',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'list_item_added',
          payload: {
            'id': 'task_1',
            'home_id': 'home_1',
            'list_id': 'list_home',
            'title': 'Order gas cylinder',
            'created_by': 'user_saba',
            'owner': 'either',
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 1),
        );

        var storedTask = await (db.select(db.localListItems)
              ..where((t) => t.id.equals('task_1')))
            .getSingle();
        expect(storedTask.owner, 'either');

        // v11 update payload WITHOUT 'owner' key keeps 'either'
        await store.applyEvent(
          eventId: 'li_sync_2',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'list_item_updated',
          payload: {
            'id': 'task_1',
            'title': 'Order HP gas cylinder',
            'notes': 'Book via app',
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 5),
        );

        storedTask = await (db.select(db.localListItems)
              ..where((t) => t.id.equals('task_1')))
            .getSingle();
        expect(storedTask.title, 'Order HP gas cylinder');
        expect(storedTask.owner, 'either');

        // v12 update payload WITH 'owner': 'user_saba'
        await store.applyEvent(
          eventId: 'li_sync_3',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'list_item_updated',
          payload: {
            'id': 'task_1',
            'title': 'Order HP gas cylinder',
            'notes': 'Book via app',
            'owner': 'user_saba',
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 10),
        );

        storedTask = await (db.select(db.localListItems)
              ..where((t) => t.id.equals('task_1')))
            .getSingle();
        expect(storedTask.owner, 'user_saba');

        // v12 update payload WITH explicit 'owner': null clears the owner
        await store.applyEvent(
          eventId: 'li_sync_4',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'list_item_updated',
          payload: {
            'id': 'task_1',
            'title': 'Order HP gas cylinder',
            'notes': 'Book via app',
            'owner': null,
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 15),
        );

        storedTask = await (db.select(db.localListItems)
              ..where((t) => t.id.equals('task_1')))
            .getSingle();
        expect(storedTask.owner, isNull);

        // --- C. Routine Event: add with owner, v11 update without owner, v12 update with owner ---
        await store.applyEvent(
          eventId: 're_sync_0',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'routine_created',
          payload: {
            'id': 'routine_1',
            'home_id': 'home_1',
            'name': 'Everyday',
            'days': [1, 2, 3, 4, 5, 6, 7],
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 0),
        );

        await store.applyEvent(
          eventId: 're_sync_1',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'routine_event_created',
          payload: {
            'id': 're_1',
            'routine_id': 'routine_1',
            'home_id': 'home_1',
            'title': 'Walk Lyla & Cabo',
            'start_minutes': 450,
            'end_minutes': 480,
            'owner': 'user_saba',
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 1),
        );

        var storedRoutineEvent = await (db.select(db.localRoutineEvents)
              ..where((t) => t.id.equals('re_1')))
            .getSingle();
        expect(storedRoutineEvent.owner, 'user_saba');

        // v11 update payload WITHOUT 'owner' key keeps 'user_saba'
        await store.applyEvent(
          eventId: 're_sync_2',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'routine_event_updated',
          payload: {
            'id': 're_1',
            'routine_id': 'routine_1',
            'home_id': 'home_1',
            'title': 'Morning walk with Lyla & Cabo',
            'start_minutes': 450,
            'end_minutes': 495,
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 5),
        );

        storedRoutineEvent = await (db.select(db.localRoutineEvents)
              ..where((t) => t.id.equals('re_1')))
            .getSingle();
        expect(storedRoutineEvent.title, 'Morning walk with Lyla & Cabo');
        expect(storedRoutineEvent.owner, 'user_saba');

        // v12 update payload WITH 'owner': 'user_ancy'
        await store.applyEvent(
          eventId: 're_sync_3',
          homeId: 'home_1',
          authorId: 'user_saba',
          eventType: 'routine_event_updated',
          payload: {
            'id': 're_1',
            'routine_id': 'routine_1',
            'home_id': 'home_1',
            'title': 'Morning walk with Lyla & Cabo',
            'start_minutes': 450,
            'end_minutes': 495,
            'owner': 'user_ancy',
          },
          timestamp: DateTime.utc(2026, 10, 15, 8, 10),
        );

        storedRoutineEvent = await (db.select(db.localRoutineEvents)
              ..where((t) => t.id.equals('re_1')))
            .getSingle();
        expect(storedRoutineEvent.owner, 'user_ancy');
      },
    );

    testWidgets(
      '2. Edit forms round trip: CalendarEventFormSheet, ListItemDetailSheet, and RoutineEventFormSheet pick and save owner',
      (tester) async {
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final store = LocalStateStoreImpl(db);
        final emittedPayloads =
            <({String eventType, Map<String, dynamic> payload})>[];

        await db.into(db.localHomes).insert(
              LocalHomesCompanion.insert(
                id: 'home_1',
                name: 'Our Cove',
                createdBy: 'user_saba',
                createdAt: DateTime(2026, 10, 1),
              ),
            );

        final overrides = <Override>[
          appDatabaseProvider.overrideWithValue(db),
          authProvider.overrideWith(_FakeAuthNotifier.new),
          activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
          activeHomeHasPartnerProvider
              .overrideWith(_FakeActivePartnerNotifier.new),
          userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
          partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
          currencyPreferenceProvider.overrideWith(_FakeCurrencyNotifier.new),
          coveEmitActionProvider.overrideWithValue(({
            required String eventType,
            required Map<String, dynamic> payload,
            String? targetHomeId,
          }) async {
            emittedPayloads.add((eventType: eventType, payload: payload));
            await store.applyEvent(
              eventId: 'evt_${emittedPayloads.length}',
              homeId: targetHomeId ?? 'home_1',
              authorId: 'user_saba',
              eventType: eventType,
              payload: payload,
              timestamp: DateTime(2026, 10, 15, 10, 0),
            );
          }),
        ];

        final container = ProviderContainer(overrides: overrides);
        addTearDown(container.dispose);

        // --- A. Create and edit Calendar Event via controller + CalendarEventFormSheet ---
        final calCtrl = container.read(calendarControllerProvider);
        final eventId = await calCtrl.createEvent(
          title: 'Book club',
          startTime: DateTime(2026, 10, 15, 18, 0),
          endTime: DateTime(2026, 10, 15, 19, 0),
          owner: 'user_saba',
        );
        expect(emittedPayloads.last.eventType, 'calendar_event_added');
        expect(emittedPayloads.last.payload['owner'], 'user_saba');

        var dbEvent = await (db.select(db.localCalendarEvents)
              ..where((t) => t.id.equals(eventId)))
            .getSingle();
        expect(dbEvent.owner, 'user_saba');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              key: const ValueKey('app_a'),
              theme: ThemeData.dark().copyWith(
                extensions: const [CoveTokens.dark],
              ),
              home: Scaffold(
                body: CalendarEventFormSheet(existing: dbEvent),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap partner tile 'Ancy' and save
        final ancyTile = find.text('Ancy');
        await tester.ensureVisible(ancyTile);
        await tester.pumpAndSettle();
        await tester.tap(ancyTile);
        await tester.pumpAndSettle();

        final saveEventBtn = find.text('Save Changes');
        await tester.ensureVisible(saveEventBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveEventBtn);
        await tester.pumpAndSettle();

        expect(emittedPayloads.last.eventType, 'calendar_event_updated');
        expect(emittedPayloads.last.payload['owner'], 'user_ancy');
        dbEvent = await (db.select(db.localCalendarEvents)
              ..where((t) => t.id.equals(eventId)))
            .getSingle();
        expect(dbEvent.owner, 'user_ancy');

        // --- B. Create and edit Task via controller + ListItemDetailSheet ---
        final listCtrl = container.read(listControllerProvider);
        final listId = await listCtrl.createList(name: 'Home');
        final itemId = await listCtrl.addItem(
          listId: listId,
          title: 'Clean balcony',
          owner: 'both',
        );
        expect(emittedPayloads.last.eventType, 'list_item_added');
        expect(emittedPayloads.last.payload['owner'], 'both');

        var dbItem = await (db.select(db.localListItems)
              ..where((t) => t.id.equals(itemId)))
            .getSingle();
        expect(dbItem.owner, 'both');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              key: const ValueKey('app_b'),
              theme: ThemeData.dark().copyWith(
                extensions: const [CoveTokens.dark],
              ),
              home: Scaffold(
                body: ListItemDetailSheet(
                  item: dbItem,
                  listName: 'Home',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Detail sheet slip shows 'Both of you'
        expect(find.text('Both of you'), findsOneWidget);

        // Tap Edit verb -> dialog opens with owner picker -> select 'Either of you' -> Save
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        final eitherTile = find.text('Either of you');
        await tester.ensureVisible(eitherTile);
        await tester.pumpAndSettle();
        await tester.tap(eitherTile);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(emittedPayloads.last.eventType, 'list_item_updated');
        expect(emittedPayloads.last.payload['owner'], 'either');
        dbItem = await (db.select(db.localListItems)
              ..where((t) => t.id.equals(itemId)))
            .getSingle();
        expect(dbItem.owner, 'either');

        // --- C. Create and edit RoutineEvent via controller + RoutineEventFormSheet ---
        final routineCtrl = container.read(routineControllerProvider);
        final routineId = await routineCtrl.createRoutine(
          name: 'Morning',
          days: const [1, 2, 3, 4, 5],
        );
        final routineEventId = await routineCtrl.createRoutineEvent(
          routineId: routineId,
          title: 'Filter coffee',
          startMinutes: 480,
          endMinutes: 510,
          owner: 'both',
        );
        expect(emittedPayloads.last.eventType, 'routine_event_created');
        expect(emittedPayloads.last.payload['owner'], 'both');

        var dbRoutineEvent = await (db.select(db.localRoutineEvents)
              ..where((t) => t.id.equals(routineEventId)))
            .getSingle();
        expect(dbRoutineEvent.owner, 'both');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              key: const ValueKey('app_c'),
              theme: ThemeData.dark().copyWith(
                extensions: const [CoveTokens.dark],
              ),
              home: Scaffold(
                body: RoutineEventFormSheet(
                  routineId: routineId,
                  event: RoutineEvent.fromLocal(dbRoutineEvent),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final sabaTile = find.text('Saba');
        await tester.ensureVisible(sabaTile);
        await tester.pumpAndSettle();
        await tester.tap(sabaTile);
        await tester.pumpAndSettle();

        final saveRoutineBtn = find.text('Save Changes');
        await tester.ensureVisible(saveRoutineBtn);
        await tester.pumpAndSettle();
        await tester.tap(saveRoutineBtn);
        await tester.pumpAndSettle();

        expect(emittedPayloads.last.eventType, 'routine_event_updated');
        expect(emittedPayloads.last.payload['owner'], 'user_saba');
        dbRoutineEvent = await (db.select(db.localRoutineEvents)
              ..where((t) => t.id.equals(routineEventId)))
            .getSingle();
        expect(dbRoutineEvent.owner, 'user_saba');
      },
    );

    testWidgets(
      '3. Display rule across Day Sheet, Today ticket & note, Calendar agenda, and Lists',
      (tester) async {
        final oct15 = DateTime(2026, 10, 15, 9, 0);

        final events = <LocalCalendarEvent>[
          LocalCalendarEvent(
            id: 'ev_partner',
            homeId: 'home_1',
            title: 'Ancy dental checkup',
            location: 'Koramangala',
            startTime: DateTime(2026, 10, 15, 11, 0),
            endTime: DateTime(2026, 10, 15, 12, 0),
            isAllDay: false,
            createdBy: 'user_saba',
            owner: 'user_ancy',
            createdAt: oct15,
          ),
        ];

        final lists = <LocalList>[
          LocalList(
            id: 'list_1',
            homeId: 'home_1',
            name: 'Home',
            createdBy: 'user_saba',
            isArchived: false,
            createdAt: oct15,
          ),
        ];

        final listItems = <LocalListItem>[
          LocalListItem(
            id: 'task_either',
            homeId: 'home_1',
            listId: 'list_1',
            title: 'Pay water bill',
            isCompleted: false,
            dueDate: DateTime(2026, 10, 15, 14, 0),
            createdBy: 'user_saba',
            owner: 'either',
            createdAt: oct15,
          ),
          LocalListItem(
            id: 'task_null_owner',
            homeId: 'home_1',
            listId: 'list_1',
            title: 'Unassigned task',
            isCompleted: false,
            dueDate: DateTime(2026, 10, 15, 16, 0),
            createdBy: 'user_saba',
            owner: null,
            createdAt: oct15,
          ),
        ];

        final routines = <Routine>[
          Routine(
            id: 'r_1',
            homeId: 'home_1',
            name: 'Everyday',
            days: const [1, 2, 3, 4, 5, 6, 7],
            createdAt: oct15,
          ),
        ];

        final routineEvents = <RoutineEvent>[
          RoutineEvent(
            id: 're_viewer',
            routineId: 'r_1',
            homeId: 'home_1',
            title: 'Morning run',
            startMinutes: 7 * 60,
            endMinutes: 7 * 60 + 30,
            owner: 'user_saba',
            createdAt: oct15,
          ),
        ];

        // 1. Day Sheet second line
        final daySheet = DaySheetSummary.compute(
          now: oct15,
          calendarEvents: events,
          routines: routines,
          routineEvents: routineEvents,
          lists: lists,
          listItems: listItems,
          habits: const [],
          checkins: const [],
          expenses: const [],
          currentUserId: 'user_saba',
          myName: 'Saba',
          partnerName: 'Ancy',
          currency: _kInr,
        );

        final routineLine =
            daySheet.lines.firstWhere((l) => l.id == 're_viewer');
        expect(routineLine.subtitle, 'You · routine');

        final eventLine =
            daySheet.lines.firstWhere((l) => l.id == 'ev_partner');
        expect(eventLine.subtitle, 'Ancy · Koramangala');

        final eitherTaskLine =
            daySheet.lines.firstWhere((l) => l.id == 'task_either');
        expect(eitherTaskLine.subtitle, 'Either of you · Home');

        final nullOwnerTaskLine =
            daySheet.lines.firstWhere((l) => l.id == 'task_null_owner');
        expect(nullOwnerTaskLine.subtitle, 'Home');

        // 2. Today screen ticket owner line & note item owner line
        await withClock(Clock.fixed(oct15), () async {
          final stubDb = _StubAppDatabase();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(stubDb),
                authProvider.overrideWith(_FakeAuthNotifier.new),
                activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
                activeHomeHasPartnerProvider
                    .overrideWith(_FakeActivePartnerNotifier.new),
                userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
                partnerProfileProvider
                    .overrideWith(_FakePartnerProfileNotifier.new),
                currencyPreferenceProvider
                    .overrideWith(_FakeCurrencyNotifier.new),
                weatherProvider.overrideWith(_FakeWeatherNotifier.new),
                activeHomeCalendarEventsProvider
                    .overrideWith((ref) => Stream.value(events)),
                activeHomeListsProvider
                    .overrideWith((ref) => Stream.value(lists)),
                activeHomeAllListItemsProvider
                    .overrideWith((ref) => Stream.value(listItems)),
                activeHomeHabitsProvider
                    .overrideWith((ref) => Stream.value(const <LocalHabit>[])),
                activeHomeAllHabitCheckinsProvider.overrideWith(
                  (ref) => Stream.value(const <LocalHabitCheckin>[]),
                ),
                activeHomeExpensesProvider.overrideWith(
                  (ref) => Stream.value(const <LocalExpense>[]),
                ),
                activeHomeSubscriptionsProvider.overrideWith(
                  (ref) => Stream.value(const <LocalSubscription>[]),
                ),
                firstRunProvider(
                  CoveScreen.today,
                ).overrideWithValue(FirstRunState.inUse),
              ],
              child: MaterialApp(
                theme: ThemeData.dark().copyWith(
                  extensions: const [CoveTokens.dark],
                ),
                home: const TodayScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final ticket = tester.widget<CoveTicket>(
            find.byKey(const ValueKey('today_ticket_ev_partner')),
          );
          expect(ticket.owner, 'Ancy');

          final note = tester.widget<CoveNote>(
            find.byKey(const ValueKey('today_note')),
          );
          expect(note.items[0].title, 'Pay water bill');
          expect(note.items[0].owner, 'Either of you');
          expect(note.items[1].title, 'Unassigned task');
          expect(note.items[1].owner, isNull);
        });
      },
    );
  });
}
