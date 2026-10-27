import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_checkbox.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_error_state.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../core/widgets/cove_tab_row.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../sync/db/app_database.dart';
import '../../sync/pending_delete_service.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../add/widgets/add_person_picker.dart';
import '../auth/auth_controller.dart';
import '../notifications/notification_controller.dart';
import '../profile/partner_profile_controller.dart';
import 'create_list_dialog.dart';
import 'list_controller.dart';
import 'list_item_detail_sheet.dart';

class ListsScreen extends ConsumerStatefulWidget {
  final List<LocalList>? initialLists;
  final List<LocalListItem>? initialItems;

  const ListsScreen({
    super.key,
    this.initialLists,
    this.initialItems,
  });

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  static const double _kNavItemRadius =
      10.0; // (literal) 10dp desktop list navigator item corner radius

  FlutterSecureStorage get _storage => ref.read(homeKeyStoreProvider).storage;

  int _selectedTabIndex = 0;
  String? _selectedListId;

  /// Visible for tests to verify which list tab is currently active.
  String? get activeListIdForTest => _lastClosedBatchListId ?? _selectedListId;
  String? _lastClosedBatchListId;
  List<String>? _customListOrder;

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isSubmitting = false;

  /// Custom active item ordering per list ID
  final Map<String, List<String>> _customOrderMap = {};

  Future<void> _handleRefresh() async {
    final homeId = ref.read(activeHomeIdProvider);
    await ref.read(listControllerProvider).ensureDefaultLists();
    await ref.read(syncEngineProvider).pullLatestEvents(homeId: homeId);
  }

  @override
  void initState() {
    super.initState();
    _loadCustomListOrder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialLists == null) {
        ref.read(listControllerProvider).ensureDefaultLists();
      }
    });
  }

  Future<void> _loadCustomListOrder() async {
    final homeId = ref.read(activeHomeIdProvider);
    if (homeId == null) return;
    try {
      final raw = await _storage.read(key: 'cove_lists_tab_order_$homeId');
      if (raw != null && raw.isNotEmpty && mounted) {
        setState(() {
          _customListOrder = raw.split(',').where((s) => s.isNotEmpty).toList();
        });
      }
    } catch (_) {}
  }

  List<LocalList> _getSortedLists(List<LocalList> originalLists) {
    if (_customListOrder == null || _customListOrder!.isEmpty) {
      return originalLists;
    }
    final orderMap = {
      for (int i = 0; i < _customListOrder!.length; i++) _customListOrder![i]: i,
    };
    final sorted = List<LocalList>.from(originalLists);
    sorted.sort((a, b) {
      final aIndex = orderMap[a.id] ?? 999999;
      final bIndex = orderMap[b.id] ?? 999999;
      if (aIndex != bIndex) {
        return aIndex.compareTo(bIndex);
      }
      return a.createdAt.compareTo(b.createdAt);
    });
    return sorted;
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleAddItem(String activeListId) async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final controller = ref.read(listControllerProvider);
      await controller.addItem(listId: activeListId, title: text);
      _inputController.clear();
      _inputFocusNode.requestFocus();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleCreateNewList() async {
    final newListId = await CreateListDialog.show(context);
    if (newListId != null && mounted) {
      setState(() {
        _selectedListId = newListId;
        if (_customListOrder != null && !_customListOrder!.contains(newListId)) {
          _customListOrder!.add(newListId);
        }
      });
    }
  }

  Future<void> _handleClearCompleted(String activeListId, int completedCount) async {
    if (completedCount == 0) return;

    final cv = context.cv;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        shape: CoveShape.border(
          CoveRadius.inline,
          side: BorderSide(color: cv.lineHairline, width: 1),
        ),
        title: Text(
          'Clear completed items?',
          style: CoveType.rowTitle.copyWith(
            fontWeight: FontWeight.w600,
            color: cv.textPrimary,
          ),
        ),
        content: Text(
          'This will remove $completedCount completed item${completedCount > 1 ? "s" : ""} from this list.',
          style: CoveType.readout.copyWith(
            color: cv.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: CoveType.readout.copyWith(
                color: cv.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Clear',
              style: CoveType.readout.copyWith(
                fontWeight: FontWeight.w600,
                color: cv.statusAlertText,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final controller = ref.read(listControllerProvider);
      await controller.clearCompleted(listId: activeListId);
    }
  }

  Future<void> _handleRenameList(LocalList list) async {
    final cv = context.cv;
    final controller = TextEditingController(text: list.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        shape: CoveShape.border(
          CoveRadius.inline,
          side: BorderSide(color: cv.lineHairline, width: 1),
        ),
        title: Text(
          'Rename list',
          style: CoveType.rowTitle.copyWith(
            fontWeight: FontWeight.w600,
            color: cv.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: CoveType.body.copyWith(
            color: cv.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'List name',
            hintStyle: CoveType.body.copyWith(color: cv.textSecondary),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: cv.lineHairline),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: cv.accentFill),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: CoveType.readout.copyWith(color: cv.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.of(ctx).pop(val);
              }
            },
            child: Text(
              'Rename',
              style: CoveType.readout.copyWith(
                fontWeight: FontWeight.w600,
                color: cv.accentText,
              ),
            ),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != list.name) {
      await ref.read(listControllerProvider).renameList(
            listId: list.id,
            newName: newName,
          );
    }
  }

  Future<void> _handleDeleteList(LocalList list, int totalCount) async {
    final cv = context.cv;
    final partnerName = ref.read(partnerProfileProvider).displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        shape: CoveShape.border(
          CoveRadius.inline,
          side: BorderSide(color: cv.lineHairline, width: 1),
        ),
        title: Text(
          'Delete "${list.name}"?',
          style: CoveType.rowTitle.copyWith(
            fontWeight: FontWeight.w600,
            color: cv.textPrimary,
          ),
        ),
        content: Text(
          'This will permanently delete this list and all its items for you and $partnerName.',
          style: CoveType.readout.copyWith(
            color: cv.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: CoveType.readout.copyWith(color: cv.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: CoveType.readout.copyWith(
                fontWeight: FontWeight.w600,
                color: cv.statusAlertText,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (_selectedTabIndex > 0) {
        setState(() {
          _selectedTabIndex = _selectedTabIndex - 1;
        });
      }
      _selectedListId = null;
      if (_customListOrder != null) {
        _customListOrder!.remove(list.id);
        final homeId = ref.read(activeHomeIdProvider);
        if (homeId != null) {
          try {
            await _storage.write(
              key: 'cove_lists_tab_order_$homeId',
              value: _customListOrder!.join(','),
            );
          } catch (_) {}
        }
      }
      await ref.read(listControllerProvider).deleteList(listId: list.id);
    }
  }

  Future<void> _handleEditItem(LocalListItem item) async {
    final cv = context.cv;
    final controller = TextEditingController(text: item.title);
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

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: cv.surfaceCard,
          shape: CoveShape.border(
            CoveRadius.inline,
            side: BorderSide(color: cv.lineHairline, width: 1),
          ),
          title: Text(
            'Edit item',
            style: CoveType.rowTitle.copyWith(
              fontWeight: FontWeight.w600,
              color: cv.textPrimary,
            ),
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
                  style: CoveType.body.copyWith(
                    color: cv.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Item name',
                    hintStyle: CoveType.body.copyWith(color: cv.textSecondary),
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
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: CoveType.readout.copyWith(color: cv.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                final val = controller.text.trim();
                if (val.isNotEmpty) {
                  Navigator.of(ctx).pop(val);
                }
              },
              child: Text(
                'Save',
                style: CoveType.readout.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cv.accentText,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (newTitle != null &&
        newTitle.isNotEmpty &&
        (newTitle != item.title || selectedOwner != item.owner)) {
      await ref.read(listControllerProvider).updateItem(
            itemId: item.id,
            title: newTitle,
            notes: item.notes,
            owner: selectedOwner,
          );
    }
  }

  Future<void> _handleDeleteItem(LocalListItem item) async {
    final pendingDelete = ref.read(pendingDeleteServiceProvider);
    await pendingDelete.scheduleDelete(
      kind: PendingDeleteKind.listItem,
      id: item.id,
    );
    if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);

    ref.listen<String?>(selectedListIdProvider, (prev, next) {
      if (next != null && next.isNotEmpty) {
        setState(() {
          _selectedListId = next;
        });
        ref.read(selectedListIdProvider.notifier).selectList(null);
      }
    });

    final pendingTargetListId = ref.read(selectedListIdProvider);
    if (pendingTargetListId != null &&
        pendingTargetListId.isNotEmpty &&
        _selectedListId != pendingTargetListId) {
      _selectedListId = pendingTargetListId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(selectedListIdProvider.notifier).selectList(null);
        }
      });
    }

    if (widget.initialLists != null) {
      return _buildWithLists(context, widget.initialLists!, hasPartner: hasPartner);
    }

    final listsAsync = ref.watch(activeHomeListsProvider);

    return listsAsync.when(
      data: (lists) => _buildWithLists(context, lists, hasPartner: hasPartner),
      loading: () => Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: const CovePageInsets(child: Center(child: CoveLoading())),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: CovePageInsets(
          child: Center(
            child: CoveErrorState.generic(
              title: 'Lists unavailable',
              description: 'Could not load your lists right now.',
              onRetry: () => ref.invalidate(activeHomeListsProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWithLists(
    BuildContext context,
    List<LocalList> lists, {
    bool hasPartner = true,
  }) {
    final cv = context.cv;

    if (lists.isEmpty) {
      return Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: CovePageInsets(
          child: Center(
            child: CoveEmptyState(
              icon: Icons.checklist_outlined,
              title: 'No shared lists yet',
              description: 'Start tracking joint groceries, packing lists, and household essentials.',
              action: TextButton.icon(
                onPressed: _handleCreateNewList,
                icon: Icon(Icons.add, size: 16, color: cv.accentText),
                label: Text(
                  'Create First List',
                  style: CoveType.readout.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cv.accentText,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final orderedLists = _getSortedLists(lists);
    int safeIndex = 0;
    if (_selectedListId != null) {
      final idx = orderedLists.indexWhere((l) => l.id == _selectedListId);
      if (idx != -1) {
        safeIndex = idx;
      }
    } else {
      safeIndex = _selectedTabIndex.clamp(0, orderedLists.length - 1);
    }
    final activeList = orderedLists[safeIndex];
    if (_lastClosedBatchListId != activeList.id) {
      _lastClosedBatchListId = activeList.id;
      final openedListId = activeList.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(notificationServiceProvider).onListOpened(openedListId);
        }
      });
    }

    final isWide = kIsWeb && MediaQuery.sizeOf(context).width >= 880;

    if (isWide) {
      return Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Pane: Lists Navigator
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: cv.surfaceCard.withValues(alpha: 0.5),
                border: Border(
                  right: BorderSide(color: cv.lineHairline, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: CoveSpace.gutter,
                      right: CoveSpace.md,
                      top: CoveSpace.gutter,
                      bottom: CoveSpace.md,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SHARED LISTS',
                          style: CoveType.capsPage.copyWith(
                            color: cv.textSecondary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_rounded, size: 20, color: cv.accentText),
                          tooltip: 'Add new list',
                          onPressed: _handleCreateNewList,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoveSpace.md,
                        vertical: CoveSpace.sm,
                      ),
                      itemCount: orderedLists.length,
                      itemBuilder: (ctx, idx) {
                        final list = orderedLists[idx];
                        final isSelected = idx == safeIndex;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Material(
                            color: cv.surfaceCard.withValues(alpha: 0),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedTabIndex = idx;
                                  _selectedListId = list.id;
                                });
                              },
                              customBorder: CoveShape.border(_kNavItemRadius),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: CoveSpace.md,
                                  vertical: 10,
                                ),
                                decoration: CoveShape.decoration(
                                  _kNavItemRadius,
                                  color: isSelected
                                      ? cv.accentWash
                                      : cv.surfaceCard.withValues(alpha: 0),
                                  side: isSelected
                                      ? BorderSide(
                                          color: cv.accentFill.withValues(alpha: 0.3),
                                          width: 1,
                                        )
                                      : BorderSide.none,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.checklist_rounded
                                          : Icons.checklist_rtl_rounded,
                                      size: 18,
                                      color: isSelected ? cv.accentText : cv.textSecondary,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        list.name,
                                        style: CoveType.readout.copyWith(
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? cv.textPrimary : cv.textSecondary,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_horiz_rounded, size: 16, color: cv.textTertiary),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: CoveSize.avatarInline,
                                        minHeight: CoveSize.avatarInline,
                                      ),
                                      color: cv.surfaceCard,
                                      shape: CoveShape.border(
                                        CoveSpace.md,
                                        side: BorderSide(color: cv.lineHairline, width: 1),
                                      ),
                                      onSelected: (action) {
                                        if (action == 'rename') {
                                          _handleRenameList(list);
                                        } else if (action == 'delete') {
                                          _handleDeleteList(list, lists.length);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        PopupMenuItem(
                                          value: 'rename',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 16, color: cv.textPrimary),
                                              const SizedBox(width: CoveSpace.sm),
                                              Text(
                                                'Rename',
                                                style: CoveType.readout.copyWith(color: cv.textPrimary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 16, color: cv.statusAlertText),
                                              const SizedBox(width: CoveSpace.sm),
                                              Text(
                                                'Delete',
                                                style: CoveType.readout.copyWith(color: cv.statusAlertText),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Right Pane: Active List Items & Input
            Expanded(
              child: Column(
                children: [
                  // Desktop Active List Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                    decoration: BoxDecoration(
                      color: cv.surfaceCanvas,
                      border: Border(
                        bottom: BorderSide(color: cv.lineHairline, width: 1),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeList.name,
                              style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
                            ),
                            Text(
                              'Shared with partner · Instant sync',
                              style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 18, color: cv.textSecondary),
                              tooltip: 'Rename list',
                              onPressed: () => _handleRenameList(activeList),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: cv.statusAlertText),
                              tooltip: 'Delete list',
                              onPressed: () => _handleDeleteList(activeList, lists.length),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Items List Area
                  Expanded(
                    child: _buildItemsArea(context, activeList),
                  ),

                  // Pinned Input Bar
                  _buildPinnedInputBar(context, activeList),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: CovePageInsets(
        child: Column(
          children: [
            // Pinned Header: Tab Row & Underline
            Container(
              color: cv.surfaceCanvas,
              padding: const EdgeInsets.only(
                left: CoveSpace.gutter,
                right: CoveSpace.md,
                top: 16,
                bottom: CoveSpace.sm,
              ),
              alignment: Alignment.centerLeft,
              child: CoveTabRow(
                tabs: orderedLists.map((l) => l.name).toList(),
                tabKeys: orderedLists.map((l) => ValueKey('tab_${l.id}')).toList(),
                selectedIndex: safeIndex,
                onTabSelected: (index) {
                  setState(() {
                    _selectedTabIndex = index;
                    _selectedListId = orderedLists[index].id;
                  });
                },
                onReorder: (oldIndex, newIndex) async {
                  if (oldIndex == newIndex) return;

                  final reordered = List<LocalList>.from(orderedLists);
                  final moved = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, moved);

                  final newOrderIds = reordered.map((l) => l.id).toList();

                  setState(() {
                    _customListOrder = newOrderIds;
                    _selectedListId = activeList.id;
                    _selectedTabIndex = reordered.indexWhere((l) => l.id == activeList.id);
                  });

                  final homeId = ref.read(activeHomeIdProvider);
                  if (homeId != null) {
                    try {
                      await _storage.write(
                        key: 'cove_lists_tab_order_$homeId',
                        value: newOrderIds.join(','),
                      );
                    } catch (_) {}

                    try {
                      final emitAction = ref.read(coveEmitActionProvider);
                      await emitAction(
                        eventType: 'lists_reordered',
                        payload: {
                          'home_id': homeId,
                          'order': newOrderIds,
                        },
                        targetHomeId: homeId,
                      );
                    } catch (_) {}
                  }
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.add, size: 18, color: cv.textSecondary),
                      tooltip: 'Add new list',
                      splashRadius: 18,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: CoveSize.avatarRow,
                        minHeight: CoveSize.avatarRow,
                      ),
                      onPressed: _handleCreateNewList,
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, size: 18, color: cv.textSecondary),
                      tooltip: 'List options',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: CoveSize.avatarRow,
                        minHeight: CoveSize.avatarRow,
                      ),
                      color: cv.surfaceCard,
                      shape: CoveShape.border(
                        CoveSpace.md,
                        side: BorderSide(color: cv.lineHairline, width: 1),
                      ),
                      onSelected: (action) {
                        if (action == 'rename') {
                          _handleRenameList(activeList);
                        } else if (action == 'delete') {
                          _handleDeleteList(activeList, lists.length);
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 16, color: cv.textPrimary),
                              const SizedBox(width: CoveSpace.sm),
                              Text(
                                'Rename "${activeList.name}"',
                                style: CoveType.readout.copyWith(
                                  color: cv.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 16, color: cv.statusAlertText),
                              const SizedBox(width: CoveSpace.sm),
                              Text(
                                'Delete "${activeList.name}"',
                                style: CoveType.readout.copyWith(
                                  color: cv.statusAlertText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Body: Reactive Items Feed
            Expanded(
              child: _buildItemsArea(context, activeList),
            ),

            // Pinned Bottom Capsule Input
            _buildPinnedInputBar(context, activeList),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsArea(BuildContext context, LocalList activeList) {
    if (widget.initialItems != null) {
      final filtered = widget.initialItems!
          .where((i) => i.listId == activeList.id)
          .toList();
      return _buildItemsList(context, activeList, filtered);
    }

    final itemsAsync = ref.watch(activeHomeListItemsProvider(activeList.id));

    return itemsAsync.when(
      data: (items) => _buildItemsList(context, activeList, items),
      loading: () => const Center(child: CoveLoading()),
      error: (e, st) => Center(
        child: CoveErrorState.generic(
          title: 'Items unavailable',
          description: 'Could not load list items right now.',
          onRetry: () => ref.invalidate(activeHomeListItemsProvider(activeList.id)),
        ),
      ),
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    LocalList activeList,
    List<LocalListItem> rawItems,
  ) {
    final pendingItemIds = ref.watch(
      pendingDeleteIdsProvider(PendingDeleteKind.listItem),
    );
    final items = pendingItemIds.isEmpty
        ? rawItems
        : rawItems
            .where((i) => !pendingItemIds.contains(i.id))
            .toList(growable: false);
    final cv = context.cv;
    final currentUser = ref.watch(authProvider).value;
    final outbox = ref.watch(activeHomeOutboxProvider).value ?? [];
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);

    final rawActive = items.where((i) => !i.isCompleted).toList();
    final completedItems = items.where((i) => i.isCompleted).toList();

    // Sort active items according to user custom drag-order if exists
    final orderedIds = _customOrderMap[activeList.id] ?? [];
    final List<LocalListItem> activeItems = List.from(rawActive);
    if (orderedIds.isNotEmpty) {
      activeItems.sort((a, b) {
        final indexA = orderedIds.indexOf(a.id);
        final indexB = orderedIds.indexOf(b.id);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });
    }

    final bottomPadding =
        CoveSpace.barClearance + CovePageInsets.bottomOf(context);

    return RefreshIndicator(
      color: cv.accentFill,
      backgroundColor: cv.surfaceCard,
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          CoveSpace.gutter,
          CoveSpace.md,
          CoveSpace.gutter,
          bottomPadding,
        ),
        children: [
          // Actions row: remaining count & "Clear completed"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${activeItems.length} remaining${completedItems.isNotEmpty ? " • ${completedItems.length} completed" : ""}',
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
              if (completedItems.isNotEmpty)
                GestureDetector(
                  onTap: () => _handleClearCompleted(activeList.id, completedItems.length),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: CoveSpace.xs,
                      horizontal: CoveSpace.xs,
                    ),
                    child: Text(
                      'Clear completed',
                      style: CoveType.rowSub.copyWith(
                        color: cv.accentText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: CoveSpace.md),

          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: CoveSpace.xl),
              child: CoveEmptyState(
                icon: Icons.checklist_outlined,
                title: 'No items in ${activeList.name}',
                description: 'Add an item using the field below to share it with ${ref.watch(partnerProfileProvider).displayName}.',
              ),
            )
          else ...[
            // Reorderable active items card
            if (activeItems.isNotEmpty)
              CoveCard(
                padding: EdgeInsets.zero,
                child: CoveShape.clip(
                  CoveRadius.card,
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: activeItems.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final moved = activeItems.removeAt(oldIndex);
                        activeItems.insert(newIndex, moved);
                        _customOrderMap[activeList.id] = activeItems.map((i) => i.id).toList();
                      });
                    },
                    itemBuilder: (ctx, index) {
                      final item = activeItems[index];
                      return Container(
                        key: ValueKey('active_${item.id}'),
                        decoration: BoxDecoration(
                          border: index < activeItems.length - 1
                              ? Border(bottom: BorderSide(color: cv.lineHairline, width: 1))
                              : null,
                        ),
                        child: _buildListItemRow(
                          item,
                          currentUser,
                          outbox,
                          activeList: activeList,
                          hasPartner: hasPartner,
                          dragIndex: index,
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Completed items section
            if (completedItems.isNotEmpty) ...[
              const SizedBox(height: CoveSpace.gutter),
              Text(
                'COMPLETED (${completedItems.length})',
                style: CoveType.capsCard.copyWith(
                  color: cv.textSecondary,
                ),
              ),
              const SizedBox(height: CoveSpace.sm),
              CoveCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: completedItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Container(
                      decoration: BoxDecoration(
                        border: index < completedItems.length - 1
                            ? Border(bottom: BorderSide(color: cv.lineHairline, width: 1))
                            : null,
                      ),
                      child: _buildListItemRow(
                        item,
                        currentUser,
                        outbox,
                        activeList: activeList,
                        hasPartner: hasPartner,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildListItemRow(
    LocalListItem item,
    CoveUser? currentUser,
    List<LocalOutboxEvent> outbox, {
    required LocalList activeList,
    bool hasPartner = true,
    int? dragIndex,
  }) {
    final cv = context.cv;
    final isCompleted = item.isCompleted;

    // Build neutral attribution tag
    final partnerName = ref.watch(partnerProfileProvider).displayName;
    final String baseAttribution;
    if (isCompleted && item.completedBy != null) {
      final isYou = item.completedBy == currentUser?.id;
      baseAttribution = isYou ? 'Completed by You' : 'Completed by $partnerName';
    } else {
      final isYou = item.createdBy == currentUser?.id;
      baseAttribution = isYou ? 'Added by You' : 'Added by $partnerName';
    }

    final rawOwner = item.owner;
    String? ownerLabel;
    if (rawOwner != null && rawOwner.isNotEmpty) {
      if (rawOwner == 'both') {
        ownerLabel = 'Both of you';
      } else if (rawOwner == 'either') {
        ownerLabel = 'Either of you';
      } else if (rawOwner == currentUser?.id ||
          rawOwner == 'local_user' ||
          rawOwner == 'me') {
        ownerLabel = 'You';
      } else {
        ownerLabel = partnerName;
      }
    }
    final attributionText = ownerLabel != null
        ? '$ownerLabel · $baseAttribution'
        : baseAttribution;

    // Determine two-tick delivery status
    final tickStatus = resolveCoveSyncStatus(
      entityId: item.id,
      outbox: outbox,
      hasPartner: hasPartner,
    );

    return Dismissible(
      key: ValueKey('item_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: CoveSpace.gutter),
        color: cv.statusAlert.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline, color: cv.statusAlertText, size: 20),
      ),
      onDismissed: (_) {
        final pendingDelete = ref.read(pendingDeleteServiceProvider);
        pendingDelete.scheduleDelete(
          kind: PendingDeleteKind.listItem,
          id: item.id,
        );
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
      },
      child: CoveChecklistRow(
        value: isCompleted,
        onChanged: (val) async {
          try {
            await ref.read(listControllerProvider).toggleItem(
                  itemId: item.id,
                  isCompleted: val,
                );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.maybeOf(context)
              ?..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text('Could not save: $e'),
                  duration: const Duration(seconds: 3),
                ),
              );
          }
        },
        onTap: () => ListItemDetailSheet.show(
          context,
          item: item,
          listName: activeList.name,
        ),
        onLongPress: () => _handleEditItem(item),
        title: item.title,
        subtitle: attributionText,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoveSyncTick(status: tickStatus, size: 13),
            const SizedBox(width: CoveSpace.xs),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 16, color: cv.textTertiary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: CoveSize.avatarInline,
                minHeight: CoveSize.avatarInline,
              ),
              color: cv.surfaceCard,
              shape: CoveShape.border(
                CoveSpace.md,
                side: BorderSide(color: cv.lineHairline, width: 1),
              ),
              onSelected: (action) {
                if (action == 'details') {
                  ListItemDetailSheet.show(
                    context,
                    item: item,
                    listName: activeList.name,
                  );
                } else if (action == 'edit') {
                  _handleEditItem(item);
                } else if (action == 'delete') {
                  _handleDeleteItem(item);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 15, color: cv.textPrimary),
                      const SizedBox(width: CoveSpace.sm),
                      Text('Details', style: CoveType.readout.copyWith(color: cv.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 15, color: cv.textPrimary),
                      const SizedBox(width: CoveSpace.sm),
                      Text('Edit', style: CoveType.readout.copyWith(color: cv.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 15, color: cv.statusAlertText),
                      const SizedBox(width: CoveSpace.sm),
                      Text('Delete', style: CoveType.readout.copyWith(color: cv.statusAlertText)),
                    ],
                  ),
                ),
              ],
            ),
            if (dragIndex != null) ...[
              const SizedBox(width: 2),
              ReorderableDragStartListener(
                index: dragIndex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.xs,
                    vertical: CoveSpace.sm,
                  ),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 18,
                    color: cv.textTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedInputBar(BuildContext context, LocalList activeList) {
    final cv = context.cv;
    final isWide = kIsWeb && MediaQuery.sizeOf(context).width >= 880;
    final bottomPadding = isWide
        ? 16.0
        : CoveSpace.barClearance + CovePageInsets.bottomOf(context);

    return Container(
      decoration: BoxDecoration(
        color: cv.surfaceCanvas,
        border: Border(
          top: BorderSide(color: cv.lineHairline, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        CoveSpace.gutter,
        10,
        CoveSpace.gutter,
        bottomPadding,
      ),
      child: SafeArea(
        top: false,
        bottom: isWide,
        child: CovePillInput(
          controller: _inputController,
          focusNode: _inputFocusNode,
          hintText: 'Add an item to ${activeList.name}…',
          textInputAction: TextInputAction.send,
          prefixIcon: Icon(Icons.add, size: 18, color: cv.textSecondary),
          suffix: InkWell(
            onTap: () => _handleAddItem(activeList.id),
            customBorder: CoveShape.border(CoveRadius.pill),
            child: Container(
              width: CoveSize.avatarRow,
              height: CoveSize.avatarRow,
              decoration: BoxDecoration(
                color: cv.accentWash,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 16,
                color: cv.accentText,
              ),
            ),
          ),
          onSubmitted: (_) => _handleAddItem(activeList.id),
        ),
      ),
    );
  }
}
