import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_checkbox.dart';
import '../../core/widgets/cove_empty_state.dart';
import '../../core/widgets/cove_error_state.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_loading.dart';
import '../../core/widgets/cove_page_header.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_streak_badge.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../add/add_draft.dart';
import '../add/add_flow.dart';
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
    final cv = context.cv;
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
        backgroundColor: cv.surfaceCanvas,
        body: const CovePageInsets(child: Center(child: CoveLoading())),
      );
    }

    if (habitsAsync.hasError) {
      return Scaffold(
        backgroundColor: cv.surfaceCanvas,
        body: CovePageInsets(
          child: Center(
            child: CoveErrorState.generic(
              title: 'Habits unavailable',
              description: 'Could not load your habits right now.',
              onRetry: () {
                ref.invalidate(activeHomeHabitsProvider);
                ref.invalidate(activeHomeAllHabitCheckinsProvider);
              },
            ),
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
    final cv = context.cv;
    final userId = currentUser?.id ?? 'local_user';

    final isDesktop = kIsWeb && MediaQuery.sizeOf(context).width >= 840;

    return CovePageInsets(
      child: Scaffold(
        backgroundColor: cv.surfaceCanvas,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            'Habits',
            style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: CovePillButton(
                label: '+ New',
                variant: CoveButtonVariant.secondary,
                isCompact: true,
                minTapTargetSize: CoveSize.hit,
                onPressed: () => AddFlow.show(context, kind: AddKind.habit),
              ),
            ),
          ],
        ),
        body: Center(
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
    final bottomPadding =
        CoveSpace.barClearance + CovePageInsets.bottomOf(context);
    return ListView(
      padding: EdgeInsets.only(bottom: bottomPadding),
      children: [
        CoveEmptyState(
          icon: Icons.repeat_outlined,
          title: 'No Habits Logged',
          description:
              'Track personal habits together or privately without gamified noise or guilt.',
          action: CovePillButton(
            label: 'Create First Habit',
            onPressed: () => AddFlow.show(context, kind: AddKind.habit),
          ),
        ),
      ],
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
    final cv = context.cv;
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
    final bottomPadding =
        CoveSpace.barClearance + CovePageInsets.bottomOf(context);

    if (isDesktop) {
      return ListView(
        padding: EdgeInsets.fromLTRB(
          CoveSpace.section,
          CoveSpace.lg,
          CoveSpace.section,
          bottomPadding,
        ),
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
                      Text(
                        'YOUR SHARED HABITS',
                        style: CoveType.capsPage.copyWith(
                          color: cv.textSecondary,
                        ),
                      ),
                      const SizedBox(height: CoveSpace.sm),
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
                      const SizedBox(height: CoveSpace.lg),
                    ],
                    if (yourPrivate.isNotEmpty) ...[
                      Row(
                        children: [
                          Text(
                            'PRIVATE TO YOU',
                            style: CoveType.capsPage.copyWith(
                              color: cv.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.lock_outline,
                            size: 12,
                            color: cv.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: CoveSpace.sm),
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
              const SizedBox(width: CoveSpace.section),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (partnerShared.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${partnerName.toUpperCase()}'S HABITS",
                            style: CoveType.capsPage.copyWith(
                              color: cv.textSecondary,
                            ),
                          ),
                          Text(
                            'Read-only',
                            style: CoveType.barLabel.copyWith(
                              color: cv.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CoveSpace.sm),
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
      padding: EdgeInsets.fromLTRB(
        CoveSpace.gutter,
        16,
        CoveSpace.gutter,
        bottomPadding,
      ),
      children: [
        // 1. YOUR HABITS
        if (yourShared.isNotEmpty) ...[
          Text(
            'YOUR SHARED HABITS',
            style: CoveType.capsPage.copyWith(color: cv.textSecondary),
          ),
          const SizedBox(height: CoveSpace.sm),
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
          const SizedBox(height: CoveSpace.lg),
        ],

        // 2. PARTNER'S SHARED HABITS (READ-ONLY VIEW)
        if (partnerShared.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${partnerName.toUpperCase()}'S HABITS",
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              Text(
                'Read-only',
                style: CoveType.barLabel.copyWith(color: cv.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: CoveSpace.sm),
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
          const SizedBox(height: CoveSpace.lg),
        ],

        // 3. YOUR PRIVATE HABITS
        if (yourPrivate.isNotEmpty) ...[
          Row(
            children: [
              Text(
                'PRIVATE TO YOU',
                style: CoveType.capsPage.copyWith(color: cv.textSecondary),
              ),
              const SizedBox(width: 6),
              Icon(Icons.lock_outline, size: 12, color: cv.textSecondary),
            ],
          ),
          const SizedBox(height: CoveSpace.sm),
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
          const SizedBox(height: CoveSpace.lg),
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
    final cv = context.cv;
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
        padding: const EdgeInsets.only(right: CoveSpace.gutter),
        color: cv.statusAlert.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline, size: 20, color: cv.statusAlertText),
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
        splashColor: cv.accentFill.withValues(alpha: 0.05),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 2,
            right: CoveSpace.xs,
            top: 9,
            bottom: 9,
          ),
          child: Row(
            children: [
              // Checkbox for today's checkin
              CoveCheckbox(
                value: streak.isCheckedToday,
                hitSize: CoveSize.hit,
                onChanged: (checked) async {
                  try {
                    await ref.read(habitControllerProvider).toggleCheckin(
                          habit: habit,
                          checked: checked,
                        );
                  } catch (e) {
                    if (!context.mounted) return;
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
              ),

              // Title & Cadence
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: CoveSpace.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            habit.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CoveType.rowTitle.copyWith(
                              color: streak.isCheckedToday
                                  ? cv.textSecondary
                                  : cv.textPrimary,
                              decoration: streak.isCheckedToday
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: cv.textSecondary,
                            ),
                          ),
                          if (streak.hasAcknowledgmentToday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: cv.accentWash,
                                borderRadius: BorderRadius.circular(CoveRadius.pill),
                              ),
                              child: Text(
                                'Acknowledged',
                                style: CoveType.barLabel.copyWith(
                                  color: cv.accentText,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            cadenceLabel,
                            style: CoveType.rowSub.copyWith(
                              color: cv.textTertiary,
                            ),
                          ),
                          if (streak.bestStreak > 0) ...[
                            Text(
                              ' • Best: ${streak.bestStreak}',
                              style: CoveType.rowSub.copyWith(
                                color: cv.textTertiary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
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

              // Edit / Delete Popup Menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 16, color: cv.textTertiary),
                padding: EdgeInsets.zero,
                style: const ButtonStyle(
                  minimumSize: WidgetStatePropertyAll(
                    Size(CoveSize.hit, CoveSize.hit),
                  ),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  padding: WidgetStatePropertyAll(EdgeInsets.zero),
                ),
                constraints: const BoxConstraints(
                  minWidth: CoveSize.hit,
                  minHeight: CoveSize.hit,
                ),
                color: cv.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoveRadius.inline),
                  side: BorderSide(color: cv.lineHairline, width: 1),
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
                        Icon(Icons.edit_outlined, size: 15, color: cv.textPrimary),
                        const SizedBox(width: CoveSpace.sm),
                        Text(
                          'Edit Habit',
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
                        Icon(
                          Icons.delete_outline,
                          size: 15,
                          color: cv.statusAlertText,
                        ),
                        const SizedBox(width: CoveSpace.sm),
                        Text(
                          'Delete Habit',
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
    );
  }

  /// Read-only row for partner's shared habits with optional quiet acknowledge tap.
  Widget _buildPartnerReadOnlyRow(
    BuildContext context, {
    required LocalHabit habit,
    required List<LocalHabitCheckin> checkins,
  }) {
    final cv = context.cv;
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
              width: CoveSpace.gutter,
              height: CoveSpace.gutter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: streak.isCheckedToday
                    ? cv.accentFill.withValues(alpha: 0.25)
                    : Colors.transparent,
                border: Border.all(
                  color: streak.isCheckedToday
                      ? cv.accentFill
                      : cv.textTertiary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: streak.isCheckedToday
                  ? Icon(
                      Icons.check,
                      size: 12,
                      color: cv.accentText,
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
                    style: CoveType.rowTitle.copyWith(
                      color: cv.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    streak.isCheckedToday
                        ? '$cadenceLabel • Completed today'
                        : '$cadenceLabel • Resting today',
                    style: CoveType.rowSub.copyWith(
                      color: cv.textTertiary,
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
            const SizedBox(width: CoveSpace.md),

            // Quiet Acknowledge Tap
            if (streak.isCheckedToday)
              GestureDetector(
                onTap: () {
                  ref.read(habitControllerProvider).acknowledgeCheckin(
                        habit: habit,
                      );
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: CoveSize.hit,
                  height: CoveSize.hit,
                  child: Center(
                    child: AnimatedContainer(
                      duration: CoveMotion.q(context),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: streak.hasAcknowledgmentToday
                            ? cv.accentWash
                            : cv.surfaceRow,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: streak.hasAcknowledgmentToday
                              ? cv.accentFill
                              : cv.lineHairline,
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        streak.hasAcknowledgmentToday
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 14,
                        color: streak.hasAcknowledgmentToday
                            ? cv.accentText
                            : cv.textSecondary,
                      ),
                    ),
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
    final cv = context.cv;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cv.surfaceCard,
        title: Text(
          'Delete Habit?',
          style: CoveType.slipTitle.copyWith(color: cv.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${habit.name}" and its check-in history?',
          style: CoveType.body.copyWith(color: cv.textSecondary),
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
  }
}
