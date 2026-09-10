import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/cove_colors.dart';
import '../../core/widgets/cove_pill_button.dart';
import 'auth_controller.dart';

/// Exact implementation of the approved "Sign in" mockup artboard.
/// Rendered exclusively in the Dark theme palette (#0B1F1E).
class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

    // Strict dark tokens per mockup specification
    const bgDark = Color(0xFF0B1F1E);
    const accentChampagne = Color(0xFFD8B98C);
    const textPrimary = Color(0xFFF3ECE2);
    const textMuted = Color(0x8CF3ECE2); // ~55%
    const textSubtle = Color(0x66F3ECE2); // ~40%

    return Scaffold(
      backgroundColor: bgDark,
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
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: CustomPaint(
                          painter: _BrandMarkPainter(
                            strokeColor: accentChampagne,
                            fillColor: accentChampagne.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Wordmark: Bodoni Moda 500
                      Text(
                        'Cove',
                        style: GoogleFonts.bodoniModa(
                          fontSize: 42,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                          letterSpacing: -0.6,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Minimal Tagline
                      const Text(
                        'A private, shared home operating system.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'GeneralSans',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: textMuted,
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
                        icon: const Icon(
                          Icons.login,
                          size: 18,
                          color: Color(0xFF0B1F1E),
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
                            color: CoveColors.dark.accentSecondary,
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
                  children: const [
                    Icon(
                      Icons.lock_outline,
                      size: 13,
                      color: textSubtle,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'End-to-end encrypted on-device. Zero cloud knowledge.',
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: textSubtle,
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

class _BrandMarkPainter extends CustomPainter {
  final Color strokeColor;
  final Color fillColor;

  const _BrandMarkPainter({
    required this.strokeColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final radius = size.width * 0.32;
    final centerY = size.height / 2;
    final centerLeft = Offset(size.width * 0.38, centerY);
    final centerRight = Offset(size.width * 0.62, centerY);

    // Left circle
    canvas.drawCircle(centerLeft, radius, fillPaint);
    canvas.drawCircle(centerLeft, radius, strokePaint);

    // Right circle
    canvas.drawCircle(centerRight, radius, fillPaint);
    canvas.drawCircle(centerRight, radius, strokePaint);
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => false;
}
