import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

/// Visual variant of [CoveRoundButton].
///
/// Per `design/specs/04-round-button.md`:
/// - [gold]: `accent.fill` background, `text.onAccent` icon. Reserved for the
///   single primary "add" action on a screen.
/// - [ghost]: transparent background, 1dp `line.strong` border,
///   `text.secondary` icon. Used for back, close, menu, and secondary actions.
enum CoveRoundButtonVariant {
  ghost,
  gold,
}

/// Every circular action in Cove: header actions, add, back, sheet close, and
/// inline stepper chevrons.
///
/// Drawn diameter is [CoveSize.buttonRound] (40dp) inside an invisible
/// [CoveSize.hit] (48dp) tap target. The [CoveRoundButton.stepper] constructor
/// builds the 24dp inline stepper chevron sibling without the 48dp hit target.
class CoveRoundButton extends StatefulWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onPressed;
  final CoveRoundButtonVariant variant;
  final String? tooltip;
  final String? semanticLabel;
  final bool isStepper;
  final bool isPressed;

  static const double _kIconSize = 20.0; // (literal) per 04-round-button.md
  static const double _kStepperDiameter = 24.0; // (literal) per 04-round-button.md
  static const double _kStepperIconSize = 14.0; // (literal)
  static const double _kBorderWidth = 1.0; // (literal) 1dp line.strong border
  static const double _kGoldPressAlpha = 0.12; // (literal) 12% black overlay per 04-round-button.md

  const CoveRoundButton({
    super.key,
    this.icon,
    this.child,
    this.onPressed,
    this.variant = CoveRoundButtonVariant.ghost,
    this.tooltip,
    this.semanticLabel,
    this.isPressed = false,
  })  : isStepper = false,
        assert(icon != null || child != null, 'Provide either icon or child.');

  /// Smaller 24dp inline stepper chevron sibling inside a row or day header.
  /// Does not carry the 48dp header action hit target.
  const CoveRoundButton.stepper({
    super.key,
    this.icon,
    this.child,
    this.onPressed,
    this.variant = CoveRoundButtonVariant.ghost,
    this.tooltip,
    this.semanticLabel,
    this.isPressed = false,
  })  : isStepper = true,
        assert(icon != null || child != null, 'Provide either icon or child.');

  @override
  State<CoveRoundButton> createState() => _CoveRoundButtonState();
}

class _CoveRoundButtonState extends State<CoveRoundButton> {
  bool _pressing = false;

  bool get _showPressOverlay => widget.isPressed || _pressing;

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed == null) return;
    setState(() => _pressing = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (_pressing) {
      setState(() => _pressing = false);
    }
  }

  void _handleTapCancel() {
    if (_pressing) {
      setState(() => _pressing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final isGold = widget.variant == CoveRoundButtonVariant.gold;

    final fillColor = isGold ? cv.accentFill : Colors.transparent;
    final iconColor = isGold ? cv.textOnAccent : cv.textSecondary;
    final border = isGold
        ? null
        : Border.all(
            color: cv.lineStrong,
            width: CoveRoundButton._kBorderWidth,
          );

    final drawnDiameter = widget.isStepper
        ? CoveRoundButton._kStepperDiameter
        : CoveSize.buttonRound;
    final hitDiameter =
        widget.isStepper ? CoveRoundButton._kStepperDiameter : CoveSize.hit;
    final iconSize = widget.isStepper
        ? CoveRoundButton._kStepperIconSize
        : CoveRoundButton._kIconSize;

    final duration = CoveMotion.q(context);

    final Widget iconWidget = IconTheme(
      data: IconThemeData(
        color: iconColor,
        size: iconSize,
      ),
      child: widget.child ??
          Icon(
            widget.icon,
            size: iconSize,
            color: iconColor,
          ),
    );

    final pressOverlayColor = isGold
        ? Colors.black.withValues(alpha: CoveRoundButton._kGoldPressAlpha)
        : cv.accentWash;

    final Widget drawnCircle = SizedBox(
      width: drawnDiameter,
      height: drawnDiameter,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          border: border,
        ),
        child: AnimatedContainer(
          duration: duration,
          curve: CoveMotion.easing,
          decoration: BoxDecoration(
            color: _showPressOverlay ? pressOverlayColor : Colors.transparent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: iconWidget,
        ),
      ),
    );

    Widget interactive = Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.semanticLabel ?? widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: widget.onPressed != null ? _handleTapDown : null,
        onTapUp: widget.onPressed != null ? _handleTapUp : null,
        onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
        child: SizedBox(
          width: hitDiameter,
          height: hitDiameter,
          child: Center(
            child: drawnCircle,
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      interactive = Tooltip(
        message: widget.tooltip!,
        child: interactive,
      );
    }

    return interactive;
  }
}
