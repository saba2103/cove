import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../calendar/calendar_event_form_sheet.dart';
import '../expenses/expense_detail_sheet.dart';
import '../habits/habit_detail_sheet.dart';
import '../lists/list_item_detail_sheet.dart';
import '../subscriptions/commitment_detail_sheet.dart';
import 'notification_models.dart';

/// Dispatches push notification deep links directly to the corresponding
/// entity detail bottom sheet (Expense, Commitment, List Item, Calendar Event, Habit).
class NotificationDetailDispatcher {
  static bool _isOpening = false;
  static String? _lastDispatchedEntityId;
  static DateTime? _lastDispatchedTime;

  @visibleForTesting
  static void resetState() {
    _isOpening = false;
    _lastDispatchedEntityId = null;
    _lastDispatchedTime = null;
  }

  static Future<void> openDetailForNotification(
    BuildContext context,
    WidgetRef ref,
    CoveNotificationPayload payload, {
    Duration delay = const Duration(milliseconds: 200),
  }) async {
    final db = ref.read(appDatabaseProvider);
    final syncEngine = ref.read(syncEngineProvider);

    // 1. Resolve raw payload map and event ID
    Map<String, dynamic>? rawPayload = payload.payload;
    final eventId = payload.eventId;

    // If payload is empty or not enriched, look up decrypted event from localActivityEvents
    if ((rawPayload == null || rawPayload.isEmpty) &&
        eventId != null &&
        eventId.isNotEmpty) {
      var ev = await (db.select(db.localActivityEvents)
            ..where((t) => t.id.equals(eventId)))
          .getSingleOrNull();

      // If not yet in local SQLite, pull latest events from cloud
      if (ev == null && payload.homeId.isNotEmpty) {
        try {
          await syncEngine.pullLatestEvents(homeId: payload.homeId);
          ev = await (db.select(db.localActivityEvents)
                ..where((t) => t.id.equals(eventId)))
              .getSingleOrNull();
        } catch (_) {}
      }

      if (ev != null && ev.payloadJson.isNotEmpty) {
        try {
          rawPayload = jsonDecode(ev.payloadJson) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    final entityId = rawPayload?['id'] as String? ??
        rawPayload?['item_id'] as String? ??
        rawPayload?['expense_id'] as String? ??
        rawPayload?['subscription_id'] as String? ??
        rawPayload?['habit_id'] as String? ??
        rawPayload?['event_id'] as String?;

    // If there is no specific entity associated with this notification,
    // the user has already navigated to the module screen.
    if (entityId == null) return;

    final now = clock.now();
    if (_isOpening && _lastDispatchedEntityId == entityId) {
      debugPrint('[NotificationDetailDispatcher] Already opening detail for $entityId, skipping duplicate');
      return;
    }
    if (_lastDispatchedEntityId == entityId &&
        _lastDispatchedTime != null &&
        now.difference(_lastDispatchedTime!) < const Duration(milliseconds: 1500)) {
      debugPrint('[NotificationDetailDispatcher] Dropping duplicate sheet open for $entityId within 1500ms');
      return;
    }

    _isOpening = true;
    _lastDispatchedEntityId = entityId;
    _lastDispatchedTime = now;

    try {
      // Allow UI tab switch to render and settle before opening the modal sheet
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }
      if (!context.mounted) return;

      // Ensure any existing sheet is popped before opening to prevent stacking
      Navigator.of(context).popUntil((route) => route.isFirst);

      switch (payload.module) {
        case NotificationModule.expenses:
          var expense = await (db.select(db.localExpenses)
                ..where((t) => t.id.equals(entityId)))
              .getSingleOrNull();

          if (expense == null && payload.homeId.isNotEmpty) {
            try {
              await syncEngine.pullLatestEvents(homeId: payload.homeId);
              expense = await (db.select(db.localExpenses)
                    ..where((t) => t.id.equals(entityId)))
                  .getSingleOrNull();
            } catch (_) {}
          }

          if (expense != null && context.mounted) {
            ExpenseDetailSheet.show(context, expense);
          }
          break;

        case NotificationModule.subscriptions:
          var sub = await (db.select(db.localSubscriptions)
                ..where((t) => t.id.equals(entityId)))
              .getSingleOrNull();

          if (sub == null && payload.homeId.isNotEmpty) {
            try {
              await syncEngine.pullLatestEvents(homeId: payload.homeId);
              sub = await (db.select(db.localSubscriptions)
                    ..where((t) => t.id.equals(entityId)))
                  .getSingleOrNull();
            } catch (_) {}
          }

          if (sub != null && context.mounted) {
            CommitmentDetailSheet.show(context, sub);
          }
          break;

        case NotificationModule.lists:
          var item = await (db.select(db.localListItems)
                ..where((t) => t.id.equals(entityId)))
              .getSingleOrNull();

          if (item == null && payload.homeId.isNotEmpty) {
            try {
              await syncEngine.pullLatestEvents(homeId: payload.homeId);
              item = await (db.select(db.localListItems)
                    ..where((t) => t.id.equals(entityId)))
                  .getSingleOrNull();
            } catch (_) {}
          }

          final resolvedItem = item;
          if (resolvedItem != null && context.mounted) {
            final list = await (db.select(db.localLists)
                  ..where((t) => t.id.equals(resolvedItem.listId)))
                .getSingleOrNull();
            final listName = list?.name ??
                rawPayload?['list_name'] as String? ??
                'Shared List';
            if (context.mounted) {
              ListItemDetailSheet.show(
                context,
                item: resolvedItem,
                listName: listName,
              );
            }
          }
          break;

        case NotificationModule.calendar:
          var event = await (db.select(db.localCalendarEvents)
                ..where((t) => t.id.equals(entityId)))
              .getSingleOrNull();

          if (event == null && payload.homeId.isNotEmpty) {
            try {
              await syncEngine.pullLatestEvents(homeId: payload.homeId);
              event = await (db.select(db.localCalendarEvents)
                    ..where((t) => t.id.equals(entityId)))
                  .getSingleOrNull();
            } catch (_) {}
          }

          if (event != null && context.mounted) {
            CalendarEventFormSheet.show(context, existing: event);
          }
          break;

        case NotificationModule.habits:
          var habit = await (db.select(db.localHabits)
                ..where((t) => t.id.equals(entityId)))
              .getSingleOrNull();

          if (habit == null && payload.homeId.isNotEmpty) {
            try {
              await syncEngine.pullLatestEvents(homeId: payload.homeId);
              habit = await (db.select(db.localHabits)
                    ..where((t) => t.id.equals(entityId)))
                  .getSingleOrNull();
            } catch (_) {}
          }

          final resolvedHabit = habit;
          if (resolvedHabit != null && context.mounted) {
            final checkins = await (db.select(db.localHabitCheckins)
                  ..where((t) => t.habitId.equals(resolvedHabit.id)))
                .get();
            final currentUserId = ref.read(authProvider).value?.id;
            if (context.mounted) {
              HabitDetailSheet.show(
                context,
                habit: resolvedHabit,
                checkins: checkins,
                isPartnerHabit: resolvedHabit.createdBy != currentUserId,
              );
            }
          }
          break;

        case NotificationModule.activity:
        case NotificationModule.home:
          break;
      }
    } finally {
      _isOpening = false;
    }
  }
}
