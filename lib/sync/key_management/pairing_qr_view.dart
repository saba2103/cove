import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
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

  static const double _kQrFramePadding = 14.0; // (literal) QR quiet-zone padding
  static const double _kQrBorderWidth = 1.5; // (literal) QR frame stroke
  static const double _kQrSize = 190.0; // (literal) QR matrix viewport size
  static const double _kCodeSpinnerSize = 32.0; // (literal) loading spinner box
  static const double _kCodeSpinnerStroke = 2.0; // (literal) loading spinner stroke
  static const double _kCodeLetterSpacing = 4.0; // (literal) 6-digit code tracking
  static const double _kCopyIconSize = 14.0; // (literal) copy glyph size

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
  Uint8List? _shownPublicKey;
  String? _statusMessage;
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
          final next = pending.isNotEmpty ? pending.first : null;
          if (next == null) {
            _activePendingRequest = null;
            _shownPublicKey = null;
          } else if (_activePendingRequest == null ||
              _activePendingRequest!.id != next.id) {
            _activePendingRequest = next;
            // Pin the public key in memory at the moment we show the two words.
            _shownPublicKey = Uint8List.fromList(next.joinerPublicKeyBytes);
            _statusMessage = null;
          } else {
            _activePendingRequest = next;
          }
        });
      },
      onError: (_) {},
    );
  }

  Future<void> _handleApprove(
    PairingRequestRecord request,
    Uint8List shownPublicKey,
  ) async {
    if (_isSubmittingDecision) return;
    setState(() => _isSubmittingDecision = true);
    try {
      await ref.read(homeControllerProvider).approvePairingRequest(
            request: request,
            shownPublicKey: shownPublicKey,
            payloadOverride: widget.payload,
          );
      if (mounted) {
        setState(() {
          _isSubmittingDecision = false;
          _activePendingRequest = null;
          _shownPublicKey = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll('Bad state: ', '').trim();
        setState(() {
          _isSubmittingDecision = false;
          _activePendingRequest = null;
          _shownPublicKey = null;
          _statusMessage = msg.isNotEmpty
              ? msg
              : 'This request changed. Ask them to try again.';
        });
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
          _shownPublicKey = null;
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
    final cv = context.cv;
    final qrData = widget.payload.toQrString();

    final pendingRequest = _activePendingRequest;
    final shownPublicKey = _shownPublicKey;
    if (pendingRequest != null && shownPublicKey != null) {
      return Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: CoveSize.maxContent),
            child: PairingApprovalSheet(
              request: pendingRequest,
              shownPublicKey: shownPublicKey,
              homeName: widget.payload.homeName,
              isSubmitting: _isSubmittingDecision,
              onApprove: () => _handleApprove(pendingRequest, shownPublicKey),
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
          constraints: const BoxConstraints(maxWidth: CoveSize.maxContent),
          child: CoveCard(
            padding: const EdgeInsets.all(CoveSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pairTitle,
                  textAlign: TextAlign.center,
                  style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
                ),
                const SizedBox(height: CoveSpace.sm),
                Text(
                  pairDesc,
                  textAlign: TextAlign.center,
                  style: CoveType.body.copyWith(
                    color: cv.textSecondary,
                  ),
                ),
                const SizedBox(height: CoveSpace.gutter),

                // QR Code container (high-contrast paper plate for camera scan)
                Container(
                  padding: const EdgeInsets.all(PairingQrView._kQrFramePadding),
                  decoration: CoveShape.decoration(
                    CoveRadius.inline,
                    color: CoveTokens.light.surfaceCard,
                    side: BorderSide(
                      color: cv.lineControl,
                      width: PairingQrView._kQrBorderWidth,
                    ),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: PairingQrView._kQrSize,
                    eyeStyle: QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: CoveTokens.dark.surfaceCanvas,
                    ),
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: CoveTokens.dark.surfaceCanvas,
                    ),
                  ),
                ),
                const SizedBox(height: CoveSpace.md + CoveSpace.xs),

                // 6-Digit Pairing Code Display Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.md + CoveSpace.xs,
                    vertical: CoveSpace.md,
                  ),
                  decoration: CoveShape.decoration(
                    CoveRadius.inline,
                    color: cv.surfaceRow,
                    side: BorderSide(
                      color: cv.lineControl,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'PAIRING CODE',
                        style: CoveType.capsCard.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                      const SizedBox(height: CoveSpace.sm),
                      if (_isLoadingCode)
                        const SizedBox(
                          height: PairingQrView._kCodeSpinnerSize,
                          width: PairingQrView._kCodeSpinnerSize,
                          child: CircularProgressIndicator(
                            strokeWidth: PairingQrView._kCodeSpinnerStroke,
                          ),
                        )
                      else ...[
                        Text(
                          formattedCode,
                          style: CoveType.cardFigure.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: PairingQrView._kCodeLetterSpacing,
                            color: cv.accentText,
                          ),
                        ),
                        const SizedBox(height: CoveSpace.xs),
                        Text(
                          'Valid for 10 minutes',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                        const SizedBox(height: CoveSpace.sm),
                        InkWell(
                          onTap: _copyCode,
                          customBorder: CoveShape.border(CoveRadius.inline),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: CoveSpace.md,
                              vertical: CoveSpace.sm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _copied ? Icons.check : Icons.copy_rounded,
                                  size: PairingQrView._kCopyIconSize,
                                  color: _copied
                                      ? cv.accentText
                                      : cv.textSecondary,
                                ),
                                const SizedBox(width: CoveSpace.sm),
                                Flexible(
                                  child: Text(
                                    _copied
                                        ? 'Copied to clipboard'
                                        : 'Copy 6-digit code',
                                    style: CoveType.rowSub.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: _copied
                                          ? cv.accentText
                                          : cv.textSecondary,
                                    ),
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

                if (_statusMessage != null) ...[
                  const SizedBox(height: CoveSpace.md),
                  Text(
                    _statusMessage!,
                    key: const ValueKey('pairing_qr_status_message'),
                    textAlign: TextAlign.center,
                    style: CoveType.rowSub.copyWith(
                      color: cv.accentText,
                    ),
                  ),
                ],

                const SizedBox(height: CoveSpace.md),

                // Home name chip
                Text(
                  widget.payload.homeName,
                  textAlign: TextAlign.center,
                  style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                ),
                const SizedBox(height: CoveSpace.xs),
                Text(
                  'Zero-Knowledge Direct Key Exchange',
                  textAlign: TextAlign.center,
                  style: CoveType.rowSub.copyWith(
                    color: cv.accentText,
                  ),
                ),
                const SizedBox(height: CoveSpace.gutter),
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
