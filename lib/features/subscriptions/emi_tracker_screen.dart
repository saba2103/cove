import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_round_button.dart';
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

enum EmiSortMode {
  byWho,
  endsFirst,
  biggest,
}

class _StaircaseStep {
  final int monthsFromNow;
  final DateTime date;
  final double remainingMonthly;
  final List<LocalSubscription> closedAtStep;

  const _StaircaseStep({
    required this.monthsFromNow,
    required this.date,
    required this.remainingMonthly,
    required this.closedAtStep,
  });
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
  static const double _kHairline = 1.0; // (literal)
  static const double _kSelectedBorder = 1.5; // (literal)
  static const double _kBarHeight = 4.0; // (literal)
  static const double _kStaircaseHeight = 164.0; // (literal)
  static const double _kHeroSilhouetteHeight = 44.0; // (literal)
  static const double _kTickTrackHeight = 6.0; // (literal)
  static const double _kSortPillHeight = 32.0; // (literal)
  static const double _kCheckIconSize = 14.0; // (literal)

  EmiSortMode _sortMode = EmiSortMode.byWho;
  bool _whatIfMode = false;
  final Set<String> _selectedEmiIds = <String>{};
  int? _selectedStepIndex;

  void _toggleWhatIfMode() {
    setState(() {
      if (_whatIfMode || _selectedEmiIds.isNotEmpty) {
        _whatIfMode = false;
        _selectedEmiIds.clear();
      } else {
        _whatIfMode = true;
      }
    });
  }

  void _toggleEmiSelection(String emiId) {
    setState(() {
      if (_selectedEmiIds.contains(emiId)) {
        _selectedEmiIds.remove(emiId);
      } else {
        _selectedEmiIds.add(emiId);
        _whatIfMode = true;
      }
    });
  }

  int _remainingInstallmentsOf(LocalSubscription emi) {
    final paid = emi.emiProgress?.paidInstallments ?? (emi.paidInstallments ?? 0);
    final total =
        emi.emiProgress?.totalInstallments ?? (emi.totalInstallments ?? 1);
    return (total - paid).clamp(0, total);
  }

  int _paidInstallmentsOf(LocalSubscription emi) {
    final paid = emi.emiProgress?.paidInstallments ?? (emi.paidInstallments ?? 0);
    final total =
        emi.emiProgress?.totalInstallments ?? (emi.totalInstallments ?? 1);
    return paid.clamp(0, total);
  }

  int _totalInstallmentsOf(LocalSubscription emi) {
    return math.max(
      1,
      emi.emiProgress?.totalInstallments ?? (emi.totalInstallments ?? 1),
    );
  }

  DateTime _endDateOf(LocalSubscription emi) {
    if (emi.endDate != null) {
      return emi.endDate!.toLocal();
    }
    final rem = math.max(1, _remainingInstallmentsOf(emi));
    final billingLocal = emi.nextBillingDate.toLocal();
    return DateTime(
      billingLocal.year,
      billingLocal.month + rem - 1,
      billingLocal.day,
    );
  }

  CovePerson _resolvePayerPerson(
    LocalSubscription emi, {
    required String creatorId,
    required String? currentUserId,
    required String? partnerUserId,
  }) {
    final payer = emi.effectivePaidBy.trim();
    final lower = payer.toLowerCase();
    if (lower == 'split' || lower == '50/50') {
      return CovePerson.both;
    }

    String? resolvedUserId;
    if (lower == 'me') {
      resolvedUserId = currentUserId ?? creatorId;
    } else if (lower == 'partner') {
      resolvedUserId = partnerUserId ?? 'partner_user';
    } else if (payer == currentUserId || payer == partnerUserId || payer == creatorId) {
      resolvedUserId = payer;
    } else if (emi.paidBy == null || payer.isEmpty) {
      resolvedUserId = emi.createdBy;
    }

    if (resolvedUserId != null) {
      return resolvedUserId == creatorId ? CovePerson.a : CovePerson.b;
    }
    return CovePerson.b;
  }

  String _resolvePayerGroupName(
    LocalSubscription emi, {
    required String creatorId,
    required String? currentUserId,
    required String? partnerUserId,
    required String myName,
    required String partnerName,
  }) {
    final payer = emi.effectivePaidBy.trim();
    final lower = payer.toLowerCase();
    if (lower == 'split' || lower == '50/50') {
      return 'BOTH · SPLIT 50/50';
    }
    final isMe = (payer == currentUserId) ||
        (currentUserId == null && payer == 'user_alex') ||
        lower == 'me' ||
        (currentUserId != null &&
            emi.createdBy == currentUserId &&
            (emi.paidBy == null || payer.isEmpty));
    if (isMe) {
      return myName;
    }
    if (partnerUserId != null && payer == partnerUserId) {
      return partnerName;
    }
    if (payer.isNotEmpty && lower != 'partner') {
      return payer;
    }
    return partnerName;
  }

  List<_StaircaseStep> _computeStaircaseSteps(
    List<LocalSubscription> activeEmis,
    DateTime referenceDate,
  ) {
    if (activeEmis.isEmpty) return const [];

    final byMonths = <int, List<LocalSubscription>>{};
    for (final emi in activeEmis) {
      final rem = math.max(1, _remainingInstallmentsOf(emi));
      byMonths.putIfAbsent(rem, () => []).add(emi);
    }

    final sortedMonths = byMonths.keys.toList()..sort();
    final steps = <_StaircaseStep>[];

    for (final m in sortedMonths) {
      double remainingAfter = 0.0;
      for (final emi in activeEmis) {
        final rem = math.max(1, _remainingInstallmentsOf(emi));
        if (rem > m) {
          remainingAfter += emi.amount;
        }
      }
      final stepDate = DateTime(referenceDate.year, referenceDate.month + m, 1);
      steps.add(
        _StaircaseStep(
          monthsFromNow: m,
          date: stepDate,
          remainingMonthly: remainingAfter,
          closedAtStep: byMonths[m]!,
        ),
      );
    }

    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final currency = ref.watch(currencyPreferenceProvider);

    if (widget.initialSubscriptions != null) {
      return _buildScaffold(context, widget.initialSubscriptions!, currency);
    }

    final subscriptionsAsync = ref.watch(activeHomeSubscriptionsProvider);
    return subscriptionsAsync.when(
      data: (subscriptions) => _buildScaffold(context, subscriptions, currency),
      loading: () => Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: const CovePageInsets(child: Center(child: CoveLoading())),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: CovePageInsets(
          child: Center(
            child: Text(
              'Could not load EMIs right now',
              style: CoveType.body.copyWith(color: cv.textTertiary),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    List<LocalSubscription> subscriptions,
    CurrencyOption currency,
  ) {
    final cv = context.cv;

    final home = ref.watch(activeHomeProvider).value;
    final currentUser = ref.watch(authProvider).value;
    final currentUserId = currentUser?.id;
    final creatorId = home?.createdBy ?? currentUserId ?? 'user_alex';

    final myProfile = ref.watch(userProfileProvider);
    final myName = myProfile.displayName.trim().isNotEmpty
        ? myProfile.displayName.trim()
        : 'You';
    final partnerProfile = ref.watch(partnerProfileProvider);
    final partnerName = partnerProfile.displayName.trim().isNotEmpty
        ? partnerProfile.displayName.trim()
        : 'Partner';
    final partnerUserId = partnerProfile.userId;

    final allActiveEmis = subscriptions
        .where((s) => s.isEmi && s.isActive && !s.isEmiFinished)
        .toList();
    final completedEmis = subscriptions
        .where((s) => s.isEmi && s.isEmiFinished)
        .toList();

    // Effective EMIs after excluding any simulated "What if…" closures
    final effectiveEmis = allActiveEmis
        .where((e) => !_selectedEmiIds.contains(e.id))
        .toList();

    double totalOutstanding = 0.0;
    double totalPaid = 0.0;
    double totalMonthlyOutflow = 0.0;
    double personAMonthly = 0.0;
    double personBMonthly = 0.0;
    double bothMonthly = 0.0;

    LocalSubscription? longestEmi;
    int maxRemainingMonths = 0;

    for (final emi in effectiveEmis) {
      final paid = _paidInstallmentsOf(emi);
      final rem = _remainingInstallmentsOf(emi);
      totalOutstanding += rem * emi.amount;
      totalPaid += paid * emi.amount;
      totalMonthlyOutflow += emi.amount;

      if (rem >= maxRemainingMonths) {
        maxRemainingMonths = rem;
        longestEmi = emi;
      }

      final person = _resolvePayerPerson(
        emi,
        creatorId: creatorId,
        currentUserId: currentUserId,
        partnerUserId: partnerUserId,
      );
      switch (person) {
        case CovePerson.a:
          personAMonthly += emi.amount;
        case CovePerson.b:
          personBMonthly += emi.amount;
        case CovePerson.both:
          bothMonthly += emi.amount;
      }
    }

    final totalLoanValue = totalOutstanding + totalPaid;
    final overallPayoffPercent = totalLoanValue > 0
        ? (totalPaid / totalLoanValue).clamp(0.0, 1.0)
        : 0.0;

    double selectedOutstanding = 0.0;
    double selectedMonthlyOutflow = 0.0;
    for (final emi in allActiveEmis) {
      if (_selectedEmiIds.contains(emi.id)) {
        final rem = _remainingInstallmentsOf(emi);
        selectedOutstanding += rem * emi.amount;
        selectedMonthlyOutflow += emi.amount;
      }
    }

    final referenceDate = allActiveEmis.isNotEmpty
        ? allActiveEmis.first.nextBillingDate
        : clock.now();
    final freeByDate = longestEmi != null
        ? _endDateOf(longestEmi)
        : referenceDate;

    final steps = _computeStaircaseSteps(effectiveEmis, referenceDate);

    final bottomPadding =
        CoveSpace.barClearance + CovePageInsets.bottomOf(context);

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: CovePageInsets(
        child: CoveMaxWidth(
          child: allActiveEmis.isEmpty && completedEmis.isEmpty
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CovePageHeader(
                      leading: CoveRoundButton(
                        icon: Icons.arrow_back_rounded,
                        variant: CoveRoundButtonVariant.ghost,
                        tooltip: 'Back',
                        semanticLabel: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      title: 'EMIs',
                      trailingPill: CoveHeaderPill(
                        key: const ValueKey('emi_what_if_pill'),
                        label: 'What if…',
                        isActive: _whatIfMode,
                        onPressed: _toggleWhatIfMode,
                      ),
                    ),
                    Expanded(child: _buildEmptyState(context)),
                  ],
                )
              : ListView(
                  padding: EdgeInsets.only(bottom: bottomPadding),
                  children: [
                    // 1. CovePageHeader — back button, "EMIs", and the "What if…" pill (28dp)
                    CovePageHeader(
                      leading: CoveRoundButton(
                        icon: Icons.arrow_back_rounded,
                        variant: CoveRoundButtonVariant.ghost,
                        tooltip: 'Back',
                        semanticLabel: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      title: 'EMIs',
                      trailingPill: CoveHeaderPill(
                        key: const ValueKey('emi_what_if_pill'),
                        label: 'What if…',
                        isActive: _whatIfMode || _selectedEmiIds.isNotEmpty,
                        onPressed: _toggleWhatIfMode,
                      ),
                    ),
                    const SizedBox(height: CoveSpace.md),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.gutter,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // What-if interactive tray when active or when rows are selected
                          if (_whatIfMode || _selectedEmiIds.isNotEmpty) ...[
                            _buildWhatIfTray(
                              context,
                              currency: currency,
                              selectedCount: _selectedEmiIds.length,
                              selectedMonthlyOutflow: selectedMonthlyOutflow,
                              selectedOutstanding: selectedOutstanding,
                            ),
                            const SizedBox(height: CoveSpace.md),
                          ],

                          // 2. Three cards:
                          //    Card 1: when it all closes
                          _buildFreeByHeroCard(
                            context,
                            effectiveEmis: effectiveEmis,
                            longestEmi: longestEmi,
                            maxRemainingMonths: maxRemainingMonths,
                            freeByDate: freeByDate,
                            hasWhatIfSelection: _selectedEmiIds.isNotEmpty,
                            steps: steps,
                            initialMonthly: totalMonthlyOutflow,
                          ),
                          const SizedBox(height: CoveSpace.md),

                          //    Card 2 & Card 3: the monthly EMI with a who-split bar · left-to-pay with a paid-% bar
                          _buildSecondaryCardsRow(
                            context,
                            currency: currency,
                            effectiveCount: effectiveEmis.length,
                            totalMonthlyOutflow: totalMonthlyOutflow,
                            totalOutstanding: totalOutstanding,
                            totalPaid: totalPaid,
                            overallPayoffPercent: overallPayoffPercent,
                            personAMonthly: personAMonthly,
                            personBMonthly: personBMonthly,
                            bothMonthly: bothMonthly,
                          ),
                          const SizedBox(height: CoveSpace.section),

                          // 3. The staircase graph — "tap the steps"
                          if (effectiveEmis.isNotEmpty) ...[
                            const CoveSectionLabel.page(
                              label: 'WHEN IT GETS LIGHTER',
                              readout: 'tap the steps',
                            ),
                            const SizedBox(height: CoveSpace.md),
                            _buildStaircaseGraph(
                              context,
                              currency: currency,
                              initialMonthly: totalMonthlyOutflow,
                              referenceDate: referenceDate,
                              steps: steps,
                            ),
                            const SizedBox(height: CoveSpace.section),
                          ],

                          // 4. Sort controls + Ledger rows grouped by who pays
                          if (allActiveEmis.isNotEmpty) ...[
                            _buildSortModeRow(context),
                            const SizedBox(height: CoveSpace.lg),
                            _buildLedgerSection(
                              context,
                              allActiveEmis: allActiveEmis,
                              currency: currency,
                              creatorId: creatorId,
                              currentUserId: currentUserId,
                              partnerUserId: partnerUserId,
                              myName: myName,
                              partnerName: partnerName,
                            ),
                          ],

                          if (completedEmis.isNotEmpty) ...[
                            const SizedBox(height: CoveSpace.section),
                            CoveSectionLabel.page(
                              label: 'COMPLETED LOANS',
                              readout: '${completedEmis.length}',
                            ),
                            const SizedBox(height: CoveSpace.sm),
                            _buildCompletedGroupCard(
                              context,
                              completedEmis: completedEmis,
                              currency: currency,
                            ),
                          ],

                          const SizedBox(height: CoveSpace.lg),
                          Text(
                            'One tick per instalment — a sixty-month loan with nine left still looks like a sixty-month loan. Press and hold any loan — or use What if… above — to see the month without it.',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildWhatIfTray(
    BuildContext context, {
    required CurrencyOption currency,
    required int selectedCount,
    required double selectedMonthlyOutflow,
    required double selectedOutstanding,
  }) {
    final cv = context.cv;

    return Container(
      padding: const EdgeInsets.all(CoveSpace.md),
      decoration: CoveShape.decoration(
        CoveRadius.inline,
        color: cv.surfaceRow,
        side: BorderSide(
          color: cv.accentFill,
          width: _kHairline,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: selectedCount == 0
                ? Text(
                    'Tap any EMI below to see the month and free-by date without it.',
                    style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'IF WE CLOSE THESE',
                            style: CoveType.capsCard.copyWith(
                              color: cv.accentTint,
                            ),
                          ),
                          const SizedBox(width: CoveSpace.xs),
                          Text(
                            '($selectedCount)',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CoveSpace.xs),
                      Wrap(
                        spacing: CoveSpace.md,
                        runSpacing: CoveSpace.xs,
                        children: [
                          Text(
                            'Frees ${currency.symbol}${formatCoveAmount(selectedMonthlyOutflow)}/mo',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textPrimary,
                            ),
                          ),
                          Text(
                            'Payoff ${currency.symbol}${formatCoveAmount(selectedOutstanding)}',
                            style: CoveType.rowSub.copyWith(
                              color: cv.accentTint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: CoveSpace.sm),
          CoveRoundButton.stepper(
            key: const ValueKey('emi_clear_what_if'),
            icon: Icons.close_rounded,
            tooltip: 'Clear what-if selection',
            semanticLabel: 'Clear what-if selection',
            onPressed: () {
              setState(() {
                _whatIfMode = false;
                _selectedEmiIds.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFreeByHeroCard(
    BuildContext context, {
    required List<LocalSubscription> effectiveEmis,
    required LocalSubscription? longestEmi,
    required int maxRemainingMonths,
    required DateTime freeByDate,
    required bool hasWhatIfSelection,
    required List<_StaircaseStep> steps,
    required double initialMonthly,
  }) {
    final cv = context.cv;

    final String label = hasWhatIfSelection
        ? 'IF CLOSED · FREE OF ALL ${effectiveEmis.length} IN'
        : 'FREE OF ALL ${effectiveEmis.length} IN';

    final String heroText = effectiveEmis.isEmpty
        ? 'Right now'
        : DateFormat('MMMM yyyy').format(freeByDate);

    return Container(
      padding: const EdgeInsets.all(CoveSpace.gutter),
      decoration: CoveShape.decoration(
        CoveRadius.card,
        color: cv.surfaceCard,
        side: BorderSide(
          color: cv.lineHairline,
          width: _kHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (steps.isNotEmpty) ...[
            SizedBox(
              height: _kHeroSilhouetteHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: _MiniStaircaseSilhouettePainter(
                  steps: steps,
                  initialMonthly: initialMonthly,
                  strokeColor: cv.lineStrong,
                  fillColor: cv.accentWash,
                ),
              ),
            ),
            const SizedBox(height: CoveSpace.sm),
          ],
          CoveSectionLabel.card(label: label),
          const SizedBox(height: CoveSpace.xs),
          Text(
            heroText,
            style: CoveType.heroFigure.copyWith(color: cv.accentTint),
          ),
          const SizedBox(height: CoveSpace.sm),
          if (longestEmi != null)
            Text.rich(
              TextSpan(
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                children: [
                  TextSpan(
                    text:
                        '$maxRemainingMonths more ${maxRemainingMonths == 1 ? 'EMI' : 'EMIs'}',
                    style: CoveType.rowSub.copyWith(color: cv.textPrimary),
                  ),
                  TextSpan(
                    text:
                        ' on the longest — ${longestEmi.name}. Everything else is gone before it.',
                  ),
                ],
              ),
            )
          else
            Text(
              'Every active loan is cleared in this scenario.',
              style: CoveType.rowSub.copyWith(color: cv.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _buildSecondaryCardsRow(
    BuildContext context, {
    required CurrencyOption currency,
    required int effectiveCount,
    required double totalMonthlyOutflow,
    required double totalOutstanding,
    required double totalPaid,
    required double overallPayoffPercent,
    required double personAMonthly,
    required double personBMonthly,
    required double bothMonthly,
  }) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isCompact =
        (MediaQuery.sizeOf(context).width / textScale) <
        CoveSize.compactThreshold;

    final eachMonthCard = _buildEachMonthCard(
      context,
      currency: currency,
      effectiveCount: effectiveCount,
      totalMonthlyOutflow: totalMonthlyOutflow,
      personAMonthly: personAMonthly,
      personBMonthly: personBMonthly,
      bothMonthly: bothMonthly,
    );

    final leftToPayCard = _buildLeftToPayCard(
      context,
      currency: currency,
      totalOutstanding: totalOutstanding,
      totalPaid: totalPaid,
      overallPayoffPercent: overallPayoffPercent,
    );

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          eachMonthCard,
          const SizedBox(height: CoveSpace.md),
          leftToPayCard,
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: eachMonthCard),
          const SizedBox(width: CoveSpace.md),
          Expanded(child: leftToPayCard),
        ],
      ),
    );
  }

  Widget _buildEachMonthCard(
    BuildContext context, {
    required CurrencyOption currency,
    required int effectiveCount,
    required double totalMonthlyOutflow,
    required double personAMonthly,
    required double personBMonthly,
    required double bothMonthly,
  }) {
    final cv = context.cv;
    final total = totalMonthlyOutflow > 0 ? totalMonthlyOutflow : 1.0;
    final aFlex = ((personAMonthly / total) * 1000).round().clamp(0, 1000);
    final bothFlex = ((bothMonthly / total) * 1000).round().clamp(0, 1000);
    final bFlex = ((personBMonthly / total) * 1000).round().clamp(0, 1000);
    final hasAny = aFlex + bothFlex + bFlex > 0;

    return Container(
      padding: const EdgeInsets.all(CoveSpace.md),
      decoration: CoveShape.decoration(
        CoveRadius.card,
        color: cv.surfaceCard,
        side: BorderSide(
          color: cv.lineHairline,
          width: _kHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoveSectionLabel.card(label: 'EACH MONTH'),
          const SizedBox(height: CoveSpace.sm),
          Text(
            '${currency.symbol}${formatCoveAmount(totalMonthlyOutflow)}',
            style: CoveType.cardFigure.copyWith(color: cv.textPrimary),
          ),
          const SizedBox(height: CoveSpace.sm),
          CoveShape.clip(
            CoveRadius.pill,
            SizedBox(
              height: _kBarHeight,
              child: hasAny
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (aFlex > 0)
                          Expanded(
                            flex: aFlex,
                            child: ColoredBox(color: cv.accentFill),
                          ),
                        if (bothFlex > 0) ...[
                          if (aFlex > 0) const SizedBox(width: CoveSpace.xs),
                          Expanded(
                            flex: bothFlex,
                            child: ColoredBox(color: cv.accentTint),
                          ),
                        ],
                        if (bFlex > 0) ...[
                          if (aFlex > 0 || bothFlex > 0)
                            const SizedBox(width: CoveSpace.xs),
                          Expanded(
                            flex: bFlex,
                            child: ColoredBox(color: cv.statusGood),
                          ),
                        ],
                      ],
                    )
                  : ColoredBox(color: cv.surfaceRow),
            ),
          ),
          const SizedBox(height: CoveSpace.xs),
          Text.rich(
            TextSpan(
              style: CoveType.rowSub.copyWith(color: cv.textTertiary),
              children: [
                TextSpan(
                  text: '$effectiveCount',
                  style: CoveType.rowSub.copyWith(color: cv.textPrimary),
                ),
                TextSpan(
                  text: ' ${effectiveCount == 1 ? 'EMI' : 'EMIs'} running',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftToPayCard(
    BuildContext context, {
    required CurrencyOption currency,
    required double totalOutstanding,
    required double totalPaid,
    required double overallPayoffPercent,
  }) {
    final cv = context.cv;
    final paidPct = (overallPayoffPercent * 100).round();

    return Container(
      padding: const EdgeInsets.all(CoveSpace.md),
      decoration: CoveShape.decoration(
        CoveRadius.card,
        color: cv.surfaceCard,
        side: BorderSide(
          color: cv.lineHairline,
          width: _kHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const CoveSectionLabel.card(label: 'LEFT TO PAY'),
          const SizedBox(height: CoveSpace.sm),
          Text(
            '${currency.symbol}${formatCoveAmount(totalOutstanding)}',
            style: CoveType.cardFigure.copyWith(color: cv.textPrimary),
          ),
          const SizedBox(height: CoveSpace.sm),
          DecoratedBox(
            decoration: CoveShape.decoration(
              CoveRadius.pill,
              color: cv.surfaceRow,
              side: BorderSide(color: cv.lineControl),
            ),
            child: CoveShape.clip(
              CoveRadius.pill,
              SizedBox(
                height: _kBarHeight,
                child: LinearProgressIndicator(
                  value: overallPayoffPercent,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(cv.accentFill),
                ),
              ),
            ),
          ),
          const SizedBox(height: CoveSpace.xs),
          Text.rich(
            TextSpan(
              style: CoveType.rowSub.copyWith(color: cv.textTertiary),
              children: [
                TextSpan(
                  text: '$paidPct%',
                  style: CoveType.rowSub.copyWith(color: cv.textPrimary),
                ),
                TextSpan(
                  text:
                      ' already paid (${currency.symbol}${formatCoveAmount(totalPaid)})',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaircaseGraph(
    BuildContext context, {
    required CurrencyOption currency,
    required double initialMonthly,
    required DateTime referenceDate,
    required List<_StaircaseStep> steps,
  }) {
    final cv = context.cv;
    final effectiveIdx = (_selectedStepIndex != null &&
            _selectedStepIndex! >= 0 &&
            _selectedStepIndex! < steps.length)
        ? _selectedStepIndex
        : null;
    final selectedStep = effectiveIdx != null ? steps[effectiveIdx] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _kStaircaseHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final maxMonths = steps.isNotEmpty ? steps.last.monthsFromNow : 1;

              return GestureDetector(
                key: const ValueKey('emi_staircase_graph'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  if (steps.isEmpty || width <= 0) return;
                  final tapX = details.localPosition.dx;
                  int closestIdx = 0;
                  double closestDist = double.infinity;
                  for (var i = 0; i < steps.length; i++) {
                    final stepX = (steps[i].monthsFromNow / maxMonths) * width;
                    final dist = (stepX - tapX).abs();
                    if (dist < closestDist) {
                      closestDist = dist;
                      closestIdx = i;
                    }
                  }
                  setState(() {
                    _selectedStepIndex =
                        _selectedStepIndex == closestIdx ? null : closestIdx;
                  });
                },
                child: CustomPaint(
                  size: Size(width, _kStaircaseHeight),
                  painter: _StaircaseGraphPainter(
                    steps: steps,
                    initialMonthly: initialMonthly,
                    referenceDate: referenceDate,
                    currencySymbol: currency.symbol,
                    selectedIndex: effectiveIdx,
                    strokeColor: cv.accentFill,
                    fillColor: cv.accentWash,
                    gridColor: cv.lineControl,
                    surfaceColor: cv.surfaceCanvas,
                    labelStyle: CoveType.rowSub.copyWith(
                      color: cv.textSecondary,
                    ),
                    axisStyle: CoveType.barLabel.copyWith(
                      color: cv.textTertiary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (selectedStep != null) ...[
          const SizedBox(height: CoveSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.md,
              vertical: CoveSpace.sm,
            ),
            decoration: CoveShape.decoration(
              CoveRadius.inline,
              color: cv.surfaceCard,
              side: BorderSide(
                color: cv.lineHairline,
                width: _kHairline,
              ),
            ),
            child: Text(
              selectedStep.remainingMonthly <= 0
                  ? '${DateFormat("MMM yyyy").format(selectedStep.date)}: ${selectedStep.closedAtStep.map((e) => e.name).join(", ")} closes — free of all EMIs.'
                  : '${DateFormat("MMM yyyy").format(selectedStep.date)}: ${selectedStep.closedAtStep.map((e) => e.name).join(", ")} closes → drops to ${currency.symbol}${formatCoveAmount(selectedStep.remainingMonthly)}/mo.',
              style: CoveType.rowSub.copyWith(color: cv.textSecondary),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSortModeRow(BuildContext context) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);

    final modes = <(EmiSortMode, String)>[
      (EmiSortMode.byWho, 'By who'),
      (EmiSortMode.endsFirst, 'Ends first'),
      (EmiSortMode.biggest, 'Biggest'),
    ];

    return Wrap(
      spacing: CoveSpace.sm,
      runSpacing: CoveSpace.sm,
      children: [
        for (final item in modes)
          Builder(
            builder: (context) {
              final isSelected = _sortMode == item.$1;
              final isScaled =
                  MediaQuery.textScalerOf(context).scale(1.0) > 1.0;
              return Semantics(
                button: true,
                selected: isSelected,
                label: item.$2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _sortMode = item.$1),
                  child: AnimatedContainer(
                    duration: duration,
                    curve: CoveMotion.easing,
                    height: isScaled ? null : _kSortPillHeight,
                    constraints: isScaled
                        ? const BoxConstraints(minHeight: _kSortPillHeight)
                        : null,
                    padding: EdgeInsets.symmetric(
                      horizontal: CoveSpace.md,
                      vertical: isScaled ? CoveSpace.xs : 0,
                    ),
                    decoration: CoveShape.decoration(
                      CoveRadius.pill,
                      color: isSelected ? cv.accentWash : Colors.transparent,
                      side: BorderSide(
                        color: isSelected ? cv.accentFill : cv.lineStrong,
                        width: _kHairline,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.$2,
                          style: CoveType.rowSub.copyWith(
                            color: isSelected
                                ? cv.textPrimary
                                : cv.textSecondary,
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

  Widget _buildLedgerSection(
    BuildContext context, {
    required List<LocalSubscription> allActiveEmis,
    required CurrencyOption currency,
    required String creatorId,
    required String? currentUserId,
    required String? partnerUserId,
    required String myName,
    required String partnerName,
  }) {
    if (_sortMode != EmiSortMode.byWho) {
      final sorted = List<LocalSubscription>.from(allActiveEmis);
      if (_sortMode == EmiSortMode.endsFirst) {
        sorted.sort(
          (a, b) =>
              _remainingInstallmentsOf(a).compareTo(_remainingInstallmentsOf(b)),
        );
      } else {
        sorted.sort((a, b) {
          final outA = _remainingInstallmentsOf(a) * a.amount;
          final outB = _remainingInstallmentsOf(b) * b.amount;
          return outB.compareTo(outA);
        });
      }

      return _buildEmiGroupCard(
        context,
        emis: sorted,
        currency: currency,
        isSplitGroup: false,
      );
    }

    // Group by who pays, preserving first-seen payer order
    final groupOrder = <String>[];
    final groupedEmis = <String, List<LocalSubscription>>{};
    final groupPerson = <String, CovePerson>{};

    for (final emi in allActiveEmis) {
      final groupLabel = _resolvePayerGroupName(
        emi,
        creatorId: creatorId,
        currentUserId: currentUserId,
        partnerUserId: partnerUserId,
        myName: myName,
        partnerName: partnerName,
      );
      if (!groupedEmis.containsKey(groupLabel)) {
        groupOrder.add(groupLabel);
        groupedEmis[groupLabel] = <LocalSubscription>[];
        groupPerson[groupLabel] = _resolvePayerPerson(
          emi,
          creatorId: creatorId,
          currentUserId: currentUserId,
          partnerUserId: partnerUserId,
        );
      }
      groupedEmis[groupLabel]!.add(emi);
    }

    // Sort items within each group by monthly amount descending
    for (final list in groupedEmis.values) {
      list.sort((a, b) => b.amount.compareTo(a.amount));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var g = 0; g < groupOrder.length; g++) ...[
          if (g > 0) const SizedBox(height: CoveSpace.lg),
          Builder(
            builder: (context) {
              final cv = context.cv;
              final groupName = groupOrder[g];
              final emis = groupedEmis[groupName]!;
              final person = groupPerson[groupName]!;
              final isSplitGroup = person == CovePerson.both;
              final groupMonthly = emis.fold<double>(
                0.0,
                (sum, e) => sum + e.amount,
              );
              final headerTitle = isSplitGroup
                  ? groupName
                  : '${groupName.toUpperCase()} · ${emis.length}';

              final isScaled =
                  MediaQuery.textScalerOf(context).scale(1.0) > 1.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isScaled)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: CoveSpace.sm,
                      runSpacing: CoveSpace.xs,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CoveAvatar.inline(
                              person: person,
                              nameOrInitial: isSplitGroup ? null : groupName,
                            ),
                            const SizedBox(width: CoveSpace.sm),
                            Flexible(
                              child: Text(
                                headerTitle,
                                style: CoveType.capsCard.copyWith(
                                  color: cv.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    '${currency.symbol}${formatCoveAmount(groupMonthly)}',
                                style: CoveType.rowTitle.copyWith(
                                  color: cv.accentText,
                                ),
                              ),
                              TextSpan(
                                text: ' /mo',
                                style: CoveType.rowSub.copyWith(
                                  color: cv.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        CoveAvatar.inline(
                          person: person,
                          nameOrInitial: isSplitGroup ? null : groupName,
                        ),
                        const SizedBox(width: CoveSpace.sm),
                        Expanded(
                          child: Text(
                            headerTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CoveType.capsCard.copyWith(
                              color: cv.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: CoveSpace.sm),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text:
                                    '${currency.symbol}${formatCoveAmount(groupMonthly)}',
                                style: CoveType.rowTitle.copyWith(
                                  color: cv.accentText,
                                ),
                              ),
                              TextSpan(
                                text: ' /mo',
                                style: CoveType.rowSub.copyWith(
                                  color: cv.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: CoveSpace.sm),
                  _buildEmiGroupCard(
                    context,
                    emis: emis,
                    currency: currency,
                    isSplitGroup: isSplitGroup,
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildEmiGroupCard(
    BuildContext context, {
    required List<LocalSubscription> emis,
    required CurrencyOption currency,
    required bool isSplitGroup,
  }) {
    final cv = context.cv;

    return Container(
      decoration: CoveShape.decoration(
        CoveRadius.card,
        color: cv.surfaceCard,
        side: BorderSide(
          color: cv.lineHairline,
          width: _kHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < emis.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoveSpace.md,
                ),
                child: ColoredBox(
                  color: cv.lineHairline,
                  child: const SizedBox(
                    width: double.infinity,
                    height: _kHairline,
                  ),
                ),
              ),
            _buildPunchedEmiVoucherRow(
              context,
              emi: emis[i],
              currency: currency,
              isSplitGroup: isSplitGroup,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPunchedEmiVoucherRow(
    BuildContext context, {
    required LocalSubscription emi,
    required CurrencyOption currency,
    required bool isSplitGroup,
  }) {
    final cv = context.cv;
    final isSelected = _selectedEmiIds.contains(emi.id);
    final paid = _paidInstallmentsOf(emi);
    final total = _totalInstallmentsOf(emi);
    final remaining = _remainingInstallmentsOf(emi);
    final endDate = _endDateOf(emi);
    final endStr = DateFormat("MMM ''yy").format(endDate);

    final metaParts = <String>[
      if (emi.financedThrough != null &&
          emi.financedThrough!.trim().isNotEmpty)
        emi.financedThrough!.trim(),
      if (isSplitGroup)
        'your half ${currency.symbol}${formatCoveAmount(emi.amount / 2)}',
      'ends $endStr',
    ];

    return Semantics(
      button: true,
      selected: isSelected,
      label: emi.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: () => _toggleEmiSelection(emi.id),
        onTap: () {
          if (_whatIfMode || _selectedEmiIds.isNotEmpty) {
            _toggleEmiSelection(emi.id);
          } else {
            CommitmentDetailSheet.show(context, emi);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(CoveSpace.md),
          decoration: isSelected
              ? CoveShape.decoration(
                  CoveRadius.inline,
                  color: cv.accentWash,
                  side: BorderSide(
                    color: cv.accentFill,
                    width: _kSelectedBorder,
                  ),
                )
              : null,
          child: Builder(
            builder: (context) {
              final isScaled =
                  MediaQuery.textScalerOf(context).scale(1.0) > 1.0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isScaled)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: CoveSpace.sm,
                      runSpacing: CoveSpace.xs,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              Icon(
                                Icons.check_circle_rounded,
                                size: _kCheckIconSize,
                                color: cv.accentFill,
                              ),
                              const SizedBox(width: CoveSpace.xs),
                            ],
                            Flexible(
                              child: Text(
                                emi.name,
                                style: CoveType.rowTitle.copyWith(
                                  color: cv.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${currency.symbol}${formatCoveAmount(emi.amount)}',
                          style: CoveType.rowTitle.copyWith(
                            color: cv.textPrimary,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        if (isSelected) ...[
                          Icon(
                            Icons.check_circle_rounded,
                            size: _kCheckIconSize,
                            color: cv.accentFill,
                          ),
                          const SizedBox(width: CoveSpace.xs),
                        ],
                        Expanded(
                          child: Text(
                            emi.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CoveType.rowTitle.copyWith(
                              color: cv.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: CoveSpace.sm),
                        Text(
                          '${currency.symbol}${formatCoveAmount(emi.amount)}',
                          style: CoveType.rowTitle.copyWith(
                            color: cv.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: CoveSpace.xs),
                  if (isScaled)
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: CoveSpace.sm,
                      runSpacing: CoveSpace.xs,
                      children: [
                        Text(
                          metaParts.join(' · '),
                          style: CoveType.rowSub.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                        Text(
                          '$remaining left ($paid/$total mo)',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            metaParts.join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CoveType.rowSub.copyWith(
                              color: cv.textTertiary,
                            ),
                          ),
                        ),
                        const SizedBox(width: CoveSpace.sm),
                        Text(
                          '$remaining left ($paid/$total mo)',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: CoveSpace.sm),
                  // Punched installment tick strip (one tick per installment)
                  SizedBox(
                    height: _kTickTrackHeight,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _PunchedInstallmentTicksPainter(
                        totalInstallments: total,
                        paidInstallments: paid,
                        punchedColor: cv.accentFill,
                        unpunchedColor: cv.lineControl,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedGroupCard(
    BuildContext context, {
    required List<LocalSubscription> completedEmis,
    required CurrencyOption currency,
  }) {
    final cv = context.cv;

    return Container(
      decoration: CoveShape.decoration(
        CoveRadius.card,
        color: cv.surfaceCard,
        side: BorderSide(
          color: cv.lineHairline,
          width: _kHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < completedEmis.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: CoveSpace.md),
                child: ColoredBox(
                  color: cv.lineHairline,
                  child: const SizedBox(
                    width: double.infinity,
                    height: _kHairline,
                  ),
                ),
              ),
            Builder(
              builder: (context) {
                final emi = completedEmis[i];
                final total = _totalInstallmentsOf(emi);
                final totalAmount = total * emi.amount;
                final isScaled =
                    MediaQuery.textScalerOf(context).scale(1.0) > 1.0;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => CommitmentDetailSheet.show(context, emi),
                  child: Padding(
                    padding: const EdgeInsets.all(CoveSpace.md),
                    child: isScaled
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: CoveSpace.xs,
                                ),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: _kCheckIconSize,
                                  color: cv.statusGood,
                                ),
                              ),
                              const SizedBox(width: CoveSpace.sm),
                              Expanded(
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  spacing: CoveSpace.sm,
                                  runSpacing: CoveSpace.xs,
                                  children: [
                                    Text(
                                      emi.name,
                                      style: CoveType.rowTitle.copyWith(
                                        color: cv.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      '${currency.symbol}${formatCoveAmount(totalAmount)} paid',
                                      style: CoveType.rowSub.copyWith(
                                        color: cv.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: _kCheckIconSize,
                                color: cv.statusGood,
                              ),
                              const SizedBox(width: CoveSpace.sm),
                              Expanded(
                                child: Text(
                                  emi.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: CoveType.rowTitle.copyWith(
                                    color: cv.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: CoveSpace.sm),
                              Text(
                                '${currency.symbol}${formatCoveAmount(totalAmount)} paid',
                                style: CoveType.rowSub.copyWith(
                                  color: cv.textTertiary,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: CoveEmptyState(
        icon: Icons.account_balance_outlined,
        title: 'No EMIs or loans active',
        description:
            'Track your home, vehicle, gadget or personal loans with automatic payoff tracking.',
        action: CovePillButton(
          label: 'Add Loan or EMI',
          icon: const Icon(Icons.add, size: 16),
          onPressed: () => AddFlow.show(
            context,
            kind: AddKind.commitment,
            presetEmi: true,
          ),
        ),
      ),
    );
  }
}

class _MiniStaircaseSilhouettePainter extends CustomPainter {
  final List<_StaircaseStep> steps;
  final double initialMonthly;
  final Color strokeColor;
  final Color fillColor;

  const _MiniStaircaseSilhouettePainter({
    required this.steps,
    required this.initialMonthly,
    required this.strokeColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty || initialMonthly <= 0) return;

    final maxMonths = math.max(1, steps.last.monthsFromNow);
    final maxWidth = size.width * 0.65;

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final path = Path()..moveTo(0, 0);
    double currentY = 0.0;

    if (steps.length == 1) {
      // Render a 4-step descending staircase silhouette when a single loan is active
      const fractions = <(double, double)>[
        (0.22, 0.30),
        (0.46, 0.56),
        (0.72, 0.78),
        (0.92, 1.0),
      ];
      for (final f in fractions) {
        final x = f.$1 * maxWidth;
        final nextY = size.height * f.$2;
        path.lineTo(x, currentY);
        path.lineTo(x, nextY);
        currentY = nextY;
      }
      path.lineTo(maxWidth, size.height);
    } else {
      for (final step in steps) {
        final x = (step.monthsFromNow / maxMonths) * maxWidth;
        final nextY = size.height *
            (1.0 - (step.remainingMonthly / initialMonthly).clamp(0.0, 1.0));
        path.lineTo(x, currentY);
        path.lineTo(x, nextY);
        currentY = nextY;
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(maxWidth, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniStaircaseSilhouettePainter oldDelegate) {
    return oldDelegate.steps != steps ||
        oldDelegate.initialMonthly != initialMonthly ||
        oldDelegate.strokeColor != strokeColor ||
        oldDelegate.fillColor != fillColor;
  }
}

class _StaircaseGraphPainter extends CustomPainter {
  final List<_StaircaseStep> steps;
  final double initialMonthly;
  final DateTime referenceDate;
  final String currencySymbol;
  final int? selectedIndex;
  final Color strokeColor;
  final Color fillColor;
  final Color gridColor;
  final Color surfaceColor;
  final TextStyle labelStyle;
  final TextStyle axisStyle;

  const _StaircaseGraphPainter({
    required this.steps,
    required this.initialMonthly,
    required this.referenceDate,
    required this.currencySymbol,
    required this.selectedIndex,
    required this.strokeColor,
    required this.fillColor,
    required this.gridColor,
    required this.surfaceColor,
    required this.labelStyle,
    required this.axisStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (steps.isEmpty || initialMonthly <= 0) return;

    const topPad = 8.0;
    const bottomPad = 24.0;
    const rightPad = 12.0;
    final chartHeight = math.max(1.0, size.height - topPad - bottomPad);
    final chartBottom = topPad + chartHeight;
    final plotWidth = math.max(1.0, size.width - rightPad);
    final maxMonths = math.max(1, steps.last.monthsFromNow);

    // Baseline rule
    final axisPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, chartBottom),
      Offset(size.width, chartBottom),
      axisPaint,
    );

    // Year markers along the horizontal axis
    final endYear = steps.last.date.year;
    for (var year = referenceDate.year + 1; year <= endYear; year++) {
      final monthsToJan =
          (year - referenceDate.year) * 12 - referenceDate.month + 1;
      if (monthsToJan > 0 && monthsToJan <= maxMonths) {
        final x = (monthsToJan / maxMonths) * plotWidth;
        for (double y = topPad; y < chartBottom; y += 6.0) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x, math.min(y + 3.0, chartBottom)),
            axisPaint,
          );
        }
        final tp = TextPainter(
          text: TextSpan(text: '$year', style: axisStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelX = (x - tp.width / 2).clamp(0.0, size.width - tp.width);
        tp.paint(canvas, Offset(labelX, chartBottom + 6.0));
      }
    }

    // Staircase path
    final stepPath = Path()..moveTo(0, topPad);
    double currentY = topPad;
    final nodeCenters = <Offset>[];

    for (final step in steps) {
      final x = (step.monthsFromNow / maxMonths) * plotWidth;
      final ratio = (step.remainingMonthly / initialMonthly).clamp(0.0, 1.0);
      final nextY = topPad + chartHeight * (1.0 - ratio);
      stepPath.lineTo(x, currentY);
      stepPath.lineTo(x, nextY);
      nodeCenters.add(Offset(x, nextY));
      currentY = nextY;
    }

    final fillPath = Path.from(stepPath)
      ..lineTo(plotWidth, chartBottom)
      ..lineTo(0, chartBottom)
      ..close();
    stepPath.lineTo(size.width, currentY);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(stepPath, strokePaint);

    // Draw nodes and annotations
    final nodeFillPaint = Paint()
      ..color = surfaceColor
      ..style = PaintingStyle.fill;
    final selectedNodeFillPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < steps.length; i++) {
      final center = nodeCenters[i];
      final isSelected = selectedIndex == i;
      canvas.drawCircle(
        center,
        isSelected ? 5.0 : 3.5,
        isSelected ? selectedNodeFillPaint : nodeFillPaint,
      );
      canvas.drawCircle(center, isSelected ? 5.0 : 3.5, strokePaint);
    }

    // Annotate final step ("free · MMM 'yy") and up to 2 intermediate steps
    final indicesToAnnotate = <int>{steps.length - 1};
    if (steps.length >= 2) {
      indicesToAnnotate.add(0);
    }
    if (steps.length >= 3) {
      indicesToAnnotate.add(steps.length ~/ 2);
    }
    if (selectedIndex != null) {
      indicesToAnnotate.add(selectedIndex!);
    }

    for (final idx in indicesToAnnotate) {
      final step = steps[idx];
      final center = nodeCenters[idx];
      final dateStr = DateFormat("MMM ''yy").format(step.date);
      final text = step.remainingMonthly <= 0
          ? 'free · $dateStr'
          : '$currencySymbol${formatCoveAmount(step.remainingMonthly)} · $dateStr';

      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);

      final dx = (center.dx - tp.width - 6.0).clamp(0.0, size.width - tp.width);
      final dy = (center.dy - tp.height - 4.0).clamp(topPad, chartBottom - tp.height - 2.0);
      tp.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _StaircaseGraphPainter oldDelegate) {
    return oldDelegate.steps != steps ||
        oldDelegate.initialMonthly != initialMonthly ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.strokeColor != strokeColor;
  }
}

class _PunchedInstallmentTicksPainter extends CustomPainter {
  final int totalInstallments;
  final int paidInstallments;
  final Color punchedColor;
  final Color unpunchedColor;

  const _PunchedInstallmentTicksPainter({
    required this.totalInstallments,
    required this.paidInstallments,
    required this.punchedColor,
    required this.unpunchedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = totalInstallments.clamp(1, 120);
    final gap = count > 36 ? 2.0 : 3.0;
    final totalGaps = (count - 1) * gap;
    final tickWidth = math.max(2.0, (size.width - totalGaps) / count);
    final tickHeight = size.height;
    final cornerRadius = tickHeight / 2;

    final punchedPaint = Paint()
      ..color = punchedColor
      ..style = PaintingStyle.fill;
    final unpunchedPaint = Paint()
      ..color = unpunchedColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final x = i * (tickWidth + gap);
      if (x > size.width) break;
      final path = smoothCornerPath(
        Rect.fromLTWH(
          x,
          0,
          math.min(tickWidth, size.width - x),
          tickHeight,
        ),
        radius: cornerRadius,
      );
      canvas.drawPath(
        path,
        i < paidInstallments ? punchedPaint : unpunchedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PunchedInstallmentTicksPainter oldDelegate) {
    return oldDelegate.totalInstallments != totalInstallments ||
        oldDelegate.paidInstallments != paidInstallments ||
        oldDelegate.punchedColor != punchedColor ||
        oldDelegate.unpunchedColor != unpunchedColor;
  }
}
