import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_checkbox.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../activity/activity_screen.dart';
import '../calendar/calendar_event_form_sheet.dart';
import '../calendar/calendar_screen.dart';
import '../expenses/expense_form_sheet.dart';
import '../expenses/expenses_screen.dart';
import '../habits/habit_controller.dart';
import '../habits/habit_form_sheet.dart';
import '../habits/habits_screen.dart';
import '../lists/list_controller.dart';
import '../lists/lists_screen.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../weather/weather_controller.dart';
import '../weather/widgets/dashboard_weather_badge.dart';
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
          ref.read(appDatabaseProvider).purgeOrphanedAndArchivedListItems(homeId);
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
      futures.add(ref.read(appDatabaseProvider).purgeOrphanedAndArchivedListItems(homeId));
    } catch (_) {}
    await Future.wait(futures);
  }

  String _getGreetingPrefix(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.watch(currencyPreferenceProvider);
    final todayData = ref.watch(todayDataProvider);

    final now = widget.initialNow ?? DateTime.now();
    final todayFormatted = DateFormat('EEEE, MMMM d').format(now).toUpperCase();
    final greetingPrefix = _getGreetingPrefix(now.hour);
    final name = todayData.userName.isNotEmpty ? todayData.userName : 'there';

    final completedHabits = todayData.habits.where((h) => h.userCheckedInToday).length;
    final totalHabits = todayData.habits.length;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.wb_sunny_rounded, size: 20, color: colors.accentPrimary),
            const SizedBox(width: 8),
            Text(
              'Today',
              style: typography.headline.copyWith(fontSize: 20),
            ),
          ],
        ),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: DashboardWeatherBadge(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: colors.accentPrimary,
        backgroundColor: colors.surfaceCard,
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // --- 1. AMBIENT MORNING HERO ---
            _buildAmbientHero(
              context,
              todayFormatted: todayFormatted,
              greetingPrefix: greetingPrefix,
              name: name,
              quote: todayData.morningQuote,
            ),
            const SizedBox(height: 20),

            // --- 2. AT-A-GLANCE PULSE CARDS ---
            _buildPulseStrip(
              context,
              eventsCount: todayData.eventsOnlyCount,
              completedHabits: completedHabits,
              totalHabits: totalHabits,
              openTasksCount: todayData.focusTasks.length,
              spendTotal: todayData.todaySpendTotal,
              currencySymbol: currency.symbol,
            ),
            const SizedBox(height: 28),

            // --- 3. TODAY'S FLOW (Timeline & Commitments) ---
            _buildFlowSection(context, todayData.events),
            const SizedBox(height: 28),

            // --- 4. RHYTHMS OF US ---
            _buildHabitsSection(context, todayData.habits, completedHabits, totalHabits),
            const SizedBox(height: 28),

            // --- 5. FOCUS TASKS ---
            _buildTasksSection(context, todayData.focusTasks),
            const SizedBox(height: 20),

            // --- 6. SHARED LISTS PILL ROW ---
            _buildSharedListsSection(context, todayData.listsSummary),
            const SizedBox(height: 28),

            // --- 7. TODAY'S SPEND & EXPENSES ---
            _buildSpendSection(
              context,
              todayData.todayExpenses,
              todayData.todaySpendTotal,
              todayData.sharedMonthExpensesTotal,
              currency.symbol,
            ),
            const SizedBox(height: 28),

            // --- 8. RECENT ACTIVITY ---
            _buildRecentActivitySection(context),
            const SizedBox(height: 48),

            // --- 9. SERENE FOOTER ---
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAmbientHero(
    BuildContext context, {
    required String todayFormatted,
    required String greetingPrefix,
    required String name,
    required String quote,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accentPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                todayFormatted,
                style: typography.caption.copyWith(
                  letterSpacing: 1.0,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$greetingPrefix,',
            style: TextStyle(
              fontFamily: 'LibreBodoni',
              fontSize: 26,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              color: colors.textPrimary,
              height: 1.15,
            ),
          ),
          Text(
            name,
            style: typography.headline.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceRow.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.spa_outlined, size: 16, color: colors.accentPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    quote,
                    style: TextStyle(
                      fontFamily: 'LibreBodoni',
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseStrip(
    BuildContext context, {
    required int eventsCount,
    required int completedHabits,
    required int totalHabits,
    required int openTasksCount,
    required double spendTotal,
    required String currencySymbol,
  }) {
    final colors = context.colors;

    return Row(
      children: [
        Expanded(
          child: _buildPulseCard(
            context,
            icon: Icons.event_note_outlined,
            title: 'Events',
            value: eventsCount > 0 ? '$eventsCount' : '0',
            subtitle: eventsCount == 1 ? 'event' : 'events',
            color: colors.accentPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildPulseCard(
            context,
            icon: Icons.repeat_rounded,
            title: 'Habits',
            value: totalHabits > 0 ? '$completedHabits/$totalHabits' : '0',
            subtitle: completedHabits == totalHabits && totalHabits > 0 ? 'done ✨' : 'rhythms',
            color: colors.accentPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildPulseCard(
            context,
            icon: Icons.checklist_rounded,
            title: 'Tasks',
            value: '$openTasksCount',
            subtitle: openTasksCount == 1 ? 'task' : 'tasks',
            color: colors.accentPrimary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildPulseCard(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Spent',
            value: '$currencySymbol${formatCoveIntegerAmount(spendTotal)}',
            subtitle: 'today',
            color: colors.accentTint,
          ),
        ),
      ],
    );
  }

  Widget _buildPulseCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: typography.caption.copyWith(
                  fontSize: 9,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: colors.textSubtle,
                ),
              ),
              Icon(icon, size: 12, color: colors.textSubtle),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'LibreBodoni',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: typography.caption.copyWith(
              fontSize: 10,
              color: colors.textMuted,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFlowSection(BuildContext context, List<TodayEventItem> events) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('TODAY\'S FLOW', style: typography.caption),
            GestureDetector(
              onTap: () => CalendarEventFormSheet.show(context, initialDate: DateTime.now()),
              child: Text(
                '+ Add Event',
                style: typography.caption.copyWith(
                  color: colors.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          CoveCard(
            padding: const EdgeInsets.all(18),
            onTap: () => CalendarEventFormSheet.show(context, initialDate: DateTime.now()),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surfaceRow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.wb_twilight_rounded, size: 20, color: colors.accentPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A calm, unhurried day ahead',
                        style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No events or renewals scheduled for today.',
                        style: typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: events.map((ev) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CoveCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CalendarScreen()),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: colors.surfaceRow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: colors.borderHairline),
                        ),
                        child: Text(
                          ev.isAllDay ? 'ALL DAY' : DateFormat('h:mm a').format(ev.startTime),
                          style: typography.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.accentPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ev.title,
                              style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                            if (ev.subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                ev.subtitle!,
                                style: typography.caption.copyWith(color: colors.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: colors.textSubtle),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildHabitsSection(
    BuildContext context,
    List<TodayHabitItem> habits,
    int completed,
    int total,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final partnerName = ref.watch(partnerProfileProvider).displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('DAILY RHYTHMS', style: typography.caption),
                if (total > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: colors.surfaceRow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$completed/$total',
                      style: typography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.accentPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HabitsScreen()),
                );
              },
              child: Text(
                'Habits →',
                style: typography.caption.copyWith(color: colors.accentPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (habits.isEmpty)
          CoveCard(
            padding: const EdgeInsets.all(18),
            onTap: () => HabitFormSheet.show(context),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, size: 24, color: colors.accentPrimary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set your daily shared rhythm',
                        style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to add morning routines, fitness, or reading together.',
                        style: typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: habits.map((h) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CoveCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // 1-Tap Interactive Checkin Button
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Icon(
                          h.userCheckedInToday
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 24,
                          color: h.userCheckedInToday ? colors.accentPrimary : colors.textSubtle,
                        ),
                        onPressed: () async {
                          final controller = ref.read(habitControllerProvider);
                          await controller.toggleCheckin(
                            habit: h.habit,
                            checked: !h.userCheckedInToday,
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.habitName,
                              style: typography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                decoration: h.userCheckedInToday
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: h.userCheckedInToday
                                    ? colors.textMuted
                                    : colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (h.streak > 0) ...[
                                  Text(
                                    '${h.streak}d streak 🔥',
                                    style: typography.caption.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colors.accentSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (h.partnerCheckedInToday)
                                  Text(
                                    '$partnerName checked in ✓',
                                    style: typography.caption.copyWith(
                                      fontSize: 11,
                                      color: colors.accentPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildTasksSection(BuildContext context, List<TodayListItem> tasks) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('FOCUS TASKS', style: typography.caption),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ListsScreen()),
                );
              },
              child: Text(
                'Lists →',
                style: typography.caption.copyWith(color: colors.accentPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          CoveCard(
            padding: const EdgeInsets.all(18),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ListsScreen()),
              );
            },
            child: Row(
              children: [
                Icon(Icons.done_all_rounded, size: 22, color: colors.accentPrimary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All lists are clear!',
                        style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'No uncompleted items in your shared lists right now.',
                        style: typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: tasks.map((task) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CoveCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CoveCheckbox(
                        value: task.isCompleted,
                        onChanged: (checked) async {
                          final controller = ref.read(listControllerProvider);
                          await controller.toggleItem(
                            itemId: task.id,
                            isCompleted: checked,
                            itemTitle: task.title,
                            listName: task.listName,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.title,
                              style: typography.bodyMedium.copyWith(
                                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                color: task.isCompleted ? colors.textMuted : colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              task.listName,
                              style: typography.caption.copyWith(
                                fontSize: 11,
                                color: colors.textSubtle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSharedListsSection(BuildContext context, List<TodayListSummary> summaries) {
    final colors = context.colors;
    final typography = context.typography;

    if (summaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('SHARED LISTS', style: typography.caption),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ListsScreen()),
                );
              },
              child: Text(
                'All lists →',
                style: typography.caption.copyWith(color: colors.accentPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: summaries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              final s = summaries[idx];
              return InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ListsScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(19),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: colors.surfaceCard,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: colors.borderHairline),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.name,
                        style: typography.bodyMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: s.openCount > 0
                              ? colors.accentPrimary.withValues(alpha: 0.15)
                              : colors.surfaceRow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${s.openCount}',
                          style: TextStyle(
                            fontFamily: 'LibreBodoni',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: s.openCount > 0 ? colors.accentPrimary : colors.textSubtle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpendSection(
    BuildContext context,
    List<TodayExpenseItem> expenses,
    double totalSpend,
    double sharedMonthSpendTotal,
    String currencySymbol,
  ) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('TODAY\'S SPEND', style: typography.caption),
            GestureDetector(
              onTap: () => ExpenseFormSheet.show(context),
              child: Text(
                '+ Log Expense',
                style: typography.caption.copyWith(
                  color: colors.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        CoveCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL SPENT TODAY',
                    style: typography.caption.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                      );
                    },
                    child: Text(
                      'Ledger →',
                      style: typography.caption.copyWith(color: colors.accentPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$currencySymbol${formatCoveAmount(totalSpend)}',
                style: typography.largeNumber.copyWith(
                  fontSize: 32,
                  color: colors.accentTint,
                ),
              ),
              if (expenses.isEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'No expenses logged yet today.',
                  style: typography.caption.copyWith(color: colors.textMuted),
                ),
              ] else ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                ...expenses.take(3).map((exp) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exp.title, style: typography.bodyMedium),
                              Text(
                                '${exp.category}${exp.paymentMethod != null ? " • ${exp.paymentMethod!.toUpperCase()}" : ""} · ${exp.payerName}',
                                style: typography.caption.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$currencySymbol${formatCoveAmount(exp.amount)}',
                          style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 14),
              // Shared this month total in Bodoni Moda
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surfaceRow.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.borderHairline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SHARED THIS MONTH',
                          style: typography.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: colors.textSubtle,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$currencySymbol${formatCoveAmount(sharedMonthSpendTotal)}',
                          style: const TextStyle(
                            fontFamily: 'LibreBodoni',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    CovePillButton(
                      label: 'Ledger →',
                      variant: CoveButtonVariant.secondary,
                      isCompact: true,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final recentActivityAsync = ref.watch(todayRecentActivityProvider);
    final items = recentActivityAsync.value ?? [];

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RECENT ACTIVITY', style: typography.caption),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActivityScreen()),
                );
              },
              child: Text(
                'All →',
                style: typography.caption.copyWith(color: colors.accentPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        CoveCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: items.take(3).map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.accentPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, size: 15, color: colors.accentPrimary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.actionText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.bodyMedium.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.timeAgo,
                            style: typography.caption.copyWith(
                              fontSize: 11,
                              color: colors.textSubtle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CoveSyncTick(status: item.syncStatus),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Text(
            'Two lives.\nOne calm rhythm.',
            style: TextStyle(
              fontFamily: 'LibreBodoni',
              fontSize: 24,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              height: 1.25,
              color: colors.textMuted.withValues(alpha: 0.35),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 12, color: colors.textSubtle.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'End-to-end encrypted on-device · Zero cloud knowledge',
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 11,
                    color: colors.textSubtle.withValues(alpha: 0.6),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
