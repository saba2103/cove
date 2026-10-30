import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_round_button.dart';
import '../../core/widgets/cove_row.dart';
import '../../core/widgets/cove_section_label.dart';
import '../../core/widgets/cove_sheet.dart';
import '../../core/widgets/cove_toggle_switch.dart';
import '../../sync/db/app_database.dart';
import '../../sync/key_management/pairing_qr_view.dart';
import '../../sync/providers/active_home_provider.dart';
import '../auth/auth_controller.dart';
import '../backup/drive_backup_controller.dart';
import '../backup/drive_backup_section.dart';
import '../backup/drive_backup_sheets.dart';
import '../changelog/changelog_models.dart';
import '../changelog/changelog_screen.dart';
import '../expenses/monthly_budget_controller.dart';
import '../expenses/monthly_budget_sheet.dart';
import '../home/about_cove_screen.dart';
import '../home/home_controller.dart';
import '../home/home_settings_screen.dart';
import '../home/home_switcher_sheet.dart';
import '../notifications/notification_controller.dart';
import '../notifications/notification_models.dart';
import '../reminders/reminders_screen.dart';
import '../roadmap/roadmap_screen.dart';
import 'currency_selector_sheet.dart';
import 'delete_data_dialog.dart';
import 'edit_profile_dialog.dart';
import 'home_metadata_controller.dart';
import 'partner_profile_controller.dart';
import 'preferences_controller.dart';
import 'user_profile_controller.dart';

/// Settings screen (`design/screens/settings.md`).
///
/// Order:
/// 1. [CovePageHeader] — back, "Settings".
/// 2. The user alone in the first card — their own avatar, not `both`.
/// 3. Six sections as [CoveRow] lists:
///    Preferences · Notifications · Backup & restore · Household · About Cove · Account.
class ProfileScreen extends ConsumerWidget {
  final UserProfileState? initialProfile;
  final LocalHome? initialHome;
  final List<LocalHome>? initialHomes;
  final HomeMetadataState? initialHomeMetadata;
  final DriveBackupState? initialDriveBackupState;

  static const double _kBorderWidth = 1.0;
  static const double _kThemeBarHeight = 36.0;
  static const double _kBackupButtonHeight = 40.0;
  static const double _kIconSize = 16.0;

  const ProfileScreen({
    super.key,
    this.initialProfile,
    this.initialHome,
    this.initialHomes,
    this.initialHomeMetadata,
    this.initialDriveBackupState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
    final UserProfileState userProfile =
        initialProfile ?? ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final activeHome = initialHome ?? ref.watch(activeHomeProvider).value;
    final homes = initialHomes ?? (ref.watch(userHomesProvider).value ?? []);
    final HomeMetadataState homeMeta =
        initialHomeMetadata ?? ref.watch(homeMetadataProvider);
    final currentTheme = ref.watch(themeModeProvider);
    final currency = ref.watch(currencyPreferenceProvider);
    final monthlyBudget = ref.watch(monthlyBudgetProvider);
    final notificationPrefs = ref.watch(notificationPreferencesProvider);
    final DriveBackupState backupState =
        initialDriveBackupState ?? ref.watch(driveBackupProvider);
    final authUser =
        initialProfile != null ? null : ref.watch(authProvider).value;

    final homeCreatedBy = activeHome?.createdBy ?? authUser?.id ?? 'user-alex';
    final currentUserId = authUser?.id ?? homeCreatedBy;
    final userPerson = CoveAvatar.resolvePerson(
      homeCreatedBy: homeCreatedBy,
      actorUserId: currentUserId,
    );

    final effectiveUserName = userProfile.displayName.isNotEmpty
        ? userProfile.displayName
        : (authUser?.displayName?.isNotEmpty == true
            ? authUser!.displayName!
            : 'You');
    final effectivePartnerName = partnerProfile.displayName.isNotEmpty
        ? partnerProfile.displayName
        : 'Partner';
    final hasPartner = effectivePartnerName.isNotEmpty;

    final themeReadout = switch (currentTheme) {
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
      ThemeMode.system => 'System',
    };

    final enabledNotifCount = [
      !notificationPrefs.muteLists,
      !notificationPrefs.muteExpenses,
      !notificationPrefs.muteSubscriptions,
      !notificationPrefs.muteHabits,
      !notificationPrefs.muteCalendar,
    ].where((enabled) => enabled).length;

    const reminderSubtitle = 'Warm daily nudges to log & stay in sync';

    final bottomInset = CovePageInsets.bottomOf(context);

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: CovePageInsets(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: CoveSpace.barClearance + bottomInset,
          ),
          child: CoveMaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. CovePageHeader — back, "Settings"
                CovePageHeader(
                  title: 'Settings',
                  leading: CoveRoundButton(
                    icon: Icons.arrow_back_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),

                const SizedBox(height: CoveSpace.lg),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.gutter,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 2. The user alone in the first card — their own avatar, not `both`
                      _buildUserCard(
                        context: context,
                        displayName: effectiveUserName,
                        email: userProfile.email.isNotEmpty
                            ? userProfile.email
                            : (authUser?.email ?? 'Google Account'),
                        person: userPerson,
                        cv: cv,
                      ),

                      const SizedBox(height: CoveSpace.section),

                      // 3.1 PREFERENCES
                      CoveSectionLabel.page(
                        label: 'Preferences',
                        readout: themeReadout,
                      ),
                      const SizedBox(height: CoveSpace.md),
                      _buildSectionCard(
                        cv: cv,
                        children: [
                          const SizedBox(height: CoveSpace.xs),
                          _buildThemeSegmentedControl(
                            context: context,
                            ref: ref,
                            activeMode: currentTheme,
                            cv: cv,
                          ),
                          const SizedBox(height: CoveSpace.sm),
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.attach_money_rounded,
                              cv,
                            ),
                            title: 'Currency',
                            trailing: _buildTrailingValueWithChevron(
                              label: '${currency.symbol} ${currency.code}',
                              cv: cv,
                            ),
                            onTap: () => CurrencySelectorSheet.show(context),
                          ),
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.attach_money_rounded,
                              cv,
                            ),
                            title: 'Monthly budget',
                            subtitle:
                                'what you mean to spend, outside commitments',
                            isLast: true,
                            trailing: _buildTrailingValueWithChevron(
                              label: monthlyBudget != null && monthlyBudget > 0
                                  ? formatCoveCurrency(
                                      monthlyBudget,
                                      currency.symbol,
                                    )
                                  : 'Not set',
                              cv: cv,
                            ),
                            onTap: () => MonthlyBudgetSheet.show(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: CoveSpace.section),

                      // 3.2 NOTIFICATIONS
                      CoveSectionLabel.page(
                        label: 'Notifications',
                        readout: '$enabledNotifCount of 5 on',
                      ),
                      const SizedBox(height: CoveSpace.md),
                      _buildSectionCard(
                        cv: cv,
                        children: [
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.check_box_outlined,
                              cv,
                            ),
                            title: 'Lists',
                            subtitle:
                                '$effectivePartnerName adds or checks off items',
                            trailing: CoveToggleSwitch(
                              value: !notificationPrefs.muteLists,
                              onChanged: (_) => ref
                                  .read(
                                      notificationPreferencesProvider.notifier)
                                  .toggleModule(NotificationModule.lists),
                            ),
                            onTap: () => ref
                                .read(notificationPreferencesProvider.notifier)
                                .toggleModule(NotificationModule.lists),
                          ),
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.receipt_long_outlined,
                              cv,
                            ),
                            title: 'Expenses',
                            subtitle:
                                'New expenses logged by $effectivePartnerName',
                            trailing: CoveToggleSwitch(
                              value: !notificationPrefs.muteExpenses,
                              onChanged: (_) => ref
                                  .read(
                                      notificationPreferencesProvider.notifier)
                                  .toggleModule(NotificationModule.expenses),
                            ),
                            onTap: () => ref
                                .read(notificationPreferencesProvider.notifier)
                                .toggleModule(NotificationModule.expenses),
                          ),
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.autorenew_outlined,
                              cv,
                            ),
                            title: 'Commitments',
                            subtitle: 'New or renewed commitments & EMIs',
                            trailing: CoveToggleSwitch(
                              value: !notificationPrefs.muteSubscriptions,
                              onChanged: (_) => ref
                                  .read(
                                      notificationPreferencesProvider.notifier)
                                  .toggleModule(
                                      NotificationModule.subscriptions),
                            ),
                            onTap: () => ref
                                .read(notificationPreferencesProvider.notifier)
                                .toggleModule(NotificationModule.subscriptions),
                          ),
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.repeat_outlined,
                              cv,
                            ),
                            title: 'Habits',
                            subtitle:
                                '$effectivePartnerName check-in activity',
                            trailing: CoveToggleSwitch(
                              value: !notificationPrefs.muteHabits,
                              onChanged: (_) => ref
                                  .read(
                                      notificationPreferencesProvider.notifier)
                                  .toggleModule(NotificationModule.habits),
                            ),
                            onTap: () => ref
                                .read(notificationPreferencesProvider.notifier)
                                .toggleModule(NotificationModule.habits),
                          ),
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.calendar_today_outlined,
                              cv,
                            ),
                            title: 'Calendar',
                            subtitle:
                                'Events scheduled or updated by $effectivePartnerName',
                            trailing: CoveToggleSwitch(
                              value: !notificationPrefs.muteCalendar,
                              onChanged: (_) => ref
                                  .read(
                                      notificationPreferencesProvider.notifier)
                                  .toggleModule(NotificationModule.calendar),
                            ),
                            onTap: () => ref
                                .read(notificationPreferencesProvider.notifier)
                                .toggleModule(NotificationModule.calendar),
                          ),
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.favorite_border_rounded,
                              cv,
                            ),
                            title: 'Check-in reminders',
                            subtitle: reminderSubtitle,
                            isLast: true,
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: _kIconSize,
                              color: cv.textTertiary,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RemindersScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: CoveSpace.section),

                      // 3.3 BACKUP & RESTORE
                      _buildBackupAndRestoreSection(
                        context: context,
                        ref: ref,
                        state: backupState,
                        cv: cv,
                      ),

                      const SizedBox(height: CoveSpace.section),

                      // 3.4 HOUSEHOLD
                      CoveSectionLabel.page(
                        label: 'Household',
                        readout: hasPartner ? '2 members' : '1 member',
                      ),
                      const SizedBox(height: CoveSpace.md),
                      _buildSectionCard(
                        cv: cv,
                        children: [
                          // Rule 1: The couple is a row under Household that navigates to Our home
                          CoveRow(
                            avatar: const CoveAvatar.row(
                              person: CovePerson.both,
                            ),
                            title: '$effectiveUserName & $effectivePartnerName',
                            subtitle: _buildHouseholdSubtitle(
                              activeHome: activeHome,
                              homeMeta: homeMeta,
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: _kIconSize,
                              color: cv.textTertiary,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HomeSettingsScreen(),
                              ),
                            ),
                          ),
                          if (homes.length > 1)
                            CoveRow(
                              leading: _buildRowIcon(
                                Icons.swap_horiz_rounded,
                                cv,
                              ),
                              title: 'Switch Home',
                              subtitle: '${homes.length} homes connected',
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                size: _kIconSize,
                                color: cv.textTertiary,
                              ),
                              onTap: () => HomeSwitcherSheet.show(context),
                            ),
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.qr_code_2_rounded,
                              cv,
                            ),
                            title: 'Pair a new phone',
                            subtitle: 'Both phones hold a key',
                            isLast: true,
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: _kIconSize,
                              color: cv.textTertiary,
                            ),
                            onTap: () => _openPairingSheet(
                              context: context,
                              ref: ref,
                              activeHome: activeHome,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: CoveSpace.section),

                      // 3.5 ABOUT COVE
                      CoveSectionLabel.page(
                        label: 'About Cove',
                        readout: kCoveCurrentAppVersion,
                      ),
                      const SizedBox(height: CoveSpace.md),
                      _buildSectionCard(
                        cv: cv,
                        children: [
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.auto_awesome_outlined,
                              cv,
                            ),
                            title: "What's new",
                            subtitle: 'In $kCoveCurrentAppVersion',
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: _kIconSize,
                              color: cv.textTertiary,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ChangelogScreen(),
                              ),
                            ),
                          ),
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.map_outlined,
                              cv,
                            ),
                            title: 'Roadmap & wishlist',
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: _kIconSize,
                              color: cv.textTertiary,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RoadmapScreen(),
                              ),
                            ),
                          ),
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.shield_outlined,
                              cv,
                            ),
                            title: 'How Cove keeps this private',
                            subtitle: 'One page, plain words',
                            isLast: true,
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: _kIconSize,
                              color: cv.textTertiary,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AboutCoveScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: CoveSpace.section),

                      // 3.6 ACCOUNT
                      const CoveSectionLabel.page(label: 'Account'),
                      const SizedBox(height: CoveSpace.md),
                      _buildSectionCard(
                        cv: cv,
                        children: [
                          CoveRow(
                            leading: _buildRowIcon(
                              Icons.logout_rounded,
                              cv,
                              destructive: true,
                            ),
                            title: 'Sign out, leave or delete',
                            subtitle:
                                'Everything that ends something, in one place',
                            isLast: true,
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              size: _kIconSize,
                              color: cv.textTertiary,
                            ),
                            onTap: () => _showDestructiveActionsSheet(
                              context: context,
                              ref: ref,
                              activeHome: activeHome,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: CoveSpace.xl),

                      // Rule 5: Version is secondary text, never a row title.
                      Center(
                        child: Text(
                          'Cove $kCoveCurrentAppVersion',
                          style: CoveType.rowSub.copyWith(
                            color: cv.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard({
    required BuildContext context,
    required String displayName,
    required String email,
    required CovePerson person,
    required CoveTokens cv,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => EditProfileDialog.show(context),
      child: DecoratedBox(
        decoration: CoveShape.decoration(
          CoveRadius.card,
          color: cv.surfaceCard,
          side: BorderSide(
            color: cv.lineHairline,
            width: _kBorderWidth,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(CoveSpace.lg),
          child: Row(
            children: [
              CoveAvatar.profile(
                person: person,
                nameOrInitial: displayName,
              ),
              const SizedBox(width: CoveSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: CoveType.title.copyWith(color: cv.textPrimary),
                    ),
                    const SizedBox(height: CoveSpace.xs),
                    Text(
                      email,
                      style: CoveType.rowSub.copyWith(color: cv.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: _kIconSize,
                color: cv.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required CoveTokens cv,
    required List<Widget> children,
  }) {
    return DecoratedBox(
      decoration: CoveShape.decoration(
        CoveRadius.card,
        color: cv.surfaceCard,
        side: BorderSide(
          color: cv.lineHairline,
          width: _kBorderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.md,
          vertical: CoveSpace.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _buildThemeSegmentedControl({
    required BuildContext context,
    required WidgetRef ref,
    required ThemeMode activeMode,
    required CoveTokens cv,
  }) {
    final duration = CoveMotion.q(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final isScaled = textScale > 1.0;
    final stackModes =
        isScaled &&
        (MediaQuery.sizeOf(context).width / textScale) <
            CoveSize.compactThreshold;
    const modes = <(String, ThemeMode)>[
      ('Light', ThemeMode.light),
      ('Dark', ThemeMode.dark),
      ('System', ThemeMode.system),
    ];

    Widget buildPill((String, ThemeMode) entry) {
      final (label, mode) = entry;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(themeModeProvider.notifier).setThemeMode(mode),
        child: AnimatedContainer(
          duration: duration,
          curve: CoveMotion.easing,
          height: isScaled ? null : _kThemeBarHeight,
          constraints: isScaled
              ? const BoxConstraints(minHeight: _kThemeBarHeight)
              : null,
          padding: isScaled
              ? const EdgeInsets.symmetric(
                  vertical: CoveSpace.xs,
                  horizontal: CoveSpace.sm,
                )
              : null,
          alignment: Alignment.center,
          decoration: CoveShape.decoration(
            CoveRadius.pill,
            color: mode == activeMode ? cv.accentWash : Colors.transparent,
            side: BorderSide(
              color: mode == activeMode ? cv.accentFill : Colors.transparent,
              width: _kBorderWidth,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: CoveType.readout.copyWith(
              color: mode == activeMode ? cv.textPrimary : cv.textSecondary,
              fontWeight:
                  mode == activeMode ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: CoveShape.decoration(
        stackModes ? CoveRadius.inline : CoveRadius.pill,
        color: cv.surfaceCanvas,
        side: BorderSide(
          color: cv.lineHairline,
          width: _kBorderWidth,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoveSpace.xs),
        child: stackModes
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < modes.length; i++) ...[
                    if (i > 0) const SizedBox(height: CoveSpace.xs),
                    buildPill(modes[i]),
                  ],
                ],
              )
            : Row(
                children: [
                  for (final entry in modes) Expanded(child: buildPill(entry)),
                ],
              ),
      ),
    );
  }

  Widget _buildRowIcon(
    IconData icon,
    CoveTokens cv, {
    bool active = false,
    bool destructive = false,
  }) {
    final Color iconColor = destructive
        ? cv.statusAlertText
        : (active ? cv.accentText : cv.accentText);
    final Color borderColor =
        destructive ? cv.statusAlert : cv.lineHairline;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cv.surfaceRow,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: _kBorderWidth,
        ),
      ),
      child: SizedBox(
        width: CoveSize.avatarRow,
        height: CoveSize.avatarRow,
        child: Center(
          child: Icon(
            icon,
            size: _kIconSize,
            color: iconColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingValueWithChevron({
    required String label,
    required CoveTokens cv,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: CoveType.readout.copyWith(color: cv.textSecondary),
          ),
        ),
        const SizedBox(width: CoveSpace.xs),
        Icon(
          Icons.chevron_right_rounded,
          size: _kIconSize,
          color: cv.textTertiary,
        ),
      ],
    );
  }

  Widget _buildBackupAndRestoreSection({
    required BuildContext context,
    required WidgetRef ref,
    required DriveBackupState state,
    required CoveTokens cv,
  }) {
    final notifier = ref.read(driveBackupProvider.notifier);

    if (!state.isSupported) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CoveSectionLabel.page(
            label: 'Backup & restore',
            readout: 'End-to-end encrypted',
          ),
          const SizedBox(height: CoveSpace.md),
          _buildSectionCard(
            cv: cv,
            children: [
              CoveRow(
                leading: _buildRowIcon(Icons.cloud_outlined, cv),
                title: 'Google Drive Backup',
                subtitle: 'Available in the Cove Android app',
                isLast: true,
              ),
            ],
          ),
        ],
      );
    }

    final lastBackupText = state.lastBackupAt == null
        ? 'No backups yet'
        : [
            DateFormat('MMM d, h:mm a').format(state.lastBackupAt!),
            if (state.lastBackupSizeBytes != null)
              formatBackupSize(state.lastBackupSizeBytes!),
          ].join(' · ');

    final backingUp = state.activity == DriveBackupActivity.backingUp;
    final connecting = state.activity == DriveBackupActivity.connecting;

    final backupWindowLabel = state.autoEnabled
        ? 'Nightly at ${state.autoTime.format(context)}'
        : 'Off · back up manually';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CoveSectionLabel.page(
          label: 'Backup & restore',
          readout: 'End-to-end encrypted',
        ),
        const SizedBox(height: CoveSpace.md),
        _buildSectionCard(
          cv: cv,
          children: [
            CoveRow(
              leading: _buildRowIcon(
                state.isConnected
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_outlined,
                cv,
                active: state.isConnected,
              ),
              title: 'Google Drive',
              subtitle: state.isConnected
                  ? (state.accountEmail ?? 'Connected')
                  : 'Not connected',
              trailing: Text(
                connecting
                    ? 'Connecting…'
                    : (state.isConnected ? 'Disconnect' : 'Connect'),
                style: CoveType.readout.copyWith(
                  color: state.isConnected ? cv.textSecondary : cv.accentText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: state.isBusy
                  ? null
                  : () => state.isConnected
                      ? notifier.disconnect()
                      : notifier.connect(),
            ),
            CoveRow(
              leading: _buildRowIcon(Icons.key_outlined, cv),
              title: 'Recovery Passphrase',
              subtitle: state.hasPassphrase
                  ? 'Set · needed to restore on a new phone'
                  : 'Not set',
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: _kIconSize,
                color: cv.textTertiary,
              ),
              onTap: state.isBusy
                  ? null
                  : () => BackupPassphraseSheet.show(context),
            ),
            CoveRow(
              leading: _buildRowIcon(Icons.history_outlined, cv),
              title: 'Last Backup',
              subtitle: lastBackupText,
            ),
            CoveRow(
              leading: _buildRowIcon(Icons.schedule_outlined, cv),
              title: 'Backup window',
              trailing: _buildTrailingValueWithChevron(
                label: backupWindowLabel,
                cv: cv,
              ),
              onTap: state.isBusy
                  ? null
                  : () async {
                      if (!state.autoEnabled) {
                        await notifier.setAutoEnabled(true);
                      }
                      if (!context.mounted) return;
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: state.autoTime,
                      );
                      if (picked != null) {
                        await notifier.setAutoTime(picked);
                      }
                    },
            ),
            CoveRow(
              leading: _buildRowIcon(Icons.download_rounded, cv),
              title: 'Restore',
              subtitle: 'Restore from an encrypted Drive backup',
              isLast: true,
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: _kIconSize,
                color: cv.textTertiary,
              ),
              onTap: state.isBusy
                  ? null
                  : () => DriveBackupSection.runRestoreFlow(context),
            ),
            const SizedBox(height: CoveSpace.sm),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: state.isBusy
                  ? null
                  : () => DriveBackupSection.runBackupFlow(context, ref),
              child: DecoratedBox(
                decoration: CoveShape.decoration(
                  CoveRadius.pill,
                  color: cv.surfaceRow,
                  side: BorderSide(
                    color: cv.lineStrong,
                    width: _kBorderWidth,
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: _kBackupButtonHeight,
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: CoveSpace.md,
                      vertical:
                          MediaQuery.textScalerOf(context).scale(1.0) > 1.0
                          ? CoveSpace.sm
                          : 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: _kIconSize,
                          color: cv.textPrimary,
                        ),
                        const SizedBox(width: CoveSpace.sm),
                        Flexible(
                          child: Text(
                            backingUp ? 'Backing Up…' : 'Back Up Now',
                            textAlign: TextAlign.center,
                            style: CoveType.rowTitle.copyWith(
                              color: cv.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: CoveSpace.xs),
          ],
        ),
      ],
    );
  }

  String _buildHouseholdSubtitle({
    required LocalHome? activeHome,
    required HomeMetadataState homeMeta,
  }) {
    final parts = <String>[
      if (activeHome != null && activeHome.name.isNotEmpty) activeHome.name,
      if (homeMeta.formattedTogetherDuration != null &&
          homeMeta.formattedTogetherDuration!.isNotEmpty)
        homeMeta.formattedTogetherDuration!,
      if (activeHome?.description != null &&
          activeHome!.description!.isNotEmpty)
        activeHome.description!,
    ];
    return parts.isEmpty ? 'Our home' : parts.join(' · ');
  }

  Future<void> _openPairingSheet({
    required BuildContext context,
    required WidgetRef ref,
    required LocalHome? activeHome,
  }) async {
    if (activeHome == null) return;
    final payload = await ref
        .read(homeControllerProvider)
        .getPairingPayload(activeHome.id);
    if (payload == null || !context.mounted) return;

    await CoveSheet.show<void>(
      context: context,
      builder: (_) => CoveSheet(
        child: PairingQrView(payload: payload),
      ),
    );
  }

  Future<void> _showDestructiveActionsSheet({
    required BuildContext context,
    required WidgetRef ref,
    required LocalHome? activeHome,
  }) async {
    await CoveSheet.show<void>(
      context: context,
      builder: (sheetCtx) {
        final cv = sheetCtx.cv;
        final homeName = activeHome?.name ?? 'Our Home';

        return CoveSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sign out, leave or delete',
                      style: CoveType.title.copyWith(color: cv.textPrimary),
                    ),
                  ),
                  CoveRoundButton(
                    icon: Icons.close_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Close',
                    onPressed: () => Navigator.of(sheetCtx).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: CoveSpace.md),
              CoveRow(
                leading: _buildRowIcon(Icons.logout_rounded, cv),
                title: 'Sign Out',
                subtitle: 'Signs out of your account on this device',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: _kIconSize,
                  color: cv.textTertiary,
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  ref.read(authProvider.notifier).signOut();
                },
              ),
              if (activeHome != null)
                CoveRow(
                  leading: _buildRowIcon(
                    Icons.exit_to_app_rounded,
                    cv,
                    destructive: true,
                  ),
                  title: 'Leave Home',
                  subtitle:
                      'Removes encryption key and access to $homeName on this device',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    size: _kIconSize,
                    color: cv.textTertiary,
                  ),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _confirmLeaveHome(context, ref, activeHome);
                  },
                ),
              CoveRow(
                leading: _buildRowIcon(
                  Icons.delete_forever_outlined,
                  cv,
                  destructive: true,
                ),
                title: 'Delete Local Data',
                subtitle: 'Purges encrypted storage & keys from this device',
                isLast: true,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: _kIconSize,
                  color: cv.textTertiary,
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  DeleteDataDialog.show(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmLeaveHome(
    BuildContext context,
    WidgetRef ref,
    LocalHome? activeHome,
  ) async {
    if (activeHome == null) return;
    final homeController = ref.read(homeControllerProvider);
    final partnerName = ref.read(partnerProfileProvider).displayName;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cv = ctx.cv;
        return AlertDialog(
          backgroundColor: cv.surfaceSheet,
          shape: CoveShape.border(CoveRadius.card),
          title: Text(
            'Leave ${activeHome.name}?',
            style: CoveType.title.copyWith(color: cv.textPrimary),
          ),
          content: Text(
            'You will remove the encryption key and access to this Home from this device. $partnerName will keep the Home.',
            style: CoveType.body.copyWith(color: cv.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Cancel',
                style: CoveType.rowTitle.copyWith(color: cv.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Leave',
                style: CoveType.rowTitle.copyWith(color: cv.statusAlertText),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await homeController.leaveHome(activeHome.id);
    }
  }
}
