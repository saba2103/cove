import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/shape/cove_shape.dart';
import '../../core/theme/cove_tokens.dart';
import '../../core/utils/cove_currency_formatter.dart';
import '../../core/widgets/cove_actor_avatar.dart';
import '../../core/widgets/cove_detail_sheet.dart';
import '../../core/widgets/cove_grouped_list.dart';
import '../../core/widgets/cove_pill_button.dart';
import '../../core/widgets/cove_sync_tick.dart';
import '../../core/widgets/cove_undo_toast.dart';
import '../../core/widgets/slips/cove_slip.dart';
import '../../core/widgets/slips/cove_ticket.dart';
import '../../sync/db/app_database.dart';
import '../../sync/pending_delete_service.dart';
import '../../sync/providers/active_home_provider.dart';
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
import '../pets/pet_controller.dart';
import '../pets/pet_tag_widgets.dart';
import '../profile/preferences_controller.dart';
import '../roadmap/roadmap_controller.dart';
import '../subscriptions/commitment_detail_sheet.dart';
import '../subscriptions/subscription_controller.dart';
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
              await CalendarEventDetailSheet.show(context, event);
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
              await CommitmentDetailSheet.show(context, sub);
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

/// Detail sheet for a calendar event (`design/specs/13-detail-sheet.md`),
/// built on [CoveDetailSheet] with a paper-variant [CoveTicket] slip.
class CalendarEventDetailSheet extends ConsumerWidget {
  final LocalCalendarEvent event;

  static const double _kDialogBorderWidth =
      1.0; // (literal) 1dp dialog hairline border

  const CalendarEventDetailSheet({
    super.key,
    required this.event,
  });

  static Future<void> show(
    BuildContext context,
    LocalCalendarEvent event,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => CalendarEventDetailSheet(event: event),
    );
  }

  static String _formatContextLabel(LocalCalendarEvent event) {
    final rec = event.recurrence?.trim().toLowerCase();
    if (rec != null && rec.isNotEmpty && rec != 'none') {
      switch (rec) {
        case 'daily':
          return 'EVERY DAY';
        case 'weekly':
          return 'EVERY WEEK';
        case 'biweekly':
          return 'EVERY 2 WEEKS';
        case 'monthly':
          return 'EVERY MONTH';
        case 'yearly':
          return 'EVERY YEAR';
        default:
          return rec.toUpperCase();
      }
    }
    return DateFormat('EEE d MMM').format(event.startTime.toLocal()).toUpperCase();
  }

  Future<void> _handleEdit(BuildContext context) async {
    Navigator.of(context).pop();
    await CalendarEventFormSheet.show(context, existing: event);
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
          'Delete Event?',
          style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
        ),
        content: Text(
          'Remove "${event.title}" from your shared calendar?',
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
      final pendingDelete = ref.read(pendingDeleteServiceProvider);
      await pendingDelete.scheduleDelete(
        kind: PendingDeleteKind.event,
        id: event.id,
      );
      if (context.mounted) {
        Navigator.of(context).pop();
        CoveUndoToast.show(
          context,
          message: 'Deleted "${event.title}"',
          onUndo: () async {
            await pendingDelete.undoDelete(
              kind: PendingDeleteKind.event,
              id: event.id,
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPartner = ref.watch(activeHomeHasPartnerProvider);
    final whoLabel = hasPartner ? 'Both of you' : 'You';

    final startLocal = event.startTime.toLocal();
    final datePart = DateFormat('EEEE, d MMM').format(startLocal);
    final hasLocation =
        event.location != null && event.location!.trim().isNotEmpty;
    final trimmedLocation = hasLocation ? event.location!.trim() : null;

    final ticketDateLine = trimmedLocation != null
        ? '$datePart · $trimmedLocation'
        : datePart;

    final hour12 =
        startLocal.hour % 12 == 0 ? 12 : startLocal.hour % 12;
    final hourStr = event.isAllDay
        ? 'ALL'
        : (startLocal.minute == 0
            ? '$hour12'
            : DateFormat('h:mm').format(startLocal));
    final meridiemStr = event.isAllDay
        ? 'DAY'
        : DateFormat('a').format(startLocal).toUpperCase();

    final timePhrase = event.isAllDay
        ? 'All day'
        : DateFormat('h:mm a').format(startLocal);
    final meaningTitle = '$datePart · $timePhrase';
    final meaningSubtitle = trimmedLocation != null
        ? '$trimmedLocation · $whoLabel'
        : whoLabel;

    final contextLabel = _formatContextLabel(event);
    final taggedPets = ref.watch(
      recordPetTagsProvider(
        (recordKind: PetRecordKind.event, recordId: event.id),
      ),
    );

    return CoveDetailSheet(
      kindGlyph: const Icon(Icons.calendar_today_rounded),
      kindLabel: 'EVENT',
      contextLabel: contextLabel,
      onClose: () => Navigator.of(context).pop(),
      slip: CoveTicket(
        key: ValueKey('event_ticket_${event.id}'),
        variant: CoveSlipVariant.paper,
        title: event.title,
        date: ticketDateLine,
        owner: whoLabel,
        hour: hourStr,
        meridiem: meridiemStr,
        capsLabel: 'COVE · PLAN',
      ),
      meaningPanel: CoveDetailMeaningPanel.icon(
        icon: Icons.event_outlined,
        title: meaningTitle,
        subtitle: meaningSubtitle,
      ),
      belowMeaningPanel:
          taggedPets.isEmpty ? null : RecordPetTagChips(pets: taggedPets),
      editVerb: CoveDetailVerb(
        label: 'Edit',
        icon: Icons.edit_outlined,
        onPressed: () => _handleEdit(context),
      ),
      menuItems: [
        CoveDetailMenuItem(
          label: petTagMenuLabel(taggedPets),
          icon: Icons.pets_outlined,
          onSelected: () => PetTagPickerSheet.show(
            context,
            recordKind: PetRecordKind.event,
            recordId: event.id,
          ),
        ),
        CoveDetailMenuItem(
          label: 'Delete this event',
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          onSelected: () => _handleDelete(context, ref),
        ),
      ],
    );
  }
}

class ActivityEventDetailSheet extends ConsumerWidget {
  final FormattedActivityItem item;

  static const double _kGrabHandleWidth = 36.0; // (literal)
  static const double _kGrabHandleHeight = 4.0; // (literal)
  static const double _kGrabHandleRadius = 2.0; // (literal)
  static const double _kSyncTickSize = 14.0; // (literal)
  static const double _kAvatarSize = 38.0; // (literal)
  static const double _kRowIconSize = 18.0; // (literal)

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
          final currency = payload['currency'] as String? ?? ref.read(currencyPreferenceProvider).code;
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
            final currency = prev['currency'] as String? ?? ref.read(currencyPreferenceProvider).code;
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
          final startTime = startStr != null ? DateTime.tryParse(startStr) ?? clock.now() : clock.now();
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
        final cv = context.cv;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to undo: $e',
              style: CoveType.body.copyWith(color: cv.textPrimary),
            ),
            backgroundColor: cv.statusAlert,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cv = context.cv;
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
      decoration: CoveShape.topDecoration(
        CoveRadius.sheet,
        color: cv.surfaceCard,
      ),
      padding: EdgeInsets.fromLTRB(
        CoveSpace.xl,
        CoveSpace.lg,
        CoveSpace.xl,
        MediaQuery.of(context).padding.bottom + CoveSpace.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: _kGrabHandleWidth,
                height: _kGrabHandleHeight,
                decoration: CoveShape.decoration(
                  _kGrabHandleRadius,
                  color: cv.textTertiary.withValues(alpha: 0.3),
                ),
              ),
            ),
            const SizedBox(height: CoveSpace.xl),

            // Module & Sync status header
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: CoveSpace.sm,
              runSpacing: CoveSpace.xs,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoveSpace.sm,
                    vertical: CoveSpace.xs,
                  ),
                  decoration: CoveShape.decoration(
                    CoveRadius.inline,
                    color: cv.surfaceRow,
                  ),
                  child: Text(
                    item.module.label.toUpperCase(),
                    style: CoveType.capsCard.copyWith(
                      color: cv.accentText,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CoveSyncTick(status: item.syncStatus, size: _kSyncTickSize),
                    const SizedBox(width: CoveSpace.xs),
                    Flexible(
                      child: Text(
                        item.syncStatus == CoveSyncStatus.syncedToPartner
                            ? 'Synced E2EE'
                            : 'Saved Locally',
                        style: CoveType.rowSub.copyWith(
                          color: cv.textTertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.lg),

            // Action description with Actor Avatar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoveActorAvatar(item: item, size: _kAvatarSize, showBadge: true),
                const SizedBox(width: CoveSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.actorName} ${item.actionText}',
                        style: CoveType.title.copyWith(
                          color: cv.textPrimary,
                        ),
                      ),
                      const SizedBox(height: CoveSpace.xs),
                      Text(
                        formattedDate,
                        style: CoveType.rowSub.copyWith(
                          color: cv.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.xl),

            // Contextual Breakdown Card
            CoveGroupedCard(
              children: [
                CoveGroupedRow(
                  leading: Icon(item.icon, size: _kRowIconSize, color: cv.accentTint),
                  title: Text(
                    'Subject',
                    style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                  ),
                  trailing: Text(
                    title,
                    style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                  ),
                ),
                if (listName != null && listName.isNotEmpty)
                  CoveGroupedRow(
                    leading: Icon(Icons.checklist, size: _kRowIconSize, color: cv.textTertiary),
                    title: Text(
                      'List',
                      style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                    ),
                    trailing: Text(
                      listName,
                      style: CoveType.body.copyWith(color: cv.textPrimary),
                    ),
                  ),
                if (category != null && category.isNotEmpty)
                  CoveGroupedRow(
                    leading: Icon(Icons.label_outline, size: _kRowIconSize, color: cv.textTertiary),
                    title: Text(
                      'Category',
                      style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                    ),
                    trailing: Text(
                      category,
                      style: CoveType.body.copyWith(color: cv.textPrimary),
                    ),
                  ),
                if (amount != null)
                  CoveGroupedRow(
                    leading: Icon(Icons.payments_outlined, size: _kRowIconSize, color: cv.textTertiary),
                    title: Text(
                      'Amount',
                      style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                    ),
                    trailing: Text(
                      '$sym${formatCoveAmount(amount)}',
                      style: CoveType.rowTitle.copyWith(color: cv.textPrimary),
                    ),
                  ),
                if (prev != null) ...[
                  CoveGroupedRow(
                    leading: Icon(Icons.history_rounded, size: _kRowIconSize, color: cv.accentTint),
                    title: Text(
                      'Prior Value',
                      style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                    ),
                    trailing: Text(
                      '${prev['title'] ?? ''}${prev['amount'] != null ? ' ($prevSym${formatCoveAmount(prev['amount'])})' : ''}',
                      style: CoveType.body.copyWith(
                        color: cv.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                CoveGroupedRow(
                  leading: Icon(Icons.person_outline, size: _kRowIconSize, color: cv.textTertiary),
                  title: Text(
                    'Actor',
                    style: CoveType.rowSub.copyWith(color: cv.textSecondary),
                  ),
                  trailing: Text(
                    item.actorName,
                    style: CoveType.body.copyWith(color: cv.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoveSpace.xl),

            // Undo CTA Button (if action is reversible)
            if (canUndo) ...[
              CovePillButton(
                label: undoLabel,
                onPressed: () => _handleUndo(context, ref),
                variant: CoveButtonVariant.primary,
                isFullWidth: true,
              ),
              const SizedBox(height: CoveSpace.sm),
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
