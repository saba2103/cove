import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_toggle_switch.dart';
import '../../sync/crypto/deterministic_home_icon.dart';
import '../../sync/db/app_database.dart';
import '../../sync/key_management/pairing_qr_view.dart';
import '../../sync/providers/active_home_provider.dart';
import '../auth/auth_controller.dart';
import '../home/home_controller.dart';
import '../home/home_switcher_sheet.dart';
import '../notifications/notification_controller.dart';
import '../notifications/notification_models.dart';
import '../reminders/reminders_screen.dart';
import '../roadmap/roadmap_screen.dart';
import '../changelog/changelog_models.dart';
import '../changelog/changelog_screen.dart';
import 'currency_selector_sheet.dart';
import 'delete_data_dialog.dart';
import 'edit_home_dialog.dart';
import 'edit_partner_profile_dialog.dart';
import 'edit_profile_dialog.dart';
import 'home_metadata_controller.dart';
import 'partner_profile_controller.dart';
import 'preferences_controller.dart';
import 'user_profile_controller.dart';

class ProfileScreen extends ConsumerWidget {
  final UserProfileState? initialProfile;
  final LocalHome? initialHome;
  final List<LocalHome>? initialHomes;
  final HomeMetadataState? initialHomeMetadata;
  final BackupStatusState? initialBackupStatus;

  const ProfileScreen({
    super.key,
    this.initialProfile,
    this.initialHome,
    this.initialHomes,
    this.initialHomeMetadata,
    this.initialBackupStatus,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final UserProfileState userProfile = initialProfile ?? ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final activeHome = initialHome ?? ref.watch(activeHomeProvider).value;
    final homes = initialHomes ?? (ref.watch(userHomesProvider).value ?? []);
    final HomeMetadataState homeMeta = initialHomeMetadata ?? ref.watch(homeMetadataProvider);
    final currentTheme = ref.watch(themeModeProvider);
    final currency = ref.watch(currencyPreferenceProvider);
    final notificationPrefs = ref.watch(notificationPreferencesProvider);
    final BackupStatusState backupStatus = initialBackupStatus ?? ref.watch(backupStatusProvider);
    final homeController = ref.read(homeControllerProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('Settings', style: typography.headline.copyWith(fontSize: 22)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // ==========================================
            // 1. PROFILE CARD
            // ==========================================
            CoveCard(
              padding: const EdgeInsets.all(18),
              onTap: () => EditProfileDialog.show(context),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: (userProfile.avatarUrl != null && userProfile.avatarUrl!.isNotEmpty)
                            ? colors.surfaceRow
                            : colors.accentPrimary,
                        backgroundImage: userProfile.avatarUrl != null && userProfile.avatarUrl!.isNotEmpty
                            ? NetworkImage(userProfile.avatarUrl!)
                            : null,
                        child: userProfile.avatarUrl == null || userProfile.avatarUrl!.isEmpty
                            ? Text(
                                userProfile.displayName.isNotEmpty
                                    ? userProfile.displayName[0].toUpperCase()
                                    : 'U',
                                style: typography.headline.copyWith(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: colors.surfaceRow,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: colors.accentPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.edit, size: 10, color: colors.surfaceCard),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userProfile.displayName,
                          style: typography.title.copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userProfile.email.isNotEmpty ? userProfile.email : 'Google Account',
                          style: typography.caption.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.textSubtle, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 2. ABOUT US (HOME-LEVEL)
            // ==========================================
            Text('ABOUT US', style: typography.caption),
            const SizedBox(height: 8),
            CoveCard(
              padding: const EdgeInsets.all(18),
              onTap: activeHome != null ? () => EditHomeDialog.show(context) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (activeHome != null)
                        DeterministicHomeIcon(homeId: activeHome.id, size: 36)
                      else
                        Icon(Icons.home_outlined, size: 36, color: colors.accentPrimary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeHome?.name ?? 'Our Home',
                              style: typography.title.copyWith(fontSize: 16),
                            ),
                            if (activeHome?.description != null && activeHome!.description!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                activeHome.description!,
                                style: typography.caption.copyWith(color: colors.textMuted),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.edit_outlined, size: 16, color: colors.textSubtle),
                    ],
                  ),
                  if (homeMeta.formattedTogetherDuration != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.surfaceRow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_outline, size: 14, color: colors.accentPrimary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              homeMeta.formattedTogetherDuration!,
                              style: typography.caption.copyWith(
                                color: colors.accentPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 3. PREFERENCES
            // ==========================================
            Text('PREFERENCES', style: typography.caption),
            const SizedBox(height: 8),
            CoveGroupedCard(
              children: [
                // Theme Mode 3-way Segmented Control
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Appearance Theme', style: typography.bodyMedium),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: colors.surfaceRow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildThemeSegment(
                              context: context,
                              label: 'Light',
                              icon: Icons.light_mode_outlined,
                              mode: ThemeMode.light,
                              activeMode: currentTheme,
                              onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                            ),
                            _buildThemeSegment(
                              context: context,
                              label: 'Dark',
                              icon: Icons.dark_mode_outlined,
                              mode: ThemeMode.dark,
                              activeMode: currentTheme,
                              onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                            ),
                            _buildThemeSegment(
                              context: context,
                              label: 'System',
                              icon: Icons.settings_brightness_outlined,
                              mode: ThemeMode.system,
                              activeMode: currentTheme,
                              onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Currency & Locale
                CoveGroupedRow(
                  leading: Icon(Icons.payments_outlined, size: 20, color: colors.textPrimary),
                  title: Text('Currency & Locale', style: typography.bodyMedium),
                  subtitle: Text('${currency.name} (${currency.symbol})', style: typography.caption),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => CurrencySelectorSheet.show(context),
                ),

                // Check-in Reminders
                CoveGroupedRow(
                  leading: Icon(Icons.favorite_outline, size: 20, color: colors.accentPrimary),
                  title: Text('Check-in Reminders', style: typography.bodyMedium),
                  subtitle: Text('Warm daily nudges to log & stay in sync', style: typography.caption),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RemindersScreen()),
                  ),
                ),

                // App Roadmap & Wishlist
                CoveGroupedRow(
                  leading: Icon(Icons.checklist_rtl_rounded, size: 20, color: colors.accentPrimary),
                  title: Text('App Roadmap & Wishlist', style: typography.bodyMedium),
                  subtitle: Text('Feature requests & updates checklist', style: typography.caption),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RoadmapScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 4. PARTNER NOTIFICATIONS
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${partnerProfile.displayName.toUpperCase()} NOTIFICATIONS', style: typography.caption),
                Text('Quietly grouped', style: typography.caption.copyWith(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            CoveGroupedCard(
              children: [
                CoveGroupedRow(
                  leading: Icon(Icons.check_box_outlined, size: 20, color: colors.textPrimary),
                  title: Text('Shared Lists', style: typography.bodyMedium),
                  subtitle: Text('${partnerProfile.displayName} adds or checks off items', style: typography.caption),
                  trailing: CoveToggleSwitch(
                    value: !notificationPrefs.muteLists,
                    onChanged: (_) {
                      ref.read(notificationPreferencesProvider.notifier).toggleModule(NotificationModule.lists);
                    },
                  ),
                ),
                CoveGroupedRow(
                  leading: Icon(Icons.receipt_long_outlined, size: 20, color: colors.textPrimary),
                  title: Text('Expenses', style: typography.bodyMedium),
                  subtitle: Text('New expenses logged by ${partnerProfile.displayName}', style: typography.caption),
                  trailing: CoveToggleSwitch(
                    value: !notificationPrefs.muteExpenses,
                    onChanged: (_) {
                      ref.read(notificationPreferencesProvider.notifier).toggleModule(NotificationModule.expenses);
                    },
                  ),
                ),
                CoveGroupedRow(
                  leading: Icon(Icons.autorenew_outlined, size: 20, color: colors.textPrimary),
                  title: Text('Commitments', style: typography.bodyMedium),
                  subtitle: Text('New or renewed commitments & EMIs', style: typography.caption),
                  trailing: CoveToggleSwitch(
                    value: !notificationPrefs.muteSubscriptions,
                    onChanged: (_) {
                      ref.read(notificationPreferencesProvider.notifier).toggleModule(NotificationModule.subscriptions);
                    },
                  ),
                ),
                CoveGroupedRow(
                  leading: Icon(Icons.repeat_outlined, size: 20, color: colors.textPrimary),
                  title: Text('Habits & Rhythms', style: typography.bodyMedium),
                  subtitle: Text('${partnerProfile.displayName} check-in activity', style: typography.caption),
                  trailing: CoveToggleSwitch(
                    value: !notificationPrefs.muteHabits,
                    onChanged: (_) {
                      ref.read(notificationPreferencesProvider.notifier).toggleModule(NotificationModule.habits);
                    },
                  ),
                ),
                CoveGroupedRow(
                  leading: Icon(Icons.calendar_today_outlined, size: 20, color: colors.textPrimary),
                  title: Text('Shared Calendar', style: typography.bodyMedium),
                  subtitle: Text('Events scheduled or updated by ${partnerProfile.displayName}', style: typography.caption),
                  trailing: CoveToggleSwitch(
                    value: !notificationPrefs.muteCalendar,
                    onChanged: (_) {
                      ref.read(notificationPreferencesProvider.notifier).toggleModule(NotificationModule.calendar);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 5. BACKUP & RESTORE
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('BACKUP & RESTORE', style: typography.caption),
                Text('Google Drive app-data', style: typography.caption.copyWith(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            CoveGroupedCard(
              children: [
                CoveGroupedRow(
                  leading: Icon(Icons.cloud_done_outlined, size: 20, color: colors.accentPrimary),
                  title: Text('Last Backup', style: typography.bodyMedium),
                  subtitle: Text(
                    backupStatus.lastBackupTime != null
                        ? 'Backed up ${DateFormat('MMM d, h:mm a').format(backupStatus.lastBackupTime!)}'
                        : 'No backup recorded yet',
                    style: typography.caption,
                  ),
                ),
                CoveGroupedRow(
                  leading: Icon(Icons.sync_outlined, size: 20, color: colors.textPrimary),
                  title: Text('Ready for Next Backup', style: typography.bodyMedium),
                  subtitle: Text(
                    '${backupStatus.pendingEventCount} events · ~${backupStatus.pendingBytesKb.toStringAsFixed(1)} KB ciphertext',
                    style: typography.caption,
                  ),
                ),
                CoveGroupedRow(
                  leading: Icon(Icons.schedule_outlined, size: 20, color: colors.textPrimary),
                  title: Text('Backup Window', style: typography.bodyMedium),
                  subtitle: Text('Nightly at ${backupStatus.backupTimeWindow}', style: typography.caption),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 2, minute: 0),
                    );
                    if (picked != null) {
                      final formatted = DateFormat('hh:mm a').format(
                        DateTime(2026, 1, 1, picked.hour, picked.minute),
                      );
                      await ref.read(backupStatusProvider.notifier).setBackupTimeWindow(formatted);
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: CovePillButton(
                    label: backupStatus.isBackingUp ? 'Backing Up...' : 'Back Up Now',
                    isCompact: true,
                    variant: CoveButtonVariant.secondary,
                    icon: backupStatus.isBackingUp
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: colors.accentPrimary),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 16),
                    onPressed: backupStatus.isBackingUp
                        ? null
                        : () => ref.read(backupStatusProvider.notifier).triggerManualBackup(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ==========================================
            // 6. HOUSEHOLD & MEMBERS
            // ==========================================
            Text('HOUSEHOLD', style: typography.caption),
            const SizedBox(height: 8),
            CoveGroupedCard(
              children: [
                // Active Home & Switcher
                if (activeHome != null)
                  CoveGroupedRow(
                    leading: DeterministicHomeIcon(homeId: activeHome.id, size: 28),
                    title: Text(activeHome.name, style: typography.bodyMedium),
                    subtitle: Text('Active Household', style: typography.caption),
                  ),

                if (homes.length > 1)
                  CoveGroupedRow(
                    leading: Icon(Icons.swap_horiz_outlined, size: 20, color: colors.textPrimary),
                    title: Text('Switch Home', style: typography.bodyMedium),
                    subtitle: Text('${homes.length} homes connected', style: typography.caption),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => HomeSwitcherSheet.show(context),
                  ),

                // Members List
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
                  title: Text('${userProfile.displayName} (You)', style: typography.bodyMedium),
                  subtitle: Text('Home member', style: typography.caption),
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
                      TextButton(
                        onPressed: () => _confirmRemoveMember(context, partnerProfile.displayName),
                        child: Text(
                          'Remove',
                          style: typography.caption.copyWith(color: colors.accentSecondary),
                        ),
                      ),
                    ],
                  ),
                  onTap: () => EditPartnerProfileDialog.show(context),
                ),

                // Regenerate Invite QR
                CoveGroupedRow(
                  leading: Icon(Icons.qr_code_2_outlined, size: 20, color: colors.textPrimary),
                  title: Text('Invite ${partnerProfile.displayName} QR', style: typography.bodyMedium),
                  subtitle: Text('View or regenerate pairing code', style: typography.caption),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () async {
                    if (activeHome == null) return;
                    final payload = await homeController.getPairingPayload(activeHome.id);
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

                // Leave Home
                CoveGroupedRow(
                  leading: Icon(Icons.logout_outlined, size: 20, color: colors.accentSecondary),
                  title: Text(
                    'Leave Home',
                    style: typography.bodyMedium.copyWith(color: colors.accentSecondary),
                  ),
                  subtitle: Text('Remove access on this device', style: typography.caption),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => _confirmLeaveHome(context, ref, activeHome),
                ),
              ],
            ),
            // ==========================================
            // 7. ABOUT COVE & UPDATES
            // ==========================================
            Text('ABOUT COVE', style: typography.caption),
            const SizedBox(height: 8),
            CoveGroupedCard(
              children: [
                CoveGroupedRow(
                  leading: Icon(Icons.auto_awesome_rounded, size: 20, color: colors.accentPrimary),
                  title: Text('Changelog & Updates', style: typography.bodyMedium),
                  subtitle: Text('What\'s fresh in Cove v$kCoveCurrentAppVersion', style: typography.caption),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'v$kCoveCurrentAppVersion',
                          style: TextStyle(
                            fontFamily: 'GeneralSans',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: colors.accentPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChangelogScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ==========================================
            // 8. ACCOUNT & DANGER ZONE
            // ==========================================
            Text('ACCOUNT', style: typography.caption),
            const SizedBox(height: 8),
            CoveGroupedCard(
              children: [
                CoveGroupedRow(
                  leading: Icon(Icons.logout, size: 20, color: colors.textPrimary),
                  title: Text('Sign Out', style: typography.bodyMedium),
                  subtitle: Text('Sign out of your account on this device', style: typography.caption),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    ref.read(authProvider.notifier).signOut();
                  },
                ),
                CoveGroupedRow(
                  leading: Icon(Icons.delete_forever_outlined, size: 20, color: colors.accentSecondary),
                  title: Text(
                    'Delete Local Data',
                    style: typography.bodyMedium.copyWith(color: colors.accentSecondary),
                  ),
                  subtitle: Text(
                    'Purge encrypted storage & keys from device',
                    style: typography.caption.copyWith(color: colors.accentSecondary.withValues(alpha: 0.8)),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () => DeleteDataDialog.show(context),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSegment({
    required BuildContext context,
    required String label,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode activeMode,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isSelected = mode == activeMode;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.surfaceCard : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? colors.textPrimary : colors.textMuted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? colors.textPrimary : colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemoveMember(BuildContext context, String memberName) async {
    final colors = context.colors;
    final typography = context.typography;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Remove $memberName?', style: typography.title),
        content: Text(
          'Removing $memberName means they stop receiving new events for this Home. They will keep their local copy of everything up to that point, matching the mental model of leaving a group.',
          style: typography.bodyRegular.copyWith(color: colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove', style: TextStyle(color: colors.accentSecondary)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$memberName has been removed from new household sync events.'),
          backgroundColor: colors.surfaceCard,
        ),
      );
    }
  }

  Future<void> _confirmLeaveHome(
    BuildContext context,
    WidgetRef ref,
    dynamic activeHome,
  ) async {
    if (activeHome == null) return;
    final colors = context.colors;
    final typography = context.typography;
    final homeController = ref.read(homeControllerProvider);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Leave ${activeHome.name}?', style: typography.title),
        content: Text(
          'You will remove the encryption key and access to this Home from this device. ${ref.read(partnerProfileProvider).displayName} will keep the Home.',
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
    }
  }
}
