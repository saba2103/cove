import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';

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
    final colors = context.colors;
    final isDark = context.isDark;

    final height = isCompact ? 40.0 : 48.0;
    final horizontalPadding = isCompact ? 16.0 : 24.0;

    Color backgroundColor;
    Color textColor;
    Border? border;

    switch (variant) {
      case CoveButtonVariant.primary:
        backgroundColor = colors.accentPrimary;
        textColor = isDark ? const Color(0xFF0B1F1E) : const Color(0xFFFFFFFF);
        border = null;
        break;
      case CoveButtonVariant.secondary:
        backgroundColor = Colors.transparent;
        textColor = colors.textPrimary;
        border = Border.all(
          color: colors.textMuted.withValues(alpha: 0.3),
          width: 1.5,
        );
        break;
      case CoveButtonVariant.ghost:
        backgroundColor = Colors.transparent;
        textColor = colors.textPrimary;
        border = null;
        break;
    }

    final buttonStyle = TextStyle(
      fontFamily: 'GeneralSans',
      fontSize: isCompact ? 14 : 15,
      fontWeight: FontWeight.w600,
      color: onPressed == null ? textColor.withValues(alpha: 0.38) : textColor,
    );

    Widget content = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: isCompact ? 16 : 18,
            height: isCompact ? 16 : 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        Text(label, style: buttonStyle),
      ],
    );

    final buttonContainer = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: onPressed == null
            ? backgroundColor.withValues(alpha: 0.5)
            : backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: border,
      ),
      child: content,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(999),
        child: isFullWidth
            ? SizedBox(width: double.infinity, child: buttonContainer)
            : buttonContainer,
      ),
    );
  }
}
