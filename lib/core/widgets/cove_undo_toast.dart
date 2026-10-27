import 'dart:async';
import 'package:flutter/material.dart';
import '../shape/cove_shape.dart';
import '../theme/cove_tokens.dart';

class CoveUndoToast {
  static const double _kHorizontalInset =
      16.0; // (literal) 16dp snackbar horizontal inset
  static const double _kBorderWidth =
      1.0; // (literal) 1dp snackbar hairline border
  static const double _kIconSize =
      18.0; // (literal) 18dp snackbar icon glyph size

  static void show(
    BuildContext context, {
    required String message,
    required FutureOr<void> Function() onUndo,
    String actionLabel = 'UNDO',
    IconData icon = Icons.delete_outline_rounded,
    Duration duration = const Duration(seconds: 5),
  }) {
    final cv = context.cv;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(
          horizontal: _kHorizontalInset,
          vertical: CoveSpace.md,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: _kHorizontalInset,
          vertical: CoveSpace.sm,
        ),
        shape: CoveShape.border(
          CoveRadius.inline,
          side: BorderSide(color: cv.lineHairline, width: _kBorderWidth),
        ),
        backgroundColor: cv.surfaceCard,
        duration: duration,
        elevation: 6,
        content: Row(
          children: [
            Container(
              width: CoveSize.avatarHeader,
              height: CoveSize.avatarHeader,
              decoration: CoveShape.decoration(
                CoveSpace.sm,
                color: cv.accentWash,
              ),
              child: Icon(icon, color: cv.accentFill, size: _kIconSize),
            ),
            const SizedBox(width: CoveSpace.md),
            Expanded(
              child: Text(
                message,
                style: CoveType.readout.copyWith(
                  fontWeight: FontWeight.w500,
                  color: cv.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: actionLabel,
          textColor: cv.accentText,
          onPressed: () async {
            messenger.hideCurrentSnackBar();
            await onUndo();
          },
        ),
      ),
    );
  }
}
