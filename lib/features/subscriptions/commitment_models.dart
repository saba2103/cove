import '../../sync/db/app_database.dart';

class EmiProgress {
  final int paidInstallments;
  final int totalInstallments;
  final bool isFinished;

  const EmiProgress({
    required this.paidInstallments,
    required this.totalInstallments,
    required this.isFinished,
  });

  String get caption => '$paidInstallments/$totalInstallments paid';
}

/// Parses the number of months represented by a billing cycle string.
/// Handles standard ('monthly', 'annual', 'quarterly') and custom formats
/// (e.g. 'every_7_months', 'custom_7', '7_months', '7').
int getBillingCycleMonths(String cycle) {
  final lower = cycle.toLowerCase().trim();
  if (lower == 'monthly' || lower == 'month') return 1;
  if (lower == 'annual' || lower == 'yearly' || lower == 'year') return 12;
  if (lower == 'quarterly') return 3;
  if (lower == 'biannual' || lower == 'semi-annual') return 6;
  final match = RegExp(r'\d+').firstMatch(lower);
  if (match != null) {
    final n = int.tryParse(match.group(0)!);
    if (n != null && n > 0) return n;
  }
  return 1;
}

/// Checks if a billing cycle represents a custom (non-standard 1 or 12 month) duration.
bool isCustomBillingCycle(String cycle) {
  final lower = cycle.toLowerCase().trim();
  if (lower == 'monthly' || lower == 'month' || lower == 'annual' || lower == 'yearly' || lower == 'year') {
    return false;
  }
  final months = getBillingCycleMonths(cycle);
  return months != 1 && months != 12;
}

/// Formats a billing cycle string for human-readable display (e.g. 'Monthly', 'Annual', 'Every 7 months').
String formatBillingCycleLabel(String cycle) {
  final lower = cycle.toLowerCase().trim();
  if (lower == 'monthly' || lower == 'month') return 'Monthly';
  if (lower == 'annual' || lower == 'yearly' || lower == 'year') return 'Annual';
  if (lower == 'quarterly') return 'Quarterly';
  final months = getBillingCycleMonths(cycle);
  if (months == 1) return 'Monthly';
  if (months == 12) return 'Annual';
  return 'Every $months months';
}

/// Formats a billing cycle suffix for amount display (e.g. '/mo', '/yr', '/7mo').
String formatBillingCycleSuffix(String cycle) {
  final lower = cycle.toLowerCase().trim();
  if (lower == 'monthly' || lower == 'month') return '/mo';
  if (lower == 'annual' || lower == 'yearly' || lower == 'year') return '/yr';
  final months = getBillingCycleMonths(cycle);
  if (months == 1) return '/mo';
  if (months == 12) return '/yr';
  return '/${months}mo';
}

EmiProgress calculateEmiProgress({
  required DateTime startDate,
  required DateTime endDate,
  required String billingCycle,
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final monthsPerCycle = getBillingCycleMonths(billingCycle);

  final start = DateTime(startDate.year, startDate.month, startDate.day);
  final end = DateTime(endDate.year, endDate.month, endDate.day);
  final today = DateTime(current.year, current.month, current.day);

  int totalMonths = (end.year - start.year) * 12 + (end.month - start.month);
  if (end.day > start.day) {
    totalMonths += 1;
  }
  if (totalMonths <= 0) totalMonths = 1;

  final totalCycles = (totalMonths / monthsPerCycle).ceil();
  final total = totalCycles > 0 ? totalCycles : 1;

  int elapsedMonths = (today.year - start.year) * 12 + (today.month - start.month);
  if (today.day >= start.day) {
    elapsedMonths += 1;
  }
  if (elapsedMonths < 0) elapsedMonths = 0;

  final elapsedCycles = (elapsedMonths / monthsPerCycle).floor();
  final paid = elapsedCycles.clamp(0, total);
  final isDone = paid >= total || today.isAfter(end) || today.isAtSameMomentAs(end);

  return EmiProgress(
    paidInstallments: paid,
    totalInstallments: total,
    isFinished: isDone,
  );
}

extension LocalSubscriptionCommitmentX on LocalSubscription {
  /// Classification is implicit from endDate or totalInstallments:
  /// - null: Subscription (open-ended)
  /// - non-null: EMI (finite installments)
  bool get isEmi => endDate != null || (totalInstallments != null && totalInstallments! > 0);

  String get commitmentTypeBadge => isEmi ? 'EMI' : 'Sub';

  EmiProgress? get emiProgress {
    if (!isEmi) return null;

    if (totalInstallments != null && totalInstallments! > 0) {
      final total = totalInstallments!;
      int paid;
      if (paidInstallments != null) {
        paid = paidInstallments!.clamp(0, total);
      } else if (endDate != null) {
        final monthsPerCycle = getBillingCycleMonths(billingCycle);
        final today = DateTime.now();
        int remainingMonths = (endDate!.year - today.year) * 12 + (endDate!.month - today.month);
        if (endDate!.day >= today.day) remainingMonths += 1;
        if (remainingMonths < 0) remainingMonths = 0;
        final remainingCycles = (remainingMonths / monthsPerCycle).ceil();
        paid = (total - remainingCycles).clamp(0, total);
      } else {
        paid = 0;
      }
      final isDone = paid >= total;
      return EmiProgress(
        paidInstallments: paid,
        totalInstallments: total,
        isFinished: isDone,
      );
    }

    return calculateEmiProgress(
      startDate: createdAt,
      endDate: endDate!,
      billingCycle: billingCycle,
    );
  }

  bool get isEmiFinished {
    if (!isEmi) return false;
    return emiProgress?.isFinished ?? false;
  }

  String get effectivePaidBy => (paidBy != null && paidBy!.isNotEmpty)
      ? paidBy!
      : (createdBy ?? 'me');
}
