import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/widgets/cove_detail_sheet.dart';
import '../../core/widgets/slips/cove_habit_card.dart';
import '../../core/widgets/slips/cove_slip.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import 'habit_controller.dart';
import 'habit_form_sheet.dart';
import 'habit_schedule.dart';
import 'habit_streak_calculator.dart';

class HabitDetailSheet extends ConsumerWidget {
  final LocalHabit habit;
  final List<LocalHabitCheckin> checkins;
  final bool isPartnerHabit;

  static const double _kDialogBorderWidth =
      1.0; // (literal) 1dp dialog hairline border

  const HabitDetailSheet({
    super.key,
    required this.habit,
    required this.checkins,
    this.isPartnerHabit = false,
  });

  static Future<void> show(
    BuildContext context, {
    required LocalHabit habit,
    required List<LocalHabitCheckin> checkins,
    bool isPartnerHabit = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HabitDetailSheet(
        habit: habit,
        checkins: checkins,
        isPartnerHabit: isPartnerHabit,
      ),
    );
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
          'Delete Habit?',
          style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove "${habit.name}"? This removes history for this habit.',
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
      await ref.read(habitControllerProvider).deleteHabit(habit);
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _handleEdit(BuildContext context) async {
    Navigator.of(context).pop();
    await HabitFormSheet.show(context, existing: habit);
  }

  void _handleToggleCheckin(
    BuildContext context,
    WidgetRef ref,
    bool nextChecked,
  ) {
    ref.read(habitControllerProvider).toggleCheckin(
          habit: habit,
          checked: nextChecked,
        );
    Navigator.of(context).pop();
  }

  void _handleAcknowledge(BuildContext context, WidgetRef ref) {
    ref.read(habitControllerProvider).acknowledgeCheckin(
          habit: habit,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);
    final user = ref.watch(authProvider).value;
    final partnerProfile = ref.watch(partnerProfileProvider);
    final isMe = habit.createdBy == user?.id;

    final streak = HabitStreakCalculator.calculate(
      habit: habit,
      checkins: checkins,
    );
    final history21 = HabitStreakCalculator.buildHistory21(
      checkins: checkins,
      totalDays: CoveHabitCard.kTotalCells,
    );

    final schedule = HabitSchedule.parse(
      habit.cadence,
      targetDays: habit.targetDaysPerWeek,
    );
    final cadenceLabel = schedule.formatDisplayLabel(
      targetDays: habit.targetDaysPerWeek,
    );

    final isPrivate = habit.targetDaysPerWeek < 0;
    final String slipCadenceLine;
    if (isPrivate) {
      slipCadenceLine = '$cadenceLabel · Yours alone';
    } else if (isMe) {
      slipCadenceLine = hasPartner
          ? '$cadenceLabel · Shared with ${partnerProfile.displayName}'
          : '$cadenceLabel · Created by you';
    } else {
      slipCadenceLine = '$cadenceLabel · ${partnerProfile.displayName}\'s habit';
    }

    final menuItems = <CoveDetailMenuItem>[
      if (isPartnerHabit)
        CoveDetailMenuItem(
          label: streak.hasAcknowledgmentToday
              ? 'Cheered ${partnerProfile.displayName} today'
              : 'Cheer ${partnerProfile.displayName}',
          icon: Icons.celebration_outlined,
          onSelected: () => _handleAcknowledge(context, ref),
        ),
      CoveDetailMenuItem(
        label: 'Delete this habit',
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
        onSelected: () => _handleDelete(context, ref),
      ),
    ];

    return CoveDetailSheet(
      kindGlyph: const Icon(Icons.repeat_rounded),
      kindLabel: 'HABIT',
      contextLabel: cadenceLabel,
      onClose: () => Navigator.of(context).pop(),
      slip: CoveHabitCard(
        variant: CoveSlipVariant.paper,
        title: habit.name,
        cadence: slipCadenceLine,
        isDoneToday: streak.isCheckedToday,
        daysRunning: streak.currentStreak,
        history21: history21,
        onToggle: isPartnerHabit
            ? null
            : (checked) => _handleToggleCheckin(context, ref, checked),
      ),
      meaningPanel: CoveDetailMeaningPanel.icon(
        icon: Icons.local_fire_department_outlined,
        title: '${streak.currentStreak} days running',
        subtitle: 'Best ${streak.bestStreak} · $cadenceLabel',
      ),
      editVerb: CoveDetailVerb(
        label: 'Edit',
        icon: Icons.edit_outlined,
        onPressed: () => _handleEdit(context),
      ),
      secondaryVerb: isPartnerHabit
          ? null
          : CoveDetailVerb(
              label: streak.isCheckedToday ? 'Undo check-in' : 'Check in',
              icon: streak.isCheckedToday
                  ? Icons.undo_rounded
                  : Icons.check_circle_outline_rounded,
              onPressed: () => _handleToggleCheckin(
                context,
                ref,
                !streak.isCheckedToday,
              ),
            ),
      menuItems: menuItems,
    );
  }
}
