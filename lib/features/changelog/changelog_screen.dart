import 'package:flutter/material.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_pill_button.dart';
import 'changelog_models.dart';
import 'whats_fresh_modal.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  static const double _kBackIconSize =
      18.0; // (literal) 18dp AppBar back chevron icon size
  static const double _kButtonIconSize =
      14.0; // (literal) 14dp What's Fresh pill button sparkle icon
  static const double _kVerticalPadding =
      16.0; // (literal) 16dp vertical scroll inset
  static const double _kChipRadius =
      6.0; // (literal) 6dp changelog version/category tag corner radius
  static const double _kIntroBottomGap =
      28.0; // (literal) 28dp vertical gap below intro header card

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: _kBackIconSize,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Text(
          'Changelog & Updates',
          style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: CoveSpace.md),
            child: CovePillButton(
              label: "What's Fresh",
              icon: const Icon(Icons.auto_awesome, size: _kButtonIconSize),
              isCompact: true,
              variant: CoveButtonVariant.secondary,
              onPressed: () => WhatsFreshModal.show(context, force: true),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: CoveSpace.gutter,
            vertical: _kVerticalPadding,
          ),
          children: [
            // Intro Header Card
            Container(
              padding: const EdgeInsets.all(CoveSpace.gutter),
              decoration: CoveShape.decoration(
                CoveRadius.card,
                color: cv.surfaceCard,
                side: BorderSide(color: cv.lineHairline),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(CoveSpace.md),
                    decoration: BoxDecoration(
                      color: cv.accentWash,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_edu_rounded,
                      size: CoveSize.avatarInline,
                      color: cv.accentFill,
                    ),
                  ),
                  const SizedBox(width: CoveSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: CoveSpace.sm,
                          runSpacing: CoveSpace.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Cove Evolution',
                              style: CoveType.rowTitle.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cv.textPrimary,
                              ),
                            ),
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
                                'LATEST v$kCoveCurrentAppVersion',
                                style: CoveType.barLabel.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cv.accentText,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CoveSpace.xs),
                        Text(
                          'Every update is engineered to protect domestic harmony, privacy, and calm.',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _kIntroBottomGap),

            // Timeline Header
            Text(
              'RELEASE TIMELINE',
              style: CoveType.capsPage.copyWith(color: cv.textSecondary),
            ),
            const SizedBox(height: CoveSpace.md),

            // Timeline Items
            ...List.generate(kChangelogItems.length, (index) {
              final item = kChangelogItems[index];
              final isFirst = index == 0;
              final isLast = index == kChangelogItems.length - 1;

              return _TimelineItemRow(
                item: item,
                isFirst: isFirst,
                isLast: isLast,
              );
            }),

            const SizedBox(height: CoveSpace.section),
          ],
        ),
      ),
    );
  }
}

class _TimelineItemRow extends StatelessWidget {
  final ChangelogItem item;
  final bool isFirst;
  final bool isLast;

  const _TimelineItemRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
  });

  static const double _kTimelineLineOffset =
      14.0; // (literal) 14dp vertical offset to center timeline stem on node dot
  static const double _kTimelineLineWidth =
      1.5; // (literal) 1.5dp timeline vertical axis line stroke
  static const double _kNodeBorderWidth =
      2.0; // (literal) 2dp timeline node dot ring stroke
  static const double _kNodeBlurRadius =
      6.0; // (literal) 6dp featured timeline node glow blur
  static const double _kNodeSpreadRadius =
      1.0; // (literal) 1dp featured timeline node glow spread
  static const double _kCardPadding =
      16.0; // (literal) 16dp timeline card interior padding
  static const double _kFeaturedBorderWidth =
      1.2; // (literal) 1.2dp featured changelog card border width
  static const double _kNormalBorderWidth =
      1.0; // (literal) 1dp standard changelog card hairline border width
  static const double _kChipRadius =
      6.0; // (literal) 6dp changelog version/category tag corner radius
  static const double _kCategoryIconSize =
      16.0; // (literal) 16dp changelog item category icon glyph
  static const double _kUnderTheHoodRadius =
      10.0; // (literal) 10dp Under the Hood code box corner radius
  static const double _kTerminalIconSize =
      11.0; // (literal) 11dp terminal prompt icon in Under the Hood header

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------
          // TIMELINE AXIS: VERTICAL LINE & GLOWING NODE
          // -------------------------------------------------------------
          SizedBox(
            width: CoveSpace.lg,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Vertical Line
                Positioned(
                  top: isFirst ? _kTimelineLineOffset : 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? _kTimelineLineOffset : null,
                  child: Container(
                    width: _kTimelineLineWidth,
                    color: cv.lineHairline,
                  ),
                ),
                // Glowing Node Dot
                Container(
                  margin: const EdgeInsets.only(top: CoveSpace.sm),
                  width: CoveSpace.md,
                  height: CoveSpace.md,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isFeatured ? cv.accentFill : cv.surfaceCard,
                    border: Border.all(
                      color: item.isFeatured
                          ? cv.accentFill
                          : cv.textSecondary.withValues(alpha: 0.6),
                      width: _kNodeBorderWidth,
                    ),
                    boxShadow: item.isFeatured
                        ? [
                            BoxShadow(
                              color: cv.accentFill.withValues(alpha: 0.4),
                              blurRadius: _kNodeBlurRadius,
                              spreadRadius: _kNodeSpreadRadius,
                            ),
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: CoveSpace.md),

          // -------------------------------------------------------------
          // CONTENT CARD
          // -------------------------------------------------------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: CoveSpace.gutter),
              child: Container(
                padding: const EdgeInsets.all(_kCardPadding),
                decoration: CoveShape.decoration(
                  CoveRadius.card,
                  color: cv.surfaceCard,
                  side: BorderSide(
                    color: item.isFeatured
                        ? cv.accentFill.withValues(alpha: 0.3)
                        : cv.lineHairline,
                    width: item.isFeatured
                        ? _kFeaturedBorderWidth
                        : _kNormalBorderWidth,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Chips: Version & Category
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: CoveSpace.sm,
                        runSpacing: CoveSpace.xs,
                        children: [
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
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.date,
                                style: CoveType.barLabel.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: cv.textSecondary,
                                ),
                              ),
                              const SizedBox(width: CoveSpace.sm),
                              Icon(
                                item.icon,
                                size: _kCategoryIconSize,
                                color: cv.textSecondary,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CoveSpace.sm),

                    // Feature Title
                    Text(
                      item.title,
                      style: CoveType.rowTitle.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cv.textPrimary,
                      ),
                    ),
                    const SizedBox(height: CoveSpace.xs),

                    // Tagline (Benefit Headline)
                    Text(
                      item.tagline,
                      style: CoveType.rowSub.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cv.accentText,
                      ),
                    ),
                    const SizedBox(height: CoveSpace.sm),

                    // Outcome & Human Benefit
                    Text(
                      item.outcome,
                      style: CoveType.readout.copyWith(
                        height: 1.45,
                        color: cv.textPrimary.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: CoveSpace.md),

                    // Monospaced "Under the Hood" Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(CoveSpace.md),
                      decoration: CoveShape.decoration(
                        _kUnderTheHoodRadius,
                        color: cv.surfaceRow,
                        side: BorderSide(
                          color: cv.lineHairline.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.terminal_rounded,
                                size: _kTerminalIconSize,
                                color: cv.textSecondary,
                              ),
                              const SizedBox(width: CoveSpace.xs),
                              Text(
                                'UNDER THE HOOD',
                                style: CoveType.barLabel.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                  color: cv.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: CoveSpace.xs),
                          Text(
                            item.underTheHood,
                            style: CoveType.barLabel.copyWith(
                              fontWeight: FontWeight.w400,
                              height: 1.35,
                              color: cv.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
