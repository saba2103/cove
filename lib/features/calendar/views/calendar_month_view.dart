import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/cove_theme.dart';
import '../../../core/utils/cove_currency_formatter.dart';
import '../../../core/widgets/cove_grouped_list.dart';
import '../../../core/widgets/cove_sync_tick.dart';
import '../../../sync/db/app_database.dart';
import '../../activity/activity_formatter.dart';
import '../../profile/preferences_controller.dart';
import '../calendar_event_form_sheet.dart';
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final now = DateTime.now();

    final monthStart = DateTime(_currentYear, _currentMonth, 1);
    final monthEnd = DateTime(_currentYear, _currentMonth + 1, 0);

    // 1. Project subscriptions for current month
    final projectedSubs = CalendarDateUtils.projectSubscriptions(
      subscriptions: widget.subscriptions,
      startDate: monthStart,
      endDate: monthEnd,
    );

    // 2. Project recurring and regular calendar events
    final projectedEvents = CalendarDateUtils.projectCalendarEvents(
      events: widget.events,
      startDate: monthStart,
      endDate: monthEnd,
    );

    // 3. Combine all entries
    final List<CalendarEntry> allEntries = [
      ...projectedEvents,
      ...projectedSubs,
    ];

    // 3. Map entries per day
    final Map<DateTime, List<CalendarEntry>> entriesByDay = {};
    for (final entry in allEntries) {
      final d = CalendarDateUtils.dateOnly(entry.date);
      entriesByDay.putIfAbsent(d, () => []).add(entry);
    }

    final gridDays = CalendarDateUtils.getMonthGridDays(_currentYear, _currentMonth);
    final selectedDateOnly = CalendarDateUtils.dateOnly(widget.selectedDate);
    final selectedDayEntries = entriesByDay[selectedDateOnly] ?? [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // Month Navigation Header
        Row(
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
                  onPressed: _prevMonth,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 22),
                  onPressed: _nextMonth,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Day of Week Header Row (Monday first)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
              .map((letter) => SizedBox(
                    width: 36,
                    child: Center(
                      child: Text(
                        letter,
                        style: TextStyle(
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
        const SizedBox(height: 8),

        // Month Days Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.05,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: gridDays.length,
          itemBuilder: (ctx, idx) {
            final day = gridDays[idx];
            if (day == null) return const SizedBox.shrink();

            final isToday = CalendarDateUtils.isSameDay(day, now);
            final isSelected = CalendarDateUtils.isSameDay(day, widget.selectedDate);
            final itemsForDay = entriesByDay[CalendarDateUtils.dateOnly(day)] ?? [];
            final hasItems = itemsForDay.isNotEmpty;

            return GestureDetector(
              onTap: () => widget.onSelectDate(day),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.accentPrimary
                        : (isToday
                            ? colors.accentPrimary.withValues(alpha: 0.15)
                            : Colors.transparent),
                    shape: BoxShape.circle,
                    border: isToday && !isSelected
                        ? Border.all(color: colors.accentPrimary, width: 1.2)
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: typography.bodyMedium.copyWith(
                          fontSize: 14,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? colors.background
                              : (isToday
                                  ? colors.accentPrimary
                                  : colors.textPrimary),
                        ),
                      ),
                      if (hasItems)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? colors.background
                                : colors.accentPrimary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),
        const Divider(height: 1, thickness: 1),
        const SizedBox(height: 18),

        // Selected Day Panel Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              CalendarDateUtils.formatDateHeading(widget.selectedDate),
              style: typography.caption.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: CalendarDateUtils.isSameDay(widget.selectedDate, now)
                    ? colors.accentPrimary
                    : colors.textPrimary,
              ),
            ),
            IconButton(
              icon: Icon(Icons.add, size: 20, color: colors.accentPrimary),
              visualDensity: VisualDensity.compact,
              onPressed: () => CalendarEventFormSheet.show(
                context,
                initialDate: widget.selectedDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Selected Day Items List
        if (selectedDayEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No events or renewals on this day',
                style: typography.caption.copyWith(color: colors.textSubtle),
              ),
            ),
          )
        else
          CoveGroupedCard(
            children: selectedDayEntries.map((entry) {
              if (entry is CalendarSubscriptionEntry) {
                return _buildSubscriptionRow(context, entry);
              } else if (entry is CalendarEventEntry) {
                return _buildEventRow(context, entry);
              }
              return const SizedBox.shrink();
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildEventRow(BuildContext context, CalendarEventEntry entry) {
    final colors = context.colors;
    final typography = context.typography;
    final event = entry.event;

    final syncStatus = resolveCoveSyncStatus(
      entityId: event.id,
      outbox: widget.outboxEvents,
      hasPartner: widget.hasPartner,
    );

    String timeStr;
    if (event.isAllDay) {
      timeStr = 'All day';
    } else {
      final start = CalendarDateUtils.formatTime(entry.startTime);
      final end = CalendarDateUtils.formatTime(entry.endTime);
      timeStr = '$start – $end';
    }

    return InkWell(
      onTap: () => CalendarEventFormSheet.show(context, existing: event),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: colors.accentPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                entry.isRecurring
                    ? Icons.repeat
                    : Icons.calendar_today_outlined,
                size: 15,
                color: colors.accentPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          event.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.bodyMedium.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (entry.isRecurring) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.repeat,
                          size: 13,
                          color: colors.accentPrimary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        timeStr,
                        style: typography.caption.copyWith(
                          fontSize: 12,
                          color: colors.textSubtle,
                        ),
                      ),
                      if (event.location != null &&
                          event.location!.trim().isNotEmpty) ...[
                        Text(
                          ' • ${event.location!}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.caption.copyWith(
                            fontSize: 12,
                            color: colors.textSubtle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CoveSyncTick(status: syncStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionRow(
      BuildContext context, CalendarSubscriptionEntry entry) {
    final colors = context.colors;
    final typography = context.typography;
    final sub = entry.subscription;
    final currency = ref.watch(currencyPreferenceProvider);
    final sym = ActivityFormatter.getCurrencySymbol(sub.currency, fallbackSymbol: currency.symbol);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.accentSecondary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.autorenew_rounded,
              size: 16,
              color: colors.accentSecondary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sub.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'from Subscriptions',
                  style: typography.caption.copyWith(
                    fontSize: 11,
                    color: colors.accentPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$sym${formatCoveAmount(sub.amount)}',
            style: typography.headline.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
