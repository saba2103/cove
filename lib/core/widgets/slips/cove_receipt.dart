import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/cove_tokens.dart';
import '../cove_avatar.dart';
import 'cove_slip.dart';

/// A single purchase row inside a [CoveReceipt] (`design/specs/10-paper-objects.md`).
@immutable
class CoveReceiptItem {
  final CovePerson payer;
  final String? nameOrInitial;
  final String title;
  final String? subtitle;
  final String amount;
  final VoidCallback? onTap;

  const CoveReceiptItem({
    required this.payer,
    this.nameOrInitial,
    required this.title,
    this.subtitle,
    required this.amount,
    this.onTap,
  });
}

/// Household split summary rendered below the total in a [CoveReceipt]
/// (`design/specs/10-paper-objects.md`).
///
/// Both names and formatted amounts are always written beside the bar so
/// colour never carries the split alone (WCAG 1.4.1).
@immutable
class CoveReceiptSplit {
  final String viewerName;
  final String viewerAmount;
  final String partnerName;
  final String partnerAmount;

  /// Viewer's share of the total in `0.0..1.0`.
  final double viewerShare;

  const CoveReceiptSplit({
    required this.viewerName,
    required this.viewerAmount,
    required this.partnerName,
    required this.partnerAmount,
    required this.viewerShare,
  });
}

/// Deterministic bar descriptor for a [CoveReceipt] barcode strip.
@immutable
class CoveBarcodeBar {
  final double heightFactor;
  final double width;

  const CoveBarcodeBar({
    required this.heightFactor,
    required this.width,
  });
}

/// A paper/ink receipt with torn zigzag top/bottom edges (`design/specs/10-paper-objects.md` & `14-add-flow.md` §8).
///
/// Built on [CoveSlip] to the contract in `design/specs/10-paper-objects.md`:
/// - Torn edges top and bottom: zigzag teeth [kToothWidth] (`8dp`) wide ×
///   [kToothHeight] (`6dp`) tall, corner radius [kZeroRadius] (`0dp`).
/// - Centred header: [capsLabel] in [CoveType.capsSlip], [title] (the day or
///   merchant) in [CoveType.slipTitle], and [subtitle] in [CoveType.capsSlip].
/// - Dashed rule, then [items] as rows: [CoveAvatar.inline], title + sub-line,
///   amount right in [CoveType.readout]. Interactive row hover/press plate uses
///   radius [kRowHoverRadius] (`8dp`).
/// - Dashed rule, `TOTAL` caps left, [totalAmount] right in [CoveType.slipFigure].
/// - Split bar ([split]): viewer's share in `accent.fill`, partner's in the
///   rule colour, [kSplitBarHeight] (`4dp`) tall with pill radius, and both
///   names and amounts written beside it.
/// - Barcode strip: [kBarcodeHeight] (`24dp`) tall, derived deterministically
///   from [recordId], followed by [footerDate] in caps.
/// - Optional [stamp], [visibility] line, and [fieldTaps] (`design/specs/14-add-flow.md` §8).
/// - Exposes its state as semantics: `"Receipt, Wednesday, total ₹5,631, 3 items"`.
class CoveReceipt extends StatelessWidget implements CoveSlipObject {
  @override
  final CoveSlipVariant variant;
  final String recordId;
  final String title;
  final String subtitle;
  final String capsLabel;
  final List<CoveReceiptItem> items;
  final String totalLabel;
  final String totalAmount;
  final CoveReceiptSplit? split;
  final String footerDate;
  final String? stamp;
  final bool stampLanded;
  final CoveSlipVisibility? visibility;
  final CoveSlipFieldTaps? fieldTaps;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double kToothWidth = 8.0; // (literal) teeth 8dp wide
  static const double kToothHeight = 6.0; // (literal) teeth 6dp tall
  static const double kZeroRadius =
      0.0; // (literal) Radius 0 — torn paper has no corners
  static const double kRuleHeight = 1.0; // (literal) 1dp dashed rule
  static const double kDashLength = 4.0; // (literal) dash 4
  static const double kDashGap = 4.0; // (literal) gap 4
  static const double kRowHoverRadius = 8.0; // (literal) Row hover plate radius 8
  static const double kSplitBarHeight = 4.0; // (literal) 4dp tall split bar
  static const double kBarcodeHeight = 24.0; // (literal) Barcode strip, 24dp tall
  static const int _kDefaultBarcodeCount = 34;

  const CoveReceipt({
    super.key,
    required this.variant,
    required this.recordId,
    required this.title,
    required this.items,
    required this.totalAmount,
    required this.footerDate,
    this.subtitle = "THE DAY'S SPENDING",
    this.capsLabel = 'COVE · RECEIPT',
    this.totalLabel = 'TOTAL',
    this.split,
    this.stamp,
    this.stampLanded = true,
    this.visibility,
    this.fieldTaps,
    this.onTap,
    this.semanticLabel,
  });

  /// Deterministically derives barcode bars from [recordId] using FNV-1a +
  /// xorshift32 so identical record IDs produce byte-identical renders across
  /// runs.
  static List<CoveBarcodeBar> computeBarcodeBars(
    String recordId, {
    int count = _kDefaultBarcodeCount,
  }) {
    final seedInput = recordId.isEmpty ? 'cove-receipt-default' : recordId;
    var state = 0x811C9DC5;
    for (final unit in seedInput.codeUnits) {
      state ^= unit;
      state = (state * 0x01000193) & 0xFFFFFFFF;
    }
    if (state == 0) {
      state = 0x9E3779B9;
    }

    const heightChoices = <double>[0.42, 0.58, 0.74, 0.88, 1.0];
    const widthChoices = <double>[1.5, 1.5, 2.5];

    final bars = <CoveBarcodeBar>[];
    for (var i = 0; i < count; i++) {
      state ^= (state << 13) & 0xFFFFFFFF;
      state ^= (state >> 17) & 0xFFFFFFFF;
      state ^= (state << 5) & 0xFFFFFFFF;
      state &= 0xFFFFFFFF;

      final hIndex = state % heightChoices.length;
      final wIndex = (state >> 8) % widthChoices.length;
      bars.add(
        CoveBarcodeBar(
          heightFactor: heightChoices[hIndex],
          width: widthChoices[wIndex],
        ),
      );
    }
    return bars;
  }

  /// Builds the torn-paper silhouette path with [kToothWidth] × [kToothHeight]
  /// zigzag teeth along the top and bottom edges and [kZeroRadius] corners.
  static Path buildTornReceiptPath(Size size) {
    final path = Path();
    final width = size.width;
    final height = size.height;
    final toothW = kToothWidth;
    final toothH = kToothHeight;

    if (width <= 0 || height <= toothH * 2) {
      return path..addRect(Offset.zero & size);
    }

    final teethCount = math.max(1, (width / toothW).round());
    final step = width / teethCount;

    // Top zigzag edge: left-to-right
    path.moveTo(0.0, toothH);
    for (var i = 0; i < teethCount; i++) {
      final peakX = (i + 0.5) * step;
      final valleyX = (i + 1) * step;
      path.lineTo(peakX, 0.0);
      path.lineTo(valleyX, toothH);
    }

    // Right vertical edge
    final bottomValleyY = height - toothH;
    path.lineTo(width, bottomValleyY);

    // Bottom zigzag edge: right-to-left
    for (var i = teethCount - 1; i >= 0; i--) {
      final peakX = (i + 0.5) * step;
      final valleyX = i * step;
      path.lineTo(peakX, height);
      path.lineTo(valleyX, bottomValleyY);
    }

    // Left vertical edge
    path.close();
    return path;
  }

  String _buildDefaultSemantics() {
    final count = items.length;
    final itemWord = count == 1 ? '1 item' : '$count items';
    return 'Receipt, $title, total $totalAmount, $itemWord';
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoveSlipPalette.resolve(context, variant);
    final bars = computeBarcodeBars(recordId);

    return CoveSlip(
      variant: variant,
      borderRadius: const BorderRadius.all(Radius.circular(kZeroRadius)),
      pathBuilder: buildTornReceiptPath,
      padding: const EdgeInsets.fromLTRB(
        CoveSpace.gutter,
        CoveSpace.gutter + kToothHeight,
        CoveSpace.gutter,
        CoveSpace.gutter + kToothHeight,
      ),
      onTap: onTap,
      stamp: stamp,
      stampLanded: stampLanded,
      visibility: visibility,
      showVisibilityTopRule: false,
      fieldTaps: fieldTaps,
      semanticLabel: semanticLabel ?? _buildDefaultSemantics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Centred header: caps line, day in slipTitle, caps sub-line
          Text(
            capsLabel.toUpperCase(),
            textAlign: TextAlign.center,
            style: CoveType.capsSlip.copyWith(color: palette.tertiary),
          ),
          const SizedBox(height: CoveSpace.xs),
          CoveSlipFieldTapTarget(
            field: CoveSlipField.title,
            fieldTaps: fieldTaps,
            alignment: Alignment.center,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: CoveType.slipTitle.copyWith(color: palette.title),
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: CoveSpace.xs),
            Text(
              subtitle.toUpperCase(),
              textAlign: TextAlign.center,
              style: CoveType.capsSlip.copyWith(color: palette.tertiary),
            ),
          ],
          const SizedBox(height: CoveSpace.md),

          // 2. Top dashed rule
          _ReceiptDashedRule(color: palette.rule),
          const SizedBox(height: CoveSpace.sm),

          // 3. Line items as rows
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(height: CoveSpace.xs),
            if (i == 0 &&
                fieldTaps != null &&
                fieldTaps!.containsKey(CoveSlipField.category))
              CoveSlipFieldTapTarget(
                field: CoveSlipField.category,
                fieldTaps: fieldTaps,
                child: _ReceiptItemRow(
                  item: items[i],
                  palette: palette,
                ),
              )
            else if (i == 1 &&
                fieldTaps != null &&
                fieldTaps!.containsKey(CoveSlipField.paymentMethod))
              CoveSlipFieldTapTarget(
                field: CoveSlipField.paymentMethod,
                fieldTaps: fieldTaps,
                child: _ReceiptItemRow(
                  item: items[i],
                  palette: palette,
                ),
              )
            else
              _ReceiptItemRow(
                item: items[i],
                palette: palette,
              ),
          ],
          const SizedBox(height: CoveSpace.sm),

          // 4. Bottom dashed rule + TOTAL row
          _ReceiptDashedRule(color: palette.rule),
          const SizedBox(height: CoveSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  totalLabel.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CoveType.capsSlip.copyWith(color: palette.tertiary),
                ),
              ),
              const SizedBox(width: CoveSpace.sm),
              CoveSlipFieldTapTarget(
                field: CoveSlipField.amount,
                fieldTaps: fieldTaps,
                alignment: Alignment.centerRight,
                child: Text(
                  totalAmount,
                  maxLines: 1,
                  softWrap: false,
                  style: CoveType.slipFigure.copyWith(color: palette.title),
                ),
              ),
            ],
          ),

          // 5. Split bar + named amounts beside it (WCAG 1.4.1)
          if (split != null) ...[
            const SizedBox(height: CoveSpace.md),
            CoveSlipFieldTapTarget(
              field: CoveSlipField.paidBy,
              fieldTaps: fieldTaps,
              child: _ReceiptSplitSection(
                split: split!,
                palette: palette,
              ),
            ),
          ],

          // 6. Deterministic barcode strip + date in caps
          const SizedBox(height: CoveSpace.lg),
          SizedBox(
            height: kBarcodeHeight,
            child: CustomPaint(
              painter: _ReceiptBarcodePainter(
                bars: bars,
                color: palette.accent,
              ),
            ),
          ),
          const SizedBox(height: CoveSpace.sm),
          CoveSlipFieldTapTarget(
            field: CoveSlipField.date,
            fieldTaps: fieldTaps,
            alignment: Alignment.center,
            child: Text(
              footerDate.toUpperCase(),
              textAlign: TextAlign.center,
              style: CoveType.capsSlip.copyWith(color: palette.tertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptItemRow extends StatefulWidget {
  final CoveReceiptItem item;
  final CoveSlipPalette palette;

  const _ReceiptItemRow({
    required this.item,
    required this.palette,
  });

  @override
  State<_ReceiptItemRow> createState() => _ReceiptItemRowState();
}

class _ReceiptItemRowState extends State<_ReceiptItemRow> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _interactive => widget.item.onTap != null;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final palette = widget.palette;
    final hasSubtitle = item.subtitle != null && item.subtitle!.trim().isNotEmpty;
    final showPlate = _interactive && (_hovered || _pressed);

    return MouseRegion(
      cursor: _interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
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
          decoration: BoxDecoration(
            color: showPlate ? palette.hairline : Colors.transparent,
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveReceipt.kRowHoverRadius),
            ),
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

class _ReceiptSplitSection extends StatelessWidget {
  final CoveReceiptSplit split;
  final CoveSlipPalette palette;

  const _ReceiptSplitSection({
    required this.split,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final clampedShare = split.viewerShare.clamp(0.0, 1.0);
    final viewerFlex = (clampedShare * 1000).round();
    final partnerFlex = ((1.0 - clampedShare) * 1000).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.pill),
          ),
          child: SizedBox(
            height: CoveReceipt.kSplitBarHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (viewerFlex > 0)
                  Expanded(
                    flex: viewerFlex,
                    child: ColoredBox(color: palette.accentFill),
                  ),
                if (partnerFlex > 0)
                  Expanded(
                    flex: partnerFlex,
                    child: ColoredBox(color: palette.rule),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CoveSpace.sm),
        Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: CoveSpace.sm,
                    height: CoveSpace.sm,
                    decoration: BoxDecoration(
                      color: palette.accentFill,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(CoveSpace.xs / 2),
                      ),
                    ),
                  ),
                  const SizedBox(width: CoveSpace.xs),
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${split.viewerName} ',
                            style: CoveType.rowSub.copyWith(
                              color: palette.tertiary,
                            ),
                          ),
                          TextSpan(
                            text: split.viewerAmount,
                            style: CoveType.rowSub.copyWith(
                              color: palette.secondary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: CoveSpace.sm),
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${split.partnerAmount} ',
                            style: CoveType.rowSub.copyWith(
                              color: palette.secondary,
                            ),
                          ),
                          TextSpan(
                            text: split.partnerName,
                            style: CoveType.rowSub.copyWith(
                              color: palette.tertiary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  const SizedBox(width: CoveSpace.xs),
                  Container(
                    width: CoveSpace.sm,
                    height: CoveSpace.sm,
                    decoration: BoxDecoration(
                      color: palette.rule,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(CoveSpace.xs / 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReceiptDashedRule extends StatelessWidget {
  final Color color;

  const _ReceiptDashedRule({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CoveReceipt.kRuleHeight,
      child: CustomPaint(
        painter: _HorizontalDashedLinePainter(color: color),
      ),
    );
  }
}

class _HorizontalDashedLinePainter extends CustomPainter {
  final Color color;

  const _HorizontalDashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = CoveReceipt.kRuleHeight
      ..style = PaintingStyle.stroke;

    var x = 0.0;
    final y = size.height / 2.0;
    while (x < size.width) {
      final dashEnd = math.min(x + CoveReceipt.kDashLength, size.width);
      canvas.drawLine(Offset(x, y), Offset(dashEnd, y), paint);
      x += CoveReceipt.kDashLength + CoveReceipt.kDashGap;
    }
  }

  @override
  bool shouldRepaint(_HorizontalDashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ReceiptBarcodePainter extends CustomPainter {
  final List<CoveBarcodeBar> bars;
  final Color color;

  const _ReceiptBarcodePainter({
    required this.bars,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty || size.width <= 0 || size.height <= 0) return;

    const gap = CoveSpace.xs;
    var totalWidth = 0.0;
    for (var i = 0; i < bars.length; i++) {
      if (i > 0) totalWidth += gap;
      totalWidth += bars[i].width;
    }

    // Fit cleanly inside narrow viewports (e.g. cover 320dp) while centering.
    final scale = totalWidth > size.width ? size.width / totalWidth : 1.0;
    final scaledWidth = totalWidth * scale;
    var x = (size.width - scaledWidth) / 2.0;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final bar in bars) {
      final w = bar.width * scale;
      final h = size.height * bar.heightFactor;
      final top = size.height - h;
      canvas.drawRect(Rect.fromLTWH(x, top, w, h), paint);
      x += w + (gap * scale);
    }
  }

  @override
  bool shouldRepaint(_ReceiptBarcodePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.bars != bars;
}
