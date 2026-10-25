import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';
import 'cove_sync_tick.dart';

class CoveActivityRow extends StatelessWidget {
  final String authorName;
  final String actionText;
  final String timestamp;
  final CoveSyncStatus syncStatus;
  final VoidCallback? onTap;

  static const double _kHorizontalPadding =
      16.0; // (literal) 16dp activity row horizontal inset
  static const double _kBorderWidth =
      1.0; // (literal) 1dp avatar circle hairline border
  static const double _kSyncTickSize =
      13.0; // (literal) 13dp sync tick glyph size

  const CoveActivityRow({
    super.key,
    required this.authorName,
    required this.actionText,
    required this.timestamp,
    this.syncStatus = CoveSyncStatus.syncedToPartner,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final initial = authorName.isNotEmpty ? authorName[0].toUpperCase() : '•';

    return InkWell(
      onTap: onTap,
      splashColor: cv.accentWash,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _kHorizontalPadding,
          vertical: CoveSpace.md,
        ),
        child: Row(
          children: [
            // Subtle initial circle
            Container(
              width: CoveSize.avatarRow,
              height: CoveSize.avatarRow,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cv.surfaceRow,
                border: Border.all(
                  color: cv.lineHairline,
                  width: _kBorderWidth,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: CoveType.rowSub.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cv.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: CoveSpace.md),
            // Text content
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: CoveType.readout.copyWith(
                    color: cv.textPrimary,
                  ),
                  children: [
                    TextSpan(
                      text: '$authorName ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: actionText,
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: cv.textPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: CoveSpace.md),
            // Timestamp and delivery indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timestamp,
                  style: CoveType.rowSub.copyWith(
                    color: cv.textTertiary,
                  ),
                ),
                const SizedBox(width: CoveSpace.xs),
                CoveSyncTick(
                  status: syncStatus,
                  size: _kSyncTickSize,
                  color: cv.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
