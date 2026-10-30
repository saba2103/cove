import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../profile/partner_profile_controller.dart';
import 'home_controller.dart';

class JoinHomeScreen extends ConsumerStatefulWidget {
  final bool initialShowManualInput;

  const JoinHomeScreen({
    super.key,
    this.initialShowManualInput = false,
  });

  @override
  ConsumerState<JoinHomeScreen> createState() => _JoinHomeScreenState();
}

class _JoinHomeScreenState extends ConsumerState<JoinHomeScreen> {
  static const double _kBodyVerticalPadding =
      16.0; // (literal) 16dp join home body vertical inset
  static const double _kMaxCardWidth =
      440.0; // (literal) 440dp join home card column max width
  static const double _kHeaderBottomGap =
      28.0; // (literal) 28dp gap below join home subtitle
  static const double _kScannerSize =
      260.0; // (literal) 260dp QR camera viewfinder square
  static const double _kViewfinderSize =
      220.0; // (literal) 220dp QR inner viewfinder frame
  static const double _kViewfinderBorderWidth =
      2.0; // (literal) 2dp QR viewfinder border width
  static const double _kPinInputRadius =
      12.0; // (literal) 12dp pairing code input corner radius
  static const double _kPinBorderWidth =
      1.5; // (literal) 1.5dp pairing code input border width
  static const double _kPinLetterSpacing =
      8.0; // (literal) 8dp 6-digit PIN tracking
  static const double _kPinHintLetterSpacing =
      6.0; // (literal) 6dp PIN dot hint tracking
  static const double _kErrorRadius =
      10.0; // (literal) 10dp error banner corner radius
  static const double _kSmallIconSize =
      16.0; // (literal) 16dp inline icon glyph size

  final TextEditingController _codeController = TextEditingController();
  MobileScannerController? _scannerController;

  bool _isProcessing = false;
  PendingPairingJoinSession? _pendingSession;
  String? _errorMessage;
  late bool _showManualInput;

  @override
  void initState() {
    super.initState();
    // Default directly to 6-digit code on Web, or when explicitly requested
    _showManualInput = widget.initialShowManualInput || kIsWeb;
    if (!_showManualInput) {
      _scannerController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _processInput(String rawInput) async {
    final input = rawInput.trim();
    if (input.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _pendingSession = null;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(homeControllerProvider);
      final cleanDigits = input.replaceAll(RegExp(r'\s+'), '');

      if (cleanDigits.length == 6 && int.tryParse(cleanDigits) != null) {
        // 6-digit pairing code (approved on inviter's phone)
        await controller.joinHomeFromCode(
          cleanDigits,
          onSessionCreated: (session) {
            if (mounted) {
              setState(() {
                _pendingSession = session;
              });
            }
          },
        );
      } else {
        // Fallback to QR JSON payload string
        await controller.joinHomeFromQr(input);
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _pendingSession = null;
        });
        // Exit onboarding into the main shell
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _pendingSession = null;
          final err = e
              .toString()
              .replaceAll('Exception: ', '')
              .replaceAll('FormatException: ', '')
              .replaceAll('Bad state: ', '');
          _errorMessage =
              err.isNotEmpty ? err : 'Invalid pairing code. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final partnerProfile = ref.watch(partnerProfileProvider);
    final inviterLabel = (partnerProfile.hasCustomName &&
            partnerProfile.displayName.trim().isNotEmpty &&
            partnerProfile.displayName.trim() != 'Partner')
        ? partnerProfile.displayName.trim()
        : 'your partner';

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      appBar: AppBar(
        title: Text(
          'Join a Home',
          style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip:
                _showManualInput ? 'Open Camera Scanner' : 'Enter 6-Digit Code',
            icon: Icon(
              _showManualInput ? Icons.qr_code_scanner : Icons.dialpad_outlined,
              size: CoveSpace.gutter,
              color: cv.textPrimary,
            ),
            onPressed: () {
              setState(() {
                _showManualInput = !_showManualInput;
                if (!_showManualInput && _scannerController == null) {
                  _scannerController = MobileScannerController();
                }
              });
            },
          ),
          const SizedBox(width: CoveSpace.sm),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.lg,
              vertical: _kBodyVerticalPadding,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxCardWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showManualInput
                        ? 'Enter 6-Digit Code'
                        : 'Scan Partner\'s QR Code',
                    style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
                  ),
                  const SizedBox(height: CoveSpace.sm),
                  Text(
                    _showManualInput
                        ? 'Type the 6-digit code shown on your partner\'s device to securely join and unlock this Home.'
                        : 'Point your camera at the pairing code on your partner\'s device to import the Home encryption key.',
                    textAlign: TextAlign.center,
                    style: CoveType.body.copyWith(
                      color: cv.textSecondary,
                    ),
                  ),
                  const SizedBox(height: _kHeaderBottomGap),

                  if (!_showManualInput && _scannerController != null) ...[
                    // Camera Scanner Viewfinder (Mobile Default)
                    CoveShape.clip(
                      CoveRadius.card,
                      Container(
                        width: _kScannerSize,
                        height: _kScannerSize,
                        color: Colors.black,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            MobileScanner(
                              controller: _scannerController!,
                              onDetect: (capture) {
                                final barcodes = capture.barcodes;
                                for (final barcode in barcodes) {
                                  final val = barcode.rawValue;
                                  if (val != null && val.isNotEmpty) {
                                    _processInput(val);
                                    break;
                                  }
                                }
                              },
                              errorBuilder: (context, error) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      _kBodyVerticalPadding,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.videocam_off_outlined,
                                          size: CoveSize.avatarHeader,
                                          color: cv.textSecondary,
                                        ),
                                        const SizedBox(height: CoveSpace.sm),
                                        Text(
                                          'Camera unavailable',
                                          style: CoveType.rowTitle.copyWith(
                                            color: cv.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: CoveSpace.md),
                                        CovePillButton(
                                          label: 'Enter 6-Digit Code Instead',
                                          isCompact: true,
                                          variant: CoveButtonVariant.secondary,
                                          onPressed: () {
                                            setState(
                                              () => _showManualInput = true,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Viewfinder Overlay border
                            Container(
                              width: _kViewfinderSize,
                              height: _kViewfinderSize,
                              decoration: CoveShape.decoration(
                                CoveRadius.inline,
                                side: BorderSide(
                                  color: cv.accentFill.withValues(alpha: 0.6),
                                  width: _kViewfinderBorderWidth,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else ...[
                    // 6-Digit Code Entry Card (Web Default)
                    CoveCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.lg,
                        vertical: CoveSpace.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(
                              'PAIRING CODE',
                              style: CoveType.capsCard.copyWith(
                                color: cv.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: _kBodyVerticalPadding),

                          // Large Centered 6-Digit PIN Input Field
                          Container(
                            decoration: CoveShape.decoration(
                              _kPinInputRadius,
                              color: cv.surfaceRow,
                              side: BorderSide(
                                color: cv.lineHairline,
                                width: _kPinBorderWidth,
                              ),
                            ),
                            child: TextField(
                              controller: _codeController,
                              autofocus: true,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (val) => _processInput(val),
                              onChanged: (val) {
                                final digits =
                                    val.replaceAll(RegExp(r'\s+'), '');
                                if (digits.length == 6) {
                                  _processInput(digits);
                                }
                              },
                              style: CoveType.title.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: _kPinLetterSpacing,
                                color: cv.accentText,
                              ),
                              cursorColor: cv.accentFill,
                              decoration: InputDecoration(
                                hintText: '• • • • • •',
                                hintMaxLines:
                                    MediaQuery.textScalerOf(
                                          context,
                                        ).scale(1.0) >
                                        1.0
                                    ? 2
                                    : null,
                                hintStyle: CoveType.slipTitle.copyWith(
                                  letterSpacing:
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1.0) >
                                          1.0
                                      ? 0.5
                                      : _kPinHintLetterSpacing,
                                  color: cv.textTertiary,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal:
                                      MediaQuery.textScalerOf(
                                            context,
                                          ).scale(1.0) >
                                          1.0
                                      ? CoveSpace.xs
                                      : _kBodyVerticalPadding,
                                  vertical: CoveSpace.md,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: 'Paste from clipboard',
                                  icon: Icon(
                                    Icons.paste_rounded,
                                    size: CoveSpace.gutter,
                                    color: cv.textSecondary,
                                  ),
                                  onPressed: () async {
                                    final data =
                                        await Clipboard.getData('text/plain');
                                    if (data?.text != null) {
                                      _codeController.text =
                                          data!.text!.trim();
                                      _processInput(_codeController.text);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),

                          if (_pendingSession != null) ...[
                            const SizedBox(height: CoveSpace.lg),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: CoveSpace.lg,
                                vertical: CoveSpace.md,
                              ),
                              decoration: CoveShape.decoration(
                                CoveRadius.inline,
                                color: cv.surfaceRow,
                                side: BorderSide(color: cv.lineHairline),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    _pendingSession!
                                        .verificationWords.formatted,
                                    key: const ValueKey(
                                      'joiner_verification_words',
                                    ),
                                    style: CoveType.title.copyWith(
                                      color: cv.accentText,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: CoveSpace.xs),
                                  Text(
                                    'Ask $inviterLabel to check these words.',
                                    style: CoveType.readout.copyWith(
                                      color: cv.textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: CoveSpace.gutter),

                          CovePillButton(
                            label: 'Join Home',
                            isLoading: _isProcessing,
                            isFullWidth: true,
                            onPressed: () {
                              _processInput(_codeController.text);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: _kBodyVerticalPadding),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.md,
                        vertical: CoveSpace.sm,
                      ),
                      decoration: CoveShape.decoration(
                        _kErrorRadius,
                        color: cv.statusAlert.withValues(alpha: 0.12),
                        side: BorderSide(
                          color: cv.statusAlert.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: _kSmallIconSize,
                            color: cv.statusAlertText,
                          ),
                          const SizedBox(width: CoveSpace.sm),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: CoveType.readout.copyWith(
                                color: cv.statusAlertText,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: CoveSpace.lg),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showManualInput = !_showManualInput;
                        if (!_showManualInput && _scannerController == null) {
                          _scannerController = MobileScannerController();
                        }
                      });
                    },
                    icon: Icon(
                      _showManualInput
                          ? Icons.qr_code_scanner
                          : Icons.dialpad_outlined,
                      size: _kSmallIconSize,
                      color: cv.accentText,
                    ),
                    label: Text(
                      _showManualInput
                          ? (kIsWeb
                              ? 'Scan with webcam instead'
                              : 'Scan QR code with camera')
                          : 'Enter 6-digit code manually',
                      style: CoveType.readout.copyWith(
                        fontWeight: FontWeight.w500,
                        color: cv.accentText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
