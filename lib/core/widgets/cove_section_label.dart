import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

/// The two variants of [CoveSectionLabel] defined in `design/specs/02-section-label.md`.
enum CoveSectionLabelVariant {
  /// On the page: [CoveType.capsPage] (12sp / .15em / w700), followed by a
  /// full-width hairline rule in `line.hairline`.
  page,

  /// Inside a card or metric tile: [CoveType.capsCard] (11sp / .14em / w700),
  /// without the page-level hairline rule.
  card,
}

/// The caps line that opens a section (`design/specs/02-section-label.md`).
///
/// **There are two. Not three.**
/// - [CoveSectionLabelVariant.page] (`CoveType.capsPage`, 12sp / .15em / w700):
///   A section heading on the scroll surface, followed by a full-width hairline
///   rule in `line.hairline`.
/// - [CoveSectionLabelVariant.card] (`CoveType.capsCard`, 11sp / .14em / w700):
///   A label within a card or metric tile.
///
/// Colour is `text.tertiary` in both cases. An optional right-hand [readout]
/// sits on the same alphabetic baseline in [CoveType.readout] (`text.tertiary`).
class CoveSectionLabel extends StatelessWidget {
  final String label;
  final String? readout;
  final CoveSectionLabelVariant variant;

  static const double _kHairlineHeight = 1.0; // (literal) 1dp hairline rule

  const CoveSectionLabel({
    super.key,
    required this.label,
    this.readout,
    this.variant = CoveSectionLabelVariant.page,
  });

  /// Convenience constructor for the `CoveType.capsPage` page-level variant.
  const CoveSectionLabel.page({
    super.key,
    required this.label,
    this.readout,
  }) : variant = CoveSectionLabelVariant.page;

  /// Convenience constructor for the `CoveType.capsCard` card-interior variant.
  const CoveSectionLabel.card({
    super.key,
    required this.label,
    this.readout,
  }) : variant = CoveSectionLabelVariant.card;

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final baseStyle = switch (variant) {
      CoveSectionLabelVariant.page => CoveType.capsPage,
      CoveSectionLabelVariant.card => CoveType.capsCard,
    };

    final labelWidget = Text(
      label.toUpperCase(),
      style: baseStyle.copyWith(color: cv.textTertiary),
    );

    final hasReadout = readout != null && readout!.isNotEmpty;

    final Widget line = hasReadout
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: labelWidget),
              const SizedBox(width: CoveSpace.md),
              Text(
                readout!,
                style: CoveType.readout.copyWith(color: cv.textTertiary),
              ),
            ],
          )
        : labelWidget;

    if (variant == CoveSectionLabelVariant.card) {
      return line;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line,
        const SizedBox(height: CoveSpace.sm),
        ColoredBox(
          color: cv.lineHairline,
          child: const SizedBox(
            width: double.infinity,
            height: _kHairlineHeight,
          ),
        ),
      ],
    );
  }
}
