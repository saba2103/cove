import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/profile/partner_profile_controller.dart';
import '../db/app_database.dart';
import 'active_home_provider.dart';
import 'cove_sync_providers.dart';

/// The seven first-run screens (`design/specs/16-first-run.md` §3).
enum CoveScreen {
  today,
  calendar,
  routines,
  expenses,
  commitments,
  activity,
  ourHome;

  /// Per-home preference key (`first_run_done.<screen>.<homeId>`).
  String prefKeyFor(String homeId) => 'first_run_done.$name.$homeId';

  /// Legacy global preference key (`first_run_done.<screen>`), migrated once
  /// to the current active home only.
  String get legacyGlobalPrefKey => 'first_run_done.$name';
}

/// The three states returned by [firstRunProvider]:
/// - [loading]: until both the database counts for the active home have emitted
///   at least once and [SharedPreferences] have loaded. While [loading], each
///   screen renders its normal in-use layout, never the seed card.
/// - [firstRun]: the home has zero records for this screen and the per-home
///   preference flag has never been set.
/// - [inUse]: the screen has seen at least one record in this home (or its
///   per-home preference flag is set).
enum FirstRunState {
  loading,
  firstRun,
  inUse;

  bool get isFirstRun => this == FirstRunState.firstRun;
  bool get isLoading => this == FirstRunState.loading;
  bool get isInUse => this == FirstRunState.inUse;
}

/// Loads [SharedPreferences] so [firstRunProvider] can read and persist
/// `first_run_done.<screen>.<homeId>` flags.
final firstRunSharedPrefsProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Container-scoped synchronous cache of `first_run_done.<screen>.<homeId>`
/// flags, backed by [SharedPreferences].
class FirstRunDoneStore {
  final Set<String> _doneKeys = <String>{};
  String? _migratedLegacyForHomeId;

  /// If any legacy global key (`first_run_done.<screen>`) is set in [prefs],
  /// migrates it to `first_run_done.<screen>.<activeHomeId>` for the current
  /// active home only and removes the legacy global key.
  void migrateLegacyGlobalKeysIfNeeded(
    SharedPreferences prefs,
    String activeHomeId,
  ) {
    if (_migratedLegacyForHomeId != null) return;
    _migratedLegacyForHomeId = activeHomeId;
    for (final screen in CoveScreen.values) {
      final legacyKey = screen.legacyGlobalPrefKey;
      if (prefs.getBool(legacyKey) == true) {
        final perHomeKey = screen.prefKeyFor(activeHomeId);
        _doneKeys.add(perHomeKey);
        unawaited(prefs.setBool(perHomeKey, true));
        unawaited(prefs.remove(legacyKey));
      }
    }
  }

  bool isDone(CoveScreen screen, SharedPreferences prefs, String homeId) {
    migrateLegacyGlobalKeysIfNeeded(prefs, homeId);
    final key = screen.prefKeyFor(homeId);
    if (_doneKeys.contains(key)) {
      return true;
    }
    if (prefs.getBool(key) == true) {
      _doneKeys.add(key);
      return true;
    }
    return false;
  }

  void markDone(CoveScreen screen, SharedPreferences prefs, String homeId) {
    migrateLegacyGlobalKeysIfNeeded(prefs, homeId);
    final key = screen.prefKeyFor(homeId);
    final alreadyMarked = _doneKeys.contains(key);
    _doneKeys.add(key);
    if (!alreadyMarked) {
      unawaited(prefs.setBool(key, true));
    }
  }
}

final firstRunDoneStoreProvider = Provider<FirstRunDoneStore>((ref) {
  return FirstRunDoneStore();
});

/// Streams live [FirstRunCounts] from [AppDatabase] for the given [homeId].
final firstRunDbCountsStreamProvider =
    StreamProvider.family<FirstRunCounts, String>((ref, homeId) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchFirstRunCounts(homeId);
});

/// Resolves `{partner}` for first-run copy (`design/specs/16-first-run.md` §4):
/// returns the partner's display name once known/joined, or `"your partner"`
/// before they join.
String resolveFirstRunPartnerName(WidgetRef ref) {
  final partnerProfile = ref.watch(partnerProfileProvider);
  final hasPartner = ref.watch(activeHomeHasPartnerProvider);
  final name = partnerProfile.displayName.trim();
  if (name.isNotEmpty &&
      name != 'Partner' &&
      (hasPartner || partnerProfile.hasCustomName)) {
    return name;
  }
  return 'your partner';
}

/// First-run rule (`design/specs/16-first-run.md` §3):
/// `firstRunProvider(CoveScreen)` → [FirstRunState].
///
/// Returns [FirstRunState.loading] until both the database counts for the
/// active home have emitted at least once and [SharedPreferences] have loaded.
/// Reads only the database counts and the `first_run_done.<screen>.<homeId>`
/// preference, flipping the preference the first time it sees data.
final firstRunProvider =
    Provider.family<FirstRunState, CoveScreen>((ref, screen) {
  final homeId = ref.watch(activeHomeIdProvider);
  if (homeId == null || homeId.isEmpty) {
    return FirstRunState.loading;
  }

  final countsAsync = ref.watch(firstRunDbCountsStreamProvider(homeId));
  final prefsAsync = ref.watch(firstRunSharedPrefsProvider);

  if (!countsAsync.hasValue || !prefsAsync.hasValue) {
    return FirstRunState.loading;
  }

  final counts = countsAsync.requireValue;
  final prefs = prefsAsync.requireValue;
  final doneStore = ref.watch(firstRunDoneStoreProvider);

  final bool hasData = switch (screen) {
    CoveScreen.today => (counts.expenses +
            counts.events +
            counts.habits +
            counts.listItems +
            counts.commitments +
            counts.routineEvents) >
        0,
    CoveScreen.calendar => (counts.events +
            counts.expenses +
            counts.listItems +
            counts.habitCheckins) >
        0,
    CoveScreen.routines => counts.routineEvents > 0,
    CoveScreen.expenses => counts.expenses > 0,
    CoveScreen.commitments => counts.commitments > 0,
    CoveScreen.activity => counts.activity > 0,
    CoveScreen.ourHome => counts.hasPartnerInDb,
  };

  if (hasData) {
    doneStore.markDone(screen, prefs, homeId);
    return FirstRunState.inUse;
  }

  if (doneStore.isDone(screen, prefs, homeId)) {
    return FirstRunState.inUse;
  }

  return FirstRunState.firstRun;
});
