import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/shape/cove_shape.dart';
import '../../../core/theme/cove_tokens.dart';
import '../../../core/widgets/cove_pill_button.dart';
import 'changelog_models.dart';
import 'widgets/changelog_preview_mockup.dart';

class WhatsFreshModal extends StatefulWidget {
  final VoidCallback? onDismissed;

  const WhatsFreshModal({super.key, this.onDismissed});

  /// Automatically checks if the current version has already been viewed.
  /// If not, pops up the What's Fresh modal once.
  static Future<void> checkAndShow(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(kCoveLastSeenFreshVersionKey);
      if (lastSeen == kCoveCurrentAppVersion) return;

      if (!context.mounted) return;
      await show(context, force: false);
    } catch (_) {}
  }

  /// Explicitly displays the What's Fresh modal (e.g. from Changelog page button).
  static Future<void> show(BuildContext context, {bool force = false}) async {
    if (!force) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kCoveLastSeenFreshVersionKey,
        kCoveCurrentAppVersion,
      );
    }

    if (!context.mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'What\'s Fresh',
      barrierColor: context.cv.surfaceScrim,
      transitionDuration: CoveMotion.sheet,
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * anim1.value),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
      pageBuilder: (context, anim1, anim2) {
        return const WhatsFreshModal();
      },
    );
  }

  @override
  State<WhatsFreshModal> createState() => _WhatsFreshModalState();
}

class _WhatsFreshModalState extends State<WhatsFreshModal> {
  static const double _kWideBreakpoint =
      600.0; // (literal) 600dp responsive modal width breakpoint
  static const double _kWideMaxWidth =
      460.0; // (literal) 460dp modal card width on wide screens
  static const double _kBorderWidth =
      1.2; // (literal) 1.2dp modal outer card hairline border width
  static const double _kShadowOffsetY =
      16.0; // (literal) 16dp modal elevation shadow vertical offset
  static const double _kTopBarTopPadding =
      16.0; // (literal) 16dp top inset on modal badge bar
  static const double _kCloseIconSize =
      18.0; // (literal) 18dp modal close button icon and splash radius
  static const double _kChipRadius =
      6.0; // (literal) 6dp version/category chip corner radius
  static const double _kDotSize =
      6.0; // (literal) 6dp carousel pagination dot height and inactive width
  static const double _kButtonIconSize =
      15.0; // (literal) 15dp Next/Got it button trailing icon size

  late final PageController _pageController;
  late final List<ChangelogItem> _featuredItems;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _featuredItems = kChangelogItems.where((i) => i.isFeatured).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _featuredItems.length - 1) {
      _pageController.nextPage(
        duration: CoveMotion.s(context),
        curve: CoveMotion.easing,
      );
    } else {
      Navigator.of(context, rootNavigator: true).pop();
      widget.onDismissed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < _kWideBreakpoint;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: isCompact ? size.width * 0.92 : _kWideMaxWidth,
          constraints: BoxConstraints(maxHeight: size.height * 0.88),
          decoration: CoveShape.decoration(
            CoveRadius.hero,
            color: cv.surfaceCard,
            side: BorderSide(
              color: cv.lineHairline.withValues(alpha: 0.8),
              width: _kBorderWidth,
            ),
            shadows: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: CoveSpace.section,
                offset: const Offset(0, _kShadowOffsetY),
              ),
            ],
          ),
          child: CoveShape.clip(
            CoveRadius.hero,
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // -------------------------------------------------------------
                // TOP BAR: BADGE, STEP COUNTER, CLOSE BUTTON
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.only(
                    left: CoveSpace.gutter,
                    right: CoveSpace.md,
                    top: _kTopBarTopPadding,
                    bottom: CoveSpace.xs,
                  ),
                  child: Builder(
                    builder: (context) {
                      final isScaled =
                          MediaQuery.textScalerOf(context).scale(1.0) > 1.0;
                      final badge = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CoveSpace.sm,
                          vertical: CoveSpace.xs,
                        ),
                        decoration: CoveShape.decoration(
                          CoveRadius.pill,
                          color: cv.accentWash,
                          side: BorderSide(
                            color: cv.accentFill.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: CoveSpace.md,
                              color: cv.accentFill,
                            ),
                            const SizedBox(width: CoveSpace.xs),
                            Flexible(
                              child: Text(
                                "WHAT'S FRESH · v1.0",
                                overflow:
                                    isScaled ? null : TextOverflow.ellipsis,
                                style: CoveType.barLabel.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: cv.accentText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      final stepCounter = Text(
                        '${_currentPage + 1} of ${_featuredItems.length}',
                        style: CoveType.barLabel.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cv.textSecondary,
                        ),
                      );
                      final closeButton = IconButton(
                        onPressed: () =>
                            Navigator.of(context, rootNavigator: true).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          size: _kCloseIconSize,
                          color: cv.textSecondary,
                        ),
                        splashRadius: _kCloseIconSize,
                        tooltip: 'Close',
                      );

                      if (isScaled) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  top: CoveSpace.xs,
                                ),
                                child: Wrap(
                                  spacing: CoveSpace.sm,
                                  runSpacing: CoveSpace.xs,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    badge,
                                    stepCounter,
                                  ],
                                ),
                              ),
                            ),
                            closeButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Flexible(child: badge),
                          const SizedBox(width: CoveSpace.sm),
                          stepCounter,
                          const SizedBox(width: CoveSpace.xs),
                          closeButton,
                        ],
                      );
                    },
                  ),
                ),

                // -------------------------------------------------------------
                // ONBOARDING-STYLE CAROUSEL (PAGEVIEW)
                // -------------------------------------------------------------
                Flexible(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _featuredItems.length,
                    onPageChanged: (idx) => setState(() => _currentPage = idx),
                    itemBuilder: (context, index) {
                      final item = _featuredItems[index];
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CoveSpace.gutter,
                          vertical: CoveSpace.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Meta Row: Version, Category, Date
                            Wrap(
                              spacing: CoveSpace.sm,
                              runSpacing: CoveSpace.xs,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: CoveSpace.sm,
                                    vertical: CoveSpace.xs,
                                  ),
                                  decoration: CoveShape.decoration(
                                    _kChipRadius,
                                    color: cv.accentWash,
                                  ),
                                  child: Text(
                                    item.version,
                                    style: CoveType.barLabel.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: cv.accentText,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: CoveSpace.sm,
                                    vertical: CoveSpace.xs,
                                  ),
                                  decoration: CoveShape.decoration(
                                    _kChipRadius,
                                    color: cv.surfaceRow,
                                    side: BorderSide(color: cv.lineHairline),
                                  ),
                                  child: Text(
                                    item.category.toUpperCase(),
                                    style: CoveType.barLabel.copyWith(
                                      letterSpacing: 0.6,
                                      fontWeight: FontWeight.w600,
                                      color: cv.textSecondary,
                                    ),
                                  ),
                                ),
                                ExcludeSemantics(
                                  child: Text(
                                    '·',
                                    style: CoveType.barLabel.copyWith(
                                      color: cv.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  item.date,
                                  style: CoveType.barLabel.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: cv.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: CoveSpace.sm),

                            // Big Title
                            Text(
                              item.title,
                              style: CoveType.letter.copyWith(
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: cv.textPrimary,
                              ),
                            ),
                            const SizedBox(height: CoveSpace.xs),
                            // Tagline
                            Text(
                              item.tagline,
                              style: CoveType.rowSub.copyWith(
                                color: cv.accentText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: CoveSpace.md),

                            // DUMMY SCREENSHOT / UI MOCKUP
                            ChangelogPreviewMockup(
                              previewType: item.previewType,
                            ),
                            const SizedBox(height: CoveSpace.md),

                            // OUTCOME & BENEFIT
                            Text(
                              item.outcome,
                              style: CoveType.readout.copyWith(
                                height: 1.45,
                                color: cv.textPrimary.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: CoveSpace.md),

                            // MONOSPACED "UNDER THE HOOD" BOX
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(CoveSpace.md),
                              decoration: CoveShape.decoration(
                                CoveSpace.md,
                                color: cv.surfaceRow,
                                side: BorderSide(color: cv.lineHairline),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.terminal_rounded,
                                        size: CoveSpace.md,
                                        color: cv.textSecondary,
                                      ),
                                      const SizedBox(width: CoveSpace.sm),
                                      Expanded(
                                        child: Text(
                                          'UNDER THE HOOD',
                                          style: CoveType.barLabel.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                            color: cv.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: CoveSpace.sm),
                                  Text(
                                    item.underTheHood,
                                    style: CoveType.barLabel.copyWith(
                                      fontWeight: FontWeight.w400,
                                      height: 1.4,
                                      color: cv.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // -------------------------------------------------------------
                // BOTTOM BAR: DOTS & ACTION BUTTON
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.only(
                    left: CoveSpace.gutter,
                    right: CoveSpace.gutter,
                    bottom: CoveSpace.gutter,
                    top: CoveSpace.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Smooth Dot Indicators
                      Flexible(
                        child: Wrap(
                          runSpacing: CoveSpace.xs,
                          children: List.generate(_featuredItems.length, (idx) {
                            final isActive = idx == _currentPage;
                            return AnimatedContainer(
                              duration: CoveMotion.q(context),
                              margin: const EdgeInsets.only(right: _kDotSize),
                              width: isActive ? CoveSpace.gutter : _kDotSize,
                              height: _kDotSize,
                              decoration: CoveShape.decoration(
                                CoveRadius.pill,
                                color: isActive
                                    ? cv.accentFill
                                    : cv.lineHairline.withValues(alpha: 0.8),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(width: CoveSpace.sm),
                      // Next / Done Button
                      CovePillButton(
                        label: _currentPage == _featuredItems.length - 1
                            ? 'Got it'
                            : 'Next',
                        icon: Icon(
                          _currentPage == _featuredItems.length - 1
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: _kButtonIconSize,
                        ),
                        isCompact: true,
                        onPressed: _onNext,
                      ),
                    ],
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
