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
    final now = DateTime.now();
    if (anniversaryDate.isAfter(now)) return null;

    int years = now.year - anniversaryDate.year;
    int months = now.month - anniversaryDate.month;
    if (now.day < anniversaryDate.day) {
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
    final homeId = ref.watch(activeHomeIdProvider) ?? '';
    _loadAnniversaryDate(homeId);
    return HomeMetadataState(homeId: homeId);
  }

  Future<void> _loadAnniversaryDate(String homeId) async {
    if (homeId.isEmpty) return;
    try {
      final raw = await _storage.read(key: '$_anniversaryKeyPrefix$homeId');
      if (raw != null && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) {
          state = HomeMetadataState(
            homeId: homeId,
            anniversaryDate: parsed,
            formattedTogetherDuration: HomeMetadataState.formatDuration(parsed),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> setAnniversaryDate(DateTime? date) async {
    final homeId = state.homeId;
    if (homeId.isEmpty) return;

    state = HomeMetadataState(
      homeId: homeId,
      anniversaryDate: date,
      formattedTogetherDuration: HomeMetadataState.formatDuration(date),
    );

    if (date != null) {
      await _storage.write(
        key: '$_anniversaryKeyPrefix$homeId',
        value: date.toIso8601String(),
      );
    } else {
      await _storage.delete(key: '$_anniversaryKeyPrefix$homeId');
    }
  }

  Future<void> updateHomeDetails({
    required String name,
    String? description,
    DateTime? anniversaryDate,
  }) async {
    final homeId = state.homeId;
    if (homeId.isEmpty) return;

    // 1. Update anniversary date locally
    await setAnniversaryDate(anniversaryDate);

    // 2. Update local Drift database projection
    final db = ref.read(appDatabaseProvider);
    final home = await (db.select(db.localHomes)..where((t) => t.id.equals(homeId))).getSingleOrNull();
    if (home != null) {
      await (db.update(db.localHomes)..where((t) => t.id.equals(homeId))).write(
        LocalHomesCompanion(
          name: drift.Value(name.trim()),
          description: drift.Value(description?.trim()),
        ),
      );
    }

    // 3. Emit home_updated sync action for partner
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
