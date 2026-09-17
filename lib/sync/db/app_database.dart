import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// --- DRIFT TABLES: SCOPED BY homeId ---

class LocalHomes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
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
  DateTimeColumn get endDate => dateTime().nullable()();
  TextColumn get paidBy => text().nullable()();
  TextColumn get financedThrough => text().nullable()();
  IntColumn get totalInstallments => integer().nullable()();
  IntColumn get paidInstallments => integer().nullable()();

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
  TextColumn get paymentMethod => text().nullable()(); // 'card', 'upi', 'cash'
  BoolColumn get isTransfer => boolean().withDefault(const Constant(false))();
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
  TextColumn get recurrence => text().nullable()(); // 'daily', 'weekly', 'biweekly', 'monthly', 'yearly'

  @override
  Set<Column> get primaryKey => {id};
}

class LocalRoadmapItems extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text()();
  DateTimeColumn get completedAt => dateTime().nullable()();

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

class LocalActivityEvents extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get actorId => text()();
  TextColumn get eventType => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('savedLocally'))(); // savedLocally, syncedToPartner
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalNotificationPreferences extends Table {
  TextColumn get id => text().withDefault(const Constant('default'))();
  BoolColumn get muteSubscriptions =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get muteLists => boolean().withDefault(const Constant(false))();
  BoolColumn get muteExpenses =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get muteHabits => boolean().withDefault(const Constant(false))();
  BoolColumn get muteCalendar =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalRoutines extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get name => text()();
  TextColumn get daysJson => text()(); // JSON array of day ints: 1=Mon .. 7=Sun
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalRoutineEvents extends Table {
  TextColumn get id => text()();
  TextColumn get routineId => text()();
  TextColumn get homeId => text()();
  TextColumn get title => text()();
  IntColumn get startMinutes => integer()(); // 0 to 1439 (minutes from midnight)
  IntColumn get endMinutes => integer()(); // 0 to 1439
  TextColumn get category => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

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
  LocalActivityEvents,
  LocalNotificationPreferences,
  LocalRoadmapItems,
  LocalRoutines,
  LocalRoutineEvents,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'cove_db',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(localSubscriptions, localSubscriptions.endDate);
          }
          if (from < 3) {
            await m.addColumn(localCalendarEvents, localCalendarEvents.recurrence);
            await m.createTable(localRoadmapItems);
          }
          if (from < 4) {
            await m.addColumn(localHomes, localHomes.currency);
          }
          if (from < 5) {
            await m.addColumn(localExpenses, localExpenses.paymentMethod);
          }
          if (from < 6) {
            await m.addColumn(localExpenses, localExpenses.isTransfer);
          }
          if (from < 7) {
            await m.addColumn(localSubscriptions, localSubscriptions.paidBy);
            await m.createTable(localRoutines);
            await m.createTable(localRoutineEvents);
          }
          if (from < 8) {
            await m.addColumn(localSubscriptions, localSubscriptions.financedThrough);
            await m.addColumn(localSubscriptions, localSubscriptions.totalInstallments);
            await m.addColumn(localSubscriptions, localSubscriptions.paidInstallments);
          }
        },
      );

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

  Stream<List<LocalListItem>> watchAllHomeListItems(String homeId) {
    final query = select(localListItems).join([
      innerJoin(
        localLists,
        localLists.id.equalsExp(localListItems.listId) &
            localLists.isArchived.equals(false),
      ),
    ])
      ..where(localListItems.homeId.equals(homeId));

    return query.watch().map((rows) {
      return rows.map((r) => r.readTable(localListItems)).toList();
    });
  }

  Future<List<LocalListItem>> getAllHomeListItems(String homeId) {
    final query = select(localListItems).join([
      innerJoin(
        localLists,
        localLists.id.equalsExp(localListItems.listId) &
            localLists.isArchived.equals(false),
      ),
    ])
      ..where(localListItems.homeId.equals(homeId));

    return query.get().then((rows) {
      return rows.map((r) => r.readTable(localListItems)).toList();
    });
  }

  Future<int> purgeOrphanedAndArchivedListItems([String? homeId]) async {
    // 1. Delete all items belonging to archived lists and delete the archived lists themselves
    final archivedLists = await (select(localLists)
          ..where((t) =>
              t.isArchived.equals(true) &
              (homeId != null ? t.homeId.equals(homeId) : const Constant(true))))
        .get();
    final archivedIds = archivedLists.map((l) => l.id).toSet();
    if (archivedIds.isNotEmpty) {
      await (delete(localListItems)..where((t) => t.listId.isIn(archivedIds))).go();
      await (delete(localLists)..where((t) => t.id.isIn(archivedIds))).go();
    }

    // 2. Auto-heal any items whose listId does not exist in localLists rather than destroying data
    final allLists = await (select(localLists)
          ..where((t) =>
              (homeId != null ? t.homeId.equals(homeId) : const Constant(true))))
        .get();
    final validListIds = allLists.map((l) => l.id).toSet();

    final orphanedItems = await (select(localListItems)
          ..where((t) =>
              (homeId != null ? t.homeId.equals(homeId) : const Constant(true)) &
              t.listId.isNotIn(validListIds)))
        .get();

    if (orphanedItems.isNotEmpty) {
      final now = DateTime.now().toUtc();
      final missingListIds = orphanedItems.map((i) => i.listId).toSet();
      for (final mId in missingListIds) {
        final listName = mId.toLowerCase().contains('grocery')
            ? 'Grocery'
            : (mId.toLowerCase().contains('travel')
                ? 'Travel'
                : (mId.toLowerCase().contains('planning')
                    ? 'Planning'
                    : 'List'));
        await into(localLists).insertOnConflictUpdate(
          LocalListsCompanion.insert(
            id: mId,
            homeId: homeId ?? orphanedItems.first.homeId,
            name: listName,
            isArchived: const Value(false),
            createdAt: now,
            createdBy: orphanedItems.first.createdBy,
          ),
        );
      }
    }

    return 0;
  }

  Future<void> ensureDefaultLists(String homeId, String userId) async {
    final existing = await getLists(homeId);
    final existingNames = existing.map((l) => l.name.trim().toLowerCase()).toSet();

    final now = DateTime.now().toUtc();
    final defaultNames = ['Grocery', 'Travel', 'Planning'];
    for (int i = 0; i < defaultNames.length; i++) {
      final name = defaultNames[i];
      if (existingNames.contains(name.toLowerCase())) continue;

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

  Stream<List<LocalExpense>> watchExpenses(
    String homeId, {
    String? currentUserId,
  }) {
    return (select(localExpenses)
          ..where((t) {
            final inHome = t.homeId.equals(homeId);
            // If expense has splitRatio == -1.0, that indicates privateToMe
            // (or if paidBy is current user)
            // But we also have splitRatio or notes/currency.
            // Private expenses must only be visible to current user who paid it.
            if (currentUserId != null) {
              return inHome &
                  (t.splitRatio.isBiggerThanValue(0.0) |
                      t.paidBy.equals(currentUserId));
            }
            return inHome & t.splitRatio.isBiggerThanValue(0.0);
          })
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .watch();
  }

  Future<List<LocalExpense>> getExpenses(
    String homeId, {
    String? currentUserId,
  }) {
    return (select(localExpenses)
          ..where((t) {
            final inHome = t.homeId.equals(homeId);
            if (currentUserId != null) {
              return inHome &
                  (t.splitRatio.isBiggerThanValue(0.0) |
                      t.paidBy.equals(currentUserId));
            }
            return inHome & t.splitRatio.isBiggerThanValue(0.0);
          })
          ..orderBy([(t) => OrderingTerm.desc(t.expenseDate)]))
        .get();
  }

  Future<void> deleteExpense(String expenseId) {
    return (delete(localExpenses)..where((t) => t.id.equals(expenseId))).go();
  }

  Stream<List<LocalHabit>> watchHabits(
    String homeId, {
    String? currentUserId,
  }) {
    return (select(localHabits)
          ..where((t) {
            final inHome = t.homeId.equals(homeId) & t.isArchived.equals(false);
            // Non-private habits (targetDaysPerWeek >= 0) are visible to all home members.
            // Private habits (targetDaysPerWeek < 0) are strictly visible only to their creator.
            if (currentUserId != null) {
              return inHome &
                  (t.targetDaysPerWeek.isBiggerOrEqualValue(0) |
                      t.createdBy.equals(currentUserId));
            }
            return inHome & t.targetDaysPerWeek.isBiggerOrEqualValue(0);
          })
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<LocalHabit>> getHabits(
    String homeId, {
    String? currentUserId,
  }) {
    return (select(localHabits)
          ..where((t) {
            final inHome = t.homeId.equals(homeId) & t.isArchived.equals(false);
            if (currentUserId != null) {
              return inHome &
                  (t.targetDaysPerWeek.isBiggerOrEqualValue(0) |
                      t.createdBy.equals(currentUserId));
            }
            return inHome & t.targetDaysPerWeek.isBiggerOrEqualValue(0);
          })
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> deleteHabit(String habitId) async {
    await (delete(localHabitCheckins)..where((t) => t.habitId.equals(habitId))).go();
    await (delete(localHabits)..where((t) => t.id.equals(habitId))).go();
  }

  Stream<List<LocalHabitCheckin>> watchHabitCheckins(
      String homeId, String habitId) {
    return (select(localHabitCheckins)
          ..where((t) => t.homeId.equals(homeId) & t.habitId.equals(habitId))
          ..orderBy([(t) => OrderingTerm.desc(t.checkinDate)]))
        .watch();
  }

  Stream<List<LocalHabitCheckin>> watchAllHabitCheckins(String homeId) {
    return (select(localHabitCheckins)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.desc(t.checkinDate)]))
        .watch();
  }

  Future<List<LocalHabitCheckin>> getAllHabitCheckins(String homeId) {
    return (select(localHabitCheckins)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.desc(t.checkinDate)]))
        .get();
  }

  Stream<List<LocalCalendarEvent>> watchCalendarEvents(String homeId) {
    return (select(localCalendarEvents)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .watch();
  }

  Future<List<LocalCalendarEvent>> getCalendarEvents(String homeId) {
    return (select(localCalendarEvents)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.asc(t.startTime)]))
        .get();
  }

  Future<void> deleteCalendarEvent(String eventId) {
    return (delete(localCalendarEvents)..where((t) => t.id.equals(eventId))).go();
  }

  Stream<List<LocalOutboxEvent>> watchOutbox(String homeId) {
    return (select(localOutboxEvents)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Stream<List<LocalActivityEvent>> watchActivityEvents(
    String homeId, {
    String? currentUserId,
    List<String>? eventTypeFilter,
    int limit = 50,
    int offset = 0,
  }) {
    final query = select(localActivityEvents)
      ..where((t) {
        Expression<bool> predicate = t.homeId.equals(homeId) &
            t.eventType.isNotValue('member_profile_updated') &
            t.eventType.isNotValue('profile_updated');
        if (currentUserId != null) {
          predicate = predicate &
              (t.isPrivate.equals(false) | t.actorId.equals(currentUserId));
        } else {
          predicate = predicate & t.isPrivate.equals(false);
        }
        if (eventTypeFilter != null && eventTypeFilter.isNotEmpty) {
          predicate = predicate & t.eventType.isIn(eventTypeFilter);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit, offset: offset);

    return query.watch();
  }

  Future<List<LocalActivityEvent>> getActivityEvents(
    String homeId, {
    String? currentUserId,
    List<String>? eventTypeFilter,
    int limit = 50,
    int offset = 0,
  }) {
    final query = select(localActivityEvents)
      ..where((t) {
        Expression<bool> predicate = t.homeId.equals(homeId) &
            t.eventType.isNotValue('member_profile_updated') &
            t.eventType.isNotValue('profile_updated');
        if (currentUserId != null) {
          predicate = predicate &
              (t.isPrivate.equals(false) | t.actorId.equals(currentUserId));
        } else {
          predicate = predicate & t.isPrivate.equals(false);
        }
        if (eventTypeFilter != null && eventTypeFilter.isNotEmpty) {
          predicate = predicate & t.eventType.isIn(eventTypeFilter);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit, offset: offset);

    return query.get();
  }

  Future<int> clearProfileActivityEvents() async {
    return (delete(localActivityEvents)
          ..where((t) =>
              t.eventType.equals('member_profile_updated') |
              t.eventType.equals('profile_updated')))
        .go();
  }

  Future<void> recordActivityEvent(LocalActivityEventsCompanion event) async {
    await into(localActivityEvents).insertOnConflictUpdate(event);
  }

  Future<bool> hasActivityEvent(String eventId) async {
    final row = await (select(localActivityEvents)
          ..where((t) => t.id.equals(eventId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> updateActivityEventSyncStatus(
      String eventId, String syncStatus) async {
    await (update(localActivityEvents)..where((t) => t.id.equals(eventId)))
        .write(LocalActivityEventsCompanion(syncStatus: Value(syncStatus)));
  }

  Stream<LocalNotificationPreference?> watchNotificationPreferences(
      {String id = 'default'}) {
    return (select(localNotificationPreferences)
          ..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<LocalNotificationPreference?> getNotificationPreferences(
      {String id = 'default'}) {
    return (select(localNotificationPreferences)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> saveNotificationPreferences({
    String id = 'default',
    required bool muteSubscriptions,
    required bool muteLists,
    required bool muteExpenses,
    required bool muteHabits,
    required bool muteCalendar,
  }) async {
    await into(localNotificationPreferences).insertOnConflictUpdate(
      LocalNotificationPreferencesCompanion(
        id: Value(id),
        muteSubscriptions: Value(muteSubscriptions),
        muteLists: Value(muteLists),
        muteExpenses: Value(muteExpenses),
        muteHabits: Value(muteHabits),
        muteCalendar: Value(muteCalendar),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  // --- ROADMAP ITEMS ---

  Stream<List<LocalRoadmapItem>> watchRoadmapItems(String homeId) {
    return (select(localRoadmapItems)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<LocalRoadmapItem>> getRoadmapItems(String homeId) {
    return (select(localRoadmapItems)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<void> deleteRoadmapItem(String itemId) {
    return (delete(localRoadmapItems)..where((t) => t.id.equals(itemId))).go();
  }

  // --- ROUTINES ---

  Stream<List<LocalRoutine>> watchRoutines(String homeId) {
    return (select(localRoutines)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<LocalRoutine>> getRoutines(String homeId) {
    return (select(localRoutines)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Stream<List<LocalRoutineEvent>> watchRoutineEvents(String routineId) {
    return (select(localRoutineEvents)
          ..where((t) => t.routineId.equals(routineId))
          ..orderBy([(t) => OrderingTerm.asc(t.startMinutes)]))
        .watch();
  }

  Future<List<LocalRoutineEvent>> getRoutineEvents(String routineId) {
    return (select(localRoutineEvents)
          ..where((t) => t.routineId.equals(routineId))
          ..orderBy([(t) => OrderingTerm.asc(t.startMinutes)]))
        .get();
  }
}

