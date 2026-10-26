import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  static const double _kCompactThreeCellThreshold = 240.0; // (literal) 3-cell width threshold
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

        return DefaultTextStyle.merge(
          style: const TextStyle(decoration: TextDecoration.none),
          child: Container(
            padding: const EdgeInsets.all(CoveSpace.gutter),
            decoration: BoxDecoration(
              color: cv.surfaceCard.withValues(alpha: _kCardFillOpacity),
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.hero),
              ),
              border: Border.all(
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
                    child: _buildLeftColumn(cv),
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
                      child: _buildRightColumn(cv),
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

  Widget _buildLeftColumn(CoveTokens cv) {
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
            style: CoveType.capsCard.copyWith(color: cv.textTertiary),
          ),
          const SizedBox(height: CoveSpace.xs),
          Text(
            'No money has moved this month',
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
              style: CoveType.capsCard.copyWith(color: cv.textTertiary),
            ),
            const SizedBox(height: CoveSpace.xs),
            Text(
              '${currency.symbol}${formatCoveAmount(sharedTotal)}',
              style: CoveType.slipFigure.copyWith(color: cv.accentTint),
            ),
            if (expenses.hasPrevComparison) ...[
              const SizedBox(height: CoveSpace.xs),
              Text(
                '$deltaFormatted $directionWord ${expenses.prevMonthName}\n'
                'by this point · $daysLeftLabel',
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
            ],
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.pill),
              ),
              child: SizedBox(
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
        ),
      ],
    );
  }

  Widget _buildRightColumn(CoveTokens cv) {
    final next = commitments.nextSharedCommitment;
    final whenLabel = commitments.nextSharedCommitmentWhen;
    final currency = expenses.currency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'RENEWS',
          style: CoveType.capsCard.copyWith(color: cv.textTertiary),
        ),
        const SizedBox(height: CoveSpace.xs),
        if (next == null)
          Text(
            'Nothing renews yet',
            maxLines: 1,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          )
        else ...[
          Text(
            next.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
          ),
          if (whenLabel != null)
            Text(
              whenLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CoveType.rowSub.copyWith(color: cv.textTertiary),
            ),
          const SizedBox(height: CoveSpace.sm),
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
