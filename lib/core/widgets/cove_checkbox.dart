import 'package:flutter/material.dart';
import '../shape/cove_shape.dart';
import '../theme/cove_tokens.dart';
import 'cove_reflow_row.dart';
import 'slips/cove_slip.dart';

class CoveCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  final double? hitSize;

  static const double _kDefaultBoxSize =
      20.0; // (literal) 20dp checkbox square between 16 and 24 avatar tokens
  static const double _kBorderWidth =
      1.5; // (literal) 1.5dp unchecked box stroke

  const CoveCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = _kDefaultBoxSize,
    this.hitSize,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final slipPalette = CoveSlipScope.maybeOf(context);
    final duration = CoveMotion.q(context);
    final checkedFill = slipPalette?.accentFill ?? cv.accentFill;
    final checkIconColor = slipPalette?.variant == CoveSlipVariant.paper
        ? CoveTokens.dark.textPrimary
        : cv.textOnAccent;
    final uncheckedBorder = slipPalette?.mark ?? cv.lineControl;

    final box = AnimatedContainer(
      duration: duration,
      curve: CoveMotion.easing,
      width: size,
      height: size,
      decoration: CoveShape.decoration(
        CoveSpace.xs,
        color: value ? checkedFill : Colors.transparent,
        side: value
            ? BorderSide.none
            : BorderSide(
                color: uncheckedBorder,
                width: _kBorderWidth,
              ),
      ),
      alignment: Alignment.center,
      child: value
          ? Icon(
              Icons.check,
              size: size * 0.72,
              color: checkIconColor,
              weight: 600,
            )
          : null,
    );

    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: hitSize != null
          ? SizedBox(
              width: hitSize,
              height: hitSize,
              child: Center(child: box),
            )
          : box,
    );
  }
}

class CoveChecklistRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const double _kHorizontalPadding =
      16.0; // (literal) 16dp legacy checklist row horizontal inset

  const CoveChecklistRow({
    super.key,
    required this.value,
    required this.onChanged,
    this.onTap,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);
    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: duration,
          style: CoveType.rowTitle.copyWith(
            color: value ? cv.textSecondary : cv.textPrimary,
            decoration: value
                ? TextDecoration.lineThrough
                : TextDecoration.none,
            decorationColor: cv.textSecondary,
          ),
          child: Text(title),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: CoveSpace.xs),
          Text(
            subtitle!,
            style: CoveType.rowSub.copyWith(
              color: cv.textTertiary,
            ),
          ),
        ],
      ],
    );

    final Widget bodyContent;
    if (isScaled && trailing != null && trailing is! Icon) {
      bodyContent = CoveReflowRow(
        body: titleColumn,
        trailing: trailing!,
        trailingGap: CoveSpace.sm,
        stackGap: CoveSpace.xs,
        allowStack: true,
      );
    } else {
      bodyContent = Row(
        children: [
          Expanded(child: titleColumn),
          if (trailing != null) ...[
            const SizedBox(width: CoveSpace.sm),
            trailing!,
          ],
        ],
      );
    }

    return InkWell(
      onTap: onTap ?? (onChanged != null ? () => onChanged!(!value) : null),
      onLongPress: onLongPress,
      splashColor: cv.accentWash,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _kHorizontalPadding,
          vertical: CoveSpace.md,
        ),
        child: Row(
          crossAxisAlignment:
              isScaled ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(top: isScaled ? CoveSpace.xs : 0),
              child: CoveCheckbox(
                value: value,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: CoveSpace.md),
            Expanded(child: bodyContent),
          ],
        ),
      ),
    );
  }
}
