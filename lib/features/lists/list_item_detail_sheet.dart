import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_detail_sheet.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../core/widgets/slips/cove_note.dart';
import '../../core/widgets/slips/cove_slip.dart';
import '../../sync/db/app_database.dart';
import '../../sync/pending_delete_service.dart';
import '../../sync/providers/active_home_provider.dart';
import '../add/widgets/add_person_picker.dart';
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
    final user = ref.read(authProvider).value;
    final myId = user?.id ?? 'local_user';
    final myName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!.trim()
        : 'You';
    final partnerProfile = ref.read(partnerProfileProvider);
    final partnerId = partnerProfile.userId ?? 'partner';
    final partnerName = partnerProfile.displayName;
    final hasPartner = ref.read(activeHomeHasPartnerProvider);
    String? selectedOwner = item.owner;

    final people = <AddPersonTileData<String>>[
      AddPersonTileData(
        value: myId,
        person: CovePerson.a,
        label: myName,
        nameOrInitial: myName,
      ),
      if (hasPartner) ...[
        AddPersonTileData(
          value: partnerId,
          person: CovePerson.b,
          label: partnerName,
          nameOrInitial: partnerName,
        ),
        const AddPersonTileData(
          value: 'both',
          person: CovePerson.both,
          label: 'Both of you',
        ),
        const AddPersonTileData(
          value: 'either',
          person: CovePerson.both,
          label: 'Either of you',
        ),
      ],
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                const SizedBox(height: CoveSpace.md),
                Text(
                  'Whose is it?',
                  style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                ),
                const SizedBox(height: CoveSpace.sm),
                AddPersonPicker<String>(
                  people: people,
                  selectedValue: selectedOwner,
                  onSelected: (value) {
                    setDialogState(() {
                      selectedOwner = selectedOwner == value ? null : value;
                    });
                  },
                ),
              ],
            ),
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
              owner: selectedOwner,
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

    final rawOwner = item.owner;
    String? ownerLabel;
    if (rawOwner != null && rawOwner.isNotEmpty) {
      if (rawOwner == 'both') {
        ownerLabel = 'Both of you';
      } else if (rawOwner == 'either') {
        ownerLabel = 'Either of you';
      } else if (rawOwner == user?.id ||
          rawOwner == 'local_user' ||
          rawOwner == 'me') {
        ownerLabel = 'You';
      } else {
        ownerLabel = partnerProfile.displayName;
      }
    }

    final meaningTitle =
        isCompleted ? 'Done by $completedByName' : 'On $listName';
    final meaningSubtitle = ownerLabel != null
        ? '$ownerLabel · Added by $addedByName · $formattedCreatedDate'
        : 'Added by $addedByName · $formattedCreatedDate';

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
            owner: ownerLabel,
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
