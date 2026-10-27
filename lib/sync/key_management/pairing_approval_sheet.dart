import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import 'pairing_crypto.dart';
import 'pairing_relay.dart';

/// Inviter approval sheet (`17-invite-and-keys.md` §1 step 4):
/// `"{B} wants to join {home}. Do these words match on their phone? AMBER · HARBOUR"`
/// with **Let them in** / **Not them**.
///
/// Always derives the two verification words from [shownPublicKey] held in
/// memory, and the inviter seals to that exact same in-memory key.
class PairingApprovalSheet extends StatelessWidget {
  final PairingRequestRecord request;
  final Uint8List shownPublicKey;
  final String homeName;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final bool isSubmitting;

  const PairingApprovalSheet({
    super.key,
    required this.request,
    required this.shownPublicKey,
    required this.homeName,
    required this.onApprove,
    required this.onDecline,
    this.isSubmitting = false,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final joiner = request.joinerName.trim().isNotEmpty
        ? request.joinerName.trim()
        : 'Someone';
    final words = PairingCrypto.deriveVerificationWords(
      joinerPublicKey: shownPublicKey,
      code: request.code,
    ).formatted;

    return Padding(
      padding: const EdgeInsets.all(CoveSpace.lg),
      child: CoveCard(
        padding: const EdgeInsets.all(CoveSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$joiner wants to join $homeName.',
              style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CoveSpace.sm),
            Text(
              'Do these words match on their phone?',
              style: CoveType.body.copyWith(color: cv.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: CoveSpace.lg),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: CoveSpace.lg,
                vertical: CoveSpace.md,
              ),
              decoration: CoveShape.decoration(
                CoveRadius.inline,
                color: cv.surfaceRow,
                side: BorderSide(
                  color: cv.lineHairline,
                ),
              ),
              child: Text(
                words,
                key: const ValueKey('pairing_approval_verification_words'),
                style: CoveType.title.copyWith(
                  color: cv.accentText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: CoveSpace.xl),
            CovePillButton(
              label: 'Let them in',
              isFullWidth: true,
              isLoading: isSubmitting,
              onPressed: isSubmitting ? null : onApprove,
            ),
            const SizedBox(height: CoveSpace.sm),
            CovePillButton(
              label: 'Not them',
              variant: CoveButtonVariant.secondary,
              isFullWidth: true,
              onPressed: isSubmitting ? null : onDecline,
            ),
          ],
        ),
      ),
    );
  }
}
