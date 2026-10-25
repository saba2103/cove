import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_error_state.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_round_button.dart';
import '../../core/widgets/cove_row.dart';
import '../../core/widgets/cove_section_label.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../add/add_draft.dart';
import '../add/add_flow.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import 'commitment_detail_sheet.dart';
import 'commitment_models.dart';
import 'commitments_helicopter_screen.dart';
import 'emi_tracker_screen.dart';

/// Segment filter modes for the Commitments screen (`design/screens/commitments.md`).
enum CommitmentKindFilter {
  all,
  subs,
  emis,
  savings,
}

/// Commitments screen (`design/screens/commitments.md` & `design/screens/commitments.png`).
///
/// Order:
/// 1. [CovePageHeader] — "Commitments", [CoveRoundButton] gold add.
/// 2. Monthly total card with a split bar (EMIs / subs / savings).
/// 3. "The runway" — caption with two icon buttons: EMIs page, full-year page.
/// 4. Segment filter: All · Subs · EMIs · Savings.
/// 5. Next-due block, then the list of commitments as [CoveRow], each with its
///    kind tag, payer avatar, financed-through source and amount.
class SubscriptionsScreen extends ConsumerStatefulWidget {
  final List<LocalSubscription>? initialSubscriptions;

  const SubscriptionsScreen({super.key, this.initialSubscriptions});

  @override
  ConsumerState<SubscriptionsScreen> createState() =>
      _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends ConsumerState<SubscriptionsScreen> {
  static const double _kHairline = 1.0; // (literal) 1dp hairline border
  static const double _kSplitBarHeight = 6.0; // (literal) hero split bar height
  static const double _kSwatchSize = 8.0; // (literal) legend square swatch
  static const double _kRunwayChartHeight =
      112.0; // (literal) runway mini chart height
  static const double _kPillHeight = 32.0; // (literal) filter pill height
  static const double _kAlertDotSize = 6.0; // (literal) status.alert mark size
  static const double _kAvatarOverlapOffset =
      16.0; // (literal) dual avatar overlap
  static const double _kInlineIconSize = 16.0; // (literal) inline icon size
  static const double _kEmptyIconSize = 28.0; // (literal) empty card icon size

  bool _showAnnual = false;
  bool _includePrivateInHero = false;
  bool _combineCycles = false;
  int _selectedAttributionTab = 0; // 0 = All, 1 = Me, 2 = Partner, 3 = Split
  CommitmentKindFilter _selectedKindFilter = CommitmentKindFilter.all;

  Future<void> _handleRefresh() async {
    final homeId = ref.read(activeHomeIdProvider);
    await ref
        .read(syncEngineProvider)
        .pullLatestEvents(homeId: homeId, forceFullCatchup: true);
  }

  static bool _isSavingsCommitment(LocalSubscription sub) {
    if (sub.isEmi) return false;
    final cat = (sub.category ?? '').trim().toLowerCase();
    final name = sub.name.trim().toLowerCase();
    if (cat == 'savings' ||
        cat == 'sip' ||
        cat == 'investment' ||
        cat == 'investments' ||
        cat == 'mutual_funds' ||
        cat == 'gold_sip') {
      return true;
    }
    return name.contains('sip') ||
        name.contains('mutual fund') ||
        name.contains('savings');
  }

  static String _kindTagFor(LocalSubscription sub) {
    if (sub.isEmi) return 'EMI';
    if (_isSavingsCommitment(sub)) return 'SIP';
    final cat = (sub.category ?? '').trim().toLowerCase();
    if (cat == 'rent') return 'RENT';
    if (cat == 'service' || cat == 'services') return 'SERVICE';
    if (cat == 'home' || cat == 'home & utilities' || cat == 'utilities') {
      return 'HOME';
    }
    if (cat == 'insurance') return 'INSURANCE';
    if (cat == 'pets') return 'PETS';
    return 'SUB';
  }

  CovePerson _resolvePayerPerson(
    LocalSubscription sub, {
    required String creatorId,
    required String myUserId,
    required String partnerUserId,
  }) {
    final payer = sub.effectivePaidBy.trim();
    final lower = payer.toLowerCase();
    if (lower == 'split' || lower == '50/50') {
      return CovePerson.both;
    }

    String? resolvedUserId;
    if (lower == 'me' ||
        payer == myUserId ||
        (payer == 'user_alex' && myUserId == 'local_user')) {
      resolvedUserId = myUserId;
    } else if (lower == 'partner' ||
        lower == 'partner_user' ||
        payer == partnerUserId) {
      resolvedUserId = partnerUserId;
    } else if (payer == creatorId) {
      resolvedUserId = creatorId;
    } else if (sub.paidBy == null || payer.isEmpty) {
      resolvedUserId = sub.createdBy ?? creatorId;
    }

    if (resolvedUserId != null) {
      return resolvedUserId == creatorId ? CovePerson.a : CovePerson.b;
    }
    return CovePerson.b;
  }

  String _resolvePayerInitial(
    LocalSubscription sub, {
    required CovePerson person,
    required String myName,
    required String partnerName,
    required String creatorId,
    required String myUserId,
  }) {
    if (person == CovePerson.both) return '&';
    final creatorIsMe = myUserId == creatorId || creatorId == 'user_alex';
    if (person == CovePerson.a) {
      return creatorIsMe ? myName : partnerName;
    }
    return creatorIsMe ? partnerName : myName;
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    if (widget.initialSubscriptions != null) {
      return _buildContent(context, widget.initialSubscriptions!);
    }

    final subscriptionsAsync = ref.watch(activeHomeSubscriptionsProvider);
    return subscriptionsAsync.when(
      data: (subscriptions) => _buildContent(context, subscriptions),
      loading: () => Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: const Center(child: CoveLoading()),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: cv.surfaceCanvas,
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
  ) {
    final cv = context.cv;
    final bottomPadding =
        CoveSpace.barClearance + MediaQuery.paddingOf(context).bottom;

    if (subscriptions.isEmpty) {
      return _buildEmptyState(context, bottomPadding: bottomPadding);
    }

    final home = ref.watch(activeHomeProvider).value;
    final currentUser = ref.watch(authProvider).value;
    final myUserId = currentUser?.id ?? 'local_user';
    final creatorId = home?.createdBy ?? myUserId;

    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);

    final myName = userProfile.displayName.trim().isNotEmpty
        ? userProfile.displayName.trim()
        : 'Me';
    final partnerName = partnerProfile.displayName.trim().isNotEmpty
        ? partnerProfile.displayName.trim()
        : 'Partner';
    final partnerUserId = partnerProfile.userId ?? 'partner_user';
    final currency = ref.watch(currencyPreferenceProvider);

    // 1. Separate Active vs Inactive (finished EMIs move out of active list)
    final activeSubs = subscriptions
        .where((s) => s.isActive && !s.isEmiFinished)
        .toList();
    final inactiveSubs = subscriptions
        .where((s) => !s.isActive || s.isEmiFinished)
        .toList();

    // 2. Separate Shared vs Private
    final sharedActive = activeSubs.where((s) => !s.isPrivate).toList();
    final privateActive = activeSubs.where((s) => s.isPrivate).toList();

    // 3. Compute Totals & Breakdown (EMIs / Subs / Savings)
    final relevantActive = _includePrivateInHero ? activeSubs : sharedActive;

    double subsMonthlyOnly = 0.0;
    double emisMonthlyOnly = 0.0;
    double savingsMonthlyOnly = 0.0;

    double subsAnnualOnly = 0.0;
    double emisAnnualOnly = 0.0;
    double savingsAnnualOnly = 0.0;

    double subsCombinedMonthly = 0.0;
    double emisCombinedMonthly = 0.0;
    double savingsCombinedMonthly = 0.0;

    for (final item in relevantActive) {
      final months = getBillingCycleMonths(item.billingCycle);
      final isAnnual = months == 12;
      final isMonthly = months == 1;
      final isSavings = _isSavingsCommitment(item);

      if (isAnnual) {
        if (item.isEmi) {
          emisAnnualOnly += item.amount;
        } else if (isSavings) {
          savingsAnnualOnly += item.amount;
        } else {
          subsAnnualOnly += item.amount;
        }
      } else if (isMonthly) {
        if (item.isEmi) {
          emisMonthlyOnly += item.amount;
        } else if (isSavings) {
          savingsMonthlyOnly += item.amount;
        } else {
          subsMonthlyOnly += item.amount;
        }
      }

      final monthlyAmount = item.amount / months;
      if (item.isEmi) {
        emisCombinedMonthly += monthlyAmount;
      } else if (isSavings) {
        savingsCombinedMonthly += monthlyAmount;
      } else {
        subsCombinedMonthly += monthlyAmount;
      }
    }

    final double displayedSubs;
    final double displayedEmis;
    final double displayedSavings;

    if (_combineCycles) {
      if (_showAnnual) {
        displayedSubs = subsCombinedMonthly * 12.0;
        displayedEmis = emisCombinedMonthly * 12.0;
        displayedSavings = savingsCombinedMonthly * 12.0;
      } else {
        displayedSubs = subsCombinedMonthly;
        displayedEmis = emisCombinedMonthly;
        displayedSavings = savingsCombinedMonthly;
      }
    } else {
      if (_showAnnual) {
        displayedSubs = subsAnnualOnly;
        displayedEmis = emisAnnualOnly;
        displayedSavings = savingsAnnualOnly;
      } else {
        displayedSubs = subsMonthlyOnly;
        displayedEmis = emisMonthlyOnly;
        displayedSavings = savingsMonthlyOnly;
      }
    }

    final double displayedAmount =
        displayedSubs + displayedEmis + displayedSavings;

    bool isMine(LocalSubscription item) {
      final pb = (item.paidBy ?? '').trim().toLowerCase();
      if (pb == 'split' || pb == '50/50') return false;
      if (pb == 'me' || pb == myUserId.toLowerCase()) return true;
      if (pb == partnerUserId.toLowerCase() || pb == 'partner_user') {
        return false;
      }
      if (pb.isEmpty) {
        return item.createdBy == myUserId || item.createdBy == 'local_user';
      }
      return true;
    }

    bool isPartner(LocalSubscription item) {
      final pb = (item.paidBy ?? '').trim().toLowerCase();
      if (pb == 'split' || pb == '50/50') return false;
      if (pb == partnerUserId.toLowerCase() || pb == 'partner_user') {
        return true;
      }
      return false;
    }

    bool isSplit(LocalSubscription item) {
      final pb = (item.paidBy ?? '').trim().toLowerCase();
      return pb == 'split' || pb == '50/50';
    }

    final attributionNames = <String>['All', myName, partnerName, 'Split'];
    if (_selectedAttributionTab >= attributionNames.length) {
      _selectedAttributionTab = 0;
    }

    List<LocalSubscription> filterByAttribution(List<LocalSubscription> list) {
      if (_selectedAttributionTab == 0) return list;
      if (_selectedAttributionTab == 1) {
        return list.where(isMine).toList();
      }
      if (_selectedAttributionTab == 2) {
        return list.where(isPartner).toList();
      }
      if (_selectedAttributionTab == 3) {
        return list.where(isSplit).toList();
      }
      return list;
    }

    final attributionFilteredActive = filterByAttribution(activeSubs);
    final attributionFilteredInactive = filterByAttribution(inactiveSubs);

    final allCount = attributionFilteredActive.length;
    final subsCount = attributionFilteredActive
        .where((s) => !s.isEmi && !_isSavingsCommitment(s))
        .length;
    final emisCount =
        attributionFilteredActive.where((s) => s.isEmi).length;
    final savingsCount = attributionFilteredActive
        .where(_isSavingsCommitment)
        .length;

    List<LocalSubscription> filterByKind(List<LocalSubscription> list) {
      switch (_selectedKindFilter) {
        case CommitmentKindFilter.all:
          return list;
        case CommitmentKindFilter.subs:
          return list
              .where((s) => !s.isEmi && !_isSavingsCommitment(s))
              .toList();
        case CommitmentKindFilter.emis:
          return list.where((s) => s.isEmi).toList();
        case CommitmentKindFilter.savings:
          return list.where(_isSavingsCommitment).toList();
      }
    }

    final filteredActive = filterByKind(attributionFilteredActive);
    final filteredInactive = filterByKind(attributionFilteredInactive);

    // Sort active commitments chronologically by nextBillingDate
    final sortedActive = List<LocalSubscription>.from(filteredActive)
      ..sort((a, b) {
        final cmp = a.nextBillingDate.compareTo(b.nextBillingDate);
        if (cmp != 0) return cmp;
        return b.amount.compareTo(a.amount);
      });

    // Group active commitments by calendar day (year, month, day)
    final dateGroups = <_CommitmentDateGroup>[];
    for (final sub in sortedActive) {
      final dayKey = DateTime(
        sub.nextBillingDate.year,
        sub.nextBillingDate.month,
        sub.nextBillingDate.day,
      );
      if (dateGroups.isEmpty || dateGroups.last.date != dayKey) {
        dateGroups.add(_CommitmentDateGroup(date: dayKey, items: [sub]));
      } else {
        dateGroups.last.items.add(sub);
      }
    }

    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SafeArea(
        bottom: false,
        child: CoveMaxWidth(
          child: RefreshIndicator(
            color: cv.accentFill,
            backgroundColor: cv.surfaceCard,
            onRefresh: _handleRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPadding),
              children: [
                // 1. CovePageHeader — "Commitments", CoveRoundButton gold add.
                CovePageHeader(
                  title: 'Commitments',
                  actions: [
                    CoveRoundButton(
                      icon: Icons.add_rounded,
                      variant: CoveRoundButtonVariant.gold,
                      tooltip: 'Add Commitment',
                      semanticLabel: 'Add Commitment',
                      onPressed: () => AddFlow.show(
                        context,
                        kind: AddKind.commitment,
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
                      // 2. Monthly total card with a split bar (EMIs / subs / savings)
                      _buildHeroTotalCard(
                        context,
                        currency: currency,
                        displayedAmount: displayedAmount,
                        displayedEmis: displayedEmis,
                        displayedSubs: displayedSubs,
                        displayedSavings: displayedSavings,
                        sharedCount: sharedActive.length,
                        privateCount: privateActive.length,
                        attributionLabel:
                            attributionNames[_selectedAttributionTab],
                        onCycleAttribution: () {
                          setState(() {
                            _selectedAttributionTab =
                                (_selectedAttributionTab + 1) %
                                    attributionNames.length;
                          });
                        },
                        myName: myName,
                        partnerName: partnerName,
                      ),
                      const SizedBox(height: CoveSpace.section),

                      // 3. "The runway" — caption with two icon buttons: EMIs page, full-year page
                      _buildRunwaySection(
                        context,
                        subscriptions: subscriptions,
                        activeSubs: relevantActive,
                      ),
                      const SizedBox(height: CoveSpace.section),

                      // 4. Segment filter: All · Subs · EMIs · Savings
                      _buildSegmentFilterRow(
                        context,
                        allCount: allCount,
                        subsCount: subsCount,
                        emisCount: emisCount,
                        savingsCount: savingsCount,
                      ),
                      const SizedBox(height: CoveSpace.lg),

                      // 5. Next-due block, then the list of commitments as CoveRow
                      if (dateGroups.isEmpty && filteredInactive.isEmpty)
                        _buildFilteredEmptyCard(
                          context,
                          filterLabel:
                              attributionNames[_selectedAttributionTab],
                        )
                      else ...[
                        for (var g = 0; g < dateGroups.length; g++) ...[
                          if (g > 0) const SizedBox(height: CoveSpace.lg),
                          _buildDateGroupBlock(
                            context,
                            group: dateGroups[g],
                            isFirstGroup: g == 0,
                            today: today,
                            currency: currency,
                            creatorId: creatorId,
                            myUserId: myUserId,
                            partnerUserId: partnerUserId,
                            myName: myName,
                            partnerName: partnerName,
                          ),
                        ],
                      ],

                      // Paused & Completed section when inactive commitments exist
                      if (filteredInactive.isNotEmpty) ...[
                        const SizedBox(height: CoveSpace.section),
                        CoveSectionLabel.page(
                          label: 'Paused & Completed',
                          readout: '${filteredInactive.length}',
                        ),
                        const SizedBox(height: CoveSpace.sm),
                        _buildInactiveGroupCard(
                          context,
                          inactiveSubs: filteredInactive,
                          currency: currency,
                          creatorId: creatorId,
                          myUserId: myUserId,
                          partnerUserId: partnerUserId,
                          myName: myName,
                          partnerName: partnerName,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroTotalCard(
    BuildContext context, {
    required CurrencyOption currency,
    required double displayedAmount,
    required double displayedEmis,
    required double displayedSubs,
    required double displayedSavings,
    required int sharedCount,
    required int privateCount,
    required String attributionLabel,
    required VoidCallback onCycleAttribution,
    required String myName,
    required String partnerName,
  }) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);

    final totalForBar =
        displayedAmount > 0 ? displayedAmount : 1.0;
    final emiFlex =
        ((displayedEmis / totalForBar) * 1000).round().clamp(0, 1000);
    final subsFlex =
        ((displayedSubs / totalForBar) * 1000).round().clamp(0, 1000);
    final savingsFlex =
        ((displayedSavings / totalForBar) * 1000).round().clamp(0, 1000);
    final hasAnyBar = emiFlex + subsFlex + savingsFlex > 0;

    final String cycleCaption = _showAnnual
        ? (_combineCycles
            ? 'per year · combined monthly & annual'
            : 'per year · annual commitments only')
        : (_combineCycles
            ? 'per month · combined monthly & annual'
            : 'per month · monthly commitments only');

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(CoveRadius.card)),
      child: Container(
        decoration: BoxDecoration(
          color: cv.surfaceCard,
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.card),
          ),
          border: Border.all(
            color: cv.lineHairline,
            width: _kHairline,
          ),
        ),
        child: Stack(
          children: [
            // Subtle concentric arc rings in top-right corner
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ConcentricArcsPainter(
                    lineColor: cv.lineHairline,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(CoveSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Monthly / Annually toggle + Household payer pill
                  Wrap(
                    spacing: CoveSpace.sm,
                    runSpacing: CoveSpace.sm,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Monthly / Annually segmented pill
                      Container(
                        decoration: BoxDecoration(
                          color: cv.surfaceRow,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(CoveRadius.pill),
                          ),
                          border: Border.all(
                            color: cv.lineHairline,
                            width: _kHairline,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildCycleSegmentPill(
                              context,
                              label: 'Monthly',
                              selected: !_showAnnual,
                              duration: duration,
                              onTap: () => setState(
                                () => _showAnnual =
                                    !_showAnnual ? true : false,
                              ),
                            ),
                            _buildCycleSegmentPill(
                              context,
                              label: 'Annually',
                              selected: _showAnnual,
                              duration: duration,
                              onTap: () => setState(
                                () => _showAnnual =
                                    _showAnnual ? false : true,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Payer attribution filter pill with dual inline avatars
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onCycleAttribution,
                        child: Container(
                          height: _kPillHeight,
                          padding: const EdgeInsets.symmetric(
                            horizontal: CoveSpace.sm,
                          ),
                          decoration: BoxDecoration(
                            color: cv.surfaceRow,
                            borderRadius: const BorderRadius.all(
                              Radius.circular(CoveRadius.pill),
                            ),
                            border: Border.all(
                              color: cv.lineHairline,
                              width: _kHairline,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: CoveSize.avatarInline +
                                    _kAvatarOverlapOffset,
                                height: CoveSize.avatarInline,
                                child: Stack(
                                  children: [
                                    Positioned(
                                      left: _kAvatarOverlapOffset,
                                      top: 0,
                                      child: CoveAvatar.inline(
                                        person: CovePerson.b,
                                        nameOrInitial: partnerName,
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      child: CoveAvatar.inline(
                                        person: CovePerson.a,
                                        nameOrInitial: myName,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: CoveSpace.xs),
                              Text(
                                attributionLabel,
                                style: CoveType.barLabel.copyWith(
                                  color: cv.textPrimary,
                                ),
                              ),
                              const SizedBox(width: CoveSpace.xs),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: _kInlineIconSize,
                                color: cv.textTertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CoveSpace.lg),

                  // Hero amount + "a month" / "a year"
                  Wrap(
                    spacing: CoveSpace.sm,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      Text(
                        '${currency.symbol}${formatCoveAmount(displayedAmount)}',
                        style: CoveType.heroFigure.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: CoveSpace.xs),
                        child: Text(
                          _showAnnual ? 'a year' : 'a month',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CoveSpace.xs),
                  Text(
                    cycleCaption,
                    style: CoveType.rowSub.copyWith(
                      color: cv.textTertiary,
                    ),
                  ),
                  const SizedBox(height: CoveSpace.md),

                  // Split bar (EMIs / Subs / Savings)
                  ClipRRect(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(CoveRadius.pill),
                    ),
                    child: SizedBox(
                      height: _kSplitBarHeight,
                      child: hasAnyBar
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (emiFlex > 0)
                                  Expanded(
                                    flex: emiFlex,
                                    child: ColoredBox(color: cv.accentFill),
                                  ),
                                if (subsFlex > 0) ...[
                                  if (emiFlex > 0)
                                    const SizedBox(width: CoveSpace.xs),
                                  Expanded(
                                    flex: subsFlex,
                                    child: ColoredBox(color: cv.lineStrong),
                                  ),
                                ],
                                if (savingsFlex > 0) ...[
                                  if (emiFlex > 0 || subsFlex > 0)
                                    const SizedBox(width: CoveSpace.xs),
                                  Expanded(
                                    flex: savingsFlex,
                                    child: ColoredBox(color: cv.statusGood),
                                  ),
                                ],
                              ],
                            )
                          : ColoredBox(color: cv.surfaceRow),
                    ),
                  ),
                  const SizedBox(height: CoveSpace.md),

                  // Legend: EMIs · Subs · Savings
                  Wrap(
                    spacing: CoveSpace.md,
                    runSpacing: CoveSpace.xs,
                    children: [
                      _buildLegendItem(
                        context,
                        swatchColor: cv.accentFill,
                        label: 'EMIs',
                        amountText:
                            '${currency.symbol}${formatCoveAmount(displayedEmis)}',
                      ),
                      _buildLegendItem(
                        context,
                        swatchColor: cv.lineStrong,
                        label: 'Subs',
                        amountText:
                            '${currency.symbol}${formatCoveAmount(displayedSubs)}',
                      ),
                      _buildLegendItem(
                        context,
                        swatchColor: cv.statusGood,
                        label: 'Savings',
                        amountText:
                            '${currency.symbol}${formatCoveAmount(displayedSavings)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: CoveSpace.md),

                  // Cycle combination toggle + Shared / Private count footer
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        setState(() => _combineCycles = !_combineCycles),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: CoveSpace.xs,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _combineCycles
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: _kInlineIconSize,
                            color: _combineCycles
                                ? cv.accentFill
                                : cv.textTertiary,
                          ),
                          const SizedBox(width: CoveSpace.xs),
                          Expanded(
                            child: Text(
                              'Calculate monthly & annual together',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CoveType.rowSub.copyWith(
                                color: cv.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: CoveSpace.xs),
                  Wrap(
                    spacing: CoveSpace.sm,
                    runSpacing: CoveSpace.xs,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        '$sharedCount shared commitments${privateCount > 0 ? " • $privateCount private" : ""}',
                        style: CoveType.rowSub.copyWith(
                          color: cv.textTertiary,
                        ),
                      ),
                      if (privateCount > 0)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(
                            () => _includePrivateInHero =
                                !_includePrivateInHero,
                          ),
                          child: Text(
                            _includePrivateInHero
                                ? 'Show shared only'
                                : 'Include private',
                            style: CoveType.rowSub.copyWith(
                              color: cv.accentText,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleSegmentPill(
    BuildContext context, {
    required String label,
    required bool selected,
    required Duration duration,
    required VoidCallback onTap,
  }) {
    final cv = context.cv;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: CoveMotion.easing,
        height: _kPillHeight,
        padding: const EdgeInsets.symmetric(horizontal: CoveSpace.md),
        decoration: BoxDecoration(
          color: selected ? cv.accentWash : Colors.transparent,
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.pill),
          ),
          border: Border.all(
            color: selected ? cv.accentFill : Colors.transparent,
            width: _kHairline,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: CoveType.barLabel.copyWith(
                color: selected ? cv.textPrimary : cv.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context, {
    required Color swatchColor,
    required String label,
    required String amountText,
  }) {
    final cv = context.cv;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: _kSwatchSize,
          height: _kSwatchSize,
          decoration: BoxDecoration(
            color: swatchColor,
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveSpace.xs),
            ),
          ),
        ),
        const SizedBox(width: CoveSpace.xs),
        Text(
          label,
          style: CoveType.rowSub.copyWith(color: cv.textTertiary),
        ),
        const SizedBox(width: CoveSpace.xs),
        Text(
          amountText,
          style: CoveType.rowSub.copyWith(color: cv.textPrimary),
        ),
      ],
    );
  }

  Widget _buildRunwaySection(
    BuildContext context, {
    required List<LocalSubscription> subscriptions,
    required List<LocalSubscription> activeSubs,
  }) {
    final cv = context.cv;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'THE RUNWAY',
                style: CoveType.capsPage.copyWith(color: cv.textTertiary),
              ),
            ),
            CoveRoundButton(
              icon: Icons.stacked_line_chart_rounded,
              variant: CoveRoundButtonVariant.ghost,
              tooltip: 'EMI Outstanding',
              semanticLabel: 'EMI Outstanding',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const EmiTrackerScreen(),
                  ),
                );
              },
            ),
            const SizedBox(width: CoveSpace.xs),
            CoveRoundButton(
              icon: Icons.calendar_month_outlined,
              variant: CoveRoundButtonVariant.ghost,
              tooltip: 'Helicopter View',
              semanticLabel: 'The year',
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
          ],
        ),
        const SizedBox(height: CoveSpace.sm),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EmiTrackerScreen(),
              ),
            );
          },
          child: SizedBox(
            height: _kRunwayChartHeight,
            width: double.infinity,
            child: CustomPaint(
              painter: _RunwayMiniChartPainter(
                activeSubs: activeSubs,
                strokeColor: cv.accentFill,
                fillColor: cv.accentWash,
                gridColor: cv.lineHairline,
                surfaceColor: cv.surfaceCanvas,
                pillFillColor: cv.accentFill,
                pillTextStyle: CoveType.barLabel.copyWith(
                  color: cv.textOnAccent,
                ),
                axisTextStyle: CoveType.barLabel.copyWith(
                  color: cv.textTertiary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentFilterRow(
    BuildContext context, {
    required int allCount,
    required int subsCount,
    required int emisCount,
    required int savingsCount,
  }) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);

    final segments = <(CommitmentKindFilter, String, int)>[
      (CommitmentKindFilter.all, 'All', allCount),
      (CommitmentKindFilter.subs, 'Subs', subsCount),
      (CommitmentKindFilter.emis, 'EMIs', emisCount),
      (CommitmentKindFilter.savings, 'Savings', savingsCount),
    ];

    return Wrap(
      spacing: CoveSpace.sm,
      runSpacing: CoveSpace.sm,
      children: [
        for (final seg in segments)
          Builder(
            builder: (context) {
              final isSelected = _selectedKindFilter == seg.$1;
              return Semantics(
                button: true,
                selected: isSelected,
                label: '${seg.$2} ${seg.$3}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      setState(() => _selectedKindFilter = seg.$1),
                  child: AnimatedContainer(
                    duration: duration,
                    curve: CoveMotion.easing,
                    height: _kPillHeight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoveSpace.md,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? cv.accentWash : Colors.transparent,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(CoveRadius.pill),
                      ),
                      border: Border.all(
                        color: isSelected ? cv.accentFill : cv.lineStrong,
                        width: _kHairline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          seg.$2,
                          style: CoveType.rowSub.copyWith(
                            color: isSelected
                                ? cv.textPrimary
                                : cv.textSecondary,
                          ),
                        ),
                        const SizedBox(width: CoveSpace.xs),
                        Text(
                          '${seg.$3}',
                          style: CoveType.barLabel.copyWith(
                            color: isSelected
                                ? cv.accentTint
                                : cv.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDateGroupBlock(
    BuildContext context, {
    required _CommitmentDateGroup group,
    required bool isFirstGroup,
    required DateTime today,
    required CurrencyOption currency,
    required String creatorId,
    required String myUserId,
    required String partnerUserId,
    required String myName,
    required String partnerName,
  }) {
    final cv = context.cv;
    final daysUntil = group.date.difference(today).inDays;
    final isOverdue = daysUntil < 0;
    final isDueSoon = daysUntil >= 0 && daysUntil <= 7;
    final carriesAlert = isOverdue || isDueSoon;

    final dayNum = '${group.date.day}';
    final monthWeekday =
        '${DateFormat('MMM').format(group.date)} · ${DateFormat('EEE').format(group.date)}';

    final String? statusWords;
    if (isOverdue) {
      statusWords = 'overdue';
    } else if (isDueSoon) {
      statusWords = isFirstGroup ? 'next · due soon' : 'due soon';
    } else if (isFirstGroup) {
      statusWords = 'next';
    } else {
      statusWords = null;
    }

    final groupTotal = group.items.fold<double>(
      0.0,
      (sum, s) => sum + s.amount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date group header
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              dayNum,
              style: CoveType.cardFigure.copyWith(
                color: isFirstGroup ? cv.accentTint : cv.textSecondary,
              ),
            ),
            const SizedBox(width: CoveSpace.sm),
            Expanded(
              child: Wrap(
                spacing: CoveSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    monthWeekday,
                    style: CoveType.rowSub.copyWith(
                      color: cv.textTertiary,
                    ),
                  ),
                  if (carriesAlert)
                    Container(
                      width: _kAlertDotSize,
                      height: _kAlertDotSize,
                      decoration: BoxDecoration(
                        color: cv.statusAlert,
                        shape: BoxShape.circle,
                      ),
                    ),
                  if (statusWords != null)
                    Text(
                      statusWords,
                      style: CoveType.rowSub.copyWith(
                        color: carriesAlert ? cv.statusAlert : cv.accentTint,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: CoveSpace.sm),
            Text(
              '${currency.symbol}${formatCoveAmount(groupTotal)}',
              style: CoveType.rowSub.copyWith(
                color: isFirstGroup ? cv.accentTint : cv.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: CoveSpace.sm),

        // Date group card containing CoveRow items
        Container(
          padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
          decoration: BoxDecoration(
            color: cv.surfaceCard,
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveRadius.card),
            ),
            border: Border.all(
              color: cv.lineHairline,
              width: _kHairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < group.items.length; i++)
                _buildCommitmentRow(
                  context,
                  sub: group.items[i],
                  isLast: i == group.items.length - 1,
                  today: today,
                  currency: currency,
                  creatorId: creatorId,
                  myUserId: myUserId,
                  partnerUserId: partnerUserId,
                  myName: myName,
                  partnerName: partnerName,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommitmentRow(
    BuildContext context, {
    required LocalSubscription sub,
    required bool isLast,
    required DateTime today,
    required CurrencyOption currency,
    required String creatorId,
    required String myUserId,
    required String partnerUserId,
    required String myName,
    required String partnerName,
    bool isPaused = false,
  }) {
    final person = _resolvePayerPerson(
      sub,
      creatorId: creatorId,
      myUserId: myUserId,
      partnerUserId: partnerUserId,
    );
    final initial = _resolvePayerInitial(
      sub,
      person: person,
      myName: myName,
      partnerName: partnerName,
      creatorId: creatorId,
      myUserId: myUserId,
    );

    final kindTag = _kindTagFor(sub);
    final subParts = <String>[kindTag];

    final renDay = DateTime(
      sub.nextBillingDate.year,
      sub.nextBillingDate.month,
      sub.nextBillingDate.day,
    );
    final daysUntil = renDay.difference(today).inDays;

    if (isPaused) {
      if (sub.isEmiFinished) {
        final progress = sub.emiProgress;
        subParts.add(
          progress != null
              ? 'Completed (${progress.totalInstallments}/${progress.totalInstallments} paid)'
              : 'Completed',
        );
      } else {
        subParts.add('Paused');
      }
      if (sub.financedThrough != null &&
          sub.financedThrough!.trim().isNotEmpty) {
        subParts.add('via ${sub.financedThrough!.trim()}');
      }
    } else {
      if (sub.isEmi) {
        final progress = sub.emiProgress;
        if (progress != null) {
          subParts.add(progress.caption);
        }
      } else if (_isSavingsCommitment(sub)) {
        subParts.add('auto-debit');
      } else if (person == CovePerson.both) {
        subParts.add(
          'split · ${currency.symbol}${formatCoveAmount(sub.amount / 2)} each',
        );
      } else {
        subParts.add(formatBillingCycleLabel(sub.billingCycle));
      }

      if (sub.financedThrough != null &&
          sub.financedThrough!.trim().isNotEmpty) {
        subParts.add('via ${sub.financedThrough!.trim()}');
      }

      if (daysUntil < 0) {
        subParts.add('Overdue');
      } else if (daysUntil <= 7) {
        subParts.add('Due soon');
      }
    }

    if (sub.isPrivate) {
      subParts.add('Private');
    }

    final cycleSuffix = formatBillingCycleSuffix(sub.billingCycle);
    final amountText = cycleSuffix == '/mo'
        ? '${currency.symbol}${formatCoveAmount(sub.amount)}'
        : '${currency.symbol}${formatCoveAmount(sub.amount)}$cycleSuffix';

    return CoveRow(
      avatar: CoveAvatar.row(
        person: person,
        nameOrInitial: person == CovePerson.both ? null : initial,
      ),
      title: sub.name,
      subtitle: subParts.join(' · '),
      amount: amountText,
      isLast: isLast,
      showDivider: !isLast,
      onTap: () => CommitmentDetailSheet.show(context, sub),
    );
  }

  Widget _buildInactiveGroupCard(
    BuildContext context, {
    required List<LocalSubscription> inactiveSubs,
    required CurrencyOption currency,
    required String creatorId,
    required String myUserId,
    required String partnerUserId,
    required String myName,
    required String partnerName,
  }) {
    final cv = context.cv;
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
      decoration: BoxDecoration(
        color: cv.surfaceCard,
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveRadius.card),
        ),
        border: Border.all(
          color: cv.lineHairline,
          width: _kHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < inactiveSubs.length; i++)
            _buildCommitmentRow(
              context,
              sub: inactiveSubs[i],
              isLast: i == inactiveSubs.length - 1,
              today: today,
              currency: currency,
              creatorId: creatorId,
              myUserId: myUserId,
              partnerUserId: partnerUserId,
              myName: myName,
              partnerName: partnerName,
              isPaused: true,
            ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyCard(
    BuildContext context, {
    required String filterLabel,
  }) {
    final cv = context.cv;

    return Container(
      padding: const EdgeInsets.all(CoveSpace.gutter),
      decoration: BoxDecoration(
        color: cv.surfaceCard,
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveRadius.card),
        ),
        border: Border.all(
          color: cv.lineHairline,
          width: _kHairline,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: _kEmptyIconSize,
            color: cv.textTertiary,
          ),
          const SizedBox(height: CoveSpace.sm),
          Text(
            'No commitments for $filterLabel',
            style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: CoveSpace.xs),
          Text(
            'Tap "+" above to add a commitment to this category.',
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required double bottomPadding,
  }) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SafeArea(
        bottom: false,
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
                  title: 'Commitments',
                  actions: [
                    CoveRoundButton(
                      icon: Icons.stacked_line_chart_rounded,
                      variant: CoveRoundButtonVariant.ghost,
                      tooltip: 'EMI Outstanding',
                      semanticLabel: 'EMI Outstanding',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EmiTrackerScreen(),
                          ),
                        );
                      },
                    ),
                    CoveRoundButton(
                      icon: Icons.add_rounded,
                      variant: CoveRoundButtonVariant.gold,
                      tooltip: 'Add Commitment',
                      semanticLabel: 'Add Commitment',
                      onPressed: () => AddFlow.show(
                        context,
                        kind: AddKind.commitment,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CoveSpace.section),
                Center(
                  child: CoveEmptyState(
                    icon: Icons.repeat_outlined,
                    title: 'No commitments yet',
                    description:
                        'Track joint household commitments, renewals, and finite EMIs in one calm space.',
                    action: CovePillButton(
                      label: 'Add First Commitment',
                      icon: const Icon(
                        Icons.add,
                        size: _kInlineIconSize,
                      ),
                      onPressed: () => AddFlow.show(
                        context,
                        kind: AddKind.commitment,
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
}

class _CommitmentDateGroup {
  final DateTime date;
  final List<LocalSubscription> items;

  _CommitmentDateGroup({
    required this.date,
    required this.items,
  });
}

class _ConcentricArcsPainter extends CustomPainter {
  final Color lineColor;

  const _ConcentricArcsPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final center = Offset(size.width * 0.92, -size.height * 0.12);
    for (int i = 1; i <= 7; i++) {
      final radius = i * 24.0;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricArcsPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}

class _RunwayMiniChartPainter extends CustomPainter {
  final List<LocalSubscription> activeSubs;
  final Color strokeColor;
  final Color fillColor;
  final Color gridColor;
  final Color surfaceColor;
  final Color pillFillColor;
  final TextStyle pillTextStyle;
  final TextStyle axisTextStyle;

  const _RunwayMiniChartPainter({
    required this.activeSubs,
    required this.strokeColor,
    required this.fillColor,
    required this.gridColor,
    required this.surfaceColor,
    required this.pillFillColor,
    required this.pillTextStyle,
    required this.axisTextStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 24.0;
    const bottomPad = 20.0;
    const rightPad = 8.0;
    final chartHeight = math.max(1.0, size.height - topPad - bottomPad);
    final chartBottom = topPad + chartHeight;
    final plotWidth = math.max(1.0, size.width - rightPad);

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    // Baseline and left axis
    canvas.drawLine(
      Offset(0, topPad),
      Offset(0, chartBottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(0, chartBottom),
      Offset(size.width, chartBottom),
      gridPaint,
    );

    // "TODAY" pill at top-left
    final todayTp = TextPainter(
      text: TextSpan(text: 'TODAY', style: pillTextStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, todayTp.width + 12.0, todayTp.height + 4.0),
      const Radius.circular(CoveRadius.pill),
    );
    canvas.drawRRect(
      pillRect,
      Paint()..color = pillFillColor,
    );
    todayTp.paint(canvas, const Offset(6.0, 2.0));

    // Dashed vertical year guides
    final baseYear = activeSubs.isNotEmpty
        ? activeSubs.first.nextBillingDate.year
        : clock.now().year;
    for (int i = 1; i <= 3; i++) {
      final x = (i / 3.4) * plotWidth;
      for (double y = topPad; y < chartBottom; y += 6.0) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, math.min(y + 3.0, chartBottom)),
          gridPaint,
        );
      }
      final yrShort = "'${(baseYear + i) % 100}";
      final yrTp = TextPainter(
        text: TextSpan(text: yrShort, style: axisTextStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      yrTp.paint(
        canvas,
        Offset(
          (x - yrTp.width / 2).clamp(0.0, size.width - yrTp.width),
          chartBottom + 4.0,
        ),
      );
    }

    // Build stepped runway curve
    final emis = activeSubs.where((s) => s.isEmi).toList();
    final stepPoints = <(double, double)>[];
    if (emis.length >= 2) {
      final totalMonthly = activeSubs.fold<double>(
        0.0,
        (sum, s) => sum + s.amount / getBillingCycleMonths(s.billingCycle),
      );
      final remList = <int>[];
      for (final e in emis) {
        final p = e.emiProgress;
        final rem = p != null
            ? math.max(1, p.totalInstallments - p.paidInstallments)
            : 6;
        if (!remList.contains(rem)) remList.add(rem);
      }
      remList.sort();
      final maxM = math.max(1, remList.last);
      for (final m in remList) {
        double remAmt = 0.0;
        for (final s in activeSubs) {
          if (!s.isEmi) {
            remAmt += s.amount / getBillingCycleMonths(s.billingCycle);
          } else {
            final p = s.emiProgress;
            final r = p != null
                ? math.max(1, p.totalInstallments - p.paidInstallments)
                : 6;
            if (r > m) {
              remAmt += s.amount / getBillingCycleMonths(s.billingCycle);
            }
          }
        }
        final xFrac = (m / maxM).clamp(0.0, 1.0);
        final yFrac = totalMonthly > 0
            ? (1.0 - (remAmt / totalMonthly)).clamp(0.15, 0.85)
            : 0.5;
        stepPoints.add((xFrac, yFrac));
      }
    } else {
      stepPoints.addAll(const <(double, double)>[
        (0.18, 0.25),
        (0.42, 0.48),
        (0.72, 0.68),
        (0.95, 0.84),
      ]);
    }

    final stepPath = Path()..moveTo(0, topPad + 4.0);
    double currentY = topPad + 4.0;
    final nodes = <Offset>[];

    for (final pt in stepPoints) {
      final x = pt.$1 * plotWidth;
      final nextY = topPad + chartHeight * pt.$2;
      stepPath.lineTo(x, currentY);
      stepPath.lineTo(x, nextY);
      nodes.add(Offset(x, nextY));
      currentY = nextY;
    }
    stepPath.lineTo(plotWidth, currentY);

    final fillPath = Path.from(stepPath)
      ..lineTo(plotWidth, chartBottom)
      ..lineTo(0, chartBottom)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      stepPath,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final nodeFill = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;
    final nodeStroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final center in nodes) {
      canvas.drawCircle(center, 3.0, nodeFill);
      canvas.drawCircle(center, 3.0, nodeStroke);
    }
  }

  @override
  bool shouldRepaint(covariant _RunwayMiniChartPainter oldDelegate) {
    return oldDelegate.activeSubs != activeSubs ||
        oldDelegate.strokeColor != strokeColor;
  }
}
