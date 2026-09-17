import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/uuid_generator.dart';
import '../features/notifications/notification_models.dart';
import '../features/profile/partner_profile_controller.dart';
import '../features/profile/user_profile_controller.dart';
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

  /// Optional callback invoked when partner activity is received and decrypted
  void Function(CoveNotificationPayload payload)? onInboundActivityReceived;

  final StreamController<SyncConnectionState> _connectionStateController =
      StreamController<SyncConnectionState>.broadcast();

  SyncConnectionState _currentState = SyncConnectionState.disconnected;

  SyncConnectionState get currentState => _currentState;
  RealtimeChannel? _realtimeChannel;
  Timer? _outboxFlushTimer;
  Timer? _foregroundPollTimer;
  bool _isFlushing = false;
  int _consecutiveFailures = 0;
  final Set<String> _processedEventIds = <String>{};

  SyncEngineImpl({
    required this.eventStore,
    required this.localStateStore,
    SodiumCryptoService? encryptionService,
    HomeKeyStore? keyStore,
    this.supabaseClient,
    this.getCurrentUserId,
    this.getActiveHomeId,
    this.onInboundActivityReceived,
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
        _subscribeToRealtime(homeId: activeHomeId ?? getActiveHomeId?.call());
      } catch (e) {
        _updateConnectionState(SyncConnectionState.error);
      }
    }

    _updateConnectionState(SyncConnectionState.connected);

    // Start periodic outbox drain & periodic foreground polling
    _startOutboxTimer();
    _startForegroundPoller();

    // Trigger immediate outbox flush
    unawaited(flushOutbox());
  }

  void _subscribeToRealtime({String? homeId}) {
    if (supabaseClient == null) return;
    try {
      _realtimeChannel?.unsubscribe();
    } catch (_) {}

    final targetId = homeId ?? getActiveHomeId?.call();
    final channelName = (targetId != null && targetId.isNotEmpty)
        ? 'cove_home_$targetId'
        : 'cove_sync_channel';

    debugPrint('[SyncEngine] Subscribing to Supabase Realtime channel: $channelName');

    _realtimeChannel = supabaseClient!
        .channel(channelName)
        .onBroadcast(
          event: 'sync_event',
          callback: (payload) =>
              _handleInboundEvent(Map<String, dynamic>.from(payload), isLiveEvent: true),
        )
        .onBroadcast(
          event: 'sync_ack',
          callback: (payload) =>
              _handleInboundDelivery(Map<String, dynamic>.from(payload)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'home_events',
          callback: (payload) => _handleInboundEvent(payload.newRecord, isLiveEvent: true),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'event_deliveries',
          callback: (payload) => _handleInboundDelivery(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'home_members',
          callback: (payload) => _handleInboundMemberChange(payload.newRecord),
        )
        .subscribe();
  }

  void _handleInboundMemberChange(Map<String, dynamic> record) {
    try {
      final hId = record['home_id']?.toString();
      final uId = record['user_id']?.toString();
      final dName = record['display_name']?.toString().trim();
      final avatar = record['avatar_url']?.toString();
      final currentUserId = supabaseClient?.auth.currentUser?.id;

      if (hId == null || uId == null || dName == null || dName.isEmpty) return;
      if (currentUserId != null && uId == currentUserId) {
        UserProfileNotifier.updateUserFromRemote(
          name: dName,
          avatarUrl: avatar,
        );
        return; // Do not update partner profile for self!
      }

      PartnerProfileNotifier.updatePartnerFromRemote(
        homeId: hId,
        name: dName,
        avatarUrl: avatar,
        userId: uId,
      );
    } catch (e) {
      debugPrint('[SyncEngine] Error handling inbound member change: $e');
    }
  }

  /// Visible for testing to simulate inbound Realtime events directly.
  @visibleForTesting
  Future<void> handleInboundEvent(Map<String, dynamic> record,
          {bool isLiveEvent = true}) =>
      _handleInboundEvent(record, isLiveEvent: isLiveEvent);

  /// Processes an incoming event row pushed from Supabase Realtime (Broadcast or Postgres CDC).
  Future<void> _handleInboundEvent(Map<String, dynamic> record,
      {bool isLiveEvent = false}) async {
    final homeId = record['home_id']?.toString() ?? '';
    final actorId = record['actor_id']?.toString() ?? '';
    final eventId = record['id']?.toString() ?? '';
    final eventType = record['event_type']?.toString() ?? '';
    final rawCiphertext = record['encrypted_payload']?.toString() ?? '';
    final createdAt = DateTime.tryParse(record['created_at']?.toString() ?? '') ??
        DateTime.now().toUtc();

    if (homeId.isEmpty ||
        actorId.isEmpty ||
        eventId.isEmpty ||
        eventType.isEmpty ||
        rawCiphertext.isEmpty) {
      return;
    }

    // Deduplication: prevent reprocessing if already processed in memory,
    // already in outbox (originated on this client), or previously applied locally.
    if (_processedEventIds.contains(eventId)) {
      return;
    }
    if (await eventStore.hasEvent(eventId)) {
      _processedEventIds.add(eventId);
      return;
    }
    if (await localStateStore.hasEvent(eventId)) {
      _processedEventIds.add(eventId);
      return;
    }

    if (_processedEventIds.length > 500) {
      _processedEventIds.remove(_processedEventIds.first);
    }
    _processedEventIds.add(eventId);

    // Retrieve symmetric key for the event's home
    final homeKey = await keyStore.getKey(homeId);
    if (homeKey == null) {
      debugPrint('[SyncEngine] Inbound event $eventId received, but no key found for home $homeId');
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
        eventId: eventId,
        homeId: homeId,
        eventType: eventType,
        payload: payloadMap,
        timestamp: createdAt,
        authorId: actorId,
      );
      debugPrint('[SyncEngine] Successfully applied inbound event $eventType to local store');

      final inboundPartnerName = (payloadMap['display_name'] ?? payloadMap['actor_name']) as String?;
      if (inboundPartnerName != null &&
          inboundPartnerName.trim().isNotEmpty &&
          inboundPartnerName.trim() != 'Partner' &&
          inboundPartnerName.trim() != 'You') {
        unawaited(PartnerProfileNotifier.updatePartnerFromRemote(
          homeId: homeId,
          name: inboundPartnerName,
          avatarUrl: payloadMap['avatar_url'] as String?,
          userId: actorId,
        ));
      }

      // Send delivery confirmation only for partner's events (not our own multi-device events)
      if (actorId != currentUserId) {
        if (_realtimeChannel != null) {
          unawaited(_realtimeChannel!.sendBroadcastMessage(
            event: 'sync_ack',
            payload: {
              'event_id': eventId,
              'member_id': currentUserId,
            },
          ));
        }

        if (supabaseClient != null) {
          unawaited(supabaseClient!.from('event_deliveries').upsert(
            {
              'event_id': eventId,
              'member_id': currentUserId,
              'delivered_at': DateTime.now().toUtc().toIso8601String(),
            },
            onConflict: 'event_id,member_id',
            ignoreDuplicates: true,
          ));
          debugPrint('[SyncEngine] Sent delivery ack for event $eventId');
        }
      }

      // Trigger partner activity notification callback ONLY for live Realtime events from partner
      if (isLiveEvent && actorId != currentUserId) {
        final notifPayload = CoveNotificationPayload.fromDecrypted(
          homeId: homeId,
          actorId: actorId,
          eventType: eventType,
          eventId: eventId,
          payload: payloadMap,
        );
        onInboundActivityReceived?.call(notifPayload);
      }
    } catch (e, st) {
      debugPrint('[SyncEngine] Error decrypting/applying inbound event: $e\n$st');
    }
  }

  /// Processes an acknowledgment row pushed from Supabase Realtime.
  /// When a partner's device acknowledges receipt of our event, this flips
  /// our local status from 1-tick (savedLocally) to 2-ticks (syncedToPartner).
  Future<void> _handleInboundDelivery(Map<String, dynamic> record) async {
    final eventId = record['event_id']?.toString();
    final memberId = record['member_id']?.toString();
    if (eventId == null || memberId == null) return;

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

    _processedEventIds.add(eventId);

    // 1. Zero-latency local update: Apply to Drift projections immediately
    await localStateStore.applyEvent(
      eventId: eventId,
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

        // 1. Concurrently broadcast event in realtime via WebSocket to peer
        if (_realtimeChannel != null) {
          unawaited(_realtimeChannel!.sendBroadcastMessage(
            event: 'sync_event',
            payload: {
              'id': event.id,
              'home_id': event.homeId,
              'actor_id': event.authorId,
              'event_type': event.eventType,
              'encrypted_payload': transportPayload,
              'created_at': event.createdAt.toIso8601String(),
            },
          ));
        }

        // 2. Insert into Supabase home_events table
        await supabaseClient!.from('home_events').upsert(
          {
            'id': event.id,
            'home_id': event.homeId,
            'actor_id': event.authorId,
            'event_type': event.eventType,
            'encrypted_payload': transportPayload,
            'created_at': event.createdAt.toIso8601String(),
          },
          onConflict: 'id',
          ignoreDuplicates: true,
        );
        debugPrint('[SyncEngine] Upserted event ${event.id} (${event.eventType}) to Supabase');

        // Immediately mark event as uploaded to break outbox re-upload loops
        await eventStore.markEventUploaded(event.id);

        // Check if partner already marked delivery for this event
        try {
          final existingDeliveries = await supabaseClient!
              .from('event_deliveries')
              .select('member_id')
              .eq('event_id', event.id)
              .neq('member_id', currentUserId);

          if ((existingDeliveries as List).isNotEmpty) {
            await eventStore.markEventSynced(event.id);
          }
        } catch (deliveryErr) {
          debugPrint('[SyncEngine] Delivery check error (non-fatal): $deliveryErr');
        }
      }

      _consecutiveFailures = 0;
    } catch (e, st) {
      debugPrint('[SyncEngine] Error flushing outbox to Supabase: $e\n$st');
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

  void _startForegroundPoller() {
    _foregroundPollTimer?.cancel();
    // Periodic background fetch every 4 seconds to guarantee zero missed events
    _foregroundPollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      pullLatestEvents();
    });
  }

  void _updateConnectionState(SyncConnectionState state) {
    _currentState = state;
    _connectionStateController.add(state);
  }

  String _generateUuid() => generateCoveUuid();

  DateTime? _lastPulledCreatedAt;

  @override
  Future<void> pullLatestEvents({String? homeId}) async {
    final targetHomeId = homeId ?? getActiveHomeId?.call();
    if (targetHomeId == null || supabaseClient == null) return;

    try {
      final baseQuery = supabaseClient!
          .from('home_events')
          .select()
          .eq('home_id', targetHomeId);

      final query = _lastPulledCreatedAt != null
          ? baseQuery.gt('created_at', _lastPulledCreatedAt!.toIso8601String())
          : baseQuery;

      final rows = await query
          .order('created_at', ascending: true)
          .limit(100);

      for (final record in (rows as List)) {
        final map = record as Map<String, dynamic>;
        final dt = DateTime.tryParse(map['created_at']?.toString() ?? '');
        if (dt != null &&
            (_lastPulledCreatedAt == null || dt.isAfter(_lastPulledCreatedAt!))) {
          _lastPulledCreatedAt = dt;
        }
        await _handleInboundEvent(map, isLiveEvent: false);
      }

      // If full page returned, pull next batch until fully caught up
      if ((rows as List).length >= 100) {
        unawaited(pullLatestEvents(homeId: targetHomeId));
      }

      await flushOutbox();
    } catch (_) {
      // Offline or temporary fetch failure; silent background wake falls back gracefully
    }
  }

  @override
  Future<void> stop() async {
    _outboxFlushTimer?.cancel();
    _foregroundPollTimer?.cancel();
    await _realtimeChannel?.unsubscribe();
    _updateConnectionState(SyncConnectionState.disconnected);
  }
}
