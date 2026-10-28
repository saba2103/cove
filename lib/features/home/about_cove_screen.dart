import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
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

  static const double _kVerticalPadding =
      16.0; // (literal) 16dp vertical scroll inset and action button right margin
  static const double _kHeroCircleSize =
      88.0; // (literal) 88dp hero sanctuary monogram circle diameter
  static const double _kHeroBorderWidth =
      2.0; // (literal) 2dp hero sanctuary monogram ring stroke
  static const double _kHeroIconSize =
      44.0; // (literal) 44dp deterministic home icon glyph inside 88dp circle
  static const double _kHeroSectionGap =
      28.0; // (literal) 28dp vertical gap below hero sanctuary monogram
  static const double _kPhilosophySectionGap =
      36.0; // (literal) 36dp vertical gap below philosophy card
  static const double _kChevronSize =
      18.0; // (literal) 18dp list tile trailing chevron and philosophy header icon
  static const double _kPillarIconSize =
      16.0; // (literal) 16dp philosophy pillar icon glyph
  static const double _kPillarIconBoxRadius =
      10.0; // (literal) 10dp philosophy pillar icon box corner radius

  Future<void> _showPairingModal(
    BuildContext context,
    WidgetRef ref,
    String homeId,
  ) async {
    final payload = await ref
        .read(homeControllerProvider)
        .getPairingPayload(homeId);
    if (payload != null && context.mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(CoveSpace.gutter),
          child: PairingQrView(payload: payload),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;

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
    final userInitial = effectiveUserName.isNotEmpty
        ? effectiveUserName[0].toUpperCase()
        : 'U';

    final partnerName = partnerProfile.displayName.isNotEmpty
        ? partnerProfile.displayName
        : 'Partner';
    final partnerInitial = partnerName.isNotEmpty
        ? partnerName[0].toUpperCase()
        : 'P';

    final createdDateStr = activeHome != null
        ? DateFormat('MMMM yyyy').format(activeHome.createdAt)
        : 'Recently';

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      appBar: AppBar(
        title: Text(
          'About Sanctuary',
          style: CoveType.letter.copyWith(color: cv.textPrimary),
        ),
        actions: [
          if (homes.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: _kVerticalPadding),
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
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.gutter,
          vertical: _kVerticalPadding,
        ),
        children: [
          // --- 1. HERO COVE MONOGRAM & NAME ---
          Center(
            child: Column(
              children: [
                const SizedBox(height: CoveSpace.sm),
                Container(
                  width: _kHeroCircleSize,
                  height: _kHeroCircleSize,
                  decoration: BoxDecoration(
                    color: cv.surfaceCard,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: cv.accentFill.withValues(alpha: 0.4),
                      width: _kHeroBorderWidth,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cv.accentFill.withValues(alpha: 0.12),
                        blurRadius: CoveSpace.lg,
                        spreadRadius: CoveSpace.xs,
                      ),
                    ],
                  ),
                  child: Center(
                    child: activeHome != null
                        ? DeterministicHomeIcon(
                            homeId: activeHome.id,
                            size: _kHeroIconSize,
                          )
                        : Icon(
                            Icons.home_outlined,
                            size: CoveSize.buttonRound,
                            color: cv.accentFill,
                          ),
                  ),
                ),
                const SizedBox(height: _kVerticalPadding),
                Text(
                  homeName,
                  style: CoveType.slipFigure.copyWith(
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: cv.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: CoveSpace.xs),
                Text(
                  'Established $createdDateStr · A private sanctuary for two',
                  style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: _kHeroSectionGap),

          // --- 2. PARTNERS CARD ---
          CoveCard(
            padding: const EdgeInsets.all(CoveSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MEMBERS OF THIS COVE',
                      style: CoveType.capsCard.copyWith(
                        color: cv.textSecondary,
                      ),
                    ),
                    CoveSyncTick(
                      status: hasPartner
                          ? CoveSyncStatus.syncedToPartner
                          : CoveSyncStatus.savedLocally,
                    ),
                  ],
                ),
                const SizedBox(height: _kVerticalPadding),
                Row(
                  children: [
                    CircleAvatar(
                      radius: CoveSpace.lg,
                      backgroundColor:
                          (userProfile.avatarUrl != null &&
                              userProfile.avatarUrl!.isNotEmpty)
                          ? cv.surfaceRow
                          : cv.accentFill,
                      backgroundImage:
                          (userProfile.avatarUrl != null &&
                              userProfile.avatarUrl!.isNotEmpty)
                          ? NetworkImage(userProfile.avatarUrl!)
                          : null,
                      child:
                          (userProfile.avatarUrl != null &&
                              userProfile.avatarUrl!.isNotEmpty)
                          ? null
                          : Text(
                              userInitial,
                              style: CoveType.slipTitle.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cv.surfaceRow,
                              ),
                            ),
                    ),
                    const SizedBox(width: CoveSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            effectiveUserName,
                            style: CoveType.rowTitle.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cv.textPrimary,
                            ),
                          ),
                          Text(
                            'You · Sanctuary Member',
                            style: CoveType.rowSub.copyWith(
                              color: cv.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: CoveSpace.md),
                Divider(color: cv.lineHairline),
                const SizedBox(height: CoveSpace.md),
                if (hasPartner)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: CoveSpace.lg,
                        backgroundColor:
                            (partnerProfile.avatarUrl != null &&
                                partnerProfile.avatarUrl!.isNotEmpty)
                            ? cv.surfaceRow
                            : cv.accentFill,
                        backgroundImage:
                            (partnerProfile.avatarUrl != null &&
                                partnerProfile.avatarUrl!.isNotEmpty)
                            ? NetworkImage(partnerProfile.avatarUrl!)
                            : null,
                        child:
                            (partnerProfile.avatarUrl != null &&
                                partnerProfile.avatarUrl!.isNotEmpty)
                            ? null
                            : Text(
                                partnerInitial,
                                style: CoveType.slipTitle.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cv.surfaceRow,
                                ),
                              ),
                      ),
                      const SizedBox(width: CoveSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              partnerName,
                              style: CoveType.rowTitle.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cv.textPrimary,
                              ),
                            ),
                            Text(
                              'Partner · Connected & In Sync',
                              style: CoveType.rowSub.copyWith(
                                color: cv.accentText,
                              ),
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
                        width: CoveSize.hit,
                        height: CoveSize.hit,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cv.surfaceRow,
                          border: Border.all(color: cv.lineHairline),
                        ),
                        child: Icon(
                          Icons.person_add_outlined,
                          size: CoveSize.avatarInline,
                          color: cv.statusAlert,
                        ),
                      ),
                      const SizedBox(width: CoveSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Partner not yet joined',
                              style: CoveType.rowTitle.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cv.textPrimary,
                              ),
                            ),
                            Text(
                              'Share your pairing code to link devices.',
                              style: CoveType.rowSub.copyWith(
                                color: cv.textSecondary,
                              ),
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
          const SizedBox(height: CoveSpace.gutter),

          // --- 3. SANCTUARY ACTIONS & SETTINGS ---
          Material(
            color: cv.surfaceCard,
            shape: CoveShape.border(CoveRadius.card),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kVerticalPadding,
                vertical: CoveSpace.sm,
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.edit_outlined,
                      color: cv.accentFill,
                      size: CoveSpace.gutter,
                    ),
                    title: Text(
                      'Edit Cove Name',
                      style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                    ),
                    subtitle: Text(
                      homeName,
                      style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: _kChevronSize,
                      color: cv.textTertiary,
                    ),
                    onTap: () {
                      EditHomeDialog.show(context);
                    },
                  ),
                  Divider(color: cv.lineHairline),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.qr_code_rounded,
                      color: cv.accentFill,
                      size: CoveSpace.gutter,
                    ),
                    title: Text(
                      'Pairing Code & QR',
                      style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                    ),
                    subtitle: Text(
                      'Add partner or new device',
                      style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: _kChevronSize,
                      color: cv.textTertiary,
                    ),
                    onTap: () {
                      if (activeHome != null) {
                        _showPairingModal(context, ref, activeHome.id);
                      }
                    },
                  ),
                  Divider(color: cv.lineHairline),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.attach_money_rounded,
                      color: cv.accentFill,
                      size: CoveSpace.gutter,
                    ),
                    title: Text(
                      'Home Currency',
                      style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                    ),
                    subtitle: Text(
                      '${currency.name} (${currency.symbol})',
                      style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      size: _kChevronSize,
                      color: cv.textTertiary,
                    ),
                    onTap: () => CurrencySelectorSheet.show(context),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: CoveSpace.lg),

          // --- 4. THE COVE PHILOSOPHY ---
          Container(
            padding: const EdgeInsets.all(CoveSpace.gutter),
            decoration: CoveShape.decoration(
              CoveRadius.card,
              color: cv.surfaceCard,
              side: BorderSide(color: cv.lineHairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_outlined,
                      size: _kChevronSize,
                      color: cv.accentFill,
                    ),
                    const SizedBox(width: CoveSpace.sm),
                    Text(
                      'THE COVE PHILOSOPHY',
                      style: CoveType.capsCard.copyWith(color: cv.accentText),
                    ),
                  ],
                ),
                const SizedBox(height: CoveSpace.md),
                Text(
                  'A private digital sanctuary crafted exclusively for two people.',
                  style: CoveType.letter.copyWith(
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: cv.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: CoveSpace.sm),
                Text(
                  'Cove was born out of a desire for intimacy and calm. In a world of public feeds and noisy social networks, Cove exists as a quiet, encrypted sanctuary where two partners align their days, cherish shared habits, manage household finances, and grow together in complete digital peace.',
                  style: CoveType.readout.copyWith(
                    color: cv.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: CoveSpace.gutter),
                _buildPillarRow(
                  context,
                  icon: Icons.shield_outlined,
                  title: 'Zero-Knowledge Cryptography',
                  desc:
                      'End-to-end encrypted with LibSodium on your device. The cloud never sees your shared data.',
                ),
                const SizedBox(height: CoveSpace.md),
                _buildPillarRow(
                  context,
                  icon: Icons.spa_outlined,
                  title: 'Calm Household Habits',
                  desc:
                      'No addictive gamification or spam. Designed to help you live together with ease.',
                ),
                const SizedBox(height: CoveSpace.md),
                _buildPillarRow(
                  context,
                  icon: Icons.sync_lock_outlined,
                  title: 'Seamless Multi-Device Sync',
                  desc:
                      'Blind relay synchronizes changes instantaneously across iOS, Android, and Web.',
                ),
              ],
            ),
          ),
          const SizedBox(height: _kPhilosophySectionGap),

          // --- 5. APP VERSION & FOOTER ---
          Center(
            child: Column(
              children: [
                Text(
                  'Cove v2.0-alpha.1 (2) · Designed for Two',
                  style: CoveType.rowSub.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cv.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: CoveSpace.xs),
                Text(
                  'Crafted with love for the two of you ❤️',
                  style: CoveType.barLabel.copyWith(
                    fontWeight: FontWeight.w400,
                    color: cv.textTertiary,
                  ),
                ),
                const SizedBox(height: CoveSpace.lg),
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
    final cv = context.cv;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: CoveSize.avatarHeader,
          height: CoveSize.avatarHeader,
          decoration: CoveShape.decoration(
            _kPillarIconBoxRadius,
            color: cv.surfaceRow,
            side: BorderSide(color: cv.lineHairline),
          ),
          child: Icon(icon, size: _kPillarIconSize, color: cv.accentFill),
        ),
        const SizedBox(width: CoveSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: CoveType.readout.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cv.textPrimary,
                ),
              ),
              const SizedBox(height: CoveSpace.xs),
              Text(
                desc,
                style: CoveType.rowSub.copyWith(
                  color: cv.textSecondary,
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
