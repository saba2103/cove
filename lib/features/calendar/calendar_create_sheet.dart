import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_pill_input.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../expenses/expense_form_sheet.dart';
import '../habits/habit_form_sheet.dart';
import '../lists/list_controller.dart';
import '../subscriptions/subscription_form_sheet.dart';
import 'calendar_event_form_sheet.dart';
import 'calendar_models.dart';

class CalendarCreateSheet extends ConsumerWidget {
  final DateTime selectedDate;

  const CalendarCreateSheet({
    super.key,
    required this.selectedDate,
  });

  static Future<void> show(BuildContext context, {required DateTime selectedDate}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarCreateSheet(selectedDate: selectedDate),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final dateLabel = CalendarDateUtils.formatDateHeading(selectedDate);

    final options = [
      (
        icon: Icons.calendar_today_outlined,
        label: 'Event',
        microLabel: 'EVENT',
        subtitle: 'Dated plan, outing, or travel',
        onTap: () {
          Navigator.of(context).pop();
          CalendarEventFormSheet.show(context, initialDate: selectedDate);
        },
      ),
      (
        icon: Icons.receipt_long_outlined,
        label: 'Expense',
        microLabel: 'MONEY',
        subtitle: 'Log a shared or personal expense',
        onTap: () {
          Navigator.of(context).pop();
          ExpenseFormSheet.show(context, initialDate: selectedDate);
        },
      ),
      (
        icon: Icons.check_circle_outline,
        label: 'Task',
        microLabel: 'TASK',
        subtitle: 'Add an item to a list with due date',
        onTap: () {
          Navigator.of(context).pop();
          _showAddTaskSheet(context, ref, selectedDate);
        },
      ),
      (
        icon: Icons.autorenew_rounded,
        label: 'Rhythm',
        microLabel: 'RHYTHM',
        subtitle: 'Daily or weekly recurring habit',
        onTap: () {
          Navigator.of(context).pop();
          HabitFormSheet.show(context);
        },
      ),
      (
        icon: Icons.credit_card_outlined,
        label: 'Commitment',
        microLabel: 'RENEWAL',
        subtitle: 'Subscription, bill, or renewal',
        onTap: () {
          Navigator.of(context).pop();
          SubscriptionFormSheet.show(context, initialDate: selectedDate);
        },
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add to Sanctuary',
                      style: typography.headline.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      style: typography.caption.copyWith(
                        color: colors.accentPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: options.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              indent: 68,
              thickness: 1,
              color: colors.borderHairline,
            ),
            itemBuilder: (ctx, idx) {
              final opt = options[idx];
              return InkWell(
                onTap: opt.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: colors.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(opt.icon, size: 20, color: colors.accentPrimary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  opt.label,
                                  style: typography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceRow,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: colors.borderHairline),
                                  ),
                                  child: Text(
                                    opt.microLabel,
                                    style: typography.caption.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                      color: colors.textSubtle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              opt.subtitle,
                              style: typography.caption.copyWith(
                                color: colors.textSubtle,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: colors.textSubtle),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context, WidgetRef ref, DateTime dueDate) {
    final colors = context.colors;
    final typography = context.typography;
    final titleController = TextEditingController();
    final lists = ref.read(activeHomeListsProvider).value ?? [];
    String? selectedListId = lists.isNotEmpty ? lists.first.id : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: BoxDecoration(
            color: colors.surfaceCard,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Task',
                    style: typography.headline.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CovePillInput(
                controller: titleController,
                hintText: 'What needs to get done?',
                autofocus: true,
              ),
              const SizedBox(height: 14),
              if (lists.isNotEmpty) ...[
                Text(
                  'List',
                  style: typography.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colors.textSubtle,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colors.surfaceRow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.borderHairline),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedListId,
                      isExpanded: true,
                      dropdownColor: colors.surfaceCard,
                      items: lists
                          .map((l) => DropdownMenuItem(
                                value: l.id,
                                child: Text(l.name, style: typography.bodyMedium),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setSheetState(() => selectedListId = val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              CovePillButton(
                label: 'Save Task',
                variant: CoveButtonVariant.primary,
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) return;
                  if (selectedListId == null && lists.isNotEmpty) {
                    selectedListId = lists.first.id;
                  }
                  if (selectedListId != null) {
                    await ref.read(listControllerProvider).addItem(
                          listId: selectedListId!,
                          title: title,
                          dueDate: dueDate,
                        );
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
