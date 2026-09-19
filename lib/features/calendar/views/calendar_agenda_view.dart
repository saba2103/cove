import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/cove_theme.dart';
import '../../../core/utils/cove_currency_formatter.dart';
import '../../../core/widgets/cove_checkbox.dart';
import '../../../core/widgets/cove_empty_state.dart';
import '../../../core/widgets/cove_grouped_list.dart';
import '../../../core/widgets/cove_pill_button.dart';
import '../../../core/widgets/cove_sync_tick.dart';
import '../../../sync/db/app_database.dart';
import '../../activity/activity_formatter.dart';
import '../../expenses/expense_detail_sheet.dart';
import '../../habits/habit_controller.dart';
import '../../lists/list_controller.dart';
import '../../lists/list_item_detail_sheet.dart';
import '../../profile/preferences_controller.dart';
import '../../subscriptions/commitment_detail_sheet.dart';
import '../calendar_controller.dart';
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
  CalendarLayer _selectedLayer = CalendarLayer.all;

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

    final windowStart = DateTime(_displayedWeekStart.year, _displayedWeekStart.month - 1, 1);
    final windowEnd = DateTime(_displayedWeekStart.year, _displayedWeekStart.month + 2, 0);

    final entriesMap = ref.watch(
      unifiedCalendarEntriesProvider(
        CalendarWindow(startDate: windowStart, endDate: windowEnd),
      ),
    );

    final weekDays = List.generate(
      7,
      (i) => _displayedWeekStart.add(Duration(days: i)),
    );

    final selectedDateOnly = CalendarDateUtils.dateOnly(widget.selectedDate);
    final dayEntries = entriesMap[selectedDateOnly] ?? [];

    // Filtered entries for selected layer
    final filteredEntries = _selectedLayer == CalendarLayer.all
        ? dayEntries
        : dayEntries.where((e) => e.layer == _selectedLayer).toList();

    // Layer counts for chips
    final eventsCount = dayEntries.whereType<CalendarEventEntry>().length;
    final commitmentsCount = dayEntries.whereType<CalendarSubscriptionEntry>().length;
    final moneyCount = dayEntries.whereType<CalendarExpenseEntry>().length;
    final rhythms = dayEntries.whereType<CalendarHabitEntry>().toList();
    final rhythmsCount = rhythms.length;
    final tasksCount = dayEntries
        .where((e) => e is CalendarTaskEntry || e is CalendarRoutineEntry || e is CalendarReminderEntry)
        .length;

    final completedRhythms = rhythms.where((r) => r.userCheckedIn).length;
    final totalSpent = dayEntries.whereType<CalendarExpenseEntry>().fold<double>(
          0.0,
          (sum, exp) => sum + exp.amount,
        );

    final currencyPref = ref.watch(currencyPreferenceProvider);
    final isToday = CalendarDateUtils.isSameDay(selectedDateOnly, now);

    return Column(
      children: [
        // Month Navigation Header with chevron expand/collapse
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
            entriesMap: entriesMap,
            today: now,
          ),
          secondChild: _buildMonthGrid(
            context,
            year: _displayedWeekStart.year,
            month: _displayedWeekStart.month,
            entriesMap: entriesMap,
            today: now,
          ),
        ),

        // Layer Filter Chips Row (All, Events, Commitments, Money, Rhythms, Tasks)
        _buildLayerFilterChips(
          context,
          allCount: dayEntries.length,
          eventsCount: eventsCount,
          commitmentsCount: commitmentsCount,
          moneyCount: moneyCount,
          rhythmsCount: rhythmsCount,
          tasksCount: tasksCount,
        ),

        const Divider(height: 1, thickness: 1),

        // Selected Day Events & Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            children: [
              // Date Heading & Bodoni Summary Line
              _buildDayHeaderAndSummary(
                context,
                selectedDateOnly: selectedDateOnly,
                isToday: isToday,
                now: now,
                eventsCount: eventsCount,
                completedRhythms: completedRhythms,
                totalRhythms: rhythmsCount,
                totalSpent: totalSpent,
                currencySymbol: currencyPref.symbol,
              ),
              const SizedBox(height: 14),

              // Rhythms Strip (shown if All or Rhythms layer selected and rhythms exist)
              if ((_selectedLayer == CalendarLayer.all || _selectedLayer == CalendarLayer.rhythms) &&
                  rhythms.isNotEmpty) ...[
                _buildRhythmsStrip(context, rhythms),
                const SizedBox(height: 18),
              ],

              // Filtered Timeline Entries or Empty State
              if (filteredEntries.isEmpty)
                _buildEmptyLayerState(context, selectedDateOnly)
              else
                _buildTimelineList(
                  context,
                  entries: _selectedLayer == CalendarLayer.all
                      ? filteredEntries.where((e) => e is! CalendarHabitEntry).toList()
                      : filteredEntries,
                ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekStrip(
    BuildContext context, {
    required List<DateTime> weekDays,
    required Map<DateTime, List<CalendarEntry>> entriesMap,
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
          final isSelected = CalendarDateUtils.isSameDay(day, widget.selectedDate);
          final isToday = CalendarDateUtils.isSameDay(day, today);
          final dotCount = _getDistinctLayerCount(entriesMap, day);

          return GestureDetector(
            onTap: () => widget.onSelectDate(day),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 42,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.accentPrimary
                    : (isToday
                        ? colors.accentPrimary.withValues(alpha: 0.12)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
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
                      color: isSelected ? colors.background : colors.textSubtle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontFamily: 'BodoniModa',
                      fontSize: 16,
                      fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? colors.background
                          : (isToday ? colors.accentPrimary : colors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 5),
                  // Stepped champagne opacity density dots
                  _buildDensityDots(
                    colors: colors,
                    count: dotCount,
                    isSelected: isSelected,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(
    BuildContext context, {
    required int year,
    required int month,
    required Map<DateTime, List<CalendarEntry>> entriesMap,
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

              final isSelected = CalendarDateUtils.isSameDay(day, widget.selectedDate);
              final isToday = CalendarDateUtils.isSameDay(day, today);
              final dotCount = _getDistinctLayerCount(entriesMap, day);

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
                          ? Border.all(color: colors.accentPrimary, width: 1)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontFamily: 'BodoniModa',
                            fontSize: 13,
                            fontWeight: isSelected || isToday
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? colors.background
                                : (isToday ? colors.accentPrimary : colors.textPrimary),
                          ),
                        ),
                        const SizedBox(height: 2),
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
        ],
      ),
    );
  }

  /// Up to 3 density dots based on distinct layers at stepped champagne opacity
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

  Widget _buildLayerFilterChips(
    BuildContext context, {
    required int allCount,
    required int eventsCount,
    required int commitmentsCount,
    required int moneyCount,
    required int rhythmsCount,
    required int tasksCount,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    final chips = [
      (layer: CalendarLayer.all, count: allCount),
      (layer: CalendarLayer.events, count: eventsCount),
      (layer: CalendarLayer.commitments, count: commitmentsCount),
      (layer: CalendarLayer.money, count: moneyCount),
      (layer: CalendarLayer.rhythms, count: rhythmsCount),
      (layer: CalendarLayer.tasks, count: tasksCount),
    ];

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (ctx, idx) {
          final item = chips[idx];
          final isSelected = _selectedLayer == item.layer;

          return GestureDetector(
            onTap: () => setState(() => _selectedLayer = item.layer),
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.accentPrimary
                    : colors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? colors.accentPrimary : colors.borderHairline,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.layer.label,
                    style: typography.caption.copyWith(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? colors.background : colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${item.count}',
                    style: TextStyle(
                      fontFamily: 'BodoniModa',
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? colors.background
                          : colors.textSubtle,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayHeaderAndSummary(
    BuildContext context, {
    required DateTime selectedDateOnly,
    required bool isToday,
    required DateTime now,
    required int eventsCount,
    required int completedRhythms,
    required int totalRhythms,
    required double totalSpent,
    required String currencySymbol,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              CalendarDateUtils.getRelativeDateLabel(selectedDateOnly, now: now),
              style: typography.caption.copyWith(
                color: isToday ? colors.accentPrimary : colors.textSubtle,
                fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
            if (isToday) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accentPrimary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Figures in Bodoni Moda
        Row(
          children: [
            Text(
              '$eventsCount',
              style: const TextStyle(
                fontFamily: 'BodoniModa',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              ' ${eventsCount == 1 ? 'event' : 'events'}  ·  ',
              style: typography.caption.copyWith(color: colors.textSubtle),
            ),
            Text(
              '$completedRhythms/$totalRhythms',
              style: const TextStyle(
                fontFamily: 'BodoniModa',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              ' rhythms  ·  ',
              style: typography.caption.copyWith(color: colors.textSubtle),
            ),
            Text(
              '$currencySymbol${formatCoveAmount(totalSpent)}',
              style: const TextStyle(
                fontFamily: 'BodoniModa',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              ' logged',
              style: typography.caption.copyWith(color: colors.textSubtle),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRhythmsStrip(BuildContext context, List<CalendarHabitEntry> habits) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'RHYTHMS DUE TODAY',
            style: typography.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: colors.textSubtle,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: habits.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (ctx, idx) {
              final habitEntry = habits[idx];
              final isChecked = habitEntry.userCheckedIn;

              return Container(
                width: 190,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderHairline),
                ),
                child: Row(
                  children: [
                    CoveCheckbox(
                      value: isChecked,
                      onChanged: (val) async {
                        await ref.read(habitControllerProvider).toggleCheckin(
                              habit: habitEntry.habit,
                              date: habitEntry.date,
                              checked: val,
                            );
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            habitEntry.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.bodyMedium.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              // Dropping to textMuted without strikethrough
                              color: isChecked ? colors.textMuted : colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '🔥 ',
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                '${habitEntry.streak}',
                                style: const TextStyle(
                                  fontFamily: 'BodoniModa',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                ' streak',
                                style: typography.caption.copyWith(
                                  fontSize: 11,
                                  color: colors.textSubtle,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildTimelineList(
    BuildContext context, {
    required List<CalendarEntry> entries,
  }) {
    return CoveGroupedCard(
      children: entries.map((entry) {
        return _buildTimelineRow(context, entry);
      }).toList(),
    );
  }

  Widget _buildTimelineRow(BuildContext context, CalendarEntry entry) {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.watch(currencyPreferenceProvider);

    // Left gutter time in Bodoni Moda
    String gutterText;
    if (entry.isAllDay) {
      gutterText = 'ALL DAY';
    } else {
      gutterText = DateFormat('h:mm a').format(entry.startTime);
    }

    Widget content;
    if (entry is CalendarEventEntry) {
      content = _buildEventContent(context, entry);
    } else if (entry is CalendarSubscriptionEntry) {
      content = _buildSubscriptionContent(context, entry, currency.symbol);
    } else if (entry is CalendarExpenseEntry) {
      content = _buildExpenseContent(context, entry, currency.symbol);
    } else if (entry is CalendarTaskEntry) {
      content = _buildTaskContent(context, entry);
    } else if (entry is CalendarRoutineEntry) {
      content = _buildRoutineContent(context, entry);
    } else if (entry is CalendarReminderEntry) {
      content = _buildReminderContent(context, entry);
    } else {
      content = Text(entry.title, style: typography.bodyMedium);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bodoni Tabular Time Gutter
          SizedBox(
            width: 72,
            child: Text(
              gutterText,
              style: entry.isAllDay
                  ? typography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: colors.textSubtle,
                    )
                  : const TextStyle(
                      fontFamily: 'BodoniModa',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildEventContent(BuildContext context, CalendarEventEntry entry) {
    final colors = context.colors;
    final typography = context.typography;
    final event = entry.event;

    final syncStatus = resolveCoveSyncStatus(
      entityId: event.id,
      outbox: widget.outboxEvents,
      hasPartner: widget.hasPartner,
    );

    return InkWell(
      onTap: () => CalendarEventFormSheet.show(context, existing: event),
      child: Row(
        children: [
          _buildLayerIcon(
            icon: entry.isRecurring ? Icons.repeat : Icons.calendar_today_outlined,
            color: colors.accentPrimary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMicroLabel('EVENT', colors),
                const SizedBox(height: 2),
                Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                if (event.location != null && event.location!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    event.location!,
                    style: typography.caption.copyWith(
                      fontSize: 11,
                      color: colors.textSubtle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          CoveSyncTick(status: syncStatus),
        ],
      ),
    );
  }

  Widget _buildSubscriptionContent(
    BuildContext context,
    CalendarSubscriptionEntry entry,
    String defaultSymbol,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final sub = entry.subscription;
    final sym = ActivityFormatter.getCurrencySymbol(sub.currency, fallbackSymbol: defaultSymbol);

    return InkWell(
      onTap: () => CommitmentDetailSheet.show(context, sub),
      child: Row(
        children: [
          _buildLayerIcon(
            icon: Icons.autorenew_rounded,
            color: colors.accentSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMicroLabel('RENEWAL', colors),
                const SizedBox(height: 2),
                Text(
                  sub.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sub.billingCycle} commitment',
                  style: typography.caption.copyWith(
                    fontSize: 11,
                    color: colors.textSubtle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sym${formatCoveAmount(sub.amount)}',
            style: const TextStyle(
              fontFamily: 'BodoniModa',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseContent(
    BuildContext context,
    CalendarExpenseEntry entry,
    String defaultSymbol,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final exp = entry.expense;
    final sym = ActivityFormatter.getCurrencySymbol(exp.currency, fallbackSymbol: defaultSymbol);

    return InkWell(
      onTap: () => ExpenseDetailSheet.show(context, exp),
      child: Row(
        children: [
          _buildLayerIcon(
            icon: Icons.receipt_long_outlined,
            color: colors.accentPrimary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildMicroLabel('EXPENSE', colors),
                    const SizedBox(width: 6),
                    _buildAttributionChip(entry.payerName, colors),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  exp.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                if (exp.category != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    exp.category!,
                    style: typography.caption.copyWith(
                      fontSize: 11,
                      color: colors.textSubtle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sym${formatCoveAmount(exp.amount)}',
            style: const TextStyle(
              fontFamily: 'BodoniModa',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskContent(BuildContext context, CalendarTaskEntry entry) {
    final colors = context.colors;
    final typography = context.typography;
    final item = entry.item;
    final isDone = item.isCompleted;

    return InkWell(
      onTap: () => ListItemDetailSheet.show(
        context,
        item: item,
        listName: entry.listName,
      ),
      child: Row(
        children: [
          CoveCheckbox(
            value: isDone,
            onChanged: (val) async {
              await ref.read(listControllerProvider).toggleItem(
                    itemId: item.id,
                    isCompleted: val,
                    itemTitle: item.title,
                    listName: entry.listName,
                  );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildMicroLabel('TASK', colors),
                    const SizedBox(width: 6),
                    _buildAttributionChip(entry.listName, colors),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDone ? colors.textMuted : colors.textPrimary,
                    // Strikethrough for tasks
                    decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineContent(BuildContext context, CalendarRoutineEntry entry) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceRow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colors.borderHairline,
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, size: 16, color: colors.textSubtle),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildMicroLabel('ROUTINE', colors),
                    const SizedBox(width: 6),
                    Text(
                      entry.routine.name,
                      style: typography.caption.copyWith(
                        fontSize: 10,
                        color: colors.textSubtle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  entry.title,
                  style: typography.bodyMedium.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderContent(BuildContext context, CalendarReminderEntry entry) {
    final colors = context.colors;
    final typography = context.typography;

    return Row(
      children: [
        _buildLayerIcon(
          icon: Icons.notifications_none_outlined,
          color: colors.accentSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMicroLabel('CHECK-IN', colors),
              const SizedBox(height: 2),
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayerIcon({required IconData icon, required Color color}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 16, color: color),
    );
  }

  Widget _buildMicroLabel(String label, CoveColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: colors.surfaceRow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'GeneralSans',
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: colors.textSubtle,
        ),
      ),
    );
  }

  Widget _buildAttributionChip(String text, CoveColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colors.accentPrimary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'GeneralSans',
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: colors.accentPrimary,
        ),
      ),
    );
  }

  Widget _buildEmptyLayerState(BuildContext context, DateTime date) {
    if (_selectedLayer == CalendarLayer.all) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: CoveEmptyState(
          icon: Icons.spa_outlined,
          title: 'A quiet day in your sanctuary',
          description: 'No events, rhythms, or tasks scheduled for today.',
          action: CovePillButton(
            label: '+ Add Entry',
            icon: const Icon(Icons.add, size: 16),
            onPressed: widget.onAddEvent,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: CoveEmptyState(
        icon: Icons.event_available_outlined,
        title: 'No ${_selectedLayer.label.toLowerCase()} on this day',
        description: 'Keep your household rhythms and commitments in sync together.',
        action: CovePillButton(
          label: 'Add to Sanctuary',
          icon: const Icon(Icons.add, size: 16),
          onPressed: widget.onAddEvent,
        ),
      ),
    );
  }
}
