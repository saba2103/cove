import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../activity/activity_formatter.dart';
import '../activity/activity_models.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../subscriptions/commitment_models.dart';
import 'dashboard_models.dart';
import '../../core/utils/cove_currency_formatter.dart';

String _formatDateBadge(DateTime date, int daysDiff) {
  if (daysDiff == 0) return 'TODAY';
  if (daysDiff == 1) return 'TOMORROW';
  return DateFormat('EEE, MMM d').format(date).toUpperCase();
}

final dashboardDataProvider = Provider<DashboardData>((ref) {
  final homeId = ref.watch(activeHomeIdProvider);
  if (homeId == null) return DashboardData.empty();

  final currency = ref.watch(currencyPreferenceProvider);
  final user = ref.watch(authProvider).value;
  final currentUserId = user?.id ?? '';

  final expenses = ref.watch(activeHomeExpensesProvider).value ?? [];
  final subscriptions = ref.watch(activeHomeSubscriptionsProvider).value ?? [];
  final calendarEvents = ref.watch(activeHomeCalendarEventsProvider).value ?? [];
  final lists = ref.watch(activeHomeListsProvider).value ?? [];
  final allListItems = ref.watch(activeHomeAllListItemsProvider).value ?? [];
  final habits = ref.watch(activeHomeHabitsProvider).value ?? [];
  final allCheckins = ref.watch(activeHomeAllHabitCheckinsProvider).value ?? [];

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final todayString = DateFormat('yyyy-MM-dd').format(now);

  // 1. Shared Expenses Total (current month, non-private)
  double sharedExpensesTotal = 0.0;
  for (final exp in expenses) {
    if (exp.expenseDate.year == now.year && exp.expenseDate.month == now.month) {
      sharedExpensesTotal += exp.amount;
    }
  }

  // 2. Upcoming Items (calendar events + subscriptions within next 14 days)
  final upcoming = <DashboardUpcomingItem>[];

  for (final event in calendarEvents) {
    final eventStart = event.startTime;
    if (eventStart.isAfter(startOfToday.subtract(const Duration(seconds: 1)))) {
      final daysDiff = DateTime(eventStart.year, eventStart.month, eventStart.day)
          .difference(startOfToday)
          .inDays;
      final badge = _formatDateBadge(eventStart, daysDiff);
      final timeStr = DateFormat('h:mm a').format(eventStart);
      final detail = event.description ?? event.location;

      upcoming.add(DashboardUpcomingItem(
        id: event.id,
        title: event.title,
        date: eventStart,
        dateBadge: badge,
        subtitle: detail?.isNotEmpty == true ? '$timeStr · $detail' : timeStr,
        isSubscription: false,
        icon: Icons.calendar_today_outlined,
      ));
    }
  }

  for (final sub in subscriptions) {
    if (sub.isActive && !sub.isPrivate) {
      final billingDate = sub.nextBillingDate;
      if (billingDate.isAfter(startOfToday.subtract(const Duration(seconds: 1)))) {
        final daysDiff = DateTime(billingDate.year, billingDate.month, billingDate.day)
            .difference(startOfToday)
            .inDays;
        final badge = _formatDateBadge(billingDate, daysDiff);
        final amt = '${currency.symbol}${formatCoveAmount(sub.amount)}${formatBillingCycleSuffix(sub.billingCycle)}';

        upcoming.add(DashboardUpcomingItem(
          id: sub.id,
          title: sub.name,
          date: billingDate,
          dateBadge: badge,
          subtitle: 'from Commitments',
          isSubscription: true,
          amountFormatted: amt,
          icon: Icons.subscriptions_outlined,
        ));
      }
    }
  }

  upcoming.sort((a, b) => a.date.compareTo(b.date));
  final limitedUpcoming = upcoming.take(3).toList();

  // 3. Lists Summary
  final listsSummary = <DashboardListSummary>[];
  for (final list in lists) {
    if (!list.isArchived) {
      final openCount = allListItems.where((i) => i.listId == list.id && !i.isCompleted).length;
      listsSummary.add(DashboardListSummary(
        listId: list.id,
        name: list.name,
        openCount: openCount,
      ));
    }
  }

  // 4. Habits Status Today
  final habitsStatus = <DashboardHabitStatus>[];
  for (final habit in habits) {
    if (!habit.isArchived) {
      final userChecked = allCheckins.any((c) =>
          c.habitId == habit.id &&
          c.memberId == currentUserId &&
          c.checkinDate == todayString);

      final partnerChecked = allCheckins.any((c) =>
          c.habitId == habit.id &&
          c.memberId != currentUserId &&
          c.checkinDate == todayString);

      habitsStatus.add(DashboardHabitStatus(
        habitId: habit.id,
        habitName: habit.name,
        userCheckedInToday: userChecked,
        partnerCheckedInToday: partnerChecked,
      ));
    }
  }

  return DashboardData(
    sharedExpensesTotal: sharedExpensesTotal,
    upcomingItems: limitedUpcoming,
    listsSummary: listsSummary,
    habitsStatus: habitsStatus,
    recentActivity: const [],
  );
});

final dashboardRecentActivityProvider =
    StreamProvider<List<FormattedActivityItem>>((ref) {
  final homeId = ref.watch(activeHomeIdProvider);
  if (homeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  final user = ref.watch(authProvider).value;
  final partnerName = ref.watch(partnerProfileProvider).displayName;
  final currency = ref.watch(currencyPreferenceProvider);

  return db
      .watchActivityEvents(
        homeId,
        currentUserId: user?.id,
        limit: 4,
      )
      .map((rows) {
        return rows.map((r) {
          return ActivityFormatter.format(
            rawEvent: r,
            currentUserId: user?.id,
            partnerName: partnerName,
            preferredCurrencySymbol: currency.symbol,
          );
        }).toList();
      });
});
