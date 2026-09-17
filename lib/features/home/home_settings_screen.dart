import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../sync/crypto/deterministic_home_icon.dart';
import '../../sync/key_management/pairing_qr_view.dart';
import '../../sync/providers/active_home_provider.dart';
import '../auth/auth_controller.dart';
import '../profile/edit_partner_profile_dialog.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/user_profile_controller.dart';
import 'home_controller.dart';

/// Home Settings screen stub (fully built out in the Settings mission).
/// Displays member list, regenerate/view invite QR, and leave Home action.
class HomeSettingsScreen extends ConsumerWidget {
  const HomeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final activeHome = ref.watch(activeHomeProvider).value;
    final user = ref.watch(authProvider).value;
    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final homeController = ref.read(homeControllerProvider);

    if (activeHome == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Home Settings')),
        body: const Center(child: Text('No active home found.')),
      );
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Home Settings', style: typography.headline.copyWith(fontSize: 20)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Home Header Card
            CoveCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  DeterministicHomeIcon(homeId: activeHome.id, size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(activeHome.name, style: typography.title),
                        if (activeHome.description != null &&
                            activeHome.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(activeHome.description!, style: typography.caption),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Members Section
            Text('MEMBERS', style: typography.caption),
            const SizedBox(height: 8),
            CoveGroupedCard(
              children: [
                CoveGroupedRow(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: (userProfile.avatarUrl != null && userProfile.avatarUrl!.isNotEmpty)
                        ? colors.surfaceRow
                        : colors.accentPrimary,
                    backgroundImage: (userProfile.avatarUrl != null && userProfile.avatarUrl!.isNotEmpty)
                        ? NetworkImage(userProfile.avatarUrl!)
                        : null,
                    child: (userProfile.avatarUrl != null && userProfile.avatarUrl!.isNotEmpty)
                        ? null
                        : Text(
                            userProfile.displayName.isNotEmpty
                                ? userProfile.displayName[0].toUpperCase()
                                : 'U',
                            style: typography.headline.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.surfaceRow,
                            ),
                          ),
                  ),
                  title: Text(
                    '${userProfile.displayName} (You)',
                    style: typography.bodyMedium,
                  ),
                  subtitle: Text(user?.email ?? '', style: typography.caption),
                ),
                CoveGroupedRow(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: (partnerProfile.avatarUrl != null && partnerProfile.avatarUrl!.isNotEmpty)
                        ? colors.surfaceRow
                        : colors.accentPrimary,
                    backgroundImage: (partnerProfile.avatarUrl != null && partnerProfile.avatarUrl!.isNotEmpty)
                        ? NetworkImage(partnerProfile.avatarUrl!)
                        : null,
                    child: (partnerProfile.avatarUrl != null && partnerProfile.avatarUrl!.isNotEmpty)
                        ? null
                        : Text(
                            partnerProfile.displayName.isNotEmpty
                                ? partnerProfile.displayName[0].toUpperCase()
                                : 'P',
                            style: typography.headline.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colors.surfaceRow,
                            ),
                          ),
                  ),
                  title: Text(partnerProfile.displayName, style: typography.bodyMedium),
                  subtitle: Text('Connected via direct pairing', style: typography.caption),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, size: 16, color: colors.textMuted),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => EditPartnerProfileDialog.show(context),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: colors.accentPrimary,
                      ),
                    ],
                  ),
                  onTap: () => EditPartnerProfileDialog.show(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pairing Actions
            Text('PAIRING & ENCRYPTION', style: typography.caption),
            const SizedBox(height: 8),
            CoveCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invite Partner', style: typography.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Display the pairing QR code again to connect a new device or re-pair your partner.',
                    style: typography.caption,
                  ),
                  const SizedBox(height: 14),
                  CovePillButton(
                    label: 'View / Regenerate Invite QR',
                    isCompact: true,
                    icon: const Icon(Icons.qr_code, size: 16),
                    onPressed: () async {
                      final payload =
                          await homeController.getPairingPayload(activeHome.id);
                      if (payload != null && context.mounted) {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => Padding(
                            padding: const EdgeInsets.all(20),
                            child: PairingQrView(payload: payload),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Danger Zone: Leave Home
            CovePillButton(
              label: 'Leave Home',
              variant: CoveButtonVariant.secondary,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: colors.surfaceCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    title: Text('Leave ${activeHome.name}?', style: typography.title),
                    content: Text(
                      'You will remove the encryption key and access to this Home from this device.',
                      style: typography.bodyRegular.copyWith(color: colors.textMuted),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text('Leave', style: TextStyle(color: colors.accentSecondary)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await homeController.leaveHome(activeHome.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
