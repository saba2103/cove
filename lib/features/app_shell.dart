import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/cove_theme.dart';
import '../core/theme/theme_provider.dart';
import '../core/widgets/cove_bottom_nav.dart';
import '../core/widgets/cove_grouped_list.dart';
import 'activity/activity_screen.dart';
import 'calendar/calendar_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'expenses/expenses_screen.dart';
import 'habits/habits_screen.dart';
import 'home/home_switcher_sheet.dart';
import 'lists/lists_screen.dart';
import 'profile/profile_screen.dart';
import 'subscriptions/subscriptions_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const HomeSwitcherAppBarTitle(),
        actions: [
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              size: 20,
              color: colors.textPrimary,
            ),
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            tooltip: 'Profile & Settings',
            icon: Icon(
              Icons.person_outline,
              size: 20,
              color: colors.textPrimary,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: CoveBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: _buildCurrentTab(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const SubscriptionsScreen();
      case 2:
        return const ListsScreen();
      case 3:
        return const ExpensesScreen();
      case 4:
        return const _MoreMenuTab();
      default:
        return const DashboardScreen();
    }
  }
}

class _MoreMenuTab extends ConsumerWidget {
  const _MoreMenuTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        Text('MORE HOUSEHOLD AREAS', style: typography.caption),
        const SizedBox(height: 10),
        CoveGroupedCard(
          children: [
            CoveGroupedRow(
              leading: Icon(Icons.repeat_outlined, size: 20, color: colors.accentPrimary),
              title: Text('Habits & Rhythms', style: typography.bodyMedium),
              subtitle: Text('Track daily shared momentum', style: typography.caption),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HabitsScreen()),
                );
              },
            ),
            CoveGroupedRow(
              leading: Icon(Icons.calendar_today_outlined, size: 20, color: colors.accentPrimary),
              title: Text('Shared Calendar', style: typography.bodyMedium),
              subtitle: Text('Joint events, dinners & trips', style: typography.caption),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CalendarScreen()),
                );
              },
            ),
            CoveGroupedRow(
              leading: Icon(Icons.history_outlined, size: 20, color: colors.accentPrimary),
              title: Text('Activity Feed', style: typography.bodyMedium),
              subtitle: Text('Recent actions & receipts', style: typography.caption),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActivityScreen()),
                );
              },
            ),
            CoveGroupedRow(
              leading: Icon(Icons.settings_outlined, size: 20, color: colors.accentPrimary),
              title: Text('Profile & Preferences', style: typography.bodyMedium),
              subtitle: Text('Theme, Home details, Backup', style: typography.caption),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}
