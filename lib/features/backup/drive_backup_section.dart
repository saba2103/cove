import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_toggle_switch.dart';
import 'backup_service.dart';
import 'drive_backup_controller.dart';
import 'drive_backup_sheets.dart';

/// "Backup & Restore" block on the Settings screen, backed by real
/// end-to-end encrypted Google Drive backups.
class DriveBackupSection extends ConsumerWidget {
  /// Optional fixed state for previews/screenshots.
  final DriveBackupState? initialState;

  static const double _kChevronSize =
      18.0; // (literal) 18dp row chevron icon size
  static const double _kActionAreaPaddingH =
      16.0; // (literal) 16dp action footer horizontal inset and button icon size
  static const double _kSpinnerStroke =
      2.0; // (literal) 2dp backup spinner stroke

  const DriveBackupSection({super.key, this.initialState});

  /// Runs the full "Back Up Now" flow: connect → passphrase → upload.
  static Future<void> runBackupFlow(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(driveBackupProvider.notifier);
    if (!ref.read(driveBackupProvider).isConnected) {
      if (!await notifier.connect()) return;
    }
    if (!ref.read(driveBackupProvider).hasPassphrase) {
      if (!context.mounted) return;
      if (!await BackupPassphraseSheet.show(context)) return;
    }
    final ok = await notifier.backupNow();
    if (ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backed up to Google Drive')),
      );
    }
  }

  static Future<void> runRestoreFlow(BuildContext context) async {
    final restored = await RestoreBackupSheet.show(context);
    if (restored && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Backup restored. Catching up with your partner…'),
        ),
      );
    }
  }

  static String _nightlySubtitle(BuildContext context, DriveBackupState state) {
    if (!state.autoEnabled) return 'Off · back up manually';
    if (!state.isConfigured) return 'Starts after your first backup';
    if (state.autoError != null) return state.autoError!;
    final last = state.autoLastRunAt;
    if (last == null) return 'On · first run tonight';
    final when = DateFormat('MMM d, h:mm a').format(last);
    return switch (state.autoLastOutcome) {
      BackupRunOutcome.uploaded => 'On · last ran $when',
      BackupRunOutcome.skippedUnchanged =>
        'On · $when, nothing new to back up',
      BackupRunOutcome.skippedRecent =>
        'On · $when, already backed up today',
      BackupRunOutcome.failed =>
        'On · $when didn\'t finish, will retry',
      _ => 'On · last checked $when',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
    final DriveBackupState state =
        initialState ?? ref.watch(driveBackupProvider);
    final notifier = ref.read(driveBackupProvider.notifier);

    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'BACKUP & RESTORE',
          style: CoveType.capsPage.copyWith(color: cv.textSecondary),
        ),
        Text(
          'End-to-end encrypted',
          style: CoveType.rowSub.copyWith(color: cv.textSecondary),
        ),
      ],
    );

    if (!state.isSupported) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: CoveSpace.sm),
          CoveGroupedCard(
            children: [
              CoveGroupedRow(
                leading: Icon(
                  Icons.cloud_outlined,
                  size: CoveSpace.gutter,
                  color: cv.textSecondary,
                ),
                title: Text(
                  'Google Drive Backup',
                  style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                ),
                subtitle: Text(
                  'Available in the Cove Android app',
                  style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: CoveSpace.sm),
        CoveGroupedCard(
          children: [
            CoveGroupedRow(
              leading: Icon(
                state.isConnected
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_outlined,
                size: CoveSpace.gutter,
                color: state.isConnected ? cv.accentFill : cv.textPrimary,
              ),
              title: Text(
                'Google Drive',
                style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
              ),
              subtitle: Text(
                state.isConnected
                    ? (state.accountEmail ?? 'Connected')
                    : 'Not connected',
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
              trailing: TextButton(
                onPressed: state.isBusy
                    ? null
                    : () => state.isConnected
                        ? notifier.disconnect()
                        : notifier.connect(),
                child: Text(
                  connecting
                      ? 'Connecting…'
                      : (state.isConnected ? 'Disconnect' : 'Connect'),
                  style: CoveType.rowSub.copyWith(
                    color:
                        state.isConnected ? cv.textSecondary : cv.accentText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            CoveGroupedRow(
              leading: Icon(
                Icons.key_outlined,
                size: CoveSpace.gutter,
                color: cv.textPrimary,
              ),
              title: Text(
                'Recovery Passphrase',
                style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
              ),
              subtitle: Text(
                state.hasPassphrase
                    ? 'Set · needed to restore on a new phone'
                    : 'Not set',
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
              trailing: Icon(
                Icons.chevron_right,
                size: _kChevronSize,
                color: cv.textTertiary,
              ),
              onTap: state.isBusy
                  ? null
                  : () => BackupPassphraseSheet.show(context),
            ),
            CoveGroupedRow(
              leading: Icon(
                Icons.history_outlined,
                size: CoveSpace.gutter,
                color: cv.textPrimary,
              ),
              title: Text(
                'Last Backup',
                style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
              ),
              subtitle: Text(
                lastBackupText,
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
            ),
            CoveGroupedRow(
              key: const ValueKey('nightly_backup_row'),
              leading: Icon(
                Icons.nightlight_outlined,
                size: CoveSpace.gutter,
                color: cv.textPrimary,
              ),
              title: Text(
                'Nightly Backup',
                style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
              ),
              subtitle: Text(
                _nightlySubtitle(context, state),
                style: CoveType.rowSub.copyWith(
                  color: state.autoError != null && state.isAutoActive
                      ? cv.statusAlertText
                      : cv.textSecondary,
                ),
              ),
              trailing: CoveToggleSwitch(
                value: state.autoEnabled,
                onChanged: state.isBusy
                    ? null
                    : (v) => notifier.setAutoEnabled(v),
              ),
            ),
            if (state.autoEnabled) ...[
              CoveGroupedRow(
                leading: Icon(
                  Icons.schedule_outlined,
                  size: CoveSpace.gutter,
                  color: cv.textPrimary,
                ),
                title: Text(
                  'Backup Time',
                  style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                ),
                subtitle: Text(
                  'Around ${state.autoTime.format(context)} · Android may shift it slightly',
                  style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  size: _kChevronSize,
                  color: cv.textTertiary,
                ),
                onTap: state.isBusy
                    ? null
                    : () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: state.autoTime,
                        );
                        if (picked != null) await notifier.setAutoTime(picked);
                      },
              ),
              CoveGroupedRow(
                leading: Icon(
                  Icons.wifi_outlined,
                  size: CoveSpace.gutter,
                  color: cv.textPrimary,
                ),
                title: Text(
                  'Wi-Fi Only',
                  style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                ),
                subtitle: Text(
                  state.autoWifiOnly
                      ? 'Waits for Wi-Fi'
                      : 'Wi-Fi or mobile data',
                  style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                ),
                trailing: CoveToggleSwitch(
                  value: state.autoWifiOnly,
                  onChanged: state.isBusy
                      ? null
                      : (v) => notifier.setAutoWifiOnly(v),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kActionAreaPaddingH,
                vertical: CoveSpace.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.errorMessage != null) ...[
                    Text(
                      state.errorMessage!,
                      style: CoveType.rowSub.copyWith(
                        color: cv.statusAlertText,
                      ),
                    ),
                    const SizedBox(height: CoveSpace.sm),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: CovePillButton(
                          label: backingUp ? 'Backing Up…' : 'Back Up Now',
                          isCompact: true,
                          variant: CoveButtonVariant.secondary,
                          icon: backingUp
                              ? SizedBox(
                                  width: CoveSpace.md,
                                  height: CoveSpace.md,
                                  child: CircularProgressIndicator(
                                    strokeWidth: _kSpinnerStroke,
                                    color: cv.accentFill,
                                  ),
                                )
                              : const Icon(
                                  Icons.cloud_upload_outlined,
                                  size: _kActionAreaPaddingH,
                                ),
                          onPressed: state.isBusy
                              ? null
                              : () => runBackupFlow(context, ref),
                        ),
                      ),
                      const SizedBox(width: CoveSpace.sm),
                      Expanded(
                        child: CovePillButton(
                          label: 'Restore',
                          isCompact: true,
                          variant: CoveButtonVariant.ghost,
                          icon: const Icon(
                            Icons.settings_backup_restore_outlined,
                            size: _kActionAreaPaddingH,
                          ),
                          onPressed: state.isBusy
                              ? null
                              : () => runRestoreFlow(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
