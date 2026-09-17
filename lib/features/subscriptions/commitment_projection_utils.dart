import 'dart:math';
import '../../sync/db/app_database.dart';
import 'commitment_models.dart';

/// Represents a projected commitment instance in a specific calendar month.
class ProjectedCommitmentItem {
  final LocalSubscription subscription;
  final DateTime projectedDate;
  final double amount;
  final bool isEmi;
  final bool isAnnual;

  const ProjectedCommitmentItem({
    required this.subscription,
    required this.projectedDate,
    required this.amount,
    required this.isEmi,
    required this.isAnnual,
  });

  String get id => '${subscription.id}_${projectedDate.year}_${projectedDate.month}';
  String get name => subscription.name;
  String? get category => subscription.category;
  String? get paidBy => subscription.paidBy;
}

/// Aggregated commitment stats for a single calendar month.
class MonthCommitmentSummary {
  final int year;
  final int month;
  final List<ProjectedCommitmentItem> items;

  const MonthCommitmentSummary({
    required this.year,
    required this.month,
    required this.items,
  });

  double get totalAmount => items.fold(0.0, (sum, i) => sum + i.amount);

  int get subsCount => items.where((i) => !i.isEmi).length;
  int get emisCount => items.where((i) => i.isEmi).length;

  double get subsAmount =>
      items.where((i) => !i.isEmi).fold(0.0, (sum, i) => sum + i.amount);
  double get emisAmount =>
      items.where((i) => i.isEmi).fold(0.0, (sum, i) => sum + i.amount);

  bool isPartner(LocalSubscription sub, String? currentUserId, String? partnerUserId) {
    final pb = (sub.paidBy ?? '').trim().toLowerCase();
    if (pb == 'split' || pb == '50/50') return false;
    if (pb == 'partner' || pb == 'taylor') return true;
    if (partnerUserId != null && pb == partnerUserId.toLowerCase()) return true;
    if (pb == 'partner_user') return true;
    return false;
  }

  bool isMine(LocalSubscription sub, String? currentUserId, String? partnerUserId) {
    final pb = (sub.paidBy ?? '').trim().toLowerCase();
    if (pb == 'split' || pb == '50/50') return false;
    if (isPartner(sub, currentUserId, partnerUserId)) return false;
    if (pb == 'me' || pb == 'alex') return true;
    if (currentUserId != null && pb == currentUserId.toLowerCase()) return true;
    if (pb.isEmpty) {
      return sub.createdBy == null ||
          sub.createdBy == currentUserId ||
          sub.createdBy == 'local_user';
    }
    return true;
  }

  bool isSplit(LocalSubscription sub) {
    final pb = (sub.paidBy ?? '').trim().toLowerCase();
    return pb == 'split' || pb == '50/50';
  }

  List<ProjectedCommitmentItem> filterByAttribution({
    required int tabIndex, // 0: All, 1: Mine, 2: Partner, 3: Split
    required String? currentUserId,
    required String? partnerUserId,
  }) {
    if (tabIndex == 0) return items;
    if (tabIndex == 1) {
      return items
          .where((i) => isMine(i.subscription, currentUserId, partnerUserId))
          .toList();
    }
    if (tabIndex == 2) {
      return items
          .where((i) => isPartner(i.subscription, currentUserId, partnerUserId))
          .toList();
    }
    if (tabIndex == 3) {
      return items.where((i) => isSplit(i.subscription)).toList();
    }
    return items;
  }

  double allocationMine(String? currentUserId, String? partnerUserId) {
    return items
        .where((i) => isMine(i.subscription, currentUserId, partnerUserId))
        .fold(0.0, (sum, i) => sum + i.amount);
  }

  double allocationPartner(String? currentUserId, String? partnerUserId) {
    return items
        .where((i) => isPartner(i.subscription, currentUserId, partnerUserId))
        .fold(0.0, (sum, i) => sum + i.amount);
  }

  double allocationSplit() {
    return items.where((i) => isSplit(i.subscription)).fold(0.0, (sum, i) => sum + i.amount);
  }
}

class CommitmentProjectionUtils {
  /// Projects all subscriptions and EMIs across the 12 months (1..12) of [year].
  ///
  /// - Monthly commitments and active EMIs recur in every month they are active.
  /// - Annual commitments are attributed 100% to their specific renewal month only.
  /// - Inactive subscriptions or expired EMIs are excluded.
  static Map<int, MonthCommitmentSummary> projectYear({
    required List<LocalSubscription> subscriptions,
    required int year,
  }) {
    final Map<int, List<ProjectedCommitmentItem>> monthItems = {
      for (int m = 1; m <= 12; m++) m: [],
    };

    for (final sub in subscriptions) {
      if (!sub.isActive) continue;

      final cycleMonths = getBillingCycleMonths(sub.billingCycle);
      final isAnnual = cycleMonths == 12;
      final isEmi = sub.isEmi;

      for (int m = 1; m <= 12; m++) {
        final daysInMonth = DateTime(year, m + 1, 0).day;
        final renewalDay = min(sub.nextBillingDate.day, daysInMonth);
        final projectedDate = DateTime(year, m, renewalDay);

        bool applies = false;

        if (isEmi) {
          applies = _isEmiActiveInMonth(sub, year, m);
        } else if (isAnnual) {
          // Annual commitments apply exclusively to their specific renewal month
          applies = (sub.nextBillingDate.month == m);
        } else if (cycleMonths == 1) {
          // Monthly commitments apply every month
          applies = true;
        } else {
          // Custom cycle (e.g. quarterly every 3 months, biannual every 6 months)
          final diff = (m - sub.nextBillingDate.month);
          applies = (diff % cycleMonths == 0);
        }

        if (applies) {
          monthItems[m]!.add(ProjectedCommitmentItem(
            subscription: sub,
            projectedDate: projectedDate,
            amount: sub.amount,
            isEmi: isEmi,
            isAnnual: isAnnual,
          ));
        }
      }
    }

    // Sort items in each month by day
    for (int m = 1; m <= 12; m++) {
      monthItems[m]!.sort((a, b) => a.projectedDate.day.compareTo(b.projectedDate.day));
    }

    return {
      for (int m = 1; m <= 12; m++)
        m: MonthCommitmentSummary(
          year: year,
          month: m,
          items: monthItems[m]!,
        ),
    };
  }

  /// Checks if an EMI is active during the specified month and year.
  static bool _isEmiActiveInMonth(LocalSubscription sub, int year, int month) {
    final targetMonthStart = DateTime(year, month, 1);
    final targetMonthEnd = DateTime(year, month + 1, 0);

    // 1. Check end date
    if (sub.endDate != null) {
      final endMonthStart = DateTime(sub.endDate!.year, sub.endDate!.month, 1);
      if (targetMonthStart.isAfter(endMonthStart)) {
        return false;
      }
    }

    // 2. Check total and paid installments
    if (sub.totalInstallments != null && sub.totalInstallments! > 0) {
      final total = sub.totalInstallments!;
      final paid = (sub.paidInstallments ?? 0).clamp(0, total);
      final remaining = total - paid;

      // Next billing date represents installment `paid + 1`
      final nextYear = sub.nextBillingDate.year;
      final nextMonth = sub.nextBillingDate.month;

      // The last installment month
      final lastInstallmentDate = DateTime(nextYear, nextMonth + (remaining - 1), 1);
      if (targetMonthStart.isAfter(DateTime(lastInstallmentDate.year, lastInstallmentDate.month, 1))) {
        return false;
      }

      // The first installment month
      final firstInstallmentDate = DateTime(nextYear, nextMonth - paid, 1);
      if (targetMonthEnd.isBefore(firstInstallmentDate)) {
        return false;
      }

      return true;
    }

    // 3. Fallback: if endDate was provided and target is on or before endDate
    if (sub.endDate != null) {
      final start = DateTime(sub.createdAt.year, sub.createdAt.month, 1);
      if (targetMonthEnd.isBefore(start)) {
        return false;
      }
      return true;
    }

    return true;
  }
}
