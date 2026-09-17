import 'package:flutter/material.dart';
import '../../../../core/theme/cove_theme.dart';
import '../changelog_models.dart';

class ChangelogPreviewMockup extends StatelessWidget {
  final ChangelogPreviewType previewType;

  const ChangelogPreviewMockup({
    super.key,
    required this.previewType,
  });

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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.grid_view_rounded, size: 14, color: colors.accentPrimary),
                  const SizedBox(width: 6),
                  Text(
                    '2026 Commitments',
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '50/50 ON',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: colors.accentPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 3x2 Mini Month Grid
          Row(
            children: [
              _buildMiniMonth(context, 'Jan', '₹24k', true),
              const SizedBox(width: 6),
              _buildMiniMonth(context, 'Feb', '₹18k', false),
              const SizedBox(width: 6),
              _buildMiniMonth(context, 'Mar', '₹32k', false),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildMiniMonth(context, 'Apr', '₹19k', false),
              const SizedBox(width: 6),
              _buildMiniMonth(context, 'May', '₹21k', false),
              const SizedBox(width: 6),
              _buildMiniMonth(context, 'Jun', '₹27k', false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMonth(BuildContext context, String name, String amount, bool isCurrent) {
    final colors = context.colors;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: colors.surfaceRow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent ? colors.accentPrimary.withValues(alpha: 0.6) : colors.borderHairline,
            width: isCurrent ? 1.2 : 1.0,
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
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isCurrent ? colors.accentPrimary : colors.textPrimary,
                  ),
                ),
                if (isCurrent)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.accentPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              amount,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: colors.accentPrimary,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      color: colors.accentSecondary,
                      borderRadius: BorderRadius.circular(1),
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderHairline),
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
          Divider(color: colors.borderHairline.withValues(alpha: 0.5), height: 16),
          // Before / After Comparison 2
          _buildComparisonRow(
            context,
            label: 'Electricity Bill',
            before: '₹1,450.00',
            after: '₹1,450',
            isClean: true,
          ),
          Divider(color: colors.borderHairline.withValues(alpha: 0.5), height: 16),
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
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: colors.textMuted,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              before,
              style: TextStyle(
                fontSize: 11,
                decoration: TextDecoration.lineThrough,
                color: colors.textMuted.withValues(alpha: 0.5),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded, size: 10, color: Colors.grey),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isClean
                    ? colors.accentPrimary.withValues(alpha: 0.15)
                    : colors.surfaceRow,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isClean
                      ? colors.accentPrimary.withValues(alpha: 0.3)
                      : colors.borderHairline,
                ),
              ),
              child: Text(
                after,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isClean ? colors.accentPrimary : colors.textPrimary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// 3. PROFILE STUDIO MOCKUP
// -------------------------------------------------------------
class _ProfileStudioPreview extends StatelessWidget {
  const _ProfileStudioPreview();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          // Avatar with Camera Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accentPrimary,
                  border: Border.all(color: colors.borderHairline, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'S',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colors.accentPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.background, width: 1.5),
                  ),
                  child: Icon(Icons.camera_alt_rounded, size: 10, color: colors.background),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          // Chips Row
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildPillChip(context, Icons.photo_library_outlined, 'Upload Photo'),
                    const SizedBox(width: 6),
                    _buildPillChip(context, Icons.text_fields_rounded, 'Initials'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.done_all_rounded, size: 12, color: colors.accentPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'Frame 0 Instant Sync',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colors.accentPrimary,
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
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceRow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: colors.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderHairline),
      ),
      child: Center(
        child: Icon(Icons.auto_awesome_rounded, size: 28, color: colors.accentPrimary),
      ),
    );
  }
}
