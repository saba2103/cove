import 'dart:async';
import 'package:drift/drift.dart';
import 'crypto/sodium_crypto_service.dart';
import 'db/app_database.dart';
import 'encryption_service.dart';
import 'event_store.dart';

class EventStoreImpl implements EventStore {
  final AppDatabase db;
  final SodiumCryptoService cryptoService;

  EventStoreImpl({
    required this.db,
    SodiumCryptoService? cryptoService,
  }) : cryptoService = cryptoService ?? SodiumCryptoService();

  @override
  Future<void> appendEvent(
    CoveEncryptedEvent event, {
    String payloadJson = '{}',
  }) async {
    final transportPayload = cryptoService.serializeToTransportString(
      EncryptedPayload(
        ciphertext: event.ciphertext,
        nonce: event.nonce,
      ),
    );

    await db.into(db.localOutboxEvents).insertOnConflictUpdate(
          LocalOutboxEventsCompanion.insert(
            id: event.id,
            homeId: event.homeId,
            actorId: event.authorId,
            eventType: event.eventType,
            payloadJson: payloadJson,
            encryptedPayload: transportPayload,
            createdAt: event.createdAt,
            syncStatus: Value(event.syncStatus == EventSyncStatus.syncedToPartner
                ? 'syncedToPartner'
                : (event.syncStatus == EventSyncStatus.uploadedToCloud
                    ? 'uploadedToCloud'
                    : 'savedLocally')),
            retryCount: const Value(0),
            lastAttemptAt: const Value(null),
          ),
        );
  }

  @override
  Future<bool> hasEvent(String eventId) async {
    final row = await (db.select(db.localOutboxEvents)
          ..where((t) => t.id.equals(eventId)))
        .getSingleOrNull();
    return row != null;
  }

  @override
  Future<List<CoveEncryptedEvent>> getPendingUploadEvents(
      {int limit = 50}) async {
    final rows = await (db.select(db.localOutboxEvents)
          ..where((t) => t.syncStatus.equals('savedLocally'))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
          ..limit(limit))
        .get();

    return rows.map(_mapRowToEvent).toList();
  }

  @override
  Future<void> markEventUploaded(String eventId) async {
    await (db.update(db.localOutboxEvents)..where((t) => t.id.equals(eventId)))
        .write(
      const LocalOutboxEventsCompanion(
        syncStatus: Value('uploadedToCloud'),
      ),
    );
    await db.updateActivityEventSyncStatus(eventId, 'uploadedToCloud');
  }

  @override
  Future<void> markEventSynced(String eventId) async {
    await (db.update(db.localOutboxEvents)..where((t) => t.id.equals(eventId)))
        .write(
      const LocalOutboxEventsCompanion(
        syncStatus: Value('syncedToPartner'),
      ),
    );
    await db.updateActivityEventSyncStatus(eventId, 'syncedToPartner');
  }

  @override
  Future<List<CoveEncryptedEvent>> getEventsForHome(
    String homeId, {
    int? afterSequence,
    int limit = 100,
  }) async {
    final query = db.select(db.localOutboxEvents)
      ..where((t) => t.homeId.equals(homeId))
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
      ..limit(limit);

    final rows = await query.get();
    return rows.map(_mapRowToEvent).toList();
  }

  @override
  Stream<CoveEncryptedEvent> watchEvents({String? homeId}) {
    final query = db.select(db.localOutboxEvents);
    if (homeId != null) {
      query.where((t) => t.homeId.equals(homeId));
    }
    query.orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    return query.watch().expand((rows) => rows.map(_mapRowToEvent));
  }

  CoveEncryptedEvent _mapRowToEvent(LocalOutboxEvent row) {
    final payload =
        cryptoService.deserializeFromTransportString(row.encryptedPayload);

    return CoveEncryptedEvent(
      id: row.id,
      homeId: row.homeId,
      eventType: row.eventType,
      authorId: row.actorId,
      createdAt: row.createdAt,
      ciphertext: payload.ciphertext,
      nonce: payload.nonce,
      syncStatus: row.syncStatus == 'syncedToPartner'
          ? EventSyncStatus.syncedToPartner
          : (row.syncStatus == 'uploadedToCloud'
              ? EventSyncStatus.uploadedToCloud
              : EventSyncStatus.savedLocally),
    );
  }
}
