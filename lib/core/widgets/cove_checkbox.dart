import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

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
    final duration = CoveMotion.q(context);

    final box = AnimatedContainer(
      duration: duration,
      curve: CoveMotion.easing,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: value ? cv.accentFill : Colors.transparent,
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveSpace.xs),
        ),
        border: value
            ? null
            : Border.all(
                color: cv.textTertiary,
                width: _kBorderWidth,
              ),
      ),
      alignment: Alignment.center,
      child: value
          ? Icon(
              Icons.check,
              size: size * 0.72,
              color: cv.textOnAccent,
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
          children: [
            CoveCheckbox(
              value: value,
              onChanged: onChanged,
            ),
            const SizedBox(width: CoveSpace.md),
            Expanded(
              child: Column(
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
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: CoveSpace.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
