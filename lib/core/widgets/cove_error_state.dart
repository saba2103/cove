import 'package:flutter/material.dart';
import '../theme/cove_tokens.dart';
import 'cove_pill_button.dart';

/// A calm, non-alarming error or disconnected state presentation.
class CoveErrorState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  static const double _kIconCircleSize =
      56.0; // (literal) 56dp state icon medallion diameter
  static const double _kBorderWidth =
      1.0; // (literal) 1dp medallion border stroke
  static const double _kIconToTitleGap =
      16.0; // (literal) 16dp medallion-to-title gap

  const CoveErrorState({
    super.key,
    this.icon = Icons.cloud_off_outlined,
    required this.title,
    this.description,
    this.action,
  });

  /// Specialized factory for offline / pending sync state.
  factory CoveErrorState.syncPending({
    Key? key,
    VoidCallback? onRetry,
  }) {
    return CoveErrorState(
      key: key,
      icon: Icons.cloud_queue_outlined,
      title: 'Waiting to sync',
      description:
          'Changes are saved securely on your device and will sync once connected.',
      action: onRetry != null
          ? CovePillButton(
              label: 'Check connection',
              variant: CoveButtonVariant.secondary,
              onPressed: onRetry,
            )
          : null,
    );
  }

  /// Specialized factory for waiting on partner to join home.
  factory CoveErrorState.partnerWaiting({
    Key? key,
    VoidCallback? onInvite,
  }) {
    return CoveErrorState(
      key: key,
      icon: Icons.people_outline,
      title: "Partner hasn't joined yet",
      description:
          'Shared items are ready and will quietly sync when your partner joins.',
      action: onInvite != null
          ? CovePillButton(
              label: 'Share invite code',
              variant: CoveButtonVariant.secondary,
              onPressed: onInvite,
            )
          : null,
    );
  }

  /// Generic calm error presentation.
  factory CoveErrorState.generic({
    Key? key,
    String title = 'Something went wrong',
    String? description,
    VoidCallback? onRetry,
    String retryLabel = 'Try again',
  }) {
    return CoveErrorState(
      key: key,
      icon: Icons.info_outline,
      title: title,
      description:
          description ?? 'We could not load this information right now.',
      action: onRetry != null
          ? CovePillButton(
              label: retryLabel,
              variant: CoveButtonVariant.secondary,
              onPressed: onRetry,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.section,
          vertical: CoveSpace.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: _kIconCircleSize,
              height: _kIconCircleSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cv.accentWash,
                border: Border.all(
                  color: cv.lineStrong,
                  width: _kBorderWidth,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: CoveSize.avatarInline,
                color: cv.accentFill,
              ),
            ),
            const SizedBox(height: _kIconToTitleGap),
            Text(
              title,
              textAlign: TextAlign.center,
              style: CoveType.rowTitle.copyWith(
                fontWeight: FontWeight.w600,
                color: cv.textPrimary,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: CoveSpace.xs),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: CoveType.readout.copyWith(
                  color: cv.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: CoveSpace.gutter),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
