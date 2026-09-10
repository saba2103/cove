import 'package:drift/drift.dart';
import '../local_state_store.dart';
import 'app_database.dart';

class LocalStateStoreImpl implements LocalStateStore {
  final AppDatabase db;

  LocalStateStoreImpl(this.db);

  @override
  Future<void> initialize() async {
    // Drift automatically initializes tables on first query.
  }

  @override
  Future<void> applyEvent({
    required String homeId,
    required String eventType,
    required Map<String, dynamic> payload,
    required DateTime timestamp,
    required String authorId,
  }) async {
    await db.transaction(() async {
      switch (eventType) {
        // --- HOMES ---
        case 'home_created':
        case 'home_updated':
          final id = (payload['id'] as String?) ?? homeId;
          await db.into(db.localHomes).insertOnConflictUpdate(
                LocalHomesCompanion.insert(
                  id: id,
                  name: (payload['name'] as String?) ?? 'Home',
                  description: Value(payload['description'] as String?),
                  icon: Value(payload['icon'] as String?),
                  createdAt: timestamp,
                  createdBy: authorId,
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
          final listId = payload['id'] as String;
          await (db.update(db.localLists)..where((t) => t.id.equals(listId)))
              .write(const LocalListsCompanion(isArchived: Value(true)));
          break;

        // --- LIST ITEMS ---
        case 'list_item_added':
          await db.into(db.localListItems).insertOnConflictUpdate(
                LocalListItemsCompanion.insert(
                  id: payload['id'] as String,
                  homeId: homeId,
                  listId: payload['list_id'] as String,
                  title: (payload['title'] as String?) ?? '',
                  notes: Value(payload['notes'] as String?),
                  isCompleted: const Value(false),
                  createdAt: timestamp,
                  createdBy: authorId,
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

        // --- EXPENSES ---
        case 'expense_logged':
          final dateStr = payload['expense_date'] as String?;
          final expenseDate = dateStr != null
              ? DateTime.tryParse(dateStr) ?? timestamp
              : timestamp;

          await db.into(db.localExpenses).insertOnConflictUpdate(
                LocalExpensesCompanion.insert(
                  id: payload['id'] as String,
                  homeId: homeId,
                  title: (payload['title'] as String?) ?? '',
                  amount: (payload['amount'] as num?)?.toDouble() ?? 0.0,
                  currency: Value((payload['currency'] as String?) ?? 'USD'),
                  paidBy: (payload['paid_by'] as String?) ?? authorId,
                  splitRatio:
                      Value((payload['split_ratio'] as num?)?.toDouble() ?? 0.5),
                  expenseDate: expenseDate,
                  category: Value(payload['category'] as String?),
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
          await db.into(db.localHabits).insertOnConflictUpdate(
                LocalHabitsCompanion.insert(
                  id: payload['id'] as String,
                  homeId: homeId,
                  name: (payload['name'] as String?) ?? '',
                  cadence: Value((payload['cadence'] as String?) ?? 'daily'),
                  targetDaysPerWeek: Value(
                      (payload['target_days_per_week'] as num?)?.toInt() ?? 7),
                  isArchived: const Value(false),
                  createdAt: timestamp,
                  createdBy: authorId,
                ),
              );
          break;

        case 'habit_checkin_toggled':
          final habitId = payload['habit_id'] as String;
          final checkinDate = payload['checkin_date'] as String; // YYYY-MM-DD
          final checked = payload['checked'] as bool? ?? true;
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

        case 'habit_archived':
          final habitId = payload['id'] as String;
          await (db.update(db.localHabits)
                ..where((t) => t.id.equals(habitId)))
              .write(const LocalHabitsCompanion(isArchived: Value(true)));
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
                ),
              );
          break;

        case 'calendar_event_deleted':
          final eventId = payload['id'] as String;
          await (db.delete(db.localCalendarEvents)
                ..where((t) => t.id.equals(eventId)))
              .go();
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
    });
  }

  @override
  Future<void> close() async {
    await db.close();
  }
}
