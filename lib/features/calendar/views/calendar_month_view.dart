import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/cove_theme.dart';
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
    final colors = context.colors;
    final typography = context.typography;
    final now = DateTime.now();

    final monthStart = DateTime(_currentYear, _currentMonth, 1);
    final monthEnd = DateTime(_currentYear, _currentMonth + 1, 0, 23, 59, 59);

    final entriesMap = ref.watch(
      unifiedCalendarEntriesProvider(
        CalendarWindow(startDate: monthStart, endDate: monthEnd),
      ),
    );

    final gridDays = CalendarDateUtils.getMonthGridDays(_currentYear, _currentMonth);
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
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(monthStart),
                style: typography.headline.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 22),
                    tooltip: 'Previous month',
                    onPressed: _prevMonth,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 22),
                    tooltip: 'Next month',
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 1),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // Monday-first 7-column header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                      .map((letter) => SizedBox(
                            width: 40,
                            child: Center(
                              child: Text(
                                letter,
                                style: const TextStyle(
                                  fontFamily: 'GeneralSans',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                            ),
                          ))
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
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemCount: gridDays.length,
                itemBuilder: (ctx, idx) {
                  final day = gridDays[idx];
                  if (day == null) return const SizedBox.shrink();

                  final isSelected = CalendarDateUtils.isSameDay(day, widget.selectedDate);
                  final isToday = CalendarDateUtils.isSameDay(day, now);
                  final dotCount = _getDistinctLayerCount(entriesMap, day);

                  return GestureDetector(
                    onTap: () => widget.onSelectDate(day),
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.accentPrimary
                              : (isToday
                                  ? colors.accentPrimary.withValues(alpha: 0.12)
                                  : colors.surfaceCard),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isToday && !isSelected
                                ? colors.accentPrimary
                                : (isSelected ? colors.accentPrimary : colors.borderHairline),
                            width: isToday && !isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontFamily: 'LibreBodoni',
                                fontSize: 14,
                                fontWeight: isSelected || isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? colors.background
                                    : (isToday ? colors.accentPrimary : colors.textPrimary),
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Stepped champagne opacity density dots
                            _buildDensityDots(
                              colors: colors,
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

              const SizedBox(height: 20),

              // Selected day quiet summary peek card
              CoveCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: colors.accentPrimary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              CalendarDateUtils.formatDateHeading(widget.selectedDate),
                              style: typography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedDayEntries.isEmpty
                                  ? 'No scheduled entries · Tap to view day'
                                  : '${selectedDayEntries.length} items'
                                      '${totalSpentOnSelectedDay > 0 ? " · ${currencyPref.symbol}${formatCoveAmount(totalSpentOnSelectedDay)} logged" : ""}',
                              style: typography.caption.copyWith(
                                color: colors.textSubtle,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CovePillButton(
                        label: 'View Day',
                        isCompact: true,
                        variant: CoveButtonVariant.secondary,
                        onPressed: () => widget.onSelectDate(widget.selectedDate),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDensityDots({
    required CoveColors colors,
    required int count,
    required bool isSelected,
  }) {
    if (count <= 0) {
      return const SizedBox(height: 4);
    }

    final dotColor = isSelected ? colors.background : colors.accentPrimary;
    final effectiveCount = count > 3 ? 3 : count;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(effectiveCount, (i) {
        double opacity = 1.0;
        if (i == 1) opacity = 0.55;
        if (i == 2) opacity = 0.30;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 3.5,
          height: 3.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor.withValues(alpha: isSelected ? (opacity * 0.9) : opacity),
          ),
        );
      }),
    );
  }
}
