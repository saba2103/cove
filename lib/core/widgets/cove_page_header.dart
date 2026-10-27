import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/cove_theme.dart';
import 'cove_round_button.dart';

/// Pads a page below the status-bar top inset (`MediaQuery.viewPaddingOf(context).top`),
/// paints the status-bar area with `surface.canvas` so scrolled content never
/// shows under the clock and icons, and applies [CoveTheme.overlayStyleFor]
/// for the active brightness.
class CovePageInsets extends StatelessWidget {
  final Widget child;
  final bool bottom;

  const CovePageInsets({
    super.key,
    required this.child,
    this.bottom = false,
  });

  /// Effective top status-bar inset (`max(viewPadding.top, padding.top)`).
  static double topOf(BuildContext context) {
    final vp = MediaQuery.viewPaddingOf(context).top;
    final p = MediaQuery.paddingOf(context).top;
    return vp > p ? vp : p;
  }

  /// Effective bottom gesture-bar inset (`max(viewPadding.bottom, padding.bottom)`).
  static double bottomOf(BuildContext context) {
    final vp = MediaQuery.viewPaddingOf(context).bottom;
    final p = MediaQuery.paddingOf(context).bottom;
    return vp > p ? vp : p;
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final mq = MediaQuery.of(context);
    final topInset = topOf(context);
    final bottomInset = bottom ? bottomOf(context) : 0.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: CoveTheme.overlayStyleFor(Theme.of(context).brightness),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (topInset > 0)
            ColoredBox(
              key: const ValueKey('cove_status_bar_band'),
              color: cv.surfaceCanvas,
              child: SizedBox(
                height: topInset,
                width: double.infinity,
              ),
            ),
          Expanded(
            child: ClipRect(
              child: MediaQuery(
                data: mq.copyWith(
                  padding: mq.padding.copyWith(
                    top: 0.0,
                    bottom: bottom ? 0.0 : mq.padding.bottom,
                  ),
                  viewPadding: mq.viewPadding.copyWith(
                    top: 0.0,
                    bottom: bottom ? 0.0 : mq.viewPadding.bottom,
                  ),
                ),
                child: child,
              ),
            ),
          ),
          if (bottomInset > 0)
            ColoredBox(
              color: cv.surfaceCanvas,
              child: SizedBox(
                height: bottomInset,
                width: double.infinity,
              ),
            ),
        ],
      ),
    );
  }
}

/// Optional 28dp pill control for a header verb that has no glyph (the EMI
/// "What if…" exception in `design/specs/01-page-header.md`).
class CoveHeaderPill extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isActive;

  static const double kHeight = 28.0; // (literal) per 01-page-header.md
  static const double _kBorderWidth = 1.0; // (literal)

  const CoveHeaderPill({
    super.key,
    required this.label,
    this.onPressed,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);

    return Semantics(
      button: true,
      selected: isActive,
      enabled: onPressed != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: duration,
          curve: CoveMotion.easing,
          height: kHeight,
          padding: const EdgeInsets.symmetric(horizontal: CoveSpace.md),
          alignment: Alignment.center,
          decoration: CoveShape.decoration(
            CoveRadius.pill,
            color: isActive ? cv.accentWash : Colors.transparent,
            side: BorderSide(
              color: isActive ? cv.accentFill : cv.lineStrong,
              width: _kBorderWidth,
            ),
          ),
          child: Text(
            label,
            style: CoveType.rowSub.copyWith(
              color: isActive ? cv.accentText : cv.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The title block at the top of a destination. One per screen, directly below
/// the status-bar inset.
///
/// Built to the contract in `design/specs/01-page-header.md`:
/// - Height: `56` `(literal)` — grows if the title wraps.
/// - Padding: [CoveSpace.gutter] horizontal, `20` top `(literal)`, `0` bottom.
/// - Title: [CoveType.title] — 28sp Libre Bodoni w500 on a 36dp line box.
/// - Trailing readout: [CoveType.readout] in `text.tertiary`, baseline-aligned
///   to the title, separated by [CoveSpace.md].
/// - Actions: up to three [CoveRoundButton]s (`actions.length <= 3`),
///   right-aligned with [CoveSpace.sm] between drawn circles and the trailing
///   edge flush to [CoveSpace.gutter].
class CovePageHeader extends StatelessWidget {
  final String title;
  final String? readout;
  final CoveRoundButton? leading;
  final List<CoveRoundButton> actions;
  final CoveHeaderPill? trailingPill;

  static const double kMinHeight = 56.0; // (literal) per 01-page-header.md
  static const double kTopPadding = 20.0; // (literal) per 01-page-header.md
  static const double _kLineBoxHeight = 36.0; // (literal) 28sp * 1.2857 = 36dp
  static const double _kHitBleed =
      (CoveSize.hit - CoveSize.buttonRound) / 2; // 4.0dp invisible hit ring

  const CovePageHeader({
    super.key,
    required this.title,
    this.readout,
    this.leading,
    this.actions = const [],
    this.trailingPill,
  }) : assert(
          actions.length <= 3,
          'CovePageHeader supports at most 3 actions.',
        );

  @override
  Widget build(BuildContext context) {
    assert(
      leading == null || !leading!.isStepper,
      'Header leading button must be a full CoveRoundButton (40dp drawn, 48dp hit), not a stepper.',
    );
    assert(
      actions.every((b) => !b.isStepper),
      'Header actions must be full CoveRoundButtons (40dp drawn, 48dp hit), not steppers.',
    );

    final cv = context.cv;
    final hasLeading = leading != null;
    final hasActions = actions.isNotEmpty;
    final hasTrailingPill = trailingPill != null;
    final hasReadout = readout != null && readout!.isNotEmpty;
    final double actionsDrawnWidth = hasActions
        ? actions.length * CoveSize.buttonRound +
            (actions.length - 1) * CoveSpace.sm
        : 0.0;

    final Widget titleWidget = Text(
      title,
      style: CoveType.title.copyWith(color: cv.textPrimary),
    );

    final Widget titleAndReadout = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (hasReadout) ...[
          titleWidget,
          const SizedBox(width: CoveSpace.md),
          Flexible(
            child: Text(
              readout!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: CoveType.readout.copyWith(color: cv.textTertiary),
            ),
          ),
        ] else
          Flexible(child: titleWidget),
      ],
    );

    final topInset = CovePageInsets.topOf(context);
    final effectiveTopPadding = topInset + kTopPadding;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: topInset + kMinHeight),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: CoveSpace.gutter,
              right: CoveSpace.gutter,
              top: effectiveTopPadding,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _kLineBoxHeight),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasLeading) ...[
                    const SizedBox(
                      width: CoveSize.buttonRound,
                      height: _kLineBoxHeight,
                    ),
                    const SizedBox(width: CoveSpace.md),
                  ],
                  Expanded(child: titleAndReadout),
                  if (hasTrailingPill) ...[
                    const SizedBox(width: CoveSpace.sm),
                    SizedBox(
                      height: _kLineBoxHeight,
                      child: Center(child: trailingPill!),
                    ),
                  ],
                  if (hasActions) ...[
                    const SizedBox(width: CoveSpace.sm),
                    SizedBox(
                      width: actionsDrawnWidth,
                      height: _kLineBoxHeight,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasLeading)
            Positioned(
              left: CoveSpace.gutter - _kHitBleed,
              top: effectiveTopPadding + (_kLineBoxHeight - CoveSize.hit) / 2,
              child: leading!,
            ),
          if (hasActions)
            Positioned(
              right: CoveSpace.gutter - _kHitBleed,
              top: effectiveTopPadding + (_kLineBoxHeight - CoveSize.hit) / 2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0)
                      const SizedBox(width: CoveSpace.sm - 2 * _kHitBleed),
                    actions[i],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
