import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_toggle_switch.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
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
  bool _showSeparate5050 = false;

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

    // Profiles for attribution
    final currentUserId = ref.watch(authProvider).value?.id;
    final partnerProfile = ref.watch(partnerProfileProvider);
    final partnerUserId = partnerProfile.userId ?? 'partner_user';
    final partnerName = partnerProfile.displayName.isNotEmpty
        ? partnerProfile.displayName
        : 'Partner';
    final myProfile = ref.watch(userProfileProvider);
    final myName = myProfile.displayName.isNotEmpty
        ? myProfile.displayName
        : 'You';

    // Project commitments for the selected year
    final projections = CommitmentProjectionUtils.projectYear(
      subscriptions: subsList,
      year: _selectedYear,
    );

    // Calculate annual grand total
    double annualGrandTotal = 0.0;
    for (final summary in projections.values) {
      annualGrandTotal += summary.totalAmount;
    }
    final totalUniqueCommitments = subsList.where((s) => s.isActive).length;

    final now = DateTime.now();

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Commitments Helicopter',
              style: typography.headline.copyWith(fontSize: 18),
            ),
            Text(
              'Total ${currency.symbol}${formatCoveAmount(annualGrandTotal)} in $_selectedYear · $totalUniqueCommitments active',
              style: typography.caption.copyWith(
                color: colors.accentPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
            constraints: BoxConstraints(maxWidth: isDesktop ? 1100 : 640),
            child: Column(
              children: [
                // Top Header Row: 50/50 Toggle on top left, Year Navigation on right
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Left: 50/50 Separate Toggle
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CoveToggleSwitch(
                            value: _showSeparate5050,
                            onChanged: (val) =>
                                setState(() => _showSeparate5050 = val),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '50/50 Separate',
                            style: typography.caption.copyWith(
                              color: _showSeparate5050
                                  ? colors.accentPrimary
                                  : colors.textMuted,
                              fontWeight: _showSeparate5050
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),

                      // Top Right: Year Navigation
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left, size: 20),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            onPressed: () =>
                                setState(() => _selectedYear--),
                          ),
                          Text(
                            '$_selectedYear',
                            style: typography.headline.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right, size: 20),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 32, minHeight: 32),
                            onPressed: () =>
                                setState(() => _selectedYear++),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Expanded 12-Month Grid filling entire screen space
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final availableHeight = constraints.maxHeight;

                      const paddingH = 12.0;
                      const paddingV = 6.0;
                      const crossSpacing = 8.0;
                      const mainSpacing = 8.0;

                      // 3 columns, 4 rows = 12 months exactly
                      final tileWidth = (availableWidth -
                              (paddingH * 2) -
                              (crossSpacing * 2)) /
                          3;
                      final tileHeight = (availableHeight -
                              (paddingV * 2) -
                              (mainSpacing * 3)) /
                          4;
                      final childAspectRatio = tileWidth / tileHeight;

                      return GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: paddingH,
                          vertical: paddingV,
                        ),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: crossSpacing,
                          mainAxisSpacing: mainSpacing,
                        ),
                        itemCount: 12,
                        itemBuilder: (ctx, idx) {
                          final month = idx + 1;
                          final summary = projections[month]!;
                          final monthDate = DateTime(_selectedYear, month, 1);
                          final monthName = DateFormat('MMM').format(monthDate);
                          final isCurrentMonth =
                              now.year == _selectedYear && now.month == month;

                          // Calculations for attribution
                          final pureMineAmount = summary.allocationMine(
                              currentUserId, partnerUserId);
                          final purePartnerAmount = summary.allocationPartner(
                              currentUserId, partnerUserId);
                          final splitAmount = summary.allocationSplit();

                          final pureMineSubs = summary.mineSubsCount(
                              currentUserId, partnerUserId);
                          final pureMineEmis = summary.mineEmisCount(
                              currentUserId, partnerUserId);

                          final purePartnerSubs = summary.partnerSubsCount(
                              currentUserId, partnerUserId);
                          final purePartnerEmis = summary.partnerEmisCount(
                              currentUserId, partnerUserId);

                          final splitSubs = summary.splitSubsCount();
                          final splitEmis = summary.splitEmisCount();

                          final double displayedMineAmount;
                          final double displayedPartnerAmount;
                          final int displayedMineSubs;
                          final int displayedMineEmis;
                          final int displayedPartnerSubs;
                          final int displayedPartnerEmis;

                          if (_showSeparate5050) {
                            // Show 50/50 separately
                            displayedMineAmount = pureMineAmount;
                            displayedPartnerAmount = purePartnerAmount;
                            displayedMineSubs = pureMineSubs;
                            displayedMineEmis = pureMineEmis;
                            displayedPartnerSubs = purePartnerSubs;
                            displayedPartnerEmis = purePartnerEmis;
                          } else {
                            // 50/50 is absorbed into Mine and Partner
                            displayedMineAmount =
                                pureMineAmount + (splitAmount / 2.0);
                            displayedPartnerAmount =
                                purePartnerAmount + (splitAmount / 2.0);
                            displayedMineSubs = pureMineSubs + splitSubs;
                            displayedMineEmis = pureMineEmis + splitEmis;
                            displayedPartnerSubs = purePartnerSubs + splitSubs;
                            displayedPartnerEmis = purePartnerEmis + splitEmis;
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 7,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 1. Month Name + Current Month Dot + Month Total
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            monthName,
                                            style: typography.bodyMedium
                                                .copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: isCurrentMonth
                                                  ? colors.accentPrimary
                                                  : colors.textPrimary,
                                            ),
                                          ),
                                          if (isCurrentMonth) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              width: 5,
                                              height: 5,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: colors.accentPrimary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Flexible(
                                        child: Text(
                                          summary.totalAmount > 0
                                              ? '${currency.symbol}${formatCoveAmount(summary.totalAmount)}'
                                              : '—',
                                          style: typography.bodyMedium
                                              .copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            color: summary.totalAmount > 0
                                                ? colors.accentTint
                                                : colors.textMuted,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.end,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    height: 1,
                                    color: colors.borderHairline
                                        .withValues(alpha: 0.6),
                                  ),
                                  const Spacer(),

                                  // 2. Mine Split Section
                                  _buildAttributionSection(
                                    label: myName,
                                    amount: displayedMineAmount,
                                    subsCount: displayedMineSubs,
                                    emisCount: displayedMineEmis,
                                    labelColor: colors.accentPrimary,
                                    colors: colors,
                                    typography: typography,
                                    currencySymbol: currency.symbol,
                                  ),
                                  const Spacer(),

                                  // 3. Partner Split Section
                                  _buildAttributionSection(
                                    label: partnerName,
                                    amount: displayedPartnerAmount,
                                    subsCount: displayedPartnerSubs,
                                    emisCount: displayedPartnerEmis,
                                    labelColor: colors.accentSecondary,
                                    colors: colors,
                                    typography: typography,
                                    currencySymbol: currency.symbol,
                                  ),

                                  // 4. 50/50 Split Section (shown separately when toggle ON)
                                  if (_showSeparate5050) ...[
                                    const Spacer(),
                                    _buildAttributionSection(
                                      label: '50/50',
                                      amount: splitAmount,
                                      subsCount: splitSubs,
                                      emisCount: splitEmis,
                                      labelColor: colors.textMuted,
                                      colors: colors,
                                      typography: typography,
                                      currencySymbol: currency.symbol,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
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

  Widget _buildAttributionSection({
    required String label,
    required double amount,
    required int subsCount,
    required int emisCount,
    required Color labelColor,
    required CoveColors colors,
    required CoveTypography typography,
    required String currencySymbol,
  }) {
    final countParts = <String>[];
    if (subsCount > 0) {
      countParts.add('$subsCount ${subsCount == 1 ? "sub" : "subs"}');
    }
    if (emisCount > 0) {
      countParts.add('$emisCount ${emisCount == 1 ? "EMI" : "EMIs"}');
    }
    final countLabel =
        countParts.isEmpty ? '0 commitments' : countParts.join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 10.5,
                  color: labelColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              amount > 0 ? '$currencySymbol${formatCoveAmount(amount)}' : '—',
              style: typography.caption.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: amount > 0 ? colors.textPrimary : colors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Text(
          countLabel,
          style: typography.caption.copyWith(
            color: colors.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
