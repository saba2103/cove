import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
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
    final colors = context.colors;
    final typography = context.typography;

    // If already created, display the pairing QR code directly
    if (_createdPayload != null) {
      return Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          title: Text('Invite Partner', style: typography.headline.copyWith(fontSize: 20)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Create a Home', style: typography.headline.copyWith(fontSize: 20)),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auto-generated Home Icon Mark Preview
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.surfaceCard,
                            border: Border.all(
                              color: colors.borderHairline,
                              width: 1,
                            ),
                          ),
                          child: DeterministicHomeIcon(
                            homeId: _homeNamePreview,
                            size: 48,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _homeNamePreview,
                          style: typography.title.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Mark generated automatically',
                          style: typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Home Details Card
                  CoveCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('HOME DETAILS', style: typography.caption),
                        const SizedBox(height: 14),
                        Text('Name', style: typography.bodyMedium),
                        const SizedBox(height: 6),
                        CovePillInput(
                          controller: _nameController,
                          hintText: 'e.g. Our Home, The Cabin',
                          prefixIcon: Icon(
                            Icons.home_outlined,
                            size: 18,
                            color: colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text('Description (optional)', style: typography.bodyMedium),
                        const SizedBox(height: 6),
                        CovePillInput(
                          controller: _descriptionController,
                          hintText: 'e.g. Apartment on Elm Street',
                          prefixIcon: Icon(
                            Icons.info_outline,
                            size: 18,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Encryption Info Banner
                  Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 16, color: colors.accentPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A 256-bit symmetric key will be generated. You can pair your partner immediately after.',
                          style: typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

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
