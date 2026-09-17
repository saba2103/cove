import 'package:flutter/material.dart';
import '../theme/cove_theme.dart';
import 'cove_pill_button.dart';

/// A calm, non-alarming error or disconnected state presentation.
class CoveErrorState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

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
      description: description ?? 'We could not load this information right now.',
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
    final colors = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accentSecondary.withValues(alpha: 0.12),
                border: Border.all(
                  color: colors.accentSecondary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 24,
                color: colors.accentSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: colors.textMuted,
                  height: 1.4,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
