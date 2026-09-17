import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../profile/preferences_controller.dart';
import 'commitment_projection_utils.dart';
import 'month_commitments_sheet.dart';

class CommitmentsHelicopterScreen extends ConsumerStatefulWidget {
  final List<LocalSubscription>? subscriptions;
  final int? initialYear;

  const CommitmentsHelicopterScreen({
    super.key,
    this.subscriptions,
    this.initialYear,
  });

  @override
  ConsumerState<CommitmentsHelicopterScreen> createState() =>
      _CommitmentsHelicopterScreenState();
}

class _CommitmentsHelicopterScreenState
    extends ConsumerState<CommitmentsHelicopterScreen> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear ?? DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.watch(currencyPreferenceProvider);

    final subsList = widget.subscriptions ??
        ref.watch(activeHomeSubscriptionsProvider).value ??
        [];

    final isDesktop = kIsWeb && MediaQuery.sizeOf(context).width >= 840;

    // Project commitments for the selected year
    final projections = CommitmentProjectionUtils.projectYear(
      subscriptions: subsList,
      year: _selectedYear,
    );

    // Calculate annual grand total
    double annualGrandTotal = 0.0;
    int totalUniqueCommitments = 0;
    for (final summary in projections.values) {
      annualGrandTotal += summary.totalAmount;
    }
    totalUniqueCommitments = subsList.where((s) => s.isActive).length;

    final now = DateTime.now();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Commitments Helicopter',
          style: typography.headline.copyWith(fontSize: 20),
        ),
        actions: [
          // Quick navigation back to current year if navigated away
          if (_selectedYear != now.year)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: () => setState(() => _selectedYear = now.year),
                child: Text(
                  'Current Year',
                  style: typography.caption.copyWith(
                    color: colors.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 960 : 540),
            child: Column(
              children: [
                // Year Navigation & Annual Summary Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$_selectedYear',
                                style: typography.headline.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.surfaceRow,
                                  borderRadius: BorderRadius.circular(999),
                                  border:
                                      Border.all(color: colors.borderHairline),
                                ),
                                child: Text(
                                  '$totalUniqueCommitments active',
                                  style: typography.caption.copyWith(
                                    color: colors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total ${currency.symbol}${formatCoveAmount(annualGrandTotal)} across $_selectedYear',
                            style: typography.caption.copyWith(
                              color: colors.accentPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 22),
                            onPressed: () =>
                                setState(() => _selectedYear--),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 22),
                            onPressed: () =>
                                setState(() => _selectedYear++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 12-Month Grid View (matching Calendar Year View)
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.85,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: 12,
                    itemBuilder: (ctx, idx) {
                      final month = idx + 1;
                      final summary = projections[month]!;
                      final monthDate = DateTime(_selectedYear, month, 1);
                      final monthName = DateFormat('MMM').format(monthDate);
                      final isCurrentMonth =
                          now.year == _selectedYear && now.month == month;

                      String countLabel;
                      if (summary.items.isEmpty) {
                        countLabel = 'No commitments';
                      } else {
                        final parts = <String>[];
                        if (summary.subsCount > 0) {
                          parts.add('${summary.subsCount} ${summary.subsCount == 1 ? 'sub' : 'subs'}');
                        }
                        if (summary.emisCount > 0) {
                          parts.add('${summary.emisCount} ${summary.emisCount == 1 ? 'EMI' : 'EMIs'}');
                        }
                        countLabel = parts.join(' · ');
                      }

                      return GestureDetector(
                        onTap: () {
                          MonthCommitmentsSheet.show(
                            context,
                            summary: summary,
                          );
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.surfaceCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isCurrentMonth
                                  ? colors.accentPrimary
                                  : colors.borderHairline,
                              width: isCurrentMonth ? 1.5 : 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Month Name + Current month dot
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    monthName,
                                    style: typography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isCurrentMonth
                                          ? colors.accentPrimary
                                          : colors.textPrimary,
                                    ),
                                  ),
                                  if (isCurrentMonth)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.accentPrimary,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Month commitment amount
                              Text(
                                summary.totalAmount > 0
                                    ? '${currency.symbol}${formatCoveAmount(summary.totalAmount)}'
                                    : '—',
                                style: typography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: summary.totalAmount > 0
                                      ? colors.textPrimary
                                      : colors.textMuted,
                                ),
                              ),

                              const Spacer(),

                              // Subscriptions & EMIs info
                              Text(
                                countLabel,
                                style: typography.caption.copyWith(
                                  color: colors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
