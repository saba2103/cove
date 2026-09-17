import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../sync/providers/active_home_provider.dart';
import 'activity_controller.dart';
import 'activity_models.dart';
import '../notifications/notification_controller.dart';

class ActivityReadState {
  final DateTime? lastReadTimestamp;
  final Set<String> readEventIds;

  const ActivityReadState({
    this.lastReadTimestamp,
    this.readEventIds = const {},
  });

  bool isRead(FormattedActivityItem item) {
    // Current user's own actions are naturally already read/known
    if (item.isLocalActor) return true;
    if (readEventIds.contains(item.id)) return true;
    if (lastReadTimestamp != null &&
        (item.timestamp.isBefore(lastReadTimestamp!) ||
            item.timestamp.isAtSameMomentAs(lastReadTimestamp!))) {
      return true;
    }
    return false;
  }

  ActivityReadState copyWith({
    DateTime? lastReadTimestamp,
    Set<String>? readEventIds,
  }) {
    return ActivityReadState(
      lastReadTimestamp: lastReadTimestamp ?? this.lastReadTimestamp,
      readEventIds: readEventIds ?? this.readEventIds,
    );
  }
}

class ActivityReadNotifier extends Notifier<ActivityReadState> {
  static const _storage = FlutterSecureStorage();
  static const _lastReadPrefix = 'cove_act_last_read_';
  static const _readIdsPrefix = 'cove_act_read_ids_';

  @override
  ActivityReadState build() {
    final homeId = ref.watch(activeHomeIdProvider) ?? 'default';
    _loadState(homeId);
    return const ActivityReadState();
  }

  Future<void> _loadState(String homeId) async {
    try {
      final tsStr = await _storage.read(key: '$_lastReadPrefix$homeId');
      final idsStr = await _storage.read(key: '$_readIdsPrefix$homeId');

      DateTime? lastRead;
      if (tsStr != null && tsStr.isNotEmpty) {
        lastRead = DateTime.tryParse(tsStr);
      }

      Set<String> readIds = {};
      if (idsStr != null && idsStr.isNotEmpty) {
        final decoded = jsonDecode(idsStr);
        if (decoded is List) {
          readIds = decoded.map((e) => e.toString()).toSet();
        }
      }

      state = ActivityReadState(
        lastReadTimestamp: lastRead,
        readEventIds: readIds,
      );
    } catch (_) {}
  }

  Future<void> markAsRead(String eventId) async {
    if (state.readEventIds.contains(eventId)) return;
    final homeId = ref.read(activeHomeIdProvider) ?? 'default';
    final updatedIds = {...state.readEventIds, eventId};
    state = state.copyWith(readEventIds: updatedIds);

    try {
      await _storage.write(
        key: '$_readIdsPrefix$homeId',
        value: jsonEncode(updatedIds.toList()),
      );
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final homeId = ref.read(activeHomeIdProvider) ?? 'default';
    final now = DateTime.now().toUtc();
    state = ActivityReadState(
      lastReadTimestamp: now,
      readEventIds: const {},
    );

    // Clear system notification shade
    try {
      ref.read(notificationServiceProvider).cancelAllNotifications();
    } catch (_) {}

    try {
      await _storage.write(
        key: '$_lastReadPrefix$homeId',
        value: now.toIso8601String(),
      );
      await _storage.delete(key: '$_readIdsPrefix$homeId');
    } catch (_) {}
  }
}

final activityReadStatusProvider =
    NotifierProvider<ActivityReadNotifier, ActivityReadState>(
        ActivityReadNotifier.new);

/// Computed unread count for notifications badge in AppShell header.
final unreadActivityCountProvider = Provider<int>((ref) {
  final readState = ref.watch(activityReadStatusProvider);
  final feedAsync = ref.watch(activityFeedProvider);
  final activities = feedAsync.value ?? [];

  int count = 0;
  for (final item in activities) {
    if (!readState.isRead(item)) {
      count++;
    }
  }
  return count;
});
