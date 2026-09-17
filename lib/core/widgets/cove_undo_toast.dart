import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';

class CoveUndoToast {
  static void show(
    BuildContext context, {
    required String message,
    required FutureOr<void> Function() onUndo,
    String actionLabel = 'UNDO',
    IconData icon = Icons.delete_outline_rounded,
    Duration duration = const Duration(seconds: 5),
  }) {
    final colors = context.colors;
    final typography = context.typography;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderHairline, width: 1),
        ),
        backgroundColor: colors.surfaceCard,
        duration: duration,
        elevation: 6,
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.accentPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colors.accentPrimary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: typography.bodyMedium.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: actionLabel,
          textColor: colors.accentPrimary,
          onPressed: () async {
            messenger.hideCurrentSnackBar();
            await onUndo();
          },
        ),
      ),
    );
  }
}
