import 'package:flutter/material.dart';

/// Renders a Home icon mark.
/// Uses the two-overlapping-circles motif from DESIGN_SYSTEM.md, tinted by a
/// deterministic color derived from the Home's ID.
/// Leaves an extension point for an uploaded image path.
class DeterministicHomeIcon extends StatelessWidget {
  final String homeId;
  final String? imagePath; // Extension point for uploaded custom images
  final double size;

  const DeterministicHomeIcon({
    super.key,
    required this.homeId,
    this.imagePath,
    this.size = 36,
  });

  static const List<Color> _homePalette = [
    Color(0xFFD8B98C), // Champagne
    Color(0xFFC46D5E), // Muted Terracotta
    Color(0xFF6B9080), // Sage green
    Color(0xFF8B9EB7), // Slate blue
    Color(0xFFB5838D), // Dusty mauve
    Color(0xFFE0A96D), // Warm Ochre
  ];

  Color _deriveColor(String id) {
    if (id.isEmpty) return _homePalette[0];
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = (hash * 31 + id.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return _homePalette[hash % _homePalette.length];
  }

  @override
  Widget build(BuildContext context) {
    if (imagePath != null && imagePath!.isNotEmpty) {
      // Extension point for uploaded image path
      return ClipOval(
        child: Image.network(
          imagePath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildMark(),
        ),
      );
    }

    return _buildMark();
  }

  Widget _buildMark() {
    final tint = _deriveColor(homeId);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _OverlappingCirclesPainter(tint: tint),
      ),
    );
  }
}

class _OverlappingCirclesPainter extends CustomPainter {
  final Color tint;

  const _OverlappingCirclesPainter({required this.tint});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = tint.withValues(alpha: 0.12)
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
  bool shouldRepaint(_OverlappingCirclesPainter oldDelegate) =>
      oldDelegate.tint != tint;
}
