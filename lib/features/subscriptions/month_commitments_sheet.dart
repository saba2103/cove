import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_tab_row.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import 'commitment_detail_sheet.dart';
import 'commitment_projection_utils.dart';

class MonthCommitmentsSheet extends ConsumerStatefulWidget {
  final MonthCommitmentSummary summary;

  const MonthCommitmentsSheet({
    super.key,
    required this.summary,
  });

  static Future<void> show(
    BuildContext context, {
    required MonthCommitmentSummary summary,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MonthCommitmentsSheet(summary: summary),
    );
  }

  @override
  ConsumerState<MonthCommitmentsSheet> createState() =>
      _MonthCommitmentsSheetState();
}

class _MonthCommitmentsSheetState extends ConsumerState<MonthCommitmentsSheet> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.watch(currencyPreferenceProvider);

    final currentUserId = ref.watch(authProvider).value?.id;
    final partnerProfile = ref.watch(partnerProfileProvider);
    final partnerUserId = partnerProfile.userId ?? 'partner_user';
    final partnerName = partnerProfile.displayName.isNotEmpty
        ? partnerProfile.displayName
        : 'Partner';
    final myProfile = ref.watch(userProfileProvider);
    final myName = myProfile.displayName.isNotEmpty
        ? myProfile.displayName
        : 'Mine';

    final tabNames = ['All', myName, partnerName, 'Split'];

    final filteredItems = widget.summary.filterByAttribution(
      tabIndex: _selectedTabIndex,
      currentUserId: currentUserId,
      partnerUserId: partnerUserId,
    );

    final monthDate = DateTime(widget.summary.year, widget.summary.month, 1);
    final monthName = DateFormat('MMMM yyyy').format(monthDate);

    final totalMonthAmount = widget.summary.totalAmount;
    final mineAlloc = widget.summary.allocationMine(currentUserId, partnerUserId);
    final partnerAlloc =
        widget.summary.allocationPartner(currentUserId, partnerUserId);
    final splitAlloc = widget.summary.allocationSplit();

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderHairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        monthName,
                        style: typography.headline.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${currency.symbol}${formatCoveAmount(totalMonthAmount)}',
                            style: typography.largeNumber.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: colors.accentTint,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${widget.summary.subsCount} subs · ${widget.summary.emisCount} EMIs)',
                            style: typography.caption.copyWith(
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Attribution Progress Bar (when multiple attributions exist)
          if (totalMonthAmount > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildAttributionBar(
                colors: colors,
                total: totalMonthAmount,
                mineAmount: mineAlloc,
                partnerAmount: partnerAlloc,
                splitAmount: splitAlloc,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Attribution Tabs: All | Mine | Partner | Split
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: CoveTabRow(
              tabs: tabNames,
              selectedIndex: _selectedTabIndex,
              onTabSelected: (idx) => setState(() => _selectedTabIndex = idx),
            ),
          ),
          const SizedBox(height: 12),

          // List of commitments for this month
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: CoveEmptyState(
                      icon: Icons.calendar_today_outlined,
                      title: 'No commitments',
                      description: 'No commitments under "${tabNames[_selectedTabIndex]}" for $monthName.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final item = filteredItems[idx];
                      return _buildCommitmentTile(
                        context: context,
                        item: item,
                        colors: colors,
                        typography: typography,
                        currencySymbol: currency.symbol,
                        currentUserId: currentUserId,
                        partnerUserId: partnerUserId,
                        partnerName: partnerName,
                        myName: myName,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttributionBar({
    required CoveColors colors,
    required double total,
    required double mineAmount,
    required double partnerAmount,
    required double splitAmount,
  }) {
    if (total <= 0) return const SizedBox.shrink();

    final mineRatio = (mineAmount / total).clamp(0.0, 1.0);
    final partnerRatio = (partnerAmount / total).clamp(0.0, 1.0);
    final splitRatio = (splitAmount / total).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            if (mineRatio > 0)
              Expanded(
                flex: (mineRatio * 1000).toInt(),
                child: Container(color: colors.accentPrimary),
              ),
            if (partnerRatio > 0)
              Expanded(
                flex: (partnerRatio * 1000).toInt(),
                child: Container(color: colors.accentSecondary),
              ),
            if (splitRatio > 0)
              Expanded(
                flex: (splitRatio * 1000).toInt(),
                child: Container(color: colors.accentPrimary.withValues(alpha: 0.4)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitmentTile({
    required BuildContext context,
    required ProjectedCommitmentItem item,
    required CoveColors colors,
    required CoveTypography typography,
    required String currencySymbol,
    required String? currentUserId,
    required String? partnerUserId,
    required String partnerName,
    required String myName,
  }) {
    final dayFormatted = DateFormat('MMM d').format(item.projectedDate);
    final isPartner = widget.summary.isPartner(item.subscription, currentUserId, partnerUserId);
    final isSplit = widget.summary.isSplit(item.subscription);

    String payerLabel = myName;
    Color payerColor = colors.accentPrimary;
    if (isSplit) {
      payerLabel = 'Split 50/50';
      payerColor = colors.textMuted;
    } else if (isPartner) {
      payerLabel = partnerName;
      payerColor = colors.accentSecondary;
    }

    return InkWell(
      onTap: () {
        CommitmentDetailSheet.show(context, item.subscription);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceRow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderHairline),
        ),
        child: Row(
          children: [
            // Category Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderHairline),
              ),
              child: Icon(
                _getCategoryIcon(item.category),
                size: 20,
                color: colors.accentPrimary,
              ),
            ),
            const SizedBox(width: 12),

            // Title and Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.name,
                          style: typography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // EMI or Sub badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.isEmi
                              ? colors.accentSecondary.withValues(alpha: 0.15)
                              : colors.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.isEmi ? 'EMI' : 'Sub',
                          style: typography.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: item.isEmi
                                ? colors.accentSecondary
                                : colors.accentPrimary,
                          ),
                        ),
                      ),
                      if (item.isAnnual) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.borderHairline,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Annual',
                            style: typography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Due $dayFormatted',
                        style: typography.caption.copyWith(
                          color: colors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        ' · ',
                        style: typography.caption.copyWith(color: colors.textSubtle),
                      ),
                      Text(
                        payerLabel,
                        style: typography.caption.copyWith(
                          color: payerColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            const SizedBox(width: 8),
            Text(
              '$currencySymbol${formatCoveAmount(item.amount)}',
              style: typography.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'entertainment':
      case 'streaming':
        return Icons.play_circle_outline;
      case 'utilities':
        return Icons.bolt_outlined;
      case 'software':
      case 'productivity':
        return Icons.devices_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'health':
      case 'fitness':
        return Icons.fitness_center_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'finance':
      case 'insurance':
        return Icons.account_balance_outlined;
      default:
        return Icons.repeat_outlined;
    }
  }
}
