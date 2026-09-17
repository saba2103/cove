import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/preferences_controller.dart';

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
    final now = DateTime.now().toUtc();
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
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final expense = await (_db.select(_db.localExpenses)..where((t) => t.id.equals(id))).getSingleOrNull();

    // 1. Immediately delete from local database and record tombstone to prevent resurrection on pull-to-refresh
    await _db.deleteExpense(id);
    await _db.recordTombstone(id, 'expense');

    // 2. Broadcast deletion to partner if not private
    if (visibility != ExpenseVisibility.privateToMe) {
      try {
        final emit = ref.read(coveEmitActionProvider);
        await emit(
          eventType: 'expense_deleted',
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
        'expense_date': (expenseDate ?? DateTime.now()).toIso8601String(),
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
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = (random.hashCode & 0x7FFFFFFF).toRadixString(16).padLeft(8, '0');
    final p1 = (DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    return '$p1-$hash-4000-8000-${DateTime.now().microsecond.toRadixString(16).padLeft(12, '0')}';
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
