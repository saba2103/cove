import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_streak_badge.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
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
          'Delete Habit?',
          style: TextStyle(
            fontFamily: 'GeneralSans',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${habit.name}"? This removes history for this habit.',
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final outbox = ref.watch(activeHomeOutboxProvider).value ?? [];
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);
    final user = ref.watch(authProvider).value;
    final partnerProfile = ref.watch(partnerProfileProvider);
    final isMe = habit.createdBy == user?.id;

    final streak = HabitStreakCalculator.calculate(
      habit: habit,
      checkins: checkins,
    );

    final schedule = HabitSchedule.parse(habit.cadence, targetDays: habit.targetDaysPerWeek);
    final cadenceLabel = schedule.formatDisplayLabel(targetDays: habit.targetDaysPerWeek);

    final tickStatus = resolveCoveSyncStatus(
      entityId: habit.id,
      outbox: outbox,
      hasPartner: hasPartner,
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: colors.borderHairline, width: 1)),
      ),
      padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Center drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.borderHairline.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Top bar: Rhythm chip & Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.repeat_outlined, size: 14, color: colors.accentPrimary),
                      const SizedBox(width: 5),
                      Text(
                        cadenceLabel,
                        style: typography.caption.copyWith(
                          color: colors.accentPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: colors.textMuted),
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Habit Name
            Text(
              habit.name,
              style: typography.headline.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 10),

            // Streak & Status Row
            Row(
              children: [
                CoveStreakIndicator(count: streak.currentStreak),
                const SizedBox(width: 10),
                if (streak.isCheckedToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.accentPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check, size: 12, color: colors.accentPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'Checked in today',
                          style: TextStyle(
                            fontFamily: 'GeneralSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.accentPrimary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.surfaceRow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Pending check-in today',
                      style: typography.caption.copyWith(fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Details Grouped Card
            CoveGroupedCard(
              children: [
                CoveGroupedRow(
                  leading: Icon(Icons.calendar_today_outlined, size: 18, color: colors.accentPrimary),
                  title: Text('Cadence & Target', style: typography.bodyMedium),
                  trailing: Text(
                    schedule.timeOfDay != null
                        ? '${schedule.timeOfDay!.format(context)} · $cadenceLabel'
                        : cadenceLabel,
                    style: typography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                CoveGroupedRow(
                  leading: Icon(Icons.people_outline, size: 18, color: colors.accentPrimary),
                  title: Text('Ownership', style: typography.bodyMedium),
                  trailing: Text(
                    isMe ? 'Created by You' : '${partnerProfile.displayName}\'s Habit',
                    style: typography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                CoveGroupedRow(
                  leading: Icon(Icons.lock_outline, size: 18, color: colors.textSubtle),
                  title: Text('End-to-End Encryption', style: typography.bodyMedium),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tickStatus == CoveSyncStatus.syncedToPartner
                            ? 'Synced with ${partnerProfile.displayName}'
                            : 'Saved on this device',
                        style: typography.caption.copyWith(color: colors.textMuted),
                      ),
                      const SizedBox(width: 6),
                      CoveSyncTick(status: tickStatus, size: 13),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Check-in toggle / Action Buttons
            if (isPartnerHabit) ...[
              CovePillButton(
                label: streak.hasAcknowledgmentToday ? 'Cheered ${partnerProfile.displayName} Today 👏' : 'Cheer ${partnerProfile.displayName} 👏',
                onPressed: () {
                  ref.read(habitControllerProvider).acknowledgeCheckin(
                        habit: habit,
                      );
                  Navigator.of(context).pop();
                },
                isFullWidth: true,
              ),
            ] else ...[
              CovePillButton(
                label: streak.isCheckedToday ? 'Checked in for Today ✓' : 'Check in for Today',
                icon: Icon(
                  streak.isCheckedToday ? Icons.check_circle : Icons.check_circle_outline,
                  size: 16,
                ),
                onPressed: () {
                  ref.read(habitControllerProvider).toggleCheckin(
                        habit: habit,
                        checked: !streak.isCheckedToday,
                      );
                  Navigator.of(context).pop();
                },
                isFullWidth: true,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleEdit(context),
                    icon: Icon(Icons.edit_outlined, size: 15, color: colors.textPrimary),
                    label: Text(
                      'Edit Habit',
                      style: TextStyle(
                        fontFamily: 'GeneralSans',
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: colors.borderHairline),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _handleDelete(context, ref),
                  icon: Icon(Icons.delete_outline, size: 16, color: colors.accentSecondary),
                  label: Text(
                    'Delete',
                    style: TextStyle(
                      fontFamily: 'GeneralSans',
                      fontWeight: FontWeight.w600,
                      color: colors.accentSecondary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    side: BorderSide(color: colors.accentSecondary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
