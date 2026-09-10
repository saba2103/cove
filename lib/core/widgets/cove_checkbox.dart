import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';

class CoveCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;

  const CoveCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    final checkmarkColor =
        isDark ? const Color(0xFF0B1F1E) : const Color(0xFFFFFFFF);

    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: value ? colors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: value
              ? null
              : Border.all(
                  color: colors.textMuted.withValues(alpha: 0.5),
                  width: 1.5,
                ),
        ),
        alignment: Alignment.center,
        child: value
            ? Icon(
                Icons.check,
                size: size * 0.72,
                color: checkmarkColor,
                weight: 600,
              )
            : null,
      ),
    );
  }
}

class CoveChecklistRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const CoveChecklistRow({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return InkWell(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      splashColor: colors.accentPrimary.withValues(alpha: 0.05),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CoveCheckbox(
              value: value,
              onChanged: onChanged,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: value ? colors.textMuted : colors.textPrimary,
                      decoration: value
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: colors.textMuted,
                    ),
                    child: Text(title),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: colors.textSubtle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
