import 'package:intl/intl.dart';

import '../../core/utils/cove_currency_formatter.dart';
import 'notification_models.dart';

/// A decrypted household sync event passed to [composeNotification].
class DecryptedEvent {
  final String id;
  final String homeId;
  final String eventType;
  final String actorId;
  final Map<String, dynamic> payload;
  final DateTime? createdAt;

  const DecryptedEvent({
    this.id = '',
    this.homeId = '',
    required this.eventType,
    this.actorId = '',
    this.payload = const <String, dynamic>{},
    this.createdAt,
  });
}

/// Context required by [composeNotification] that is not carried on the event
/// itself (`design/specs/15-notifications.md` §1–§3).
///
/// The caller fills this in from local read-only state; [composeNotification]
/// performs zero lookups.
class NotificationContext {
  final String partnerName;
  final String homeName;
  final String currencySymbol;
  final DateTime today;
  final String viewerUserId;
  final int? untickedItemsLeft;
  final int? habitStreak;
  final bool createdByViewer;

  /// Optional pre-resolved record fields when an event payload carries only an ID.
  final String? listId;
  final String? listName;
  final String? itemTitle;
  final String? habitName;
  final DateTime? eventStartTime;
  final bool? eventIsAllDay;
  final DateTime? previousEventStartTime;
  final bool? previousEventIsAllDay;
  final bool? calendarDateOrTimeChanged;
  final String? billingCycle;
  final DateTime? endDate;
  final bool isPrivate;

  const NotificationContext({
    required this.partnerName,
    required this.homeName,
    required this.currencySymbol,
    required this.today,
    required this.viewerUserId,
    this.untickedItemsLeft,
    this.habitStreak,
    this.createdByViewer = false,
    this.listId,
    this.listName,
    this.itemTitle,
    this.habitName,
    this.eventStartTime,
    this.eventIsAllDay,
    this.previousEventStartTime,
    this.previousEventIsAllDay,
    this.calendarDateOrTimeChanged,
    this.billingCycle,
    this.endDate,
    this.isPrivate = false,
  });
}

/// The pure data output of [composeNotification] (`design/specs/15-notifications.md`).
class NotificationCopy {
  final String title;
  final String body;

  /// The list ID for list item events (`list_item_added`, `list_item_toggled`,
  /// `list_item_deleted`); `null` for every other event.
  final String? batchKey;

  /// Module group key so Android stacks notifications by module (§6).
  final NotificationModule groupKey;

  /// The line this event contributes to a 90s list batch (`+ item`, `✓ item`,
  /// or `− item`); `null` for non-batched events.
  final String? batchLine;

  /// Whether this event can start a notification card on its own.
  ///
  /// False for `list_item_deleted` (§3: "A removal never starts a card. If a
  /// card for that same list is already out and still inside its window (§5),
  /// the removal rides along as a `−` line inside it. Otherwise it stays silent.").
  final bool canStartCard;

  /// Partner name carried forward for batch summary composition (`Ancy made two changes`).
  final String partnerName;
  final String eventId;
  final String homeId;
  final String eventType;

  const NotificationCopy({
    required this.title,
    required this.body,
    required this.groupKey,
    this.batchKey,
    this.batchLine,
    this.canStartCard = true,
    this.partnerName = '',
    this.eventId = '',
    this.homeId = '',
    this.eventType = '',
  });

  NotificationModule get module => groupKey;
  String? get line => batchLine;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationCopy &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          body == other.body &&
          batchKey == other.batchKey &&
          groupKey == other.groupKey &&
          batchLine == other.batchLine &&
          canStartCard == other.canStartCard;

  @override
  int get hashCode => Object.hash(
        title,
        body,
        batchKey,
        groupKey,
        batchLine,
        canStartCard,
      );

  @override
  String toString() =>
      'NotificationCopy(title: "$title", body: "$body", batchKey: $batchKey, '
      'groupKey: ${groupKey.name}, batchLine: $batchLine, canStartCard: $canStartCard)';
}

/// Composes the Quiet Ledger notification copy for [event] in [ctx]
/// (`design/specs/15-notifications.md` §1–§3).
///
/// Returns `null` when the event is never sent (§3).
/// For `list_item_deleted`, returns a [NotificationCopy] with
/// `canStartCard: false` and `batchLine: '− {item}'` so the batcher (§5) can
/// ride it along into an open list batch or drop it if no batch is open.
NotificationCopy? composeNotification(
  DecryptedEvent event,
  NotificationContext ctx,
) {
  final p = event.payload;

  // §3: Anything the user did themselves on another device -> never sent.
  if (ctx.createdByViewer) return null;
  if (ctx.viewerUserId.isNotEmpty) {
    if (event.actorId.isNotEmpty && event.actorId == ctx.viewerUserId) {
      return null;
    }
    final payloadActor = (p['actor_id'] ?? p['created_by']) as String?;
    if (payloadActor != null &&
        payloadActor.isNotEmpty &&
        payloadActor == ctx.viewerUserId &&
        event.actorId.isEmpty) {
      return null;
    }
  }

  // §3: Anything about a private record -> never sent.
  if (_isPrivatePayload(p, ctx)) {
    return null;
  }

  final partner = ctx.partnerName.trim();

  switch (event.eventType) {
    // -------------------------------------------------------------------------
    // SHARED LISTS (§2 & §3)
    // -------------------------------------------------------------------------
    case 'list_item_added': {
      final item = _extractString(p, const ['title', 'name', 'item']) ??
          ctx.itemTitle ??
          '';
      if (item.isEmpty) return null;
      final listName =
          _extractString(p, const ['list_name']) ?? ctx.listName ?? 'Shared lists';
      final listId = _extractString(p, const ['list_id']) ?? ctx.listId;
      return NotificationCopy(
        title: listName,
        body: '$partner added $item',
        batchKey: listId,
        groupKey: NotificationModule.lists,
        batchLine: '+ $item',
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    case 'list_item_toggled': {
      final isDone =
          (p['is_completed'] as bool?) ?? (p['checked'] as bool?) ?? true;
      // §3: An item put back on a list (toggled to not done) -> never sent.
      if (!isDone) return null;

      final item = _extractString(p, const ['title', 'name', 'item']) ??
          ctx.itemTitle ??
          '';
      if (item.isEmpty) return null;
      final listName =
          _extractString(p, const ['list_name']) ?? ctx.listName ?? 'Shared lists';
      final listId = _extractString(p, const ['list_id']) ?? ctx.listId;
      final remaining =
          ctx.untickedItemsLeft ?? (p['unticked_left'] as num?)?.toInt() ?? 0;
      final leftPhrase = formatItemsLeftPhrase(remaining);

      return NotificationCopy(
        title: listName,
        body: '$partner ticked off $item — $leftPhrase',
        batchKey: listId,
        groupKey: NotificationModule.lists,
        batchLine: '✓ $item',
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    case 'list_item_deleted': {
      // §3: A removal never starts a card. Rides along as `− {item}` if a batch
      // for that list is open; otherwise dropped by the batcher.
      final item = _extractString(p, const ['title', 'name', 'item']) ??
          ctx.itemTitle ??
          '';
      if (item.isEmpty) return null;
      final listName =
          _extractString(p, const ['list_name']) ?? ctx.listName ?? 'Shared lists';
      final listId = _extractString(p, const ['list_id']) ?? ctx.listId;

      return NotificationCopy(
        title: listName,
        body: '',
        batchKey: listId,
        groupKey: NotificationModule.lists,
        batchLine: '− $item',
        canStartCard: false,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    case 'list_created': {
      final name = _extractString(p, const ['name', 'title', 'list_name']) ??
          ctx.listName ??
          '';
      if (name.isEmpty) return null;
      return NotificationCopy(
        title: 'Shared lists',
        body: '$partner started a new list — $name',
        batchKey: null,
        groupKey: NotificationModule.lists,
        batchLine: null,
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    // -------------------------------------------------------------------------
    // EXPENSES (§2 & §3)
    // -------------------------------------------------------------------------
    case 'expense_logged': {
      final title = _extractString(p, const ['title', 'name']) ?? '';
      if (title.isEmpty) return null;
      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
      final formattedAmount = '${ctx.currencySymbol}${formatCoveAmount(amount)}';
      return NotificationCopy(
        title: 'Expenses',
        body: '$partner logged $formattedAmount for $title',
        batchKey: null,
        groupKey: NotificationModule.expenses,
        batchLine: null,
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    // -------------------------------------------------------------------------
    // HABITS (§2 & §3)
    // -------------------------------------------------------------------------
    case 'habit_checkin_toggled': {
      final checked =
          (p['checked'] as bool?) ?? (p['is_completed'] as bool?) ?? true;
      // §3: A habit unchecked -> never sent.
      if (!checked) return null;

      final habitName =
          _extractString(p, const ['habit_name', 'name', 'title']) ??
              ctx.habitName ??
              '';
      if (habitName.isEmpty) return null;

      final streak =
          ctx.habitStreak ?? (p['streak'] as num?)?.toInt() ?? 1;
      final body = streak >= 2
          ? '$partner kept it. ${formatStreakCount(streak)} days running.'
          : '$partner kept it.';

      return NotificationCopy(
        title: habitName,
        body: body,
        batchKey: null,
        groupKey: NotificationModule.habits,
        batchLine: null,
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    case 'habit_created': {
      final name =
          _extractString(p, const ['name', 'habit_name', 'title']) ??
              ctx.habitName ??
              '';
      if (name.isEmpty) return null;
      return NotificationCopy(
        title: 'Habits',
        body: '$partner added a habit — $name',
        batchKey: null,
        groupKey: NotificationModule.habits,
        batchLine: null,
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    // -------------------------------------------------------------------------
    // CALENDAR (§2 & §3)
    // -------------------------------------------------------------------------
    case 'calendar_event_added': {
      final title = _extractString(p, const ['title', 'name']) ?? '';
      if (title.isEmpty) return null;
      final startTime =
          _parseDateTime(p['start_time']) ?? ctx.eventStartTime;
      if (startTime == null) return null;
      final isAllDay =
          (p['is_all_day'] as bool?) ?? ctx.eventIsAllDay ?? false;
      final whenStr = formatCalendarWhen(
        startTime,
        today: ctx.today,
        isAllDay: isAllDay,
      );
      return NotificationCopy(
        title: title,
        body: '$partner put it in for $whenStr',
        batchKey: null,
        groupKey: NotificationModule.calendar,
        batchLine: null,
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    case 'calendar_event_updated': {
      final title = _extractString(p, const ['title', 'name']) ?? '';
      if (title.isEmpty) return null;
      final startTime =
          _parseDateTime(p['start_time']) ?? ctx.eventStartTime;
      if (startTime == null) return null;
      final isAllDay =
          (p['is_all_day'] as bool?) ?? ctx.eventIsAllDay ?? false;

      // §2 & §3: Only sent when date or time changed.
      final bool dateOrTimeChanged;
      if (ctx.calendarDateOrTimeChanged != null) {
        dateOrTimeChanged = ctx.calendarDateOrTimeChanged!;
      } else if (p['date_or_time_changed'] is bool) {
        dateOrTimeChanged = p['date_or_time_changed'] as bool;
      } else {
        final prevStart = _parseDateTime(p['previous_start_time']) ??
            ctx.previousEventStartTime;
        final prevAllDay =
            (p['previous_is_all_day'] as bool?) ?? ctx.previousEventIsAllDay;
        if (prevStart != null) {
          final sameInstant = startTime.year == prevStart.year &&
              startTime.month == prevStart.month &&
              startTime.day == prevStart.day &&
              startTime.hour == prevStart.hour &&
              startTime.minute == prevStart.minute;
          final sameAllDay = prevAllDay == null || isAllDay == prevAllDay;
          dateOrTimeChanged = !(sameInstant && sameAllDay);
        } else {
          dateOrTimeChanged = true;
        }
      }

      if (!dateOrTimeChanged) return null;

      final whenStr = formatCalendarWhen(
        startTime,
        today: ctx.today,
        isAllDay: isAllDay,
      );
      return NotificationCopy(
        title: title,
        body: '$partner moved it to $whenStr',
        batchKey: null,
        groupKey: NotificationModule.calendar,
        batchLine: null,
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    case 'calendar_event_deleted': {
      final title = _extractString(p, const ['title', 'name']) ?? '';
      if (title.isEmpty) return null;
      final startTime =
          _parseDateTime(p['start_time'] ?? p['date']) ?? ctx.eventStartTime;
      if (startTime == null) return null;
      final dayStr = formatCalendarDay(startTime, today: ctx.today);
      return NotificationCopy(
        title: title,
        body: '$partner cancelled it — $dayStr',
        batchKey: null,
        groupKey: NotificationModule.calendar,
        batchLine: null,
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    // -------------------------------------------------------------------------
    // COMMITMENTS / SUBSCRIPTIONS (§2 & §3)
    // -------------------------------------------------------------------------
    case 'subscription_added': {
      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
      final formattedAmount = '${ctx.currencySymbol}${formatCoveAmount(amount)}';
      final endDate = _parseDateTime(p['end_date']) ?? ctx.endDate;
      final totalInstallments = (p['total_installments'] as num?)?.toInt();
      final paidInstallments = (p['paid_installments'] as num?)?.toInt() ?? 0;
      final isEmi = (p['is_emi'] == true) ||
          endDate != null ||
          (totalInstallments != null && totalInstallments > 0);

      if (isEmi) {
        final DateTime lastInstalmentDate;
        if (endDate != null) {
          lastInstalmentDate = endDate;
        } else {
          final nextBilling =
              _parseDateTime(p['next_billing_date']) ?? ctx.today;
          final total = totalInstallments ?? 1;
          final remaining = (total - paidInstallments).clamp(1, total);
          lastInstalmentDate = DateTime(
            nextBilling.year,
            nextBilling.month + remaining - 1,
            1,
          );
        }
        final lastMonthStr = DateFormat('MMM yyyy').format(lastInstalmentDate);
        return NotificationCopy(
          title: 'Commitments',
          body: '$partner added an EMI — $formattedAmount a month to $lastMonthStr',
          batchKey: null,
          groupKey: NotificationModule.subscriptions,
          batchLine: null,
          canStartCard: true,
          partnerName: partner,
          eventId: event.id,
          homeId: event.homeId,
          eventType: event.eventType,
        );
      }

      final name = _extractString(p, const ['name', 'title']) ?? '';
      if (name.isEmpty) return null;
      final cycle =
          _extractString(p, const ['billing_cycle']) ?? ctx.billingCycle ?? 'monthly';
      final cyclePhrase = formatBillingCyclePhrase(cycle);
      return NotificationCopy(
        title: 'Commitments',
        body: '$partner added $name — $formattedAmount $cyclePhrase',
        batchKey: null,
        groupKey: NotificationModule.subscriptions,
        batchLine: null,
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    case 'subscription_cancelled': {
      final name = _extractString(p, const ['name', 'title']) ?? '';
      if (name.isEmpty) return null;
      final amount = (p['amount'] as num?)?.toDouble() ?? 0.0;
      final formattedAmount = '${ctx.currencySymbol}${formatCoveAmount(amount)}';
      final cycle =
          _extractString(p, const ['billing_cycle']) ?? ctx.billingCycle ?? 'monthly';
      final cyclePhrase = formatBillingCyclePhrase(cycle);
      return NotificationCopy(
        title: 'Commitments',
        body: '$partner paused $name — $formattedAmount $cyclePhrase back',
        batchKey: null,
        groupKey: NotificationModule.subscriptions,
        batchLine: null,
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    // -------------------------------------------------------------------------
    // HOME & CHECK-IN REMINDER (§2)
    // -------------------------------------------------------------------------
    case 'member_joined': {
      final homeTitle = ctx.homeName.trim().isNotEmpty
          ? ctx.homeName.trim()
          : (_extractString(p, const ['home_name', 'name']) ?? 'Home');
      return NotificationCopy(
        title: homeTitle,
        body: '$partner joined. You are both in.',
        batchKey: null,
        groupKey: NotificationModule.home,
        batchLine: null,
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    case 'checkin_reminder':
    case 'check_in_reminder': {
      final label = _extractString(p, const ['label', 'title', 'name']) ?? 'Evening';
      return NotificationCopy(
        title: label,
        body: 'A quiet moment, together.',
        batchKey: null,
        groupKey: NotificationModule.activity,
        batchLine: null,
        canStartCard: true,
        partnerName: partner,
        eventId: event.id,
        homeId: event.homeId,
        eventType: event.eventType,
      );
    }

    // -------------------------------------------------------------------------
    // NEVER SENT (§3)
    // -------------------------------------------------------------------------
    default:
      return null;
  }
}

/// Composes the §4 fallback notification when the phone cannot decrypt or
/// compose the event within the 8-second budget.
NotificationCopy composeFallbackNotification({
  required String homeName,
  required String partnerName,
  String homeId = '',
  String eventId = '',
  String eventType = 'fallback',
}) {
  final cleanHome = homeName.trim().isNotEmpty ? homeName.trim() : 'Home';
  final cleanPartner =
      partnerName.trim().isNotEmpty ? partnerName.trim() : 'Partner';
  return NotificationCopy(
    title: cleanHome,
    body: '$cleanPartner made a change. Open to see it.',
    batchKey: null,
    groupKey: NotificationModule.activity,
    batchLine: null,
    canStartCard: true,
    partnerName: cleanPartner,
    eventId: eventId,
    homeId: homeId,
    eventType: eventType,
  );
}

/// Composes the §2 local scheduled check-in reminder notification.
NotificationCopy composeCheckinReminder({String? label}) {
  final cleanLabel =
      (label != null && label.trim().isNotEmpty) ? label.trim() : 'Evening';
  return NotificationCopy(
    title: cleanLabel,
    body: 'A quiet moment, together.',
    batchKey: null,
    groupKey: NotificationModule.activity,
    batchLine: null,
    canStartCard: true,
    eventType: 'checkin_reminder',
  );
}

/// Resolves a currency code (`INR`, `USD`, `EUR`, etc.) to its symbol,
/// preferring [fallbackSymbol] when [code] is null/empty or default `'USD'`.
String resolveNotificationCurrencySymbol(
  String? code, {
  String? fallbackSymbol,
}) {
  if (fallbackSymbol != null && fallbackSymbol.isNotEmpty) {
    if (code == null || code.isEmpty || code.toUpperCase() == 'USD') {
      return fallbackSymbol;
    }
  }
  switch (code?.toUpperCase()) {
    case 'INR':
      return '₹';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'CAD':
      return 'CA\$';
    case 'AUD':
      return 'AU\$';
    case 'JPY':
      return '¥';
    case 'CHF':
      return 'CHF ';
    case 'USD':
    default:
      return fallbackSymbol ?? '\$';
  }
}

/// Formats numbers of things: words up to ten (`one`..`ten`), digits after (`11`, ...).
String formatCountWordUpToTen(int n) {
  const words = <String>[
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
  ];
  if (n >= 0 && n <= 10) return words[n];
  return '$n';
}

/// Formats `{n} left` for `list_item_toggled`:
/// `nothing left` at 0, `one left`..`ten left` for 1..10, `11 left` for >= 11.
String formatItemsLeftPhrase(int remaining) {
  if (remaining <= 0) return 'nothing left';
  return '${formatCountWordUpToTen(remaining)} left';
}

/// Formats habit streak counts (`{N} days running.`):
/// Sentence-cased number words up to 99 (`Two`, `Twenty-three`, `Ninety-nine`),
/// digits for 100 and beyond (`100`).
String formatStreakCount(int n) {
  if (n < 0 || n >= 100) return '$n';
  const underTwenty = <String>[
    'Zero',
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
    'Seven',
    'Eight',
    'Nine',
    'Ten',
    'Eleven',
    'Twelve',
    'Thirteen',
    'Fourteen',
    'Fifteen',
    'Sixteen',
    'Seventeen',
    'Eighteen',
    'Nineteen',
  ];
  if (n < 20) return underTwenty[n];

  const tensWords = <int, String>{
    20: 'Twenty',
    30: 'Thirty',
    40: 'Forty',
    50: 'Fifty',
    60: 'Sixty',
    70: 'Seventy',
    80: 'Eighty',
    90: 'Ninety',
  };
  const ones = <String>[
    '',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
  ];
  final tens = (n ~/ 10) * 10;
  final rem = n % 10;
  final tensWord = tensWords[tens]!;
  if (rem == 0) return tensWord;
  return '$tensWord-${ones[rem]}';
}

/// Formats `{day}` for calendar events (`design/specs/15-notifications.md` §2):
/// - Within the next six days (`0 <= diffDays <= 6`): full weekday (`Saturday`).
/// - Further out: `EEE d MMM` (`Sat 14 Nov`).
String formatCalendarDay(DateTime eventStart, {required DateTime today}) {
  final todayDate = DateTime(today.year, today.month, today.day);
  final eventDate = DateTime(eventStart.year, eventStart.month, eventStart.day);
  final diffDays = eventDate.difference(todayDate).inDays;
  if (diffDays >= 0 && diffDays <= 6) {
    return DateFormat('EEEE').format(eventStart);
  }
  return DateFormat('EEE d MMM').format(eventStart);
}

/// Formats `{when}` for calendar events (`design/specs/15-notifications.md` §2):
/// - All-day events have no time (`Saturday` or `Sat 14 Nov`).
/// - Timed events append `, h:mm a` (`Saturday, 7:30 PM` or `Sat 14 Nov, 7:30 PM`).
String formatCalendarWhen(
  DateTime eventStart, {
  required DateTime today,
  required bool isAllDay,
}) {
  final dayStr = formatCalendarDay(eventStart, today: today);
  if (isAllDay) return dayStr;
  final timeStr = DateFormat('h:mm a').format(eventStart);
  return '$dayStr, $timeStr';
}

/// Maps a billing cycle code to the §2 phrase (`a month`, `a year`, `every 3 months`).
String formatBillingCyclePhrase(String rawCycle) {
  final norm = rawCycle.trim().toLowerCase();
  switch (norm) {
    case 'monthly':
    case 'month':
    case 'a month':
      return 'a month';
    case 'annual':
    case 'yearly':
    case 'year':
    case 'a year':
      return 'a year';
    case 'every_3_months':
    case 'quarterly':
    case 'quarter':
    case 'every 3 months':
      return 'every 3 months';
    case 'weekly':
    case 'week':
      return 'a week';
    case 'biweekly':
    case 'every_2_weeks':
      return 'every 2 weeks';
    default:
      final match = RegExp(r'^every_(\d+)_months$').firstMatch(norm);
      if (match != null) {
        return 'every ${match.group(1)} months';
      }
      return 'a month';
  }
}

bool _isPrivatePayload(Map<String, dynamic> p, NotificationContext ctx) {
  if (ctx.isPrivate) return true;
  if (p['is_private'] == true) return true;
  if (p['visibility'] == 'private_to_me') return true;
  final splitRatio = p['split_ratio'];
  if (splitRatio is num && splitRatio < 0) return true;
  final targetDays = p['target_days_per_week'];
  if (targetDays is num && targetDays < 0) return true;
  return false;
}

String? _extractString(Map<String, dynamic> p, List<String> keys) {
  for (final k in keys) {
    final val = p[k];
    if (val is String && val.trim().isNotEmpty) {
      return val.trim();
    }
  }
  return null;
}

DateTime? _parseDateTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String && raw.trim().isNotEmpty) {
    return DateTime.tryParse(raw.trim());
  }
  return null;
}
