import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_tokens.dart';
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
  ConsumerState<EditPartnerProfileDialog> createState() =>
      _EditPartnerProfileDialogState();
}

class _EditPartnerProfileDialogState
    extends ConsumerState<EditPartnerProfileDialog> {
  static const double _kAvatarRadius =
      36.0; // (literal) 36dp partner avatar circle radius
  static const double _kInputIconSize =
      18.0; // (literal) 18dp input field prefix icon glyph size

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
    final cv = context.cv;
    final partnerProfile = ref.watch(partnerProfileProvider);

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
                  "Partner's Name",
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

            Center(
              child: CircleAvatar(
                radius: _kAvatarRadius,
                backgroundColor: cv.accentFill,
                child: Text(
                  partnerProfile.displayName.isNotEmpty
                      ? partnerProfile.displayName[0].toUpperCase()
                      : 'P',
                  style: CoveType.title.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cv.textOnAccent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: CoveSpace.gutter),

            Text(
              "PARTNER'S DISPLAY NAME",
              style: CoveType.capsCard.copyWith(color: cv.textSecondary),
            ),
            const SizedBox(height: CoveSpace.sm),
            CovePillInput(
              controller: _nameController,
              hintText: "Enter partner's name or nickname",
              textCapitalization: TextCapitalization.words,
              prefixIcon: Icon(
                Icons.person_outline,
                size: _kInputIconSize,
                color: cv.textSecondary,
              ),
            ),
            const SizedBox(height: CoveSpace.lg),

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
