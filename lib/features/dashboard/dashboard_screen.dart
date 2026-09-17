import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_actor_avatar.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/providers/active_home_provider.dart';
import '../activity/activity_detail_sheet.dart';
import '../activity/activity_models.dart';
import '../activity/activity_screen.dart';
import '../auth/auth_controller.dart';
import '../calendar/calendar_screen.dart';
import '../habits/habits_screen.dart';
import '../notifications/notification_controller.dart';
import '../notifications/notification_models.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../weather/weather_controller.dart';
import '../weather/widgets/dashboard_weather_badge.dart';
import 'dashboard_controller.dart';
import 'dashboard_models.dart';

class DashboardScreen extends ConsumerWidget {
  final DashboardData? initialData;
  final List<FormattedActivityItem>? initialRecentActivity;

  const DashboardScreen({
    super.key,
    this.initialData,
    this.initialRecentActivity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final profile = ref.watch(userProfileProvider);
    final user = ref.watch(authProvider).value;
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);

    final DashboardData dashboardData = initialData ?? ref.watch(dashboardDataProvider);
    final List<FormattedActivityItem> recentActivity;
    if (initialRecentActivity != null) {
      recentActivity = initialRecentActivity!;
    } else if (dashboardData.recentActivity.isNotEmpty) {
      recentActivity = dashboardData.recentActivity;
    } else {
      recentActivity = ref.watch(dashboardRecentActivityProvider).value ?? [];
    }

    final now = DateTime.now();
    final todayFormatted = DateFormat('EEEE, MMMM d').format(now).toUpperCase();
    final greetingPrefix = _getGreetingPrefix(now.hour);
    final effectiveName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : (user?.displayName?.trim().isNotEmpty == true
            ? user!.displayName!.trim()
            : '');
    final firstName = effectiveName.split(' ').firstOrNull ?? '';
    final greeting = firstName.isNotEmpty ? '$greetingPrefix, $firstName' : greetingPrefix;

    final isWide = kIsWeb && MediaQuery.sizeOf(context).width >= 960;

    return RefreshIndicator(
      color: colors.accentPrimary,
      backgroundColor: colors.surfaceCard,
      onRefresh: () async {
        final homeId = ref.read(activeHomeIdProvider);
        await Future.wait([
          ref.read(syncEngineProvider).pullLatestEvents(homeId: homeId),
          ref.read(weatherProvider.notifier).refreshWeather(),
        ]);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 36 : 20,
          vertical: isWide ? 32 : 20,
        ),
        children: [
          // --- 1. GREETING HEADER WITH WEATHER BADGE ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todayFormatted,
                      style: typography.caption.copyWith(
                        letterSpacing: 0.8,
                        fontSize: isWide ? 12 : 11,
                        color: colors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      greeting,
                      style: typography.headline.copyWith(
                        fontSize: isWide ? 32 : 26,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const DashboardWeatherBadge(),
            ],
          ),
          const SizedBox(height: 24),

          if (!hasPartner) ...[
            CoveCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.accentSecondary.withValues(alpha: 0.12),
                    ),
                    child: Icon(Icons.people_outline, size: 18, color: colors.accentSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Partner hasn't joined yet",
                          style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Items you add are saved securely and will sync when they join.',
                          style: typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (isWide) ...[
            // Dual-column desktop layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: Spend hero, lists, habits
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSharedExpensesCard(context, ref, dashboardData.sharedExpensesTotal),
                      const SizedBox(height: 28),
                      _buildListsPillRow(context, ref, dashboardData.listsSummary),
                      const SizedBox(height: 28),
                      _buildHabitsTodaySection(context, ref, dashboardData.habitsStatus),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                // Right column: Coming up events/commitments & recent activity
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildComingUpSection(context, ref, dashboardData.upcomingItems),
                      const SizedBox(height: 28),
                      _buildRecentActivitySection(context, ref, recentActivity),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            // Mobile single column layout
            _buildSharedExpensesCard(context, ref, dashboardData.sharedExpensesTotal),
            const SizedBox(height: 24),
            _buildComingUpSection(context, ref, dashboardData.upcomingItems),
            const SizedBox(height: 24),
            _buildListsPillRow(context, ref, dashboardData.listsSummary),
            const SizedBox(height: 24),
            _buildHabitsTodaySection(context, ref, dashboardData.habitsStatus),
            const SizedBox(height: 24),
            _buildRecentActivitySection(context, ref, recentActivity),
          ],

          const SizedBox(height: 16),
          _buildDashboardFooter(context),
        ],
      ),
    );
  }

  Widget _buildDashboardFooter(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: 52, bottom: 44),
      child: Column(
        children: [
          // Elegant luxury editorial quote in italics with generous spacing
          Text(
            'Your home, sorted together.',
            style: GoogleFonts.bodoniModa(
              fontSize: 26,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w400,
              height: 1.25,
              letterSpacing: -0.3,
              color: colors.textMuted.withValues(alpha: 0.45),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // End-to-end encrypted badge exactly like sign-in screen
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 12,
                color: colors.textSubtle.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'End-to-end encrypted on-device · Zero cloud knowledge',
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: colors.textSubtle.withValues(alpha: 0.6),
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGreetingPrefix(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  // --- SECTION BUILDERS ---

  Widget _buildSharedExpensesCard(BuildContext context, WidgetRef ref, double total) {
    final colors = context.colors;
    final typography = context.typography;
    final currency = ref.watch(currencyPreferenceProvider);
    final totalFormatted = formatCoveCurrency(total, currency.symbol, showDecimals: total % 1 != 0);

    return CoveCard(
      onTap: () {
        ref.read(notificationNavigationProvider.notifier).navigateTo(NotificationModule.expenses);
      },
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SHARED THIS MONTH', style: typography.caption),
              Icon(Icons.arrow_forward_ios, size: 12, color: colors.textSubtle),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            totalFormatted,
            style: typography.displayLarge.copyWith(
              fontSize: 34,
              color: colors.accentTint,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Split equally · tap to view ledger',
            style: typography.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildComingUpSection(
    BuildContext context,
    WidgetRef ref,
    List<DashboardUpcomingItem> items,
  ) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('COMING UP', style: typography.caption),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CalendarScreen()),
                  );
                },
                child: Text(
                  'Calendar →',
                  style: typography.caption.copyWith(color: colors.accentPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CoveGroupedCard(
          children: items.isEmpty
              ? [
                  CoveGroupedRow(
                    leading: Icon(Icons.event_available_outlined, size: 20, color: colors.textSubtle),
                    title: Text('Nothing scheduled', style: typography.bodyMedium),
                    subtitle: Text('Enjoy the calm rhythm ahead', style: typography.caption),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CalendarScreen()),
                      );
                    },
                  ),
                ]
              : items.map((item) {
                  return CoveGroupedRow(
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.surfaceRow,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: Text(
                        item.dateBadge,
                        style: typography.caption.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: colors.accentPrimary,
                        ),
                      ),
                    ),
                    title: Text(item.title, style: typography.bodyMedium),
                    subtitle: Text(
                      item.isSubscription && item.amountFormatted != null
                          ? '${item.amountFormatted} · ${item.subtitle}'
                          : item.subtitle,
                      style: typography.caption,
                    ),
                    trailing: Icon(Icons.chevron_right, size: 16, color: colors.textSubtle),
                    onTap: () {
                      if (item.isSubscription) {
                        ref.read(notificationNavigationProvider.notifier).navigateTo(NotificationModule.subscriptions);
                      } else {
                        ref.read(notificationNavigationProvider.notifier).navigateTo(NotificationModule.calendar);
                      }
                    },
                  );
                }).toList(),
        ),
      ],
    );
  }

  Widget _buildListsPillRow(
    BuildContext context,
    WidgetRef ref,
    List<DashboardListSummary> lists,
  ) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SHARED LISTS', style: typography.caption),
              GestureDetector(
                onTap: () {
                  ref.read(notificationNavigationProvider.notifier).navigateTo(NotificationModule.lists);
                },
                child: Text(
                  'View all →',
                  style: typography.caption.copyWith(color: colors.accentPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (lists.isEmpty)
          GestureDetector(
            onTap: () {
              ref.read(notificationNavigationProvider.notifier).navigateTo(NotificationModule.lists);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.borderHairline),
              ),
              child: Text(
                'No lists created yet · tap to open Lists',
                style: typography.caption.copyWith(color: colors.textMuted),
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: lists.map((list) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      ref.read(notificationNavigationProvider.notifier).navigateTo(NotificationModule.lists);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceCard,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: colors.borderHairline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_box_outlined, size: 16, color: colors.textPrimary),
                          const SizedBox(width: 8),
                          Text(list.name, style: typography.bodyMedium.copyWith(fontSize: 14)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.surfaceRow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${list.openCount}',
                              style: typography.caption.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: list.openCount > 0 ? colors.accentPrimary : colors.textSubtle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildHabitsTodaySection(
    BuildContext context,
    WidgetRef ref,
    List<DashboardHabitStatus> habits,
  ) {
    final colors = context.colors;
    final typography = context.typography;
    final partnerName = ref.watch(partnerProfileProvider).displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('HABITS TODAY', style: typography.caption),
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
        ),
        const SizedBox(height: 8),
        CoveGroupedCard(
          children: habits.isEmpty
              ? [
                  CoveGroupedRow(
                    leading: Icon(Icons.repeat_outlined, size: 20, color: colors.textSubtle),
                    title: Text('No active shared habits', style: typography.bodyMedium),
                    subtitle: Text('Tap to set your shared daily momentum', style: typography.caption),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HabitsScreen()),
                      );
                    },
                  ),
                ]
              : [
                  ...habits.map((habit) {
                    return CoveGroupedRow(
                      leading: Icon(Icons.repeat_outlined, size: 18, color: colors.textPrimary),
                      title: Text(habit.habitName, style: typography.bodyMedium),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHabitDot(
                            context: context,
                            label: 'You',
                            checked: habit.userCheckedInToday,
                          ),
                          const SizedBox(width: 14),
                          _buildHabitDot(
                            context: context,
                            label: partnerName,
                            checked: habit.partnerCheckedInToday,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HabitsScreen()),
                        );
                      },
                    );
                  }),
                ],
        ),
      ],
    );
  }

  Widget _buildHabitDot({
    required BuildContext context,
    required String label,
    required bool checked,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: typography.caption.copyWith(
            fontSize: 11,
            color: checked ? colors.textPrimary : colors.textSubtle,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: checked ? colors.accentPrimary : Colors.transparent,
            border: Border.all(
              color: checked ? colors.accentPrimary : colors.textSubtle,
              width: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivitySection(
    BuildContext context,
    WidgetRef ref,
    List<FormattedActivityItem> activities,
  ) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'RECENT ACTIVITY',
                  style: typography.caption,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActivityScreen()),
                  );
                },
                child: Text(
                  'View feed →',
                  style: typography.caption.copyWith(color: colors.accentPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        CoveGroupedCard(
          children: activities.isEmpty
              ? [
                  CoveGroupedRow(
                    leading: Icon(Icons.history_outlined, size: 20, color: colors.textSubtle),
                    title: Text('No activity yet', style: typography.bodyMedium),
                    subtitle: Text('Household events will appear here in real-time', style: typography.caption),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ActivityScreen()),
                      );
                    },
                  ),
                ]
              : activities.map((item) {
                  return CoveGroupedRow(
                    leading: CoveActorAvatar(
                      item: item,
                      size: 28,
                      showBadge: true,
                    ),
                    title: Text(
                      '${item.actorName} ${item.actionText}',
                      style: typography.bodyMedium.copyWith(fontSize: 13),
                    ),
                    subtitle: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.timeAgo, style: typography.caption.copyWith(fontSize: 11)),
                        if (item.isLocalActor) ...[
                          const SizedBox(width: 6),
                          CoveSyncTick(status: item.syncStatus, size: 12),
                        ],
                      ],
                    ),
                    trailing: Icon(Icons.chevron_right, size: 16, color: colors.textSubtle),
                    onTap: () => ActivityDetailDispatcher.openDetail(context, ref, item),
                  );
                }).toList(),
        ),
      ],
    );
  }
}
