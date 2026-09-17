import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';
import '../profile/partner_profile_controller.dart';
import '../profile/preferences_controller.dart';
import 'notification_models.dart';
import 'notification_service.dart';

// --- SERVICE PROVIDER ---

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final sync = ref.watch(syncEngineProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final user = ref.watch(authProvider).value;
  final partner = ref.watch(partnerProfileProvider);

  final service = NotificationService(
    supabaseClient: supabase,
    syncEngine: sync,
    appDatabase: db,
    getCurrentUserId: () => user?.id,
    getPartnerName: () => partner.displayName,
    getCurrencySymbol: () => ref.read(currencyPreferenceProvider).symbol,
  );

  // Wire sync engine inbound activity into the notification pipeline
  sync.onInboundActivityReceived = (payload) {
    service.handleIncomingMessage(payload.toMap());
  };

  ref.onDispose(() => service.dispose());
  return service;
});

// --- NOTIFICATION PREFERENCES STREAM & CONTROLLER ---

final rawNotificationPreferencesProvider =
    StreamProvider<LocalNotificationPreference?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchNotificationPreferences();
});

class NotificationPreferencesNotifier extends Notifier<NotificationPreferences> {
  @override
  NotificationPreferences build() {
    final rawPrefAsync = ref.watch(rawNotificationPreferencesProvider);
    final row = rawPrefAsync.value;
    if (row != null) {
      return NotificationPreferences(
        muteSubscriptions: row.muteSubscriptions,
        muteLists: row.muteLists,
        muteExpenses: row.muteExpenses,
        muteHabits: row.muteHabits,
        muteCalendar: row.muteCalendar,
      );
    }

    return const NotificationPreferences();
  }

  Future<void> toggleModule(NotificationModule module) async {
    final isCurrentlyMuted = state.isMuted(module);
    await setModuleMuted(module, !isCurrentlyMuted);
  }

  Future<void> setModuleMuted(NotificationModule module, bool muted) async {
    final db = ref.read(appDatabaseProvider);
    NotificationPreferences updated;
    switch (module) {
      case NotificationModule.subscriptions:
        updated = state.copyWith(muteSubscriptions: muted);
        break;
      case NotificationModule.lists:
        updated = state.copyWith(muteLists: muted);
        break;
      case NotificationModule.expenses:
        updated = state.copyWith(muteExpenses: muted);
        break;
      case NotificationModule.habits:
        updated = state.copyWith(muteHabits: muted);
        break;
      case NotificationModule.calendar:
        updated = state.copyWith(muteCalendar: muted);
        break;
      case NotificationModule.activity:
      case NotificationModule.home:
        return;
    }

    state = updated;
    await db.saveNotificationPreferences(
      muteSubscriptions: updated.muteSubscriptions,
      muteLists: updated.muteLists,
      muteExpenses: updated.muteExpenses,
      muteHabits: updated.muteHabits,
      muteCalendar: updated.muteCalendar,
    );
  }
}

final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
        NotificationPreferencesNotifier.new);

// --- DEEP LINK NAVIGATION DISPATCHER ---

class NotificationNavigationNotifier extends Notifier<NotificationModule?> {
  @override
  NotificationModule? build() => null;

  void navigateTo(NotificationModule? module) => state = module;
}

/// Dispatches requested module destination when a notification is tapped
final notificationNavigationProvider =
    NotifierProvider<NotificationNavigationNotifier, NotificationModule?>(
        NotificationNavigationNotifier.new);
