import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import 'pairing_payload.dart';

/// Modal or screen view presenting a Home Pairing QR code.
/// The partner opens their camera/scanner to import the symmetric home key directly.
class PairingQrView extends StatelessWidget {
  final PairingPayload payload;
  final VoidCallback? onDone;

  const PairingQrView({
    super.key,
    required this.payload,
    this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final qrData = payload.toQrString();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: CoveCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pair with Partner',
                style: typography.headline.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 6),
              Text(
                'Have your partner scan this QR code from their Cove app to securely exchange the Home key.',
                textAlign: TextAlign.center,
                style: typography.bodyRegular.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 24),
              // QR Code container (clean white background for optimal optical contrast)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.accentPrimary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220.0,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF0B1F1E),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0B1F1E),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Home name chip
              Text(
                payload.homeName,
                style: typography.title.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Zero-Knowledge Direct Key Exchange',
                style: typography.caption.copyWith(color: colors.accentPrimary),
              ),
              const SizedBox(height: 24),
              CovePillButton(
                label: 'Done',
                onPressed: onDone ?? () => Navigator.of(context).maybePop(),
                isFullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
