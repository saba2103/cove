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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final now = DateTime.now();

    // 1. Project recurring and regular events for window
    final windowStart = _displayedWeekStart.subtract(const Duration(days: 14));
    final windowEnd = _displayedWeekStart.add(const Duration(days: 60));

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

    // 4. Dates with items for dot indicators in week strip
    final datesWithItems = allEntries
        .map((e) => CalendarDateUtils.dateOnly(e.date))
        .toSet();

    // 5. Week days (Monday-Sunday)
    final weekDays = List.generate(
      7,
      (i) => _displayedWeekStart.add(Duration(days: i)),
    );

    // 6. Group entries by date
    final Map<DateTime, List<CalendarEntry>> groupedEntries = {};
    for (final entry in allEntries) {
      final d = CalendarDateUtils.dateOnly(entry.date);
      groupedEntries.putIfAbsent(d, () => []).add(entry);
    }

    final sortedDates = groupedEntries.keys.toList()..sort();

    return Column(
      children: [
        // Month Navigation Header with arrows (matching Month tab)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_displayedWeekStart),
                style: typography.headline.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 22),
                    onPressed: () {
                      setState(() {
                        _displayedWeekStart =
                            _displayedWeekStart.subtract(const Duration(days: 7));
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 22),
                    onPressed: () {
                      setState(() {
                        _displayedWeekStart =
                            _displayedWeekStart.add(const Duration(days: 7));
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Horizontal Week Strip
        _buildWeekStrip(
          context,
          weekDays: weekDays,
          datesWithItems: datesWithItems,
          today: now,
        ),

        const Divider(height: 1, thickness: 1),

        // Chronological Agenda
        Expanded(
          child: allEntries.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: sortedDates.length,
                  itemBuilder: (ctx, idx) {
                    final date = sortedDates[idx];
                    final entriesForDate = groupedEntries[date]!;
                    final isToday = CalendarDateUtils.isSameDay(date, now);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group date heading
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Row(
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
                          ),

                          // Card containing entries for this date
                          CoveGroupedCard(
                            children: entriesForDate.map((entry) {
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
                    );
                  },
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

  Widget _buildEmptyState(BuildContext context) {
    return CoveEmptyState(
      icon: Icons.calendar_month_outlined,
      title: 'Nothing Scheduled Yet',
      description:
          'Keep your shared dates, travels, and commitments in calm sync together.',
      action: CovePillButton(
        label: 'Add First Event',
        onPressed: widget.onAddEvent,
      ),
    );
  }
}
