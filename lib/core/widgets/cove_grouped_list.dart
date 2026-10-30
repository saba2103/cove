import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';
import 'cove_card.dart';
import 'cove_reflow_row.dart';

class CoveGroupedCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final double radius;

  const CoveGroupedCard({
    super.key,
    required this.children,
    this.margin,
    this.radius = CoveRadius.card,
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
      radius: radius,
      child: CoveShape.clip(
        radius,
        Column(
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
    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        title,
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          subtitle!,
        ],
      ],
    );

    final Widget bodyContent;
    if (isScaled && trailing != null && trailing is! Icon) {
      bodyContent = CoveReflowRow(
        body: titleColumn,
        trailing: trailing!,
        trailingGap: CoveSpace.md,
        stackGap: CoveSpace.xs,
        allowStack: true,
      );
    } else {
      bodyContent = Row(
        children: [
          Expanded(child: titleColumn),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      );
    }

    final rowContent = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: padding,
      child: Row(
        crossAxisAlignment:
            isScaled ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 14),
          ],
          Expanded(child: bodyContent),
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
