import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/utils/uuid_generator.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';

final activeHomeRoadmapProvider = StreamProvider<List<LocalRoadmapItem>>((ref) {
  final homeId = ref.watch(activeHomeIdProvider);
  if (homeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchRoadmapItems(homeId);
});

class RoadmapCustomOrderNotifier extends Notifier<Map<String, List<String>>> {
  @override
  Map<String, List<String>> build() => {};

  void setOrder(String homeId, List<String> order) {
    state = {...state, homeId: order};
  }
}

final roadmapCustomOrderProvider =
    NotifierProvider<RoadmapCustomOrderNotifier, Map<String, List<String>>>(
  RoadmapCustomOrderNotifier.new,
);

class RoadmapController {
  final Ref ref;

  RoadmapController(this.ref);

  String? get _activeHomeId => ref.read(activeHomeIdProvider);
  CoveUser? get _currentUser => ref.read(authProvider).value;

  String _generateUuid() => generateCoveUuid();

  Future<void> loadCustomOrder(String homeId) async {
    const storage = FlutterSecureStorage();
    final raw = await storage.read(key: 'cove_roadmap_order_$homeId');
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final list = decoded.map((e) => e.toString()).toList();
          ref.read(roadmapCustomOrderProvider.notifier).setOrder(homeId, list);
        }
      } catch (_) {}
    }
  }

  Future<String> createItem({
    required String title,
    String? description,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final user = _currentUser;
    final userId = user?.id ?? 'local_user';
    final id = _generateUuid();

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'roadmap_item_added',
      payload: {
        'id': id,
        'home_id': homeId,
        'title': title.trim(),
        'description': description?.trim(),
        'is_completed': false,
        'created_by': userId,
      },
    );

    return id;
  }

  Future<void> updateItem({
    required String id,
    required String title,
    String? description,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'roadmap_item_updated',
      payload: {
        'id': id,
        'home_id': homeId,
        'title': title.trim(),
        'description': description?.trim(),
      },
    );
  }

  Future<void> reorderItems({required List<String> orderedIds}) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    // Save locally to secure storage
    const storage = FlutterSecureStorage();
    await storage.write(
      key: 'cove_roadmap_order_$homeId',
      value: jsonEncode(orderedIds),
    );

    // Update in-memory state
    ref.read(roadmapCustomOrderProvider.notifier).setOrder(homeId, orderedIds);

    // Emit sync event to partner
    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'roadmap_items_reordered',
      payload: {
        'home_id': homeId,
        'order': orderedIds,
      },
    );
  }

  Future<void> toggleItem({
    required String id,
    required bool isCompleted,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'roadmap_item_toggled',
      payload: {
        'id': id,
        'home_id': homeId,
        'is_completed': isCompleted,
        'completed_at': isCompleted ? DateTime.now().toIso8601String() : null,
      },
    );
  }

  Future<void> deleteItem(String id) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final emitAction = ref.read(coveEmitActionProvider);
    await emitAction(
      eventType: 'roadmap_item_deleted',
      payload: {
        'id': id,
        'home_id': homeId,
      },
    );
  }
}

final roadmapControllerProvider = Provider<RoadmapController>((ref) {
  return RoadmapController(ref);
});
