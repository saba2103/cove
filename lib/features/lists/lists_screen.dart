import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_checkbox.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../core/widgets/cove_tab_row.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import 'create_list_dialog.dart';
import 'list_controller.dart';

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
  int _selectedTabIndex = 0;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialLists == null) {
        ref.read(listControllerProvider).ensureDefaultLists();
      }
    });
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
      // Switch to the newly created list
      setState(() {
        // We'll let the reactive lists stream update the index
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (widget.initialLists != null) {
      return _buildWithLists(context, widget.initialLists!);
    }

    final listsAsync = ref.watch(activeHomeListsProvider);

    return listsAsync.when(
      data: (lists) => _buildWithLists(context, lists),
      loading: () => Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CoveLoading()),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: colors.background,
        body: Center(child: Text('Failed to load lists: $e')),
      ),
    );
  }

  Widget _buildWithLists(BuildContext context, List<LocalList> lists) {
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

    final safeIndex = _selectedTabIndex.clamp(0, lists.length - 1);
    final activeList = lists[safeIndex];

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
              tabs: lists.map((l) => l.name).toList(),
              selectedIndex: safeIndex,
              onTabSelected: (index) {
                setState(() => _selectedTabIndex = index);
              },
              trailing: IconButton(
                icon: Icon(Icons.add, size: 18, color: colors.textMuted),
                tooltip: 'Add new list',
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _handleCreateNewList,
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
      error: (e, st) => Center(child: Text('Error loading items: $e')),
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

    final activeItems = items.where((i) => !i.isCompleted).toList();
    final completedItems = items.where((i) => i.isCompleted).toList();

    return ListView(
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
              description: 'Add an item using the field below to share it with your partner.',
            ),
          )
        else
          CoveGroupedCard(
            children: [
              ...activeItems.map((item) => _buildListItemRow(item, currentUser, outbox)),
              ...completedItems.map((item) => _buildListItemRow(item, currentUser, outbox)),
            ],
          ),

        // Space to scroll past pinned input
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildListItemRow(
    LocalListItem item,
    CoveUser? currentUser,
    List<LocalOutboxEvent> outbox,
  ) {
    final colors = context.colors;
    final isCompleted = item.isCompleted;

    // Build neutral attribution tag
    final String attributionText;
    if (isCompleted && item.completedBy != null) {
      final isYou = item.completedBy == currentUser?.id;
      attributionText = isYou ? 'Completed by You' : 'Completed by Partner';
    } else {
      final isYou = item.createdBy == currentUser?.id;
      attributionText = isYou ? 'Added by You' : 'Added by Partner';
    }

    // Determine two-tick delivery status
    CoveSyncStatus tickStatus = CoveSyncStatus.savedLocally;
    final outboxItem = outbox.firstWhere(
      (o) => o.payloadJson.contains(item.id),
      orElse: () => LocalOutboxEvent(
        id: '',
        homeId: '',
        actorId: '',
        eventType: '',
        payloadJson: '',
        encryptedPayload: '',
        createdAt: DateTime.now(),
        syncStatus: 'syncedToPartner',
        retryCount: 0,
      ),
    );
    if (outboxItem.syncStatus == 'syncedToPartner') {
      tickStatus = CoveSyncStatus.syncedToPartner;
    }

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
      },
      child: CoveChecklistRow(
        value: isCompleted,
        onChanged: (val) {
          ref.read(listControllerProvider).toggleItem(
                itemId: item.id,
                isCompleted: val,
              );
        },
        title: item.title,
        subtitle: attributionText,
        trailing: CoveSyncTick(status: tickStatus, size: 13),
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
