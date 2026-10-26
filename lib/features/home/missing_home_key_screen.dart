import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_seed_card.dart';
import '../../sync/providers/first_run_provider.dart';
import '../backup/drive_backup_section.dart';
import 'join_home_screen.dart';

/// Full-screen recovery state shown when the active home has no symmetric key
/// on this device (`design/specs/17-invite-and-keys.md` §3).
///
/// Never invents a new key for an existing home; offers restoring from the
/// encrypted Google Drive backup or joining again with a pairing code.
class MissingHomeKeyScreen extends ConsumerWidget {
  const MissingHomeKeyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
    final partnerName = resolveFirstRunPartnerName(ref);

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: CovePageInsets(
        bottom: true,
        child: CoveMaxWidth(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: CoveSpace.section),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: CoveSeedArt(CoveSeedArtKind.key),
                    ),
                    const SizedBox(height: CoveSpace.lg),
                    Text(
                      "This phone doesn't have your home's key",
                      textAlign: TextAlign.center,
                      style: CoveType.title.copyWith(
                        color: cv.textPrimary,
                      ),
                    ),
                    const SizedBox(height: CoveSpace.sm),
                    Text(
                      'Restore it from your Drive backup, or ask '
                      '$partnerName to send a key again.',
                      textAlign: TextAlign.center,
                      style: CoveType.body.copyWith(
                        color: cv.textSecondary,
                      ),
                    ),
                    const SizedBox(height: CoveSpace.section),
                    CovePillButton(
                      key: const ValueKey('missing_key_restore_backup'),
                      label: 'Restore from backup',
                      isFullWidth: true,
                      onPressed: () =>
                          DriveBackupSection.runRestoreFlow(context),
                    ),
                    const SizedBox(height: CoveSpace.md),
                    CovePillButton(
                      key: const ValueKey('missing_key_join_with_code'),
                      label: 'Join again with a code',
                      variant: CoveButtonVariant.secondary,
                      isFullWidth: true,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const JoinHomeScreen(
                              initialShowManualInput: true,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
