import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/cove_tokens.dart';
import '../../../core/utils/cove_currency_formatter.dart';
import '../../../core/widgets/cove_card.dart';
import '../../../core/widgets/cove_pill_button.dart';
import '../../../sync/db/app_database.dart';
import '../../profile/preferences_controller.dart';
import '../calendar_controller.dart';
import '../calendar_models.dart';

class CalendarMonthView extends ConsumerStatefulWidget {
  final List<LocalCalendarEvent> events;
  final List<LocalSubscription> subscriptions;
  final List<LocalOutboxEvent> outboxEvents;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onAddEvent;
  final bool hasPartner;

  const CalendarMonthView({
    super.key,
    required this.events,
    required this.subscriptions,
    required this.outboxEvents,
    required this.selectedDate,
    required this.onSelectDate,
    required this.onAddEvent,
    this.hasPartner = true,
  });

  @override
  ConsumerState<CalendarMonthView> createState() => _CalendarMonthViewState();
}

class _CalendarMonthViewState extends ConsumerState<CalendarMonthView> {
  static const double _kDividerHeight =
      1.0; // (literal) 1dp header divider height and border stroke
  static const double _kListHorizontalPadding =
      16.0; // (literal) 16dp calendar scroll view and summary card horizontal inset
  static const double _kGridSpacing =
      6.0; // (literal) 6dp calendar 7-column day cell spacing
  static const double _kDayCellSize =
      44.0; // (literal) 44dp calendar day square cell size
  static const double _kTodayBorderWidth =
      1.5; // (literal) 1.5dp today cell border ring stroke
  static const double _kSummaryIconBoxSize =
      36.0; // (literal) 36dp selected day summary icon square
  static const double _kSummaryIconBoxRadius =
      10.0; // (literal) 10dp selected day summary icon corner radius
  static const double _kSummaryIconSize =
      18.0; // (literal) 18dp selected day summary calendar icon
  static const double _kBottomSpacer =
      40.0; // (literal) 40dp bottom scroll clearance below summary card
  static const double _kDotMargin =
      1.0; // (literal) 1dp horizontal margin around density dot
  static const double _kDotSize =
      3.5; // (literal) 3.5dp calendar density dot diameter

  late int _currentYear;
  late int _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentYear = widget.selectedDate.year;
    _currentMonth = widget.selectedDate.month;
  }

  @override
  void didUpdateWidget(covariant CalendarMonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      _currentYear = widget.selectedDate.year;
      _currentMonth = widget.selectedDate.month;
    }
  }

  void _prevMonth() {
    setState(() {
      if (_currentMonth == 1) {
        _currentMonth = 12;
        _currentYear--;
      } else {
        _currentMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_currentMonth == 12) {
        _currentMonth = 1;
        _currentYear++;
      } else {
        _currentMonth++;
      }
    });
  }

  int _getDistinctLayerCount(
    Map<DateTime, List<CalendarEntry>> entriesMap,
    DateTime date,
  ) {
    final dayEntries = entriesMap[CalendarDateUtils.dateOnly(date)] ?? [];
    final layers = <CalendarLayer>{};
    for (final e in dayEntries) {
      if (e is CalendarHabitEntry) {
        // Daily recurring habits do not contribute a dot on every day
        final h = e.habit;
        if (h.cadence.toLowerCase() == 'daily' || h.targetDaysPerWeek == 7) {
          continue;
        }
      }
      layers.add(e.layer);
    }
    return layers.length;
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final now = clock.now();

    final monthStart = DateTime(_currentYear, _currentMonth, 1);
    final monthEnd = DateTime(_currentYear, _currentMonth + 1, 0, 23, 59, 59);

    final entriesMap = ref.watch(
      unifiedCalendarEntriesProvider(
        CalendarWindow(startDate: monthStart, endDate: monthEnd),
      ),
    );

    final gridDays = CalendarDateUtils.getMonthGridDays(
      _currentYear,
      _currentMonth,
    );
    final selectedDateOnly = CalendarDateUtils.dateOnly(widget.selectedDate);
    final selectedDayEntries = entriesMap[selectedDateOnly] ?? [];

    final currencyPref = ref.watch(currencyPreferenceProvider);
    final totalSpentOnSelectedDay = selectedDayEntries
        .whereType<CalendarExpenseEntry>()
        .fold<double>(0.0, (sum, exp) => sum + exp.amount);

    return Column(
      children: [
        // Month Navigation Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoveSpace.gutter,
            CoveSpace.sm,
            CoveSpace.md,
            CoveSpace.sm,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(monthStart),
                style: CoveType.slipTitle.copyWith(
                  fontWeight: FontWeight.w500,
                  color: cv.textPrimary,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      size: CoveSize.avatarInline,
                    ),
                    tooltip: 'Previous month',
                    onPressed: _prevMonth,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      size: CoveSize.avatarInline,
                    ),
                    tooltip: 'Next month',
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ],
          ),
        ),

        Divider(
          height: _kDividerHeight,
          thickness: _kDividerHeight,
          color: cv.lineHairline,
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: _kListHorizontalPadding,
              vertical: CoveSpace.md,
            ),
            children: [
              // Monday-first 7-column header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: CoveSpace.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                      .map(
                        (letter) => SizedBox(
                          width: CoveSize.buttonRound,
                          child: Center(
                            child: Text(
                              letter,
                              style: CoveType.rowSub.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cv.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              // 7-column calendar grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.0,
                  mainAxisSpacing: _kGridSpacing,
                  crossAxisSpacing: _kGridSpacing,
                ),
                itemCount: gridDays.length,
                itemBuilder: (ctx, idx) {
                  final day = gridDays[idx];
                  if (day == null) return const SizedBox.shrink();

                  final isSelected = CalendarDateUtils.isSameDay(
                    day,
                    widget.selectedDate,
                  );
                  final isToday = CalendarDateUtils.isSameDay(day, now);
                  final dotCount = _getDistinctLayerCount(entriesMap, day);

                  return GestureDetector(
                    onTap: () => widget.onSelectDate(day),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Container(
                        width: _kDayCellSize,
                        height: _kDayCellSize,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cv.accentFill
                              : (isToday ? cv.accentWash : cv.surfaceCard),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(CoveSpace.md),
                          ),
                          border: Border.all(
                            color: isToday && !isSelected
                                ? cv.accentFill
                                : (isSelected
                                      ? cv.accentFill
                                      : cv.lineHairline),
                            width: isToday && !isSelected
                                ? _kTodayBorderWidth
                                : _kDividerHeight,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: CoveType.readout.copyWith(
                                fontFamily: 'LibreBodoni',
                                fontWeight: isSelected || isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? cv.textOnAccent
                                    : (isToday
                                          ? cv.accentText
                                          : cv.textPrimary),
                              ),
                            ),
                            const SizedBox(height: CoveSpace.xs),
                            // Stepped champagne opacity density dots
                            _buildDensityDots(
                              cv: cv,
                              count: dotCount,
                              isSelected: isSelected,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: CoveSpace.gutter),

              // Selected day quiet summary peek card
              CoveCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kListHorizontalPadding,
                    vertical: CoveSpace.md,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: _kSummaryIconBoxSize,
                        height: _kSummaryIconBoxSize,
                        decoration: BoxDecoration(
                          color: cv.accentWash,
                          borderRadius: const BorderRadius.all(
                            Radius.circular(_kSummaryIconBoxRadius),
                          ),
                        ),
                        child: Icon(
                          Icons.calendar_today_outlined,
                          size: _kSummaryIconSize,
                          color: cv.accentFill,
                        ),
                      ),
                      const SizedBox(width: CoveSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CalendarDateUtils.formatDateHeading(
                                widget.selectedDate,
                              ),
                              style: CoveType.rowTitle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cv.textPrimary,
                              ),
                            ),
                            const SizedBox(height: CoveSpace.xs),
                            Text(
                              selectedDayEntries.isEmpty
                                  ? 'No scheduled entries · Tap to view day'
                                  : '${selectedDayEntries.length} items'
                                        '${totalSpentOnSelectedDay > 0 ? " · ${currencyPref.symbol}${formatCoveAmount(totalSpentOnSelectedDay)} logged" : ""}',
                              style: CoveType.rowSub.copyWith(
                                color: cv.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CovePillButton(
                        label: 'View Day',
                        isCompact: true,
                        variant: CoveButtonVariant.secondary,
                        onPressed: () =>
                            widget.onSelectDate(widget.selectedDate),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: _kBottomSpacer),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDensityDots({
    required CoveTokens cv,
    required int count,
    required bool isSelected,
  }) {
    if (count <= 0) {
      return const SizedBox(height: CoveSpace.xs);
    }

    final dotColor = isSelected ? cv.textOnAccent : cv.accentFill;
    final effectiveCount = count > 3 ? 3 : count;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(effectiveCount, (i) {
        double opacity = 1.0;
        if (i == 1) opacity = 0.55;
        if (i == 2) opacity = 0.30;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: _kDotMargin),
          width: _kDotSize,
          height: _kDotSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor.withValues(
              alpha: isSelected ? (opacity * 0.9) : opacity,
            ),
          ),
        );
      }),
    );
  }
}
