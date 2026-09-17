import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../habits/habit_streak_calculator.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import 'today_models.dart';

final todayDataProvider = Provider<TodayData>((ref) {
  final homeId = ref.watch(activeHomeIdProvider);
  if (homeId == null) return TodayData.empty();

  final user = ref.watch(authProvider).value;
  final currentUserId = user?.id ?? '';
  final userProfile = ref.watch(userProfileProvider);
  final effectiveUserName = userProfile.displayName.trim().isNotEmpty
      ? userProfile.displayName.trim()
      : (user?.displayName?.trim().isNotEmpty == true
          ? user!.displayName!.trim()
          : '');
  final firstName = effectiveUserName.split(' ').firstOrNull ?? '';

  final partnerProfile = ref.watch(partnerProfileProvider);
  final partnerName = partnerProfile.displayName;
  final hasPartner = ref.watch(activeHomeHasPartnerProvider);
  final currency = ref.watch(currencyPreferenceProvider);

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
  final todayString = DateFormat('yyyy-MM-dd').format(now);

  final calendarEvents = ref.watch(activeHomeCalendarEventsProvider).value ?? [];
  final subscriptions = ref.watch(activeHomeSubscriptionsProvider).value ?? [];
  final habits = ref.watch(activeHomeHabitsProvider).value ?? [];
  final allCheckins = ref.watch(activeHomeAllHabitCheckinsProvider).value ?? [];
  final lists = ref.watch(activeHomeListsProvider).value ?? [];
  final allListItems = ref.watch(activeHomeAllListItemsProvider).value ?? [];
  final expenses = ref.watch(activeHomeExpensesProvider).value ?? [];

  // --- 1. Today's Events & Renewals ---
  final events = <TodayEventItem>[];

  for (final ev in calendarEvents) {
    final evStart = ev.startTime;
    final evEnd = ev.endTime;
    final fallsOnToday = (evStart.isAfter(startOfToday.subtract(const Duration(seconds: 1))) &&
            evStart.isBefore(endOfToday.add(const Duration(seconds: 1)))) ||
        (evStart.isBefore(startOfToday) && evEnd.isAfter(startOfToday));

    if (fallsOnToday) {
      final timeStr = ev.isAllDay ? 'All Day' : DateFormat('h:mm a').format(evStart);
      events.add(TodayEventItem(
        id: ev.id,
        title: ev.title,
        startTime: evStart,
        endTime: evEnd,
        isAllDay: ev.isAllDay,
        location: ev.location,
        subtitle: ev.location?.isNotEmpty == true ? '$timeStr · ${ev.location}' : timeStr,
        isSubscription: false,
      ));
    }
  }

  for (final sub in subscriptions) {
    if (sub.isActive && !sub.isPrivate) {
      final billing = sub.nextBillingDate;
      if (billing.year == now.year && billing.month == now.month && billing.day == now.day) {
        final amt = '${currency.symbol}${formatCoveAmount(sub.amount)}';
        events.add(TodayEventItem(
          id: sub.id,
          title: sub.name,
          startTime: startOfToday,
          isAllDay: true,
          isSubscription: true,
          amountFormatted: amt,
          subtitle: 'Commitment renewal · $amt',
        ));
      }
    }
  }

  events.sort((a, b) {
    if (a.isAllDay && !b.isAllDay) return -1;
    if (!a.isAllDay && b.isAllDay) return 1;
    return a.startTime.compareTo(b.startTime);
  });

  // --- 2. Today's Habits ---
  final todayHabits = <TodayHabitItem>[];
  for (final h in habits) {
    if (h.isArchived) continue;

    final userChecked = allCheckins.any((c) =>
        c.habitId == h.id &&
        c.memberId == currentUserId &&
        c.checkinDate == todayString);

    final partnerChecked = allCheckins.any((c) =>
        c.habitId == h.id &&
        c.memberId != currentUserId &&
        c.checkinDate == todayString);

    final streak = HabitStreakCalculator.calculate(
      habit: h,
      checkins: allCheckins,
      referenceDate: now,
      currentUserId: h.createdBy,
    );

    final isPrivate = h.targetDaysPerWeek < 0;

    todayHabits.add(TodayHabitItem(
      habit: h,
      habitId: h.id,
      habitName: h.name,
      userCheckedInToday: userChecked,
      partnerCheckedInToday: partnerChecked,
      partnerAcknowledged: false,
      streak: streak.currentStreak,
      isPrivate: isPrivate,
      isOwnedByCurrentUser: h.createdBy == currentUserId,
    ));
  }

  // --- 3. Focus Tasks from Lists ---
  final focusTasks = <TodayListItem>[];
  final validLists = lists.where((l) => !l.isArchived).toList();
  final validListIds = validLists.map((l) => l.id).toSet();
  final listMap = {for (final l in validLists) l.id: l.name};

  // Strictly filter out any tasks whose parent list was deleted or archived
  final uncompletedItems = allListItems
      .where((i) => !i.isCompleted && validListIds.contains(i.listId))
      .toList();
  for (final item in uncompletedItems.take(5)) {
    focusTasks.add(TodayListItem(
      item: item,
      id: item.id,
      title: item.title,
      listId: item.listId,
      listName: listMap[item.listId] ?? 'List',
      isCompleted: item.isCompleted,
    ));
  }

  // --- 4. Today's Expenses ---
  final todayExpensesList = <TodayExpenseItem>[];
  double spendTotal = 0.0;

  for (final exp in expenses) {
    final expDate = exp.expenseDate;
    if (expDate.year == now.year && expDate.month == now.month && expDate.day == now.day) {
      final isMine = exp.paidBy == currentUserId;
      final payer = isMine ? 'You' : partnerName;
      spendTotal += exp.amount;

      todayExpensesList.add(TodayExpenseItem(
        id: exp.id,
        title: exp.title,
        amount: exp.amount,
        category: exp.category ?? 'General',
        paymentMethod: exp.paymentMethod,
        payerName: payer,
        isCurrentUser: isMine,
        expenseDate: expDate,
      ));
    }
  }

  todayExpensesList.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

  // --- 5. Serene Morning Quote ---
  final quotes = const [
    'Two lives. One calm rhythm.',
    'A quiet start, a steady step together.',
    'Clear minds, light hearts, one day at a time.',
    'Today is an open canvas for the two of you.',
    'Gentle mornings create peaceful days.',
    'Shared moments weave our sanctuary.',
    'Breathe in ease. Step into today with joy.',
  ];
  final quoteIndex = now.day % quotes.length;

  return TodayData(
    events: events,
    habits: todayHabits,
    focusTasks: focusTasks,
    todayExpenses: todayExpensesList,
    todaySpendTotal: spendTotal,
    userName: firstName,
    partnerName: partnerName,
    hasPartner: hasPartner,
    morningQuote: quotes[quoteIndex],
  );
});
