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
  /// across all homes the user belongs to, and begins draining the outbox.
  Future<void> start({String? activeHomeId, List<int>? activeHomeKey});

  /// Dispatches a local mutation event:
  /// 1. Updates local SQLite projections immediately for zero-latency UI.
  /// 2. Encrypts the event payload using libsodium and the shared home key.
  /// 3. Appends the encrypted event to the local EventStore (Status: savedLocally).
  /// 4. Attempts push to Supabase relay; updates status to syncedToPartner on ack.
  Future<void> dispatchLocalEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    String? homeId,
  });

  /// Stops sync loops and closes active relay subscriptions.
  Future<void> stop();
}
