import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/profile/partner_profile_controller.dart';
import '../../features/routines/routine_controller.dart';
import '../db/app_database.dart';
import 'active_home_provider.dart';
import 'cove_sync_providers.dart';

/// The seven first-run screens (`design/specs/16-first-run.md` §3).
enum CoveScreen {
  today('today'),
  calendar('calendar'),
  routines('routines'),
  expenses('expenses'),
  commitments('commitments'),
  activity('activity'),
  ourHome('our_home');

  final String slug;
  const CoveScreen(this.slug);

  /// Primary local-preference key (`first_run_done.<screen>`).
  String get prefKey => 'first_run_done.$name';

  /// Alternate snake_case preference key (`first_run_done.<slug>`).
  String get slugPrefKey => 'first_run_done.$slug';
}

/// Loads [SharedPreferences] so [firstRunProvider] can read and persist
/// `first_run_done.<screen>` flags.
final firstRunSharedPrefsProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Container-scoped synchronous cache of `first_run_done.<screen>` flags,
/// backed by [SharedPreferences].
class FirstRunDoneStore {
  final Set<String> _doneKeys = <String>{};

  bool isDone(CoveScreen screen, SharedPreferences? prefs, String homeKey) {
    if (_doneKeys.contains('$homeKey:${screen.prefKey}') ||
        _doneKeys.contains(screen.prefKey) ||
        _doneKeys.contains(screen.slugPrefKey)) {
      return true;
    }
    if (prefs != null) {
      final fromPrefs = (prefs.getBool(screen.prefKey) ?? false) ||
          (prefs.getBool(screen.slugPrefKey) ?? false) ||
          (prefs.getBool('${screen.prefKey}.$homeKey') ?? false);
      if (fromPrefs) {
        _doneKeys.add('$homeKey:${screen.prefKey}');
        _doneKeys.add(screen.prefKey);
        _doneKeys.add(screen.slugPrefKey);
        return true;
      }
    }
    return false;
  }

  void markDone(CoveScreen screen, SharedPreferences? prefs, String homeKey) {
    final alreadyMarked = _doneKeys.contains('$homeKey:${screen.prefKey}') &&
        _doneKeys.contains(screen.prefKey);
    _doneKeys.add('$homeKey:${screen.prefKey}');
    _doneKeys.add(screen.prefKey);
    _doneKeys.add(screen.slugPrefKey);
    if (!alreadyMarked) {
      if (prefs != null) {
        unawaited(prefs.setBool(screen.prefKey, true));
        if (screen.slugPrefKey != screen.prefKey) {
          unawaited(prefs.setBool(screen.slugPrefKey, true));
        }
        unawaited(prefs.setBool('${screen.prefKey}.$homeKey', true));
      } else {
        unawaited(
          SharedPreferences.getInstance().then((p) {
            unawaited(p.setBool(screen.prefKey, true));
            if (screen.slugPrefKey != screen.prefKey) {
              unawaited(p.setBool(screen.slugPrefKey, true));
            }
            unawaited(p.setBool('${screen.prefKey}.$homeKey', true));
          }),
        );
      }
    }
  }
}

final firstRunDoneStoreProvider = Provider<FirstRunDoneStore>((ref) {
  return FirstRunDoneStore();
});

/// Streams live [FirstRunCounts] from [AppDatabase] for the given home key.
final firstRunDbCountsStreamProvider =
    StreamProvider.family<FirstRunCounts, String>((ref, homeKey) {
  final db = ref.watch(appDatabaseProvider);
  try {
    return db.watchFirstRunCounts(homeKey);
  } catch (_) {
    return Stream.value(FirstRunCounts.empty);
  }
});

/// Resolves the effective [FirstRunCounts] for the active home by combining
/// the database count query with any active stream overrides.
final firstRunCountsProvider = Provider<FirstRunCounts>((ref) {
  final activeId = ref.watch(activeHomeIdProvider);
  final homeKey = (activeId == null || activeId.isEmpty) ? '*' : activeId;
  final db = ref.watch(appDatabaseProvider);

  // Subscribe to DB count updates so Riverpod invalidates whenever tables change.
  final streamCounts = ref.watch(firstRunDbCountsStreamProvider(homeKey)).value;

  FirstRunCounts dbCounts = streamCounts ?? FirstRunCounts.empty;
  try {
    final cached = db.cachedFirstRunCounts[homeKey] ??
        db.cachedFirstRunCounts['*'];
    if (cached != null) {
      dbCounts = cached;
    }
    final sub = db.firstRunCountsUpdates.stream.listen((updatedKey) {
      if (updatedKey == homeKey || updatedKey == '*' || homeKey == '*') {
        ref.invalidateSelf();
      }
    });
    ref.onDispose(sub.cancel);
  } catch (_) {
    // Stub/Fake AppDatabase in golden tests — rely on stream providers below.
  }

  // Also observe the active-home stream providers so tests that override streams
  // (e.g. screens_golden_test.dart) reflect their seeded records automatically.
  final expensesStream = ref.watch(activeHomeExpensesProvider).value;
  final subsStream = ref.watch(activeHomeSubscriptionsProvider).value;
  final eventsStream = ref.watch(activeHomeCalendarEventsProvider).value;
  final listItemsStream = ref.watch(activeHomeAllListItemsProvider).value;
  final habitsStream = ref.watch(activeHomeHabitsProvider).value;
  final checkinsStream = ref.watch(activeHomeAllHabitCheckinsProvider).value;
  final routineEventsStream =
      ref.watch(activeHomeAllRoutineEventsProvider).value;

  return FirstRunCounts(
    expenses: math.max(dbCounts.expenses, expensesStream?.length ?? 0),
    events: math.max(dbCounts.events, eventsStream?.length ?? 0),
    habits: math.max(
      dbCounts.habits,
      habitsStream?.where((h) => !h.isArchived).length ?? 0,
    ),
    habitCheckins: math.max(
      dbCounts.habitCheckins,
      checkinsStream?.length ?? 0,
    ),
    listItems: math.max(dbCounts.listItems, listItemsStream?.length ?? 0),
    commitments: math.max(dbCounts.commitments, subsStream?.length ?? 0),
    routineEvents: math.max(
      dbCounts.routineEvents,
      routineEventsStream?.length ?? 0,
    ),
    activity: dbCounts.activity,
    hasPartnerInDb: dbCounts.hasPartnerInDb,
  );
});

/// First-run rule (`design/specs/16-first-run.md` §3):
/// `firstRunProvider(CoveScreen)` → `bool`.
///
/// Reads the database counts each screen needs and the `first_run_done.<screen>`
/// preference, flipping the preference the first time it sees data.
final firstRunProvider = Provider.family<bool, CoveScreen>((ref, screen) {
  final activeId = ref.watch(activeHomeIdProvider);
  final homeKey = (activeId == null || activeId.isEmpty) ? '*' : activeId;
  final counts = ref.watch(firstRunCountsProvider);
  final prefs = ref.watch(firstRunSharedPrefsProvider).value;
  final doneStore = ref.watch(firstRunDoneStoreProvider);

  // Partner joined detection for `CoveScreen.ourHome`:
  final partnerValue = ref.watch(activeHomeHasPartnerProvider);
  final partnerNotifier = ref.read(activeHomeHasPartnerProvider.notifier);
  final partnerProfile = ref.watch(partnerProfileProvider);
  final hasPartnerFromProfile = (partnerProfile.userId != null &&
          partnerProfile.userId!.trim().isNotEmpty) ||
      partnerProfile.hasCustomName ||
      (partnerProfile.displayName.trim().isNotEmpty &&
          partnerProfile.displayName.trim() != 'Partner');
  final hasJoinedPartner = counts.hasPartnerInDb ||
      hasPartnerFromProfile ||
      (ActiveHomePartnerNotifier.isExplicit(partnerNotifier) && partnerValue);

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
    CoveScreen.ourHome => hasJoinedPartner,
  };

  if (hasData) {
    doneStore.markDone(screen, prefs, homeKey);
    return false;
  }

  if (doneStore.isDone(screen, prefs, homeKey)) {
    return false;
  }

  return true;
});
