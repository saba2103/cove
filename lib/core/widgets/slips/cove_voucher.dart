import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/cove_tokens.dart';
import 'cove_slip.dart';

/// Payment state of a [CoveVoucher] (`design/specs/10-paper-objects.md`).
enum CoveVoucherState {
  /// Upcoming or due now — due circle highlighted in `accent.fill`.
  due,

  /// Settled — `PAID` stamp in `status.good` rotated −8°, due circle faded to rule colour.
  paid,
}

/// A commitment / EMI voucher slip (`design/specs/10-paper-objects.md` & `14-add-flow.md` §8).
///
/// Built on [CoveSlip] to the contract in `design/specs/10-paper-objects.md`:
/// - Perforated rail down the left: [kRailWidth] (`1dp`) dashed line
///   [kRailInset] (`12dp`) in from the left edge.
/// - Caps line ([capsLabel], default `'COVE · EVERY MONTH'`), [title] in
///   [CoveType.slipTitle], and [amount] in [CoveType.slipFigure] with
///   [cadenceSuffix] (`'a month'`) in [CoveType.readout].
/// - Due circle top right, [kDueCircleSize] (`64dp`), `1dp` dashed
///   `accent.fill` ring holding [dueDay] in [CoveType.slipTitle] and
///   [dueMonth] in [CoveType.capsSlip] beneath (never puts `'DUE'` inside the
///   circle, which would fall below the 11sp floor).
/// - Paid state ([CoveVoucherState.paid]): `PAID` stamp ([CoveSlipStamp]) —
///   caps, outlined, rotated −8° ([kPaidStampDegrees]), in `status.good`; the
///   due circle fades to the rule colour.
/// - EMI punched variant ([totalInstallments] != null): a grid of `N` dots for
///   `N` instalments, with [paidInstallments] filled in `accent.fill` and the
///   remaining outlined.
/// - Optional [paidFrom] and [whose] metadata rows, [stamp], [visibility]
///   line, and [fieldTaps] (`design/specs/14-add-flow.md` §8).
/// - Semantics (WCAG 4.1.2): reads out the state (`due` / `paid`) and, for an
///   EMI, `"12 of 48 paid"`.
class CoveVoucher extends StatelessWidget implements CoveSlipObject {
  @override
  final CoveSlipVariant variant;
  final String title;
  final String amount;
  final String dueDay;
  final String dueMonth;

  /// Optional full month name for screen-reader announcement (e.g. `'October'`).
  final String? dueMonthSemantic;
  final String capsLabel;
  final String cadenceSuffix;
  final CoveVoucherState state;
  final int? totalInstallments;
  final int paidInstallments;
  final String? paidFrom;
  final String? whose;
  final String? stamp;
  final bool stampLanded;
  final CoveSlipVisibility? visibility;
  final CoveSlipFieldTaps? fieldTaps;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const double kRailInset =
      12.0; // (literal) 12dp in from the left edge
  static const double kRailWidth = 1.0; // (literal) 1dp dashed line
  static const double kDueCircleSize = 64.0; // (literal) 64dp due circle
  static const double kDueCircleStroke = 1.0; // (literal) 1dp dashed ring
  static const double kDashLength = 4.0; // (literal) dash 4
  static const double kDashGap = 4.0; // (literal) gap 4
  static const double kPaidStampDegrees =
      CoveSlipStamp.kStampDegrees; // (literal) rotated -8°
  static const double kPaidStampBorder =
      CoveSlipStamp.kStampBorder; // (literal) outlined stamp stroke
  static const double kPaidStampRadius =
      CoveSlipStamp.kStampRadius; // (literal) stamp corner radius
  static const double kPunchDotSize = 8.0; // (literal) EMI punch dot diameter
  static const double kPunchOutlineWidth =
      1.0; // (literal) 1dp outline on remaining instalments

  const CoveVoucher({
    super.key,
    required this.variant,
    required this.title,
    required this.amount,
    required this.dueDay,
    required this.dueMonth,
    this.dueMonthSemantic,
    this.capsLabel = 'COVE · EVERY MONTH',
    this.cadenceSuffix = 'a month',
    this.state = CoveVoucherState.due,
    this.totalInstallments,
    this.paidInstallments = 0,
    this.paidFrom,
    this.whose,
    this.stamp,
    this.stampLanded = true,
    this.visibility,
    this.fieldTaps,
    this.onTap,
    this.semanticLabel,
  }) : assert(
          totalInstallments == null ||
              (paidInstallments >= 0 && paidInstallments <= totalInstallments),
          'paidInstallments must be within 0..totalInstallments.',
        );

  bool get isEmi => totalInstallments != null && totalInstallments! > 0;
  bool get isPaid => state == CoveVoucherState.paid;

  String _buildDefaultSemantics() {
    final monthWord = dueMonthSemantic ?? dueMonth;
    final stateWord = isPaid ? 'paid' : 'due';
    final base = 'Voucher, $title, $amount, due $dueDay $monthWord, $stateWord';
    if (isEmi) {
      return '$base, EMI, $paidInstallments of $totalInstallments paid';
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoveSlipPalette.resolve(context, variant);
    final hasPaidFrom = paidFrom != null && paidFrom!.trim().isNotEmpty;
    final hasWhose = whose != null && whose!.trim().isNotEmpty;
    final dueField = (fieldTaps != null &&
            fieldTaps!.containsKey(CoveSlipField.dueDate))
        ? CoveSlipField.dueDate
        : CoveSlipField.date;

    return CoveSlip(
      variant: variant,
      padding: const EdgeInsets.fromLTRB(
        CoveSpace.gutter + CoveSpace.sm,
        CoveSpace.gutter,
        CoveSpace.gutter,
        CoveSpace.gutter,
      ),
      backgroundPainter: _CoveVoucherRailPainter(
        ruleColor: palette.rule,
      ),
      onTap: onTap,
      stamp: stamp,
      stampLanded: stampLanded,
      visibility: visibility,
      fieldTaps: fieldTaps,
      semanticLabel: semanticLabel ?? _buildDefaultSemantics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capsLabel.toUpperCase(),
                      style: CoveType.capsSlip.copyWith(color: palette.tertiary),
                    ),
                    const SizedBox(height: CoveSpace.xs),
                    CoveSlipFieldTapTarget(
                      field: CoveSlipField.title,
                      fieldTaps: fieldTaps,
                      child: Text(
                        title,
                        style: CoveType.slipTitle.copyWith(color: palette.title),
                      ),
                    ),
                    const SizedBox(height: CoveSpace.sm),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: CoveSpace.xs,
                      runSpacing: CoveSpace.xs,
                      children: [
                        CoveSlipFieldTapTarget(
                          field: CoveSlipField.amount,
                          fieldTaps: fieldTaps,
                          child: Text(
                            amount,
                            style: CoveType.slipFigure.copyWith(
                              color: palette.title,
                            ),
                          ),
                        ),
                        if (cadenceSuffix.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: CoveSpace.xs,
                            ),
                            child: CoveSlipFieldTapTarget(
                              field: CoveSlipField.cadence,
                              fieldTaps: fieldTaps,
                              child: Text(
                                cadenceSuffix,
                                style: CoveType.readout.copyWith(
                                  color: palette.tertiary,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CoveSpace.md),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CoveSlipFieldTapTarget(
                    field: dueField,
                    fieldTaps: fieldTaps,
                    alignment: Alignment.center,
                    child: _DueCircle(
                      day: dueDay,
                      month: dueMonth,
                      isPaid: isPaid,
                      palette: palette,
                    ),
                  ),
                  if (isPaid) ...[
                    const SizedBox(height: CoveSpace.sm),
                    CoveSlipStamp(
                      text: 'PAID',
                      color: palette.statusGood,
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (isEmi) ...[
            const SizedBox(height: CoveSpace.md),
            SizedBox(
              height: kRailWidth,
              child: CustomPaint(
                painter: _VoucherHorizontalDashedPainter(color: palette.rule),
              ),
            ),
            const SizedBox(height: CoveSpace.md),
            CoveSlipFieldTapTarget(
              field: CoveSlipField.installments,
              fieldTaps: fieldTaps,
              child: _EmiPunchGrid(
                totalInstallments: totalInstallments!,
                paidInstallments: paidInstallments,
                palette: palette,
              ),
            ),
          ],
          if (hasPaidFrom || hasWhose) ...[
            const SizedBox(height: CoveSpace.md),
            SizedBox(
              height: kRailWidth,
              child: CustomPaint(
                painter: _VoucherHorizontalDashedPainter(color: palette.rule),
              ),
            ),
            const SizedBox(height: CoveSpace.sm),
            if (hasPaidFrom)
              CoveSlipFieldTapTarget(
                field: CoveSlipField.paidFrom,
                fieldTaps: fieldTaps,
                child: _VoucherMetaRow(
                  label: 'Paid from',
                  value: paidFrom!,
                  palette: palette,
                ),
              ),
            if (hasPaidFrom && hasWhose) const SizedBox(height: CoveSpace.xs),
            if (hasWhose)
              CoveSlipFieldTapTarget(
                field: CoveSlipField.owner,
                fieldTaps: fieldTaps,
                child: _VoucherMetaRow(
                  label: 'Whose',
                  value: whose!,
                  palette: palette,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _VoucherMetaRow extends StatelessWidget {
  final String label;
  final String value;
  final CoveSlipPalette palette;

  const _VoucherMetaRow({
    required this.label,
    required this.value,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: CoveType.readout.copyWith(color: palette.secondary),
          ),
        ),
        const SizedBox(width: CoveSpace.sm),
        Text(
          value,
          style: CoveType.readout.copyWith(color: palette.title),
        ),
      ],
    );
  }
}

class _DueCircle extends StatelessWidget {
  final String day;
  final String month;
  final bool isPaid;
  final CoveSlipPalette palette;

  const _DueCircle({
    required this.day,
    required this.month,
    required this.isPaid,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = isPaid ? palette.rule : palette.accentFill;
    final dayColor = isPaid ? palette.tertiary : palette.accent;
    final monthColor = palette.tertiary;

    return SizedBox(
      width: CoveVoucher.kDueCircleSize,
      height: CoveVoucher.kDueCircleSize,
      child: CustomPaint(
        painter: _DashedCirclePainter(color: ringColor),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                day,
                textAlign: TextAlign.center,
                style: CoveType.slipTitle.copyWith(color: dayColor),
              ),
              Text(
                month.toUpperCase(),
                textAlign: TextAlign.center,
                style: CoveType.capsSlip.copyWith(color: monthColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmiPunchGrid extends StatelessWidget {
  final int totalInstallments;
  final int paidInstallments;
  final CoveSlipPalette palette;

  const _EmiPunchGrid({
    required this.totalInstallments,
    required this.paidInstallments,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = totalInstallments - paidInstallments;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$paidInstallments OF $totalInstallments PAID',
                style: CoveType.capsSlip.copyWith(color: palette.tertiary),
              ),
            ),
            Text(
              '$remaining LEFT',
              style: CoveType.capsSlip.copyWith(color: palette.tertiary),
            ),
          ],
        ),
        const SizedBox(height: CoveSpace.sm),
        Wrap(
          spacing: CoveSpace.xs,
          runSpacing: CoveSpace.xs,
          children: List<Widget>.generate(totalInstallments, (index) {
            final punched = index < paidInstallments;
            return SizedBox(
              width: CoveVoucher.kPunchDotSize,
              height: CoveVoucher.kPunchDotSize,
              child: CustomPaint(
                painter: _PunchDotPainter(
                  punched: punched,
                  fillColor: palette.accentFill,
                  outlineColor: palette.mark,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PunchDotPainter extends CustomPainter {
  final bool punched;
  final Color fillColor;
  final Color outlineColor;

  const _PunchDotPainter({
    required this.punched,
    required this.fillColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2.0;

    if (punched) {
      final paint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, paint);
    } else {
      final paint = Paint()
        ..color = outlineColor
        ..strokeWidth = CoveVoucher.kPunchOutlineWidth
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(
        center,
        radius - (CoveVoucher.kPunchOutlineWidth / 2.0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PunchDotPainter oldDelegate) =>
      oldDelegate.punched != punched ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.outlineColor != outlineColor;
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;

  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - CoveVoucher.kDueCircleStroke) / 2.0;
    if (radius <= 0) return;

    final circumference = 2.0 * math.pi * radius;
    final segmentCount = math.max(
      12,
      (circumference / (CoveVoucher.kDashLength + CoveVoucher.kDashGap)).round(),
    );
    final stepAngle = (2.0 * math.pi) / segmentCount;
    final dashSweep = stepAngle *
        (CoveVoucher.kDashLength /
            (CoveVoucher.kDashLength + CoveVoucher.kDashGap));

    final paint = Paint()
      ..color = color
      ..strokeWidth = CoveVoucher.kDueCircleStroke
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < segmentCount; i++) {
      final startAngle = i * stepAngle;
      canvas.drawArc(rect, startAngle, dashSweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _CoveVoucherRailPainter extends CustomPainter {
  final Color ruleColor;

  const _CoveVoucherRailPainter({required this.ruleColor});

  @override
  void paint(Canvas canvas, Size size) {
    final startY = CoveSpace.md;
    final endY = math.max(startY, size.height - CoveSpace.md);

    final paint = Paint()
      ..color = ruleColor
      ..strokeWidth = CoveVoucher.kRailWidth
      ..style = PaintingStyle.stroke;

    var y = startY;
    while (y < endY) {
      final dashEnd = math.min(y + CoveVoucher.kDashLength, endY);
      canvas.drawLine(
        Offset(CoveVoucher.kRailInset, y),
        Offset(CoveVoucher.kRailInset, dashEnd),
        paint,
      );
      y += CoveVoucher.kDashLength + CoveVoucher.kDashGap;
    }
  }

  @override
  bool shouldRepaint(_CoveVoucherRailPainter oldDelegate) =>
      oldDelegate.ruleColor != ruleColor;
}

class _VoucherHorizontalDashedPainter extends CustomPainter {
  final Color color;

  const _VoucherHorizontalDashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = CoveVoucher.kRailWidth
      ..style = PaintingStyle.stroke;

    var x = 0.0;
    final y = size.height / 2.0;
    while (x < size.width) {
      final dashEnd = math.min(x + CoveVoucher.kDashLength, size.width);
      canvas.drawLine(Offset(x, y), Offset(dashEnd, y), paint);
      x += CoveVoucher.kDashLength + CoveVoucher.kDashGap;
    }
  }

  @override
  bool shouldRepaint(_VoucherHorizontalDashedPainter oldDelegate) =>
      oldDelegate.color != color;
}
