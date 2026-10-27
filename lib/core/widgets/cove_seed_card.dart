import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../shape/cove_shape.dart';
import '../theme/cove_tokens.dart';
import 'cove_pill_button.dart';

/// The seven first-run line illustrations (`design/specs/16-first-run.md` §1).
///
/// Drawn with vector [Path] primitives in `accent.text` — no image assets.
enum CoveSeedArtKind {
  /// Today — a small sprout.
  sprout,

  /// Calendar — a calendar frame with a single gold dot.
  calendar,

  /// Routines — three horizontal bands across a dashed centre line.
  bands,

  /// Expenses — a coin with a subtle inner ring.
  coin,

  /// Commitments — two curved renewal arrows.
  arrows,

  /// Activity — a quiet two-stroke wave.
  wave,

  /// Our home — a key.
  key;

  static const CoveSeedArtKind today = CoveSeedArtKind.sprout;
  static const CoveSeedArtKind routines = CoveSeedArtKind.bands;
  static const CoveSeedArtKind expenses = CoveSeedArtKind.coin;
  static const CoveSeedArtKind commitments = CoveSeedArtKind.arrows;
  static const CoveSeedArtKind activity = CoveSeedArtKind.wave;
  static const CoveSeedArtKind ourHome = CoveSeedArtKind.key;
}

/// 48dp stroke-only line drawing in `accent.text` for [CoveSeedCard]
/// (`design/specs/16-first-run.md` §1).
class CoveSeedArt extends StatelessWidget {
  final CoveSeedArtKind kind;
  final double size;
  final Color? color;

  static const double _kDefaultSize = CoveSize.hit; // 48dp

  const CoveSeedArt(
    this.kind, {
    super.key,
    this.size = _kDefaultSize,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CoveSeedArtPainter(
          kind: kind,
          color: color ?? cv.accentText,
        ),
      ),
    );
  }
}

class _CoveSeedArtPainter extends CustomPainter {
  final CoveSeedArtKind kind;
  final Color color;

  static const double _kDesignSize = 48.0;
  static const double _kStrokeWidth = 1.75;

  const _CoveSeedArtPainter({
    required this.kind,
    required this.color,
  });

  Paint _strokePaint([double alpha = 1.0]) {
    return Paint()
      ..color = alpha >= 1.0 ? color : color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / _kDesignSize;
    canvas.save();
    canvas.scale(scale, scale);

    switch (kind) {
      case CoveSeedArtKind.sprout:
        _paintSprout(canvas);
      case CoveSeedArtKind.calendar:
        _paintCalendar(canvas);
      case CoveSeedArtKind.bands:
        _paintBands(canvas);
      case CoveSeedArtKind.coin:
        _paintCoin(canvas);
      case CoveSeedArtKind.arrows:
        _paintArrows(canvas);
      case CoveSeedArtKind.wave:
        _paintWave(canvas);
      case CoveSeedArtKind.key:
        _paintKey(canvas);
    }

    canvas.restore();
  }

  void _paintSprout(Canvas canvas) {
    final paint = _strokePaint();

    // Ground line
    canvas.drawLine(const Offset(14, 39), const Offset(34, 39), paint);

    // Stem
    final stem = Path()
      ..moveTo(24, 39)
      ..cubicTo(24, 32, 24, 24, 25.5, 17.5);
    canvas.drawPath(stem, paint);

    // Left leaf (pointed oval branching left)
    final leftLeaf = Path()
      ..moveTo(24, 29)
      ..cubicTo(17, 29, 12.5, 24.5, 13, 18.5)
      ..cubicTo(19, 18.5, 23.5, 22.5, 24, 29);
    canvas.drawPath(leftLeaf, paint);

    // Right leaf (slightly higher pointed oval branching right)
    final rightLeaf = Path()
      ..moveTo(24.5, 25)
      ..cubicTo(25.5, 17.5, 30, 13.5, 36.5, 14)
      ..cubicTo(36, 20.5, 31.5, 24.5, 24.5, 25);
    canvas.drawPath(rightLeaf, paint);
  }

  void _paintCalendar(Canvas canvas) {
    final paint = _strokePaint();

    // Outer rounded frame
    canvas.drawPath(
      smoothCornerPath(const Rect.fromLTRB(9, 12, 39, 39), radius: 5.5),
      paint,
    );

    // Binding pegs
    canvas.drawLine(const Offset(17, 8), const Offset(17, 15), paint);
    canvas.drawLine(const Offset(31, 8), const Offset(31, 15), paint);

    // Header divider line
    canvas.drawLine(const Offset(9, 20.5), const Offset(39, 20.5), paint);

    // Single gold date dot inside the grid
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(30.5, 28.5), 2.2, dotPaint);
  }

  void _paintBands(Canvas canvas) {
    final primaryPaint = _strokePaint();
    final secondaryPaint = _strokePaint(0.5);
    final guidePaint = _strokePaint(0.32);

    // Subtle vertical dashed centre guide
    for (double y = 7; y < 41; y += 5) {
      canvas.drawLine(
        Offset(24, y),
        Offset(24, math.min(y + 2.5, 41)),
        guidePaint,
      );
    }

    // Three staggered horizontal bands
    canvas.drawPath(
      smoothCornerPath(const Rect.fromLTRB(8, 12, 31, 18), radius: 3),
      primaryPaint,
    );
    canvas.drawPath(
      smoothCornerPath(const Rect.fromLTRB(17, 21, 40, 27), radius: 3),
      secondaryPaint,
    );
    canvas.drawPath(
      smoothCornerPath(const Rect.fromLTRB(11, 30, 35, 36), radius: 3),
      primaryPaint,
    );
  }

  void _paintCoin(Canvas canvas) {
    final outerPaint = _strokePaint();
    final innerPaint = _strokePaint(0.45);

    canvas.drawCircle(const Offset(24, 24), 15.5, outerPaint);
    canvas.drawCircle(const Offset(24, 24), 10.5, innerPaint);
  }

  void _paintArrows(Canvas canvas) {
    final paint = _strokePaint();
    final rect = Rect.fromCircle(center: const Offset(24, 24), radius: 13.5);

    // Top arc (sweeps clockwise from left-upper to right-upper)
    final topArc = Path()..addArc(rect, -math.pi * 0.88, math.pi * 0.78);
    canvas.drawPath(topArc, paint);

    // Top-right arrowhead
    final topHead = Path()
      ..moveTo(36.5, 14.5)
      ..lineTo(37.0, 20.5)
      ..lineTo(31.0, 19.5);
    canvas.drawPath(topHead, paint);

    // Bottom arc (sweeps clockwise from right-lower to left-lower)
    final bottomArc = Path()..addArc(rect, math.pi * 0.12, math.pi * 0.78);
    canvas.drawPath(bottomArc, paint);

    // Bottom-left arrowhead
    final bottomHead = Path()
      ..moveTo(11.5, 33.5)
      ..lineTo(11.0, 27.5)
      ..lineTo(17.0, 28.5);
    canvas.drawPath(bottomHead, paint);
  }

  void _paintWave(Canvas canvas) {
    final upperPaint = _strokePaint();
    final lowerPaint = _strokePaint(0.42);

    Path buildWave(double yOffset) {
      return Path()
        ..moveTo(8, 22 + yOffset)
        ..cubicTo(11.5, 14 + yOffset, 16.5, 14 + yOffset, 21, 21 + yOffset)
        ..cubicTo(25.5, 28 + yOffset, 30.5, 28 + yOffset, 35, 19 + yOffset)
        ..cubicTo(36.8, 15.5 + yOffset, 38.5, 16 + yOffset, 40, 18.5 + yOffset);
    }

    canvas.drawPath(buildWave(0), upperPaint);
    canvas.drawPath(buildWave(6.5), lowerPaint);
  }

  void _paintKey(Canvas canvas) {
    final paint = _strokePaint();

    // Key bow (ring) at bottom-left
    const bowCenter = Offset(16.5, 31.5);
    canvas.drawCircle(bowCenter, 6.8, paint);
    canvas.drawCircle(bowCenter, 1.8, paint);

    // Diagonal shaft and teeth extending to top-right
    final blade = Path()
      ..moveTo(21.3, 26.7)
      ..lineTo(33.5, 14.5)
      ..lineTo(37.5, 18.5)
      ..lineTo(34.5, 21.5)
      ..lineTo(32.2, 19.2)
      ..moveTo(29.0, 23.0)
      ..lineTo(32.5, 26.5)
      ..lineTo(29.8, 29.2)
      ..lineTo(26.3, 25.7);
    canvas.drawPath(blade, paint);
  }

  @override
  bool shouldRepaint(covariant _CoveSeedArtPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}

/// First-run "seed card" (`design/specs/16-first-run.md` §1).
///
/// Sits where the screen's primary list or slip would sit once data exists:
/// - `CoveRadius.card`, `surface.card` fill with a 1dp dashed `line.strong`
///   border and a soft radial `accent.fill` glow behind the top-centre.
/// - 48dp [CoveSeedArt] line drawing in `accent.text`.
/// - Title in `CoveType.slipTitle` (`text.primary`, centred).
/// - Body in `CoveType.rowSub` (`text.secondary`, centred).
/// - Optional primary gold pill button with a `+` icon.
/// - Optional `alt` line under the button in `text.tertiary`.
class CoveSeedCard extends StatelessWidget {
  final CoveSeedArtKind art;
  final String title;
  final String body;
  final String? buttonLabel;
  final VoidCallback? onPressed;
  final String? altText;
  final String? altAccentText;
  final VoidCallback? onAltTap;
  final Widget? alt;

  static const double _kCardFillAlphaDark = 0.55;
  static const double _kCardFillAlphaLight = 0.78;
  static const double _kGlowAlpha = 0.14;
  static const double _kArtGap = CoveSpace.md + CoveSpace.xs; // 16dp
  static const double _kTitleBodyGap = CoveSpace.sm + 2.0; // 10dp
  static const double _kBodyButtonGap = CoveSpace.lg - CoveSpace.xs; // 20dp
  static const double _kAltGap = CoveSpace.md + CoveSpace.xs; // 16dp
  static const double _kVerticalPadding = CoveSpace.lg + CoveSpace.xs; // 28dp

  const CoveSeedCard({
    super.key,
    required this.art,
    required this.title,
    required this.body,
    this.buttonLabel,
    this.onPressed,
    this.altText,
    this.altAccentText,
    this.onAltTap,
    this.alt,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillAlpha = isDark ? _kCardFillAlphaDark : _kCardFillAlphaLight;

    Widget? altWidget = alt;
    if (altWidget == null && altText != null && altText!.isNotEmpty) {
      final baseStyle = CoveType.rowSub.copyWith(
        color: cv.textTertiary,
        height: 1.4,
      );
      if (altAccentText != null && altAccentText!.isNotEmpty) {
        altWidget = Text.rich(
          TextSpan(
            text: altText,
            style: baseStyle,
            children: [
              TextSpan(
                text: altAccentText,
                style: baseStyle.copyWith(
                  color: cv.accentText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        );
      } else {
        altWidget = Text(
          altText!,
          textAlign: TextAlign.center,
          style: baseStyle,
        );
      }
      if (onAltTap != null) {
        altWidget = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAltTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: CoveSize.hit),
            child: Center(child: altWidget),
          ),
        );
      }
    }

    return CustomPaint(
      foregroundPainter: _DashedCardBorderPainter(
        color: cv.lineStrong,
        radius: CoveRadius.card,
      ),
      child: CoveShape.clip(
        CoveRadius.card,
        DecoratedBox(
          decoration: CoveShape.decoration(
            CoveRadius.card,
            color: cv.surfaceCard.withValues(alpha: fillAlpha),
          ),
          child: Stack(
            children: [
              // Soft radial accent glow behind the top-centre illustration
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0.0, -0.78),
                        radius: 0.92,
                        colors: [
                          cv.accentFill.withValues(alpha: _kGlowAlpha),
                          cv.accentFill.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoveSpace.lg,
                  vertical: _kVerticalPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: double.infinity),
                    CoveSeedArt(art),
                    const SizedBox(height: _kArtGap),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: CoveType.slipTitle.copyWith(
                        color: cv.textPrimary,
                      ),
                    ),
                    const SizedBox(height: _kTitleBodyGap),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: CoveType.rowSub.copyWith(
                        color: cv.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    if (buttonLabel != null && buttonLabel!.isNotEmpty) ...[
                      const SizedBox(height: _kBodyButtonGap),
                      CovePillButton(
                        label: buttonLabel!,
                        icon: const Icon(Icons.add),
                        onPressed: onPressed,
                      ),
                    ],
                    if (altWidget != null) ...[
                      const SizedBox(height: _kAltGap),
                      altWidget,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedCardBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  static const double _kStrokeWidth = 1.0;
  static const double _kDashLength = 5.0;
  static const double _kDashGap = 4.0;

  const _DashedCardBorderPainter({
    required this.color,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _kStrokeWidth;

    final path = smoothCornerPath(
      (Offset.zero & size).deflate(_kStrokeWidth / 2),
      radius: radius - _kStrokeWidth / 2,
    );
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + _kDashLength, metric.length);
        dashedPath.addPath(
          metric.extractPath(distance, next),
          Offset.zero,
        );
        distance += _kDashLength + _kDashGap;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedCardBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
