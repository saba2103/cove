import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  /// Ensures that default lists (Grocery, Travel, Planning) exist for the home.
  Future<void> ensureDefaultLists() async {
    final homeId = _activeHomeId;
    if (homeId == null) return;
    final userId = _currentUser?.id ?? 'local_user';
    await _db.ensureDefaultLists(homeId, userId);
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
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');
    final id = _generateUuid();

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'list_item_added',
      payload: {
        'id': id,
        'home_id': homeId,
        'list_id': listId,
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
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'list_item_toggled',
      payload: {
        'id': itemId,
        'home_id': homeId,
        'is_completed': isCompleted,
      },
    );
  }

  /// Deletes a specific item and emits `list_item_deleted`.
  Future<void> deleteItem({required String itemId}) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'list_item_deleted',
      payload: {
        'id': itemId,
        'home_id': homeId,
      },
    );
  }

  /// Clears all completed items from a list and emits `list_completed_cleared`.
  Future<void> clearCompleted({required String listId}) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'list_completed_cleared',
      payload: {
        'home_id': homeId,
        'list_id': listId,
      },
    );
  }

  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = (random.hashCode & 0x7FFFFFFF).toRadixString(16).padLeft(8, '0');
    final p1 = (DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    return '$p1-$hash-4000-8000-${DateTime.now().microsecond.toRadixString(16).padLeft(12, '0')}';
  }
}

final listControllerProvider = Provider<ListController>((ref) {
  return ListController(ref);
});
