import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';

class DeleteDataDialog extends ConsumerStatefulWidget {
  const DeleteDataDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeleteDataDialog(),
    );
  }

  @override
  ConsumerState<DeleteDataDialog> createState() => _DeleteDataDialogState();
}

class _DeleteDataDialogState extends ConsumerState<DeleteDataDialog> {
  static const double _kConfirmPromptTopGap =
      16.0; // (literal) 16dp gap above confirmation prompt

  final TextEditingController _confirmController = TextEditingController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final isConfirmed = _confirmController.text.trim() == 'DELETE';

    return AlertDialog(
      backgroundColor: cv.surfaceCard,
      shape: CoveShape.border(CoveRadius.card),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(CoveSpace.sm),
            decoration: BoxDecoration(
              color: cv.statusAlert.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: cv.statusAlert,
              size: CoveSize.avatarInline,
            ),
          ),
          const SizedBox(width: CoveSpace.md),
          Expanded(
            child: Text(
              'Delete Local Data',
              style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'This permanently wipes all local decrypted projections, cached event logs, and encryption keys from this device.',
              style: CoveType.body.copyWith(color: cv.textPrimary),
            ),
            const SizedBox(height: CoveSpace.md),
            CoveCard(
              padding: const EdgeInsets.all(CoveSpace.md),
              child: Text(
                'Note: If your partner is connected, their copy of the Home and history remains safe on their device.',
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
            ),
            const SizedBox(height: _kConfirmPromptTopGap),
            Text(
              'Type "DELETE" below to confirm:',
              style: CoveType.rowSub.copyWith(
                color: cv.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: CoveSpace.sm),
            CovePillInput(
              controller: _confirmController,
              hintText: 'DELETE',
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(
        horizontal: CoveSpace.gutter,
        vertical: _kConfirmPromptTopGap,
      ),
      actions: [
        TextButton(
          onPressed:
              _isDeleting ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: CoveType.readout.copyWith(color: cv.textSecondary),
          ),
        ),
        CovePillButton(
          label: _isDeleting ? 'Deleting...' : 'Delete Everything',
          variant: CoveButtonVariant.secondary,
          isCompact: true,
          onPressed: (isConfirmed && !_isDeleting)
              ? () async {
                  setState(() => _isDeleting = true);
                  await _purgeAllLocalData();
                  if (context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                }
              : null,
        ),
      ],
    );
  }

  Future<void> _purgeAllLocalData() async {
    final db = ref.read(appDatabaseProvider);

    // 1. Wipe all Drift database tables
    try {
      await db.delete(db.localActivityEvents).go();
      await db.delete(db.localOutboxEvents).go();
      await db.delete(db.localCalendarEvents).go();
      await db.delete(db.localHabitCheckins).go();
      await db.delete(db.localHabits).go();
      await db.delete(db.localExpenses).go();
      await db.delete(db.localSubscriptions).go();
      await db.delete(db.localListItems).go();
      await db.delete(db.localLists).go();
      await db.delete(db.localHomes).go();
      await db.delete(db.localNotificationPreferences).go();
    } catch (_) {}

    // 2. Wipe secure storage keys
    try {
      const storage = FlutterSecureStorage();
      await storage.deleteAll();
    } catch (_) {}

    // 3. Clear active home
    ref.read(activeHomeIdProvider.notifier).setActiveHome('');

    // 4. Sign out
    await ref.read(authProvider.notifier).signOut();
  }
}
