import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

class CoveEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  static const double _kIconCircleSize =
      56.0; // (literal) 56dp empty-state icon medallion diameter
  static const double _kBorderWidth =
      1.0; // (literal) 1dp medallion hairline border
  static const double _kIconToTitleGap =
      16.0; // (literal) 16dp medallion-to-title gap

  const CoveEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.section,
          vertical: CoveSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: _kIconCircleSize,
              height: _kIconCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cv.surfaceRow,
                border: Border.all(
                  color: cv.lineHairline,
                  width: _kBorderWidth,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: CoveSize.avatarInline,
                color: cv.textSecondary,
              ),
            ),
            const SizedBox(height: _kIconToTitleGap),
            Text(
              title,
              textAlign: TextAlign.center,
              style: CoveType.rowTitle.copyWith(
                fontWeight: FontWeight.w600,
                color: cv.textPrimary,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: CoveSpace.xs),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: CoveType.readout.copyWith(
                  color: cv.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: CoveSpace.gutter),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
