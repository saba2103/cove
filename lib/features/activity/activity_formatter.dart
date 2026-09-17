import 'dart:convert';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/db/app_database.dart';
import 'activity_models.dart';

class ActivityFormatter {
  static String getCurrencySymbol(String? code, {String? fallbackSymbol}) {
    if (fallbackSymbol != null && fallbackSymbol.isNotEmpty) {
      if (code == null || code.toUpperCase() == 'USD') {
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
        return fallbackSymbol ?? '\$';
      default:
        return fallbackSymbol ?? '\$';
    }
  }

  /// Synchronous format for fast rendering and tests.
  static FormattedActivityItem format({
    required LocalActivityEvent rawEvent,
    required String? currentUserId,
    String? partnerName,
    String? preferredCurrencySymbol,
  }) {
    Map<String, dynamic> payload = {};
    try {
      payload = jsonDecode(rawEvent.payloadJson) as Map<String, dynamic>;
    } catch (_) {}

    return formatFromPayload(
      rawEvent: rawEvent,
      payload: payload,
      currentUserId: currentUserId,
      partnerName: partnerName,
      preferredCurrencySymbol: preferredCurrencySymbol,
    );
  }

  /// Asynchronous format that enriches missing titles and names from SQLite.
  static Future<FormattedActivityItem> formatWithDb({
    required LocalActivityEvent rawEvent,
    required String? currentUserId,
    String? partnerName,
    String? preferredCurrencySymbol,
    required AppDatabase db,
  }) async {
    Map<String, dynamic> payload = {};
    try {
      payload = jsonDecode(rawEvent.payloadJson) as Map<String, dynamic>;
    } catch (_) {}

    String? resolvedPartnerName = partnerName;
    if (resolvedPartnerName == null ||
        resolvedPartnerName.trim().isEmpty ||
        resolvedPartnerName.trim() == 'Partner') {
      if (payload['actor_name'] is String &&
          (payload['actor_name'] as String).trim().isNotEmpty &&
          (payload['actor_name'] as String).trim() != 'Partner') {
        resolvedPartnerName = (payload['actor_name'] as String).trim();
      } else if (payload['display_name'] is String &&
          (payload['display_name'] as String).trim().isNotEmpty &&
          (payload['display_name'] as String).trim() != 'Partner') {
        resolvedPartnerName = (payload['display_name'] as String).trim();
      } else {
        try {
          final profileEvent = await (db.select(db.localActivityEvents)
                ..where((t) =>
                    t.homeId.equals(rawEvent.homeId) &
                    t.eventType.equals('member_profile_updated') &
                    (currentUserId != null
                        ? t.actorId.isNotValue(currentUserId)
                        : const Constant(true)))
                ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
                ..limit(1))
              .getSingleOrNull();
          if (profileEvent != null) {
            final pMap = jsonDecode(profileEvent.payloadJson) as Map<String, dynamic>;
            final dName = (pMap['display_name'] ?? pMap['actor_name']) as String?;
            if (dName != null && dName.trim().isNotEmpty && dName.trim() != 'Partner') {
              resolvedPartnerName = dName.trim();
            }
          }
        } catch (_) {}
      }
    }

    final id = payload['id'] as String? ??
        payload['item_id'] as String? ??
        payload['habit_id'] as String?;

    if (rawEvent.eventType.startsWith('list_item_')) {
      if (payload['title'] == null ||
          payload['title'] == 'an item' ||
          payload['list_name'] == null) {
        if (id != null) {
          final item = await (db.select(db.localListItems)
                ..where((t) => t.id.equals(id)))
              .getSingleOrNull();
          if (item != null) {
            payload['title'] ??= item.title;
            final list = await (db.select(db.localLists)
                  ..where((t) => t.id.equals(item.listId)))
                .getSingleOrNull();
            if (list != null) {
              payload['list_name'] ??= list.name;
              payload['list_id'] ??= list.id;
            }
          }
        }
      }
    } else if (rawEvent.eventType.startsWith('habit_')) {
      if (payload['habit_name'] == null &&
          payload['title'] == null &&
          payload['name'] == null) {
        final habitId = payload['habit_id'] as String? ?? id;
        if (habitId != null) {
          final habit = await (db.select(db.localHabits)
                ..where((t) => t.id.equals(habitId)))
              .getSingleOrNull();
          if (habit != null) {
            payload['habit_name'] = habit.name;
            payload['name'] = habit.name;
            payload['title'] = habit.name;
          }
        }
      }
    } else if (rawEvent.eventType.startsWith('expense_')) {
      if (payload['title'] == null && id != null) {
        final exp = await (db.select(db.localExpenses)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (exp != null) {
          payload['title'] = exp.title;
          payload['amount'] ??= exp.amount;
          payload['currency'] ??= exp.currency;
          payload['category'] ??= exp.category;
          payload['paid_by'] ??= exp.paidBy;
        }
      }
    } else if (rawEvent.eventType.startsWith('calendar_')) {
      if (payload['title'] == null && id != null) {
        final cal = await (db.select(db.localCalendarEvents)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (cal != null) {
          payload['title'] = cal.title;
          payload['start_time'] ??= cal.startTime.toIso8601String();
          payload['is_all_day'] ??= cal.isAllDay;
        }
      }
    } else if (rawEvent.eventType.startsWith('subscription_')) {
      if (payload['name'] == null && id != null) {
        final sub = await (db.select(db.localSubscriptions)
              ..where((t) => t.id.equals(id)))
            .getSingleOrNull();
        if (sub != null) {
          payload['name'] = sub.name;
          payload['amount'] ??= sub.amount;
          payload['currency'] ??= sub.currency;
          payload['billing_cycle'] ??= sub.billingCycle;
          payload['end_date'] ??= sub.endDate?.toIso8601String();
        }
      }
    }

    return formatFromPayload(
      rawEvent: rawEvent,
      payload: payload,
      currentUserId: currentUserId,
      partnerName: resolvedPartnerName,
      preferredCurrencySymbol: preferredCurrencySymbol,
    );
  }

  static FormattedActivityItem formatFromPayload({
    required LocalActivityEvent rawEvent,
    required Map<String, dynamic> payload,
    required String? currentUserId,
    String? partnerName,
    String? preferredCurrencySymbol,
  }) {
    final isLocalActor = currentUserId != null &&
        (rawEvent.actorId == currentUserId ||
            rawEvent.actorId == 'local_user' ||
            rawEvent.actorId == 'user_alex' ||
            rawEvent.actorId == 'demo-user-alex');

    final effectivePartnerName = (partnerName != null &&
            partnerName.trim().isNotEmpty &&
            partnerName.trim() != 'Partner')
        ? partnerName.trim()
        : ((payload['actor_name'] is String &&
                (payload['actor_name'] as String).trim().isNotEmpty &&
                (payload['actor_name'] as String).trim() != 'Partner')
            ? (payload['actor_name'] as String).trim()
            : ((payload['display_name'] is String &&
                    (payload['display_name'] as String).trim().isNotEmpty &&
                    (payload['display_name'] as String).trim() != 'Partner')
                ? (payload['display_name'] as String).trim()
                : (partnerName ?? 'Partner')));

    final actorName = isLocalActor ? 'You' : effectivePartnerName;

    final syncStatus = rawEvent.syncStatus == 'syncedToPartner'
        ? CoveSyncStatus.syncedToPartner
        : CoveSyncStatus.savedLocally;

    final timeAgo = formatTimeAgo(rawEvent.createdAt);

    switch (rawEvent.eventType) {
      // --- LISTS ---
      case 'list_item_added':
        final item = payload['title'] ?? payload['name'] ?? 'an item';
        final list = payload['list_name'] ?? 'the list';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "added '$item' to $list",
          eventType: rawEvent.eventType,
          module: ActivityModule.lists,
          icon: Icons.checklist_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: item.toString(),
          detailSubtitle: 'List: $list',
        );

      case 'list_item_toggled':
        final item = payload['title'] ?? payload['name'] ?? 'an item';
        final isCompleted = payload['is_completed'] as bool? ?? true;
        final verb = isCompleted ? 'checked off' : 'unchecked';
        final list = payload['list_name'];
        final action = (list != null && list.toString().trim().isNotEmpty)
            ? "$verb '$item' in $list"
            : "$verb '$item'";
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: action,
          eventType: rawEvent.eventType,
          module: ActivityModule.lists,
          icon: isCompleted
              ? Icons.check_circle_outline_rounded
              : Icons.radio_button_unchecked_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: item.toString(),
          detailSubtitle: list != null ? 'List: $list' : null,
        );

      case 'list_item_deleted':
        final item = payload['title'] ?? payload['name'] ?? 'an item';
        final list = payload['list_name'];
        final action = (list != null && list.toString().trim().isNotEmpty)
            ? "removed '$item' from $list"
            : "removed '$item'";
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: action,
          eventType: rawEvent.eventType,
          module: ActivityModule.lists,
          icon: Icons.delete_outline_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: item.toString(),
          detailSubtitle: list != null ? 'List: $list' : null,
        );

      case 'list_created':
        final name = payload['name'] ?? 'New List';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "created list '$name'",
          eventType: rawEvent.eventType,
          module: ActivityModule.lists,
          icon: Icons.format_list_bulleted_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: name.toString(),
          detailSubtitle: 'New shared list',
        );

      case 'list_archived':
        final name = payload['name'] ?? 'list';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "archived list '$name'",
          eventType: rawEvent.eventType,
          module: ActivityModule.lists,
          icon: Icons.archive_outlined,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: name.toString(),
          detailSubtitle: 'Archived list',
        );

      case 'list_completed_cleared':
        final list = payload['list_name'] ?? 'list';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "cleared completed items in $list",
          eventType: rawEvent.eventType,
          module: ActivityModule.lists,
          icon: Icons.cleaning_services_outlined,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['list_id'] as String?,
          targetTitle: list.toString(),
          detailSubtitle: 'List cleaned up',
        );

      // --- EXPENSES ---
      case 'expense_logged':
        final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
        final currencyCode = payload['currency'] as String?;
        final sym = getCurrencySymbol(currencyCode, fallbackSymbol: preferredCurrencySymbol);
        final formattedAmt = '$sym${NumberFormat('#,##0.00').format(amount)}';
        final category = payload['category'] as String?;
        final title = payload['title'] as String?;

        String action;
        if (title != null &&
            title.isNotEmpty &&
            category != null &&
            category.isNotEmpty) {
          action = "logged $formattedAmt for '$title' ($category)";
        } else if (title != null && title.isNotEmpty) {
          action = "logged $formattedAmt for '$title'";
        } else if (category != null && category.isNotEmpty) {
          action = 'logged $formattedAmt under $category';
        } else {
          action = 'logged $formattedAmt';
        }

        String? detailSub;
        final paidBy = payload['paid_by'] as String?;
        if (paidBy != null && paidBy.isNotEmpty) {
          final bool isPaidByMe = (paidBy == currentUserId) ||
              (paidBy == 'me') ||
              (paidBy == 'user_alex') ||
              (paidBy == 'partner_user' && rawEvent.actorId != currentUserId);
          final paidByName = isPaidByMe ? 'You' : actorName;
          detailSub = 'Paid by $paidByName';
          if (category != null && category.isNotEmpty) {
            detailSub = '$detailSub • $category';
          }
        } else if (category != null && category.isNotEmpty) {
          detailSub = category;
        }

        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: action,
          eventType: rawEvent.eventType,
          module: ActivityModule.expenses,
          icon: Icons.account_balance_wallet_outlined,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: title ?? category ?? 'Expense',
          detailSubtitle: detailSub,
        );

      case 'expense_updated':
        final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
        final currencyCode = payload['currency'] as String?;
        final sym = getCurrencySymbol(currencyCode, fallbackSymbol: preferredCurrencySymbol);
        final formattedAmt = '$sym${NumberFormat('#,##0.00').format(amount)}';
        final category = payload['category'] as String?;
        final title = payload['title'] as String?;
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "updated expense '${title ?? 'Expense'}' ($formattedAmt)",
          eventType: rawEvent.eventType,
          module: ActivityModule.expenses,
          icon: Icons.edit_outlined,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: title ?? category ?? 'Expense',
          detailSubtitle: 'Updated in ledger',
        );

      case 'expense_deleted':
        final title = payload['title'] ?? 'expense';
        final amount = (payload['amount'] as num?)?.toDouble();
        final sym = getCurrencySymbol(payload['currency'] as String?, fallbackSymbol: preferredCurrencySymbol);
        final amtStr =
            amount != null ? ' ($sym${NumberFormat('#,##0.00').format(amount)})' : '';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "deleted expense '$title'$amtStr",
          eventType: rawEvent.eventType,
          module: ActivityModule.expenses,
          icon: Icons.delete_outline_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: title.toString(),
          detailSubtitle: 'Deleted from ledger',
        );

      // --- COMMITMENTS (SUBSCRIPTIONS & EMIS) ---
      case 'subscription_added':
        final name = payload['name'] ?? 'commitment';
        final isEmi = payload['end_date'] != null;
        final kind = isEmi ? 'EMI' : 'commitment';
        final amount = (payload['amount'] as num?)?.toDouble();
        final cycle = payload['billing_cycle'] ?? 'monthly';
        final sym = getCurrencySymbol(payload['currency'] as String?, fallbackSymbol: preferredCurrencySymbol);
        final costStr =
            amount != null ? ' ($sym${NumberFormat('#,##0.00').format(amount)}/$cycle)' : '';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "added '$name' $kind$costStr",
          eventType: rawEvent.eventType,
          module: ActivityModule.subscriptions,
          icon: Icons.autorenew_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: name.toString(),
          detailSubtitle:
              amount != null ? '$sym${NumberFormat('#,##0.00').format(amount)}/$cycle' : null,
        );

      case 'subscription_updated':
        final name = payload['name'] ?? 'commitment';
        final isEmi = payload['end_date'] != null;
        final kind = isEmi ? 'EMI' : 'commitment';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "updated '$name' $kind",
          eventType: rawEvent.eventType,
          module: ActivityModule.subscriptions,
          icon: Icons.edit_outlined,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: name.toString(),
          detailSubtitle: '$kind updated',
        );

      case 'subscription_cancelled':
        final name = payload['name'] ?? 'commitment';
        final isEmi = payload['end_date'] != null;
        final kind = isEmi ? 'EMI' : 'commitment';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "cancelled '$name' $kind",
          eventType: rawEvent.eventType,
          module: ActivityModule.subscriptions,
          icon: Icons.pause_circle_outline_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: name.toString(),
          detailSubtitle: 'Paused / Cancelled',
        );

      case 'subscription_reactivated':
        final name = payload['name'] ?? 'commitment';
        final isEmi = payload['end_date'] != null;
        final kind = isEmi ? 'EMI' : 'commitment';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "reactivated '$name' $kind",
          eventType: rawEvent.eventType,
          module: ActivityModule.subscriptions,
          icon: Icons.play_circle_outline_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: name.toString(),
          detailSubtitle: 'Reactivated',
        );

      // --- HABITS ---
      case 'habit_created':
        final name = payload['name'] ?? payload['title'] ?? 'habit';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "created habit '$name'",
          eventType: rawEvent.eventType,
          module: ActivityModule.habits,
          icon: Icons.repeat_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String? ?? payload['habit_id'] as String?,
          targetTitle: name.toString(),
          detailSubtitle: 'New shared rhythm',
        );

      case 'habit_checkin_toggled':
        final habit = payload['habit_name'] ??
            payload['title'] ??
            payload['name'] ??
            'habit';
        final checked = payload['checked'] as bool? ?? true;
        final action =
            checked ? "checked in on '$habit'" : "unchecked '$habit'";
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: action,
          eventType: rawEvent.eventType,
          module: ActivityModule.habits,
          icon: checked
              ? Icons.check_rounded
              : Icons.radio_button_unchecked_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['habit_id'] as String? ?? payload['id'] as String?,
          targetTitle: habit.toString(),
          detailSubtitle: checked ? 'Completed check-in' : 'Unchecked check-in',
        );

      case 'habit_checkin_acknowledged':
        final habit = payload['habit_name'] ??
            payload['title'] ??
            payload['name'] ??
            'habit';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "acknowledged check-in for '$habit' 👏",
          eventType: rawEvent.eventType,
          module: ActivityModule.habits,
          icon: Icons.favorite_outline_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['habit_id'] as String? ?? payload['id'] as String?,
          targetTitle: habit.toString(),
          detailSubtitle: isLocalActor ? 'Your cheer' : '$actorName cheer',
        );

      case 'habit_archived':
      case 'habit_deleted':
        final name = payload['name'] ?? payload['title'] ?? 'habit';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "deleted habit '$name'",
          eventType: rawEvent.eventType,
          module: ActivityModule.habits,
          icon: Icons.delete_outline_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['habit_id'] as String? ?? payload['id'] as String?,
          targetTitle: name.toString(),
          detailSubtitle: 'Removed habit',
        );

      // --- CALENDAR ---
      case 'calendar_event_added':
        final title = payload['title'] ?? 'event';
        String? detailSub;
        if (payload['start_time'] != null) {
          final start = DateTime.tryParse(payload['start_time'] as String);
          if (start != null) {
            detailSub =
                DateFormat('EEE, MMM d • h:mm a').format(start.toLocal());
          }
        }
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "scheduled '$title'",
          eventType: rawEvent.eventType,
          module: ActivityModule.calendar,
          icon: Icons.calendar_today_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: title.toString(),
          detailSubtitle: detailSub,
        );

      case 'calendar_event_updated':
        final title = payload['title'] ?? 'event';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "updated event '$title'",
          eventType: rawEvent.eventType,
          module: ActivityModule.calendar,
          icon: Icons.edit_calendar_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: title.toString(),
          detailSubtitle: 'Schedule updated',
        );

      case 'calendar_event_deleted':
        final title = payload['title'] ?? 'event';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "removed event '$title'",
          eventType: rawEvent.eventType,
          module: ActivityModule.calendar,
          icon: Icons.event_busy_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          entityId: payload['id'] as String?,
          targetTitle: title.toString(),
          detailSubtitle: 'Removed from calendar',
        );

      // --- HOME / MEMBERS ---
      case 'member_profile_updated':
        final displayName = payload['display_name'] as String?;
        final actionDesc = isLocalActor
            ? (displayName != null
                ? "updated your display name to '$displayName'"
                : 'updated your profile details')
            : (displayName != null
                ? "updated their display name to '$displayName'"
                : 'updated profile details');
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: actionDesc,
          eventType: rawEvent.eventType,
          module: ActivityModule.all,
          icon: Icons.person_outline,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          targetTitle: displayName ?? 'Profile',
        );

      case 'home_currency_updated':
        final currency = payload['currency'] as String? ?? 'USD';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "changed home currency to '$currency'",
          eventType: rawEvent.eventType,
          module: ActivityModule.all,
          icon: Icons.currency_exchange_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          targetTitle: 'Home Currency',
        );

      case 'member_joined':
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: 'joined the Home',
          eventType: rawEvent.eventType,
          module: ActivityModule.all,
          icon: Icons.person_add_outlined,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          targetTitle: 'Household Member',
        );

      case 'home_created':
        final name = payload['name'] ?? 'Our Home';
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "created the Home '$name'",
          eventType: rawEvent.eventType,
          module: ActivityModule.all,
          icon: Icons.home_outlined,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
          targetTitle: name.toString(),
        );

      default:
        return FormattedActivityItem(
          id: rawEvent.id,
          homeId: rawEvent.homeId,
          actorId: rawEvent.actorId,
          actorName: actorName,
          actionText: "updated ${rawEvent.eventType.replaceAll('_', ' ')}",
          eventType: rawEvent.eventType,
          module: ActivityModule.all,
          icon: Icons.update_rounded,
          timestamp: rawEvent.createdAt,
          timeAgo: timeAgo,
          syncStatus: syncStatus,
          isPrivate: rawEvent.isPrivate,
          isLocalActor: isLocalActor,
          rawPayload: payload,
        );
    }
  }

  static String formatTimeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 45) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dt);
    }
  }

  static String formatDateHeading(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;

    if (diff == 0) {
      return 'Today';
    } else if (diff == 1) {
      return 'Yesterday';
    } else if (diff > 1 && diff < 7) {
      return 'Earlier this week';
    } else {
      return DateFormat('MMMM yyyy').format(dt);
    }
  }
}
