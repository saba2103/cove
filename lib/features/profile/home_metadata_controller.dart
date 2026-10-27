import 'package:clock/clock.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../sync/db/app_database.dart';
import '../../sync/providers/active_home_provider.dart';
import '../../sync/providers/cove_sync_providers.dart';

class HomeMetadataState {
  final String homeId;
  final DateTime? anniversaryDate;
  final String? formattedTogetherDuration;

  const HomeMetadataState({
    required this.homeId,
    this.anniversaryDate,
    this.formattedTogetherDuration,
  });

  static String? formatDuration(DateTime? anniversaryDate) {
    if (anniversaryDate == null) return null;
    final now = clock.now().toLocal();
    final annivLocal = anniversaryDate.toLocal();
    if (annivLocal.isAfter(now)) return null;

    int years = now.year - annivLocal.year;
    int months = now.month - annivLocal.month;
    if (now.day < annivLocal.day) {
      months -= 1;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }

    if (years <= 0 && months <= 0) {
      return 'Just started your journey together';
    } else if (years <= 0) {
      return 'Together for $months ${months == 1 ? 'month' : 'months'}';
    } else if (months == 0) {
      return 'Together for $years ${years == 1 ? 'year' : 'years'}';
    } else {
      return 'Together for $years ${years == 1 ? 'year' : 'years'}, $months ${months == 1 ? 'month' : 'months'}';
    }
  }
}

class HomeMetadataNotifier extends Notifier<HomeMetadataState> {
  static const _storage = FlutterSecureStorage();
  static const _anniversaryKeyPrefix = 'cove_home_anniversary_';

  @override
  HomeMetadataState build() {
    final homeAsync = ref.watch(activeHomeProvider);
    final home = homeAsync.value;
    final homeId = ref.watch(activeHomeIdProvider) ?? '';

    if (home != null) {
      return HomeMetadataState(
        homeId: home.id,
        anniversaryDate: home.anniversaryDate,
        formattedTogetherDuration: HomeMetadataState.formatDuration(home.anniversaryDate),
      );
    }

    if (homeId.isNotEmpty) {
      _loadAnniversaryDate(homeId);
    }
    return HomeMetadataState(homeId: homeId);
  }

  Future<void> _loadAnniversaryDate(String homeId) async {
    if (homeId.isEmpty) return;
    try {
      final raw = await _storage.read(key: '$_anniversaryKeyPrefix$homeId');
      if (raw != null && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null && state.anniversaryDate == null) {
          state = HomeMetadataState(
            homeId: homeId,
            anniversaryDate: parsed,
            formattedTogetherDuration: HomeMetadataState.formatDuration(parsed),
          );
          // Self-heal SQLite if empty
          final db = ref.read(appDatabaseProvider);
          await (db.update(db.localHomes)..where((t) => t.id.equals(homeId))).write(
            LocalHomesCompanion(anniversaryDate: drift.Value(parsed)),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> setAnniversaryDate(DateTime? date) async {
    final homeId = state.homeId.isNotEmpty
        ? state.homeId
        : (ref.read(activeHomeIdProvider) ?? '');
    if (homeId.isEmpty) return;

    state = HomeMetadataState(
      homeId: homeId,
      anniversaryDate: date,
      formattedTogetherDuration: HomeMetadataState.formatDuration(date),
    );

    // 1. Update Drift SQLite database
    try {
      final db = ref.read(appDatabaseProvider);
      await (db.update(db.localHomes)..where((t) => t.id.equals(homeId))).write(
        LocalHomesCompanion(anniversaryDate: drift.Value(date)),
      );
    } catch (_) {}

    // 2. Update secure storage fallback
    try {
      if (date != null) {
        await _storage.write(
          key: '$_anniversaryKeyPrefix$homeId',
          value: date.toIso8601String(),
        );
      } else {
        await _storage.delete(key: '$_anniversaryKeyPrefix$homeId');
      }
    } catch (_) {}

    // 3. Emit home_anniversary_updated sync event so partner updates
    try {
      final emitAction = ref.read(coveEmitActionProvider);
      await emitAction(
        eventType: 'home_anniversary_updated',
        payload: {
          'id': homeId,
          'anniversary_date': date?.toIso8601String(),
        },
        targetHomeId: homeId,
      );
    } catch (_) {}
  }

  Future<void> updateHomeDetails({
    required String name,
    String? description,
    DateTime? anniversaryDate,
  }) async {
    final homeId = state.homeId.isNotEmpty
        ? state.homeId
        : (ref.read(activeHomeIdProvider) ?? '');
    if (homeId.isEmpty) return;

    // 1. Update state
    state = HomeMetadataState(
      homeId: homeId,
      anniversaryDate: anniversaryDate,
      formattedTogetherDuration: HomeMetadataState.formatDuration(anniversaryDate),
    );

    // 2. Update local Drift database projection
    final db = ref.read(appDatabaseProvider);
    try {
      await (db.update(db.localHomes)..where((t) => t.id.equals(homeId))).write(
        LocalHomesCompanion(
          name: drift.Value(name.trim()),
          description: drift.Value(description?.trim()),
          anniversaryDate: drift.Value(anniversaryDate),
        ),
      );
    } catch (_) {}

    // 3. Update secure storage fallback
    try {
      if (anniversaryDate != null) {
        await _storage.write(
          key: '$_anniversaryKeyPrefix$homeId',
          value: anniversaryDate.toIso8601String(),
        );
      } else {
        await _storage.delete(key: '$_anniversaryKeyPrefix$homeId');
      }
    } catch (_) {}

    // 4. Emit home_updated sync action for partner
    try {
      final emitAction = ref.read(coveEmitActionProvider);
      await emitAction(
        eventType: 'home_updated',
        payload: {
          'id': homeId,
          'name': name.trim(),
          'description': description?.trim(),
          'anniversary_date': anniversaryDate?.toIso8601String(),
        },
        targetHomeId: homeId,
      );
    } catch (_) {
      // Continue gracefully in offline / test mode
    }
  }
}

final homeMetadataProvider =
    NotifierProvider<HomeMetadataNotifier, HomeMetadataState>(HomeMetadataNotifier.new);
