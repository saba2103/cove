import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/cove_tokens.dart';
import 'cove_slip.dart';

/// A paper/ink event ticket (`design/specs/10-paper-objects.md`).
///
/// Built on [CoveSlip] to the contract in `design/specs/10-paper-objects.md`:
/// - Main body left: caps line ([capsLabel], default `'COVE · PLAN'`) in
///   [CoveType.capsSlip], [title] in [CoveType.slipTitle], [date] in
///   [CoveType.readout], and [owner] (e.g. `'Both of you'`) in
///   [CoveType.readout].
/// - Stub on the right, [kStubWidth] (`112dp`) wide: caps `'STARTS'`
///   ([stubLabel]) in [CoveType.capsSlip], [hour] in [CoveType.slipFigure],
///   and [meridiem] in [CoveType.capsSlip].
/// - Between them a perforation: [kPerforationWidth] (`1dp`) dashed line
///   (dash [kDashLength] `4dp` / gap [kDashGap] `4dp`) in the rule colour,
///   with a [kNotchDiameter] (`16dp`) semicircle notch bitten out at the top
///   and bottom edge.
/// - A [kSpineWidth] (`2dp`) accent spine down the left edge.
/// - Exposes its complete state as a single semantic label for assistive tech.
class CoveTicket extends StatelessWidget implements CoveSlipObject {
  @override
  final CoveSlipVariant variant;
  final String title;
  final String date;
  final String owner;
  final String hour;
  final String? meridiem;
  final String capsLabel;
  final String stubLabel;
  final String? alertText;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double kStubWidth = 112.0; // (literal) stub on the right, 112 wide
  static const double kNotchDiameter =
      16.0; // (literal) 16dp semicircle notch at top & bottom
  static const double kPerforationWidth =
      1.0; // (literal) 1dp dashed perforation line
  static const double kDashLength = 4.0; // (literal) dash 4
  static const double kDashGap = 4.0; // (literal) gap 4
  static const double kSpineWidth =
      2.0; // (literal) 2dp accent spine down the left edge

  const CoveTicket({
    super.key,
    required this.variant,
    required this.title,
    required this.date,
    required this.owner,
    required this.hour,
    this.meridiem,
    this.capsLabel = 'COVE · PLAN',
    this.stubLabel = 'STARTS',
    this.alertText,
    this.onTap,
    this.semanticLabel,
  });

  String _buildDefaultSemantics() {
    final timePart = (meridiem != null && meridiem!.trim().isNotEmpty)
        ? '$hour ${meridiem!.trim()}'
        : hour;
    final base = 'Ticket, $title, $date, starts $timePart, $owner';
    if (alertText != null && alertText!.trim().isNotEmpty) {
      return '$base, ${alertText!.trim()}';
    }
    return base;
  }

  static Path _buildTicketPath(Size size) {
    final rect = Offset.zero & size;
    final cardPath = Path()
      ..addRRect(
        const BorderRadius.all(
          Radius.circular(CoveRadius.card),
        ).toRRect(rect),
      );

    final notchRadius = kNotchDiameter / 2.0;
    final perfX = math.max(notchRadius, size.width - kStubWidth);

    final notchesPath = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(perfX, 0.0),
          radius: notchRadius,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(perfX, size.height),
          radius: notchRadius,
        ),
      );

    return Path.combine(PathOperation.difference, cardPath, notchesPath);
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoveSlipPalette.resolve(context, variant);
    final hasMeridiem = meridiem != null && meridiem!.trim().isNotEmpty;
    final hasAlert = alertText != null && alertText!.trim().isNotEmpty;

    return CoveSlip(
      variant: variant,
      padding: EdgeInsets.zero,
      pathBuilder: _buildTicketPath,
      foregroundPainter: _CoveTicketDecorationPainter(
        spineColor: palette.accent,
        ruleColor: palette.rule,
      ),
      onTap: onTap,
      semanticLabel: semanticLabel ?? _buildDefaultSemantics(),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(CoveSpace.gutter),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CoveSlip.buildHeader(
                      palette: palette,
                      capsLabel: capsLabel,
                      title: title,
                    ),
                    const SizedBox(height: CoveSpace.xs),
                    Text(
                      date,
                      style: CoveType.readout.copyWith(
                        color: palette.secondary,
                      ),
                    ),
                    const SizedBox(height: CoveSpace.sm),
                    Text(
                      owner,
                      style: CoveType.readout.copyWith(
                        color: palette.tertiary,
                      ),
                    ),
                    if (hasAlert) ...[
                      const SizedBox(height: CoveSpace.xs),
                      Text(
                        alertText!,
                        style: CoveType.rowSub.copyWith(
                          color: palette.alertText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(
              width: kStubWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoveSpace.md,
                  vertical: CoveSpace.gutter,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      stubLabel.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: CoveType.capsSlip.copyWith(
                        color: palette.tertiary,
                      ),
                    ),
                    const SizedBox(height: CoveSpace.xs),
                    Text(
                      hour,
                      textAlign: TextAlign.center,
                      style: CoveType.slipFigure.copyWith(
                        color: palette.title,
                      ),
                    ),
                    if (hasMeridiem) ...[
                      const SizedBox(height: CoveSpace.xs),
                      Text(
                        meridiem!.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: CoveType.capsSlip.copyWith(
                          color: palette.tertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoveTicketDecorationPainter extends CustomPainter {
  final Color spineColor;
  final Color ruleColor;

  const _CoveTicketDecorationPainter({
    required this.spineColor,
    required this.ruleColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Left accent spine (2dp wide down the straight left edge between corner radii)
    final spinePaint = Paint()
      ..color = spineColor
      ..style = PaintingStyle.fill;
    final spineTop = math.min(CoveRadius.card, size.height / 2.0);
    final spineBottom = math.max(spineTop, size.height - CoveRadius.card);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0.0, spineTop, CoveTicket.kSpineWidth, spineBottom),
        const Radius.circular(CoveTicket.kSpineWidth),
      ),
      spinePaint,
    );

    // 2. Vertical dashed perforation line between the top and bottom 16dp semicircle notches
    final notchRadius = CoveTicket.kNotchDiameter / 2.0;
    final perfX = math.max(notchRadius, size.width - CoveTicket.kStubWidth);
    final startY = notchRadius;
    final endY = math.max(startY, size.height - notchRadius);

    final dashPaint = Paint()
      ..color = ruleColor
      ..strokeWidth = CoveTicket.kPerforationWidth
      ..style = PaintingStyle.stroke;

    var y = startY;
    while (y < endY) {
      final dashEnd = math.min(y + CoveTicket.kDashLength, endY);
      canvas.drawLine(
        Offset(perfX, y),
        Offset(perfX, dashEnd),
        dashPaint,
      );
      y += CoveTicket.kDashLength + CoveTicket.kDashGap;
    }
  }

  @override
  bool shouldRepaint(_CoveTicketDecorationPainter oldDelegate) =>
      oldDelegate.spineColor != spineColor ||
      oldDelegate.ruleColor != ruleColor;
}
