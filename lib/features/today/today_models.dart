import 'package:flutter/foundation.dart';
import '../../sync/db/app_database.dart';

@immutable
class TodayEventItem {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isAllDay;
  final String? location;
  final bool isSubscription;
  final String? amountFormatted;
  final String? subtitle;
  final String owner;

  const TodayEventItem({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.isAllDay = false,
    this.location,
    this.isSubscription = false,
    this.amountFormatted,
    this.subtitle,
    this.owner = 'both',
  });
}

@immutable
class TodayHabitItem {
  final LocalHabit habit;
  final String habitId;
  final String habitName;
  final bool userCheckedInToday;
  final bool partnerCheckedInToday;
  final bool partnerAcknowledged;
  final int streak;
  final bool isPrivate;
  final bool isOwnedByCurrentUser;

  const TodayHabitItem({
    required this.habit,
    required this.habitId,
    required this.habitName,
    required this.userCheckedInToday,
    required this.partnerCheckedInToday,
    required this.partnerAcknowledged,
    required this.streak,
    required this.isPrivate,
    required this.isOwnedByCurrentUser,
  });
}

@immutable
class TodayListItem {
  final LocalListItem item;
  final String id;
  final String title;
  final String listId;
  final String listName;
  final bool isCompleted;

  const TodayListItem({
    required this.item,
    required this.id,
    required this.title,
    required this.listId,
    required this.listName,
    required this.isCompleted,
  });
}

@immutable
class TodayExpenseItem {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String? paymentMethod;
  final String payerName;
  final bool isCurrentUser;
  final DateTime expenseDate;

  const TodayExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.paymentMethod,
    required this.payerName,
    required this.isCurrentUser,
    required this.expenseDate,
  });
}

@immutable
class TodayListSummary {
  final String listId;
  final String name;
  final int openCount;

  const TodayListSummary({
    required this.listId,
    required this.name,
    required this.openCount,
  });
}

@immutable
class TodayData {
  final List<TodayEventItem> events;
  final int eventsOnlyCount;
  final List<TodayHabitItem> habits;
  final List<TodayListItem> focusTasks;
  final List<TodayListSummary> listsSummary;
  final List<TodayExpenseItem> todayExpenses;
  final double todaySpendTotal;
  final double sharedMonthExpensesTotal;
  final String userName;
  final String partnerName;
  final bool hasPartner;
  final String morningQuote;

  /// Total open (uncompleted) list items across all active lists.
  ///
  /// [focusTasks] is capped at 5 for the preview card, whereas [openTasksCount]
  /// reflects the true open count for the "The list" metric tile and readout.
  final int openTasksCount;

  TodayData({
    required this.events,
    required this.eventsOnlyCount,
    required this.habits,
    required this.focusTasks,
    int? openTasksCount,
    required this.listsSummary,
    required this.todayExpenses,
    required this.todaySpendTotal,
    required this.sharedMonthExpensesTotal,
    required this.userName,
    required this.partnerName,
    required this.hasPartner,
    required this.morningQuote,
  }) : openTasksCount =
           openTasksCount ??
           (listsSummary.isNotEmpty
               ? listsSummary.fold<int>(0, (sum, l) => sum + l.openCount)
               : focusTasks.where((t) => !t.isCompleted).length);

  factory TodayData.empty() {
    return TodayData(
      events: const [],
      eventsOnlyCount: 0,
      habits: const [],
      focusTasks: const [],
      openTasksCount: 0,
      listsSummary: const [],
      todayExpenses: const [],
      todaySpendTotal: 0.0,
      sharedMonthExpensesTotal: 0.0,
      userName: '',
      partnerName: 'Partner',
      hasPartner: false,
      morningQuote: 'Two lives. One calm habit.',
    );
  }
}
