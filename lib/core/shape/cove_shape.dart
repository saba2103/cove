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
  /// inside ([BorderAlign.inside]).
  static SmoothRectangleBorder border(
    double cornerRadius, {
    BorderSide side = BorderSide.none,
    double smoothing = CoveRadius.smoothing,
  }) {
    return SmoothRectangleBorder(
      side: side,
      borderAlign: BorderAlign.inside,
      borderRadius: borderRadius(cornerRadius, smoothing: smoothing),
    );
  }

  /// Top-corners-only [SmoothRectangleBorder] for sheets, drawn inside.
  static SmoothRectangleBorder topBorder(
    double cornerRadius, {
    BorderSide side = BorderSide.none,
    double smoothing = CoveRadius.smoothing,
  }) {
    return SmoothRectangleBorder(
      side: side,
      borderAlign: BorderAlign.inside,
      borderRadius: topBorderRadius(cornerRadius, smoothing: smoothing),
    );
  }

  /// Per-corner [SmoothRectangleBorder], drawn inside.
  static SmoothRectangleBorder onlyBorder({
    double topLeft = 0,
    double topRight = 0,
    double bottomLeft = 0,
    double bottomRight = 0,
    BorderSide side = BorderSide.none,
    double smoothing = CoveRadius.smoothing,
  }) {
    return SmoothRectangleBorder(
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

  /// Clips [child] to a smooth squircle of [cornerRadius].
  static Widget clip(
    double cornerRadius,
    Widget child, {
    Key? key,
    Clip clipBehavior = Clip.antiAlias,
    double smoothing = CoveRadius.smoothing,
  }) {
    return ClipSmoothRect(
      key: key,
      radius: borderRadius(cornerRadius, smoothing: smoothing),
      clipBehavior: clipBehavior,
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
    return ClipSmoothRect(
      key: key,
      radius: topBorderRadius(cornerRadius, smoothing: smoothing),
      clipBehavior: clipBehavior,
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
    return ClipSmoothRect(
      key: key,
      radius: onlyBorderRadius(
        topLeft: topLeft,
        topRight: topRight,
        bottomLeft: bottomLeft,
        bottomRight: bottomRight,
        smoothing: smoothing,
      ),
      clipBehavior: clipBehavior,
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
/// smoothing maths as [CoveShape]. Used by custom paper/slip painters (4.5c).
Path smoothCornerPath(
  Rect rect, {
  double radius = CoveRadius.card,
  double smoothing = CoveRadius.smoothing,
  double? topLeft,
  double? topRight,
  double? bottomLeft,
  double? bottomRight,
}) {
  return CoveShape.onlyBorderRadius(
    topLeft: topLeft ?? radius,
    topRight: topRight ?? radius,
    bottomLeft: bottomLeft ?? radius,
    bottomRight: bottomRight ?? radius,
    smoothing: smoothing,
  ).toPath(rect);
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
