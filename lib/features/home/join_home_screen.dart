import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
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
  final TextEditingController _pasteController = TextEditingController();
  MobileScannerController? _scannerController;

  bool _isProcessing = false;
  String? _errorMessage;
  late bool _showManualInput;

  @override
  void initState() {
    super.initState();
    _showManualInput = widget.initialShowManualInput;
    if (!_showManualInput) {
      _scannerController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _pasteController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _processQrData(String rawData) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final controller = ref.read(homeControllerProvider);
      await controller.joinHomeFromQr(rawData);

      if (mounted) {
        setState(() => _isProcessing = false);
        // Exit onboarding into the main shell
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Invalid or corrupted pairing code. Please try again.';
      });
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
            tooltip: _showManualInput ? 'Open Camera Scanner' : 'Enter Code Manually',
            icon: Icon(
              _showManualInput ? Icons.qr_code_scanner : Icons.keyboard_outlined,
              size: 20,
              color: colors.textPrimary,
            ),
            onPressed: () {
              setState(() => _showManualInput = !_showManualInput);
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
                    'Scan Partner\'s QR Code',
                    style: typography.title.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Point your camera at the pairing code on your partner\'s device to import the Home encryption key.',
                    textAlign: TextAlign.center,
                    style: typography.bodyRegular.copyWith(
                      color: colors.textMuted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_showManualInput && _scannerController != null) ...[
                    // Camera Scanner Viewfinder
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
                                    _processQrData(val);
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
                                          label: 'Paste Code Instead',
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
                    // Manual Code Paste Card
                    CoveCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MANUAL PAIRING CODE', style: typography.caption),
                          const SizedBox(height: 12),
                          CovePillInput(
                            controller: _pasteController,
                            hintText: 'Paste pairing code JSON here…',
                            prefixIcon: Icon(
                              Icons.vpn_key_outlined,
                              size: 18,
                              color: colors.textMuted,
                            ),
                            suffix: IconButton(
                              icon: const Icon(Icons.paste, size: 18),
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null) {
                                  _pasteController.text = data!.text!;
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          CovePillButton(
                            label: 'Join with Code',
                            isLoading: _isProcessing,
                            isFullWidth: true,
                            onPressed: () {
                              final text = _pasteController.text.trim();
                              if (text.isNotEmpty) {
                                _processQrData(text);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontSize: 13,
                        color: colors.accentSecondary,
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showManualInput = !_showManualInput;
                        if (!_showManualInput && _scannerController == null) {
                          _scannerController = MobileScannerController();
                        }
                      });
                    },
                    child: Text(
                      _showManualInput
                          ? 'Switch to Camera Scanner'
                          : 'Enter Pairing Code Manually',
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
