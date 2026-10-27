import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_checkbox.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/add/add_flow.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/habits/habits_screen.dart';
import 'package:cove/features/lists/lists_screen.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/event_store.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'golden/golden_harness.dart';

/// EventStore wrapper that inspects SQLite transaction state at the moment
/// `appendEvent` runs and can simulate an outbox failure mid-transaction to
/// prove the record projection rolls back with the outbox.
class _InspectingEventStore extends EventStoreImpl {
  bool shouldThrowOnAppend = false;
  final List<bool> appendSawUncommittedActivityRow = <bool>[];
  void Function()? onAppend;

  _InspectingEventStore({required super.db, super.cryptoService});

  @override
  Future<void> appendEvent(
    CoveEncryptedEvent event, {
    String payloadJson = '{}',
  }) async {
    onAppend?.call();
    // In SQLite, if the record projection (`applyEventInTransaction`) ran
    // inside the same open transaction on this connection, querying
    // `local_activity_events` sees the uncommitted row for `event.id`.
    final uncommittedActivityCount = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM local_activity_events WHERE id = ?',
          variables: <Variable<Object>>[Variable.withString(event.id)],
        )
        .getSingle();
    appendSawUncommittedActivityRow.add(
      uncommittedActivityCount.read<int>('c') == 1,
    );

    if (shouldThrowOnAppend) {
      throw StateError('Simulated outbox append failure');
    }
    await super.appendEvent(event, payloadJson: payloadJson);
  }
}

/// Fake [FlutterSecureStorage] with configurable delay per operation and a hook
/// that records whether a SQLite write transaction is currently open when a
/// storage operation begins.
class _FakeSlowSecureStorage extends FlutterSecureStorage {
  final Duration delayPerCall;
  final Map<String, String> values = <String, String>{};
  int writeCalls = 0;

  _FakeSlowSecureStorage({
    required this.delayPerCall,
  }) : super();

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
    writeCalls++;
    if (delayPerCall > Duration.zero) {
      await Future<void>.delayed(delayPerCall);
    }
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
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
    if (delayPerCall > Duration.zero) {
      await Future<void>.delayed(delayPerCall);
    }
    return values[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

class _StubActiveHomeNotifier extends ActiveHomeNotifier {
  final String? initialHomeId;
  _StubActiveHomeNotifier(this.initialHomeId);

  @override
  String? build() => initialHomeId;
}

class _StubAuthNotifier extends AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncValue.data(
        CoveUser(id: 'user_saba', email: 'saba@cove.app', displayName: 'Saba'),
      );
}

class _StubUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState(
        displayName: 'Saba',
        email: 'saba@cove.app',
      );
}

class _StubPartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => const PartnerProfileState(
        displayName: 'Ancy',
        userId: 'user_ancy',
        hasCustomName: true,
      );
}

class _StubCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() => const CurrencyOption(
        code: 'INR',
        symbol: '₹',
        name: 'Indian Rupee',
      );
}

class _StubCustomCategoriesNotifier extends CustomCategoriesNotifier {
  @override
  List<String> build() => const <String>[];
}

void main() {
  const homeId = 'home_44c_emit';
  const userId = 'user_saba';
  final fixedNow = DateTime(2026, 10, 5, 10, 30);
  final fixedToday = DateTime(2026, 10, 5);

  late AppDatabase db;
  late _FakeSlowSecureStorage keyStorage;
  late HomeKeyStore keyStore;
  late _InspectingEventStore eventStore;
  late LocalStateStoreImpl localStateStore;
  late SodiumCryptoService cryptoService;
  late SyncEngineImpl syncEngine;

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AddAgainPreferenceNotifier.cachedInitialAgain = null;

    db = AppDatabase(NativeDatabase.memory());
    keyStorage = _FakeSlowSecureStorage(delayPerCall: Duration.zero);
    keyStore = HomeKeyStore(
      storage: keyStorage,
      fallbackStorage: keyStorage,
    );
    cryptoService = SodiumCryptoService();
    final key = cryptoService.generateHomeKey();
    await keyStore.saveKey(homeId, key);

    eventStore = _InspectingEventStore(db: db, cryptoService: cryptoService);
    localStateStore = LocalStateStoreImpl(
      db,
      storage: _FakeSlowSecureStorage(delayPerCall: Duration.zero),
    );
    syncEngine = SyncEngineImpl(
      eventStore: eventStore,
      localStateStore: localStateStore,
      encryptionService: cryptoService,
      keyStore: keyStore,
      getCurrentUserId: () => userId,
      getActiveHomeId: () => homeId,
    );

    await db.into(db.localHomes).insert(
          LocalHomesCompanion.insert(
            id: homeId,
            name: 'Sanctuary',
            currency: const Value('INR'),
            createdAt: fixedNow,
            createdBy: userId,
          ),
        );
  });

  List<Override> buildRealSyncOverrides() {
    return <Override>[
      appDatabaseProvider.overrideWithValue(db),
      activeHomeIdProvider.overrideWith(() => _StubActiveHomeNotifier(homeId)),
      authProvider.overrideWith(_StubAuthNotifier.new),
      userProfileProvider.overrideWith(_StubUserProfileNotifier.new),
      partnerProfileProvider.overrideWith(_StubPartnerProfileNotifier.new),
      currencyPreferenceProvider.overrideWith(_StubCurrencyNotifier.new),
      customCategoriesProvider.overrideWith(_StubCustomCategoriesNotifier.new),
      syncEngineProvider.overrideWithValue(syncEngine),
    ];
  }

  group('4.4c App-wide One-Transaction Emit Safety', () {
    testWidgets(
      '1. On-screen writes, one per kind (expense, list item toggle, habit check-in, event, commitment, routine event): '
      'each produces exactly one record change and one outbox event, both in the same transaction',
      (tester) async {
        await loadCoveFonts();
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        // Seed prerequisites for list item toggle, habit check-in, and routine event
        const listId = 'default_grocery_home_44c_emit';
        const listItemId = 'item_milk';
        const habitId = 'habit_read';
        const routineId = 'routine_weekday';

        await db.ensureDefaultLists(homeId, userId);
        await db.into(db.localListItems).insert(
              LocalListItemsCompanion.insert(
                id: listItemId,
                homeId: homeId,
                listId: listId,
                title: 'Almond milk',
                isCompleted: const Value(false),
                createdBy: userId,
                createdAt: fixedNow,
              ),
            );
        await db.into(db.localHabits).insert(
              LocalHabitsCompanion.insert(
                id: habitId,
                homeId: homeId,
                name: 'Read 20 pages',
                cadence: const Value('daily'),
                targetDaysPerWeek: const Value(7),
                createdAt: fixedNow,
                createdBy: userId,
              ),
            );
        await db.into(db.localRoutines).insert(
              LocalRoutinesCompanion.insert(
                id: routineId,
                homeId: homeId,
                name: 'Weekdays',
                daysJson: jsonEncode(<int>[1, 2, 3, 4, 5]),
                createdAt: fixedNow,
              ),
            );

        final flowContext = AddFlowContext(
          anchor: fixedToday,
          today: fixedToday,
          viewerUserId: userId,
          partnerUserId: 'user_ancy',
          hasPartner: true,
        );

        await withClock(Clock.fixed(fixedNow), () async {
          // ------------------------------------------------------------------
          // Kind 1: EXPENSE (via on-screen AddFlow review -> 'Add expense')
          // ------------------------------------------------------------------
          final expenseDraft = ExpenseDraft(
            amount: 640,
            title: 'Blue Tokai Coffee',
            expenseDate: fixedToday,
            category: 'Dining',
            payer: ExpensePayer.you,
            splitHalfAndHalf: true,
            isPrivate: false,
            paymentMethod: 'upi',
            viewerUserId: userId,
            partnerUserId: 'user_ancy',
            hasPartner: true,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: buildRealSyncOverrides(),
              child: MaterialApp(
                theme: CoveTheme.darkTheme,
                home: Scaffold(
                  body: AddFlow(
                    initialKind: AddKind.expense,
                    initialDraft: expenseDraft,
                    initialStepIndex:
                        expenseDraft.stepsFor(flowContext).length - 1,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          var outboxBefore = await db.select(db.localOutboxEvents).get();
          expect(await db.select(db.localExpenses).get(), isEmpty);

          await tester.tap(find.bySemanticsLabel('Add expense'));
          await tester.pumpAndSettle();

          final expensesAfter = await db.select(db.localExpenses).get();
          var outboxAfter = await db.select(db.localOutboxEvents).get();
          expect(expensesAfter, hasLength(1));
          expect(expensesAfter.single.title, 'Blue Tokai Coffee');
          expect(outboxAfter.length - outboxBefore.length, 1);
          expect(outboxAfter.last.eventType, 'expense_logged');
          expect(eventStore.appendSawUncommittedActivityRow.last, isTrue);

          // ------------------------------------------------------------------
          // Kind 2: LIST ITEM TOGGLE (via on-screen ListsScreen checkbox tap)
          // ------------------------------------------------------------------
          await tester.pumpWidget(
            ProviderScope(
              overrides: buildRealSyncOverrides(),
              child: MaterialApp(
                theme: CoveTheme.darkTheme,
                home: const ListsScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Almond milk'), findsOneWidget);
          outboxBefore = await db.select(db.localOutboxEvents).get();
          final listCheckbox = find.byType(CoveCheckbox).first;
          await tester.tap(listCheckbox);
          await tester.pumpAndSettle();

          final toggledItem = await (db.select(db.localListItems)
                ..where((t) => t.id.equals(listItemId)))
              .getSingle();
          outboxAfter = await db.select(db.localOutboxEvents).get();
          expect(toggledItem.isCompleted, isTrue);
          expect(outboxAfter.length - outboxBefore.length, 1);
          expect(outboxAfter.last.eventType, 'list_item_toggled');
          expect(eventStore.appendSawUncommittedActivityRow.last, isTrue);

          // ------------------------------------------------------------------
          // Kind 3: HABIT CHECK-IN (via on-screen HabitsScreen checkbox tap)
          // ------------------------------------------------------------------
          await tester.pumpWidget(
            ProviderScope(
              overrides: buildRealSyncOverrides(),
              child: MaterialApp(
                theme: CoveTheme.darkTheme,
                home: const HabitsScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(await db.select(db.localHabitCheckins).get(), isEmpty);
          outboxBefore = await db.select(db.localOutboxEvents).get();
          final habitCheckbox = find.byType(CoveCheckbox).first;
          await tester.tap(habitCheckbox);
          await tester.pumpAndSettle();

          final checkinsAfter = await db.select(db.localHabitCheckins).get();
          outboxAfter = await db.select(db.localOutboxEvents).get();
          expect(checkinsAfter, hasLength(1));
          expect(checkinsAfter.single.habitId, habitId);
          expect(outboxAfter.length - outboxBefore.length, 1);
          expect(outboxAfter.last.eventType, 'habit_checkin_toggled');
          expect(eventStore.appendSawUncommittedActivityRow.last, isTrue);

          // ------------------------------------------------------------------
          // Kind 4: EVENT (via on-screen AddFlow review -> 'Add event')
          // ------------------------------------------------------------------
          final eventDraft = EventDraft(
            title: 'Dinner at Bastian',
            day: fixedToday,
            hour: 20,
            minute: 0,
            isAllDay: false,
            location: 'Bandra',
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: buildRealSyncOverrides(),
              child: MaterialApp(
                theme: CoveTheme.darkTheme,
                home: Scaffold(
                  body: AddFlow(
                    initialKind: AddKind.event,
                    initialDraft: eventDraft,
                    initialStepIndex:
                        eventDraft.stepsFor(flowContext).length - 1,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(await db.select(db.localCalendarEvents).get(), isEmpty);
          outboxBefore = await db.select(db.localOutboxEvents).get();
          await tester.tap(find.bySemanticsLabel('Add event'));
          await tester.pumpAndSettle();

          final eventsAfter = await db.select(db.localCalendarEvents).get();
          outboxAfter = await db.select(db.localOutboxEvents).get();
          expect(eventsAfter, hasLength(1));
          expect(eventsAfter.single.title, 'Dinner at Bastian');
          expect(outboxAfter.length - outboxBefore.length, 1);
          expect(outboxAfter.last.eventType, 'calendar_event_added');
          expect(eventStore.appendSawUncommittedActivityRow.last, isTrue);

          // ------------------------------------------------------------------
          // Kind 5: COMMITMENT (via on-screen AddFlow review -> 'Add commitment')
          // ------------------------------------------------------------------
          final commitmentDraft = CommitmentDraft(
            name: 'Netflix 4K',
            amount: 649,
            cycle: CommitmentCycleOption.everyMonth,
            dayOfMonth: 5,
            paidFrom: 'HDFC Infinia',
            owner: CommitmentOwner.both,
            isPrivate: false,
            today: fixedToday,
            viewerUserId: userId,
            partnerUserId: 'user_ancy',
            hasPartner: true,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: buildRealSyncOverrides(),
              child: MaterialApp(
                theme: CoveTheme.darkTheme,
                home: Scaffold(
                  body: AddFlow(
                    initialKind: AddKind.commitment,
                    initialDraft: commitmentDraft,
                    initialStepIndex:
                        commitmentDraft.stepsFor(flowContext).length - 1,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(await db.select(db.localSubscriptions).get(), isEmpty);
          outboxBefore = await db.select(db.localOutboxEvents).get();
          await tester.tap(find.bySemanticsLabel('Add commitment'));
          await tester.pumpAndSettle();

          final subsAfter = await db.select(db.localSubscriptions).get();
          outboxAfter = await db.select(db.localOutboxEvents).get();
          expect(subsAfter, hasLength(1));
          expect(subsAfter.single.name, 'Netflix 4K');
          expect(outboxAfter.length - outboxBefore.length, 1);
          expect(outboxAfter.last.eventType, 'subscription_added');
          expect(eventStore.appendSawUncommittedActivityRow.last, isTrue);

          // ------------------------------------------------------------------
          // Kind 6: ROUTINE EVENT (via on-screen AddFlow review -> 'Add to routine')
          // ------------------------------------------------------------------
          final routineDraft = RoutineDraft(
            title: 'Morning stretch',
            days: const <int>{1, 2, 3, 4, 5},
            startMinutes: 7 * 60,
            durationMinutes: 30,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: buildRealSyncOverrides(),
              child: MaterialApp(
                theme: CoveTheme.darkTheme,
                home: Scaffold(
                  body: AddFlow(
                    initialKind: AddKind.routine,
                    routineId: routineId,
                    initialDraft: routineDraft,
                    initialStepIndex:
                        routineDraft.stepsFor(flowContext).length - 1,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(await db.select(db.localRoutineEvents).get(), isEmpty);
          outboxBefore = await db.select(db.localOutboxEvents).get();
          await tester.tap(find.bySemanticsLabel('Add routine'));
          await tester.pumpAndSettle();

          final routineEventsAfter =
              await db.select(db.localRoutineEvents).get();
          outboxAfter = await db.select(db.localOutboxEvents).get();
          expect(routineEventsAfter, hasLength(1));
          expect(routineEventsAfter.single.title, 'Morning stretch');
          expect(outboxAfter.length - outboxBefore.length, 1);
          expect(outboxAfter.last.eventType, 'routine_event_created');
          expect(eventStore.appendSawUncommittedActivityRow.last, isTrue);

          // ------------------------------------------------------------------
          // Same-transaction rollback proof: if outbox append throws inside
          // the transaction, the local record write rolls back too.
          // ------------------------------------------------------------------
          eventStore.shouldThrowOnAppend = true;
          outboxBefore = await db.select(db.localOutboxEvents).get();
          final failingExpenseDraft = ExpenseDraft(
            amount: 999,
            title: 'Should Roll Back',
            expenseDate: fixedToday,
            category: 'Dining',
            payer: ExpensePayer.you,
            splitHalfAndHalf: true,
            isPrivate: false,
            paymentMethod: 'upi',
            viewerUserId: userId,
            partnerUserId: 'user_ancy',
            hasPartner: true,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: buildRealSyncOverrides(),
              child: MaterialApp(
                theme: CoveTheme.darkTheme,
                home: Scaffold(
                  body: AddFlow(
                    initialKind: AddKind.expense,
                    initialDraft: failingExpenseDraft,
                    initialStepIndex:
                        failingExpenseDraft.stepsFor(flowContext).length - 1,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('Add expense'));
          await tester.pumpAndSettle();

          // Record count and outbox count are unchanged because both ran in one transaction
          expect(await db.select(db.localExpenses).get(), hasLength(1));
          expect(
            await db.select(db.localOutboxEvents).get(),
            hasLength(outboxBefore.length),
          );
        });

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 4));
        await tester.runAsync(() => db.close());
      },
    );

    testWidgets(
      '2. Encryption throws (for example, no home key) -> neither the record nor the outbox row exists afterwards, '
      'and the UI shows the existing error toast',
      (tester) async {
        await loadCoveFonts();
        tester.view
          ..physicalSize = const Size(411, 914) * 2
          ..devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);

        // Remove the home key so encryption / key lookup throws before any DB write
        await keyStore.removeKey(homeId);

        final flowContext = AddFlowContext(
          anchor: fixedToday,
          today: fixedToday,
          viewerUserId: userId,
          partnerUserId: 'user_ancy',
          hasPartner: true,
        );
        final expenseDraft = ExpenseDraft(
          amount: 1450,
          title: 'Keyless Expense',
          expenseDate: fixedToday,
          category: 'Groceries',
          payer: ExpensePayer.you,
          splitHalfAndHalf: true,
          isPrivate: false,
          paymentMethod: 'card',
          viewerUserId: userId,
          partnerUserId: 'user_ancy',
          hasPartner: true,
        );

        await withClock(Clock.fixed(fixedNow), () async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: buildRealSyncOverrides(),
              child: MaterialApp(
                theme: CoveTheme.darkTheme,
                home: Scaffold(
                  body: AddFlow(
                    initialKind: AddKind.expense,
                    initialDraft: expenseDraft,
                    initialStepIndex:
                        expenseDraft.stepsFor(flowContext).length - 1,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.bySemanticsLabel('Add expense'));
          await tester.pumpAndSettle();

          // Neither the record nor the outbox row nor the activity event row exists
          expect(await db.select(db.localExpenses).get(), isEmpty);
          expect(await db.select(db.localOutboxEvents).get(), isEmpty);
          expect(await db.select(db.localActivityEvents).get(), isEmpty);

          // UI shows the existing error toast ('Could not save: ...')
          expect(find.textContaining('Could not save:'), findsWidgets);
          expect(find.text('Added.'), findsNothing);
        });

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 4));
        await tester.runAsync(() => db.close());
      },
    );

    test(
      '3. A secure-storage write inside applyEvent (partner-name update) runs after the transaction commits '
      'and completes in under 1s with a fake slow storage',
      () async {
        final slowStorage = _FakeSlowSecureStorage(
          // 6 sequential writes * 250ms would take 1.5s if run sequentially.
          delayPerCall: const Duration(milliseconds: 250),
        );

        final slowStateStore = LocalStateStoreImpl(
          db,
          storage: slowStorage,
        );

        // When eventStore.appendEvent runs, the SQLite transaction is open.
        // Verify zero secure-storage writes have happened at that point.
        var storageWritesAtAppendTime = -1;
        eventStore.onAppend = () {
          storageWritesAtAppendTime = slowStorage.writeCalls;
        };

        final engineWithCheck = SyncEngineImpl(
          eventStore: eventStore,
          localStateStore: slowStateStore,
          encryptionService: cryptoService,
          keyStore: keyStore,
          getCurrentUserId: () => userId,
          getActiveHomeId: () => homeId,
        );

        final sw = Stopwatch()..start();
        await engineWithCheck.dispatchLocalEvent(
          eventType: 'member_profile_updated',
          payload: <String, dynamic>{
            'display_name': 'Ancy',
            'avatar_url': 'https://example.com/ancy.png',
            'user_id': 'user_ancy',
          },
          homeId: homeId,
        );
        sw.stop();

        // 1. Storage writes did NOT happen while the SQLite transaction was open
        expect(storageWritesAtAppendTime, 0);
        // 2. Total time completed in well under 1s even with 6 writes to a 250ms fake slow storage
        expect(
          sw.elapsed,
          lessThan(const Duration(seconds: 1)),
          reason:
              'dispatchLocalEvent took ${sw.elapsedMilliseconds}ms with slow storage',
        );
        // 3. All 6 partner profile keys were persisted after commit
        expect(slowStorage.writeCalls, 6);
        expect(slowStorage.values['cove_partner_name_$homeId'], 'Ancy');
        expect(slowStorage.values['cove_partner_id_$homeId'], 'user_ancy');

        // 4. Even if storage hangs for 2 seconds per write, applyEvent still
        //    completes in under 1 second without holding the transaction open.
        final hangingStorage = _FakeSlowSecureStorage(
          delayPerCall: const Duration(seconds: 2),
        );
        final hangingStore = LocalStateStoreImpl(db, storage: hangingStorage);
        final swHang = Stopwatch()..start();
        await hangingStore.applyEvent(
          eventId: 'evt_partner_profile_slow',
          homeId: homeId,
          eventType: 'member_profile_updated',
          payload: <String, dynamic>{
            'display_name': 'Ancy Updated',
            'avatar_url': 'https://example.com/ancy2.png',
            'user_id': 'user_ancy',
          },
          timestamp: fixedNow,
          authorId: 'user_ancy',
        );
        swHang.stop();
        expect(
          swHang.elapsed,
          lessThan(const Duration(seconds: 1)),
          reason:
              'applyEvent took ${swHang.elapsedMilliseconds}ms with 2s-per-write storage',
        );

        await db.close();
      },
    );
  });
}
