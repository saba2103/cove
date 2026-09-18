import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/cove_theme.dart';
import '../../../core/utils/cove_currency_formatter.dart';
import '../../../core/widgets/cove_grouped_list.dart';
import '../../../core/widgets/cove_pill_button.dart';
import '../../../core/widgets/cove_sync_tick.dart';
import '../../../sync/db/app_database.dart';
import '../../activity/activity_formatter.dart';
import '../../profile/preferences_controller.dart';
import '../calendar_event_form_sheet.dart';
import '../calendar_models.dart';

class CalendarAgendaView extends ConsumerStatefulWidget {
  final List<LocalCalendarEvent> events;
  final List<LocalSubscription> subscriptions;
  final List<LocalOutboxEvent> outboxEvents;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onAddEvent;
  final bool hasPartner;

  const CalendarAgendaView({
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
  ConsumerState<CalendarAgendaView> createState() => _CalendarAgendaViewState();
}

class _CalendarAgendaViewState extends ConsumerState<CalendarAgendaView> {
  late DateTime _displayedWeekStart;
  bool _isMonthExpanded = false;

  @override
  void initState() {
    super.initState();
    _displayedWeekStart = CalendarDateUtils.startOfWeek(widget.selectedDate);
  }

  @override
  void didUpdateWidget(covariant CalendarAgendaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!CalendarDateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _displayedWeekStart = CalendarDateUtils.startOfWeek(widget.selectedDate);
    }
  }

  void _prevPeriod() {
    setState(() {
      if (_isMonthExpanded) {
        _displayedWeekStart = DateTime(
          _displayedWeekStart.year,
          _displayedWeekStart.month - 1,
          1,
        );
      } else {
        _displayedWeekStart = _displayedWeekStart.subtract(const Duration(days: 7));
      }
    });
  }

  void _nextPeriod() {
    setState(() {
      if (_isMonthExpanded) {
        _displayedWeekStart = DateTime(
          _displayedWeekStart.year,
          _displayedWeekStart.month + 1,
          1,
        );
      } else {
        _displayedWeekStart = _displayedWeekStart.add(const Duration(days: 7));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final now = DateTime.now();

    // 1. Project recurring and regular events for window
    final windowStart = DateTime(_displayedWeekStart.year, _displayedWeekStart.month - 1, 1);
    final windowEnd = DateTime(_displayedWeekStart.year, _displayedWeekStart.month + 2, 0);

    final projectedEvents = CalendarDateUtils.projectCalendarEvents(
      events: widget.events,
      startDate: windowStart,
      endDate: windowEnd,
    );

    // 2. Project subscriptions
    final projectedSubs = CalendarDateUtils.projectSubscriptions(
      subscriptions: widget.subscriptions,
      startDate: windowStart,
      endDate: windowEnd,
    );

    // 3. Combine events and subscriptions into single chronological list
    final List<CalendarEntry> allEntries = [
      ...projectedEvents,
      ...projectedSubs,
    ]..sort((a, b) => a.date.compareTo(b.date));

    // 4. Dates with items for dot indicators in week strip & month grid
    final datesWithItems = allEntries
        .map((e) => CalendarDateUtils.dateOnly(e.date))
        .toSet();

    // 5. Week days (Monday-Sunday)
    final weekDays = List.generate(
      7,
      (i) => _displayedWeekStart.add(Duration(days: i)),
    );

    // 6. Filter entries strictly for selected date
    final selectedDateOnly = CalendarDateUtils.dateOnly(widget.selectedDate);
    final selectedDayEntries = allEntries
        .where((e) => CalendarDateUtils.isSameDay(e.date, selectedDateOnly))
        .toList();

    final isToday = CalendarDateUtils.isSameDay(selectedDateOnly, now);

    return Column(
      children: [
        // Month Navigation Header with Chevron to expand/collapse into Month View
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isMonthExpanded = !_isMonthExpanded),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_displayedWeekStart),
                      style: typography.headline.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isMonthExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: colors.accentPrimary,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 22),
                    tooltip: _isMonthExpanded ? 'Previous month' : 'Previous week',
                    onPressed: _prevPeriod,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 22),
                    tooltip: _isMonthExpanded ? 'Next month' : 'Next week',
                    onPressed: _nextPeriod,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Date Row Strip (Collapsed 1-Week Strip or Expanded Month Grid)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _isMonthExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: _buildWeekStrip(
            context,
            weekDays: weekDays,
            datesWithItems: datesWithItems,
            today: now,
          ),
          secondChild: _buildMonthGrid(
            context,
            year: _displayedWeekStart.year,
            month: _displayedWeekStart.month,
            datesWithItems: datesWithItems,
            today: now,
          ),
        ),

        const Divider(height: 1, thickness: 1),

        // Selected Day Events List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Selected Day Date Heading
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    Text(
                      CalendarDateUtils.getRelativeDateLabel(selectedDateOnly, now: now),
                      style: typography.caption.copyWith(
                        color: isToday
                            ? colors.accentPrimary
                            : colors.textSubtle,
                        fontWeight: isToday
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accentPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Events for Selected Day or Day Empty State
              if (selectedDayEntries.isEmpty)
                _buildDayEmptyState(context, selectedDateOnly)
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
          ),
        ),
      ],
    );
  }

  Widget _buildWeekStrip(
    BuildContext context, {
    required List<DateTime> weekDays,
    required Set<DateTime> datesWithItems,
    required DateTime today,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      color: colors.surfaceCard,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: weekDays.map((day) {
          final isSelected =
              CalendarDateUtils.isSameDay(day, widget.selectedDate);
          final isToday = CalendarDateUtils.isSameDay(day, today);
          final hasItems =
              datesWithItems.contains(CalendarDateUtils.dateOnly(day));

          return GestureDetector(
            onTap: () => widget.onSelectDate(day),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.accentPrimary
                    : (isToday
                        ? colors.accentPrimary.withValues(alpha: 0.15)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(14),
                border: isToday && !isSelected
                    ? Border.all(color: colors.accentPrimary, width: 1)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    CalendarDateUtils.formatDayOfWeek(day).substring(0, 2),
                    style: typography.caption.copyWith(
                      fontSize: 11,
                      color: isSelected
                          ? colors.background
                          : colors.textSubtle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: typography.bodyMedium.copyWith(
                      fontWeight:
                          isSelected || isToday ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? colors.background
                          : (isToday
                              ? colors.accentPrimary
                              : colors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Item dot
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasItems
                          ? (isSelected
                              ? colors.background
                              : colors.accentPrimary)
                          : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Expanded full month calendar grid
  Widget _buildMonthGrid(
    BuildContext context, {
    required int year,
    required int month,
    required Set<DateTime> datesWithItems,
    required DateTime today,
  }) {
    final colors = context.colors;
    final gridDays = CalendarDateUtils.getMonthGridDays(year, month);

    return Container(
      color: colors.surfaceCard,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Day of week labels (M, T, W, T, F, S, S)
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

          // 7-column calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: gridDays.length,
            itemBuilder: (ctx, idx) {
              final day = gridDays[idx];
              if (day == null) return const SizedBox.shrink();

              final isSelected =
                  CalendarDateUtils.isSameDay(day, widget.selectedDate);
              final isToday = CalendarDateUtils.isSameDay(day, today);
              final hasItems =
                  datesWithItems.contains(CalendarDateUtils.dateOnly(day));

              return GestureDetector(
                onTap: () {
                  widget.onSelectDate(day);
                  setState(() {
                    _displayedWeekStart = CalendarDateUtils.startOfWeek(day);
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.accentPrimary
                          : (isToday
                              ? colors.accentPrimary.withValues(alpha: 0.15)
                              : Colors.transparent),
                      shape: BoxShape.circle,
                      border: isToday && !isSelected
                          ? Border.all(color: colors.accentPrimary, width: 1)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontFamily: 'GeneralSans',
                            fontSize: 13,
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
                            width: 3.5,
                            height: 3.5,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? colors.background
                                  : colors.accentPrimary,
                            ),
                          )
                        else
                          const SizedBox(height: 4.5),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Row for actual calendar events (interactive, supports edit/delete, has sync tick)
  Widget _buildEventRow(BuildContext context, CalendarEventEntry entry) {
    final colors = context.colors;
    final typography = context.typography;
    final event = entry.event;

    // Check outbox status
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
            // Calendar icon marker
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.accentPrimary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                entry.isRecurring
                    ? Icons.repeat
                    : Icons.calendar_today_outlined,
                size: 16,
                color: colors.accentPrimary,
              ),
            ),
            const SizedBox(width: 14),

            // Title, time & location
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

            // Two-tick sync indicator
            CoveSyncTick(status: syncStatus),
          ],
        ),
      ),
    );
  }

  /// Row for surfaced subscription renewals (read-only, no sync tick, has "from Subscriptions" caption)
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
          // Subscriptions icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.accentSecondary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.autorenew_rounded,
              size: 18,
              color: colors.accentSecondary,
            ),
          ),
          const SizedBox(width: 14),

          // Title & "from Subscriptions" caption
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
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Surfaced renewal amount in editorial Bodoni Moda style
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

  Widget _buildDayEmptyState(BuildContext context, DateTime date) {
    final colors = context.colors;
    final typography = context.typography;
    final isToday = CalendarDateUtils.isSameDay(date, DateTime.now());
    final dayLabel = isToday ? 'today' : DateFormat('EEEE, MMM d').format(date);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 40,
            color: colors.textSubtle.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Nothing planned for $dayLabel',
            style: typography.bodyMedium.copyWith(
              color: colors.textSubtle,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          CovePillButton(
            label: 'Add Event',
            icon: const Icon(Icons.add, size: 16),
            onPressed: widget.onAddEvent,
          ),
        ],
      ),
    );
  }
}
