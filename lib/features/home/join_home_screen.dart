import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
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
  final TextEditingController _codeController = TextEditingController();
  MobileScannerController? _scannerController;

  bool _isProcessing = false;
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
      _errorMessage = null;
    });

    try {
      final controller = ref.read(homeControllerProvider);
      final cleanDigits = input.replaceAll(RegExp(r'\s+'), '');

      if (cleanDigits.length == 6 && int.tryParse(cleanDigits) != null) {
        // 6-digit pairing code
        await controller.joinHomeFromCode(cleanDigits);
      } else {
        // Fallback to QR JSON payload string
        await controller.joinHomeFromQr(input);
      }

      if (mounted) {
        setState(() => _isProcessing = false);
        // Exit onboarding into the main shell
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          final err = e.toString().replaceAll('Exception: ', '').replaceAll('FormatException: ', '');
          _errorMessage = err.isNotEmpty ? err : 'Invalid pairing code. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Join a Home', style: typography.headline.copyWith(fontSize: 20)),
        actions: [
          IconButton(
            tooltip: _showManualInput ? 'Open Camera Scanner' : 'Enter 6-Digit Code',
            icon: Icon(
              _showManualInput ? Icons.qr_code_scanner : Icons.dialpad_outlined,
              size: 20,
              color: colors.textPrimary,
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
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _showManualInput
                        ? 'Enter 6-Digit Code'
                        : 'Scan Partner\'s QR Code',
                    style: typography.title.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showManualInput
                        ? 'Type the 6-digit code shown on your partner\'s device to securely join and unlock this Home.'
                        : 'Point your camera at the pairing code on your partner\'s device to import the Home encryption key.',
                    textAlign: TextAlign.center,
                    style: typography.bodyRegular.copyWith(
                      color: colors.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (!_showManualInput && _scannerController != null) ...[
                    // Camera Scanner Viewfinder (Mobile Default)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 260,
                        height: 260,
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
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.videocam_off_outlined,
                                          size: 32,
                                          color: colors.textMuted,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Camera unavailable',
                                          style: typography.bodyMedium,
                                        ),
                                        const SizedBox(height: 12),
                                        CovePillButton(
                                          label: 'Enter 6-Digit Code Instead',
                                          isCompact: true,
                                          variant: CoveButtonVariant.secondary,
                                          onPressed: () {
                                            setState(() => _showManualInput = true);
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
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.accentPrimary.withValues(alpha: 0.6),
                                  width: 2,
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
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Text(
                              'PAIRING CODE',
                              style: typography.caption.copyWith(
                                letterSpacing: 1.0,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Large Centered 6-Digit PIN Input Field
                          Container(
                            decoration: BoxDecoration(
                              color: colors.surfaceRow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colors.borderHairline,
                                width: 1.5,
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
                                final digits = val.replaceAll(RegExp(r'\s+'), '');
                                if (digits.length == 6) {
                                  _processInput(digits);
                                }
                              },
                              style: TextStyle(
                                fontFamily: 'GeneralSans',
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 8.0,
                                color: colors.accentPrimary,
                              ),
                              cursorColor: colors.accentPrimary,
                              decoration: InputDecoration(
                                hintText: '• • • • • •',
                                hintStyle: TextStyle(
                                  fontFamily: 'GeneralSans',
                                  fontSize: 24,
                                  letterSpacing: 6.0,
                                  color: colors.textSubtle,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: 'Paste from clipboard',
                                  icon: const Icon(Icons.paste_rounded, size: 20),
                                  onPressed: () async {
                                    final data = await Clipboard.getData('text/plain');
                                    if (data?.text != null) {
                                      _codeController.text = data!.text!.trim();
                                      _processInput(_codeController.text);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

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
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: colors.accentSecondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colors.accentSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: colors.accentSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontFamily: 'GeneralSans',
                                fontSize: 13,
                                color: colors.accentSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
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
                      _showManualInput ? Icons.qr_code_scanner : Icons.dialpad_outlined,
                      size: 16,
                      color: colors.accentPrimary,
                    ),
                    label: Text(
                      _showManualInput
                          ? (kIsWeb ? 'Scan with webcam instead' : 'Scan QR code with camera')
                          : 'Enter 6-digit code manually',
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: colors.accentPrimary,
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

