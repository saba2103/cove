import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/expenses/monthly_budget_controller.dart';
import '../../features/profile/partner_profile_controller.dart';
import '../../features/profile/user_profile_controller.dart';
import '../local_state_store.dart';
import 'app_database.dart';

class LocalStateStoreImpl implements LocalStateStore {
  final AppDatabase db;
  final FlutterSecureStorage storage;

  LocalStateStoreImpl(this.db, {this.storage = const FlutterSecureStorage()}) {
    // Proactively purge any existing profile update activity rows
    db.clearProfileActivityEvents().catchError((_) => 0);
    // Proactively purge any orphaned or deleted list items
    db.purgeOrphanedAndArchivedListItems().catchError((_) => 0);
  }

  @override
  Future<void> initialize() async {
    // Purge legacy profile events from activity log
    try {
      await db.clearProfileActivityEvents();
    } catch (_) {}
    // Purge any orphaned or deleted list items
    try {
      await db.purgeOrphanedAndArchivedListItems();
    } catch (_) {}
  }

  @override
  Future<void> applyEvent({
    String? eventId,
    required String homeId,
    required String eventType,
    required Map<String, dynamic> payload,
    required DateTime timestamp,
    required String authorId,
  }) async {
    await db.transaction(() async {
      // Record in local activity log (excluding silent profile updates)
      if (eventType != 'member_profile_updated' &&
          eventType != 'profile_updated') {
        final activityEventId = eventId ??
            (payload['event_id'] as String?) ??
            '${eventType}_${payload['id'] ?? ''}_${timestamp.millisecondsSinceEpoch}';

        final isPrivate = (payload['is_private'] as bool?) ??
            (payload['split_ratio'] == -1.0);

        await db.recordActivityEvent(
          LocalActivityEventsCompanion.insert(
            id: activityEventId,
            homeId: homeId,
            actorId: authorId,
            eventType: eventType,
            payloadJson: jsonEncode(payload),
            createdAt: timestamp,
            syncStatus: const Value('savedLocally'),
            isPrivate: Value(isPrivate),
          ),
        );
      }

      switch (eventType) {
        // --- HOMES ---
        case 'home_created':
        case 'home_updated':
          final id = (payload['id'] as String?) ?? homeId;
          final existing = await (db.select(db.localHomes)..where((t) => t.id.equals(id))).getSingleOrNull();
          final currencyVal = payload['currency'] as String? ?? existing?.currency ?? 'USD';
          await db.into(db.localHomes).insertOnConflictUpdate(
                LocalHomesCompanion(
                  id: Value(id),
                  name: Value((payload['name'] as String?) ?? existing?.name ?? 'Home'),
                  description: Value(payload.containsKey('description') ? payload['description'] as String? : existing?.description),
                  icon: Value(payload.containsKey('icon') ? payload['icon'] as String? : existing?.icon),
                  currency: Value(currencyVal),
                  createdAt: Value(existing?.createdAt ?? timestamp),
                  createdBy: Value(existing?.createdBy ?? authorId),
                ),
              );
          break;

        case 'home_currency_updated':
          final id = (payload['id'] as String?) ?? homeId;
          final currency = (payload['currency'] as String?) ?? 'USD';
          await (db.update(db.localHomes)..where((t) => t.id.equals(id))).write(
            LocalHomesCompanion(
              currency: Value(currency),
            ),
          );
          break;

        // --- LISTS ---
        case 'list_created':
          await db.into(db.localLists).insertOnConflictUpdate(
                LocalListsCompanion.insert(
                  id: payload['id'] as String,
                  homeId: homeId,
                  name: (payload['name'] as String?) ?? 'List',
                  isArchived: const Value(false),
                  createdAt: timestamp,
                  createdBy: authorId,
                ),
              );
          break;

        case 'list_archived':
        case 'list_deleted':
          final listId = (payload['id'] ?? payload['list_id']) as String?;
          if (listId != null && listId.isNotEmpty) {
            await (db.delete(db.localListItems)..where((t) => t.listId.equals(listId))).go();
            await (db.delete(db.localLists)..where((t) => t.id.equals(listId))).go();
          }
          break;

        case 'list_renamed':
          final listId = (payload['id'] ?? payload['list_id']) as String;
          final newName = payload['name'] as String? ?? 'List';
          await (db.update(db.localLists)..where((t) => t.id.equals(listId)))
              .write(LocalListsCompanion(name: Value(newName)));
          break;

        case 'lists_reordered':
          final orderList = (payload['order'] as List<dynamic>?)?.map((e) => e.toString()).toList();
          if (orderList != null && orderList.isNotEmpty) {
            try {
              await storage.write(
                key: 'cove_lists_tab_order_$homeId',
                value: orderList.join(','),
              );
            } catch (_) {}
          }
          break;

        // --- LIST ITEMS ---
        case 'list_item_added':
          final itemId = (payload['id'] as String?) ?? 'item_${timestamp.millisecondsSinceEpoch}';
          final listId = (payload['list_id'] as String?) ?? 'default_list';

          // Auto-heal: Ensure the parent list exists in localLists and is unarchived!
          final existingParent = await (db.select(db.localLists)..where((t) => t.id.equals(listId))).getSingleOrNull();
          if (existingParent == null) {
            final listName = (payload['list_name'] as String?) ??
                (listId.toLowerCase().contains('grocery')
                    ? 'Grocery'
                    : (listId.toLowerCase().contains('travel')
                        ? 'Travel'
                        : (listId.toLowerCase().contains('planning')
                            ? 'Planning'
                            : 'List')));
            await db.into(db.localLists).insertOnConflictUpdate(
              LocalListsCompanion.insert(
                id: listId,
                homeId: homeId,
                name: listName,
                isArchived: const Value(false),
                createdAt: timestamp,
                createdBy: authorId,
              ),
            );
          } else if (existingParent.isArchived) {
            await (db.update(db.localLists)..where((t) => t.id.equals(listId)))
                .write(const LocalListsCompanion(isArchived: Value(false)));
          }

          await db.into(db.localListItems).insertOnConflictUpdate(
                LocalListItemsCompanion.insert(
                  id: itemId,
                  homeId: homeId,
                  listId: listId,
                  title: (payload['title'] as String?) ?? '',
                  notes: Value(payload['notes'] as String?),
                  isCompleted: const Value(false),
                  createdAt: timestamp,
                  createdBy: authorId,
                ),
              );
          break;

        case 'list_item_updated':
          final itemId = payload['id'] as String;
          final title = payload['title'] as String?;
          final notes = payload['notes'] as String?;
          await (db.update(db.localListItems)..where((t) => t.id.equals(itemId))).write(
            LocalListItemsCompanion(
              title: title != null ? Value(title) : const Value.absent(),
              notes: notes != null ? Value(notes) : const Value.absent(),
            ),
          );
          break;

        case 'list_item_toggled':
          final itemId = payload['id'] as String;
          final isCompleted = payload['is_completed'] as bool? ?? true;
          await (db.update(db.localListItems)
                ..where((t) => t.id.equals(itemId)))
              .write(
            LocalListItemsCompanion(
              isCompleted: Value(isCompleted),
              completedAt: Value(isCompleted ? timestamp : null),
              completedBy: Value(isCompleted ? authorId : null),
            ),
          );
          break;

        case 'list_item_deleted':
          final itemId = payload['id'] as String;
          await (db.delete(db.localListItems)
                ..where((t) => t.id.equals(itemId)))
              .go();
          break;

        case 'list_completed_cleared':
          final targetListId = payload['list_id'] as String;
          await db.clearCompletedListItems(homeId, targetListId);
          break;

        // --- SUBSCRIPTIONS ---
        case 'subscription_added':
        case 'subscription_updated':
          final nextDateStr = payload['next_billing_date'] as String?;
          final nextDate = nextDateStr != null
              ? DateTime.tryParse(nextDateStr) ?? timestamp
              : timestamp;
          final endDateStr = payload['end_date'] as String?;
          final endDate = endDateStr != null ? DateTime.tryParse(endDateStr) : null;

          await db.into(db.localSubscriptions).insertOnConflictUpdate(
                LocalSubscriptionsCompanion.insert(
                  id: payload['id'] as String,
                  homeId: homeId,
                  name: (payload['name'] as String?) ?? '',
                  amount: (payload['amount'] as num?)?.toDouble() ?? 0.0,
                  currency: Value((payload['currency'] as String?) ?? 'USD'),
                  billingCycle:
                      Value((payload['billing_cycle'] as String?) ?? 'monthly'),
                  nextBillingDate: nextDate,
                  category: Value(payload['category'] as String?),
                  isActive: Value((payload['is_active'] as bool?) ?? true),
                  isPrivate: Value((payload['is_private'] as bool?) ?? false),
                  createdBy: Value((payload['created_by'] as String?) ?? authorId),
                  createdAt: timestamp,
                  endDate: Value(endDate),
                  paidBy: Value((payload['paid_by'] as String?) ??
                      (payload['created_by'] as String?) ??
                      authorId),
                  financedThrough: Value(payload['financed_through'] as String?),
                  totalInstallments: Value(payload['total_installments'] as int?),
                  paidInstallments: Value(payload['paid_installments'] as int?),
                ),
              );
          break;

        case 'subscription_cancelled':
          final subId = payload['id'] as String;
          await (db.update(db.localSubscriptions)
                ..where((t) => t.id.equals(subId)))
              .write(const LocalSubscriptionsCompanion(isActive: Value(false)));
          break;

        case 'subscription_reactivated':
          final reactivateId = payload['id'] as String;
          await (db.update(db.localSubscriptions)
                ..where((t) => t.id.equals(reactivateId)))
              .write(const LocalSubscriptionsCompanion(isActive: Value(true)));
          break;

        case 'subscription_deleted':
          final deleteId = payload['id'] as String;
          await (db.delete(db.localSubscriptions)
                ..where((t) => t.id.equals(deleteId)))
              .go();
          break;

        // --- EXPENSES ---
        case 'expense_logged':
        case 'expense_updated':
          final dateStr = payload['expense_date'] as String?;
          final expenseDate = dateStr != null
              ? DateTime.tryParse(dateStr) ?? timestamp
              : timestamp;

          final visibility = payload['visibility'] as String? ?? 'shared';
          // Split ratio conventions:
          // 0.5 = shared 50/50
          // 0.0 = partner_can_see (disclosed, but not part of joint split)
          // -1.0 = private_to_me (only stored locally, but if encountered)
          double defaultRatio = 0.5;
          if (visibility == 'partner_can_see') {
            defaultRatio = 0.0;
          } else if (visibility == 'private_to_me') {
            defaultRatio = -1.0;
          }

          final splitRatioVal = (payload['split_ratio'] as num?)?.toDouble() ?? defaultRatio;

          // Combine category and notes if notes present: "Category • Notes" or clean category
          String? categoryVal = payload['category'] as String?;
          final noteVal = payload['notes'] as String?;
          if (noteVal != null && noteVal.trim().isNotEmpty) {
            if (categoryVal != null && categoryVal.isNotEmpty) {
              categoryVal = '$categoryVal • ${noteVal.trim()}';
            } else {
              categoryVal = noteVal.trim();
            }
          }

          final isTransfer = (payload['is_transfer'] as bool?) ?? false;

          await db.into(db.localExpenses).insertOnConflictUpdate(
                LocalExpensesCompanion.insert(
                  id: payload['id'] as String,
                  homeId: homeId,
                  title: (payload['title'] as String?) ?? '',
                  amount: (payload['amount'] as num?)?.toDouble() ?? 0.0,
                  currency: Value((payload['currency'] as String?) ?? 'USD'),
                  paidBy: (payload['paid_by'] as String?) ?? authorId,
                  splitRatio: Value(splitRatioVal),
                  expenseDate: expenseDate,
                  category: Value(categoryVal),
                  paymentMethod: Value(payload['payment_method'] as String?),
                  isTransfer: Value(isTransfer),
                  createdAt: timestamp,
                ),
              );
          break;

        case 'expense_deleted':
          final expenseId = payload['id'] as String;
          await (db.delete(db.localExpenses)
                ..where((t) => t.id.equals(expenseId)))
              .go();
          break;

        // --- HABITS ---
        case 'habit_created':
          final rawDays = (payload['target_days_per_week'] as num?)?.toInt() ?? 7;
          final isPrivate = payload['is_private'] as bool? ?? false;
          // Negative target days signifies privateToMe locally
          final effectiveTarget = isPrivate ? -rawDays.abs() : rawDays.abs();

          await db.into(db.localHabits).insertOnConflictUpdate(
                LocalHabitsCompanion.insert(
                  id: payload['id'] as String,
                  homeId: homeId,
                  name: (payload['name'] as String?) ?? '',
                  cadence: Value((payload['cadence'] as String?) ?? 'daily'),
                  targetDaysPerWeek: Value(effectiveTarget),
                  isArchived: const Value(false),
                  createdAt: timestamp,
                  createdBy: authorId,
                ),
              );
          break;

        case 'habit_updated':
          final habitId = payload['id'] as String;
          final name = payload['name'] as String?;
          final cadence = payload['cadence'] as String?;
          final rawDays = (payload['target_days_per_week'] as num?)?.toInt();
          final isPrivate = payload['is_private'] as bool?;

          int? effectiveTarget;
          if (rawDays != null) {
            effectiveTarget = (isPrivate == true) ? -rawDays.abs() : rawDays.abs();
          }

          await (db.update(db.localHabits)..where((t) => t.id.equals(habitId))).write(
            LocalHabitsCompanion(
              name: name != null ? Value(name) : const Value.absent(),
              cadence: cadence != null ? Value(cadence) : const Value.absent(),
              targetDaysPerWeek:
                  effectiveTarget != null ? Value(effectiveTarget) : const Value.absent(),
            ),
          );
          break;

        case 'habit_checkin_toggled':
          final habitId = payload['habit_id'] as String;
          final checkinDate = payload['checkin_date'] as String; // YYYY-MM-DD
          final checked = payload['checked'] as bool? ?? true;

          // STRICT ACTOR ENFORCEMENT:
          // A user can ONLY emit check-in events for their own habits!
          // An event's actor_id must match the habit's owner (createdBy).
          final habitList = await (db.select(db.localHabits)
                ..where((t) => t.id.equals(habitId)))
              .get();
          if (habitList.isNotEmpty) {
            final habit = habitList.first;
            if (habit.createdBy != authorId) {
              // Actor is NOT the habit owner. Drop/reject the check-in event.
              break;
            }
          }

          final checkinId = '$habitId-$checkinDate-$authorId';

          if (checked) {
            await db.into(db.localHabitCheckins).insertOnConflictUpdate(
                  LocalHabitCheckinsCompanion.insert(
                    id: checkinId,
                    homeId: homeId,
                    habitId: habitId,
                    checkinDate: checkinDate,
                    memberId: authorId,
                    createdAt: timestamp,
                  ),
                );
          } else {
            await (db.delete(db.localHabitCheckins)
                  ..where((t) =>
                      t.habitId.equals(habitId) &
                      t.checkinDate.equals(checkinDate) &
                      t.memberId.equals(authorId)))
                .go();
          }
          break;

        case 'habit_checkin_acknowledged':
          final habitId = payload['habit_id'] as String;
          final checkinDate = payload['checkin_date'] as String;
          final ownerId = payload['owner_id'] as String? ?? '';

          // If checkin exists, mark or update acknowledgment in checkin id or record
          // The checkin record ID format is '$habitId-$checkinDate-$ownerId'
          // We can record an acknowledgment entry:
          final checkinId = '$habitId-$checkinDate-$ownerId';
          final checkinAckId = '$checkinId-ack-$authorId';

          // Insert or update check-in record so partner can see the quiet acknowledgment
          await db.into(db.localHabitCheckins).insertOnConflictUpdate(
                LocalHabitCheckinsCompanion.insert(
                  id: checkinAckId,
                  homeId: homeId,
                  habitId: habitId,
                  checkinDate: checkinDate,
                  memberId: 'ack:$authorId', // Ack marker tag
                  createdAt: timestamp,
                ),
              );
          break;

        case 'habit_archived':
        case 'habit_deleted':
          final habitId = payload['id'] as String;
          await db.deleteHabit(habitId);
          break;

        // --- CALENDAR EVENTS ---
        case 'calendar_event_added':
        case 'calendar_event_updated':
          final startStr = payload['start_time'] as String?;
          final endStr = payload['end_time'] as String?;
          final start = startStr != null
              ? DateTime.tryParse(startStr) ?? timestamp
              : timestamp;
          final end = endStr != null
              ? DateTime.tryParse(endStr) ?? start.add(const Duration(hours: 1))
              : start.add(const Duration(hours: 1));

          await db.into(db.localCalendarEvents).insertOnConflictUpdate(
                LocalCalendarEventsCompanion.insert(
                  id: payload['id'] as String,
                  homeId: homeId,
                  title: (payload['title'] as String?) ?? '',
                  description: Value(payload['description'] as String?),
                  startTime: start,
                  endTime: end,
                  isAllDay: Value(payload['is_all_day'] as bool? ?? false),
                  location: Value(payload['location'] as String?),
                  createdAt: timestamp,
                  createdBy: authorId,
                  recurrence: Value(payload['recurrence'] as String?),
                ),
              );
          break;

        case 'calendar_event_deleted':
          final eventId = payload['id'] as String;
          await (db.delete(db.localCalendarEvents)
                ..where((t) => t.id.equals(eventId)))
              .go();
          break;

        // --- ROADMAP ITEMS ---
        case 'roadmap_item_added':
          await db.into(db.localRoadmapItems).insertOnConflictUpdate(
                LocalRoadmapItemsCompanion.insert(
                  id: payload['id'] as String,
                  homeId: homeId,
                  title: (payload['title'] as String?) ?? '',
                  description: Value(payload['description'] as String?),
                  isCompleted: Value(payload['is_completed'] as bool? ?? false),
                  createdAt: timestamp,
                  createdBy: authorId,
                  completedAt: Value(payload['completed_at'] != null
                      ? DateTime.tryParse(payload['completed_at'] as String)
                      : null),
                ),
              );
          break;

        case 'roadmap_item_toggled':
          final isCompleted = payload['is_completed'] as bool? ?? false;
          final completedAtStr = payload['completed_at'] as String?;
          final completedAt = isCompleted
              ? (completedAtStr != null ? DateTime.tryParse(completedAtStr) : timestamp)
              : null;
          await (db.update(db.localRoadmapItems)
                ..where((t) => t.id.equals(payload['id'] as String)))
              .write(
            LocalRoadmapItemsCompanion(
              isCompleted: Value(isCompleted),
              completedAt: Value(completedAt),
            ),
          );
          break;

        case 'roadmap_item_deleted':
          final rId = payload['id'] as String;
          await db.deleteRoadmapItem(rId);
          break;

        case 'roadmap_item_updated':
          final updateId = payload['id'] as String;
          final updateTitle = payload['title'] as String?;
          final updateDesc = payload['description'] as String?;
          await (db.update(db.localRoadmapItems)..where((t) => t.id.equals(updateId))).write(
            LocalRoadmapItemsCompanion(
              title: updateTitle != null ? Value(updateTitle) : const Value.absent(),
              description: Value(updateDesc),
            ),
          );
          break;

        case 'roadmap_items_reordered':
          final rawOrder = payload['order'];
          if (rawOrder is List) {
            final orderList = rawOrder.map((e) => e.toString()).toList();
            try {
              await storage.write(
                key: 'cove_roadmap_order_$homeId',
                value: jsonEncode(orderList),
              );
            } catch (_) {}
          }
          break;

        // --- ROUTINES ---
        case 'routine_created':
        case 'routine_updated':
          final rId = payload['id'] as String;
          final rName = (payload['name'] as String?) ?? 'Routine';
          final rDaysJson = (payload['days_json'] as String?) ?? jsonEncode([1, 2, 3, 4, 5]);
          await db.into(db.localRoutines).insertOnConflictUpdate(
            LocalRoutinesCompanion(
              id: Value(rId),
              homeId: Value(homeId),
              name: Value(rName),
              daysJson: Value(rDaysJson),
              createdAt: Value(timestamp),
            ),
          );
          break;

        case 'routine_deleted':
          final delRoutineId = payload['id'] as String;
          await (db.delete(db.localRoutineEvents)..where((t) => t.routineId.equals(delRoutineId))).go();
          await (db.delete(db.localRoutines)..where((t) => t.id.equals(delRoutineId))).go();
          break;

        case 'routine_event_created':
        case 'routine_event_updated':
          final eId = payload['id'] as String;
          final eRoutineId = (payload['routine_id'] as String?) ?? '';
          final eTitle = (payload['title'] as String?) ?? '';
          final eStart = (payload['start_minutes'] as num?)?.toInt() ?? 0;
          final eEnd = (payload['end_minutes'] as num?)?.toInt() ?? 60;
          final eCategory = payload['category'] as String?;
          final eNotes = payload['notes'] as String?;
          await db.into(db.localRoutineEvents).insertOnConflictUpdate(
            LocalRoutineEventsCompanion(
              id: Value(eId),
              routineId: Value(eRoutineId),
              homeId: Value(homeId),
              title: Value(eTitle),
              startMinutes: Value(eStart),
              endMinutes: Value(eEnd),
              category: Value(eCategory),
              notes: Value(eNotes),
              createdAt: Value(timestamp),
            ),
          );
          break;

        case 'routine_event_deleted':
          final delEventId = payload['id'] as String;
          await (db.delete(db.localRoutineEvents)..where((t) => t.id.equals(delEventId))).go();
          break;

        case 'member_profile_updated':
          final dName = (payload['display_name'] ?? payload['actor_name']) as String?;
          final avatar = payload['avatar_url'] as String?;
          final pUserId = (payload['user_id'] as String?) ?? authorId;

          // Guard against self-overwrite: do not update partner profile if this is the current user
          String? currentUserId;
          try {
            currentUserId = Supabase.instance.client.auth.currentUser?.id;
          } catch (_) {}

          if (currentUserId != null && currentUserId.isNotEmpty) {
            if (pUserId == currentUserId || authorId == currentUserId) {
              // Same account on another device: sync local user profile!
              final useInitials = payload['use_initials'] == true;
              if (dName != null && dName.trim().isNotEmpty) {
                await UserProfileNotifier.updateUserFromRemote(
                  name: dName.trim(),
                  avatarUrl: useInitials ? null : avatar,
                  useInitials: useInitials,
                );
              }
              break;
            }
          }

          if (dName != null &&
              dName.trim().isNotEmpty &&
              dName.trim() != 'Partner' &&
              dName.trim() != 'You') {
            final trimmed = dName.trim();
            try {
              await storage.write(key: 'cove_partner_name_$homeId', value: trimmed);
              await storage.write(key: 'cove_partner_name_default', value: trimmed);
              if (avatar != null && avatar.isNotEmpty) {
                await storage.write(key: 'cove_partner_avatar_$homeId', value: avatar);
                await storage.write(key: 'cove_partner_avatar_default', value: avatar);
              }
              if (pUserId.isNotEmpty) {
                await storage.write(key: 'cove_partner_id_$homeId', value: pUserId);
                await storage.write(key: 'cove_partner_id_default', value: pUserId);
              }
            } catch (_) {}
            await PartnerProfileNotifier.updatePartnerFromRemote(
              homeId: homeId,
              name: trimmed,
              avatarUrl: avatar,
              userId: pUserId,
            );
          }
          break;

        case 'monthly_budget_updated':
          final bAmt = (payload['amount'] as num?)?.toDouble();
          if (bAmt != null && bAmt > 0) {
            await MonthlyBudgetNotifier.updateFromRemote(homeId: homeId, amount: bAmt);
          }
          break;

        case 'monthly_budget_cleared':
          await MonthlyBudgetNotifier.updateFromRemote(homeId: homeId, amount: null);
          break;

        default:
          // Unknown or custom event: silently accepted into event log
          break;
      }
    });
  }

  @override
  Future<void> clearAll() async {
    await db.transaction(() async {
      await db.delete(db.localCalendarEvents).go();
      await db.delete(db.localHabitCheckins).go();
      await db.delete(db.localHabits).go();
      await db.delete(db.localExpenses).go();
      await db.delete(db.localSubscriptions).go();
      await db.delete(db.localListItems).go();
      await db.delete(db.localLists).go();
      await db.delete(db.localHomes).go();
      await db.delete(db.localOutboxEvents).go();
      await db.delete(db.localActivityEvents).go();
    });
  }

  @override
  Future<bool> hasEvent(String eventId) async {
    return db.hasActivityEvent(eventId);
  }

  @override
  Future<void> close() async {
    await db.close();
  }
}
