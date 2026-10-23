import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';
import 'cove_round_button.dart';

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
          decoration: BoxDecoration(
            color: isActive ? cv.accentWash : Colors.transparent,
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveRadius.pill),
            ),
            border: Border.all(
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
/// - Action: one [CoveRoundButton], trailing edge of its drawn circle flush to
///   [CoveSpace.gutter].
class CovePageHeader extends StatelessWidget {
  final String title;
  final String? readout;
  final CoveRoundButton? leading;
  final Widget? trailingAccessory;
  final CoveRoundButton? action;
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
    this.trailingAccessory,
    this.action,
    this.trailingPill,
  }) : assert(
          action == null || trailingPill == null,
          'Provide at most one trailing control (action or trailingPill).',
        );

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final hasLeading = leading != null;
    final hasTrailingRound = action != null;
    final hasTrailingPill = trailingPill != null;
    final hasReadout = readout != null && readout!.isNotEmpty;

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

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinHeight),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: CoveSpace.gutter,
              right: CoveSpace.gutter,
              top: kTopPadding,
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
                  if (trailingAccessory != null) ...[
                    const SizedBox(width: CoveSpace.sm),
                    SizedBox(
                      height: _kLineBoxHeight,
                      child: Center(child: trailingAccessory!),
                    ),
                  ],
                  if (hasTrailingRound) ...[
                    const SizedBox(width: CoveSpace.md),
                    const SizedBox(
                      width: CoveSize.buttonRound,
                      height: _kLineBoxHeight,
                    ),
                  ] else if (hasTrailingPill) ...[
                    const SizedBox(width: CoveSpace.md),
                    SizedBox(
                      height: _kLineBoxHeight,
                      child: Center(child: trailingPill!),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (hasLeading)
            Positioned(
              left: CoveSpace.gutter - _kHitBleed,
              top: kTopPadding + (_kLineBoxHeight - CoveSize.hit) / 2,
              child: leading!,
            ),
          if (hasTrailingRound)
            Positioned(
              right: CoveSpace.gutter - _kHitBleed,
              top: kTopPadding + (_kLineBoxHeight - CoveSize.hit) / 2,
              child: action!,
            ),
        ],
      ),
    );
  }
}
