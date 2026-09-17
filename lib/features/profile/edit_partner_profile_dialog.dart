import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import 'partner_profile_controller.dart';

class EditPartnerProfileDialog extends ConsumerStatefulWidget {
  const EditPartnerProfileDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditPartnerProfileDialog(),
    );
  }

  @override
  ConsumerState<EditPartnerProfileDialog> createState() => _EditPartnerProfileDialogState();
}

class _EditPartnerProfileDialogState extends ConsumerState<EditPartnerProfileDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final partnerProfile = ref.read(partnerProfileProvider);
    _nameController = TextEditingController(text: partnerProfile.displayName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final partnerProfile = ref.watch(partnerProfileProvider);

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
                Text("Partner's Name", style: typography.headline.copyWith(fontSize: 20)),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Center(
              child: CircleAvatar(
                radius: 36,
                backgroundColor: colors.accentPrimary,
                child: Text(
                  partnerProfile.displayName.isNotEmpty
                      ? partnerProfile.displayName[0].toUpperCase()
                      : 'P',
                  style: typography.headline.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: colors.surfaceRow,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text("PARTNER'S DISPLAY NAME", style: typography.caption),
            const SizedBox(height: 8),
            CovePillInput(
              controller: _nameController,
              hintText: "Enter partner's name or nickname",
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icon(Icons.person_outline, size: 18, color: colors.textMuted),
            ),
            const SizedBox(height: 24),

            CovePillButton(
              label: 'Save',
              onPressed: () async {
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty) {
                  await ref
                      .read(partnerProfileProvider.notifier)
                      .updatePartnerDisplayName(newName);
                }
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
