import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_error_state.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import 'category_detail_sheet.dart';
import 'expense_controller.dart';
import 'expense_detail_sheet.dart';
import 'expense_form_sheet.dart';
import 'monthly_budget_controller.dart';
import 'monthly_budget_sheet.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  final List<LocalExpense>? initialExpenses;

  const ExpensesScreen({super.key, this.initialExpenses});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final DateTime _selectedMonth = DateTime.now();
  bool _showTransfers = false;

  Future<void> _handleRefresh() async {
    final homeId = ref.read(activeHomeIdProvider);
    await ref.read(syncEngineProvider).pullLatestEvents(homeId: homeId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outboxEvents = ref.watch(activeHomeOutboxProvider).value ?? [];
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);

    if (widget.initialExpenses != null) {
      return _buildContent(context, widget.initialExpenses!, outboxEvents, hasPartner: hasPartner);
    }

    final expensesAsync = ref.watch(activeHomeExpensesProvider);

    return expensesAsync.when(
      data: (expenses) => _buildContent(context, expenses, outboxEvents, hasPartner: hasPartner),
      loading: () => Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CoveLoading()),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CoveErrorState.generic(
            title: 'Expenses unavailable',
            description: 'Could not load expenses right now.',
            onRetry: () => ref.invalidate(activeHomeExpensesProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<LocalExpense> allExpenses,
    List<LocalOutboxEvent> outboxEvents, {
    bool hasPartner = true,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.watch(currencyPreferenceProvider);
    final currentUser = ref.watch(authProvider).value;

    if (allExpenses.isEmpty) {
      return Scaffold(
        backgroundColor: colors.background,
        body: RefreshIndicator(
          color: colors.accentPrimary,
          backgroundColor: colors.surfaceCard,
          onRefresh: _handleRefresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
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
                ),
              );
            },
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

    // Separate expenditures from transfers so expenditures remain completely separate
    final monthActualExpenses = monthExpenses.where((e) => !e.isTransfer).toList();
    final monthTransfers = monthExpenses.where((e) => e.isTransfer).toList();

    // Compute Shared Monthly Total:
    // Only includes shared expenses (splitRatio > 0)
    // Excludes partnerCanSee (splitRatio == 0) and privateToMe (splitRatio < 0) from the shared pool
    // Strictly excludes transfers!
    double sharedMonthlyTotal = 0.0;
    int sharedCount = 0;
    int personalCount = 0;

    for (final exp in monthActualExpenses) {
      if (exp.splitRatio > 0.0) {
        sharedMonthlyTotal += exp.amount;
        sharedCount++;
      } else {
        personalCount++;
      }
    }

    // Compute Monthly Transfers Total:
    double transfersMonthlyTotal = 0.0;
    double sentByMeTotal = 0.0;
    double sentByPartnerTotal = 0.0;
    final int transfersCount = monthTransfers.length;

    for (final t in monthTransfers) {
      transfersMonthlyTotal += t.amount;
      final isMe = (t.paidBy == currentUser?.id) ||
          (currentUser?.id == null && t.paidBy == 'user_alex') ||
          (t.paidBy == 'me');
      if (isMe) {
        sentByMeTotal += t.amount;
      } else {
        sentByPartnerTotal += t.amount;
      }
    }

    // Attribution for partner
    final partnerProfile = ref.watch(partnerProfileProvider);
    final partnerName =
        partnerProfile.displayName.isNotEmpty ? partnerProfile.displayName : 'Partner';

    // Compute category breakdown strictly for actual expenses (transfers are excluded)
    final categoryTotals = <String, double>{};
    for (final exp in monthActualExpenses) {
      // Clean category title (strip notes if appended via " • ")
      final rawCat = exp.category ?? 'Uncategorized';
      final cleanCat = rawCat.contains(' • ') ? rawCat.split(' • ').first : rawCat;
      categoryTotals[cleanCat] = (categoryTotals[cleanCat] ?? 0.0) + exp.amount;
    }

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalSpendAll = categoryTotals.values.fold<double>(0.0, (acc, v) => acc + v);

    final isWide = kIsWeb && MediaQuery.sizeOf(context).width >= 960;

    final heroCard = CoveCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showTransfers
                    ? '${monthName.toUpperCase()} TRANSFERS TOTAL'
                    : '${monthName.toUpperCase()} SHARED TOTAL',
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
          const SizedBox(height: 12),

          // Switcher pill row (Expenditure | Transfers)
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: colors.surfaceRow,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.borderHairline, width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCardSegment(
                  label: 'Expenditure',
                  isSelected: !_showTransfers,
                  onTap: () => setState(() => _showTransfers = false),
                ),
                _buildCardSegment(
                  label: 'Transfers',
                  isSelected: _showTransfers,
                  onTap: () => setState(() => _showTransfers = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Bodoni Moda Editorial Number
          Text(
            _showTransfers
                ? '${currency.symbol}${NumberFormat('#,##0.00').format(transfersMonthlyTotal)}'
                : '${currency.symbol}${NumberFormat('#,##0.00').format(sharedMonthlyTotal)}',
            style: typography.largeNumber.copyWith(
              fontSize: 38,
              height: 1.1,
              color: colors.accentTint,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            _showTransfers
                ? '$transfersCount transfer${transfersCount == 1 ? "" : "s"} • You sent ${currency.symbol}${NumberFormat('#,##0.00').format(sentByMeTotal)}${sentByPartnerTotal > 0 ? " • $partnerName sent ${currency.symbol}${NumberFormat('#,##0.00').format(sentByPartnerTotal)}" : ""}'
                : '$sharedCount shared item${sharedCount == 1 ? "" : "s"}${personalCount > 0 ? " • $personalCount personal" : ""}',
            style: typography.caption.copyWith(
              color: colors.textMuted,
            ),
          ),

          if (!_showTransfers) ...[
            Builder(
              builder: (context) {
                final monthlyBudget = ref.watch(monthlyBudgetProvider);
                if (monthlyBudget != null && monthlyBudget > 0) {
                  final isOverBudget = sharedMonthlyTotal > monthlyBudget;
                  final remaining = (monthlyBudget - sharedMonthlyTotal).clamp(0.0, double.infinity);
                  final overshoot = (sharedMonthlyTotal - monthlyBudget).clamp(0.0, double.infinity);
                  final percentUsed = (sharedMonthlyTotal / monthlyBudget).clamp(0.0, 1.0);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () => MonthlyBudgetSheet.show(context),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isOverBudget
                                ? colors.accentSecondary.withValues(alpha: 0.1)
                                : colors.surfaceRow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isOverBudget
                                  ? colors.accentSecondary.withValues(alpha: 0.35)
                                  : colors.borderHairline,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isOverBudget
                                            ? Icons.trending_up_rounded
                                            : Icons.pie_chart_outline_rounded,
                                        size: 15,
                                        color: isOverBudget
                                            ? colors.accentSecondary
                                            : colors.accentPrimary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isOverBudget ? 'SHOT UP · OVER BUDGET' : 'MONTHLY BUDGET',
                                        style: typography.caption.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: isOverBudget
                                              ? colors.accentSecondary
                                              : colors.accentTint,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        isOverBudget
                                            ? 'Shot up by ${currency.symbol}${NumberFormat('#,##0.00').format(overshoot)}'
                                            : '${currency.symbol}${NumberFormat('#,##0.00').format(remaining)} remaining',
                                        style: typography.caption.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isOverBudget
                                              ? colors.accentSecondary
                                              : colors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.edit_outlined, size: 12, color: colors.textMuted),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Progress bar
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: Stack(
                                  children: [
                                    Container(
                                      height: 6,
                                      width: double.infinity,
                                      color: colors.borderHairline.withValues(alpha: 0.6),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: isOverBudget ? 1.0 : percentUsed,
                                      child: Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: isOverBudget
                                              ? colors.accentSecondary
                                              : colors.accentPrimary,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${currency.symbol}${NumberFormat('#,##0.00').format(sharedMonthlyTotal)} spent',
                                    style: typography.caption.copyWith(
                                      fontSize: 11,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    'Target: ${currency.symbol}${NumberFormat('#,##0.00').format(monthlyBudget)} (${(percentUsed * 100).toInt()}%)',
                                    style: typography.caption.copyWith(
                                      fontSize: 11,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: InkWell(
                      onTap: () => MonthlyBudgetSheet.show(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_circle_outline_rounded, size: 14, color: colors.accentPrimary),
                            const SizedBox(width: 6),
                            Text(
                              'Set monthly budget target',
                              style: typography.caption.copyWith(
                                color: colors.accentPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );

    final categorySection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            children: sortedCategories.asMap().entries.map((item) {
              final idx = item.key;
              final entry = item.value;
              final percent = totalSpendAll > 0
                  ? ((entry.value / totalSpendAll) * 100).toStringAsFixed(0)
                  : '0';
              final catColor = _getCategoryColor(entry.key, idx, colors);
              return CoveGroupedRow(
                title: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: catColor,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: typography.bodyMedium.copyWith(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  '$percent% of monthly spend',
                  style: typography.caption.copyWith(color: colors.textSubtle),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${currency.symbol}${NumberFormat('#,##0.00').format(entry.value)}',
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right, size: 16, color: colors.textSubtle),
                  ],
                ),
                onTap: () {
                  CategoryDetailSheet.show(
                    context,
                    categoryName: entry.key,
                    allExpenses: monthExpenses,
                    totalMonthSpend: totalSpendAll,
                  );
                },
              );
            }).toList(),
          ),
        ],
      ],
    );

    final purchasesSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              hasPartner: hasPartner,
            );
          }).toList(),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        color: colors.accentPrimary,
        backgroundColor: colors.surfaceCard,
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 36 : 20,
            vertical: isWide ? 32 : 20,
          ),
          children: [
            if (isWide) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        heroCard,
                        if (!_showTransfers && sortedCategories.isNotEmpty && totalSpendAll > 0) ...[
                          const SizedBox(height: 16),
                          _buildCategorySplitBar(context, sortedCategories, totalSpendAll, monthExpenses),
                        ],
                        const SizedBox(height: 28),
                        categorySection,
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 6,
                    child: purchasesSection,
                  ),
                ],
              ),
            ] else ...[
              heroCard,
              if (!_showTransfers && sortedCategories.isNotEmpty && totalSpendAll > 0) ...[
                const SizedBox(height: 16),
                _buildCategorySplitBar(context, sortedCategories, totalSpendAll, monthExpenses),
              ],
              const SizedBox(height: 24),
              categorySection,
              const SizedBox(height: 28),
              purchasesSection,
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseRow(
    BuildContext context,
    LocalExpense expense,
    CoveUser? currentUser,
    List<LocalOutboxEvent> outbox, {
    bool hasPartner = true,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    // Determine visibility
    final visibility = ExpenseVisibilityExtension.fromSplitRatio(expense.splitRatio);

    // Attribution
    final partnerProfile = ref.watch(partnerProfileProvider);
    final isMe = (expense.paidBy == currentUser?.id) ||
        (currentUser?.id == null && expense.paidBy == 'user_alex') ||
        (expense.paidBy == 'me');
    final partnerName =
        partnerProfile.displayName.isNotEmpty ? partnerProfile.displayName : 'Partner';
    final paidText = isMe ? 'Paid by You' : 'Paid by $partnerName';
    final dateFormatted = DateFormat('MMM d').format(expense.expenseDate);

    // Two-tick sync status
    final tickStatus = resolveCoveSyncStatus(
      entityId: expense.id,
      outbox: outbox,
      isPrivate: visibility == ExpenseVisibility.privateToMe,
      hasPartner: hasPartner,
    );

    final isTransfer = expense.isTransfer;

    // Subtitle text:
    final String subtitleText;
    if (isTransfer) {
      final directionText = isMe
          ? 'You transferred to $partnerName'
          : '$partnerName transferred to You';
      String sub = '$directionText • $dateFormatted';
      if (expense.paymentMethod != null && expense.paymentMethod!.isNotEmpty) {
        final pmLabel = expense.paymentMethod == 'upi'
            ? 'UPI'
            : (expense.paymentMethod == 'cash' ? 'Cash' : 'Card/Bank');
        sub += ' • $pmLabel';
      }
      subtitleText = sub;
    } else {
      String sub = '$paidText • $dateFormatted';
      if (expense.category != null && expense.category!.isNotEmpty) {
        sub += ' • ${expense.category}';
      }
      if (expense.paymentMethod != null && expense.paymentMethod!.isNotEmpty) {
        final pmLabel = expense.paymentMethod == 'upi'
            ? 'UPI'
            : (expense.paymentMethod == 'cash' ? 'Cash' : 'Card');
        sub += ' • $pmLabel';
      }
      subtitleText = sub;
    }

    final currency = ref.watch(currencyPreferenceProvider);

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
        CoveUndoToast.show(
          context,
          message: 'Deleted "${expense.title}"',
          onUndo: () async {
            await ref.read(expenseControllerProvider).restoreExpense(expense);
          },
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
            if (isTransfer) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colors.accentPrimary.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz, size: 12, color: colors.accentPrimary),
                    const SizedBox(width: 3),
                    Text(
                      'Transfer',
                      style: typography.caption.copyWith(
                        fontSize: 10,
                        color: colors.accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (visibility == ExpenseVisibility.partnerCanSee) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceRow,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: colors.borderHairline, width: 1),
                ),
                child: Text(
                  '${partnerProfile.displayName} sees',
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
              '${currency.symbol}${NumberFormat('#,##0.00').format(expense.amount)}',
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
        onTap: () => ExpenseDetailSheet.show(context, expense),
      ),
    );
  }

  Widget _buildCardSegment({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.surfaceCard : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? Border.all(color: colors.accentPrimary.withValues(alpha: 0.35), width: 1)
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? colors.accentPrimary : colors.textMuted,
          ),
        ),
      ),
    );
  }

  static Color _getCategoryColor(String category, int index, CoveColors colors) {
    final lower = category.toLowerCase().trim();
    if (lower.contains('grocer') || lower.contains('food')) {
      return const Color(0xFF7A9E8A); // Soft Sage Green
    }
    if (lower.contains('home') || lower.contains('utilit')) {
      return colors.accentPrimary; // Cove Warm Gold / Amber
    }
    if (lower.contains('dining') || lower.contains('restaurant')) {
      return const Color(0xFFDF9E5F); // Warm Apricot
    }
    if (lower.contains('travel') || lower.contains('transport')) {
      return const Color(0xFF6B8CAE); // Slate Blue
    }
    if (lower.contains('health') || lower.contains('personal')) {
      return const Color(0xFF4A877F); // Deep Teal
    }
    if (lower.contains('entertainment') || lower.contains('stream')) {
      return const Color(0xFFA27896); // Dusty Plum
    }
    if (lower.contains('shopping')) {
      return const Color(0xFFC46D5E); // Warm Brick Red
    }
    const fallbackPalette = [
      Color(0xFF7A9E8A),
      Color(0xFFD8B98C),
      Color(0xFFDF9E5F),
      Color(0xFF6B8CAE),
      Color(0xFF4A877F),
      Color(0xFFA27896),
      Color(0xFFC46D5E),
      Color(0xFF8A9A9E),
    ];
    return fallbackPalette[index % fallbackPalette.length];
  }

  Widget _buildCategorySplitBar(
    BuildContext context,
    List<MapEntry<String, double>> sortedCategories,
    double totalSpend,
    List<LocalExpense> monthExpenses,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    if (sortedCategories.isEmpty || totalSpend <= 0) return const SizedBox.shrink();

    return CoveCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SPENDING BREAKDOWN',
                style: typography.caption.copyWith(
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              Text(
                '${sortedCategories.length} categories',
                style: typography.caption.copyWith(
                  fontSize: 11,
                  color: colors.textSubtle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Multi-segment horizontal split progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Row(
                children: List.generate(sortedCategories.length, (idx) {
                  final entry = sortedCategories[idx];
                  final fraction = (entry.value / totalSpend).clamp(0.01, 1.0);
                  final catColor = _getCategoryColor(entry.key, idx, colors);

                  return Expanded(
                    flex: (fraction * 1000).toInt().clamp(1, 1000),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: idx < sortedCategories.length - 1 ? 2.0 : 0.0,
                      ),
                      decoration: BoxDecoration(
                        color: catColor,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Category legend chips
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(sortedCategories.length, (idx) {
              final entry = sortedCategories[idx];
              final percent = ((entry.value / totalSpend) * 100).toStringAsFixed(0);
              final catColor = _getCategoryColor(entry.key, idx, colors);

              return InkWell(
                onTap: () {
                  CategoryDetailSheet.show(
                    context,
                    categoryName: entry.key,
                    allExpenses: monthExpenses,
                    totalMonthSpend: totalSpend,
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: catColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        entry.key,
                        style: typography.caption.copyWith(
                          color: colors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$percent%',
                        style: typography.caption.copyWith(
                          color: colors.textSubtle,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
