import 'dart:async';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/core/widgets/cove_checkbox.dart';
import 'package:cove/core/widgets/cove_pill_button.dart';
import 'package:cove/core/widgets/cove_pill_input.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/lists/create_list_dialog.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/lists/lists_screen.dart';
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
      authorId: 'user_alex',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeSecureStorage fakeStorage;
  late HomeKeyStore keyStore;
  late SodiumCryptoService crypto;
  late FakeTrackingSyncEngine fakeEngine;

  const testUser = CoveUser(
    id: 'user_alex',
    email: 'alex@cove.test',
    displayName: 'Alex',
  );

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fakeStorage = FakeSecureStorage();
    keyStore = HomeKeyStore(storage: fakeStorage);
    crypto = SodiumCryptoService();
    final localStore = LocalStateStoreImpl(db);
    final eventStore = EventStoreImpl(db: db, cryptoService: crypto);
    fakeEngine = FakeTrackingSyncEngine(
      eventStore: eventStore,
      localStateStore: localStore,
      encryptionService: crypto,
      keyStore: keyStore,
    );

    // Seed active home
    await db.into(db.localHomes).insert(
          LocalHomesCompanion.insert(
            id: 'home_1',
            name: 'Our Home',
            createdAt: DateTime.now(),
            createdBy: 'user_alex',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  List<Override> createOverrides({
    CoveUser? user,
    ValueNotifier<List<LocalList>>? listsNotifier,
    Map<String, ValueNotifier<List<LocalListItem>>>? itemsNotifiers,
  }) {
    final effectiveListsNotifier = listsNotifier ?? ValueNotifier<List<LocalList>>([]);
    final effectiveItemsNotifiers = itemsNotifiers ?? <String, ValueNotifier<List<LocalListItem>>>{};

    Future<void> reload() async {
      final lists = await db.getLists('home_1');
      effectiveListsNotifier.value = lists;
      for (final list in lists) {
        final items = await db.getListItems('home_1', list.id);
        if (!effectiveItemsNotifiers.containsKey(list.id)) {
          effectiveItemsNotifiers[list.id] = ValueNotifier(items);
        } else {
          effectiveItemsNotifiers[list.id]!.value = items;
        }
      }
    }

    // Initial load
    db.getLists('home_1').then((lists) async {
      effectiveListsNotifier.value = lists;
      for (final list in lists) {
        final items = await db.getListItems('home_1', list.id);
        if (!effectiveItemsNotifiers.containsKey(list.id)) {
          effectiveItemsNotifiers[list.id] = ValueNotifier(items);
        } else {
          effectiveItemsNotifiers[list.id]!.value = items;
        }
      }
    });

    return [
      appDatabaseProvider.overrideWithValue(db),
      homeKeyStoreProvider.overrideWithValue(keyStore),
      sodiumCryptoServiceProvider.overrideWithValue(crypto),
      syncEngineProvider.overrideWithValue(fakeEngine),
      authProvider.overrideWith(() => FakeAuthNotifier(AsyncData(user ?? testUser))),
      activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_1')),
      activeHomeProvider.overrideWith((ref) => Stream.value(
        LocalHome(id: 'home_1', name: 'Our Home', createdAt: DateTime.now(), createdBy: 'user_alex', currency: 'USD'),
      )),
      partnerProfileProvider.overrideWith(() => FakePartnerProfileNotifier()),
      coveEmitActionProvider.overrideWithValue(
        ({required String eventType, required Map<String, dynamic> payload, String? targetHomeId}) async {
          await fakeEngine.dispatchLocalEvent(
            eventType: eventType,
            payload: payload,
            homeId: targetHomeId ?? 'home_1',
          );
          await reload();
        },
      ),
      listControllerProvider.overrideWith((ref) => _TestListController(ref, onMutate: reload)),
      activeHomeListsProvider.overrideWith((ref) {
        final controller = StreamController<List<LocalList>>();
        controller.add(effectiveListsNotifier.value);
        void listener() {
          if (!controller.isClosed) {
            controller.add(effectiveListsNotifier.value);
          }
        }
        effectiveListsNotifier.addListener(listener);
        ref.onDispose(() {
          effectiveListsNotifier.removeListener(listener);
          controller.close();
        });
        return controller.stream;
      }),
      activeHomeListItemsProvider.overrideWith((ref, listId) {
        if (!effectiveItemsNotifiers.containsKey(listId)) {
          effectiveItemsNotifiers[listId] = ValueNotifier([]);
          db.getListItems('home_1', listId).then((items) {
            effectiveItemsNotifiers[listId]!.value = items;
          });
        }
        final notifier = effectiveItemsNotifiers[listId]!;
        final controller = StreamController<List<LocalListItem>>();
        controller.add(notifier.value);
        void listener() {
          if (!controller.isClosed) {
            controller.add(notifier.value);
          }
        }
        notifier.addListener(listener);
        ref.onDispose(() {
          notifier.removeListener(listener);
          controller.close();
        });
        return controller.stream;
      }),
      activeHomeOutboxProvider.overrideWith((ref) => Stream.value([])),
    ];
  }

  group('Shared Lists Feature Tests', () {
    testWidgets('Ensure default lists (Grocery, Travel, Planning) are created', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ListsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final lists = await db.getLists('home_1');
      expect(lists.length, equals(3));
      expect(lists.map((l) => l.name), containsAll(['Grocery', 'Travel', 'Planning']));

      // Tab row displays the default lists
      expect(find.text('Grocery'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Planning'), findsOneWidget);
    });

    testWidgets('Add custom list via dialog emits list_created', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ListsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap + button in tab row
      final addListBtn = find.byTooltip('Add new list');
      expect(addListBtn, findsOneWidget);
      await tester.tap(addListBtn);
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.byType(CreateListDialog), findsOneWidget);
      expect(find.text('NEW SHARED LIST'), findsOneWidget);

      // Enter list name and submit
      final textField = find.descendant(
        of: find.byType(CreateListDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(textField, 'Weekend Hardware');
      await tester.pump();

      final createBtn = find.widgetWithText(CovePillButton, 'Create List');
      expect(createBtn, findsOneWidget);
      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Verify sync event emitted
      expect(
        fakeEngine.dispatchedEvents.any((e) =>
            e['eventType'] == 'list_created' &&
            (e['payload'] as Map)['name'] == 'Weekend Hardware'),
        isTrue,
      );

      // Verify list saved in DB
      final lists = await db.getLists('home_1');
      expect(lists.any((l) => l.name == 'Weekend Hardware'), isTrue);
    });

    testWidgets('Adding an item via pinned pill input emits list_item_added and updates list',
        (tester) async {
      // Seed default lists first
      await db.ensureDefaultLists('home_1', 'user_alex');

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ListsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter item title in pill input
      final pillInput = find.byType(CovePillInput);
      expect(pillInput, findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Organic Oat Milk');
      await tester.pump();

      // Tap arrow upward suffix button
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // 1. Verify sync event emitted
      expect(
        fakeEngine.dispatchedEvents.any((e) =>
            e['eventType'] == 'list_item_added' &&
            (e['payload'] as Map)['title'] == 'Organic Oat Milk'),
        isTrue,
      );

      // 2. Verify item appears with neutral attribution
      expect(find.text('Organic Oat Milk'), findsOneWidget);
      expect(find.text('Added by You'), findsOneWidget);
      expect(find.byType(CoveSyncTick), findsOneWidget);
    });

    testWidgets('Toggling item emits list_item_toggled and updates to completed with strikethrough',
        (tester) async {
      await db.ensureDefaultLists('home_1', 'user_alex');
      final lists = await db.getLists('home_1');
      final groceryList = lists.firstWhere((l) => l.name == 'Grocery');

      // Seed item
      await db.into(db.localListItems).insert(
            LocalListItemsCompanion.insert(
              id: 'item_1',
              homeId: 'home_1',
              listId: groceryList.id,
              title: 'Sourdough Bread',
              isCompleted: const Value(false),
              createdAt: DateTime.now(),
              createdBy: 'user_alex',
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ListsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sourdough Bread'), findsOneWidget);
      expect(find.text('Added by You'), findsOneWidget);

      // Tap the row or checkbox
      await tester.tap(find.byType(CoveCheckbox).first);
      await tester.pumpAndSettle();

      // 1. Verify sync event emitted
      expect(
        fakeEngine.dispatchedEvents.any((e) =>
            e['eventType'] == 'list_item_toggled' &&
            (e['payload'] as Map)['id'] == 'item_1' &&
            (e['payload'] as Map)['is_completed'] == true),
        isTrue,
      );

      // 2. Verify completion tag
      expect(find.text('Completed by You'), findsOneWidget);
      expect(find.text('0 remaining • 1 completed'), findsOneWidget);
    });

    testWidgets('Clear completed removes all completed items from list', (tester) async {
      await db.ensureDefaultLists('home_1', 'user_alex');
      final lists = await db.getLists('home_1');
      final groceryList = lists.firstWhere((l) => l.name == 'Grocery');

      // Seed 1 active and 2 completed items
      await db.into(db.localListItems).insert(
            LocalListItemsCompanion.insert(
              id: 'item_active',
              homeId: 'home_1',
              listId: groceryList.id,
              title: 'Avocados',
              isCompleted: const Value(false),
              createdAt: DateTime.now(),
              createdBy: 'user_alex',
            ),
          );
      await db.into(db.localListItems).insert(
            LocalListItemsCompanion.insert(
              id: 'item_done_1',
              homeId: 'home_1',
              listId: groceryList.id,
              title: 'Butter',
              isCompleted: const Value(true),
              createdAt: DateTime.now(),
              createdBy: 'user_alex',
            ),
          );
      await db.into(db.localListItems).insert(
            LocalListItemsCompanion.insert(
              id: 'item_done_2',
              homeId: 'home_1',
              listId: groceryList.id,
              title: 'Eggs',
              isCompleted: const Value(true),
              createdAt: DateTime.now(),
              createdBy: 'user_alex',
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ListsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Clear completed'), findsOneWidget);
      expect(find.text('1 remaining • 2 completed'), findsOneWidget);

      // Tap Clear completed
      await tester.tap(find.text('Clear completed'));
      await tester.pumpAndSettle();

      // Confirm in dialog
      expect(find.text('Clear completed items?'), findsOneWidget);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // Verify sync event emitted
      expect(
        fakeEngine.dispatchedEvents.any((e) =>
            e['eventType'] == 'list_completed_cleared' &&
            (e['payload'] as Map)['list_id'] == groceryList.id),
        isTrue,
      );

      // Completed items gone, active item remains
      expect(find.text('Avocados'), findsOneWidget);
      expect(find.text('Butter'), findsNothing);
      expect(find.text('Eggs'), findsNothing);
    });

    testWidgets('NEUTRAL OWNERSHIP: Partner added items display "Added by Partner" without assignment fields',
        (tester) async {
      await db.ensureDefaultLists('home_1', 'user_alex');
      final lists = await db.getLists('home_1');
      final groceryList = lists.firstWhere((l) => l.name == 'Grocery');

      // Seed item added by partner Sarah
      await db.into(db.localListItems).insert(
            LocalListItemsCompanion.insert(
              id: 'item_sarah',
              homeId: 'home_1',
              listId: groceryList.id,
              title: 'Almond Flour',
              isCompleted: const Value(false),
              createdAt: DateTime.now(),
              createdBy: 'user_sarah',
            ),
          );

      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ListsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Alex is viewing
      expect(find.text('Almond Flour'), findsOneWidget);
      expect(find.text('Added by Sarah'), findsOneWidget);

      // Strictly NO assignment fields anywhere in the tree
      expect(find.textContaining('Assign'), findsNothing);
      expect(find.textContaining('Assigned to'), findsNothing);
    });

    testWidgets('Long press and reorder tabs (lists) in lists page', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: createOverrides(),
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const ListsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify default tabs exist: Grocery, Travel, Planning
      expect(find.text('Grocery'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
      expect(find.text('Planning'), findsOneWidget);

      final groceryTab = find.text('Grocery');
      final travelTab = find.text('Travel');

      // Verify Grocery is to the left of Travel initially
      expect(tester.getCenter(groceryTab).dx, lessThan(tester.getCenter(travelTab).dx));

      final planningTab = find.text('Planning');

      // Long press Grocery to initiate drag, then move past Travel towards Planning
      final gesture = await tester.startGesture(tester.getCenter(groceryTab));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveTo(tester.getCenter(planningTab) + const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify tabs have been reordered: Travel is now before Grocery!
      final groceryAfter = find.text('Grocery');
      final travelAfter = find.text('Travel');
      expect(tester.getCenter(travelAfter).dx, lessThan(tester.getCenter(groceryAfter).dx));

      // Verify lists_reordered sync event was dispatched
      expect(
        fakeEngine.dispatchedEvents.any((e) => e['eventType'] == 'lists_reordered'),
        isTrue,
      );
    });
  });
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

class _TestListController extends ListController {
  final Future<void> Function() onMutate;

  _TestListController(super.ref, {required this.onMutate});

  @override
  Future<void> ensureDefaultLists() async {
    await super.ensureDefaultLists();
    await onMutate();
  }

  @override
  Future<String> createList({required String name}) async {
    final res = await super.createList(name: name);
    await onMutate();
    return res;
  }

  @override
  Future<String> addItem({
    required String listId,
    required String title,
    String? notes,
    String? listName,
  }) async {
    final res = await super.addItem(listId: listId, title: title, notes: notes, listName: listName);
    await onMutate();
    return res;
  }

  @override
  Future<void> toggleItem({
    required String itemId,
    required bool isCompleted,
    String? itemTitle,
    String? listName,
  }) async {
    await super.toggleItem(itemId: itemId, isCompleted: isCompleted, itemTitle: itemTitle, listName: listName);
    await onMutate();
  }

  @override
  Future<void> deleteItem({
    required String itemId,
    String? itemTitle,
    String? listName,
  }) async {
    await super.deleteItem(itemId: itemId, itemTitle: itemTitle, listName: listName);
    await onMutate();
  }

  @override
  Future<void> clearCompleted({required String listId}) async {
    await super.clearCompleted(listId: listId);
    await onMutate();
  }
}

class FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() {
    return const PartnerProfileState(displayName: 'Sarah');
  }
}
