import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/cove_theme.dart';
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
      final userId = user?.id ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
      final ext = picked.name.split('.').lastOrNull?.toLowerCase() ?? 'jpg';
      final mime = (ext == 'png')
          ? 'image/png'
          : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
      final fileName = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final supabase = ref.read(supabaseClientProvider);
      if (supabase != null) {
        await supabase.storage.from('avatars').uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        );
        final publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);
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
    _pendingUseInitials = profile.avatarUrl == null || profile.avatarUrl!.isEmpty;
    _avatarUrlController = TextEditingController(text: profile.avatarUrl ?? '');
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
    final colors = context.colors;
    final typography = context.typography;
    final profile = ref.watch(userProfileProvider);
    final currentName = _nameController.text.trim();
    final initialLetter = currentName.isNotEmpty
        ? currentName[0].toUpperCase()
        : (profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : 'U');

    final hasPhoto = !_pendingUseInitials && _pendingAvatarUrl != null && _pendingAvatarUrl!.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 24,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Profile', style: typography.headline.copyWith(fontSize: 20)),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Preview Avatar with Camera Tap & Upload Overlay
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _isUploading ? null : () => _pickAndUploadImage(ImageSource.gallery),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: hasPhoto ? colors.surfaceRow : colors.accentPrimary,
                      backgroundImage: hasPhoto ? NetworkImage(_pendingAvatarUrl!.trim()) : null,
                      child: _isUploading
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: colors.accentPrimary,
                              ),
                            )
                          : (!hasPhoto
                              ? Text(
                                  initialLetter,
                                  style: typography.headline.copyWith(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: colors.surfaceRow,
                                  ),
                                )
                              : null),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploading ? null : () => _pickAndUploadImage(ImageSource.gallery),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colors.accentPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.surfaceCard, width: 2),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 15,
                          color: colors.surfaceRow,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Image Source Options: Upload Photo | Camera | Use Initials
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(
                  avatar: Icon(Icons.photo_library_outlined, size: 16, color: colors.accentPrimary),
                  label: Text('Upload Photo', style: typography.caption.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500)),
                  backgroundColor: colors.surfaceRow,
                  side: BorderSide(color: colors.borderHairline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: _isUploading ? null : () => _pickAndUploadImage(ImageSource.gallery),
                ),
                ActionChip(
                  avatar: Icon(Icons.camera_alt_outlined, size: 16, color: colors.accentPrimary),
                  label: Text('Camera', style: typography.caption.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500)),
                  backgroundColor: colors.surfaceRow,
                  side: BorderSide(color: colors.borderHairline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: _isUploading ? null : () => _pickAndUploadImage(ImageSource.camera),
                ),
                if (hasPhoto)
                  ActionChip(
                    avatar: Icon(Icons.account_circle_outlined, size: 16, color: colors.textMuted),
                    label: Text('Use Initials', style: typography.caption.copyWith(color: colors.textMuted)),
                    backgroundColor: colors.surfaceRow,
                    side: BorderSide(color: colors.borderHairline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  avatar: Icon(Icons.link, size: 16, color: colors.textMuted),
                  label: Text(_showAvatarInput ? 'Hide URL' : 'Link URL', style: typography.caption.copyWith(color: colors.textMuted)),
                  backgroundColor: colors.surfaceRow,
                  side: BorderSide(color: colors.borderHairline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () {
                    setState(() {
                      _showAvatarInput = !_showAvatarInput;
                    });
                  },
                ),
                if (profile.hasCustomName || profile.hasCustomAvatar)
                  ActionChip(
                    avatar: Icon(Icons.restore, size: 16, color: colors.accentSecondary),
                    label: Text('Reset', style: typography.caption.copyWith(color: colors.accentSecondary)),
                    backgroundColor: colors.surfaceRow,
                    side: BorderSide(color: colors.borderHairline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              const SizedBox(height: 10),
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

            const SizedBox(height: 18),

            // Display Name
            Text('DISPLAY NAME', style: typography.caption),
            const SizedBox(height: 8),
            CovePillInput(
              controller: _nameController,
              hintText: 'Your name as seen by partner',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 6),
            Text(
              'This is what your partner sees in the app, saved directly to your cloud profile.',
              style: typography.caption.copyWith(color: colors.textMuted, fontSize: 11),
            ),

            const SizedBox(height: 20),

            // Read-Only Google Email
            Text('GOOGLE ACCOUNT EMAIL', style: typography.caption),
            const SizedBox(height: 8),
            CoveCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: colors.textSubtle),
                  const SizedBox(width: 10),
                  Text(
                    profile.email.isNotEmpty ? profile.email : 'No email associated',
                    style: typography.bodyMedium.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Save Button (Commits all changes atomically)
            CovePillButton(
              label: _isSaving ? 'Saving Changes...' : 'Save Changes',
              onPressed: _isSaving
                  ? null
                  : () async {
                      final newName = _nameController.text.trim();
                      if (newName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Display name cannot be empty')),
                        );
                        return;
                      }

                      setState(() => _isSaving = true);
                      await ref.read(userProfileProvider.notifier).saveProfile(
                            displayName: newName,
                            avatarUrl: _pendingUseInitials ? null : _pendingAvatarUrl,
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
