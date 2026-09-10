import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/cove_theme.dart';

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
    final colors = context.colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$count',
          style: GoogleFonts.bodoniModa(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: colors.accentTint,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: colors.textMuted,
          ),
        ),
      ],
    );
  }
}
