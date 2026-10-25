import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../sync/crypto/deterministic_home_icon.dart';
import '../../sync/key_management/pairing_payload.dart';
import '../../sync/key_management/pairing_qr_view.dart';
import 'home_controller.dart';

class CreateHomeScreen extends ConsumerStatefulWidget {
  const CreateHomeScreen({super.key});

  @override
  ConsumerState<CreateHomeScreen> createState() => _CreateHomeScreenState();
}

class _CreateHomeScreenState extends ConsumerState<CreateHomeScreen> {
  static const double _kQrVerticalPadding =
      16.0; // (literal) 16dp QR pairing view vertical inset
  static const double _kMaxCardWidth =
      440.0; // (literal) 440dp create home card column max width
  static const double _kBorderWidth =
      1.0; // (literal) 1dp home icon circle hairline border
  static const double _kInputIconSize =
      18.0; // (literal) 18dp input field prefix icon glyph size
  static const double _kActionTopGap =
      28.0; // (literal) 28dp gap above create home submit button

  final TextEditingController _nameController =
      TextEditingController(text: 'Our Home');
  final TextEditingController _descriptionController = TextEditingController();

  bool _isCreating = false;
  PairingPayload? _createdPayload;
  String _homeNamePreview = 'Our Home';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() {
        _homeNamePreview = _nameController.text.trim().isEmpty
            ? 'Our Home'
            : _nameController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final name = _nameController.text.trim().isEmpty
        ? 'Our Home'
        : _nameController.text.trim();
    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();

    setState(() => _isCreating = true);

    try {
      final controller = ref.read(homeControllerProvider);
      final payload = await controller.createHome(
        name: name,
        description: description,
      );

      setState(() {
        _isCreating = false;
        _createdPayload = payload;
      });
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create home: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;

    // If already created, display the pairing QR code directly
    if (_createdPayload != null) {
      return Scaffold(
        backgroundColor: cv.surfaceCanvas,
        appBar: AppBar(
          title: Text(
            'Invite Partner',
            style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.lg,
              vertical: _kQrVerticalPadding,
            ),
            child: PairingQrView(
              payload: _createdPayload!,
              onDone: () {
                // Exit onboarding into the main shell
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      appBar: AppBar(
        title: Text(
          'Create a Home',
          style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.lg,
              vertical: CoveSpace.gutter,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxCardWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auto-generated Home Icon Mark Preview
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(_kQrVerticalPadding),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cv.surfaceCard,
                            border: Border.all(
                              color: cv.lineHairline,
                              width: _kBorderWidth,
                            ),
                          ),
                          child: DeterministicHomeIcon(
                            homeId: _homeNamePreview,
                            size: CoveSize.hit,
                          ),
                        ),
                        const SizedBox(height: CoveSpace.md),
                        Text(
                          _homeNamePreview,
                          style: CoveType.rowTitle.copyWith(
                            color: cv.textPrimary,
                          ),
                        ),
                        const SizedBox(height: CoveSpace.xs),
                        Text(
                          'Mark generated automatically',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CoveSpace.section),

                  // Home Details Card
                  CoveCard(
                    padding: const EdgeInsets.all(CoveSpace.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HOME DETAILS',
                          style: CoveType.capsCard.copyWith(
                            color: cv.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CoveSpace.md),
                        Text(
                          'Name',
                          style: CoveType.rowTitle.copyWith(
                            color: cv.textPrimary,
                          ),
                        ),
                        const SizedBox(height: CoveSpace.sm),
                        CovePillInput(
                          controller: _nameController,
                          hintText: 'e.g. Our Home, The Cabin',
                          prefixIcon: Icon(
                            Icons.home_outlined,
                            size: _kInputIconSize,
                            color: cv.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CoveSpace.gutter),
                        Text(
                          'Description (optional)',
                          style: CoveType.rowTitle.copyWith(
                            color: cv.textPrimary,
                          ),
                        ),
                        const SizedBox(height: CoveSpace.sm),
                        CovePillInput(
                          controller: _descriptionController,
                          hintText: 'e.g. Apartment on Elm Street',
                          prefixIcon: Icon(
                            Icons.info_outline,
                            size: _kInputIconSize,
                            color: cv.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CoveSpace.lg),

                  // Encryption Info Banner
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: _kQrVerticalPadding,
                        color: cv.accentFill,
                      ),
                      const SizedBox(width: CoveSpace.sm),
                      Expanded(
                        child: Text(
                          'A 256-bit symmetric key will be generated. You can pair your partner immediately after.',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: _kActionTopGap),

                  // Create Action
                  CovePillButton(
                    label: 'Create Home & Generate Key',
                    isLoading: _isCreating,
                    isFullWidth: true,
                    onPressed: _handleCreate,
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
