import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../sync/crypto/sodium_crypto_service.dart';
import '../../sync/db/app_database.dart';
import '../../sync/key_management/home_key_store.dart';
import '../../sync/key_management/pairing_payload.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';
import '../auth/auth_controller.dart';

class HomeController {
  final Ref ref;

  HomeController(this.ref);

  AppDatabase get _db => ref.read(appDatabaseProvider);
  HomeKeyStore get _keyStore => ref.read(homeKeyStoreProvider);
  SodiumCryptoService get _crypto => ref.read(sodiumCryptoServiceProvider);

  /// Creates a new shared household, generates its 256-bit encryption key,
  /// saves it to secure storage, and returns the PairingPayload for the QR code.
  Future<PairingPayload> createHome({
    required String name,
    String? description,
  }) async {
    final user = ref.read(authProvider).value;
    final userId = user?.id ?? 'local_user';
    final now = DateTime.now().toUtc();
    final homeId = _generateUuid();

    // 1. Generate 256-bit symmetric encryption key
    final symmetricKey = _crypto.generateHomeKey();

    // 2. Persist symmetric key securely on-device
    await _keyStore.saveKey(homeId, symmetricKey);

    // 3. Insert into local Drift database
    await _db.into(_db.localHomes).insertOnConflictUpdate(
          LocalHomesCompanion.insert(
            id: homeId,
            name: name,
            description: drift.Value(description),
            icon: drift.Value(null), // Deterministic icon mark
            createdAt: now,
            createdBy: userId,
          ),
        );

    // 4. Insert into Supabase if connected
    final supabase = ref.read(supabaseClientProvider);
    if (supabase != null) {
      try {
        await supabase.from('homes').insert({
          'id': homeId,
          'name': name,
          'description': description,
          'icon': null,
          'created_at': now.toIso8601String(),
          'created_by': userId,
        });

        await supabase.from('home_members').insert({
          'home_id': homeId,
          'user_id': userId,
          'joined_at': now.toIso8601String(),
        });
      } catch (_) {
        // Continue gracefully in offline mode
      }
    }

    // 5. Set as active Home
    ref.read(activeHomeIdProvider.notifier).setActiveHome(homeId);

    // 6. Start Sync Engine with this home
    final engine = ref.read(syncEngineProvider);
    await engine.start(activeHomeId: homeId, activeHomeKey: symmetricKey);

    return PairingPayload(
      homeId: homeId,
      homeName: name,
      symmetricKey: symmetricKey,
      inviterId: userId,
      createdAt: now,
    );
  }

  /// Joins a Home using a scanned or pasted Pairing QR string.
  Future<void> joinHomeFromQr(String qrString) async {
    final payload = PairingPayload.fromQrString(qrString);
    final user = ref.read(authProvider).value;
    final userId = user?.id ?? 'local_user';
    final now = DateTime.now().toUtc();

    // 1. Save imported symmetric key securely on-device
    await _keyStore.saveKey(payload.homeId, payload.symmetricKey);

    // 2. Store home record in local Drift projections
    await _db.into(_db.localHomes).insertOnConflictUpdate(
          LocalHomesCompanion.insert(
            id: payload.homeId,
            name: payload.homeName,
            createdAt: payload.createdAt,
            createdBy: payload.inviterId,
          ),
        );

    // 3. Add membership in Supabase if connected
    final supabase = ref.read(supabaseClientProvider);
    if (supabase != null) {
      try {
        await supabase.from('home_members').insert({
          'home_id': payload.homeId,
          'user_id': userId,
          'joined_at': now.toIso8601String(),
        });
      } catch (_) {
        // Continue gracefully
      }
    }

    // 4. Set as active Home
    ref.read(activeHomeIdProvider.notifier).setActiveHome(payload.homeId);

    // 5. Start Sync Engine
    final engine = ref.read(syncEngineProvider);
    await engine.start(
      activeHomeId: payload.homeId,
      activeHomeKey: payload.symmetricKey,
    );
  }

  /// Retrieves an existing pairing payload for a Home (to show QR code again).
  Future<PairingPayload?> getPairingPayload(String homeId) async {
    final key = await _keyStore.getKey(homeId);
    if (key == null) return null;

    final home = await (_db.select(_db.localHomes)
          ..where((t) => t.id.equals(homeId)))
        .getSingleOrNull();
    if (home == null) return null;

    final user = ref.read(authProvider).value;
    return PairingPayload(
      homeId: home.id,
      homeName: home.name,
      symmetricKey: key,
      inviterId: user?.id ?? home.createdBy,
      createdAt: home.createdAt,
    );
  }

  /// Leaves a home, cleans up keys and local data.
  Future<void> leaveHome(String homeId) async {
    await _keyStore.removeKey(homeId);

    final supabase = ref.read(supabaseClientProvider);
    final user = ref.read(authProvider).value;
    if (supabase != null && user != null) {
      try {
        await supabase
            .from('home_members')
            .delete()
            .match({'home_id': homeId, 'user_id': user.id});
      } catch (_) {}
    }

    await (_db.delete(_db.localHomes)..where((t) => t.id.equals(homeId))).go();

    // If leaving active home, switch to remaining home if any
    final remainingHomes = await _db.select(_db.localHomes).get();
    if (remainingHomes.isNotEmpty) {
      ref
          .read(activeHomeIdProvider.notifier)
          .setActiveHome(remainingHomes.first.id);
    } else {
      ref.read(activeHomeIdProvider.notifier).setActiveHome('');
    }
  }

  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch.toString();
    final hash = (random.hashCode & 0x7FFFFFFF).toRadixString(16).padLeft(8, '0');
    final p1 = (DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF)
        .toRadixString(16)
        .padLeft(8, '0');
    return '$p1-$hash-4000-8000-${DateTime.now().microsecond.toRadixString(16).padLeft(12, '0')}';
  }
}

final homeControllerProvider = Provider<HomeController>((ref) {
  return HomeController(ref);
});
