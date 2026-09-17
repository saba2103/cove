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
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../core/widgets/cove_toggle_switch.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import '../../core/widgets/cove_tab_row.dart';
import 'commitment_models.dart';
import 'commitment_detail_sheet.dart';
import 'commitments_helicopter_screen.dart';
import 'subscription_form_sheet.dart';
import '../../core/utils/cove_currency_formatter.dart';

class SubscriptionsScreen extends ConsumerStatefulWidget {
  final List<LocalSubscription>? initialSubscriptions;

  const SubscriptionsScreen({super.key, this.initialSubscriptions});

  @override
  ConsumerState<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  bool _showAnnual = false;
  bool _includePrivateInHero = false;
  bool _combineCycles = false;
  int _selectedAttributionTab = 0;
  bool _distributeSplit5050 = false;

  Future<void> _handleRefresh() async {
    final homeId = ref.read(activeHomeIdProvider);
    await ref.read(syncEngineProvider).pullLatestEvents(homeId: homeId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outboxEvents = ref.watch(activeHomeOutboxProvider).value ?? [];
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);

    if (widget.initialSubscriptions != null) {
      return _buildContent(context, widget.initialSubscriptions!, outboxEvents, hasPartner: hasPartner);
    }

    final subscriptionsAsync = ref.watch(activeHomeSubscriptionsProvider);
    return subscriptionsAsync.when(
      data: (subscriptions) => _buildContent(context, subscriptions, outboxEvents, hasPartner: hasPartner),
      loading: () => Scaffold(
        backgroundColor: colors.background,
        body: const Center(
          child: CoveLoading(),
        ),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CoveErrorState.generic(
            title: 'Subscriptions unavailable',
            description: 'Could not load recurring services right now.',
            onRetry: () => ref.invalidate(activeHomeSubscriptionsProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<LocalSubscription> subscriptions,
    List<LocalOutboxEvent> outboxEvents, {
    bool hasPartner = true,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    if (subscriptions.isEmpty) {
      return _buildEmptyState(context);
    }

        // 1. Separate Active vs Inactive (Auto-move finished EMIs out of active list)
        final activeSubs = subscriptions.where((s) => s.isActive && !s.isEmiFinished).toList();
        final inactiveSubs = subscriptions.where((s) => !s.isActive || s.isEmiFinished).toList();

        // 2. Separate Shared vs Private
        final sharedActive = activeSubs.where((s) => !s.isPrivate).toList();
        final privateActive = activeSubs.where((s) => s.isPrivate).toList();

        // 3. Compute Totals & Breakdown (Subs vs EMIs)
        final relevantActive = _includePrivateInHero ? activeSubs : sharedActive;

        double subsMonthlyOnly = 0.0;
        double emisMonthlyOnly = 0.0;
        double subsAnnualOnly = 0.0;
        double emisAnnualOnly = 0.0;
        double subsCombinedMonthly = 0.0;
        double emisCombinedMonthly = 0.0;

        for (final item in relevantActive) {
          final months = getBillingCycleMonths(item.billingCycle);
          final isAnnual = months == 12;
          final isMonthly = months == 1;

          if (isAnnual) {
            if (item.isEmi) {
              emisAnnualOnly += item.amount;
            } else {
              subsAnnualOnly += item.amount;
            }
          } else if (isMonthly) {
            if (item.isEmi) {
              emisMonthlyOnly += item.amount;
            } else {
              subsMonthlyOnly += item.amount;
            }
          }

          // Prorated monthly amount for combined calculations (works for 1 mo, 12 mo, 7 mo, etc.)
          final monthlyAmount = item.amount / months;
          if (item.isEmi) {
            emisCombinedMonthly += monthlyAmount;
          } else {
            subsCombinedMonthly += monthlyAmount;
          }
        }

        final double displayedAmount;
        final double displayedSubs;
        final double displayedEmis;

        if (_combineCycles) {
          // Combined calculation for both monthly, annual, and custom commitments
          if (_showAnnual) {
            final combinedSubs = subsCombinedMonthly * 12.0;
            final combinedEmis = emisCombinedMonthly * 12.0;
            displayedSubs = combinedSubs;
            displayedEmis = combinedEmis;
            displayedAmount = combinedSubs + combinedEmis;
          } else {
            final combinedSubs = subsCombinedMonthly;
            final combinedEmis = emisCombinedMonthly;
            displayedSubs = combinedSubs;
            displayedEmis = combinedEmis;
            displayedAmount = combinedSubs + combinedEmis;
          }
        } else {
          // Strict cycle separation: monthly calculates monthly only, annual calculates annual only
          if (_showAnnual) {
            displayedSubs = subsAnnualOnly;
            displayedEmis = emisAnnualOnly;
            displayedAmount = subsAnnualOnly + emisAnnualOnly;
          } else {
            displayedSubs = subsMonthlyOnly;
            displayedEmis = emisMonthlyOnly;
            displayedAmount = subsMonthlyOnly + emisMonthlyOnly;
          }
        }

        final displayedAmountStr = formatCoveAmount(displayedAmount);
        final displayedSubsStr = formatCoveAmount(displayedSubs);
        final displayedEmisStr = formatCoveAmount(displayedEmis);

        final myUserId = ref.watch(authProvider).value?.id ?? 'local_user';
        final userProfile = ref.watch(userProfileProvider);
        final partnerProfile = ref.watch(partnerProfileProvider);

        final myName = userProfile.displayName.trim().isNotEmpty
            ? userProfile.displayName.trim()
            : 'Me';
        final partnerName = partnerProfile.displayName.trim().isNotEmpty
            ? partnerProfile.displayName.trim()
            : 'Partner';
        final partnerUserId = partnerProfile.userId ?? 'partner_user';

        bool isMine(LocalSubscription item) {
          final pb = (item.paidBy ?? '').trim().toLowerCase();
          if (pb == 'split' || pb == '50/50') return false;
          if (pb == 'me' || pb == myUserId.toLowerCase()) return true;
          if (pb == partnerUserId.toLowerCase() || pb == 'partner_user') return false;
          if (pb.isEmpty) {
            return item.createdBy == myUserId || item.createdBy == 'local_user';
          }
          return true;
        }

        bool isPartner(LocalSubscription item) {
          final pb = (item.paidBy ?? '').trim().toLowerCase();
          if (pb == 'split' || pb == '50/50') return false;
          if (pb == partnerUserId.toLowerCase() || pb == 'partner_user') return true;
          return false;
        }

        bool isSplit(LocalSubscription item) {
          final pb = (item.paidBy ?? '').trim().toLowerCase();
          return pb == 'split' || pb == '50/50';
        }

        double getItemAmount(LocalSubscription item) {
          final months = getBillingCycleMonths(item.billingCycle);
          if (_combineCycles) {
            final monthly = item.amount / months;
            return _showAnnual ? monthly * 12.0 : monthly;
          } else {
            if (_showAnnual) {
              return months == 12 ? item.amount : 0.0;
            } else {
              return months == 1 ? item.amount : 0.0;
            }
          }
        }

        double mineAmount = 0.0;
        int mineSubs = 0;
        int mineEmis = 0;

        double partnerAmount = 0.0;
        int partnerSubs = 0;
        int partnerEmis = 0;

        double splitAmount = 0.0;
        int splitSubs = 0;
        int splitEmis = 0;

        for (final item in relevantActive) {
          final amt = getItemAmount(item);
          if (isSplit(item)) {
            splitAmount += amt;
            if (item.isEmi) {
              splitEmis++;
            } else {
              splitSubs++;
            }
          } else if (isPartner(item)) {
            partnerAmount += amt;
            if (item.isEmi) {
              partnerEmis++;
            } else {
              partnerSubs++;
            }
          } else {
            mineAmount += amt;
            if (item.isEmi) {
              mineEmis++;
            } else {
              mineSubs++;
            }
          }
        }

        final effectiveMineAmount =
            mineAmount + (_distributeSplit5050 ? splitAmount / 2.0 : 0.0);
        final effectivePartnerAmount =
            partnerAmount + (_distributeSplit5050 ? splitAmount / 2.0 : 0.0);
        final totalAllocation = mineAmount + partnerAmount + splitAmount;

        final tabNames = ['All', myName, partnerName, 'Split'];
        if (_selectedAttributionTab >= tabNames.length) {
          _selectedAttributionTab = 0;
        }

        List<LocalSubscription> filterByTab(List<LocalSubscription> list) {
          if (_selectedAttributionTab == 0) return list;
          if (_selectedAttributionTab == 1) {
            return list.where((s) {
              if (isMine(s)) return true;
              if (_distributeSplit5050 && isSplit(s)) return true;
              return false;
            }).toList();
          }
          if (_selectedAttributionTab == 2) {
            return list.where((s) {
              if (isPartner(s)) return true;
              if (_distributeSplit5050 && isSplit(s)) return true;
              return false;
            }).toList();
          }
          if (_selectedAttributionTab == 3) {
            return list.where((s) => isSplit(s)).toList();
          }
          return list;
        }

        final filteredActive = filterByTab(activeSubs);
        final filteredInactive = filterByTab(inactiveSubs);

        // 4. Group by Renewal / Payment Date (Strict Calendar Classification)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final in7Days = today.add(const Duration(days: 7));

        final overdue = <LocalSubscription>[];
        final renewingThisWeek = <LocalSubscription>[];
        final renewingThisMonth = <LocalSubscription>[];
        final nextMonth = <LocalSubscription>[];
        final later = <LocalSubscription>[];

        final nextMonthYear = today.month == 12 ? today.year + 1 : today.year;
        final nextMonthValue = today.month == 12 ? 1 : today.month + 1;

        for (final sub in filteredActive) {
          final ren = DateTime(
            sub.nextBillingDate.year,
            sub.nextBillingDate.month,
            sub.nextBillingDate.day,
          );

          if (ren.isBefore(today)) {
            // Past due date and not marked as paid / renewed
            overdue.add(sub);
          } else if (ren.year == today.year && ren.month == today.month) {
            // Strictly within the current calendar month
            if (ren.isBefore(in7Days) || ren.isAtSameMomentAs(in7Days)) {
              renewingThisWeek.add(sub);
            } else {
              renewingThisMonth.add(sub);
            }
          } else if (ren.year == nextMonthYear && ren.month == nextMonthValue) {
            // Strictly within the next calendar month
            nextMonth.add(sub);
          } else {
            // Anything beyond next month
            later.add(sub);
          }
        }

        overdue.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
        renewingThisWeek.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
        renewingThisMonth.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
        nextMonth.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
        later.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));

        final currency = ref.watch(currencyPreferenceProvider);

        final isDesktop = kIsWeb && MediaQuery.sizeOf(context).width >= 840;
        final isWide = kIsWeb && MediaQuery.sizeOf(context).width >= 960;

        final heroCard = CoveCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _showAnnual ? 'ANNUAL COMMITMENTS' : 'MONTHLY COMMITMENTS',
                      style: typography.caption.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // + Add Commitment Button
                      CovePillButton(
                        label: '+ Add',
                        isCompact: true,
                        onPressed: () => SubscriptionFormSheet.show(context),
                      ),
                      // Helicopter View Button
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CommitmentsHelicopterScreen(
                                subscriptions: subscriptions,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.surfaceRow,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: colors.borderHairline, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.grid_view_rounded,
                                size: 13,
                                color: colors.accentPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Helicopter View',
                                style: typography.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.accentPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Toggle Monthly / Annual
                      InkWell(
                        onTap: () => setState(() => _showAnnual = !_showAnnual),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.surfaceRow,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: colors.borderHairline, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _showAnnual ? 'Annual' : 'Monthly',
                                style: typography.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.accentPrimary,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(
                                Icons.swap_horiz,
                                size: 14,
                                color: colors.accentPrimary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Bodoni Moda Luminous Numerical Total
              Text(
                '${currency.symbol}$displayedAmountStr',
                style: typography.largeNumber.copyWith(
                  fontSize: 40,
                  height: 1.1,
                  color: colors.accentTint,
                ),
              ),
              const SizedBox(height: 4),

              // Label
              Text(
                _showAnnual
                    ? (_combineCycles
                        ? 'per year · combined monthly & annual'
                        : 'per year · annual commitments only')
                    : (_combineCycles
                        ? 'per month · combined monthly & annual'
                        : 'per month · monthly commitments only'),
                style: typography.caption.copyWith(
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: 6),

              // Secondary Breakdown line
              Text(
                'Subs ${currency.symbol}$displayedSubsStr · EMIs ${currency.symbol}$displayedEmisStr',
                style: typography.caption.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),

              // Combine Cycles Switcher Row
              InkWell(
                onTap: () => setState(() => _combineCycles = !_combineCycles),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceRow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colors.borderHairline),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Calculate monthly & annual together',
                            style: typography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            _combineCycles
                                ? (_showAnnual
                                    ? 'Monthly converted to annual'
                                    : 'Annual converted to monthly')
                                : 'Separate monthly and annual pools',
                            style: typography.caption.copyWith(
                              fontSize: 11,
                              color: colors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      CoveToggleSwitch(
                        value: _combineCycles,
                        onChanged: (val) => setState(() => _combineCycles = val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${sharedActive.length} shared commitments${privateActive.isNotEmpty ? " • ${privateActive.length} private" : ""}',
                    style: typography.caption.copyWith(
                      color: colors.textSubtle,
                      fontSize: 11,
                    ),
                  ),
                  if (privateActive.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(
                          () => _includePrivateInHero = !_includePrivateInHero),
                      child: Text(
                        _includePrivateInHero
                            ? 'Show shared only'
                            : 'Include private',
                        style: typography.caption.copyWith(
                          color: colors.accentPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );

        final commitmentsList = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedAttributionTab == 0
                      ? 'ALL COMMITMENTS'
                      : '${tabNames[_selectedAttributionTab].toUpperCase()} COMMITMENTS',
                  style: typography.caption.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Section: Overdue
            if (overdue.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'Overdue',
                count: overdue.length,
                highlight: true,
                isWarning: true,
              ),
              const SizedBox(height: 8),
              CoveGroupedCard(
                children: overdue
                    .map((sub) => _buildSubscriptionRow(
                          sub,
                          outboxEvents,
                          hasPartner: hasPartner,
                          isUrgent: true,
                          isOverdue: true,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Section: Renewing this week (strictly current month)
            if (renewingThisWeek.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'Renewing this week',
                count: renewingThisWeek.length,
                highlight: true,
              ),
              const SizedBox(height: 8),
              CoveGroupedCard(
                children: renewingThisWeek
                    .map((sub) => _buildSubscriptionRow(
                          sub,
                          outboxEvents,
                          hasPartner: hasPartner,
                          isUrgent: true,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Section: Renewing this month (strictly current month)
            if (renewingThisMonth.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'Renewing this month',
                count: renewingThisMonth.length,
                highlight: false,
              ),
              const SizedBox(height: 8),
              CoveGroupedCard(
                children: renewingThisMonth
                    .map((sub) => _buildSubscriptionRow(
                          sub,
                          outboxEvents,
                          hasPartner: hasPartner,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Section: Next month
            if (nextMonth.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'Next month',
                count: nextMonth.length,
                highlight: false,
              ),
              const SizedBox(height: 8),
              CoveGroupedCard(
                children: nextMonth
                    .map((sub) => _buildSubscriptionRow(
                          sub,
                          outboxEvents,
                          hasPartner: hasPartner,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Section: Later Renewals
            if (later.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'Later',
                count: later.length,
                highlight: false,
              ),
              const SizedBox(height: 8),
              CoveGroupedCard(
                children: later
                    .map((sub) => _buildSubscriptionRow(
                          sub,
                          outboxEvents,
                          hasPartner: hasPartner,
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Section: Inactive / Completed EMIs
            if (filteredInactive.isNotEmpty) ...[
              _buildSectionHeader(
                title: 'Paused & Completed',
                count: filteredInactive.length,
                highlight: false,
              ),
              const SizedBox(height: 8),
              CoveGroupedCard(
                children: filteredInactive
                    .map((sub) => _buildSubscriptionRow(sub, outboxEvents, hasPartner: hasPartner, isPaused: true))
                    .toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Empty state for filtered tab
            if (filteredActive.isEmpty && filteredInactive.isEmpty) ...[
              const SizedBox(height: 8),
              CoveCard(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 28, color: colors.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        'No commitments for ${tabNames[_selectedAttributionTab]}',
                        style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap "+ EMI" or "Add" to assign a commitment to this category.',
                        style: typography.caption.copyWith(color: colors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        );

        final allocationCard = CoveCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.pie_chart_outline_rounded,
                          size: 16, color: colors.accentPrimary),
                      const SizedBox(width: 8),
                      Text(
                        'COMMITMENT ALLOCATION',
                        style: typography.caption.copyWith(
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => setState(
                        () => _distributeSplit5050 = !_distributeSplit5050),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Split 50/50',
                            style: typography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: _distributeSplit5050
                                  ? colors.accentPrimary
                                  : colors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          CoveToggleSwitch(
                            value: _distributeSplit5050,
                            onChanged: (val) =>
                                setState(() => _distributeSplit5050 = val),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Multi-segment horizontal progress bar
              _buildAttributionProgressBar(
                colors: colors,
                total: totalAllocation,
                mineAmount:
                    _distributeSplit5050 ? effectiveMineAmount : mineAmount,
                partnerAmount: _distributeSplit5050
                    ? effectivePartnerAmount
                    : partnerAmount,
                splitAmount: _distributeSplit5050 ? 0.0 : splitAmount,
              ),
              const SizedBox(height: 14),

              // Allocation Stats
              if (_distributeSplit5050) ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildAllocationStatTile(
                        name: myName,
                        amount: effectiveMineAmount,
                        subsCount: mineSubs,
                        emisCount: mineEmis,
                        splitSubsCount: splitSubs,
                        splitEmisCount: splitEmis,
                        color: colors.accentPrimary,
                        percent: totalAllocation > 0
                            ? ((effectiveMineAmount / totalAllocation) * 100)
                                .round()
                            : 0,
                        isSplitDistributed: true,
                        currency: currency,
                        typography: typography,
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildAllocationStatTile(
                        name: partnerName,
                        amount: effectivePartnerAmount,
                        subsCount: partnerSubs,
                        emisCount: partnerEmis,
                        splitSubsCount: splitSubs,
                        splitEmisCount: splitEmis,
                        color: colors.accentSecondary,
                        percent: totalAllocation > 0
                            ? ((effectivePartnerAmount / totalAllocation) * 100)
                                .round()
                            : 0,
                        isSplitDistributed: true,
                        currency: currency,
                        typography: typography,
                        colors: colors,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildAllocationStatTile(
                        name: myName,
                        amount: mineAmount,
                        subsCount: mineSubs,
                        emisCount: mineEmis,
                        color: colors.accentPrimary,
                        percent: totalAllocation > 0
                            ? ((mineAmount / totalAllocation) * 100).round()
                            : 0,
                        isSplitDistributed: false,
                        currency: currency,
                        typography: typography,
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAllocationStatTile(
                        name: 'Split',
                        amount: splitAmount,
                        subsCount: splitSubs,
                        emisCount: splitEmis,
                        color: const Color(0xFFC49A45),
                        percent: totalAllocation > 0
                            ? ((splitAmount / totalAllocation) * 100).round()
                            : 0,
                        isSplitDistributed: false,
                        currency: currency,
                        typography: typography,
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildAllocationStatTile(
                        name: partnerName,
                        amount: partnerAmount,
                        subsCount: partnerSubs,
                        emisCount: partnerEmis,
                        color: colors.accentSecondary,
                        percent: totalAllocation > 0
                            ? ((partnerAmount / totalAllocation) * 100).round()
                            : 0,
                        isSplitDistributed: false,
                        currency: currency,
                        typography: typography,
                        colors: colors,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );

        final tabRow = Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: CoveTabRow(
            tabs: tabNames,
            selectedIndex: _selectedAttributionTab,
            onTabSelected: (idx) =>
                setState(() => _selectedAttributionTab = idx),
          ),
        );

        return Scaffold(
          backgroundColor: colors.background,
          appBar: !isDesktop
              ? AppBar(
                  title: Text(
                    'Commitments',
                    style: typography.headline.copyWith(fontSize: 20),
                  ),
                  actions: [
                    IconButton(
                      tooltip: 'Helicopter View',
                      icon: const Icon(Icons.grid_view_rounded, size: 20),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CommitmentsHelicopterScreen(
                              subscriptions: subscriptions,
                            ),
                          ),
                        );
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: CovePillButton(
                        label: '+ Add',
                        variant: CoveButtonVariant.secondary,
                        isCompact: true,
                        onPressed: () => SubscriptionFormSheet.show(context),
                      ),
                    ),
                  ],
                )
              : null,
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
                          children: [
                            heroCard,
                            const SizedBox(height: 20),
                            allocationCard,
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            tabRow,
                            const SizedBox(height: 16),
                            commitmentsList,
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  heroCard,
                  const SizedBox(height: 16),
                  allocationCard,
                  const SizedBox(height: 16),
                  tabRow,
                  const SizedBox(height: 16),
                  commitmentsList,
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
  }

  Widget _buildAttributionProgressBar({
    required CoveColors colors,
    required double total,
    required double mineAmount,
    required double partnerAmount,
    required double splitAmount,
  }) {
    if (total <= 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: colors.surfaceRow,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    final mineWeight = (mineAmount / total).clamp(0.0, 1.0);
    final partnerWeight = (partnerAmount / total).clamp(0.0, 1.0);
    final splitWeight = (splitAmount / total).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 8,
        color: colors.surfaceRow,
        child: Row(
          children: [
            if (mineWeight > 0)
              Expanded(
                flex: (mineWeight * 1000).round().clamp(1, 1000),
                child: Container(color: colors.accentPrimary),
              ),
            if (splitWeight > 0)
              Expanded(
                flex: (splitWeight * 1000).round().clamp(1, 1000),
                child: Container(color: const Color(0xFFC49A45)),
              ),
            if (partnerWeight > 0)
              Expanded(
                flex: (partnerWeight * 1000).round().clamp(1, 1000),
                child: Container(color: colors.accentSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllocationStatTile({
    required String name,
    required double amount,
    required int subsCount,
    required int emisCount,
    int splitSubsCount = 0,
    int splitEmisCount = 0,
    required Color color,
    required int percent,
    required bool isSplitDistributed,
    required CurrencyOption currency,
    required CoveTypography typography,
    required CoveColors colors,
  }) {
    final formattedAmt = formatCoveAmount(amount);

    final String countLabel;
    if (isSplitDistributed && (splitSubsCount > 0 || splitEmisCount > 0)) {
      countLabel = '$subsCount subs (+$splitSubsCount split) · $emisCount EMIs (+$splitEmisCount split)';
    } else {
      countLabel = '$subsCount subs · $emisCount EMIs';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceRow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  name,
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$percent%',
                style: typography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${currency.symbol}$formattedAmt',
            style: typography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: colors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            countLabel,
            style: typography.caption.copyWith(
              color: colors.textMuted,
              fontSize: 10,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required bool highlight,
    bool isWarning = false,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final dotColor = isWarning ? colors.accentSecondary : colors.accentPrimary;
    final textColor = isWarning
        ? colors.accentSecondary
        : (highlight ? colors.accentPrimary : colors.textPrimary);

    return Row(
      children: [
        if (highlight || isWarning) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: typography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: typography.caption.copyWith(
            color: isWarning ? colors.accentSecondary.withValues(alpha: 0.7) : colors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionRow(
    LocalSubscription sub,
    List<LocalOutboxEvent> outbox, {
    bool hasPartner = true,
    bool isUrgent = false,
    bool isOverdue = false,
    bool isPaused = false,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.watch(currencyPreferenceProvider);

    // Determine two-tick delivery status for shared items
    final tickStatus = resolveCoveSyncStatus(
      entityId: sub.id,
      outbox: outbox,
      isPrivate: sub.isPrivate,
      hasPartner: hasPartner,
    );

    final cycleSuffix = formatBillingCycleSuffix(sub.billingCycle);
    final renewalFormatted = DateFormat('MMM d').format(sub.nextBillingDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysUntilNext = DateTime(
      sub.nextBillingDate.year,
      sub.nextBillingDate.month,
      sub.nextBillingDate.day,
    ).difference(today).inDays;

    final String nextTiming;
    final String renewsText;
    if (daysUntilNext < 0) {
      final daysOverdue = -daysUntilNext;
      final overdueStr = daysOverdue == 1 ? 'overdue by 1 day' : 'overdue by $daysOverdue days';
      nextTiming = overdueStr;
      renewsText = overdueStr;
    } else if (daysUntilNext == 0) {
      nextTiming = 'next today';
      renewsText = 'renews today';
    } else if (daysUntilNext == 1) {
      nextTiming = 'next tomorrow';
      renewsText = 'renews tomorrow';
    } else if (daysUntilNext <= 30) {
      nextTiming = 'next in $daysUntilNext days';
      renewsText = 'renews in $daysUntilNext days';
    } else {
      nextTiming = 'next $renewalFormatted';
      renewsText = 'renews $renewalFormatted';
    }

    // Payer attribution
    final currentUser = ref.watch(authProvider).value;
    final partnerProfile = ref.watch(partnerProfileProvider);
    final partnerName = partnerProfile.displayName.trim().isNotEmpty
        ? partnerProfile.displayName.trim()
        : 'Partner';
    final isSplit = sub.effectivePaidBy == 'split' || sub.effectivePaidBy == '50/50';
    final isMe = (sub.effectivePaidBy == currentUser?.id) ||
        (currentUser?.id == null && sub.effectivePaidBy == 'user_alex') ||
        (sub.effectivePaidBy == 'me') ||
        (currentUser?.id != null && sub.createdBy == currentUser?.id && sub.paidBy == null);
    final paidText = isSplit ? 'Split (50/50)' : (isMe ? 'Paid by You' : 'Paid by $partnerName');
    final viaText = (sub.financedThrough != null && sub.financedThrough!.trim().isNotEmpty)
        ? ' · via ${sub.financedThrough!.trim()}'
        : '';

    final String subtitleText;
    if (isPaused) {
      subtitleText = sub.isEmiFinished
          ? '$paidText$viaText · Completed (${sub.emiProgress?.totalInstallments}/${sub.emiProgress?.totalInstallments} paid)'
          : '$paidText$viaText · Paused';
    } else if (sub.isEmi) {
      final progress = sub.emiProgress;
      subtitleText = progress != null
          ? '$paidText$viaText · ${progress.caption} · $nextTiming'
          : '$paidText$viaText · EMI · $nextTiming';
    } else {
      final cycleLabel = formatBillingCycleLabel(sub.billingCycle);
      subtitleText = '$paidText · $renewsText · $cycleLabel';
    }

    return CoveGroupedRow(
      onTap: () => CommitmentDetailSheet.show(context, sub),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: colors.surfaceRow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isOverdue
                ? colors.accentSecondary.withValues(alpha: 0.5)
                : (isUrgent
                    ? colors.accentPrimary.withValues(alpha: 0.4)
                    : colors.borderHairline),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          _getCategoryIcon(sub.category),
          size: 18,
          color: isOverdue
              ? colors.accentSecondary
              : (isUrgent ? colors.accentPrimary : colors.textMuted),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              sub.name,
              style: typography.bodyMedium.copyWith(
                color: isPaused
                    ? colors.textMuted
                    : (isOverdue ? colors.accentSecondary : colors.textPrimary),
                decoration: isPaused ? TextDecoration.lineThrough : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          if (isOverdue) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: colors.accentSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: colors.accentSecondary.withValues(alpha: 0.3), width: 1),
              ),
              child: Text(
                'OVERDUE',
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: colors.accentSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          // "Sub" or "EMI" Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: colors.surfaceRow,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.borderHairline, width: 1),
            ),
            child: Text(
              sub.commitmentTypeBadge,
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: colors.textMuted,
              ),
            ),
          ),
          if (sub.isPrivate) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surfaceRow,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.borderHairline, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 11,
                    color: colors.textMuted,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Private',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitleText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: typography.caption.copyWith(
          color: isOverdue
              ? colors.accentSecondary
              : (isUrgent ? colors.accentPrimary : colors.textMuted),
          fontWeight: (isUrgent || isOverdue) ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${currency.symbol}${formatCoveAmount(sub.amount)}$cycleSuffix',
            style: typography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: isPaused
                  ? colors.textMuted
                  : (isOverdue ? colors.accentSecondary : colors.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          CoveSyncTick(
            status: tickStatus,
            size: 13,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Commitments',
          style: context.typography.headline.copyWith(fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CovePillButton(
              label: '+ Add',
              variant: CoveButtonVariant.secondary,
              isCompact: true,
              onPressed: () => SubscriptionFormSheet.show(context),
            ),
          ),
        ],
      ),
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
                    icon: Icons.repeat_outlined,
                    title: 'No commitments yet',
                    description:
                        'Track joint household commitments, renewals, and finite EMIs in one calm space.',
                    action: CovePillButton(
                      label: 'Add First Commitment',
                      icon: const Icon(Icons.add, size: 16),
                      onPressed: () => SubscriptionFormSheet.show(context),
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

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'streaming':
        return Icons.play_circle_outline;
      case 'utilities':
        return Icons.bolt_outlined;
      case 'software':
        return Icons.devices_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'health':
        return Icons.favorite_outline;
      case 'news':
        return Icons.newspaper_outlined;
      default:
        return Icons.repeat_outlined;
    }
  }
}
