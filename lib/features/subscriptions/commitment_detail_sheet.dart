import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_checkbox.dart';
import '../../core/widgets/cove_detail_sheet.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../core/widgets/slips/cove_slip.dart';
import '../../core/widgets/slips/cove_voucher.dart';
import '../../sync/db/app_database.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import 'commitment_models.dart';
import 'subscription_controller.dart';
import 'subscription_form_sheet.dart';

class CommitmentDetailSheet extends ConsumerStatefulWidget {
  final LocalSubscription subscription;

  static const double _kDialogBorderWidth =
      1.0; // (literal) 1dp dialog hairline border
  static const double _kDialogIconSize =
      20.0; // (literal) 20dp dialog title icon

  const CommitmentDetailSheet({
    super.key,
    required this.subscription,
  });

  static Future<void> show(
    BuildContext context,
    LocalSubscription subscription,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommitmentDetailSheet(subscription: subscription),
    );
  }

  @override
  ConsumerState<CommitmentDetailSheet> createState() =>
      _CommitmentDetailSheetState();
}

class _CommitmentDetailSheetState extends ConsumerState<CommitmentDetailSheet> {
  bool _markedPaidInSession = false;
  int? _sessionPaidInstallments;
  DateTime? _sessionNextBillingDate;

  LocalSubscription get _sub => widget.subscription;

  String _formatContextCadence(String cycle) {
    final lower = cycle.toLowerCase().trim();
    if (lower == 'monthly' || lower == 'month') return 'EVERY MONTH';
    if (lower == 'annual' || lower == 'yearly' || lower == 'year') {
      return 'EVERY YEAR';
    }
    if (lower == 'quarterly') return 'EVERY QUARTER';
    final months = getBillingCycleMonths(cycle);
    if (months == 1) return 'EVERY MONTH';
    if (months == 12) return 'EVERY YEAR';
    if (months == 3) return 'EVERY QUARTER';
    return 'EVERY $months MONTHS';
  }

  String _formatCadencePhrase(String cycle) {
    final lower = cycle.toLowerCase().trim();
    if (lower == 'monthly' || lower == 'month') return 'a month';
    if (lower == 'annual' || lower == 'yearly' || lower == 'year') {
      return 'a year';
    }
    if (lower == 'quarterly') return 'a quarter';
    final months = getBillingCycleMonths(cycle);
    if (months == 1) return 'a month';
    if (months == 12) return 'a year';
    if (months == 3) return 'a quarter';
    return 'every $months months';
  }

  String _resolvePaidByLabel({
    required String? currentUserId,
    required String? partnerUserId,
    required String myDisplayName,
    required String partnerDisplayName,
  }) {
    final pDisplayName =
        partnerDisplayName.isNotEmpty ? partnerDisplayName : 'Partner';
    final rawPaidBy = _sub.paidBy?.trim();
    final pBy = rawPaidBy?.toLowerCase();

    if (pBy == 'split' ||
        pBy == 'split_50_50' ||
        pBy == 'split (50/50)' ||
        pBy == '50/50') {
      return 'Split (50/50)';
    }
    if (pBy != null && pBy.isNotEmpty) {
      if (pBy == 'me' ||
          pBy == 'you' ||
          pBy == 'user_alex' ||
          (currentUserId != null &&
              currentUserId.isNotEmpty &&
              pBy == currentUserId) ||
          (myDisplayName.isNotEmpty &&
              myDisplayName != 'you' &&
              pBy == myDisplayName)) {
        return 'You';
      }
      if (pBy == 'partner' ||
          pBy == 'partner_user' ||
          pBy == 'partner-user-sarah' ||
          (partnerUserId != null &&
              partnerUserId.isNotEmpty &&
              pBy == partnerUserId) ||
          (pDisplayName.isNotEmpty && pBy == pDisplayName.toLowerCase())) {
        return pDisplayName;
      }
      if (pBy.contains('-') || (pBy.length >= 16 && !pBy.contains(' '))) {
        if (currentUserId != null && pBy == currentUserId) {
          return 'You';
        }
        return pDisplayName;
      }
      return rawPaidBy!;
    }

    final creator = _sub.createdBy?.trim().toLowerCase();
    if (creator != null && creator.isNotEmpty) {
      if (currentUserId != null && creator == currentUserId) {
        return 'You';
      }
      if (partnerUserId != null && creator == partnerUserId) {
        return pDisplayName;
      }
      if (creator.contains('-') || creator.length >= 16) {
        return pDisplayName;
      }
    }
    return 'You';
  }

  Future<void> _handleEdit(BuildContext context) async {
    Navigator.of(context).pop();
    await SubscriptionFormSheet.show(context, existing: _sub);
  }

  Future<void> _handleTogglePause(BuildContext context, WidgetRef ref) async {
    final isPaused = !_sub.isActive;
    if (isPaused) {
      await ref.read(subscriptionControllerProvider).reactivateSubscription(
            _sub.id,
            isPrivate: _sub.isPrivate,
          );
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Resumed "${_sub.name}"',
          onUndo: () =>
              ref.read(subscriptionControllerProvider).cancelSubscription(
                    _sub.id,
                    isPrivate: _sub.isPrivate,
                  ),
        );
      }
    } else {
      await ref.read(subscriptionControllerProvider).cancelSubscription(
            _sub.id,
            isPrivate: _sub.isPrivate,
          );
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Paused "${_sub.name}"',
          onUndo: () =>
              ref.read(subscriptionControllerProvider).reactivateSubscription(
                    _sub.id,
                    isPrivate: _sub.isPrivate,
                  ),
        );
      }
    }
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final cv = context.cv;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.inline),
          ),
          side: BorderSide(
            color: cv.lineHairline,
            width: CommitmentDetailSheet._kDialogBorderWidth,
          ),
        ),
        title: Text(
          'Delete ${_sub.isEmi ? 'EMI' : 'Subscription'}?',
          style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove "${_sub.name}"? This action cannot be undone.',
          style: CoveType.readout.copyWith(color: cv.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: CoveType.rowTitle.copyWith(color: cv.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: CoveType.rowTitle.copyWith(color: cv.statusAlertText),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(subscriptionControllerProvider).deleteSubscription(
            _sub.id,
            isPrivate: _sub.isPrivate,
          );
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Deleted "${_sub.name}"',
          onUndo: () =>
              ref.read(subscriptionControllerProvider).createSubscription(
                    name: _sub.name,
                    amount: _sub.amount,
                    currency: _sub.currency,
                    billingCycle: _sub.billingCycle,
                    nextBillingDate: _sub.nextBillingDate,
                    category: _sub.category,
                    isPrivate: _sub.isPrivate,
                    endDate: _sub.endDate,
                    paidBy: _sub.paidBy,
                    financedThrough: _sub.financedThrough,
                    totalInstallments: _sub.totalInstallments,
                    paidInstallments: _sub.paidInstallments,
                  ),
        );
      }
    }
  }

  Future<void> _handleRenewOrPay(BuildContext context, WidgetRef ref) async {
    final cv = context.cv;
    final currency = ref.read(currencyPreferenceProvider);
    final isEmi = _sub.isEmi;
    final cycleMonths = getBillingCycleMonths(_sub.billingCycle);
    final currentNext = _sessionNextBillingDate ?? _sub.nextBillingDate;
    final advancedNext = DateTime(
      currentNext.year,
      currentNext.month + cycleMonths,
      currentNext.day,
    );

    final emiProg = _sub.emiProgress;
    final total = _sub.totalInstallments ?? emiProg?.totalInstallments ?? 12;
    final currentPaid = _sessionPaidInstallments ??
        _sub.paidInstallments ??
        emiProg?.paidInstallments ??
        0;
    final nextPaid = isEmi ? (currentPaid + 1).clamp(0, total) : null;
    final willComplete = isEmi && nextPaid != null && nextPaid >= total;

    bool logExpense = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cv.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.inline),
              ),
              side: BorderSide(
                color: cv.lineHairline,
                width: CommitmentDetailSheet._kDialogBorderWidth,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  isEmi ? Icons.payments_outlined : Icons.autorenew_rounded,
                  color: cv.accentTint,
                  size: CommitmentDetailSheet._kDialogIconSize,
                ),
                const SizedBox(width: CoveSpace.sm),
                Expanded(
                  child: Text(
                    isEmi ? 'Record Installment Payment' : 'Record Renewal',
                    style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEmi
                      ? 'Mark installment #$nextPaid of $total paid for "${_sub.name}"?'
                      : 'Mark "${_sub.name}" as renewed?',
                  style: CoveType.readout.copyWith(color: cv.textPrimary),
                ),
                const SizedBox(height: CoveSpace.md),
                Container(
                  padding: const EdgeInsets.all(CoveSpace.md),
                  decoration: BoxDecoration(
                    color: cv.surfaceRow,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(CoveRadius.card),
                    ),
                    border: Border.all(
                      color: cv.lineHairline,
                      width: CommitmentDetailSheet._kDialogBorderWidth,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textSecondary,
                            ),
                          ),
                          Text(
                            '${currency.symbol}${formatCoveAmount(_sub.amount)}',
                            style: CoveType.rowTitle.copyWith(
                              color: cv.accentTint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CoveSpace.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Next Due Date',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textSecondary,
                            ),
                          ),
                          Text(
                            willComplete
                                ? 'Final installment'
                                : DateFormat('MMM d, y').format(advancedNext),
                            style: CoveType.rowTitle.copyWith(
                              color: cv.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (isEmi) ...[
                        const SizedBox(height: CoveSpace.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: CoveType.rowSub.copyWith(
                                color: cv.textSecondary,
                              ),
                            ),
                            Text(
                              willComplete
                                  ? '$total/$total (Complete!)'
                                  : '$nextPaid/$total paid',
                              style: CoveType.rowTitle.copyWith(
                                color: willComplete
                                    ? cv.accentTint
                                    : cv.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: CoveSpace.md),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setDialogState(() => logExpense = !logExpense),
                  child: Row(
                    children: [
                      CoveCheckbox(
                        value: logExpense,
                        onChanged: (val) =>
                            setDialogState(() => logExpense = val),
                      ),
                      const SizedBox(width: CoveSpace.sm),
                      Expanded(
                        child: Text(
                          'Log to household Expenses',
                          style: CoveType.readout.copyWith(
                            color: cv.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Cancel',
                  style: CoveType.rowTitle.copyWith(color: cv.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cv.accentFill,
                  foregroundColor: cv.textOnAccent,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(CoveRadius.pill),
                    ),
                  ),
                ),
                child: Text(
                  isEmi ? 'Confirm Payment' : 'Confirm Renewal',
                  style: CoveType.rowTitle.copyWith(color: cv.textOnAccent),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(subscriptionControllerProvider).renewOrPaySubscription(
            _sub.id,
            isPrivate: _sub.isPrivate,
            logExpense: logExpense,
          );
      if (mounted) {
        setState(() {
          _markedPaidInSession = true;
          if (isEmi && nextPaid != null) {
            _sessionPaidInstallments = nextPaid;
          }
          _sessionNextBillingDate = advancedNext;
        });
      }
      if (context.mounted) {
        CoveUndoToast.show(
          context,
          message: isEmi
              ? (willComplete
                  ? 'Completed all installments for "${_sub.name}"!'
                  : 'Recorded installment #$nextPaid for "${_sub.name}"')
              : 'Renewed "${_sub.name}" for another cycle',
          icon: Icons.check_circle_outline_rounded,
          onUndo: () async {
            await ref.read(subscriptionControllerProvider).updateSubscription(
                  id: _sub.id,
                  name: _sub.name,
                  amount: _sub.amount,
                  currency: _sub.currency,
                  billingCycle: _sub.billingCycle,
                  nextBillingDate: _sub.nextBillingDate,
                  category: _sub.category,
                  isPrivate: _sub.isPrivate,
                  endDate: _sub.endDate,
                  paidBy: _sub.paidBy,
                  financedThrough: _sub.financedThrough,
                  totalInstallments: _sub.totalInstallments,
                  paidInstallments: _sub.paidInstallments,
                );
            if (mounted) {
              setState(() {
                _markedPaidInSession = false;
                _sessionPaidInstallments = null;
                _sessionNextBillingDate = null;
              });
            }
          },
        );
      }
    }
  }

  Future<void> _handleForecloseEmi(BuildContext context, WidgetRef ref) async {
    final cv = context.cv;
    final currency = ref.read(currencyPreferenceProvider);

    final emiProg = _sub.emiProgress;
    final total = _sub.totalInstallments ?? emiProg?.totalInstallments ?? 12;
    final currentPaid = _sessionPaidInstallments ??
        _sub.paidInstallments ??
        emiProg?.paidInstallments ??
        0;
    final remainingInstallments = (total - currentPaid).clamp(0, total);
    final outstandingAmount = remainingInstallments * _sub.amount;

    bool logExpense = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: cv.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.inline),
              ),
              side: BorderSide(
                color: cv.lineHairline,
                width: CommitmentDetailSheet._kDialogBorderWidth,
              ),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  color: cv.accentTint,
                  size: CommitmentDetailSheet._kDialogIconSize,
                ),
                const SizedBox(width: CoveSpace.sm),
                Expanded(
                  child: Text(
                    'Foreclose EMI',
                    style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to foreclose "${_sub.name}"? This will settle all remaining installments and close this loan.',
                  style: CoveType.readout.copyWith(color: cv.textSecondary),
                ),
                const SizedBox(height: CoveSpace.md),
                Container(
                  padding: const EdgeInsets.all(CoveSpace.md),
                  decoration: BoxDecoration(
                    color: cv.surfaceRow,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(CoveRadius.card),
                    ),
                    border: Border.all(
                      color: cv.lineHairline,
                      width: CommitmentDetailSheet._kDialogBorderWidth,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Loan Name',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textSecondary,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              _sub.name,
                              style: CoveType.rowTitle.copyWith(
                                color: cv.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (_sub.financedThrough != null &&
                          _sub.financedThrough!.trim().isNotEmpty) ...[
                        const SizedBox(height: CoveSpace.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Financed Via',
                              style: CoveType.rowSub.copyWith(
                                color: cv.textSecondary,
                              ),
                            ),
                            Text(
                              _sub.financedThrough!.trim(),
                              style: CoveType.rowTitle.copyWith(
                                color: cv.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: CoveSpace.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly EMI',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textSecondary,
                            ),
                          ),
                          Text(
                            '${currency.symbol}${formatCoveAmount(_sub.amount)}/mo',
                            style: CoveType.rowTitle.copyWith(
                              color: cv.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CoveSpace.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tenure Status',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textSecondary,
                            ),
                          ),
                          Text(
                            '$currentPaid of $total paid ($remainingInstallments remaining)',
                            style: CoveType.rowTitle.copyWith(
                              color: cv.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CoveSpace.sm),
                      Divider(
                        height: CoveSpace.md,
                        thickness: CommitmentDetailSheet._kDialogBorderWidth,
                        color: cv.lineHairline,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Payoff Outstanding',
                            style: CoveType.rowTitle.copyWith(
                              color: cv.textPrimary,
                            ),
                          ),
                          Text(
                            '${currency.symbol}${formatCoveAmount(outstandingAmount)}',
                            style: CoveType.rowTitle.copyWith(
                              color: cv.accentTint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CoveSpace.md),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setDialogState(() => logExpense = !logExpense),
                  child: Row(
                    children: [
                      CoveCheckbox(
                        value: logExpense,
                        onChanged: (val) =>
                            setDialogState(() => logExpense = val),
                      ),
                      const SizedBox(width: CoveSpace.sm),
                      Expanded(
                        child: Text(
                          'Log payoff of ${currency.symbol}${formatCoveAmount(outstandingAmount)} to Expenses',
                          style: CoveType.readout.copyWith(
                            color: cv.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Cancel',
                  style: CoveType.rowTitle.copyWith(color: cv.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  'Foreclose EMI',
                  style: CoveType.rowTitle.copyWith(color: cv.accentText),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(subscriptionControllerProvider).forecloseEmi(
            _sub.id,
            isPrivate: _sub.isPrivate,
            logExpense: logExpense,
          );
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Foreclosed "${_sub.name}" · Loan closed',
          icon: Icons.task_alt_rounded,
          onUndo: () async {
            await ref.read(subscriptionControllerProvider).updateSubscription(
                  id: _sub.id,
                  name: _sub.name,
                  amount: _sub.amount,
                  currency: _sub.currency,
                  billingCycle: _sub.billingCycle,
                  nextBillingDate: _sub.nextBillingDate,
                  category: _sub.category,
                  isPrivate: _sub.isPrivate,
                  endDate: _sub.endDate,
                  paidBy: _sub.paidBy,
                  financedThrough: _sub.financedThrough,
                  totalInstallments: _sub.totalInstallments,
                  paidInstallments: _sub.paidInstallments,
                );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencyPreferenceProvider);
    final currentUser = ref.watch(authProvider).value;
    final partnerProfile = ref.watch(partnerProfileProvider);
    final userProfile = ref.watch(userProfileProvider);

    final isEmi = _sub.isEmi;
    final isPaused = !_sub.isActive;
    final emiProgress = _sub.emiProgress;
    final totalInstallments =
        isEmi ? (_sub.totalInstallments ?? emiProgress?.totalInstallments ?? 12) : null;
    final effectivePaidInstallments = isEmi
        ? (_sessionPaidInstallments ??
                _sub.paidInstallments ??
                emiProgress?.paidInstallments ??
                0)
            .clamp(0, totalInstallments!)
        : 0;
    final isDone = isEmi &&
        (effectivePaidInstallments >= totalInstallments! || _sub.isEmiFinished);

    final effectiveNextDate = _sessionNextBillingDate ?? _sub.nextBillingDate;
    final voucherDate = _markedPaidInSession ? _sub.nextBillingDate : effectiveNextDate;
    final contextCadence = _formatContextCadence(_sub.billingCycle);
    final cadencePhrase = isEmi ? 'a month' : _formatCadencePhrase(_sub.billingCycle);
    final formattedAmount =
        '${currency.symbol}${formatCoveAmount(_sub.amount)}';

    final paidByLabel = _resolvePaidByLabel(
      currentUserId: currentUser?.id.toLowerCase(),
      partnerUserId: partnerProfile.userId?.toLowerCase(),
      myDisplayName: userProfile.displayName.trim().toLowerCase(),
      partnerDisplayName: partnerProfile.displayName.trim(),
    );

    final voucherState = (_markedPaidInSession || isDone)
        ? CoveVoucherState.paid
        : CoveVoucherState.due;

    // Meaning panel per design/specs/13-detail-sheet.md:
    // - Commitment: "Renews {date}" / "{amount} a month/a year · via {financedThrough}"
    // - EMI: "{paid} of {total} paid" / "Ends {date} · {remaining} left"
    final CoveDetailMeaningPanel meaningPanel;
    if (isEmi && totalInstallments != null) {
      final remainingCount =
          (totalInstallments - effectivePaidInstallments).clamp(0, totalInstallments);
      final remainingAmount = remainingCount * _sub.amount;
      final formattedRemaining =
          '${currency.symbol}${formatCoveAmount(remainingAmount)}';
      final cycleMonths = getBillingCycleMonths(_sub.billingCycle);
      final resolvedEndDate = _sub.endDate ??
          DateTime(
            effectiveNextDate.year,
            effectiveNextDate.month + ((remainingCount - 1).clamp(0, 999) * cycleMonths),
            effectiveNextDate.day,
          );
      final endsDateStr = DateFormat('MMM y').format(resolvedEndDate);
      final viaSuffix = (_sub.financedThrough != null &&
              _sub.financedThrough!.trim().isNotEmpty)
          ? ' · via ${_sub.financedThrough!.trim()}'
          : '';
      meaningPanel = CoveDetailMeaningPanel.icon(
        icon: Icons.donut_large_outlined,
        title: '$effectivePaidInstallments of $totalInstallments paid',
        subtitle: 'Ends $endsDateStr · $formattedRemaining left$viaSuffix',
      );
    } else {
      final renewsDateStr = DateFormat('d MMM y').format(effectiveNextDate);
      final hasFinancedThrough = _sub.financedThrough != null &&
          _sub.financedThrough!.trim().isNotEmpty;
      final viaPart = hasFinancedThrough
          ? 'via ${_sub.financedThrough!.trim()}'
          : 'Paid by $paidByLabel';
      meaningPanel = CoveDetailMeaningPanel.icon(
        icon: Icons.autorenew_rounded,
        title: isPaused ? 'Paused · Renews $renewsDateStr' : 'Renews $renewsDateStr',
        subtitle: '$formattedAmount $cadencePhrase · $viaPart',
      );
    }

    final menuItems = <CoveDetailMenuItem>[
      if (isEmi && !isDone)
        CoveDetailMenuItem(
          label: 'Foreclose this EMI — settle remaining installments',
          icon: Icons.task_alt_rounded,
          onSelected: () => _handleForecloseEmi(context, ref),
        ),
      CoveDetailMenuItem(
        label: isPaused
            ? (isEmi ? 'Resume this EMI' : 'Resume this commitment')
            : (isEmi ? 'Pause this EMI' : 'Pause this commitment'),
        icon: isPaused
            ? Icons.play_arrow_outlined
            : Icons.pause_circle_outline_rounded,
        onSelected: () => _handleTogglePause(context, ref),
      ),
      CoveDetailMenuItem(
        label: isEmi ? 'Delete this EMI' : 'Delete this commitment',
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
        onSelected: () => _handleDelete(context, ref),
      ),
    ];

    return CoveDetailSheet(
      kindGlyph: const Icon(Icons.event_repeat_rounded),
      kindLabel: 'COMMITMENT',
      contextLabel: contextCadence,
      onClose: () => Navigator.of(context).pop(),
      slip: CoveVoucher(
        key: ValueKey('commitment_voucher_${_sub.id}'),
        variant: CoveSlipVariant.paper,
        title: _sub.name,
        amount: formattedAmount,
        dueDay: DateFormat('d').format(voucherDate),
        dueMonth: DateFormat('MMM').format(voucherDate).toUpperCase(),
        dueMonthSemantic: DateFormat('MMMM').format(voucherDate),
        capsLabel: 'COVE · $contextCadence',
        cadenceSuffix: cadencePhrase,
        state: voucherState,
        totalInstallments: totalInstallments,
        paidInstallments: effectivePaidInstallments,
      ),
      meaningPanel: meaningPanel,
      editVerb: CoveDetailVerb(
        label: 'Edit',
        icon: Icons.edit_outlined,
        onPressed: () => _handleEdit(context),
      ),
      secondaryVerb: (!isDone && !isPaused)
          ? CoveDetailVerb(
              label: 'Mark paid',
              icon: Icons.check_circle_outline_rounded,
              onPressed: () => _handleRenewOrPay(context, ref),
            )
          : null,
      menuItems: menuItems,
    );
  }
}
