import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';

enum CoveSyncStatus {
  /// Saved locally on this device. Displays a single thin checkmark.
  savedLocally,

  /// Synced to partner's device. Displays two overlapping thin checkmarks.
  syncedToPartner,
}

/// Understated sync status indicator.
/// Deliberately rendered in a muted tone so it never competes with the champagne accent.
/// Strictly supports two states: saved locally (1 tick) and synced to partner (2 ticks).
class CoveSyncTick extends StatelessWidget {
  final CoveSyncStatus status;
  final double size;
  final Color? color;

  const CoveSyncTick({
    super.key,
    required this.status,
    this.size = 14,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? context.colors.textMuted;
    final isDouble = status == CoveSyncStatus.syncedToPartner;

    return Semantics(
      label: isDouble ? 'Synced to partner' : 'Saved locally',
      child: SizedBox(
        width: isDouble ? size * 1.35 : size,
        height: size,
        child: CustomPaint(
          painter: _TickPainter(
            color: effectiveColor,
            isDouble: isDouble,
            strokeWidth: 1.5,
          ),
        ),
      ),
    );
  }
}

class _TickPainter extends CustomPainter {
  final Color color;
  final bool isDouble;
  final double strokeWidth;

  const _TickPainter({
    required this.color,
    required this.isDouble,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final h = size.height;

    // Draw base checkmark
    void drawCheck(double offsetX) {
      final path = Path();
      // start at left mid-down, down to vertex, up to top right
      path.moveTo(offsetX + h * 0.15, h * 0.52);
      path.lineTo(offsetX + h * 0.42, h * 0.80);
      path.lineTo(offsetX + h * 0.85, h * 0.22);
      canvas.drawPath(path, paint);
    }

    if (isDouble) {
      // First checkmark (left)
      drawCheck(0);
      // Second overlapping checkmark (shifted right by 35% width)
      drawCheck(size.width - h);
    } else {
      drawCheck((size.width - h) / 2);
    }
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.isDouble != isDouble ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
