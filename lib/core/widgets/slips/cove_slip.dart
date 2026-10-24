import 'package:flutter/material.dart';

import '../../theme/cove_theme.dart';

/// Visual surface variant for a paper object (`design/specs/10-paper-objects.md`).
///
/// Always chosen by the caller — never inferred from ambient [Brightness]
/// inside the widget.
enum CoveSlipVariant {
  /// Warm cream paper (`paper.from` → `paper.via` → `paper.to`).
  paper,

  /// Deep green ink slip cut from the app green (`slip.inkFrom` → `slip.inkVia` → `slip.inkTo`).
  ink,
}

/// Resolved colour palette for a [CoveSlip] (`design/specs/10-paper-objects.md`).
///
/// Maps semantic slip roles onto [CoveTokens] based on the caller-selected
/// [CoveSlipVariant]:
/// - On [CoveSlipVariant.ink], tertiary text uses `slip.inkText3` (never
///   `text.tertiary`, which fails contrast at 3.63:1) and alert words use
///   `slip.inkAlertText` (never `status.alertText`, which fails at 3.61:1).
/// - On [CoveSlipVariant.paper], the `1dp` `paper.edge` hairline and
///   `elevationPaper` shadow appear in light mode only (`cv.paperEdge.a > 0`).
@immutable
class CoveSlipPalette {
  final CoveSlipVariant variant;
  final Gradient fillGradient;
  final Color title;
  final Color body;
  final Color secondary;
  final Color tertiary;
  final Color accent;
  final Color accentFill;
  final Color alertText;
  final Color statusGood;
  final Color rule;
  final Color hairline;
  final Color mark;
  final Color? edgeColor;
  final List<BoxShadow> shadows;

  // CSS 168° linear-gradient: sin(168°) ≈ 0.2079, -cos(168°) ≈ 0.9781.
  static const Alignment _kGradientBegin = Alignment(-0.2079, -0.9781);
  static const Alignment _kGradientEnd = Alignment(0.2079, 0.9781);
  // Middle stop at 46% per design/specs/10-paper-objects.md.
  static const List<double> _kGradientStops = <double>[0.0, 0.46, 1.0];

  const CoveSlipPalette({
    required this.variant,
    required this.fillGradient,
    required this.title,
    required this.body,
    required this.secondary,
    required this.tertiary,
    required this.accent,
    required this.accentFill,
    required this.alertText,
    required this.statusGood,
    required this.rule,
    required this.hairline,
    required this.mark,
    required this.edgeColor,
    required this.shadows,
  });

  /// Resolves the slip palette for [variant] from [context].
  factory CoveSlipPalette.resolve(
    BuildContext context,
    CoveSlipVariant variant,
  ) {
    final cv = context.cv;

    switch (variant) {
      case CoveSlipVariant.paper:
        // paper.edge is transparent in dark mode and 20% ink in light mode.
        final bool hasPaperEdge = cv.paperEdge.a > 0;
        return CoveSlipPalette(
          variant: CoveSlipVariant.paper,
          fillGradient: LinearGradient(
            begin: _kGradientBegin,
            end: _kGradientEnd,
            colors: <Color>[cv.paperFrom, cv.paperVia, cv.paperTo],
            stops: _kGradientStops,
          ),
          title: cv.paperInk,
          body: cv.paperInk,
          secondary: cv.paperInk2,
          tertiary: cv.paperInk3,
          accent: cv.paperAccent,
          accentFill: cv.paperAccent,
          alertText: CoveTokens.light.statusAlertText,
          statusGood: CoveTokens.light.statusGood,
          rule: cv.paperRule,
          hairline: cv.paperHairline,
          mark: cv.paperInk3,
          edgeColor: hasPaperEdge ? cv.paperEdge : null,
          shadows: hasPaperEdge ? cv.elevationPaper : const <BoxShadow>[],
        );

      case CoveSlipVariant.ink:
        return CoveSlipPalette(
          variant: CoveSlipVariant.ink,
          fillGradient: LinearGradient(
            begin: _kGradientBegin,
            end: _kGradientEnd,
            colors: <Color>[cv.slipInkFrom, cv.slipInkVia, cv.slipInkTo],
            stops: _kGradientStops,
          ),
          title: CoveTokens.dark.textPrimary,
          body: CoveTokens.dark.textPrimary,
          secondary: CoveTokens.dark.textSecondary,
          tertiary: cv.slipInkText3,
          accent: CoveTokens.dark.accentText,
          accentFill: CoveTokens.dark.accentFill,
          alertText: cv.slipInkAlertText,
          statusGood: CoveTokens.dark.statusGood,
          rule: CoveTokens.dark.lineStrong,
          hairline: CoveTokens.dark.lineHairline,
          mark: cv.slipInkMark,
          edgeColor: null,
          shadows: const <BoxShadow>[],
        );
    }
  }
}

/// Inherited scope exposing the enclosing [CoveSlip]'s [CoveSlipPalette].
class CoveSlipScope extends InheritedWidget {
  final CoveSlipPalette palette;

  const CoveSlipScope({
    super.key,
    required this.palette,
    required super.child,
  });

  static CoveSlipPalette? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CoveSlipScope>()?.palette;
  }

  static CoveSlipPalette of(BuildContext context) {
    final palette = maybeOf(context);
    assert(palette != null, 'No CoveSlipScope found in context.');
    return palette!;
  }

  @override
  bool updateShouldNotify(CoveSlipScope oldWidget) =>
      palette.variant != oldWidget.palette.variant ||
      palette.edgeColor != oldWidget.palette.edgeColor;
}

/// Signature for building a custom silhouette [Path] for a [CoveSlip]
/// (e.g., ticket perforation notches or torn receipt edges).
typedef CoveSlipPathBuilder = Path Function(Size size);

/// Shared frame for all five Cove paper objects (`design/specs/10-paper-objects.md`).
///
/// Built to the contract in `design/specs/10-paper-objects.md`:
/// - [variant] ([CoveSlipVariant.paper] or [CoveSlipVariant.ink]) is chosen by
///   the caller, never inferred from ambient brightness.
/// - Fill: `168°` linear gradient (`paper.from` → `paper.via` 46% → `paper.to`
///   for paper; `slip.inkFrom` → `slip.inkVia` 46% → `slip.inkTo` for ink).
/// - Radius: defaults to [CoveRadius.card] (`20dp`).
/// - Inner padding: defaults to [CoveSpace.gutter] (`20dp`).
/// - Edge: `1dp` `paper.edge` hairline + `elevationPaper` in light mode on
///   paper only; none on ink.
/// - Semantics: wraps the slip in a single [Semantics] node when
///   [semanticLabel] is provided so assistive tech reads the full state cleanly.
class CoveSlip extends StatelessWidget {
  final CoveSlipVariant variant;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final CoveSlipPathBuilder? pathBuilder;
  final CustomPainter? backgroundPainter;
  final CustomPainter? foregroundPainter;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double kEdgeStrokeWidth = 1.0; // (literal) 1dp paper.edge hairline

  const CoveSlip({
    super.key,
    required this.variant,
    required this.child,
    this.padding = const EdgeInsets.all(CoveSpace.gutter),
    this.borderRadius = const BorderRadius.all(
      Radius.circular(CoveRadius.card),
    ),
    this.pathBuilder,
    this.backgroundPainter,
    this.foregroundPainter,
    this.onTap,
    this.semanticLabel,
  });

  /// Builds the opening caps line (`CoveType.capsSlip`) and title
  /// (`CoveType.slipTitle`) shared by Cove slips.
  static Widget buildHeader({
    required CoveSlipPalette palette,
    required String capsLabel,
    required String title,
    TextAlign textAlign = TextAlign.start,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          capsLabel.toUpperCase(),
          textAlign: textAlign,
          style: CoveType.capsSlip.copyWith(color: palette.tertiary),
        ),
        const SizedBox(height: CoveSpace.sm),
        Text(
          title,
          textAlign: textAlign,
          style: CoveType.slipTitle.copyWith(color: palette.title),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoveSlipPalette.resolve(context, variant);
    final innerTheme = variant == CoveSlipVariant.paper
        ? CoveTheme.lightTheme
        : CoveTheme.darkTheme;
    final clipper = _CoveSlipClipper(
      borderRadius: borderRadius,
      pathBuilder: pathBuilder,
    );

    Widget content = Theme(
      data: innerTheme,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (backgroundPainter != null || foregroundPainter != null) {
      content = CustomPaint(
        painter: backgroundPainter,
        foregroundPainter: foregroundPainter,
        child: content,
      );
    }

    Widget slipBody = CustomPaint(
      painter: _CoveSlipSurfacePainter(
        palette: palette,
        borderRadius: borderRadius,
        pathBuilder: pathBuilder,
      ),
      child: ClipPath(
        clipper: clipper,
        child: content,
      ),
    );

    if (onTap != null) {
      slipBody = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: slipBody,
      );
    }

    if (semanticLabel != null) {
      slipBody = Semantics(
        container: true,
        button: onTap != null,
        label: semanticLabel,
        child: ExcludeSemantics(child: slipBody),
      );
    }

    return CoveSlipScope(
      palette: palette,
      child: slipBody,
    );
  }
}

class _CoveSlipClipper extends CustomClipper<Path> {
  final BorderRadius borderRadius;
  final CoveSlipPathBuilder? pathBuilder;

  const _CoveSlipClipper({
    required this.borderRadius,
    required this.pathBuilder,
  });

  @override
  Path getClip(Size size) {
    if (pathBuilder != null) {
      return pathBuilder!(size);
    }
    return Path()..addRRect(borderRadius.toRRect(Offset.zero & size));
  }

  @override
  bool shouldReclip(_CoveSlipClipper oldClipper) =>
      oldClipper.borderRadius != borderRadius ||
      oldClipper.pathBuilder != pathBuilder;
}

class _CoveSlipSurfacePainter extends CustomPainter {
  final CoveSlipPalette palette;
  final BorderRadius borderRadius;
  final CoveSlipPathBuilder? pathBuilder;

  const _CoveSlipSurfacePainter({
    required this.palette,
    required this.borderRadius,
    required this.pathBuilder,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = pathBuilder != null
        ? pathBuilder!(size)
        : (Path()..addRRect(borderRadius.toRRect(rect)));

    for (final shadow in palette.shadows) {
      final shadowPaint = Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurSigma);
      canvas.save();
      canvas.translate(shadow.offset.dx, shadow.offset.dy);
      canvas.drawPath(path, shadowPaint);
      canvas.restore();
    }

    final fillPaint = Paint()
      ..shader = palette.fillGradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    if (palette.edgeColor != null) {
      final edgePaint = Paint()
        ..color = palette.edgeColor!
        ..style = PaintingStyle.stroke
        ..strokeWidth = CoveSlip.kEdgeStrokeWidth;
      canvas.save();
      canvas.clipPath(path);
      canvas.drawPath(path, edgePaint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CoveSlipSurfacePainter oldDelegate) =>
      oldDelegate.palette.variant != palette.variant ||
      oldDelegate.palette.edgeColor != palette.edgeColor ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.pathBuilder != pathBuilder;
}
