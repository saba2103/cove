import 'dart:convert';
import 'package:clock/clock.dart';
import 'notification_copy.dart';

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
  final String? listId;
  final bool isBatch;

  const CoveNotificationPayload({
    required this.homeId,
    required this.module,
    required this.eventType,
    this.eventId,
    required this.title,
    required this.body,
    this.payload,
    this.actorName,
    this.listId,
    this.isBatch = false,
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
    String? viewerUserId,
    DateTime? today,
    int? untickedItemsLeft,
    int? habitStreak,
    bool? createdByViewer,
  }) {
    final module = moduleForEventType(eventType);
    final resolvedPartner = _resolveActorName(actorName, payload);
    final resolvedHome = (homeName != null && homeName.trim().isNotEmpty)
        ? homeName.trim()
        : ((payload['home_name'] as String?)?.trim().isNotEmpty == true
            ? (payload['home_name'] as String).trim()
            : 'Home');
    final resolvedSymbol = resolveNotificationCurrencySymbol(
      payload['currency'] as String?,
      fallbackSymbol: preferredCurrencySymbol,
    );

    final copy = composeNotification(
      DecryptedEvent(
        id: eventId ?? (payload['id'] as String? ?? ''),
        homeId: homeId,
        eventType: eventType,
        actorId: actorId,
        payload: payload,
      ),
      NotificationContext(
        partnerName: resolvedPartner,
        homeName: resolvedHome,
        currencySymbol: resolvedSymbol,
        today: today ?? clock.now(),
        viewerUserId: viewerUserId ?? '',
        untickedItemsLeft: untickedItemsLeft,
        habitStreak: habitStreak,
        createdByViewer: createdByViewer ?? false,
      ),
    );

    return CoveNotificationPayload(
      homeId: homeId,
      module: copy?.groupKey ?? module,
      eventType: eventType,
      eventId: eventId,
      title: copy?.title ?? resolvedHome,
      body: copy?.body ?? '',
      payload: payload,
      actorName: actorName ?? resolvedPartner,
    );
  }

  /// Parses from incoming push data Map. If actorName is null, falls back to raw payload.
  factory CoveNotificationPayload.fromMap(
    Map<String, dynamic> data, {
    String? actorName,
    String? homeName,
    String? preferredCurrencySymbol,
    DateTime? today,
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
    final resolvedPartner = _resolveActorName(effectiveActorName, payloadMap);
    final resolvedHome = (homeName != null && homeName.trim().isNotEmpty)
        ? homeName.trim()
        : ((data['home_name'] as String?)?.trim().isNotEmpty == true
            ? (data['home_name'] as String).trim()
            : 'Home');

    String title;
    String body;

    if (payloadMap != null && payloadMap.isNotEmpty) {
      final resolvedSymbol = resolveNotificationCurrencySymbol(
        payloadMap['currency'] as String?,
        fallbackSymbol: preferredCurrencySymbol,
      );
      final copy = composeNotification(
        DecryptedEvent(
          id: eventId ?? (payloadMap['id'] as String? ?? ''),
          homeId: homeId,
          eventType: eventType,
          payload: payloadMap,
        ),
        NotificationContext(
          partnerName: resolvedPartner,
          homeName: resolvedHome,
          currencySymbol: resolvedSymbol,
          today: today ?? clock.now(),
          viewerUserId: '',
        ),
      );
      if (copy != null && copy.canStartCard) {
        title = copy.title;
        body = copy.body;
      } else {
        final fallback = composeFallbackNotification(
          homeName: resolvedHome,
          partnerName: resolvedPartner,
          homeId: homeId,
          eventId: eventId ?? '',
          eventType: eventType,
        );
        title = fallback.title;
        body = fallback.body;
      }
    } else if (data['title'] != null &&
        data['body'] != null &&
        data['title'].toString().isNotEmpty &&
        data['body'].toString().isNotEmpty &&
        data['title'].toString() != module.displayName) {
      title = data['title'].toString();
      body = data['body'].toString();
    } else {
      final fallback = composeFallbackNotification(
        homeName: resolvedHome,
        partnerName: resolvedPartner,
        homeId: homeId,
        eventId: eventId ?? '',
        eventType: eventType,
      );
      title = fallback.title;
      body = fallback.body;
    }

    final listId = (data['list_id'] as String?) ??
        (payloadMap?['list_id'] as String?);
    final isBatch =
        (data['is_batch'] == true) || (payloadMap?['is_batch'] == true);

    return CoveNotificationPayload(
      homeId: homeId,
      module: module,
      eventType: eventType,
      eventId: eventId,
      title: title,
      body: body,
      payload: payloadMap,
      actorName: effectiveActorName,
      listId: listId,
      isBatch: isBatch,
    );
  }

  static String _resolveActorName(
    String? actorName,
    Map<String, dynamic>? payload,
  ) {
    if (actorName != null &&
        actorName.trim().isNotEmpty &&
        actorName.trim() != 'Partner') {
      return actorName.trim();
    }
    if (payload != null) {
      final pActor = payload['actor_name'];
      if (pActor is String &&
          pActor.trim().isNotEmpty &&
          pActor.trim() != 'Partner') {
        return pActor.trim();
      }
      final pDisplay = payload['display_name'];
      if (pDisplay is String &&
          pDisplay.trim().isNotEmpty &&
          pDisplay.trim() != 'Partner') {
        return pDisplay.trim();
      }
    }
    return (actorName != null && actorName.trim().isNotEmpty)
        ? actorName.trim()
        : 'Partner';
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
    String? listId,
    bool? isBatch,
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
      listId: listId ?? this.listId,
      isBatch: isBatch ?? this.isBatch,
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
      if (listId != null) 'list_id': listId,
      if (isBatch) 'is_batch': true,
      if (payload != null) 'payload': payload,
    };
  }
}

