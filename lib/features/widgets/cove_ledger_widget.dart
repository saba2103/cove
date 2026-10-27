import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../sync/db/app_database.dart';
import '../expenses/expense_controller.dart';
import '../subscriptions/subscription_controller.dart';

/// Home-screen Ledger widget (4×2, read-only) per `design/specs/18-widgets.md` §3
/// and `design/screens/widgets/led-{dark,light}.png`.
///
/// Consumes [expensesStandingSummaryProvider] and [commitmentsSummaryProvider]
/// directly so the figures are never computed a second time.
class CoveLedgerWidget extends ConsumerWidget {
  final VoidCallback? onTapExpenses;
  final ValueChanged<LocalSubscription?>? onTapCommitment;

  const CoveLedgerWidget({
    super.key,
    this.onTapExpenses,
    this.onTapCommitment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesStandingSummaryProvider);
    final commitments = ref.watch(commitmentsSummaryProvider);

    return CoveLedgerCard(
      expenses: expenses,
      commitments: commitments,
      onTapExpenses: onTapExpenses,
      onTapCommitment: onTapCommitment,
    );
  }
}

/// Pure presentation card for The Ledger (`design/specs/18-widgets.md` §3).
///
/// Follows the ambient [Theme] (system dark / light mode on the home screen).
/// At 3-cell width (`< 240dp`), hides the right column so content reflows
/// without scaling text down below the type scale.
class CoveLedgerCard extends StatelessWidget {
  static const double _kCardFillOpacity = 0.88; // (literal) ~88% card fill over wallpaper
  static const double _kHairlineWidth = 1.0; // (literal) 1dp border and divider
  static const double _kSplitBarHeight = 6.0; // (literal) 6dp person split bar
  static const double _kCompactThreeCellThreshold = 260.0; // (literal) 3-cell width threshold (Fold Cover 3-cell is 252dp)
  static const double _kShowComparisonHeightThreshold = 160.0; // (literal) height needed for 2-line month comparison
  static const double _kShortHeightThreshold = 130.0; // (literal) height below which vertical padding tightens
  static const double _kShowSplitLabelsHeightThreshold = 104.0; // (literal) height needed for You/Partner labels under split bar
  static const double _kCompactVerticalPad = 10.0; // (literal) 10dp vertical padding on short resize
  static const int _kLeftColumnFlex = 62;
  static const int _kRightColumnFlex = 38;

  final ExpensesStandingSummary expenses;
  final CommitmentsSummary commitments;
  final VoidCallback? onTapExpenses;
  final ValueChanged<LocalSubscription?>? onTapCommitment;

  const CoveLedgerCard({
    super.key,
    required this.expenses,
    required this.commitments,
    this.onTapExpenses,
    this.onTapCommitment,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return LayoutBuilder(
      builder: (context, constraints) {
        final hideRightColumn = constraints.maxWidth.isFinite &&
            constraints.maxWidth > 0 &&
            constraints.maxWidth < _kCompactThreeCellThreshold;
        final hasFiniteHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0;
        final showComparison = !hasFiniteHeight ||
            constraints.maxHeight >= _kShowComparisonHeightThreshold;
        final isShortHeight =
            hasFiniteHeight && constraints.maxHeight < _kShortHeightThreshold;
        final showSplitLabels = !hasFiniteHeight ||
            constraints.maxHeight >= _kShowSplitLabelsHeightThreshold;

        return DefaultTextStyle.merge(
          style: const TextStyle(decoration: TextDecoration.none),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: CoveSpace.gutter,
              vertical: isShortHeight ? _kCompactVerticalPad : CoveSpace.gutter,
            ),
            decoration: CoveShape.decoration(
              CoveRadius.hero,
              color: cv.surfaceCard.withValues(alpha: _kCardFillOpacity),
              side: BorderSide(
                color: cv.lineStrong,
                width: _kHairlineWidth,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: _kLeftColumnFlex,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTapExpenses,
                    child: _buildLeftColumn(
                      cv,
                      showComparison: showComparison,
                      showSplitLabels: showSplitLabels,
                    ),
                  ),
                ),
                if (!hideRightColumn) ...[
                  const SizedBox(width: CoveSpace.md),
                  Container(
                    width: _kHairlineWidth,
                    color: cv.lineStrong,
                  ),
                  const SizedBox(width: CoveSpace.md),
                  Expanded(
                    flex: _kRightColumnFlex,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTapCommitment != null
                          ? () => onTapCommitment!(
                                commitments.nextSharedCommitment,
                              )
                          : null,
                      child: _buildRightColumn(
                        cv,
                        isShortHeight: isShortHeight,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftColumn(
    CoveTokens cv, {
    required bool showComparison,
    required bool showSplitLabels,
  }) {
    final currency = expenses.currency;
    final sharedTotal = expenses.sharedMonthlyTotal;
    final hasSpend = sharedTotal > 0;

    if (!hasSpend) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'SHARED THIS MONTH',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CoveType.capsCard.copyWith(color: cv.textTertiary),
          ),
          const SizedBox(height: CoveSpace.xs),
          Text(
            'No money has moved this month',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: CoveType.rowSub.copyWith(color: cv.textSecondary),
          ),
        ],
      );
    }

    final myPaid = expenses.paidByMeSharedTotal;
    final partnerPaid = expenses.paidByPartnerSharedTotal;
    final myFlex = ((myPaid / sharedTotal) * 1000).round().clamp(0, 1000);
    final partnerFlex =
        ((partnerPaid / sharedTotal) * 1000).round().clamp(0, 1000);

    final directionWord = expenses.isSpendingLess ? 'ahead of' : 'behind';
    final deltaFormatted =
        '${currency.symbol}${formatCoveAmount(expenses.prevDelta.abs())}';
    final daysLeftLabel =
        '${expenses.daysRemaining} day${expenses.daysRemaining == 1 ? "" : "s"} left';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SHARED THIS MONTH',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CoveType.capsCard.copyWith(color: cv.textTertiary),
            ),
            const SizedBox(height: CoveSpace.xs),
            Text(
              '${currency.symbol}${formatCoveAmount(sharedTotal)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CoveType.slipFigure.copyWith(color: cv.accentTint),
            ),
            if (expenses.hasPrevComparison && showComparison) ...[
              const SizedBox(height: CoveSpace.xs),
              Text(
                '$deltaFormatted $directionWord ${expenses.prevMonthName}\n'
                'by this point · $daysLeftLabel',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
            ],
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            CoveShape.clip(
              CoveRadius.pill,
              SizedBox(
                height: _kSplitBarHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (myFlex > 0)
                      Expanded(
                        flex: myFlex,
                        child: DecoratedBox(
                          decoration: BoxDecoration(gradient: cv.personA),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    if (partnerFlex > 0)
                      Expanded(
                        flex: partnerFlex,
                        child: DecoratedBox(
                          decoration: BoxDecoration(gradient: cv.personB),
                          child: const SizedBox.expand(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (showSplitLabels) ...[
              const SizedBox(height: CoveSpace.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'You ${currency.symbol}${formatCoveAmount(myPaid)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                    ),
                  ),
                  const SizedBox(width: CoveSpace.xs),
                  Flexible(
                    child: Text(
                      '${expenses.partnerName} ${currency.symbol}${formatCoveAmount(partnerPaid)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildRightColumn(
    CoveTokens cv, {
    required bool isShortHeight,
  }) {
    final next = commitments.nextSharedCommitment;
    final whenLabel = commitments.nextSharedCommitmentWhen;
    final currency = expenses.currency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'RENEWS',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: CoveType.capsCard.copyWith(color: cv.textTertiary),
        ),
        const SizedBox(height: CoveSpace.xs),
        if (next == null)
          Text(
            'Nothing renews yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          )
        else ...[
          Text(
            next.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
          ),
          if (whenLabel != null && !isShortHeight)
            Text(
              whenLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CoveType.rowSub.copyWith(color: cv.textTertiary),
            ),
          SizedBox(height: isShortHeight ? CoveSpace.xs : CoveSpace.sm),
          Text(
            '${currency.symbol}${formatCoveAmount(next.amount)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CoveType.slipTitle.copyWith(color: cv.accentTint),
          ),
        ],
      ],
    );
  }
}
