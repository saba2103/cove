import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import 'user_profile_controller.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  const EditProfileDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditProfileDialog(),
    );
  }

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  static const double _kSpinnerStroke =
      2.5; // (literal) 2.5dp avatar upload spinner stroke
  static const double _kCameraBadgeBorderWidth =
      2.0; // (literal) 2dp camera badge border width
  static const double _kCameraBadgeIconSize =
      15.0; // (literal) 15dp camera badge icon size
  static const double _kChipIconSize =
      16.0; // (literal) 16dp action chip icon size
  static const double _kSaveButtonTopGap =
      28.0; // (literal) 28dp gap above save profile button

  late final TextEditingController _nameController;
  late final TextEditingController _avatarUrlController;
  late bool _pendingUseInitials;
  late String? _pendingAvatarUrl;
  bool _showAvatarInput = false;
  bool _isSaving = false;
  bool _isUploading = false;

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);

      final bytes = await picked.readAsBytes();
      final user = ref.read(authProvider).value;
      final userId = user?.id ?? 'user_${clock.now().millisecondsSinceEpoch}';
      final ext = picked.name.split('.').lastOrNull?.toLowerCase() ?? 'jpg';
      final mime = (ext == 'png')
          ? 'image/png'
          : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
      final fileName =
          '$userId/avatar_${clock.now().millisecondsSinceEpoch}.$ext';

      final supabase = ref.read(supabaseClientProvider);
      if (supabase != null) {
        await supabase.storage.from('avatars').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        );
        final publicUrl =
            supabase.storage.from('avatars').getPublicUrl(fileName);
        if (mounted) {
          setState(() {
            _pendingAvatarUrl = publicUrl;
            _pendingUseInitials = false;
            _avatarUrlController.text = publicUrl;
            _showAvatarInput = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final profile = ref.read(userProfileProvider);
    _nameController = TextEditingController(text: profile.displayName);
    _pendingAvatarUrl = profile.avatarUrl;
    _pendingUseInitials =
        profile.avatarUrl == null || profile.avatarUrl!.isEmpty;
    _avatarUrlController =
        TextEditingController(text: profile.avatarUrl ?? '');
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final profile = ref.watch(userProfileProvider);
    final currentName = _nameController.text.trim();
    final initialLetter = currentName.isNotEmpty
        ? currentName[0].toUpperCase()
        : (profile.displayName.isNotEmpty
            ? profile.displayName[0].toUpperCase()
            : 'U');

    final hasPhoto = !_pendingUseInitials &&
        _pendingAvatarUrl != null &&
        _pendingAvatarUrl!.trim().isNotEmpty;

    const chipShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(CoveRadius.card)),
    );

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + CoveSpace.lg,
        left: CoveSpace.gutter,
        right: CoveSpace.gutter,
        top: CoveSpace.lg,
      ),
      decoration: BoxDecoration(
        color: cv.surfaceSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CoveRadius.sheet),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit Profile',
                  style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: cv.textSecondary,
                    size: CoveSpace.gutter,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.gutter),

            // Live Preview Avatar with Camera Tap & Upload Overlay
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _isUploading
                        ? null
                        : () => _pickAndUploadImage(ImageSource.gallery),
                    child: CircleAvatar(
                      radius: CoveSize.buttonRound,
                      backgroundColor:
                          hasPhoto ? cv.surfaceRow : cv.accentFill,
                      backgroundImage: hasPhoto
                          ? NetworkImage(_pendingAvatarUrl!.trim())
                          : null,
                      child: _isUploading
                          ? SizedBox(
                              width: CoveSize.avatarRow,
                              height: CoveSize.avatarRow,
                              child: CircularProgressIndicator(
                                strokeWidth: _kSpinnerStroke,
                                color: cv.accentFill,
                              ),
                            )
                          : (!hasPhoto
                              ? Text(
                                  initialLetter,
                                  style: CoveType.slipFigure.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cv.textOnAccent,
                                  ),
                                )
                              : null),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploading
                          ? null
                          : () => _pickAndUploadImage(ImageSource.gallery),
                      child: Container(
                        padding: const EdgeInsets.all(CoveSpace.xs),
                        decoration: BoxDecoration(
                          color: cv.accentFill,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cv.surfaceSheet,
                            width: _kCameraBadgeBorderWidth,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: _kCameraBadgeIconSize,
                          color: cv.textOnAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: CoveSpace.md),

            // Image Source Options: Upload Photo | Camera | Use Initials
            Wrap(
              alignment: WrapAlignment.center,
              spacing: CoveSpace.sm,
              runSpacing: CoveSpace.xs,
              children: [
                ActionChip(
                  avatar: Icon(
                    Icons.photo_library_outlined,
                    size: _kChipIconSize,
                    color: cv.accentFill,
                  ),
                  label: Text(
                    'Upload Photo',
                    style: CoveType.rowSub.copyWith(
                      color: cv.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: cv.surfaceRow,
                  side: BorderSide(color: cv.lineHairline),
                  shape: chipShape,
                  onPressed: _isUploading
                      ? null
                      : () => _pickAndUploadImage(ImageSource.gallery),
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.camera_alt_outlined,
                    size: _kChipIconSize,
                    color: cv.accentFill,
                  ),
                  label: Text(
                    'Camera',
                    style: CoveType.rowSub.copyWith(
                      color: cv.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: cv.surfaceRow,
                  side: BorderSide(color: cv.lineHairline),
                  shape: chipShape,
                  onPressed: _isUploading
                      ? null
                      : () => _pickAndUploadImage(ImageSource.camera),
                ),
                if (hasPhoto)
                  ActionChip(
                    avatar: Icon(
                      Icons.account_circle_outlined,
                      size: _kChipIconSize,
                      color: cv.textSecondary,
                    ),
                    label: Text(
                      'Use Initials',
                      style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                    ),
                    backgroundColor: cv.surfaceRow,
                    side: BorderSide(color: cv.lineHairline),
                    shape: chipShape,
                    onPressed: () {
                      setState(() {
                        _pendingUseInitials = true;
                        _pendingAvatarUrl = null;
                        _avatarUrlController.clear();
                        _showAvatarInput = false;
                      });
                    },
                  ),
                ActionChip(
                  avatar: Icon(
                    Icons.link,
                    size: _kChipIconSize,
                    color: cv.textSecondary,
                  ),
                  label: Text(
                    _showAvatarInput ? 'Hide URL' : 'Link URL',
                    style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                  ),
                  backgroundColor: cv.surfaceRow,
                  side: BorderSide(color: cv.lineHairline),
                  shape: chipShape,
                  onPressed: () {
                    setState(() {
                      _showAvatarInput = !_showAvatarInput;
                    });
                  },
                ),
                if (profile.hasCustomName || profile.hasCustomAvatar)
                  ActionChip(
                    avatar: Icon(
                      Icons.restore,
                      size: _kChipIconSize,
                      color: cv.statusAlertText,
                    ),
                    label: Text(
                      'Reset',
                      style: CoveType.rowSub.copyWith(
                        color: cv.statusAlertText,
                      ),
                    ),
                    backgroundColor: cv.surfaceRow,
                    side: BorderSide(color: cv.lineHairline),
                    shape: chipShape,
                    onPressed: () {
                      final user = ref.read(authProvider).value;
                      setState(() {
                        _nameController.text = user?.displayName ?? 'You';
                        _pendingAvatarUrl = user?.avatarUrl;
                        _pendingUseInitials = user?.avatarUrl == null;
                        _avatarUrlController.text = user?.avatarUrl ?? '';
                        _showAvatarInput = false;
                      });
                    },
                  ),
              ],
            ),

            if (_showAvatarInput) ...[
              const SizedBox(height: CoveSpace.sm),
              CovePillInput(
                controller: _avatarUrlController,
                hintText: 'Image URL (https://...)',
                keyboardType: TextInputType.url,
                textCapitalization: TextCapitalization.none,
                onChanged: (val) {
                  setState(() {
                    if (val.trim().isNotEmpty) {
                      _pendingAvatarUrl = val.trim();
                      _pendingUseInitials = false;
                    } else {
                      _pendingAvatarUrl = null;
                      _pendingUseInitials = true;
                    }
                  });
                },
              ),
            ],

            const SizedBox(height: CoveSpace.gutter),

            // Display Name
            Text(
              'DISPLAY NAME',
              style: CoveType.capsCard.copyWith(color: cv.textSecondary),
            ),
            const SizedBox(height: CoveSpace.sm),
            CovePillInput(
              controller: _nameController,
              hintText: 'Your name as seen by partner',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: CoveSpace.sm),
            Text(
              'This is what your partner sees in the app, saved directly to your cloud profile.',
              style: CoveType.rowSub.copyWith(color: cv.textSecondary),
            ),

            const SizedBox(height: CoveSpace.gutter),

            // Read-Only Google Email
            Text(
              'GOOGLE ACCOUNT EMAIL',
              style: CoveType.capsCard.copyWith(color: cv.textSecondary),
            ),
            const SizedBox(height: CoveSpace.sm),
            CoveCard(
              padding: const EdgeInsets.symmetric(
                horizontal: _kChipIconSize,
                vertical: CoveSpace.md,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: _kChipIconSize,
                    color: cv.textTertiary,
                  ),
                  const SizedBox(width: CoveSpace.sm),
                  Text(
                    profile.email.isNotEmpty
                        ? profile.email
                        : 'No email associated',
                    style: CoveType.rowTitle.copyWith(
                      color: cv.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: _kSaveButtonTopGap),

            // Save Button (Commits all changes atomically)
            CovePillButton(
              label: _isSaving ? 'Saving Changes...' : 'Save Changes',
              onPressed: _isSaving
                  ? null
                  : () async {
                      final newName = _nameController.text.trim();
                      if (newName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Display name cannot be empty'),
                          ),
                        );
                        return;
                      }

                      setState(() => _isSaving = true);
                      await ref.read(userProfileProvider.notifier).saveProfile(
                            displayName: newName,
                            avatarUrl: _pendingUseInitials
                                ? null
                                : _pendingAvatarUrl,
                            useInitials: _pendingUseInitials,
                          );

                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
