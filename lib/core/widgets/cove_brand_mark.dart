import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';

/// The Cove brand mark — two soft overlapping forms representing quiet partnership.
class CoveBrandMark extends StatelessWidget {
  final double size;
  final Color? strokeColor;
  final Color? fillColor;
  final double strokeWidth;

  const CoveBrandMark({
    super.key,
    this.size = 64,
    this.strokeColor,
    this.fillColor,
    this.strokeWidth = 1.5,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final effectiveStroke = strokeColor ?? colors.accentPrimary;
    final effectiveFill = fillColor ?? colors.accentPrimary.withValues(alpha: 0.12);

    return CustomPaint(
      size: Size(size, size),
      painter: CoveBrandMarkPainter(
        strokeColor: effectiveStroke,
        fillColor: effectiveFill,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class CoveBrandMarkPainter extends CustomPainter {
  final Color strokeColor;
  final Color fillColor;
  final double strokeWidth;

  const CoveBrandMarkPainter({
    required this.strokeColor,
    required this.fillColor,
    this.strokeWidth = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final radius = size.width * 0.32;
    final centerY = size.height / 2;
    final centerLeft = Offset(size.width * 0.38, centerY);
    final centerRight = Offset(size.width * 0.62, centerY);

    // Left circle
    canvas.drawCircle(centerLeft, radius, fillPaint);
    canvas.drawCircle(centerLeft, radius, strokePaint);

    // Right circle
    canvas.drawCircle(centerRight, radius, fillPaint);
    canvas.drawCircle(centerRight, radius, strokePaint);
  }

  @override
  bool shouldRepaint(CoveBrandMarkPainter oldDelegate) =>
      strokeColor != oldDelegate.strokeColor ||
      fillColor != oldDelegate.fillColor ||
      strokeWidth != oldDelegate.strokeWidth;
}
