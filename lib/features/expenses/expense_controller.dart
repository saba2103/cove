import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';

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
    String currency = 'USD',
    DateTime? expenseDate,
    required String paidBy,
    String? category,
    String? notes,
    ExpenseVisibility visibility = ExpenseVisibility.shared,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null) throw StateError('No active home selected.');

    final user = _currentUser;
    final userId = user?.id ?? 'local_user';
    final now = DateTime.now().toUtc();
    final date = expenseDate ?? now;
    final id = _generateUuid();

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
              currency: Value(currency),
              paidBy: paidBy,
              splitRatio: const Value(-1.0), // -1.0 designates privateToMe
              expenseDate: date,
              category: Value(categoryVal),
              createdAt: now,
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
          'currency': currency,
          'paid_by': paidBy,
          'split_ratio': splitRatio,
          'expense_date': date.toIso8601String(),
          'category': category?.trim(),
          'notes': notes?.trim(),
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

    if (visibility == ExpenseVisibility.privateToMe) {
      await _db.deleteExpense(id);
    } else {
      final emit = ref.read(coveEmitActionProvider);
      await emit(
        eventType: 'expense_deleted',
        payload: {
          'id': id,
          'home_id': homeId,
        },
      );
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

final expenseControllerProvider = Provider<ExpenseController>((ref) {
  return ExpenseController(ref);
});
