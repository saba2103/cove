import 'package:flutter/material.dart';

import '../../../core/theme/cove_tokens.dart';
import '../../../core/widgets/slips/cove_slip.dart';

/// Footer bar for every step in the Add flow (`design/specs/14-add-flow.md` §2.6 & §7).
///
/// Supports two layouts:
/// 1. **Standard / Review foot** (`secondaryLabel == null`):
///    - Left: visibility chip (`Both can see it` / `Only you can see it`).
///    - Right: gold pill button (`Next →` or `Add {kind}`), disabled until [enabled] is `true`.
/// 2. **Added confirmation foot** (`secondaryLabel != null`, §7):
///    - Left: outlined pill button (`Add another`).
///    - Right: gold pill button (`Done`).
class AddStepFoot extends StatelessWidget {
  final CoveSlipVisibility visibility;
  final VoidCallback? onToggleVisibility;
  final String primaryLabel;
  final bool showArrow;
  final bool enabled;
  final VoidCallback? onPrimaryTap;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryTap;

  static const double _kVisIconSize = 16.0; // (literal) 16dp visibility icon
  static const double _kArrowIconSize = 18.0; // (literal) 18dp arrow icon
  static const double _kPrimaryMinWidth = 120.0; // (literal) 120dp Next pill min width
  static const double _kBorderWidth = 1.0; // (literal) 1dp outlined pill border
  static const double _kDisabledAlpha = 0.45; // (literal) disabled button opacity

  const AddStepFoot({
    super.key,
    this.visibility = CoveSlipVisibility.bothCanSee,
    this.onToggleVisibility,
    this.primaryLabel = 'Next',
    this.showArrow = true,
    this.enabled = true,
    this.onPrimaryTap,
    this.secondaryLabel,
    this.onSecondaryTap,
  });

  String get _visibilityText => visibility == CoveSlipVisibility.bothCanSee
      ? 'Both can see it'
      : 'Only you can see it';

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    final Widget leftWidget;
    if (secondaryLabel != null) {
      leftWidget = Semantics(
        container: true,
        button: true,
        label: secondaryLabel,
        onTap: onSecondaryTap,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSecondaryTap,
            child: Container(
              constraints: const BoxConstraints(
                minWidth: CoveSize.hit,
                minHeight: CoveSize.row,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: CoveSpace.gutter,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: const BorderRadius.all(
                  Radius.circular(CoveRadius.pill),
                ),
                border: Border.all(
                  color: cv.lineStrong,
                  width: _kBorderWidth,
                ),
              ),
              child: Text(
                secondaryLabel!,
                style: CoveType.rowTitle.copyWith(color: cv.textSecondary),
              ),
            ),
          ),
        ),
      );
    } else {
      final visRow = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            visibility.icon,
            size: _kVisIconSize,
            color: cv.textTertiary,
          ),
          const SizedBox(width: CoveSpace.sm),
          Flexible(
            child: Text(
              _visibilityText,
              style: CoveType.rowSub.copyWith(color: cv.textTertiary),
            ),
          ),
        ],
      );

      if (onToggleVisibility != null) {
        leftWidget = Semantics(
          container: true,
          button: true,
          label: 'Visibility: $_visibilityText. Tap to change',
          onTap: onToggleVisibility,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggleVisibility,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: CoveSize.hit,
                  minHeight: CoveSize.hit,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1.0,
                  child: visRow,
                ),
              ),
            ),
          ),
        );
      } else {
        leftWidget = Semantics(
          container: true,
          label: _visibilityText,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: CoveSize.hit,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1.0,
                child: visRow,
              ),
            ),
          ),
        );
      }
    }

    final canTapPrimary = enabled && onPrimaryTap != null;
    final fillColor = enabled
        ? cv.accentFill
        : cv.accentFill.withValues(alpha: _kDisabledAlpha);
    final labelColor = enabled
        ? cv.textOnAccent
        : cv.textOnAccent.withValues(alpha: _kDisabledAlpha);

    final primaryButton = Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: primaryLabel,
      onTap: canTapPrimary ? onPrimaryTap : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canTapPrimary ? onPrimaryTap : null,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: _kPrimaryMinWidth,
              minHeight: CoveSize.row,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.lg,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.pill),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  primaryLabel,
                  style: CoveType.rowTitle.copyWith(color: labelColor),
                ),
                if (showArrow) ...[
                  const SizedBox(width: CoveSpace.sm),
                  Icon(
                    Icons.arrow_forward,
                    size: _kArrowIconSize,
                    color: labelColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: leftWidget),
        const SizedBox(width: CoveSpace.md),
        primaryButton,
      ],
    );
  }
}
