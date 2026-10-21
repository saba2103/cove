import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import 'drive_backup_controller.dart';
import 'drive_backup_sheets.dart';

/// "Backup & Restore" block on the Settings screen, backed by real
/// end-to-end encrypted Google Drive backups.
class DriveBackupSection extends ConsumerWidget {
  /// Optional fixed state for previews/screenshots.
  final DriveBackupState? initialState;

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
        const SnackBar(content: Text('Backup restored. Catching up with your partner…')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final DriveBackupState state = initialState ?? ref.watch(driveBackupProvider);
    final notifier = ref.read(driveBackupProvider.notifier);

    final header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('BACKUP & RESTORE', style: typography.caption),
        Text('End-to-end encrypted', style: typography.caption.copyWith(fontSize: 11)),
      ],
    );

    if (!state.isSupported) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 8),
          CoveGroupedCard(
            children: [
              CoveGroupedRow(
                leading: Icon(Icons.cloud_outlined, size: 20, color: colors.textMuted),
                title: Text('Google Drive Backup', style: typography.bodyMedium),
                subtitle: Text('Available in the Cove Android app', style: typography.caption),
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
            if (state.lastBackupSizeBytes != null) formatBackupSize(state.lastBackupSizeBytes!),
          ].join(' · ');

    final backingUp = state.activity == DriveBackupActivity.backingUp;
    final connecting = state.activity == DriveBackupActivity.connecting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 8),
        CoveGroupedCard(
          children: [
            CoveGroupedRow(
              leading: Icon(
                state.isConnected ? Icons.cloud_done_outlined : Icons.cloud_outlined,
                size: 20,
                color: state.isConnected ? colors.accentPrimary : colors.textPrimary,
              ),
              title: Text('Google Drive', style: typography.bodyMedium),
              subtitle: Text(
                state.isConnected ? (state.accountEmail ?? 'Connected') : 'Not connected',
                style: typography.caption,
              ),
              trailing: TextButton(
                onPressed: state.isBusy
                    ? null
                    : () => state.isConnected ? notifier.disconnect() : notifier.connect(),
                child: Text(
                  connecting ? 'Connecting…' : (state.isConnected ? 'Disconnect' : 'Connect'),
                  style: typography.caption.copyWith(
                    color: state.isConnected ? colors.textMuted : colors.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            CoveGroupedRow(
              leading: Icon(Icons.key_outlined, size: 20, color: colors.textPrimary),
              title: Text('Recovery Passphrase', style: typography.bodyMedium),
              subtitle: Text(
                state.hasPassphrase ? 'Set · needed to restore on a new phone' : 'Not set',
                style: typography.caption,
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: state.isBusy ? null : () => BackupPassphraseSheet.show(context),
            ),
            CoveGroupedRow(
              leading: Icon(Icons.history_outlined, size: 20, color: colors.textPrimary),
              title: Text('Last Backup', style: typography.bodyMedium),
              subtitle: Text(lastBackupText, style: typography.caption),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.errorMessage != null) ...[
                    Text(
                      state.errorMessage!,
                      style: typography.caption.copyWith(color: colors.accentSecondary),
                    ),
                    const SizedBox(height: 10),
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
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.accentPrimary),
                                )
                              : const Icon(Icons.cloud_upload_outlined, size: 16),
                          onPressed: state.isBusy ? null : () => runBackupFlow(context, ref),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CovePillButton(
                          label: 'Restore',
                          isCompact: true,
                          variant: CoveButtonVariant.ghost,
                          icon: const Icon(Icons.settings_backup_restore_outlined, size: 16),
                          onPressed: state.isBusy ? null : () => runRestoreFlow(context),
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
