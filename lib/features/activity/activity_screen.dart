import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_actor_avatar.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_error_state.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/providers/cove_sync_providers.dart';
import 'activity_controller.dart';
import 'activity_detail_sheet.dart';
import 'activity_formatter.dart';
import 'activity_models.dart';
import 'activity_read_status_controller.dart';
import '../profile/partner_profile_controller.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  final List<FormattedActivityItem>? initialActivities;
  final ActivityModule? initialFilter;

  const ActivityScreen({
    super.key,
    this.initialActivities,
    this.initialFilter,
  });

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  late ActivityModule _currentFilter;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _lastLoadedCount = 0;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter ?? ActivityModule.all;
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activityReadStatusProvider.notifier).markAllAsRead();
        // Clear any legacy profile update events from local activity events
        ref.read(appDatabaseProvider).clearProfileActivityEvents();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      if (widget.initialActivities == null && !_isLoadingMore) {
        final currentLimit = ref.read(activityPageLimitProvider);
        if (_lastLoadedCount >= currentLimit) {
          _isLoadingMore = true;
          ref.read(activityPageLimitProvider.notifier).loadMore();
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) setState(() => _isLoadingMore = false);
          });
        }
      }
    }
  }

  void _selectFilter(ActivityModule filter) {
    setState(() {
      _currentFilter = filter;
    });
    if (widget.initialActivities == null) {
      ref.read(activityModuleFilterProvider.notifier).setFilter(filter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final partnerName = ref.watch(partnerProfileProvider).displayName;

    final AsyncValue<List<FormattedActivityItem>>? feedAsync =
        widget.initialActivities != null ? null : ref.watch(activityFeedProvider);

    if (feedAsync != null) {
      // Only show full-screen loader if there is no data loaded yet (initial load)
      if (!feedAsync.hasValue && feedAsync.isLoading) {
        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            title: Text(
              'Notifications',
              style: typography.headline.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            elevation: 0,
            backgroundColor: colors.background,
          ),
          body: const Center(child: CoveLoading()),
        );
      }
      if (!feedAsync.hasValue && feedAsync.hasError) {
        return Scaffold(
          backgroundColor: colors.background,
          appBar: AppBar(
            title: Text(
              'Notifications',
              style: typography.headline.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            elevation: 0,
            backgroundColor: colors.background,
          ),
          body: Center(
            child: CoveErrorState.generic(
              title: 'Notifications unavailable',
              description: 'Could not load your notifications right now.',
              onRetry: () => ref.invalidate(activityFeedProvider),
            ),
          ),
        );
      }
    }

    List<FormattedActivityItem> activities;
    if (widget.initialActivities != null) {
      activities = widget.initialActivities!.where((item) {
        if (_currentFilter == ActivityModule.all) return true;
        return item.module == _currentFilter;
      }).toList();
    } else {
      activities = (feedAsync?.value ?? []).where((item) {
        if (_currentFilter == ActivityModule.all) return true;
        return item.module == _currentFilter;
      }).toList();
    }

    _lastLoadedCount = activities.length;

    // Group activities by date heading
    final Map<String, List<FormattedActivityItem>> grouped = {};
    for (final item in activities) {
      final heading = ActivityFormatter.formatDateHeading(item.timestamp);
      grouped.putIfAbsent(heading, () => []).add(item);
    }

    final unreadCount = ref.watch(unreadActivityCountProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notifications',
              style: typography.headline.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              unreadCount > 0 ? '$unreadCount unread updates' : 'All caught up',
              style: typography.caption.copyWith(
                color: unreadCount > 0 ? colors.accentPrimary : colors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: colors.background,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter pills bar
          _buildFilterBar(context),

          const SizedBox(height: 8),

          // Activity Feed List or Empty State
          Expanded(
            child: activities.isEmpty
                ? Center(
                    child: CoveEmptyState(
                      icon: Icons.history_rounded,
                      title: 'No activity yet',
                      description: _currentFilter == ActivityModule.all
                          ? (partnerName.isNotEmpty && partnerName != 'Partner'
                              ? 'As you and $partnerName use Cove, your shared activity and updates will appear here.'
                              : 'As you and your partner use Cove, your shared activity and updates will appear here.')
                          : 'No activity found in ${_currentFilter.label}.',
                    ),
                  )
                : ListView.builder(
                    key: const PageStorageKey('activity_feed_scroll_key'),
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: grouped.keys.length,
                    itemBuilder: (context, idx) {
                          final heading = grouped.keys.elementAt(idx);
                          final items = grouped[heading]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4),
                                child: Text(
                                  heading.toUpperCase(),
                                  style: typography.caption.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.1,
                                    color: colors.textSubtle,
                                  ),
                                ),
                              ),
                              CoveGroupedCard(
                                children: items.map((item) => _buildActivityRow(context, item)).toList(),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: ActivityModule.values.map((module) {
          final isSelected = _currentFilter == module;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _selectFilter(module),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.accentPrimary
                      : colors.surfaceCard,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? colors.accentPrimary
                        : colors.borderHairline,
                    width: 1,
                  ),
                ),
                child: Text(
                  module.label,
                  style: typography.caption.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colors.background
                        : colors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityRow(BuildContext context, FormattedActivityItem item) {
    final colors = context.colors;
    final typography = context.typography;
    final isRead = ref.watch(activityReadStatusProvider).isRead(item);

    return Material(
      color: isRead ? Colors.transparent : colors.accentPrimary.withValues(alpha: 0.05),
      child: InkWell(
        onTap: () {
          ref.read(activityReadStatusProvider.notifier).markAsRead(item.id);
          ActivityDetailDispatcher.openDetail(context, ref, item);
        },
        child: Container(
          decoration: BoxDecoration(
            border: isRead
                ? null
                : Border(
                    left: BorderSide(
                      color: colors.accentPrimary,
                      width: 3.5,
                    ),
                  ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isRead ? 16 : 12.5,
            vertical: 14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Actor Profile Avatar with Action Badge and Unread dot
              CoveActorAvatar(
                item: item,
                isRead: isRead,
                size: 38,
              ),
              const SizedBox(width: 14),

              // Main Description: Actor + Action Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: typography.bodyRegular.copyWith(
                          fontSize: 14,
                          color: colors.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: item.actorName,
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(
                            text: item.actionText,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.detailSubtitle != null &&
                        item.detailSubtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.detailSubtitle!,
                        style: typography.caption.copyWith(
                          fontSize: 12,
                          color: colors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    if (item.isPrivate) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.surfaceRow,
                          borderRadius: BorderRadius.circular(4),
                          border:
                              Border.all(color: colors.borderHairline, width: 1),
                        ),
                        child: Text(
                          'Private to you',
                          style: typography.caption.copyWith(
                            fontSize: 10,
                            color: colors.textSubtle,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Trailing: Timestamp + Sync Tick + Chevron
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.timeAgo,
                        style: typography.caption.copyWith(
                          fontSize: 12,
                          color: isRead ? colors.textSubtle : colors.accentPrimary,
                          fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                      if (item.isLocalActor && !item.isPrivate) ...[
                        const SizedBox(height: 4),
                        CoveSyncTick(
                          status: item.syncStatus,
                          size: 13,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: colors.textSubtle.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
