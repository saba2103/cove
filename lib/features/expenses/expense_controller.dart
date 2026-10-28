import 'dart:convert';
import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show DateUtils, debugPrint, immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import 'monthly_budget_controller.dart';

enum ExpenseVisibility {
  /// Both partners see this expense; included in household shared total & split.
  shared,

  /// Partner can see this expense in the ledger, but it is personal / outside the joint split pool.
  partnerCanSee,

  /// Stored strictly on this local device only. 0 bytes sent to sync engine or partner.
  privateToMe,
}

extension ExpenseVisibilityExtension on ExpenseVisibility {
  String get wireName {
    switch (this) {
      case ExpenseVisibility.shared:
        return 'shared';
      case ExpenseVisibility.partnerCanSee:
        return 'partner_can_see';
      case ExpenseVisibility.privateToMe:
        return 'private_to_me';
    }
  }

  static ExpenseVisibility fromSplitRatio(double ratio) {
    if (ratio < 0.0) return ExpenseVisibility.privateToMe;
    if (ratio == 0.0) return ExpenseVisibility.partnerCanSee;
    return ExpenseVisibility.shared;
  }
}

/// Shared arithmetic and metadata breakdown for a single [LocalExpense],
/// used by both [ExpensesScreen] and [ExpenseDetailSheet].
@immutable
class ExpenseShareBreakdown {
  final ExpenseVisibility visibility;
  final bool isPaidByViewer;
  final bool isShared;
  final bool isExactHalf;
  final double viewerShareRatio;
  final double viewerShareAmount;
  final double partnerShareAmount;

  const ExpenseShareBreakdown({
    required this.visibility,
    required this.isPaidByViewer,
    required this.isShared,
    required this.isExactHalf,
    required this.viewerShareRatio,
    required this.viewerShareAmount,
    required this.partnerShareAmount,
  });
}

/// Computes the viewer/partner share arithmetic and visibility for [expense]
/// from `splitRatio` and `paidBy`.
ExpenseShareBreakdown computeExpenseShare(
  LocalExpense expense, {
  required String? currentUserId,
}) {
  final visibility =
      ExpenseVisibilityExtension.fromSplitRatio(expense.splitRatio);
  final paidByViewer = (expense.paidBy == currentUserId) ||
      (currentUserId == null && expense.paidBy == 'user_alex') ||
      (expense.paidBy == 'me');
  final isShared = visibility == ExpenseVisibility.shared;

  if (!isShared) {
    final viewerRatio = paidByViewer ? 1.0 : 0.0;
    return ExpenseShareBreakdown(
      visibility: visibility,
      isPaidByViewer: paidByViewer,
      isShared: false,
      isExactHalf: false,
      viewerShareRatio: viewerRatio,
      viewerShareAmount: paidByViewer ? expense.amount : 0.0,
      partnerShareAmount: paidByViewer ? 0.0 : expense.amount,
    );
  }

  final ratio = expense.splitRatio.clamp(0.0, 1.0);
  final isExactHalf = (ratio - 0.5).abs() < 1e-6;
  final viewerAmount = expense.amount * ratio;
  final partnerAmount = expense.amount - viewerAmount;

  return ExpenseShareBreakdown(
    visibility: visibility,
    isPaidByViewer: paidByViewer,
    isShared: true,
    isExactHalf: isExactHalf,
    viewerShareRatio: ratio,
    viewerShareAmount: viewerAmount,
    partnerShareAmount: partnerAmount,
  );
}

/// Extracts the clean category name from a raw `category` field
/// (stripping any ` • {notes}` suffix).
String cleanExpenseCategoryName(String? rawCategory) {
  final raw = (rawCategory == null || rawCategory.trim().isEmpty)
      ? 'Uncategorized'
      : rawCategory.trim();
  return raw.contains(' • ') ? raw.split(' • ').first.trim() : raw;
}

/// Extracts the optional notes suffix from a raw `category` field.
String? extractExpenseNotes(String? rawCategory) {
  if (rawCategory == null || !rawCategory.contains(' • ')) return null;
  final parts = rawCategory.split(' • ');
  final notes = parts.sublist(1).join(' • ').trim();
  return notes.isEmpty ? null : notes;
}

/// Formats an expense's raw `paymentMethod` code (`'upi'`, `'cash'`, `'card'`).
String? formatExpensePaymentMethod(String? paymentMethod) {
  if (paymentMethod == null || paymentMethod.trim().isEmpty) return null;
  switch (paymentMethod.trim().toLowerCase()) {
    case 'upi':
      return 'UPI';
    case 'cash':
      return 'Cash';
    default:
      return 'Card';
  }
}

class ExpenseController {
  final Ref ref;

  ExpenseController(this.ref);

  AppDatabase get _db => ref.read(appDatabaseProvider);
  String? get _activeHomeId => ref.read(activeHomeIdProvider);
  CoveUser? get _currentUser => ref.read(authProvider).value;

  /// Logs a new expense.
  ///
  /// CRITICAL PRIVACY ARCHITECTURE:
  /// - [ExpenseVisibility.shared]:
  ///     Emits `expense_logged` via [coveEmitActionProvider], encrypted with
  ///     the shared Home key. `split_ratio` defaults to 0.5 (shared pool).
  /// - [ExpenseVisibility.partnerCanSee]:
  ///     Emits `expense_logged` via [coveEmitActionProvider], encrypted with
  ///     the shared Home key. `split_ratio` is 0.0 (unshared personal expense).
  /// - [ExpenseVisibility.privateToMe]:
  ///     Writes DIRECTLY to local Drift SQLite only. It is NEVER emitted to
  ///     [coveEmitActionProvider], NEVER encrypted with the Home key, and NEVER sent
  ///     over Supabase relay. The partner's device receives 0 bytes.
  Future<String> logExpense({
    required String title,
    required double amount,
    String? currency,
    DateTime? expenseDate,
    required String paidBy,
    String? category,
    String? notes,
    String? paymentMethod,
    bool isTransfer = false,
    ExpenseVisibility visibility = ExpenseVisibility.shared,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final user = _currentUser;
    final userId = user?.id ?? 'local_user';
    final now = clock.now().toUtc();
    final date = expenseDate ?? now;
    final id = _generateUuid();
    final resolvedCurrency = (currency != null && currency.isNotEmpty)
        ? currency
        : ref.read(currencyPreferenceProvider).code;

    // Combine category and notes if needed
    String? categoryVal = category?.trim();
    if (notes != null && notes.trim().isNotEmpty) {
      if (categoryVal != null && categoryVal.isNotEmpty) {
        categoryVal = '$categoryVal • ${notes.trim()}';
      } else {
        categoryVal = notes.trim();
      }
    }

    if (visibility == ExpenseVisibility.privateToMe) {
      // Direct local SQLite write ONLY - zero cloud or sync knowledge!
      await _db.into(_db.localExpenses).insertOnConflictUpdate(
            LocalExpensesCompanion.insert(
              id: id,
              homeId: homeId,
              title: title.trim(),
              amount: amount,
              currency: Value(resolvedCurrency),
              paidBy: paidBy,
              splitRatio: const Value(-1.0), // -1.0 designates privateToMe
              expenseDate: date,
              category: Value(categoryVal),
              paymentMethod: Value(paymentMethod),
              isTransfer: Value(isTransfer),
              createdAt: now,
            ),
          );
      await _db.recordActivityEvent(
        LocalActivityEventsCompanion.insert(
          id: 'expense_logged_${id}_${now.millisecondsSinceEpoch}',
          homeId: homeId,
          actorId: userId,
          eventType: 'expense_logged',
          payloadJson: jsonEncode({
            'id': id,
            'home_id': homeId,
            'title': title.trim(),
            'amount': amount,
            'currency': resolvedCurrency,
            'paid_by': paidBy,
            'category': categoryVal,
            'payment_method': paymentMethod,
            'is_transfer': isTransfer,
            'is_private': true,
            'split_ratio': -1.0,
            'expense_date': date.toIso8601String(),
          }),
          createdAt: now,
          syncStatus: const Value('savedLocally'),
          isPrivate: const Value(true),
        ),
      );
    } else {
      // Shared or partner_can_see write through Sync Engine
      final splitRatio = visibility == ExpenseVisibility.partnerCanSee ? 0.0 : 0.5;
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'expense_logged',
        payload: {
          'id': id,
          'home_id': homeId,
          'title': title.trim(),
          'amount': amount,
          'currency': resolvedCurrency,
          'paid_by': paidBy,
          'split_ratio': splitRatio,
          'expense_date': date.toIso8601String(),
          'category': category?.trim(),
          'notes': notes?.trim(),
          if (paymentMethod != null && paymentMethod.trim().isNotEmpty)
            'payment_method': paymentMethod.trim(),
          'is_transfer': isTransfer,
          'visibility': visibility.wireName,
          'created_by': userId,
        },
      );
    }

    return id;
  }

  /// Deletes an expense.
  Future<void> deleteExpense(String id, {required ExpenseVisibility visibility}) async {
    LocalExpense? expense;
    try {
      expense = await (_db.select(_db.localExpenses)..where((t) => t.id.equals(id))).getSingleOrNull();
    } catch (_) {}

    final homeId = _activeHomeId ?? expense?.homeId;
    if (homeId == null) throw StateError('No active home selected.');

    // 1. Immediately delete from local database and record tombstone to prevent resurrection on pull-to-refresh
    try {
      if (visibility == ExpenseVisibility.privateToMe) {
        await _db.deletePetTagsForRecord('expense', id);
      }
      await _db.deleteExpense(id);
      await _db.recordTombstone(id, 'expense');
    } catch (_) {}

    // 2. Broadcast deletion to partner if not private
    if (visibility != ExpenseVisibility.privateToMe) {
      try {
        final emit = ref.read(coveEmitActionProvider);
        await emit(
          eventType: 'expense_deleted',
          targetHomeId: homeId,
          payload: {
            'id': id,
            'home_id': homeId,
            if (expense != null) ...{
              'title': expense.title,
              'amount': expense.amount,
              'currency': expense.currency,
              if (expense.category != null) 'category': expense.category,
              if (expense.paymentMethod != null) 'payment_method': expense.paymentMethod,
              'paid_by': expense.paidBy,
              'expense_date': expense.expenseDate.toIso8601String(),
              'visibility': ExpenseVisibilityExtension.fromSplitRatio(expense.splitRatio).wireName,
            },
          },
        );
      } catch (e) {
        debugPrint('[ExpenseController] Failed to emit expense_deleted: $e');
      }
    }
  }

  /// Restores a previously deleted expense with identical properties.
  Future<String> restoreExpense(LocalExpense expense) async {
    final visibility = ExpenseVisibilityExtension.fromSplitRatio(expense.splitRatio);

    return logExpense(
      title: expense.title,
      amount: expense.amount,
      currency: expense.currency,
      expenseDate: expense.expenseDate,
      paidBy: expense.paidBy,
      category: expense.category,
      paymentMethod: expense.paymentMethod,
      isTransfer: expense.isTransfer,
      visibility: visibility,
    );
  }

  /// Updates an existing expense, capturing the previous state for undo capability.
  Future<String> updateExpense({
    required String id,
    required String title,
    required double amount,
    String? currency,
    DateTime? expenseDate,
    required String paidBy,
    String? category,
    String? notes,
    String? paymentMethod,
    bool? isTransfer,
    required ExpenseVisibility oldVisibility,
    ExpenseVisibility visibility = ExpenseVisibility.shared,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final previous = await (_db.select(_db.localExpenses)..where((t) => t.id.equals(id))).getSingleOrNull();
    final resolvedCurrency = (currency != null && currency.isNotEmpty)
        ? currency
        : (previous?.currency ?? ref.read(currencyPreferenceProvider).code);
    final resolvedIsTransfer = isTransfer ?? previous?.isTransfer ?? false;

    if (oldVisibility == ExpenseVisibility.privateToMe || visibility == ExpenseVisibility.privateToMe) {
      await deleteExpense(id, visibility: oldVisibility);
      return logExpense(
        title: title,
        amount: amount,
        currency: resolvedCurrency,
        expenseDate: expenseDate,
        paidBy: paidBy,
        category: category,
        notes: notes,
        paymentMethod: paymentMethod,
        isTransfer: resolvedIsTransfer,
        visibility: visibility,
      );
    }

    final user = _currentUser;
    final userId = user?.id ?? 'local_user';
    final emit = ref.read(coveEmitActionProvider);

    await emit(
      eventType: 'expense_updated',
      payload: {
        'id': id,
        'home_id': homeId,
        'title': title.trim(),
        'amount': amount,
        'currency': resolvedCurrency,
        'expense_date': (expenseDate ?? clock.now()).toIso8601String(),
        'paid_by': paidBy,
        'created_by': userId,
        'is_transfer': resolvedIsTransfer,
        if (category != null && category.trim().isNotEmpty) 'category': category.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        if (paymentMethod != null && paymentMethod.trim().isNotEmpty)
          'payment_method': paymentMethod.trim(),
        'visibility': visibility == ExpenseVisibility.partnerCanSee
            ? 'partner_can_see'
            : 'shared',
        if (previous != null)
          'previous': {
            'title': previous.title,
            'amount': previous.amount,
            'currency': previous.currency,
            'expense_date': previous.expenseDate.toIso8601String(),
            'paid_by': previous.paidBy,
            'is_transfer': previous.isTransfer,
            if (previous.category != null) 'category': previous.category,
            if (previous.paymentMethod != null) 'payment_method': previous.paymentMethod,
            'visibility': ExpenseVisibilityExtension.fromSplitRatio(previous.splitRatio).wireName,
          },
      },
    );

    return id;
  }

  /// Renames a category across all expenses in the active home, updates custom categories,
  /// and syncs the changes to the partner.
  Future<int> renameCategory(String oldCategory, String newCategory) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final from = oldCategory.trim();
    final to = newCategory.trim();
    if (to.isEmpty || from == to) return 0;

    // 1. Update custom categories memory
    await ref.read(customCategoriesProvider.notifier).renameCategory(from, to);

    // 2. Query all expenses in this home
    final allExpenses = await (_db.select(_db.localExpenses)
          ..where((t) => t.homeId.equals(homeId)))
        .get();

    int updatedCount = 0;
    final emitAction = ref.read(coveEmitActionProvider);

    for (final exp in allExpenses) {
      final rawCat = exp.category;
      if (rawCat == null) continue;

      String? newCatValue;
      if (rawCat == from) {
        newCatValue = to;
      } else if (rawCat.startsWith('$from • ')) {
        final suffix = rawCat.substring('$from • '.length);
        newCatValue = '$to • $suffix';
      }

      if (newCatValue != null) {
        updatedCount++;
        // Update local DB
        await (_db.update(_db.localExpenses)..where((t) => t.id.equals(exp.id)))
            .write(LocalExpensesCompanion(category: Value(newCatValue)));

        // If shared or partnerCanSee, sync the change
        if (exp.splitRatio >= 0.0) {
          final visibility = exp.splitRatio == 0.0
              ? 'partner_can_see'
              : 'shared';
          await emitAction(
            eventType: 'expense_updated',
            payload: {
              'id': exp.id,
              'home_id': homeId,
              'title': exp.title,
              'amount': exp.amount,
              'currency': exp.currency,
              'paid_by': exp.paidBy,
              'split_ratio': exp.splitRatio,
              'expense_date': exp.expenseDate.toIso8601String(),
              'category': newCatValue,
              'visibility': visibility,
            },
          );
        }
      }
    }

    return updatedCount;
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

class CustomCategoriesNotifier extends Notifier<List<String>> {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'cove_custom_expense_categories_v1';

  @override
  List<String> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<String>();
        state = list;
      }
    } catch (_) {}
  }

  Future<void> _save(List<String> list) async {
    try {
      await _storage.write(key: _storageKey, value: jsonEncode(list));
    } catch (_) {}
  }

  Future<void> addCategory(String category) async {
    final cat = category.trim();
    if (cat.isEmpty || state.contains(cat)) return;
    final updated = [...state, cat];
    state = updated;
    await _save(updated);
  }

  Future<void> renameCategory(String oldName, String newName) async {
    final from = oldName.trim();
    final to = newName.trim();
    if (to.isEmpty) return;
    final updated = state.map((c) => c == from ? to : c).toSet().toList();
    if (!updated.contains(to)) updated.add(to);
    state = updated;
    await _save(updated);
  }
}

final customCategoriesProvider =
    NotifierProvider<CustomCategoriesNotifier, List<String>>(
        CustomCategoriesNotifier.new);

final expenseControllerProvider = Provider<ExpenseController>((ref) {
  return ExpenseController(ref);
});

/// Optional override for the standing month's reference date (defaults to `null`,
/// which uses `clock.now()`).
final expensesReferenceDateProvider = Provider<DateTime?>((ref) => null);

/// Shared standing-month expense figures consumed by both [ExpensesScreen] and
/// the home-screen Ledger widget (`design/specs/18-widgets.md` §3).
@immutable
class ExpensesStandingSummary {
  final DateTime referenceDate;
  final DateTime standingMonth;
  final String standingMonthName;
  final int daysInStandingMonth;
  final int standingDay;
  final int daysRemaining;
  final List<LocalExpense> standingMonthExpenses;
  final List<LocalExpense> standingActualExpenses;
  final List<LocalExpense> standingTransfers;
  final double sharedMonthlyTotal;
  final double paidByMeSharedTotal;
  final double paidByPartnerSharedTotal;
  final int sharedCount;
  final int personalCount;
  final double transfersMonthlyTotal;
  final double sentByMeTotal;
  final double sentByPartnerTotal;
  final int transfersCount;
  final DateTime prevMonth;
  final String prevMonthName;
  final int daysInPrevMonth;
  final double prevMonthTotal;
  final double prevMonthByThisDay;
  final bool hasPrevComparison;
  final double prevDelta;
  final bool isSpendingLess;
  final int prevPct;
  final String myName;
  final String partnerName;
  final String creatorId;
  final CurrencyOption currency;
  final double? monthlyBudget;

  const ExpensesStandingSummary({
    required this.referenceDate,
    required this.standingMonth,
    required this.standingMonthName,
    required this.daysInStandingMonth,
    required this.standingDay,
    required this.daysRemaining,
    required this.standingMonthExpenses,
    required this.standingActualExpenses,
    required this.standingTransfers,
    required this.sharedMonthlyTotal,
    required this.paidByMeSharedTotal,
    required this.paidByPartnerSharedTotal,
    required this.sharedCount,
    required this.personalCount,
    required this.transfersMonthlyTotal,
    required this.sentByMeTotal,
    required this.sentByPartnerTotal,
    required this.transfersCount,
    required this.prevMonth,
    required this.prevMonthName,
    required this.daysInPrevMonth,
    required this.prevMonthTotal,
    required this.prevMonthByThisDay,
    required this.hasPrevComparison,
    required this.prevDelta,
    required this.isSpendingLess,
    required this.prevPct,
    required this.myName,
    required this.partnerName,
    required this.creatorId,
    required this.currency,
    required this.monthlyBudget,
  });

  factory ExpensesStandingSummary.compute({
    required List<LocalExpense> allExpenses,
    required String? currentUserId,
    required String myName,
    required String partnerName,
    required String creatorId,
    required CurrencyOption currency,
    required double? monthlyBudget,
    DateTime? referenceDate,
  }) {
    final resolvedDate = (referenceDate ?? clock.now()).toLocal();
    final standingMonth = DateTime(resolvedDate.year, resolvedDate.month, 1);
    final standingMonthName = DateFormat('MMMM').format(standingMonth);
    final daysInStandingMonth = DateUtils.getDaysInMonth(
      standingMonth.year,
      standingMonth.month,
    );
    final standingDay = resolvedDate.day.clamp(1, daysInStandingMonth);
    final daysRemaining = math.max(0, daysInStandingMonth - standingDay);

    final standingMonthExpenses = allExpenses.where((e) {
      final d = e.expenseDate.toLocal();
      return d.year == standingMonth.year && d.month == standingMonth.month;
    }).toList();

    final standingActualExpenses =
        standingMonthExpenses.where((e) => !e.isTransfer).toList();
    final standingTransfers =
        standingMonthExpenses.where((e) => e.isTransfer).toList();

    double sharedMonthlyTotal = 0.0;
    double paidByMeSharedTotal = 0.0;
    double paidByPartnerSharedTotal = 0.0;
    int sharedCount = 0;
    int personalCount = 0;

    for (final exp in standingActualExpenses) {
      final share = computeExpenseShare(exp, currentUserId: currentUserId);
      if (share.isShared) {
        sharedMonthlyTotal += exp.amount;
        sharedCount++;
        if (share.isPaidByViewer) {
          paidByMeSharedTotal += exp.amount;
        } else {
          paidByPartnerSharedTotal += exp.amount;
        }
      } else {
        personalCount++;
      }
    }

    double transfersMonthlyTotal = 0.0;
    double sentByMeTotal = 0.0;
    double sentByPartnerTotal = 0.0;
    final int transfersCount = standingTransfers.length;

    for (final t in standingTransfers) {
      transfersMonthlyTotal += t.amount;
      final share = computeExpenseShare(t, currentUserId: currentUserId);
      if (share.isPaidByViewer) {
        sentByMeTotal += t.amount;
      } else {
        sentByPartnerTotal += t.amount;
      }
    }

    final prevMonth = DateTime(standingMonth.year, standingMonth.month - 1, 1);
    final prevMonthName = DateFormat('MMMM').format(prevMonth);
    final daysInPrevMonth = DateUtils.getDaysInMonth(
      prevMonth.year,
      prevMonth.month,
    );
    final prevMonthActualExpenses = allExpenses.where((e) {
      final d = e.expenseDate.toLocal();
      return !e.isTransfer &&
          e.splitRatio > 0.0 &&
          d.year == prevMonth.year &&
          d.month == prevMonth.month;
    }).toList();

    final double prevMonthTotal = prevMonthActualExpenses.fold<double>(
      0.0,
      (acc, e) => acc + e.amount,
    );
    final double prevMonthByThisDay = prevMonthActualExpenses
        .where((e) => e.expenseDate.toLocal().day <= standingDay)
        .fold<double>(0.0, (acc, e) => acc + e.amount);

    final bool hasPrevComparison = prevMonthByThisDay > 0;
    final double prevDelta = sharedMonthlyTotal - prevMonthByThisDay;
    final bool isSpendingLess = prevDelta <= 0;
    final int prevPct = prevMonthByThisDay > 0
        ? ((prevDelta.abs() / prevMonthByThisDay) * 100).round()
        : 0;

    return ExpensesStandingSummary(
      referenceDate: resolvedDate,
      standingMonth: standingMonth,
      standingMonthName: standingMonthName,
      daysInStandingMonth: daysInStandingMonth,
      standingDay: standingDay,
      daysRemaining: daysRemaining,
      standingMonthExpenses: standingMonthExpenses,
      standingActualExpenses: standingActualExpenses,
      standingTransfers: standingTransfers,
      sharedMonthlyTotal: sharedMonthlyTotal,
      paidByMeSharedTotal: paidByMeSharedTotal,
      paidByPartnerSharedTotal: paidByPartnerSharedTotal,
      sharedCount: sharedCount,
      personalCount: personalCount,
      transfersMonthlyTotal: transfersMonthlyTotal,
      sentByMeTotal: sentByMeTotal,
      sentByPartnerTotal: sentByPartnerTotal,
      transfersCount: transfersCount,
      prevMonth: prevMonth,
      prevMonthName: prevMonthName,
      daysInPrevMonth: daysInPrevMonth,
      prevMonthTotal: prevMonthTotal,
      prevMonthByThisDay: prevMonthByThisDay,
      hasPrevComparison: hasPrevComparison,
      prevDelta: prevDelta,
      isSpendingLess: isSpendingLess,
      prevPct: prevPct,
      myName: myName,
      partnerName: partnerName,
      creatorId: creatorId,
      currency: currency,
      monthlyBudget: monthlyBudget,
    );
  }
}

/// Provider computing the standing-month expenses summary once for both
/// [ExpensesScreen] and the Ledger widget.
final expensesStandingSummaryProvider = Provider<ExpensesStandingSummary>((ref) {
  final allExpenses =
      ref.watch(activeHomeExpensesProvider).value ?? const <LocalExpense>[];
  final currentUser = ref.watch(authProvider).value;
  final userProfile = ref.watch(userProfileProvider);
  final partnerProfile = ref.watch(partnerProfileProvider);
  final home = ref.watch(activeHomeProvider).value;
  final currency = ref.watch(currencyPreferenceProvider);
  final monthlyBudget = ref.watch(monthlyBudgetProvider);
  final referenceDateOverride = ref.watch(expensesReferenceDateProvider);

  final partnerName = partnerProfile.displayName.isNotEmpty
      ? partnerProfile.displayName
      : 'Partner';
  final myName =
      userProfile.displayName.isNotEmpty ? userProfile.displayName : 'You';
  final creatorId = home?.createdBy ?? currentUser?.id ?? 'user_alex';

  return ExpensesStandingSummary.compute(
    allExpenses: allExpenses,
    currentUserId: currentUser?.id,
    myName: myName,
    partnerName: partnerName,
    creatorId: creatorId,
    currency: currency,
    monthlyBudget: monthlyBudget,
    referenceDate: referenceDateOverride,
  );
});
