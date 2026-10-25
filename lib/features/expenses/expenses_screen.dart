import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_error_state.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../core/widgets/cove_metric_card.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_round_button.dart';
import '../../core/widgets/cove_row.dart';
import '../../core/widgets/cove_section_label.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../add/add_draft.dart';
import '../add/add_flow.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import 'category_detail_sheet.dart';
import 'expense_controller.dart';
import 'expense_detail_sheet.dart';
import 'expense_form_sheet.dart';
import 'monthly_budget_controller.dart';
import 'monthly_budget_sheet.dart';

/// v2 "Expenses" screen (`design/screens/expenses.md` & `design/screens/expenses.png`).
///
/// Order:
/// 1. [CovePageHeader] — "Expenses", month + total as the baseline readout, gold add.
/// 2. Hero card: month total in [CoveType.heroFigure], pace line against last month,
///    budget bar with a `TODAY` marker, and household person split bar.
/// 3. Every day this month — bar chart annotated on the graph itself.
/// 4. Pace cards ([CoveMetricGrid]): Pace now / On this pace / Budget runs out / Per day from here.
/// 5. Where it went — categories with `category.*` token colours; tap one to isolate
///    it in the bar and the purchase rows below.
/// 6. Every purchase — independent ledger month switcher + date-grouped [CoveRow] list.
class ExpensesScreen extends ConsumerStatefulWidget {
  final List<LocalExpense>? initialExpenses;

  const ExpensesScreen({super.key, this.initialExpenses});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  static const double _kBorderWidth = 1.0; // (literal)
  static const double _kBarHeight = 8.0; // (literal)
  static const double _kCategoryBarHeight = 10.0; // (literal)
  static const double _kCategorySegmentGap = 2.0; // (literal)
  static const double _kCategoryDotSize = 8.0; // (literal)
  static const double _kTodayMarkerHeight = 14.0; // (literal)
  static const double _kTodayMarkerWidth = 2.0; // (literal)
  static const double _kChartHeight = 112.0; // (literal)
  static const double _kBadgeVertPad = 2.0; // (literal)
  static const double _kBadgeHorizPad = 6.0; // (literal)
  static const double _kDimmedAlpha = 0.25; // (literal)

  DateTime? _ledgerMonthOverride;
  bool _showTransfers = false;
  String? _selectedCategory;

  Future<void> _handleRefresh() async {
    final homeId = ref.read(activeHomeIdProvider);
    await ref.read(syncEngineProvider).pullLatestEvents(homeId: homeId);
  }

  DateTime _resolveReferenceDate(List<LocalExpense> allExpenses) {
    if (widget.initialExpenses != null && widget.initialExpenses!.isNotEmpty) {
      DateTime latest = widget.initialExpenses!.first.expenseDate;
      for (final exp in widget.initialExpenses!) {
        if (exp.expenseDate.isAfter(latest)) {
          latest = exp.expenseDate;
        }
      }
      return latest;
    }
    return clock.now();
  }

  void _stepLedgerMonth(DateTime currentLedgerMonth, int deltaMonths) {
    setState(() {
      _ledgerMonthOverride = DateTime(
        currentLedgerMonth.year,
        currentLedgerMonth.month + deltaMonths,
        1,
      );
    });
  }

  static String _cleanCategoryName(String? rawCategory) =>
      cleanExpenseCategoryName(rawCategory);

  static Color _resolveCategoryColor(
    String category,
    int index,
    CoveTokens cv,
  ) {
    final lower = category.toLowerCase().trim();
    if (lower.contains('travel') ||
        lower.contains('flight') ||
        lower.contains('trip')) {
      return cv.categoryTravel;
    }
    if (lower.contains('grocer') || lower.contains('market')) {
      return cv.categoryGroceries;
    }
    if (lower.contains('health') ||
        lower.contains('dentist') ||
        lower.contains('med') ||
        lower.contains('shop')) {
      return cv.categoryHealth;
    }
    if (lower.contains('eat') ||
        lower.contains('dining') ||
        lower.contains('restaurant') ||
        lower.contains('cafe')) {
      return cv.categoryEatingOut;
    }
    if (lower.contains('home') ||
        lower.contains('utilit') ||
        lower.contains('electric') ||
        lower.contains('rent')) {
      return cv.categoryHome;
    }
    if (lower.contains('pet') ||
        lower.contains('lyla') ||
        lower.contains('cabo') ||
        lower.contains('luca')) {
      return cv.categoryPets;
    }
    if (lower.contains('fuel') ||
        lower.contains('petrol') ||
        lower.contains('auto') ||
        lower.contains('transport')) {
      return cv.categoryFuel;
    }
    if (lower.contains('gift') ||
        lower.contains('entertain') ||
        lower.contains('stream')) {
      return cv.categoryGifts;
    }
    final palette = <Color>[
      cv.categoryGroceries,
      cv.categoryHome,
      cv.categoryTravel,
      cv.categoryEatingOut,
      cv.categoryHealth,
      cv.categoryFuel,
      cv.categoryPets,
      cv.categoryGifts,
    ];
    return palette[index % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final outboxEvents = ref.watch(activeHomeOutboxProvider).value ?? [];
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);

    if (widget.initialExpenses != null) {
      return _buildContent(
        context,
        widget.initialExpenses!,
        outboxEvents,
        hasPartner: hasPartner,
      );
    }

    final expensesAsync = ref.watch(activeHomeExpensesProvider);

    return expensesAsync.when(
      data: (expenses) => _buildContent(
        context,
        expenses,
        outboxEvents,
        hasPartner: hasPartner,
      ),
      loading: () => Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: const CovePageInsets(child: Center(child: CoveLoading())),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: CovePageInsets(
          child: Center(
            child: CoveErrorState.generic(
              title: 'Expenses unavailable',
              description: 'Could not load expenses right now.',
              onRetry: () => ref.invalidate(activeHomeExpensesProvider),
            ),
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
    final cv = context.cv;
    final currency = ref.watch(currencyPreferenceProvider);
    final currentUser = ref.watch(authProvider).value;
    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final home = ref.watch(activeHomeProvider).value;
    final bottomPadding =
        CoveSpace.barClearance + CovePageInsets.bottomOf(context);

    if (allExpenses.isEmpty) {
      return Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: CovePageInsets(
          child: CoveMaxWidth(
            child: RefreshIndicator(
              color: cv.accentFill,
              backgroundColor: cv.surfaceCard,
              onRefresh: _handleRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(bottom: bottomPadding),
                children: [
                  CovePageHeader(
                    title: 'Expenses',
                    actions: [
                      CoveRoundButton(
                        key: const ValueKey('expenses_record_transfer_button'),
                        icon: Icons.swap_horiz_rounded,
                        variant: CoveRoundButtonVariant.ghost,
                        tooltip: 'Record a transfer',
                        semanticLabel: 'Record a transfer',
                        onPressed: () => ExpenseFormSheet.show(
                          context,
                          initialIsTransfer: true,
                        ),
                      ),
                      CoveRoundButton(
                        icon: Icons.add_rounded,
                        variant: CoveRoundButtonVariant.gold,
                        tooltip: 'Log Expense',
                        semanticLabel: 'Log Expense',
                        onPressed: () => AddFlow.show(
                          context,
                          kind: AddKind.expense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CoveSpace.section),
                  Center(
                    child: CoveEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No expenses recorded yet',
                      description:
                          'Track shared groceries, utilities, and household expenses together.',
                      action: CovePillButton(
                        label: 'Log First Expense',
                        icon: const Icon(Icons.add, size: CoveSpace.md),
                        onPressed: () => AddFlow.show(
                          context,
                          kind: AddKind.expense,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final referenceDate = _resolveReferenceDate(allExpenses);
    final standingMonth = DateTime(referenceDate.year, referenceDate.month, 1);
    final daysInStandingMonth = DateUtils.getDaysInMonth(
      standingMonth.year,
      standingMonth.month,
    );
    final standingDay = referenceDate.day.clamp(1, daysInStandingMonth);
    final daysRemaining = math.max(0, daysInStandingMonth - standingDay);
    final standingMonthName = DateFormat('MMMM').format(standingMonth);

    // Standing month expenses (used by Hero, Daily Chart, Pace Cards, Where It Went)
    final standingMonthExpenses = allExpenses.where((e) {
      return e.expenseDate.year == standingMonth.year &&
          e.expenseDate.month == standingMonth.month;
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
      final share = computeExpenseShare(exp, currentUserId: currentUser?.id);
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
      final share = computeExpenseShare(t, currentUserId: currentUser?.id);
      if (share.isPaidByViewer) {
        sentByMeTotal += t.amount;
      } else {
        sentByPartnerTotal += t.amount;
      }
    }

    // Previous month comparison
    final prevMonth = DateTime(standingMonth.year, standingMonth.month - 1, 1);
    final prevMonthName = DateFormat('MMMM').format(prevMonth);
    final daysInPrevMonth = DateUtils.getDaysInMonth(
      prevMonth.year,
      prevMonth.month,
    );
    final prevMonthActualExpenses = allExpenses.where((e) {
      return !e.isTransfer &&
          e.splitRatio > 0.0 &&
          e.expenseDate.year == prevMonth.year &&
          e.expenseDate.month == prevMonth.month;
    }).toList();

    final double prevMonthTotal = prevMonthActualExpenses.fold<double>(
      0.0,
      (acc, e) => acc + e.amount,
    );
    final double prevMonthByThisDay = prevMonthActualExpenses
        .where((e) => e.expenseDate.day <= standingDay)
        .fold<double>(0.0, (acc, e) => acc + e.amount);

    final partnerName = partnerProfile.displayName.isNotEmpty
        ? partnerProfile.displayName
        : 'Partner';
    final myName =
        userProfile.displayName.isNotEmpty ? userProfile.displayName : 'You';
    final creatorId = home?.createdBy ?? currentUser?.id ?? 'user_alex';

    // Category breakdown for standing month actual expenses
    final categoryTotals = <String, double>{};
    for (final exp in standingActualExpenses) {
      final cleanCat = _cleanCategoryName(exp.category);
      categoryTotals[cleanCat] = (categoryTotals[cleanCat] ?? 0.0) + exp.amount;
    }
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalSpendAll =
        categoryTotals.values.fold<double>(0.0, (acc, v) => acc + v);

    final categoryColorMap = <String, Color>{};
    for (var i = 0; i < sortedCategories.length; i++) {
      categoryColorMap[sortedCategories[i].key] = _resolveCategoryColor(
        sortedCategories[i].key,
        i,
        cv,
      );
    }

    // Daily spend map for standing month (respecting isolated category if active)
    final dailyTotals = List<double>.filled(daysInStandingMonth, 0.0);
    for (final exp in standingActualExpenses) {
      if (exp.splitRatio <= 0.0) continue;
      if (_selectedCategory != null &&
          _cleanCategoryName(exp.category) != _selectedCategory) {
        continue;
      }
      final dayIdx = (exp.expenseDate.day - 1).clamp(0, daysInStandingMonth - 1);
      dailyTotals[dayIdx] += exp.amount;
    }

    final double activeSharedTotal = _selectedCategory != null
        ? dailyTotals.fold<double>(0.0, (a, b) => a + b)
        : sharedMonthlyTotal;
    final double dailyPace =
        standingDay > 0 ? activeSharedTotal / standingDay : 0.0;
    final double projectedMonthTotal = dailyPace * daysInStandingMonth;
    final double prevDailyPace =
        daysInPrevMonth > 0 ? prevMonthTotal / daysInPrevMonth : 0.0;

    final monthlyBudget = ref.watch(monthlyBudgetProvider);

    // Independent ledger month state (Rule 2: browsing ledger month never disturbs standing hero)
    final ledgerMonth = _ledgerMonthOverride ?? standingMonth;
    final isLedgerAtStandingMonth =
        ledgerMonth.year == standingMonth.year &&
            ledgerMonth.month == standingMonth.month;
    final ledgerMonthExpenses = allExpenses.where((e) {
      return e.expenseDate.year == ledgerMonth.year &&
          e.expenseDate.month == ledgerMonth.month;
    }).toList();

    final ledgerFilteredExpenses = _selectedCategory == null
        ? ledgerMonthExpenses
        : ledgerMonthExpenses
            .where((e) => _cleanCategoryName(e.category) == _selectedCategory)
            .toList();

    final double ledgerMonthSharedTotal = ledgerFilteredExpenses
        .where((e) => !e.isTransfer && e.splitRatio > 0.0)
        .fold<double>(0.0, (acc, e) => acc + e.amount);

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: CovePageInsets(
        child: CoveMaxWidth(
          child: RefreshIndicator(
            color: cv.accentFill,
            backgroundColor: cv.surfaceCard,
            onRefresh: _handleRefresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. CovePageHeader — "Expenses", month + total as baseline readout, gold add
                  CovePageHeader(
                    title: 'Expenses',
                    readout:
                        '$standingMonthName · ${currency.symbol}${formatCoveAmount(sharedMonthlyTotal)}',
                    actions: [
                      CoveRoundButton(
                        key: const ValueKey('expenses_record_transfer_button'),
                        icon: Icons.swap_horiz_rounded,
                        variant: CoveRoundButtonVariant.ghost,
                        tooltip: 'Record a transfer',
                        semanticLabel: 'Record a transfer',
                        onPressed: () => ExpenseFormSheet.show(
                          context,
                          initialIsTransfer: true,
                        ),
                      ),
                      CoveRoundButton(
                        key: const ValueKey('expenses_add_button'),
                        icon: Icons.add_rounded,
                        variant: CoveRoundButtonVariant.gold,
                        tooltip: 'Log Expense',
                        semanticLabel: 'Log Expense',
                        onPressed: () => AddFlow.show(
                          context,
                          kind: AddKind.expense,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CoveSpace.md),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoveSpace.gutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 2. Hero card
                        _buildHeroCard(
                          context,
                          cv: cv,
                          currency: currency,
                          standingMonthName: standingMonthName,
                          standingDay: standingDay,
                          daysInStandingMonth: daysInStandingMonth,
                          sharedMonthlyTotal: sharedMonthlyTotal,
                          transfersMonthlyTotal: transfersMonthlyTotal,
                          sharedCount: sharedCount,
                          personalCount: personalCount,
                          transfersCount: transfersCount,
                          sentByMeTotal: sentByMeTotal,
                          sentByPartnerTotal: sentByPartnerTotal,
                          paidByMeSharedTotal: paidByMeSharedTotal,
                          paidByPartnerSharedTotal: paidByPartnerSharedTotal,
                          partnerName: partnerName,
                          prevMonthName: prevMonthName,
                          prevMonthByThisDay: prevMonthByThisDay,
                          monthlyBudget: monthlyBudget,
                        ),

                        if (!_showTransfers) ...[
                          if (sharedMonthlyTotal > 0) ...[
                            const SizedBox(height: CoveSpace.section),

                            // 3. Every day this month — annotated bar chart
                            const CoveSectionLabel.page(
                              label: 'Every day this month',
                            ),
                            const SizedBox(height: CoveSpace.md),
                            _DailySpendBarChart(
                              dailyTotals: dailyTotals,
                              standingDay: standingDay,
                              daysInMonth: daysInStandingMonth,
                              daysRemaining: daysRemaining,
                              dailyPace: dailyPace,
                              currencySymbol: currency.symbol,
                              isolatedColor: _selectedCategory != null
                                  ? categoryColorMap[_selectedCategory!]
                                  : null,
                            ),

                            const SizedBox(height: CoveSpace.lg),

                            // 4. Pace cards
                            _buildPaceCards(
                              context,
                              currency: currency,
                              standingMonth: standingMonth,
                              standingDay: standingDay,
                              daysInStandingMonth: daysInStandingMonth,
                              daysRemaining: daysRemaining,
                              sharedMonthlyTotal: sharedMonthlyTotal,
                              dailyPace: dailyPace,
                              projectedMonthTotal: projectedMonthTotal,
                              prevMonthName: prevMonthName,
                              prevMonthTotal: prevMonthTotal,
                              prevDailyPace: prevDailyPace,
                              monthlyBudget: monthlyBudget,
                            ),
                          ],

                          if (sortedCategories.isNotEmpty) ...[
                            const SizedBox(height: CoveSpace.section),

                            // 5. Where it went — categories with category.* colours
                            _buildWhereItWentSection(
                              context,
                              cv: cv,
                              currency: currency,
                              sortedCategories: sortedCategories,
                              totalSpendAll: totalSpendAll,
                              categoryColorMap: categoryColorMap,
                              standingMonthExpenses: standingMonthExpenses,
                            ),
                          ],
                        ],

                        const SizedBox(height: CoveSpace.section),

                        // 6. Every purchase — independent month switcher + date-grouped CoveRow list
                        _buildEveryPurchaseSection(
                          context,
                          cv: cv,
                          currency: currency,
                          ledgerMonth: ledgerMonth,
                          isLedgerAtStandingMonth: isLedgerAtStandingMonth,
                          ledgerExpenses: ledgerFilteredExpenses,
                          ledgerMonthSharedTotal: ledgerMonthSharedTotal,
                          currentUser: currentUser,
                          myName: myName,
                          partnerName: partnerName,
                          creatorId: creatorId,
                          outboxEvents: outboxEvents,
                          hasPartner: hasPartner,
                          categoryColorMap: categoryColorMap,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(
    BuildContext context, {
    required CoveTokens cv,
    required CurrencyOption currency,
    required String standingMonthName,
    required int standingDay,
    required int daysInStandingMonth,
    required double sharedMonthlyTotal,
    required double transfersMonthlyTotal,
    required int sharedCount,
    required int personalCount,
    required int transfersCount,
    required double sentByMeTotal,
    required double sentByPartnerTotal,
    required double paidByMeSharedTotal,
    required double paidByPartnerSharedTotal,
    required String partnerName,
    required String prevMonthName,
    required double prevMonthByThisDay,
    required double? monthlyBudget,
  }) {
    final daysLeft = math.max(0, daysInStandingMonth - standingDay);
    final hasPrevComparison = !_showTransfers && prevMonthByThisDay > 0;
    final double prevDelta = sharedMonthlyTotal - prevMonthByThisDay;
    final bool isSpendingLess = prevDelta <= 0;
    final int prevPct = prevMonthByThisDay > 0
        ? ((prevDelta.abs() / prevMonthByThisDay) * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(CoveSpace.gutter),
      decoration: BoxDecoration(
        color: cv.surfaceCard,
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveRadius.hero),
        ),
        border: Border.all(
          color: cv.lineHairline,
          width: _kBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top caption line: MONTH · SHARED and DAY N OF M
          Row(
            children: [
              Expanded(
                child: Text(
                  _showTransfers
                      ? '${standingMonthName.toUpperCase()} · TRANSFERS'
                      : '${standingMonthName.toUpperCase()} · SHARED',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoveType.capsCard.copyWith(color: cv.textTertiary),
                ),
              ),
              const SizedBox(width: CoveSpace.sm),
              Text(
                'DAY $standingDay OF $daysInStandingMonth',
                style: CoveType.capsCard.copyWith(color: cv.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: CoveSpace.sm),

          // Expenditure | Transfers segmented pill
          Container(
            decoration: BoxDecoration(
              color: cv.surfaceRow,
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.pill),
              ),
              border: Border.all(
                color: cv.lineHairline,
                width: _kBorderWidth,
              ),
            ),
            padding: const EdgeInsets.all(_kBadgeVertPad),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCardSegment(
                  cv: cv,
                  label: 'Expenditure',
                  isSelected: !_showTransfers,
                  onTap: () => setState(() => _showTransfers = false),
                ),
                _buildCardSegment(
                  cv: cv,
                  label: 'Transfers',
                  isSelected: _showTransfers,
                  onTap: () => setState(() => _showTransfers = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: CoveSpace.md),

          // Hero figure in CoveType.heroFigure
          Text(
            _showTransfers
                ? '${currency.symbol}${formatCoveAmount(transfersMonthlyTotal)}'
                : '${currency.symbol}${formatCoveAmount(sharedMonthlyTotal)}',
            style: CoveType.heroFigure.copyWith(color: cv.accentTint),
          ),
          const SizedBox(height: CoveSpace.xs),

          // Pace comparison line against last month + item counts
          if (_showTransfers)
            Text(
              '$transfersCount transfer${transfersCount == 1 ? "" : "s"} • You sent ${currency.symbol}${formatCoveAmount(sentByMeTotal)}${sentByPartnerTotal > 0 ? " • $partnerName sent ${currency.symbol}${formatCoveAmount(sentByPartnerTotal)}" : ""}',
              style: CoveType.rowSub.copyWith(color: cv.textSecondary),
            )
          else ...[
            if (hasPrevComparison)
              RichText(
                text: TextSpan(
                  style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                  children: [
                    TextSpan(
                      text:
                          '${currency.symbol}${formatCoveAmount(prevDelta.abs())} ${isSpendingLess ? "less" : "more"}',
                      style: CoveType.rowSub.copyWith(
                        color: isSpendingLess ? cv.moneyLess : cv.moneyMore,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' than $prevMonthName by this day · $prevPct% ${isSpendingLess ? "down" : "up"}',
                    ),
                  ],
                ),
              )
            else
              Text(
                '$sharedCount shared item${sharedCount == 1 ? "" : "s"}${personalCount > 0 ? " • $personalCount personal" : ""} · vs ${currency.symbol}0 in $prevMonthName',
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
          ],

          // Budget bar with TODAY marker
          if (!_showTransfers) ...[
            if (monthlyBudget != null && monthlyBudget > 0) ...[
              const SizedBox(height: CoveSpace.md),
              _buildBudgetBlock(
                context,
                cv: cv,
                currency: currency,
                sharedMonthlyTotal: sharedMonthlyTotal,
                monthlyBudget: monthlyBudget,
                standingDay: standingDay,
                daysInStandingMonth: daysInStandingMonth,
                daysLeft: daysLeft,
              ),
            ] else ...[
              const SizedBox(height: CoveSpace.sm),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => MonthlyBudgetSheet.show(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: CoveSpace.xs),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        size: CoveSpace.md,
                        color: cv.accentText,
                      ),
                      const SizedBox(width: CoveSpace.xs),
                      Text(
                        'Set monthly budget target',
                        style: CoveType.rowSub.copyWith(
                          color: cv.accentText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Person A / Person B split bar at foot of hero card
            if (sharedMonthlyTotal > 0) ...[
              const SizedBox(height: CoveSpace.md),
              ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(CoveRadius.pill),
                ),
                child: SizedBox(
                  height: _kBarHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (paidByMeSharedTotal > 0)
                        Expanded(
                          flex: ((paidByMeSharedTotal / sharedMonthlyTotal) *
                                  1000)
                              .round()
                              .clamp(1, 1000),
                          child: DecoratedBox(
                            decoration: BoxDecoration(gradient: cv.personA),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      if (paidByMeSharedTotal > 0 &&
                          paidByPartnerSharedTotal > 0)
                        const SizedBox(width: _kCategorySegmentGap),
                      if (paidByPartnerSharedTotal > 0)
                        Expanded(
                          flex: ((paidByPartnerSharedTotal /
                                      sharedMonthlyTotal) *
                                  1000)
                              .round()
                              .clamp(1, 1000),
                          child: DecoratedBox(
                            decoration: BoxDecoration(gradient: cv.personB),
                            child: const SizedBox.expand(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CoveSpace.xs),
              Row(
                children: [
                  Expanded(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                        children: [
                          const TextSpan(text: 'You '),
                          TextSpan(
                            text:
                                '${currency.symbol}${formatCoveAmount(paidByMeSharedTotal)}',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: CoveSpace.sm),
                  Flexible(
                    child: RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                        children: [
                          TextSpan(text: '$partnerName '),
                          TextSpan(
                            text:
                                '${currency.symbol}${formatCoveAmount(paidByPartnerSharedTotal)}',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBudgetBlock(
    BuildContext context, {
    required CoveTokens cv,
    required CurrencyOption currency,
    required double sharedMonthlyTotal,
    required double monthlyBudget,
    required int standingDay,
    required int daysInStandingMonth,
    required int daysLeft,
  }) {
    final isOverBudget = sharedMonthlyTotal > monthlyBudget;
    final remaining =
        (monthlyBudget - sharedMonthlyTotal).clamp(0.0, double.infinity);
    final overshoot =
        (sharedMonthlyTotal - monthlyBudget).clamp(0.0, double.infinity);
    final percentUsed = (sharedMonthlyTotal / monthlyBudget).clamp(0.0, 1.0);
    final todayFraction =
        (standingDay / daysInStandingMonth).clamp(0.05, 0.95);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => MonthlyBudgetSheet.show(context),
      child: Container(
        padding: const EdgeInsets.all(CoveSpace.md),
        decoration: BoxDecoration(
          color: cv.surfaceRow,
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.inline),
          ),
          border: Border.all(
            color: isOverBudget ? cv.statusAlert : cv.lineHairline,
            width: _kBorderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isOverBudget ? 'SHOT UP · OVER BUDGET' : 'MONTHLY BUDGET',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoveType.capsCard.copyWith(
                      color: isOverBudget ? cv.statusAlertText : cv.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: CoveSpace.sm),
                Flexible(
                  child: Text(
                    isOverBudget
                        ? 'Shot up by ${currency.symbol}${formatCoveAmount(overshoot)}'
                        : '${currency.symbol}${formatCoveAmount(remaining)} remaining',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoveType.rowSub.copyWith(
                      color: isOverBudget ? cv.moneyMore : cv.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.sm),

            // Progress bar with TODAY marker
            LayoutBuilder(
              builder: (context, constraints) {
                final markerX = constraints.maxWidth * todayFraction;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: _kTodayMarkerHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(CoveRadius.pill),
                            ),
                            child: SizedBox(
                              height: _kBarHeight,
                              width: double.infinity,
                              child: ColoredBox(
                                color: cv.lineStrong,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FractionallySizedBox(
                                    widthFactor:
                                        isOverBudget ? 1.0 : percentUsed,
                                    child: ColoredBox(
                                      color: isOverBudget
                                          ? cv.statusAlert
                                          : cv.accentFill,
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: (markerX - _kTodayMarkerWidth / 2).clamp(
                              0.0,
                              constraints.maxWidth - _kTodayMarkerWidth,
                            ),
                            top: 0,
                            bottom: 0,
                            child: ColoredBox(
                              color: cv.textPrimary,
                              child: const SizedBox(width: _kTodayMarkerWidth),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CoveSpace.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TODAY',
                          style: CoveType.capsCard.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                        Text(
                          '$daysLeft day${daysLeft == 1 ? "" : "s"} left',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: CoveSpace.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${currency.symbol}${formatCoveAmount(sharedMonthlyTotal)} spent',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                  ),
                ),
                const SizedBox(width: CoveSpace.sm),
                Flexible(
                  child: Text(
                    'Target: ${currency.symbol}${formatCoveAmount(monthlyBudget)} (${(percentUsed * 100).toInt()}%)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaceCards(
    BuildContext context, {
    required CurrencyOption currency,
    required DateTime standingMonth,
    required int standingDay,
    required int daysInStandingMonth,
    required int daysRemaining,
    required double sharedMonthlyTotal,
    required double dailyPace,
    required double projectedMonthTotal,
    required String prevMonthName,
    required double prevMonthTotal,
    required double prevDailyPace,
    required double? monthlyBudget,
  }) {
    // 1. PACE NOW
    final roundedDailyPace = dailyPace.roundToDouble();
    final roundedPrevDailyPace = prevDailyPace.roundToDouble();
    final roundedProjected = projectedMonthTotal.roundToDouble();

    final String paceNowSub = prevDailyPace > 0
        ? '$prevMonthName ran at ${currency.symbol}${formatCoveAmount(roundedPrevDailyPace)}/day'
        : 'vs ${currency.symbol}0/day in $prevMonthName';

    // 2. ON THIS PACE
    final bool hasBudget = monthlyBudget != null && monthlyBudget > 0;
    final bool isProjOverBudget =
        hasBudget && projectedMonthTotal > monthlyBudget;
    final String onThisPaceSub;
    if (hasBudget) {
      final diffPct =
          (((projectedMonthTotal - monthlyBudget) / monthlyBudget) * 100)
              .round();
      final sign = diffPct >= 0 ? '+$diffPct%' : '$diffPct%';
      onThisPaceSub = '$sign against the budget';
    } else if (prevMonthTotal > 0) {
      final diffPct =
          (((projectedMonthTotal - prevMonthTotal) / prevMonthTotal) * 100)
              .round();
      final sign = diffPct >= 0 ? '+$diffPct%' : '$diffPct%';
      onThisPaceSub = '$sign vs $prevMonthName';
    } else {
      onThisPaceSub =
          'across $daysInStandingMonth days at ${currency.symbol}${formatCoveAmount(roundedDailyPace)}/day';
    }

    // 3. BUDGET RUNS OUT
    final String budgetRunsOutValue;
    final String budgetRunsOutSub;
    final CoveMetricValueTone budgetRunsOutTone;
    if (hasBudget && dailyPace > 0) {
      final int runOutDay = (monthlyBudget / dailyPace).floor();
      if (runOutDay < daysInStandingMonth) {
        final clampedDay = runOutDay.clamp(1, daysInStandingMonth);
        final runOutDate = DateTime(
          standingMonth.year,
          standingMonth.month,
          clampedDay,
        );
        final daysShort = daysInStandingMonth - clampedDay;
        budgetRunsOutValue = DateFormat('MMM d').format(runOutDate);
        budgetRunsOutSub =
            '$daysShort day${daysShort == 1 ? "" : "s"} before the month does';
        budgetRunsOutTone = CoveMetricValueTone.moneyMore;
      } else {
        final endOfMonthDate = DateTime(
          standingMonth.year,
          standingMonth.month,
          daysInStandingMonth,
        );
        budgetRunsOutValue = DateFormat('MMM d').format(endOfMonthDate);
        budgetRunsOutSub =
            'lasts all $daysInStandingMonth days of the month';
        budgetRunsOutTone = CoveMetricValueTone.moneyLess;
      }
    } else {
      budgetRunsOutValue = '$daysRemaining days';
      budgetRunsOutSub = 'left in ${DateFormat('MMMM').format(standingMonth)}';
      budgetRunsOutTone = CoveMetricValueTone.accentTint;
    }

    // 4. PER DAY FROM HERE
    final double perDayFromHere;
    final String perDayFromHereSub;
    if (hasBudget && daysRemaining > 0) {
      final remainingBudget =
          (monthlyBudget - sharedMonthlyTotal).clamp(0.0, double.infinity);
      perDayFromHere = remainingBudget / daysRemaining;
      final delta = perDayFromHere - dailyPace;
      final word = delta < 0 ? 'less' : 'more';
      perDayFromHereSub =
          '${currency.symbol}${formatCoveAmount(delta.abs().roundToDouble())} $word than now, each day';
    } else {
      perDayFromHere = dailyPace;
      perDayFromHereSub =
          'matching your ${currency.symbol}${formatCoveAmount(roundedDailyPace)}/day pace';
    }
    final roundedPerDayFromHere = perDayFromHere.roundToDouble();

    return CoveMetricGrid(
      children: [
        CoveMetricCard(
          label: 'Pace now',
          value: '${currency.symbol}${formatCoveAmount(roundedDailyPace)}/day',
          subtitle: paceNowSub,
        ),
        CoveMetricCard(
          label: 'On this pace',
          value: '${currency.symbol}${formatCoveAmount(roundedProjected)}',
          subtitle: onThisPaceSub,
          valueTone: isProjOverBudget
              ? CoveMetricValueTone.moneyMore
              : CoveMetricValueTone.accentTint,
        ),
        CoveMetricCard(
          label: 'Budget runs out',
          value: budgetRunsOutValue,
          subtitle: budgetRunsOutSub,
          valueTone: budgetRunsOutTone,
        ),
        CoveMetricCard(
          label: 'Per day from here',
          value:
              '${currency.symbol}${formatCoveAmount(roundedPerDayFromHere)}/day',
          subtitle: perDayFromHereSub,
        ),
      ],
    );
  }

  Widget _buildWhereItWentSection(
    BuildContext context, {
    required CoveTokens cv,
    required CurrencyOption currency,
    required List<MapEntry<String, double>> sortedCategories,
    required double totalSpendAll,
    required Map<String, Color> categoryColorMap,
    required List<LocalExpense> standingMonthExpenses,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoveSectionLabel.page(
          label: 'Where it went',
          readout: '${sortedCategories.length} categories',
        ),
        const SizedBox(height: CoveSpace.md),

        // Proportional category split bar
        if (totalSpendAll > 0) ...[
          ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveRadius.pill),
            ),
            child: SizedBox(
              height: _kCategoryBarHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(sortedCategories.length, (idx) {
                  final entry = sortedCategories[idx];
                  final fraction =
                      (entry.value / totalSpendAll).clamp(0.01, 1.0);
                  final baseColor =
                      categoryColorMap[entry.key] ?? cv.categoryGroceries;
                  final isDimmed = _selectedCategory != null &&
                      _selectedCategory != entry.key;
                  final barColor = isDimmed
                      ? baseColor.withValues(alpha: _kDimmedAlpha)
                      : baseColor;

                  return Expanded(
                    flex: (fraction * 1000).round().clamp(1, 1000),
                    child: Container(
                      margin: EdgeInsets.only(
                        right: idx < sortedCategories.length - 1
                            ? _kCategorySegmentGap
                            : 0.0,
                      ),
                      color: barColor,
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: CoveSpace.md),
        ],

        // Tappable category pills (tap to isolate in bar & rows, long-press for CategoryDetailSheet)
        Wrap(
          spacing: CoveSpace.sm,
          runSpacing: CoveSpace.sm,
          children: List.generate(sortedCategories.length, (idx) {
            final entry = sortedCategories[idx];
            final catColor =
                categoryColorMap[entry.key] ?? cv.categoryGroceries;
            final isSelected = _selectedCategory == entry.key;

            return Semantics(
              button: true,
              selected: isSelected,
              label:
                  '${entry.key}, ${currency.symbol}${formatCoveAmount(entry.value)}',
              child: GestureDetector(
                key: ValueKey('category_pill_${entry.key}'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    _selectedCategory = isSelected ? null : entry.key;
                  });
                },
                onLongPress: () {
                  CategoryDetailSheet.show(
                    context,
                    categoryName: entry.key,
                    allExpenses: standingMonthExpenses,
                    totalMonthSpend: totalSpendAll,
                  );
                },
                child: AnimatedContainer(
                  duration: CoveMotion.q(context),
                  curve: CoveMotion.easing,
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.md,
                    vertical: CoveSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? cv.accentWash : cv.surfaceCard,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(CoveRadius.pill),
                    ),
                    border: Border.all(
                      color: isSelected ? cv.accentFill : cv.lineHairline,
                      width: _kBorderWidth,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: _kCategoryDotSize,
                        height: _kCategoryDotSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: catColor,
                        ),
                      ),
                      const SizedBox(width: CoveSpace.xs),
                      Text(
                        entry.key,
                        style: CoveType.rowSub.copyWith(
                          color: isSelected ? cv.accentText : cv.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: CoveSpace.xs),
                      Text(
                        '${currency.symbol}${formatCoveAmount(entry.value)}',
                        style: CoveType.rowSub.copyWith(
                          color: isSelected ? cv.accentText : cv.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildEveryPurchaseSection(
    BuildContext context, {
    required CoveTokens cv,
    required CurrencyOption currency,
    required DateTime ledgerMonth,
    required bool isLedgerAtStandingMonth,
    required List<LocalExpense> ledgerExpenses,
    required double ledgerMonthSharedTotal,
    required CoveUser? currentUser,
    required String myName,
    required String partnerName,
    required String creatorId,
    required List<LocalOutboxEvent> outboxEvents,
    required bool hasPartner,
    required Map<String, Color> categoryColorMap,
  }) {
    final ledgerMonthLabel = DateFormat('MMMM y').format(ledgerMonth);
    final count = ledgerExpenses.length;
    final soFarSuffix = isLedgerAtStandingMonth ? ' · so far' : '';

    // Group ledger expenses by calendar date descending
    final sortedExpenses = List<LocalExpense>.from(ledgerExpenses)
      ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

    final dayGroups = <DateTime, List<LocalExpense>>{};
    for (final exp in sortedExpenses) {
      final dayKey = DateTime(
        exp.expenseDate.year,
        exp.expenseDate.month,
        exp.expenseDate.day,
      );
      dayGroups.putIfAbsent(dayKey, () => <LocalExpense>[]).add(exp);
    }
    final sortedDayKeys = dayGroups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoveSectionLabel.page(
          label: 'Every purchase',
          readout: _selectedCategory != null ? _selectedCategory! : '$count total',
        ),
        const SizedBox(height: CoveSpace.md),

        // Independent ledger month switcher
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CoveSpace.md,
            vertical: CoveSpace.sm,
          ),
          decoration: BoxDecoration(
            color: cv.surfaceCard,
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveRadius.card),
            ),
            border: Border.all(
              color: cv.lineHairline,
              width: _kBorderWidth,
            ),
          ),
          child: Row(
            children: [
              CoveRoundButton.stepper(
                key: const ValueKey('ledger_prev_month'),
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous ledger month',
                semanticLabel: 'Previous ledger month',
                onPressed: () => _stepLedgerMonth(ledgerMonth, -1),
              ),
              const SizedBox(width: CoveSpace.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ledgerMonthLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                    ),
                    Text(
                      '${currency.symbol}${formatCoveAmount(ledgerMonthSharedTotal)} · $count purchase${count == 1 ? "" : "s"}$soFarSuffix',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CoveSpace.sm),
              CoveRoundButton.stepper(
                key: const ValueKey('ledger_next_month'),
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next ledger month',
                semanticLabel: 'Next ledger month',
                onPressed: () => _stepLedgerMonth(ledgerMonth, 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: CoveSpace.lg),

        if (sortedDayKeys.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CoveSpace.lg),
            child: Text(
              'No purchases recorded in $ledgerMonthLabel.',
              style: CoveType.body.copyWith(color: cv.textTertiary),
            ),
          )
        else
          for (var gIdx = 0; gIdx < sortedDayKeys.length; gIdx++) ...[
            if (gIdx > 0) const SizedBox(height: CoveSpace.lg),
            _buildDayGroup(
              context,
              cv: cv,
              currency: currency,
              dayDate: sortedDayKeys[gIdx],
              dayExpenses: dayGroups[sortedDayKeys[gIdx]]!,
              currentUser: currentUser,
              myName: myName,
              partnerName: partnerName,
              creatorId: creatorId,
              outboxEvents: outboxEvents,
              hasPartner: hasPartner,
            ),
          ],
      ],
    );
  }

  Widget _buildDayGroup(
    BuildContext context, {
    required CoveTokens cv,
    required CurrencyOption currency,
    required DateTime dayDate,
    required List<LocalExpense> dayExpenses,
    required CoveUser? currentUser,
    required String myName,
    required String partnerName,
    required String creatorId,
    required List<LocalOutboxEvent> outboxEvents,
    required bool hasPartner,
  }) {
    final dayLabel = DateFormat('MMM d').format(dayDate).toUpperCase();
    final dayTotal = dayExpenses
        .where((e) => !e.isTransfer)
        .fold<double>(0.0, (acc, e) => acc + e.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              dayLabel,
              style: CoveType.capsCard.copyWith(color: cv.textTertiary),
            ),
            const SizedBox(width: CoveSpace.md),
            Expanded(
              child: ColoredBox(
                color: cv.lineHairline,
                child: const SizedBox(height: _kBorderWidth),
              ),
            ),
            const SizedBox(width: CoveSpace.md),
            Text(
              '${currency.symbol}${formatCoveAmount(dayTotal)}',
              style: CoveType.readout.copyWith(color: cv.textSecondary),
            ),
            const SizedBox(width: CoveSpace.sm),
            CoveRoundButton.stepper(
              icon: Icons.add_rounded,
              tooltip: 'Log Expense',
              semanticLabel: 'Log Expense',
              onPressed: () => AddFlow.show(
                context,
                kind: AddKind.expense,
                anchor: dayDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: CoveSpace.xs),
        for (var i = 0; i < dayExpenses.length; i++)
          _buildExpenseRow(
            context,
            cv: cv,
            currency: currency,
            expense: dayExpenses[i],
            currentUser: currentUser,
            myName: myName,
            partnerName: partnerName,
            creatorId: creatorId,
            outbox: outboxEvents,
            hasPartner: hasPartner,
            isLast: i == dayExpenses.length - 1,
          ),
      ],
    );
  }

  Widget _buildExpenseRow(
    BuildContext context, {
    required CoveTokens cv,
    required CurrencyOption currency,
    required LocalExpense expense,
    required CoveUser? currentUser,
    required String myName,
    required String partnerName,
    required String creatorId,
    required List<LocalOutboxEvent> outbox,
    required bool hasPartner,
    required bool isLast,
  }) {
    final share = computeExpenseShare(
      expense,
      currentUserId: currentUser?.id,
    );
    final visibility = share.visibility;
    final isMe = share.isPaidByViewer;
    final effectiveActorId = isMe
        ? (currentUser?.id ?? 'user_alex')
        : (expense.paidBy == 'user_alex' ? 'user_sarah' : expense.paidBy);
    final person = CoveAvatar.resolvePerson(
      homeCreatedBy: creatorId,
      actorUserId: effectiveActorId,
    );
    final payerInitialName = isMe ? myName : partnerName;
    final dateFormatted = DateFormat('MMM d').format(expense.expenseDate);

    final tickStatus = resolveCoveSyncStatus(
      entityId: expense.id,
      outbox: outbox,
      isPrivate: visibility == ExpenseVisibility.privateToMe,
      hasPartner: hasPartner,
    );

    final isTransfer = expense.isTransfer;
    final String? pmLabel = formatExpensePaymentMethod(expense.paymentMethod);

    final String subtitleText;
    if (isTransfer) {
      final directionText = isMe
          ? 'You transferred to $partnerName'
          : '$partnerName transferred to You';
      subtitleText = [
        directionText,
        dateFormatted,
        ?pmLabel,
      ].join(' · ');
    } else {
      final cleanCat = _cleanCategoryName(expense.category);
      subtitleText = [
        cleanCat,
        ?pmLabel,
        dateFormatted,
      ].join(' · ');
    }

    String? badgeLabel;
    if (isTransfer) {
      badgeLabel = 'Transfer';
    } else if (visibility == ExpenseVisibility.partnerCanSee) {
      badgeLabel = '$partnerName sees';
    } else if (visibility == ExpenseVisibility.privateToMe) {
      badgeLabel = 'Private';
    }

    return Dismissible(
      key: ValueKey('exp_${expense.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: CoveSpace.gutter),
        color: cv.statusAlert,
        child: Icon(
          Icons.delete_outline,
          color: cv.textPrimary,
          size: CoveSpace.gutter,
        ),
      ),
      onDismissed: (_) async {
        try {
          await ref.read(expenseControllerProvider).deleteExpense(
                expense.id,
                visibility: visibility,
              );
        } catch (e) {
          debugPrint('[ExpensesScreen] Error deleting expense: $e');
        }
        if (context.mounted) {
          CoveUndoToast.show(
            context,
            message: 'Deleted "${expense.title}"',
            onUndo: () async {
              await ref
                  .read(expenseControllerProvider)
                  .restoreExpense(expense);
            },
          );
        }
      },
      child: CoveRow(
        avatar: CoveAvatar.row(
          person: person,
          nameOrInitial: payerInitialName,
        ),
        title: expense.title,
        subtitle: subtitleText,
        isLast: isLast,
        onTap: () => ExpenseDetailSheet.show(context, expense),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeLabel != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: _kBadgeHorizPad,
                  vertical: _kBadgeVertPad,
                ),
                decoration: BoxDecoration(
                  color: cv.accentWash,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(CoveRadius.pill),
                  ),
                  border: Border.all(
                    color: cv.lineStrong,
                    width: _kBorderWidth,
                  ),
                ),
                child: Text(
                  badgeLabel,
                  style: CoveType.barLabel.copyWith(color: cv.accentText),
                ),
              ),
              const SizedBox(width: CoveSpace.xs),
            ],
            Text(
              '${currency.symbol}${formatCoveAmount(expense.amount)}',
              style: CoveType.cardFigure.copyWith(color: cv.textPrimary),
            ),
            const SizedBox(width: CoveSpace.xs),
            CoveSyncTick(status: tickStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSegment({
    required CoveTokens cv,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: CoveMotion.q(context),
        curve: CoveMotion.easing,
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.md,
          vertical: CoveSpace.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? cv.surfaceCard : Colors.transparent,
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.pill),
          ),
          border: isSelected
              ? Border.all(color: cv.accentFill, width: _kBorderWidth)
              : null,
        ),
        child: Text(
          label,
          style: CoveType.rowSub.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? cv.accentText : cv.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Annotated bar chart for "Every day this month" (`design/screens/expenses.md`).
class _DailySpendBarChart extends StatelessWidget {
  final List<double> dailyTotals;
  final int standingDay;
  final int daysInMonth;
  final int daysRemaining;
  final double dailyPace;
  final String currencySymbol;
  final Color? isolatedColor;

  static const double _kChartHeight =
      _ExpensesScreenState._kChartHeight; // 112.0dp
  static const double _kBarRadius = 3.0; // (literal)
  static const double _kBorderWidth = 1.0; // (literal)
  static const double _kMinElapsedBarHeight = 4.0; // (literal)

  const _DailySpendBarChart({
    required this.dailyTotals,
    required this.standingDay,
    required this.daysInMonth,
    required this.daysRemaining,
    required this.dailyPace,
    required this.currencySymbol,
    this.isolatedColor,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    double maxVal = dailyPace * 1.6;
    for (final v in dailyTotals) {
      if (v > maxVal) maxVal = v;
    }
    if (maxVal <= 0) maxVal = 1.0;

    final paceFraction = (dailyPace / maxVal).clamp(0.12, 0.85);
    final activeBarColor = isolatedColor ?? cv.accentFill;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top-right graph annotation for remaining future days
        if (daysRemaining > 0)
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$daysRemaining DAY${daysRemaining == 1 ? "" : "S"} STILL TO COME',
                  style: CoveType.capsCard.copyWith(color: cv.accentText),
                ),
                Text(
                  'drawn at the pace you are keeping',
                  style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                ),
              ],
            ),
          ),
        const SizedBox(height: CoveSpace.xs),

        SizedBox(
          height: _kChartHeight,
          child: Stack(
            alignment: Alignment.bottomLeft,
            children: [
              // Horizontal dashed pace line + inline pace annotation on the graph
              Positioned(
                left: 0,
                right: 0,
                bottom: _kChartHeight * paceFraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$currencySymbol${formatCoveAmount(dailyPace.roundToDouble())} A DAY',
                      style: CoveType.capsCard.copyWith(color: cv.textSecondary),
                    ),
                    const SizedBox(height: 2.0), // (literal)
                    ColoredBox(
                      color: cv.lineStrong,
                      child: const SizedBox(
                        width: double.infinity,
                        height: _kBorderWidth,
                      ),
                    ),
                  ],
                ),
              ),

              // Daily bars (1 .. daysInMonth)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(daysInMonth, (index) {
                  final dayNum = index + 1;
                  final isFuture = dayNum > standingDay;
                  final value = dailyTotals[index];
                  final double barHeight;
                  if (isFuture) {
                    barHeight = (_kChartHeight * paceFraction).clamp(
                      _kMinElapsedBarHeight,
                      _kChartHeight,
                    );
                  } else if (value <= 0) {
                    barHeight = _kMinElapsedBarHeight;
                  } else {
                    barHeight = ((value / maxVal) * (_kChartHeight - 16.0))
                        .clamp(_kMinElapsedBarHeight, _kChartHeight - 16.0);
                  }

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 1.0, // (literal)
                      ),
                      child: Container(
                        height: barHeight,
                        decoration: BoxDecoration(
                          color: isFuture
                              ? Colors.transparent
                              : (value > 0 ? activeBarColor : cv.lineStrong),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(_kBarRadius),
                          ),
                          border: isFuture
                              ? Border.all(
                                  color: cv.lineStrong,
                                  width: _kBorderWidth,
                                )
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: CoveSpace.xs),

        // Day axis ticks: 1, 7, 14, 21, daysInMonth
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('1', style: CoveType.rowSub.copyWith(color: cv.textTertiary)),
            Text('7', style: CoveType.rowSub.copyWith(color: cv.textTertiary)),
            Text('14', style: CoveType.rowSub.copyWith(color: cv.textTertiary)),
            Text('21', style: CoveType.rowSub.copyWith(color: cv.textTertiary)),
            Text(
              '$daysInMonth',
              style: CoveType.rowSub.copyWith(color: cv.textTertiary),
            ),
          ],
        ),
      ],
    );
  }
}
