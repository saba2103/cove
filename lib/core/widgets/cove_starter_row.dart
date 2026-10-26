import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

/// Full-width starter row below a [CoveSeedCard] on Today and Commitments
/// (`design/specs/16-first-run.md` §2).
///
/// Each row has a glyph in a rounded square, a title, a short second line
/// explaining *why this one*, and a chevron. Tapping a starter row opens the
/// Add sheet pre-selected to a kind or preset — it creates nothing on its own.
class CoveStarterRow extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget? leading;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double _kLeadingBoxSize = CoveSize.avatarHeader + CoveSpace.xs; // 36dp
  static const double _kLeadingBoxRadius = CoveRadius.inline - 6.0; // 10dp
  static const double _kIconSize = 18.0;
  static const double _kBorderWidth = 1.0;
  static const double _kSubtitleGap = 2.0;
  static const double _kHorizontalPadding = CoveSpace.md + 2.0; // 14dp

  const CoveStarterRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.leading,
    this.onTap,
    this.semanticLabel,
  }) : assert(
          icon == null || leading == null,
          'Provide at most one of icon or leading.',
        );

  @override
  State<CoveStarterRow> createState() => _CoveStarterRowState();
}

class _CoveStarterRowState extends State<CoveStarterRow> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _interactive => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);
    final active = _pressed || _hovered;

    final Widget glyph = widget.leading ??
        Icon(
          widget.icon ?? Icons.add_rounded,
          size: CoveStarterRow._kIconSize,
          color: cv.accentText,
        );

    return Semantics(
      button: _interactive,
      label: widget.semanticLabel ?? '${widget.title}, ${widget.subtitle}',
      child: MouseRegion(
        cursor:
            _interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: _interactive ? (_) => setState(() => _hovered = true) : null,
        onExit: _interactive ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: _interactive ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _interactive ? (_) => setState(() => _pressed = false) : null,
          onTapCancel:
              _interactive ? () => setState(() => _pressed = false) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CoveSize.hit),
            child: AnimatedContainer(
              duration: duration,
              curve: CoveMotion.easing,
              padding: const EdgeInsets.symmetric(
                horizontal: CoveStarterRow._kHorizontalPadding,
                vertical: CoveSpace.md,
              ),
              decoration: BoxDecoration(
                color: active ? cv.surfaceRow : cv.surfaceCard,
                borderRadius: const BorderRadius.all(
                  Radius.circular(CoveRadius.inline),
                ),
                border: Border.all(
                  color: active ? cv.lineStrong : cv.lineHairline,
                  width: CoveStarterRow._kBorderWidth,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: CoveStarterRow._kLeadingBoxSize,
                    height: CoveStarterRow._kLeadingBoxSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: cv.accentWash,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(CoveStarterRow._kLeadingBoxRadius),
                        ),
                      ),
                      child: Center(child: glyph),
                    ),
                  ),
                  const SizedBox(width: CoveSpace.md),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: CoveType.rowTitle.copyWith(
                            color: cv.textPrimary,
                          ),
                        ),
                        const SizedBox(height: CoveStarterRow._kSubtitleGap),
                        Text(
                          widget.subtitle,
                          style: CoveType.rowSub.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: CoveSpace.sm),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: CoveStarterRow._kIconSize,
                    color: cv.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
