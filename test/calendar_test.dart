import 'dart:async';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_controller.dart';
import 'package:cove/features/calendar/calendar_screen.dart';
import 'package:cove/features/calendar/views/calendar_agenda_view.dart';
import 'package:cove/features/calendar/views/calendar_month_view.dart';
import 'package:cove/features/calendar/views/calendar_year_view.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/drift.dart' as drift;
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
  final alexUser = const CoveUser(
    id: userIdAlex,
    email: 'alex@example.com',
    displayName: 'Alex',
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
      activeHomeOutboxProvider.overrideWith((ref) => Stream.value([])),
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
    testWidgets('1. Empty state renders correctly with Add First Event button',
        (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(child: const CalendarScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shared Calendar'), findsOneWidget);
      expect(find.byType(CalendarAgendaView), findsOneWidget);
      expect(find.text('Nothing Scheduled Yet'), findsOneWidget);
      expect(find.text('Add First Event'), findsOneWidget);
    });

    testWidgets('2. Three-way view switcher toggles between Agenda, Month, and Year modes',
        (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(child: const CalendarScreen()),
      );
      await tester.pumpAndSettle();

      // Default is Agenda
      expect(find.byType(CalendarAgendaView), findsOneWidget);
      expect(find.byType(CalendarMonthView), findsNothing);
      expect(find.byType(CalendarYearView), findsNothing);

      // Switch to Month
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarAgendaView), findsNothing);
      expect(find.byType(CalendarMonthView), findsOneWidget);
      expect(find.byType(CalendarYearView), findsNothing);

      // Switch to Year
      await tester.tap(find.text('Year'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarAgendaView), findsNothing);
      expect(find.byType(CalendarMonthView), findsNothing);
      expect(find.byType(CalendarYearView), findsOneWidget);

      // Tap on a month card in Year view returns to Month view
      await tester.tap(find.text('Jan'));
      await tester.pumpAndSettle();
      expect(find.byType(CalendarMonthView), findsOneWidget);
    });

    testWidgets('3. Adding a calendar event emits calendar_event_added and renders with CoveSyncTick',
        (tester) async {
      await tester.pumpWidget(
        createWidgetUnderTest(child: const CalendarScreen()),
      );
      await tester.pumpAndSettle();

      // Open creation sheet via + Event
      await tester.tap(find.widgetWithText(CovePillButton, '+ Event'));
      await tester.pumpAndSettle();

      expect(find.text('Add Calendar Event'), findsOneWidget);

      // Enter event title
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'Dinner with Sarah');
      await tester.pumpAndSettle();

      // Tap Save
      final saveBtn = find.text('Create Shared Event');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
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

    testWidgets('4. Subscription renewals are surfaced inline with from Subscriptions caption and NO sync tick',
        (tester) async {
      final now = DateTime.now();

      // Insert active subscription renewing in 2 days
      await db.into(db.localSubscriptions).insert(
            LocalSubscriptionsCompanion.insert(
              id: 'sub_netflix',
              homeId: homeId,
              name: 'Netflix Premium',
              amount: 22.99,
              currency: const drift.Value('USD'),
              billingCycle: const drift.Value('monthly'),
              nextBillingDate: now.add(const Duration(days: 2)),
              isActive: const drift.Value(true),
              isPrivate: const drift.Value(false),
              createdAt: now,
            ),
          );

      // Also insert a calendar event
      await db.into(db.localCalendarEvents).insert(
            LocalCalendarEventsCompanion.insert(
              id: 'event_dentist',
              homeId: homeId,
              title: 'Dentist Checkup',
              startTime: now.add(const Duration(days: 1)),
              endTime: now.add(const Duration(days: 1, hours: 1)),
              isAllDay: const drift.Value(false),
              createdAt: now,
              createdBy: userIdAlex,
            ),
          );

      await tester.pumpWidget(
        createWidgetUnderTest(child: const CalendarScreen()),
      );
      await tester.pumpAndSettle();

      // 1. Dentist event is rendered
      expect(find.text('Dentist Checkup'), findsOneWidget);

      // 2. Surfaced subscription is rendered with distinct caption and amount
      expect(find.text('Netflix Premium'), findsWidgets);
      expect(find.text('from Subscriptions'), findsWidgets);
      expect(find.text('\$22.99'), findsWidgets);

      // 3. Exactly one sync tick exists (for the real calendar event, NOT for the subscription)
      expect(find.byType(CoveSyncTick), findsOneWidget);
    });

    testWidgets('5. Month view shows Monday-first grid with dots and selected day panel',
        (tester) async {
      final now = DateTime.now();
      final flightEvent = LocalCalendarEvent(
        id: 'event_flight',
        homeId: homeId,
        title: 'Flight to Tokyo',
        startTime: now,
        endTime: now.add(const Duration(hours: 12)),
        isAllDay: false,
        createdAt: now,
        createdBy: userIdAlex,
      );

      await db.into(db.localCalendarEvents).insert(
            LocalCalendarEventsCompanion.insert(
              id: flightEvent.id,
              homeId: homeId,
              title: flightEvent.title,
              startTime: flightEvent.startTime,
              endTime: flightEvent.endTime,
              isAllDay: const drift.Value(false),
              createdAt: now,
              createdBy: userIdAlex,
            ),
          );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createWidgetUnderTest(
          child: CalendarScreen(
            initialMode: CalendarViewMode.month,
            initialEvents: [flightEvent],
            initialSelectedDate: flightEvent.startTime,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CalendarMonthView), findsOneWidget);

      // Day of week headers Monday-first
      expect(find.text('M'), findsOneWidget);
      expect(find.text('W'), findsOneWidget);

      // Selected day panel contains Tokyo flight
      expect(find.text('Flight to Tokyo'), findsOneWidget);
    });

    testWidgets('6. Year view shows 12 month cards with upcoming count',
        (tester) async {
      final now = DateTime.now();
      final annivEvent = LocalCalendarEvent(
        id: 'event_anniversary',
        homeId: homeId,
        title: 'Our Anniversary',
        startTime: DateTime(now.year, now.month, 15),
        endTime: DateTime(now.year, now.month, 15, 23, 59),
        isAllDay: true,
        createdAt: now,
        createdBy: userIdAlex,
      );

      await db.into(db.localCalendarEvents).insert(
            LocalCalendarEventsCompanion.insert(
              id: annivEvent.id,
              homeId: homeId,
              title: annivEvent.title,
              startTime: annivEvent.startTime,
              endTime: annivEvent.endTime,
              isAllDay: const drift.Value(true),
              createdAt: now,
              createdBy: userIdAlex,
            ),
          );

      await tester.pumpWidget(
        createWidgetUnderTest(
          child: CalendarScreen(
            initialMode: CalendarViewMode.year,
            initialEvents: [annivEvent],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CalendarYearView), findsOneWidget);

      // Cards for months
      expect(find.text('Jan'), findsOneWidget);
      expect(find.text('1 upcoming'), findsOneWidget);
    });

    testWidgets('7. Dual-theme verification: renders correctly in light and dark themes',
        (tester) async {
      // Light theme
      await tester.pumpWidget(
        createWidgetUnderTest(
          child: const CalendarScreen(),
          theme: CoveTheme.lightTheme,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Shared Calendar'), findsOneWidget);

      // Dark theme
      await tester.pumpWidget(
        createWidgetUnderTest(
          child: const CalendarScreen(),
          theme: CoveTheme.darkTheme,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Shared Calendar'), findsOneWidget);
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

