import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/activity/activity_detail_sheet.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/add/add_flow.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/expenses/expense_detail_sheet.dart';
import 'package:cove/features/habits/habit_detail_sheet.dart';
import 'package:cove/features/home/home_settings_screen.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/lists/list_item_detail_sheet.dart';
import 'package:cove/features/pets/pet_controller.dart';
import 'package:cove/features/subscriptions/commitment_detail_sheet.dart';
import 'package:cove/sync/crypto/sodium_crypto_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/event_store_impl.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/pending_delete_service.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/sync_engine_impl.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthNotifier extends AuthNotifier {
  final CoveUser? initialUser;
  _TestAuthNotifier(this.initialUser);

  @override
  AsyncValue<CoveUser?> build() => AsyncValue.data(initialUser);
}

class _ActiveHomeIdStub extends ActiveHomeNotifier {
  final String? _initial;
  _ActiveHomeIdStub(this._initial);

  @override
  String? build() => _initial;
}

class _ActiveHomePartnerStub extends ActiveHomePartnerNotifier {
  @override
  bool build() => true;
}

class _InMemoryHomeKeyStore extends HomeKeyStore {
  final Map<String, Uint8List> _keys = <String, Uint8List>{};

  @override
  Future<void> saveKey(String homeId, Uint8List key) async {
    _keys[homeId] = key;
  }

  @override
  Future<Uint8List?> getKey(String homeId) async => _keys[homeId];
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  const homeId = 'home_pets_47e';
  const alex = CoveUser(
    id: 'user_alex',
    email: 'alex@cove.app',
    displayName: 'Alex',
  );

  Future<(AppDatabase, LocalStateStoreImpl)> createTestDb() async {
    final db = AppDatabase(NativeDatabase.memory());
    final store = LocalStateStoreImpl(db);
    await db.into(db.localHomes).insertOnConflictUpdate(
          LocalHomesCompanion.insert(
            id: homeId,
            name: 'Our Cove',
            createdBy: 'user_alex',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
    return (db, store);
  }

  ProviderContainer createContainer({
    required AppDatabase db,
    required LocalStateStoreImpl store,
    required List<(String, Map<String, dynamic>)> emittedEvents,
  }) {
    var seq = 0;
    return ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeHomeIdProvider.overrideWith(() => _ActiveHomeIdStub(homeId)),
        activeHomeProvider.overrideWith(
          (ref) => Stream.value(
            LocalHome(
              id: homeId,
              name: 'Our Cove',
              createdAt: DateTime.utc(2026, 1, 1),
              createdBy: 'user_alex',
              currency: 'INR',
            ),
          ),
        ),
        activeHomeHasPartnerProvider
            .overrideWith(_ActiveHomePartnerStub.new),
        authProvider.overrideWith(() => _TestAuthNotifier(alex)),
        coveEmitActionProvider.overrideWithValue(({
          required String eventType,
          required Map<String, dynamic> payload,
          String? targetHomeId,
        }) async {
          final targetHome = targetHomeId ?? homeId;
          emittedEvents.add((eventType, Map<String, dynamic>.from(payload)));
          await store.applyEvent(
            eventId: 'evt_${++seq}_$eventType',
            homeId: targetHome,
            eventType: eventType,
            payload: payload,
            timestamp: clock.now().toUtc(),
            authorId: alex.id,
          );
        }),
      ],
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'cove_user_display_name_user_alex': 'Alex',
      'cove_partner_display_name_home_${homeId}_partner': 'Sam',
      'cove_partner_user_id_home_${homeId}_partner': 'user_sam',
      'first_run_done.ourHome.$homeId': true,
    });
    PendingDeleteService.markAsBackgroundIsolate(false);
  });

  test(
    'Private expense with a pet tag writes locally and emits zero synced events',
    () async {
      final (db, store) = await createTestDb();
      final emittedEvents = <(String, Map<String, dynamic>)>[];
      final container = createContainer(
        db: db,
        store: store,
        emittedEvents: emittedEvents,
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      // Seed a shared pet first, then clear emittedEvents to measure only the
      // private expense + pet tag operation.
      final petController = container.read(petControllerProvider);
      final lylaId = await petController.createPet('Lyla');
      emittedEvents.clear();

      // Create a private expense and tag Lyla on it (same path as AddFlow._handleCommit).
      final expenseController = container.read(expenseControllerProvider);
      final expenseId = await expenseController.logExpense(
        title: 'Vet checkup (private)',
        amount: 1200,
        currency: 'INR',
        expenseDate: DateTime.utc(2026, 4, 20),
        paidBy: alex.id,
        category: 'Pets',
        visibility: ExpenseVisibility.privateToMe,
      );

      await petController.setRecordPetTags(
        recordKind: PetRecordKind.expense,
        recordId: expenseId,
        petIds: {lylaId},
        isPrivate: true,
      );

      // Zero synced events emitted!
      expect(emittedEvents, isEmpty);
      final outbox = await EventStoreImpl(db: db).getPendingUploadEvents();
      expect(outbox, isEmpty);

      // Tag is persisted locally in local_pet_tags.
      final localTags = await db.getPetTagsForRecord(
        PetRecordKind.expense,
        expenseId,
      );
      expect(localTags, hasLength(1));
      expect(localTags.single.petId, lylaId);

      // Removing the tag on the private expense also emits zero synced events.
      await petController.removePetTag(
        petId: lylaId,
        recordKind: PetRecordKind.expense,
        recordId: expenseId,
        isPrivate: true,
      );
      expect(emittedEvents, isEmpty);
      final afterRemove = await db.getPetTagsForRecord(
        PetRecordKind.expense,
        expenseId,
      );
      expect(afterRemove, isEmpty);
    },
  );

  testWidgets(
    'Add flow: "About a pet?" chips appear when active pets exist and tag private expense with zero synced events',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (db, store) = await createTestDb();
      final emittedEvents = <(String, Map<String, dynamic>)>[];
      final container = createContainer(
        db: db,
        store: store,
        emittedEvents: emittedEvents,
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final petController = container.read(petControllerProvider);
      final lylaId = await petController.createPet('Lyla');
      emittedEvents.clear();

      final draft = ExpenseDraft(
        amount: 850,
        title: 'Dog treats',
        expenseDate: DateTime(2026, 4, 20),
        category: 'Pets',
        payer: ExpensePayer.you,
        splitHalfAndHalf: false,
        isPrivate: true,
        paymentMethod: 'upi',
        viewerUserId: alex.id,
        partnerUserId: 'user_sam',
        hasPartner: true,
      );

      // Open AddFlow on step 4 (expenseWhoPaid, index 4).
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: CoveTheme.lightTheme,
            home: Scaffold(
              body: AddFlow(
                initialKind: AddKind.expense,
                initialDraft: draft,
                initialStepIndex: 4,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Who paid?'), findsOneWidget);
      expect(find.text('About a pet?'), findsOneWidget);
      expect(find.byKey(ValueKey('add_pet_chip_$lylaId')), findsOneWidget);

      // Select Lyla chip.
      await tester.ensureVisible(find.byKey(ValueKey('add_pet_chip_$lylaId')));
      await tester.tap(find.byKey(ValueKey('add_pet_chip_$lylaId')));
      await tester.pumpAndSettle();

      // Tap Next -> Payment method (already 'upi') -> Next -> Review -> Add expense.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Add expense'), findsOneWidget);
      await tester.tap(find.text('Add expense'));
      await tester.pumpAndSettle();

      expect(find.text('Added.'), findsOneWidget);

      // Because the expense was marked private, zero sync events were emitted!
      expect(emittedEvents, isEmpty);

      final expenses = await db.getExpenses(homeId, currentUserId: alex.id);
      expect(expenses, hasLength(1));
      final tags = await db.getPetTagsForRecord(
        PetRecordKind.expense,
        expenses.single.id,
      );
      expect(tags, hasLength(1));
      expect(tags.single.petId, lylaId);
    },
  );

  testWidgets(
    'Our home -> Pets: add a pet, tap to rename, archive from overflow menu',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (db, store) = await createTestDb();
      final emittedEvents = <(String, Map<String, dynamic>)>[];
      final container = createContainer(
        db: db,
        store: store,
        emittedEvents: emittedEvents,
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: CoveTheme.lightTheme,
            home: const HomeSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PETS'), findsOneWidget);
      expect(find.byKey(const ValueKey('our_home_add_pet_row')), findsOneWidget);

      // Tap "Add a pet"
      await tester.ensureVisible(
        find.byKey(const ValueKey('our_home_add_pet_row')),
      );
      await tester.tap(find.byKey(const ValueKey('our_home_add_pet_row')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('our_home_pet_name_input')),
        'Lyla',
      );
      await tester.tap(
        find.byKey(const ValueKey('our_home_pet_add_confirm')),
      );
      await tester.pumpAndSettle();

      final petsAfterCreate = await db.getPets(homeId);
      expect(petsAfterCreate, hasLength(1));
      expect(petsAfterCreate.single.name, 'Lyla');
      final petId = petsAfterCreate.single.id;
      expect(find.byKey(ValueKey('our_home_pet_row_$petId')), findsOneWidget);

      // Tap pet row to rename
      await tester.ensureVisible(
        find.byKey(ValueKey('our_home_pet_row_$petId')),
      );
      await tester.tap(find.byKey(ValueKey('our_home_pet_row_$petId')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('our_home_pet_rename_input')),
        'Lyla Bear',
      );
      await tester.tap(
        find.byKey(const ValueKey('our_home_pet_rename_confirm')),
      );
      await tester.pumpAndSettle();

      final petsAfterRename = await db.getPets(homeId);
      expect(petsAfterRename.single.name, 'Lyla Bear');
      expect(find.text('Lyla Bear'), findsOneWidget);

      // Archive from overflow menu
      await tester.tap(find.byKey(ValueKey('our_home_pet_menu_$petId')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive Lyla Bear'));
      await tester.pumpAndSettle();

      final petsAfterArchive = await db.getPets(homeId);
      expect(petsAfterArchive.single.isArchived, isTrue);
      expect(find.byKey(ValueKey('our_home_pet_row_$petId')), findsNothing);
    },
  );

  testWidgets(
    'Detail sheets render pet tag chips under meaning panel (greyed out when archived) and overflow menu opens PetTagPickerSheet',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (db, store) = await createTestDb();
      final emittedEvents = <(String, Map<String, dynamic>)>[];
      final container = createContainer(
        db: db,
        store: store,
        emittedEvents: emittedEvents,
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final petController = container.read(petControllerProvider);
      final lylaId = await petController.createPet('Lyla');
      final miloId = await petController.createPet('Milo');

      final expenseId = await container.read(expenseControllerProvider).logExpense(
            title: 'Kibble',
            amount: 500,
            currency: 'INR',
            expenseDate: DateTime.utc(2026, 4, 20),
            paidBy: alex.id,
            category: 'Pets',
          );

      final expense = (await db.getExpenses(homeId)).single;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: CoveTheme.lightTheme,
            home: Scaffold(
              body: ExpenseDetailSheet(expense: expense),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially untagged -> no pet tag chips, menu says "Tag a pet…"
      expect(
        find.byKey(const ValueKey('record_pet_tag_chips')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('cove_detail_sheet_menu_button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tag a pet…'), findsOneWidget);

      // Open PetTagPickerSheet and tag both Lyla and Milo.
      await tester.tap(find.text('Tag a pet…'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey('pet_picker_row_$lylaId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('pet_picker_row_$miloId')));
      await tester.pumpAndSettle();

      // Close picker sheet.
      await tester.tap(find.byKey(const ValueKey('pet_tag_picker_close_button')));
      await tester.pumpAndSettle();

      // Chips now appear under meaning panel!
      expect(
        find.byKey(const ValueKey('record_pet_tag_chips')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('record_pet_chip_$lylaId')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('record_pet_chip_$miloId')),
        findsOneWidget,
      );

      // Archive Milo -> Milo stays on the old expense record, greyed out!
      await petController.archivePet(miloId);
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('record_pet_chip_$lylaId')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('record_pet_chip_archived_$miloId')),
        findsOneWidget,
      );

      // Menu now says "Change pets…"
      await tester.tap(
        find.byKey(const ValueKey('cove_detail_sheet_menu_button')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Change pets…'), findsOneWidget);
      expect(expenseId, isNotEmpty);
    },
  );

  testWidgets(
    'Task, Habit, Commitment, and Event detail sheets render pet tag chips under meaning panel',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final (db, store) = await createTestDb();
      final emittedEvents = <(String, Map<String, dynamic>)>[];
      final container = createContainer(
        db: db,
        store: store,
        emittedEvents: emittedEvents,
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final petController = container.read(petControllerProvider);
      final lylaId = await petController.createPet('Lyla');

      // Task
      final listId = await container
          .read(listControllerProvider)
          .createList(name: 'Errands');
      final taskId = await container.read(listControllerProvider).addItem(
            listId: listId,
            title: 'Buy leash',
          );
      await petController.addPetTag(
        petId: lylaId,
        recordKind: PetRecordKind.task,
        recordId: taskId,
      );

      final item = (await db.getListItems(homeId, listId)).single;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: CoveTheme.lightTheme,
            home: Scaffold(
              body: ListItemDetailSheet(item: item, listName: 'Errands'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('record_pet_chip_$lylaId')), findsOneWidget);

      // Habit
      final habit = LocalHabit(
        id: 'habit_walk_lyla',
        homeId: homeId,
        name: 'Walk Lyla',
        cadence: 'daily',
        targetDaysPerWeek: 7,
        isArchived: false,
        createdAt: DateTime.utc(2026, 4, 1),
        createdBy: alex.id,
      );
      await db.into(db.localHabits).insert(habit.toCompanion(true));
      await petController.addPetTag(
        petId: lylaId,
        recordKind: PetRecordKind.habit,
        recordId: habit.id,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: CoveTheme.lightTheme,
            home: Scaffold(
              body: HabitDetailSheet(
                habit: habit,
                checkins: const [],
                isPartnerHabit: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('record_pet_chip_$lylaId')), findsOneWidget);

      // Commitment
      final sub = LocalSubscription(
        id: 'sub_pet_insurance',
        homeId: homeId,
        name: 'Pet insurance',
        amount: 900,
        currency: 'INR',
        billingCycle: 'monthly',
        nextBillingDate: DateTime.utc(2026, 5, 1),
        category: 'Pets',
        isActive: true,
        isPrivate: false,
        createdBy: alex.id,
        paidBy: alex.id,
        createdAt: DateTime.utc(2026, 4, 1),
      );
      await db.into(db.localSubscriptions).insert(sub.toCompanion(true));
      await petController.addPetTag(
        petId: lylaId,
        recordKind: PetRecordKind.commitment,
        recordId: sub.id,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: CoveTheme.lightTheme,
            home: Scaffold(
              body: CommitmentDetailSheet(subscription: sub),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('record_pet_chip_$lylaId')), findsOneWidget);

      // Calendar Event
      final ev = LocalCalendarEvent(
        id: 'ev_vet_visit',
        homeId: homeId,
        title: 'Vet visit',
        startTime: DateTime.utc(2026, 4, 21, 10, 0),
        endTime: DateTime.utc(2026, 4, 21, 11, 0),
        isAllDay: false,
        createdBy: alex.id,
        owner: 'both',
        createdAt: DateTime.utc(2026, 4, 1),
      );
      await db.into(db.localCalendarEvents).insert(ev.toCompanion(true));
      await petController.addPetTag(
        petId: lylaId,
        recordKind: PetRecordKind.event,
        recordId: ev.id,
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: CoveTheme.lightTheme,
            home: Scaffold(
              body: CalendarEventDetailSheet(event: ev),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('record_pet_chip_$lylaId')), findsOneWidget);
    },
  );

  test(
    'Saba deletes a tagged expense -> after sync, zero tags for it on Ancy\'s device too; an undo during the window leaves the tags on both',
    () async {
      // Saba's device and Ancy's device each have their own SQLite database.
      final (sabaDb, sabaStore) = await createTestDb();
      final (ancyDb, ancyStore) = await createTestDb();

      // Any event emitted on Saba's device is applied locally in the same
      // transaction and queued for sync to Ancy's device.
      final relayQueue = <(String, String, Map<String, dynamic>, DateTime)>[];
      var seq = 0;

      final sabaContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(sabaDb),
          activeHomeIdProvider.overrideWith(() => _ActiveHomeIdStub(homeId)),
          activeHomeProvider.overrideWith(
            (ref) => Stream.value(
              LocalHome(
                id: homeId,
                name: 'Our Cove',
                createdAt: DateTime.utc(2026, 1, 1),
                createdBy: alex.id,
                currency: 'INR',
              ),
            ),
          ),
          activeHomeHasPartnerProvider
              .overrideWith(_ActiveHomePartnerStub.new),
          authProvider.overrideWith(() => _TestAuthNotifier(alex)),
          coveEmitActionProvider.overrideWithValue(({
            required String eventType,
            required Map<String, dynamic> payload,
            String? targetHomeId,
          }) async {
            final targetHome = targetHomeId ?? homeId;
            final eventId = 'evt_${++seq}_$eventType';
            final now = clock.now().toUtc();
            final cloned = Map<String, dynamic>.from(payload);
            await sabaStore.applyEvent(
              eventId: eventId,
              homeId: targetHome,
              eventType: eventType,
              payload: cloned,
              timestamp: now,
              authorId: alex.id,
            );
            relayQueue.add((eventId, eventType, cloned, now));
          }),
        ],
      );
      addTearDown(() async {
        sabaContainer.dispose();
        await sabaDb.close();
        await ancyDb.close();
      });

      Future<void> syncRelayToAncy() async {
        while (relayQueue.isNotEmpty) {
          final (eventId, eventType, payload, ts) = relayQueue.removeAt(0);
          await ancyStore.applyEvent(
            eventId: eventId,
            homeId: homeId,
            eventType: eventType,
            payload: payload,
            timestamp: ts,
            authorId: alex.id,
          );
        }
      }

      final petController = sabaContainer.read(petControllerProvider);
      final lylaId = await petController.createPet('Lyla');

      final expenseId = await sabaContainer
          .read(expenseControllerProvider)
          .logExpense(
            title: 'Pet shampoo',
            amount: 350,
            currency: 'INR',
            expenseDate: DateTime.utc(2026, 4, 20),
            paidBy: alex.id,
            category: 'Pets',
          );
      await petController.addPetTag(
        petId: lylaId,
        recordKind: PetRecordKind.expense,
        recordId: expenseId,
      );

      // Sync creation + tag to Ancy's device -> both devices have 1 tag for the expense.
      await syncRelayToAncy();
      expect(
        await sabaDb.getPetTagsForRecord(PetRecordKind.expense, expenseId),
        hasLength(1),
      );
      expect(
        await ancyDb.getPetTagsForRecord(PetRecordKind.expense, expenseId),
        hasLength(1),
      );

      final pendingDelete = sabaContainer.read(pendingDeleteServiceProvider);

      // 1. Saba deletes the expense and undoes during the window -> tags stay on both devices.
      await pendingDelete.scheduleDelete(
        kind: PendingDeleteKind.expense,
        id: expenseId,
        duration: const Duration(hours: 1),
      );
      await pendingDelete.undoDelete(
        kind: PendingDeleteKind.expense,
        id: expenseId,
      );
      await syncRelayToAncy();
      expect(
        await sabaDb.getPetTagsForRecord(PetRecordKind.expense, expenseId),
        hasLength(1),
      );
      expect(
        await ancyDb.getPetTagsForRecord(PetRecordKind.expense, expenseId),
        hasLength(1),
      );

      // 2. Saba deletes the expense and lets the window commit -> after sync,
      // zero tags for it on Saba's device AND zero tags on Ancy's device too.
      await pendingDelete.scheduleDelete(
        kind: PendingDeleteKind.expense,
        id: expenseId,
        duration: const Duration(milliseconds: 10),
      );
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await syncRelayToAncy();

      expect(
        await sabaDb.getPetTagsForRecord(PetRecordKind.expense, expenseId),
        isEmpty,
      );
      expect(
        await ancyDb.getPetTagsForRecord(PetRecordKind.expense, expenseId),
        isEmpty,
      );
    },
  );

  test(
    'Every record-delete event in applyEventInTransaction deletes that record\'s pet tags in the same transaction',
    () async {
      final (db, store) = await createTestDb();
      addTearDown(db.close);

      final now = DateTime.utc(2026, 4, 20, 12, 0);
      await store.applyEvent(
        eventId: 'evt_pet_1',
        homeId: homeId,
        eventType: 'pet_created',
        payload: {
          'id': 'pet_lyla',
          'home_id': homeId,
          'name': 'Lyla',
          'created_by': alex.id,
          'created_at': now.toIso8601String(),
        },
        timestamp: now,
        authorId: alex.id,
      );

      const cases = <(String, String, String)>[
        (PetRecordKind.expense, 'exp_del_1', 'expense_deleted'),
        (PetRecordKind.task, 'task_del_1', 'list_item_deleted'),
        (PetRecordKind.habit, 'habit_del_1', 'habit_deleted'),
        (PetRecordKind.event, 'event_del_1', 'calendar_event_deleted'),
        (PetRecordKind.commitment, 'sub_del_1', 'subscription_deleted'),
        (PetRecordKind.routineEvent, 'rev_del_1', 'routine_event_deleted'),
      ];

      var seq = 0;
      for (final (recordKind, recordId, deleteEventType) in cases) {
        await store.applyEvent(
          eventId: 'evt_tag_${++seq}',
          homeId: homeId,
          eventType: 'pet_tag_added',
          payload: {
            'id': 'tag_$recordId',
            'home_id': homeId,
            'pet_id': 'pet_lyla',
            'record_kind': recordKind,
            'record_id': recordId,
            'created_by': alex.id,
            'created_at': now.toIso8601String(),
          },
          timestamp: now,
          authorId: alex.id,
        );
        expect(
          await db.getPetTagsForRecord(recordKind, recordId),
          hasLength(1),
        );

        await store.applyEvent(
          eventId: 'evt_del_${++seq}',
          homeId: homeId,
          eventType: deleteEventType,
          payload: {
            'id': recordId,
            'home_id': homeId,
          },
          timestamp: now.add(const Duration(seconds: 1)),
          authorId: alex.id,
        );
        expect(
          await db.getPetTagsForRecord(recordKind, recordId),
          isEmpty,
          reason: '$deleteEventType should remove pet tags for $recordKind',
        );
      }
    },
  );

  test(
    'First-launch v12 safety net replays pet_* events even if already marked in local_applied_events by v11',
    () async {
      final (db, store) = await createTestDb();
      addTearDown(db.close);

      // Simulate a v11 install that had already recorded pet_created and
      // pet_tag_added event IDs in local_applied_events without projecting them.
      await db.into(db.localAppliedEvents).insert(
            LocalAppliedEventsCompanion.insert(
              id: 'evt_v11_pet_created',
              appliedAt: DateTime.utc(2026, 4, 10, 10, 0),
            ),
          );
      await db.into(db.localAppliedEvents).insert(
            LocalAppliedEventsCompanion.insert(
              id: 'evt_v11_pet_tag_added',
              appliedAt: DateTime.utc(2026, 4, 10, 10, 1),
            ),
          );

      expect(await db.getPets(homeId), isEmpty);
      expect(await db.getPetTags(homeId), isEmpty);

      final crypto = SodiumCryptoService();
      final homeKey = Uint8List.fromList(List<int>.filled(32, 7));
      final keyStore = _InMemoryHomeKeyStore();
      await keyStore.saveKey(homeId, homeKey);

      final encryptedCreated = await crypto.encrypt(
        plaintextJson: jsonEncode({
          'id': 'pet_lyla',
          'home_id': homeId,
          'name': 'Lyla',
          'created_by': 'user_sam',
          'created_at': '2026-04-10T10:00:00.000Z',
        }),
        homeKey: homeKey,
      );
      final encryptedTagAdded = await crypto.encrypt(
        plaintextJson: jsonEncode({
          'id': 'tag_1',
          'home_id': homeId,
          'pet_id': 'pet_lyla',
          'record_kind': 'expense',
          'record_id': 'exp_1',
          'created_by': 'user_sam',
          'created_at': '2026-04-10T10:01:00.000Z',
        }),
        homeKey: homeKey,
      );

      final engine = SyncEngineImpl(
        eventStore: EventStoreImpl(db: db),
        localStateStore: store,
        encryptionService: crypto,
        keyStore: keyStore,
        getActiveHomeId: () => homeId,
        getCurrentUserId: () => alex.id,
        fetchRemotePetEvents: (targetHomeId) async {
          return [
            {
              'id': 'evt_v11_pet_created',
              'home_id': targetHomeId,
              'actor_id': 'user_sam',
              'event_type': 'pet_created',
              'encrypted_payload':
                  crypto.serializeToTransportString(encryptedCreated),
              'created_at': '2026-04-10T10:00:00.000Z',
            },
            {
              'id': 'evt_v11_pet_tag_added',
              'home_id': targetHomeId,
              'actor_id': 'user_sam',
              'event_type': 'pet_tag_added',
              'encrypted_payload':
                  crypto.serializeToTransportString(encryptedTagAdded),
              'created_at': '2026-04-10T10:01:00.000Z',
            },
          ];
        },
      );

      final applied = await engine.reconcileUnprojectedPetEvents(
        homeId: homeId,
      );
      expect(applied, 2);

      final pets = await db.getPets(homeId);
      expect(pets, hasLength(1));
      expect(pets.single.id, 'pet_lyla');
      expect(pets.single.name, 'Lyla');

      final tags = await db.getPetTags(homeId);
      expect(tags, hasLength(1));
      expect(tags.single.petId, 'pet_lyla');
      expect(tags.single.recordKind, 'expense');
      expect(tags.single.recordId, 'exp_1');

      // Running reconcile a second time is a no-op because SharedPreferences
      // recorded completion for this home.
      final secondRun = await engine.reconcileUnprojectedPetEvents(
        homeId: homeId,
      );
      expect(secondRun, 0);
    },
  );
}
