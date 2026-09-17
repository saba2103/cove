import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import 'expense_controller.dart';
import 'expense_form_sheet.dart';

class ExpenseDetailSheet extends ConsumerWidget {
  final LocalExpense expense;

  const ExpenseDetailSheet({
    super.key,
    required this.expense,
  });

  static Future<void> show(BuildContext context, LocalExpense expense) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpenseDetailSheet(expense: expense),
    );
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
          'Delete Expense?',
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${expense.title}"? This cannot be undone.',
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
      final visibility = ExpenseVisibilityExtension.fromSplitRatio(expense.splitRatio);
      await ref.read(expenseControllerProvider).deleteExpense(expense.id, visibility: visibility);
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Deleted "${expense.title}"',
          onUndo: () async {
            await ref.read(expenseControllerProvider).restoreExpense(expense);
          },
        );
      }
    }
  }

  Future<void> _handleEdit(BuildContext context) async {
    Navigator.of(context).pop();
    await ExpenseFormSheet.show(context, initialExpense: expense);
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

    final visibility = ExpenseVisibilityExtension.fromSplitRatio(expense.splitRatio);
    final isMe = (expense.paidBy == currentUser?.id) ||
        (currentUser?.id == null && expense.paidBy == 'user_alex') ||
        (expense.paidBy == 'me');
    final isShared = visibility == ExpenseVisibility.shared;

    final tickStatus = resolveCoveSyncStatus(
      entityId: expense.id,
      outbox: outbox,
      isPrivate: visibility == ExpenseVisibility.privateToMe,
      hasPartner: hasPartner,
    );

    final formattedDate = DateFormat('EEEE, MMMM d, y · h:mm a').format(expense.expenseDate);

    // Split Category & Notes if separated by bullet
    String categoryName = expense.category ?? 'Uncategorized';
    String? notes;
    if (categoryName.contains(' • ')) {
      final parts = categoryName.split(' • ');
      categoryName = parts.first;
      notes = parts.sublist(1).join(' • ');
    }

    // Amount formatted
    final amountFormatted = '${currency.symbol}${NumberFormat('#,##0.00').format(expense.amount)}';
    final yourShare = isShared ? expense.amount / 2 : (isMe ? expense.amount : 0.0);
    final yourShareFormatted = '${currency.symbol}${NumberFormat('#,##0.00').format(yourShare)}';

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colors.borderHairline, width: 1)),
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 32),
      child: SafeArea(
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

            // Top Header: Category badge & Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        expense.isTransfer ? Icons.swap_horiz : Icons.category_outlined,
                        size: 13,
                        color: colors.accentPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        expense.isTransfer ? 'TRANSFER' : categoryName,
                        style: typography.caption.copyWith(
                          color: colors.accentPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
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
            const SizedBox(height: 12),

            // Amount in big Bodoni Moda / display style
            Text(
              amountFormatted,
              style: typography.displayLarge.copyWith(
                fontSize: 38,
                color: colors.accentTint,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),

            // Title
            Text(
              expense.title,
              style: typography.headline.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 6),

            // Date & Time
            Text(
              formattedDate,
              style: typography.caption.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 20),

            // Details Grouped Card
            CoveGroupedCard(
              children: [
                if (expense.isTransfer) ...[
                  CoveGroupedRow(
                    leading: Icon(Icons.arrow_upward_rounded, size: 18, color: colors.accentPrimary),
                    title: Text('Sender', style: typography.bodyMedium),
                    trailing: Text(
                      isMe ? 'You' : partnerProfile.displayName,
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  CoveGroupedRow(
                    leading: Icon(Icons.arrow_downward_rounded, size: 18, color: colors.accentPrimary),
                    title: Text('Recipient', style: typography.bodyMedium),
                    trailing: Text(
                      isMe ? partnerProfile.displayName : 'You',
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  CoveGroupedRow(
                    leading: Icon(Icons.swap_horiz, size: 18, color: colors.accentPrimary),
                    title: Text('Classification', style: typography.bodyMedium),
                    trailing: Text(
                      'Partner Transfer',
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ] else ...[
                  CoveGroupedRow(
                    leading: Icon(Icons.account_circle_outlined, size: 18, color: colors.accentPrimary),
                    title: Text('Paid by', style: typography.bodyMedium),
                    trailing: Text(
                      isMe ? 'You' : partnerProfile.displayName,
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  CoveGroupedRow(
                    leading: Icon(Icons.call_split_outlined, size: 18, color: colors.accentPrimary),
                    title: Text('Split Policy', style: typography.bodyMedium),
                    trailing: Text(
                      isShared
                          ? 'Split 50/50'
                          : (visibility == ExpenseVisibility.partnerCanSee ? 'Personal' : 'Private'),
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
                if (expense.paymentMethod != null && expense.paymentMethod!.isNotEmpty)
                  CoveGroupedRow(
                    leading: Icon(
                      expense.paymentMethod == 'upi'
                          ? Icons.qr_code_2_rounded
                          : (expense.paymentMethod == 'cash'
                              ? Icons.payments_outlined
                              : Icons.credit_card_outlined),
                      size: 18,
                      color: colors.accentPrimary,
                    ),
                    title: Text('Payment Method', style: typography.bodyMedium),
                    trailing: Text(
                      expense.paymentMethod == 'upi'
                          ? 'UPI'
                          : (expense.paymentMethod == 'cash' ? 'Cash' : 'Card'),
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                if (!expense.isTransfer && isShared)
                  CoveGroupedRow(
                    leading: Icon(Icons.pie_chart_outline, size: 18, color: colors.accentPrimary),
                    title: Text('Your Share', style: typography.bodyMedium),
                    trailing: Text(
                      yourShareFormatted,
                      style: typography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.accentPrimary,
                      ),
                    ),
                  ),
                CoveGroupedRow(
                  leading: Icon(Icons.lock_outline, size: 18, color: colors.textSubtle),
                  title: Text('Sync & Encryption', style: typography.bodyMedium),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        visibility == ExpenseVisibility.privateToMe
                            ? 'On-device only'
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

            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              CoveCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notes_outlined, size: 16, color: colors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        notes,
                        style: typography.caption.copyWith(
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action Buttons: Edit & Delete
            Row(
              children: [
                Expanded(
                  child: CovePillButton(
                    label: 'Edit Expense',
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    onPressed: () => _handleEdit(context),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _handleDelete(context, ref),
                  icon: Icon(Icons.delete_outline, size: 16, color: colors.accentSecondary),
                  label: Text(
                    'Delete',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontWeight: FontWeight.w600,
                      color: colors.accentSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    side: BorderSide(color: colors.accentSecondary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
