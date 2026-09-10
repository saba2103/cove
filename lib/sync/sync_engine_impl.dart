import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'crypto/sodium_crypto_service.dart';
import 'encryption_service.dart';
import 'event_store.dart';
import 'key_management/home_key_store.dart';
import 'local_state_store.dart';
import 'sync_engine.dart';

class SyncEngineImpl implements SyncEngine {
  @override
  final EventStore eventStore;

  @override
  final LocalStateStore localStateStore;

  @override
  final SodiumCryptoService encryptionService;

  final HomeKeyStore keyStore;
  final SupabaseClient? supabaseClient;
  final String Function()? getCurrentUserId;
  final String? Function()? getActiveHomeId;

  final StreamController<SyncConnectionState> _connectionStateController =
      StreamController<SyncConnectionState>.broadcast();

  SyncConnectionState _currentState = SyncConnectionState.disconnected;

  SyncConnectionState get currentState => _currentState;
  RealtimeChannel? _realtimeChannel;
  Timer? _outboxFlushTimer;
  bool _isFlushing = false;
  int _consecutiveFailures = 0;

  SyncEngineImpl({
    required this.eventStore,
    required this.localStateStore,
    SodiumCryptoService? encryptionService,
    HomeKeyStore? keyStore,
    this.supabaseClient,
    this.getCurrentUserId,
    this.getActiveHomeId,
  })  : encryptionService = encryptionService ?? SodiumCryptoService(),
        keyStore = keyStore ?? HomeKeyStore();

  @override
  Stream<SyncConnectionState> get connectionState =>
      _connectionStateController.stream;

  String get currentUserId =>
      getCurrentUserId?.call() ??
      supabaseClient?.auth.currentUser?.id ??
      'local_user';

  @override
  Future<void> start({String? activeHomeId, List<int>? activeHomeKey}) async {
    _updateConnectionState(SyncConnectionState.connecting);

    if (activeHomeId != null && activeHomeKey != null) {
      await keyStore.saveKey(activeHomeId, Uint8List.fromList(activeHomeKey));
    }

    await localStateStore.initialize();

    // Setup Supabase Realtime subscriptions if client is available
    if (supabaseClient != null) {
      try {
        _subscribeToRealtime();
      } catch (e) {
        _updateConnectionState(SyncConnectionState.error);
      }
    }

    _updateConnectionState(SyncConnectionState.connected);

    // Start periodic outbox drain
    _startOutboxTimer();

    // Trigger immediate outbox flush
    unawaited(flushOutbox());
  }

  void _subscribeToRealtime() {
    _realtimeChannel = supabaseClient!
        .channel('cove_sync_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'home_events',
          callback: (payload) => _handleInboundEvent(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_deliveries',
          callback: (payload) => _handleInboundDelivery(payload.newRecord),
        )
        .subscribe();
  }

  /// Processes an incoming event row pushed from Supabase Realtime.
  Future<void> _handleInboundEvent(Map<String, dynamic> record) async {
    final homeId = record['home_id'] as String;
    final actorId = record['actor_id'] as String;
    final eventId = record['id'] as String;
    final eventType = record['event_type'] as String;
    final rawCiphertext = record['encrypted_payload'] as String;
    final createdAt = DateTime.tryParse(record['created_at'] as String) ??
        DateTime.now().toUtc();

    // If actor is self, the event is already stored and projected locally
    if (actorId == currentUserId) {
      return;
    }

    // Retrieve symmetric key for the event's home
    final homeKey = await keyStore.getKey(homeId);
    if (homeKey == null) {
      // Key for this home not available on this device; cannot decrypt
      return;
    }

    try {
      final encryptedPayload =
          encryptionService.deserializeFromTransportString(rawCiphertext);
      final plaintextJson = await encryptionService.decrypt(
        payload: encryptedPayload,
        homeKey: homeKey,
      );
      final payloadMap = jsonDecode(plaintextJson) as Map<String, dynamic>;

      // Apply to local Drift SQLite projections
      await localStateStore.applyEvent(
        homeId: homeId,
        eventType: eventType,
        payload: payloadMap,
        timestamp: createdAt,
        authorId: actorId,
      );

      // Confirm receipt by writing an event_deliveries acknowledgment row
      if (supabaseClient != null) {
        await supabaseClient!.from('event_deliveries').insert({
          'event_id': eventId,
          'member_id': currentUserId,
          'delivered_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    } catch (_) {
      // Malformed or failed decryption; drop gracefully
    }
  }

  /// Processes an acknowledgment row pushed from Supabase Realtime.
  /// When a partner's device acknowledges receipt of our event, this flips
  /// our local status from 1-tick (savedLocally) to 2-ticks (syncedToPartner).
  Future<void> _handleInboundDelivery(Map<String, dynamic> record) async {
    final eventId = record['event_id'] as String;
    final memberId = record['member_id'] as String;

    // A partner (not ourselves) has confirmed receipt of an event
    if (memberId != currentUserId) {
      await eventStore.markEventSynced(eventId);
    }
  }

  @override
  Future<void> dispatchLocalEvent({
    required String eventType,
    required Map<String, dynamic> payload,
    String? homeId,
  }) async {
    final targetHomeId = homeId ?? getActiveHomeId?.call();
    if (targetHomeId == null || targetHomeId.isEmpty) {
      throw StateError('Cannot dispatch event: No active home selected.');
    }

    final homeKey = await keyStore.getKey(targetHomeId);
    if (homeKey == null) {
      throw StateError(
          'Cannot dispatch event: No symmetric key found for home $targetHomeId.');
    }

    final now = DateTime.now().toUtc();
    final eventId = _generateUuid();
    final actorId = currentUserId;

    // 1. Zero-latency local update: Apply to Drift projections immediately
    await localStateStore.applyEvent(
      homeId: targetHomeId,
      eventType: eventType,
      payload: payload,
      timestamp: now,
      authorId: actorId,
    );

    // 2. Client-side authenticated encryption (AEAD SecretBox)
    final plaintextJson = jsonEncode(payload);
    final encrypted = await encryptionService.encrypt(
      plaintextJson: plaintextJson,
      homeKey: homeKey,
    );

    // 3. Append to local outbox (initial status: savedLocally / 1 tick)
    final event = CoveEncryptedEvent(
      id: eventId,
      homeId: targetHomeId,
      eventType: eventType,
      authorId: actorId,
      createdAt: now,
      ciphertext: encrypted.ciphertext,
      nonce: encrypted.nonce,
      syncStatus: EventSyncStatus.savedLocally,
    );

    await eventStore.appendEvent(
      event,
      payloadJson: plaintextJson,
    );

    // 4. Attempt immediate push to Supabase relay
    unawaited(flushOutbox());
  }

  /// Drains pending outbox events to the Supabase blind relay.
  Future<void> flushOutbox() async {
    if (_isFlushing || supabaseClient == null) return;
    _isFlushing = true;

    try {
      final pendingEvents = await eventStore.getPendingUploadEvents(limit: 25);
      if (pendingEvents.isEmpty) {
        _consecutiveFailures = 0;
        return;
      }

      for (final event in pendingEvents) {
        final transportPayload =
            encryptionService.serializeToTransportString(EncryptedPayload(
          ciphertext: event.ciphertext,
          nonce: event.nonce,
        ));

        // Insert into Supabase home_events
        await supabaseClient!.from('home_events').upsert({
          'id': event.id,
          'home_id': event.homeId,
          'actor_id': event.authorId,
          'event_type': event.eventType,
          'encrypted_payload': transportPayload,
          'created_at': event.createdAt.toIso8601String(),
        });

        // Check if partner already marked delivery for this event
        final existingDeliveries = await supabaseClient!
            .from('event_deliveries')
            .select('member_id')
            .eq('event_id', event.id)
            .neq('member_id', currentUserId);

        if ((existingDeliveries as List).isNotEmpty) {
          await eventStore.markEventSynced(event.id);
        }
      }

      _consecutiveFailures = 0;
    } catch (_) {
      _consecutiveFailures++;
    } finally {
      _isFlushing = false;
    }
  }

  void _startOutboxTimer() {
    _outboxFlushTimer?.cancel();
    // Exponential backoff: 3s up to 30s
    final delaySeconds = _consecutiveFailures == 0
        ? 3
        : (_consecutiveFailures * 3).clamp(3, 30);

    _outboxFlushTimer = Timer(Duration(seconds: delaySeconds), () {
      flushOutbox().whenComplete(_startOutboxTimer);
    });
  }

  void _updateConnectionState(SyncConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = (random.hashCode & 0x7FFFFFFF).toRadixString(16).padLeft(8, '0');
    final p1 = (DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    return '$p1-$hash-4000-8000-${DateTime.now().microsecond.toRadixString(16).padLeft(12, '0')}';
  }

  @override
  Future<void> stop() async {
    _outboxFlushTimer?.cancel();
    await _realtimeChannel?.unsubscribe();
    _updateConnectionState(SyncConnectionState.disconnected);
  }
}
