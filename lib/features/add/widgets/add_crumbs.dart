import 'package:flutter/material.dart';

import '../../../core/theme/cove_tokens.dart';

/// A single answered-step crumb in [AddCrumbs] (`design/specs/14-add-flow.md` §2.3).
@immutable
class AddCrumbItem {
  /// The step index or identifier this crumb jumps back to.
  final int stepIndex;

  /// Answered text to display inside the pill (never ellipsized).
  final String label;

  /// Optional callback when tapped.
  final VoidCallback? onTap;

  const AddCrumbItem({
    required this.stepIndex,
    required this.label,
    this.onTap,
  });
}

/// Answered-step crumb pills (`design/specs/14-add-flow.md` §2.3).
///
/// - Renders one pill per answered step before the current step.
/// - Wraps across as many lines as needed; never ellipsizes an answer.
/// - Each crumb carries at least a `48 × 48dp` ([CoveSize.hit]) tap target.
class AddCrumbs extends StatelessWidget {
  final List<AddCrumbItem> crumbs;
  final ValueChanged<int>? onSelectStep;

  static const double _kBorderWidth = 1.0; // (literal) 1dp pill border
  static const double _kPillMinHeight = 34.0; // (literal) visual pill height inside 48dp hit target

  const AddCrumbs({
    super.key,
    required this.crumbs,
    this.onSelectStep,
  });

  @override
  Widget build(BuildContext context) {
    if (crumbs.isEmpty) {
      return const SizedBox.shrink();
    }

    final cv = context.cv;

    return Wrap(
      spacing: CoveSpace.sm,
      runSpacing: CoveSpace.xs,
      children: [
        for (final crumb in crumbs)
          _CrumbPill(
            crumb: crumb,
            cv: cv,
            onTap: crumb.onTap ??
                (onSelectStep != null
                    ? () => onSelectStep!(crumb.stepIndex)
                    : null),
          ),
      ],
    );
  }
}

class _CrumbPill extends StatelessWidget {
  final AddCrumbItem crumb;
  final CoveTokens cv;
  final VoidCallback? onTap;

  const _CrumbPill({
    required this.crumb,
    required this.cv,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrency = crumb.label.trimLeft().startsWith('₹');
    final textStyle = isCurrency
        ? CoveType.readout.copyWith(color: cv.accentText)
        : CoveType.rowSub.copyWith(color: cv.textSecondary);

    final pill = Container(
      constraints: const BoxConstraints(
        minHeight: AddCrumbs._kPillMinHeight,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: CoveSpace.md,
        vertical: CoveSpace.xs,
      ),
      decoration: BoxDecoration(
        color: cv.surfaceRow,
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveRadius.pill),
        ),
        border: Border.all(
          color: cv.lineStrong,
          width: AddCrumbs._kBorderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              crumb.label,
              softWrap: true,
              style: textStyle,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return pill;
    }

    return Semantics(
      container: true,
      button: true,
      label: 'Change ${crumb.label}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.hit,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: pill,
            ),
          ),
        ),
      ),
    );
  }
}
