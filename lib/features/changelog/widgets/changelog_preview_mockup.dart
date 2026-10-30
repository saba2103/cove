import 'package:flutter/material.dart';
import '../../../../core/shape/cove_shape.dart';
import '../../../../core/theme/cove_tokens.dart';
import '../changelog_models.dart';

class ChangelogPreviewMockup extends StatelessWidget {
  final ChangelogPreviewType previewType;

  const ChangelogPreviewMockup({super.key, required this.previewType});

  @override
  Widget build(BuildContext context) {
    switch (previewType) {
      case ChangelogPreviewType.helicopterView:
        return const _HelicopterPreview();
      case ChangelogPreviewType.smartDecimals:
        return const _SmartDecimalsPreview();
      case ChangelogPreviewType.profileStudio:
        return const _ProfileStudioPreview();
      default:
        return const _GenericPreview();
    }
  }
}

// -------------------------------------------------------------
// 1. HELICOPTER VIEW MOCKUP
// -------------------------------------------------------------
class _HelicopterPreview extends StatelessWidget {
  const _HelicopterPreview();

  static const double _kHeaderIconSize =
      14.0; // (literal) 14dp helicopter grid header icon
  static const double _kBadgeRadius =
      6.0; // (literal) 6dp 50/50 badge corner radius
  static const double _kCurrentBorderWidth =
      1.2; // (literal) 1.2dp active mini month cell border stroke
  static const double _kNormalBorderWidth =
      1.0; // (literal) 1dp inactive mini month cell border stroke
  static const double _kBarHeight =
      2.0; // (literal) 2dp mini month split bar height and gap
  static const double _kBarRadius =
      1.0; // (literal) 1dp mini month split bar corner radius

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;

    return Container(
      padding: const EdgeInsets.all(CoveSpace.md),
      decoration: CoveShape.decoration(
        CoveRadius.inline,
        color: cv.surfaceCard,
        side: BorderSide(color: cv.lineHairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          if (isScaled)
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: CoveSpace.sm,
                runSpacing: CoveSpace.xs,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        size: _kHeaderIconSize,
                        color: cv.accentFill,
                      ),
                      const SizedBox(width: CoveSpace.sm),
                      Flexible(
                        child: Text(
                          '2026 Commitments',
                          style: CoveType.rowSub.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cv.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoveSpace.sm,
                      vertical: CoveSpace.xs,
                    ),
                    decoration: CoveShape.decoration(
                      _kBadgeRadius,
                      color: cv.accentWash,
                    ),
                    child: Text(
                      '50/50 ON',
                      style: CoveType.barLabel.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cv.accentText,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.grid_view_rounded,
                      size: _kHeaderIconSize,
                      color: cv.accentFill,
                    ),
                    const SizedBox(width: CoveSpace.sm),
                    Text(
                      '2026 Commitments',
                      style: CoveType.rowSub.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cv.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.sm,
                    vertical: CoveSpace.xs,
                  ),
                  decoration: CoveShape.decoration(
                    _kBadgeRadius,
                    color: cv.accentWash,
                  ),
                  child: Text(
                    '50/50 ON',
                    style: CoveType.barLabel.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cv.accentText,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: CoveSpace.sm),
          // Mini Month Grid (3x2 at 1.0x, 2x3 when scaled)
          if (isScaled) ...[
            Row(
              children: [
                _buildMiniMonth(context, 'Jan', '₹24k', true),
                const SizedBox(width: CoveSpace.sm),
                _buildMiniMonth(context, 'Feb', '₹18k', false),
              ],
            ),
            const SizedBox(height: CoveSpace.sm),
            Row(
              children: [
                _buildMiniMonth(context, 'Mar', '₹32k', false),
                const SizedBox(width: CoveSpace.sm),
                _buildMiniMonth(context, 'Apr', '₹19k', false),
              ],
            ),
            const SizedBox(height: CoveSpace.sm),
            Row(
              children: [
                _buildMiniMonth(context, 'May', '₹21k', false),
                const SizedBox(width: CoveSpace.sm),
                _buildMiniMonth(context, 'Jun', '₹27k', false),
              ],
            ),
          ] else ...[
            Row(
              children: [
                _buildMiniMonth(context, 'Jan', '₹24k', true),
                const SizedBox(width: CoveSpace.sm),
                _buildMiniMonth(context, 'Feb', '₹18k', false),
                const SizedBox(width: CoveSpace.sm),
                _buildMiniMonth(context, 'Mar', '₹32k', false),
              ],
            ),
            const SizedBox(height: CoveSpace.sm),
            Row(
              children: [
                _buildMiniMonth(context, 'Apr', '₹19k', false),
                const SizedBox(width: CoveSpace.sm),
                _buildMiniMonth(context, 'May', '₹21k', false),
                const SizedBox(width: CoveSpace.sm),
                _buildMiniMonth(context, 'Jun', '₹27k', false),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniMonth(
    BuildContext context,
    String name,
    String amount,
    bool isCurrent,
  ) {
    final cv = context.cv;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: CoveSpace.sm,
          horizontal: CoveSpace.sm,
        ),
        decoration: CoveShape.decoration(
          CoveSpace.sm,
          color: cv.surfaceRow,
          side: BorderSide(
            color: isCurrent
                ? cv.accentFill.withValues(alpha: 0.6)
                : cv.lineHairline,
            width: isCurrent ? _kCurrentBorderWidth : _kNormalBorderWidth,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: CoveType.barLabel.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isCurrent ? cv.accentText : cv.textPrimary,
                  ),
                ),
                if (isCurrent)
                  Container(
                    width: CoveSpace.xs,
                    height: CoveSpace.xs,
                    decoration: BoxDecoration(
                      color: cv.accentFill,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: CoveSpace.xs),
            Text(
              amount,
              style: CoveType.barLabel.copyWith(
                fontWeight: FontWeight.w700,
                color: cv.textPrimary,
              ),
            ),
            const SizedBox(height: CoveSpace.xs),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: _kBarHeight,
                    decoration: CoveShape.decoration(
                      _kBarRadius,
                      color: cv.accentFill,
                    ),
                  ),
                ),
                const SizedBox(width: _kBarHeight),
                Expanded(
                  child: Container(
                    height: _kBarHeight,
                    decoration: CoveShape.decoration(
                      _kBarRadius,
                      color: cv.statusAlert,
                    ),
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

// -------------------------------------------------------------
// 2. SMART DECIMALS MOCKUP
// -------------------------------------------------------------
class _SmartDecimalsPreview extends StatelessWidget {
  const _SmartDecimalsPreview();

  static const double _kDividerHeight =
      16.0; // (literal) 16dp comparison row divider vertical extent
  static const double _kArrowIconSize =
      10.0; // (literal) 10dp before-to-after comparison arrow icon

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CoveSpace.md,
        vertical: CoveSpace.md,
      ),
      decoration: CoveShape.decoration(
        CoveRadius.inline,
        color: cv.surfaceCard,
        side: BorderSide(color: cv.lineHairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Before / After Comparison 1
          _buildComparisonRow(
            context,
            label: 'Oat Milk & Coffee',
            before: '₹250.00',
            after: '₹250',
            isClean: true,
          ),
          Divider(
            color: cv.lineHairline.withValues(alpha: 0.5),
            height: _kDividerHeight,
          ),
          // Before / After Comparison 2
          _buildComparisonRow(
            context,
            label: 'Electricity Bill',
            before: '₹1,450.00',
            after: '₹1,450',
            isClean: true,
          ),
          Divider(
            color: cv.lineHairline.withValues(alpha: 0.5),
            height: _kDividerHeight,
          ),
          // Kept precision when non-zero
          _buildComparisonRow(
            context,
            label: 'Split Uber Ride',
            before: '₹349.50',
            after: '₹349.50',
            isClean: false,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
    BuildContext context, {
    required String label,
    required String before,
    required String after,
    required bool isClean,
  }) {
    final cv = context.cv;
    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;

    final valuesRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          before,
          style: CoveType.barLabel.copyWith(
            decoration: TextDecoration.lineThrough,
            color: cv.textSecondary.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: CoveSpace.sm),
        Icon(
          Icons.arrow_forward_rounded,
          size: _kArrowIconSize,
          color: cv.textTertiary,
        ),
        const SizedBox(width: CoveSpace.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: CoveSpace.sm,
            vertical: CoveSpace.xs,
          ),
          decoration: CoveShape.decoration(
            CoveSpace.xs,
            color: isClean ? cv.accentWash : cv.surfaceRow,
            side: BorderSide(
              color: isClean
                  ? cv.accentFill.withValues(alpha: 0.3)
                  : cv.lineHairline,
            ),
          ),
          child: Text(
            after,
            style: CoveType.barLabel.copyWith(
              fontWeight: FontWeight.w700,
              color: isClean ? cv.accentText : cv.textPrimary,
            ),
          ),
        ),
      ],
    );

    if (isScaled) {
      return SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: CoveSpace.sm,
          runSpacing: CoveSpace.xs,
          children: [
            Text(
              label,
              style: CoveType.barLabel.copyWith(
                color: cv.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            valuesRow,
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: CoveType.barLabel.copyWith(
              color: cv.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: CoveSpace.sm),
        valuesRow,
      ],
    );
  }
}

// -------------------------------------------------------------
// 3. PROFILE STUDIO MOCKUP
// -------------------------------------------------------------
class _ProfileStudioPreview extends StatelessWidget {
  const _ProfileStudioPreview();

  static const double _kHorizontalPadding =
      16.0; // (literal) 16dp profile studio preview horizontal inset
  static const double _kAvatarBorderWidth =
      1.5; // (literal) 1.5dp profile avatar and camera badge ring stroke
  static const double _kBadgeOffset =
      -2.0; // (literal) -2dp camera badge corner overhang offset
  static const double _kSmallIconSize =
      10.0; // (literal) 10dp camera badge and pill chip icon glyph

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final isScaled = MediaQuery.textScalerOf(context).scale(1.0) > 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: _kHorizontalPadding,
        vertical: CoveSpace.md,
      ),
      decoration: CoveShape.decoration(
        CoveRadius.inline,
        color: cv.surfaceCard,
        side: BorderSide(color: cv.lineHairline),
      ),
      child: Row(
        crossAxisAlignment:
            isScaled ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          // Avatar with Camera Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: CoveSize.hit,
                height: CoveSize.hit,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cv.accentFill,
                  border: Border.all(
                    color: cv.lineHairline,
                    width: _kAvatarBorderWidth,
                  ),
                ),
                child: Center(
                  child: Text(
                    'S',
                    style: CoveType.slipTitle.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cv.textPrimary,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: _kBadgeOffset,
                right: _kBadgeOffset,
                child: Container(
                  padding: const EdgeInsets.all(CoveSpace.xs),
                  decoration: BoxDecoration(
                    color: cv.accentFill,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cv.surfaceCanvas,
                      width: _kAvatarBorderWidth,
                    ),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    size: _kSmallIconSize,
                    color: cv.surfaceCanvas,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: CoveSpace.md),
          // Chips Row
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isScaled)
                  Wrap(
                    spacing: CoveSpace.sm,
                    runSpacing: CoveSpace.xs,
                    children: [
                      _buildPillChip(
                        context,
                        Icons.photo_library_outlined,
                        'Upload Photo',
                      ),
                      _buildPillChip(
                        context,
                        Icons.text_fields_rounded,
                        'Initials',
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      _buildPillChip(
                        context,
                        Icons.photo_library_outlined,
                        'Upload Photo',
                      ),
                      const SizedBox(width: CoveSpace.sm),
                      _buildPillChip(
                        context,
                        Icons.text_fields_rounded,
                        'Initials',
                      ),
                    ],
                  ),
                const SizedBox(height: CoveSpace.sm),
                Row(
                  children: [
                    Icon(
                      Icons.done_all_rounded,
                      size: CoveSpace.md,
                      color: cv.accentFill,
                    ),
                    const SizedBox(width: CoveSpace.xs),
                    Flexible(
                      child: Text(
                        'Frame 0 Instant Sync',
                        style: CoveType.barLabel.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cv.accentText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillChip(BuildContext context, IconData icon, String label) {
    final cv = context.cv;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CoveSpace.sm,
        vertical: CoveSpace.xs,
      ),
      decoration: CoveShape.decoration(
        CoveSpace.md,
        color: cv.surfaceRow,
        side: BorderSide(color: cv.lineHairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _kSmallIconSize, color: cv.textSecondary),
          const SizedBox(width: CoveSpace.xs),
          Text(
            label,
            style: CoveType.barLabel.copyWith(
              fontWeight: FontWeight.w500,
              color: cv.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. GENERIC MOCKUP FALLBACK
// -------------------------------------------------------------
class _GenericPreview extends StatelessWidget {
  const _GenericPreview();

  static const double _kFallbackHeight =
      70.0; // (literal) 70dp generic changelog preview fallback box height

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Container(
      height: _kFallbackHeight,
      decoration: CoveShape.decoration(
        CoveRadius.inline,
        color: cv.surfaceCard,
        side: BorderSide(color: cv.lineHairline),
      ),
      child: Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          size: CoveSize.avatarRow,
          color: cv.accentFill,
        ),
      ),
    );
  }
}
