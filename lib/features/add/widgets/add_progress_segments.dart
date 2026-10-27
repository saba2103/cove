import 'package:flutter/material.dart';

import '../../../core/shape/cove_shape.dart';
import '../../../core/theme/cove_tokens.dart';

/// Segmented step progress bar (`design/specs/14-add-flow.md` §2.2).
///
/// Renders [totalSteps] horizontal segments, filled in `accentFill` up to and
/// including [currentStep] (1-based: `1..totalSteps`), and in `lineStrong` for
/// remaining steps.
class AddProgressSegments extends StatelessWidget {
  /// 1-based current step index (`1..totalSteps`).
  final int currentStep;

  /// Total number of steps in the current draft path.
  final int totalSteps;

  static const double kSegmentHeight = 3.0; // (literal) 3dp segment bar height

  const AddProgressSegments({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  }) : assert(totalSteps >= 1, 'totalSteps must be at least 1.');

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final clampedCurrent = currentStep.clamp(0, totalSteps);

    return Semantics(
      container: true,
      label: 'Step $clampedCurrent of $totalSteps',
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < totalSteps; i++) ...[
              if (i > 0) const SizedBox(width: CoveSpace.xs),
              Expanded(
                child: Container(
                  height: kSegmentHeight,
                  decoration: CoveShape.decoration(
                    CoveRadius.pill,
                    color: i < clampedCurrent ? cv.accentFill : cv.lineStrong,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
