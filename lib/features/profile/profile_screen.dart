import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_toggle_switch.dart';
import '../../sync/crypto/deterministic_home_icon.dart';
import '../../sync/providers/active_home_provider.dart';
import '../auth/auth_controller.dart';
import '../home/home_settings_screen.dart';
import '../home/home_switcher_sheet.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDark;
    final user = ref.watch(authProvider).value;
    final activeHome = ref.watch(activeHomeProvider).value;
    final homes = ref.watch(userHomesProvider).value ?? [];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Profile & Preferences', style: typography.headline.copyWith(fontSize: 20)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            // User Card
            CoveCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colors.surfaceRow,
                    child: Text(
                      user?.displayName?.isNotEmpty == true
                          ? user!.displayName![0].toUpperCase()
                          : 'U',
                      style: typography.title.copyWith(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.displayName ?? 'Partner', style: typography.title),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '', style: typography.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Preferences
            Text('PREFERENCES', style: typography.caption),
            const SizedBox(height: 8),
            CoveGroupedCard(
              children: [
                CoveGroupedRow(
                  leading: Icon(
                    isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                    size: 20,
                    color: colors.textPrimary,
                  ),
                  title: Text('Dark Theme', style: typography.bodyMedium),
                  subtitle: Text(
                    isDark ? 'Obsidian & champagne' : 'Linen & amber',
                    style: typography.caption,
                  ),
                  trailing: CoveToggleSwitch(
                    value: isDark,
                    onChanged: (val) {
                      ref.read(themeModeProvider.notifier).toggleTheme();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Household
            Text('HOUSEHOLD', style: typography.caption),
            const SizedBox(height: 8),
            CoveGroupedCard(
              children: [
                if (activeHome != null)
                  CoveGroupedRow(
                    leading: DeterministicHomeIcon(homeId: activeHome.id, size: 28),
                    title: Text(activeHome.name, style: typography.bodyMedium),
                    subtitle: Text('Home settings & partner pairing', style: typography.caption),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HomeSettingsScreen(),
                        ),
                      );
                    },
                  ),
                if (homes.length > 1)
                  CoveGroupedRow(
                    leading: Icon(Icons.swap_horiz_outlined, size: 20, color: colors.textPrimary),
                    title: Text('Switch Home', style: typography.bodyMedium),
                    subtitle: Text('${homes.length} homes connected', style: typography.caption),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () {
                      HomeSwitcherSheet.show(context);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 36),

            // Sign Out
            CovePillButton(
              label: 'Sign Out',
              variant: CoveButtonVariant.secondary,
              onPressed: () {
                ref.read(authProvider.notifier).signOut();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
