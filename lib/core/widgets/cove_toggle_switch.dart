import 'package:flutter/material.dart';
import '../shape/cove_shape.dart';
import '../theme/cove_tokens.dart';

class CoveToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _kKnobSize =
      20.0; // (literal) 20dp switch thumb diameter (28dp track - 2 * 4dp inset)
  static const double _kBorderWidth =
      1.5; // (literal) 1.5dp off-track border stroke

  const CoveToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);

    final knobColorOn = cv.textOnAccent;
    final knobColorOff = cv.textSecondary;

    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(!value) : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: duration,
        curve: CoveMotion.easing,
        width: CoveSize.hit,
        height: CoveSize.avatarRow,
        padding: const EdgeInsets.all(CoveSpace.xs),
        decoration: CoveShape.decoration(
          CoveRadius.pill,
          color: value ? cv.accentFill : Colors.transparent,
          side: value
              ? BorderSide.none
              : BorderSide(
                  color: cv.lineStrong,
                  width: _kBorderWidth,
                ),
        ),
        child: AnimatedAlign(
          duration: duration,
          curve: CoveMotion.easing,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: _kKnobSize,
            height: _kKnobSize,
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
