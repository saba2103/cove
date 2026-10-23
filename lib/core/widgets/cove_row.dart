import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';
import 'cove_avatar.dart';

/// Semantic colour tone for a [CoveRow] trailing amount (`design/specs/03-row.md`).
///
/// Amounts are `text.primary` ([neutral]) by default; [more] (`money.more`) and
/// [less] (`money.less`) must always be accompanied by a sign or a word.
enum CoveRowAmountTone {
  neutral,
  more,
  less,
}

/// The standard 52dp interactive row primitive (`design/specs/03-row.md`).
///
/// Built to the contract in `design/specs/03-row.md`:
/// - Height: [CoveSize.row] (`52dp`) — vertical padding is derived as
///   `(row - content) / 2`.
/// - Hit plate: [CoveSpace.hitPlate] (`12dp`) horizontal padding with a
///   `-CoveSpace.hitPlate` negative horizontal margin so the pressed/hover
///   plate (`surface.row`, radius [CoveRadius.inline]) bleeds past the text to
///   the gutter edge.
/// - Leading avatar: [CoveSize.avatarRow] (`28dp`), separated from text by
///   [CoveSpace.md] (`12dp`).
/// - Title: [CoveType.rowTitle] in `text.primary`.
/// - Sub-line: [CoveType.rowSub] in `text.tertiary`.
/// - Trailing amount: [CoveType.cardFigure] in `text.primary` (Libre Bodoni),
///   or `money.more` / `money.less` when [amountTone] is set.
/// - Divider: `line.hairline`, inset to the text edge (`40dp` when an avatar
///   is present, `0dp` otherwise), omitted on the last row ([isLast] /
///   `showDivider: false`).
class CoveRow extends StatefulWidget {
  final String title;
  final String? subtitle;
  final CoveAvatar? avatar;
  final Widget? leading;
  final String? amount;
  final CoveRowAmountTone amountTone;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showDivider;
  final bool isLast;
  final bool isPressed;
  final String? semanticLabel;

  static const double _kDividerHeight = 1.0; // (literal) 1dp hairline rule
  static const double _kSubtitleGap = 2.0; // (literal) tight title->sub gap

  const CoveRow({
    super.key,
    required this.title,
    this.subtitle,
    this.avatar,
    this.leading,
    this.amount,
    this.amountTone = CoveRowAmountTone.neutral,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.showDivider = true,
    this.isLast = false,
    this.isPressed = false,
    this.semanticLabel,
  }) : assert(
          avatar == null || leading == null,
          'Provide at most one of avatar or leading.',
        ),
        assert(
          amount == null || trailing == null,
          'Provide at most one of amount or trailing.',
        );

  @override
  State<CoveRow> createState() => _CoveRowState();
}

class _CoveRowState extends State<CoveRow> {
  bool _pressed = false;
  bool _hovered = false;

  bool get _interactive =>
      widget.onTap != null || widget.onLongPress != null;

  void _handleTapDown(TapDownDetails _) {
    if (!_interactive) return;
    setState(() => _pressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  void _handleTapCancel() {
    if (_pressed) {
      setState(() => _pressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);
    final showPlate = widget.isPressed || _pressed || _hovered;

    final Widget? leadingWidget = widget.avatar ?? widget.leading;
    final hasLeading = leadingWidget != null;
    final hasSubtitle =
        widget.subtitle != null && widget.subtitle!.isNotEmpty;
    final hasAmount = widget.amount != null && widget.amount!.isNotEmpty;
    final hasTrailing = hasAmount || widget.trailing != null;

    final Color amountColor = switch (widget.amountTone) {
      CoveRowAmountTone.neutral => cv.textPrimary,
      CoveRowAmountTone.more => cv.moneyMore,
      CoveRowAmountTone.less => cv.moneyLess,
    };

    final double textInset =
        hasLeading ? CoveSize.avatarRow + CoveSpace.md : 0.0;
    final bool renderDivider =
        widget.showDivider && !widget.isLast && !showPlate;

    return Semantics(
      button: _interactive,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor:
            _interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: _interactive ? (_) => setState(() => _hovered = true) : null,
        onExit: _interactive ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CoveSize.row),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // Negative-margin hit plate (-CoveSpace.hitPlate horizontal bleed)
                Positioned(
                  left: -CoveSpace.hitPlate,
                  right: -CoveSpace.hitPlate,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: duration,
                      curve: CoveMotion.easing,
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.hitPlate,
                      ),
                      decoration: BoxDecoration(
                        color: showPlate ? cv.surfaceRow : Colors.transparent,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(CoveRadius.inline),
                        ),
                      ),
                    ),
                  ),
                ),

                // Row content (padding derived as (CoveSize.row - content) / 2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: CoveSpace.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (hasLeading) ...[
                        SizedBox(
                          width: CoveSize.avatarRow,
                          child: Center(child: leadingWidget),
                        ),
                        const SizedBox(width: CoveSpace.md),
                      ],
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CoveType.rowTitle.copyWith(
                                color: cv.textPrimary,
                              ),
                            ),
                            if (hasSubtitle) ...[
                              const SizedBox(height: CoveRow._kSubtitleGap),
                              Text(
                                widget.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CoveType.rowSub.copyWith(
                                  color: cv.textTertiary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (hasTrailing) ...[
                        const SizedBox(width: CoveSpace.md),
                        if (hasAmount)
                          Text(
                            widget.amount!,
                            style: CoveType.cardFigure.copyWith(
                              color: amountColor,
                            ),
                          )
                        else
                          widget.trailing!,
                      ],
                    ],
                  ),
                ),

                // Hairline divider inset to the text edge, omitted on last row
                if (renderDivider)
                  Positioned(
                    left: textInset,
                    right: 0,
                    bottom: 0,
                    height: CoveRow._kDividerHeight,
                    child: ColoredBox(color: cv.lineHairline),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
