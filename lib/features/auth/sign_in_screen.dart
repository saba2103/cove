import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_brand_mark.dart';
import '../../core/widgets/cove_pill_button.dart';
import 'auth_controller.dart';

/// Serene sign in screen adhering to DESIGN_SYSTEM.md in both light and dark themes.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: 12),

              // Central Brand Area
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand Mark: Two Overlapping Circles Motif
                      const CoveBrandMark(size: 54),
                      const SizedBox(height: 20),

                      // Wordmark: Bodoni Moda 500
                      Text(
                        'Cove',
                        style: typography.displayLarge.copyWith(
                          fontSize: 42,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Minimal Tagline
                      Text(
                        'A private, shared home operating system.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'GeneralSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: colors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Single Action: Sign in with Google
                      CovePillButton(
                        label: 'Sign in with Google',
                        isLoading: isLoading,
                        onPressed: () {
                          ref.read(authProvider.notifier).signInWithGoogle();
                        },
                        icon: Icon(
                          Icons.login,
                          size: 18,
                          color: colors.surfaceCard,
                        ),
                        isFullWidth: true,
                      ),

                      if (authState.hasError) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Sign in failed. Please check connection.',
                          style: TextStyle(
                            fontFamily: 'GeneralSans',
                            fontSize: 13,
                            color: colors.accentSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer: Encryption Reassurance Line
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 13,
                      color: colors.textSubtle,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'End-to-end encrypted on-device. Zero cloud knowledge.',
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: colors.textSubtle,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
