import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_carousel.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../core/widgets/cove_metric_card.dart';
import '../../core/widgets/cove_round_button.dart';
import '../../core/widgets/cove_section_label.dart';
import '../../core/widgets/slips/cove_habit_card.dart';
import '../../core/widgets/slips/cove_note.dart';
import '../../core/widgets/slips/cove_receipt.dart';
import '../../core/widgets/slips/cove_slip.dart';
import '../../core/widgets/slips/cove_ticket.dart';
import '../../core/widgets/slips/cove_voucher.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../activity/activity_read_status_controller.dart';
import '../activity/activity_screen.dart';
import '../auth/auth_controller.dart';
import '../calendar/calendar_event_form_sheet.dart';
import '../calendar/calendar_screen.dart';
import '../expenses/expense_form_sheet.dart';
import '../expenses/expenses_screen.dart';
import '../habits/habit_controller.dart';
import '../habits/habit_form_sheet.dart';
import '../habits/habits_screen.dart';
import '../home/home_settings_screen.dart';
import '../home/home_switcher_sheet.dart';
import '../lists/list_controller.dart';
import '../lists/lists_screen.dart';
import '../profile/preferences_controller.dart';
import '../profile/profile_screen.dart';
import '../subscriptions/subscription_form_sheet.dart';
import '../subscriptions/subscriptions_screen.dart';
import '../weather/weather_controller.dart';
import '../weather/weather_model.dart';
import '../weather/widgets/weather_detail_sheet.dart';
import 'letter/letter.dart';
import 'today_controller.dart';
import 'today_models.dart';

class TodayScreen extends ConsumerStatefulWidget {
  final DateTime? initialNow;

  const TodayScreen({super.key, this.initialNow});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final homeId = ref.read(activeHomeIdProvider);
          ref
              .read(appDatabaseProvider)
              .purgeOrphanedAndArchivedListItems(homeId);
        } catch (_) {}
      }
    });
  }

  Future<void> _handleRefresh() async {
    final homeId = ref.read(activeHomeIdProvider);
    final futures = <Future<dynamic>>[
      ref.read(syncEngineProvider).pullLatestEvents(homeId: homeId),
      ref.read(weatherProvider.notifier).refreshWeather(),
    ];
    try {
      futures.add(
        ref.read(appDatabaseProvider).purgeOrphanedAndArchivedListItems(homeId),
      );
    } catch (_) {}
    await Future.wait(futures);
  }

  String _getGreetingPrefix(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<bool>? _resolveHabitHistory21({
    required String habitId,
    required DateTime now,
    required List<LocalHabitCheckin> allCheckins,
  }) {
    final habitCheckins = allCheckins
        .where((c) => c.habitId == habitId)
        .toList();
    if (habitCheckins.isEmpty) {
      return null;
    }
    final checkedDates = habitCheckins.map((c) => c.checkinDate).toSet();
    final fmt = DateFormat('yyyy-MM-dd');
    return List<bool>.generate(CoveHabitCard.kTotalCells, (index) {
      final daysAgo = (CoveHabitCard.kTotalCells - 1) - index;
      final date = DateTime(now.year, now.month, now.day - daysAgo);
      return checkedDates.contains(fmt.format(date));
    });
  }

  void _handleLetterTargetTap(BuildContext context, LetterTarget target) {
    switch (target.kind) {
      case LetterTargetKind.calendarSection:
      case LetterTargetKind.event:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CalendarScreen()),
        );
      case LetterTargetKind.habitsSection:
      case LetterTargetKind.habit:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HabitsScreen()),
        );
      case LetterTargetKind.expensesSection:
      case LetterTargetKind.expense:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ExpensesScreen()),
        );
      case LetterTargetKind.commitmentsSection:
      case LetterTargetKind.commitment:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
        );
      case LetterTargetKind.listsSection:
      case LetterTargetKind.list:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ListsScreen()),
        );
      case LetterTargetKind.person:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const HomeSettingsScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final slipVariant = Theme.of(context).brightness == Brightness.dark
        ? CoveSlipVariant.ink
        : CoveSlipVariant.paper;

    final currency = ref.watch(currencyPreferenceProvider);
    final todayData = ref.watch(todayDataProvider);
    final activeHome = ref.watch(activeHomeProvider).value;
    final currentUser = ref.watch(authProvider).value;
    final currentUserId = currentUser?.id ?? '';
    final weather = ref.watch(weatherProvider);
    final unreadCount = ref.watch(unreadActivityCountProvider);
    final allCheckins =
        ref.watch(activeHomeAllHabitCheckinsProvider).value ??
        const <LocalHabitCheckin>[];
    final allListItems =
        ref.watch(activeHomeAllListItemsProvider).value ??
        const <LocalListItem>[];
    final allSubscriptions =
        ref.watch(activeHomeSubscriptionsProvider).value ??
        const <LocalSubscription>[];

    final now = widget.initialNow ?? DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final tomorrowDate = DateTime(now.year, now.month, now.day + 1);

    final isCreator =
        activeHome == null ||
        activeHome.createdBy.isEmpty ||
        currentUserId.isEmpty ||
        activeHome.createdBy == currentUserId;
    final viewerPerson = isCreator ? CovePerson.a : CovePerson.b;
    final partnerPerson = isCreator ? CovePerson.b : CovePerson.a;

    final name = todayData.userName.isNotEmpty ? todayData.userName : 'there';
    final greetingPrefix = _getGreetingPrefix(now.hour);
    final dateLabel = DateFormat('EEEE, d MMMM').format(now);
    final cityReadout = weather?.cityName.trim().isNotEmpty == true
        ? weather!.cityName.trim().toUpperCase()
        : null;

    final completedHabits = todayData.habits
        .where((h) => h.userCheckedInToday)
        .length;
    final totalHabits = todayData.habits.length;
    final waitingHabits = totalHabits - completedHabits;

    // Filter active, visible commitments
    final activeCommitments =
        allSubscriptions
            .where(
              (s) =>
                  s.isActive && (!s.isPrivate || s.createdBy == currentUserId),
            )
            .toList()
          ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));

    final dueSoonCommitments = activeCommitments
        .where(
          (s) =>
              _isSameDay(s.nextBillingDate, todayDate) ||
              _isSameDay(s.nextBillingDate, tomorrowDate),
        )
        .toList();
    final displayedCommitments = dueSoonCommitments.isNotEmpty
        ? dueSoonCommitments
        : activeCommitments;

    // Count tasks ticked today for the Letter and metric tile
    final tickedTodayCount = allListItems
        .where(
          (i) =>
              i.isCompleted &&
              ((i.completedAt != null && _isSameDay(i.completedAt!, now)) ||
                  _isSameDay(i.createdAt, now)),
        )
        .length;
    final openTasksCount = todayData.focusTasks
        .where((t) => !t.isCompleted)
        .length;
    final totalListCount = openTasksCount + tickedTodayCount;

    // Calendar events (non-subscription events, or all today events)
    final calendarEvents = todayData.events;

    // Compose the Day Letter on every build over today's real data, home currency, and real commitment due dates.
    final isFirstRun =
        calendarEvents.isEmpty &&
        todayData.habits.isEmpty &&
        todayData.todayExpenses.isEmpty &&
        todayData.sharedMonthExpensesTotal <= 0 &&
        todayData.focusTasks.isEmpty &&
        todayData.listsSummary.every((l) => l.openCount == 0) &&
        activeCommitments.isEmpty;

    final letterInput = isFirstRun
        ? DayLetterInput.firstRun(
            clock: now,
            currencySymbol: currency.symbol,
            partnerName: todayData.hasPartner ? todayData.partnerName : null,
          )
        : DayLetterInput(
            clock: now,
            currencySymbol: currency.symbol,
            partnerName: todayData.hasPartner ? todayData.partnerName : null,
            events: calendarEvents
                .where((e) => !e.isSubscription)
                .map(
                  (e) => DayLetterEvent(
                    id: e.id,
                    title: e.title,
                    startTime: e.startTime,
                    isAllDay: e.isAllDay,
                  ),
                )
                .toList(),
            habits: todayData.habits
                .map(
                  (h) => DayLetterHabit(
                    id: h.habitId,
                    title: h.habitName,
                    doneByYou: h.userCheckedInToday,
                    doneByPartner: h.partnerCheckedInToday,
                    isShared: !h.isPrivate && todayData.hasPartner,
                  ),
                )
                .toList(),
            expenses: todayData.todayExpenses
                .map(
                  (e) => DayLetterExpense(
                    id: e.id,
                    title: e.title,
                    amount: e.amount,
                  ),
                )
                .toList(),
            tickedTaskCount: tickedTodayCount,
            commitmentsDue: activeCommitments
                .map(
                  (s) => DayLetterCommitment(
                    id: s.id,
                    title: s.name,
                    amount: s.amount,
                    dueDate: s.nextBillingDate,
                  ),
                )
                .toList(),
            openLists: todayData.listsSummary
                .map(
                  (l) => DayLetterList(
                    id: l.listId,
                    name: l.name,
                    openCount: l.openCount,
                  ),
                )
                .toList(),
          );
    final letterSpans = composeDayLetter(letterInput);

    final bottomPadding =
        CoveSpace.barClearance + MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: RefreshIndicator(
        color: cv.accentFill,
        backgroundColor: cv.surfaceCard,
        onRefresh: _handleRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: CoveSpace.md,
            bottom: bottomPadding,
          ),
          child: CoveMaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Screen-local Header (_TodayHeader)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: _TodayHeader(
                    homeName: activeHome?.name ?? 'Our Home',
                    viewerPerson: viewerPerson,
                    viewerName: name,
                    weather: weather,
                    unreadCount: unreadCount,
                  ),
                ),
                const SizedBox(height: CoveSpace.md),

                // 2. Date line — CoveSectionLabel.page with city readout
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: CoveSectionLabel.page(
                    label: dateLabel,
                    readout: cityReadout,
                  ),
                ),
                const SizedBox(height: CoveSpace.md),

                // 3. Greeting — CoveType.greeting: italic accent.tint, then name in roman text.primary
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greetingPrefix,',
                        style: CoveType.greeting.copyWith(
                          fontStyle: FontStyle.italic,
                          color: cv.accentTint,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              style: CoveType.greeting.copyWith(
                                color: cv.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '.',
                            style: CoveType.greeting.copyWith(
                              color: cv.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CoveSpace.lg),

                // 4. CoveMetricGrid — spent today, events, habits, the list
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: CoveMetricGrid(
                    children: [
                      CoveMetricCard(
                        label: 'Spent today',
                        value: formatCoveCurrency(
                          todayData.todaySpendTotal,
                          currency.symbol,
                        ),
                        subtitle:
                            '${formatCoveCurrency(todayData.sharedMonthExpensesTotal, currency.symbol)} this month',
                        valueTone: CoveMetricValueTone.accentTint,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ExpensesScreen(),
                            ),
                          );
                        },
                      ),
                      CoveMetricCard(
                        label: 'Events',
                        value: '${calendarEvents.length}',
                        subtitle: _buildEventsMetricSubtitle(calendarEvents),
                        valueTone: CoveMetricValueTone.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CalendarScreen(),
                            ),
                          );
                        },
                      ),
                      CoveMetricCard(
                        label: 'Habits',
                        value: '$completedHabits/$totalHabits',
                        subtitle: totalHabits == 0
                            ? 'none scheduled'
                            : (waitingHabits == 0
                                  ? 'all done today'
                                  : '${formatLetterNumber(waitingHabits)} still waiting'),
                        valueTone: CoveMetricValueTone.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const HabitsScreen(),
                            ),
                          );
                        },
                      ),
                      CoveMetricCard(
                        label: 'The list',
                        value: '$tickedTodayCount/$totalListCount',
                        subtitle: openTasksCount == 0
                            ? 'all clear'
                            : '$openTasksCount still open',
                        valueTone: CoveMetricValueTone.primary,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ListsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CoveSpace.section),

                // 5. On the calendar — CoveTicket, carousel when more than one
                _buildCalendarSection(
                  context,
                  events: calendarEvents,
                  slipVariant: slipVariant,
                  hasPartner: todayData.hasPartner,
                  now: now,
                ),
                const SizedBox(height: CoveSpace.section),

                // 6. Habits — CoveHabitCard in a CoveCarousel
                _buildHabitsSection(
                  context,
                  habits: todayData.habits,
                  completedHabits: completedHabits,
                  totalHabits: totalHabits,
                  hasPartner: todayData.hasPartner,
                  partnerName: todayData.partnerName,
                  slipVariant: slipVariant,
                  now: now,
                  allCheckins: allCheckins,
                ),
                const SizedBox(height: CoveSpace.section),

                // 7. Spent today — one CoveReceipt holding the day's purchases, with the split bar
                _buildSpentTodaySection(
                  context,
                  expenses: todayData.todayExpenses,
                  totalSpend: todayData.todaySpendTotal,
                  currencySymbol: currency.symbol,
                  viewerPerson: viewerPerson,
                  partnerPerson: partnerPerson,
                  viewerName: name,
                  partnerName: todayData.partnerName,
                  hasPartner: todayData.hasPartner,
                  slipVariant: slipVariant,
                  now: now,
                ),
                const SizedBox(height: CoveSpace.section),

                // 8. The list — one CoveNote with the open items
                _buildListSection(
                  context,
                  tasks: todayData.focusTasks,
                  listsSummary: todayData.listsSummary,
                  currentUserId: currentUserId,
                  partnerName: todayData.partnerName,
                  slipVariant: slipVariant,
                ),
                const SizedBox(height: CoveSpace.section),

                // 9. Due tomorrow — CoveVouchers in a CoveCarousel
                _buildDueTomorrowSection(
                  context,
                  commitments: displayedCommitments,
                  currencySymbol: currency.symbol,
                  slipVariant: slipVariant,
                ),
                const SizedBox(height: CoveSpace.section),

                // 10. The Letter — CoveLetter over composeDayLetter()
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: CoveLetter(
                    key: const ValueKey('today_day_letter'),
                    spans: letterSpans,
                    onTapTarget: (target) =>
                        _handleLetterTargetTap(context, target),
                  ),
                ),
                const SizedBox(height: CoveSpace.xl),

                // 11. Footer — "Two lives. One calm home." italic, then the encryption line
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: _buildFooter(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildEventsMetricSubtitle(List<TodayEventItem> events) {
    if (events.isEmpty) {
      return 'Nothing today';
    }
    final first = events.first;
    if (first.isAllDay) {
      return first.title;
    }
    final hour12 = first.startTime.hour % 12 == 0
        ? 12
        : first.startTime.hour % 12;
    if (first.startTime.minute == 0) {
      return '${first.title} at ${formatLetterNumber(hour12)}';
    }
    final minStr = first.startTime.minute.toString().padLeft(2, '0');
    return '${first.title} at $hour12:$minStr';
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String label,
    required String readout,
    required String addSemanticLabel,
    required VoidCallback onOpenSection,
    required VoidCallback onAdd,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onOpenSection,
              child: CoveSectionLabel.page(
                label: label,
                readout: readout,
              ),
            ),
          ),
          const SizedBox(width: CoveSpace.sm),
          CoveRoundButton(
            icon: Icons.add,
            variant: CoveRoundButtonVariant.ghost,
            semanticLabel: addSemanticLabel,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection(
    BuildContext context, {
    required List<TodayEventItem> events,
    required CoveSlipVariant slipVariant,
    required bool hasPartner,
    required DateTime now,
  }) {
    final readout = events.isEmpty
        ? 'none today'
        : '${formatLetterNumber(events.length)} today';

    void openCalendar() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CalendarScreen()),
      );
    }

    final tickets = events.isEmpty
        ? <Widget>[
            CoveTicket(
              variant: slipVariant,
              title: 'Nothing on the calendar',
              date: DateFormat('EEEE, MMM d').format(now),
              owner: hasPartner ? 'Both of you' : 'You',
              hour: '—',
              meridiem: 'OPEN',
              onTap: openCalendar,
            ),
          ]
        : events.map((ev) {
            final datePart = DateFormat('EEEE, MMM d').format(ev.startTime);
            final String? locationStr =
                (ev.location != null && ev.location!.trim().isNotEmpty)
                ? ev.location!.trim()
                : (ev.subtitle != null && ev.subtitle!.contains('·')
                      ? ev.subtitle!.split('·').last.trim()
                      : null);
            final subtitlePart =
                (locationStr != null && locationStr.isNotEmpty)
                ? '$datePart · $locationStr'
                : datePart;
            final hour12 = ev.startTime.hour % 12 == 0
                ? 12
                : ev.startTime.hour % 12;
            final hourStr = ev.isAllDay
                ? 'ALL'
                : (ev.startTime.minute == 0
                      ? '$hour12'
                      : DateFormat('h:mm').format(ev.startTime));
            final meridiemStr = ev.isAllDay
                ? 'DAY'
                : DateFormat('a').format(ev.startTime).toUpperCase();

            return CoveTicket(
              key: ValueKey('today_ticket_${ev.id}'),
              variant: slipVariant,
              title: ev.title,
              date: subtitlePart,
              owner: hasPartner ? 'Both of you' : 'You',
              hour: hourStr,
              meridiem: meridiemStr,
              onTap: openCalendar,
            );
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          context: context,
          label: 'On the calendar',
          readout: readout,
          addSemanticLabel: 'Add event',
          onOpenSection: openCalendar,
          onAdd: () => CalendarEventFormSheet.show(context, initialDate: now),
        ),
        const SizedBox(height: CoveSpace.sm),
        CoveCarousel(children: tickets),
      ],
    );
  }

  Widget _buildHabitsSection(
    BuildContext context, {
    required List<TodayHabitItem> habits,
    required int completedHabits,
    required int totalHabits,
    required bool hasPartner,
    required String partnerName,
    required CoveSlipVariant slipVariant,
    required DateTime now,
    required List<LocalHabitCheckin> allCheckins,
  }) {
    final readout = totalHabits == 0
        ? 'none'
        : '$completedHabits of $totalHabits';

    void openHabits() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const HabitsScreen()),
      );
    }

    final cards = habits.isEmpty
        ? <Widget>[
            CoveHabitCard(
              variant: slipVariant,
              title: 'Start a daily habit',
              cadence: hasPartner ? 'every day · both of you' : 'every day · you',
              isDoneToday: false,
              daysRunning: 0,
              onTap: openHabits,
            ),
          ]
        : habits.map((h) {
            final cadenceBase = h.habit.cadence == 'weekly'
                ? '${h.habit.targetDaysPerWeek.abs()}x a week'
                : 'every day';
            final whoPart = (!h.isPrivate && hasPartner)
                ? (h.partnerCheckedInToday
                      ? 'both of you · $partnerName checked in'
                      : 'both of you')
                : 'you';
            final history21 = _resolveHabitHistory21(
              habitId: h.habitId,
              now: now,
              allCheckins: allCheckins,
            );

            return CoveHabitCard(
              key: ValueKey('today_habit_${h.habitId}'),
              variant: slipVariant,
              title: h.habitName,
              cadence: '$cadenceBase · $whoPart',
              isDoneToday: h.userCheckedInToday,
              daysRunning: h.streak,
              history21: history21,
              onToggle: (_) async {
                final controller = ref.read(habitControllerProvider);
                await controller.toggleCheckin(
                  habit: h.habit,
                  checked: !h.userCheckedInToday,
                );
              },
              onTap: openHabits,
            );
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          context: context,
          label: 'Habits',
          readout: readout,
          addSemanticLabel: 'Add habit',
          onOpenSection: openHabits,
          onAdd: () => HabitFormSheet.show(context),
        ),
        const SizedBox(height: CoveSpace.sm),
        CoveCarousel(children: cards),
      ],
    );
  }

  Widget _buildSpentTodaySection(
    BuildContext context, {
    required List<TodayExpenseItem> expenses,
    required double totalSpend,
    required String currencySymbol,
    required CovePerson viewerPerson,
    required CovePerson partnerPerson,
    required String viewerName,
    required String partnerName,
    required bool hasPartner,
    required CoveSlipVariant slipVariant,
    required DateTime now,
  }) {
    final count = expenses.length;
    final readout = count == 0
        ? 'none today'
        : '$count ${count == 1 ? 'purchase' : 'purchases'}';

    void openExpenses() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ExpensesScreen()),
      );
    }

    final viewerSpent = expenses
        .where((e) => e.isCurrentUser)
        .fold<double>(0.0, (sum, e) => sum + e.amount);
    final partnerSpent = expenses
        .where((e) => !e.isCurrentUser)
        .fold<double>(0.0, (sum, e) => sum + e.amount);
    final splitTotal = viewerSpent + partnerSpent;
    final viewerShare = splitTotal > 0 ? (viewerSpent / splitTotal) : 1.0;

    final receiptItems = expenses.map((exp) {
      final methodPart =
          (exp.paymentMethod != null && exp.paymentMethod!.trim().isNotEmpty)
          ? ' · ${exp.paymentMethod!.toUpperCase()}'
          : '';
      return CoveReceiptItem(
        payer: exp.isCurrentUser ? viewerPerson : partnerPerson,
        nameOrInitial: exp.isCurrentUser ? viewerName : partnerName,
        title: exp.title,
        subtitle: '${exp.category}$methodPart',
        amount: formatCoveCurrency(exp.amount, currencySymbol),
        onTap: openExpenses,
      );
    }).toList();

    final split = hasPartner
        ? CoveReceiptSplit(
            viewerName: 'You',
            viewerAmount: formatCoveCurrency(viewerSpent, currencySymbol),
            partnerName: partnerName,
            partnerAmount: formatCoveCurrency(partnerSpent, currencySymbol),
            viewerShare: viewerShare,
          )
        : null;

    final recordSeed = expenses.isNotEmpty
        ? expenses.map((e) => e.id).join('-')
        : DateFormat('yyyy-MM-dd').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          context: context,
          label: 'Spent today',
          readout: readout,
          addSemanticLabel: 'Add expense',
          onOpenSection: openExpenses,
          onAdd: () => ExpenseFormSheet.show(context),
        ),
        const SizedBox(height: CoveSpace.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
          child: CoveReceipt(
            key: const ValueKey('today_receipt'),
            variant: slipVariant,
            recordId: recordSeed,
            title: DateFormat('EEEE').format(now),
            items: receiptItems,
            totalAmount: formatCoveCurrency(totalSpend, currencySymbol),
            split: split,
            footerDate: DateFormat('EEEE, MMM d').format(now).toUpperCase(),
            onTap: openExpenses,
          ),
        ),
      ],
    );
  }

  Widget _buildListSection(
    BuildContext context, {
    required List<TodayListItem> tasks,
    required List<TodayListSummary> listsSummary,
    required String currentUserId,
    required String partnerName,
    required CoveSlipVariant slipVariant,
  }) {
    final openCount = tasks.where((t) => !t.isCompleted).length;
    final readout = openCount == 0 ? 'all clear' : '$openCount open';

    void openLists() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ListsScreen()),
      );
    }

    final primaryListName = tasks.isNotEmpty
        ? tasks.first.listName
        : (listsSummary.isNotEmpty ? listsSummary.first.name : 'Grocery');
    final upperListName = primaryListName.trim().toUpperCase();
    final capsLabel = upperListName.endsWith('LIST')
        ? 'COVE · $upperListName'
        : 'COVE · $upperListName LIST';

    final noteItems = tasks.isEmpty
        ? <CoveNoteItem>[
            CoveNoteItem(
              title: 'Nothing open on $primaryListName',
              addedBy: 'tap to open lists',
              isDone: false,
              onTap: openLists,
            ),
          ]
        : tasks.map((task) {
            final addedBy =
                (currentUserId.isEmpty || task.item.createdBy == currentUserId)
                ? 'added by you'
                : 'added by $partnerName';
            return CoveNoteItem(
              title: task.title,
              addedBy: addedBy,
              isDone: task.isCompleted,
              onChanged: (checked) async {
                final controller = ref.read(listControllerProvider);
                await controller.toggleItem(
                  itemId: task.id,
                  isCompleted: checked,
                  itemTitle: task.title,
                  listName: task.listName,
                );
              },
              onTap: openLists,
            );
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          context: context,
          label: 'The list',
          readout: readout,
          addSemanticLabel: 'Add list item',
          onOpenSection: openLists,
          onAdd: openLists,
        ),
        const SizedBox(height: CoveSpace.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
          child: CoveNote(
            key: const ValueKey('today_note'),
            variant: slipVariant,
            capsLabel: capsLabel,
            items: noteItems,
            onTap: openLists,
          ),
        ),
      ],
    );
  }

  Widget _buildDueTomorrowSection(
    BuildContext context, {
    required List<LocalSubscription> commitments,
    required String currencySymbol,
    required CoveSlipVariant slipVariant,
  }) {
    final totalDue = commitments.fold<double>(0.0, (sum, c) => sum + c.amount);
    final readout = commitments.isEmpty
        ? 'none due'
        : '${commitments.length} · ${formatCoveCurrency(totalDue, currencySymbol)}';

    void openCommitments() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SubscriptionsScreen()),
      );
    }

    final vouchers = commitments.isEmpty
        ? <Widget>[
            CoveVoucher(
              variant: slipVariant,
              title: 'No commitments due',
              amount: formatCoveCurrency(0, currencySymbol),
              dueDay: '—',
              dueMonth: '—',
              state: CoveVoucherState.paid,
              onTap: openCommitments,
            ),
          ]
        : commitments.map((sub) {
            final isYearly = sub.billingCycle.toLowerCase() == 'yearly';
            return CoveVoucher(
              key: ValueKey('today_voucher_${sub.id}'),
              variant: slipVariant,
              title: sub.name,
              amount: formatCoveCurrency(sub.amount, currencySymbol),
              dueDay: '${sub.nextBillingDate.day}',
              dueMonth: DateFormat('MMM')
                  .format(sub.nextBillingDate)
                  .toUpperCase(),
              dueMonthSemantic: DateFormat('MMMM').format(sub.nextBillingDate),
              capsLabel: isYearly ? 'COVE · EVERY YEAR' : 'COVE · EVERY MONTH',
              cadenceSuffix: isYearly ? 'a year' : 'a month',
              state: CoveVoucherState.due,
              totalInstallments: sub.totalInstallments,
              paidInstallments: sub.paidInstallments ?? 0,
              onTap: openCommitments,
            );
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(
          context: context,
          label: 'Due tomorrow',
          readout: readout,
          addSemanticLabel: 'Add commitment',
          onOpenSection: openCommitments,
          onAdd: () => SubscriptionFormSheet.show(context),
        ),
        const SizedBox(height: CoveSpace.sm),
        CoveCarousel(children: vouchers),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final cv = context.cv;

    return Column(
      children: [
        Text(
          'Two lives.\nOne calm home.',
          style: CoveType.slipTitle.copyWith(
            fontStyle: FontStyle.italic,
            color: cv.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: CoveSpace.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: CoveSpace.md,
              color: cv.textTertiary,
            ),
            const SizedBox(width: CoveSpace.xs),
            Flexible(
              child: Text(
                'Encrypted on your phones, never on ours',
                style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Screen-local header for [TodayScreen] (`design/screens/today.md`).
///
/// Composed strictly of existing primitives:
/// - Home name with chevron (opens [HomeSwitcherSheet] or [HomeSettingsScreen])
/// - Weather chip restyled with tokens
/// - Ghost [CoveRoundButton] for the notification bell with an `8dp` `(literal)`
///   `accent.fill` unread dot
/// - [CoveAvatar.header] for the viewer (never [CovePerson.both])
class _TodayHeader extends ConsumerWidget {
  final String homeName;
  final CovePerson viewerPerson;
  final String viewerName;
  final WeatherData? weather;
  final int unreadCount;

  static const double _kUnreadDotSize =
      8.0; // (literal) 8dp accent.fill unread dot
  static const double _kWeatherIconSize = 16.0;
  static const double _kChevronIconSize = 18.0;

  const _TodayHeader({
    required this.homeName,
    required this.viewerPerson,
    required this.viewerName,
    required this.weather,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
    final homes = ref.watch(userHomesProvider).value ?? const <LocalHome>[];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Home: $homeName',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (homes.length > 1) {
                  HomeSwitcherSheet.show(context);
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HomeSettingsScreen(),
                    ),
                  );
                }
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: CoveSize.hit),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          homeName,
                          style: CoveType.slipTitle.copyWith(
                            color: cv.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: CoveSpace.xs),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: _kChevronIconSize,
                        color: cv.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (weather != null) ...[
          _buildWeatherChip(context, weather!),
          const SizedBox(width: CoveSpace.xs),
        ],
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            CoveRoundButton(
              icon: Icons.notifications_none_rounded,
              variant: CoveRoundButtonVariant.ghost,
              semanticLabel: 'Notifications',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActivityScreen()),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                top: CoveSpace.md,
                right: CoveSpace.md,
                child: IgnorePointer(
                  child: Container(
                    width: _kUnreadDotSize,
                    height: _kUnreadDotSize,
                    decoration: BoxDecoration(
                      color: cv.accentFill,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: CoveSpace.xs),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          },
          child: SizedBox(
            width: CoveSize.hit,
            height: CoveSize.hit,
            child: Center(
              child: CoveAvatar.header(
                person: viewerPerson,
                nameOrInitial: viewerName,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherChip(BuildContext context, WeatherData data) {
    final cv = context.cv;
    final (iconData, _) = WeatherData.getWeatherIconAndCondition(
      data.weatherCode,
      data.isDay,
    );

    return Semantics(
      button: true,
      label: 'Weather: ${data.temperatureC.round()} degrees in ${data.cityName}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => WeatherDetailSheet.show(context, data),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CoveSize.hit),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  iconData,
                  size: _kWeatherIconSize,
                  color: cv.textSecondary,
                ),
                const SizedBox(width: CoveSpace.xs),
                Text(
                  '${data.temperatureC.round()}°',
                  style: CoveType.readout.copyWith(color: cv.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
