import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/cove_theme.dart';
import '../../../core/utils/cove_currency_formatter.dart';
import '../../../core/widgets/cove_empty_state.dart';
import '../../../core/widgets/cove_grouped_list.dart';
import '../../../core/widgets/cove_pill_button.dart';
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
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _todayKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentYear = widget.selectedDate.year;
    _currentMonth = widget.selectedDate.month;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToToday(animated: false);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CalendarMonthView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      _currentYear = widget.selectedDate.year;
      _currentMonth = widget.selectedDate.month;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToToday(animated: false);
      });
    }
  }

  void _scrollToToday({bool animated = false}) {
    final now = DateTime.now();
    if (_currentYear == now.year && _currentMonth == now.month) {
      final ctx = _todayKey.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.0,
          duration: animated ? const Duration(milliseconds: 250) : Duration.zero,
          curve: Curves.easeInOut,
        );
        return;
      }
    }
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToToday(animated: false);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToToday(animated: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final now = DateTime.now();

    final monthStart = DateTime(_currentYear, _currentMonth, 1);
    final monthEnd = DateTime(_currentYear, _currentMonth + 1, 0, 23, 59, 59);
    final isCurrentMonth = _currentYear == now.year && _currentMonth == now.month;

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
    ]..sort((a, b) => a.date.compareTo(b.date));

    // 4. Map entries per day
    final Map<DateTime, List<CalendarEntry>> entriesByDay = {};
    for (final entry in allEntries) {
      final d = CalendarDateUtils.dateOnly(entry.date);
      entriesByDay.putIfAbsent(d, () => []).add(entry);
    }

    final Set<DateTime> datesToShow = Set<DateTime>.from(entriesByDay.keys);
    if (isCurrentMonth) {
      datesToShow.add(CalendarDateUtils.dateOnly(now));
    }
    final sortedDates = datesToShow.toList()..sort();

    return Column(
      children: [
        // Month Navigation Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
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

        // Continuous Month Agenda View
        Expanded(
          child: sortedDates.isEmpty
              ? _buildEmptyMonthState(context, monthStart)
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    ...sortedDates.map((date) {
                      final isToday = CalendarDateUtils.isSameDay(date, now);
                      final entries = entriesByDay[date] ?? [];

                      return KeyedSubtree(
                        key: isToday ? _todayKey : ValueKey(date),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date Header
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          CalendarDateUtils.getRelativeDateLabel(date, now: now),
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
                                    IconButton(
                                      icon: Icon(Icons.add, size: 18, color: colors.textSubtle),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Add event',
                                      onPressed: () => CalendarEventFormSheet.show(
                                        context,
                                        initialDate: date,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Grouped entries for the day or empty today placeholder
                              if (entries.isEmpty)
                                CoveGroupedCard(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 14),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.event_available_outlined,
                                            size: 18,
                                            color: colors.textSubtle,
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Nothing scheduled for today',
                                            style: typography.bodyMedium.copyWith(
                                              color: colors.textSubtle,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              else
                                CoveGroupedCard(
                                  children: entries.map((entry) {
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
                      );
                    }),
                    // Extra bottom padding to allow days later in month to scroll to top
                    const SizedBox(height: 240),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyMonthState(BuildContext context, DateTime month) {
    return CoveEmptyState(
      icon: Icons.calendar_month_outlined,
      title: 'Nothing in ${DateFormat('MMMM yyyy').format(month)}',
      description:
          'Keep your shared dates, travels, and commitments in calm sync together.',
      action: CovePillButton(
        label: 'Add Event',
        icon: const Icon(Icons.add, size: 16),
        onPressed: widget.onAddEvent,
      ),
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
