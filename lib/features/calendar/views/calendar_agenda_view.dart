import 'dart:math' as math;
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/shape/cove_shape.dart';
import '../../../core/theme/cove_tokens.dart';
import '../../../core/utils/cove_currency_formatter.dart';
import '../../../core/widgets/cove_avatar.dart';
import '../../../core/widgets/cove_max_width.dart';
import '../../../core/widgets/cove_metric_card.dart';
import '../../../core/widgets/cove_page_header.dart';
import '../../../core/widgets/cove_round_button.dart';
import '../../../core/widgets/cove_row.dart';
import '../../../core/widgets/cove_section_label.dart';
import '../../../core/widgets/cove_seed_card.dart';
import '../../../core/widgets/cove_sync_tick.dart';
import '../../../sync/db/app_database.dart';
import '../../../sync/providers/active_home_provider.dart';
import '../../../sync/providers/first_run_provider.dart';
import '../../activity/activity_formatter.dart';
import '../../auth/auth_controller.dart';
import '../../expenses/expense_detail_sheet.dart';
import '../../habits/habit_controller.dart';
import '../../lists/list_controller.dart';
import '../../lists/list_item_detail_sheet.dart';
import '../../profile/partner_profile_controller.dart';
import '../../profile/preferences_controller.dart';
import '../../profile/user_profile_controller.dart';
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
  static const double _kDayPillWidth = CoveSize.buttonRound;
  static const double _kDayPillGap = CoveSpace.xs;
  static const double _kDayPillStride = _kDayPillWidth + _kDayPillGap;
  static const double _kHairline = 1.0; // (literal)
  static const double _kCheckBorder = 1.5; // (literal)
  static const double _kTaskCheckboxSize = 20.0; // (literal)
  static const double _kCheckIconSize = 14.0; // (literal)
  static const double _kRenewalIconSize = 16.0; // (literal)
  static const double _kPipDiameter = 4.0; // (literal)
  static const double _kPipCommitmentWidth = 10.0; // (literal)
  static const double _kPipSpacing = 2.0; // (literal)

  late ScrollController _dateStripController;

  @override
  void initState() {
    super.initState();
    _dateStripController = ScrollController(
      initialScrollOffset: _computeStripOffset(
        widget.selectedDate.toLocal().day,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant CalendarAgendaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!CalendarDateUtils.isSameDay(
          oldWidget.selectedDate,
          widget.selectedDate,
        ) &&
        _dateStripController.hasClients) {
      final target = _computeStripOffset(
        widget.selectedDate.toLocal().day,
      ).clamp(
        0.0,
        _dateStripController.position.maxScrollExtent,
      );
      _dateStripController.jumpTo(target);
    }
  }

  @override
  void dispose() {
    _dateStripController.dispose();
    super.dispose();
  }

  double _computeStripOffset(int dayOfMonth) {
    // Center the selected day roughly 3 pills in from the left gutter.
    final index = math.max(0, dayOfMonth - 4);
    return index * _kDayPillStride;
  }

  void _stepMonth(int deltaMonths) {
    final selectedLocal = widget.selectedDate.toLocal();
    final targetFirst = DateTime(
      selectedLocal.year,
      selectedLocal.month + deltaMonths,
      1,
    );
    final daysInTargetMonth =
        DateTime(targetFirst.year, targetFirst.month + 1, 0).day;
    final clampedDay = math.min(selectedLocal.day, daysInTargetMonth);
    widget.onSelectDate(
      DateTime(targetFirst.year, targetFirst.month, clampedDay),
    );
  }

  Map<DateTime, List<CalendarEntry>> _resolveEntriesMap({
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final baseMap = ref.watch(
      unifiedCalendarEntriesProvider(
        CalendarWindow(startDate: windowStart, endDate: windowEnd),
      ),
    );

    final merged = <DateTime, List<CalendarEntry>>{
      for (final e in baseMap.entries) e.key: List<CalendarEntry>.from(e.value),
    };

    // Ensure initialEvents / initialSubscriptions passed directly to CalendarScreen
    // are also projected if not already present in the stream provider map.
    if (widget.events.isNotEmpty) {
      final projectedEvents = CalendarDateUtils.projectCalendarEvents(
        events: widget.events,
        startDate: windowStart,
        endDate: windowEnd,
      );
      for (final ev in projectedEvents) {
        final d = CalendarDateUtils.dateOnly(ev.date);
        final list = merged.putIfAbsent(d, () => []);
        if (!list.any((x) => x.id == ev.id)) {
          list.add(ev);
        }
      }
    }

    if (widget.subscriptions.isNotEmpty) {
      final projectedSubs = CalendarDateUtils.projectSubscriptions(
        subscriptions: widget.subscriptions,
        startDate: windowStart,
        endDate: windowEnd,
      );
      for (final sub in projectedSubs) {
        final d = CalendarDateUtils.dateOnly(sub.date);
        final list = merged.putIfAbsent(d, () => []);
        if (!list.any((x) => x.id == sub.id)) {
          list.add(sub);
        }
      }
    }

    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final now = clock.now();
    final selectedDateOnly = CalendarDateUtils.dateOnly(widget.selectedDate);

    final monthStart = DateTime(selectedDateOnly.year, selectedDateOnly.month, 1);
    final monthEnd = DateTime(selectedDateOnly.year, selectedDateOnly.month + 1, 0);
    final windowEnd = monthEnd.add(const Duration(days: 60));

    final entriesMap = _resolveEntriesMap(
      windowStart: monthStart,
      windowEnd: windowEnd,
    );

    final daysInMonth = monthEnd.day;
    final monthDays = List<DateTime>.generate(
      daysInMonth,
      (i) => DateTime(selectedDateOnly.year, selectedDateOnly.month, i + 1),
    );

    final dayEntries = entriesMap[selectedDateOnly] ?? const <CalendarEntry>[];

    final events = dayEntries.whereType<CalendarEventEntry>().toList();
    final habits = dayEntries.whereType<CalendarHabitEntry>().toList();
    final expenses = dayEntries.whereType<CalendarExpenseEntry>().toList();
    final tasks = dayEntries.whereType<CalendarTaskEntry>().toList();
    final commitmentsDue =
        dayEntries.whereType<CalendarSubscriptionEntry>().toList();

    final completedHabits = habits.where((h) => h.userCheckedIn).length;
    final completedTasks = tasks.where((t) => t.isCompleted).length;
    final totalSpent = expenses.fold<double>(
      0.0,
      (sum, exp) => sum + exp.amount,
    );

    final currencyPref = ref.watch(currencyPreferenceProvider);
    final home = ref.watch(activeHomeProvider).value;
    final currentUserId = ref.watch(authProvider).value?.id ?? 'local_user';
    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);

    final myName =
        userProfile.displayName.isNotEmpty ? userProfile.displayName : 'You';
    final partnerName = partnerProfile.displayName.isNotEmpty
        ? partnerProfile.displayName
        : 'Partner';
    final creatorId = home?.createdBy ?? currentUserId;
    final isFirstRun =
        ref.watch(firstRunProvider(CoveScreen.calendar)) == FirstRunState.firstRun;
    final isTodaySelected = CalendarDateUtils.isSameDay(
      selectedDateOnly,
      CalendarDateUtils.dateOnly(now),
    );
    final weekdayName = DateFormat('EEEE').format(selectedDateOnly);

    final bottomPadding =
        CoveSpace.barClearance + CovePageInsets.bottomOf(context);

    return CoveMaxWidth(
      child: ListView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        children: [
          // 1. CovePageHeader — month name + year, chevrons for month switching, gold add
          CovePageHeader(
            title: DateFormat('MMMM').format(monthStart),
            readout: '${monthStart.year}',
            actions: [
              CoveRoundButton(
                key: const ValueKey('calendar_prev_month'),
                icon: Icons.chevron_left_rounded,
                variant: CoveRoundButtonVariant.ghost,
                tooltip: 'Previous month',
                semanticLabel: 'Previous month',
                onPressed: () => _stepMonth(-1),
              ),
              CoveRoundButton(
                key: const ValueKey('calendar_next_month'),
                icon: Icons.chevron_right_rounded,
                variant: CoveRoundButtonVariant.ghost,
                tooltip: 'Next month',
                semanticLabel: 'Next month',
                onPressed: () => _stepMonth(1),
              ),
              CoveRoundButton(
                key: const ValueKey('calendar_add_button'),
                icon: Icons.add_rounded,
                variant: CoveRoundButtonVariant.gold,
                tooltip: 'Add',
                semanticLabel: 'Add',
                onPressed: widget.onAddEvent,
              ),
            ],
          ),
          const SizedBox(height: CoveSpace.md),

          // 2. Date strip — selected month's dates only, horizontally scrollable, pips under days that have content
          _buildMonthDateStrip(
            context,
            monthDays: monthDays,
            selectedDateOnly: selectedDateOnly,
            today: CalendarDateUtils.dateOnly(now),
            entriesMap: entriesMap,
          ),
          const SizedBox(height: CoveSpace.md),
          ColoredBox(
            color: cv.lineHairline,
            child: const SizedBox(
              width: double.infinity,
              height: _kHairline,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: CoveSpace.lg),

                // 3. Selected day line: "Wednesday, Oct 21 · today"
                _buildSelectedDayLine(
                  context,
                  selectedDateOnly: selectedDateOnly,
                  now: now,
                ),
                const SizedBox(height: CoveSpace.lg),

                // 4. CoveMetricCard row — spent, events, habits, the list
                CoveMetricGrid(
                  children: [
                    CoveMetricCard(
                      label: 'SPENT',
                      value: isFirstRun
                          ? '—'
                          : '${currencyPref.symbol}${formatCoveAmount(totalSpent)}',
                      subtitle: expenses.isEmpty
                          ? 'no spends'
                          : '${expenses.length} ${expenses.length == 1 ? 'spend' : 'spends'}',
                    ),
                    CoveMetricCard(
                      label: 'EVENTS',
                      value: isFirstRun ? '—' : '${events.length}',
                      subtitle: events.isEmpty
                          ? 'nothing scheduled'
                          : 'on the calendar',
                    ),
                    CoveMetricCard(
                      label: 'HABITS',
                      value: isFirstRun
                          ? '—'
                          : '$completedHabits/${habits.length}',
                      subtitle: habits.isEmpty ? 'none due' : 'kept today',
                    ),
                    CoveMetricCard(
                      label: 'THE LIST',
                      value:
                          isFirstRun ? '—' : '$completedTasks/${tasks.length}',
                      subtitle:
                          tasks.isEmpty ? 'nothing on the list' : 'struck off',
                    ),
                  ],
                ),
                const SizedBox(height: CoveSpace.section),

                if (isFirstRun)
                  CoveSeedCard(
                    art: CoveSeedArtKind.calendar,
                    title: 'An empty $weekdayName',
                    body:
                        'Events, spending, habits and list lines all land on a '
                        'date. Put one here and the day starts holding things.',
                    buttonLabel:
                        isTodaySelected ? 'Add to today' : 'Add to $weekdayName',
                    onPressed: widget.onAddEvent,
                    altText: 'Nothing is due this month either.',
                  )
                else ...[
                  // 5. Fixed Section 1: EVENTS
                  CoveSectionLabel.page(
                    label: 'EVENTS',
                    readout: '${events.length}',
                  ),
                  const SizedBox(height: CoveSpace.xs),
                  if (events.isEmpty)
                    _buildQuietEmptyLine(
                      context,
                      'Nothing on the calendar for this day.',
                    )
                  else
                    for (var i = 0; i < events.length; i++)
                      _buildEventRow(
                        context,
                        entry: events[i],
                        isLast: i == events.length - 1,
                        creatorId: creatorId,
                        currentUserId: currentUserId,
                        myName: myName,
                        partnerName: partnerName,
                      ),
                  const SizedBox(height: CoveSpace.section),

                  // 5. Fixed Section 2: HABITS
                  CoveSectionLabel.page(
                    label: 'HABITS',
                    readout: habits.isEmpty
                        ? '0'
                        : '$completedHabits of ${habits.length}',
                  ),
                  const SizedBox(height: CoveSpace.xs),
                  if (habits.isEmpty)
                    _buildQuietEmptyLine(
                      context,
                      'No habits due on this day.',
                    )
                  else
                    for (var i = 0; i < habits.length; i++)
                      _buildHabitRow(
                        context,
                        entry: habits[i],
                        isLast: i == habits.length - 1,
                      ),
                  const SizedBox(height: CoveSpace.section),

                  // 5. Fixed Section 3: SPENT
                  CoveSectionLabel.page(
                    label: 'SPENT',
                    readout:
                        '${currencyPref.symbol}${formatCoveAmount(totalSpent)}',
                  ),
                  const SizedBox(height: CoveSpace.xs),
                  if (expenses.isEmpty)
                    _buildQuietEmptyLine(
                      context,
                      'No expenses logged on this day.',
                    )
                  else
                    for (var i = 0; i < expenses.length; i++)
                      _buildExpenseRow(
                        context,
                        entry: expenses[i],
                        isLast: i == expenses.length - 1,
                        defaultSymbol: currencyPref.symbol,
                        creatorId: creatorId,
                        currentUserId: currentUserId,
                        myName: myName,
                        partnerName: partnerName,
                      ),
                  const SizedBox(height: CoveSpace.section),

                  // 5. Fixed Section 4: THE LIST
                  CoveSectionLabel.page(
                    label: 'THE LIST',
                    readout: tasks.isEmpty ? null : '${tasks.length}',
                  ),
                  const SizedBox(height: CoveSpace.xs),
                  if (tasks.isEmpty)
                    _buildQuietEmptyLine(
                      context,
                      'Nothing added or struck on this day.',
                    )
                  else
                    for (var i = 0; i < tasks.length; i++)
                      _buildTaskRow(
                        context,
                        entry: tasks[i],
                        isLast: i == tasks.length - 1,
                        currentUserId: currentUserId,
                        myName: myName,
                        partnerName: partnerName,
                      ),
                  const SizedBox(height: CoveSpace.section),

                  // 6. Commitments due, given prominence — this is where renewals are noticed
                  _buildCommitmentsDueCard(
                    context,
                    commitmentsDue: commitmentsDue,
                    entriesMap: entriesMap,
                    selectedDateOnly: selectedDateOnly,
                    windowEnd: windowEnd,
                    defaultSymbol: currencyPref.symbol,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthDateStrip(
    BuildContext context, {
    required List<DateTime> monthDays,
    required DateTime selectedDateOnly,
    required DateTime today,
    required Map<DateTime, List<CalendarEntry>> entriesMap,
  }) {
    final cv = context.cv;
    final duration = CoveMotion.q(context);

    return SingleChildScrollView(
      controller: _dateStripController,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
      child: Row(
        children: [
          for (var i = 0; i < monthDays.length; i++) ...[
            if (i > 0) const SizedBox(width: _kDayPillGap),
            Builder(
              builder: (context) {
                final day = monthDays[i];
                final isSelected =
                    CalendarDateUtils.isSameDay(day, selectedDateOnly);
                final isToday = CalendarDateUtils.isSameDay(day, today);
                final dayEntries =
                    entriesMap[CalendarDateUtils.dateOnly(day)] ?? const [];
                final weekdayLetter = DateFormat('E')
                    .format(day)
                    .substring(0, 1)
                    .toUpperCase();

                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: DateFormat('EEEE, MMMM d').format(day),
                  child: GestureDetector(
                    key: ValueKey('calendar_day_${day.year}_${day.month}_${day.day}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onSelectDate(day),
                    child: AnimatedContainer(
                      duration: duration,
                      curve: CoveMotion.easing,
                      width: _kDayPillWidth,
                      padding: const EdgeInsets.symmetric(
                        vertical: CoveSpace.sm,
                      ),
                      decoration: CoveShape.decoration(
                        CoveRadius.inline,
                        color: isSelected ? cv.accentFill : Colors.transparent,
                        side: isToday && !isSelected
                            ? BorderSide(
                                color: cv.lineStrong,
                                width: _kHairline,
                              )
                            : BorderSide.none,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            weekdayLetter,
                            style: CoveType.capsCard.copyWith(
                              color: isSelected
                                  ? cv.textOnAccent
                                  : cv.textTertiary,
                            ),
                          ),
                          const SizedBox(height: CoveSpace.xs),
                          Text(
                            '${day.day}',
                            style: CoveType.rowTitle.copyWith(
                              color: isSelected
                                  ? cv.textOnAccent
                                  : (isToday ? cv.accentTint : cv.textPrimary),
                            ),
                          ),
                          const SizedBox(height: CoveSpace.xs),
                          _buildDayPips(
                            context,
                            dayEntries: dayEntries,
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
        ],
      ),
    );
  }

  Widget _buildDayPips(
    BuildContext context, {
    required List<CalendarEntry> dayEntries,
    required bool isSelected,
  }) {
    final cv = context.cv;
    final hasEvent = dayEntries.any((e) => e is CalendarEventEntry);
    final hasExpense = dayEntries.any((e) => e is CalendarExpenseEntry);
    final hasTask = dayEntries.any((e) => e is CalendarTaskEntry);
    final hasCommitment =
        dayEntries.any((e) => e is CalendarSubscriptionEntry);

    final pipKinds = <bool>[
      if (hasEvent) false,
      if (hasExpense) false,
      if (hasTask) false,
      if (hasCommitment) true, // true = wider commitment bar pip
    ];

    if (pipKinds.isEmpty) {
      return const SizedBox(height: _kPipDiameter);
    }

    final pipColor = isSelected ? cv.textOnAccent : cv.accentTint;
    final visiblePips = pipKinds.take(3).toList();

    return SizedBox(
      height: _kPipDiameter,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < visiblePips.length; i++) ...[
            if (i > 0) const SizedBox(width: _kPipSpacing),
            DecoratedBox(
              decoration: CoveShape.decoration(
                CoveRadius.pill,
                color: pipColor,
              ),
              child: SizedBox(
                width:
                    visiblePips[i] ? _kPipCommitmentWidth : _kPipDiameter,
                height: _kPipDiameter,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectedDayLine(
    BuildContext context, {
    required DateTime selectedDateOnly,
    required DateTime now,
  }) {
    final cv = context.cv;
    final todayOnly = CalendarDateUtils.dateOnly(now);
    final diffDays = selectedDateOnly.difference(todayOnly).inDays;

    String? relativeWord;
    if (diffDays == 0) {
      relativeWord = 'today';
    } else if (diffDays == 1) {
      relativeWord = 'tomorrow';
    } else if (diffDays == -1) {
      relativeWord = 'yesterday';
    }

    final formattedDate = DateFormat('EEEE, MMM d').format(selectedDateOnly);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            formattedDate,
            style: CoveType.title.copyWith(color: cv.textPrimary),
          ),
        ),
        if (relativeWord != null) ...[
          const SizedBox(width: CoveSpace.sm),
          Text(
            relativeWord,
            style: CoveType.readout.copyWith(color: cv.textTertiary),
          ),
        ],
      ],
    );
  }

  Widget _buildQuietEmptyLine(BuildContext context, String message) {
    final cv = context.cv;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CoveSpace.sm),
      child: Text(
        message,
        style: CoveType.rowSub.copyWith(color: cv.textTertiary),
      ),
    );
  }

  Widget _buildEventRow(
    BuildContext context, {
    required CalendarEventEntry entry,
    required bool isLast,
    required String creatorId,
    required String currentUserId,
    required String myName,
    required String partnerName,
  }) {
    final cv = context.cv;
    final event = entry.event;

    final syncStatus = resolveCoveSyncStatus(
      entityId: event.id,
      outbox: widget.outboxEvents,
      hasPartner: widget.hasPartner,
    );

    final startLocal = entry.startTime.toLocal();
    final String topTime = entry.isAllDay
        ? 'ALL'
        : DateFormat('h').format(startLocal);
    final String bottomTime = entry.isAllDay
        ? 'DAY'
        : DateFormat('a').format(startLocal).toUpperCase();

    final rawOwner = event.owner ?? 'both';
    final String ownerLabel;
    final Widget ownerAvatar;
    if (rawOwner.isEmpty || rawOwner == 'both') {
      ownerLabel = 'Both of you';
      ownerAvatar = const CoveAvatar.inline(person: CovePerson.both);
    } else if (rawOwner == currentUserId ||
        rawOwner == 'local_user' ||
        rawOwner == 'me') {
      ownerLabel = myName;
      final isCreator = currentUserId == creatorId || rawOwner == creatorId;
      ownerAvatar = CoveAvatar.inline(
        person: isCreator ? CovePerson.a : CovePerson.b,
        nameOrInitial: myName,
      );
    } else {
      ownerLabel = partnerName;
      final isCreator = rawOwner == creatorId;
      ownerAvatar = CoveAvatar.inline(
        person: isCreator ? CovePerson.a : CovePerson.b,
        nameOrInitial: partnerName,
      );
    }

    final subtitleParts = <String>[
      if (event.location != null && event.location!.trim().isNotEmpty)
        event.location!.trim(),
      ownerLabel,
    ];

    return CoveRow(
      leading: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topTime,
            style: CoveType.rowSub.copyWith(color: cv.textSecondary),
          ),
          Text(
            bottomTime,
            style: CoveType.barLabel.copyWith(color: cv.textTertiary),
          ),
        ],
      ),
      title: event.title,
      subtitle: subtitleParts.join(' · '),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CoveSyncTick(status: syncStatus),
          const SizedBox(width: CoveSpace.sm),
          ownerAvatar,
        ],
      ),
      isLast: isLast,
      onTap: () => CalendarEventFormSheet.show(context, existing: event),
    );
  }

  Widget _buildHabitRow(
    BuildContext context, {
    required CalendarHabitEntry entry,
    required bool isLast,
  }) {
    final cv = context.cv;
    final isKept = entry.userCheckedIn;
    final cadenceText = _formatHabitCadence(entry.habit);
    final scopeText = entry.isPrivate ? 'just you' : 'both of you';

    Future<void> handleToggle() async {
      await ref.read(habitControllerProvider).toggleCheckin(
            habit: entry.habit,
            date: entry.date,
            checked: !isKept,
          );
    }

    return CoveRow(
      leading: Container(
        width: CoveSize.avatarInline,
        height: CoveSize.avatarInline,
        decoration: BoxDecoration(
          color: isKept ? cv.accentFill : Colors.transparent,
          shape: BoxShape.circle,
          border: isKept
              ? null
              : Border.all(
                  color: cv.accentFill,
                  width: _kCheckBorder,
                ),
        ),
        alignment: Alignment.center,
        child: isKept
            ? Icon(
                Icons.check_rounded,
                size: _kCheckIconSize,
                color: cv.textOnAccent,
              )
            : null,
      ),
      title: entry.title,
      subtitle: '$cadenceText · $scopeText',
      trailing: Text(
        isKept ? 'KEPT' : 'NOT YET',
        style: CoveType.capsCard.copyWith(
          color: isKept ? cv.accentText : cv.textTertiary,
        ),
      ),
      isLast: isLast,
      onTap: handleToggle,
    );
  }

  String _formatHabitCadence(LocalHabit habit) {
    final c = habit.cadence.trim().toLowerCase();
    if (c == 'daily' || habit.targetDaysPerWeek >= 7) {
      return 'every day';
    }
    if (habit.targetDaysPerWeek > 0) {
      return '${habit.targetDaysPerWeek}x a week';
    }
    return c.isEmpty ? 'every day' : c;
  }

  Widget _buildExpenseRow(
    BuildContext context, {
    required CalendarExpenseEntry entry,
    required bool isLast,
    required String defaultSymbol,
    required String creatorId,
    required String currentUserId,
    required String myName,
    required String partnerName,
  }) {
    final exp = entry.expense;
    final sym = ActivityFormatter.getCurrencySymbol(
      exp.currency,
      fallbackSymbol: defaultSymbol,
    );

    final isCreator = exp.paidBy == creatorId ||
        (exp.paidBy == 'local_user' && currentUserId == creatorId);
    final person = isCreator ? CovePerson.a : CovePerson.b;
    final payerDisplay =
        (exp.paidBy == currentUserId || exp.paidBy == 'local_user')
            ? myName
            : partnerName;

    final subParts = <String>[
      if (exp.category != null && exp.category!.trim().isNotEmpty)
        exp.category!.trim(),
      if (exp.paymentMethod != null && exp.paymentMethod!.trim().isNotEmpty)
        _formatPaymentMethod(exp.paymentMethod!.trim()),
    ];

    return CoveRow(
      avatar: CoveAvatar.row(
        person: person,
        nameOrInitial: payerDisplay,
      ),
      title: exp.title,
      subtitle: subParts.isEmpty ? payerDisplay : subParts.join(' · '),
      amount: '$sym${formatCoveAmount(exp.amount)}',
      isLast: isLast,
      onTap: () => ExpenseDetailSheet.show(context, exp),
    );
  }

  String _formatPaymentMethod(String method) {
    final lower = method.toLowerCase();
    if (lower == 'upi') return 'UPI';
    if (lower == 'card') return 'Card';
    if (lower == 'cash') return 'Cash';
    return method;
  }

  Widget _buildTaskRow(
    BuildContext context, {
    required CalendarTaskEntry entry,
    required bool isLast,
    required String currentUserId,
    required String myName,
    required String partnerName,
  }) {
    final cv = context.cv;
    final item = entry.item;
    final isDone = item.isCompleted;
    final actorId = isDone ? (item.completedBy ?? item.createdBy) : item.createdBy;
    final actorName =
        (actorId == currentUserId || actorId == 'local_user') ? myName : partnerName;

    final rawOwner = item.owner;
    final String whoLabel;
    if (rawOwner != null && rawOwner.isNotEmpty) {
      if (rawOwner == 'both') {
        whoLabel = 'Both of you';
      } else if (rawOwner == 'either') {
        whoLabel = 'Either of you';
      } else if (rawOwner == currentUserId ||
          rawOwner == 'local_user' ||
          rawOwner == 'me') {
        whoLabel = myName;
      } else {
        whoLabel = partnerName;
      }
    } else {
      whoLabel = actorName;
    }

    return CoveRow(
      leading: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          await ref.read(listControllerProvider).toggleItem(
                itemId: item.id,
                isCompleted: !isDone,
                itemTitle: item.title,
                listName: entry.listName,
              );
        },
        child: Container(
          width: _kTaskCheckboxSize,
          height: _kTaskCheckboxSize,
          decoration: CoveShape.decoration(
            CoveSpace.xs,
            color: isDone ? cv.accentFill : Colors.transparent,
            side: isDone
                ? BorderSide.none
                : BorderSide(
                    color: cv.accentFill,
                    width: _kCheckBorder,
                  ),
          ),
          alignment: Alignment.center,
          child: isDone
              ? Icon(
                  Icons.check_rounded,
                  size: _kCheckIconSize,
                  color: cv.textOnAccent,
                )
              : null,
        ),
      ),
      title: item.title,
      subtitle: '${entry.listName} · $whoLabel',
      trailing: Text(
        isDone ? 'STRUCK' : 'WENT ON',
        style: CoveType.capsCard.copyWith(
          color: isDone ? cv.accentText : cv.textTertiary,
        ),
      ),
      isLast: isLast,
      onTap: () => ListItemDetailSheet.show(
        context,
        item: item,
        listName: entry.listName,
      ),
    );
  }

  Widget _buildCommitmentsDueCard(
    BuildContext context, {
    required List<CalendarSubscriptionEntry> commitmentsDue,
    required Map<DateTime, List<CalendarEntry>> entriesMap,
    required DateTime selectedDateOnly,
    required DateTime windowEnd,
    required String defaultSymbol,
  }) {
    final cv = context.cv;

    if (commitmentsDue.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.all(CoveSpace.md),
        decoration: CoveShape.decoration(
          CoveRadius.card,
          color: cv.surfaceCard,
          side: BorderSide(
            color: cv.lineStrong,
            width: _kHairline,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoveSectionLabel.card(
              label: 'RENEWAL',
              readout: '${commitmentsDue.length} due',
            ),
            const SizedBox(height: CoveSpace.xs),
            for (var i = 0; i < commitmentsDue.length; i++)
              Builder(
                builder: (context) {
                  final entry = commitmentsDue[i];
                  final sub = entry.subscription;
                  final sym = ActivityFormatter.getCurrencySymbol(
                    sub.currency,
                    fallbackSymbol: defaultSymbol,
                  );
                  final viaText = (sub.financedThrough != null &&
                          sub.financedThrough!.trim().isNotEmpty)
                      ? ' · via ${sub.financedThrough!.trim()}'
                      : '';

                  return CoveRow(
                    leading: Container(
                      width: CoveSize.avatarRow,
                      height: CoveSize.avatarRow,
                      decoration: CoveShape.decoration(
                        CoveRadius.inline,
                        color: cv.surfaceRow,
                        side: BorderSide(
                          color: cv.lineHairline,
                          width: _kHairline,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.autorenew_rounded,
                        size: _kRenewalIconSize,
                        color: cv.accentTint,
                      ),
                    ),
                    title: sub.name,
                    subtitle: '${sub.billingCycle} commitment$viaText',
                    amount: '$sym${formatCoveAmount(sub.amount)}',
                    isLast: i == commitmentsDue.length - 1,
                    onTap: () => CommitmentDetailSheet.show(context, sub),
                  );
                },
              ),
          ],
        ),
      );
    }

    // Find next date after selectedDateOnly that has commitment renewals
    DateTime? nextRenewalDate;
    List<CalendarSubscriptionEntry> nextRenewalSubs = const [];
    final maxDays = windowEnd.difference(selectedDateOnly).inDays;
    for (var d = 1; d <= maxDays; d++) {
      final candidate = selectedDateOnly.add(Duration(days: d));
      final candidateSubs = (entriesMap[candidate] ?? const [])
          .whereType<CalendarSubscriptionEntry>()
          .toList();
      if (candidateSubs.isNotEmpty) {
        nextRenewalDate = candidate;
        nextRenewalSubs = candidateSubs;
        break;
      }
    }

    final Widget summaryText;
    if (nextRenewalDate != null && nextRenewalSubs.isNotEmpty) {
      final firstSub = nextRenewalSubs.first.subscription;
      final extraCount = nextRenewalSubs.length - 1;
      final totalAmount = nextRenewalSubs.fold<double>(
        0.0,
        (sum, s) => sum + s.amount,
      );
      final sym = ActivityFormatter.getCurrencySymbol(
        firstSub.currency,
        fallbackSymbol: defaultSymbol,
      );
      final dateStr = DateFormat('MMM d').format(nextRenewalDate);

      summaryText = Text.rich(
        TextSpan(
          style: CoveType.rowSub.copyWith(color: cv.textSecondary),
          children: [
            const TextSpan(text: 'Nothing due today. Next: '),
            TextSpan(
              text: firstSub.name,
              style: CoveType.rowSub.copyWith(color: cv.accentTint),
            ),
            if (extraCount > 0) TextSpan(text: ' and $extraCount more'),
            const TextSpan(text: ' on '),
            TextSpan(
              text: dateStr,
              style: CoveType.rowSub.copyWith(color: cv.textPrimary),
            ),
            TextSpan(text: ', $sym${formatCoveAmount(totalAmount)} in all.'),
          ],
        ),
      );
    } else {
      summaryText = Text(
        'Nothing due today. No upcoming commitments scheduled.',
        style: CoveType.rowSub.copyWith(color: cv.textSecondary),
      );
    }

    return Container(
      padding: const EdgeInsets.all(CoveSpace.md),
      decoration: CoveShape.decoration(
        CoveRadius.card,
        color: cv.surfaceCard,
        side: BorderSide(
          color: cv.lineStrong,
          width: _kHairline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: CoveSize.avatarRow,
            height: CoveSize.avatarRow,
            decoration: CoveShape.decoration(
              CoveRadius.inline,
              color: cv.surfaceRow,
              side: BorderSide(
                color: cv.lineHairline,
                width: _kHairline,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.autorenew_rounded,
              size: _kRenewalIconSize,
              color: cv.accentTint,
            ),
          ),
          const SizedBox(width: CoveSpace.md),
          Expanded(child: summaryText),
        ],
      ),
    );
  }
}
