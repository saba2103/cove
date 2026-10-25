import 'dart:math' as math;

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

/// Optional footer visibility line on a slip (`design/specs/14-add-flow.md` §8).
enum CoveSlipVisibility {
  /// Shared with partner (`BOTH CAN SEE IT`).
  bothCanSee,

  /// Private to viewer (`ONLY YOU CAN SEE IT`).
  onlyYouCanSee;

  String get label => this == CoveSlipVisibility.bothCanSee
      ? 'BOTH CAN SEE IT'
      : 'ONLY YOU CAN SEE IT';

  String get semanticLabel => this == CoveSlipVisibility.bothCanSee
      ? 'both can see it'
      : 'only you can see it';

  IconData get icon => this == CoveSlipVisibility.bothCanSee
      ? Icons.visibility_outlined
      : Icons.lock_outline;
}

/// Tappable field identifiers across Cove slips on the Add review step (`design/specs/14-add-flow.md` §8).
enum CoveSlipField {
  title('title'),
  amount('amount'),
  date('date'),
  time('time'),
  category('category'),
  paidBy('paid by'),
  paymentMethod('payment method'),
  location('location'),
  owner('owner'),
  list('list'),
  cadence('cadence'),
  visibility('visibility'),
  dueDate('due date'),
  paidFrom('paid from'),
  installments('installments'),
  duration('duration'),
  days('days');

  final String label;
  const CoveSlipField(this.label);

  String get semanticLabel => 'Change $label';
}

/// Map from a slip's fields to callbacks for review-step editing (`design/specs/14-add-flow.md` §8).
typedef CoveSlipFieldTaps = Map<CoveSlipField, VoidCallback>;

/// Wraps a slip field in a `48dp` minimum hit target with `'Change {field}'`
/// semantics when [field] is present in [fieldTaps].
///
/// When [fieldTaps] is `null` or does not contain [field], returns [child]
/// unchanged so existing non-interactive slips are byte-for-byte identical.
class CoveSlipFieldTapTarget extends StatelessWidget {
  final CoveSlipField field;
  final CoveSlipFieldTaps? fieldTaps;
  final Widget child;
  final AlignmentGeometry alignment;

  const CoveSlipFieldTapTarget({
    super.key,
    required this.field,
    required this.fieldTaps,
    required this.child,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    final callback = fieldTaps?[field];
    if (callback == null) {
      return child;
    }

    return Semantics(
      container: true,
      button: true,
      label: field.semanticLabel,
      onTap: callback,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: callback,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.hit,
            ),
            child: Align(
              alignment: alignment,
              widthFactor: 1.0,
              heightFactor: 1.0,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared stamp widget for `PAID` and `ADDED` (`design/specs/14-add-flow.md` §8).
///
/// Renders an outlined caps label rotated −8°.
class CoveSlipStamp extends StatelessWidget {
  final String text;
  final Color color;
  final Color? backgroundColor;

  static const double kStampDegrees = -8.0; // (literal) rotated -8°
  static const double kStampBorder = 1.5; // (literal) outlined stamp stroke
  static const double kStampRadius = 4.0; // (literal) stamp corner radius

  const CoveSlipStamp({
    super.key,
    required this.text,
    required this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: kStampDegrees * math.pi / 180.0,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.sm,
          vertical: CoveSpace.xs / 2,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.all(
            Radius.circular(kStampRadius),
          ),
          border: Border.all(
            color: color,
            width: kStampBorder,
          ),
        ),
        child: Text(
          text.toUpperCase(),
          style: CoveType.capsSlip.copyWith(color: color),
        ),
      ),
    );
  }
}

/// Shared footer visibility line (`BOTH CAN SEE IT` / `ONLY YOU CAN SEE IT`)
/// rendered on slips when `visibility` is provided (`design/specs/14-add-flow.md` §8).
class CoveSlipVisibilityLine extends StatelessWidget {
  final CoveSlipVisibility visibility;
  final CoveSlipPalette palette;
  final bool showTopRule;
  final CoveSlipFieldTaps? fieldTaps;

  static const double kIconSize = 14.0; // (literal) 14dp visibility glyph
  static const double kRuleHeight = 1.0; // (literal) 1dp dashed rule
  static const double kDashLength = 4.0; // (literal) dash 4
  static const double kDashGap = 4.0; // (literal) gap 4

  const CoveSlipVisibilityLine({
    super.key,
    required this.visibility,
    required this.palette,
    this.showTopRule = true,
    this.fieldTaps,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          visibility.icon,
          size: kIconSize,
          color: palette.tertiary,
        ),
        const SizedBox(width: CoveSpace.xs),
        Flexible(
          child: Text(
            visibility.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: CoveType.capsSlip.copyWith(color: palette.tertiary),
          ),
        ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: CoveSpace.md),
        if (showTopRule) ...[
          SizedBox(
            height: kRuleHeight,
            child: CustomPaint(
              painter: _SlipHorizontalDashedPainter(color: palette.rule),
            ),
          ),
          const SizedBox(height: CoveSpace.md),
        ],
        Center(
          child: CoveSlipFieldTapTarget(
            field: CoveSlipField.visibility,
            fieldTaps: fieldTaps,
            alignment: Alignment.center,
            child: row,
          ),
        ),
      ],
    );
  }
}

class _SlipHorizontalDashedPainter extends CustomPainter {
  final Color color;

  const _SlipHorizontalDashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = CoveSlipVisibilityLine.kRuleHeight
      ..style = PaintingStyle.stroke;

    var x = 0.0;
    final y = size.height / 2.0;
    while (x < size.width) {
      final dashEnd = math.min(
        x + CoveSlipVisibilityLine.kDashLength,
        size.width,
      );
      canvas.drawLine(Offset(x, y), Offset(dashEnd, y), paint);
      x += CoveSlipVisibilityLine.kDashLength + CoveSlipVisibilityLine.kDashGap;
    }
  }

  @override
  bool shouldRepaint(_SlipHorizontalDashedPainter oldDelegate) =>
      oldDelegate.color != color;
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

/// Shared interface implemented by every Cove slip widget, exposing its
/// [variant] (`paper` vs `ink`).
abstract interface class CoveSlipObject implements Widget {
  CoveSlipVariant get variant;
}

/// Shared frame for all Cove paper objects (`design/specs/10-paper-objects.md` & `14-add-flow.md` §8).
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
/// - Optional [stamp] (e.g. `'ADDED'` or `'PAID'`) + [stampLanded] state.
/// - Optional [visibility] footer line (`BOTH CAN SEE IT` / `ONLY YOU CAN SEE IT`).
/// - Semantics: wraps the slip in a single [Semantics] node when
///   [semanticLabel] is provided and no interactive [fieldTaps] are active.
class CoveSlip extends StatelessWidget implements CoveSlipObject {
  @override
  final CoveSlipVariant variant;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final CoveSlipPathBuilder? pathBuilder;
  final CustomPainter? backgroundPainter;
  final CustomPainter? foregroundPainter;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final String? stamp;
  final bool stampLanded;
  final Color? stampColor;
  final CoveSlipVisibility? visibility;
  final bool showVisibilityTopRule;
  final bool renderVisibilityInSlip;
  final CoveSlipFieldTaps? fieldTaps;

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
    this.stamp,
    this.stampLanded = true,
    this.stampColor,
    this.visibility,
    this.showVisibilityTopRule = true,
    this.renderVisibilityInSlip = true,
    this.fieldTaps,
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

    Widget innerChild = child;
    if (visibility != null && renderVisibilityInSlip) {
      innerChild = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          child,
          CoveSlipVisibilityLine(
            visibility: visibility!,
            palette: palette,
            showTopRule: showVisibilityTopRule,
            fieldTaps: fieldTaps,
          ),
        ],
      );
    }

    Widget content = Theme(
      data: innerTheme,
      child: Padding(
        padding: padding,
        child: innerChild,
      ),
    );

    if (stamp != null && stamp!.trim().isNotEmpty && stampLanded) {
      final resolvedStampColor = stampColor ??
          (stamp!.trim().toUpperCase() == 'PAID'
              ? palette.statusGood
              : palette.accent);
      content = Stack(
        children: [
          content,
          Positioned(
            top: CoveSpace.gutter,
            right: CoveSpace.gutter,
            child: IgnorePointer(
              child: CoveSlipStamp(
                text: stamp!,
                color: resolvedStampColor,
              ),
            ),
          ),
        ],
      );
    }

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

    final hasFieldTaps = fieldTaps != null && fieldTaps!.isNotEmpty;

    if (onTap != null && !hasFieldTaps) {
      slipBody = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: slipBody,
      );
    }

    if (semanticLabel != null) {
      var resolvedSemantics = semanticLabel!;
      if (visibility != null) {
        resolvedSemantics = '$resolvedSemantics, ${visibility!.semanticLabel}';
      }
      if (stamp != null && stamp!.trim().isNotEmpty && stampLanded) {
        resolvedSemantics =
            '$resolvedSemantics, ${stamp!.trim().toLowerCase()}';
      }
      if (hasFieldTaps) {
        slipBody = Semantics(
          container: true,
          label: resolvedSemantics,
          child: slipBody,
        );
      } else {
        slipBody = Semantics(
          container: true,
          button: onTap != null,
          label: resolvedSemantics,
          child: ExcludeSemantics(child: slipBody),
        );
      }
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
