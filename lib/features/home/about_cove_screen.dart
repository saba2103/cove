import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/crypto/deterministic_home_icon.dart';
import '../../sync/key_management/pairing_qr_view.dart';
import '../../sync/providers/active_home_provider.dart';
import '../auth/auth_controller.dart';
import '../profile/currency_selector_sheet.dart';
import '../profile/edit_home_dialog.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import '../profile/user_profile_controller.dart';
import 'home_controller.dart';
import 'home_switcher_sheet.dart';

class AboutCoveScreen extends ConsumerWidget {
  const AboutCoveScreen({super.key});

  Future<void> _showPairingModal(BuildContext context, WidgetRef ref, String homeId) async {
    final payload = await ref.read(homeControllerProvider).getPairingPayload(homeId);
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
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;

    final activeHome = ref.watch(activeHomeProvider).value;
    final homes = ref.watch(userHomesProvider).value ?? [];
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final userProfile = ref.watch(userProfileProvider);
    final currentUser = ref.watch(authProvider).value;
    final currency = ref.watch(currencyPreferenceProvider);

    final homeName = activeHome?.name ?? 'Our Cove';
    final effectiveUserName = userProfile.displayName.trim().isNotEmpty
        ? userProfile.displayName.trim()
        : (currentUser?.displayName?.trim().isNotEmpty == true
            ? currentUser!.displayName!.trim()
            : 'You');
    final userInitial = effectiveUserName.isNotEmpty ? effectiveUserName[0].toUpperCase() : 'U';

    final partnerName = partnerProfile.displayName.isNotEmpty ? partnerProfile.displayName : 'Partner';
    final partnerInitial = partnerName.isNotEmpty ? partnerName[0].toUpperCase() : 'P';

    final createdDateStr = activeHome != null
        ? DateFormat('MMMM yyyy').format(activeHome.createdAt)
        : 'Recently';

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'About Sanctuary',
          style: typography.headline.copyWith(fontSize: 18),
        ),
        actions: [
          if (homes.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CovePillButton(
                label: 'Switch Home',
                isCompact: true,
                variant: CoveButtonVariant.secondary,
                onPressed: () => HomeSwitcherSheet.show(context),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // --- 1. HERO COVE MONOGRAM & NAME ---
          Center(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colors.surfaceCard,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.accentPrimary.withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.accentPrimary.withValues(alpha: 0.12),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: activeHome != null
                        ? DeterministicHomeIcon(homeId: activeHome.id, size: 44)
                        : Icon(Icons.home_outlined, size: 40, color: colors.accentPrimary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  homeName,
                  style: GoogleFonts.bodoniModa(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: colors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Established $createdDateStr · A private sanctuary for two',
                  style: typography.caption.copyWith(
                    color: colors.textMuted,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // --- 2. PARTNERS CARD ---
          CoveCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MEMBERS OF THIS COVE',
                      style: typography.caption.copyWith(
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CoveSyncTick(
                      status: hasPartner ? CoveSyncStatus.syncedToPartner : CoveSyncStatus.savedLocally,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: (userProfile.avatarUrl != null && userProfile.avatarUrl!.isNotEmpty)
                          ? colors.surfaceRow
                          : colors.accentPrimary,
                      backgroundImage: (userProfile.avatarUrl != null && userProfile.avatarUrl!.isNotEmpty)
                          ? NetworkImage(userProfile.avatarUrl!)
                          : null,
                      child: (userProfile.avatarUrl != null && userProfile.avatarUrl!.isNotEmpty)
                          ? null
                          : Text(
                              userInitial,
                              style: typography.headline.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: colors.surfaceRow,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            effectiveUserName,
                            style: typography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'You · Sanctuary Member',
                            style: typography.caption.copyWith(color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 14),
                if (hasPartner)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: (partnerProfile.avatarUrl != null && partnerProfile.avatarUrl!.isNotEmpty)
                            ? colors.surfaceRow
                            : colors.accentPrimary,
                        backgroundImage: (partnerProfile.avatarUrl != null && partnerProfile.avatarUrl!.isNotEmpty)
                            ? NetworkImage(partnerProfile.avatarUrl!)
                            : null,
                        child: (partnerProfile.avatarUrl != null && partnerProfile.avatarUrl!.isNotEmpty)
                            ? null
                            : Text(
                                partnerInitial,
                                style: typography.headline.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: colors.surfaceRow,
                                ),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              partnerName,
                              style: typography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Partner · Connected & In Sync',
                              style: typography.caption.copyWith(color: colors.accentPrimary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.surfaceRow,
                          border: Border.all(color: colors.borderHairline),
                        ),
                        child: Icon(Icons.person_add_outlined, size: 22, color: colors.accentSecondary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Partner not yet joined',
                              style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Share your pairing code to link devices.',
                              style: typography.caption.copyWith(color: colors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      CovePillButton(
                        label: 'Invite',
                        isCompact: true,
                        variant: CoveButtonVariant.secondary,
                        onPressed: () {
                          if (activeHome != null) {
                            _showPairingModal(context, ref, activeHome.id);
                          }
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- 3. SANCTUARY ACTIONS & SETTINGS ---
          Material(
            color: colors.surfaceCard,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined, color: colors.accentPrimary, size: 20),
                    title: Text('Edit Cove Name', style: typography.bodyMedium),
                    subtitle: Text(homeName, style: typography.caption),
                    trailing: Icon(Icons.chevron_right, size: 18, color: colors.textSubtle),
                    onTap: () {
                      EditHomeDialog.show(context);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.qr_code_rounded, color: colors.accentPrimary, size: 20),
                    title: Text('Pairing Code & QR', style: typography.bodyMedium),
                    subtitle: Text('Add partner or new device', style: typography.caption),
                    trailing: Icon(Icons.chevron_right, size: 18, color: colors.textSubtle),
                    onTap: () {
                      if (activeHome != null) {
                        _showPairingModal(context, ref, activeHome.id);
                      }
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.attach_money_rounded, color: colors.accentPrimary, size: 20),
                    title: Text('Home Currency', style: typography.bodyMedium),
                    subtitle: Text('${currency.name} (${currency.symbol})', style: typography.caption),
                    trailing: Icon(Icons.chevron_right, size: 18, color: colors.textSubtle),
                    onTap: () => CurrencySelectorSheet.show(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- 4. THE COVE PHILOSOPHY ---
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.surfaceCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.borderHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_outlined, size: 18, color: colors.accentPrimary),
                    const SizedBox(width: 8),
                    Text(
                      'THE COVE PHILOSOPHY',
                      style: typography.caption.copyWith(
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w600,
                        color: colors.accentPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'A private digital sanctuary crafted exclusively for two people.',
                  style: GoogleFonts.bodoniModa(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: colors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Cove was born out of a desire for intimacy and calm. In a world of public feeds and noisy social networks, Cove exists as a quiet, encrypted sanctuary where two partners align their days, cherish shared rhythms, manage household finances, and grow together in complete digital peace.',
                  style: typography.bodyMedium.copyWith(
                    color: colors.textMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                _buildPillarRow(
                  context,
                  icon: Icons.shield_outlined,
                  title: 'Zero-Knowledge Cryptography',
                  desc: 'End-to-end encrypted with LibSodium on your device. The cloud never sees your shared data.',
                ),
                const SizedBox(height: 14),
                _buildPillarRow(
                  context,
                  icon: Icons.spa_outlined,
                  title: 'Calm Household Rhythms',
                  desc: 'No addictive gamification or spam. Designed to help you live together with ease.',
                ),
                const SizedBox(height: 14),
                _buildPillarRow(
                  context,
                  icon: Icons.sync_lock_outlined,
                  title: 'Seamless Multi-Device Sync',
                  desc: 'Blind relay synchronizes changes instantaneously across iOS, Android, and Web.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),

          // --- 5. APP VERSION & FOOTER ---
          Center(
            child: Column(
              children: [
                Text(
                  'Cove v1.0.0 · Designed for Two',
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Crafted with love for the two of you ❤️',
                  style: typography.caption.copyWith(
                    fontSize: 11,
                    color: colors.textSubtle,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colors.surfaceRow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.borderHairline),
          ),
          child: Icon(icon, size: 16, color: colors.accentPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: typography.caption.copyWith(
                  color: colors.textMuted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
