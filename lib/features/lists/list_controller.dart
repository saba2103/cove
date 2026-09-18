import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/uuid_generator.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';

class ListController {
  final Ref ref;

  ListController(this.ref);

  AppDatabase get _db => ref.read(appDatabaseProvider);
  String? get _activeHomeId => ref.read(activeHomeIdProvider);
  CoveUser? get _currentUser => ref.read(authProvider).value;

  /// Ensures that default lists (Grocery, Travel, Planning) exist for the home
  /// and that all active lists are synced to the partner.
  Future<void> ensureDefaultLists() async {
    final homeId = _activeHomeId;
    if (homeId == null) return;
    final userId = _currentUser?.id ?? 'local_user';
    await _db.ensureDefaultLists(homeId, userId);
    await syncActiveLists();
  }

  /// Ensures every active list in localLists is synced to Supabase
  /// so both partners always see the exact same lists.
  Future<void> syncActiveLists() async {
    final homeId = _activeHomeId;
    if (homeId == null) return;

    final activeLists = await (_db.select(_db.localLists)
          ..where((t) => t.homeId.equals(homeId) & t.isArchived.equals(false)))
        .get();

    final emit = ref.read(coveEmitActionProvider);

    for (final list in activeLists) {
      if (await _db.isTombstoned(list.id)) continue;

      final alreadyDispatched = await (_db.select(_db.localOutboxEvents)
            ..where((t) =>
                t.homeId.equals(homeId) &
                t.eventType.equals('list_created') &
                t.payloadJson.like('%"${list.id}"%')))
          .get();

      if (alreadyDispatched.isEmpty) {
        await emit(
          eventType: 'list_created',
          payload: {
            'id': list.id,
            'home_id': homeId,
            'name': list.name,
          },
        );
      }
    }
  }

  /// Creates a custom list and emits `list_created`.
  Future<String> createList({required String name}) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');
    final id = _generateUuid();

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'list_created',
      payload: {
        'id': id,
        'home_id': homeId,
        'name': name.trim(),
      },
    );
    return id;
  }

  /// Archives a list and emits `list_archived`.
  Future<void> archiveList({required String listId}) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'list_archived',
      payload: {
        'id': listId,
        'home_id': homeId,
      },
    );
  }

  /// Adds an item to a list and emits `list_item_added`.
  Future<String> addItem({
    required String listId,
    required String title,
    String? notes,
    String? listName,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');
    final id = _generateUuid();

    String? resolvedListName = listName;
    if (resolvedListName == null) {
      final list = await (_db.select(_db.localLists)..where((t) => t.id.equals(listId))).getSingleOrNull();
      resolvedListName = list?.name;
    }

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'list_item_added',
      payload: {
        'id': id,
        'home_id': homeId,
        'list_id': listId,
        'list_name': ?resolvedListName,
        'title': title.trim(),
        'notes': notes?.trim(),
      },
    );
    return id;
  }

  /// Checks or unchecks an item and emits `list_item_toggled`.
  Future<void> toggleItem({
    required String itemId,
    required bool isCompleted,
    String? itemTitle,
    String? listName,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    String? resolvedTitle = itemTitle;
    String? resolvedListName = listName;
    String? resolvedListId;
    if (resolvedTitle == null || resolvedListName == null) {
      final item = await (_db.select(_db.localListItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
      resolvedTitle ??= item?.title;
      resolvedListId = item?.listId;
      if (resolvedListId != null) {
        final list = await (_db.select(_db.localLists)..where((t) => t.id.equals(resolvedListId!))).getSingleOrNull();
        resolvedListName ??= list?.name;
      }
    }

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'list_item_toggled',
      payload: {
        'id': itemId,
        'home_id': homeId,
        'is_completed': isCompleted,
        'title': ?resolvedTitle,
        'list_id': ?resolvedListId,
        'list_name': ?resolvedListName,
      },
    );
  }

  /// Deletes a specific item and emits `list_item_deleted`.
  Future<void> deleteItem({
    required String itemId,
    String? itemTitle,
    String? listName,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    String? resolvedTitle = itemTitle;
    String? resolvedListName = listName;
    String? resolvedListId;
    if (resolvedTitle == null || resolvedListName == null) {
      final item = await (_db.select(_db.localListItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
      resolvedTitle ??= item?.title;
      resolvedListId = item?.listId;
      if (resolvedListId != null) {
        final list = await (_db.select(_db.localLists)..where((t) => t.id.equals(resolvedListId!))).getSingleOrNull();
        resolvedListName ??= list?.name;
      }
    }

    // 1. Immediately record tombstone and delete from SQLite
    await _db.recordTombstone(itemId, 'list_item');
    await (_db.delete(_db.localListItems)..where((t) => t.id.equals(itemId))).go();

    // 2. Emit list_item_deleted
    try {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'list_item_deleted',
        payload: {
          'id': itemId,
          'home_id': homeId,
          'title': ?resolvedTitle,
          'list_id': ?resolvedListId,
          'list_name': ?resolvedListName,
        },
      );
    } catch (_) {}
  }

  /// Renames a list and emits `list_renamed`.
  Future<void> renameList({required String listId, required String newName}) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'list_renamed',
      payload: {
        'id': listId,
        'home_id': homeId,
        'name': newName.trim(),
      },
    );
  }

  /// Deletes a list and all its items, emitting `list_deleted`.
  Future<void> deleteList({required String listId}) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final list = await (_db.select(_db.localLists)..where((t) => t.id.equals(listId))).getSingleOrNull();

    // 1. Immediately record tombstones for the list and default variations
    await _db.recordTombstone(listId, 'list');
    if (list != null) {
      final normName = list.name.trim().toLowerCase();
      await _db.recordTombstone('default_${normName}_$homeId', 'list');
      await _db.recordTombstone('default_name_${normName}_$homeId', 'list');
    }

    // Tombstone all items belonging to this list
    final items = await (_db.select(_db.localListItems)..where((t) => t.listId.equals(listId))).get();
    for (final item in items) {
      await _db.recordTombstone(item.id, 'list_item');
    }

    // 2. Immediately delete locally from SQLite
    await (_db.delete(_db.localListItems)..where((t) => t.listId.equals(listId))).go();
    await (_db.delete(_db.localLists)..where((t) => t.id.equals(listId))).go();

    // 3. Clean up tab order in secure storage
    try {
      final storage = ref.read(homeKeyStoreProvider).storage;
      final rawOrder = await storage.read(key: 'cove_lists_tab_order_$homeId');
      if (rawOrder != null && rawOrder.contains(listId)) {
        final updated = rawOrder.split(',').where((id) => id.isNotEmpty && id != listId).join(',');
        await storage.write(key: 'cove_lists_tab_order_$homeId', value: updated);
      }
    } catch (_) {}

    // 4. Emit list_deleted
    try {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'list_deleted',
        payload: {
          'id': listId,
          'home_id': homeId,
        },
      );
    } catch (_) {}
  }

  /// Updates an item's title or notes and emits `list_item_updated`.
  Future<void> updateItem({
    required String itemId,
    required String title,
    String? notes,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'list_item_updated',
      payload: {
        'id': itemId,
        'home_id': homeId,
        'title': title.trim(),
        'notes': notes?.trim(),
      },
    );
  }

  /// Clears all completed items from a list and emits `list_completed_cleared`.
  Future<void> clearCompleted({required String listId}) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    // 1. Immediately record tombstones for completed items
    final completedItems = await (_db.select(_db.localListItems)
          ..where((t) => t.homeId.equals(homeId) & t.listId.equals(listId) & t.isCompleted.equals(true)))
        .get();
    for (final item in completedItems) {
      await _db.recordTombstone(item.id, 'list_item');
    }

    // 2. Immediately delete locally
    await _db.clearCompletedListItems(homeId, listId);

    // 3. Emit list_completed_cleared
    try {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'list_completed_cleared',
        payload: {
          'home_id': homeId,
          'list_id': listId,
        },
      );
    } catch (_) {}
  }

  String _generateUuid() => generateCoveUuid();
}

final listControllerProvider = Provider<ListController>((ref) {
  return ListController(ref);
});
