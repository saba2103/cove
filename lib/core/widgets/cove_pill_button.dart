import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

enum CoveButtonVariant {
  primary,
  secondary,
  ghost,
}

class CovePillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final CoveButtonVariant variant;
  final Widget? icon;
  final bool isLoading;
  final bool isCompact;
  final bool isFullWidth;

  static const double _kCompactHorizontalPadding =
      16.0; // (literal) 16dp compact pill horizontal padding
  static const double _kSecondaryBorderWidth =
      1.5; // (literal) 1.5dp secondary button border stroke
  static const double _kCompactIconSize =
      16.0; // (literal) 16dp compact button icon size
  static const double _kStandardIconSize =
      18.0; // (literal) 18dp standard button icon size
  static const double _kSpinnerStrokeWidth =
      2.0; // (literal) 2dp button loading spinner stroke

  const CovePillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = CoveButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.isCompact = false,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);

    final height = isCompact ? CoveSize.buttonRound : CoveSize.hit;
    final horizontalPadding =
        isCompact ? _kCompactHorizontalPadding : CoveSpace.lg;
    final iconSize = isCompact ? _kCompactIconSize : _kStandardIconSize;

    Color backgroundColor;
    Color textColor;
    Border? border;

    switch (variant) {
      case CoveButtonVariant.primary:
        backgroundColor = cv.accentFill;
        textColor = cv.textOnAccent;
        border = null;
        break;
      case CoveButtonVariant.secondary:
        backgroundColor = Colors.transparent;
        textColor = cv.textPrimary;
        border = Border.all(
          color: cv.lineStrong,
          width: _kSecondaryBorderWidth,
        );
        break;
      case CoveButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        textColor = cv.textPrimary;
        border = null;
        break;
    }

    final effectiveTextColor =
        onPressed == null ? textColor.withValues(alpha: 0.38) : textColor;
    final buttonStyle =
        (isCompact ? CoveType.readout : CoveType.rowTitle).copyWith(
      fontWeight: FontWeight.w600,
      color: effectiveTextColor,
    );

    Widget? themedIcon = icon;
    if (themedIcon != null) {
      if (themedIcon is Icon) {
        themedIcon = Icon(
          themedIcon.icon,
          size: themedIcon.size ?? iconSize,
          color: effectiveTextColor,
          semanticLabel: themedIcon.semanticLabel,
          textDirection: themedIcon.textDirection,
          shadows: themedIcon.shadows,
        );
      } else {
        themedIcon = IconTheme.merge(
          data: IconThemeData(
            color: effectiveTextColor,
            size: iconSize,
          ),
          child: themedIcon,
        );
      }
    }

    final Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: _kSpinnerStrokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveTextColor),
            ),
          ),
          const SizedBox(width: CoveSpace.sm),
        ] else ...[
          if (themedIcon != null) ...[
            themedIcon,
            const SizedBox(width: CoveSpace.sm),
          ],
          Flexible(
            child: Text(
              label,
              style: buttonStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ],
    );

    final buttonContainer = AnimatedContainer(
      duration: duration,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: onPressed == null
            ? backgroundColor.withValues(alpha: 0.5)
            : backgroundColor,
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveRadius.pill),
        ),
        border: border,
      ),
      child: content,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveRadius.pill),
        ),
        child: isFullWidth
            ? SizedBox(width: double.infinity, child: buttonContainer)
            : buttonContainer,
      ),
    );
  }
}
