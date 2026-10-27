import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';

class CoveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double radius;
  final double? borderRadius;
  final Color? backgroundColor;
  final Border? border;

  const CoveCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.onTap,
    this.radius = CoveRadius.card,
    this.borderRadius,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;
    final effectiveRadius = borderRadius ?? radius;

    final BorderSide effectiveSide = border != null
        ? border!.top
        : (isDark
            ? BorderSide.none
            : BorderSide(color: colors.borderHairline, width: 1.0));

    final cardContent = Container(
      padding: padding,
      decoration: CoveShape.decoration(
        effectiveRadius,
        color: backgroundColor ?? colors.surfaceCard,
        side: effectiveSide,
      ),
      child: child,
    );

    if (onTap != null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          shape: CoveShape.border(effectiveRadius),
          child: InkWell(
            onTap: onTap,
            customBorder: CoveShape.border(effectiveRadius),
            highlightColor: colors.accentPrimary.withValues(alpha: 0.05),
            splashColor: colors.accentPrimary.withValues(alpha: 0.08),
            child: cardContent,
          ),
        ),
      );
    }

    if (margin != null) {
      return Padding(
        padding: margin!,
        child: cardContent,
      );
    }

    return cardContent;
  }
}
