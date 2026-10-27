import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../sync/crypto/deterministic_home_icon.dart';
import '../../sync/providers/active_home_provider.dart';
import 'about_cove_screen.dart';
import 'create_home_screen.dart';
import 'join_home_screen.dart';

/// Lightweight modal sheet displaying joined Homes.
/// Only triggered when user belongs to more than 1 Home.
class HomeSwitcherSheet extends ConsumerWidget {
  const HomeSwitcherSheet({super.key});

  static const double _kBorderWidth =
      1.0; // (literal) 1dp hairline border
  static const double _kItemPaddingH =
      16.0; // (literal) 16dp home row horizontal inset
  static const double _kHomeIconSize =
      36.0; // (literal) 36dp home switcher icon size

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
    final cv = context.cv;
    final homesAsync = ref.watch(userHomesProvider);
    final activeHomeId = ref.watch(activeHomeIdProvider);

    return Container(
      decoration: CoveShape.topDecoration(
        CoveRadius.sheet,
        color: cv.surfaceSheet,
        side: BorderSide(color: cv.lineHairline, width: _kBorderWidth),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: CoveSpace.gutter,
        vertical: CoveSpace.lg,
      ),
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
                  style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: CoveSpace.gutter,
                    color: cv.textSecondary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.md),

            // Homes List
            homesAsync.when(
              data: (homes) {
                return Column(
                  children: homes.map((home) {
                    final isActive = home.id == activeHomeId;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: CoveSpace.sm),
                      child: InkWell(
                        onTap: () {
                          ref
                              .read(activeHomeIdProvider.notifier)
                              .setActiveHome(home.id);
                          Navigator.of(context).pop();
                        },
                        customBorder: CoveShape.border(CoveRadius.inline),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _kItemPaddingH,
                            vertical: CoveSpace.md,
                          ),
                          decoration: CoveShape.decoration(
                            CoveRadius.inline,
                            color: isActive
                                ? cv.surfaceRow
                                : Colors.transparent,
                            side: BorderSide(
                              color: isActive
                                  ? cv.accentFill.withValues(alpha: 0.4)
                                  : cv.lineHairline,
                              width: _kBorderWidth,
                            ),
                          ),
                          child: Row(
                            children: [
                              DeterministicHomeIcon(
                                homeId: home.id,
                                size: _kHomeIconSize,
                              ),
                              const SizedBox(width: CoveSpace.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      home.name,
                                      style: CoveType.rowTitle.copyWith(
                                        color: cv.textPrimary,
                                        fontWeight: isActive
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    if (home.description != null &&
                                        home.description!.isNotEmpty) ...[
                                      const SizedBox(height: CoveSpace.xs),
                                      Text(
                                        home.description!,
                                        style: CoveType.rowSub.copyWith(
                                          color: cv.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isActive)
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: CoveSpace.gutter,
                                  color: cv.accentFill,
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
                  padding: EdgeInsets.all(_kItemPaddingH),
                  child: CoveLoading(size: CoveSpace.gutter),
                ),
              ),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),

            const SizedBox(height: _kItemPaddingH),
            Divider(color: cv.lineHairline, height: _kBorderWidth),
            const SizedBox(height: _kItemPaddingH),

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
                const SizedBox(width: CoveSpace.sm),
                Expanded(
                  child: CovePillButton(
                    label: 'Join Home',
                    isCompact: true,
                    variant: CoveButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const JoinHomeScreen(
                            initialShowManualInput: kIsWeb,
                          ),
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

  static const double _kChevronSize =
      18.0; // (literal) 18dp appbar switcher chevron size

  const HomeSwitcherAppBarTitle({
    super.key,
    this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
    final homes = ref.watch(userHomesProvider).value ?? [];
    final activeHome = ref.watch(activeHomeProvider).value;
    final title = activeHome?.name ?? 'Cove';
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AboutCoveScreen()),
        );
      },
      customBorder: CoveShape.border(CoveSpace.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.sm,
          vertical: CoveSpace.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeHome != null && homes.length > 1) ...[
              DeterministicHomeIcon(
                homeId: activeHome.id,
                size: CoveSize.avatarInline,
              ),
              const SizedBox(width: CoveSpace.sm),
            ],
            Text(
              title,
              style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
            ),
            if (homes.length > 1) ...[
              const SizedBox(width: CoveSpace.xs),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => HomeSwitcherSheet.show(context),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: _kChevronSize,
                  color: cv.accentFill,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
