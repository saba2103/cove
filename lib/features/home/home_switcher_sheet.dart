import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../sync/crypto/deterministic_home_icon.dart';
import '../../sync/providers/active_home_provider.dart';
import 'create_home_screen.dart';
import 'join_home_screen.dart';

/// Lightweight modal sheet displaying joined Homes.
/// Only triggered when user belongs to more than 1 Home.
class HomeSwitcherSheet extends ConsumerWidget {
  const HomeSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const HomeSwitcherSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final homesAsync = ref.watch(userHomesProvider);
    final activeHomeId = ref.watch(activeHomeIdProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: colors.borderHairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Switch Home',
                  style: typography.title.copyWith(fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Homes List
            homesAsync.when(
              data: (homes) {
                return Column(
                  children: homes.map((home) {
                    final isActive = home.id == activeHomeId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          ref
                              .read(activeHomeIdProvider.notifier)
                              .setActiveHome(home.id);
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isActive ? colors.surfaceRow : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isActive
                                  ? colors.accentPrimary.withValues(alpha: 0.4)
                                  : colors.borderHairline,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              DeterministicHomeIcon(homeId: home.id, size: 36),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      home.name,
                                      style: typography.bodyMedium.copyWith(
                                        fontWeight: isActive
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    if (home.description != null &&
                                        home.description!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        home.description!,
                                        style: typography.caption,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isActive)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: colors.accentPrimary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 16),
            Divider(color: colors.borderHairline, height: 1),
            const SizedBox(height: 16),

            // Add/Join another home actions
            Row(
              children: [
                Expanded(
                  child: CovePillButton(
                    label: 'Create Home',
                    isCompact: true,
                    variant: CoveButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateHomeScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CovePillButton(
                    label: 'Join Home',
                    isCompact: true,
                    variant: CoveButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const JoinHomeScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// AppBar title widget that conditionally displays the Home switcher affordance
/// ONLY when the user belongs to more than one Home.
class HomeSwitcherAppBarTitle extends ConsumerWidget {
  final VoidCallback? onSettingsTap;

  const HomeSwitcherAppBarTitle({
    super.key,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final homes = ref.watch(userHomesProvider).value ?? [];
    final activeHome = ref.watch(activeHomeProvider).value;
    final title = activeHome?.name ?? 'Cove';

    // STRICT RULE: If the user belongs to 0 or 1 Home, show plain title only!
    // No dropdown arrow, no empty affordance, no "1 of 1" indicator.
    if (homes.length <= 1) {
      return Text(
        title,
        style: typography.headline.copyWith(fontSize: 20),
      );
    }

    // When user belongs to more than 1 Home, show interactive switcher trigger
    return InkWell(
      onTap: () => HomeSwitcherSheet.show(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeHome != null) ...[
              DeterministicHomeIcon(homeId: activeHome.id, size: 22),
              const SizedBox(width: 8),
            ],
            Text(
              title,
              style: typography.headline.copyWith(fontSize: 20),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: colors.accentPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
