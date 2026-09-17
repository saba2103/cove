import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/cove_theme.dart';
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
      await prefs.setString(kCoveLastSeenFreshVersionKey, kCoveCurrentAppVersion);
    }

    if (!context.mounted) return;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'What\'s Fresh',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * anim1.value),
          child: Opacity(
            opacity: anim1.value,
            child: child,
          ),
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
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      Navigator.of(context, rootNavigator: true).pop();
      widget.onDismissed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 600;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: isCompact ? size.width * 0.92 : 460,
          constraints: BoxConstraints(
            maxHeight: size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.borderHairline.withValues(alpha: 0.8), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // -------------------------------------------------------------
                // TOP BAR: BADGE, STEP COUNTER, CLOSE BUTTON
                // -------------------------------------------------------------
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 12, top: 16, bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: colors.accentPrimary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 12, color: colors.accentPrimary),
                            const SizedBox(width: 5),
                            Text(
                              'WHAT\'S FRESH · v2.4',
                              style: TextStyle(
                                fontFamily: 'GeneralSans',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: colors.accentPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${_currentPage + 1} of ${_featuredItems.length}',
                        style: typography.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                        icon: Icon(Icons.close_rounded, size: 18, color: colors.textMuted),
                        splashRadius: 18,
                        tooltip: 'Close',
                      ),
                    ],
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
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Big Title
                            Text(
                              item.title,
                              style: typography.headline.copyWith(
                                fontSize: 21,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Tagline
                            Text(
                              item.tagline,
                              style: typography.caption.copyWith(
                                fontSize: 12.5,
                                color: colors.accentPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // DUMMY SCREENSHOT / UI MOCKUP
                            ChangelogPreviewMockup(previewType: item.previewType),
                            const SizedBox(height: 14),

                            // OUTCOME & BENEFIT
                            Text(
                              item.outcome,
                              style: typography.bodyMedium.copyWith(
                                fontSize: 13.5,
                                height: 1.45,
                                color: colors.textPrimary.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // MONOSPACED "UNDER THE HOOD" BOX
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.surfaceRow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: colors.borderHairline),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.terminal_rounded, size: 12, color: colors.textMuted),
                                      const SizedBox(width: 6),
                                      Text(
                                        'UNDER THE HOOD',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: colors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item.underTheHood,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      height: 1.4,
                                      color: colors.textMuted,
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
                  padding: const EdgeInsets.only(left: 22, right: 22, bottom: 20, top: 10),
                  child: Row(
                    children: [
                      // Smooth Dot Indicators
                      Row(
                        children: List.generate(
                          _featuredItems.length,
                          (idx) {
                            final isActive = idx == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(right: 6),
                              width: isActive ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? colors.accentPrimary
                                    : colors.borderHairline.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            );
                          },
                        ),
                      ),
                      const Spacer(),
                      // Next / Done Button
                      CovePillButton(
                        label: _currentPage == _featuredItems.length - 1 ? 'Got it' : 'Next',
                        icon: Icon(
                          _currentPage == _featuredItems.length - 1
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: 15,
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
