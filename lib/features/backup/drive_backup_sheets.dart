import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import 'backup_crypto.dart';
import 'backup_snapshot_service.dart';
import 'drive_backup_controller.dart';
import 'drive_backup_remote.dart';

const double _kNoticeIconSize =
    18.0; // (literal) 18dp notice card and radio icon size
const double _kSectionGap =
    16.0; // (literal) 16dp backup sheet section gap
const double _kSpinnerStroke =
    2.0; // (literal) 2dp spinner stroke width
const double _kBorderWidth =
    1.0; // (literal) 1dp backup row hairline border
const double _kSelectedBorderWidth =
    1.5; // (literal) 1.5dp selected backup row border

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
    final cv = context.cv;
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            CovePageInsets.bottomOf(context) +
            CoveSpace.lg,
        left: CoveSpace.gutter,
        right: CoveSpace.gutter,
        top: CoveSpace.lg,
      ),
      decoration: BoxDecoration(
        color: cv.surfaceSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CoveRadius.sheet),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: cv.textSecondary,
                    size: CoveSpace.gutter,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.md),
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

  const _NoticeCard({
    required this.icon,
    required this.text,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final tint = isWarning ? cv.statusAlert : cv.accentFill;
    return CoveCard(
      padding: const EdgeInsets.all(CoveSpace.md),
      backgroundColor: cv.surfaceRow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: _kNoticeIconSize, color: tint),
          const SizedBox(width: CoveSpace.sm),
          Expanded(
            child: Text(
              text,
              style: CoveType.rowSub.copyWith(color: cv.textPrimary),
            ),
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
  ConsumerState<BackupPassphraseSheet> createState() =>
      _BackupPassphraseSheetState();
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
      setState(() => _localError =
          'Use at least ${DriveBackupController.minPassphraseLength} characters.');
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
    final cv = context.cv;
    final backup = ref.watch(driveBackupProvider);
    final error = _localError ?? backup.errorMessage;
    final saving = backup.activity == DriveBackupActivity.settingPassphrase;

    return _SheetFrame(
      title: backup.hasPassphrase
          ? 'Change Recovery Passphrase'
          : 'Recovery Passphrase',
      children: [
        Text(
          'Your backups are encrypted on this phone before they reach Google Drive. '
          'This passphrase is the only way to open them on a new phone.',
          style: CoveType.readout.copyWith(color: cv.textSecondary),
        ),
        const SizedBox(height: _kSectionGap),
        const _NoticeCard(
          icon: Icons.warning_amber_rounded,
          isWarning: true,
          text:
              'If you forget it, your backups can\'t be opened — not even by Cove. '
              'Save it in a password manager.',
        ),
        if (backup.hasPassphrase) ...[
          const SizedBox(height: CoveSpace.sm),
          const _NoticeCard(
            icon: Icons.info_outline,
            text:
                'Backups already in Drive stay locked with your old passphrase. New backups will use this one.',
          ),
        ],
        const SizedBox(height: CoveSpace.gutter),
        Text(
          'PASSPHRASE',
          style: CoveType.capsCard.copyWith(color: cv.textSecondary),
        ),
        const SizedBox(height: CoveSpace.sm),
        CovePillInput(
          key: const ValueKey('backup_passphrase_input'),
          controller: _first,
          hintText:
              'At least ${DriveBackupController.minPassphraseLength} characters',
          obscureText: true,
          textCapitalization: TextCapitalization.none,
          textInputAction: TextInputAction.next,
          autofocus: true,
        ),
        const SizedBox(height: CoveSpace.md),
        Text(
          'CONFIRM PASSPHRASE',
          style: CoveType.capsCard.copyWith(color: cv.textSecondary),
        ),
        const SizedBox(height: CoveSpace.sm),
        CovePillInput(
          key: const ValueKey('backup_passphrase_confirm_input'),
          controller: _second,
          hintText: 'Type it again',
          obscureText: true,
          textCapitalization: TextCapitalization.none,
          onSubmitted: (_) => _save(),
        ),
        if (error != null) ...[
          const SizedBox(height: CoveSpace.md),
          Text(
            error,
            style: CoveType.rowSub.copyWith(color: cv.statusAlertText),
          ),
        ],
        const SizedBox(height: CoveSpace.lg),
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
      final opened = await ref
          .read(driveBackupProvider.notifier)
          .openBackup(file.id, _passphrase.text);
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
    final cv = context.cv;
    return [
      const SizedBox(height: CoveSpace.lg),
      Center(
        child: CircularProgressIndicator(
          strokeWidth: _kSpinnerStroke,
          color: cv.accentFill,
        ),
      ),
      const SizedBox(height: _kSectionGap),
      Center(
        child: Text(
          label,
          style: CoveType.rowSub.copyWith(color: cv.textSecondary),
        ),
      ),
      const SizedBox(height: CoveSpace.lg),
    ];
  }

  Widget _errorText() {
    final cv = context.cv;
    return Padding(
      padding: const EdgeInsets.only(top: CoveSpace.md),
      child: Text(
        _error!,
        style: CoveType.rowSub.copyWith(color: cv.statusAlertText),
      ),
    );
  }

  List<Widget> _buildPick() {
    final cv = context.cv;
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
        const SizedBox(height: CoveSpace.gutter),
        CovePillButton(
          label: 'Try Again',
          variant: CoveButtonVariant.secondary,
          isFullWidth: true,
          onPressed: _loadList,
        ),
      ];
    }

    return [
      Text(
        'Choose a backup',
        style: CoveType.rowSub.copyWith(color: cv.textSecondary),
      ),
      const SizedBox(height: CoveSpace.sm),
      ..._files.take(DriveBackupController.retainCount).map((f) {
        final selected = f.id == _selected?.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: CoveSpace.sm),
          child: CoveCard(
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.md,
              vertical: CoveSpace.md,
            ),
            backgroundColor: selected ? cv.surfaceRow : null,
            border: Border.all(
              color: selected ? cv.accentFill : cv.lineHairline,
              width: selected ? _kSelectedBorderWidth : _kBorderWidth,
            ),
            onTap: () => setState(() => _selected = f),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: _kNoticeIconSize,
                  color: selected ? cv.accentFill : cv.textTertiary,
                ),
                const SizedBox(width: CoveSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fmt.format(f.createdAt),
                        style: CoveType.rowTitle.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                      Text(
                        formatBackupSize(f.sizeBytes),
                        style: CoveType.rowSub.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (f.id == _files.first.id)
                  Text(
                    'Latest',
                    style: CoveType.rowSub.copyWith(color: cv.accentText),
                  ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: CoveSpace.md),
      CovePillButton(
        label: 'Continue',
        isFullWidth: true,
        onPressed: _selected == null
            ? null
            : () => setState(() => _step = _RestoreStep.unlock),
      ),
    ];
  }

  List<Widget> _buildUnlock() {
    final cv = context.cv;
    return [
      Text(
        'Enter the recovery passphrase you set when this backup was made.',
        style: CoveType.readout.copyWith(color: cv.textSecondary),
      ),
      const SizedBox(height: _kSectionGap),
      Text(
        'RECOVERY PASSPHRASE',
        style: CoveType.capsCard.copyWith(color: cv.textSecondary),
      ),
      const SizedBox(height: CoveSpace.sm),
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
      const SizedBox(height: CoveSpace.gutter),
      CovePillButton(
        label: _unlocking ? 'Unlocking…' : 'Unlock Backup',
        isFullWidth: true,
        isLoading: _unlocking,
        onPressed: _unlocking ? null : _unlock,
      ),
      const SizedBox(height: CoveSpace.sm),
      CovePillButton(
        label: 'Back',
        variant: CoveButtonVariant.ghost,
        isFullWidth: true,
        onPressed: _unlocking
            ? null
            : () => setState(() => _step = _RestoreStep.pick),
      ),
    ];
  }

  List<Widget> _buildConfirm() {
    final cv = context.cv;
    final opened = _opened!;
    final summary = BackupSnapshotService.summarize(opened.payload);
    final homes = summary.homeNames.isEmpty
        ? 'Your home'
        : summary.homeNames.join(', ');
    final date = DateFormat('EEE, MMM d, yyyy · h:mm a')
        .format(opened.envelope.createdAt.toLocal());

    return [
      CoveCard(
        padding: const EdgeInsets.all(_kSectionGap),
        backgroundColor: cv.surfaceRow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_open_outlined,
                  size: _kNoticeIconSize,
                  color: cv.accentFill,
                ),
                const SizedBox(width: CoveSpace.sm),
                Text(
                  'Backup unlocked',
                  style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.sm),
            Text(
              homes,
              style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
            ),
            const SizedBox(height: CoveSpace.xs),
            Text(
              date,
              style: CoveType.rowSub.copyWith(color: cv.textSecondary),
            ),
            Text(
              '${summary.totalRows} records',
              style: CoveType.rowSub.copyWith(color: cv.textSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: CoveSpace.md),
      const _NoticeCard(
        icon: Icons.swap_horiz_rounded,
        isWarning: true,
        text:
            'This replaces everything currently on this phone with the backup. '
            'Anything that synced after the backup was taken will catch up from your partner automatically.',
      ),
      if (_error != null) _errorText(),
      const SizedBox(height: CoveSpace.gutter),
      CovePillButton(
        label: 'Restore This Backup',
        isFullWidth: true,
        onPressed: _restore,
      ),
    ];
  }
}
