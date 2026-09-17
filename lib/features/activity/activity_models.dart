import 'package:flutter/material.dart';
import '../../core/widgets/cove_sync_tick.dart';

enum ActivityModule {
  all,
  subscriptions,
  lists,
  expenses,
  habits,
  calendar;

  String get label {
    switch (this) {
      case ActivityModule.all:
        return 'All';
      case ActivityModule.subscriptions:
        return 'Commitments';
      case ActivityModule.lists:
        return 'Lists';
      case ActivityModule.expenses:
        return 'Expenses';
      case ActivityModule.habits:
        return 'Habits';
      case ActivityModule.calendar:
        return 'Calendar';
    }
  }

  List<String>? get eventTypes {
    switch (this) {
      case ActivityModule.all:
        return null;
      case ActivityModule.subscriptions:
        return [
          'subscription_added',
          'subscription_updated',
          'subscription_cancelled',
          'subscription_reactivated',
        ];
      case ActivityModule.lists:
        return [
          'list_created',
          'list_archived',
          'list_item_added',
          'list_item_toggled',
          'list_item_deleted',
          'list_completed_cleared',
        ];
      case ActivityModule.expenses:
        return [
          'expense_logged',
          'expense_deleted',
        ];
      case ActivityModule.habits:
        return [
          'habit_created',
          'habit_checkin_toggled',
          'habit_checkin_acknowledged',
          'habit_archived',
          'habit_deleted',
        ];
      case ActivityModule.calendar:
        return [
          'calendar_event_added',
          'calendar_event_updated',
          'calendar_event_deleted',
        ];
    }
  }
}

class FormattedActivityItem {
  final String id;
  final String homeId;
  final String actorId;
  final String actorName;
  final String? actorAvatarUrl;
  final String actionText;
  final String eventType;
  final ActivityModule module;
  final IconData icon;
  final DateTime timestamp;
  final String timeAgo;
  final CoveSyncStatus syncStatus;
  final bool isPrivate;
  final bool isLocalActor;
  final Map<String, dynamic> rawPayload;
  final String? entityId;
  final String? targetTitle;
  final String? detailSubtitle;

  const FormattedActivityItem({
    required this.id,
    required this.homeId,
    required this.actorId,
    required this.actorName,
    this.actorAvatarUrl,
    required this.actionText,
    required this.eventType,
    required this.module,
    required this.icon,
    required this.timestamp,
    required this.timeAgo,
    required this.syncStatus,
    required this.isPrivate,
    required this.isLocalActor,
    this.rawPayload = const {},
    this.entityId,
    this.targetTitle,
    this.detailSubtitle,
  });
}
