import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';

class CoveToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const CoveToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    const width = 46.0;
    const height = 26.0;
    const knobSize = 20.0;
    const padding = 3.0;

    final knobColorOn =
        isDark ? const Color(0xFF0B1F1E) : const Color(0xFFFFFFFF);
    final knobColorOff = colors.textMuted;

    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        width: width,
        height: height,
        padding: const EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: value ? colors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: value
              ? null
              : Border.all(
                  color: colors.textMuted.withValues(alpha: 0.35),
                  width: 1.5,
                ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: knobSize,
            height: knobSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? knobColorOn : knobColorOff,
            ),
          ),
        ),
      ),
    );
  }
}
