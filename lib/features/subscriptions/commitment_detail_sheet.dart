import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import 'commitment_models.dart';
import 'subscription_controller.dart';
import 'subscription_form_sheet.dart';
import '../../core/utils/cove_currency_formatter.dart';

class CommitmentDetailSheet extends ConsumerWidget {
  final LocalSubscription subscription;

  const CommitmentDetailSheet({
    super.key,
    required this.subscription,
  });

  static Future<void> show(BuildContext context, LocalSubscription subscription) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommitmentDetailSheet(subscription: subscription),
    );
  }

  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'entertainment':
      case 'streaming':
        return Icons.movie_outlined;
      case 'productivity':
      case 'software':
        return Icons.laptop_chromebook_outlined;
      case 'utilities':
        return Icons.power_outlined;
      case 'fitness':
      case 'health':
        return Icons.fitness_center_outlined;
      case 'music':
        return Icons.headphones_outlined;
      case 'gaming':
        return Icons.sports_esports_outlined;
      case 'news':
        return Icons.menu_book_outlined;
      case 'cloud':
      case 'storage':
        return Icons.cloud_outlined;
      case 'electronics':
        return Icons.devices_outlined;
      case 'finance':
      case 'loan':
      case 'vehicle':
        return Icons.directions_car_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  Future<void> _handleEdit(BuildContext context) async {
    Navigator.of(context).pop();
    await SubscriptionFormSheet.show(context, existing: subscription);
  }

  Future<void> _handleTogglePause(BuildContext context, WidgetRef ref) async {
    final isPaused = !subscription.isActive;
    if (isPaused) {
      await ref.read(subscriptionControllerProvider).reactivateSubscription(
            subscription.id,
            isPrivate: subscription.isPrivate,
          );
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Resumed "${subscription.name}"',
          onUndo: () => ref.read(subscriptionControllerProvider).cancelSubscription(
                subscription.id,
                isPrivate: subscription.isPrivate,
              ),
        );
      }
    } else {
      await ref.read(subscriptionControllerProvider).cancelSubscription(
            subscription.id,
            isPrivate: subscription.isPrivate,
          );
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Paused "${subscription.name}"',
          onUndo: () => ref.read(subscriptionControllerProvider).reactivateSubscription(
                subscription.id,
                isPrivate: subscription.isPrivate,
              ),
        );
      }
    }
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderHairline, width: 1),
        ),
        title: Text(
          'Delete ${subscription.isEmi ? 'EMI' : 'Subscription'}?',
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${subscription.name}"? This action cannot be undone.',
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 14,
            color: colors.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'GeneralSans', color: colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontWeight: FontWeight.w600,
                color: colors.accentSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(subscriptionControllerProvider).deleteSubscription(
            subscription.id,
            isPrivate: subscription.isPrivate,
          );
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Deleted "${subscription.name}"',
          onUndo: () => ref.read(subscriptionControllerProvider).createSubscription(
                name: subscription.name,
                amount: subscription.amount,
                currency: subscription.currency,
                billingCycle: subscription.billingCycle,
                nextBillingDate: subscription.nextBillingDate,
                category: subscription.category,
                isPrivate: subscription.isPrivate,
                endDate: subscription.endDate,
                paidBy: subscription.paidBy,
                financedThrough: subscription.financedThrough,
                totalInstallments: subscription.totalInstallments,
                paidInstallments: subscription.paidInstallments,
              ),
        );
      }
    }
  }

  Future<void> _handleRenewOrPay(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.read(currencyPreferenceProvider);
    final isEmi = subscription.isEmi;
    final cycleMonths = getBillingCycleMonths(subscription.billingCycle);
    final currentNext = subscription.nextBillingDate;
    final advancedNext = DateTime(
      currentNext.year,
      currentNext.month + cycleMonths,
      currentNext.day,
    );

    final total = subscription.totalInstallments ?? 12;
    final currentPaid = subscription.paidInstallments ?? 0;
    final nextPaid = isEmi ? (currentPaid + 1).clamp(0, total) : null;
    final willComplete = isEmi && nextPaid != null && nextPaid >= total;

    bool logExpense = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors.borderHairline, width: 1),
            ),
            title: Row(
              children: [
                Icon(
                  isEmi ? Icons.payments_outlined : Icons.autorenew_rounded,
                  color: colors.accentPrimary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEmi ? 'Record Installment Payment' : 'Record Renewal',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
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
                      ? 'Mark installment #$nextPaid of $total paid for "${subscription.name}"?'
                      : 'Mark "${subscription.name}" as renewed?',
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 14,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceRow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.borderHairline),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount', style: typography.caption.copyWith(color: colors.textMuted)),
                          Text(
                            '${currency.symbol}${formatCoveAmount(subscription.amount)}',
                            style: typography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.accentTint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Next Due Date', style: typography.caption.copyWith(color: colors.textMuted)),
                          Text(
                            willComplete ? 'Final installment' : DateFormat('MMM d, y').format(advancedNext),
                            style: typography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (isEmi) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Progress', style: typography.caption.copyWith(color: colors.textMuted)),
                            Text(
                              willComplete ? '$total/$total (Complete!)' : '$nextPaid/$total paid',
                              style: typography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: willComplete ? colors.accentPrimary : colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () => setDialogState(() => logExpense = !logExpense),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: logExpense,
                            activeColor: colors.accentPrimary,
                            checkColor: const Color(0xFF0B1F1E),
                            onChanged: (val) => setDialogState(() => logExpense = val ?? true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Log to household Expenses',
                            style: typography.bodyRegular.copyWith(
                              fontSize: 13,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontFamily: 'GeneralSans', color: colors.textMuted),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentPrimary,
                  foregroundColor: const Color(0xFF0B1F1E),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(
                  isEmi ? 'Confirm Payment' : 'Confirm Renewal',
                  style: const TextStyle(
                    fontFamily: 'GeneralSans',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(subscriptionControllerProvider).renewOrPaySubscription(
            subscription.id,
            isPrivate: subscription.isPrivate,
            logExpense: logExpense,
          );
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: isEmi
              ? (willComplete
                  ? 'Completed all installments for "${subscription.name}"!'
                  : 'Recorded installment #$nextPaid for "${subscription.name}"')
              : 'Renewed "${subscription.name}" for another cycle',
          icon: Icons.check_circle_outline_rounded,
          onUndo: () async {
            await ref.read(subscriptionControllerProvider).updateSubscription(
                  id: subscription.id,
                  name: subscription.name,
                  amount: subscription.amount,
                  currency: subscription.currency,
                  billingCycle: subscription.billingCycle,
                  nextBillingDate: subscription.nextBillingDate,
                  category: subscription.category,
                  isPrivate: subscription.isPrivate,
                  endDate: subscription.endDate,
                  paidBy: subscription.paidBy,
                  financedThrough: subscription.financedThrough,
                  totalInstallments: subscription.totalInstallments,
                  paidInstallments: subscription.paidInstallments,
                );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.watch(currencyPreferenceProvider);
    final currentUser = ref.watch(authProvider).value;
    final partnerProfile = ref.watch(partnerProfileProvider);
    final outbox = ref.watch(activeHomeOutboxProvider).value ?? [];
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);

    final isEmi = subscription.isEmi;
    final isPaused = !subscription.isActive;
    final isDone = isEmi && subscription.isEmiFinished;
    final emiProgress = subscription.emiProgress;

    final tickStatus = resolveCoveSyncStatus(
      entityId: subscription.id,
      outbox: outbox,
      isPrivate: subscription.isPrivate,
      hasPartner: hasPartner,
    );

    // Paid by resolution
    String paidByLabel = 'You';
    final pBy = subscription.paidBy?.trim().toLowerCase();
    if (pBy == 'split' || pBy == 'split_50_50' || pBy == 'split (50/50)') {
      paidByLabel = 'Split (50/50)';
    } else if (pBy != null && pBy.isNotEmpty) {
      if (pBy == currentUser?.id.toLowerCase() || pBy == 'me' || pBy == 'user_alex') {
        paidByLabel = 'You';
      } else if (pBy == 'partner' || pBy == partnerProfile.displayName.toLowerCase()) {
        paidByLabel = partnerProfile.displayName;
      } else {
        paidByLabel = subscription.paidBy!;
      }
    }

    // Currency & amount formatting
    final formattedAmount = '${currency.symbol}${formatCoveAmount(subscription.amount)}';
    final cycleSuffix = isEmi ? ' / month' : ' ${formatBillingCycleSuffix(subscription.billingCycle)}';

    // Dates formatting
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextDate = DateTime(
      subscription.nextBillingDate.year,
      subscription.nextBillingDate.month,
      subscription.nextBillingDate.day,
    );
    final daysUntilNext = nextDate.difference(today).inDays;
    final nextFormatted = DateFormat('EEEE, MMMM d, y').format(subscription.nextBillingDate);

    String timingCaption;
    if (isPaused) {
      timingCaption = 'Commitment is paused';
    } else if (isDone) {
      timingCaption = 'All installments completed';
    } else if (daysUntilNext == 0) {
      timingCaption = 'Due today · $nextFormatted';
    } else if (daysUntilNext == 1) {
      timingCaption = 'Due tomorrow · $nextFormatted';
    } else if (daysUntilNext > 1 && daysUntilNext <= 30) {
      timingCaption = 'Due in $daysUntilNext days · $nextFormatted';
    } else {
      timingCaption = 'Next due on $nextFormatted';
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colors.borderHairline, width: 1)),
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 32),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Center drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderHairline.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header: Badges and Close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Sub / EMI Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEmi
                              ? colors.accentPrimary.withValues(alpha: 0.15)
                              : colors.surfaceRow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isEmi
                                ? colors.accentPrimary.withValues(alpha: 0.4)
                                : colors.borderHairline,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isEmi ? 'EMI FINANCING' : 'SUBSCRIPTION',
                          style: typography.caption.copyWith(
                            color: isEmi ? colors.accentPrimary : colors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surfaceRow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: colors.borderHairline, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(subscription.category),
                              size: 13,
                              color: colors.textMuted,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              subscription.category ?? 'General',
                              style: typography.caption.copyWith(
                                color: colors.textMuted,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: colors.textMuted),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount and Suffix
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    formattedAmount,
                    style: typography.displayLarge.copyWith(
                      fontSize: 36,
                      color: colors.accentTint,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cycleSuffix,
                    style: typography.bodyMedium.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  // Status indicator pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPaused
                          ? colors.surfaceRow
                          : (isDone
                              ? colors.accentPrimary.withValues(alpha: 0.12)
                              : colors.accentPrimary.withValues(alpha: 0.12)),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isPaused
                            ? colors.borderHairline
                            : colors.accentPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isPaused ? 'Paused' : (isDone ? 'Completed' : 'Active'),
                      style: typography.caption.copyWith(
                        color: isPaused ? colors.textMuted : colors.accentPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Title
              Text(
                subscription.name,
                style: typography.headline.copyWith(
                  fontSize: 22,
                  decoration: isPaused ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 6),

              // Timing subtitle
              Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 14,
                    color: colors.accentPrimary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      timingCaption,
                      style: typography.caption.copyWith(
                        color: colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // EMI Progress Card (if EMI)
              if (isEmi && emiProgress != null) ...[
                CoveCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Installments Progress',
                            style: typography.bodyRegular.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.accentPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              emiProgress.caption,
                              style: typography.caption.copyWith(
                                color: colors.accentPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (emiProgress.totalInstallments > 0)
                              ? (emiProgress.paidInstallments / emiProgress.totalInstallments).clamp(0.0, 1.0)
                              : 0.0,
                          minHeight: 8,
                          backgroundColor: colors.surfaceRow,
                          valueColor: AlwaysStoppedAnimation<Color>(colors.accentPrimary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${(emiProgress.totalInstallments - emiProgress.paidInstallments).clamp(0, emiProgress.totalInstallments)} remaining',
                            style: typography.caption.copyWith(
                              fontSize: 12,
                              color: colors.textMuted,
                            ),
                          ),
                          if (subscription.endDate != null)
                            Text(
                              'Ends ${DateFormat('MMM y').format(subscription.endDate!)}',
                              style: typography.caption.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                        ],
                      ),
                      if (emiProgress.totalInstallments > 0) ...[
                        const SizedBox(height: 10),
                        Divider(color: colors.borderHairline, height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total EMI Commitment',
                              style: typography.caption.copyWith(
                                fontSize: 12,
                                color: colors.textMuted,
                              ),
                            ),
                            Text(
                              '${currency.symbol}${formatCoveAmount(subscription.amount * emiProgress.totalInstallments)}',
                              style: typography.bodyRegular.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.accentTint,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Primary Action: Mark as Renewed / Mark Installment as Paid
              if (!isDone && !isPaused) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleRenewOrPay(context, ref),
                    icon: Icon(
                      isEmi ? Icons.payments_outlined : Icons.autorenew_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isEmi ? 'Mark Installment as Paid' : 'Mark as Renewed',
                      style: const TextStyle(
                        fontFamily: 'GeneralSans',
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accentPrimary,
                      foregroundColor: const Color(0xFF0B1F1E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Details Grouped Card
              CoveGroupedCard(
                children: [
                  CoveGroupedRow(
                    leading: Icon(Icons.calendar_today_outlined, size: 18, color: colors.accentPrimary),
                    title: Text('Billing Cycle', style: typography.bodyMedium),
                    trailing: Text(
                      formatBillingCycleLabel(subscription.billingCycle),
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  CoveGroupedRow(
                    leading: Icon(Icons.account_circle_outlined, size: 18, color: colors.accentPrimary),
                    title: Text('Paid By', style: typography.bodyMedium),
                    trailing: Text(
                      paidByLabel,
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  if (isEmi && subscription.financedThrough != null && subscription.financedThrough!.isNotEmpty)
                    CoveGroupedRow(
                      leading: Icon(Icons.credit_card_outlined, size: 18, color: colors.accentPrimary),
                      title: Text('Financed Through', style: typography.bodyMedium),
                      trailing: Text(
                        subscription.financedThrough!,
                        style: typography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  if (subscription.endDate != null)
                    CoveGroupedRow(
                      leading: Icon(Icons.event_available_outlined, size: 18, color: colors.accentPrimary),
                      title: Text('Last Due / Ends On', style: typography.bodyMedium),
                      trailing: Text(
                        DateFormat('MMM d, y').format(subscription.endDate!),
                        style: typography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  CoveGroupedRow(
                    leading: Icon(Icons.lock_outline, size: 18, color: colors.textSubtle),
                    title: Text('Sync & Privacy', style: typography.bodyMedium),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          subscription.isPrivate
                              ? 'Private (on-device only)'
                              : (tickStatus == CoveSyncStatus.syncedToPartner
                                  ? 'Synced with ${partnerProfile.displayName}'
                                  : 'Saved Locally'),
                          style: typography.caption.copyWith(color: colors.textMuted),
                        ),
                        const SizedBox(width: 6),
                        CoveSyncTick(status: tickStatus, size: 13),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Action Buttons: Edit, Pause/Resume, Delete
              Row(
                children: [
                  Expanded(
                    child: CovePillButton(
                      label: 'Edit Commitment',
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      onPressed: () => _handleEdit(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => _handleTogglePause(context, ref),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      side: BorderSide(color: colors.borderHairline),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: Icon(
                      isPaused ? Icons.play_arrow_outlined : Icons.pause_outlined,
                      size: 18,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: () => _handleDelete(context, ref),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      side: BorderSide(color: colors.accentSecondary.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: colors.accentSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
