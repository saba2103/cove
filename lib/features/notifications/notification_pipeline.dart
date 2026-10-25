import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/cove_tokens.dart';
import '../../sync/crypto/sodium_crypto_service.dart';
import '../../sync/db/app_database.dart';
import '../../sync/encryption_service.dart';
import '../../sync/key_management/home_key_store.dart';
import '../profile/preferences_controller.dart';
import 'notification_batcher.dart';
import 'notification_copy.dart';
import 'notification_models.dart';

/// Reason logged when the §4 fallback notification is shown (`design/specs/15-notifications.md` §4).
enum FallbackReason {
  noKey,
  noSession,
  decryptFailed,
  eventNotFound,
  timeout,
  unknown,
}

/// Exception thrown by the fetch/decrypt step when an event cannot be produced
/// so the pipeline can log the exact [FallbackReason] (with no content) and
/// render the §4 fallback.
class NotificationPipelineException implements Exception {
  final FallbackReason reason;

  const NotificationPipelineException(this.reason);

  @override
  String toString() => 'NotificationPipelineException(${reason.name})';
}

/// Value object describing a local notification rendered by [LocalNotificationSink]
/// per `design/specs/15-notifications.md` §5–§6.
class RenderedNotification {
  static const String channelIdValue = 'cove_partner_activity';
  static const String smallIconResource = '@drawable/ic_stat_cove';

  final int id;
  final String? tag;
  final String channelId;
  final String groupKey;
  final NotificationModule module;
  final String icon;
  final Color color;
  final String title;
  final String body;
  final List<String> inboxLines;
  final bool onlyAlertOnce;
  final bool isFallback;
  final bool isBatch;
  final CoveNotificationPayload tapPayload;

  const RenderedNotification({
    required this.id,
    required this.groupKey,
    required this.module,
    required this.title,
    required this.body,
    required this.tapPayload,
    this.tag,
    this.channelId = channelIdValue,
    this.icon = smallIconResource,
    required this.color,
    this.inboxLines = const <String>[],
    this.onlyAlertOnce = false,
    this.isFallback = false,
    this.isBatch = false,
  });

  bool get usesInboxStyle => inboxLines.isNotEmpty;
}

/// Pluggable sink for displaying and cancelling local notifications.
abstract class LocalNotificationSink {
  Future<void> show(RenderedNotification notification);
  Future<void> cancel({required int id, String? tag});
  Future<void> cancelAll();
}

/// Production [LocalNotificationSink] backed by [FlutterLocalNotificationsPlugin].
class FlutterLocalNotificationSink implements LocalNotificationSink {
  final FlutterLocalNotificationsPlugin plugin;
  final Future<void> Function()? ensureInitialized;

  FlutterLocalNotificationSink({
    required this.plugin,
    this.ensureInitialized,
  });

  @override
  Future<void> show(RenderedNotification notification) async {
    if (kIsWeb) return;
    try {
      if (ensureInitialized != null) {
        await ensureInitialized!();
      }

      final StyleInformation styleInfo = notification.usesInboxStyle
          ? InboxStyleInformation(
              notification.inboxLines,
              contentTitle: notification.title,
              summaryText: notification.body,
            )
          : const DefaultStyleInformation(false, false);

      final androidDetails = AndroidNotificationDetails(
        notification.channelId,
        'Partner Activity',
        channelDescription:
            'Realtime updates and notifications for household activity',
        importance: Importance.max,
        priority: Priority.high,
        ticker: notification.title,
        icon: notification.icon,
        color: notification.color,
        groupKey: notification.groupKey,
        onlyAlertOnce: notification.onlyAlertOnce,
        tag: notification.tag,
        styleInformation: styleInfo,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await plugin.show(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        notificationDetails: details,
        payload: jsonEncode(notification.tapPayload.toMap()),
      );
    } catch (e) {
      debugPrint(
        '[FlutterLocalNotificationSink] Error displaying local notification: $e',
      );
    }
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    if (kIsWeb) return;
    try {
      if (ensureInitialized != null) {
        await ensureInitialized!();
      }
      if (tag != null && tag.isNotEmpty) {
        await plugin.cancel(id: id, tag: tag);
      }
      await plugin.cancel(id: id);
    } catch (e) {
      debugPrint(
        '[FlutterLocalNotificationSink] Error cancelling local notification: $e',
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      if (ensureInitialized != null) {
        await ensureInitialized!();
      }
      await plugin.cancelAll();
    } catch (e) {
      debugPrint(
        '[FlutterLocalNotificationSink] Error cancelling all notifications: $e',
      );
    }
  }
}

/// Outcome of processing a single push message through [NotificationPipeline].
enum PipelineOutcomeKind {
  /// Message carried a legacy `notification` block; ignored so Android doesn't
  /// render a duplicate card.
  ignoredNotificationBlock,

  /// Event was already processed recently (deduplicated).
  deduplicated,

  /// Event belongs to a module muted by the user in local preferences.
  muted,

  /// Event is never sent on the lock screen per §3 (`composeNotification == null`).
  suppressed,

  /// Event was dropped by [NotificationBatcher] (e.g. removal with no open batch).
  dropped,

  /// A notification card was shown or replaced (`showNew`, `replace`, `rideAlong`).
  shown,

  /// The 8-second budget or decrypt chain failed; the §4 fallback card was shown.
  fallbackShown,
}

class PipelineResult {
  final PipelineOutcomeKind kind;
  final BatchDecision? batchDecision;
  final RenderedNotification? rendered;
  final FallbackReason? fallbackReason;
  final CoveNotificationPayload? payload;

  const PipelineResult({
    required this.kind,
    this.batchDecision,
    this.rendered,
    this.fallbackReason,
    this.payload,
  });

  bool get didShowNotification =>
      kind == PipelineOutcomeKind.shown ||
      kind == PipelineOutcomeKind.fallbackShown;
}

typedef NotificationEventDecryptor = Future<DecryptedEvent> Function({
  required String homeId,
  required String eventId,
  required String eventType,
  required Map<String, dynamic> data,
});

/// Event fetcher & decryptor that reads from local `localActivityEvents` (if
/// already projected) or fetches the single `sync_events` row from Supabase and
/// decrypts it in-memory using [HomeKeyStore] and [EncryptionService].
///
/// Strictly read-only: never writes to SQLite or the outbox.
class ReadOnlyEventDecryptor {
  final AppDatabase? database;
  final SupabaseClient? supabaseClient;
  final HomeKeyStore? keyStore;
  final EncryptionService? encryptionService;

  const ReadOnlyEventDecryptor({
    this.database,
    this.supabaseClient,
    this.keyStore,
    this.encryptionService,
  });

  Future<DecryptedEvent> fetchAndDecrypt({
    required String homeId,
    required String eventId,
    required String eventType,
    required Map<String, dynamic> data,
  }) async {
    // 1. If the message map already carries a decrypted `payload` (e.g. in-app
    //    local test or pre-decrypted broadcast), use it directly.
    Map<String, dynamic>? inlinePayload;
    if (data['payload'] is Map<String, dynamic>) {
      inlinePayload = data['payload'] as Map<String, dynamic>;
    } else if (data['payload'] is String &&
        (data['payload'] as String).trim().isNotEmpty) {
      try {
        inlinePayload =
            jsonDecode(data['payload'] as String) as Map<String, dynamic>;
      } catch (_) {
        throw const NotificationPipelineException(FallbackReason.decryptFailed);
      }
    }

    if (inlinePayload != null && inlinePayload.isNotEmpty) {
      return DecryptedEvent(
        id: eventId.isNotEmpty
            ? eventId
            : ((inlinePayload['id'] as String?) ?? ''),
        homeId: homeId,
        eventType: eventType,
        actorId: (data['actor_id'] as String?) ??
            (inlinePayload['actor_id'] as String?) ??
            '',
        payload: inlinePayload,
      );
    }

    // 2. Check if the decrypted event is already present in local read-only DB.
    if (database != null && eventId.isNotEmpty) {
      final localRow = await (database!.select(database!.localActivityEvents)
            ..where((t) => t.id.equals(eventId)))
          .getSingleOrNull();
      if (localRow != null && localRow.payloadJson.isNotEmpty) {
        try {
          final parsed =
              jsonDecode(localRow.payloadJson) as Map<String, dynamic>;
          return DecryptedEvent(
            id: localRow.id,
            homeId: localRow.homeId,
            eventType: localRow.eventType,
            actorId: localRow.actorId,
            payload: parsed,
            createdAt: localRow.createdAt,
          );
        } catch (_) {
          throw const NotificationPipelineException(
            FallbackReason.decryptFailed,
          );
        }
      }
    }

    // 3. Fetch encrypted_payload from Supabase and decrypt in memory (read-only).
    if (eventId.isEmpty || homeId.isEmpty) {
      throw const NotificationPipelineException(FallbackReason.eventNotFound);
    }

    if (data['encrypted_payload'] is String &&
        (data['encrypted_payload'] as String).isNotEmpty) {
      return _decryptTransportString(
        homeId: homeId,
        eventId: eventId,
        eventType: eventType,
        actorId: (data['actor_id'] as String?) ?? '',
        encryptedPayloadStr: data['encrypted_payload'] as String,
      );
    }

    final client = supabaseClient;
    if (client == null || client.auth.currentSession == null) {
      throw const NotificationPipelineException(FallbackReason.noSession);
    }

    Map<String, dynamic>? row;
    try {
      row = await client
          .from('sync_events')
          .select('id, home_id, actor_id, event_type, encrypted_payload, created_at')
          .eq('id', eventId)
          .maybeSingle();
    } catch (_) {
      throw const NotificationPipelineException(FallbackReason.eventNotFound);
    }

    if (row == null) {
      throw const NotificationPipelineException(FallbackReason.eventNotFound);
    }

    final encryptedPayloadStr = row['encrypted_payload'] as String?;
    if (encryptedPayloadStr == null || encryptedPayloadStr.isEmpty) {
      throw const NotificationPipelineException(FallbackReason.decryptFailed);
    }

    return _decryptTransportString(
      homeId: (row['home_id'] as String?) ?? homeId,
      eventId: (row['id'] as String?) ?? eventId,
      eventType: (row['event_type'] as String?) ?? eventType,
      actorId: (row['actor_id'] as String?) ?? '',
      encryptedPayloadStr: encryptedPayloadStr,
    );
  }

  Future<DecryptedEvent> _decryptTransportString({
    required String homeId,
    required String eventId,
    required String eventType,
    required String actorId,
    required String encryptedPayloadStr,
  }) async {
    final store = keyStore ?? HomeKeyStore();
    final homeKey = await store.getKey(homeId);
    if (homeKey == null || homeKey.isEmpty) {
      throw const NotificationPipelineException(FallbackReason.noKey);
    }

    final crypto = encryptionService ?? SodiumCryptoService();
    try {
      final encrypted = crypto is SodiumCryptoService
          ? crypto.deserializeFromTransportString(encryptedPayloadStr)
          : SodiumCryptoService().deserializeFromTransportString(
              encryptedPayloadStr,
            );
      final plaintext = await crypto.decrypt(
        payload: encrypted,
        homeKey: homeKey,
      );
      final decoded = jsonDecode(plaintext) as Map<String, dynamic>;
      return DecryptedEvent(
        id: eventId,
        homeId: homeId,
        eventType: eventType,
        actorId: actorId,
        payload: decoded,
      );
    } catch (_) {
      throw const NotificationPipelineException(FallbackReason.decryptFailed);
    }
  }
}

/// The unified phone notification pipeline (`design/specs/15-notifications.md` §4–§6),
/// shared by both the foreground `onMessage` listener and the background isolate
/// handler (`_firebaseMessagingBackgroundHandler`).
class NotificationPipeline {
  static const Duration defaultBudget = Duration(seconds: 8);

  /// Events that §3 suppresses based on `event_type` alone, before even needing
  /// to decrypt the payload.
  static const Set<String> unconditionallySilentEventTypes = <String>{
    'member_profile_updated',
    'profile_updated',
    'user_profile_updated',
    'avatar_updated',
    'avatar_changed',
    'name_updated',
    'display_name_updated',
    'home_currency_updated',
    'home_updated',
    'home_settings_updated',
    'preferences_updated',
    'settings_updated',
    'list_item_updated',
    'list_renamed',
    'list_archived',
    'list_deleted',
    'list_reordered',
    'list_completed_cleared',
    'expense_updated',
    'expense_deleted',
    'habit_checkin_acknowledged',
    'habit_updated',
    'habit_deleted',
    'subscription_updated',
    'subscription_restarted',
    'subscription_reactivated',
    'subscription_deleted',
    'routine_created',
    'routine_updated',
    'routine_deleted',
    'routine_block_added',
    'routine_event_added',
    'routine_event_updated',
    'routine_event_deleted',
    'roadmap_item_added',
    'roadmap_item_updated',
    'roadmap_item_deleted',
    'checkin_reminder_added',
    'checkin_reminder_updated',
    'checkin_reminder_toggled',
    'checkin_reminder_deleted',
  };

  final AppDatabase? database;
  final LocalNotificationSink sink;
  final NotificationEventDecryptor decryptEvent;
  final Duration budget;
  final String? Function()? getViewerUserId;
  final String? Function()? getPartnerName;
  final String? Function()? getCurrencySymbol;
  final SharedPreferences? sharedPreferences;
  final void Function(FallbackReason reason, String homeId, String eventId)?
      onFallbackLogged;

  final Map<FallbackReason, int> fallbackCounts = <FallbackReason, int>{};
  FallbackReason? lastFallbackReason;

  NotificationPipeline({
    required this.sink,
    this.database,
    NotificationEventDecryptor? decryptEvent,
    SupabaseClient? supabaseClient,
    HomeKeyStore? keyStore,
    EncryptionService? encryptionService,
    this.budget = defaultBudget,
    this.getViewerUserId,
    this.getPartnerName,
    this.getCurrencySymbol,
    this.sharedPreferences,
    this.onFallbackLogged,
  }) : decryptEvent = decryptEvent ??
            ReadOnlyEventDecryptor(
              database: database,
              supabaseClient: supabaseClient,
              keyStore: keyStore,
              encryptionService: encryptionService,
            ).fetchAndDecrypt;

  /// Handles a Firebase [RemoteMessage].
  ///
  /// Per 3.14c rule 4: while old server messages carrying a `notification`
  /// block are still arriving, Android displays them itself — do not show a
  /// second copy. Only act on data-only messages.
  Future<PipelineResult> handleRemoteMessage(RemoteMessage message) {
    return handleDataMessage(
      message.data,
      hasNotificationBlock: message.notification != null,
    );
  }

  /// Processes a data message through:
  /// `data message → fetch & decrypt → build NotificationContext from read-only DB → composeNotification → NotificationBatcher → show/replace/drop`.
  Future<PipelineResult> handleDataMessage(
    Map<String, dynamic> data, {
    bool hasNotificationBlock = false,
  }) async {
    // Rule 4: Ignore messages that carry a notification block.
    if (hasNotificationBlock || data['__has_notification_block'] == true) {
      return const PipelineResult(
        kind: PipelineOutcomeKind.ignoredNotificationBlock,
      );
    }

    final homeId = (data['home_id'] as String?) ?? '';
    final eventId = (data['event_id'] as String?) ?? '';
    final eventType = (data['event_type'] as String?) ?? '';

    // §3: Events silenced by event_type alone never produce a notification or fallback.
    if (unconditionallySilentEventTypes.contains(eventType)) {
      return const PipelineResult(kind: PipelineOutcomeKind.suppressed);
    }

    // Check module mute preferences (read-only).
    final module = (data['module'] as String?) != null
        ? NotificationModule.fromString(data['module'] as String)
        : CoveNotificationPayload.moduleForEventType(eventType);
    final prefs = await _readNotificationPreferences();
    if (prefs.isMuted(module)) {
      return const PipelineResult(kind: PipelineOutcomeKind.muted);
    }

    try {
      return await _runWithinBudget(
        data: data,
        homeId: homeId,
        eventId: eventId,
        eventType: eventType,
      ).timeout(budget);
    } on TimeoutException {
      return _showFallback(
        reason: FallbackReason.timeout,
        homeId: homeId,
        eventId: eventId,
        eventType: eventType,
        data: data,
      );
    } on NotificationPipelineException catch (e) {
      return _showFallback(
        reason: e.reason,
        homeId: homeId,
        eventId: eventId,
        eventType: eventType,
        data: data,
      );
    } catch (_) {
      return _showFallback(
        reason: FallbackReason.unknown,
        homeId: homeId,
        eventId: eventId,
        eventType: eventType,
        data: data,
      );
    }
  }

  Future<PipelineResult> _runWithinBudget({
    required Map<String, dynamic> data,
    required String homeId,
    required String eventId,
    required String eventType,
  }) async {
    final event = await decryptEvent(
      homeId: homeId,
      eventId: eventId,
      eventType: eventType,
      data: data,
    );

    final ctx = await buildContextFromReadOnlyDatabase(
      event: event,
      data: data,
    );

    final copy = composeNotification(event, ctx);
    if (copy == null) {
      return const PipelineResult(kind: PipelineOutcomeKind.suppressed);
    }

    // Check mute preferences again in case composeNotification resolved a more specific groupKey.
    final prefs = await _readNotificationPreferences();
    if (prefs.isMuted(copy.groupKey)) {
      return const PipelineResult(kind: PipelineOutcomeKind.muted);
    }

    final batcher =
        await NotificationBatcherPreferences.load(sharedPreferences);
    final now = clock.now();
    final decision = batcher.offer(copy, now);
    await NotificationBatcherPreferences.save(batcher, sharedPreferences);

    if (decision.isDrop || decision.id == null) {
      return PipelineResult(
        kind: PipelineOutcomeKind.dropped,
        batchDecision: decision,
      );
    }

    final isBatch = decision.lines.isNotEmpty;
    final tapPayload = CoveNotificationPayload(
      homeId: event.homeId.isNotEmpty ? event.homeId : homeId,
      module: decision.groupKey,
      eventType: event.eventType,
      eventId: isBatch ? null : event.id,
      title: decision.title,
      body: decision.body,
      actorName: ctx.partnerName,
      listId: decision.batchKey,
      isBatch: isBatch,
      payload: isBatch
          ? <String, dynamic>{
              if (decision.batchKey != null) 'list_id': decision.batchKey,
              'list_name': decision.title,
              'is_batch': true,
            }
          : event.payload,
    );

    final rendered = RenderedNotification(
      id: decision.id!,
      tag: decision.tag,
      groupKey: 'cove_group_${decision.groupKey.name}',
      module: decision.groupKey,
      color: CoveTokens.dark.accentFill,
      title: decision.title,
      body: decision.body,
      inboxLines: decision.lines,
      onlyAlertOnce: decision.onlyAlertOnce,
      isFallback: false,
      isBatch: isBatch,
      tapPayload: tapPayload,
    );

    await sink.show(rendered);

    return PipelineResult(
      kind: PipelineOutcomeKind.shown,
      batchDecision: decision,
      rendered: rendered,
      payload: tapPayload,
    );
  }

  Future<PipelineResult> _showFallback({
    required FallbackReason reason,
    required String homeId,
    required String eventId,
    required String eventType,
    required Map<String, dynamic> data,
  }) async {
    fallbackCounts[reason] = (fallbackCounts[reason] ?? 0) + 1;
    lastFallbackReason = reason;
    debugPrint(
      '[NotificationPipeline] Fallback shown: reason=${reason.name} homeId=$homeId eventId=$eventId',
    );
    onFallbackLogged?.call(reason, homeId, eventId);

    final homeName = await _readHomeName(homeId, data: data);
    final partnerName = await _readPartnerName(homeId, data: data);

    final fallbackCopy = composeFallbackNotification(
      homeName: homeName,
      partnerName: partnerName,
      homeId: homeId,
      eventId: eventId,
      eventType: eventType,
    );

    final batcher =
        await NotificationBatcherPreferences.load(sharedPreferences);
    final decision = batcher.offer(fallbackCopy, clock.now());
    await NotificationBatcherPreferences.save(batcher, sharedPreferences);

    final tapPayload = CoveNotificationPayload(
      homeId: homeId,
      module: NotificationModule.activity,
      eventType: eventType,
      eventId: eventId.isNotEmpty ? eventId : null,
      title: fallbackCopy.title,
      body: fallbackCopy.body,
      actorName: partnerName,
    );

    final rendered = RenderedNotification(
      id: decision.id ?? 1,
      groupKey: 'cove_group_${NotificationModule.activity.name}',
      module: NotificationModule.activity,
      color: CoveTokens.dark.accentFill,
      title: fallbackCopy.title,
      body: fallbackCopy.body,
      inboxLines: const <String>[],
      onlyAlertOnce: false,
      isFallback: true,
      isBatch: false,
      tapPayload: tapPayload,
    );

    await sink.show(rendered);

    return PipelineResult(
      kind: PipelineOutcomeKind.fallbackShown,
      batchDecision: decision,
      rendered: rendered,
      fallbackReason: reason,
      payload: tapPayload,
    );
  }

  /// Builds [NotificationContext] from the local Drift database using strictly
  /// read-only `SELECT` queries.
  Future<NotificationContext> buildContextFromReadOnlyDatabase({
    required DecryptedEvent event,
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    final db = database;
    final p = event.payload;
    final homeId = event.homeId.isNotEmpty
        ? event.homeId
        : ((data['home_id'] as String?) ?? '');
    final viewerUserId =
        getViewerUserId?.call() ?? (data['viewer_user_id'] as String?) ?? '';

    LocalHome? home;
    if (db != null && homeId.isNotEmpty) {
      try {
        home = await (db.select(db.localHomes)
              ..where((t) => t.id.equals(homeId)))
            .getSingleOrNull();
      } catch (_) {}
    }

    final homeName = (home != null && home.name.trim().isNotEmpty)
        ? home.name.trim()
        : ((p['home_name'] as String?) ??
            (data['home_name'] as String?) ??
            'Home');

    final currencyCode = (p['currency'] as String?) ?? home?.currency;
    final currencySymbol = resolveNotificationCurrencySymbol(
      currencyCode,
      fallbackSymbol: getCurrencySymbol?.call(),
    );

    final partnerName = await _readPartnerName(
      homeId,
      actorId: event.actorId,
      viewerUserId: viewerUserId,
      payload: p,
      data: data,
    );

    String? listId = p['list_id'] as String?;
    String? listName = p['list_name'] as String?;
    String? itemTitle = (p['title'] ?? p['name'] ?? p['item']) as String?;
    int? untickedItemsLeft = (p['unticked_left'] as num?)?.toInt();

    if (db != null && event.eventType.startsWith('list_item_')) {
      final itemId = (p['id'] ?? p['item_id']) as String?;
      if ((listId == null || itemTitle == null) &&
          itemId != null &&
          itemId.isNotEmpty) {
        try {
          final itemRow = await (db.select(db.localListItems)
                ..where((t) => t.id.equals(itemId)))
              .getSingleOrNull();
          if (itemRow != null) {
            listId ??= itemRow.listId;
            itemTitle ??= itemRow.title;
          }
        } catch (_) {}
      }

      if (listId != null && listId.isNotEmpty) {
        if (listName == null || listName.isEmpty) {
          try {
            final listRow = await (db.select(db.localLists)
                  ..where((t) => t.id.equals(listId!)))
                .getSingleOrNull();
            listName = listRow?.name;
          } catch (_) {}
        }

        if (event.eventType == 'list_item_toggled' &&
            untickedItemsLeft == null) {
          try {
            final itemsInList = await (db.select(db.localListItems)
                  ..where((t) => t.listId.equals(listId!)))
                .get();
            if (itemsInList.isNotEmpty) {
              untickedItemsLeft = itemsInList
                  .where((item) => !item.isCompleted && item.id != itemId)
                  .length;
            }
          } catch (_) {}
        }
      }
    }

    String? habitName = (p['habit_name'] ?? p['name'] ?? p['title']) as String?;
    int? habitStreak = (p['streak'] as num?)?.toInt();

    if (db != null && event.eventType == 'habit_checkin_toggled') {
      final habitId = (p['habit_id'] ?? p['id']) as String?;
      if (habitId != null && habitId.isNotEmpty) {
        if (habitName == null || habitName.isEmpty) {
          try {
            final habitRow = await (db.select(db.localHabits)
                  ..where((t) => t.id.equals(habitId)))
                .getSingleOrNull();
            habitName = habitRow?.name;
          } catch (_) {}
        }
        if (habitStreak == null) {
          try {
            final checkins = await (db.select(db.localHabitCheckins)
                  ..where((t) => t.habitId.equals(habitId)))
                .get();
            final dates = <String>{
              for (final c in checkins)
                if (event.actorId.isEmpty || c.memberId == event.actorId)
                  c.checkinDate,
            };
            final eventDate = (p['checkin_date'] ?? p['date']) as String?;
            if (eventDate != null && eventDate.length >= 10) {
              dates.add(eventDate.substring(0, 10));
            }
            if (dates.isNotEmpty) {
              habitStreak = _calculateConsecutiveDaysStreak(dates, clock.now());
            }
          } catch (_) {}
        }
      }
    }

    DateTime? eventStartTime;
    bool? eventIsAllDay;
    DateTime? previousEventStartTime;
    bool? previousEventIsAllDay;

    if (db != null && event.eventType.startsWith('calendar_event_')) {
      final calId = (p['id'] ?? p['event_id'] ?? event.id) as String?;
      if (calId != null && calId.isNotEmpty) {
        try {
          final existingCal = await (db.select(db.localCalendarEvents)
                ..where((t) => t.id.equals(calId)))
              .getSingleOrNull();
          if (existingCal != null) {
            if (event.eventType == 'calendar_event_updated') {
              previousEventStartTime = existingCal.startTime;
              previousEventIsAllDay = existingCal.isAllDay;
            } else if (event.eventType == 'calendar_event_deleted') {
              eventStartTime = existingCal.startTime;
              eventIsAllDay = existingCal.isAllDay;
            }
          }
        } catch (_) {}
      }
    }

    String? billingCycle = p['billing_cycle'] as String?;
    DateTime? endDate;
    if (db != null && event.eventType.startsWith('subscription_')) {
      final subId = (p['id'] ?? p['subscription_id'] ?? event.id) as String?;
      if (subId != null && subId.isNotEmpty) {
        try {
          final existingSub = await (db.select(db.localSubscriptions)
                ..where((t) => t.id.equals(subId)))
              .getSingleOrNull();
          if (existingSub != null) {
            billingCycle ??= existingSub.billingCycle;
            endDate ??= existingSub.endDate;
          }
        } catch (_) {}
      }
    }

    final createdByViewer = viewerUserId.isNotEmpty &&
        event.actorId.isNotEmpty &&
        event.actorId == viewerUserId;

    return NotificationContext(
      partnerName: partnerName,
      homeName: homeName,
      currencySymbol: currencySymbol,
      today: clock.now(),
      viewerUserId: viewerUserId,
      untickedItemsLeft: untickedItemsLeft,
      habitStreak: habitStreak,
      createdByViewer: createdByViewer,
      listId: listId,
      listName: listName,
      itemTitle: itemTitle,
      habitName: habitName,
      eventStartTime: eventStartTime,
      eventIsAllDay: eventIsAllDay,
      previousEventStartTime: previousEventStartTime,
      previousEventIsAllDay: previousEventIsAllDay,
      billingCycle: billingCycle,
      endDate: endDate,
    );
  }

  Future<NotificationPreferences> _readNotificationPreferences() async {
    if (database == null) return const NotificationPreferences();
    try {
      final row = await database!.getNotificationPreferences();
      if (row == null) return const NotificationPreferences();
      return NotificationPreferences(
        muteSubscriptions: row.muteSubscriptions,
        muteLists: row.muteLists,
        muteExpenses: row.muteExpenses,
        muteHabits: row.muteHabits,
        muteCalendar: row.muteCalendar,
      );
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  Future<String> _readHomeName(
    String homeId, {
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    if (database != null && homeId.isNotEmpty) {
      try {
        final home = await (database!.select(database!.localHomes)
              ..where((t) => t.id.equals(homeId)))
            .getSingleOrNull();
        if (home != null && home.name.trim().isNotEmpty) {
          return home.name.trim();
        }
      } catch (_) {}
    }
    final fromData = data['home_name'] as String?;
    if (fromData != null && fromData.trim().isNotEmpty) {
      return fromData.trim();
    }
    return 'Home';
  }

  Future<String> _readPartnerName(
    String homeId, {
    String? actorId,
    String? viewerUserId,
    Map<String, dynamic> payload = const <String, dynamic>{},
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    final fromCallback = getPartnerName?.call();
    if (fromCallback != null &&
        fromCallback.trim().isNotEmpty &&
        fromCallback.trim() != 'Partner') {
      return fromCallback.trim();
    }

    final fromPayload =
        (payload['actor_name'] ?? payload['display_name'] ?? data['actor_name'])
            as String?;
    if (fromPayload != null &&
        fromPayload.trim().isNotEmpty &&
        fromPayload.trim() != 'Partner') {
      return fromPayload.trim();
    }

    if (database != null && homeId.isNotEmpty) {
      try {
        final events = await (database!.select(database!.localActivityEvents)
              ..where((t) => t.homeId.equals(homeId)))
            .get();
        for (final ev in events.reversed) {
          if (viewerUserId != null &&
              viewerUserId.isNotEmpty &&
              ev.actorId == viewerUserId) {
            continue;
          }
          if (actorId != null && actorId.isNotEmpty && ev.actorId != actorId) {
            continue;
          }
          if (ev.payloadJson.isNotEmpty) {
            final decoded = jsonDecode(ev.payloadJson);
            if (decoded is Map) {
              final name =
                  (decoded['display_name'] ?? decoded['actor_name']) as String?;
              if (name != null &&
                  name.trim().isNotEmpty &&
                  name.trim() != 'Partner') {
                return name.trim();
              }
            }
          }
        }
      } catch (_) {}
    }

    return 'Partner';
  }

  int _calculateConsecutiveDaysStreak(Set<String> dateStrings, DateTime today) {
    if (dateStrings.isEmpty) return 1;
    final sorted = dateStrings.toList()..sort();
    final latest = DateTime.tryParse(sorted.last);
    if (latest == null) return 1;
    var count = 0;
    var cursor = DateTime(latest.year, latest.month, latest.day);
    while (true) {
      final key =
          '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}';
      if (dateStrings.contains(key)) {
        count += 1;
        cursor = cursor.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return count < 1 ? 1 : count;
  }
}
