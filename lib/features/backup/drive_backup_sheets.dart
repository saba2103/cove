import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import 'backup_crypto.dart';
import 'backup_snapshot_service.dart';
import 'drive_backup_controller.dart';
import 'drive_backup_remote.dart';

/// Human-readable byte size (e.g. "48 KB", "1.2 MB").
String formatBackupSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
}

/// Shared bottom-sheet chrome matching Cove's sheet style.
class _SheetFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SheetFrame({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 24,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(title, style: typography.headline.copyWith(fontSize: 20))),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isWarning;

  const _NoticeCard({required this.icon, required this.text, this.isWarning = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final tint = isWarning ? colors.accentSecondary : colors.accentPrimary;
    return CoveCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: colors.surfaceRow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: typography.caption.copyWith(color: colors.textPrimary, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// RECOVERY PASSPHRASE SHEET
// =============================================================================

class BackupPassphraseSheet extends ConsumerStatefulWidget {
  const BackupPassphraseSheet({super.key});

  /// Returns true when a passphrase was saved.
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BackupPassphraseSheet(),
    );
    return result ?? false;
  }

  @override
  ConsumerState<BackupPassphraseSheet> createState() => _BackupPassphraseSheetState();
}

class _BackupPassphraseSheetState extends ConsumerState<BackupPassphraseSheet> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final a = _first.text;
    if (a.length < DriveBackupController.minPassphraseLength) {
      setState(() => _localError = 'Use at least ${DriveBackupController.minPassphraseLength} characters.');
      return;
    }
    if (a != _second.text) {
      setState(() => _localError = 'The two passphrases don\'t match.');
      return;
    }
    setState(() => _localError = null);
    final ok = await ref.read(driveBackupProvider.notifier).setPassphrase(a);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final backup = ref.watch(driveBackupProvider);
    final error = _localError ?? backup.errorMessage;
    final saving = backup.activity == DriveBackupActivity.settingPassphrase;

    return _SheetFrame(
      title: backup.hasPassphrase ? 'Change Recovery Passphrase' : 'Recovery Passphrase',
      children: [
        Text(
          'Your backups are encrypted on this phone before they reach Google Drive. '
          'This passphrase is the only way to open them on a new phone.',
          style: typography.bodyRegular.copyWith(color: colors.textMuted, fontSize: 13, height: 1.45),
        ),
        const SizedBox(height: 16),
        const _NoticeCard(
          icon: Icons.warning_amber_rounded,
          isWarning: true,
          text: 'If you forget it, your backups can\'t be opened — not even by Cove. '
              'Save it in a password manager.',
        ),
        if (backup.hasPassphrase) ...[
          const SizedBox(height: 10),
          const _NoticeCard(
            icon: Icons.info_outline,
            text: 'Backups already in Drive stay locked with your old passphrase. New backups will use this one.',
          ),
        ],
        const SizedBox(height: 18),
        Text('PASSPHRASE', style: typography.caption),
        const SizedBox(height: 8),
        CovePillInput(
          key: const ValueKey('backup_passphrase_input'),
          controller: _first,
          hintText: 'At least ${DriveBackupController.minPassphraseLength} characters',
          obscureText: true,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.next,
          autofocus: true,
        ),
        const SizedBox(height: 14),
        Text('CONFIRM PASSPHRASE', style: typography.caption),
        const SizedBox(height: 8),
        CovePillInput(
          key: const ValueKey('backup_passphrase_confirm_input'),
          controller: _second,
          hintText: 'Type it again',
          obscureText: true,
          textCapitalization: TextCapitalization.none,
          onSubmitted: (_) => _save(),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error, style: typography.caption.copyWith(color: colors.accentSecondary)),
        ],
        const SizedBox(height: 22),
        CovePillButton(
          label: saving ? 'Securing…' : 'Save Passphrase',
          isFullWidth: true,
          isLoading: saving,
          onPressed: saving ? null : _save,
        ),
      ],
    );
  }
}

// =============================================================================
// RESTORE SHEET
// =============================================================================

enum _RestoreStep { loading, pick, unlock, confirm, restoring }

class RestoreBackupSheet extends ConsumerStatefulWidget {
  const RestoreBackupSheet({super.key});

  /// Returns true when a backup was restored.
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RestoreBackupSheet(),
    );
    return result ?? false;
  }

  @override
  ConsumerState<RestoreBackupSheet> createState() => _RestoreBackupSheetState();
}

class _RestoreBackupSheetState extends ConsumerState<RestoreBackupSheet> {
  final _passphrase = TextEditingController();
  _RestoreStep _step = _RestoreStep.loading;
  List<RemoteBackupFile> _files = const [];
  RemoteBackupFile? _selected;
  OpenedBackup? _opened;
  bool _unlocking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadList);
  }

  @override
  void dispose() {
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() {
      _step = _RestoreStep.loading;
      _error = null;
    });
    try {
      final files = await ref.read(driveBackupProvider.notifier).listBackups();
      if (!mounted) return;
      setState(() {
        _files = files;
        _selected = files.isNotEmpty ? files.first : null;
        _step = _RestoreStep.pick;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _step = _RestoreStep.pick;
      });
    }
  }

  Future<void> _unlock() async {
    final file = _selected;
    if (file == null || _passphrase.text.isEmpty) return;
    setState(() {
      _unlocking = true;
      _error = null;
    });
    try {
      final opened = await ref.read(driveBackupProvider.notifier).openBackup(file.id, _passphrase.text);
      if (!mounted) return;
      setState(() {
        _opened = opened;
        _step = _RestoreStep.confirm;
        _unlocking = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _unlocking = false;
      });
    }
  }

  Future<void> _restore() async {
    final opened = _opened;
    if (opened == null) return;
    setState(() {
      _step = _RestoreStep.restoring;
      _error = null;
    });
    final ok = await ref.read(driveBackupProvider.notifier).restore(opened);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = ref.read(driveBackupProvider).errorMessage;
        _step = _RestoreStep.confirm;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetFrame(
      title: 'Restore from Google Drive',
      children: switch (_step) {
        _RestoreStep.loading => _buildLoading('Looking for your backups…'),
        _RestoreStep.pick => _buildPick(),
        _RestoreStep.unlock => _buildUnlock(),
        _RestoreStep.confirm => _buildConfirm(),
        _RestoreStep.restoring => _buildLoading('Restoring your home…'),
      },
    );
  }

  List<Widget> _buildLoading(String label) {
    final colors = context.colors;
    final typography = context.typography;
    return [
      const SizedBox(height: 24),
      Center(child: CircularProgressIndicator(strokeWidth: 2, color: colors.accentPrimary)),
      const SizedBox(height: 16),
      Center(child: Text(label, style: typography.caption)),
      const SizedBox(height: 24),
    ];
  }

  Widget _errorText() {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(_error!, style: context.typography.caption.copyWith(color: colors.accentSecondary)),
    );
  }

  List<Widget> _buildPick() {
    final colors = context.colors;
    final typography = context.typography;
    final fmt = DateFormat('EEE, MMM d · h:mm a');

    if (_files.isEmpty) {
      return [
        _NoticeCard(
          icon: Icons.cloud_off_outlined,
          text: _error == null
              ? 'No Cove backups found in this Google account\'s Drive.'
              : 'Couldn\'t load backups.',
        ),
        if (_error != null) _errorText(),
        const SizedBox(height: 20),
        CovePillButton(
          label: 'Try Again',
          variant: CoveButtonVariant.secondary,
          isFullWidth: true,
          onPressed: _loadList,
        ),
      ];
    }

    return [
      Text('Choose a backup', style: typography.caption),
      const SizedBox(height: 8),
      ..._files.take(DriveBackupController.retainCount).map((f) {
        final selected = f.id == _selected?.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CoveCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            backgroundColor: selected ? colors.surfaceRow : null,
            border: Border.all(
              color: selected ? colors.accentPrimary : colors.borderHairline,
              width: selected ? 1.5 : 1,
            ),
            onTap: () => setState(() => _selected = f),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 18,
                  color: selected ? colors.accentPrimary : colors.textSubtle,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmt.format(f.createdAt), style: typography.bodyMedium),
                      Text(formatBackupSize(f.sizeBytes), style: typography.caption),
                    ],
                  ),
                ),
                if (f.id == _files.first.id)
                  Text('Latest', style: typography.caption.copyWith(color: colors.accentPrimary)),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 12),
      CovePillButton(
        label: 'Continue',
        isFullWidth: true,
        onPressed: _selected == null ? null : () => setState(() => _step = _RestoreStep.unlock),
      ),
    ];
  }

  List<Widget> _buildUnlock() {
    final colors = context.colors;
    final typography = context.typography;
    return [
      Text(
        'Enter the recovery passphrase you set when this backup was made.',
        style: typography.bodyRegular.copyWith(color: colors.textMuted, fontSize: 13, height: 1.45),
      ),
      const SizedBox(height: 16),
      Text('RECOVERY PASSPHRASE', style: typography.caption),
      const SizedBox(height: 8),
      CovePillInput(
        key: const ValueKey('restore_passphrase_input'),
        controller: _passphrase,
        hintText: 'Your recovery passphrase',
        obscureText: true,
        textCapitalization: TextCapitalization.none,
        autofocus: true,
        onSubmitted: (_) => _unlock(),
      ),
      if (_error != null) _errorText(),
      const SizedBox(height: 20),
      CovePillButton(
        label: _unlocking ? 'Unlocking…' : 'Unlock Backup',
        isFullWidth: true,
        isLoading: _unlocking,
        onPressed: _unlocking ? null : _unlock,
      ),
      const SizedBox(height: 8),
      CovePillButton(
        label: 'Back',
        variant: CoveButtonVariant.ghost,
        isFullWidth: true,
        onPressed: _unlocking ? null : () => setState(() => _step = _RestoreStep.pick),
      ),
    ];
  }

  List<Widget> _buildConfirm() {
    final colors = context.colors;
    final typography = context.typography;
    final opened = _opened!;
    final summary = BackupSnapshotService.summarize(opened.payload);
    final homes = summary.homeNames.isEmpty ? 'Your home' : summary.homeNames.join(', ');
    final date = DateFormat('EEE, MMM d, yyyy · h:mm a').format(opened.envelope.createdAt.toLocal());

    return [
      CoveCard(
        padding: const EdgeInsets.all(16),
        backgroundColor: colors.surfaceRow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock_open_outlined, size: 18, color: colors.accentPrimary),
                const SizedBox(width: 8),
                Text('Backup unlocked', style: typography.bodyMedium),
              ],
            ),
            const SizedBox(height: 10),
            Text(homes, style: typography.title.copyWith(fontSize: 17)),
            const SizedBox(height: 4),
            Text(date, style: typography.caption),
            Text('${summary.totalRows} records', style: typography.caption),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const _NoticeCard(
        icon: Icons.swap_horiz_rounded,
        isWarning: true,
        text: 'This replaces everything currently on this phone with the backup. '
            'Anything that synced after the backup was taken will catch up from your partner automatically.',
      ),
      if (_error != null) _errorText(),
      const SizedBox(height: 20),
      CovePillButton(
        label: 'Restore This Backup',
        isFullWidth: true,
        onPressed: _restore,
      ),
    ];
  }
}
