import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    final now = DateTime.now().toUtc();
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
  Future<void> renewOrPaySubscription(
    String id, {
    required bool isPrivate,
    bool logExpense = false,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final sub = await (_db.select(_db.localSubscriptions)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (sub == null) return;

    final cycleMonths = getBillingCycleMonths(sub.billingCycle);
    final currentNext = sub.nextBillingDate;
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

      await expenseCtrl.logExpense(
        title: title,
        amount: sub.amount,
        currency: sub.currency,
        expenseDate: DateTime.now(),
        paidBy: isSplit ? (_currentUser?.id ?? 'me') : payer,
        category: sub.category ?? 'Utilities',
        notes: isEmi
            ? 'EMI payment via ${sub.financedThrough ?? "Commitments"}'
            : 'Recurring subscription renewal',
        visibility: visibility,
      );
    }
  }

  /// Permanently deletes a subscription.
  Future<void> deleteSubscription(String id, {required bool isPrivate}) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    // 1. Immediately record tombstone and delete locally
    await _db.recordTombstone(id, 'subscription');
    await (_db.delete(_db.localSubscriptions)..where((t) => t.id.equals(id))).go();

    if (!isPrivate) {
      try {
        final emit = ref.read(coveEmitActionProvider);
        await emit(
          eventType: 'subscription_deleted',
          payload: {
            'id': id,
            'home_id': homeId,
          },
        );
      } catch (_) {}
    }
  }

  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = (random.hashCode & 0x7FFFFFFF).toRadixString(16).padLeft(8, '0');
    final p1 = (DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    return '$p1-$hash-4000-8000-${DateTime.now().microsecond.toRadixString(16).padLeft(12, '0')}';
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
