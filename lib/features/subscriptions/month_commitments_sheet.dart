import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_tokens.dart';
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

  const MonthCommitmentsSheet({super.key, required this.summary});

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
  static const double _kHandleWidth =
      36.0; // (literal) 36dp sheet drag handle width
  static const double _kHandleRadius =
      2.0; // (literal) 2dp sheet drag handle pill corner radius
  static const double _kAttributionBarHeight =
      6.0; // (literal) 6dp attribution split progress bar height
  static const double _kBadgeRadius =
      6.0; // (literal) 6dp EMI/Sub/Annual badge corner radius

  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
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
    final mineAlloc = widget.summary.allocationMine(
      currentUserId,
      partnerUserId,
    );
    final partnerAlloc = widget.summary.allocationPartner(
      currentUserId,
      partnerUserId,
    );
    final splitAlloc = widget.summary.allocationSplit();

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      decoration: BoxDecoration(
        color: cv.surfaceSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CoveRadius.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(
                top: CoveSpace.md,
                bottom: CoveSpace.sm,
              ),
              width: _kHandleWidth,
              height: CoveSpace.xs,
              decoration: BoxDecoration(
                color: cv.lineHairline,
                borderRadius: const BorderRadius.all(
                  Radius.circular(_kHandleRadius),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CoveSpace.gutter,
              CoveSpace.sm,
              CoveSpace.md,
              CoveSpace.md,
            ),
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
                        style: CoveType.slipTitle.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                      const SizedBox(height: CoveSpace.xs),
                      Wrap(
                        spacing: CoveSpace.sm,
                        runSpacing: CoveSpace.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${currency.symbol}${formatCoveAmount(totalMonthAmount)}',
                            style: CoveType.slipTitle.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cv.accentTint,
                            ),
                          ),
                          Text(
                            '(${widget.summary.subsCount} subs · ${widget.summary.emisCount} EMIs)',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: cv.textSecondary,
                    size: CoveSpace.gutter,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Attribution Progress Bar (when multiple attributions exist)
          if (totalMonthAmount > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
              child: _buildAttributionBar(
                cv: cv,
                total: totalMonthAmount,
                mineAmount: mineAlloc,
                partnerAmount: partnerAlloc,
                splitAmount: splitAlloc,
              ),
            ),
            const SizedBox(height: CoveSpace.md),
          ],

          // Attribution Tabs: All | Mine | Partner | Split
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
            child: CoveTabRow(
              tabs: tabNames,
              selectedIndex: _selectedTabIndex,
              onTabSelected: (idx) => setState(() => _selectedTabIndex = idx),
            ),
          ),
          const SizedBox(height: CoveSpace.md),

          // List of commitments for this month
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: CoveEmptyState(
                      icon: Icons.calendar_today_outlined,
                      title: 'No commitments',
                      description:
                          'No commitments under "${tabNames[_selectedTabIndex]}" for $monthName.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      CoveSpace.gutter,
                      CoveSpace.xs,
                      CoveSpace.gutter,
                      CoveSpace.lg,
                    ),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: CoveSpace.sm),
                    itemBuilder: (ctx, idx) {
                      final item = filteredItems[idx];
                      return _buildCommitmentTile(
                        context: context,
                        item: item,
                        cv: cv,
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
    required CoveTokens cv,
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
      borderRadius: const BorderRadius.all(Radius.circular(CoveRadius.pill)),
      child: SizedBox(
        height: _kAttributionBarHeight,
        child: Row(
          children: [
            if (mineRatio > 0)
              Expanded(
                flex: (mineRatio * 1000).toInt(),
                child: Container(color: cv.accentFill),
              ),
            if (partnerRatio > 0)
              Expanded(
                flex: (partnerRatio * 1000).toInt(),
                child: Container(color: cv.statusAlert),
              ),
            if (splitRatio > 0)
              Expanded(
                flex: (splitRatio * 1000).toInt(),
                child: Container(color: cv.accentFill.withValues(alpha: 0.4)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommitmentTile({
    required BuildContext context,
    required ProjectedCommitmentItem item,
    required CoveTokens cv,
    required String currencySymbol,
    required String? currentUserId,
    required String? partnerUserId,
    required String partnerName,
    required String myName,
  }) {
    final dayFormatted = DateFormat('MMM d').format(item.projectedDate);
    final isPartner = widget.summary.isPartner(
      item.subscription,
      currentUserId,
      partnerUserId,
    );
    final isSplit = widget.summary.isSplit(item.subscription);

    String payerLabel = myName;
    Color payerColor = cv.accentText;
    if (isSplit) {
      payerLabel = 'Split 50/50';
      payerColor = cv.textSecondary;
    } else if (isPartner) {
      payerLabel = partnerName;
      payerColor = cv.statusAlertText;
    }

    return InkWell(
      onTap: () {
        CommitmentDetailSheet.show(context, item.subscription);
      },
      borderRadius: const BorderRadius.all(Radius.circular(CoveRadius.inline)),
      child: Container(
        padding: const EdgeInsets.all(CoveSpace.md),
        decoration: BoxDecoration(
          color: cv.surfaceRow,
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.inline),
          ),
          border: Border.all(color: cv.lineHairline),
        ),
        child: Row(
          children: [
            // Category Icon
            Container(
              width: CoveSize.buttonRound,
              height: CoveSize.buttonRound,
              decoration: BoxDecoration(
                color: cv.surfaceCard,
                borderRadius: const BorderRadius.all(
                  Radius.circular(CoveSpace.md),
                ),
                border: Border.all(color: cv.lineHairline),
              ),
              child: Icon(
                _getCategoryIcon(item.category),
                size: CoveSpace.gutter,
                color: cv.accentFill,
              ),
            ),
            const SizedBox(width: CoveSpace.md),

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
                          style: CoveType.rowTitle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cv.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: CoveSpace.sm),
                      // EMI or Sub badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CoveSpace.sm,
                          vertical: CoveSpace.xs,
                        ),
                        decoration: BoxDecoration(
                          color: item.isEmi
                              ? cv.statusAlert.withValues(alpha: 0.15)
                              : cv.accentWash,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(_kBadgeRadius),
                          ),
                        ),
                        child: Text(
                          item.isEmi ? 'EMI' : 'Sub',
                          style: CoveType.barLabel.copyWith(
                            fontWeight: FontWeight.w700,
                            color: item.isEmi
                                ? cv.statusAlertText
                                : cv.accentText,
                          ),
                        ),
                      ),
                      if (item.isAnnual) ...[
                        const SizedBox(width: CoveSpace.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: CoveSpace.sm,
                            vertical: CoveSpace.xs,
                          ),
                          decoration: BoxDecoration(
                            color: cv.lineHairline,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(_kBadgeRadius),
                            ),
                          ),
                          child: Text(
                            'Annual',
                            style: CoveType.barLabel.copyWith(
                              fontWeight: FontWeight.w600,
                              color: cv.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: CoveSpace.xs),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Due $dayFormatted',
                        style: CoveType.rowSub.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                      Text(
                        ' · ',
                        style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                      ),
                      Text(
                        payerLabel,
                        style: CoveType.rowSub.copyWith(
                          color: payerColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (item.subscription.financedThrough != null &&
                          item.subscription.financedThrough!
                              .trim()
                              .isNotEmpty) ...[
                        Text(
                          ' · ',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                        Text(
                          'via ${item.subscription.financedThrough!.trim()}',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            const SizedBox(width: CoveSpace.sm),
            Text(
              '$currencySymbol${formatCoveAmount(item.amount)}',
              style: CoveType.rowTitle.copyWith(
                fontWeight: FontWeight.w700,
                color: cv.textPrimary,
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
