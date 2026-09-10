import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// --- DRIFT TABLES: SCOPED BY homeId ---

class LocalHomes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get icon => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalLists extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get name => text()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalListItems extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get listId => text()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get completedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalSubscriptions extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get name => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get billingCycle =>
      text().withDefault(const Constant('monthly'))(); // monthly or annual
  DateTimeColumn get nextBillingDate => dateTime()();
  TextColumn get category => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();
  TextColumn get createdBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalExpenses extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get paidBy => text()();
  RealColumn get splitRatio => real().withDefault(const Constant(0.5))();
  DateTimeColumn get expenseDate => dateTime()();
  TextColumn get category => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalHabits extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get name => text()();
  TextColumn get cadence => text().withDefault(const Constant('daily'))();
  IntColumn get targetDaysPerWeek => integer().withDefault(const Constant(7))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalHabitCheckins extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get habitId => text()();
  TextColumn get checkinDate => text()(); // YYYY-MM-DD
  TextColumn get memberId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalCalendarEvents extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(false))();
  TextColumn get location => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalOutboxEvents extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get actorId => text()();
  TextColumn get eventType => text()();
  TextColumn get payloadJson => text()();
  TextColumn get encryptedPayload => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('savedLocally'))(); // savedLocally, syncedToPartner
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [
  LocalHomes,
  LocalLists,
  LocalListItems,
  LocalSubscriptions,
  LocalExpenses,
  LocalHabits,
  LocalHabitCheckins,
  LocalCalendarEvents,
  LocalOutboxEvents,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'cove_db'));

  @override
  int get schemaVersion => 1;

  // --- REACTION STREAMS FILTERED BY homeId ---

  Stream<List<LocalHome>> watchHomes() {
    return (select(localHomes)..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<List<LocalList>> watchLists(String homeId) {
    return (select(localLists)
          ..where((t) => t.homeId.equals(homeId) & t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<LocalList>> getLists(String homeId) {
    return (select(localLists)
          ..where((t) => t.homeId.equals(homeId) & t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Stream<List<LocalListItem>> watchListItems(String homeId, String listId) {
    return (select(localListItems)
          ..where((t) => t.homeId.equals(homeId) & t.listId.equals(listId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.isCompleted),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<LocalListItem>> getListItems(String homeId, String listId) {
    return (select(localListItems)
          ..where((t) => t.homeId.equals(homeId) & t.listId.equals(listId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.isCompleted),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .get();
  }

  Future<void> clearCompletedListItems(String homeId, String listId) {
    return (delete(localListItems)
          ..where((t) =>
              t.homeId.equals(homeId) &
              t.listId.equals(listId) &
              t.isCompleted.equals(true)))
        .go();
  }

  Future<void> ensureDefaultLists(String homeId, String userId) async {
    final existing = await getLists(homeId);
    if (existing.isNotEmpty) return;

    final now = DateTime.now().toUtc();
    final defaultNames = ['Grocery', 'Travel', 'Planning'];
    for (int i = 0; i < defaultNames.length; i++) {
      final name = defaultNames[i];
      final id = 'default_${name.toLowerCase()}_$homeId';
      await into(localLists).insertOnConflictUpdate(
        LocalListsCompanion.insert(
          id: id,
          homeId: homeId,
          name: name,
          isArchived: const Value(false),
          createdAt: now.add(Duration(milliseconds: i * 10)),
          createdBy: userId,
        ),
      );
    }
  }

  Stream<List<LocalSubscription>> watchSubscriptions(
    String homeId, {
    String? currentUserId,
  }) {
    return (select(localSubscriptions)
          ..where((t) {
            final inHome = t.homeId.equals(homeId);
            if (currentUserId != null) {
              return inHome &
                  (t.isPrivate.equals(false) | t.createdBy.equals(currentUserId));
            }
            return inHome & t.isPrivate.equals(false);
          })
          ..orderBy([(t) => OrderingTerm.asc(t.nextBillingDate)]))
        .watch();
  }

  Future<List<LocalSubscription>> getSubscriptions(
    String homeId, {
    String? currentUserId,
  }) {
    return (select(localSubscriptions)
          ..where((t) {
            final inHome = t.homeId.equals(homeId);
            if (currentUserId != null) {
              return inHome &
                  (t.isPrivate.equals(false) | t.createdBy.equals(currentUserId));
            }
            return inHome & t.isPrivate.equals(false);
          })
          ..orderBy([(t) => OrderingTerm.asc(t.nextBillingDate)]))
        .get();
  }

  Stream<List<LocalExpense>> watchExpenses(String homeId) {
    return (select(localExpenses)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .watch();
  }

  Stream<List<LocalHabit>> watchHabits(String homeId) {
    return (select(localHabits)
          ..where((t) => t.homeId.equals(homeId) & t.isArchived.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Stream<List<LocalHabitCheckin>> watchHabitCheckins(
      String homeId, String habitId) {
    return (select(localHabitCheckins)
          ..where((t) => t.homeId.equals(homeId) & t.habitId.equals(habitId))
          ..orderBy([(t) => OrderingTerm.desc(t.checkinDate)]))
        .watch();
  }

  Stream<List<LocalCalendarEvent>> watchCalendarEvents(String homeId) {
    return (select(localCalendarEvents)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .watch();
  }

  Stream<List<LocalOutboxEvent>> watchOutbox(String homeId) {
    return (select(localOutboxEvents)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }
}
