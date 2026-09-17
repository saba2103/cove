import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_checkbox.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import 'list_controller.dart';

class ListItemDetailSheet extends ConsumerWidget {
  final LocalListItem item;
  final String listName;

  const ListItemDetailSheet({
    super.key,
    required this.item,
    required this.listName,
  });

  static Future<void> show(
    BuildContext context, {
    required LocalListItem item,
    required String listName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ListItemDetailSheet(
        item: item,
        listName: listName,
      ),
    );
  }

  Future<void> _handleEdit(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final controller = TextEditingController(text: item.title);
    final notesController = TextEditingController(text: item.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderHairline, width: 1),
        ),
        title: Text(
          'Edit Item',
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontFamily: 'GeneralSans', color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Item name',
                labelStyle: TextStyle(color: colors.textMuted),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.borderHairline),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.accentPrimary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(fontFamily: 'GeneralSans', color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                labelStyle: TextStyle(color: colors.textMuted),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.borderHairline),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: colors.accentPrimary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'GeneralSans', color: colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Save',
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontWeight: FontWeight.w600,
                color: colors.accentPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      final newTitle = controller.text.trim();
      final newNotes = notesController.text.trim();
      if (newTitle.isNotEmpty) {
        await ref.read(listControllerProvider).updateItem(
              itemId: item.id,
              title: newTitle,
              notes: newNotes.isNotEmpty ? newNotes : null,
            );
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderHairline, width: 1),
        ),
        title: Text(
          'Delete Item?',
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'Remove "${item.title}" from $listName?',
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 14,
            color: colors.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'GeneralSans', color: colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'GeneralSans',
                fontWeight: FontWeight.w600,
                color: colors.accentSecondary,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(listControllerProvider).deleteItem(itemId: item.id);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final outbox = ref.watch(activeHomeOutboxProvider).value ?? [];
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);
    final user = ref.watch(authProvider).value;
    final partnerProfile = ref.watch(partnerProfileProvider);

    final isCompleted = item.isCompleted;
    final isYou = item.createdBy == user?.id;
    final formattedCreatedDate =
        DateFormat('MMM d, y · h:mm a').format(item.createdAt);

    final tickStatus = resolveCoveSyncStatus(
      entityId: item.id,
      outbox: outbox,
      hasPartner: hasPartner,
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colors.borderHairline, width: 1)),
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderHairline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Top bar: List badge & Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.checklist_outlined, size: 14, color: colors.accentPrimary),
                      const SizedBox(width: 5),
                      Text(
                        listName,
                        style: typography.caption.copyWith(
                          color: colors.accentPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: colors.textMuted),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title & Checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: CoveCheckbox(
                    value: isCompleted,
                    onChanged: (val) {
                      ref.read(listControllerProvider).toggleItem(
                            itemId: item.id,
                            isCompleted: val,
                          );
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: typography.headline.copyWith(
                          fontSize: 22,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted ? colors.textMuted : colors.textPrimary,
                        ),
                      ),
                      if (item.notes != null && item.notes!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          item.notes!,
                          style: typography.bodyMedium.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Details Grouped Card
            CoveGroupedCard(
              children: [
                CoveGroupedRow(
                  leading: Icon(Icons.person_outline, size: 18, color: colors.accentPrimary),
                  title: Text('Added by', style: typography.bodyMedium),
                  trailing: Text(
                    isYou ? 'You' : partnerProfile.displayName,
                    style: typography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                CoveGroupedRow(
                  leading: Icon(Icons.calendar_today_outlined, size: 18, color: colors.accentPrimary),
                  title: Text('Added on', style: typography.bodyMedium),
                  trailing: Text(
                    formattedCreatedDate,
                    style: typography.caption.copyWith(color: colors.textMuted),
                  ),
                ),
                if (isCompleted && item.completedAt != null)
                  CoveGroupedRow(
                    leading: Icon(Icons.check_circle_outline, size: 18, color: colors.accentPrimary),
                    title: Text('Completed on', style: typography.bodyMedium),
                    trailing: Text(
                      DateFormat('MMM d, y · h:mm a').format(item.completedAt!),
                      style: typography.caption.copyWith(color: colors.textMuted),
                    ),
                  ),
                CoveGroupedRow(
                  leading: Icon(Icons.lock_outline, size: 18, color: colors.textSubtle),
                  title: Text('Sync & Encryption', style: typography.bodyMedium),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tickStatus == CoveSyncStatus.syncedToPartner
                            ? 'Synced with ${partnerProfile.displayName}'
                            : 'Saved on device',
                        style: typography.caption.copyWith(color: colors.textMuted),
                      ),
                      const SizedBox(width: 6),
                      CoveSyncTick(status: tickStatus, size: 13),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons: Toggle, Edit, Delete
            Row(
              children: [
                Expanded(
                  child: CovePillButton(
                    label: isCompleted ? 'Mark Pending' : 'Mark Complete',
                    icon: Icon(
                      isCompleted ? Icons.undo_outlined : Icons.check_circle_outline,
                      size: 15,
                    ),
                    onPressed: () {
                      ref.read(listControllerProvider).toggleItem(
                            itemId: item.id,
                            isCompleted: !isCompleted,
                          );
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _handleEdit(context, ref),
                  icon: Icon(Icons.edit_outlined, size: 15, color: colors.textPrimary),
                  label: Text(
                    'Edit',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    side: BorderSide(color: colors.borderHairline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _handleDelete(context, ref),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    side: BorderSide(color: colors.accentSecondary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: Icon(Icons.delete_outline, size: 16, color: colors.accentSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
