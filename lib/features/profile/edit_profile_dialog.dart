import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
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

            // Live Preview Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: hasPhoto ? colors.surfaceRow : colors.accentPrimary,
                    backgroundImage: hasPhoto ? NetworkImage(_pendingAvatarUrl!.trim()) : null,
                    child: !hasPhoto
                        ? Text(
                            initialLetter,
                            style: typography.headline.copyWith(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: colors.surfaceRow,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Toggle Initials / Photo URL (Buffered locally)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasPhoto)
                  TextButton.icon(
                    icon: Icon(Icons.account_circle_outlined, size: 16, color: colors.accentPrimary),
                    label: Text('Use Initials Avatar', style: typography.caption.copyWith(color: colors.accentPrimary)),
                    onPressed: () {
                      setState(() {
                        _pendingUseInitials = true;
                        _pendingAvatarUrl = null;
                        _avatarUrlController.clear();
                        _showAvatarInput = false;
                      });
                    },
                  )
                else
                  TextButton.icon(
                    icon: Icon(Icons.add_photo_alternate_outlined, size: 16, color: colors.accentPrimary),
                    label: Text('Add Photo URL', style: typography.caption.copyWith(color: colors.accentPrimary)),
                    onPressed: () {
                      setState(() {
                        _showAvatarInput = !_showAvatarInput;
                      });
                    },
                  ),
                if (profile.hasCustomName || profile.hasCustomAvatar) ...[
                  const SizedBox(width: 8),
                  TextButton(
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
                    child: Text('Reset to Defaults', style: typography.caption.copyWith(color: colors.textMuted)),
                  ),
                ],
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
