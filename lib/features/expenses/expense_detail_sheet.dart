import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_detail_sheet.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../core/widgets/slips/cove_receipt.dart';
import '../../core/widgets/slips/cove_slip.dart';
import '../../sync/db/app_database.dart';
import '../../sync/pending_delete_service.dart';
import '../../sync/providers/active_home_provider.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import 'expense_controller.dart';
import 'expense_form_sheet.dart';

/// Builds the paper [CoveReceipt] for [expense], shared between
/// [ExpenseDetailSheet] and the Add flow's Expense review / Added state so
/// review shows the exact receipt that the saved expense will show.
CoveReceipt buildExpenseReceipt({
  required LocalExpense expense,
  required String currencySymbol,
  required String? currentUserId,
  required String? homeCreatedBy,
  required String partnerDisplayName,
  String? viewerDisplayName,
  CoveSlipVisibility? visibility,
  String? stamp,
  CoveSlipFieldTaps? fieldTaps,
}) {
  final share = computeExpenseShare(
    expense,
    currentUserId: currentUserId,
  );

  final partnerName =
      partnerDisplayName.isNotEmpty ? partnerDisplayName : 'Partner';
  final payerName = share.isPaidByViewer ? 'You' : partnerName;
  final cleanViewerName = (viewerDisplayName != null &&
          viewerDisplayName.trim().isNotEmpty &&
          viewerDisplayName.trim().toLowerCase() != 'you')
      ? viewerDisplayName.trim()
      : null;
  final cleanPartnerName = (partnerDisplayName.trim().isNotEmpty &&
          partnerDisplayName.trim().toLowerCase() != 'you')
      ? partnerDisplayName.trim()
      : null;
  final avatarNameOrInitial =
      share.isPaidByViewer ? cleanViewerName : cleanPartnerName;
  final creatorId = homeCreatedBy ?? currentUserId ?? 'user_alex';
  final effectiveActorId = share.isPaidByViewer
      ? (currentUserId ?? 'user_alex')
      : (expense.paidBy == 'user_alex' ? 'user_sarah' : expense.paidBy);
  final person = CoveAvatar.resolvePerson(
    homeCreatedBy: creatorId,
    actorUserId: effectiveActorId,
  );

  final categoryName = cleanExpenseCategoryName(expense.category);
  final notes = extractExpenseNotes(expense.category);
  final pmLabel = formatExpensePaymentMethod(expense.paymentMethod);

  final amountFormatted =
      '$currencySymbol${formatCoveAmount(expense.amount)}';
  final yourShareFormatted =
      '$currencySymbol${formatCoveAmount(share.viewerShareAmount)}';
  final partnerShareFormatted =
      '$currencySymbol${formatCoveAmount(share.partnerShareAmount)}';

  final expDateLocal = expense.expenseDate.toLocal();
  final isMidnight =
      expDateLocal.hour == 0 && expDateLocal.minute == 0;
  final timeFormatted = isMidnight
      ? null
      : DateFormat('h:mm a').format(expDateLocal).toUpperCase();
  final String receiptSubtitle;
  if (notes != null && notes.isNotEmpty) {
    receiptSubtitle = timeFormatted != null
        ? '${notes.toUpperCase()} · $timeFormatted'
        : notes.toUpperCase();
  } else {
    receiptSubtitle = timeFormatted ?? '';
  }
  final footerDate =
      DateFormat('EEE d MMM').format(expDateLocal).toUpperCase();

  return CoveReceipt(
    variant: CoveSlipVariant.paper,
    recordId: expense.id,
    title: expense.title,
    subtitle: receiptSubtitle,
    items: [
      CoveReceiptItem(
        payer: person,
        nameOrInitial: avatarNameOrInitial,
        title: expense.isTransfer
            ? 'Transfer to ${share.isPaidByViewer ? partnerName : "You"}'
            : categoryName,
        subtitle: [
          'Paid by $payerName',
          ?pmLabel,
          if (!share.isShared && !expense.isTransfer)
            share.visibility == ExpenseVisibility.privateToMe
                ? 'Private'
                : 'Personal',
        ].join(' · '),
        amount: amountFormatted,
      ),
    ],
    totalAmount: amountFormatted,
    split: share.isShared && !expense.isTransfer
        ? CoveReceiptSplit(
            viewerName: 'You',
            viewerAmount: yourShareFormatted,
            partnerName: partnerName,
            partnerAmount: partnerShareFormatted,
            viewerShare: share.viewerShareRatio,
          )
        : null,
    footerDate: footerDate,
    visibility: visibility,
    stamp: stamp,
    fieldTaps: fieldTaps,
  );
}

class ExpenseDetailSheet extends ConsumerWidget {
  final LocalExpense expense;

  static const double _kDialogBorderWidth =
      1.0; // (literal) 1dp dialog hairline border

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
    final cv = context.cv;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        shape: CoveShape.border(
          CoveRadius.inline,
          side: BorderSide(
            color: cv.lineHairline,
            width: _kDialogBorderWidth,
          ),
        ),
        title: Text(
          'Delete Expense?',
          style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove "${expense.title}"? This cannot be undone.',
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
      final visibility =
          ExpenseVisibilityExtension.fromSplitRatio(expense.splitRatio);
      final pendingDelete = ref.read(pendingDeleteServiceProvider);
      await pendingDelete.scheduleDelete(
        kind: PendingDeleteKind.expense,
        id: expense.id,
        expenseVisibility: visibility,
      );
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Deleted "${expense.title}"',
          onUndo: () async {
            await pendingDelete.undoDelete(
              kind: PendingDeleteKind.expense,
              id: expense.id,
            );
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
    final currency = ref.watch(currencyPreferenceProvider);
    final currentUser = ref.watch(authProvider).value;
    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final home = ref.watch(activeHomeProvider).value;

    final rawProfileName = userProfile.displayName.trim();
    final viewerDisplayName =
        (rawProfileName.isNotEmpty && rawProfileName.toLowerCase() != 'you')
            ? rawProfileName
            : currentUser?.displayName;

    final share = computeExpenseShare(
      expense,
      currentUserId: currentUser?.id,
    );

    final partnerName = partnerProfile.displayName.isNotEmpty
        ? partnerProfile.displayName
        : 'Partner';
    final payerName = share.isPaidByViewer ? 'You' : partnerName;
    final categoryName = cleanExpenseCategoryName(expense.category);
    final yourShareFormatted =
        '${currency.symbol}${formatCoveAmount(share.viewerShareAmount)}';

    final CoveDetailMeaningPanel meaningPanel;
    if (share.isShared) {
      final shareTitle = share.isExactHalf
          ? '$yourShareFormatted is your half'
          : '$yourShareFormatted is your share';
      meaningPanel = CoveDetailMeaningPanel(
        glyph: _ExpenseShareGlyph(shareRatio: share.viewerShareRatio),
        title: shareTitle,
        subtitle: '$payerName paid',
      );
    } else {
      meaningPanel = CoveDetailMeaningPanel.icon(
        icon: Icons.lock_outline_rounded,
        title: 'Yours alone',
        subtitle: 'Not part of the shared total',
      );
    }

    return CoveDetailSheet(
      kindGlyph: Text(currency.symbol),
      kindLabel: expense.isTransfer ? 'TRANSFER' : 'EXPENSE',
      contextLabel: expense.isTransfer ? 'PARTNER' : categoryName,
      onClose: () => Navigator.of(context).pop(),
      slip: buildExpenseReceipt(
        expense: expense,
        currencySymbol: currency.symbol,
        currentUserId: currentUser?.id,
        homeCreatedBy: home?.createdBy,
        partnerDisplayName: partnerProfile.displayName,
        viewerDisplayName: viewerDisplayName,
      ),
      meaningPanel: meaningPanel,
      editVerb: CoveDetailVerb(
        label: 'Edit',
        icon: Icons.edit_outlined,
        onPressed: () => _handleEdit(context),
      ),
      menuItems: [
        CoveDetailMenuItem(
          label: 'Delete this expense',
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          onSelected: () => _handleDelete(context, ref),
        ),
      ],
    );
  }
}

class _ExpenseShareGlyph extends StatelessWidget {
  final double shareRatio;

  static const double _kStrokeWidth = 1.5; // (literal) 1.5dp glyph ring stroke

  const _ExpenseShareGlyph({required this.shareRatio});

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    return CustomPaint(
      size: const Size.square(CoveDetailSheet.kMeaningGlyphSize),
      painter: _ExpenseShareGlyphPainter(
        color: cv.accentTint,
        shareRatio: shareRatio.clamp(0.0, 1.0),
      ),
    );
  }
}

class _ExpenseShareGlyphPainter extends CustomPainter {
  final Color color;
  final double shareRatio;

  const _ExpenseShareGlyphPainter({
    required this.color,
    required this.shareRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_ExpenseShareGlyph._kStrokeWidth);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      rect,
      math.pi / 2.0,
      2.0 * math.pi * shareRatio,
      true,
      fillPaint,
    );

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ExpenseShareGlyph._kStrokeWidth;
    canvas.drawOval(rect, strokePaint);
  }

  @override
  bool shouldRepaint(_ExpenseShareGlyphPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.shareRatio != shareRatio;
}
