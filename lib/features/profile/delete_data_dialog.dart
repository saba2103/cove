import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme/cove_theme.dart';
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
  final TextEditingController _confirmController = TextEditingController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isConfirmed = _confirmController.text.trim() == 'DELETE';

    return AlertDialog(
      backgroundColor: colors.surfaceCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.accentSecondary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.warning_amber_rounded, color: colors.accentSecondary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Delete Local Data',
              style: typography.headline.copyWith(fontSize: 18),
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
              style: typography.bodyRegular.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: 12),
            CoveCard(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Note: If your partner is connected, their copy of the Home and history remains safe on their device.',
                style: typography.caption.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Type "DELETE" below to confirm:',
              style: typography.caption.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            CovePillInput(
              controller: _confirmController,
              hintText: 'DELETE',
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
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
