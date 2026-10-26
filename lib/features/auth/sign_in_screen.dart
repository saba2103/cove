import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_brand_mark.dart';
import '../../core/widgets/cove_pill_button.dart';
import 'auth_controller.dart';

/// Serene sign in screen adhering to DESIGN_SYSTEM.md in both light and dark themes.
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  static const double _kHorizontalPadding =
      28.0; // (literal) 28dp sign-in page horizontal inset
  static const double _kMaxBrandWidth =
      380.0; // (literal) 380dp sign-in column max width
  static const double _kButtonIconSize =
      18.0; // (literal) 18dp sign-in button icon size
  static const double _kErrorTopGap =
      16.0; // (literal) 16dp error message top gap
  static const double _kLockIconSize =
      13.0; // (literal) 13dp footer lock icon size

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _kHorizontalPadding,
            vertical: CoveSpace.lg,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(height: CoveSpace.md),

              // Central Brand Area
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kMaxBrandWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Brand Mark: Two Overlapping Circles Motif
                      const CoveBrandMark(size: CoveSize.row),
                      const SizedBox(height: CoveSpace.gutter),

                      // Wordmark: Bodoni Moda 500
                      Text(
                        'Cove',
                        style: CoveType.heroFigure.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                      const SizedBox(height: CoveSpace.sm),

                      // Minimal Tagline
                      Text(
                        'A private, shared home operating system.',
                        textAlign: TextAlign.center,
                        style: CoveType.body.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                      const SizedBox(height: CoveSpace.xl),

                      // Single Action: Sign in with Google
                      CovePillButton(
                        label: 'Sign in with Google',
                        isLoading: isLoading,
                        onPressed: () {
                          ref.read(authProvider.notifier).signInWithGoogle();
                        },
                        icon: Icon(
                          Icons.login,
                          size: _kButtonIconSize,
                          color: cv.textOnAccent,
                        ),
                        isFullWidth: true,
                      ),

                      if (authState.hasError) ...[
                        const SizedBox(height: _kErrorTopGap),
                        Text(
                          'Sign in failed. Please check connection.',
                          style: CoveType.readout.copyWith(
                            color: cv.statusAlertText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer: Encryption Reassurance Line
              Padding(
                padding: const EdgeInsets.only(bottom: CoveSpace.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: _kLockIconSize,
                      color: cv.textTertiary,
                    ),
                    const SizedBox(width: CoveSpace.sm),
                    Flexible(
                      child: Text(
                        'End-to-end encrypted on-device. Zero cloud knowledge.',
                        textAlign: TextAlign.center,
                        style: CoveType.rowSub.copyWith(
                          color: cv.textTertiary,
                        ),
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
