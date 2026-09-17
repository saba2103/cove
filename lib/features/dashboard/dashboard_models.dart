import 'package:flutter/material.dart';
import '../activity/activity_models.dart';

class DashboardUpcomingItem {
  final String id;
  final String title;
  final DateTime date;
  final String dateBadge; // e.g. "TODAY", "TOMORROW", "FRI, SEP 12"
  final String subtitle;
  final bool isSubscription;
  final String? amountFormatted;
  final IconData icon;

  const DashboardUpcomingItem({
    required this.id,
    required this.title,
    required this.date,
    required this.dateBadge,
    required this.subtitle,
    required this.isSubscription,
    this.amountFormatted,
    required this.icon,
  });
}

class DashboardHabitStatus {
  final String habitId;
  final String habitName;
  final bool userCheckedInToday;
  final bool partnerCheckedInToday;

  const DashboardHabitStatus({
    required this.habitId,
    required this.habitName,
    required this.userCheckedInToday,
    required this.partnerCheckedInToday,
  });
}

class DashboardListSummary {
  final String listId;
  final String name;
  final int openCount;

  const DashboardListSummary({
    required this.listId,
    required this.name,
    required this.openCount,
  });
}

class DashboardData {
  final double sharedExpensesTotal;
  final List<DashboardUpcomingItem> upcomingItems;
  final List<DashboardListSummary> listsSummary;
  final List<DashboardHabitStatus> habitsStatus;
  final List<FormattedActivityItem> recentActivity;

  const DashboardData({
    required this.sharedExpensesTotal,
    required this.upcomingItems,
    required this.listsSummary,
    required this.habitsStatus,
    required this.recentActivity,
  });

  factory DashboardData.empty() {
    return const DashboardData(
      sharedExpensesTotal: 0.0,
      upcomingItems: [],
      listsSummary: [],
      habitsStatus: [],
      recentActivity: [],
    );
  }
}
