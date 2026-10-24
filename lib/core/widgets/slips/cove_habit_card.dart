import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/cove_tokens.dart';
import '../cove_checkbox.dart';
import 'cove_slip.dart';

/// A compact habit slip with a 21-day streak grid (`design/specs/10-paper-objects.md`).
///
/// Built on [CoveSlip] to the contract in `design/specs/10-paper-objects.md`:
/// - Caps line ([capsLabel], default `'COVE · HABIT'`), [title] in
///   [CoveType.slipTitle], [cadence] line (e.g. `'every day · both of you'`),
///   and check state top right using [CoveCheckbox].
/// - Streak grid: the last 21 days as 7 columns × 3 rows. Cells
///   [kCellSize] (`10dp`), gap [CoveSpace.xs] (`4dp`), radius
///   [kCellRadius] (`2dp`):
///   - done → `accent.fill`
///   - missed → `1dp` outline in `slip.inkMark` on ink (`3.63:1`) /
///     `paper.ink3` on paper
///   - today (the 21st cell, index 20) → a [kTodayRingWidth] (`1.5dp`)
///     `accent.fill` ring around the cell.
/// - Right of the grid: [daysRunning] in [CoveType.slipFigure] with
///   `DAYS RUNNING` ([runLabel]) in caps beneath. The run count is always in
///   text; the grid is supplementary.
/// - Exposes its state as semantics:
///   `"Habit, Morning walk, done today, 23 days running"`.
class CoveHabitCard extends StatelessWidget implements CoveSlipObject {
  @override
  final CoveSlipVariant variant;
  final String title;
  final String cadence;
  final bool isDoneToday;
  final int daysRunning;

  /// Optional 21-day history (oldest first, index 20 is today).
  /// When omitted, derives a 21-cell history matching [daysRunning] and
  /// [isDoneToday].
  final List<bool>? history21;
  final String capsLabel;
  final String runLabel;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;
  final String? semanticLabel;

  static const int kGridColumns = 7; // (literal) 7 columns
  static const int kGridRows = 3; // (literal) 3 rows
  static const int kTotalCells = 21; // (literal) last 21 days (7 x 3)
  static const double kCellSize = 10.0; // (literal) cells 10dp
  static const double kCellRadius = 2.0; // (literal) radius 2dp
  static const double kMissedOutlineWidth =
      1.0; // (literal) 1dp outline on missed cells
  static const double kTodayRingWidth =
      1.5; // (literal) 1.5dp accent.fill ring around today's cell
  static const double kTodayRingOutset =
      2.0; // (literal) ring clearance around the 10dp today cell
  static const double kRuleHeight = 1.0; // (literal) 1dp dashed rule
  static const double kDashLength = 4.0; // (literal) dash 4
  static const double kDashGap = 4.0; // (literal) gap 4

  const CoveHabitCard({
    super.key,
    required this.variant,
    required this.title,
    required this.cadence,
    required this.isDoneToday,
    required this.daysRunning,
    this.history21,
    this.capsLabel = 'COVE · HABIT',
    this.runLabel = 'DAYS RUNNING',
    this.onToggle,
    this.onTap,
    this.semanticLabel,
  }) : assert(daysRunning >= 0, 'daysRunning must be non-negative.');

  /// Resolves the 21 boolean cell states (index 0 = 20 days ago, index 20 = today).
  List<bool> resolveCells() {
    if (history21 != null && history21!.length == kTotalCells) {
      return history21!;
    }
    final cells = List<bool>.filled(kTotalCells, false);
    if (daysRunning <= 0) {
      cells[kTotalCells - 1] = isDoneToday;
      return cells;
    }

    cells[kTotalCells - 1] = isDoneToday;
    final priorFilled = isDoneToday
        ? math.min(kTotalCells - 1, daysRunning - 1)
        : math.min(kTotalCells - 1, daysRunning);
    for (var i = 0; i < priorFilled; i++) {
      cells[kTotalCells - 2 - i] = true;
    }
    return cells;
  }

  String _buildDefaultSemantics() {
    final todayState = isDoneToday ? 'done today' : 'not done today';
    final dayWord = daysRunning == 1 ? '1 day running' : '$daysRunning days running';
    return 'Habit, $title, $todayState, $dayWord';
  }

  @override
  Widget build(BuildContext context) {
    final palette = CoveSlipPalette.resolve(context, variant);
    final cells = resolveCells();
    const gridWidth =
        (kGridColumns * kCellSize) + ((kGridColumns - 1) * CoveSpace.xs);
    const gridHeight =
        (kGridRows * kCellSize) + ((kGridRows - 1) * CoveSpace.xs);

    return CoveSlip(
      variant: variant,
      onTap: onTap,
      semanticLabel: semanticLabel ?? _buildDefaultSemantics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header: caps line, title, cadence on left + CoveCheckbox top right
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
                    Text(
                      title,
                      style: CoveType.slipTitle.copyWith(color: palette.title),
                    ),
                    const SizedBox(height: CoveSpace.xs),
                    Text(
                      cadence,
                      style: CoveType.readout.copyWith(color: palette.tertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: CoveSpace.md),
              Padding(
                padding: const EdgeInsets.only(top: CoveSpace.md),
                child: CoveCheckbox(
                  value: isDoneToday,
                  onChanged: onToggle,
                ),
              ),
            ],
          ),
          const SizedBox(height: CoveSpace.md),

          // 2. Dashed horizontal rule
          SizedBox(
            height: kRuleHeight,
            child: CustomPaint(
              painter: _HabitDashedRulePainter(color: palette.rule),
            ),
          ),
          const SizedBox(height: CoveSpace.md),

          // 3. 21-day streak grid (left) + run count in slipFigure (right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: gridWidth,
                height: gridHeight,
                child: CustomPaint(
                  painter: _HabitStreakGridPainter(
                    cells: cells,
                    doneColor: palette.accentFill,
                    missedOutlineColor: palette.mark,
                    todayRingColor: palette.accentFill,
                  ),
                ),
              ),
              const SizedBox(width: CoveSpace.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$daysRunning',
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.end,
                      style: CoveType.slipFigure.copyWith(color: palette.title),
                    ),
                    const SizedBox(height: CoveSpace.xs),
                    Text(
                      runLabel.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: CoveType.capsSlip.copyWith(
                        color: palette.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HabitStreakGridPainter extends CustomPainter {
  final List<bool> cells;
  final Color doneColor;
  final Color missedOutlineColor;
  final Color todayRingColor;

  const _HabitStreakGridPainter({
    required this.cells,
    required this.doneColor,
    required this.missedOutlineColor,
    required this.todayRingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final donePaint = Paint()
      ..color = doneColor
      ..style = PaintingStyle.fill;

    final missedPaint = Paint()
      ..color = missedOutlineColor
      ..strokeWidth = CoveHabitCard.kMissedOutlineWidth
      ..style = PaintingStyle.stroke;

    final todayRingPaint = Paint()
      ..color = todayRingColor
      ..strokeWidth = CoveHabitCard.kTodayRingWidth
      ..style = PaintingStyle.stroke;

    const cellSize = CoveHabitCard.kCellSize;
    const gap = CoveSpace.xs;
    const radius = Radius.circular(CoveHabitCard.kCellRadius);

    for (var i = 0; i < CoveHabitCard.kTotalCells; i++) {
      final row = i ~/ CoveHabitCard.kGridColumns;
      final col = i % CoveHabitCard.kGridColumns;
      final left = col * (cellSize + gap);
      final top = row * (cellSize + gap);
      final isDone = i < cells.length && cells[i];
      final isToday = i == CoveHabitCard.kTotalCells - 1;

      final rect = Rect.fromLTWH(left, top, cellSize, cellSize);
      if (isDone) {
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), donePaint);
      } else {
        final insetRect = rect.deflate(CoveHabitCard.kMissedOutlineWidth / 2.0);
        canvas.drawRRect(
          RRect.fromRectAndRadius(insetRect, radius),
          missedPaint,
        );
      }

      if (isToday) {
        final ringRect = rect.inflate(CoveHabitCard.kTodayRingOutset);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            ringRect,
            const Radius.circular(
              CoveHabitCard.kCellRadius + CoveHabitCard.kTodayRingOutset,
            ),
          ),
          todayRingPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_HabitStreakGridPainter oldDelegate) =>
      oldDelegate.doneColor != doneColor ||
      oldDelegate.missedOutlineColor != missedOutlineColor ||
      oldDelegate.todayRingColor != todayRingColor ||
      oldDelegate.cells != cells;
}

class _HabitDashedRulePainter extends CustomPainter {
  final Color color;

  const _HabitDashedRulePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = CoveHabitCard.kRuleHeight
      ..style = PaintingStyle.stroke;

    var x = 0.0;
    final y = size.height / 2.0;
    while (x < size.width) {
      final dashEnd = math.min(x + CoveHabitCard.kDashLength, size.width);
      canvas.drawLine(Offset(x, y), Offset(dashEnd, y), paint);
      x += CoveHabitCard.kDashLength + CoveHabitCard.kDashGap;
    }
  }

  @override
  bool shouldRepaint(_HabitDashedRulePainter oldDelegate) =>
      oldDelegate.color != color;
}
