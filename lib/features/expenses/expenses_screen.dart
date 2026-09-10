import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import 'expense_controller.dart';
import 'expense_form_sheet.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  final List<LocalExpense>? initialExpenses;

  const ExpensesScreen({super.key, this.initialExpenses});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outboxEvents = ref.watch(activeHomeOutboxProvider).value ?? [];

    if (widget.initialExpenses != null) {
      return _buildContent(context, widget.initialExpenses!, outboxEvents);
    }

    final expensesAsync = ref.watch(activeHomeExpensesProvider);

    return expensesAsync.when(
      data: (expenses) => _buildContent(context, expenses, outboxEvents),
      loading: () => Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CoveLoading()),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: colors.background,
        body: Center(child: Text('Failed to load expenses: $e')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<LocalExpense> allExpenses,
    List<LocalOutboxEvent> outboxEvents,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final currentUser = ref.watch(authProvider).value;

    if (allExpenses.isEmpty) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CoveEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No expenses recorded yet',
            description: 'Track shared groceries, utilities, and household expenses together.',
            action: CovePillButton(
              label: 'Log First Expense',
              icon: const Icon(Icons.add, size: 16),
              onPressed: () => ExpenseFormSheet.show(context),
            ),
          ),
        ),
      );
    }

    // Filter expenses for selected month
    final currentYear = _selectedMonth.year;
    final currentMonth = _selectedMonth.month;
    final monthName = DateFormat('MMMM y').format(_selectedMonth);

    final monthExpenses = allExpenses.where((e) {
      return e.expenseDate.year == currentYear && e.expenseDate.month == currentMonth;
    }).toList();

    // Compute Shared Monthly Total:
    // Only includes shared expenses (splitRatio > 0)
    // Excludes partnerCanSee (splitRatio == 0) and privateToMe (splitRatio < 0) from the shared pool
    double sharedMonthlyTotal = 0.0;
    int sharedCount = 0;
    int personalCount = 0;

    for (final exp in monthExpenses) {
      if (exp.splitRatio > 0.0) {
        sharedMonthlyTotal += exp.amount;
        sharedCount++;
      } else {
        personalCount++;
      }
    }

    // Compute category breakdown for this month (ranked by spend, strictly plain list)
    final categoryTotals = <String, double>{};
    for (final exp in monthExpenses) {
      // Clean category title (strip notes if appended via " • ")
      final rawCat = exp.category ?? 'Uncategorized';
      final cleanCat = rawCat.contains(' • ') ? rawCat.split(' • ').first : rawCat;
      categoryTotals[cleanCat] = (categoryTotals[cleanCat] ?? 0.0) + exp.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalSpendAll = categoryTotals.values.fold<double>(0.0, (acc, v) => acc + v);

    return Scaffold(
      backgroundColor: colors.background,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          // Hero Editorial Running Total Card (Bodoni Moda treatment)
          CoveCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${monthName.toUpperCase()} SHARED TOTAL',
                      style: typography.caption.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CovePillButton(
                      label: '+ Log',
                      isCompact: true,
                      onPressed: () => ExpenseFormSheet.show(context),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Bodoni Moda Editorial Number
                Text(
                  '\$${sharedMonthlyTotal.toStringAsFixed(2)}',
                  style: typography.largeNumber.copyWith(
                    fontSize: 38,
                    height: 1.1,
                    color: colors.accentTint,
                  ),
                ),
                const SizedBox(height: 6),

                Text(
                  '$sharedCount shared item${sharedCount == 1 ? "" : "s"}'
                  '${personalCount > 0 ? " • $personalCount personal" : ""}',
                  style: typography.caption.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Monthly Category Breakdown Section (Plain list, strictly no charts)
          if (sortedCategories.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('CATEGORY BREAKDOWN', style: typography.caption),
                Text(
                  '${sortedCategories.length} categories',
                  style: typography.caption.copyWith(color: colors.textSubtle),
                ),
              ],
            ),
            const SizedBox(height: 10),
            CoveGroupedCard(
              children: sortedCategories.map((entry) {
                final percent = totalSpendAll > 0
                    ? ((entry.value / totalSpendAll) * 100).toStringAsFixed(0)
                    : '0';
                return CoveGroupedRow(
                  title: Text(
                    entry.key,
                    style: typography.bodyMedium.copyWith(fontSize: 15),
                  ),
                  subtitle: Text(
                    '$percent% of monthly spend',
                    style: typography.caption.copyWith(color: colors.textSubtle),
                  ),
                  trailing: Text(
                    '\$${entry.value.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
          ],

          // Recent Purchases Ledger (Most recent first)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('RECENT PURCHASES', style: typography.caption),
              Text(
                '${allExpenses.length} total',
                style: typography.caption.copyWith(color: colors.textSubtle),
              ),
            ],
          ),
          const SizedBox(height: 10),

          CoveGroupedCard(
            children: allExpenses.map((expense) {
              return _buildExpenseRow(
                context,
                expense,
                currentUser,
                outboxEvents,
              );
            }).toList(),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(
    BuildContext context,
    LocalExpense expense,
    CoveUser? currentUser,
    List<LocalOutboxEvent> outbox,
  ) {
    final colors = context.colors;
    final typography = context.typography;

    // Determine visibility
    final visibility = ExpenseVisibilityExtension.fromSplitRatio(expense.splitRatio);

    // Attribution
    final isMe = expense.paidBy == currentUser?.id;
    final paidText = isMe ? 'Paid by You' : 'Paid by Partner';
    final dateFormatted = DateFormat('MMM d').format(expense.expenseDate);

    // Two-tick sync status:
    // If privateToMe: always single local tick (or no tick needed, but savedLocally is accurate)
    // If shared/partnerCanSee: checks outbox
    CoveSyncStatus tickStatus = CoveSyncStatus.savedLocally;
    if (visibility != ExpenseVisibility.privateToMe) {
      final outboxItem = outbox.firstWhere(
        (o) => o.payloadJson.contains(expense.id),
        orElse: () => LocalOutboxEvent(
          id: '',
          homeId: '',
          actorId: '',
          eventType: '',
          payloadJson: '',
          encryptedPayload: '',
          createdAt: DateTime.now(),
          syncStatus: 'syncedToPartner',
          retryCount: 0,
        ),
      );
      if (outboxItem.syncStatus == 'syncedToPartner') {
        tickStatus = CoveSyncStatus.syncedToPartner;
      }
    }

    // Subtitle text: "Paid by You • Sep 10 [• Category]"
    String subtitleText = '$paidText • $dateFormatted';
    if (expense.category != null && expense.category!.isNotEmpty) {
      subtitleText += ' • ${expense.category}';
    }

    return Dismissible(
      key: ValueKey('exp_${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colors.accentSecondary.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline, color: colors.accentSecondary, size: 20),
      ),
      onDismissed: (_) {
        ref.read(expenseControllerProvider).deleteExpense(
              expense.id,
              visibility: visibility,
            );
      },
      child: CoveGroupedRow(
        title: Row(
          children: [
            Expanded(
              child: Text(
                expense.title,
                style: typography.bodyMedium.copyWith(fontSize: 15),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (visibility == ExpenseVisibility.partnerCanSee) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceRow,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colors.borderHairline, width: 1),
                ),
                child: Text(
                  'Partner sees',
                  style: typography.caption.copyWith(
                    fontSize: 10,
                    color: colors.textSubtle,
                  ),
                ),
              ),
            ] else if (visibility == ExpenseVisibility.privateToMe) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accentPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Private',
                  style: typography.caption.copyWith(
                    fontSize: 10,
                    color: colors.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitleText,
          style: typography.caption.copyWith(color: colors.textMuted),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '\$${expense.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            CoveSyncTick(status: tickStatus, size: 13),
          ],
        ),
      ),
    );
  }
}
