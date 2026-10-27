import 'dart:convert';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../expenses/expense_controller.dart';
import '../profile/preferences_controller.dart';
import 'commitment_models.dart';

class SubscriptionController {
  final Ref ref;

  SubscriptionController(this.ref);

  AppDatabase get _db => ref.read(appDatabaseProvider);
  String? get _activeHomeId => ref.read(activeHomeIdProvider);
  CoveUser? get _currentUser => ref.read(authProvider).value;

  /// Creates a new subscription.
  ///
  /// CRITICAL PRIVACY ARCHITECTURE:
  /// - If [isPrivate] is false (Shared):
  ///   The write goes through the sync engine's [coveEmitActionProvider],
  ///   which encrypts with the shared Home key and sends via Supabase relay.
  /// - If [isPrivate] is true (Private to me):
  ///   It writes DIRECTLY to local Drift SQLite only. It is NEVER passed to
  ///   [coveEmitActionProvider], NEVER encrypted with the Home key, and NEVER sent
  ///   over Supabase relay. The partner's device receives 0 bytes.
  Future<void> createSubscription({
    required String name,
    required double amount,
    String? currency,
    String billingCycle = 'monthly',
    required DateTime nextBillingDate,
    String? category,
    bool isPrivate = false,
    DateTime? endDate,
    String? paidBy,
    String? financedThrough,
    int? totalInstallments,
    int? paidInstallments,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final user = _currentUser;
    final userId = user?.id ?? 'local_user';
    final resolvedPaidBy = (paidBy != null && paidBy.isNotEmpty) ? paidBy : userId;
    final now = clock.now().toUtc();
    final id = _generateUuid();
    final resolvedCurrency = (currency != null && currency.isNotEmpty)
        ? currency
        : ref.read(currencyPreferenceProvider).code;

    if (isPrivate) {
      // Direct local SQLite write ONLY - zero cloud or sync knowledge!
      await _db.into(_db.localSubscriptions).insertOnConflictUpdate(
            LocalSubscriptionsCompanion.insert(
              id: id,
              homeId: homeId,
              name: name,
              amount: amount,
              currency: Value(resolvedCurrency),
              billingCycle: Value(billingCycle),
              nextBillingDate: nextBillingDate,
              category: Value(category),
              isActive: const Value(true),
              isPrivate: const Value(true),
              createdBy: Value(userId),
              createdAt: now,
              endDate: Value(endDate),
              paidBy: Value(resolvedPaidBy),
              financedThrough: Value(financedThrough),
              totalInstallments: Value(totalInstallments),
              paidInstallments: Value(paidInstallments),
            ),
          );
      await _db.recordActivityEvent(
        LocalActivityEventsCompanion.insert(
          id: 'subscription_added_${id}_${now.millisecondsSinceEpoch}',
          homeId: homeId,
          actorId: userId,
          eventType: 'subscription_added',
          payloadJson: jsonEncode({
            'id': id,
            'home_id': homeId,
            'name': name,
            'amount': amount,
            'currency': resolvedCurrency,
            'billing_cycle': billingCycle,
            'next_billing_date': nextBillingDate.toIso8601String(),
            'category': category,
            'is_active': true,
            'is_private': true,
            'created_by': userId,
            'end_date': endDate?.toIso8601String(),
            'paid_by': resolvedPaidBy,
            'financed_through': financedThrough,
            'total_installments': totalInstallments,
            'paid_installments': paidInstallments,
          }),
          createdAt: now,
          syncStatus: const Value('savedLocally'),
          isPrivate: const Value(true),
        ),
      );
    } else {
      // Shared write through Sync Engine blind relay
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'subscription_added',
        payload: {
          'id': id,
          'home_id': homeId,
          'name': name,
          'amount': amount,
          'currency': resolvedCurrency,
          'billing_cycle': billingCycle,
          'next_billing_date': nextBillingDate.toIso8601String(),
          'category': category,
          'is_active': true,
          'is_private': false,
          'created_by': userId,
          'end_date': endDate?.toIso8601String(),
          'paid_by': resolvedPaidBy,
          'financed_through': financedThrough,
          'total_installments': totalInstallments,
          'paid_installments': paidInstallments,
        },
      );
    }
  }

  /// Updates an existing subscription.
  Future<void> updateSubscription({
    required String id,
    required String name,
    required double amount,
    String? currency,
    String billingCycle = 'monthly',
    required DateTime nextBillingDate,
    String? category,
    required bool isPrivate,
    DateTime? endDate,
    String? paidBy,
    String? financedThrough,
    int? totalInstallments,
    int? paidInstallments,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');
    final user = _currentUser;
    final userId = user?.id ?? 'local_user';

    final existing = await (_db.select(_db.localSubscriptions)..where((t) => t.id.equals(id))).getSingleOrNull();
    final resolvedCurrency = (currency != null && currency.isNotEmpty)
        ? currency
        : (existing?.currency ?? ref.read(currencyPreferenceProvider).code);
    final resolvedPaidBy = paidBy ?? existing?.paidBy ?? userId;

    if (isPrivate) {
      // Direct local SQLite write only
      await (_db.update(_db.localSubscriptions)..where((t) => t.id.equals(id)))
          .write(
        LocalSubscriptionsCompanion(
          name: Value(name),
          amount: Value(amount),
          currency: Value(resolvedCurrency),
          billingCycle: Value(billingCycle),
          nextBillingDate: Value(nextBillingDate),
          category: Value(category),
          isActive: const Value(true),
          isPrivate: const Value(true),
          endDate: Value(endDate),
          paidBy: Value(resolvedPaidBy),
          financedThrough: Value(financedThrough),
          totalInstallments: Value(totalInstallments),
          paidInstallments: Value(paidInstallments),
        ),
      );
    } else {
      // Shared update via Sync Engine
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'subscription_updated',
        payload: {
          'id': id,
          'home_id': homeId,
          'name': name,
          'amount': amount,
          'currency': resolvedCurrency,
          'billing_cycle': billingCycle,
          'next_billing_date': nextBillingDate.toIso8601String(),
          'category': category,
          'is_active': true,
          'is_private': false,
          'created_by': userId,
          'end_date': endDate?.toIso8601String(),
          'paid_by': resolvedPaidBy,
          'financed_through': financedThrough,
          'total_installments': totalInstallments,
          'paid_installments': paidInstallments,
        },
      );
    }
  }

  /// Cancels/deactivates a subscription without deleting history.
  Future<void> cancelSubscription(String id, {required bool isPrivate}) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final sub = await (_db.select(_db.localSubscriptions)..where((t) => t.id.equals(id))).getSingleOrNull();

    if (isPrivate) {
      await (_db.update(_db.localSubscriptions)..where((t) => t.id.equals(id)))
          .write(const LocalSubscriptionsCompanion(isActive: Value(false)));
    } else {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'subscription_cancelled',
        payload: {
          'id': id,
          'home_id': homeId,
          if (sub != null) 'name': sub.name,
          if (sub != null) 'amount': sub.amount,
          if (sub != null) 'currency': sub.currency,
        },
      );
    }
  }

  /// Reactivates a cancelled subscription.
  Future<void> reactivateSubscription(String id, {required bool isPrivate}) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final sub = await (_db.select(_db.localSubscriptions)..where((t) => t.id.equals(id))).getSingleOrNull();

    if (isPrivate) {
      await (_db.update(_db.localSubscriptions)..where((t) => t.id.equals(id)))
          .write(const LocalSubscriptionsCompanion(isActive: Value(true)));
    } else {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'subscription_reactivated',
        payload: {
          'id': id,
          'home_id': homeId,
          if (sub != null) 'name': sub.name,
          if (sub != null) 'amount': sub.amount,
          if (sub != null) 'currency': sub.currency,
        },
      );
    }
  }

  /// Advances next billing date by 1 billing cycle, increments paid installments if EMI,
  /// completes EMI if reached total installments, and optionally records payment to Expenses.
  /// Returns the created expense ID when [logExpense] is true, or `null` otherwise.
  Future<String?> renewOrPaySubscription(
    String id, {
    required bool isPrivate,
    bool logExpense = false,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final sub = await (_db.select(_db.localSubscriptions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (sub == null) return null;

    final cycleMonths = getBillingCycleMonths(sub.billingCycle);
    final currentNext = sub.nextBillingDate.toLocal();
    final advancedNext = DateTime(
      currentNext.year,
      currentNext.month + cycleMonths,
      currentNext.day,
    );

    final isEmi = sub.endDate != null || (sub.totalInstallments != null && sub.totalInstallments! > 0);
    int? newPaid;
    bool newIsActive = sub.isActive;

    if (isEmi) {
      final total = sub.totalInstallments ?? 12;
      final currentPaid = sub.paidInstallments ?? 0;
      newPaid = currentPaid + 1;
      if (newPaid >= total) {
        newPaid = total;
        newIsActive = false; // Completed
      }
    }

    if (isPrivate) {
      await (_db.update(_db.localSubscriptions)..where((t) => t.id.equals(id))).write(
        LocalSubscriptionsCompanion(
          nextBillingDate: Value(advancedNext),
          paidInstallments: Value(newPaid),
          isActive: Value(newIsActive),
        ),
      );
    } else {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'subscription_updated',
        payload: {
          'id': id,
          'home_id': homeId,
          'name': sub.name,
          'amount': sub.amount,
          'currency': sub.currency,
          'billing_cycle': sub.billingCycle,
          'next_billing_date': advancedNext.toIso8601String(),
          'category': sub.category,
          'is_active': newIsActive,
          'is_private': false,
          'created_by': sub.createdBy,
          'end_date': sub.endDate?.toIso8601String(),
          'paid_by': sub.paidBy,
          'financed_through': sub.financedThrough,
          'total_installments': sub.totalInstallments,
          'paid_installments': newPaid,
        },
      );
    }

    if (logExpense) {
      final expenseCtrl = ref.read(expenseControllerProvider);
      final payer = sub.paidBy ?? _currentUser?.id ?? 'me';
      final isSplit = payer == 'split' || payer == '50/50' || payer == 'split_50_50';
      final visibility = isPrivate
          ? ExpenseVisibility.privateToMe
          : (isSplit ? ExpenseVisibility.shared : ExpenseVisibility.shared);

      final title = isEmi && newPaid != null
          ? '${sub.name} (EMI Installment $newPaid/${sub.totalInstallments ?? 12})'
          : '${sub.name} (Renewal)';

      return await expenseCtrl.logExpense(
        title: title,
        amount: sub.amount,
        currency: sub.currency,
        expenseDate: clock.now(),
        paidBy: isSplit ? (_currentUser?.id ?? 'me') : payer,
        category: sub.category ?? 'Utilities',
        notes: isEmi
            ? 'EMI payment via ${sub.financedThrough ?? "Commitments"}'
            : 'Recurring subscription renewal',
        visibility: visibility,
      );
    }

    return null;
  }

  /// Forecloses/precloses an EMI: marks all remaining installments as paid and marks isActive = false.
  /// Optionally logs the full payoff amount as an expense.
  /// Returns the created expense ID when [logExpense] is true, or `null` otherwise.
  Future<String?> forecloseEmi(
    String id, {
    required bool isPrivate,
    bool logExpense = false,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final sub = await (_db.select(_db.localSubscriptions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (sub == null) return null;

    final total = sub.totalInstallments ?? 12;
    final currentPaid = sub.paidInstallments ?? 0;
    final remainingInstallments = (total - currentPaid).clamp(0, total);
    final payoffAmount = remainingInstallments * sub.amount;

    if (isPrivate) {
      await (_db.update(_db.localSubscriptions)..where((t) => t.id.equals(id))).write(
        LocalSubscriptionsCompanion(
          paidInstallments: Value(total),
          isActive: const Value(false),
        ),
      );
    } else {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'subscription_updated',
        payload: {
          'id': id,
          'home_id': homeId,
          'name': sub.name,
          'amount': sub.amount,
          'currency': sub.currency,
          'billing_cycle': sub.billingCycle,
          'next_billing_date': sub.nextBillingDate.toIso8601String(),
          'category': sub.category,
          'is_active': false,
          'is_private': false,
          'created_by': sub.createdBy,
          'end_date': sub.endDate?.toIso8601String(),
          'paid_by': sub.paidBy,
          'financed_through': sub.financedThrough,
          'total_installments': total,
          'paid_installments': total,
        },
      );
    }

    if (logExpense && payoffAmount > 0) {
      final expenseCtrl = ref.read(expenseControllerProvider);
      final payer = sub.paidBy ?? _currentUser?.id ?? 'me';
      final isSplit = payer == 'split' || payer == '50/50' || payer == 'split_50_50';
      final visibility = isPrivate
          ? ExpenseVisibility.privateToMe
          : ExpenseVisibility.shared;

      return await expenseCtrl.logExpense(
        title: '${sub.name} (EMI Foreclosure Payoff)',
        amount: payoffAmount,
        currency: sub.currency,
        expenseDate: clock.now(),
        paidBy: isSplit ? (_currentUser?.id ?? 'me') : payer,
        category: sub.category ?? 'Loan',
        notes: 'Preclosed EMI with full settlement of remaining $remainingInstallments installments via ${sub.financedThrough ?? "Commitments"}',
        visibility: visibility,
      );
    }

    return null;
  }

  /// Permanently deletes a subscription.
  Future<void> deleteSubscription(String id, {required bool isPrivate}) async {
    LocalSubscription? sub;
    try {
      sub = await (_db.select(_db.localSubscriptions)..where((t) => t.id.equals(id))).getSingleOrNull();
    } catch (_) {}

    final homeId = _activeHomeId ?? sub?.homeId;
    if (homeId == null) throw StateError('No active home selected.');

    // 1. Immediately record tombstone and delete locally
    try {
      await _db.recordTombstone(id, 'subscription');
      await (_db.delete(_db.localSubscriptions)..where((t) => t.id.equals(id))).go();
    } catch (_) {}

    if (!isPrivate) {
      try {
        final emit = ref.read(coveEmitActionProvider);
        await emit(
          eventType: 'subscription_deleted',
          targetHomeId: homeId,
          payload: {
            'id': id,
            'home_id': homeId,
          },
        );
      } catch (_) {}
    }
  }

  String _generateUuid() {
    final random = clock.now().microsecondsSinceEpoch.toString();
    final hash = (random.hashCode & 0x7FFFFFFF).toRadixString(16).padLeft(8, '0');
    final p1 = (clock.now().millisecondsSinceEpoch & 0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    return '$p1-$hash-4000-8000-${clock.now().microsecond.toRadixString(16).padLeft(12, '0')}';
  }
}

final subscriptionControllerProvider = Provider<SubscriptionController>((ref) {
  return SubscriptionController(ref);
});

/// List of unique previously input financing sources (card, person, bank) across commitments in the active home.
final previousFinancingSourcesProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final homeId = ref.watch(activeHomeIdProvider);
  if (homeId == null) return const [];
  final subs = await (db.select(db.localSubscriptions)
        ..where((t) => t.homeId.equals(homeId)))
      .get();
  final set = <String>{};
  for (final s in subs) {
    final val = s.financedThrough?.trim();
    if (val != null && val.isNotEmpty) {
      set.add(val);
    }
  }
  final list = set.toList();
  list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
});

/// Returns true when [sub] is a savings / SIP commitment.
bool isSavingsCommitment(LocalSubscription sub) {
  if (sub.isEmi) return false;
  final cat = (sub.category ?? '').trim().toLowerCase();
  final name = sub.name.trim().toLowerCase();
  if (cat == 'savings' ||
      cat == 'sip' ||
      cat == 'investment' ||
      cat == 'investments' ||
      cat == 'mutual_funds' ||
      cat == 'gold_sip') {
    return true;
  }
  return name.contains('sip') ||
      name.contains('mutual fund') ||
      name.contains('savings');
}

/// Formats the relative renewal date for a commitment (`Tomorrow` / weekday / date)
/// per `design/specs/18-widgets.md` §3.
String formatCommitmentRenewalWhen(DateTime nextBillingDate, {DateTime? now}) {
  final current = (now ?? clock.now()).toLocal();
  final billingLocal = nextBillingDate.toLocal();
  final today = DateTime(current.year, current.month, current.day);
  final dueDay = DateTime(
    billingLocal.year,
    billingLocal.month,
    billingLocal.day,
  );
  final daysUntil = dueDay.difference(today).inDays;
  if (daysUntil == 0) return 'Today';
  if (daysUntil == 1) return 'Tomorrow';
  if (daysUntil >= 2 && daysUntil <= 6) {
    return DateFormat('EEEE').format(dueDay);
  }
  return DateFormat('d MMM').format(dueDay);
}

/// Optional override for the commitments reference date (defaults to `null`,
/// which uses `clock.now()`).
final commitmentsReferenceDateProvider = Provider<DateTime?>((ref) => null);

/// Shared commitments summary figures consumed by both [SubscriptionsScreen]
/// and the home-screen Ledger widget (`design/specs/18-widgets.md` §3).
@immutable
class CommitmentsSummary {
  final List<LocalSubscription> activeSubs;
  final List<LocalSubscription> inactiveSubs;
  final List<LocalSubscription> sharedActive;
  final List<LocalSubscription> privateActive;
  final List<LocalSubscription> sortedSharedActive;
  final LocalSubscription? nextSharedCommitment;
  final String? nextSharedCommitmentWhen;
  final double subsMonthlyOnly;
  final double emisMonthlyOnly;
  final double savingsMonthlyOnly;
  final double subsAnnualOnly;
  final double emisAnnualOnly;
  final double savingsAnnualOnly;
  final double subsCombinedMonthly;
  final double emisCombinedMonthly;
  final double savingsCombinedMonthly;

  const CommitmentsSummary({
    required this.activeSubs,
    required this.inactiveSubs,
    required this.sharedActive,
    required this.privateActive,
    required this.sortedSharedActive,
    required this.nextSharedCommitment,
    required this.nextSharedCommitmentWhen,
    required this.subsMonthlyOnly,
    required this.emisMonthlyOnly,
    required this.savingsMonthlyOnly,
    required this.subsAnnualOnly,
    required this.emisAnnualOnly,
    required this.savingsAnnualOnly,
    required this.subsCombinedMonthly,
    required this.emisCombinedMonthly,
    required this.savingsCombinedMonthly,
  });

  factory CommitmentsSummary.compute(
    List<LocalSubscription> subscriptions, {
    bool includePrivateInHero = false,
    DateTime? referenceDate,
  }) {
    final activeSubs = subscriptions
        .where((s) => s.isActive && !s.isEmiFinished)
        .toList();
    final inactiveSubs = subscriptions
        .where((s) => !s.isActive || s.isEmiFinished)
        .toList();
    final sharedActive = activeSubs.where((s) => !s.isPrivate).toList();
    final privateActive = activeSubs.where((s) => s.isPrivate).toList();

    final relevantActive = includePrivateInHero ? activeSubs : sharedActive;

    double subsMonthlyOnly = 0.0;
    double emisMonthlyOnly = 0.0;
    double savingsMonthlyOnly = 0.0;

    double subsAnnualOnly = 0.0;
    double emisAnnualOnly = 0.0;
    double savingsAnnualOnly = 0.0;

    double subsCombinedMonthly = 0.0;
    double emisCombinedMonthly = 0.0;
    double savingsCombinedMonthly = 0.0;

    for (final item in relevantActive) {
      final months = getBillingCycleMonths(item.billingCycle);
      final isAnnual = months == 12;
      final isMonthly = months == 1;
      final isSavings = isSavingsCommitment(item);

      if (isAnnual) {
        if (item.isEmi) {
          emisAnnualOnly += item.amount;
        } else if (isSavings) {
          savingsAnnualOnly += item.amount;
        } else {
          subsAnnualOnly += item.amount;
        }
      } else if (isMonthly) {
        if (item.isEmi) {
          emisMonthlyOnly += item.amount;
        } else if (isSavings) {
          savingsMonthlyOnly += item.amount;
        } else {
          subsMonthlyOnly += item.amount;
        }
      }

      final monthlyAmount = item.amount / months;
      if (item.isEmi) {
        emisCombinedMonthly += monthlyAmount;
      } else if (isSavings) {
        savingsCombinedMonthly += monthlyAmount;
      } else {
        subsCombinedMonthly += monthlyAmount;
      }
    }

    final sortedSharedActive = List<LocalSubscription>.from(sharedActive)
      ..sort((a, b) {
        final cmp = a.nextBillingDate.compareTo(b.nextBillingDate);
        if (cmp != 0) return cmp;
        return b.amount.compareTo(a.amount);
      });

    final nextSharedCommitment =
        sortedSharedActive.isNotEmpty ? sortedSharedActive.first : null;
    final nextSharedCommitmentWhen = nextSharedCommitment != null
        ? formatCommitmentRenewalWhen(
            nextSharedCommitment.nextBillingDate,
            now: referenceDate,
          )
        : null;

    return CommitmentsSummary(
      activeSubs: activeSubs,
      inactiveSubs: inactiveSubs,
      sharedActive: sharedActive,
      privateActive: privateActive,
      sortedSharedActive: sortedSharedActive,
      nextSharedCommitment: nextSharedCommitment,
      nextSharedCommitmentWhen: nextSharedCommitmentWhen,
      subsMonthlyOnly: subsMonthlyOnly,
      emisMonthlyOnly: emisMonthlyOnly,
      savingsMonthlyOnly: savingsMonthlyOnly,
      subsAnnualOnly: subsAnnualOnly,
      emisAnnualOnly: emisAnnualOnly,
      savingsAnnualOnly: savingsAnnualOnly,
      subsCombinedMonthly: subsCombinedMonthly,
      emisCombinedMonthly: emisCombinedMonthly,
      savingsCombinedMonthly: savingsCombinedMonthly,
    );
  }
}

/// Provider computing the commitments summary once for both
/// [SubscriptionsScreen] and the Ledger widget.
final commitmentsSummaryProvider = Provider<CommitmentsSummary>((ref) {
  final subscriptions = ref.watch(activeHomeSubscriptionsProvider).value ??
      const <LocalSubscription>[];
  final referenceDate = ref.watch(commitmentsReferenceDateProvider);
  return CommitmentsSummary.compute(
    subscriptions,
    referenceDate: referenceDate,
  );
});
