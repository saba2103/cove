import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/uuid_generator.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';

/// Canonical `record_kind` values stored in `local_pet_tags`
/// (`design/specs/19-owners-and-pets.md` §2).
abstract final class PetRecordKind {
  static const String expense = 'expense';
  static const String event = 'event';
  static const String task = 'task';
  static const String habit = 'habit';
  static const String commitment = 'commitment';
  static const String routineEvent = 'routine_event';
}

/// Streams all pets (active and archived) for the active home.
final activeHomePetsProvider = StreamProvider<List<LocalPet>>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null || activeId.isEmpty) {
    return Stream.value(const <LocalPet>[]);
  }
  final db = ref.watch(appDatabaseProvider);
  try {
    return db.watchPets(activeId);
  } catch (_) {
    return Stream.value(const <LocalPet>[]);
  }
});

/// Non-archived pets for the active home (`isArchived == false`).
final activeHomeActivePetsProvider = Provider<List<LocalPet>>((ref) {
  final pets = ref.watch(activeHomePetsProvider).value ?? const <LocalPet>[];
  return pets.where((p) => !p.isArchived).toList(growable: false);
});

/// Streams all pet tags for the active home.
final activeHomePetTagsProvider = StreamProvider<List<LocalPetTag>>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null || activeId.isEmpty) {
    return Stream.value(const <LocalPetTag>[]);
  }
  final db = ref.watch(appDatabaseProvider);
  try {
    return db.watchPetTags(activeId);
  } catch (_) {
    return Stream.value(const <LocalPetTag>[]);
  }
});

/// Key identifying a specific record for pet-tag lookups.
typedef PetRecordKey = ({String recordKind, String recordId});

/// Resolves the ordered list of [LocalPet]s (including archived pets, which
/// stay on old records greyed out per `design/specs/19-owners-and-pets.md` §3)
/// tagged on a given `(recordKind, recordId)`.
final recordPetTagsProvider =
    Provider.family<List<LocalPet>, PetRecordKey>((ref, key) {
  final allPets = ref.watch(activeHomePetsProvider).value ?? const <LocalPet>[];
  if (allPets.isEmpty) return const <LocalPet>[];
  final allTags =
      ref.watch(activeHomePetTagsProvider).value ?? const <LocalPetTag>[];
  if (allTags.isEmpty) return const <LocalPet>[];

  final taggedPetIds = <String>{
    for (final t in allTags)
      if (t.recordKind == key.recordKind && t.recordId == key.recordId) t.petId,
  };
  if (taggedPetIds.isEmpty) return const <LocalPet>[];

  return allPets
      .where((pet) => taggedPetIds.contains(pet.id))
      .toList(growable: false);
});

final petControllerProvider = Provider<PetController>((ref) {
  return PetController(ref);
});

/// Controller for managing household pets and record pet tags
/// (`design/specs/19-owners-and-pets.md` §2–§3).
class PetController {
  final Ref ref;

  PetController(this.ref);

  AppDatabase get _db => ref.read(appDatabaseProvider);
  String? get _activeHomeId => ref.read(activeHomeIdProvider);
  CoveUser? get _currentUser => ref.read(authProvider).value;

  String _generateUuid() => generateCoveUuid();

  /// Creates a new pet in the active home and emits `pet_created`.
  Future<String> createPet(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Pet name cannot be empty.');
    }
    final homeId = _activeHomeId;
    if (homeId == null || homeId.isEmpty) {
      throw StateError('No active home selected.');
    }

    final userId = _currentUser?.id ?? 'local_user';
    final now = clock.now().toUtc();
    final id = _generateUuid();

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'pet_created',
      payload: <String, dynamic>{
        'id': id,
        'home_id': homeId,
        'name': trimmed,
        'created_by': userId,
        'created_at': now.toIso8601String(),
        'is_archived': false,
      },
    );
    return id;
  }

  /// Renames an existing pet and emits `pet_renamed`.
  Future<void> renamePet(String petId, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final homeId = _activeHomeId;
    if (homeId == null || homeId.isEmpty) {
      throw StateError('No active home selected.');
    }

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'pet_renamed',
      payload: <String, dynamic>{
        'id': petId,
        'home_id': homeId,
        'name': trimmed,
      },
    );
  }

  /// Archives (or unarchives) a pet and emits `pet_archived`.
  /// Archived pets stay on old records, greyed out.
  Future<void> archivePet(String petId, {bool isArchived = true}) async {
    final homeId = _activeHomeId;
    if (homeId == null || homeId.isEmpty) {
      throw StateError('No active home selected.');
    }

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'pet_archived',
      payload: <String, dynamic>{
        'id': petId,
        'home_id': homeId,
        'is_archived': isArchived,
      },
    );
  }

  /// Adds a pet tag to `(recordKind, recordId)`.
  ///
  /// CRITICAL PRIVACY RULE (`design/specs/19-owners-and-pets.md` §2):
  /// A tag on a private record is itself private (never synced), exactly like
  /// the record. When [isPrivate] is `true`, this writes directly to local
  /// SQLite (`insertPetTagIfAbsent`) and emits **zero** sync events.
  Future<void> addPetTag({
    required String petId,
    required String recordKind,
    required String recordId,
    bool isPrivate = false,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null || homeId.isEmpty) {
      throw StateError('No active home selected.');
    }

    final existing = await (_db.select(_db.localPetTags)
          ..where((t) =>
              t.petId.equals(petId) &
              t.recordKind.equals(recordKind) &
              t.recordId.equals(recordId)))
        .getSingleOrNull();
    if (existing != null) return;

    final now = clock.now().toUtc();
    final id = _generateUuid();

    if (isPrivate) {
      await _db.insertPetTagIfAbsent(
        LocalPetTagsCompanion.insert(
          id: id,
          homeId: homeId,
          petId: petId,
          recordKind: recordKind,
          recordId: recordId,
          createdAt: now,
        ),
      );
      return;
    }

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'pet_tag_added',
      payload: <String, dynamic>{
        'id': id,
        'home_id': homeId,
        'pet_id': petId,
        'record_kind': recordKind,
        'record_id': recordId,
        'created_at': now.toIso8601String(),
      },
    );
  }

  /// Removes a pet tag from `(recordKind, recordId)`.
  ///
  /// When [isPrivate] is `true`, deletes directly from local SQLite without
  /// emitting any sync event.
  Future<void> removePetTag({
    required String petId,
    required String recordKind,
    required String recordId,
    bool isPrivate = false,
  }) async {
    final homeId = _activeHomeId;
    if (homeId == null || homeId.isEmpty) {
      throw StateError('No active home selected.');
    }

    final existing = await (_db.select(_db.localPetTags)
          ..where((t) =>
              t.petId.equals(petId) &
              t.recordKind.equals(recordKind) &
              t.recordId.equals(recordId)))
        .getSingleOrNull();
    if (existing == null) return;

    if (isPrivate) {
      await (_db.delete(_db.localPetTags)
            ..where((t) =>
                t.petId.equals(petId) &
                t.recordKind.equals(recordKind) &
                t.recordId.equals(recordId)))
          .go();
      return;
    }

    final emit = ref.read(coveEmitActionProvider);
    await emit(
      eventType: 'pet_tag_removed',
      payload: <String, dynamic>{
        'id': existing.id,
        'home_id': homeId,
        'pet_id': petId,
        'record_kind': recordKind,
        'record_id': recordId,
      },
    );
  }

  /// Synchronizes the exact set of [petIds] tagged on `(recordKind, recordId)`,
  /// adding newly selected pets and removing unselected ones while respecting
  /// [isPrivate].
  Future<void> setRecordPetTags({
    required String recordKind,
    required String recordId,
    required Set<String> petIds,
    bool isPrivate = false,
  }) async {
    final existingTags =
        await _db.getPetTagsForRecord(recordKind, recordId);
    final existingPetIds = existingTags.map((t) => t.petId).toSet();

    for (final petId in petIds) {
      if (!existingPetIds.contains(petId)) {
        await addPetTag(
          petId: petId,
          recordKind: recordKind,
          recordId: recordId,
          isPrivate: isPrivate,
        );
      }
    }

    for (final existingPetId in existingPetIds) {
      if (!petIds.contains(existingPetId)) {
        await removePetTag(
          petId: existingPetId,
          recordKind: recordKind,
          recordId: recordId,
          isPrivate: isPrivate,
        );
      }
    }
  }
}
