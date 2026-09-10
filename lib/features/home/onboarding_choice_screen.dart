import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../auth/auth_controller.dart';
import 'create_home_screen.dart';
import 'join_home_screen.dart';

/// First-time onboarding screen presented when a user is signed in
/// but does not yet belong to any Home.
class OnboardingChoiceScreen extends ConsumerWidget {
  const OnboardingChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final user = ref.watch(authProvider).value;
    final firstName = user?.displayName?.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: Icon(
              Icons.logout_outlined,
              size: 20,
              color: colors.textMuted,
            ),
            onPressed: () {
              ref.read(authProvider.notifier).signOut();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Title Area
                  Text(
                    'Welcome, $firstName',
                    style: typography.displayLarge.copyWith(fontSize: 32),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'To begin, create a shared space for you and your partner, or join an existing Home.',
                    style: typography.bodyRegular.copyWith(
                      color: colors.textMuted,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Option 1: Create a Home Card
                  CoveCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.surfaceRow,
                                border: Border.all(
                                  color: colors.borderHairline,
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.home_outlined,
                                size: 20,
                                color: colors.accentPrimary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create a Home',
                                    style: typography.title.copyWith(fontSize: 17),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Start your private household ledger',
                                    style: typography.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'You\'ll generate a secure encryption key and receive a pairing QR code to share with your partner.',
                          style: typography.bodyRegular.copyWith(
                            color: colors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
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
                  const SizedBox(height: 18),

                  // Option 2: Join a Home Card
                  CoveCard(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.surfaceRow,
                                border: Border.all(
                                  color: colors.borderHairline,
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.qr_code_scanner_outlined,
                                size: 20,
                                color: colors.accentPrimary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Join a Home',
                                    style: typography.title.copyWith(fontSize: 17),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Connect to your partner\'s space',
                                    style: typography.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Scan the pairing QR code displayed on your partner\'s device to import the Home encryption key.',
                          style: typography.bodyRegular.copyWith(
                            color: colors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        CovePillButton(
                          label: 'Scan QR Code to Join',
                          variant: CoveButtonVariant.secondary,
                          isFullWidth: true,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const JoinHomeScreen(),
                              ),
                            );
                          },
                        ),
                      ],
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
