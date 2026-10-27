import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/cove_tokens.dart';

export 'package:figma_squircle/figma_squircle.dart'
    show
        BorderAlign,
        ClipSmoothRect,
        SmoothBorderRadius,
        SmoothRadius,
        SmoothRectangleBorder;

/// Key for caching a squircle [Path] per `(width, height, SmoothBorderRadius)`
/// at the origin (`Rect.fromLTWH(0, 0, width, height)`), shifted by
/// `(rect.left, rect.top)` on lookup so scrollable lists (`ListsScreen`,
/// `ExpensesScreen`, `TodayScreen`) and sheet transitions (`CoveDetailSheet`)
/// never rebuild identical cubic-bezier corner paths on every frame (4.5g).
@immutable
class _SquirclePathKey {
  const _SquirclePathKey({
    required this.widthBits,
    required this.heightBits,
    required this.borderRadius,
  });

  final int widthBits;
  final int heightBits;
  final SmoothBorderRadius borderRadius;

  static int _quantize(double v) => (v * 1024.0).round();

  factory _SquirclePathKey.of(Size size, SmoothBorderRadius borderRadius) {
    return _SquirclePathKey(
      widthBits: _quantize(size.width),
      heightBits: _quantize(size.height),
      borderRadius: borderRadius,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is _SquirclePathKey &&
        other.widthBits == widthBits &&
        other.heightBits == heightBits &&
        other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(widthBits, heightBits, borderRadius);
}

/// LRU-bounded cache of origin-aligned squircle [Path]s keyed by `(Size, SmoothBorderRadius)`.
abstract final class SquirclePathCache {
  static const int maxEntries = 512;
  static final Map<_SquirclePathKey, Path> _originPaths =
      <_SquirclePathKey, Path>{};
  static int _hits = 0;
  static int _misses = 0;

  @visibleForTesting
  static int get hits => _hits;

  @visibleForTesting
  static int get misses => _misses;

  @visibleForTesting
  static int get length => _originPaths.length;

  @visibleForTesting
  static void resetStats() {
    _hits = 0;
    _misses = 0;
  }

  @visibleForTesting
  static void clear() {
    _originPaths.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Returns a [Path] for [rect] and [borderRadius], computing the origin path
  /// once per `(Size, SmoothBorderRadius)` and translating by `rect.topLeft`.
  static Path pathFor(
    Rect rect,
    SmoothBorderRadius borderRadius, {
    TextDirection? textDirection,
  }) {
    if (rect.isEmpty) return Path();
    if ([
      borderRadius.bottomLeft,
      borderRadius.bottomRight,
      borderRadius.topLeft,
      borderRadius.topRight,
    ].every((x) => x.cornerSmoothing == 0.0)) {
      return Path()
        ..addRRect(borderRadius.resolve(textDirection).toRRect(rect));
    }

    final key = _SquirclePathKey.of(rect.size, borderRadius);
    var originPath = _originPaths.remove(key);
    if (originPath != null) {
      _hits++;
      // Re-insert as most-recently-used.
      _originPaths[key] = originPath;
    } else {
      _misses++;
      originPath = borderRadius.toPath(
        Rect.fromLTWH(0.0, 0.0, rect.width, rect.height),
      );
      if (_originPaths.length >= maxEntries) {
        _originPaths.remove(_originPaths.keys.first);
      }
      _originPaths[key] = originPath;
    }

    if (rect.left == 0.0 && rect.top == 0.0) {
      return Path.from(originPath);
    }
    return originPath.shift(rect.topLeft);
  }
}

/// A [SmoothRectangleBorder] that resolves its inner, outer, and stroke [Path]s
/// through [SquirclePathCache] per `(Size, SmoothBorderRadius)`.
class CachedSmoothRectangleBorder extends SmoothRectangleBorder {
  const CachedSmoothRectangleBorder({
    super.side = BorderSide.none,
    super.borderRadius = SmoothBorderRadius.zero,
    super.borderAlign = BorderAlign.inside,
  });

  @override
  ShapeBorder scale(double t) {
    return CachedSmoothRectangleBorder(
      side: side.scale(t),
      borderRadius: borderRadius * t,
      borderAlign: borderAlign,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is SmoothRectangleBorder) {
      return CachedSmoothRectangleBorder(
        side: BorderSide.lerp(a.side, side, t),
        borderRadius: SmoothBorderRadius.lerp(a.borderRadius, borderRadius, t)!,
        borderAlign: borderAlign,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is SmoothRectangleBorder) {
      return CachedSmoothRectangleBorder(
        side: BorderSide.lerp(side, b.side, t),
        borderRadius: SmoothBorderRadius.lerp(borderRadius, b.borderRadius, t)!,
        borderAlign: b.borderAlign,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  CachedSmoothRectangleBorder copyWith({
    BorderSide? side,
    SmoothBorderRadius? borderRadius,
    BorderAlign? borderAlign,
  }) {
    return CachedSmoothRectangleBorder(
      side: side ?? this.side,
      borderRadius: borderRadius ?? this.borderRadius,
      borderAlign: borderAlign ?? this.borderAlign,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final innerRect = switch (borderAlign) {
      BorderAlign.inside => rect.deflate(side.width),
      BorderAlign.center => rect.deflate(side.width / 2),
      BorderAlign.outside => rect,
    };
    final radius = switch (borderAlign) {
      BorderAlign.inside => borderRadius -
          SmoothBorderRadius.all(
            SmoothRadius(
              cornerRadius: side.width,
              cornerSmoothing: 1.0,
            ),
          ),
      BorderAlign.center => borderRadius -
          SmoothBorderRadius.all(
            SmoothRadius(
              cornerRadius: side.width / 2,
              cornerSmoothing: 1.0,
            ),
          ),
      BorderAlign.outside => borderRadius,
    };
    return SquirclePathCache.pathFor(
      innerRect,
      radius,
      textDirection: textDirection,
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return SquirclePathCache.pathFor(
      rect,
      borderRadius,
      textDirection: textDirection,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (rect.isEmpty) return;
    switch (side.style) {
      case BorderStyle.none:
        break;
      case BorderStyle.solid:
        final adjustedRect = switch (borderAlign) {
          BorderAlign.inside => rect.deflate(side.width / 2),
          BorderAlign.center => rect,
          BorderAlign.outside => rect.inflate(side.width / 2),
        };
        final adjustedBorderRadius = switch (borderAlign) {
          BorderAlign.inside => borderRadius -
              SmoothBorderRadius.all(
                SmoothRadius(
                  cornerRadius: side.width / 2,
                  cornerSmoothing: 1.0,
                ),
              ),
          BorderAlign.center => borderRadius,
          BorderAlign.outside => borderRadius +
              SmoothBorderRadius.all(
                SmoothRadius(
                  cornerRadius: side.width / 2,
                  cornerSmoothing: 1.0,
                ),
              ),
        };
        final outerPath = SquirclePathCache.pathFor(
          adjustedRect,
          adjustedBorderRadius,
          textDirection: textDirection,
        );
        canvas.drawPath(outerPath, side.toPaint());
    }
  }
}

/// Cove's unified squircle shape helper (100% Figma corner smoothing).
///
/// Every rounded corner in the app uses [CoveRadius.smoothing] (`1.0`) via
/// `figma_squircle`. Borders are always drawn **inside** ([BorderAlign.inside])
/// so a stroke is never half-clipped where a card meets a clip edge, and
/// shadows follow the smooth outline via [ShapeDecoration].
abstract final class CoveShape {
  /// Returns a [SmoothRadius] with [CoveRadius.smoothing] when [cornerRadius] > 0.
  static SmoothRadius radius(
    double cornerRadius, {
    double smoothing = CoveRadius.smoothing,
  }) {
    if (cornerRadius <= 0) return SmoothRadius.zero;
    return SmoothRadius(
      cornerRadius: cornerRadius,
      cornerSmoothing: smoothing,
    );
  }

  /// All four corners smoothed at [cornerRadius].
  static SmoothBorderRadius borderRadius(
    double cornerRadius, {
    double smoothing = CoveRadius.smoothing,
  }) {
    final r = radius(cornerRadius, smoothing: smoothing);
    return SmoothBorderRadius.all(r);
  }

  /// Top-left and top-right corners smoothed at [cornerRadius] (for bottom sheets).
  static SmoothBorderRadius topBorderRadius(
    double cornerRadius, {
    double smoothing = CoveRadius.smoothing,
  }) {
    final r = radius(cornerRadius, smoothing: smoothing);
    return SmoothBorderRadius.only(
      topLeft: r,
      topRight: r,
    );
  }

  /// Per-corner [SmoothBorderRadius].
  static SmoothBorderRadius onlyBorderRadius({
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
    double smoothing = CoveRadius.smoothing,
  }) {
    return SmoothBorderRadius.only(
      topLeft: radius(topLeft, smoothing: smoothing),
      topRight: radius(topRight, smoothing: smoothing),
      bottomLeft: radius(bottomLeft, smoothing: smoothing),
      bottomRight: radius(bottomRight, smoothing: smoothing),
    );
  }

  /// A [SmoothRectangleBorder] at [CoveRadius.smoothing] with the border drawn
  /// inside ([BorderAlign.inside]) and its [Path] cached per size (4.5g).
  static SmoothRectangleBorder border(
    double cornerRadius, {
    BorderSide side = BorderSide.none,
    double smoothing = CoveRadius.smoothing,
  }) {
    return CachedSmoothRectangleBorder(
      side: side,
      borderAlign: BorderAlign.inside,
      borderRadius: borderRadius(cornerRadius, smoothing: smoothing),
    );
  }

  /// Top-corners-only [SmoothRectangleBorder] for sheets, drawn inside and
  /// cached per size (4.5g).
  static SmoothRectangleBorder topBorder(
    double cornerRadius, {
    BorderSide side = BorderSide.none,
    double smoothing = CoveRadius.smoothing,
  }) {
    return CachedSmoothRectangleBorder(
      side: side,
      borderAlign: BorderAlign.inside,
      borderRadius: topBorderRadius(cornerRadius, smoothing: smoothing),
    );
  }

  /// Per-corner [SmoothRectangleBorder], drawn inside and cached per size (4.5g).
  static SmoothRectangleBorder onlyBorder({
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
    BorderSide side = BorderSide.none,
    double smoothing = CoveRadius.smoothing,
  }) {
    return CachedSmoothRectangleBorder(
      side: side,
      borderAlign: BorderAlign.inside,
      borderRadius: onlyBorderRadius(
        topLeft: topLeft,
        topRight: topRight,
        bottomLeft: bottomLeft,
        bottomRight: bottomRight,
        smoothing: smoothing,
      ),
    );
  }

  /// Clips [child] to a smooth squircle of [cornerRadius], using
  /// [CachedSmoothRectangleBorder] so repeated sizes share the same path.
  static Widget clip(
    double cornerRadius,
    Widget child, {
    Key? key,
    Clip clipBehavior = Clip.antiAlias,
    double smoothing = CoveRadius.smoothing,
  }) {
    return ClipPath.shape(
      key: key,
      clipBehavior: clipBehavior,
      shape: border(cornerRadius, smoothing: smoothing),
      child: child,
    );
  }

  /// Clips [child] to a top-corners-only smooth squircle (for bottom sheets).
  static Widget topClip(
    double cornerRadius,
    Widget child, {
    Key? key,
    Clip clipBehavior = Clip.antiAlias,
    double smoothing = CoveRadius.smoothing,
  }) {
    return ClipPath.shape(
      key: key,
      clipBehavior: clipBehavior,
      shape: topBorder(cornerRadius, smoothing: smoothing),
      child: child,
    );
  }

  /// Clips [child] with per-corner smooth squircle radii.
  static Widget onlyClip(
    Widget child, {
    Key? key,
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
    Clip clipBehavior = Clip.antiAlias,
    double smoothing = CoveRadius.smoothing,
  }) {
    return ClipPath.shape(
      key: key,
      clipBehavior: clipBehavior,
      shape: onlyBorder(
        topLeft: topLeft,
        topRight: topRight,
        bottomLeft: bottomLeft,
        bottomRight: bottomRight,
        smoothing: smoothing,
      ),
      child: child,
    );
  }

  /// A [ShapeDecoration] whose shape is [CoveShape.border] so both the inside
  /// hairline and any [shadows] follow the smooth squircle outline.
  static ShapeDecoration decoration(
    double cornerRadius, {
    Color? color,
    Gradient? gradient,
    BorderSide side = BorderSide.none,
    List<BoxShadow>? shadows,
    double smoothing = CoveRadius.smoothing,
  }) {
    return ShapeDecoration(
      color: color,
      gradient: gradient,
      shadows: shadows,
      shape: border(cornerRadius, side: side, smoothing: smoothing),
    );
  }

  /// Top-corners-only [ShapeDecoration] for sheets.
  static ShapeDecoration topDecoration(
    double cornerRadius, {
    Color? color,
    Gradient? gradient,
    BorderSide side = BorderSide.none,
    List<BoxShadow>? shadows,
    double smoothing = CoveRadius.smoothing,
  }) {
    return ShapeDecoration(
      color: color,
      gradient: gradient,
      shadows: shadows,
      shape: topBorder(cornerRadius, side: side, smoothing: smoothing),
    );
  }

  /// Per-corner [ShapeDecoration].
  static ShapeDecoration onlyDecoration({
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
    Color? color,
    Gradient? gradient,
    BorderSide side = BorderSide.none,
    List<BoxShadow>? shadows,
    double smoothing = CoveRadius.smoothing,
  }) {
    return ShapeDecoration(
      color: color,
      gradient: gradient,
      shadows: shadows,
      shape: onlyBorder(
        topLeft: topLeft,
        topRight: topRight,
        bottomLeft: bottomLeft,
        bottomRight: bottomRight,
        side: side,
        smoothing: smoothing,
      ),
    );
  }
}

/// Builds a smooth squircle [Path] for [rect] using the same Figma corner
/// smoothing maths as [CoveShape], cached per `(Size, SmoothBorderRadius)` (4.5g).
Path smoothCornerPath(
  Rect rect, {
  double radius = CoveRadius.card,
  double smoothing = CoveRadius.smoothing,
  double? topLeft,
  double? topRight,
  double? bottomLeft,
  double? bottomRight,
}) {
  return SquirclePathCache.pathFor(
    rect,
    CoveShape.onlyBorderRadius(
      topLeft: topLeft ?? radius,
      topRight: topRight ?? radius,
      bottomLeft: bottomLeft ?? radius,
      bottomRight: bottomRight ?? radius,
      smoothing: smoothing,
    ),
  );
}

/// An [InputBorder] that draws a smooth squircle outline with its stroke
/// aligned inside ([BorderAlign.inside]), matching [CoveShape.border].
class CoveInputBorder extends InputBorder {
  const CoveInputBorder({
    this.radius = CoveRadius.inline,
    this.smoothing = CoveRadius.smoothing,
    super.borderSide = const BorderSide(),
  });

  final double radius;
  final double smoothing;

  SmoothRectangleBorder get _shape => CoveShape.border(
        radius,
        side: borderSide,
        smoothing: smoothing,
      );

  @override
  bool get isOutline => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  CoveInputBorder copyWith({
    BorderSide? borderSide,
    double? radius,
    double? smoothing,
  }) {
    return CoveInputBorder(
      borderSide: borderSide ?? this.borderSide,
      radius: radius ?? this.radius,
      smoothing: smoothing ?? this.smoothing,
    );
  }

  @override
  CoveInputBorder scale(double t) {
    return CoveInputBorder(
      borderSide: borderSide.scale(t),
      radius: radius * t,
      smoothing: smoothing,
    );
  }

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is CoveInputBorder) {
      return CoveInputBorder(
        borderSide: BorderSide.lerp(a.borderSide, borderSide, t),
        radius: a.radius + (radius - a.radius) * t,
        smoothing: a.smoothing + (smoothing - a.smoothing) * t,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is CoveInputBorder) {
      return CoveInputBorder(
        borderSide: BorderSide.lerp(borderSide, b.borderSide, t),
        radius: radius + (b.radius - radius) * t,
        smoothing: smoothing + (b.smoothing - smoothing) * t,
      );
    }
    return super.lerpTo(b, t);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _shape.getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    _shape.paint(canvas, rect, textDirection: textDirection);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is CoveInputBorder &&
        other.borderSide == borderSide &&
        other.radius == radius &&
        other.smoothing == smoothing;
  }

  @override
  int get hashCode => Object.hash(borderSide, radius, smoothing);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'CoveInputBorder')}($borderSide, radius: $radius, smoothing: $smoothing)';
}
