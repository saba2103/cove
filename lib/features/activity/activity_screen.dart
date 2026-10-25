import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_avatar.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_error_state.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_max_width.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_round_button.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/user_profile_controller.dart';
import 'activity_controller.dart';
import 'activity_detail_sheet.dart';
import 'activity_formatter.dart';
import 'activity_models.dart';
import 'activity_read_status_controller.dart';

/// Activity screen (`design/screens/activity.md`).
///
/// Reached from the notification icon in the Today header. Not a nav destination.
///
/// Order:
/// 1. [CovePageHeader] — back, "Activity", unread count, "Mark all read".
/// 2. Digest card on top: no collapse, a chevron day stepper, one paragraph per person.
/// 3. Day-grouped feed, kinds rendered as their forms.
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
  int _digestDayIndex = 0;

  static const double _kFilterChipHeight = 34.0;
  static const double _kHairlineHeight = 1.0;
  static const double _kUnreadRingPadding = 2.0;
  static const double _kUnreadRingStroke = 1.5;
  static const double _kHabitRingSize = 14.0;
  static const double _kHabitRingInnerDot = 6.0;
  static const double _kTicketBarWidth = 3.0;
  static const double _kSyncTickSize = 13.0;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.initialFilter ?? ActivityModule.all;
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.initialActivities == null) {
        ref.read(activityReadStatusProvider.notifier).markAllAsRead();
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
      _digestDayIndex = 0;
    });
    if (widget.initialActivities == null) {
      ref.read(activityModuleFilterProvider.notifier).setFilter(filter);
    }
  }

  List<_ActivityDaySection> _groupActivitiesByDay(
    List<FormattedActivityItem> activities,
  ) {
    final Map<DateTime, List<FormattedActivityItem>> byDay = {};
    for (final item in activities) {
      final local = item.timestamp.toLocal();
      final dayKey = DateTime(local.year, local.month, local.day);
      byDay.putIfAbsent(dayKey, () => []).add(item);
    }
    final sortedDays = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return [
      for (final day in sortedDays)
        _ActivityDaySection(
          date: day,
          items: byDay[day]!,
        ),
    ];
  }

  List<_ActivityEntryGroup> _collapseBatchEntries(
    List<FormattedActivityItem> dayItems,
  ) {
    final groups = <_ActivityEntryGroup>[];
    var i = 0;
    while (i < dayItems.length) {
      final first = dayItems[i];
      if (first.eventType == 'list_item_added') {
        final batch = <FormattedActivityItem>[first];
        var j = i + 1;
        while (j < dayItems.length) {
          final next = dayItems[j];
          final sameActor = next.actorId == first.actorId;
          final sameType = next.eventType == 'list_item_added';
          final sameList = next.detailSubtitle == first.detailSubtitle;
          final closeInTime =
              first.timestamp.difference(next.timestamp).abs().inMinutes <= 5;
          if (sameActor && sameType && sameList && closeInTime) {
            batch.add(next);
            j++;
          } else {
            break;
          }
        }
        groups.add(_ActivityEntryGroup(items: batch));
        i = j;
      } else {
        groups.add(_ActivityEntryGroup(items: [first]));
        i++;
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    final activeHome = widget.initialActivities != null
        ? null
        : ref.watch(activeHomeProvider).value;
    final user = ref.watch(authProvider).value;
    final userProfile = ref.watch(userProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final partnerName = partnerProfile.displayName;
    final readState = ref.watch(activityReadStatusProvider);

    final homeCreatedBy = activeHome?.createdBy ?? user?.id ?? 'user_alex';
    final currentUserId = user?.id ?? 'user_alex';
    final partnerUserId = partnerProfile.userId ?? 'user_sarah';

    final myDisplayName = userProfile.displayName.isNotEmpty
        ? userProfile.displayName
        : (user?.displayName?.isNotEmpty == true ? user!.displayName! : 'You');
    final effectivePartnerName =
        (partnerName.isNotEmpty && partnerName != 'Partner')
            ? partnerName
            : 'Partner';

    final AsyncValue<List<FormattedActivityItem>>? feedAsync =
        widget.initialActivities != null
            ? null
            : ref.watch(activityFeedProvider);

    if (feedAsync != null) {
      if (!feedAsync.hasValue && feedAsync.isLoading) {
        return Scaffold(
          backgroundColor: cv.surfaceCanvas,
          body: CovePageInsets(
            bottom: true,
            child: CoveMaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CovePageHeader(
                    title: 'Activity',
                    leading: CoveRoundButton(
                      icon: Icons.arrow_back_rounded,
                      variant: CoveRoundButtonVariant.ghost,
                      semanticLabel: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const Expanded(child: Center(child: CoveLoading())),
                ],
              ),
            ),
          ),
        );
      }
      if (!feedAsync.hasValue && feedAsync.hasError) {
        return Scaffold(
          backgroundColor: cv.surfaceCanvas,
          body: CovePageInsets(
            bottom: true,
            child: CoveMaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CovePageHeader(
                    title: 'Activity',
                    leading: CoveRoundButton(
                      icon: Icons.arrow_back_rounded,
                      variant: CoveRoundButtonVariant.ghost,
                      semanticLabel: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: CoveErrorState.generic(
                        title: 'Notifications unavailable',
                        description:
                            'Could not load your notifications right now.',
                        onRetry: () => ref.invalidate(activityFeedProvider),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    final List<FormattedActivityItem> allActivities =
        widget.initialActivities ?? (feedAsync?.value ?? const []);
    final int unreadCount = ref.watch(unreadActivityCountProvider);
    final List<FormattedActivityItem> activities = allActivities.where((item) {
      if (_currentFilter == ActivityModule.all) return true;
      return item.module == _currentFilter;
    }).toList();

    _lastLoadedCount = activities.length;

    final daySections = _groupActivitiesByDay(activities);
    final bottomInset = CovePageInsets.bottomOf(context);

    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: CovePageInsets(
        child: SingleChildScrollView(
          key: const PageStorageKey('activity_feed_scroll_key'),
          controller: _scrollController,
          padding: EdgeInsets.only(
            bottom: CoveSpace.barClearance + bottomInset,
          ),
          child: CoveMaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. CovePageHeader — back, "Activity", unread count, "Mark all read"
                CovePageHeader(
                  title: 'Activity',
                  readout: unreadCount > 0 ? '$unreadCount NEW' : null,
                  leading: CoveRoundButton(
                    icon: Icons.arrow_back_rounded,
                    variant: CoveRoundButtonVariant.ghost,
                    semanticLabel: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  trailingPill: CoveHeaderPill(
                    label: 'Mark all read',
                    isActive: unreadCount > 0,
                    onPressed: () => ref
                        .read(activityReadStatusProvider.notifier)
                        .markAllAsRead(),
                  ),
                ),

                const SizedBox(height: CoveSpace.md),

                // Module filter pills
                _buildFilterBar(cv),

                const SizedBox(height: CoveSpace.lg),

                if (activities.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoveSpace.gutter,
                      vertical: CoveSpace.section,
                    ),
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
                else ...[
                  // 2. Digest card on top: no collapse, chevron day stepper, one paragraph per person
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoveSpace.gutter,
                    ),
                    child: _buildDigestCard(
                      daySections: daySections,
                      homeCreatedBy: homeCreatedBy,
                      currentUserId: currentUserId,
                      partnerUserId: partnerUserId,
                      myDisplayName: myDisplayName,
                      partnerDisplayName: effectivePartnerName,
                      cv: cv,
                    ),
                  ),

                  const SizedBox(height: CoveSpace.section),

                  // 3. Day-grouped feed, kinds rendered as their forms
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoveSpace.gutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < daySections.length; i++) ...[
                          if (i > 0) const SizedBox(height: CoveSpace.section),
                          _buildDaySection(
                            section: daySections[i],
                            readState: readState,
                            homeCreatedBy: homeCreatedBy,
                            currentUserId: currentUserId,
                            partnerUserId: partnerUserId,
                            myDisplayName: myDisplayName,
                            partnerDisplayName: effectivePartnerName,
                            cv: cv,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(CoveTokens cv) {
    final duration = CoveMotion.q(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: CoveSpace.gutter),
      child: Row(
        children: [
          for (var i = 0; i < ActivityModule.values.length; i++) ...[
            if (i > 0) const SizedBox(width: CoveSpace.sm),
            _buildFilterChip(
              module: ActivityModule.values[i],
              isSelected: _currentFilter == ActivityModule.values[i],
              duration: duration,
              cv: cv,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required ActivityModule module,
    required bool isSelected,
    required Duration duration,
    required CoveTokens cv,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectFilter(module),
      child: AnimatedContainer(
        duration: duration,
        curve: CoveMotion.easing,
        height: _kFilterChipHeight,
        padding: const EdgeInsets.symmetric(horizontal: CoveSpace.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? cv.accentFill : Colors.transparent,
          borderRadius: const BorderRadius.all(
            Radius.circular(CoveRadius.pill),
          ),
          border: Border.all(
            color: isSelected ? cv.accentFill : cv.lineStrong,
          ),
        ),
        child: Text(
          module.label,
          style: CoveType.readout.copyWith(
            color: isSelected ? cv.textOnAccent : cv.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildDigestCard({
    required List<_ActivityDaySection> daySections,
    required String homeCreatedBy,
    required String currentUserId,
    required String partnerUserId,
    required String myDisplayName,
    required String partnerDisplayName,
    required CoveTokens cv,
  }) {
    final clampedIndex = _digestDayIndex.clamp(0, daySections.length - 1);
    final section = daySections[clampedIndex];
    final canStepOlder = clampedIndex < daySections.length - 1;
    final canStepNewer = clampedIndex > 0;

    final heading = ActivityFormatter.formatDateHeading(section.date);
    final digestTitle = (heading == 'Today' || heading == 'Yesterday')
        ? heading
        : DateFormat('d MMM').format(section.date);

    final myItems = section.items.where((i) => i.isLocalActor).toList();
    final partnerItems = section.items.where((i) => !i.isLocalActor).toList();

    final resolvedPartnerName = partnerItems.isNotEmpty &&
            partnerItems.first.actorName.isNotEmpty &&
            partnerItems.first.actorName != 'You'
        ? partnerItems.first.actorName
        : partnerDisplayName;

    final myPerson = CoveAvatar.resolvePerson(
      homeCreatedBy: homeCreatedBy,
      actorUserId: currentUserId,
    );
    final partnerPerson =
        myPerson == CovePerson.a ? CovePerson.b : CovePerson.a;

    final String myParagraph;
    final bool myEmpty = myItems.isEmpty;
    if (myEmpty) {
      myParagraph = "You haven't added anything yet.";
    } else if (myItems.length == 1) {
      final only = myItems.first;
      myParagraph =
          'You recorded 1 update in ${only.module.label} (${only.timeAgo}) — the only thing from you so far.';
    } else {
      final modules =
          myItems.map((e) => e.module.label).toSet().toList().join(', ');
      myParagraph =
          'You recorded ${myItems.length} updates across $modules.';
    }

    final String partnerParagraph;
    final bool partnerEmpty = partnerItems.isEmpty;
    if (partnerEmpty) {
      partnerParagraph = "$resolvedPartnerName hasn't added anything yet.";
    } else if (partnerItems.length == 1) {
      final only = partnerItems.first;
      partnerParagraph =
          '$resolvedPartnerName recorded 1 update in ${only.module.label} (${only.timeAgo}).';
    } else {
      final modules =
          partnerItems.map((e) => e.module.label).toSet().toList().join(', ');
      partnerParagraph =
          '$resolvedPartnerName recorded ${partnerItems.length} updates across $modules.';
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cv.surfaceCard,
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveRadius.card),
        ),
        border: Border.all(color: cv.lineHairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoveSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    digestTitle,
                    style: CoveType.title.copyWith(color: cv.textPrimary),
                  ),
                ),
                CoveRoundButton.stepper(
                  icon: Icons.chevron_left_rounded,
                  semanticLabel: 'Previous day',
                  onPressed: canStepOlder
                      ? () => setState(() => _digestDayIndex = clampedIndex + 1)
                      : null,
                ),
                const SizedBox(width: CoveSpace.sm),
                CoveRoundButton.stepper(
                  icon: Icons.chevron_right_rounded,
                  semanticLabel: 'Next day',
                  onPressed: canStepNewer
                      ? () => setState(() => _digestDayIndex = clampedIndex - 1)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.md),
            ColoredBox(
              color: cv.lineHairline,
              child: const SizedBox(height: _kHairlineHeight),
            ),
            const SizedBox(height: CoveSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoveAvatar.inline(
                  person: myPerson,
                  nameOrInitial: myDisplayName,
                ),
                const SizedBox(width: CoveSpace.md),
                Expanded(
                  child: Text(
                    myParagraph,
                    style: CoveType.body.copyWith(
                      color: myEmpty ? cv.textTertiary : cv.textSecondary,
                      fontStyle: myEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoveAvatar.inline(
                  person: partnerPerson,
                  nameOrInitial: resolvedPartnerName,
                ),
                const SizedBox(width: CoveSpace.md),
                Expanded(
                  child: Text(
                    partnerParagraph,
                    style: CoveType.body.copyWith(
                      color: partnerEmpty ? cv.textTertiary : cv.textSecondary,
                      fontStyle:
                          partnerEmpty ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaySection({
    required _ActivityDaySection section,
    required ActivityReadState readState,
    required String homeCreatedBy,
    required String currentUserId,
    required String partnerUserId,
    required String myDisplayName,
    required String partnerDisplayName,
    required CoveTokens cv,
  }) {
    final dayDate = section.date;
    final leftDateLabel = DateFormat('d MMM').format(dayDate);
    final rawHeading = ActivityFormatter.formatDateHeading(dayDate);
    final isToday = rawHeading == 'Today';
    final isYesterday = rawHeading == 'Yesterday';
    final rightDayLabel = isToday
        ? 'TODAY'
        : (isYesterday
            ? 'YESTERDAY'
            : DateFormat('EEEE').format(dayDate).toUpperCase());

    final unreadInDay =
        section.items.where((item) => !readState.isRead(item)).length;
    final entryGroups = _collapseBatchEntries(section.items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Day header: date on left, hairline in middle, unread badge + Today/Yesterday/Weekday on right
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              leftDateLabel,
              style: CoveType.rowTitle.copyWith(
                fontFamily: 'LibreBodoni',
                color: cv.textPrimary,
              ),
            ),
            const SizedBox(width: CoveSpace.md),
            Expanded(
              child: ColoredBox(
                color: cv.lineHairline,
                child: const SizedBox(height: _kHairlineHeight),
              ),
            ),
            const SizedBox(width: CoveSpace.md),
            if (unreadInDay > 0) ...[
              Text(
                '$unreadInDay NEW',
                style: CoveType.capsCard.copyWith(color: cv.accentText),
              ),
              const SizedBox(width: CoveSpace.sm),
            ],
            Text(
              rightDayLabel,
              style: CoveType.capsCard.copyWith(
                color: isToday ? cv.accentText : cv.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: CoveSpace.lg),
        for (var i = 0; i < entryGroups.length; i++) ...[
          if (i > 0) const SizedBox(height: CoveSpace.lg),
          _buildEntryGroup(
            group: entryGroups[i],
            readState: readState,
            homeCreatedBy: homeCreatedBy,
            myDisplayName: myDisplayName,
            partnerDisplayName: partnerDisplayName,
            cv: cv,
          ),
        ],
      ],
    );
  }

  Widget _buildEntryGroup({
    required _ActivityEntryGroup group,
    required ActivityReadState readState,
    required String homeCreatedBy,
    required String myDisplayName,
    required String partnerDisplayName,
    required CoveTokens cv,
  }) {
    final primary = group.items.first;
    final isUnread = group.items.any((item) => !readState.isRead(item));
    final isRead = !isUnread;

    final person = CoveAvatar.resolvePerson(
      homeCreatedBy: homeCreatedBy,
      actorUserId: primary.actorId,
    );
    final initialSource = primary.isLocalActor
        ? (myDisplayName != 'You' ? myDisplayName : 'Alex')
        : (primary.actorName != 'Partner'
            ? primary.actorName
            : partnerDisplayName);

    final Widget avatar = CoveAvatar.row(
      person: person,
      nameOrInitial: initialSource,
    );

    final Widget ringAvatar = isUnread
        ? DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: cv.accentFill,
                width: _kUnreadRingStroke,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(_kUnreadRingPadding),
              child: avatar,
            ),
          )
        : avatar;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        for (final item in group.items) {
          ref.read(activityReadStatusProvider.notifier).markAsRead(item.id);
        }
        ActivityDetailDispatcher.openDetail(context, ref, primary);
      },
      child: Padding(
        padding: const EdgeInsets.only(left: CoveSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: ringAvatar,
            ),
            const SizedBox(height: CoveSpace.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: CoveType.body.copyWith(
                        color: isRead ? cv.textSecondary : cv.textPrimary,
                      ),
                      children: [
                        TextSpan(
                          text: primary.actorName,
                          style: CoveType.rowTitle.copyWith(
                            color: isRead ? cv.textSecondary : cv.textPrimary,
                            fontWeight:
                                isRead ? FontWeight.w500 : FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: primary.actionText,
                          style: CoveType.body.copyWith(
                            color: isRead ? cv.textTertiary : cv.textSecondary,
                            fontWeight:
                                isRead ? FontWeight.w400 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: CoveSpace.sm),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      primary.timeAgo,
                      style: CoveType.rowSub.copyWith(
                        color: isRead ? cv.textTertiary : cv.accentText,
                        fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                    if (primary.isLocalActor && !primary.isPrivate) ...[
                      const SizedBox(width: CoveSpace.xs),
                      CoveSyncTick(
                        status: primary.syncStatus,
                        size: _kSyncTickSize,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: CoveSpace.sm),
              child: _buildKindArtifact(
                group: group,
                primary: primary,
                isRead: isRead,
                cv: cv,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKindArtifact({
    required _ActivityEntryGroup group,
    required FormattedActivityItem primary,
    required bool isRead,
    required CoveTokens cv,
  }) {
    final textColor = isRead ? cv.textSecondary : cv.textPrimary;

    final Widget kindBody = switch (primary.module) {
      ActivityModule.lists => _buildListArtifact(group, primary, textColor, cv),
      ActivityModule.expenses ||
      ActivityModule.subscriptions =>
        _buildLedgerArtifact(primary, textColor, cv),
      ActivityModule.habits => _buildHabitArtifact(primary, textColor, cv),
      ActivityModule.calendar => _buildCalendarArtifact(primary, textColor, cv),
      ActivityModule.all => _buildGenericSubtitle(primary, cv),
    };

    if (!primary.isPrivate) {
      return kindBody;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        kindBody,
        const SizedBox(height: CoveSpace.xs),
        DecoratedBox(
          decoration: BoxDecoration(
            color: cv.surfaceRow,
            borderRadius: const BorderRadius.all(
              Radius.circular(CoveRadius.pill),
            ),
            border: Border.all(color: cv.lineHairline),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CoveSpace.sm,
              vertical: CoveSpace.xs,
            ),
            child: Text(
              'Private to you',
              style: CoveType.rowSub.copyWith(color: cv.textTertiary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListArtifact(
    _ActivityEntryGroup group,
    FormattedActivityItem primary,
    Color textColor,
    CoveTokens cv,
  ) {
    if (group.items.length > 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: CoveSpace.sm,
            runSpacing: CoveSpace.sm,
            children: [
              for (var i = 0; i < group.items.length; i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(CoveRadius.pill),
                    ),
                    border: Border.all(color: cv.lineStrong),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoveSpace.md,
                      vertical: CoveSpace.xs,
                    ),
                    child: Text(
                      i == 0
                          ? (group.items[i].targetTitle ??
                              group.items[i].actionText)
                          : group.items[i].actionText,
                      style: CoveType.rowSub.copyWith(color: textColor),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: CoveSpace.xs),
          Text(
            '${group.items.length} things, in one go',
            style: CoveType.rowSub.copyWith(color: cv.textTertiary),
          ),
        ],
      );
    }

    final isToggled = primary.eventType == 'list_item_toggled';
    final subtitle = primary.detailSubtitle;
    if (subtitle == null || subtitle.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isToggled) ...[
          Icon(
            Icons.check_box_rounded,
            size: CoveSpace.lg,
            color: cv.accentFill,
          ),
          const SizedBox(width: CoveSpace.sm),
        ],
        Flexible(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(
                Radius.circular(CoveRadius.pill),
              ),
              border: Border.all(color: cv.lineStrong),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CoveSpace.md,
                vertical: CoveSpace.xs,
              ),
              child: Text(
                subtitle,
                style: CoveType.rowSub.copyWith(color: cv.textTertiary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerArtifact(
    FormattedActivityItem item,
    Color textColor,
    CoveTokens cv,
  ) {
    final rawAmount = (item.rawPayload['amount'] as num?)?.toDouble();
    final sym = ActivityFormatter.getCurrencySymbol(
      item.rawPayload['currency'] as String?,
    );
    final amountText =
        rawAmount != null ? '$sym${formatCoveAmount(rawAmount)}' : null;
    final hasSub =
        item.detailSubtitle != null && item.detailSubtitle!.isNotEmpty;

    if (!hasSub && amountText == null) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (hasSub)
          Expanded(
            child: Text(
              item.detailSubtitle!,
              style: CoveType.rowSub.copyWith(color: cv.textTertiary),
            ),
          )
        else
          const Spacer(),
        if (amountText != null) ...[
          const SizedBox(width: CoveSpace.md),
          Text(
            amountText,
            style: CoveType.rowTitle.copyWith(
              fontFamily: 'LibreBodoni',
              color: textColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHabitArtifact(
    FormattedActivityItem item,
    Color textColor,
    CoveTokens cv,
  ) {
    final hasSub =
        item.detailSubtitle != null && item.detailSubtitle!.isNotEmpty;
    if (!hasSub) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _kHabitRingSize,
          height: _kHabitRingSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: cv.accentFill,
                width: _kUnreadRingStroke,
              ),
            ),
            child: Center(
              child: SizedBox(
                width: _kHabitRingInnerDot,
                height: _kHabitRingInnerDot,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cv.accentFill,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: CoveSpace.sm),
        Flexible(
          child: Text(
            item.detailSubtitle!,
            style: CoveType.rowSub.copyWith(color: cv.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarArtifact(
    FormattedActivityItem item,
    Color textColor,
    CoveTokens cv,
  ) {
    final hasSub =
        item.detailSubtitle != null && item.detailSubtitle!.isNotEmpty;
    if (!hasSub) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cv.surfaceCard,
        borderRadius: const BorderRadius.all(
          Radius.circular(CoveRadius.inline),
        ),
        border: Border.all(color: cv.lineHairline),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoveSpace.md,
          vertical: CoveSpace.sm,
        ),
        child: Row(
          children: [
            SizedBox(
              width: _kTicketBarWidth,
              height: CoveSpace.lg,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: cv.accentFill,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(CoveRadius.pill),
                  ),
                ),
              ),
            ),
            const SizedBox(width: CoveSpace.md),
            Expanded(
              child: Text(
                item.detailSubtitle!,
                style: CoveType.rowSub.copyWith(color: cv.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericSubtitle(FormattedActivityItem item, CoveTokens cv) {
    if (item.detailSubtitle == null || item.detailSubtitle!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      item.detailSubtitle!,
      style: CoveType.rowSub.copyWith(color: cv.textTertiary),
    );
  }
}

class _ActivityDaySection {
  final DateTime date;
  final List<FormattedActivityItem> items;

  const _ActivityDaySection({
    required this.date,
    required this.items,
  });
}

class _ActivityEntryGroup {
  final List<FormattedActivityItem> items;

  const _ActivityEntryGroup({required this.items});
}
