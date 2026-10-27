import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shape/cove_shape.dart';
import '../../theme/cove_tokens.dart';
import '../cove_avatar.dart';
import 'cove_receipt.dart';
import 'cove_slip.dart';

/// Semantic spending categories mapped to [CoveTokens] (`design/specs/10b-dial.md`).
enum CoveCategory {
  travel,
  groceries,
  health,
  eatingOut,
  home,
  pets,
  fuel,
  gifts,
}

/// A category summary slip with a 160dp spending-share dial and receipt-style
/// recent purchase rows (`design/specs/10b-dial.md`).
///
/// Built on [CoveSlip] (defaults to [CoveSlipVariant.paper]):
/// - Caps line: `COVE · CATEGORY` in [CoveType.capsSlip].
/// - Title: the category name in [CoveType.slipTitle].
/// - Dial: a donut, [kDialDiameter] (`160dp`) diameter, [kDialStroke] (`12dp`)
///   stroke. Track in the palette's `rule`. Arc = [share] of the month's
///   spending, starting at 12 o'clock, clockwise, in the category's colour.
/// - Colour rule: on [CoveSlipVariant.paper], category colours ALWAYS come from
///   [CoveTokens.light], never from `context.cv`, so every category arc clears
///   `3:1` against the paper gradient in both dark and light app themes.
/// - Centre: [amount] in [CoveType.slipFigure], `"this month"` in
///   [CoveType.capsSlip] beneath.
/// - Below: recent purchases ([items]) rendered as receipt-style rows.
/// - Semantics: `"Category, Groceries, ₹12,400 this month, 31% of spending, 14 purchases"`.
class CoveDial extends StatelessWidget implements CoveSlipObject {
  @override
  final CoveSlipVariant variant;
  final String title;
  final CoveCategory? category;
  final String amount;

  /// Category's share of the month's spending in `0.0..1.0`.
  final double share;
  final List<CoveReceiptItem> items;
  final int? purchaseCount;
  final String capsLabel;
  final String periodLabel;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double kDialDiameter = 160.0; // (literal) 160dp dial diameter
  static const double kDialStroke = 12.0; // (literal) 12dp dial stroke
  static const double kRuleHeight = 1.0; // (literal) 1dp dashed rule
  static const double kDashLength = 4.0; // (literal) dash 4
  static const double kDashGap = 4.0; // (literal) gap 4
  static const double kRowHoverRadius = 8.0; // (literal) Row hover plate radius 8

  const CoveDial({
    super.key,
    this.variant = CoveSlipVariant.paper,
    required this.title,
    this.category,
    required this.amount,
    required this.share,
    this.items = const <CoveReceiptItem>[],
    this.purchaseCount,
    this.capsLabel = 'COVE · CATEGORY',
    this.periodLabel = 'this month',
    this.onTap,
    this.semanticLabel,
  });

  /// Resolves the category colour for [category] on [variant].
  ///
  /// On [CoveSlipVariant.paper], always reads from [CoveTokens.light] (never
  /// ambient `context.cv`) so dark-mode tokens like `#E0C98A` never wash out on
  /// cream paper.
  static Color colorForCategory(
    CoveCategory category, {
    CoveSlipVariant variant = CoveSlipVariant.paper,
  }) {
    final tokens = variant == CoveSlipVariant.paper
        ? CoveTokens.light
        : CoveTokens.dark;
    switch (category) {
      case CoveCategory.travel:
        return tokens.categoryTravel;
      case CoveCategory.groceries:
        return tokens.categoryGroceries;
      case CoveCategory.health:
        return tokens.categoryHealth;
      case CoveCategory.eatingOut:
        return tokens.categoryEatingOut;
      case CoveCategory.home:
        return tokens.categoryHome;
      case CoveCategory.pets:
        return tokens.categoryPets;
      case CoveCategory.fuel:
        return tokens.categoryFuel;
      case CoveCategory.gifts:
        return tokens.categoryGifts;
    }
  }

  /// Infers a [CoveCategory] from a display [name] string.
  static CoveCategory inferCategory(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('travel') ||
        lower.contains('flight') ||
        lower.contains('trip')) {
      return CoveCategory.travel;
    }
    if (lower.contains('grocer') || lower.contains('market')) {
      return CoveCategory.groceries;
    }
    if (lower.contains('health') ||
        lower.contains('dentist') ||
        lower.contains('med') ||
        lower.contains('shop')) {
      return CoveCategory.health;
    }
    if (lower.contains('eat') ||
        lower.contains('dining') ||
        lower.contains('restaurant') ||
        lower.contains('cafe') ||
        lower.contains('food')) {
      return CoveCategory.eatingOut;
    }
    if (lower.contains('home') ||
        lower.contains('utilit') ||
        lower.contains('electric') ||
        lower.contains('rent')) {
      return CoveCategory.home;
    }
    if (lower.contains('pet') ||
        lower.contains('lyla') ||
        lower.contains('cabo') ||
        lower.contains('luca')) {
      return CoveCategory.pets;
    }
    if (lower.contains('fuel') ||
        lower.contains('petrol') ||
        lower.contains('auto') ||
        lower.contains('transport')) {
      return CoveCategory.fuel;
    }
    if (lower.contains('gift') ||
        lower.contains('entertain') ||
        lower.contains('stream')) {
      return CoveCategory.gifts;
    }
    return CoveCategory.groceries;
  }

  /// Resolves the category arc colour for this dial.
  Color resolveArcColor() {
    final resolvedCategory = category ?? inferCategory(title);
    return colorForCategory(resolvedCategory, variant: variant);
  }

  String _buildDefaultSemantics() {
    final pct = (share.clamp(0.0, 1.0) * 100).round();
    final count = purchaseCount ?? items.length;
    final purchaseWord = count == 1 ? '1 purchase' : '$count purchases';
    return 'Category, $title, $amount $periodLabel, $pct% of spending, $purchaseWord';
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoveSlipPalette.resolve(context, variant);
    final arcColor = resolveArcColor();
    final clampedShare = share.clamp(0.0, 1.0);

    return CoveSlip(
      variant: variant,
      onTap: onTap,
      semanticLabel: semanticLabel ?? _buildDefaultSemantics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: COVE · CATEGORY + category name in slipTitle
          CoveSlip.buildHeader(
            palette: palette,
            capsLabel: capsLabel,
            title: title,
          ),
          const SizedBox(height: CoveSpace.lg),

          // 2. 160dp donut dial with centred figure and "THIS MONTH" caps
          Center(
            child: SizedBox(
              width: kDialDiameter,
              height: kDialDiameter,
              child: CustomPaint(
                painter: _CoveDialRingPainter(
                  trackColor: palette.rule,
                  arcColor: arcColor,
                  share: clampedShare,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kDialStroke + CoveSpace.sm,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          amount,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: CoveType.slipFigure.copyWith(
                            color: palette.title,
                          ),
                        ),
                      ),
                      const SizedBox(height: CoveSpace.xs),
                      Text(
                        periodLabel.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: CoveType.capsSlip.copyWith(
                          color: palette.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Receipt-style recent purchase rows below
          if (items.isNotEmpty) ...[
            const SizedBox(height: CoveSpace.lg),
            _DialDashedRule(color: palette.rule),
            const SizedBox(height: CoveSpace.sm),
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(height: CoveSpace.xs),
              _DialReceiptRow(
                item: items[i],
                palette: palette,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CoveDialRingPainter extends CustomPainter {
  final Color trackColor;
  final Color arcColor;
  final double share;

  const _CoveDialRingPainter({
    required this.trackColor,
    required this.arcColor,
    required this.share,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final radius =
        (math.min(size.width, size.height) - CoveDial.kDialStroke) / 2.0;
    if (radius <= 0) return;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = CoveDial.kDialStroke;
    canvas.drawCircle(center, radius, trackPaint);

    final clamped = share.clamp(0.0, 1.0);
    if (clamped <= 0.0) return;

    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = CoveDial.kDialStroke
      ..strokeCap = clamped >= 1.0 ? StrokeCap.butt : StrokeCap.round;

    const startAngle = -math.pi / 2.0; // 12 o'clock
    final sweepAngle = 2.0 * math.pi * clamped;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_CoveDialRingPainter oldDelegate) =>
      oldDelegate.trackColor != trackColor ||
      oldDelegate.arcColor != arcColor ||
      oldDelegate.share != share;
}

class _DialDashedRule extends StatelessWidget {
  final Color color;

  const _DialDashedRule({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CoveDial.kRuleHeight,
      child: CustomPaint(
        painter: _DialHorizontalDashedPainter(color: color),
      ),
    );
  }
}

class _DialHorizontalDashedPainter extends CustomPainter {
  final Color color;

  const _DialHorizontalDashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = CoveDial.kRuleHeight
      ..style = PaintingStyle.stroke;

    var x = 0.0;
    final y = size.height / 2.0;
    while (x < size.width) {
      final dashEnd = math.min(x + CoveDial.kDashLength, size.width);
      canvas.drawLine(Offset(x, y), Offset(dashEnd, y), paint);
      x += CoveDial.kDashLength + CoveDial.kDashGap;
    }
  }

  @override
  bool shouldRepaint(_DialHorizontalDashedPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DialReceiptRow extends StatefulWidget {
  final CoveReceiptItem item;
  final CoveSlipPalette palette;

  const _DialReceiptRow({
    required this.item,
    required this.palette,
  });

  @override
  State<_DialReceiptRow> createState() => _DialReceiptRowState();
}

class _DialReceiptRowState extends State<_DialReceiptRow> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _interactive => widget.item.onTap != null;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final palette = widget.palette;
    final hasSubtitle =
        item.subtitle != null && item.subtitle!.trim().isNotEmpty;
    final showPlate = _interactive && (_hovered || _pressed);

    return MouseRegion(
      cursor:
          _interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: _interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: _interactive ? (_) => setState(() => _hovered = false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: item.onTap,
        onTapDown: _interactive ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _interactive ? (_) => setState(() => _pressed = false) : null,
        onTapCancel:
            _interactive ? () => setState(() => _pressed = false) : null,
        child: AnimatedContainer(
          duration: CoveMotion.q(context),
          curve: CoveMotion.easing,
          padding: const EdgeInsets.symmetric(
            horizontal: CoveSpace.xs,
            vertical: CoveSpace.xs,
          ),
          decoration: CoveShape.decoration(
            CoveDial.kRowHoverRadius,
            color: showPlate ? palette.hairline : Colors.transparent,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CoveAvatar.inline(
                person: item.payer,
                nameOrInitial: item.nameOrInitial,
              ),
              const SizedBox(width: CoveSpace.sm),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CoveType.rowTitle.copyWith(color: palette.title),
                    ),
                    if (hasSubtitle) ...[
                      Text(
                        item.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CoveType.rowSub.copyWith(
                          color: palette.tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: CoveSpace.sm),
              Text(
                item.amount,
                maxLines: 1,
                softWrap: false,
                style: CoveType.readout.copyWith(
                  color: palette.title,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
