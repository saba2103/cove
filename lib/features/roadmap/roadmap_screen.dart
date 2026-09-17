import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_card.dart';
import '../../core/widgets/cove_checkbox.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import 'roadmap_controller.dart';

class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({super.key});

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  int _selectedTab = 0; // 0: Active, 1: Shipped

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeId = ref.read(activeHomeIdProvider);
      if (homeId != null) {
        ref.read(roadmapControllerProvider).loadCustomOrder(homeId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final roadmapAsync = ref.watch(activeHomeRoadmapProvider);
    final currentUser = ref.watch(authProvider).value;
    final partner = ref.watch(partnerProfileProvider);
    final homeId = ref.watch(activeHomeIdProvider);
    final customOrderMap = ref.watch(roadmapCustomOrderProvider);
    final orderedIds = (homeId != null ? customOrderMap[homeId] : null) ?? [];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text('App Roadmap',
            style: typography.headline.copyWith(fontSize: 20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CovePillButton(
              label: '+ Wish',
              isCompact: true,
              onPressed: () => _showWishSheet(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: roadmapAsync.when(
          loading: () => const Center(child: CoveLoading()),
          error: (err, _) => Center(
            child: Text('Error loading roadmap: $err',
                style: typography.bodyMedium.copyWith(color: colors.accentSecondary)),
          ),
          data: (items) {
            final rawActiveItems = items.where((i) => !i.isCompleted).toList();
            final completedItems = items.where((i) => i.isCompleted).toList();

            // Sort active items based on custom orderedIds (prioritized order)
            final activeItems = [...rawActiveItems];
            if (orderedIds.isNotEmpty) {
              activeItems.sort((a, b) {
                final idxA = orderedIds.indexOf(a.id);
                final idxB = orderedIds.indexOf(b.id);
                if (idxA != -1 && idxB != -1) return idxA.compareTo(idxB);
                if (idxA != -1) return 1; // Unordered/new items appear at the top
                if (idxB != -1) return -1;
                return b.createdAt.compareTo(a.createdAt);
              });
            }

            final currentList = _selectedTab == 0 ? activeItems : completedItems;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Editorial Info Banner
                CoveCard(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accentPrimary.withValues(alpha: 0.12),
                        ),
                        child: Icon(Icons.auto_awesome_outlined,
                            size: 18, color: colors.accentPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Our Cove Wishlist',
                              style: typography.title.copyWith(fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'A safe place for the two of you to dream up feature ideas, drag to prioritize, and watch them come to life.',
                              style: typography.caption.copyWith(
                                color: colors.textMuted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tab Switcher (Active vs Shipped)
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surfaceCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.borderHairline),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabPill(
                          label: 'Active (${activeItems.length})',
                          isSelected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                      ),
                      Expanded(
                        child: _buildTabPill(
                          label: 'Shipped (${completedItems.length})',
                          isSelected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (currentList.isEmpty)
                  CoveEmptyState(
                    icon: _selectedTab == 0
                        ? Icons.checklist_rtl_rounded
                        : Icons.check_circle_outline,
                    title: _selectedTab == 0
                        ? 'No active wishes right now'
                        : 'No shipped requests yet',
                    description: _selectedTab == 0
                        ? 'What would make Cove even calmer or more delightful for the two of you?'
                        : 'Completed wishlist items and built features will gather here.',
                    action: _selectedTab == 0
                        ? CovePillButton(
                            label: '+ Request First Feature',
                            onPressed: () => _showWishSheet(context),
                          )
                        : null,
                  )
                else if (_selectedTab == 0)
                  // Reorderable Active Items Card
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
                            final updatedIds = activeItems.map((i) => i.id).toList();
                            ref.read(roadmapControllerProvider).reorderItems(
                                  orderedIds: updatedIds,
                                );
                          });
                        },
                        itemBuilder: (context, index) {
                          final item = activeItems[index];
                          return Container(
                            key: ValueKey('active_wish_${item.id}'),
                            decoration: BoxDecoration(
                              border: index < activeItems.length - 1
                                  ? Border(
                                      bottom: BorderSide(
                                        color: colors.borderHairline,
                                        width: 1,
                                      ),
                                    )
                                  : null,
                            ),
                            child: _buildRoadmapRow(
                              item: item,
                              currentUser: currentUser,
                              partner: partner,
                              dragIndex: index,
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  // Shipped Items Grouped Card (Historical, no reordering)
                  CoveGroupedCard(
                    children: completedItems.map((item) {
                      return _buildRoadmapRow(
                        item: item,
                        currentUser: currentUser,
                        partner: partner,
                        dragIndex: null,
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoadmapRow({
    required LocalRoadmapItem item,
    required CoveUser? currentUser,
    required PartnerProfileState partner,
    required int? dragIndex,
  }) {
    final colors = context.colors;
    final isMe = item.createdBy == currentUser?.id;
    final creatorLabel = isMe
        ? 'You'
        : (partner.displayName.isNotEmpty ? partner.displayName : 'Partner');
    final dateStr = DateFormat('MMM d').format(item.createdAt);

    final subtitleParts = <String>[];
    if (item.description != null && item.description!.trim().isNotEmpty) {
      subtitleParts.add(item.description!.trim());
    }
    subtitleParts.add('Requested by $creatorLabel · $dateStr');

    return CoveChecklistRow(
      value: item.isCompleted,
      title: item.title,
      subtitle: subtitleParts.join('\n'),
      onTap: () => _showWishSheet(context, item: item),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Edit wish',
            icon: Icon(Icons.edit_outlined, size: 17, color: colors.textSubtle),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _showWishSheet(context, item: item),
          ),
          IconButton(
            tooltip: 'Delete wish',
            icon: Icon(Icons.delete_outline, size: 17, color: colors.textSubtle),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _confirmDelete(context, item),
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
      onChanged: (checked) {
        ref
            .read(roadmapControllerProvider)
            .toggleItem(id: item.id, isCompleted: checked);
      },
    );
  }

  Widget _buildTabPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final typography = context.typography;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.accentPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: typography.caption.copyWith(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? colors.background : colors.textSubtle,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, LocalRoadmapItem item) async {
    final colors = context.colors;
    final typography = context.typography;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        title: Text('Remove Wishlist Item?', style: typography.title),
        content: Text('Remove "${item.title}" from the shared roadmap?',
            style: typography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Remove', style: TextStyle(color: colors.accentSecondary)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(roadmapControllerProvider).deleteItem(item.id);
    }
  }

  void _showWishSheet(BuildContext context, {LocalRoadmapItem? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WishFormSheet(item: item),
    );
  }
}

class _WishFormSheet extends ConsumerStatefulWidget {
  final LocalRoadmapItem? item;

  const _WishFormSheet({this.item});

  @override
  ConsumerState<_WishFormSheet> createState() => _WishFormSheetState();
}

class _WishFormSheetState extends ConsumerState<_WishFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _descController = TextEditingController(text: widget.item?.description ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a title for the feature request.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final controller = ref.read(roadmapControllerProvider);
      final desc = _descController.text.trim().isNotEmpty
          ? _descController.text.trim()
          : null;

      if (widget.item != null) {
        await controller.updateItem(
          id: widget.item!.id,
          title: title,
          description: desc,
        );
      } else {
        await controller.createItem(
          title: title,
          description: desc,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.item != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colors.borderHairline)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.borderHairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isEditing ? 'Edit Feature Request' : 'Request a Feature',
                style: typography.headline.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                'Track updates safely and separately from everyday home todos.',
                style: typography.caption.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 20),

              Text('FEATURE TITLE', style: typography.caption),
              const SizedBox(height: 8),
              CovePillInput(
                controller: _titleController,
                hintText: 'e.g. Shared Spotify queue, Photo memories widget',
              ),
              const SizedBox(height: 18),

              Text('NOTES & WHY WE WANT THIS (OPTIONAL)', style: typography.caption),
              const SizedBox(height: 8),
              CovePillInput(
                controller: _descController,
                hintText: 'Add context, links, or ideas for how it should work...',
              ),
              const SizedBox(height: 16),

              if (_error != null) ...[
                Text(_error!,
                    style: typography.caption.copyWith(color: colors.accentSecondary)),
                const SizedBox(height: 12),
              ],

              CovePillButton(
                label: _isSaving
                    ? 'Saving...'
                    : (isEditing ? 'Save Changes' : 'Add to Roadmap'),
                onPressed: _isSaving ? null : _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
