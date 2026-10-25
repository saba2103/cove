import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../features/add/add_draft.dart';
import '../../theme/cove_tokens.dart';

export '../../../features/add/add_draft.dart' show AddKind;

/// Small paper-styled mark for each of the six [AddKind] tiles on the Add
/// picker (`design/specs/14-add-flow.md` §1, matching `design/screens/add.png`).
///
/// Drawn in the warm paper palette ([CoveTokens.light] paper stops and
/// `paperAccent` / `paperInk3`), never Material icons:
/// - [AddKind.event]: perforated ticket with left spine and stub
/// - [AddKind.expense]: receipt with zigzag bottom teeth and total bar
/// - [AddKind.task]: ruled note with a checked box
/// - [AddKind.habit]: segmented 7-arc habit ring
/// - [AddKind.commitment]: perforated voucher with dashed due ring
/// - [AddKind.routine]: routine card with 24-hour band track and ticks
class CoveAddMark extends StatelessWidget {
  final AddKind kind;
  final double size;

  static const double kDefaultSize = 44.0; // (literal) 44dp mark canvas

  const CoveAddMark(
    this.kind, {
    super.key,
    this.size = kDefaultSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CoveAddMarkPainter(kind: kind),
      ),
    );
  }
}

class _CoveAddMarkPainter extends CustomPainter {
  final AddKind kind;

  // CSS 168° linear-gradient matching CoveSlipPalette.paper.
  static const Alignment _kGradientBegin = Alignment(-0.2079, -0.9781);
  static const Alignment _kGradientEnd = Alignment(0.2079, 0.9781);
  static const List<double> _kGradientStops = <double>[0.0, 0.46, 1.0];

  const _CoveAddMarkPainter({required this.kind});

  Paint _paperFillPaint(Rect rect) {
    const tokens = CoveTokens.light;
    return Paint()
      ..shader = LinearGradient(
        begin: _kGradientBegin,
        end: _kGradientEnd,
        colors: <Color>[tokens.paperFrom, tokens.paperVia, tokens.paperTo],
        stops: _kGradientStops,
      ).createShader(rect)
      ..style = PaintingStyle.fill;
  }

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case AddKind.event:
        _paintEventTicket(canvas, size);
      case AddKind.expense:
        _paintExpenseReceipt(canvas, size);
      case AddKind.task:
        _paintTaskNote(canvas, size);
      case AddKind.habit:
        _paintHabitRing(canvas, size);
      case AddKind.commitment:
        _paintCommitmentVoucher(canvas, size);
      case AddKind.routine:
        _paintRoutineBand(canvas, size);
    }
  }

  void _paintEventTicket(Canvas canvas, Size size) {
    const tokens = CoveTokens.light;
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: w * 0.88,
      height: h * 0.56,
    );

    final cardPath = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4.0)));
    final perfX = rect.left + rect.width * 0.70;
    const notchR = 3.0;
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(perfX, rect.top), radius: notchR))
      ..addOval(
        Rect.fromCircle(center: Offset(perfX, rect.bottom), radius: notchR),
      );
    final ticketPath = Path.combine(
      PathOperation.difference,
      cardPath,
      notches,
    );

    canvas.drawPath(ticketPath, _paperFillPaint(rect));

    canvas.save();
    canvas.clipPath(ticketPath);

    // Left accent spine
    final accentPaint = Paint()
      ..color = tokens.paperAccent
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rect.top, 3.0, rect.height),
      accentPaint,
    );

    // Vertical dashed perforation
    final dashPaint = Paint()
      ..color = tokens.paperInk3
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    var y = rect.top + notchR + 2.0;
    while (y < rect.bottom - notchR - 1.0) {
      canvas.drawLine(
        Offset(perfX, y),
        Offset(perfX, math.min(y + 2.5, rect.bottom - notchR)),
        dashPaint,
      );
      y += 4.5;
    }

    // Left body bars
    final titleBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + 7.0,
        rect.top + rect.height * 0.34,
        (perfX - rect.left) * 0.56,
        2.6,
      ),
      const Radius.circular(1.3),
    );
    canvas.drawRRect(titleBar, accentPaint);

    final subPaint = Paint()
      ..color = tokens.paperInk3
      ..style = PaintingStyle.fill;
    final subBar = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        rect.left + 7.0,
        rect.top + rect.height * 0.60,
        (perfX - rect.left) * 0.38,
        2.0,
      ),
      const Radius.circular(1.0),
    );
    canvas.drawRRect(subBar, subPaint);

    // Stub bars
    final stubCenterX = perfX + (rect.right - perfX) / 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(stubCenterX, rect.top + rect.height * 0.40),
          width: (rect.right - perfX) * 0.48,
          height: 2.0,
        ),
        const Radius.circular(1.0),
      ),
      subPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(stubCenterX, rect.top + rect.height * 0.62),
          width: (rect.right - perfX) * 0.36,
          height: 2.0,
        ),
        const Radius.circular(1.0),
      ),
      subPaint,
    );

    canvas.restore();
  }

  void _paintExpenseReceipt(Canvas canvas, Size size) {
    const tokens = CoveTokens.light;
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: w * 0.60,
      height: h * 0.80,
    );

    const teeth = 4;
    const toothH = 3.0;
    final step = rect.width / teeth;
    final path = Path()
      ..moveTo(rect.left, rect.top + 2.0)
      ..quadraticBezierTo(rect.left, rect.top, rect.left + 2.0, rect.top)
      ..lineTo(rect.right - 2.0, rect.top)
      ..quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + 2.0)
      ..lineTo(rect.right, rect.bottom - toothH);

    for (var i = teeth - 1; i >= 0; i--) {
      final peakX = rect.left + (i + 0.5) * step;
      final valleyX = rect.left + i * step;
      path.lineTo(peakX, rect.bottom);
      path.lineTo(valleyX, rect.bottom - toothH);
    }
    path.close();

    canvas.drawPath(path, _paperFillPaint(rect));

    final linePaint = Paint()
      ..color = tokens.paperInk3
      ..style = PaintingStyle.fill;
    final padX = rect.left + 5.0;
    final innerW = rect.width - 10.0;

    for (var i = 0; i < 2; i++) {
      final lineY = rect.top + 7.0 + i * 5.5;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(padX, lineY, innerW * (i == 0 ? 0.72 : 0.90), 1.8),
          const Radius.circular(0.9),
        ),
        linePaint,
      );
    }

    // Bottom total row: small label left, bold bronze figure right
    final totalY = rect.bottom - toothH - 7.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(padX, totalY + 0.5, innerW * 0.36, 1.8),
        const Radius.circular(0.9),
      ),
      linePaint,
    );

    final accentPaint = Paint()
      ..color = tokens.paperAccent
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.right - 5.0 - innerW * 0.42,
          totalY,
          innerW * 0.42,
          2.8,
        ),
        const Radius.circular(1.4),
      ),
      accentPaint,
    );
  }

  void _paintTaskNote(Canvas canvas, Size size) {
    const tokens = CoveTokens.light;
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: w * 0.72,
      height: h * 0.76,
    );

    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(2.5),
      topRight: const Radius.circular(2.5),
      bottomLeft: const Radius.circular(5.0),
      bottomRight: const Radius.circular(5.0),
    );
    canvas.drawRRect(rrect, _paperFillPaint(rect));

    // Checkbox top-left
    final boxRect = Rect.fromLTWH(rect.left + 5.5, rect.top + 6.0, 9.0, 9.0);
    final accentStroke = Paint()
      ..color = tokens.paperAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(boxRect, const Radius.circular(2.0)),
      accentStroke,
    );

    // Checkmark inside box
    final checkPath = Path()
      ..moveTo(boxRect.left + 2.2, boxRect.center.dy)
      ..lineTo(boxRect.left + 4.0, boxRect.bottom - 2.3)
      ..lineTo(boxRect.right - 2.0, boxRect.top + 2.5);
    canvas.drawPath(checkPath, accentStroke);

    final linePaint = Paint()
      ..color = tokens.paperInk3
      ..style = PaintingStyle.fill;

    // Line next to checkbox
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          boxRect.right + 3.5,
          boxRect.center.dy - 1.0,
          rect.right - boxRect.right - 9.0,
          2.0,
        ),
        const Radius.circular(1.0),
      ),
      linePaint,
    );

    // Two ruled lines below
    final fullW = rect.width - 11.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 5.5, boxRect.bottom + 5.0, fullW, 1.8),
        const Radius.circular(0.9),
      ),
      linePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left + 5.5,
          boxRect.bottom + 10.5,
          fullW * 0.65,
          1.8,
        ),
        const Radius.circular(0.9),
      ),
      linePaint,
    );
  }

  void _paintHabitRing(Canvas canvas, Size size) {
    const tokens = CoveTokens.light;
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: w * 0.74,
      height: h * 0.74,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5.0));
    canvas.drawRRect(rrect, _paperFillPaint(rect));

    // 7-segment bronze ring
    final ringCenter = Offset(rect.center.dx, rect.top + rect.height * 0.44);
    final ringRadius = rect.width * 0.27;
    final arcPaint = Paint()
      ..color = tokens.paperAccent
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const segments = 7;
    const step = (2 * math.pi) / segments;
    const gap = 0.24;
    final ringRect = Rect.fromCircle(center: ringCenter, radius: ringRadius);
    for (var i = 0; i < segments; i++) {
      final start = -math.pi / 2 + i * step + gap / 2;
      canvas.drawArc(ringRect, start, step - gap, false, arcPaint);
    }

    // Small horizontal bar below ring
    final barPaint = Paint()
      ..color = tokens.paperInk3
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(rect.center.dx, rect.bottom - 5.5),
          width: rect.width * 0.48,
          height: 1.8,
        ),
        const Radius.circular(0.9),
      ),
      barPaint,
    );
  }

  void _paintCommitmentVoucher(Canvas canvas, Size size) {
    const tokens = CoveTokens.light;
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: w * 0.80,
      height: h * 0.68,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5.0));
    canvas.drawRRect(rrect, _paperFillPaint(rect));

    // Left vertical dashed rail
    final railX = rect.left + 5.0;
    final railPaint = Paint()
      ..color = tokens.paperInk3
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;
    var y = rect.top + 4.0;
    while (y < rect.bottom - 4.0) {
      canvas.drawLine(
        Offset(railX, y),
        Offset(railX, math.min(y + 2.5, rect.bottom - 4.0)),
        railPaint,
      );
      y += 4.5;
    }

    // Top-right dashed due ring
    final ringCenter = Offset(rect.right - 9.5, rect.top + 9.5);
    const ringR = 5.2;
    final duePaint = Paint()
      ..color = tokens.paperAccent
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    const dueSegments = 8;
    const step = (2 * math.pi) / dueSegments;
    final dueRect = Rect.fromCircle(center: ringCenter, radius: ringR);
    for (var i = 0; i < dueSegments; i++) {
      canvas.drawArc(dueRect, i * step, step * 0.55, false, duePaint);
    }

    // Bottom-left amount & cadence bars
    final accentPaint = Paint()
      ..color = tokens.paperAccent
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          railX + 4.0,
          rect.bottom - 11.5,
          rect.width * 0.40,
          2.6,
        ),
        const Radius.circular(1.3),
      ),
      accentPaint,
    );

    final subPaint = Paint()
      ..color = tokens.paperInk3
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          railX + 4.0,
          rect.bottom - 6.5,
          rect.width * 0.28,
          1.8,
        ),
        const Radius.circular(0.9),
      ),
      subPaint,
    );
  }

  void _paintRoutineBand(Canvas canvas, Size size) {
    const tokens = CoveTokens.light;
    final w = size.width;
    final h = size.height;
    final rect = Rect.fromCenter(
      center: Offset(w / 2, h / 2),
      width: w * 0.80,
      height: h * 0.60,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5.0));
    canvas.drawRRect(rrect, _paperFillPaint(rect));

    // Inset 24-hour band track
    final trackRect = Rect.fromLTWH(
      rect.left + 5.0,
      rect.top + 5.5,
      rect.width - 10.0,
      rect.height * 0.44,
    );
    final trackRRect = RRect.fromRectAndRadius(
      trackRect,
      const Radius.circular(3.0),
    );
    final trackPaint = Paint()
      ..color = tokens.paperRule
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRRect, trackPaint);

    // Bronze routine block inside track
    final blockRect = Rect.fromCenter(
      center: trackRect.center,
      width: trackRect.width * 0.34,
      height: trackRect.height,
    );
    final accentPaint = Paint()
      ..color = tokens.paperAccent
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(blockRect, const Radius.circular(2.5)),
      accentPaint,
    );

    // Four small tick dashes beneath the track
    final tickPaint = Paint()
      ..color = tokens.paperInk3
      ..style = PaintingStyle.fill;
    final tickY = rect.bottom - 5.0;
    const tickCount = 4;
    final tickW = (trackRect.width - 9.0) / tickCount;
    for (var i = 0; i < tickCount; i++) {
      final tickLeft = trackRect.left + i * (tickW + 3.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(tickLeft, tickY, tickW, 1.6),
          const Radius.circular(0.8),
        ),
        tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CoveAddMarkPainter oldDelegate) =>
      oldDelegate.kind != kind;
}
