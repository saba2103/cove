import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../auth/auth_controller.dart';
import '../backup/drive_backup_controller.dart';
import '../backup/drive_backup_section.dart';
import 'create_home_screen.dart';
import 'join_home_screen.dart';

/// First-time onboarding screen presented when a user is signed in
/// but does not yet belong to any Home.
class OnboardingChoiceScreen extends ConsumerWidget {
  const OnboardingChoiceScreen({super.key});

  static const double _kMaxCardWidth =
      440.0; // (literal) 440dp onboarding card column max width
  static const double _kHeaderBottomGap =
      36.0; // (literal) 36dp gap between onboarding header and first option card
  static const double _kBorderWidth =
      1.0; // (literal) 1dp icon circle hairline border
  static const double _kRestoreIconSize =
      18.0; // (literal) 18dp restore backup icon glyph size

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
    final user = ref.watch(authProvider).value;
    final firstName = user?.displayName?.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: Icon(
              Icons.logout_outlined,
              size: CoveSpace.gutter,
              color: cv.textSecondary,
            ),
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
          const SizedBox(width: CoveSpace.sm),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.lg,
              vertical: CoveSpace.lg,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _kMaxCardWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title Area
                  Text(
                    'Welcome, $firstName',
                    style: CoveType.slipFigure.copyWith(color: cv.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: CoveSpace.sm),
                  Text(
                    'To begin, create a shared space for you and your partner, or join an existing Home.',
                    style: CoveType.body.copyWith(color: cv.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: _kHeaderBottomGap),

                  // Option 1: Create a Home Card
                  CoveCard(
                    padding: const EdgeInsets.all(CoveSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: CoveSize.buttonRound,
                              height: CoveSize.buttonRound,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cv.surfaceRow,
                                border: Border.all(
                                  color: cv.lineHairline,
                                  width: _kBorderWidth,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.home_outlined,
                                size: CoveSpace.gutter,
                                color: cv.accentFill,
                              ),
                            ),
                            const SizedBox(width: CoveSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create a Home',
                                    style: CoveType.rowTitle.copyWith(
                                      color: cv.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: CoveSpace.xs),
                                  Text(
                                    'Start your private household ledger',
                                    style: CoveType.rowSub.copyWith(
                                      color: cv.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CoveSpace.gutter),
                        Text(
                          'You\'ll generate a secure encryption key and receive a pairing QR code to share with your partner.',
                          style: CoveType.readout.copyWith(
                            color: cv.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CoveSpace.gutter),
                        CovePillButton(
                          label: 'Create a Home',
                          isFullWidth: true,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateHomeScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: CoveSpace.gutter),

                  // Option 2: Join a Home Card
                  CoveCard(
                    padding: const EdgeInsets.all(CoveSpace.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: CoveSize.buttonRound,
                              height: CoveSize.buttonRound,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: cv.surfaceRow,
                                border: Border.all(
                                  color: cv.lineHairline,
                                  width: _kBorderWidth,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.qr_code_scanner_outlined,
                                size: CoveSpace.gutter,
                                color: cv.accentFill,
                              ),
                            ),
                            const SizedBox(width: CoveSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Join a Home',
                                    style: CoveType.rowTitle.copyWith(
                                      color: cv.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: CoveSpace.xs),
                                  Text(
                                    'Connect to your partner\'s space',
                                    style: CoveType.rowSub.copyWith(
                                      color: cv.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: CoveSpace.gutter),
                        Text(
                          kIsWeb
                              ? 'Enter the 6-digit pairing code displayed on your partner\'s device to securely join this Home.'
                              : 'Scan the pairing QR code displayed on your partner\'s device to import the Home encryption key.',
                          style: CoveType.readout.copyWith(
                            color: cv.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CoveSpace.gutter),
                        CovePillButton(
                          label: kIsWeb
                              ? 'Enter 6-Digit Code to Join'
                              : 'Scan QR Code to Join',
                          variant: CoveButtonVariant.secondary,
                          isFullWidth: true,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const JoinHomeScreen(
                                  initialShowManualInput: kIsWeb,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Option 3: Restore an encrypted Google Drive backup (new phone / reinstall)
                  if (ref.watch(driveBackupProvider).isSupported) ...[
                    const SizedBox(height: CoveSpace.gutter),
                    TextButton.icon(
                      key: const ValueKey('onboarding_restore_backup'),
                      icon: Icon(
                        Icons.settings_backup_restore_outlined,
                        size: _kRestoreIconSize,
                        color: cv.accentText,
                      ),
                      label: Text(
                        'Restore from Google Drive backup',
                        style: CoveType.rowTitle.copyWith(
                          color: cv.accentText,
                        ),
                      ),
                      onPressed: () => DriveBackupSection.runRestoreFlow(context),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
