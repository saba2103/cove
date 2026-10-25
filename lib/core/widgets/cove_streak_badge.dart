import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

class CoveStreakIndicator extends StatelessWidget {
  final int count;
  final String label;

  const CoveStreakIndicator({
    super.key,
    required this.count,
    this.label = 'days',
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$count',
          style: CoveType.slipTitle.copyWith(
            fontWeight: FontWeight.w500,
            color: cv.accentTint,
            height: 1.0,
          ),
        ),
        const SizedBox(width: CoveSpace.xs),
        Text(
          label,
          style: CoveType.rowSub.copyWith(
            color: cv.textSecondary,
          ),
        ),
      ],
    );
  }
}
