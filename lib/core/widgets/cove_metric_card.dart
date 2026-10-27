import 'package:flutter/material.dart';
import '../shape/cove_shape.dart';
import '../theme/cove_tokens.dart';
import 'cove_section_label.dart';

/// Semantic colour tone for a [CoveMetricCard] figure (`design/specs/06-metric-card.md`).
///
/// Defaults to [accentTint] (`accent.tint`) per spec.
enum CoveMetricValueTone {
  accentTint,
  primary,
  good,
  alert,
  moneyMore,
  moneyLess,
}

/// The small stat tile under a page header (`design/specs/06-metric-card.md`).
///
/// Built to the contract in `design/specs/06-metric-card.md`:
/// - Radius: [CoveRadius.card] (`20dp`)
/// - Fill: `surface.card` (flat — no radial glow, no gradient fill)
/// - Border: `1dp` `line.hairline`
/// - Padding: [CoveSpace.md] (`12dp`) all round
/// - Label: [CoveType.capsCard] in `text.tertiary`
/// - Value: [CoveType.cardFigure] in `accent.tint`, Libre Bodoni
/// - Sub-line: [CoveType.rowSub] in `text.tertiary` (required — a value alone
///   is not a metric)
/// - Grid gap: [CoveSpace.md] (`12dp`), two per row via [CoveMetricGrid]
class CoveMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final CoveMetricValueTone valueTone;
  final VoidCallback? onTap;

  static const double kBorderWidth = 1.0; // (literal) 1dp line.hairline

  const CoveMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
    this.valueTone = CoveMetricValueTone.accentTint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    final Color valueColor = switch (valueTone) {
      CoveMetricValueTone.accentTint => cv.accentTint,
      CoveMetricValueTone.primary => cv.textPrimary,
      CoveMetricValueTone.good => cv.statusGood,
      CoveMetricValueTone.alert => cv.statusAlertText,
      CoveMetricValueTone.moneyMore => cv.moneyMore,
      CoveMetricValueTone.moneyLess => cv.moneyLess,
    };

    final Widget card = Container(
      padding: const EdgeInsets.all(CoveSpace.md),
      decoration: CoveShape.decoration(
        CoveRadius.card,
        color: cv.surfaceCard,
        side: BorderSide(
          color: cv.lineHairline,
          width: kBorderWidth,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoveSectionLabel.card(label: label),
          const SizedBox(height: CoveSpace.sm),
          Text(
            value,
            style: CoveType.cardFigure.copyWith(color: valueColor),
          ),
          const SizedBox(height: CoveSpace.xs),
          Text(
            subtitle,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Metric card grid (`design/specs/06-metric-card.md`).
///
/// Below [CoveSize.compactThreshold] (`360dp`), renders as a single column with
/// [CoveSpace.md] (`12dp`) vertical gaps so `28sp` Libre Bodoni figures never
/// wrap mid-number at `320dp` (`cover`). At [CoveSize.compactThreshold] and
/// above, places up to two [CoveMetricCard] tiles per row with [CoveSpace.md]
/// (`12dp`) horizontal and vertical gaps, constrained to [CoveSize.maxContent]
/// (`420dp`) and centred.
class CoveMetricGrid extends StatelessWidget {
  final List<Widget> children;

  const CoveMetricGrid({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isSingleColumn =
        MediaQuery.sizeOf(context).width < CoveSize.compactThreshold;
    final rows = <Widget>[];

    if (isSingleColumn) {
      for (var i = 0; i < children.length; i++) {
        if (i > 0) {
          rows.add(const SizedBox(height: CoveSpace.md));
        }
        rows.add(children[i]);
      }
    } else {
      for (var i = 0; i < children.length; i += 2) {
        if (i > 0) {
          rows.add(const SizedBox(height: CoveSpace.md));
        }
        final first = children[i];
        final second = i + 1 < children.length ? children[i + 1] : null;
        rows.add(
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: first),
                if (second != null) ...[
                  const SizedBox(width: CoveSpace.md),
                  Expanded(child: second),
                ],
              ],
            ),
          ),
        );
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: CoveSize.maxContent),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: rows,
        ),
      ),
    );
  }
}
