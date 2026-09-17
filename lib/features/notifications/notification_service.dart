import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../sync/db/app_database.dart';
import '../../sync/sync_engine.dart';
import 'notification_formatter.dart';
import 'notification_models.dart';

class NotificationService {
  final SupabaseClient? supabaseClient;
  final SyncEngine? syncEngine;
  final AppDatabase? appDatabase;
  final String? Function()? getCurrentUserId;
  final String? Function()? getPartnerName;
  final String? Function()? getCurrencySymbol;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _localNotificationsInitialized = false;

  final StreamController<CoveNotificationPayload> _notificationStreamController =
      StreamController<CoveNotificationPayload>.broadcast();

  final StreamController<NotificationModule> _navigationStreamController =
      StreamController<NotificationModule>.broadcast();

  NotificationService({
    this.supabaseClient,
    this.syncEngine,
    this.appDatabase,
    this.getCurrentUserId,
    this.getPartnerName,
    this.getCurrencySymbol,
  });


  Stream<CoveNotificationPayload> get onNotificationReceived =>
      _notificationStreamController.stream;

  Stream<NotificationModule> get onNavigateToModule =>
      _navigationStreamController.stream;

  String? get currentUserId =>
      getCurrentUserId?.call() ?? supabaseClient?.auth.currentUser?.id;

  /// Registers an FCM token against the user's account in public.user_devices.
  Future<bool> registerDeviceToken(String token, {String? platform}) async {
    final uid = currentUserId;
    if (uid == null || supabaseClient == null) return false;

    try {
      final detectedPlatform = platform ?? _defaultPlatform();
      await supabaseClient!.from('user_devices').upsert({
        'user_id': uid,
        'fcm_token': token,
        'platform': detectedPlatform,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
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
      final formatted = NotificationFormatter.format(
        eventType: payload.eventType,
        payload: const {},
        actorName: partnerName,
        preferredCurrencySymbol: getCurrencySymbol?.call(),
      );
      return payload.copyWith(
        actorName: partnerName,
        title: formatted.title,
        body: formatted.body,
      );
    }

    return payload;
  }

  /// Handles incoming push notification payloads.
  /// 1. Silently wakes the sync engine to fetch & decrypt latest partner events.
  /// 2. Evaluates local per-module mute preferences before deciding to show an alert/banner.
  Future<CoveNotificationPayload?> handleIncomingMessage(
      Map<String, dynamic> data) async {
    final payload = CoveNotificationPayload.fromMap(
      data,
      preferredCurrencySymbol: getCurrencySymbol?.call(),
    );

    final eId = payload.eventId;
    if (eId != null && eId.isNotEmpty) {
      if (_recentNotifiedEventIds.contains(eId)) {
        return null;
      }
      _recentNotifiedEventIds.add(eId);
      if (_recentNotifiedEventIds.length > 200) {
        _recentNotifiedEventIds.remove(_recentNotifiedEventIds.first);
      }
    }

    // 1. Silent sync wake: pull unread events so decrypted data is ready
    if (syncEngine != null && payload.homeId.isNotEmpty) {
      try {
        await syncEngine!.pullLatestEvents(homeId: payload.homeId);
      } catch (e) {
        debugPrint('[NotificationService] Error pulling latest events: $e');
      }
    }

    // Profile, avatar, and settings updates are internal sync operations and must NOT generate notifications
    const silentSyncEvents = {
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
    };

    if (silentSyncEvents.contains(payload.eventType)) {
      return null;
    }

    // Enrich payload with decrypted details and partner name from local SQLite
    final enrichedPayload = await enrichPayload(payload);

    // 2. Evaluate local notification preferences
    final prefs = await getPreferences();
    if (prefs.isMuted(enrichedPayload.module)) {
      debugPrint(
          '[NotificationService] Notification for ${enrichedPayload.module.name} is muted locally. Silent wake only.');
      return null;
    }

    // 3. Trigger local Android / iOS system notification
    unawaited(showLocalNotification(enrichedPayload));

    // 4. Emit notification event for in-app floating banner display
    if (!_notificationStreamController.isClosed) {
      _notificationStreamController.add(enrichedPayload);
    }
    return enrichedPayload;
  }

  /// Initializes local notifications plugin for Android / iOS.
  Future<void> initializeLocalNotifications() async {
    if (kIsWeb) return;
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
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
            'cove_partner_activity',
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
    } catch (e) {
      debugPrint('[NotificationService] Local notifications initialization error: $e');
    }
  }

  /// Displays a heads-up system notification in the device tray.
  Future<void> showLocalNotification(CoveNotificationPayload payload) async {
    if (kIsWeb) return;
    try {
      if (!_localNotificationsInitialized) {
        await initializeLocalNotifications();
      }

      final styleInformation = BigTextStyleInformation(
        payload.body,
        contentTitle: payload.title,
        summaryText: payload.module.displayName,
      );

      final androidDetails = AndroidNotificationDetails(
        'cove_partner_activity',
        'Partner Activity',
        channelDescription:
            'Realtime updates and notifications for household activity',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Cove Partner Update',
        icon: '@mipmap/ic_launcher',
        styleInformation: styleInformation,
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

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _localNotifications.show(
        id: id,
        title: payload.title,
        body: payload.body,
        notificationDetails: details,
        payload: jsonEncode(payload.toMap()),
      );
    } catch (e) {
      debugPrint('[NotificationService] Error displaying local notification: $e');
    }
  }

  /// Dispatches a deep link navigation action to open the appropriate module screen.
  void onNotificationTapped(CoveNotificationPayload payload) {
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

  String _defaultPlatform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
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

  /// Initializes FCM listeners for foreground messages, background taps, and token refresh.
  /// Gracefully catches errors when Firebase is not initialized or platform is unsupported.
  Future<void> initializeFcm({String? fallbackToken}) async {
    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = fallbackToken ?? await fcm.getToken();
      if (token != null) {
        await registerDeviceToken(token);
      }

      final initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        final payload = CoveNotificationPayload.fromMap(initialMessage.data);
        onNotificationTapped(payload);
      }

      _fcmTokenSub?.cancel();
      _fcmTokenSub = fcm.onTokenRefresh.listen((newToken) {
        registerDeviceToken(newToken);
      });

      _fcmMessageSub?.cancel();
      _fcmMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        handleIncomingMessage(message.data);
      });

      _fcmOpenSub?.cancel();
      _fcmOpenSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final payload = CoveNotificationPayload.fromMap(message.data);
        onNotificationTapped(payload);
      });
    } catch (e) {
      debugPrint('[NotificationService] FCM initialization skipped or unavailable: $e');
      if (fallbackToken != null) {
        await registerDeviceToken(fallbackToken);
      }
    }
  }

  void dispose() {
    _fcmMessageSub?.cancel();
    _fcmOpenSub?.cancel();
    _fcmTokenSub?.cancel();
    _notificationStreamController.close();
    _navigationStreamController.close();
  }
}
