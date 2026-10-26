import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../features/home/home_controller.dart';
import '../../features/profile/partner_profile_controller.dart';
import 'pairing_approval_sheet.dart';
import 'pairing_payload.dart';
import 'pairing_relay.dart';

/// Modal or screen view presenting a Home Pairing QR code and a 6-digit PIN code.
/// The QR code carries the payload directly from A's screen to B's camera and
/// never touches the server. The 6-digit code is keyless and requires inviter
/// approval via [PairingApprovalSheet].
class PairingQrView extends ConsumerStatefulWidget {
  final PairingPayload payload;
  final VoidCallback? onDone;

  const PairingQrView({
    super.key,
    required this.payload,
    this.onDone,
  });

  @override
  ConsumerState<PairingQrView> createState() => _PairingQrViewState();
}

class _PairingQrViewState extends ConsumerState<PairingQrView> {
  String? _pairingCode;
  bool _isLoadingCode = true;
  bool _copied = false;
  bool _isSubmittingDecision = false;
  PairingRequestRecord? _activePendingRequest;
  StreamSubscription<List<PairingRequestRecord>>? _requestsSub;

  @override
  void initState() {
    super.initState();
    _initPairingCode();
  }

  @override
  void dispose() {
    _requestsSub?.cancel();
    super.dispose();
  }

  Future<void> _initPairingCode() async {
    try {
      final homeController = ref.read(homeControllerProvider);
      final cached = homeController.cachedPairingCodeFor(widget.payload.homeId);
      final code = (cached != null && cached.isNotEmpty)
          ? cached
          : await homeController.createPairingCode(
              homeId: widget.payload.homeId,
            );
      if (mounted) {
        setState(() {
          _pairingCode = code;
          _isLoadingCode = false;
        });
        _listenForPendingRequests(code);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingCode = false);
      }
    }
  }

  void _listenForPendingRequests(String code) {
    _requestsSub?.cancel();
    final homeController = ref.read(homeControllerProvider);
    _requestsSub = homeController.watchPendingRequestsForCode(code).listen(
      (pending) {
        if (!mounted) return;
        setState(() {
          _activePendingRequest = pending.isNotEmpty ? pending.first : null;
        });
      },
      onError: (_) {},
    );
  }

  Future<void> _handleApprove(PairingRequestRecord request) async {
    if (_isSubmittingDecision) return;
    setState(() => _isSubmittingDecision = true);
    try {
      await ref.read(homeControllerProvider).approvePairingRequest(
            request: request,
            payloadOverride: widget.payload,
          );
      if (mounted) {
        setState(() {
          _isSubmittingDecision = false;
          _activePendingRequest = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmittingDecision = false);
      }
    }
  }

  Future<void> _handleDecline(PairingRequestRecord request) async {
    if (_isSubmittingDecision) return;
    setState(() => _isSubmittingDecision = true);
    try {
      await ref.read(homeControllerProvider).declinePairingRequest(request.id);
      if (mounted) {
        setState(() {
          _isSubmittingDecision = false;
          _activePendingRequest = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmittingDecision = false);
      }
    }
  }

  void _copyCode() {
    if (_pairingCode == null) return;
    Clipboard.setData(ClipboardData(text: _pairingCode!));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final qrData = widget.payload.toQrString();

    final pendingRequest = _activePendingRequest;
    if (pendingRequest != null) {
      return Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: PairingApprovalSheet(
              request: pendingRequest,
              homeName: widget.payload.homeName,
              isSubmitting: _isSubmittingDecision,
              onApprove: () => _handleApprove(pendingRequest),
              onDecline: () => _handleDecline(pendingRequest),
            ),
          ),
        ),
      );
    }

    String formattedCode = '...';
    if (_pairingCode != null && _pairingCode!.length == 6) {
      formattedCode =
          '${_pairingCode!.substring(0, 3)}  ${_pairingCode!.substring(3)}';
    }

    final partnerName = ref.watch(partnerProfileProvider).displayName;
    final pairTitle = (partnerName.isNotEmpty && partnerName != 'Partner')
        ? 'Pair with $partnerName'
        : 'Pair with Partner';
    final pairDesc = (partnerName.isNotEmpty && partnerName != 'Partner')
        ? 'Have $partnerName scan the QR code or enter the 6-digit pairing code on their device.'
        : 'Have your partner scan the QR code or enter the 6-digit pairing code on their device.';

    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: CoveCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pairTitle,
                  style: typography.headline.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  pairDesc,
                  textAlign: TextAlign.center,
                  style: typography.bodyRegular.copyWith(
                    color: colors.textMuted,
                  ),
                ),
                const SizedBox(height: 20),

                // QR Code container
                Container(
                  padding: const EdgeInsets.all(14),
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
                    size: 190.0,
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

                // 6-Digit Pairing Code Display Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceRow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.borderHairline,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'PAIRING CODE',
                        style: typography.caption.copyWith(
                          letterSpacing: 1.0,
                          color: colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingCode)
                        const SizedBox(
                          height: 32,
                          width: 32,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else ...[
                        Text(
                          formattedCode,
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4.0,
                            color: colors.accentPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Valid for 10 minutes',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 11,
                            color: colors.textSubtle,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: _copyCode,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _copied ? Icons.check : Icons.copy_rounded,
                                  size: 14,
                                  color: _copied
                                      ? colors.accentPrimary
                                      : colors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _copied
                                      ? 'Copied to clipboard'
                                      : 'Copy 6-digit code',
                                  style: TextStyle(
                                    fontFamily: 'PlusJakartaSans',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: _copied
                                        ? colors.accentPrimary
                                        : colors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Home name chip
                Text(
                  widget.payload.homeName,
                  style: typography.title.copyWith(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Zero-Knowledge Direct Key Exchange',
                  style: typography.caption.copyWith(
                    color: colors.accentPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                CovePillButton(
                  label: 'Done',
                  onPressed:
                      widget.onDone ?? () => Navigator.of(context).maybePop(),
                  isFullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
