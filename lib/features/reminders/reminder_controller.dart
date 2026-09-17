import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'reminder_models.dart';

class ReminderNotifier extends Notifier<List<CheckinReminder>> {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'cove_checkin_reminders_v1';
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  @override
  List<CheckinReminder> build() {
    _loadReminders();
    return [];
  }

  Future<void> _loadReminders() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map((item) => CheckinReminder.fromMap(item as Map<String, dynamic>))
            .toList();
        state = list;
        return;
      }
    } catch (e) {
      debugPrint('[ReminderNotifier] Error loading reminders: $e');
    }

    // Default warm reminder if none exists
    final defaultReminder = CheckinReminder(
      id: 'default_evening_checkin',
      hour: 20,
      minute: 30,
      message: 'A quiet moment for us • Check in on our sanctuary',
      isEnabled: true,
      createdAt: DateTime.now(),
    );
    state = [defaultReminder];
    _saveReminders(state);
  }

  Future<void> _saveReminders(List<CheckinReminder> list) async {
    try {
      final raw = jsonEncode(list.map((e) => e.toMap()).toList());
      await _storage.write(key: _storageKey, value: raw);
    } catch (e) {
      debugPrint('[ReminderNotifier] Error saving reminders: $e');
    }
  }

  Future<void> addReminder({
    required int hour,
    required int minute,
    required String message,
  }) async {
    final newReminder = CheckinReminder(
      id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
      hour: hour,
      minute: minute,
      message: message.trim().isNotEmpty
          ? message.trim()
          : 'A quiet moment for us • Check in on our sanctuary',
      isEnabled: true,
      createdAt: DateTime.now(),
    );

    final updated = [...state, newReminder];
    state = updated;
    await _saveReminders(updated);
  }

  Future<void> updateReminder(CheckinReminder reminder) async {
    final updated = state.map((r) => r.id == reminder.id ? reminder : r).toList();
    state = updated;
    await _saveReminders(updated);
  }

  Future<void> toggleReminder(String id, bool enabled) async {
    final updated = state.map((r) {
      if (r.id == id) {
        return r.copyWith(isEnabled: enabled);
      }
      return r;
    }).toList();
    state = updated;
    await _saveReminders(updated);
  }

  Future<void> deleteReminder(String id) async {
    final updated = state.where((r) => r.id != id).toList();
    state = updated;
    await _saveReminders(updated);
  }

  /// Triggers an immediate preview notification with the warm welcoming copy.
  Future<void> previewNotification(CheckinReminder reminder) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'cove_checkin_reminders',
        'Daily Check-ins',
        channelDescription: 'Gentle warm reminders to pause and check into Cove together',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotifications.show(
        id: id,
        title: 'Cove · A warm pause for the two of you',
        body: reminder.message,
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('[ReminderNotifier] Error previewing notification: $e');
    }
  }
}

final checkinRemindersProvider =
    NotifierProvider<ReminderNotifier, List<CheckinReminder>>(ReminderNotifier.new);
