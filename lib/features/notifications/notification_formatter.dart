import 'package:intl/intl.dart';
import '../activity/activity_formatter.dart';
import 'notification_models.dart';

class NotificationFormatter {
  /// Resolves currency symbol, defaulting to '$' or fallbackSymbol.
  static String getCurrencySymbol(String? code, {String? fallbackSymbol}) {
    return ActivityFormatter.getCurrencySymbol(code, fallbackSymbol: fallbackSymbol);
  }

  /// Formats currency with commas and 2 decimals: e.g. ₹1,250.00
  static String formatAmount(double amount, String? currencyCode, {String? fallbackSymbol}) {
    final sym = getCurrencySymbol(currencyCode, fallbackSymbol: fallbackSymbol);
    final formattedNum = NumberFormat('#,##0.00').format(amount);
    return '$sym$formattedNum';
  }

  /// Enriches an activity event into a clear, detailed title and body.
  static ({String title, String body}) format({
    required String eventType,
    required Map<String, dynamic> payload,
    String? actorName,
    String? homeName,
    String? preferredCurrencySymbol,
  }) {
    final name = (actorName != null &&
            actorName.trim().isNotEmpty &&
            actorName.trim() != 'Partner')
        ? actorName.trim()
        : ((payload['actor_name'] is String &&
                (payload['actor_name'] as String).trim().isNotEmpty &&
                (payload['actor_name'] as String).trim() != 'Partner')
            ? (payload['actor_name'] as String).trim()
            : ((payload['display_name'] is String &&
                    (payload['display_name'] as String).trim().isNotEmpty &&
                    (payload['display_name'] as String).trim() != 'Partner')
                ? (payload['display_name'] as String).trim()
                : (actorName ?? 'Partner')));
    final module = CoveNotificationPayload.moduleForEventType(eventType);

    switch (eventType) {
      // ==========================
      // EXPENSES
      // ==========================
      case 'expense_logged': {
        final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
        final currency = payload['currency'] as String?;
        final formattedAmt = formatAmount(amount, currency, fallbackSymbol: preferredCurrencySymbol);
        final title = payload['title'] as String?;
        final category = payload['category'] as String?;
        final pmRaw = payload['payment_method'] as String?;
        final pmUpper = (pmRaw != null && pmRaw.trim().isNotEmpty)
            ? pmRaw.trim().toUpperCase()
            : null;

        String detail;
        if (title != null && title.trim().isNotEmpty) {
          final cleanTitle = title.trim();
          if (category != null && category.trim().isNotEmpty) {
            final cleanCat = category.trim();
            final pmPart = pmUpper != null ? ' • $pmUpper' : '';
            detail = "Logged $formattedAmt for '$cleanTitle' ($cleanCat$pmPart)";
          } else if (pmUpper != null) {
            detail = "Logged $formattedAmt for '$cleanTitle' ($pmUpper)";
          } else {
            detail = "Logged $formattedAmt for '$cleanTitle'";
          }
        } else if (category != null && category.trim().isNotEmpty) {
          final cleanCat = category.trim();
          final pmPart = pmUpper != null ? ' • $pmUpper' : '';
          detail = "Logged $formattedAmt under $cleanCat$pmPart";
        } else {
          final pmPart = pmUpper != null ? ' via $pmUpper' : '';
          detail = "Logged an expense of $formattedAmt$pmPart";
        }

        return (
          title: '$name • Expenses',
          body: detail,
        );
      }

      case 'expense_updated': {
        final title = payload['title'] as String? ?? 'Expense';
        final amount = (payload['amount'] as num?)?.toDouble();
        final currency = payload['currency'] as String?;
        final amtStr = amount != null
            ? ' (${formatAmount(amount, currency, fallbackSymbol: preferredCurrencySymbol)})'
            : '';
        return (
          title: '$name • Expenses',
          body: "Updated expense '$title'$amtStr",
        );
      }

      case 'expense_deleted': {
        final title = payload['title'] as String? ?? 'Expense';
        final amount = (payload['amount'] as num?)?.toDouble();
        final currency = payload['currency'] as String?;
        final amtStr = amount != null
            ? ' (${formatAmount(amount, currency, fallbackSymbol: preferredCurrencySymbol)})'
            : '';
        return (
          title: '$name • Expenses',
          body: "Removed expense '$title'$amtStr",
        );
      }

      // ==========================
      // SHARED LISTS
      // ==========================
      case 'list_item_added': {
        final item = payload['title'] ?? payload['name'] ?? 'an item';
        final listName = payload['list_name'] as String?;
        if (listName != null && listName.trim().isNotEmpty) {
          return (
            title: '$name • ${listName.trim()}',
            body: "Added '$item' to ${listName.trim()}",
          );
        }
        return (
          title: '$name • Shared Lists',
          body: "Added '$item' to shared lists",
        );
      }

      case 'list_item_toggled': {
        final item = payload['title'] ?? payload['name'] ?? 'an item';
        final isCompleted = payload['is_completed'] as bool? ?? true;
        final verb = isCompleted ? 'Completed' : 'Unchecked';
        final listName = payload['list_name'] as String?;
        if (listName != null && listName.trim().isNotEmpty) {
          return (
            title: '$name • ${listName.trim()}',
            body: "$verb '$item' in ${listName.trim()}",
          );
        }
        return (
          title: '$name • Shared Lists',
          body: "$verb '$item'",
        );
      }

      case 'list_item_deleted': {
        final item = payload['title'] ?? payload['name'] ?? 'an item';
        final listName = payload['list_name'] as String?;
        if (listName != null && listName.trim().isNotEmpty) {
          return (
            title: '$name • ${listName.trim()}',
            body: "Removed '$item' from ${listName.trim()}",
          );
        }
        return (
          title: '$name • Shared Lists',
          body: "Removed '$item' from shared lists",
        );
      }

      case 'list_created': {
        final listName = payload['name'] ?? payload['title'] ?? 'New List';
        return (
          title: '$name • Shared Lists',
          body: "Created new shared list '$listName'",
        );
      }

      case 'list_completed_cleared': {
        final listName = payload['list_name'] as String? ?? 'Shared Lists';
        return (
          title: '$name • $listName',
          body: "Cleared all completed items in $listName",
        );
      }

      // ==========================
      // HABITS & RHYTHMS
      // ==========================
      case 'habit_checkin_toggled': {
        final habit = payload['habit_name'] ??
            payload['name'] ??
            payload['title'] ??
            'Habit';
        final checked = payload['checked'] as bool? ?? true;
        final streak = payload['streak'] as int?;
        final streakText = (checked && streak != null && streak > 1)
            ? ' ($streak-day streak! 🔥)'
            : ' ✨';

        return (
          title: '$name • Habits',
          body: checked
              ? "Checked in on '$habit'$streakText"
              : "Unchecked '$habit'",
        );
      }

      case 'habit_checkin_acknowledged': {
        final habit = payload['habit_name'] ??
            payload['name'] ??
            payload['title'] ??
            'Habit';
        return (
          title: '$name • Habits',
          body: "Acknowledged your check-in on '$habit'! 🙌",
        );
      }

      case 'habit_created': {
        final habit = payload['name'] ?? payload['title'] ?? 'Habit';
        return (
          title: '$name • Habits',
          body: "Created new daily rhythm '$habit'",
        );
      }

      case 'habit_deleted': {
        final habit = payload['name'] ?? payload['title'] ?? 'Habit';
        return (
          title: '$name • Habits',
          body: "Removed rhythm '$habit'",
        );
      }

      // ==========================
      // SHARED CALENDAR
      // ==========================
      case 'calendar_event_added': {
        final title = payload['title'] ?? 'Event';
        String timeStr = '';
        if (payload['start_time'] != null) {
          final dt = DateTime.tryParse(payload['start_time'].toString());
          if (dt != null) {
            timeStr = ' for ${DateFormat('EEE, MMM d • h:mm a').format(dt.toLocal())}';
          }
        }
        return (
          title: '$name • Calendar',
          body: "Scheduled '$title'$timeStr",
        );
      }

      case 'calendar_event_updated': {
        final title = payload['title'] ?? 'Event';
        return (
          title: '$name • Calendar',
          body: "Updated calendar event '$title'",
        );
      }

      case 'calendar_event_deleted': {
        final title = payload['title'] ?? 'Event';
        return (
          title: '$name • Calendar',
          body: "Removed calendar event '$title'",
        );
      }

      // ==========================
      // COMMITMENTS (SUBSCRIPTIONS)
      // ==========================
      case 'subscription_added': {
        final subName = payload['name'] ?? 'Commitment';
        final isEmi = payload['end_date'] != null;
        final kind = isEmi ? 'EMI' : 'subscription';
        final amount = (payload['amount'] as num?)?.toDouble();
        final cycle = payload['billing_cycle'] as String? ?? 'monthly';
        final currency = payload['currency'] as String?;
        final costStr = amount != null
            ? ' (${formatAmount(amount, currency, fallbackSymbol: preferredCurrencySymbol)} / $cycle)'
            : '';

        return (
          title: '$name • Commitments',
          body: "Added $kind '$subName'$costStr",
        );
      }

      case 'subscription_updated': {
        final subName = payload['name'] ?? 'Commitment';
        return (
          title: '$name • Commitments',
          body: "Updated subscription '$subName'",
        );
      }

      case 'subscription_cancelled': {
        final subName = payload['name'] ?? 'Commitment';
        return (
          title: '$name • Commitments',
          body: "Cancelled subscription '$subName'",
        );
      }

      case 'subscription_reactivated': {
        final subName = payload['name'] ?? 'Commitment';
        return (
          title: '$name • Commitments',
          body: "Reactivated subscription '$subName'",
        );
      }

      // ==========================
      // HOME & PROFILE
      // ==========================
      case 'member_profile_updated': {
        final newName = payload['display_name'] as String? ?? name;
        return (
          title: 'Cove • Profile',
          body: "$newName updated their profile display name",
        );
      }

      case 'home_currency_updated': {
        final curr = payload['currency'] as String? ?? 'USD';
        final sym = getCurrencySymbol(curr);
        return (
          title: '$name • Home Settings',
          body: "Changed home currency to $curr ($sym)",
        );
      }

      case 'member_joined': {
        final hName = homeName != null && homeName.isNotEmpty
            ? ' $homeName'
            : ' your Home';
        return (
          title: 'Cove • Home',
          body: "$name joined$hName!",
        );
      }

      case 'home_created': {
        final hName = homeName != null && homeName.isNotEmpty
            ? ' $homeName'
            : ' a new Home';
        return (
          title: 'Cove • Home',
          body: "$name created$hName",
        );
      }

      default: {
        return (
          title: '$name • ${module.displayName}',
          body: CoveNotificationPayload.genericMessageForEventType(eventType),
        );
      }
    }
  }
}
