import 'dart:async';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_controller.dart';
import 'package:cove/features/calendar/calendar_screen.dart';
import 'package:cove/features/calendar/views/calendar_agenda_view.dart';
import 'package:cove/features/calendar/views/calendar_month_view.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/reminders/reminder_controller.dart';
import 'package:cove/features/reminders/reminder_models.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/providers/first_run_provider.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'golden/golden_harness.dart';

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
  final alexUser = const CoveUser(
    id: userIdAlex,
    email: 'alex@example.com',
    displayName: 'Alex',
  );

  setUpAll(() async {
    await loadCoveFonts();
  });

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
    // In-memory sqlite database is safely reclaimed by GC; closing FFI handle inside FakeAsync creates pending timer issues.
  });

  List<Override> createOverrides({
    CoveUser? user,
    ValueNotifier<List<LocalCalendarEvent>>? eventsNotifier,
    ValueNotifier<List<LocalSubscription>>? subsNotifier,
  }) {
    final effectiveUser = user ?? alexUser;
    fakeSyncEngine.currentActorId = effectiveUser.id;
    final effectiveEventsNotifier =
        eventsNotifier ?? ValueNotifier<List<LocalCalendarEvent>>([]);
    final effectiveSubsNotifier =
        subsNotifier ?? ValueNotifier<List<LocalSubscription>>([]);

    Future<void> reload() async {
      final events = await db.getCalendarEvents(homeId);
      effectiveEventsNotifier.value = events;
      final subs = await db.getSubscriptions(homeId, currentUserId: effectiveUser.id);
      effectiveSubsNotifier.value = subs;
    }

    if (eventsNotifier == null) {
      db.getCalendarEvents(homeId).then((e) {
        effectiveEventsNotifier.value = e;
      });
    }
    if (subsNotifier == null) {
      db.getSubscriptions(homeId, currentUserId: effectiveUser.id).then((s) {
        effectiveSubsNotifier.value = s;
      });
    }

    return [
      firstRunProvider(CoveScreen.calendar)
          .overrideWithValue(FirstRunState.inUse),
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
      calendarControllerProvider.overrideWith((ref) => _TestCalendarController(ref, onMutate: reload)),
      activeHomeCalendarEventsProvider.overrideWith((ref) {
        final controller = StreamController<List<LocalCalendarEvent>>();
        controller.add(effectiveEventsNotifier.value);
        void listener() {
          if (!controller.isClosed) {
            controller.add(effectiveEventsNotifier.value);
          }
        }
        effectiveEventsNotifier.addListener(listener);
        ref.onDispose(() {
          effectiveEventsNotifier.removeListener(listener);
          controller.close();
        });
        return controller.stream;
      }),
      activeHomeSubscriptionsProvider.overrideWith((ref) {
        final controller = StreamController<List<LocalSubscription>>();
        controller.add(effectiveSubsNotifier.value);
        void listener() {
          if (!controller.isClosed) {
            controller.add(effectiveSubsNotifier.value);
          }
        }
        effectiveSubsNotifier.addListener(listener);
        ref.onDispose(() {
          effectiveSubsNotifier.removeListener(listener);
          controller.close();
        });
        return controller.stream;
      }),
      activeHomeProvider.overrideWith((ref) => Stream.value(
        LocalHome(id: homeId, name: 'Our Home', createdAt: DateTime.now(), createdBy: userIdAlex, currency: 'USD'),
      )),
      partnerProfileProvider.overrideWith(() => FakePartnerProfileNotifier()),
      checkinRemindersProvider.overrideWith(() => FakeReminderNotifier()),
      activeHomeOutboxProvider.overrideWith((ref) => Stream.value([])),
      activeHomeExpensesProvider.overrideWith((ref) => Stream.value([])),
      activeHomeHabitsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeAllHabitCheckinsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeListsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeAllListItemsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeRoutinesProvider.overrideWith((ref) => Stream.value([])),
      activeHomeAllRoutineEventsProvider.overrideWith((ref) => Stream.value([])),
    ];
  }

  Widget createWidgetUnderTest({
    required Widget child,
    ThemeData? theme,
    CoveUser? user,
    ValueNotifier<List<LocalCalendarEvent>>? eventsNotifier,
    ValueNotifier<List<LocalSubscription>>? subsNotifier,
  }) {
    return ProviderScope(
      overrides: createOverrides(
        user: user,
        eventsNotifier: eventsNotifier,
        subsNotifier: subsNotifier,
      ),
      child: MaterialApp(
        theme: theme ?? CoveTheme.darkTheme,
        home: child,
      ),
    );
  }

  group('Shared Calendar Feature Tests', () {
    testWidgets('1. Empty state renders CovePageHeader, fixed section order, and quiet empty lines',
        (tester) async {
      final fixedDate = DateTime(2026, 10, 15);
      await tester.pumpWidget(
        createWidgetUnderTest(
          child: CalendarScreen(initialSelectedDate: fixedDate),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('October'), findsOneWidget);
      expect(find.text('2026'), findsOneWidget);
      expect(find.byType(CalendarAgendaView), findsOneWidget);
      expect(find.text('EVENTS'), findsWidgets);
      expect(find.text('HABITS'), findsWidgets);
      expect(find.text('SPENT'), findsWidgets);
      expect(find.text('THE LIST'), findsWidgets);
      expect(find.text('Nothing on the calendar for this day.'), findsOneWidget);
    });

    testWidgets('2. Day view only (no month view) and month chevrons switch the displayed month',
        (tester) async {
      final octDate = DateTime(2026, 10, 15);
      await tester.pumpWidget(
        createWidgetUnderTest(
          child: CalendarScreen(
            initialMode: CalendarViewMode.month,
            initialSelectedDate: octDate,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Always renders Day view (CalendarAgendaView), never CalendarMonthView
      expect(find.byType(CalendarAgendaView), findsOneWidget);
      expect(find.byType(CalendarMonthView), findsNothing);
      expect(find.text('October'), findsOneWidget);

      // Step to next month via header chevron
      await tester.tap(find.byKey(const ValueKey('calendar_next_month')));
      await tester.pumpAndSettle();
      expect(find.text('November'), findsOneWidget);

      // Step back to October via header chevron
      await tester.tap(find.byKey(const ValueKey('calendar_prev_month')));
      await tester.pumpAndSettle();
      expect(find.text('October'), findsOneWidget);
    });

    testWidgets('3. Adding a calendar event emits calendar_event_added and renders with CoveSyncTick',
        (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(child: const CalendarScreen()),
      );
      await tester.pumpAndSettle();

      // Open Add picker via gold + Add round button
      await tester.tap(find.byKey(const ValueKey('calendar_add_button')));
      await tester.pumpAndSettle();

      expect(find.text('Event'), findsOneWidget);
      await tester.tap(find.text('Event'));
      await tester.pumpAndSettle();

      expect(find.text('What is it?'), findsOneWidget);

      // Step 1: Enter event title
      await tester.enterText(
        find.byKey(const ValueKey('add_flow_text_input')),
        'Dinner with Sarah',
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pumpAndSettle();

      // Step 2: Which day? -> tap Today or first day pill to auto-advance
      await tester.tap(find.bySemanticsLabel('Next').evaluate().isNotEmpty
          ? find.bySemanticsLabel('Next')
          : find.bySemanticsLabel(RegExp(r'^Today,')).first);
      await tester.pumpAndSettle();

      // Step 3: What time? -> Next
      await tester.tap(find.bySemanticsLabel('Next'));
      await tester.pumpAndSettle();

      // Step 4: Where? -> Skip
      await tester.tap(find.bySemanticsLabel('Skip'));
      await tester.pumpAndSettle();

      // Step 5: Review -> Add event
      await tester.tap(find.bySemanticsLabel('Add event'));
      await tester.pumpAndSettle();

      // Close Added confirmation
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();

      // Verify event was emitted through sync engine
      expect(fakeSyncEngine.dispatchedEvents.length, 1);
      final emitted = fakeSyncEngine.dispatchedEvents.first;
      expect(emitted['eventType'], 'calendar_event_added');
      expect(emitted['payload']['title'], 'Dinner with Sarah');

      // Verify rendered in agenda view with sync tick
      expect(find.text('Dinner with Sarah'), findsOneWidget);
      expect(find.byType(CoveSyncTick), findsOneWidget);
    });

    testWidgets('4. Subscription renewals are surfaced in the prominent Commitments due card with RENEWAL caption and NO sync tick',
        (tester) async {
      final now = DateTime.now();

      // Insert active subscription renewing today
      await db.into(db.localSubscriptions).insert(
            LocalSubscriptionsCompanion.insert(
              id: 'sub_netflix',
              homeId: homeId,
              name: 'Netflix Premium',
              amount: 22.99,
              currency: const drift.Value('USD'),
              billingCycle: const drift.Value('monthly'),
              nextBillingDate: now,
              isActive: const drift.Value(true),
              isPrivate: const drift.Value(false),
              createdAt: now,
            ),
          );

      // Also insert a calendar event today
      await db.into(db.localCalendarEvents).insert(
            LocalCalendarEventsCompanion.insert(
              id: 'event_dentist',
              homeId: homeId,
              title: 'Dentist Checkup',
              startTime: now,
              endTime: now.add(const Duration(hours: 1)),
              isAllDay: const drift.Value(false),
              createdAt: now,
              createdBy: userIdAlex,
            ),
          );

      await tester.pumpWidget(
        createWidgetUnderTest(child: CalendarScreen(initialSelectedDate: now)),
      );
      await tester.pumpAndSettle();

      // 1. Dentist event is rendered
      expect(find.text('Dentist Checkup'), findsOneWidget);

      // 2. Surfaced subscription is rendered in the Commitments due block
      await tester.scrollUntilVisible(
        find.text('Netflix Premium'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Netflix Premium'), findsWidgets);
      expect(find.text('RENEWAL'), findsWidgets);
      expect(find.text('\$22.99'), findsWidgets);

      // 3. Exactly one sync tick exists (for the real calendar event, NOT for the subscription)
      expect(find.byType(CoveSyncTick), findsOneWidget);
    });

    testWidgets('5. Date strip shows only the selected month and allows selecting any day in the month',
        (tester) async {
      final oct15 = DateTime(2026, 10, 15);
      final flightEvent = LocalCalendarEvent(
        id: 'event_flight',
        homeId: homeId,
        title: 'Flight to Tokyo',
        startTime: DateTime(2026, 10, 16, 10, 0),
        endTime: DateTime(2026, 10, 16, 22, 0),
        isAllDay: false,
        createdAt: oct15,
        createdBy: userIdAlex,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(
          child: CalendarScreen(
            initialEvents: [flightEvent],
            initialSelectedDate: oct15,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thursday, Oct 15'), findsOneWidget);
      expect(find.text('Flight to Tokyo'), findsNothing);

      // Tap Oct 16 in the horizontal date strip
      await tester.tap(find.byKey(const ValueKey('calendar_day_2026_10_16')));
      await tester.pumpAndSettle();

      expect(find.text('Friday, Oct 16'), findsOneWidget);
      expect(find.text('Flight to Tokyo'), findsOneWidget);
    });

    testWidgets('6. Dual-theme verification: renders correctly in light and dark themes',
        (tester) async {
      final fixedDate = DateTime(2026, 10, 15);
      // Light theme
      await tester.pumpWidget(
        createWidgetUnderTest(
          child: CalendarScreen(initialSelectedDate: fixedDate),
          theme: CoveTheme.lightTheme,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('October'), findsOneWidget);

      // Dark theme
      await tester.pumpWidget(
        createWidgetUnderTest(
          child: CalendarScreen(initialSelectedDate: fixedDate),
          theme: CoveTheme.darkTheme,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('October'), findsOneWidget);
    });
  });
}

class _TestCalendarController extends CalendarController {
  final Future<void> Function() onMutate;

  _TestCalendarController(super.ref, {required this.onMutate});

  @override
  Future<String> createEvent({
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    String? location,
    String? recurrence,
  }) async {
    final res = await super.createEvent(
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      location: location,
      recurrence: recurrence,
    );
    await onMutate();
    return res;
  }

  @override
  Future<void> updateEvent({
    required String id,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    String? location,
    String? recurrence,
  }) async {
    await super.updateEvent(
      id: id,
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      location: location,
      recurrence: recurrence,
    );
    await onMutate();
  }

  @override
  Future<void> deleteEvent(String id) async {
    await super.deleteEvent(id);
    await onMutate();
  }
}

class FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() {
    return const PartnerProfileState();
  }
}

class FakeReminderNotifier extends ReminderNotifier {
  @override
  List<CheckinReminder> build() => [];
}

