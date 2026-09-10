import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';
import 'cove_sync_tick.dart';

class CoveActivityRow extends StatelessWidget {
  final String authorName;
  final String actionText;
  final String timestamp;
  final CoveSyncStatus syncStatus;
  final VoidCallback? onTap;

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
    final colors = context.colors;
    final initial = authorName.isNotEmpty ? authorName[0].toUpperCase() : '•';

    return InkWell(
      onTap: onTap,
      splashColor: colors.accentPrimary.withValues(alpha: 0.05),
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Subtle initial circle
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surfaceRow,
                border: Border.all(
                  color: colors.borderHairline,
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 14,
                    color: colors.textPrimary,
                    height: 1.35,
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
                        color: colors.textPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Timestamp and delivery indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timestamp,
                  style: TextStyle(
                    fontFamily: 'GeneralSans',
                    fontSize: 12,
                    color: colors.textSubtle,
                  ),
                ),
                const SizedBox(width: 6),
                CoveSyncTick(
                  status: syncStatus,
                  size: 13,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
