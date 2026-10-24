import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_round_button.dart';
import '../../core/widgets/cove_section_label.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear ?? DateTime.now().year;
  }

  /// Resolves a deterministic reference date when seeded `subscriptions` +
  /// `initialYear` are supplied (e.g. golden tests), otherwise `DateTime.now()`.
  DateTime _resolveReferenceNow(List<LocalSubscription> subs) {
    if (widget.initialYear != null &&
        widget.subscriptions != null &&
        subs.isNotEmpty) {
      for (final s in subs) {
        if (s.nextBillingDate.year == widget.initialYear) {
          return s.nextBillingDate;
        }
      }
      return subs.first.nextBillingDate;
    }
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final currency = ref.watch(currencyPreferenceProvider);

    final subsList = widget.subscriptions ??
        ref.watch(activeHomeSubscriptionsProvider).value ??
        [];

    final referenceNow = _resolveReferenceNow(subsList);
    final int markedMonth = referenceNow.month;

    // Profiles for attribution
    final currentUserId = ref.watch(authProvider).value?.id;
    final partnerProfile = ref.watch(partnerProfileProvider);
    final partnerUserId = partnerProfile.userId ?? 'partner_user';
    final partnerName = partnerProfile.displayName.isNotEmpty
        ? partnerProfile.displayName
        : 'Partner';
    final myProfile = ref.watch(userProfileProvider);
    final myName =
        myProfile.displayName.isNotEmpty ? myProfile.displayName : 'You';

    // Project commitments for the selected year
    final projections = CommitmentProjectionUtils.projectYear(
      subscriptions: subsList,
      year: _selectedYear,
    );

    // Compute monthly totals, month-over-month deltas (months 2..12), and annual sums
    final monthTotals = <int, double>{};
    final monthDeltas = <int, double>{};
    final monthMineAmounts = <int, double>{};
    final monthPartnerAmounts = <int, double>{};

    double annualGrandTotal = 0.0;
    double annualMineTotal = 0.0;
    double annualPartnerTotal = 0.0;
    double maxMonthlyTotal = 0.0;
    double minMonthlyTotal = double.infinity;

    for (int m = 1; m <= 12; m++) {
      final summary = projections[m]!;
      final total = summary.totalAmount.roundToDouble();
      monthTotals[m] = total;
      annualGrandTotal += total;
      if (total > maxMonthlyTotal) maxMonthlyTotal = total;
      if (total < minMonthlyTotal) minMonthlyTotal = total;

      if (m == 1) {
        monthDeltas[m] = 0.0;
      } else {
        monthDeltas[m] = total - (monthTotals[m - 1] ?? 0.0);
      }

      final pureMine = summary.allocationMine(currentUserId, partnerUserId);
      final purePartner =
          summary.allocationPartner(currentUserId, partnerUserId);
      final split = summary.allocationSplit();
      final mineShare = (pureMine + (split / 2.0)).roundToDouble();
      final partnerShare = (purePartner + (split / 2.0)).roundToDouble();

      monthMineAmounts[m] = mineShare;
      monthPartnerAmounts[m] = partnerShare;
      annualMineTotal += mineShare;
      annualPartnerTotal += partnerShare;
    }

    int peakMonthCount = 0;
    for (int m = 1; m <= 12; m++) {
      if ((monthTotals[m]! - maxMonthlyTotal).abs() < 0.01) {
        peakMonthCount++;
      }
    }

    final markedMonthShort =
        DateFormat('MMM').format(DateTime(_selectedYear, markedMonth, 1));
    final markedDelta = monthDeltas[markedMonth] ?? 0.0;
    final String chartReadout;
    if (markedMonth == 1 || markedDelta == 0.0) {
      chartReadout = '$markedMonthShort · —';
    } else if (markedDelta > 0) {
      chartReadout =
          '$markedMonthShort · +${currency.symbol}${formatCoveAmount(markedDelta)}';
    } else {
      chartReadout =
          '$markedMonthShort · −${currency.symbol}${formatCoveAmount(markedDelta.abs())}';
    }

    final bottomPadding =
        CoveSpace.barClearance + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SafeArea(
        bottom: false,
        child: CoveMaxWidth(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. CovePageHeader — back, year number as title, two chevron actions
                CovePageHeader(
                  leading: CoveRoundButton(
                    key: const ValueKey('helicopter_back_button'),
                    icon: Icons.arrow_back_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    tooltip: 'Back',
                    semanticLabel: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  title: '$_selectedYear',
                  actions: [
                    CoveRoundButton(
                      key: const ValueKey('helicopter_prev_year'),
                      icon: Icons.chevron_left_rounded,
                      variant: CoveRoundButtonVariant.ghost,
                      tooltip: 'Previous year',
                      semanticLabel: 'Previous year',
                      onPressed: () => setState(() => _selectedYear--),
                    ),
                    CoveRoundButton(
                      key: const ValueKey('helicopter_next_year'),
                      icon: Icons.chevron_right_rounded,
                      variant: CoveRoundButtonVariant.ghost,
                      tooltip: 'Next year',
                      semanticLabel: 'Next year',
                      onPressed: () => setState(() => _selectedYear++),
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
                      // 2. Change-on-the-month chart with the current month marked
                      CoveSectionLabel.page(
                        label: 'Change on the month',
                        readout: chartReadout,
                      ),
                      const SizedBox(height: CoveSpace.md),
                      _MonthChangeChart(
                        year: _selectedYear,
                        markedMonth: markedMonth,
                        monthTotals: monthTotals,
                        monthDeltas: monthDeltas,
                        currencySymbol: currency.symbol,
                      ),

                      const SizedBox(height: CoveSpace.lg),

                      // 3 & 4. Month ledger table + Footer row (year-over-year)
                      _MonthLedgerTable(
                        year: _selectedYear,
                        currentMonth: referenceNow.year == _selectedYear
                            ? referenceNow.month
                            : markedMonth,
                        projections: projections,
                        monthDeltas: monthDeltas,
                        monthMineAmounts: monthMineAmounts,
                        monthPartnerAmounts: monthPartnerAmounts,
                        annualMineTotal: annualMineTotal,
                        annualPartnerTotal: annualPartnerTotal,
                        annualGrandTotal: annualGrandTotal,
                        maxMonthlyTotal: maxMonthlyTotal,
                        hasPeakVariation: maxMonthlyTotal > minMonthlyTotal &&
                            maxMonthlyTotal > 0 &&
                            peakMonthCount == 1,
                        myName: myName,
                        partnerName: partnerName,
                        currencySymbol: currency.symbol,
                      ),
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
}

/// Diverging month-over-month change chart with the current month marked
/// (`design/screens/the-year.md`).
class _MonthChangeChart extends StatelessWidget {
  final int year;
  final int markedMonth;
  final Map<int, double> monthTotals;
  final Map<int, double> monthDeltas;
  final String currencySymbol;

  static const double _kHalfHeight = 52.0; // (literal)
  static const double _kMaxBarHeight = 34.0; // (literal)
  static const double _kMinBarHeight = 4.0; // (literal)
  static const double _kBarCornerRadius = 3.0; // (literal)
  static const double _kBorderWidth = 1.0; // (literal)
  static const double _kZeroDotSize = 4.0; // (literal)

  static const List<String> _kMonthLetters = [
    'J',
    'F',
    'M',
    'A',
    'M',
    'J',
    'J',
    'A',
    'S',
    'O',
    'N',
    'D',
  ];

  const _MonthChangeChart({
    required this.year,
    required this.markedMonth,
    required this.monthTotals,
    required this.monthDeltas,
    required this.currencySymbol,
  });

  String _formatCompactDelta(double delta) {
    final absVal = delta.abs();
    final sign = delta > 0 ? '+' : '−';
    if (absVal >= 1000) {
      final tenths = ((absVal / 1000.0) * 10).round();
      final whole = tenths ~/ 10;
      final frac = tenths % 10;
      if (frac == 0) {
        return '$sign${ whole }k';
      }
      return '$sign$whole.${frac}k';
    }
    return '$sign${formatCoveAmount(absVal.roundToDouble())}';
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    double maxAbsDelta = 0.0;
    for (int m = 2; m <= 12; m++) {
      final d = (monthDeltas[m] ?? 0.0).abs();
      if (d > maxAbsDelta) maxAbsDelta = d;
    }
    if (maxAbsDelta <= 0.0) maxAbsDelta = 1.0;

    final markedMonthShort =
        DateFormat('MMM').format(DateTime(year, markedMonth, 1));
    final markedMonthTotal = monthTotals[markedMonth] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Diverging bar area around central horizontal axis
        SizedBox(
          height: _kHalfHeight * 2 + _kBorderWidth,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Horizontal zero baseline
              ColoredBox(
                color: cv.lineStrong,
                child: const SizedBox(
                  width: double.infinity,
                  height: _kBorderWidth,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List.generate(12, (idx) {
                  final month = idx + 1;
                  final delta = month == 1 ? 0.0 : (monthDeltas[month] ?? 0.0);
                  final isMarked = month == markedMonth;
                  final fraction =
                      (delta.abs() / maxAbsDelta).clamp(0.0, 1.0);
                  final barHeight = delta == 0.0
                      ? 0.0
                      : (_kMinBarHeight +
                          fraction * (_kMaxBarHeight - _kMinBarHeight));

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2.0, // (literal)
                      ),
                      child: Column(
                        children: [
                          // Upper half (positive delta)
                          SizedBox(
                            height: _kHalfHeight,
                            child: delta > 0
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _formatCompactDelta(delta),
                                          maxLines: 1,
                                          style: CoveType.rowSub.copyWith(
                                            color: isMarked
                                                ? cv.accentText
                                                : cv.textTertiary,
                                            fontWeight: isMarked
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2.0), // (literal)
                                      Container(
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          color: cv.accentFill,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(
                                              _kBarCornerRadius,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Center axis line slot (dot if delta == 0)
                          SizedBox(
                            height: _kBorderWidth,
                            child: delta == 0.0
                                ? Center(
                                    child: Container(
                                      width: _kZeroDotSize,
                                      height: _kZeroDotSize,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isMarked
                                            ? cv.accentFill
                                            : cv.textTertiary,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),

                          // Lower half (negative delta)
                          SizedBox(
                            height: _kHalfHeight,
                            child: delta < 0
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          border: Border.all(
                                            color: cv.accentFill,
                                            width: _kBorderWidth,
                                          ),
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            bottom: Radius.circular(
                                              _kBarCornerRadius,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2.0), // (literal)
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _formatCompactDelta(delta),
                                          maxLines: 1,
                                          style: CoveType.rowSub.copyWith(
                                            color: isMarked
                                                ? cv.accentText
                                                : cv.textTertiary,
                                            fontWeight: isMarked
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: CoveSpace.sm),

        // Current month callout pill
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.md,
              vertical: CoveSpace.xs,
            ),
            decoration: BoxDecoration(
              color: cv.surfaceCard,
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.pill),
              ),
              border: Border.all(
                color: cv.accentFill,
                width: _kBorderWidth,
              ),
            ),
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                children: [
                  TextSpan(text: '$markedMonthShort · '),
                  TextSpan(
                    text:
                        '$currencySymbol${formatCoveAmount(markedMonthTotal)}',
                    style: CoveType.rowTitle.copyWith(
                      color: cv.accentTint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: CoveSpace.sm),

        // Month initials axis (J F M A M J J A S O N D)
        Row(
          children: List.generate(12, (idx) {
            final month = idx + 1;
            final isMarked = month == markedMonth;
            return Expanded(
              child: Center(
                child: Text(
                  _kMonthLetters[idx],
                  style: CoveType.capsCard.copyWith(
                    color: isMarked ? cv.accentText : cv.textTertiary,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Screen-local month ledger table (`design/screens/the-year.md`):
/// - Columns: `MONTH` · `+/-` · `<Person A>` · `<Person B>` · `TOTAL`
/// - Rows carry **no fill, no radius and no side stroke**.
/// - Current month is marked ONLY by a gold month name (`accent.text`) and
///   warmed hairlines above and below.
/// - Footer `YEAR` row renders prior-year comparison as `—` in `text.tertiary`.
class _MonthLedgerTable extends StatelessWidget {
  final int year;
  final int currentMonth;
  final Map<int, MonthCommitmentSummary> projections;
  final Map<int, double> monthDeltas;
  final Map<int, double> monthMineAmounts;
  final Map<int, double> monthPartnerAmounts;
  final double annualMineTotal;
  final double annualPartnerTotal;
  final double annualGrandTotal;
  final double maxMonthlyTotal;
  final bool hasPeakVariation;
  final String myName;
  final String partnerName;
  final String currencySymbol;

  static const double _kBorderWidth = 1.0; // (literal)
  static const double _kWarmedHairlineAlpha = 0.45; // (literal)
  static const double _kMonthColWidth = 56.0; // (literal)
  static const int _kDeltaFlex = 22;
  static const int _kPersonFlex = 23;
  static const int _kTotalFlex = 32;

  const _MonthLedgerTable({
    required this.year,
    required this.currentMonth,
    required this.projections,
    required this.monthDeltas,
    required this.monthMineAmounts,
    required this.monthPartnerAmounts,
    required this.annualMineTotal,
    required this.annualPartnerTotal,
    required this.annualGrandTotal,
    required this.maxMonthlyTotal,
    required this.hasPeakVariation,
    required this.myName,
    required this.partnerName,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final warmedHairline =
        cv.accentFill.withValues(alpha: _kWarmedHairlineAlpha);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table column header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: CoveSpace.sm),
          child: Row(
            children: [
              SizedBox(
                width: _kMonthColWidth,
                child: Text(
                  'MONTH',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoveType.capsCard.copyWith(color: cv.textTertiary),
                ),
              ),
              Expanded(
                flex: _kDeltaFlex,
                child: Text(
                  '+/-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoveType.capsCard.copyWith(color: cv.textTertiary),
                ),
              ),
              Expanded(
                flex: _kPersonFlex,
                child: Text(
                  myName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: CoveType.capsCard.copyWith(color: cv.textTertiary),
                ),
              ),
              Expanded(
                flex: _kPersonFlex,
                child: Text(
                  partnerName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: CoveType.capsCard.copyWith(color: cv.textTertiary),
                ),
              ),
              Expanded(
                flex: _kTotalFlex,
                child: Text(
                  'TOTAL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: CoveType.capsCard.copyWith(color: cv.textTertiary),
                ),
              ),
            ],
          ),
        ),

        // 12 Month rows (no fill, no radius, no side stroke; warmed hairlines around currentMonth)
        for (int month = 1; month <= 12; month++) ...[
          ColoredBox(
            color: (month == currentMonth || month - 1 == currentMonth)
                ? warmedHairline
                : cv.lineHairline,
            child: const SizedBox(
              width: double.infinity,
              height: _kBorderWidth,
            ),
          ),
          _buildMonthRow(
            context,
            cv: cv,
            month: month,
            isCurrentMonth: month == currentMonth,
          ),
        ],

        // Bottom hairline before YEAR footer row (warmed if Dec is currentMonth)
        ColoredBox(
          color: currentMonth == 12 ? warmedHairline : cv.lineHairline,
          child: const SizedBox(
            width: double.infinity,
            height: _kBorderWidth,
          ),
        ),

        // Footer row: year-over-year (prior-year comparison renders as — in text.tertiary)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: CoveSpace.md),
          child: Row(
            children: [
              SizedBox(
                width: _kMonthColWidth,
                child: Text(
                  'YEAR',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoveType.capsCard.copyWith(color: cv.textTertiary),
                ),
              ),
              Expanded(
                flex: _kDeltaFlex,
                child: Text(
                  '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                ),
              ),
              Expanded(
                flex: _kPersonFlex,
                child: Text(
                  annualMineTotal > 0
                      ? '$currencySymbol${formatCoveAmount(annualMineTotal)}'
                      : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: CoveType.rowSub.copyWith(
                    color: annualMineTotal > 0
                        ? cv.textPrimary
                        : cv.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: _kPersonFlex,
                child: Text(
                  annualPartnerTotal > 0
                      ? '$currencySymbol${formatCoveAmount(annualPartnerTotal)}'
                      : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: CoveType.rowSub.copyWith(
                    color: annualPartnerTotal > 0
                        ? cv.textPrimary
                        : cv.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                flex: _kTotalFlex,
                child: Text(
                  annualGrandTotal > 0
                      ? '$currencySymbol${formatCoveAmount(annualGrandTotal)}'
                      : '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: CoveType.rowTitle.copyWith(
                    color: annualGrandTotal > 0
                        ? cv.accentTint
                        : cv.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthRow(
    BuildContext context, {
    required CoveTokens cv,
    required int month,
    required bool isCurrentMonth,
  }) {
    final summary = projections[month]!;
    final monthDate = DateTime(year, month, 1);
    final monthName = DateFormat('MMM').format(monthDate);
    final delta = month == 1 ? 0.0 : (monthDeltas[month] ?? 0.0);
    final mineAmount = monthMineAmounts[month] ?? 0.0;
    final partnerAmount = monthPartnerAmounts[month] ?? 0.0;
    final totalAmount = summary.totalAmount.roundToDouble();
    final isPeak = hasPeakVariation &&
        totalAmount > 0 &&
        (totalAmount - maxMonthlyTotal).abs() < 0.01;

    final String deltaText;
    final Color deltaColor;
    if (month == 1 || delta == 0.0) {
      deltaText = '—';
      deltaColor = cv.textTertiary;
    } else if (delta > 0) {
      deltaText = '+${formatCoveAmount(delta)}';
      deltaColor = cv.moneyMore;
    } else {
      deltaText = '−${formatCoveAmount(delta.abs())}';
      deltaColor = cv.moneyLess;
    }

    final personTextColor = isCurrentMonth ? cv.textPrimary : cv.textSecondary;

    return Semantics(
      button: true,
      label:
          '$monthName $year, total $currencySymbol${formatCoveAmount(totalAmount)}',
      child: GestureDetector(
        key: ValueKey('helicopter_month_row_$month'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          MonthCommitmentsSheet.show(
            context,
            summary: summary,
          );
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CoveSize.row),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: CoveSpace.sm),
            child: Row(
              children: [
                // 1. Month name (gold when current month)
                SizedBox(
                  width: _kMonthColWidth,
                  child: Text(
                    monthName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoveType.rowTitle.copyWith(
                      color: isCurrentMonth ? cv.accentText : cv.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // 2. ± delta in money.more / money.less with sign
                Expanded(
                  flex: _kDeltaFlex,
                  child: Text(
                    deltaText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoveType.rowSub.copyWith(
                      color: deltaColor,
                      fontWeight:
                          delta == 0.0 ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                ),

                // 3. Person A share
                Expanded(
                  flex: _kPersonFlex,
                  child: Text(
                    mineAmount > 0
                        ? '$currencySymbol${formatCoveAmount(mineAmount)}'
                        : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: CoveType.rowSub.copyWith(
                      color: mineAmount > 0 ? personTextColor : cv.textTertiary,
                    ),
                  ),
                ),

                // 4. Person B share
                Expanded(
                  flex: _kPersonFlex,
                  child: Text(
                    partnerAmount > 0
                        ? '$currencySymbol${formatCoveAmount(partnerAmount)}'
                        : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: CoveType.rowSub.copyWith(
                      color:
                          partnerAmount > 0 ? personTextColor : cv.textTertiary,
                    ),
                  ),
                ),

                // 5. Total + optional peak ▲ + trailing chevron
                Expanded(
                  flex: _kTotalFlex,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          totalAmount > 0
                              ? '$currencySymbol${formatCoveAmount(totalAmount)}'
                              : '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: CoveType.rowTitle.copyWith(
                            color: totalAmount > 0
                                ? cv.accentTint
                                : cv.textTertiary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isPeak) ...[
                        const SizedBox(width: 2.0), // (literal)
                        Text(
                          '▲',
                          style: CoveType.capsCard.copyWith(
                            color: cv.accentText,
                          ),
                        ),
                      ],
                      const SizedBox(width: 2.0), // (literal)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: math.min(CoveSpace.md, 12.0),
                        color: cv.textTertiary,
                      ),
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
}
