import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages
import 'package:sqlite3/sqlite3.dart' show OpenMode, sqlite3;

part 'app_database.g.dart';

// --- DRIFT TABLES: SCOPED BY homeId ---

class LocalHomes extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get icon => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  RealColumn get monthlyBudget => real().nullable()();
  DateTimeColumn get anniversaryDate => dateTime().nullable()();
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
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get completedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text()();
  TextColumn get owner => text().nullable()();

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
  TextColumn get owner =>
      text().nullable().withDefault(const Constant('both'))();

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
  TextColumn get owner =>
      text().nullable().withDefault(const Constant('both'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalAppliedEvents extends Table {
  TextColumn get id => text()();
  DateTimeColumn get appliedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalDeletedTombstones extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()(); // e.g. 'expense', 'subscription'
  DateTimeColumn get deletedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalCheckinReminders extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  TextColumn get message => text()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalPets extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get createdBy => text()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_local_pet_tags_record',
  columns: {#recordKind, #recordId},
)
class LocalPetTags extends Table {
  TextColumn get id => text()();
  TextColumn get homeId => text()();
  TextColumn get petId => text()();
  TextColumn get recordKind =>
      text()(); // 'expense', 'event', 'task', 'habit', 'commitment', 'routine_event'
  TextColumn get recordId => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {petId, recordKind, recordId},
      ];
}

class FirstRunCounts {
  final int expenses;
  final int events;
  final int habits;
  final int habitCheckins;
  final int listItems;
  final int commitments;
  final int routineEvents;
  final int activity;
  final bool hasPartnerInDb;

  const FirstRunCounts({
    this.expenses = 0,
    this.events = 0,
    this.habits = 0,
    this.habitCheckins = 0,
    this.listItems = 0,
    this.commitments = 0,
    this.routineEvents = 0,
    this.activity = 0,
    this.hasPartnerInDb = false,
  });

  static const empty = FirstRunCounts();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FirstRunCounts &&
          expenses == other.expenses &&
          events == other.events &&
          habits == other.habits &&
          habitCheckins == other.habitCheckins &&
          listItems == other.listItems &&
          commitments == other.commitments &&
          routineEvents == other.routineEvents &&
          activity == other.activity &&
          hasPartnerInDb == other.hasPartnerInDb;

  @override
  int get hashCode => Object.hash(
        expenses,
        events,
        habits,
        habitCheckins,
        listItems,
        commitments,
        routineEvents,
        activity,
        hasPartnerInDb,
      );
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
  LocalAppliedEvents,
  LocalDeletedTombstones,
  LocalCheckinReminders,
  LocalPets,
  LocalPetTags,
])
class AppDatabase extends _$AppDatabase {
  bool _isClosed = false;

  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'cove_db',
              native: DriftNativeOptions(
                setup: (db) {
                  db.execute('PRAGMA busy_timeout = 5000;');
                },
              ),
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  Future<void> close() async {
    _isClosed = true;
    await super.close();
  }

  /// Opens an unshared, strictly read-only SQLite connection (`OpenMode.readOnly`
  /// + `PRAGMA busy_timeout = 5000`, `enableMigrations: false`) to [file]
  /// (or the default `cove_db.sqlite` file in the application documents directory).
  ///
  /// Used only when the main app is not running. Never shares across isolates,
  /// never runs migrations, and never writes.
  static QueryExecutor openReadOnlySqliteExecutor({
    File? file,
    Future<File> Function()? resolveFile,
  }) {
    return LazyDatabase(() async {
      final targetFile = file ??
          (resolveFile != null
              ? await resolveFile()
              : File(
                  '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}cove_db.sqlite',
                ));
      if (!targetFile.existsSync()) {
        targetFile.parent.createSync(recursive: true);
        targetFile.createSync();
      }
      final rawDb = sqlite3.open(
        targetFile.path,
        mode: OpenMode.readOnly,
      );
      return NativeDatabase.opened(
        rawDb,
        enableMigrations: false,
        closeUnderlyingOnClose: true,
        setup: (db) {
          db.execute('PRAGMA busy_timeout = 5000;');
        },
      );
    });
  }

  /// Opens a strictly read-only database handle for the background notification
  /// isolate when the main app is not running (`design/specs/15-notifications.md` / 3.14c).
  ///
  /// Opens its own, separate, unshared connection to the database file with
  /// `OpenMode.readOnly` + `busy_timeout = 5000` (`enableMigrations: false`),
  /// wrapped in [ReadOnlyQueryExecutor] as an extra Dart-level guard.
  factory AppDatabase.readOnly({
    QueryExecutor? inner,
    File? file,
    Future<File> Function()? resolveFile,
  }) {
    final base = inner ??
        openReadOnlySqliteExecutor(
          file: file,
          resolveFile: resolveFile,
        );
    return AppDatabase(ReadOnlyQueryExecutor(base));
  }

  /// Current Drift schema version (`PRAGMA user_version`).
  static const int currentSchemaVersion = 12;

  /// Opens an unshared, strictly read-only SQLite connection (`OpenMode.readOnly` +
  /// `PRAGMA busy_timeout = 5000`, `enableMigrations: false`) for a background
  /// notification isolate (`design/specs/15-notifications.md` / 4.7a).
  ///
  /// Refuses to run (closes the handle and returns `null`) if the database file
  /// does not exist or its `PRAGMA user_version` does not match
  /// [currentSchemaVersion]. Never creates tables or runs migrations from the
  /// background.
  static Future<AppDatabase?> openBackgroundReadOnlyIfSchemaMatches({
    File? file,
    Future<File> Function()? resolveFile,
  }) async {
    final targetFile = file ??
        (resolveFile != null
            ? await resolveFile()
            : File(
                '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}cove_db.sqlite',
              ));
    if (!targetFile.existsSync()) {
      return null;
    }

    final rawDb = sqlite3.open(
      targetFile.path,
      mode: OpenMode.readOnly,
    );
    try {
      rawDb.execute('PRAGMA busy_timeout = 5000;');
      final rows = rawDb.select('PRAGMA user_version;');
      final userVersion =
          rows.isNotEmpty ? (rows.first['user_version'] as int? ?? 0) : 0;
      if (userVersion != currentSchemaVersion) {
        rawDb.close();
        return null;
      }
    } catch (_) {
      rawDb.close();
      return null;
    }

    final executor = NativeDatabase.opened(
      rawDb,
      enableMigrations: false,
      closeUnderlyingOnClose: true,
      setup: (db) {
        db.execute('PRAGMA busy_timeout = 5000;');
      },
    );
    return AppDatabase(ReadOnlyQueryExecutor(executor));
  }

  /// Opens an unshared, writable SQLite connection (`OpenMode.readWrite` +
  /// `PRAGMA busy_timeout = 5000`, `enableMigrations: false`) for a background
  /// widget tick (`design/specs/18-widgets.md` § Ticking).
  ///
  /// Refuses to run (closes the handle and returns `null`) if the database file
  /// does not exist or its `PRAGMA user_version` does not match
  /// [currentSchemaVersion]. Never creates tables or runs migrations from the
  /// background.
  static Future<AppDatabase?> openBackgroundWritableIfSchemaMatches({
    File? file,
    Future<File> Function()? resolveFile,
  }) async {
    final targetFile = file ??
        (resolveFile != null
            ? await resolveFile()
            : File(
                '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}cove_db.sqlite',
              ));
    if (!targetFile.existsSync()) {
      return null;
    }

    final rawDb = sqlite3.open(
      targetFile.path,
      mode: OpenMode.readWrite,
    );
    try {
      rawDb.execute('PRAGMA busy_timeout = 5000;');
      final rows = rawDb.select('PRAGMA user_version;');
      final userVersion =
          rows.isNotEmpty ? (rows.first['user_version'] as int? ?? 0) : 0;
      if (userVersion != currentSchemaVersion) {
        rawDb.close();
        return null;
      }
    } catch (_) {
      rawDb.close();
      return null;
    }

    final executor = NativeDatabase.opened(
      rawDb,
      enableMigrations: false,
      closeUnderlyingOnClose: true,
      setup: (db) {
        db.execute('PRAGMA busy_timeout = 5000;');
      },
    );
    return AppDatabase(executor);
  }

  @override
  int get schemaVersion => currentSchemaVersion;

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
          if (from < 9) {
            await m.createTable(localAppliedEvents);
            await m.createTable(localDeletedTombstones);
          }
          if (from < 10) {
            await m.addColumn(localListItems, localListItems.dueDate);
          }
          if (from < 11) {
            await m.addColumn(localHomes, localHomes.monthlyBudget);
            await m.addColumn(localHomes, localHomes.anniversaryDate);
            await m.createTable(localCheckinReminders);
          }
          if (from < 12) {
            await m.addColumn(localCalendarEvents, localCalendarEvents.owner);
            await m.addColumn(localListItems, localListItems.owner);
            await m.addColumn(localRoutineEvents, localRoutineEvents.owner);
            await customStatement(
              "UPDATE local_calendar_events SET owner = 'both' WHERE owner IS NULL;",
            );
            await customStatement(
              "UPDATE local_routine_events SET owner = 'both' WHERE owner IS NULL;",
            );
            await customStatement(
              'UPDATE local_list_items SET owner = NULL WHERE owner IS NOT NULL;',
            );
            await m.createTable(localPets);
            await m.createTable(localPetTags);
            await m.createIndex(idxLocalPetTagsRecord);
          }
        },
      );

  /// Inserts a pet tag if `(pet_id, record_kind, record_id)` is not already
  /// tagged (`INSERT OR IGNORE`). Whichever device's `id` arrives second is a
  /// no-op so duplicate tags for the same `(pet, record)` can never exist.
  Future<int> insertPetTagIfAbsent(LocalPetTagsCompanion tag) {
    return into(localPetTags).insert(
      tag,
      mode: InsertMode.insertOrIgnore,
    );
  }

  // --- PETS & PET TAGS (`design/specs/19-owners-and-pets.md` §2) ---

  Stream<List<LocalPet>> watchPets(String homeId) {
    if (_isClosed || homeId.isEmpty) {
      return const Stream<List<LocalPet>>.empty();
    }
    return Stream<List<LocalPet>>.multi((controller) {
      var active = true;
      Future<void> emit() async {
        if (!active || _isClosed || controller.isClosed) return;
        try {
          final rows = await getPets(homeId);
          if (active && !_isClosed && !controller.isClosed) {
            controller.add(rows);
          }
        } catch (e, st) {
          if (active && !_isClosed && !controller.isClosed) {
            controller.addError(e, st);
          }
        }
      }

      unawaited(emit());
      final sub = tableUpdates(TableUpdateQuery.onTable(localPets))
          .listen((_) => unawaited(emit()));
      controller.onCancel = () {
        active = false;
        return sub.cancel();
      };
    }, isBroadcast: true);
  }

  Future<List<LocalPet>> getPets(String homeId) {
    return (select(localPets)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Stream<List<LocalPetTag>> watchPetTags(String homeId) {
    if (_isClosed || homeId.isEmpty) {
      return const Stream<List<LocalPetTag>>.empty();
    }
    return Stream<List<LocalPetTag>>.multi((controller) {
      var active = true;
      Future<void> emit() async {
        if (!active || _isClosed || controller.isClosed) return;
        try {
          final rows = await getPetTags(homeId);
          if (active && !_isClosed && !controller.isClosed) {
            controller.add(rows);
          }
        } catch (e, st) {
          if (active && !_isClosed && !controller.isClosed) {
            controller.addError(e, st);
          }
        }
      }

      unawaited(emit());
      final sub = tableUpdates(TableUpdateQuery.onTable(localPetTags))
          .listen((_) => unawaited(emit()));
      controller.onCancel = () {
        active = false;
        return sub.cancel();
      };
    }, isBroadcast: true);
  }

  Future<List<LocalPetTag>> getPetTags(String homeId) {
    return (select(localPetTags)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Stream<List<LocalPetTag>> watchPetTagsForRecord(
    String recordKind,
    String recordId,
  ) {
    if (_isClosed || recordKind.isEmpty || recordId.isEmpty) {
      return const Stream<List<LocalPetTag>>.empty();
    }
    return Stream<List<LocalPetTag>>.multi((controller) {
      var active = true;
      Future<void> emit() async {
        if (!active || _isClosed || controller.isClosed) return;
        try {
          final rows = await getPetTagsForRecord(recordKind, recordId);
          if (active && !_isClosed && !controller.isClosed) {
            controller.add(rows);
          }
        } catch (e, st) {
          if (active && !_isClosed && !controller.isClosed) {
            controller.addError(e, st);
          }
        }
      }

      unawaited(emit());
      final sub = tableUpdates(TableUpdateQuery.onTable(localPetTags))
          .listen((_) => unawaited(emit()));
      controller.onCancel = () {
        active = false;
        return sub.cancel();
      };
    }, isBroadcast: true);
  }

  Future<List<LocalPetTag>> getPetTagsForRecord(
    String recordKind,
    String recordId,
  ) {
    return (select(localPetTags)
          ..where((t) =>
              t.recordKind.equals(recordKind) & t.recordId.equals(recordId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<int> deletePetTagsForRecord(String recordKind, String recordId) {
    return (delete(localPetTags)
          ..where((t) =>
              t.recordKind.equals(recordKind) & t.recordId.equals(recordId)))
        .go();
  }

  // --- REACTION STREAMS FILTERED BY homeId ---

  Stream<List<LocalCheckinReminder>> watchCheckinReminders(String homeId) {
    return (select(localCheckinReminders)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.hour),
            (t) => OrderingTerm.asc(t.minute),
          ]))
        .watch();
  }

  Future<List<LocalCheckinReminder>> getCheckinReminders(String homeId) {
    return (select(localCheckinReminders)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.hour),
            (t) => OrderingTerm.asc(t.minute),
          ]))
        .get();
  }

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
      if (await isTombstoned(id) || await isTombstoned('default_name_${name.toLowerCase()}_$homeId')) {
        continue;
      }

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

  Future<void> deleteExpense(String expenseId) async {
    await deletePetTagsForRecord('expense', expenseId);
    await (delete(localExpenses)..where((t) => t.id.equals(expenseId))).go();
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
    await deletePetTagsForRecord('habit', habitId);
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

  Future<void> deleteCalendarEvent(String eventId) async {
    await deletePetTagsForRecord('event', eventId);
    await (delete(localCalendarEvents)..where((t) => t.id.equals(eventId))).go();
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
            t.eventType.isNotIn(const [
              'member_profile_updated',
              'profile_updated',
              'user_profile_updated',
              'avatar_updated',
              'avatar_changed',
              'name_updated',
              'display_name_updated',
              'home_currency_updated',
              'home_updated',
              'preferences_updated',
              'settings_updated',
              'pet_created',
              'pet_renamed',
              'pet_archived',
              'pet_tag_added',
              'pet_tag_removed',
            ]);
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
            t.eventType.isNotIn(const [
              'member_profile_updated',
              'profile_updated',
              'user_profile_updated',
              'avatar_updated',
              'avatar_changed',
              'name_updated',
              'display_name_updated',
              'home_currency_updated',
              'home_updated',
              'preferences_updated',
              'settings_updated',
              'pet_created',
              'pet_renamed',
              'pet_archived',
              'pet_tag_added',
              'pet_tag_removed',
            ]);
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
          ..where((t) => t.eventType.isIn(const [
                'member_profile_updated',
                'profile_updated',
                'user_profile_updated',
                'avatar_updated',
                'avatar_changed',
                'name_updated',
                'display_name_updated',
                'home_currency_updated',
                'home_updated',
                'preferences_updated',
                'settings_updated',
                'pet_created',
                'pet_renamed',
                'pet_archived',
                'pet_tag_added',
                'pet_tag_removed',
              ])))
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

  Stream<List<LocalRoutineEvent>> watchAllRoutineEvents(String homeId) {
    return (select(localRoutineEvents)
          ..where((t) => t.homeId.equals(homeId))
          ..orderBy([(t) => OrderingTerm.asc(t.startMinutes)]))
        .watch();
  }

  Future<List<LocalRoutineEvent>> getRoutineEvents(String routineId) {
    return (select(localRoutineEvents)
          ..where((t) => t.routineId.equals(routineId))
          ..orderBy([(t) => OrderingTerm.asc(t.startMinutes)]))
        .get();
  }

  // --- IDEMPOTENT SYNC LEDGER & DELETION TOMBSTONES ---

  Future<void> recordAppliedEvent(String eventId) async {
    await into(localAppliedEvents).insertOnConflictUpdate(
      LocalAppliedEventsCompanion.insert(
        id: eventId,
        appliedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<bool> hasAppliedEvent(String eventId) async {
    final row = await (select(localAppliedEvents)
          ..where((t) => t.id.equals(eventId)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> recordTombstone(String entityId, String entityType) async {
    await into(localDeletedTombstones).insertOnConflictUpdate(
      LocalDeletedTombstonesCompanion.insert(
        id: entityId,
        entityType: entityType,
        deletedAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<bool> isTombstoned(String entityId) async {
    final row = await (select(localDeletedTombstones)
          ..where((t) => t.id.equals(entityId)))
        .getSingleOrNull();
    return row != null;
  }

  // --- FIRST-RUN RECORD COUNTS (`design/specs/16-first-run.md` §3) ---

  Future<FirstRunCounts> getFirstRunCounts(String homeId) async {
    if (_isClosed || homeId.isEmpty) return FirstRunCounts.empty;
    final row = await customSelect(
      '''
      SELECT
        (SELECT COUNT(*) FROM local_expenses WHERE home_id = ?1) AS expenses_count,
        (SELECT COUNT(*) FROM local_calendar_events WHERE home_id = ?1) AS events_count,
        (SELECT COUNT(*) FROM local_habits WHERE home_id = ?1 AND is_archived = 0) AS habits_count,
        (SELECT COUNT(*) FROM local_habit_checkins WHERE home_id = ?1) AS checkins_count,
        (SELECT COUNT(*) FROM local_list_items WHERE home_id = ?1) AS list_items_count,
        (SELECT COUNT(*) FROM local_subscriptions WHERE home_id = ?1) AS commitments_count,
        (SELECT COUNT(*) FROM local_routine_events WHERE home_id = ?1) AS routine_events_count,
        (SELECT COUNT(*) FROM local_activity_events WHERE home_id = ?1 AND event_type NOT IN (
          'member_profile_updated',
          'profile_updated',
          'user_profile_updated',
          'avatar_updated',
          'avatar_changed',
          'name_updated',
          'display_name_updated',
          'home_currency_updated',
          'home_updated',
          'preferences_updated',
          'settings_updated',
          'pet_created',
          'pet_renamed',
          'pet_archived',
          'pet_tag_added',
          'pet_tag_removed'
        )) AS activity_count,
        (
          SELECT CASE WHEN (
            EXISTS(
              SELECT 1 FROM local_activity_events a
              LEFT JOIN local_homes h ON h.id = a.home_id
              WHERE a.home_id = ?1 AND (
                a.event_type IN ('member_profile_updated', 'partner_joined', 'member_joined')
                OR (h.created_by IS NOT NULL AND a.actor_id != '' AND a.actor_id != h.created_by)
              )
            )
            OR EXISTS(
              SELECT 1 FROM local_outbox_events o
              LEFT JOIN local_homes h ON h.id = o.home_id
              WHERE o.home_id = ?1 AND (
                o.event_type IN ('member_profile_updated', 'partner_joined', 'member_joined')
                OR o.sync_status = 'syncedToPartner'
                OR (h.created_by IS NOT NULL AND o.actor_id != '' AND o.actor_id != h.created_by)
              )
            )
          ) THEN 1 ELSE 0 END
        ) AS has_partner_in_db
      ''',
      variables: [
        Variable.withString(homeId),
      ],
      readsFrom: {
        localHomes,
        localExpenses,
        localCalendarEvents,
        localHabits,
        localHabitCheckins,
        localListItems,
        localSubscriptions,
        localRoutineEvents,
        localActivityEvents,
        localOutboxEvents,
      },
    ).getSingle();

    return FirstRunCounts(
      expenses: row.read<int>('expenses_count'),
      events: row.read<int>('events_count'),
      habits: row.read<int>('habits_count'),
      habitCheckins: row.read<int>('checkins_count'),
      listItems: row.read<int>('list_items_count'),
      commitments: row.read<int>('commitments_count'),
      routineEvents: row.read<int>('routine_events_count'),
      activity: row.read<int>('activity_count'),
      hasPartnerInDb: row.read<int>('has_partner_in_db') != 0,
    );
  }

  Stream<FirstRunCounts> watchFirstRunCounts(String homeId) {
    if (_isClosed || homeId.isEmpty) {
      return const Stream<FirstRunCounts>.empty();
    }
    return Stream<FirstRunCounts>.multi((controller) {
      var active = true;
      Future<void> emit() async {
        if (!active || _isClosed || controller.isClosed) return;
        try {
          final counts = await getFirstRunCounts(homeId);
          if (active && !_isClosed && !controller.isClosed) {
            controller.add(counts);
          }
        } catch (e, st) {
          if (active && !_isClosed && !controller.isClosed) {
            controller.addError(e, st);
          }
        }
      }

      unawaited(emit());
      final sub = tableUpdates().listen((_) => unawaited(emit()));
      controller.onCancel = () {
        active = false;
        return sub.cancel();
      };
    }, isBroadcast: true);
  }
}

/// A [QueryExecutor] decorator that enforces strictly read-only SQLite access.
///
/// Used by [AppDatabase.readOnly] in the background notification isolate and in
/// pipeline tests to guarantee zero writes to the database or outbox.
class ReadOnlyQueryExecutor extends QueryExecutor {
  final QueryExecutor _inner;
  final bool suppressMigrations;
  int writeAttempts = 0;
  int selectCount = 0;

  ReadOnlyQueryExecutor(
    this._inner, {
    this.suppressMigrations = true,
  });

  QueryExecutor get inner => _inner;

  @override
  SqlDialect get dialect => _inner.dialect;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async {
    final effectiveUser = suppressMigrations
        ? _NoMigrationExecutorUser(user.schemaVersion)
        : user;
    return _inner.ensureOpen(effectiveUser);
  }

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) {
    selectCount += 1;
    return _inner.runSelect(statement, args);
  }

  @override
  Future<int> runInsert(String statement, List<Object?> args) {
    writeAttempts += 1;
    throw StateError(
      'ReadOnlyQueryExecutor: INSERT is forbidden in the read-only notification pipeline.',
    );
  }

  @override
  Future<int> runUpdate(String statement, List<Object?> args) {
    writeAttempts += 1;
    throw StateError(
      'ReadOnlyQueryExecutor: UPDATE is forbidden in the read-only notification pipeline.',
    );
  }

  @override
  Future<int> runDelete(String statement, List<Object?> args) {
    writeAttempts += 1;
    throw StateError(
      'ReadOnlyQueryExecutor: DELETE is forbidden in the read-only notification pipeline.',
    );
  }

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) {
    writeAttempts += 1;
    throw StateError(
      'ReadOnlyQueryExecutor: custom SQL ($statement) is forbidden in the read-only notification pipeline.',
    );
  }

  @override
  Future<void> runBatched(BatchedStatements statements) {
    writeAttempts += 1;
    throw StateError(
      'ReadOnlyQueryExecutor: batched writes are forbidden in the read-only notification pipeline.',
    );
  }

  @override
  TransactionExecutor beginTransaction() {
    writeAttempts += 1;
    throw StateError(
      'ReadOnlyQueryExecutor: transactions are forbidden in the read-only notification pipeline.',
    );
  }

  @override
  QueryExecutor beginExclusive() => this;

  @override
  Future<void> close() => _inner.close();
}

class _NoMigrationExecutorUser extends QueryExecutorUser {
  @override
  final int schemaVersion;

  _NoMigrationExecutorUser(this.schemaVersion);

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}


