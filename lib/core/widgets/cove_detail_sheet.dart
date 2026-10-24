import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/cove_tokens.dart';
import 'cove_round_button.dart';
import 'cove_sheet.dart';
import 'slips/cove_slip.dart';

/// Meaning panel configuration for [CoveDetailSheet] (`design/specs/13-detail-sheet.md`).
///
/// Renders on a `surface.row` card (`CoveRadius.card`, `CoveSpace.md` padding)
/// with a `24dp` `(literal)` leading [glyph], [title] in [CoveType.rowTitle] /
/// `text.primary`, and optional [subtitle] in [CoveType.rowSub] /
/// `text.tertiary`.
class CoveDetailMeaningPanel {
  final Widget glyph;
  final String title;
  final String? subtitle;

  const CoveDetailMeaningPanel({
    required this.glyph,
    required this.title,
    this.subtitle,
  });

  /// Convenience constructor using an [IconData] as the `24dp` leading glyph.
  factory CoveDetailMeaningPanel.icon({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? color,
  }) {
    return CoveDetailMeaningPanel(
      glyph: Icon(icon, color: color),
      title: title,
      subtitle: subtitle,
    );
  }
}

/// Primary verb pill action in the bottom row of [CoveDetailSheet].
class CoveDetailVerb {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;

  const CoveDetailVerb({
    required this.label,
    this.icon,
    this.onPressed,
  });
}

/// Overflow menu action inside the `⋯` menu of [CoveDetailSheet].
///
/// Per `design/specs/13-detail-sheet.md`, destructive items must explicitly
/// state what they destroy (e.g. `"Delete this expense"`, never `"Delete"`).
class CoveDetailMenuItem {
  final String label;
  final IconData? icon;
  final VoidCallback? onSelected;
  final bool isDestructive;

  const CoveDetailMenuItem({
    required this.label,
    this.icon,
    this.onSelected,
    this.isDestructive = false,
  });
}

/// Shared detail sheet skeleton (`design/specs/13-detail-sheet.md`).
///
/// One skeleton, many fillings. Knows nothing about any specific record kind:
/// - **Sheet**: [CoveSheet] container.
/// - **Kind line**: `20dp` `(literal)` [kindGlyph], [kindLabel] in
///   [CoveType.capsPage] / `text.primary`, then `· {contextLabel}` in
///   `text.tertiary`. Trailing ghost [CoveRoundButton]s for `⋯` (menu) and `✕`
///   (close). No `✓` in the kind line. Context wraps at cover width and never
///   ellipsizes.
/// - **The slip**: [slip] in the paper variant across both app brightnesses,
///   full content width, [CoveSpace.md] below the kind line.
/// - **Meaning panel**: `surface.row` fill, [CoveRadius.card], [CoveSpace.md]
///   padding, [CoveSpace.gutter] above. `24dp` `(literal)` leading glyph,
///   title in [CoveType.rowTitle] / `text.primary`, one sub-line in
///   [CoveType.rowSub] / `text.tertiary`.
/// - **Verbs**: [CoveSpace.lg] above. [editVerb] plus at most one
///   [secondaryVerb] as equal-width pill buttons ([CoveSpace.md] gap, height
///   [CoveSize.hit], `1dp` `line.strong` border, label [CoveType.rowTitle]).
/// - **Semantics**: Reads the slip's state first, then the meaning panel.
class CoveDetailSheet extends StatelessWidget {
  final Widget kindGlyph;
  final String kindLabel;
  final String? contextLabel;
  final Widget slip;
  final CoveDetailMeaningPanel meaningPanel;
  final CoveDetailVerb? editVerb;
  final CoveDetailVerb? secondaryVerb;
  final List<CoveDetailMenuItem> menuItems;
  final VoidCallback? onClose;
  final bool isMidCommit;
  final bool showGrabHandle;

  static const double kKindGlyphSize = 20.0; // (literal) 20dp kind glyph per 13-detail-sheet.md
  static const double kMeaningGlyphSize = 24.0; // (literal) 24dp leading glyph per 13-detail-sheet.md
  static const double kVerbBorderWidth = 1.0; // (literal) 1dp line.strong border per 13-detail-sheet.md
  static const double kVerbIconSize = 16.0; // (literal) 16dp inline verb icon
  static const double _kViewportReserve = 96.0; // (literal) top sheet headroom

  const CoveDetailSheet({
    super.key,
    required this.kindGlyph,
    required this.kindLabel,
    this.contextLabel,
    required this.slip,
    required this.meaningPanel,
    this.editVerb,
    this.secondaryVerb,
    this.menuItems = const <CoveDetailMenuItem>[],
    this.onClose,
    this.isMidCommit = false,
    this.showGrabHandle = true,
  });

  static bool _isPaperVariant(Widget widget) =>
      widget is CoveSlipObject && widget.variant == CoveSlipVariant.paper;

  /// Presents a [CoveDetailSheet] modally via [CoveSheet.show].
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isMidCommit = false,
    String barrierLabel = 'Dismiss detail sheet',
  }) {
    return CoveSheet.show<T>(
      context: context,
      builder: builder,
      isMidCommit: isMidCommit,
      barrierLabel: barrierLabel,
    );
  }

  String _meaningPanelSemanticLabel() {
    final sub = meaningPanel.subtitle?.trim();
    if (sub != null && sub.isNotEmpty) {
      return '${meaningPanel.title}, $sub';
    }
    return meaningPanel.title;
  }

  @override
  Widget build(BuildContext context) {
    assert(
      _isPaperVariant(slip),
      'CoveDetailSheet requires the slip to use CoveSlipVariant.paper in both modes.',
    );
    final cv = context.cv;
    final hasContext =
        contextLabel != null && contextLabel!.trim().isNotEmpty;
    final trimmedContext = hasContext ? contextLabel!.trim().toUpperCase() : '';
    final normalizedKind = kindLabel.trim().toUpperCase();

    final verbs = <CoveDetailVerb>[
      ?editVerb,
      ?secondaryVerb,
    ];

    final mediaSize = MediaQuery.sizeOf(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    final maxScrollableHeight = (mediaSize.height -
            mediaPadding.vertical -
            _kViewportReserve)
        .clamp(200.0, double.infinity);

    void handleClose() {
      if (onClose != null) {
        onClose!();
      } else {
        Navigator.of(context).maybePop();
      }
    }

    return CoveSheet(
      showGrabHandle: showGrabHandle,
      isMidCommit: isMidCommit,
      onDismiss: handleClose,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxScrollableHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Kind line (no ✓ in the kind line; context wraps and never ellipsizes)
              Semantics(
                sortKey: const OrdinalSortKey(2.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      key: const ValueKey('cove_detail_sheet_kind_glyph'),
                      width: kKindGlyphSize,
                      height: kKindGlyphSize,
                      child: Center(
                        child: IconTheme(
                          data: IconThemeData(
                            size: kKindGlyphSize,
                            color: cv.accentTint,
                          ),
                          child: DefaultTextStyle.merge(
                            style: CoveType.rowTitle.copyWith(
                              color: cv.accentTint,
                            ),
                            child: kindGlyph,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: CoveSpace.sm),
                    Expanded(
                      child: Text.rich(
                        key: const ValueKey('cove_detail_sheet_kind_text'),
                        TextSpan(
                          text: normalizedKind,
                          style: CoveType.capsPage.copyWith(
                            color: cv.textPrimary,
                          ),
                          children: [
                            if (hasContext)
                              TextSpan(
                                text: ' · $trimmedContext',
                                style: CoveType.capsPage.copyWith(
                                  color: cv.textTertiary,
                                ),
                              ),
                          ],
                        ),
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(width: CoveSpace.sm),
                    if (menuItems.isNotEmpty) ...[
                      _CoveDetailMenuButton(
                        items: menuItems,
                        enabled: !isMidCommit,
                      ),
                      const SizedBox(width: CoveSpace.xs),
                    ],
                    CoveRoundButton(
                      key: const ValueKey('cove_detail_sheet_close_button'),
                      icon: Icons.close_rounded,
                      variant: CoveRoundButtonVariant.ghost,
                      semanticLabel: 'Close sheet',
                      onPressed: isMidCommit ? null : handleClose,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: CoveSpace.md),

              // 2. The slip (paper variant in both modes; read first in semantics)
              Semantics(
                sortKey: const OrdinalSortKey(0.0),
                child: slip,
              ),
              const SizedBox(height: CoveSpace.gutter),

              // 3. Meaning panel (read second in semantics, right after the slip)
              Semantics(
                sortKey: const OrdinalSortKey(1.0),
                container: true,
                label: _meaningPanelSemanticLabel(),
                child: ExcludeSemantics(
                  child: Container(
                    key: const ValueKey('cove_detail_sheet_meaning_panel'),
                    padding: const EdgeInsets.all(CoveSpace.md),
                    decoration: BoxDecoration(
                      color: cv.surfaceRow,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(CoveRadius.card),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          key: const ValueKey('cove_detail_sheet_meaning_glyph'),
                          width: kMeaningGlyphSize,
                          height: kMeaningGlyphSize,
                          child: Center(
                            child: IconTheme(
                              data: IconThemeData(
                                size: kMeaningGlyphSize,
                                color: cv.accentTint,
                              ),
                              child: DefaultTextStyle.merge(
                                style: CoveType.rowTitle.copyWith(
                                  color: cv.accentTint,
                                ),
                                child: meaningPanel.glyph,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: CoveSpace.md),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meaningPanel.title,
                                style: CoveType.rowTitle.copyWith(
                                  color: cv.textPrimary,
                                ),
                              ),
                              if (meaningPanel.subtitle != null &&
                                  meaningPanel.subtitle!.trim().isNotEmpty) ...[
                                Text(
                                  meaningPanel.subtitle!,
                                  style: CoveType.rowSub.copyWith(
                                    color: cv.textTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Verbs (Edit, plus at most ONE kind action)
              if (verbs.isNotEmpty) ...[
                const SizedBox(height: CoveSpace.lg),
                Semantics(
                  sortKey: const OrdinalSortKey(3.0),
                  child: Row(
                    children: [
                      for (var i = 0; i < verbs.length; i++) ...[
                        if (i > 0) const SizedBox(width: CoveSpace.md),
                        Expanded(
                          child: _CoveDetailVerbButton(
                            key: ValueKey('cove_detail_sheet_verb_$i'),
                            verb: verbs[i],
                            enabled: !isMidCommit,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CoveDetailVerbButton extends StatefulWidget {
  final CoveDetailVerb verb;
  final bool enabled;

  const _CoveDetailVerbButton({
    super.key,
    required this.verb,
    required this.enabled,
  });

  @override
  State<_CoveDetailVerbButton> createState() => _CoveDetailVerbButtonState();
}

class _CoveDetailVerbButtonState extends State<_CoveDetailVerbButton> {
  bool _pressing = false;

  bool get _canTap => widget.enabled && widget.verb.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);

    return Semantics(
      button: true,
      enabled: _canTap,
      label: widget.verb.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _canTap ? widget.verb.onPressed : null,
        onTapDown: _canTap ? (_) => setState(() => _pressing = true) : null,
        onTapUp: _canTap ? (_) => setState(() => _pressing = false) : null,
        onTapCancel: _canTap ? () => setState(() => _pressing = false) : null,
        child: SizedBox(
          height: CoveSize.hit,
          child: AnimatedContainer(
            duration: duration,
            curve: CoveMotion.easing,
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.md),
            decoration: BoxDecoration(
              color: _pressing ? cv.accentWash : Colors.transparent,
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.pill),
              ),
              border: Border.all(
                color: cv.lineStrong,
                width: CoveDetailSheet.kVerbBorderWidth,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.verb.icon != null) ...[
                  Icon(
                    widget.verb.icon,
                    size: CoveDetailSheet.kVerbIconSize,
                    color: cv.textSecondary,
                  ),
                  const SizedBox(width: CoveSpace.sm),
                ],
                Flexible(
                  child: Text(
                    widget.verb.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CoveType.rowTitle.copyWith(
                      color: cv.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoveDetailMenuButton extends StatelessWidget {
  final List<CoveDetailMenuItem> items;
  final bool enabled;

  const _CoveDetailMenuButton({
    required this.items,
    required this.enabled,
  });

  Future<void> _openMenu(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final cv = context.cv;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(
          box.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<CoveDetailMenuItem>(
      context: context,
      position: position,
      color: cv.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveRadius.card),
        ),
        side: BorderSide(
          color: cv.lineStrong,
          width: CoveDetailSheet.kVerbBorderWidth,
        ),
      ),
      items: [
        for (final item in items)
          PopupMenuItem<CoveDetailMenuItem>(
            value: item,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (item.icon != null) ...[
                  Icon(
                    item.icon,
                    size: CoveDetailSheet.kVerbIconSize,
                    color: item.isDestructive
                        ? cv.statusAlertText
                        : cv.textSecondary,
                  ),
                  const SizedBox(width: CoveSpace.sm),
                ],
                Flexible(
                  child: Text(
                    item.label,
                    style: CoveType.rowTitle.copyWith(
                      color: item.isDestructive
                          ? cv.statusAlertText
                          : cv.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    selected?.onSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    return CoveRoundButton(
      key: const ValueKey('cove_detail_sheet_menu_button'),
      icon: Icons.more_horiz_rounded,
      variant: CoveRoundButtonVariant.ghost,
      semanticLabel: 'More actions',
      onPressed: enabled ? () => _openMenu(context) : null,
    );
  }
}
