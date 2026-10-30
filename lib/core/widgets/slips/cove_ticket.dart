import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../shape/cove_shape.dart';
import '../../theme/cove_tokens.dart';
import 'cove_slip.dart';

/// A paper/ink event ticket (`design/specs/10-paper-objects.md` & `14-add-flow.md` §8).
///
/// Built on [CoveSlip] to the contract in `design/specs/10-paper-objects.md`:
/// - Main body left: caps line ([capsLabel], default `'COVE · PLAN'`) in
///   [CoveType.capsSlip], [title] in [CoveType.slipTitle], optional [location]
///   in [CoveType.readout], [date] in [CoveType.readout], and [owner]
///   (e.g. `'Both of you'`) in [CoveType.readout].
/// - Stub on the right, [kStubWidth] (`112dp`) wide: caps `'STARTS'`
///   ([stubLabel]) in [CoveType.capsSlip], [hour] in [CoveType.slipFigure],
///   and [meridiem] in [CoveType.capsSlip].
/// - Between them a perforation: [kPerforationWidth] (`1dp`) dashed line
///   (dash [kDashLength] `4dp` / gap [kDashGap] `4dp`) in the rule colour,
///   with a [kNotchDiameter] (`16dp`) semicircle notch bitten out at the top
///   and bottom edge.
/// - A [kSpineWidth] (`2dp`) accent spine down the left edge.
/// - Optional [stamp], [visibility] line, and [fieldTaps] (`design/specs/14-add-flow.md` §8).
/// - Exposes its complete state as a single semantic label for assistive tech.
class CoveTicket extends StatelessWidget implements CoveSlipObject {
  @override
  final CoveSlipVariant variant;
  final String title;
  final String? location;
  final String date;
  final String owner;
  final String hour;
  final String? meridiem;
  final String capsLabel;
  final String stubLabel;
  final String? alertText;
  final String? stamp;
  final bool stampLanded;
  final CoveSlipVisibility? visibility;
  final CoveSlipFieldTaps? fieldTaps;
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
    this.location,
    required this.date,
    required this.owner,
    required this.hour,
    this.meridiem,
    this.capsLabel = 'COVE · PLAN',
    this.stubLabel = 'STARTS',
    this.alertText,
    this.stamp,
    this.stampLanded = true,
    this.visibility,
    this.fieldTaps,
    this.onTap,
    this.semanticLabel,
  });

  String _buildDefaultSemantics() {
    final timePart = (meridiem != null && meridiem!.trim().isNotEmpty)
        ? '$hour ${meridiem!.trim()}'
        : hour;
    final locPart = (location != null && location!.trim().isNotEmpty)
        ? ', ${location!.trim()}'
        : '';
    final base = 'Ticket, $title$locPart, $date, starts $timePart, $owner';
    if (alertText != null && alertText!.trim().isNotEmpty) {
      return '$base, ${alertText!.trim()}';
    }
    return base;
  }

  static Path _buildTicketPath(Size size) {
    final rect = Offset.zero & size;
    final cardPath = smoothCornerPath(rect, radius: CoveRadius.card);

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
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isScaled = textScale > 1.0;
    final stackStub = isScaled &&
        (MediaQuery.sizeOf(context).width / textScale) <
            CoveSize.compactThreshold;
    final hasMeridiem = meridiem != null && meridiem!.trim().isNotEmpty;
    final hasAlert = alertText != null && alertText!.trim().isNotEmpty;
    final hasLocation = location != null && location!.trim().isNotEmpty;

    final leftColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CoveSlipFieldTapTarget(
          field: CoveSlipField.title,
          fieldTaps: fieldTaps,
          child: CoveSlip.buildHeader(
            palette: palette,
            capsLabel: capsLabel,
            title: title,
          ),
        ),
        if (hasLocation) ...[
          const SizedBox(height: CoveSpace.xs),
          CoveSlipFieldTapTarget(
            field: CoveSlipField.location,
            fieldTaps: fieldTaps,
            child: Text(
              location!,
              style: CoveType.readout.copyWith(
                color: palette.secondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: CoveSpace.xs),
        CoveSlipFieldTapTarget(
          field: CoveSlipField.date,
          fieldTaps: fieldTaps,
          child: Text(
            date,
            style: CoveType.readout.copyWith(
              color: palette.secondary,
            ),
          ),
        ),
        const SizedBox(height: CoveSpace.sm),
        CoveSlipFieldTapTarget(
          field: CoveSlipField.owner,
          fieldTaps: fieldTaps,
          child: Text(
            owner,
            style: CoveType.readout.copyWith(
              color: palette.tertiary,
            ),
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
        if (visibility != null && !stackStub)
          CoveSlipVisibilityLine(
            visibility: visibility!,
            palette: palette,
            showTopRule: true,
            fieldTaps: fieldTaps,
          ),
      ],
    );

    return CoveSlip(
      variant: variant,
      padding: EdgeInsets.zero,
      pathBuilder: stackStub ? null : _buildTicketPath,
      foregroundPainter: _CoveTicketDecorationPainter(
        spineColor: palette.accent,
        ruleColor: palette.rule,
        drawVerticalPerforation: !stackStub,
      ),
      onTap: onTap,
      stamp: stamp,
      stampLanded: stampLanded,
      visibility: visibility,
      renderVisibilityInSlip: stackStub,
      fieldTaps: fieldTaps,
      semanticLabel: semanticLabel ?? _buildDefaultSemantics(),
      child: stackStub
          ? Padding(
              padding: const EdgeInsets.all(CoveSpace.gutter),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  leftColumn,
                  const SizedBox(height: CoveSpace.md),
                  SizedBox(
                    height: kPerforationWidth,
                    child: CustomPaint(
                      painter: _TicketHorizontalDashedPainter(
                        color: palette.rule,
                      ),
                    ),
                  ),
                  const SizedBox(height: CoveSpace.md),
                  CoveSlipFieldTapTarget(
                    field: CoveSlipField.time,
                    fieldTaps: fieldTaps,
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: CoveSpace.sm,
                      runSpacing: CoveSpace.xs,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: CoveSpace.xs),
                          child: Text(
                            stubLabel.toUpperCase(),
                            style: CoveType.capsSlip.copyWith(
                              color: palette.tertiary,
                            ),
                          ),
                        ),
                        Text(
                          hour,
                          style: CoveType.slipFigure.copyWith(
                            color: palette.title,
                          ),
                        ),
                        if (hasMeridiem)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: CoveSpace.xs,
                            ),
                            child: Text(
                              meridiem!.toUpperCase(),
                              style: CoveType.capsSlip.copyWith(
                                color: palette.tertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(CoveSpace.gutter),
                      child: leftColumn,
                    ),
                  ),
                  SizedBox(
                    width: kStubWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.md,
                        vertical: CoveSpace.gutter,
                      ),
                      child: CoveSlipFieldTapTarget(
                        field: CoveSlipField.time,
                        fieldTaps: fieldTaps,
                        alignment: Alignment.center,
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
                  ),
                ],
              ),
            ),
    );
  }
}

class _TicketHorizontalDashedPainter extends CustomPainter {
  final Color color;

  const _TicketHorizontalDashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = CoveTicket.kPerforationWidth
      ..style = PaintingStyle.stroke;

    var x = 0.0;
    final y = size.height / 2.0;
    while (x < size.width) {
      final dashEnd = math.min(x + CoveTicket.kDashLength, size.width);
      canvas.drawLine(Offset(x, y), Offset(dashEnd, y), paint);
      x += CoveTicket.kDashLength + CoveTicket.kDashGap;
    }
  }

  @override
  bool shouldRepaint(_TicketHorizontalDashedPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CoveTicketDecorationPainter extends CustomPainter {
  final Color spineColor;
  final Color ruleColor;
  final bool drawVerticalPerforation;

  const _CoveTicketDecorationPainter({
    required this.spineColor,
    required this.ruleColor,
    this.drawVerticalPerforation = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Left accent spine (2dp wide down the straight left edge between corner radii)
    final spinePaint = Paint()
      ..color = spineColor
      ..style = PaintingStyle.fill;
    final spineTop = math.min(CoveRadius.card, size.height / 2.0);
    final spineBottom = math.max(spineTop, size.height - CoveRadius.card);
    canvas.drawPath(
      smoothCornerPath(
        Rect.fromLTRB(0.0, spineTop, CoveTicket.kSpineWidth, spineBottom),
        radius: CoveTicket.kSpineWidth,
      ),
      spinePaint,
    );

    if (!drawVerticalPerforation) return;

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
      oldDelegate.ruleColor != ruleColor ||
      oldDelegate.drawVerticalPerforation != drawVerticalPerforation;
}
