import 'package:flutter/material.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_pill_button.dart';
import 'changelog_models.dart';
import 'whats_fresh_modal.dart';

class ChangelogScreen extends StatelessWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: Text(
          'Changelog & Updates',
          style: typography.headline.copyWith(fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CovePillButton(
              label: "What's Fresh",
              icon: const Icon(Icons.auto_awesome, size: 14),
              isCompact: true,
              variant: CoveButtonVariant.secondary,
              onPressed: () => WhatsFreshModal.show(context, force: true),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Intro Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.borderHairline),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.accentPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.history_edu_rounded, size: 22, color: colors.accentPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Cove Evolution',
                              style: typography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.accentPrimary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'LATEST v$kCoveCurrentAppVersion',
                                style: TextStyle(
                                  fontFamily: 'GeneralSans',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: colors.accentPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Every update is engineered to protect domestic harmony, privacy, and calm.',
                          style: typography.caption.copyWith(
                            color: colors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Timeline Header
            Text(
              'RELEASE TIMELINE',
              style: typography.caption.copyWith(
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),

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

            const SizedBox(height: 32),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------
          // TIMELINE AXIS: VERTICAL LINE & GLOWING NODE
          // -------------------------------------------------------------
          SizedBox(
            width: 24,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Vertical Line
                Positioned(
                  top: isFirst ? 14 : 0,
                  bottom: isLast ? null : 0,
                  height: isLast ? 14 : null,
                  child: Container(
                    width: 1.5,
                    color: colors.borderHairline,
                  ),
                ),
                // Glowing Node Dot
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isFeatured ? colors.accentPrimary : colors.surfaceCard,
                    border: Border.all(
                      color: item.isFeatured ? colors.accentPrimary : colors.textMuted.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    boxShadow: item.isFeatured
                        ? [
                            BoxShadow(
                              color: colors.accentPrimary.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // -------------------------------------------------------------
          // CONTENT CARD
          // -------------------------------------------------------------
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: item.isFeatured
                        ? colors.accentPrimary.withValues(alpha: 0.3)
                        : colors.borderHairline,
                    width: item.isFeatured ? 1.2 : 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Chips: Version & Category
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.accentPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.version,
                            style: TextStyle(
                              fontFamily: 'GeneralSans',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.accentPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.surfaceRow,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.borderHairline),
                          ),
                          child: Text(
                            item.category.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'GeneralSans',
                              fontSize: 9.5,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w600,
                              color: colors.textMuted,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(item.icon, size: 16, color: colors.textMuted),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Feature Title
                    Text(
                      item.title,
                      style: typography.bodyMedium.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Tagline (Benefit Headline)
                    Text(
                      item.tagline,
                      style: typography.caption.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: colors.accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Outcome & Human Benefit
                    Text(
                      item.outcome,
                      style: typography.bodyMedium.copyWith(
                        fontSize: 13,
                        height: 1.45,
                        color: colors.textPrimary.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Monospaced "Under the Hood" Container
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.surfaceRow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: colors.borderHairline.withValues(alpha: 0.7)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.terminal_rounded, size: 11, color: colors.textMuted),
                              const SizedBox(width: 5),
                              Text(
                                'UNDER THE HOOD',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.7,
                                  color: colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.underTheHood,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              height: 1.35,
                              color: colors.textMuted,
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
