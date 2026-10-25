import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/cove_tokens.dart';
import '../../sync/db/app_database.dart';
import '../../sync/key_management/home_key_store.dart';
import '../../sync/sync_engine.dart';
import '../profile/preferences_controller.dart';
import 'notification_copy.dart';
import 'notification_models.dart';
import 'notification_pipeline.dart';

class NotificationService {
  static const String mainIsolatePortName = 'cove_fcm_main_isolate_port';
  final SupabaseClient? supabaseClient;
  final SyncEngine? syncEngine;
  final AppDatabase? appDatabase;
  final String? Function()? getCurrentUserId;
  final String? Function()? getPartnerName;
  final String? Function()? getCurrencySymbol;
  final void Function(NotificationModule module)? onNavigate;
  final void Function(CoveNotificationPayload payload)? onNavigatePayload;
  final LocalNotificationSink? notificationSink;
  final NotificationEventDecryptor? decryptEvent;
  final Duration budget;

  NotificationModule? _pendingNavigationModule;
  CoveNotificationPayload? _pendingNotificationPayload;

  /// Retrieves and clears any pending navigation module queued from launch notifications.
  NotificationModule? consumePendingNavigationModule() {
    final mod = _pendingNavigationModule;
    _pendingNavigationModule = null;
    return mod;
  }

  /// Retrieves and clears any pending full notification payload queued from launch notifications.
  CoveNotificationPayload? consumePendingNotificationPayload() {
    final p = _pendingNotificationPayload;
    _pendingNotificationPayload = null;
    return p;
  }

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;

  late final LocalNotificationSink _sink = notificationSink ??
      FlutterLocalNotificationSink(
        plugin: _localNotifications,
        ensureInitialized: () async {
          if (!_localNotificationsInitialized) {
            await initializeLocalNotifications();
          }
        },
      );

  late final NotificationPipeline pipeline = NotificationPipeline(
    sink: _sink,
    database: appDatabase,
    decryptEvent: decryptEvent,
    supabaseClient: supabaseClient,
    budget: budget,
    getViewerUserId: () => currentUserId,
    getPartnerName: getPartnerName,
    getCurrencySymbol: getCurrencySymbol,
  );

  final StreamController<CoveNotificationPayload> _notificationStreamController =
      StreamController<CoveNotificationPayload>.broadcast();

  final StreamController<NotificationModule> _navigationStreamController =
      StreamController<NotificationModule>.broadcast();

  final StreamController<CoveNotificationPayload> _navigationPayloadStreamController =
      StreamController<CoveNotificationPayload>.broadcast();

  NotificationService({
    this.supabaseClient,
    this.syncEngine,
    this.appDatabase,
    this.getCurrentUserId,
    this.getPartnerName,
    this.getCurrencySymbol,
    this.onNavigate,
    this.onNavigatePayload,
    this.notificationSink,
    this.decryptEvent,
    this.budget = NotificationPipeline.defaultBudget,
  });


  Stream<CoveNotificationPayload> get onNotificationReceived =>
      _notificationStreamController.stream;

  Stream<NotificationModule> get onNavigateToModule =>
      _navigationStreamController.stream;

  Stream<CoveNotificationPayload> get onNavigateToPayload =>
      _navigationPayloadStreamController.stream;

  String? get currentUserId =>
      getCurrentUserId?.call() ?? supabaseClient?.auth.currentUser?.id;

  /// Platform string registered in `public.user_devices.platform` by Android
  /// builds that include the 3.14c on-device notification pipeline.
  static const String androidDataV1Platform = 'android:data-v1';

  /// Registers an FCM token against the user's account in public.user_devices.
  Future<bool> registerDeviceToken(String token, {String? platform}) async {
    final uid = currentUserId;
    if (uid == null || supabaseClient == null) return false;

    try {
      final detectedPlatform = platform ?? defaultPlatformString();
      await supabaseClient!.from('user_devices').upsert({
        'user_id': uid,
        'fcm_token': token,
        'platform': detectedPlatform,
        'last_seen_at': clock.now().toUtc().toIso8601String(),
      }, onConflict: 'fcm_token');
      debugPrint('[NotificationService] Device token registered successfully in user_devices for $uid');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Failed to register device token: $e');
      return false;
    }
  }

  /// Removes an FCM token upon sign-out.
  Future<bool> unregisterDeviceToken(String token) async {
    if (supabaseClient == null) return false;

    try {
      await supabaseClient!
          .from('user_devices')
          .delete()
          .eq('fcm_token', token);
      debugPrint('[NotificationService] Device token unregistered successfully: $token');
      return true;
    } catch (e) {
      debugPrint('[NotificationService] Failed to unregister device token: $e');
      return false;
    }
  }

  final Set<String> _recentNotifiedEventIds = {};

  /// Enriches a notification payload with actorName and decrypted details
  /// from local SQLite database if not already enriched.
  Future<CoveNotificationPayload> enrichPayload(
      CoveNotificationPayload payload) async {
    final rawPartnerName = getPartnerName?.call();
    final partnerName = (rawPartnerName != null &&
            rawPartnerName.trim().isNotEmpty &&
            rawPartnerName.trim() != 'Partner')
        ? rawPartnerName.trim()
        : null;

    // 1. If payload already has rich details, ensure partner's name is attached
    if (payload.payload != null && payload.payload!.isNotEmpty) {
      final pActor = (payload.payload!['actor_name'] ?? payload.payload!['display_name']) as String?;
      final resolvedName = partnerName ??
          ((pActor != null && pActor.trim().isNotEmpty && pActor.trim() != 'Partner')
              ? pActor.trim()
              : null);

      if ((payload.actorName == null || payload.actorName == 'Partner') &&
          resolvedName != null &&
          resolvedName.isNotEmpty) {
        return CoveNotificationPayload.fromDecrypted(
          homeId: payload.homeId,
          actorId: '',
          eventType: payload.eventType,
          eventId: payload.eventId,
          payload: payload.payload!,
          actorName: resolvedName,
          preferredCurrencySymbol: getCurrencySymbol?.call(),
        );
      }
      return payload;
    }

    // 2. Otherwise, look up the decrypted event from Drift SQLite
    if (appDatabase != null &&
        payload.eventId != null &&
        payload.eventId!.isNotEmpty) {
      try {
        final ev = await (appDatabase!.select(appDatabase!.localActivityEvents)
              ..where((t) => t.id.equals(payload.eventId!)))
            .getSingleOrNull();

        if (ev != null && ev.payloadJson.isNotEmpty) {
          final pMap = jsonDecode(ev.payloadJson) as Map<String, dynamic>;
          final isSelf = ev.actorId == currentUserId;
          final pActor = (pMap['actor_name'] ?? pMap['display_name']) as String?;
          final resolvedName = partnerName ??
              ((pActor != null && pActor.trim().isNotEmpty && pActor.trim() != 'Partner')
                  ? pActor.trim()
                  : null);
          final effectiveActor = isSelf ? 'You' : (resolvedName ?? 'Partner');

          return CoveNotificationPayload.fromDecrypted(
            homeId: payload.homeId,
            actorId: ev.actorId,
            eventType: ev.eventType,
            eventId: payload.eventId,
            payload: pMap,
            actorName: effectiveActor,
            preferredCurrencySymbol: getCurrencySymbol?.call(),
          );
        }
      } catch (e) {
        debugPrint('[NotificationService] Error enriching notification from DB: $e');
      }
    }

    // 3. Fallback: If no DB row found, at least provide actorName if missing
    if (partnerName != null &&
        partnerName.isNotEmpty &&
        (payload.actorName == null || payload.actorName == 'Partner')) {
      final fallback = composeFallbackNotification(
        homeName: payload.title.isNotEmpty ? payload.title : 'Home',
        partnerName: partnerName,
        homeId: payload.homeId,
        eventId: payload.eventId ?? '',
        eventType: payload.eventType,
      );
      return payload.copyWith(
        actorName: partnerName,
        title: fallback.title,
        body: fallback.body,
      );
    }

    return payload;
  }

  /// Handles incoming push notification payloads through the unified
  /// [NotificationPipeline] (`design/specs/15-notifications.md` §4–§6).
  ///
  /// When [hasNotificationBlock] is `true` (legacy server message carrying a
  /// `notification` block), Android displays it itself so we do not show a
  /// second copy.
  Future<CoveNotificationPayload?> handleIncomingMessage(
    Map<String, dynamic> data, {
    bool hasNotificationBlock = false,
  }) async {
    if (hasNotificationBlock || data['__has_notification_block'] == true) {
      return null;
    }

    final homeId = (data['home_id'] as String?) ?? '';
    final eId = data['event_id'] as String?;
    if (eId != null && eId.isNotEmpty) {
      if (_recentNotifiedEventIds.contains(eId)) {
        return null;
      }
      _recentNotifiedEventIds.add(eId);
      if (_recentNotifiedEventIds.length > 200) {
        _recentNotifiedEventIds.remove(_recentNotifiedEventIds.first);
      }
    }

    // 1. Silent sync wake in foreground: pull unread events so UI streams stay fresh
    if (syncEngine != null && homeId.isNotEmpty) {
      try {
        await syncEngine!.pullLatestEvents(homeId: homeId);
      } catch (e) {
        debugPrint('[NotificationService] Error pulling latest events: $e');
      }
    }

    // 2. Run the unified read-only pipeline: decrypt -> compose -> batch -> show/replace/drop
    final result = await pipeline.handleDataMessage(
      data,
      hasNotificationBlock: hasNotificationBlock,
    );

    if (result.kind == PipelineOutcomeKind.muted) {
      final eventType = (data['event_type'] as String?) ?? 'generic';
      final module = CoveNotificationPayload.moduleForEventType(eventType);
      debugPrint(
        '[NotificationService] Notification for ${module.name} is muted locally. Silent wake only.',
      );
      return null;
    }

    if (!result.didShowNotification || result.payload == null) {
      return null;
    }

    final payload = result.payload!;
    if (!_notificationStreamController.isClosed) {
      _notificationStreamController.add(payload);
    }
    return payload;
  }

  /// Closes the open 90s batch for [listId] and cancels its active system
  /// notification card when the user opens that list in the app (§5).
  Future<int?> onListOpened(String listId) async {
    if (listId.isEmpty) return null;
    final closedId = await NotificationBatcherPreferences.closeBatch(listId);
    if (closedId != null) {
      try {
        await _sink.cancel(id: closedId, tag: listId);
      } catch (e) {
        debugPrint('[NotificationService] Error cancelling list batch card: $e');
      }
    }
    return closedId;
  }

  /// Maximum time the background handler waits for the main isolate to send
  /// `'received'` on the reply port before treating the port mapping as stale.
  static const Duration defaultForwardReceiptTimeout = Duration(seconds: 1);

  /// Background isolate entry helper invoked from `_firebaseMessagingBackgroundHandler`
  /// in `main.dart`.
  ///
  /// 1. Looks up [mainIsolatePortName] in [IsolateNameServer]. If a port is
  ///    registered, forwards the message data to it and waits up to
  ///    [forwardReceiptTimeout] (1 second) for an immediate `'received'`
  ///    receipt. If `'received'` arrives, returns
  ///    [PipelineOutcomeKind.forwardedToMainIsolate] without touching SQLite.
  ///    If no receipt arrives (the mapping is stale because the main isolate is
  ///    gone), removes the port mapping and continues down the read-only path in
  ///    the background so the notification is still shown.
  /// 2. Only when the main app is not running (or a stale mapping failed to
  ///    receipt), opens its own, separate, unshared read-only connection
  ///    (`OpenMode.readOnly` + `busy_timeout`, `enableMigrations: false`,
  ///    wrapped in [ReadOnlyQueryExecutor]) for the duration of the pipeline
  ///    and closes it in `finally`.
  static Future<PipelineResult> handleBackgroundRemoteMessage(
    RemoteMessage message, {
    String portName = mainIsolatePortName,
    Duration forwardReceiptTimeout = defaultForwardReceiptTimeout,
    Future<void> Function()? onStalePortFallback,
    File? databaseFile,
    Future<File> Function()? resolveDatabaseFile,
    AppDatabase? databaseOverride,
    void Function()? onReadOnlyDatabaseOpened,
    SupabaseClient? supabaseClientOverride,
    HomeKeyStore? keyStoreOverride,
    LocalNotificationSink? sinkOverride,
    NotificationEventDecryptor? decryptEventOverride,
    SharedPreferences? sharedPreferencesOverride,
    String? viewerUserIdOverride,
    Duration budget = NotificationPipeline.defaultBudget,
  }) async {
    if (message.notification != null) {
      return const PipelineResult(
        kind: PipelineOutcomeKind.ignoredNotificationBlock,
      );
    }

    final mainPort = IsolateNameServer.lookupPortByName(portName);
    if (mainPort != null) {
      final replyReceivePort = ReceivePort();
      Object? receipt;
      try {
        mainPort.send(<String, dynamic>{
          'data': Map<String, dynamic>.from(message.data),
          'has_notification_block': message.notification != null,
          'reply_port': replyReceivePort.sendPort,
        });
        receipt = await replyReceivePort.first.timeout(
          forwardReceiptTimeout,
          onTimeout: () => null,
        );
      } catch (_) {
        receipt = null;
      } finally {
        replyReceivePort.close();
      }
      if (receipt == 'received') {
        return const PipelineResult(
          kind: PipelineOutcomeKind.forwardedToMainIsolate,
        );
      }
      // No receipt arrived within 1 second — the port mapping is stale because
      // the main isolate is gone. Remove the port mapping and continue down the
      // read-only path in the background so the notification is still shown.
      IsolateNameServer.removePortNameMapping(portName);
      if (onStalePortFallback != null) {
        await onStalePortFallback();
      }
    }

    onReadOnlyDatabaseOpened?.call();
    final db = databaseOverride ??
        AppDatabase.readOnly(
          file: databaseFile,
          resolveFile: resolveDatabaseFile,
        );
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final sink = sinkOverride ??
          FlutterLocalNotificationSink(
            plugin: plugin,
            ensureInitialized: () async {
              const androidSettings = AndroidInitializationSettings(
                RenderedNotification.smallIconResource,
              );
              const iosSettings = DarwinInitializationSettings();
              await plugin.initialize(
                settings: const InitializationSettings(
                  android: androidSettings,
                  iOS: iosSettings,
                ),
              );
            },
          );

      SupabaseClient? supabase = supabaseClientOverride;
      if (supabase == null) {
        try {
          supabase = Supabase.instance.client;
        } catch (_) {}
      }

      final bgPipeline = NotificationPipeline(
        sink: sink,
        database: db,
        decryptEvent: decryptEventOverride,
        supabaseClient: supabase,
        keyStore: keyStoreOverride ?? HomeKeyStore(),
        budget: budget,
        sharedPreferences: sharedPreferencesOverride,
        getViewerUserId: () =>
            viewerUserIdOverride ?? supabase?.auth.currentUser?.id,
      );

      return await bgPipeline.handleRemoteMessage(message);
    } finally {
      if (databaseOverride == null) {
        await db.close();
      }
    }
  }

  /// Initializes local notifications plugin for Android / iOS.
  Future<void> initializeLocalNotifications() async {
    if (kIsWeb) return;
    try {
      const androidSettings = AndroidInitializationSettings(
        RenderedNotification.smallIconResource,
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          final payloadStr = response.payload;
          if (payloadStr != null && payloadStr.isNotEmpty) {
            try {
              final data = jsonDecode(payloadStr) as Map<String, dynamic>;
              final payload = CoveNotificationPayload.fromMap(data);
              onNotificationTapped(payload);
            } catch (_) {}
          }
        },
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            RenderedNotification.channelIdValue,
            'Partner Activity',
            description: 'Realtime updates and notifications for household activity',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          ),
        );
        await androidPlugin.requestNotificationsPermission();
      }

      _localNotificationsInitialized = true;

      // Check if a local notification launched the app from a terminated state
      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payloadStr = launchDetails.notificationResponse?.payload;
        if (payloadStr != null && payloadStr.isNotEmpty) {
          try {
            final data = jsonDecode(payloadStr) as Map<String, dynamic>;
            final payload = CoveNotificationPayload.fromMap(data);
            debugPrint(
                '[NotificationService] App launched from local notification: ${payload.module}');
            onNotificationTapped(payload);
          } catch (e) {
            debugPrint(
                '[NotificationService] Error parsing launch local notification: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Local notifications initialization error: $e');
    }
  }

  /// Displays a heads-up system notification in the device tray.
  Future<void> showLocalNotification(CoveNotificationPayload payload) async {
    if (kIsWeb) return;
    try {
      final id = clock.now().millisecondsSinceEpoch ~/ 1000;
      await _sink.show(
        RenderedNotification(
          id: id,
          groupKey: 'cove_group_${payload.module.name}',
          module: payload.module,
          color: CoveTokens.dark.accentFill,
          title: payload.title,
          body: payload.body,
          tapPayload: payload,
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] Error displaying local notification: $e');
    }
  }

  String? _lastTappedKey;
  DateTime? _lastTappedAt;

  /// Dispatches a deep link navigation action to open the appropriate module screen.
  void onNotificationTapped(CoveNotificationPayload payload) {
    final key = payload.eventId ?? '${payload.module.name}_${payload.eventType}_${payload.title}';
    final now = clock.now();
    if (_lastTappedKey == key &&
        _lastTappedAt != null &&
        now.difference(_lastTappedAt!) < const Duration(milliseconds: 1000)) {
      debugPrint('[NotificationService] Ignoring duplicate notification tap within 1000ms for $key');
      return;
    }
    _lastTappedKey = key;
    _lastTappedAt = now;

    debugPrint('[NotificationService] onNotificationTapped for module: ${payload.module}, eventId: ${payload.eventId}');
    _pendingNotificationPayload = payload;
    _pendingNavigationModule = payload.module;
    if (onNavigatePayload != null) {
      onNavigatePayload?.call(payload);
    } else {
      onNavigate?.call(payload.module);
    }
    if (!_navigationPayloadStreamController.isClosed) {
      _navigationPayloadStreamController.add(payload);
    }
    if (!_navigationStreamController.isClosed) {
      _navigationStreamController.add(payload.module);
    }
  }

  /// Cancels and clears all active notifications from the system notification shade.
  Future<void> cancelAllNotifications() async {
    if (kIsWeb || !_localNotificationsInitialized) return;
    try {
      await _localNotifications.cancelAll();
      debugPrint('[NotificationService] Cleared all system tray notifications');
    } catch (e) {
      debugPrint('[NotificationService] Error cancelling notifications: $e');
    }
  }

  /// Fetches local notification preferences from Drift database.
  Future<NotificationPreferences> getPreferences() async {
    if (appDatabase == null) return const NotificationPreferences();

    final row = await appDatabase!.getNotificationPreferences();
    if (row == null) return const NotificationPreferences();

    return NotificationPreferences(
      muteSubscriptions: row.muteSubscriptions,
      muteLists: row.muteLists,
      muteExpenses: row.muteExpenses,
      muteHabits: row.muteHabits,
      muteCalendar: row.muteCalendar,
    );
  }

  /// Updates local notification preferences in Drift database.
  Future<void> savePreferences(NotificationPreferences prefs) async {
    if (appDatabase == null) return;

    await appDatabase!.saveNotificationPreferences(
      muteSubscriptions: prefs.muteSubscriptions,
      muteLists: prefs.muteLists,
      muteExpenses: prefs.muteExpenses,
      muteHabits: prefs.muteHabits,
      muteCalendar: prefs.muteCalendar,
    );
  }

  /// Returns the default `user_devices.platform` value for the current target
  /// platform (`'android:data-v1'` on Android builds that include 3.14c).
  String defaultPlatformString() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidDataV1Platform;
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      default:
        return 'other';
    }
  }

  StreamSubscription? _fcmMessageSub;
  StreamSubscription? _fcmOpenSub;
  StreamSubscription? _fcmTokenSub;
  ReceivePort? _mainIsolateReceivePort;
  String? _registeredPortName;
  Future<void>? _pendingForwardedFuture;

  /// Waits for any in-flight message forwarded via [registerMainIsolatePort]
  /// to finish [handleIncomingMessage].
  Future<void> waitForForwardedMessage() =>
      _pendingForwardedFuture ?? Future<void>.value();

  /// Registers a [ReceivePort] with [IsolateNameServer] so that while the main
  /// isolate is alive, `_firebaseMessagingBackgroundHandler` forwards incoming
  /// message data here instead of touching SQLite.
  ///
  /// Acknowledges receipt immediately by sending `'received'` on `reply_port`
  /// before processing anything, then runs [handleIncomingMessage].
  void registerMainIsolatePort({String portName = mainIsolatePortName}) {
    unregisterMainIsolatePort(portName: portName);
    final receivePort = ReceivePort();
    _mainIsolateReceivePort = receivePort;
    _registeredPortName = portName;
    IsolateNameServer.removePortNameMapping(portName);
    IsolateNameServer.registerPortWithName(receivePort.sendPort, portName);
    receivePort.listen((dynamic rawMessage) async {
      if (rawMessage is! Map) return;
      final map = rawMessage.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      final replyPort = map['reply_port'];
      if (replyPort is SendPort) {
        replyPort.send('received');
      }
      final rawData = map['data'];
      final data = rawData is Map
          ? rawData.map((k, v) => MapEntry(k.toString(), v))
          : <String, dynamic>{};
      final hasNotificationBlock = map['has_notification_block'] == true;
      final future = handleIncomingMessage(
        data,
        hasNotificationBlock: hasNotificationBlock,
      );
      _pendingForwardedFuture = future.then<void>((_) {}, onError: (_) {});
      try {
        await future;
      } catch (_) {}
    });
  }

  /// Unregisters the main-isolate [ReceivePort] from [IsolateNameServer].
  void unregisterMainIsolatePort({String? portName}) {
    final targetName = portName ?? _registeredPortName ?? mainIsolatePortName;
    if (_mainIsolateReceivePort != null) {
      _mainIsolateReceivePort!.close();
      _mainIsolateReceivePort = null;
      _registeredPortName = null;
      IsolateNameServer.removePortNameMapping(targetName);
    }
  }

  /// Initializes FCM listeners for foreground messages, background taps, and token refresh.
  /// Gracefully catches errors when Firebase is not initialized or platform is unsupported.
  Future<void> initializeFcm({String? fallbackToken}) async {
    registerMainIsolatePort();
    try {
      final fcm = FirebaseMessaging.instance;

      // 1. Immediately attach listeners for background taps and foreground messages
      _fcmOpenSub?.cancel();
      _fcmOpenSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[NotificationService] onMessageOpenedApp received data: ${message.data}');
        final payload = CoveNotificationPayload.fromMap(message.data);
        onNotificationTapped(payload);
      });

      _fcmMessageSub?.cancel();
      _fcmMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[NotificationService] onMessage received in foreground: ${message.data}');
        handleIncomingMessage(
          message.data,
          hasNotificationBlock: message.notification != null,
        );
      });

      // 2. Check if a notification launched the app from a terminated state
      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NotificationService] getInitialMessage found: ${initialMessage.data}');
        final payload = CoveNotificationPayload.fromMap(initialMessage.data);
        onNotificationTapped(payload);
      }

      // 3. Request permissions and register token in background without blocking
      unawaited(() async {
        try {
          await fcm.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          );

          final token = fallbackToken ?? await fcm.getToken();
          if (token != null) {
            await registerDeviceToken(token);
          }

          _fcmTokenSub?.cancel();
          _fcmTokenSub = fcm.onTokenRefresh.listen((newToken) {
            registerDeviceToken(newToken);
          });
        } catch (e) {
          debugPrint('[NotificationService] FCM token registration/permission error: $e');
        }
      }());
    } catch (e) {
      debugPrint('[NotificationService] FCM initialization skipped or unavailable: $e');
      if (fallbackToken != null) {
        unawaited(registerDeviceToken(fallbackToken));
      }
    }
  }

  void dispose() {
    unregisterMainIsolatePort();
    _fcmMessageSub?.cancel();
    _fcmOpenSub?.cancel();
    _fcmTokenSub?.cancel();
    _notificationStreamController.close();
    _navigationStreamController.close();
    _navigationPayloadStreamController.close();
  }
}
