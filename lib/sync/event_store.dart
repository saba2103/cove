import 'dart:typed_data';

enum EventSyncStatus {
  savedLocally,
  uploadedToCloud,
  syncedToPartner,
}

class CoveEncryptedEvent {
  final String id;
  final String homeId;
  final String eventType;
  final String authorId;
  final DateTime createdAt;
  final Uint8List ciphertext;
  final Uint8List nonce;
  final int? sequenceNumber;
  final EventSyncStatus syncStatus;

  const CoveEncryptedEvent({
    required this.id,
    required this.homeId,
    required this.eventType,
    required this.authorId,
    required this.createdAt,
    required this.ciphertext,
    required this.nonce,
    this.sequenceNumber,
    this.syncStatus = EventSyncStatus.savedLocally,
  });

  CoveEncryptedEvent copyWith({
    String? id,
    String? homeId,
    String? eventType,
    String? authorId,
    DateTime? createdAt,
    Uint8List? ciphertext,
    Uint8List? nonce,
    int? sequenceNumber,
    EventSyncStatus? syncStatus,
  }) {
    return CoveEncryptedEvent(
      id: id ?? this.id,
      homeId: homeId ?? this.homeId,
      eventType: eventType ?? this.eventType,
      authorId: authorId ?? this.authorId,
      createdAt: createdAt ?? this.createdAt,
      ciphertext: ciphertext ?? this.ciphertext,
      nonce: nonce ?? this.nonce,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

/// Abstract contract for storing and queuing encrypted event streams locally.
abstract class EventStore {
  /// Appends an encrypted event to the local append-only log.
  Future<void> appendEvent(CoveEncryptedEvent event, {String payloadJson = '{}'});

  /// Checks if an event is already stored in the local outbox.
  Future<bool> hasEvent(String eventId);

  /// Retrieves events pending upload to the Supabase blind relay.
  Future<List<CoveEncryptedEvent>> getPendingUploadEvents({int limit = 50});

  /// Marks an event as uploaded to the Supabase blind relay.
  Future<void> markEventUploaded(String eventId);

  /// Marks an event as synced after acknowledgment from the partner or relay.
  Future<void> markEventSynced(String eventId);

  /// Retrieves all encrypted events for a home, optionally since a given sequence.
  Future<List<CoveEncryptedEvent>> getEventsForHome(
    String homeId, {
    int? afterSequence,
    int limit = 100,
  });

  /// Real-time stream of incoming events added to the store.
  Stream<CoveEncryptedEvent> watchEvents({String? homeId});
}
