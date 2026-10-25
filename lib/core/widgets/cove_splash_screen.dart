import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';
import 'cove_brand_mark.dart';

/// Serene, editorial launch splash screen for Cove.
/// Features a breathing brand mark, staggered typography entrance,
/// and smooth cross-fade capability.
class CoveSplashScreen extends StatefulWidget {
  final String? message;
  final Duration? minDuration;
  final VoidCallback? onFinished;
  final bool showProgress;

  static const double _kAmbientGlowSize =
      220.0; // (literal) 220dp splash ambient radial glow diameter
  static const double _kBrandMarkSize =
      80.0; // (literal) 80dp splash brand mark size
  static const double _kBrandMarkStroke =
      1.8; // (literal) 1.8dp splash brand mark stroke
  static const double _kMarkToTitleGap =
      28.0; // (literal) 28dp mark-to-wordmark gap
  static const double _kTaglineToSpinnerGap =
      36.0; // (literal) 36dp tagline-to-spinner gap
  static const double _kSpinnerSize =
      18.0; // (literal) 18dp splash progress spinner diameter
  static const double _kSpinnerStroke =
      1.5; // (literal) 1.5dp splash progress spinner stroke

  const CoveSplashScreen({
    super.key,
    this.message,
    this.minDuration,
    this.onFinished,
    this.showProgress = false,
  });

  @override
  State<CoveSplashScreen> createState() => _CoveSplashScreenState();
}

class _CoveSplashScreenState extends State<CoveSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _breathingController;

  late final Animation<double> _markOpacity;
  late final Animation<double> _markScale;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _titleSlide;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _breathingScale;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _markOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _markScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.30, 0.70, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<double>(begin: CoveSpace.sm, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.30, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.50, 0.85, curve: Curves.easeOut),
      ),
    );

    _breathingScale = Tween<double>(begin: 1.0, end: 1.035).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOutSine,
      ),
    );

    _entranceController.forward().then((_) {
      if (mounted) {
        _breathingController.repeat(reverse: true);
      }
    });

    if (widget.minDuration != null && widget.onFinished != null) {
      Future.delayed(widget.minDuration!, () {
        if (mounted) {
          widget.onFinished!();
        }
      });
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: Stack(
        children: [
          // Subtle ambient radial glow behind brand mark
          Center(
            child: Container(
              width: CoveSplashScreen._kAmbientGlowSize,
              height: CoveSplashScreen._kAmbientGlowSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    cv.accentFill.withValues(alpha: 0.08),
                    cv.accentFill.withValues(alpha: 0.02),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                _entranceController,
                _breathingController,
              ]),
              builder: (context, child) {
                final combinedScale = _markScale.value *
                    (_entranceController.isCompleted
                        ? _breathingScale.value
                        : 1.0);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Breathing Cove Brand Mark
                    Opacity(
                      opacity: _markOpacity.value,
                      child: Transform.scale(
                        scale: combinedScale,
                        child: const CoveBrandMark(
                          size: CoveSplashScreen._kBrandMarkSize,
                          strokeWidth: CoveSplashScreen._kBrandMarkStroke,
                        ),
                      ),
                    ),
                    const SizedBox(height: CoveSplashScreen._kMarkToTitleGap),

                    // "Cove" Title in Libre Bodoni
                    Opacity(
                      opacity: _titleOpacity.value,
                      child: Transform.translate(
                        offset: Offset(0, _titleSlide.value),
                        child: Text(
                          'Cove',
                          style: CoveType.greeting.copyWith(
                            fontWeight: FontWeight.w500,
                            color: cv.textPrimary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: CoveSpace.sm),

                    // Tagline or Status Message
                    Opacity(
                      opacity: _subtitleOpacity.value,
                      child: Text(
                        widget.message ?? 'A quiet operating system for two',
                        style: CoveType.readout.copyWith(
                          color: cv.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),

                    if (widget.showProgress) ...[
                      const SizedBox(
                        height: CoveSplashScreen._kTaglineToSpinnerGap,
                      ),
                      SizedBox(
                        width: CoveSplashScreen._kSpinnerSize,
                        height: CoveSplashScreen._kSpinnerSize,
                        child: CircularProgressIndicator(
                          strokeWidth: CoveSplashScreen._kSpinnerStroke,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            cv.accentFill,
                          ),
                          backgroundColor: cv.lineHairline,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
