import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_checkbox.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_error_state.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../core/widgets/cove_tab_row.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
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
  FlutterSecureStorage get _storage => ref.read(homeKeyStoreProvider).storage;

  int _selectedTabIndex = 0;
  String? _selectedListId;
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
          'Clear completed items?',
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'This will remove $completedCount completed item${completedCount > 1 ? "s" : ""} from this list.',
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
              style: TextStyle(
                fontFamily: 'GeneralSans',
                color: colors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Clear',
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

    if (confirmed == true) {
      final controller = ref.read(listControllerProvider);
      await controller.clearCompleted(listId: activeListId);
    }
  }

  Future<void> _handleRenameList(LocalList list) async {
    final colors = context.colors;
    final controller = TextEditingController(text: list.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderHairline, width: 1),
        ),
        title: Text(
          'Rename list',
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 15,
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'List name',
            hintStyle: TextStyle(color: colors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.borderHairline),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.accentPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'GeneralSans', color: colors.textMuted),
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

    if (newName != null && newName.isNotEmpty && newName != list.name) {
      await ref.read(listControllerProvider).renameList(
            listId: list.id,
            newName: newName,
          );
    }
  }

  Future<void> _handleDeleteList(LocalList list, int totalCount) async {
    final colors = context.colors;
    final partnerName = ref.read(partnerProfileProvider).displayName;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderHairline, width: 1),
        ),
        title: Text(
          'Delete "${list.name}"?',
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'This will permanently delete this list and all its items for you and $partnerName.',
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
    final colors = context.colors;
    final controller = TextEditingController(text: item.title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.borderHairline, width: 1),
        ),
        title: Text(
          'Edit item',
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 15,
            color: colors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Item name',
            hintStyle: TextStyle(color: colors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.borderHairline),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.accentPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'GeneralSans', color: colors.textMuted),
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

    if (newTitle != null && newTitle.isNotEmpty && newTitle != item.title) {
      await ref.read(listControllerProvider).updateItem(
            itemId: item.id,
            title: newTitle,
            notes: item.notes,
          );
    }
  }

  Future<void> _handleDeleteItem(LocalListItem item) async {
    await ref.read(listControllerProvider).deleteItem(itemId: item.id);
    if (mounted) {
      CoveUndoToast.show(
        context,
        message: 'Deleted "${item.title}"',
        onUndo: () async {
          await ref.read(listControllerProvider).addItem(
                listId: item.listId,
                title: item.title,
              );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);

    if (widget.initialLists != null) {
      return _buildWithLists(context, widget.initialLists!, hasPartner: hasPartner);
    }

    final listsAsync = ref.watch(activeHomeListsProvider);

    return listsAsync.when(
      data: (lists) => _buildWithLists(context, lists, hasPartner: hasPartner),
      loading: () => Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CoveLoading()),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CoveErrorState.generic(
            title: 'Lists unavailable',
            description: 'Could not load your lists right now.',
            onRetry: () => ref.invalidate(activeHomeListsProvider),
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
    final colors = context.colors;

    if (lists.isEmpty) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CoveEmptyState(
            icon: Icons.checklist_outlined,
            title: 'No shared lists yet',
            description: 'Start tracking joint groceries, packing lists, and household essentials.',
            action: TextButton.icon(
              onPressed: _handleCreateNewList,
              icon: Icon(Icons.add, size: 16, color: colors.accentPrimary),
              label: Text(
                'Create First List',
                style: TextStyle(
                  fontFamily: 'GeneralSans',
                  fontWeight: FontWeight.w600,
                  color: colors.accentPrimary,
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

    final typography = context.typography;
    final isWide = kIsWeb && MediaQuery.sizeOf(context).width >= 880;

    if (isWide) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Pane: Lists Navigator
            Container(
              width: 280,
              decoration: BoxDecoration(
                color: colors.surfaceCard.withValues(alpha: 0.5),
                border: Border(
                  right: BorderSide(color: colors.borderHairline, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 12, top: 20, bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'SHARED LISTS',
                          style: typography.caption.copyWith(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: colors.textMuted,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_rounded, size: 20, color: colors.accentPrimary),
                          tooltip: 'Add new list',
                          onPressed: _handleCreateNewList,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: orderedLists.length,
                      itemBuilder: (ctx, idx) {
                        final list = orderedLists[idx];
                        final isSelected = idx == safeIndex;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedTabIndex = idx;
                                  _selectedListId = list.id;
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colors.accentPrimary.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isSelected
                                      ? Border.all(
                                          color: colors.accentPrimary.withValues(alpha: 0.3),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.checklist_rounded
                                          : Icons.checklist_rtl_rounded,
                                      size: 18,
                                      color: isSelected ? colors.accentPrimary : colors.textMuted,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        list.name,
                                        style: typography.bodyRegular.copyWith(
                                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected ? colors.textPrimary : colors.textMuted,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: Icon(Icons.more_horiz_rounded, size: 16, color: colors.textSubtle),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      color: colors.surfaceCard,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: colors.borderHairline, width: 1),
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
                                              Icon(Icons.edit_outlined, size: 16, color: colors.textPrimary),
                                              const SizedBox(width: 8),
                                              Text('Rename', style: TextStyle(color: colors.textPrimary, fontSize: 14)),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 16, color: colors.accentSecondary),
                                              const SizedBox(width: 8),
                                              Text('Delete', style: TextStyle(color: colors.accentSecondary, fontSize: 14)),
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
                      color: colors.background,
                      border: Border(
                        bottom: BorderSide(color: colors.borderHairline, width: 1),
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
                              style: typography.headline.copyWith(fontSize: 22),
                            ),
                            Text(
                              'Shared with partner · Instant sync',
                              style: typography.caption.copyWith(color: colors.textMuted),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 18, color: colors.textMuted),
                              tooltip: 'Rename list',
                              onPressed: () => _handleRenameList(activeList),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline, size: 18, color: colors.accentSecondary),
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
      backgroundColor: colors.background,
      body: Column(
        children: [
          // Pinned Header: Tab Row & Underline
          Container(
            color: colors.background,
            padding: const EdgeInsets.only(left: 20, right: 12, top: 16, bottom: 8),
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
                    icon: Icon(Icons.add, size: 18, color: colors.textMuted),
                    tooltip: 'Add new list',
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _handleCreateNewList,
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, size: 18, color: colors.textMuted),
                    tooltip: 'List options',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    color: colors.surfaceCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: colors.borderHairline, width: 1),
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
                            Icon(Icons.edit_outlined, size: 16, color: colors.textPrimary),
                            const SizedBox(width: 8),
                            Text(
                              'Rename "${activeList.name}"',
                              style: TextStyle(
                                fontFamily: 'GeneralSans',
                                color: colors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 16, color: colors.accentSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'Delete "${activeList.name}"',
                              style: TextStyle(
                                fontFamily: 'GeneralSans',
                                color: colors.accentSecondary,
                                fontSize: 14,
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
    List<LocalListItem> items,
  ) {
    final colors = context.colors;
    final typography = context.typography;
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

    return RefreshIndicator(
      color: colors.accentPrimary,
      backgroundColor: colors.surfaceCard,
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Actions row: remaining count & "Clear completed"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${activeItems.length} remaining${completedItems.isNotEmpty ? " • ${completedItems.length} completed" : ""}',
                style: typography.caption.copyWith(color: colors.textMuted),
              ),
              if (completedItems.isNotEmpty)
                GestureDetector(
                  onTap: () => _handleClearCompleted(activeList.id, completedItems.length),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: Text(
                      'Clear completed',
                      style: typography.caption.copyWith(
                        color: colors.accentPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
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
                borderRadius: 18,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ReorderableListView.builder(
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
                              ? Border(bottom: BorderSide(color: colors.borderHairline, width: 1))
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
              const SizedBox(height: 20),
              Text(
                'COMPLETED (${completedItems.length})',
                style: typography.caption.copyWith(
                  letterSpacing: 0.8,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              CoveCard(
                padding: EdgeInsets.zero,
                borderRadius: 18,
                child: Column(
                  children: completedItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Container(
                      decoration: BoxDecoration(
                        border: index < completedItems.length - 1
                            ? Border(bottom: BorderSide(color: colors.borderHairline, width: 1))
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

          // Space to scroll past pinned input
          const SizedBox(height: 24),
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
    final colors = context.colors;
    final isCompleted = item.isCompleted;

    // Build neutral attribution tag
    final partnerName = ref.watch(partnerProfileProvider).displayName;
    final String attributionText;
    if (isCompleted && item.completedBy != null) {
      final isYou = item.completedBy == currentUser?.id;
      attributionText = isYou ? 'Completed by You' : 'Completed by $partnerName';
    } else {
      final isYou = item.createdBy == currentUser?.id;
      attributionText = isYou ? 'Added by You' : 'Added by $partnerName';
    }

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
        padding: const EdgeInsets.only(right: 20),
        color: colors.accentSecondary.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline, color: colors.accentSecondary, size: 20),
      ),
      onDismissed: (_) {
        ref.read(listControllerProvider).deleteItem(itemId: item.id);
        CoveUndoToast.show(
          context,
          message: 'Deleted "${item.title}"',
          onUndo: () async {
            await ref.read(listControllerProvider).addItem(
                  listId: item.listId,
                  title: item.title,
                );
          },
        );
      },
      child: CoveChecklistRow(
        value: isCompleted,
        onChanged: (val) {
          ref.read(listControllerProvider).toggleItem(
                itemId: item.id,
                isCompleted: val,
              );
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
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 16, color: colors.textSubtle),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              color: colors.surfaceCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colors.borderHairline, width: 1),
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
                      Icon(Icons.info_outline, size: 15, color: colors.textPrimary),
                      const SizedBox(width: 8),
                      Text('Details', style: TextStyle(color: colors.textPrimary, fontSize: 14)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 15, color: colors.textPrimary),
                      const SizedBox(width: 8),
                      Text('Edit', style: TextStyle(color: colors.textPrimary, fontSize: 14)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 15, color: colors.accentSecondary),
                      const SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: colors.accentSecondary, fontSize: 14)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 18,
                    color: colors.textSubtle,
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
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          top: BorderSide(color: colors.borderHairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: SafeArea(
        top: false,
        child: CovePillInput(
          controller: _inputController,
          focusNode: _inputFocusNode,
          hintText: 'Add an item to ${activeList.name}…',
          textInputAction: TextInputAction.send,
          prefixIcon: Icon(Icons.add, size: 18, color: colors.textMuted),
          suffix: InkWell(
            onTap: () => _handleAddItem(activeList.id),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.accentPrimary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 16,
                color: colors.accentPrimary,
              ),
            ),
          ),
          onSubmitted: (_) => _handleAddItem(activeList.id),
        ),
      ),
    );
  }
}
