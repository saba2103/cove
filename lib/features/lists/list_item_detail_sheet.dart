import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_detail_sheet.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../core/widgets/slips/cove_note.dart';
import '../../core/widgets/slips/cove_slip.dart';
import '../../sync/db/app_database.dart';
import '../../sync/pending_delete_service.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import 'list_controller.dart';

class ListItemDetailSheet extends ConsumerWidget {
  final LocalListItem item;
  final String listName;

  static const double _kDialogBorderWidth =
      1.0; // (literal) 1dp dialog hairline border

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
    final cv = context.cv;
    final controller = TextEditingController(text: item.title);
    final notesController = TextEditingController(text: item.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        shape: CoveShape.border(
          CoveRadius.inline,
          side: BorderSide(
            color: cv.lineHairline,
            width: _kDialogBorderWidth,
          ),
        ),
        title: Text(
          'Edit Item',
          style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: CoveType.body.copyWith(color: cv.textPrimary),
              decoration: InputDecoration(
                labelText: 'Item name',
                labelStyle: CoveType.rowSub.copyWith(color: cv.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: cv.lineHairline),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: cv.accentFill),
                ),
              ),
            ),
            const SizedBox(height: CoveSpace.md),
            TextField(
              controller: notesController,
              textCapitalization: TextCapitalization.sentences,
              style: CoveType.body.copyWith(color: cv.textPrimary),
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                labelStyle: CoveType.rowSub.copyWith(color: cv.textSecondary),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: cv.lineHairline),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: cv.accentFill),
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
              style: CoveType.rowTitle.copyWith(color: cv.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Save',
              style: CoveType.rowTitle.copyWith(color: cv.accentText),
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
    final cv = context.cv;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        shape: CoveShape.border(
          CoveRadius.inline,
          side: BorderSide(
            color: cv.lineHairline,
            width: _kDialogBorderWidth,
          ),
        ),
        title: Text(
          'Delete Item?',
          style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
        ),
        content: Text(
          'Remove "${item.title}" from $listName?',
          style: CoveType.readout.copyWith(color: cv.textSecondary),
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
              'Delete',
              style: CoveType.rowTitle.copyWith(color: cv.statusAlertText),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final pendingDelete = ref.read(pendingDeleteServiceProvider);
      await pendingDelete.scheduleDelete(
        kind: PendingDeleteKind.listItem,
        id: item.id,
      );
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Deleted "${item.title}"',
          onUndo: () async {
            await pendingDelete.undoDelete(
              kind: PendingDeleteKind.listItem,
              id: item.id,
            );
          },
        );
      }
    }
  }

  void _handleToggle(BuildContext context, WidgetRef ref, bool nextCompleted) {
    ref.read(listControllerProvider).toggleItem(
          itemId: item.id,
          isCompleted: nextCompleted,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final partnerProfile = ref.watch(partnerProfileProvider);

    final isCompleted = item.isCompleted;
    final isYouCreated = item.createdBy == user?.id;
    final addedByName = isYouCreated ? 'You' : partnerProfile.displayName;

    final completedById = item.completedBy ?? item.createdBy;
    final completedByName = completedById == user?.id
        ? 'You'
        : partnerProfile.displayName;

    final formattedCreatedDate = DateFormat('d MMM y').format(
      item.createdAt.toLocal(),
    );

    final noteAddedByLine = item.notes != null && item.notes!.trim().isNotEmpty
        ? '${item.notes!.trim()} · Added by $addedByName'
        : 'Added by $addedByName';

    final meaningTitle =
        isCompleted ? 'Done by $completedByName' : 'On $listName';
    final meaningSubtitle = 'Added by $addedByName · $formattedCreatedDate';

    return CoveDetailSheet(
      kindGlyph: const Icon(Icons.checklist_rounded),
      kindLabel: 'TASK',
      contextLabel: listName,
      onClose: () => Navigator.of(context).pop(),
      slip: CoveNote(
        variant: CoveSlipVariant.paper,
        capsLabel: 'COVE · ${listName.toUpperCase()}',
        items: [
          CoveNoteItem(
            title: item.title,
            addedBy: noteAddedByLine,
            isDone: isCompleted,
            onChanged: (val) => _handleToggle(context, ref, val),
          ),
        ],
      ),
      meaningPanel: CoveDetailMeaningPanel.icon(
        icon: isCompleted
            ? Icons.task_alt_rounded
            : Icons.format_list_bulleted_rounded,
        title: meaningTitle,
        subtitle: meaningSubtitle,
      ),
      editVerb: CoveDetailVerb(
        label: 'Edit',
        icon: Icons.edit_outlined,
        onPressed: () => _handleEdit(context, ref),
      ),
      secondaryVerb: CoveDetailVerb(
        label: isCompleted ? 'Not done' : 'Done',
        icon: isCompleted
            ? Icons.undo_rounded
            : Icons.check_circle_outline_rounded,
        onPressed: () => _handleToggle(context, ref, !isCompleted),
      ),
      menuItems: [
        CoveDetailMenuItem(
          label: 'Delete this task',
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          onSelected: () => _handleDelete(context, ref),
        ),
      ],
    );
  }
}
