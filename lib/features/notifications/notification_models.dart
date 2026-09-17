import 'dart:convert';
import 'notification_formatter.dart';

enum NotificationModule {
  subscriptions,
  lists,
  expenses,
  habits,
  calendar,
  activity,
  home;

  String get displayName {
    switch (this) {
      case NotificationModule.subscriptions:
        return 'Commitments';
      case NotificationModule.lists:
        return 'Shared Lists';
      case NotificationModule.expenses:
        return 'Expenses';
      case NotificationModule.habits:
        return 'Habits & Rhythms';
      case NotificationModule.calendar:
        return 'Shared Calendar';
      case NotificationModule.activity:
        return 'Activity';
      case NotificationModule.home:
        return 'Home';
    }
  }

  String get description {
    switch (this) {
      case NotificationModule.subscriptions:
        return 'New or renewed subscriptions';
      case NotificationModule.lists:
        return 'Partner updates or completed list items';
      case NotificationModule.expenses:
        return 'New expenses logged by partner';
      case NotificationModule.habits:
        return 'Partner check-in momentum & rhythms';
      case NotificationModule.calendar:
        return 'Events added or changed by partner';
      case NotificationModule.activity:
        return 'Household activity stream';
      case NotificationModule.home:
        return 'Partner joining or home updates';
    }
  }

  static NotificationModule fromString(String val, {NotificationModule fallback = NotificationModule.activity}) {
    return NotificationModule.values.firstWhere(
      (m) => m.name.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => fallback,
    );
  }
}

class NotificationPreferences {
  final bool muteSubscriptions;
  final bool muteLists;
  final bool muteExpenses;
  final bool muteHabits;
  final bool muteCalendar;

  const NotificationPreferences({
    this.muteSubscriptions = false,
    this.muteLists = false,
    this.muteExpenses = false,
    this.muteHabits = false,
    this.muteCalendar = false,
  });

  bool isMuted(NotificationModule module) {
    switch (module) {
      case NotificationModule.subscriptions:
        return muteSubscriptions;
      case NotificationModule.lists:
        return muteLists;
      case NotificationModule.expenses:
        return muteExpenses;
      case NotificationModule.habits:
        return muteHabits;
      case NotificationModule.calendar:
        return muteCalendar;
      case NotificationModule.activity:
      case NotificationModule.home:
        return false;
    }
  }

  NotificationPreferences copyWith({
    bool? muteSubscriptions,
    bool? muteLists,
    bool? muteExpenses,
    bool? muteHabits,
    bool? muteCalendar,
  }) {
    return NotificationPreferences(
      muteSubscriptions: muteSubscriptions ?? this.muteSubscriptions,
      muteLists: muteLists ?? this.muteLists,
      muteExpenses: muteExpenses ?? this.muteExpenses,
      muteHabits: muteHabits ?? this.muteHabits,
      muteCalendar: muteCalendar ?? this.muteCalendar,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferences &&
          runtimeType == other.runtimeType &&
          muteSubscriptions == other.muteSubscriptions &&
          muteLists == other.muteLists &&
          muteExpenses == other.muteExpenses &&
          muteHabits == other.muteHabits &&
          muteCalendar == other.muteCalendar;

  @override
  int get hashCode =>
      muteSubscriptions.hashCode ^
      muteLists.hashCode ^
      muteExpenses.hashCode ^
      muteHabits.hashCode ^
      muteCalendar.hashCode;
}

class CoveNotificationPayload {
  final String homeId;
  final NotificationModule module;
  final String eventType;
  final String? eventId;
  final String title;
  final String body;
  final Map<String, dynamic>? payload;
  final String? actorName;

  const CoveNotificationPayload({
    required this.homeId,
    required this.module,
    required this.eventType,
    this.eventId,
    required this.title,
    required this.body,
    this.payload,
    this.actorName,
  });

  /// Anti-spam collapse key for FCM / Android Tag / APNs collapse-id:
  /// e.g. "home_123_lists"
  String get collapseKey => '${homeId}_${module.name}';

  static NotificationModule moduleForEventType(String eventType) {
    if (eventType.startsWith('list_')) return NotificationModule.lists;
    if (eventType.startsWith('expense_')) return NotificationModule.expenses;
    if (eventType.startsWith('subscription_')) return NotificationModule.subscriptions;
    if (eventType.startsWith('habit_')) return NotificationModule.habits;
    if (eventType.startsWith('calendar_')) return NotificationModule.calendar;
    if (eventType.startsWith('home_') || eventType.startsWith('member_')) {
      return NotificationModule.home;
    }
    return NotificationModule.activity;
  }

  /// Strictly blind derivation from unencrypted event_type only
  static String genericMessageForEventType(String eventType, {String? actorName}) {
    final name = (actorName != null &&
            actorName.trim().isNotEmpty &&
            actorName.trim() != 'Partner')
        ? actorName.trim()
        : null;

    switch (eventType) {
      case 'list_item_added':
        return name != null ? '$name added an item to lists' : 'New item added to shared lists';
      case 'list_item_toggled':
        return name != null ? '$name updated a list item' : 'A list item was updated';
      case 'list_item_deleted':
        return name != null ? '$name removed a list item' : 'An item was removed from shared lists';
      case 'list_created':
        return name != null ? '$name created a new list' : 'A new list was created';
      case 'list_completed_cleared':
        return name != null ? '$name cleared completed items' : 'Completed list items were cleared';

      case 'expense_logged':
        return name != null ? '$name logged a new expense' : 'New expense logged';
      case 'expense_updated':
        return name != null ? '$name updated an expense' : 'An expense was updated';
      case 'expense_deleted':
        return name != null ? '$name removed an expense' : 'An expense was removed';

      case 'subscription_added':
        return name != null ? '$name added a commitment' : 'New subscription added';
      case 'subscription_updated':
        return name != null ? '$name updated a commitment' : 'A subscription was updated';
      case 'subscription_cancelled':
        return name != null ? '$name cancelled a commitment' : 'A subscription was deactivated';
      case 'subscription_reactivated':
        return name != null ? '$name reactivated a commitment' : 'A subscription was reactivated';

      case 'habit_created':
        return name != null ? '$name created a new rhythm' : 'A new habit was created';
      case 'habit_checkin_toggled':
        return name != null ? '$name checked in on a habit' : 'Partner checked in on a habit';
      case 'habit_checkin_acknowledged':
        return name != null ? '$name acknowledged your habit check-in' : 'Partner acknowledged your habit check-in';

      case 'calendar_event_added':
        return name != null ? '$name scheduled a calendar event' : 'New calendar event scheduled';
      case 'calendar_event_updated':
        return name != null ? '$name updated a calendar event' : 'A calendar event was updated';
      case 'calendar_event_deleted':
        return name != null ? '$name removed a calendar event' : 'A calendar event was removed';

      case 'member_joined':
        return name != null ? '$name joined your Home' : 'A partner joined your Home';
      case 'home_created':
        return name != null ? '$name created a new Home' : 'A new Home was created';

      default:
        return name != null ? '$name updated household activity' : 'New household activity';
    }
  }

  /// Constructs an enriched notification payload from decrypted event data.
  factory CoveNotificationPayload.fromDecrypted({
    required String homeId,
    required String actorId,
    required String eventType,
    required String? eventId,
    required Map<String, dynamic> payload,
    String? actorName,
    String? homeName,
    String? preferredCurrencySymbol,
  }) {
    final module = moduleForEventType(eventType);
    final formatted = NotificationFormatter.format(
      eventType: eventType,
      payload: payload,
      actorName: actorName,
      homeName: homeName,
      preferredCurrencySymbol: preferredCurrencySymbol,
    );

    return CoveNotificationPayload(
      homeId: homeId,
      module: module,
      eventType: eventType,
      eventId: eventId,
      title: formatted.title,
      body: formatted.body,
      payload: payload,
      actorName: actorName,
    );
  }

  /// Parses from incoming push data Map. If actorName is null, falls back to raw payload.
  factory CoveNotificationPayload.fromMap(
    Map<String, dynamic> data, {
    String? actorName,
    String? homeName,
    String? preferredCurrencySymbol,
  }) {
    final homeId = (data['home_id'] as String?) ?? '';
    final eventType = (data['event_type'] as String?) ?? 'generic';
    final eventId = data['event_id'] as String?;
    final module = (data['module'] as String?) != null
        ? NotificationModule.fromString(data['module'] as String)
        : moduleForEventType(eventType);

    // Extract payload map if present
    Map<String, dynamic>? payloadMap;
    if (data['payload'] is Map<String, dynamic>) {
      payloadMap = data['payload'] as Map<String, dynamic>;
    } else if (data['payload'] is String) {
      try {
        payloadMap =
            jsonDecode(data['payload'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    final effectiveActorName = (data['actor_name'] as String?) ?? actorName;

    String title;
    String body;

    if (payloadMap != null && payloadMap.isNotEmpty) {
      final formatted = NotificationFormatter.format(
        eventType: eventType,
        payload: payloadMap,
        actorName: effectiveActorName,
        homeName: homeName,
        preferredCurrencySymbol: preferredCurrencySymbol,
      );
      title = formatted.title;
      body = formatted.body;
    } else if (data['title'] != null &&
        data['body'] != null &&
        data['title'].toString().isNotEmpty &&
        data['body'].toString().isNotEmpty &&
        data['title'].toString() != module.displayName) {
      title = data['title'].toString();
      body = data['body'].toString();
    } else {
      final formatted = NotificationFormatter.format(
        eventType: eventType,
        payload: const {},
        actorName: effectiveActorName,
        homeName: homeName,
        preferredCurrencySymbol: preferredCurrencySymbol,
      );
      title = formatted.title;
      body = formatted.body;
    }

    return CoveNotificationPayload(
      homeId: homeId,
      module: module,
      eventType: eventType,
      eventId: eventId,
      title: title,
      body: body,
      payload: payloadMap,
      actorName: effectiveActorName,
    );
  }

  CoveNotificationPayload copyWith({
    String? homeId,
    NotificationModule? module,
    String? eventType,
    String? eventId,
    String? title,
    String? body,
    Map<String, dynamic>? payload,
    String? actorName,
  }) {
    return CoveNotificationPayload(
      homeId: homeId ?? this.homeId,
      module: module ?? this.module,
      eventType: eventType ?? this.eventType,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      body: body ?? this.body,
      payload: payload ?? this.payload,
      actorName: actorName ?? this.actorName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'home_id': homeId,
      'module': module.name,
      'event_type': eventType,
      if (eventId != null) 'event_id': eventId,
      'collapse_key': collapseKey,
      'title': title,
      'body': body,
      if (actorName != null) 'actor_name': actorName,
      if (payload != null) 'payload': payload,
    };
  }
}

