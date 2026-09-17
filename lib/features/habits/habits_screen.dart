import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_checkbox.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_error_state.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_streak_badge.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import 'habit_controller.dart';
import 'habit_detail_sheet.dart';
import 'habit_form_sheet.dart';
import 'habit_schedule.dart';
import 'habit_streak_calculator.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  final List<LocalHabit>? initialHabits;
  final List<LocalHabitCheckin>? initialCheckins;
  final CoveUser? currentUser;

  const HabitsScreen({
    super.key,
    this.initialHabits,
    this.initialCheckins,
    this.currentUser,
  });

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outboxEvents = ref.watch(activeHomeOutboxProvider).value ?? [];
    final currentUser = widget.currentUser ?? ref.watch(authProvider).value;
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);

    if (widget.initialHabits != null) {
      return _buildContent(
        context,
        widget.initialHabits!,
        widget.initialCheckins ?? [],
        outboxEvents,
        currentUser,
        hasPartner: hasPartner,
      );
    }

    final habitsAsync = ref.watch(activeHomeHabitsProvider);
    final checkinsAsync = ref.watch(activeHomeAllHabitCheckinsProvider);

    if (habitsAsync.isLoading || checkinsAsync.isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: const Center(child: CoveLoading()),
      );
    }

    if (habitsAsync.hasError) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: CoveErrorState.generic(
            title: 'Habits unavailable',
            description: 'Could not load your habits and rhythms right now.',
            onRetry: () {
              ref.invalidate(activeHomeHabitsProvider);
              ref.invalidate(activeHomeAllHabitCheckinsProvider);
            },
          ),
        ),
      );
    }

    final habits = habitsAsync.value ?? [];
    final checkins = checkinsAsync.value ?? [];
    return _buildContent(
        context, habits, checkins, outboxEvents, currentUser, hasPartner: hasPartner);
  }

  Widget _buildContent(
    BuildContext context,
    List<LocalHabit> habits,
    List<LocalHabitCheckin> allCheckins,
    List<LocalOutboxEvent> outboxEvents,
    CoveUser? currentUser, {
    bool hasPartner = true,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final userId = currentUser?.id ?? 'local_user';

    final isDesktop = kIsWeb && MediaQuery.sizeOf(context).width >= 840;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Habits & Rhythms',
          style: typography.headline.copyWith(fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CovePillButton(
              label: '+ New',
              variant: CoveButtonVariant.secondary,
              isCompact: true,
              onPressed: () => HabitFormSheet.show(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 1200 : 540),
            child: habits.isEmpty
                ? _buildEmptyState(context)
                : _buildHabitsList(
                    context, habits, allCheckins, outboxEvents, userId,
                    hasPartner: hasPartner),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return CoveEmptyState(
      icon: Icons.repeat_outlined,
      title: 'No Habits Logged',
      description:
          'Track personal rhythms together or privately without gamified noise or guilt.',
      action: CovePillButton(
        label: 'Create First Habit',
        onPressed: () => HabitFormSheet.show(context),
      ),
    );
  }

  Widget _buildHabitsList(
    BuildContext context,
    List<LocalHabit> habits,
    List<LocalHabitCheckin> allCheckins,
    List<LocalOutboxEvent> outboxEvents,
    String userId, {
    bool hasPartner = true,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final partnerName = ref.watch(partnerProfileProvider).displayName;

    // Group habits into:
    // 1. Your Habits (owned by user, targetDaysPerWeek >= 0)
    // 2. Partner's Shared Habits (owned by partner, targetDaysPerWeek >= 0)
    // 3. Private Habits (owned by user, targetDaysPerWeek < 0)
    final yourShared = habits
        .where((h) => h.createdBy == userId && h.targetDaysPerWeek >= 0)
        .toList();
    final partnerShared = habits
        .where((h) => h.createdBy != userId && h.targetDaysPerWeek >= 0)
        .toList();
    final yourPrivate = habits
        .where((h) => h.createdBy == userId && h.targetDaysPerWeek < 0)
        .toList();

    final isDesktop = kIsWeb && MediaQuery.sizeOf(context).width >= 960;

    if (isDesktop) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (yourShared.isNotEmpty) ...[
                      Text('YOUR SHARED RHYTHMS', style: typography.caption),
                      const SizedBox(height: 8),
                      CoveGroupedCard(
                        children: yourShared.map((habit) {
                          final habitCheckins =
                              allCheckins.where((c) => c.habitId == habit.id).toList();
                          return _buildInteractiveHabitRow(
                            context,
                            habit: habit,
                            checkins: habitCheckins,
                            outboxEvents: outboxEvents,
                            isPrivate: false,
                            hasPartner: hasPartner,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (yourPrivate.isNotEmpty) ...[
                      Row(
                        children: [
                          Text('PRIVATE TO YOU', style: typography.caption),
                          const SizedBox(width: 6),
                          Icon(Icons.lock_outline, size: 12, color: colors.textMuted),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CoveGroupedCard(
                        children: yourPrivate.map((habit) {
                          final habitCheckins =
                              allCheckins.where((c) => c.habitId == habit.id).toList();
                          return _buildInteractiveHabitRow(
                            context,
                            habit: habit,
                            checkins: habitCheckins,
                            outboxEvents: outboxEvents,
                            isPrivate: true,
                            hasPartner: hasPartner,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (partnerShared.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${partnerName.toUpperCase()}'S RHYTHMS",
                              style: typography.caption),
                          Text('Read-only',
                              style: typography.caption
                                  .copyWith(fontSize: 11, color: colors.textSubtle)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      CoveGroupedCard(
                        children: partnerShared.map((habit) {
                          final habitCheckins =
                              allCheckins.where((c) => c.habitId == habit.id).toList();
                          return _buildPartnerReadOnlyRow(
                            context,
                            habit: habit,
                            checkins: habitCheckins,
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // 1. YOUR HABITS
        if (yourShared.isNotEmpty) ...[
          Text('YOUR SHARED RHYTHMS', style: typography.caption),
          const SizedBox(height: 8),
          CoveGroupedCard(
            children: yourShared.map((habit) {
              final habitCheckins =
                  allCheckins.where((c) => c.habitId == habit.id).toList();
              return _buildInteractiveHabitRow(
                context,
                habit: habit,
                checkins: habitCheckins,
                outboxEvents: outboxEvents,
                isPrivate: false,
                hasPartner: hasPartner,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // 2. PARTNER'S SHARED HABITS (READ-ONLY VIEW)
        if (partnerShared.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${partnerName.toUpperCase()}'S RHYTHMS", style: typography.caption),
              Text('Read-only',
                  style: typography.caption
                      .copyWith(fontSize: 11, color: colors.textSubtle)),
            ],
          ),
          const SizedBox(height: 8),
          CoveGroupedCard(
            children: partnerShared.map((habit) {
              final habitCheckins =
                  allCheckins.where((c) => c.habitId == habit.id).toList();
              return _buildPartnerReadOnlyRow(
                context,
                habit: habit,
                checkins: habitCheckins,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // 3. YOUR PRIVATE HABITS
        if (yourPrivate.isNotEmpty) ...[
          Row(
            children: [
              Text('PRIVATE TO YOU', style: typography.caption),
              const SizedBox(width: 6),
              Icon(Icons.lock_outline, size: 12, color: colors.textMuted),
            ],
          ),
          const SizedBox(height: 8),
          CoveGroupedCard(
            children: yourPrivate.map((habit) {
              final habitCheckins =
                  allCheckins.where((c) => c.habitId == habit.id).toList();
              return _buildInteractiveHabitRow(
                context,
                habit: habit,
                checkins: habitCheckins,
                outboxEvents: outboxEvents,
                isPrivate: true,
                hasPartner: hasPartner,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  /// Interactive row for the user's own habits.
  Widget _buildInteractiveHabitRow(
    BuildContext context, {
    required LocalHabit habit,
    required List<LocalHabitCheckin> checkins,
    required List<LocalOutboxEvent> outboxEvents,
    required bool isPrivate,
    bool hasPartner = true,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final streak = HabitStreakCalculator.calculate(
      habit: habit,
      checkins: checkins,
    );

    // Sync status
    final syncStatus = resolveCoveSyncStatus(
      entityId: habit.id,
      outbox: outboxEvents,
      isPrivate: isPrivate,
      hasPartner: hasPartner,
    );

    final schedule = HabitSchedule.parse(habit.cadence, targetDays: habit.targetDaysPerWeek);
    final cadenceLabel = schedule.formatDisplayLabel(targetDays: habit.targetDaysPerWeek);

    return Dismissible(
      key: ValueKey('dismiss_${habit.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colors.accentSecondary.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline, size: 20, color: colors.accentSecondary),
      ),
      confirmDismiss: (_) => _showDeleteConfirmation(context, habit),
      onDismissed: (_) {
        ref.read(habitControllerProvider).deleteHabit(habit);
        CoveUndoToast.show(
          context,
          message: 'Deleted "${habit.name}"',
          onUndo: () async {
            await ref.read(habitControllerProvider).createHabit(
                  name: habit.name,
                  cadence: habit.cadence,
                  targetDaysPerWeek: habit.targetDaysPerWeek.abs(),
                  visibility: habit.targetDaysPerWeek < 0
                      ? HabitVisibility.privateToMe
                      : HabitVisibility.shared,
                );
          },
        );
      },
      child: InkWell(
        onTap: () => HabitDetailSheet.show(context, habit: habit, checkins: checkins),
        splashColor: colors.accentPrimary.withValues(alpha: 0.05),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Checkbox for today's checkin
              CoveCheckbox(
                value: streak.isCheckedToday,
                onChanged: (checked) {
                  ref.read(habitControllerProvider).toggleCheckin(
                        habit: habit,
                        checked: checked,
                      );
                },
              ),
              const SizedBox(width: 14),

              // Title & Cadence
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            habit.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'GeneralSans',
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: streak.isCheckedToday
                                  ? colors.textMuted
                                  : colors.textPrimary,
                              decoration: streak.isCheckedToday
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: colors.textMuted,
                            ),
                          ),
                        ),
                        if (streak.hasAcknowledgmentToday) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colors.accentPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Acknowledged',
                              style: TextStyle(
                                fontFamily: 'GeneralSans',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: colors.accentPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          cadenceLabel,
                          style: typography.caption.copyWith(
                            fontSize: 12,
                            color: colors.textSubtle,
                          ),
                        ),
                        if (streak.bestStreak > 0) ...[
                          Text(
                            ' • Best: ${streak.bestStreak}',
                            style: typography.caption.copyWith(
                              fontSize: 12,
                              color: colors.textSubtle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Streak Indicator in Bodoni Moda (no flames / badges)
              CoveStreakIndicator(
                count: streak.currentStreak,
                label: habit.cadence.startsWith('weekly') ? 'wks' : 'days',
              ),
              const SizedBox(width: 10),

              // Two-tick sync status
              CoveSyncTick(status: syncStatus),
              const SizedBox(width: 4),

              // Edit / Delete Popup Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 16, color: colors.textSubtle),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                color: colors.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.borderHairline, width: 1),
                ),
                onSelected: (action) async {
                  if (action == 'edit') {
                    HabitFormSheet.show(context, existing: habit);
                  } else if (action == 'delete') {
                    final confirmed = await _showDeleteConfirmation(context, habit);
                    if (confirmed == true) {
                      await ref.read(habitControllerProvider).deleteHabit(habit);
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 15, color: colors.textPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'Edit Habit',
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
                        Icon(Icons.delete_outline, size: 15, color: colors.accentSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Delete Habit',
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
    );
  }

  /// Read-only row for partner's shared habits with optional quiet acknowledge tap.
  Widget _buildPartnerReadOnlyRow(
    BuildContext context, {
    required LocalHabit habit,
    required List<LocalHabitCheckin> checkins,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final streak = HabitStreakCalculator.calculate(
      habit: habit,
      checkins: checkins,
    );

    final schedule = HabitSchedule.parse(habit.cadence, targetDays: habit.targetDaysPerWeek);
    final cadenceLabel = schedule.formatDisplayLabel(targetDays: habit.targetDaysPerWeek);

    return InkWell(
      onTap: () => HabitDetailSheet.show(
        context,
        habit: habit,
        checkins: checkins,
        isPartnerHabit: true,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
        children: [
          // Passive indicator: subtle circle showing completed vs resting (no red alarm!)
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: streak.isCheckedToday
                  ? colors.accentPrimary.withValues(alpha: 0.25)
                  : Colors.transparent,
              border: Border.all(
                color: streak.isCheckedToday
                    ? colors.accentPrimary
                    : colors.textSubtle.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: streak.isCheckedToday
                ? Icon(
                    Icons.check,
                    size: 12,
                    color: colors.accentPrimary,
                  )
                : null,
          ),
          const SizedBox(width: 14),

          // Title & Progress Note (calm, zero guilt/alarms)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyMedium.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  streak.isCheckedToday
                      ? '$cadenceLabel • Completed today'
                      : '$cadenceLabel • Resting today',
                  style: typography.caption.copyWith(
                    fontSize: 12,
                    color: colors.textSubtle,
                  ),
                ),
              ],
            ),
          ),

          // Streak Counter
          CoveStreakIndicator(
            count: streak.currentStreak,
            label: habit.cadence.startsWith('weekly') ? 'wks' : 'days',
          ),
          const SizedBox(width: 12),

          // Quiet Acknowledge Tap
          if (streak.isCheckedToday)
            GestureDetector(
              onTap: () {
                ref.read(habitControllerProvider).acknowledgeCheckin(
                      habit: habit,
                    );
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: streak.hasAcknowledgmentToday
                      ? colors.accentPrimary.withValues(alpha: 0.15)
                      : colors.surfaceRow,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: streak.hasAcknowledgmentToday
                        ? colors.accentPrimary
                        : colors.borderHairline,
                    width: 1,
                  ),
                ),
                child: Icon(
                  streak.hasAcknowledgmentToday
                      ? Icons.favorite
                      : Icons.favorite_border,
                  size: 14,
                  color: streak.hasAcknowledgmentToday
                      ? colors.accentPrimary
                      : colors.textMuted,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  Future<bool?> _showDeleteConfirmation(
      BuildContext context, LocalHabit habit) {
    final colors = context.colors;
    final typography = context.typography;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surfaceCard,
        title: Text('Delete Habit?', style: typography.title),
        content: Text(
          'Are you sure you want to delete "${habit.name}" and its check-in history?',
          style: typography.bodyRegular.copyWith(color: colors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel',
                style: TextStyle(color: colors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: TextStyle(color: colors.accentSecondary)),
          ),
        ],
      ),
    );
  }
}
