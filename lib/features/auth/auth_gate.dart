import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/cove_splash_screen.dart';
import '../../sync/providers/active_home_provider.dart';
import '../app_shell.dart';
import '../home/onboarding_choice_screen.dart';
import 'auth_controller.dart';
import 'sign_in_screen.dart';

/// The routing nervous system of Cove.
/// Coordinates transitions across:
/// 1. Unauthenticated -> SignInScreen
/// 2. Authenticated but has no Home -> OnboardingChoiceScreen
/// 3. Authenticated with Home(s) -> AppShell
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    final content = authState.when(
      data: (user) {
        if (user == null) {
          return const SignInScreen(key: ValueKey('sign_in'));
        }

        final homesAsync = ref.watch(userHomesProvider);

        return homesAsync.when(
          data: (homes) {
            if (homes.isEmpty) {
              return const OnboardingChoiceScreen(key: ValueKey('onboarding'));
            }

            // Ensure an active home is selected if not already
            final activeHomeId = ref.watch(activeHomeIdProvider);
            if (activeHomeId == null || !homes.any((h) => h.id == activeHomeId)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref
                    .read(activeHomeIdProvider.notifier)
                    .setActiveHome(homes.first.id);
              });
            }

            return const AppShell(key: ValueKey('app_shell'));
          },
          loading: () => const CoveSplashScreen(
            key: ValueKey('splash_homes'),
            message: 'Opening your home...',
            showProgress: true,
          ),
          error: (e, st) => const OnboardingChoiceScreen(key: ValueKey('onboarding_error')),
        );
      },
      loading: () => const CoveSplashScreen(key: ValueKey('splash_auth')),
      error: (e, st) => const SignInScreen(key: ValueKey('sign_in_error')),
    );

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: content,
    );
  }
}
