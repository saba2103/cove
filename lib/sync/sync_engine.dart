import 'event_store.dart';
import 'local_state_store.dart';
import 'encryption_service.dart';

enum SyncConnectionState {
  disconnected,
  connecting,
  connected,
  syncing,
  error,
}

/// Core synchronization coordinator managing local event queuing,
/// encryption/decryption, and blind relay transmission via Supabase Realtime.
abstract class SyncEngine {
  EventStore get eventStore;
  LocalStateStore get localStateStore;
  EncryptionService get encryptionService;

  /// Current network/relay connection state.
  Stream<SyncConnectionState> get connectionState;

  /// Starts listening to the Supabase blind relay for incoming partner events
  /// and begins draining local pending event queues.
  Future<void> start({required String homeId, required List<int> homeKey});

  /// Dispatches a local mutation event:
  /// 1. Updates local SQLite projections immediately for zero-latency UI.
  /// 2. Encrypts the event payload using libsodium and the shared home key.
  /// 3. Appends the encrypted event to the local EventStore (Status: savedLocally).
  /// 4. Attempts push to Supabase relay; updates status to syncedToPartner on ack.
  Future<void> dispatchLocalEvent({
    required String eventType,
    required Map<String, dynamic> payload,
  });

  /// Stops sync loops and closes active relay subscriptions.
  Future<void> stop();
}
