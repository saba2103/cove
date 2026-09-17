import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/profile/user_profile_controller.dart';
import '../crypto/sodium_crypto_service.dart';
import '../db/app_database.dart';
import '../db/local_state_store_impl.dart';
import '../event_store_impl.dart';
import '../key_management/home_key_store.dart';
import '../sync_engine_impl.dart';
import 'active_home_provider.dart';

// --- CORE INFRASTRUCTURE PROVIDERS ---

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final homeKeyStoreProvider = Provider<HomeKeyStore>((ref) {
  return HomeKeyStore();
});

final sodiumCryptoServiceProvider = Provider<SodiumCryptoService>((ref) {
  return SodiumCryptoService();
});

final localStateStoreProvider = Provider<LocalStateStoreImpl>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return LocalStateStoreImpl(db);
});

final eventStoreProvider = Provider<EventStoreImpl>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final crypto = ref.watch(sodiumCryptoServiceProvider);
  return EventStoreImpl(db: db, cryptoService: crypto);
});

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null; // Gracefully null when running offline or without init
  }
});

final syncEngineProvider = Provider<SyncEngineImpl>((ref) {
  final eventStore = ref.watch(eventStoreProvider);
  final localStateStore = ref.watch(localStateStoreProvider);
  final crypto = ref.watch(sodiumCryptoServiceProvider);
  final keyStore = ref.watch(homeKeyStoreProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final engine = SyncEngineImpl(
    eventStore: eventStore,
    localStateStore: localStateStore,
    encryptionService: crypto,
    keyStore: keyStore,
    supabaseClient: supabase,
    getCurrentUserId: () =>
        ref.read(authProvider).value?.id ??
        supabase?.auth.currentUser?.id ??
        'local_user',
    getActiveHomeId: () => ref.read(activeHomeIdProvider),
  );

  ref.onDispose(() => engine.stop());
  return engine;
});

// --- FEATURE FACING API: EMIT ACTIONS ---

/// Simple action emitter function exposed to feature modules:
/// `emit(eventType: 'list_item_added', payload: { ... })`
typedef CoveEventEmitter = Future<void> Function({
  required String eventType,
  required Map<String, dynamic> payload,
  String? targetHomeId,
});

final coveEmitActionProvider = Provider<CoveEventEmitter>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return ({
    required String eventType,
    required Map<String, dynamic> payload,
    String? targetHomeId,
  }) async {
    final userProfile = ref.read(userProfileProvider);
    final enrichedPayload = Map<String, dynamic>.from(payload);
    if (!enrichedPayload.containsKey('actor_name') &&
        userProfile.displayName.isNotEmpty &&
        userProfile.displayName != 'You') {
      enrichedPayload['actor_name'] = userProfile.displayName;
    }
    await engine.dispatchLocalEvent(
      eventType: eventType,
      payload: enrichedPayload,
      homeId: targetHomeId,
    );
  };
});

// --- FEATURE FACING REACTIVE STATE STREAMS (Active Home Scoped) ---

final activeHomeListsProvider = StreamProvider<List<LocalList>>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchLists(activeId);
});

final activeHomeListItemsProvider =
    StreamProvider.family<List<LocalListItem>, String>((ref, listId) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchListItems(activeId, listId);
});

final activeHomeAllListItemsProvider = StreamProvider<List<LocalListItem>>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllHomeListItems(activeId);
});


final activeHomeSubscriptionsProvider =
    StreamProvider<List<LocalSubscription>>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  final user = ref.watch(authProvider).value;
  return db.watchSubscriptions(activeId, currentUserId: user?.id);
});

final activeHomeExpensesProvider = StreamProvider<List<LocalExpense>>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  final user = ref.watch(authProvider).value;
  return db.watchExpenses(activeId, currentUserId: user?.id);
});

final activeHomeHabitsProvider = StreamProvider<List<LocalHabit>>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  final user = ref.watch(authProvider).value;
  return db.watchHabits(activeId, currentUserId: user?.id);
});

final activeHomeHabitCheckinsProvider =
    StreamProvider.family<List<LocalHabitCheckin>, String>((ref, habitId) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchHabitCheckins(activeId, habitId);
});

final activeHomeAllHabitCheckinsProvider =
    StreamProvider<List<LocalHabitCheckin>>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllHabitCheckins(activeId);
});

final activeHomeCalendarEventsProvider =
    StreamProvider<List<LocalCalendarEvent>>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchCalendarEvents(activeId);
});

final activeHomeOutboxProvider = StreamProvider<List<LocalOutboxEvent>>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  if (activeId == null) return Stream.value([]);
  final db = ref.watch(appDatabaseProvider);
  return db.watchOutbox(activeId);
});
