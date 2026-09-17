import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/cove_theme.dart';
import '../theme/theme_provider.dart';
import '../../features/activity/activity_read_status_controller.dart';
import '../../features/activity/activity_screen.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/habits/habits_screen.dart';
import '../../features/home/about_cove_screen.dart';
import '../../features/home/home_switcher_sheet.dart';
import '../../features/profile/partner_profile_controller.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/user_profile_controller.dart';
import '../../features/routines/routine_screen.dart';
import '../../features/today/today_screen.dart';
import '../../features/weather/weather_controller.dart';
import '../../sync/crypto/deterministic_home_icon.dart';
import '../../sync/providers/active_home_provider.dart';
import 'cove_sync_tick.dart';

class CoveWebSidebar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onSelectIndex;

  const CoveWebSidebar({
    super.key,
    required this.currentIndex,
    required this.onSelectIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final profile = ref.watch(userProfileProvider);
    final user = ref.watch(authProvider).value;
    final partner = ref.watch(partnerProfileProvider);
    final activeHome = ref.watch(activeHomeProvider).value;
    final userHomes = ref.watch(userHomesProvider).value ?? [];
    final unreadCount = ref.watch(unreadActivityCountProvider);
    final themeMode = ref.watch(themeModeProvider);
    final weather = ref.watch(weatherProvider);

    final effectiveName = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : (user?.displayName?.trim().isNotEmpty == true
            ? user!.displayName!.trim()
            : 'You');

    final initialLetter = effectiveName.isNotEmpty
        ? effectiveName.substring(0, 1).toUpperCase()
        : 'U';

    final partnerName = partner.displayName.trim().isNotEmpty
        ? partner.displayName.trim()
        : 'Partner';

    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        border: Border(
          right: BorderSide(color: colors.borderHairline, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. BRAND HEADER & WORKSPACE SWITCHER
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 16, top: 24, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'C',
                        style: TextStyle(
                          fontFamily: 'CormorantGaramond',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: colors.accentPrimary,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cove',
                          style: typography.headline.copyWith(
                            fontSize: 22,
                            letterSpacing: -0.3,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          'SHARED HOME OS',
                          style: typography.caption.copyWith(
                            fontSize: 9,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w700,
                            color: colors.accentPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Workspace / Active Home Pill
                InkWell(
                  onTap: () {
                    if (userHomes.length > 1) {
                      HomeSwitcherSheet.show(context);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutCoveScreen()),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.surfaceRow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.borderHairline),
                    ),
                    child: Row(
                      children: [
                        if (activeHome != null)
                          DeterministicHomeIcon(homeId: activeHome.id, size: 20)
                        else
                          Icon(Icons.home_outlined, size: 20, color: colors.accentPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeHome?.name ?? 'Household',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.bodyRegular.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'With $partnerName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.caption.copyWith(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (userHomes.length > 1)
                          Icon(
                            Icons.unfold_more_rounded,
                            size: 16,
                            color: colors.textMuted,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // 2. NAVIGATION ITEMS
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: [
                _buildNavItem(
                  context,
                  index: 0,
                  label: 'Dashboard',
                  icon: currentIndex == 0
                      ? Icons.dashboard_rounded
                      : Icons.dashboard_outlined,
                  colors: colors,
                  typography: typography,
                ),
                _buildNavItem(
                  context,
                  index: 1,
                  label: 'Commitments',
                  icon: Icons.autorenew_rounded,
                  colors: colors,
                  typography: typography,
                ),
                _buildNavItem(
                  context,
                  index: 2,
                  label: 'Calendar',
                  icon: currentIndex == 2
                      ? Icons.calendar_today_rounded
                      : Icons.calendar_today_outlined,
                  colors: colors,
                  typography: typography,
                ),
                _buildNavItem(
                  context,
                  index: 3,
                  label: 'Lists',
                  icon: currentIndex == 3
                      ? Icons.checklist_rounded
                      : Icons.checklist_rtl_rounded,
                  colors: colors,
                  typography: typography,
                ),
                _buildNavItem(
                  context,
                  index: 4,
                  label: 'Expenses',
                  icon: currentIndex == 4
                      ? Icons.receipt_long_rounded
                      : Icons.receipt_long_outlined,
                  colors: colors,
                  typography: typography,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'MODULES',
                    style: typography.caption.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: colors.textMuted,
                    ),
                  ),
                ),
                _buildActionItem(
                  context,
                  label: 'Habits Tracker',
                  icon: Icons.spa_outlined,
                  colors: colors,
                  typography: typography,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HabitsScreen()),
                    );
                  },
                ),
                _buildActionItem(
                  context,
                  label: 'Today Focus',
                  icon: Icons.wb_sunny_outlined,
                  colors: colors,
                  typography: typography,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const TodayScreen()),
                    );
                  },
                ),
                _buildActionItem(
                  context,
                  label: 'Daily Routines',
                  icon: Icons.schedule_outlined,
                  colors: colors,
                  typography: typography,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RoutineScreen()),
                    );
                  },
                ),
                _buildActionItem(
                  context,
                  label: 'Activity & Alerts',
                  icon: Icons.notifications_none_rounded,
                  colors: colors,
                  typography: typography,
                  badgeCount: unreadCount,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ActivityScreen()),
                    );
                  },
                ),
              ],
            ),
          ),

          // 3. FOOTER INFO & USER CARD
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: colors.borderHairline, width: 1),
              ),
              color: colors.surfaceRow.withValues(alpha: 0.5),
            ),
            child: Column(
              children: [
                // Sync & Weather status row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CoveSyncTick(
                          size: 13,
                          status: CoveSyncStatus.syncedToPartner,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Cloud Synced',
                          style: typography.caption.copyWith(
                            fontSize: 11,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    if (weather != null)
                      Text(
                        '${weather.temperatureC.round()}° ${weather.condition}',
                        style: typography.caption.copyWith(
                          fontSize: 11,
                          color: colors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // User profile card
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: (profile.avatarUrl != null &&
                                  profile.avatarUrl!.isNotEmpty)
                              ? colors.surfaceRow
                              : colors.accentPrimary,
                          backgroundImage: (profile.avatarUrl != null &&
                                  profile.avatarUrl!.isNotEmpty)
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          child: (profile.avatarUrl != null &&
                                  profile.avatarUrl!.isNotEmpty)
                              ? null
                              : Text(
                                  initialLetter,
                                  style: typography.headline.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: colors.surfaceRow,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                effectiveName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.bodyRegular.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Settings & profile',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.caption.copyWith(
                                  fontSize: 11,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            themeMode == ThemeMode.dark
                                ? Icons.wb_sunny_outlined
                                : Icons.nightlight_round_outlined,
                            size: 18,
                            color: colors.textMuted,
                          ),
                          tooltip: 'Toggle theme',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          splashRadius: 16,
                          onPressed: () {
                            ref.read(themeModeProvider.notifier).toggleTheme();
                          },
                        ),
                      ],
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

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
    required CoveColors colors,
    required CoveTypography typography,
  }) {
    final isSelected = currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelectIndex(index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.accentPrimary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: colors.accentPrimary.withValues(alpha: 0.3),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? colors.accentPrimary : colors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: typography.bodyRegular.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? colors.textPrimary : colors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required String label,
    required IconData icon,
    required CoveColors colors,
    required CoveTypography typography,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.textMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: typography.bodyRegular.copyWith(
                      fontWeight: FontWeight.w500,
                      color: colors.textMuted,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.accentSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
