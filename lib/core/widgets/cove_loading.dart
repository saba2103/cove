import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';

class CoveLoading extends StatelessWidget {
  final double size;
  final String? message;

  static const double _kStrokeWidth =
      1.6; // (literal) 1.6dp loading indicator stroke

  const CoveLoading({
    super.key,
    this.size = CoveSize.avatarInline,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CoveSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: _kStrokeWidth,
                valueColor: AlwaysStoppedAnimation<Color>(cv.accentFill),
                backgroundColor: cv.lineHairline,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: CoveSpace.md),
              Text(
                message!,
                style: CoveType.rowSub.copyWith(
                  color: cv.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
