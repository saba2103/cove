import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';
import 'cove_card.dart';

class CoveGroupedCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const CoveGroupedCard({
    super.key,
    required this.children,
    this.margin,
    this.borderRadius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final separatedChildren = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      separatedChildren.add(children[i]);
      if (i < children.length - 1) {
        separatedChildren.add(
          Divider(
            height: 1,
            thickness: 1,
            color: colors.borderHairline,
          ),
        );
      }
    }

    return CoveCard(
      padding: EdgeInsets.zero,
      margin: margin,
      borderRadius: borderRadius,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: separatedChildren,
        ),
      ),
    );
  }
}

class CoveGroupedRow extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const CoveGroupedRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final rowContent = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  subtitle!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: colors.accentPrimary.withValues(alpha: 0.08),
          highlightColor: colors.accentPrimary.withValues(alpha: 0.04),
          child: rowContent,
        ),
      );
    }

    return rowContent;
  }
}
