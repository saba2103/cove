import 'package:clock/clock.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/habits/habit_controller.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/subscriptions/subscription_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/pending_delete_service.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthNotifier extends AuthNotifier {
  final CoveUser _user;
  _TestAuthNotifier(this._user);

  @override
  AsyncValue<CoveUser?> build() => AsyncValue.data(_user);
}

class _ActiveHomeIdStub extends ActiveHomeNotifier {
  final String? _initial;
  _ActiveHomeIdStub(this._initial);

  @override
  String? build() => _initial;
}

class _EmittedEvent {
  final String eventType;
  final Map<String, dynamic> payload;
  final String homeId;

  const _EmittedEvent({
    required this.eventType,
    required this.payload,
    required this.homeId,
  });
}

ProviderContainer _makeContainer({
  required AppDatabase db,
  required List<_EmittedEvent> emittedEvents,
  String? activeHomeId = 'home-1',
  String userId = 'user-saba',
  String userName = 'Saba',
  bool isBackgroundIsolate = false,
  AppDatabase? partnerDb,
}) {
  final store = LocalStateStoreImpl(db);
  final partnerStore = partnerDb != null ? LocalStateStoreImpl(partnerDb) : null;
  var eventSeq = 0;

  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      activeHomeIdProvider.overrideWith(() => _ActiveHomeIdStub(activeHomeId)),
      authProvider.overrideWith(
        () => _TestAuthNotifier(
          CoveUser(
            id: userId,
            email: '$userId@cove.app',
            displayName: userName,
          ),
        ),
      ),
      isBackgroundIsolateProvider.overrideWithValue(isBackgroundIsolate),
      coveEmitActionProvider.overrideWithValue(({
        required String eventType,
        required Map<String, dynamic> payload,
        String? targetHomeId,
      }) async {
        final resolvedHomeId =
            targetHomeId ?? (payload['home_id'] as String?) ?? activeHomeId ?? 'home-1';
        emittedEvents.add(
          _EmittedEvent(
            eventType: eventType,
            payload: Map<String, dynamic>.from(payload),
            homeId: resolvedHomeId,
          ),
        );
        final eventId = 'ev-${++eventSeq}-$eventType';
        final now = clock.now().toUtc();
        await store.applyEvent(
          eventId: eventId,
          homeId: resolvedHomeId,
          eventType: eventType,
          payload: payload,
          timestamp: now,
          authorId: userId,
        );
        if (partnerStore != null) {
          await partnerStore.applyEvent(
            eventId: eventId,
            homeId: resolvedHomeId,
            eventType: eventType,
            payload: payload,
            timestamp: now,
            authorId: userId,
          );
        }
      }),
    ],
  );
}

Future<T> _readStream<T>(
  ProviderContainer container,
  StreamProvider<T> provider,
) async {
  final sub = container.listen<AsyncValue<T>>(provider, (_, _) {});
  try {
    await Future<void>.delayed(Duration.zero);
    return await container.read(provider.future);
  } finally {
    sub.close();
  }
}

Future<void> _seedHome(AppDatabase db, {String homeId = 'home-1'}) async {
  await db.into(db.localHomes).insertOnConflictUpdate(
        LocalHomesCompanion.insert(
          id: homeId,
          name: 'Test Home',
          createdBy: 'user-saba',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
    PendingDeleteService.markAsBackgroundIsolate(false);
  });

  group('4.6a — PendingDeleteService deferred delete', () {
    test(
      'delete then undo → the same id, all fields unchanged, zero delete events emitted (all 6 kinds)',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        await _seedHome(db);

        final emittedEvents = <_EmittedEvent>[];
        final container = _makeContainer(
          db: db,
          emittedEvents: emittedEvents,
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });

        // 1. Seed one record of each of the 6 kinds via the real controllers
        final expenseId = await container
            .read(expenseControllerProvider)
            .logExpense(
              title: 'Blue Tokai Coffee',
              amount: 420.0,
              category: 'Dining',
              notes: 'Morning flat white',
              paidBy: 'user-saba',
            );

        final listId = await container
            .read(listControllerProvider)
            .createList(name: 'Groceries');
        final listItemId = await container
            .read(listControllerProvider)
            .addItem(
              listId: listId,
              title: 'Sourdough bread',
              notes: 'From Subko',
              dueDate: DateTime.utc(2026, 10, 28),
            );

        final habitId = await container
            .read(habitControllerProvider)
            .createHabit(
              name: 'Evening Walk',
              cadence: 'daily',
              targetDaysPerWeek: 7,
            );

        await container.read(calendarControllerProvider).createEvent(
              title: 'Dinner at Vetro',
              startTime: DateTime.utc(2026, 10, 27, 14, 0),
              endTime: DateTime.utc(2026, 10, 27, 16, 0),
              description: 'Anniversary dinner',
              location: 'Oberoi',
            );

        await container.read(subscriptionControllerProvider).createSubscription(
              name: 'Apple One',
              amount: 365.0,
              billingCycle: 'monthly',
              nextBillingDate: DateTime.utc(2026, 11, 5),
              category: 'Entertainment',
              paidBy: 'user-saba',
              financedThrough: 'HDFC Infinia',
            );

        final routineId = await container
            .read(routineControllerProvider)
            .createRoutine(name: 'Weekday', days: [1, 2, 3, 4, 5]);
        final routineEventId = await container
            .read(routineControllerProvider)
            .createRoutineEvent(
              routineId: routineId,
              title: 'Morning Stretch',
              startMinutes: 420,
              endMinutes: 450,
              category: 'Health',
              notes: 'Mat in study',
            );

        final expenseBefore = (await (db.select(db.localExpenses)
                  ..where((t) => t.id.equals(expenseId)))
                .get())
            .single;
        final listItemBefore = (await (db.select(db.localListItems)
                  ..where((t) => t.id.equals(listItemId)))
                .get())
            .single;
        final habitBefore = (await (db.select(db.localHabits)
                  ..where((t) => t.id.equals(habitId)))
                .get())
            .single;
        final eventBefore =
            (await db.select(db.localCalendarEvents).get()).single;
        final commitmentBefore =
            (await db.select(db.localSubscriptions).get()).single;
        final routineBefore = (await (db.select(db.localRoutineEvents)
                  ..where((t) => t.id.equals(routineEventId)))
                .get())
            .single;

        final emittedBaselineCount = emittedEvents.length;
        final pendingDelete = container.read(pendingDeleteServiceProvider);

        // 2. Schedule deferred delete on all 6 kinds
        await pendingDelete.scheduleDelete(
          kind: PendingDeleteKind.expense,
          id: expenseBefore.id,
          duration: const Duration(seconds: 5),
        );
        await pendingDelete.scheduleDelete(
          kind: PendingDeleteKind.listItem,
          id: listItemBefore.id,
          duration: const Duration(seconds: 5),
        );
        await pendingDelete.scheduleDelete(
          kind: PendingDeleteKind.habit,
          id: habitBefore.id,
          duration: const Duration(seconds: 5),
        );
        await pendingDelete.scheduleDelete(
          kind: PendingDeleteKind.event,
          id: eventBefore.id,
          duration: const Duration(seconds: 5),
        );
        await pendingDelete.scheduleDelete(
          kind: PendingDeleteKind.commitment,
          id: commitmentBefore.id,
          duration: const Duration(seconds: 5),
        );
        await pendingDelete.scheduleDelete(
          kind: PendingDeleteKind.routineEvent,
          id: routineBefore.id,
          duration: const Duration(seconds: 5),
        );

        // Verify all 6 are immediately filtered from providers
        expect(
          container.read(pendingDeleteIdsProvider(PendingDeleteKind.expense)),
          contains(expenseBefore.id),
        );
        expect(
          container.read(pendingDeleteIdsProvider(PendingDeleteKind.listItem)),
          contains(listItemBefore.id),
        );
        expect(
          container.read(pendingDeleteIdsProvider(PendingDeleteKind.habit)),
          contains(habitBefore.id),
        );
        expect(
          container.read(pendingDeleteIdsProvider(PendingDeleteKind.event)),
          contains(eventBefore.id),
        );
        expect(
          container
              .read(pendingDeleteIdsProvider(PendingDeleteKind.commitment)),
          contains(commitmentBefore.id),
        );
        expect(
          container
              .read(pendingDeleteIdsProvider(PendingDeleteKind.routineEvent)),
          contains(routineBefore.id),
        );

        expect(
          await _readStream(container, activeHomeExpensesProvider),
          isEmpty,
        );
        expect(
          await _readStream(container, activeHomeAllListItemsProvider),
          isEmpty,
        );
        expect(
          await _readStream(container, activeHomeHabitsProvider),
          isEmpty,
        );
        expect(
          await _readStream(container, activeHomeCalendarEventsProvider),
          isEmpty,
        );
        expect(
          await _readStream(container, activeHomeSubscriptionsProvider),
          isEmpty,
        );
        expect(
          await _readStream(container, activeHomeAllRoutineEventsProvider),
          isEmpty,
        );

        // Zero events emitted while pending
        expect(emittedEvents.length, emittedBaselineCount);

        // 3. Undo all 6 deletes
        await pendingDelete.undoDelete(
          kind: PendingDeleteKind.expense,
          id: expenseBefore.id,
        );
        await pendingDelete.undoDelete(
          kind: PendingDeleteKind.listItem,
          id: listItemBefore.id,
        );
        await pendingDelete.undoDelete(
          kind: PendingDeleteKind.habit,
          id: habitBefore.id,
        );
        await pendingDelete.undoDelete(
          kind: PendingDeleteKind.event,
          id: eventBefore.id,
        );
        await pendingDelete.undoDelete(
          kind: PendingDeleteKind.commitment,
          id: commitmentBefore.id,
        );
        await pendingDelete.undoDelete(
          kind: PendingDeleteKind.routineEvent,
          id: routineBefore.id,
        );

        // Wait briefly to prove timers were cancelled
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // 4. Verify zero events emitted
        expect(emittedEvents.length, emittedBaselineCount);

        // 5. Verify the exact same id and all fields unchanged
        final expenseAfter = (await db.select(db.localExpenses).get()).single;
        expect(expenseAfter, equals(expenseBefore));
        expect(expenseAfter.id, expenseBefore.id);

        final listItemAfter =
            (await db.select(db.localListItems).get()).single;
        expect(listItemAfter, equals(listItemBefore));
        expect(listItemAfter.id, listItemBefore.id);

        final habitAfter = (await db.select(db.localHabits).get()).single;
        expect(habitAfter, equals(habitBefore));
        expect(habitAfter.id, habitBefore.id);

        final eventAfter =
            (await db.select(db.localCalendarEvents).get()).single;
        expect(eventAfter, equals(eventBefore));
        expect(eventAfter.id, eventBefore.id);

        final commitmentAfter =
            (await db.select(db.localSubscriptions).get()).single;
        expect(commitmentAfter, equals(commitmentBefore));
        expect(commitmentAfter.id, commitmentBefore.id);

        final routineAfter =
            (await db.select(db.localRoutineEvents).get()).single;
        expect(routineAfter, equals(routineBefore));
        expect(routineAfter.id, routineBefore.id);

        // And all 6 are visible in providers again with the exact same IDs
        expect(
          (await _readStream(container, activeHomeExpensesProvider)).single.id,
          expenseBefore.id,
        );
        expect(
          (await _readStream(container, activeHomeAllListItemsProvider))
              .single
              .id,
          listItemBefore.id,
        );
        expect(
          (await _readStream(container, activeHomeHabitsProvider)).single.id,
          habitBefore.id,
        );
        expect(
          (await _readStream(container, activeHomeCalendarEventsProvider))
              .single
              .id,
          eventBefore.id,
        );
        expect(
          (await _readStream(container, activeHomeSubscriptionsProvider))
              .single
              .id,
          commitmentBefore.id,
        );
        expect(
          (await _readStream(container, activeHomeAllRoutineEventsProvider))
              .single
              .id,
          routineBefore.id,
        );
      },
    );

    test(
      'delete then timeout → exactly one delete event',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedHome(db);

        final emittedEvents = <_EmittedEvent>[];
        final container = _makeContainer(
          db: db,
          emittedEvents: emittedEvents,
        );
        addTearDown(container.dispose);

        final expenseId = await container
            .read(expenseControllerProvider)
            .logExpense(
              title: 'Dinner',
              amount: 850.0,
              paidBy: 'user-saba',
            );

        expect(
          emittedEvents.where((e) => e.eventType == 'expense_deleted'),
          isEmpty,
        );

        final pendingDelete = container.read(pendingDeleteServiceProvider);
        await pendingDelete.scheduleDelete(
          kind: PendingDeleteKind.expense,
          id: expenseId,
          duration: const Duration(milliseconds: 60),
        );

        // Before timeout: zero delete events
        expect(
          emittedEvents.where((e) => e.eventType == 'expense_deleted'),
          isEmpty,
        );

        // Wait for timeout to fire
        await Future<void>.delayed(const Duration(milliseconds: 120));

        final deleteEvents = emittedEvents
            .where((e) => e.eventType == 'expense_deleted')
            .toList();
        expect(deleteEvents.length, 1);
        expect(deleteEvents.single.payload['id'], expenseId);

        // Underlying DB row is deleted and pending record cleared
        expect(await db.select(db.localExpenses).get(), isEmpty);
        expect(
          container.read(pendingDeleteIdsProvider(PendingDeleteKind.expense)),
          isEmpty,
        );
      },
    );

    test(
      'delete then the app killed then restart → exactly one delete event, after restart',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedHome(db);

        final emittedEvents = <_EmittedEvent>[];
        final t0 = DateTime.utc(2026, 10, 27, 12, 0, 0);
        late String commitmentId;

        // Session 1: User taps Delete, then kills the app before the 5s toast expires
        await withClock(Clock.fixed(t0), () async {
          final container1 = _makeContainer(
            db: db,
            emittedEvents: emittedEvents,
          );
          await container1
              .read(subscriptionControllerProvider)
              .createSubscription(
                name: 'Netflix',
                amount: 649.0,
                billingCycle: 'monthly',
                nextBillingDate: DateTime.utc(2026, 11, 1),
              );
          commitmentId =
              (await db.select(db.localSubscriptions).get()).single.id;

          await container1.read(pendingDeleteServiceProvider).scheduleDelete(
                kind: PendingDeleteKind.commitment,
                id: commitmentId,
                duration: const Duration(seconds: 5),
              );

          // App killed before timer completes: dispose container1
          container1.dispose();
        });

        // Verify zero delete events were emitted before restart, and row still exists in SQLite
        expect(
          emittedEvents.where((e) => e.eventType == 'subscription_deleted'),
          isEmpty,
        );
        expect((await db.select(db.localSubscriptions).get()).length, 1);

        // Session 2: App restarts 10 seconds later (past the 5s toast duration)
        // Even before activeHomeIdProvider is populated on startup!
        await withClock(
          Clock.fixed(t0.add(const Duration(seconds: 10))),
          () async {
            final container2 = _makeContainer(
              db: db,
              emittedEvents: emittedEvents,
              activeHomeId: null,
            );
            addTearDown(container2.dispose);

            await container2
                .read(pendingDeleteServiceProvider)
                .flushExpiredOnAppStart();

            final deleteEvents = emittedEvents
                .where((e) => e.eventType == 'subscription_deleted')
                .toList();
            expect(deleteEvents.length, 1);
            expect(deleteEvents.single.payload['id'], commitmentId);
            expect(await db.select(db.localSubscriptions).get(), isEmpty);

            // Calling flushExpiredOnAppStart again emits nothing more
            await container2
                .read(pendingDeleteServiceProvider)
                .flushExpiredOnAppStart();
            expect(
              emittedEvents
                  .where((e) => e.eventType == 'subscription_deleted')
                  .length,
              1,
            );
          },
        );
      },
    );

    test(
      'the partner device sees nothing during the undo window',
      () async {
        final dbA = AppDatabase(NativeDatabase.memory());
        final dbB = AppDatabase(NativeDatabase.memory());
        await _seedHome(dbA);
        await _seedHome(dbB);

        final emittedEvents = <_EmittedEvent>[];
        final containerA = _makeContainer(
          db: dbA,
          partnerDb: dbB,
          emittedEvents: emittedEvents,
          userId: 'user-saba',
          userName: 'Saba',
        );

        final partnerEvents = <_EmittedEvent>[];
        final containerB = _makeContainer(
          db: dbB,
          emittedEvents: partnerEvents,
          userId: 'user-ancy',
          userName: 'Ancy',
        );
        addTearDown(() async {
          containerA.dispose();
          containerB.dispose();
          await dbA.close();
          await dbB.close();
        });

        // Device A logs an expense -> immediately synced to Partner Device B
        final expenseId = await containerA
            .read(expenseControllerProvider)
            .logExpense(
              title: 'Groceries',
              amount: 1200.0,
              paidBy: 'user-saba',
            );

        expect(
          (await _readStream(containerB, activeHomeExpensesProvider)).single.id,
          expenseId,
        );

        final emittedCountBeforeDelete = emittedEvents.length;

        // Device A deletes the expense (entering the 5-second undo window)
        await containerA.read(pendingDeleteServiceProvider).scheduleDelete(
              kind: PendingDeleteKind.expense,
              id: expenseId,
              duration: const Duration(seconds: 5),
            );

        // Device A's UI hides the expense immediately
        expect(
          await _readStream(containerA, activeHomeExpensesProvider),
          isEmpty,
        );

        // Partner Device B sees nothing during the undo window:
        // - Zero new events were emitted by Device A
        // - Partner Device B still sees the expense untouched in its provider and DB
        expect(emittedEvents.length, emittedCountBeforeDelete);
        final partnerVisibleDuringWindow =
            await _readStream(containerB, activeHomeExpensesProvider);
        expect(partnerVisibleDuringWindow.length, 1);
        expect(partnerVisibleDuringWindow.single.id, expenseId);
        expect(partnerVisibleDuringWindow.single.title, 'Groceries');

        // Undo on Device A -> still zero events emitted to Partner Device B
        await containerA.read(pendingDeleteServiceProvider).undoDelete(
              kind: PendingDeleteKind.expense,
              id: expenseId,
            );
        expect(emittedEvents.length, emittedCountBeforeDelete);
        expect(
          (await _readStream(containerB, activeHomeExpensesProvider)).single.id,
          expenseId,
        );
      },
    );

    test(
      'background isolates never emit deletes',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await _seedHome(db);

        final emittedEvents = <_EmittedEvent>[];
        final t0 = DateTime.utc(2026, 10, 27, 10, 0, 0);
        late String expenseId;

        // Foreground schedules a delete at t0
        await withClock(Clock.fixed(t0), () async {
          final fgContainer = _makeContainer(
            db: db,
            emittedEvents: emittedEvents,
            isBackgroundIsolate: false,
          );
          expenseId = await fgContainer
              .read(expenseControllerProvider)
              .logExpense(
                title: 'Lunch',
                amount: 500.0,
                paidBy: 'user-saba',
              );
          await fgContainer.read(pendingDeleteServiceProvider).scheduleDelete(
                kind: PendingDeleteKind.expense,
                id: expenseId,
                duration: const Duration(seconds: 5),
              );
          fgContainer.dispose();
        });

        // Background isolate runs 20 seconds later (past expiry)
        await withClock(
          Clock.fixed(t0.add(const Duration(seconds: 20))),
          () async {
            final bgContainer = _makeContainer(
              db: db,
              emittedEvents: emittedEvents,
              isBackgroundIsolate: true,
            );
            addTearDown(bgContainer.dispose);

            await bgContainer
                .read(pendingDeleteServiceProvider)
                .flushExpiredOnAppStart();
            await bgContainer.read(pendingDeleteServiceProvider).commitDelete(
                  kind: PendingDeleteKind.expense,
                  id: expenseId,
                );

            // Background isolate must NOT have emitted any delete
            expect(
              emittedEvents.where((e) => e.eventType == 'expense_deleted'),
              isEmpty,
            );
            expect((await db.select(db.localExpenses).get()).length, 1);
          },
        );
      },
    );
  });
}
