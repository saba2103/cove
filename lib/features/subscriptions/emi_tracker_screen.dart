import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/cove_theme.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../profile/preferences_controller.dart';
import 'commitment_detail_sheet.dart';
import 'commitment_models.dart';
import 'subscription_form_sheet.dart';

enum EmiProgressDisplayMode {
  tenure, // n / total months paid
  relativeShare, // EMI amount relative to other loans / monthly outflow
}

class EmiTrackerScreen extends ConsumerStatefulWidget {
  final List<LocalSubscription>? initialSubscriptions;

  const EmiTrackerScreen({
    super.key,
    this.initialSubscriptions,
  });

  @override
  ConsumerState<EmiTrackerScreen> createState() => _EmiTrackerScreenState();
}

class _EmiTrackerScreenState extends ConsumerState<EmiTrackerScreen> {
  EmiProgressDisplayMode _progressMode = EmiProgressDisplayMode.tenure;
  bool _sortAscending = false; // default descending: largest outstanding balance first

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.watch(currencyPreferenceProvider);

    if (widget.initialSubscriptions != null) {
      return _buildScaffold(context, widget.initialSubscriptions!, currency);
    }

    final subscriptionsAsync = ref.watch(activeHomeSubscriptionsProvider);
    return subscriptionsAsync.when(
      data: (subscriptions) => _buildScaffold(context, subscriptions, currency),
      loading: () => Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(
            'EMI Outstanding',
            style: typography.headline.copyWith(fontSize: 20),
          ),
        ),
        body: const Center(child: CoveLoading()),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text(
            'EMI Outstanding',
            style: typography.headline.copyWith(fontSize: 20),
          ),
        ),
        body: Center(
          child: Text(
            'Could not load EMIs right now',
            style: typography.bodyRegular.copyWith(color: colors.textMuted),
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    List<LocalSubscription> subscriptions,
    dynamic currency,
  ) {
    final colors = context.colors;
    final typography = context.typography;

    // Filter active and completed EMIs
    final allActiveEmis = subscriptions
        .where((s) => s.isEmi && s.isActive && !s.isEmiFinished)
        .toList();
    final completedEmis = subscriptions
        .where((s) => s.isEmi && s.isEmiFinished)
        .toList();

    // Sort active EMIs
    final sortedEmis = List<LocalSubscription>.from(allActiveEmis);
    sortedEmis.sort((a, b) {
      final remA = (a.emiProgress?.totalInstallments ?? 1) - (a.emiProgress?.paidInstallments ?? 0);
      final outA = remA * a.amount;
      final remB = (b.emiProgress?.totalInstallments ?? 1) - (b.emiProgress?.paidInstallments ?? 0);
      final outB = remB * b.amount;
      return _sortAscending ? outA.compareTo(outB) : outB.compareTo(outA);
    });

    // Compute totals
    double totalOutstanding = 0.0;
    double totalPaid = 0.0;
    double totalMonthlyOutflow = 0.0;
    double maxMonthlyEmi = 0.0;

    for (final emi in allActiveEmis) {
      final paid = emi.emiProgress?.paidInstallments ?? 0;
      final total = emi.emiProgress?.totalInstallments ?? (emi.totalInstallments ?? 1);
      final rem = (total - paid).clamp(0, total);
      totalOutstanding += rem * emi.amount;
      totalPaid += paid * emi.amount;
      totalMonthlyOutflow += emi.amount;
      maxMonthlyEmi = max(maxMonthlyEmi, emi.amount);
    }

    final totalLoanValue = totalOutstanding + totalPaid;
    final overallPayoffPercent = totalLoanValue > 0
        ? (totalPaid / totalLoanValue).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'EMI Outstanding',
          style: typography.headline.copyWith(fontSize: 20),
        ),
        actions: [
          IconButton(
            tooltip: 'Add Loan or EMI',
            icon: const Icon(Icons.add, size: 22),
            onPressed: () => SubscriptionFormSheet.show(context),
          ),
        ],
      ),
      body: allActiveEmis.isEmpty && completedEmis.isEmpty
          ? _buildEmptyState(context)
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // 1. Top Card: Total Outstanding Hero
                _buildTotalHeroCard(
                  context,
                  currency: currency,
                  totalOutstanding: totalOutstanding,
                  totalPaid: totalPaid,
                  totalMonthlyOutflow: totalMonthlyOutflow,
                  activeCount: allActiveEmis.length,
                  payoffRatio: overallPayoffPercent,
                ),
                const SizedBox(height: 20),

                // 2. Universal Controls Row (Mode Switch & Sort Toggle)
                if (allActiveEmis.isNotEmpty) ...[
                  _buildControlsRow(context),
                  const SizedBox(height: 14),
                ],

                // 3. List of Active EMIs
                if (allActiveEmis.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'All EMIs and loans are paid off!',
                        style: typography.bodyRegular.copyWith(
                          color: colors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                else
                  ...sortedEmis.map((emi) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildEmiCard(
                          context,
                          emi: emi,
                          currency: currency,
                          totalMonthlyOutflow: totalMonthlyOutflow,
                          maxMonthlyEmi: maxMonthlyEmi,
                        ),
                      )),

                // 4. Completed EMIs Section (if any)
                if (completedEmis.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: Color(0xFF4CAF50)),
                      const SizedBox(width: 8),
                      Text(
                        'COMPLETED LOANS (${completedEmis.length})',
                        style: typography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: colors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...completedEmis.map((emi) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildCompletedEmiCard(context, emi: emi, currency: currency),
                      )),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildTotalHeroCard(
    BuildContext context, {
    required dynamic currency,
    required double totalOutstanding,
    required double totalPaid,
    required double totalMonthlyOutflow,
    required int activeCount,
    required double payoffRatio,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return CoveCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL OUTSTANDING',
                  style: typography.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: colors.textSubtle,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$activeCount active ${activeCount == 1 ? 'loan' : 'loans'}',
                    style: typography.caption.copyWith(
                      color: colors.accentPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Large Bodoni Moda Total Outstanding
            Text(
              '${currency.symbol}${formatCoveAmount(totalOutstanding)}',
              style: GoogleFonts.bodoniModa(
                fontSize: 34,
                fontWeight: FontWeight.w600,
                color: colors.accentTint,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Progress Bar: Paid vs Outstanding
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: LinearProgressIndicator(
                  value: payoffRatio,
                  backgroundColor: colors.surfaceRow,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.accentPrimary),
                ),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paid: ${currency.symbol}${formatCoveAmount(totalPaid)} (${(payoffRatio * 100).toStringAsFixed(0)}%)',
                  style: typography.caption.copyWith(
                    color: colors.textMuted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'Monthly: ${currency.symbol}${formatCoveAmount(totalMonthlyOutflow)}/mo',
                  style: typography.caption.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsRow(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Row(
      children: [
        // Mode Switch (Tenure vs Relative Share)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSegmentButton(
                    context,
                    label: 'Tenure Paid',
                    isSelected: _progressMode == EmiProgressDisplayMode.tenure,
                    onTap: () {
                      if (_progressMode != EmiProgressDisplayMode.tenure) {
                        setState(() => _progressMode = EmiProgressDisplayMode.tenure);
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _buildSegmentButton(
                    context,
                    label: 'EMI Share',
                    isSelected: _progressMode == EmiProgressDisplayMode.relativeShare,
                    onTap: () {
                      if (_progressMode != EmiProgressDisplayMode.relativeShare) {
                        setState(() => _progressMode = EmiProgressDisplayMode.relativeShare);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Sort Direction Button
        InkWell(
          onTap: () => setState(() => _sortAscending = !_sortAscending),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 16,
                  color: colors.accentPrimary,
                ),
                const SizedBox(width: 4),
                Text(
                  _sortAscending ? 'Low → High' : 'High → Low',
                  style: typography.caption.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentButton(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.surfaceRow : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: typography.caption.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? colors.accentPrimary : colors.textMuted,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmiCard(
    BuildContext context, {
    required LocalSubscription emi,
    required dynamic currency,
    required double totalMonthlyOutflow,
    required double maxMonthlyEmi,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    final paidInstallments = emi.emiProgress?.paidInstallments ?? 0;
    final totalInstallments = emi.emiProgress?.totalInstallments ?? (emi.totalInstallments ?? 1);
    final remainingInstallments = (totalInstallments - paidInstallments).clamp(0, totalInstallments);
    final outstanding = remainingInstallments * emi.amount;
    final paidAmount = paidInstallments * emi.amount;

    // Progress bar calculation based on mode
    final double progressValue;
    final String progressLeftText;
    final String progressRightText;

    if (_progressMode == EmiProgressDisplayMode.tenure) {
      progressValue = totalInstallments > 0
          ? (paidInstallments / totalInstallments).clamp(0.0, 1.0)
          : 0.0;
      progressLeftText = '$paidInstallments of $totalInstallments months paid';
      progressRightText = '${(progressValue * 100).toStringAsFixed(0)}% tenure done';
    } else {
      // Relative share: percentage of monthly outflow
      final shareRatio = totalMonthlyOutflow > 0
          ? (emi.amount / totalMonthlyOutflow).clamp(0.0, 1.0)
          : 0.0;
      progressValue = maxMonthlyEmi > 0
          ? (emi.amount / maxMonthlyEmi).clamp(0.0, 1.0)
          : 0.0;
      final percentStr = (shareRatio * 100).toStringAsFixed(1);
      progressLeftText = '$percentStr% of monthly EMI total';
      progressRightText = '${currency.symbol}${formatCoveAmount(emi.amount)} / ${currency.symbol}${formatCoveAmount(totalMonthlyOutflow)}';
    }

    return InkWell(
      onTap: () => CommitmentDetailSheet.show(context, emi),
      borderRadius: BorderRadius.circular(16),
      child: CoveCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header: Name, Financed Through Badge, and Attribution
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          emi.name,
                          style: typography.title.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (emi.financedThrough != null && emi.financedThrough!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.account_balance_outlined,
                                size: 12,
                                color: colors.textSubtle,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  emi.financedThrough!.trim(),
                                  style: typography.caption.copyWith(
                                    color: colors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Pill for Private / Shared
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: emi.isPrivate
                          ? colors.accentSecondary.withValues(alpha: 0.12)
                          : colors.surfaceRow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      emi.isPrivate ? 'Private' : 'Shared',
                      style: typography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: emi.isPrivate ? colors.accentSecondary : colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Metrics 4-Column / Grid Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceRow.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Outstanding (Emphasized)
                    Expanded(
                      child: _buildMetricItem(
                        context,
                        label: 'Outstanding',
                        value: '${currency.symbol}${formatCoveAmount(outstanding)}',
                        valueColor: colors.accentTint,
                        isEmphasized: true,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: colors.borderHairline,
                    ),
                    // EMI Amount
                    Expanded(
                      child: _buildMetricItem(
                        context,
                        label: 'Monthly EMI',
                        value: '${currency.symbol}${formatCoveAmount(emi.amount)}',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: colors.borderHairline,
                    ),
                    // Paid Total
                    Expanded(
                      child: _buildMetricItem(
                        context,
                        label: 'Paid Total',
                        value: '${currency.symbol}${formatCoveAmount(paidAmount)}',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: colors.borderHairline,
                    ),
                    // Tenure
                    Expanded(
                      child: _buildMetricItem(
                        context,
                        label: 'Tenure',
                        value: '$paidInstallments/$totalInstallments mo',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. Dynamic Progress Bar Track
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: progressValue,
                    backgroundColor: colors.surfaceRow,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _progressMode == EmiProgressDisplayMode.tenure
                          ? colors.accentPrimary
                          : colors.accentPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Progress Bar Labels
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    progressLeftText,
                    style: typography.caption.copyWith(
                      color: colors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    progressRightText,
                    style: typography.caption.copyWith(
                      color: colors.textSubtle,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    bool isEmphasized = false,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      children: [
        Text(
          label,
          style: typography.caption.copyWith(
            fontSize: 10,
            color: colors.textSubtle,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: typography.caption.copyWith(
            fontSize: isEmphasized ? 13 : 12,
            fontWeight: isEmphasized ? FontWeight.w700 : FontWeight.w600,
            color: valueColor ?? colors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCompletedEmiCard(
    BuildContext context, {
    required LocalSubscription emi,
    required dynamic currency,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final totalInstallments = emi.emiProgress?.totalInstallments ?? (emi.totalInstallments ?? 1);
    final totalAmount = totalInstallments * emi.amount;

    return InkWell(
      onTap: () => CommitmentDetailSheet.show(context, emi),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF4CAF50)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emi.name,
                    style: typography.bodyRegular.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (emi.financedThrough != null && emi.financedThrough!.isNotEmpty)
                    Text(
                      emi.financedThrough!,
                      style: typography.caption.copyWith(
                        fontSize: 10,
                        color: colors.textSubtle,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${currency.symbol}${formatCoveAmount(totalAmount)} paid',
              style: typography.caption.copyWith(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: CoveEmptyState(
        icon: Icons.account_balance_outlined,
        title: 'No EMIs or loans active',
        description: 'Track your home, vehicle, gadget or personal loans with automatic payoff tracking.',
        action: CovePillButton(
          label: 'Add Loan or EMI',
          icon: const Icon(Icons.add, size: 16),
          onPressed: () => SubscriptionFormSheet.show(context),
        ),
      ),
    );
  }
}
