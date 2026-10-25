import 'dart:async';
import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme/cove_tokens.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../notifications/notification_models.dart';
import '../notifications/notification_pipeline.dart';
import 'reminder_models.dart';

class ReminderNotifier extends Notifier<List<CheckinReminder>> {
  static const _storage = FlutterSecureStorage();
  static const _legacyStorageKey = 'cove_checkin_reminders_v1';
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription? _dbSubscription;

  @override
  List<CheckinReminder> build() {
    _dbSubscription?.cancel();
    ref.onDispose(() => _dbSubscription?.cancel());

    final homeId = ref.watch(activeHomeIdProvider);
    if (homeId != null && homeId.isNotEmpty) {
      final db = ref.watch(appDatabaseProvider);
      _dbSubscription = db.watchCheckinReminders(homeId).listen((locals) {
        if (!ref.mounted) return;
        if (locals.isNotEmpty) {
          state = locals.map(CheckinReminder.fromLocal).toList();
        } else {
          _ensureInitialReminders(homeId);
        }
      });
    }

    return const [];
  }

  Future<void> _ensureInitialReminders(String homeId) async {
    if (!ref.mounted) return;
    final db = ref.read(appDatabaseProvider);
    final existing = await db.getCheckinReminders(homeId);
    if (!ref.mounted) return;
    if (existing.isNotEmpty) {
      state = existing.map(CheckinReminder.fromLocal).toList();
      return;
    }

    // 1. Check legacy storage for migration
    try {
      final raw = await _storage.read(key: _legacyStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map((item) => CheckinReminder.fromMap(item as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          for (final rem in list) {
            await db.into(db.localCheckinReminders).insertOnConflictUpdate(
              LocalCheckinRemindersCompanion.insert(
                id: rem.id,
                homeId: homeId,
                hour: rem.hour,
                minute: rem.minute,
                message: rem.message,
                isEnabled: drift.Value(rem.isEnabled),
                createdAt: rem.createdAt,
              ),
            );
          }
          if (!ref.mounted) return;
          state = list;
          return;
        }
      }
    } catch (e) {
      debugPrint('[ReminderNotifier] Error migrating legacy reminders: $e');
    }

    // 2. Default warm reminder if none exists
    final defaultReminder = CheckinReminder(
      id: 'default_evening_checkin_$homeId',
      hour: 20,
      minute: 30,
      message: 'A quiet moment for us • Check in on our sanctuary',
      isEnabled: true,
      createdAt: clock.now(),
    );

    await db.into(db.localCheckinReminders).insertOnConflictUpdate(
      LocalCheckinRemindersCompanion.insert(
        id: defaultReminder.id,
        homeId: homeId,
        hour: defaultReminder.hour,
        minute: defaultReminder.minute,
        message: defaultReminder.message,
        isEnabled: const drift.Value(true),
        createdAt: defaultReminder.createdAt,
      ),
    );

    if (!ref.mounted) return;
    state = [defaultReminder];

    // Emit sync event so partner device also receives default reminder
    try {
      if (!ref.mounted) return;
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'checkin_reminder_added',
        payload: {
          'id': defaultReminder.id,
          'home_id': homeId,
          'hour': defaultReminder.hour,
          'minute': defaultReminder.minute,
          'message': defaultReminder.message,
          'is_enabled': true,
          'created_at': defaultReminder.createdAt.toIso8601String(),
        },
        targetHomeId: homeId,
      );
    } catch (_) {}
  }

  Future<void> addReminder({
    required int hour,
    required int minute,
    required String message,
  }) async {
    final homeId = ref.read(activeHomeIdProvider);
    if (homeId == null || homeId.isEmpty) return;

    final newReminder = CheckinReminder(
      id: 'rem_${clock.now().millisecondsSinceEpoch}',
      hour: hour,
      minute: minute,
      message: message.trim().isNotEmpty
          ? message.trim()
          : 'A quiet moment for us • Check in on our sanctuary',
      isEnabled: true,
      createdAt: clock.now(),
    );

    // 1. Insert into Drift SQLite database
    final db = ref.read(appDatabaseProvider);
    await db.into(db.localCheckinReminders).insertOnConflictUpdate(
      LocalCheckinRemindersCompanion.insert(
        id: newReminder.id,
        homeId: homeId,
        hour: newReminder.hour,
        minute: newReminder.minute,
        message: newReminder.message,
        isEnabled: const drift.Value(true),
        createdAt: newReminder.createdAt,
      ),
    );

    state = [...state, newReminder];

    // 2. Emit sync event to partner
    try {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'checkin_reminder_added',
        payload: {
          'id': newReminder.id,
          'home_id': homeId,
          'hour': newReminder.hour,
          'minute': newReminder.minute,
          'message': newReminder.message,
          'is_enabled': true,
          'created_at': newReminder.createdAt.toIso8601String(),
        },
        targetHomeId: homeId,
      );
    } catch (_) {}
  }

  Future<void> updateReminder(CheckinReminder reminder) async {
    final homeId = ref.read(activeHomeIdProvider);
    if (homeId == null || homeId.isEmpty) return;

    // 1. Update in Drift SQLite database
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.localCheckinReminders)..where((t) => t.id.equals(reminder.id))).write(
      LocalCheckinRemindersCompanion(
        hour: drift.Value(reminder.hour),
        minute: drift.Value(reminder.minute),
        message: drift.Value(reminder.message),
        isEnabled: drift.Value(reminder.isEnabled),
      ),
    );

    state = state.map((r) => r.id == reminder.id ? reminder : r).toList();

    // 2. Emit sync event to partner
    try {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'checkin_reminder_updated',
        payload: {
          'id': reminder.id,
          'home_id': homeId,
          'hour': reminder.hour,
          'minute': reminder.minute,
          'message': reminder.message,
          'is_enabled': reminder.isEnabled,
          'created_at': reminder.createdAt.toIso8601String(),
        },
        targetHomeId: homeId,
      );
    } catch (_) {}
  }

  Future<void> toggleReminder(String id, bool enabled) async {
    final homeId = ref.read(activeHomeIdProvider);
    if (homeId == null || homeId.isEmpty) return;

    // 1. Update in Drift SQLite database
    final db = ref.read(appDatabaseProvider);
    await (db.update(db.localCheckinReminders)..where((t) => t.id.equals(id))).write(
      LocalCheckinRemindersCompanion(
        isEnabled: drift.Value(enabled),
      ),
    );

    state = state.map((r) => r.id == id ? r.copyWith(isEnabled: enabled) : r).toList();

    // 2. Emit sync event to partner
    try {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'checkin_reminder_toggled',
        payload: {
          'id': id,
          'home_id': homeId,
          'is_enabled': enabled,
        },
        targetHomeId: homeId,
      );
    } catch (_) {}
  }

  Future<void> deleteReminder(String id) async {
    final homeId = ref.read(activeHomeIdProvider);
    if (homeId == null || homeId.isEmpty) return;

    // 1. Delete from Drift SQLite database
    final db = ref.read(appDatabaseProvider);
    await (db.delete(db.localCheckinReminders)..where((t) => t.id.equals(id))).go();

    state = state.where((r) => r.id != id).toList();

    // 2. Emit sync event to partner
    try {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'checkin_reminder_deleted',
        payload: {
          'id': id,
          'home_id': homeId,
        },
        targetHomeId: homeId,
      );
    } catch (_) {}
  }

  /// Triggers an immediate preview notification with the Spec §2 copy:
  /// `{reminder label, else Evening}` / `A quiet moment, together.`
  Future<void> previewNotification(
    CheckinReminder reminder, {
    LocalNotificationSink? sink,
  }) async {
    try {
      final copy = reminder.notificationCopy;
      final id = clock.now().millisecondsSinceEpoch ~/ 1000;
      if (sink != null) {
        final homeId = ref.read(activeHomeIdProvider) ?? '';
        await sink.show(
          RenderedNotification(
            id: id,
            channelId: 'cove_checkin_reminders',
            groupKey: 'cove_group_checkin',
            module: NotificationModule.home,
            color: CoveTokens.dark.accentFill,
            title: copy.title,
            body: copy.body,
            tapPayload: CoveNotificationPayload(
              homeId: homeId,
              module: NotificationModule.home,
              eventType: 'checkin_reminder',
              title: copy.title,
              body: copy.body,
            ),
          ),
        );
        return;
      }

      final androidDetails = AndroidNotificationDetails(
        'cove_checkin_reminders',
        'Daily Check-ins',
        channelDescription: 'Gentle warm reminders to pause and check into Cove together',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@drawable/ic_stat_cove',
        color: CoveTokens.dark.accentFill,
        groupKey: 'cove_group_checkin',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        threadIdentifier: 'cove_group_checkin',
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id: id,
        title: copy.title,
        body: copy.body,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('[ReminderNotifier] Error previewing notification: $e');
    }
  }
}

final checkinRemindersProvider =
    NotifierProvider<ReminderNotifier, List<CheckinReminder>>(ReminderNotifier.new);
