import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/shape/cove_shape.dart';
import '../../../core/theme/cove_tokens.dart';

/// 7-column grid of days `1–28` for monthly commitments (`design/specs/14-add-flow.md` §3 **month-day**).
///
/// - Displays optional [hint] above (`"It renews on this day, every month."`).
/// - Renders days `1..28` in 4 rows × 7 columns.
/// - Every cell is at least `48 × 48dp` ([CoveSize.hit]); at cover width
///   (`< 360dp`), the grid scrolls horizontally so no cell drops below `48 × 48dp`.
class AddMonthDayGrid extends StatelessWidget {
  final int? selectedDay;
  final ValueChanged<int> onSelected;
  final String? hint;
  final bool showHint;
  final int minEnabledDay;

  static const int kTotalDays = 28; // (literal) commitments renew on days 1..28
  static const int kColumns = 7; // (literal) 7 columns per row
  static const int kRows = 4; // (literal) 4 rows (28 / 7)
  static const double _kSelectedBorder = 1.5; // (literal) 1.5dp selected border
  static const double _kNormalBorder = 1.0; // (literal) 1dp cell border
  static const double _kDisabledAlpha = 0.35; // (literal) disabled day opacity

  const AddMonthDayGrid({
    super.key,
    required this.selectedDay,
    required this.onSelected,
    this.hint = 'It renews on this day, every month.',
    this.showHint = true,
    this.minEnabledDay = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHint && hint != null && hint!.isNotEmpty) ...[
          Text(
            hint!,
            textAlign: TextAlign.center,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
          const SizedBox(height: CoveSpace.lg),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1.0);
            final cellExtent = textScale > 1.0
                ? (CoveSize.hit * math.min(textScale, 1.5)).ceilToDouble()
                : CoveSize.hit;
            final minGridWidth =
                kColumns * cellExtent + (kColumns - 1) * CoveSpace.xs;
            final needsHorizontalScroll = constraints.maxWidth < minGridWidth;

            final grid = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < kRows; r++) ...[
                  if (r > 0) const SizedBox(height: CoveSpace.xs),
                  Row(
                    mainAxisSize: needsHorizontalScroll
                        ? MainAxisSize.min
                        : MainAxisSize.max,
                    children: [
                      for (var c = 0; c < kColumns; c++) ...[
                        if (c > 0) const SizedBox(width: CoveSpace.xs),
                        if (needsHorizontalScroll)
                          SizedBox(
                            width: cellExtent,
                            height: cellExtent,
                            child: _buildDayCell(
                              context,
                              r * kColumns + c + 1,
                            ),
                          )
                        else
                          Expanded(
                            child: SizedBox(
                              height: cellExtent,
                              child: _buildDayCell(
                                context,
                                r * kColumns + c + 1,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ],
              ],
            );

            if (needsHorizontalScroll) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: grid,
              );
            }
            return grid;
          },
        ),
      ],
    );
  }

  Widget _buildDayCell(BuildContext context, int day) {
    final cv = context.cv;
    final isSelected = selectedDay == day;
    final isEnabled = day >= minEnabledDay;

    final Color fillColor = isSelected ? cv.accentWash : cv.surfaceRow;
    final Color borderColor = isSelected ? cv.accentFill : cv.lineHairline;
    final Color textColor = isSelected
        ? cv.accentText
        : isEnabled
            ? cv.textSecondary
            : cv.textTertiary.withValues(alpha: _kDisabledAlpha);

    return Semantics(
      container: true,
      button: true,
      enabled: isEnabled,
      selected: isSelected,
      label: 'Day $day',
      onTap: isEnabled ? () => onSelected(day) : null,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: isEnabled ? () => onSelected(day) : null,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.hit,
            ),
            alignment: Alignment.center,
            decoration: CoveShape.decoration(
              CoveRadius.inline,
              color: fillColor,
              side: BorderSide(
                color: borderColor,
                width: isSelected ? _kSelectedBorder : _kNormalBorder,
              ),
            ),
            child: Text(
              '$day',
              style: CoveType.body.copyWith(color: textColor),
            ),
          ),
        ),
      ),
    );
  }
}
