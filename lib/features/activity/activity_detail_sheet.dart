import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/cove_theme.dart';
import '../../core/widgets/cove_actor_avatar.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../calendar/calendar_controller.dart';
import '../calendar/calendar_event_form_sheet.dart';
import '../expenses/expense_controller.dart';
import '../expenses/expense_detail_sheet.dart';
import '../habits/habit_controller.dart';
import '../habits/habit_detail_sheet.dart';
import '../lists/list_controller.dart';
import '../lists/list_item_detail_sheet.dart';
import '../profile/preferences_controller.dart';
import '../roadmap/roadmap_controller.dart';
import '../subscriptions/subscription_controller.dart';
import '../subscriptions/subscription_form_sheet.dart';
import 'activity_formatter.dart';
import 'activity_models.dart';

class ActivityDetailDispatcher {
  /// Opens the live detail sheet of the entity (Expense, ListItem, Habit, Event, Subscription),
  /// or opens the comprehensive ActivityEventDetailSheet if the entity was deleted, edited, or is an audit event.
  static Future<void> openDetail(
    BuildContext context,
    WidgetRef ref,
    FormattedActivityItem item,
  ) async {
    final eventType = item.eventType;

    // Direct deletions, cancellations, archives, or edit events to ActivityEventDetailSheet
    // where they can be inspected with full audit details and undone safely.
    if (eventType.endsWith('_deleted') ||
        eventType.endsWith('_updated') ||
        eventType.endsWith('_cancelled') ||
        eventType.endsWith('_archived')) {
      if (context.mounted) {
        await ActivityEventDetailSheet.show(context, item);
      }
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final currentUserId = ref.read(authProvider).value?.id;
    final entityId = item.entityId ??
        item.rawPayload['id'] as String? ??
        item.rawPayload['item_id'] as String? ??
        item.rawPayload['habit_id'] as String? ??
        item.rawPayload['event_id'] as String? ??
        item.rawPayload['subscription_id'] as String?;

    try {
      switch (item.module) {
        case ActivityModule.expenses:
          if (entityId != null) {
            final expense = await (db.select(db.localExpenses)
                  ..where((t) => t.id.equals(entityId)))
                .getSingleOrNull();
            if (expense != null && context.mounted) {
              await ExpenseDetailSheet.show(context, expense);
              return;
            }
          }
          break;

        case ActivityModule.lists:
          if (entityId != null) {
            final listItem = await (db.select(db.localListItems)
                  ..where((t) => t.id.equals(entityId)))
                .getSingleOrNull();
            if (listItem != null && context.mounted) {
              final list = await (db.select(db.localLists)
                    ..where((t) => t.id.equals(listItem.listId)))
                  .getSingleOrNull();
              final listName = list?.name ??
                  item.rawPayload['list_name'] as String? ??
                  'Shared List';
              if (context.mounted) {
                await ListItemDetailSheet.show(
                  context,
                  item: listItem,
                  listName: listName,
                );
                return;
              }
            }
          }
          break;

        case ActivityModule.habits:
          final habitId = entityId ?? item.rawPayload['habit_id'] as String?;
          if (habitId != null) {
            final habit = await (db.select(db.localHabits)
                  ..where((t) => t.id.equals(habitId)))
                .getSingleOrNull();
            if (habit != null && context.mounted) {
              final checkins = await (db.select(db.localHabitCheckins)
                    ..where((t) => t.habitId.equals(habit.id)))
                  .get();
              if (context.mounted) {
                await HabitDetailSheet.show(
                  context,
                  habit: habit,
                  checkins: checkins,
                  isPartnerHabit: habit.createdBy != currentUserId,
                );
                return;
              }
            }
          }
          break;

        case ActivityModule.calendar:
          if (entityId != null) {
            final event = await (db.select(db.localCalendarEvents)
                  ..where((t) => t.id.equals(entityId)))
                .getSingleOrNull();
            if (event != null && context.mounted) {
              await CalendarEventFormSheet.show(context, existing: event);
              return;
            }
          }
          break;

        case ActivityModule.subscriptions:
          if (entityId != null) {
            final sub = await (db.select(db.localSubscriptions)
                  ..where((t) => t.id.equals(entityId)))
                .getSingleOrNull();
            if (sub != null && context.mounted) {
              await SubscriptionFormSheet.show(context, existing: sub);
              return;
            }
          }
          break;

        case ActivityModule.all:
          break;
      }
    } catch (_) {}

    // Fallback: If the entity was deleted or cannot be resolved, open the ActivityEventDetailSheet
    if (context.mounted) {
      await ActivityEventDetailSheet.show(context, item);
    }
  }
}

class ActivityEventDetailSheet extends ConsumerWidget {
  final FormattedActivityItem item;

  const ActivityEventDetailSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, FormattedActivityItem item) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ActivityEventDetailSheet(item: item),
    );
  }

  bool _isUndoable(String eventType) {
    return eventType.endsWith('_deleted') ||
        eventType.endsWith('_updated') ||
        eventType == 'subscription_cancelled' ||
        eventType == 'habit_archived' ||
        eventType == 'list_item_toggled';
  }

  String _undoLabel(String eventType) {
    if (eventType.endsWith('_deleted') || eventType == 'habit_archived') {
      return 'Undo Deletion (Restore)';
    } else if (eventType == 'subscription_cancelled') {
      return 'Reactivate Commitment';
    } else if (eventType.endsWith('_updated')) {
      return 'Undo Edit (Revert to Previous)';
    } else if (eventType == 'list_item_toggled') {
      return 'Toggle Status Back';
    }
    return 'Undo Action';
  }

  Future<void> _handleUndo(BuildContext context, WidgetRef ref) async {
    final payload = item.rawPayload;
    final eventType = item.eventType;
    final title = item.targetTitle ?? payload['title'] as String? ?? 'Item';

    try {
      switch (eventType) {
        // --- EXPENSES ---
        case 'expense_deleted':
          final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
          final currency = payload['currency'] as String? ?? 'USD';
          final category = payload['category'] as String?;
          final dateStr = payload['expense_date'] as String?;
          final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
          final paidBy = payload['paid_by'] as String? ?? ref.read(authProvider).value?.id ?? 'me';
          final notes = payload['notes'] as String?;
          final visStr = payload['visibility'] as String?;
          final visibility = visStr == 'partner_can_see'
              ? ExpenseVisibility.partnerCanSee
              : (visStr == 'private_to_me'
                  ? ExpenseVisibility.privateToMe
                  : ExpenseVisibility.shared);

          final paymentMethod = payload['payment_method'] as String?;

          await ref.read(expenseControllerProvider).logExpense(
                title: title,
                amount: amount,
                currency: currency,
                expenseDate: date,
                paidBy: paidBy,
                category: category,
                notes: notes,
                paymentMethod: paymentMethod,
                visibility: visibility,
              );
          break;

        case 'expense_updated':
          final prev = payload['previous'] as Map<String, dynamic>?;
          final entityId = item.entityId ?? payload['id'] as String?;
          if (entityId != null && prev != null) {
            final prevTitle = prev['title'] as String? ?? title;
            final amount = (prev['amount'] as num?)?.toDouble() ?? 0.0;
            final currency = prev['currency'] as String? ?? 'USD';
            final dateStr = prev['expense_date'] as String?;
            final date = dateStr != null ? DateTime.tryParse(dateStr) : null;
            final paidBy = prev['paid_by'] as String? ?? 'me';
            final category = prev['category'] as String?;
            final notes = prev['notes'] as String?;
            final prevPaymentMethod = prev['payment_method'] as String?;
            final visStr = prev['visibility'] as String?;
            final visibility = visStr == 'partner_can_see'
                ? ExpenseVisibility.partnerCanSee
                : ExpenseVisibility.shared;

            await ref.read(expenseControllerProvider).updateExpense(
                  id: entityId,
                  title: prevTitle,
                  amount: amount,
                  currency: currency,
                  expenseDate: date,
                  paidBy: paidBy,
                  category: category,
                  notes: notes,
                  paymentMethod: prevPaymentMethod,
                  oldVisibility: visibility,
                  visibility: visibility,
                );
          }
          break;

        // --- LISTS ---
        case 'list_item_deleted':
          final listId = payload['list_id'] as String? ?? '';
          if (listId.isNotEmpty) {
            await ref.read(listControllerProvider).addItem(
                  listId: listId,
                  title: title,
                );
          }
          break;

        case 'list_item_toggled':
          final entityId = item.entityId ?? payload['id'] as String?;
          final wasCompleted = payload['is_completed'] as bool? ?? true;
          if (entityId != null) {
            await ref.read(listControllerProvider).toggleItem(
                  itemId: entityId,
                  isCompleted: !wasCompleted,
                );
          }
          break;

        // --- CALENDAR ---
        case 'calendar_event_deleted':
          final startStr = payload['start_time'] as String?;
          final endStr = payload['end_time'] as String?;
          final startTime = startStr != null ? DateTime.tryParse(startStr) ?? DateTime.now() : DateTime.now();
          final endTime = (endStr != null ? DateTime.tryParse(endStr) : null) ?? startTime.add(const Duration(hours: 1));
          final recurrence = payload['recurrence'] as String?;
          final location = payload['location'] as String?;

          await ref.read(calendarControllerProvider).createEvent(
                title: title,
                startTime: startTime,
                endTime: endTime,
                recurrence: recurrence,
                location: location,
              );
          break;

        // --- HABITS ---
        case 'habit_deleted':
        case 'habit_archived':
          final habitName = payload['name'] as String? ?? payload['title'] as String? ?? title;
          final cadence = payload['cadence'] as String? ?? payload['schedule_type'] as String? ?? 'daily';
          final targetDays = payload['target_days_per_week'] as int? ?? 7;
          final isPrivate = payload['is_private'] as bool? ?? item.isPrivate;
          await ref.read(habitControllerProvider).createHabit(
                name: habitName,
                cadence: cadence,
                targetDaysPerWeek: targetDays.abs(),
                visibility: isPrivate ? HabitVisibility.privateToMe : HabitVisibility.shared,
              );
          break;

        // --- ROADMAP ---
        case 'roadmap_item_deleted':
          final desc = payload['description'] as String?;
          await ref.read(roadmapControllerProvider).createItem(
                title: title,
                description: desc,
              );
          break;

        case 'roadmap_item_updated':
          final entityId = item.entityId ?? payload['id'] as String?;
          final prevTitle = payload['previous_title'] as String?;
          final prevDesc = payload['previous_description'] as String?;
          if (entityId != null && prevTitle != null) {
            await ref.read(roadmapControllerProvider).updateItem(
                  id: entityId,
                  title: prevTitle,
                  description: prevDesc,
                );
          }
          break;

        // --- SUBSCRIPTIONS ---
        case 'subscription_cancelled':
          final entityId = item.entityId ?? payload['id'] as String?;
          final isPrivate = payload['is_private'] as bool? ?? item.isPrivate;
          if (entityId != null) {
            await ref.read(subscriptionControllerProvider).reactivateSubscription(entityId, isPrivate: isPrivate);
          }
          break;
      }

      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Undone: Restored "$title"',
          actionLabel: 'OK',
          onUndo: () {},
          icon: Icons.check_circle_outline_rounded,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to undo: $e'),
            backgroundColor: context.colors.accentSecondary,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typography = context.typography;
    final dateFormat = DateFormat('EEEE, MMMM d, y • h:mm a');
    final formattedDate = dateFormat.format(item.timestamp.toLocal());

    final payload = item.rawPayload;
    final title = item.targetTitle ??
        payload['title'] as String? ??
        payload['name'] as String? ??
        payload['habit_name'] as String? ??
        'Activity Item';

    final category = payload['category'] as String?;
    final listName = payload['list_name'] as String?;
    final amount = (payload['amount'] as num?)?.toDouble();
    final currency = payload['currency'] as String?;
    final prev = payload['previous'] as Map<String, dynamic>?;

    final canUndo = _isUndoable(item.eventType);
    final undoLabel = _undoLabel(item.eventType);

    final preferredCurrency = ref.watch(currencyPreferenceProvider);
    final sym = ActivityFormatter.getCurrencySymbol(currency, fallbackSymbol: preferredCurrency.symbol);
    final prevSym = prev != null
        ? ActivityFormatter.getCurrencySymbol(prev['currency'] as String?, fallbackSymbol: preferredCurrency.symbol)
        : preferredCurrency.symbol;

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Module & Sync status header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.module.label.toUpperCase(),
                    style: typography.caption.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.8,
                      color: colors.accentPrimary,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CoveSyncTick(status: item.syncStatus, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      item.syncStatus == CoveSyncStatus.syncedToPartner
                          ? 'Synced E2EE'
                          : 'Saved Locally',
                      style: typography.caption.copyWith(
                        color: colors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Action description with Actor Avatar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoveActorAvatar(item: item, size: 38, showBadge: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.actorName} ${item.actionText}',
                        style: typography.title.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: typography.caption.copyWith(
                          color: colors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Contextual Breakdown Card
            CoveGroupedCard(
              children: [
                CoveGroupedRow(
                  leading: Icon(item.icon, size: 18, color: colors.accentPrimary),
                  title: Text('Subject', style: typography.caption),
                  trailing: Text(
                    title,
                    style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (listName != null && listName.isNotEmpty)
                  CoveGroupedRow(
                    leading: Icon(Icons.checklist, size: 18, color: colors.textMuted),
                    title: Text('List', style: typography.caption),
                    trailing: Text(
                      listName,
                      style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                if (category != null && category.isNotEmpty)
                  CoveGroupedRow(
                    leading: Icon(Icons.label_outline, size: 18, color: colors.textMuted),
                    title: Text('Category', style: typography.caption),
                    trailing: Text(
                      category,
                      style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                if (amount != null)
                  CoveGroupedRow(
                    leading: Icon(Icons.payments_outlined, size: 18, color: colors.textMuted),
                    title: Text('Amount', style: typography.caption),
                    trailing: Text(
                      '$sym${NumberFormat('#,##0.00').format(amount)}',
                      style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                if (prev != null) ...[
                  CoveGroupedRow(
                    leading: Icon(Icons.history_rounded, size: 18, color: colors.accentPrimary),
                    title: Text('Prior Value', style: typography.caption),
                    trailing: Text(
                      '${prev['title'] ?? ''}${prev['amount'] != null ? ' ($prevSym${NumberFormat('#,##0.00').format(prev['amount'])})' : ''}',
                      style: typography.bodyMedium.copyWith(
                        color: colors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                CoveGroupedRow(
                  leading: Icon(Icons.person_outline, size: 18, color: colors.textMuted),
                  title: Text('Actor', style: typography.caption),
                  trailing: Text(
                    item.actorName,
                    style: typography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Undo CTA Button (if action is reversible)
            if (canUndo) ...[
              CovePillButton(
                label: undoLabel,
                onPressed: () => _handleUndo(context, ref),
                variant: CoveButtonVariant.primary,
                isFullWidth: true,
              ),
              const SizedBox(height: 10),
            ],

            // Close Button
            CovePillButton(
              label: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              variant: canUndo ? CoveButtonVariant.secondary : CoveButtonVariant.primary,
              isFullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
