import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';
import 'cove_page_header.dart';
import 'cove_round_button.dart';

/// Every bottom sheet: add, detail, pickers (`design/specs/07-sheet.md`).
///
/// Built to the contract in `design/specs/07-sheet.md`:
/// - Top radius: [CoveRadius.sheet] (`32dp`)
/// - Bottom radius: [CoveRadius.device] (`40dp`) where it meets the screen edge
/// - Fill: `surface.sheet`
/// - Padding: [CoveSpace.gutter] (`20dp`) horizontal, [CoveSpace.md] (`12dp`)
///   top, [CoveSpace.lg] (`24dp`) + `MediaQuery.padding.bottom` bottom
/// - Grab handle: `36 × 4` `(literal)` in `line.strong`, centred,
///   [CoveSpace.md] (`12dp`) below
/// - Scrim: `surface.scrim`
/// - Motion: [CoveMotion.sheet] (`320ms`) with [CoveMotion.easing], resolved
///   via [CoveMotion.s] so Reduce Motion collapses it to zero
/// - Dismissable by drag and by scrim tap, unless [isMidCommit] is `true`.
class CoveSheet extends StatelessWidget {
  final String? title;
  final VoidCallback? onClose;
  final Widget child;
  final bool showGrabHandle;
  final bool isMidCommit;
  final VoidCallback? onDismiss;

  static const double kGrabHandleWidth = 36.0; // (literal) per 07-sheet.md
  static const double kGrabHandleHeight = 4.0; // (literal) per 07-sheet.md
  static const double _kBorderWidth = 1.0; // (literal) 1dp hairline border
  static const double _kDismissDragThreshold = 48.0; // (literal) drag threshold

  const CoveSheet({
    super.key,
    this.title,
    this.onClose,
    required this.child,
    this.showGrabHandle = true,
    this.isMidCommit = false,
    this.onDismiss,
  });

  /// Presents a [CoveSheet] modally over `surface.scrim` using
  /// [CoveMotion.s] (`320ms` or `0ms` when Reduce Motion is enabled) and
  /// [CoveMotion.easing].
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isMidCommit = false,
    String barrierLabel = 'Dismiss sheet',
  }) {
    final cv = context.cv;
    final duration = CoveMotion.s(context);

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: !isMidCommit,
      barrierLabel: barrierLabel,
      barrierColor: cv.surfaceScrim,
      transitionDuration: duration,
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: CoveSize.maxContent),
            child: Material(
              type: MaterialType.transparency,
              child: builder(dialogContext),
            ),
          ),
        );
      },
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        if (duration == Duration.zero) {
          return child;
        }
        final curved = CurvedAnimation(
          parent: animation,
          curve: CoveMotion.easing,
          reverseCurve: CoveMotion.easing.flipped,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final bottomInset = CovePageInsets.bottomOf(context);
    final canDismiss = !isMidCommit && onDismiss != null;

    final Widget sheetBody = Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: CoveSpace.gutter,
        right: CoveSpace.gutter,
        top: CoveSpace.md,
        bottom: CoveSpace.lg + bottomInset,
      ),
      decoration: BoxDecoration(
        color: cv.surfaceSheet,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(CoveRadius.sheet),
          topRight: Radius.circular(CoveRadius.sheet),
          bottomLeft: Radius.circular(CoveRadius.device),
          bottomRight: Radius.circular(CoveRadius.device),
        ),
        border: Border.all(
          color: cv.lineHairline,
          width: _kBorderWidth,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showGrabHandle) ...[
            Center(
              child: Container(
                key: const ValueKey('cove_sheet_grab_handle'),
                width: kGrabHandleWidth,
                height: kGrabHandleHeight,
                decoration: BoxDecoration(
                  color: cv.lineStrong,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(CoveRadius.pill),
                  ),
                ),
              ),
            ),
            const SizedBox(height: CoveSpace.md),
          ],
          if (title != null || onClose != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: CoveType.title.copyWith(color: cv.textPrimary),
                    ),
                  )
                else
                  const Spacer(),
                if (onClose != null)
                  CoveRoundButton(
                    icon: Icons.close_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Close sheet',
                    onPressed: isMidCommit ? null : onClose,
                  ),
              ],
            ),
            const SizedBox(height: CoveSpace.md),
          ],
          child,
        ],
      ),
    );

    if (!canDismiss) {
      return sheetBody;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta != null &&
            details.primaryDelta! > _kDismissDragThreshold) {
          onDismiss?.call();
        }
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0.0;
        if (velocity > 200.0) {
          onDismiss?.call();
        }
      },
      child: sheetBody,
    );
  }
}

/// Renders a [CoveSheet] (and optional stacked [secondarySheet]) over a
/// `surface.scrim` backdrop (`design/specs/07-sheet.md`).
///
/// Tapping the scrim dismisses the top-most sheet unless [isMidCommit] is
/// `true`.
class CoveSheetBackdrop extends StatelessWidget {
  final Widget background;
  final CoveSheet sheet;
  final CoveSheet? stackedSheet;
  final bool isMidCommit;
  final VoidCallback? onScrimTap;

  static const double _kStackedOffset = CoveSpace.md;

  const CoveSheetBackdrop({
    super.key,
    required this.background,
    required this.sheet,
    this.stackedSheet,
    this.isMidCommit = false,
    this.onScrimTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        GestureDetector(
          key: const ValueKey('cove_sheet_scrim'),
          behavior: HitTestBehavior.opaque,
          onTap: isMidCommit ? null : onScrimTap,
          child: ColoredBox(color: cv.surfaceScrim),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: CoveSize.maxContent),
            child: stackedSheet == null
                ? sheet
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _kStackedOffset,
                        ),
                        child: sheet,
                      ),
                      const SizedBox(height: CoveSpace.sm),
                      stackedSheet!,
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
