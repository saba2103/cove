import 'package:flutter/material.dart';

import '../../../core/theme/cove_tokens.dart';
import '../../../core/widgets/cove_round_button.dart';
import '../../../core/widgets/cove_sheet.dart';
import '../add_draft.dart';

/// Seven-day anchored date strip (`design/specs/14-add-flow.md` §3 **day** & §4).
///
/// - Displays 7 day cells (3-letter weekday caps + day-of-month number).
/// - The [anchorDate] cell carries a gold ring (`accentFill`); the
///   [selectedDate] cell is filled (`accentWash` + `1.5dp` `accentFill` border).
/// - When [anchorDate] is not [today], renders the carried line above the strip:
///   `"Starting from Thu 8 Oct — the day you tapped +. Change it here."`
/// - Under the strip: the full label (`dayLabel(selectedDate, today)`, e.g.
///   `"Today, 5 Oct"`), an optional `"No particular day"` chip for tasks, and
///   the quiet text button `"Another date"` which opens a month picker on a
///   [CoveSheet] (or invokes [onTapAnotherDate] if provided).
/// - At cover width (`< CoveSize.compactThreshold`), keeps `48dp` targets and
///   scrolls horizontally with the selected or anchor cell scrolled into view.
class AddDayStrip extends StatefulWidget {
  final List<DateTime> days;
  final DateTime anchorDate;
  final DateTime today;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback? onSelectNoParticularDay;
  final bool showNoParticularDay;
  final VoidCallback? onTapAnotherDate;

  static const double kCellMinWidth = CoveSize.hit; // 48dp minimum target width
  static const double kCellHeight = 68.0; // (literal) 68dp tall day cell
  static const double _kSelectedBorder = 1.5; // (literal) 1.5dp selected ring
  static const double _kNormalBorder = 1.0; // (literal) 1dp cell ring

  const AddDayStrip({
    super.key,
    required this.days,
    required this.anchorDate,
    required this.today,
    required this.selectedDate,
    required this.onSelected,
    this.onSelectNoParticularDay,
    this.showNoParticularDay = false,
    this.onTapAnotherDate,
  }) : assert(days.length == 7, 'AddDayStrip requires 7 anchored days.');

  static const List<String> _weekdayCaps = <String>[
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  static const List<String> _weekdayShort = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

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

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String formatShortAnchor(DateTime d) =>
      '${_weekdayShort[d.weekday - 1]} ${d.day} ${_monthShort[d.month - 1]}';

  @override
  State<AddDayStrip> createState() => _AddDayStripState();
}

class _AddDayStripState extends State<AddDayStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTargetIntoView());
  }

  @override
  void didUpdateWidget(covariant AddDayStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate != widget.selectedDate ||
        oldWidget.anchorDate != widget.anchorDate) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollTargetIntoView());
    }
  }

  void _scrollTargetIntoView() {
    if (!mounted || !_scrollController.hasClients) return;
    final targetDate = widget.selectedDate ?? widget.anchorDate;
    final index = widget.days.indexWhere(
      (d) => AddDayStrip.isSameDay(d, targetDate),
    );
    if (index < 0) return;

    const itemExtent = AddDayStrip.kCellMinWidth + CoveSpace.sm;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final desired = (index * itemExtent).clamp(0.0, maxScroll);
    _scrollController.jumpTo(desired);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleAnotherDate(BuildContext context) async {
    if (widget.onTapAnotherDate != null) {
      widget.onTapAnotherDate!();
      return;
    }
    final picked = await AddAnotherDateSheet.show(
      context: context,
      initialDate: widget.selectedDate ?? widget.anchorDate,
      today: widget.today,
    );
    if (picked != null && mounted) {
      widget.onSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final anchorIsToday =
        AddDayStrip.isSameDay(widget.anchorDate, widget.today);
    final fullLabel = widget.selectedDate != null
        ? dayLabel(widget.selectedDate!, widget.today)
        : 'No particular day';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Optional carried line when anchor != today (§4)
        if (!anchorIsToday) ...[
          Text(
            'Starting from ${AddDayStrip.formatShortAnchor(widget.anchorDate)} — the day you tapped +. Change it here.',
            textAlign: TextAlign.center,
            style: CoveType.rowSub.copyWith(color: cv.textSecondary),
          ),
          const SizedBox(height: CoveSpace.md),
        ],

        // 7-cell strip (scrolls horizontally when width cannot fit 7 × 48dp)
        LayoutBuilder(
          builder: (context, constraints) {
            const minRequiredWidth =
                7 * AddDayStrip.kCellMinWidth + 6 * CoveSpace.xs;
            final isCompact =
                MediaQuery.sizeOf(context).width < CoveSize.compactThreshold ||
                    constraints.maxWidth < minRequiredWidth;

            if (isCompact) {
              return SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.days.length; i++) ...[
                      if (i > 0) const SizedBox(width: CoveSpace.sm),
                      SizedBox(
                        width: AddDayStrip.kCellMinWidth,
                        child: _buildDayCell(context, widget.days[i]),
                      ),
                    ],
                  ],
                ),
              );
            }

            return Row(
              children: [
                for (var i = 0; i < widget.days.length; i++) ...[
                  if (i > 0) const SizedBox(width: CoveSpace.xs),
                  Expanded(
                    child: _buildDayCell(context, widget.days[i]),
                  ),
                ],
              ],
            );
          },
        ),

        const SizedBox(height: CoveSpace.md),

        // Full date label below the strip
        Text(
          fullLabel,
          textAlign: TextAlign.center,
          style: CoveType.rowSub.copyWith(color: cv.textTertiary),
        ),

        if (widget.showNoParticularDay) ...[
          const SizedBox(height: CoveSpace.sm),
          Center(
            child: _QuietActionPill(
              label: 'No particular day',
              selected: widget.selectedDate == null,
              onTap: widget.onSelectNoParticularDay,
            ),
          ),
        ],

        const SizedBox(height: CoveSpace.xs),

        // Quiet text button: Another date
        Center(
          child: Semantics(
            container: true,
            button: true,
            label: 'Another date',
            onTap: () => _handleAnotherDate(context),
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _handleAnotherDate(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: CoveSize.hit,
                    minHeight: CoveSize.hit,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoveSpace.md,
                    ),
                    child: Center(
                      widthFactor: 1.0,
                      child: Text(
                        'Another date',
                        style: CoveType.rowSub.copyWith(
                          color: cv.accentText,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime date) {
    final cv = context.cv;
    final isSelected = widget.selectedDate != null &&
        AddDayStrip.isSameDay(date, widget.selectedDate!);
    final isAnchor = AddDayStrip.isSameDay(date, widget.anchorDate);
    final weekday = AddDayStrip._weekdayCaps[date.weekday - 1];
    final semantic = dayLabel(date, widget.today);

    final Color fillColor = isSelected ? cv.accentWash : cv.surfaceRow;
    final Color borderColor = isSelected
        ? cv.accentFill
        : isAnchor
            ? cv.accentFill
            : cv.lineHairline;
    final double borderWidth =
        isSelected ? AddDayStrip._kSelectedBorder : AddDayStrip._kNormalBorder;
    final Color weekdayColor = isSelected ? cv.accentText : cv.textTertiary;
    final Color dayNumberColor = isSelected ? cv.textPrimary : cv.textSecondary;

    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: semantic,
      onTap: () => widget.onSelected(date),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSelected(date),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: AddDayStrip.kCellMinWidth,
              minHeight: AddDayStrip.kCellHeight,
            ),
            height: AddDayStrip.kCellHeight,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.inline),
              ),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekday,
                  style: CoveType.capsSlip.copyWith(color: weekdayColor),
                ),
                const SizedBox(height: CoveSpace.xs),
                Text(
                  '${date.day}',
                  style: CoveType.cardFigure.copyWith(color: dayNumberColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuietActionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  static const double _kBorderWidth = 1.0; // (literal) 1dp border

  const _QuietActionPill({
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
      label: label,
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
                Radius.circular(CoveRadius.pill),
              ),
              border: Border.all(
                color: selected ? cv.accentFill : cv.lineStrong,
                width: _kBorderWidth,
              ),
            ),
            child: Text(
              label,
              style: CoveType.rowSub.copyWith(
                color: selected ? cv.accentText : cv.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Month calendar picker sheet opened by `"Another date"` on [AddDayStrip]
/// (`design/specs/14-add-flow.md` §3 **day**).
class AddAnotherDateSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime today;
  final ValueChanged<DateTime>? onSelected;

  static const List<String> _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdayHeaders = <String>[
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  static const double _kSelectedBorder = 1.5; // (literal) 1.5dp selected ring
  static const double _kNormalBorder = 1.0; // (literal) 1dp cell border

  const AddAnotherDateSheet({
    super.key,
    required this.initialDate,
    required this.today,
    this.onSelected,
  });

  static Future<DateTime?> show({
    required BuildContext context,
    required DateTime initialDate,
    required DateTime today,
  }) {
    return CoveSheet.show<DateTime>(
      context: context,
      builder: (sheetContext) => AddAnotherDateSheet(
        initialDate: initialDate,
        today: today,
        onSelected: (picked) => Navigator.of(sheetContext).pop(picked),
      ),
    );
  }

  @override
  State<AddAnotherDateSheet> createState() => _AddAnotherDateSheetState();
}

class _AddAnotherDateSheetState extends State<AddAnotherDateSheet> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year;
    _month = widget.initialDate.month;
  }

  void _previousMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year -= 1;
      } else {
        _month -= 1;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year += 1;
      } else {
        _month += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final firstOfMonth = DateTime(_year, _month, 1);
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final leadingBlanks = firstOfMonth.weekday - 1; // Monday = 0
    final totalCells = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;
    final rows = totalCells ~/ 7;

    return CoveSheet(
      title: 'ANOTHER DATE',
      onClose: () => Navigator.of(context).maybePop(),
      onDismiss: () => Navigator.of(context).maybePop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CoveRoundButton(
                icon: Icons.chevron_left,
                semanticLabel: 'Previous month',
                onPressed: _previousMonth,
              ),
              Flexible(
                child: Text(
                  '${AddAnotherDateSheet._monthNames[_month - 1]} $_year',
                  textAlign: TextAlign.center,
                  style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
                ),
              ),
              CoveRoundButton(
                icon: Icons.chevron_right,
                semanticLabel: 'Next month',
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: CoveSpace.md),
          LayoutBuilder(
            builder: (context, constraints) {
              const minGridWidth = 7 * CoveSize.hit + 6 * CoveSpace.xs;
              final needsScroll = constraints.maxWidth < minGridWidth;

              final gridColumn = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize:
                        needsScroll ? MainAxisSize.min : MainAxisSize.max,
                    children: [
                      for (var c = 0; c < 7; c++) ...[
                        if (c > 0) const SizedBox(width: CoveSpace.xs),
                        if (needsScroll)
                          SizedBox(
                            width: CoveSize.hit,
                            child: Center(
                              child: Text(
                                AddAnotherDateSheet._weekdayHeaders[c],
                                style: CoveType.capsCard
                                    .copyWith(color: cv.textTertiary),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Center(
                              child: Text(
                                AddAnotherDateSheet._weekdayHeaders[c],
                                style: CoveType.capsCard
                                    .copyWith(color: cv.textTertiary),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                  const SizedBox(height: CoveSpace.xs),
                  for (var r = 0; r < rows; r++) ...[
                    if (r > 0) const SizedBox(height: CoveSpace.xs),
                    Row(
                      mainAxisSize:
                          needsScroll ? MainAxisSize.min : MainAxisSize.max,
                      children: [
                        for (var c = 0; c < 7; c++) ...[
                          if (c > 0) const SizedBox(width: CoveSpace.xs),
                          if (needsScroll)
                            SizedBox(
                              width: CoveSize.hit,
                              height: CoveSize.hit,
                              child: _buildDayCell(
                                context,
                                r * 7 + c - leadingBlanks + 1,
                                daysInMonth,
                              ),
                            )
                          else
                            Expanded(
                              child: SizedBox(
                                height: CoveSize.hit,
                                child: _buildDayCell(
                                  context,
                                  r * 7 + c - leadingBlanks + 1,
                                  daysInMonth,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ],
              );

              if (needsScroll) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: gridColumn,
                );
              }
              return gridColumn;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, int dayNum, int daysInMonth) {
    if (dayNum < 1 || dayNum > daysInMonth) {
      return const SizedBox.shrink();
    }
    final cv = context.cv;
    final cellDate = DateTime(_year, _month, dayNum);
    final isSelected = AddDayStrip.isSameDay(cellDate, widget.initialDate);
    final isToday = AddDayStrip.isSameDay(cellDate, widget.today);

    return Semantics(
      container: true,
      button: true,
      selected: isSelected,
      label: dayLabel(cellDate, widget.today),
      onTap: () => widget.onSelected?.call(cellDate),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSelected?.call(cellDate),
          child: Container(
            constraints: const BoxConstraints(
              minWidth: CoveSize.hit,
              minHeight: CoveSize.hit,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? cv.accentWash : cv.surfaceRow,
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.inline),
              ),
              border: Border.all(
                color: isSelected || isToday ? cv.accentFill : cv.lineHairline,
                width: isSelected
                    ? AddAnotherDateSheet._kSelectedBorder
                    : AddAnotherDateSheet._kNormalBorder,
              ),
            ),
            child: Text(
              '$dayNum',
              style: CoveType.rowTitle.copyWith(
                color: isSelected ? cv.accentText : cv.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
