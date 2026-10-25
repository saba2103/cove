import 'package:flutter/material.dart';

import '../../../core/theme/cove_tokens.dart';
import '../add_draft.dart';
import 'add_month_day_grid.dart';

/// Next-date picker for quarterly and yearly commitments (`design/specs/14-add-flow.md` §3 **next-date**).
///
/// - Hint above: `"When is the next one due?"`
/// - A horizontally scrollable row of 12 month chips (this month and the next
///   eleven), each at least `48 × 48dp` ([CoveSize.hit]).
/// - Below the month chips: the `1–28` grid ([AddMonthDayGrid]).
/// - Produces a date on or after [today] via [nextBillingDate].
class AddNextDatePicker extends StatelessWidget {
  final DateTime today;
  final int selectedMonth;
  final int selectedDay;
  final void Function(int month, int day, DateTime resolvedDate) onChanged;
  final String hint;
  final bool showHint;

  static const List<String> _monthShort = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const double _kSelectedBorder = 1.5; // (literal) 1.5dp selected border
  static const double _kNormalBorder = 1.0; // (literal) 1dp chip border

  const AddNextDatePicker({
    super.key,
    required this.today,
    required this.selectedMonth,
    required this.selectedDay,
    required this.onChanged,
    this.hint = 'When is the next one due?',
    this.showHint = true,
  })  : assert(selectedMonth >= 1 && selectedMonth <= 12),
        assert(selectedDay >= 1 && selectedDay <= 28);

  void _selectMonth(int month) {
    final resolved = nextBillingDate(
      today: today,
      dayOfMonth: selectedDay,
      month: month,
    );
    onChanged(month, selectedDay, resolved);
  }

  void _selectDay(int day) {
    final resolved = nextBillingDate(
      today: today,
      dayOfMonth: day,
      month: selectedMonth,
    );
    onChanged(selectedMonth, day, resolved);
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    // 12 months starting at today.month ("this month and the next eleven")
    final months = List<int>.generate(
      12,
      (i) => ((today.month - 1 + i) % 12) + 1,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHint && hint.isNotEmpty) ...[
          Text(
            hint,
            textAlign: TextAlign.center,
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
          const SizedBox(height: CoveSpace.md),
        ],

        // Row of 12 month chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < months.length; i++) ...[
                if (i > 0) const SizedBox(width: CoveSpace.sm),
                _MonthChip(
                  month: months[i],
                  label: _monthShort[months[i] - 1],
                  selected: months[i] == selectedMonth,
                  onTap: () => _selectMonth(months[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: CoveSpace.md),

        // 1–28 grid
        AddMonthDayGrid(
          selectedDay: selectedDay,
          showHint: false,
          onSelected: _selectDay,
        ),
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  final int month;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MonthChip({
    required this.month,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: 'Month $label',
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.hit,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.md,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? cv.accentWash : cv.surfaceRow,
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.inline),
              ),
              border: Border.all(
                color: selected ? cv.accentFill : cv.lineStrong,
                width: selected
                    ? AddNextDatePicker._kSelectedBorder
                    : AddNextDatePicker._kNormalBorder,
              ),
            ),
            child: Text(
              label,
              style: CoveType.rowTitle.copyWith(
                color: selected ? cv.accentText : cv.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
