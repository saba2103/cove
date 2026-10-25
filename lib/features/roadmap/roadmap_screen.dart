import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_tokens.dart';
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
  static const double _kIconSize =
      18.0; // (literal) 18dp banner sparkle and drag handle icon size
  static const double _kRowActionIconSize =
      17.0; // (literal) 17dp edit and delete wish row action icons
  static const double _kDividerWidth =
      1.0; // (literal) 1dp active roadmap list hairline divider width

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
    final cv = context.cv;
    final roadmapAsync = ref.watch(activeHomeRoadmapProvider);
    final currentUser = ref.watch(authProvider).value;
    final partner = ref.watch(partnerProfileProvider);
    final homeId = ref.watch(activeHomeIdProvider);
    final customOrderMap = ref.watch(roadmapCustomOrderProvider);
    final orderedIds = (homeId != null ? customOrderMap[homeId] : null) ?? [];

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      appBar: AppBar(
        title: Text(
          'App Roadmap',
          style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: CoveSpace.md),
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
            child: Text(
              'Error loading roadmap: $err',
              style: CoveType.body.copyWith(color: cv.statusAlertText),
            ),
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
                if (idxA != -1) {
                  return 1; // Unordered/new items appear at the top
                }
                if (idxB != -1) return -1;
                return b.createdAt.compareTo(a.createdAt);
              });
            }

            final currentList = _selectedTab == 0
                ? activeItems
                : completedItems;

            return ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: CoveSpace.gutter,
                vertical: CoveSpace.md,
              ),
              children: [
                // Editorial Info Banner
                CoveCard(
                  padding: const EdgeInsets.all(CoveSpace.gutter),
                  child: Row(
                    children: [
                      Container(
                        width: CoveSize.buttonRound,
                        height: CoveSize.buttonRound,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cv.accentWash,
                        ),
                        child: Icon(
                          Icons.auto_awesome_outlined,
                          size: _kIconSize,
                          color: cv.accentFill,
                        ),
                      ),
                      const SizedBox(width: CoveSpace.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Our Cove Wishlist',
                              style: CoveType.rowTitle.copyWith(
                                color: cv.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: CoveSpace.xs),
                            Text(
                              'A safe place for the two of you to dream up feature ideas, drag to prioritize, and watch them come to life.',
                              style: CoveType.rowSub.copyWith(
                                color: cv.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: CoveSpace.gutter),

                // Tab Switcher (Active vs Shipped)
                Container(
                  height: CoveSize.buttonRound,
                  decoration: BoxDecoration(
                    color: cv.surfaceCard,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(CoveRadius.card),
                    ),
                    border: Border.all(color: cv.lineHairline),
                  ),
                  padding: const EdgeInsets.all(CoveSpace.xs),
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
                const SizedBox(height: CoveSpace.gutter),

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
                    borderRadius: CoveRadius.card,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(CoveRadius.card),
                      ),
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: activeItems.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final moved = activeItems.removeAt(oldIndex);
                            activeItems.insert(newIndex, moved);
                            final updatedIds = activeItems
                                .map((i) => i.id)
                                .toList();
                            ref
                                .read(roadmapControllerProvider)
                                .reorderItems(orderedIds: updatedIds);
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
                                        color: cv.lineHairline,
                                        width: _kDividerWidth,
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

                const SizedBox(height: CoveSpace.section),
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
    final cv = context.cv;
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
            icon: Icon(
              Icons.edit_outlined,
              size: _kRowActionIconSize,
              color: cv.textTertiary,
            ),
            padding: const EdgeInsets.all(CoveSpace.xs),
            constraints: const BoxConstraints(
              minWidth: CoveSize.avatarHeader,
              minHeight: CoveSize.avatarHeader,
            ),
            onPressed: () => _showWishSheet(context, item: item),
          ),
          IconButton(
            tooltip: 'Delete wish',
            icon: Icon(
              Icons.delete_outline,
              size: _kRowActionIconSize,
              color: cv.textTertiary,
            ),
            padding: const EdgeInsets.all(CoveSpace.xs),
            constraints: const BoxConstraints(
              minWidth: CoveSize.avatarHeader,
              minHeight: CoveSize.avatarHeader,
            ),
            onPressed: () => _confirmDelete(context, item),
          ),
          if (dragIndex != null) ...[
            const SizedBox(width: CoveSpace.xs),
            ReorderableDragStartListener(
              index: dragIndex,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoveSpace.xs,
                  vertical: CoveSpace.sm,
                ),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  size: _kIconSize,
                  color: cv.textTertiary,
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
    final cv = context.cv;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: CoveMotion.q(context),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? cv.accentFill : Colors.transparent,
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.inline),
          ),
        ),
        child: Text(
          label,
          style: CoveType.rowSub.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? cv.textOnAccent : cv.textTertiary,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    LocalRoadmapItem item,
  ) async {
    final cv = context.cv;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        title: Text(
          'Remove Wishlist Item?',
          style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
        ),
        content: Text(
          'Remove "${item.title}" from the shared roadmap?',
          style: CoveType.body.copyWith(color: cv.textPrimary),
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
              'Remove',
              style: CoveType.readout.copyWith(color: cv.statusAlertText),
            ),
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
  static const double _kTopPadding =
      16.0; // (literal) 16dp wish form sheet top inset and pre-button gap
  static const double _kHandleWidth =
      36.0; // (literal) 36dp sheet drag handle width
  static const double _kHandleRadius =
      2.0; // (literal) 2dp sheet drag handle pill corner radius

  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title ?? '');
    _descController = TextEditingController(
      text: widget.item?.description ?? '',
    );
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
        await controller.createItem(title: title, description: desc);
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
    final cv = context.cv;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.item != null;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: cv.surfaceSheet,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CoveRadius.sheet),
        ),
        border: Border(top: BorderSide(color: cv.lineHairline)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          CoveSpace.lg,
          _kTopPadding,
          CoveSpace.lg,
          CoveSpace.lg + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: _kHandleWidth,
                  height: CoveSpace.xs,
                  decoration: BoxDecoration(
                    color: cv.lineHairline,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(_kHandleRadius),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CoveSpace.gutter),
              Text(
                isEditing ? 'Edit Feature Request' : 'Request a Feature',
                style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
              ),
              const SizedBox(height: CoveSpace.sm),
              Text(
                'Track updates safely and separately from everyday home todos.',
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.gutter),

              Text(
                'FEATURE TITLE',
                style: CoveType.capsCard.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              CovePillInput(
                controller: _titleController,
                hintText: 'e.g. Shared Spotify queue, Photo memories widget',
              ),
              const SizedBox(height: CoveSpace.gutter),

              Text(
                'NOTES & WHY WE WANT THIS (OPTIONAL)',
                style: CoveType.capsCard.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(height: CoveSpace.sm),
              CovePillInput(
                controller: _descController,
                hintText:
                    'Add context, links, or ideas for how it should work...',
              ),
              const SizedBox(height: _kTopPadding),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: CoveType.rowSub.copyWith(color: cv.statusAlertText),
                ),
                const SizedBox(height: CoveSpace.md),
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
