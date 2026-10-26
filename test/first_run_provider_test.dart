import 'dart:async';

import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/providers/first_run_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestActiveHomeNotifier extends ActiveHomeNotifier {
  final String _homeId;
  _TestActiveHomeNotifier(this._homeId);

  @override
  String? build() => _homeId;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    PartnerProfileNotifier.resetCache();
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.localHomes).insert(
          LocalHomesCompanion.insert(
            id: 'home_1',
            name: 'The Nest',
            createdAt: DateTime.utc(2026, 4, 20),
            createdBy: 'user_1',
          ),
        );
    await db.into(db.localHomes).insert(
          LocalHomesCompanion.insert(
            id: 'home_2',
            name: 'Summer House',
            createdAt: DateTime.utc(2026, 4, 20),
            createdBy: 'user_1',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer createContainer({
    String homeId = 'home_1',
    List<Override> extraOverrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeHomeIdProvider.overrideWith(() => _TestActiveHomeNotifier(homeId)),
        ...extraOverrides,
      ],
    );
    for (final screen in CoveScreen.values) {
      container.listen(firstRunProvider(screen), (_, _) {});
    }
    addTearDown(container.dispose);
    return container;
  }

  Future<void> waitForFirstRunReady(ProviderContainer container) async {
    await container.read(firstRunSharedPrefsProvider.future);
    await pumpEventQueue();
  }

  group('firstRunProvider rule (design/specs/16-first-run.md §3)', () {
    test(
      '0. Returns FirstRunState.loading until both DB counts and SharedPreferences have emitted',
      () async {
        final countsController = StreamController<FirstRunCounts>.broadcast();
        addTearDown(countsController.close);

        final container = createContainer(
          extraOverrides: [
            firstRunDbCountsStreamProvider('home_1').overrideWith(
              (ref) => countsController.stream,
            ),
          ],
        );

        // Initially loading (neither prefs nor counts have emitted).
        for (final screen in CoveScreen.values) {
          expect(
            container.read(firstRunProvider(screen)),
            FirstRunState.loading,
          );
        }

        // Prefs resolve, but DB counts have not emitted yet -> still loading.
        await container.read(firstRunSharedPrefsProvider.future);
        await pumpEventQueue();
        for (final screen in CoveScreen.values) {
          expect(
            container.read(firstRunProvider(screen)),
            FirstRunState.loading,
          );
        }

        // Counts emit -> transitions out of loading.
        countsController.add(FirstRunCounts.empty);
        await pumpEventQueue();
        for (final screen in CoveScreen.values) {
          expect(
            container.read(firstRunProvider(screen)),
            FirstRunState.firstRun,
          );
        }
      },
    );

    test('1. An empty home -> all seven screens are FirstRunState.firstRun', () async {
      final container = createContainer();
      await waitForFirstRunReady(container);

      for (final screen in CoveScreen.values) {
        expect(
          container.read(firstRunProvider(screen)),
          FirstRunState.firstRun,
          reason: 'Expected $screen to be in first-run on an empty home',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      for (final screen in CoveScreen.values) {
        expect(prefs.getBool(screen.prefKeyFor('home_1')), isNull);
        expect(prefs.getBool(screen.legacyGlobalPrefKey), isNull);
      }
    });

    test(
      '2. One expense -> Expenses, Today and Calendar inUse, the rest firstRun; '
      'delete that expense -> still inUse; per-home flag first_run_done.<screen>.<homeId> only',
      () async {
        final container = createContainer();
        await waitForFirstRunReady(container);

        // Keep listeners active so stream updates propagate immediately.
        for (final screen in CoveScreen.values) {
          container.listen(firstRunProvider(screen), (_, _) {});
        }

        // Insert one expense into home_1.
        await db.into(db.localExpenses).insert(
              LocalExpensesCompanion.insert(
                id: 'exp_1',
                homeId: 'home_1',
                title: 'Groceries',
                amount: 640.0,
                paidBy: 'user_1',
                expenseDate: DateTime.utc(2026, 4, 20),
                createdAt: DateTime.utc(2026, 4, 20),
              ),
            );
        await pumpEventQueue();

        expect(
          container.read(firstRunProvider(CoveScreen.expenses)),
          FirstRunState.inUse,
        );
        expect(
          container.read(firstRunProvider(CoveScreen.today)),
          FirstRunState.inUse,
        );
        expect(
          container.read(firstRunProvider(CoveScreen.calendar)),
          FirstRunState.inUse,
        );

        expect(
          container.read(firstRunProvider(CoveScreen.routines)),
          FirstRunState.firstRun,
        );
        expect(
          container.read(firstRunProvider(CoveScreen.commitments)),
          FirstRunState.firstRun,
        );
        expect(
          container.read(firstRunProvider(CoveScreen.activity)),
          FirstRunState.firstRun,
        );
        expect(
          container.read(firstRunProvider(CoveScreen.ourHome)),
          FirstRunState.firstRun,
        );

        // Verify per-home `first_run_done.<screen>.<homeId>` preferences were flipped,
        // and NO global or slug keys were written.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('first_run_done.expenses.home_1'), isTrue);
        expect(prefs.getBool('first_run_done.today.home_1'), isTrue);
        expect(prefs.getBool('first_run_done.calendar.home_1'), isTrue);
        expect(prefs.getBool('first_run_done.routines.home_1'), isNull);
        expect(prefs.getBool('first_run_done.commitments.home_1'), isNull);
        expect(prefs.getBool('first_run_done.activity.home_1'), isNull);
        expect(prefs.getBool('first_run_done.ourHome.home_1'), isNull);
        expect(prefs.getBool('first_run_done.expenses'), isNull);
        expect(prefs.getBool('first_run_done.today'), isNull);
        expect(prefs.getBool('first_run_done.calendar'), isNull);

        // Delete that expense -> Expenses, Today and Calendar stay inUse.
        await db.deleteExpense('exp_1');
        await pumpEventQueue();

        expect(
          container.read(firstRunProvider(CoveScreen.expenses)),
          FirstRunState.inUse,
        );
        expect(
          container.read(firstRunProvider(CoveScreen.today)),
          FirstRunState.inUse,
        );
        expect(
          container.read(firstRunProvider(CoveScreen.calendar)),
          FirstRunState.inUse,
        );
        expect(
          container.read(firstRunProvider(CoveScreen.routines)),
          FirstRunState.firstRun,
        );

        // A brand-new ProviderContainer reading from SharedPreferences for home_1 stays inUse.
        final restarted = createContainer(homeId: 'home_1');
        await waitForFirstRunReady(restarted);
        expect(
          restarted.read(firstRunProvider(CoveScreen.expenses)),
          FirstRunState.inUse,
        );
        expect(
          restarted.read(firstRunProvider(CoveScreen.today)),
          FirstRunState.inUse,
        );
        expect(
          restarted.read(firstRunProvider(CoveScreen.calendar)),
          FirstRunState.inUse,
        );

        // Switching to empty home_2 is isolated -> all screens are firstRun on home_2.
        final home2Container = createContainer(homeId: 'home_2');
        await waitForFirstRunReady(home2Container);
        for (final screen in CoveScreen.values) {
          expect(
            home2Container.read(firstRunProvider(screen)),
            FirstRunState.firstRun,
            reason: 'Expected $screen on empty home_2 to be firstRun',
          );
        }
      },
    );

    test(
      '3. Legacy global key migration: if an old global key is set, treat it as set for the current active home only',
      () async {
        SharedPreferences.setMockInitialValues({
          'first_run_done.expenses': true,
          'first_run_done.today': true,
        });

        final container = createContainer(homeId: 'home_1');
        await waitForFirstRunReady(container);

        expect(
          container.read(firstRunProvider(CoveScreen.expenses)),
          FirstRunState.inUse,
        );
        expect(
          container.read(firstRunProvider(CoveScreen.today)),
          FirstRunState.inUse,
        );
        expect(
          container.read(firstRunProvider(CoveScreen.calendar)),
          FirstRunState.firstRun,
        );

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('first_run_done.expenses.home_1'), isTrue);
        expect(prefs.getBool('first_run_done.today.home_1'), isTrue);
        // Old global keys are removed after migrating to current active home.
        expect(prefs.getBool('first_run_done.expenses'), isNull);
        expect(prefs.getBool('first_run_done.today'), isNull);

        // Switching active home to home_2 -> NOT treated as set for home_2.
        container.read(activeHomeIdProvider.notifier).setActiveHome('home_2');
        await waitForFirstRunReady(container);
        expect(
          container.read(firstRunProvider(CoveScreen.expenses)),
          FirstRunState.firstRun,
        );
        expect(
          container.read(firstRunProvider(CoveScreen.today)),
          FirstRunState.firstRun,
        );
      },
    );

    test('4. A home with a joined partner in DB -> Our home inUse', () async {
      final container = createContainer();
      await waitForFirstRunReady(container);
      container.listen(firstRunProvider(CoveScreen.ourHome), (_, _) {});

      expect(
        container.read(firstRunProvider(CoveScreen.ourHome)),
        FirstRunState.firstRun,
      );

      await db.into(db.localActivityEvents).insert(
            LocalActivityEventsCompanion.insert(
              id: 'act_join',
              homeId: 'home_1',
              actorId: 'user_2',
              eventType: 'member_profile_updated',
              payloadJson: '{"display_name":"Ancy"}',
              createdAt: DateTime.utc(2026, 4, 20),
            ),
          );
      await pumpEventQueue();

      expect(
        container.read(firstRunProvider(CoveScreen.ourHome)),
        FirstRunState.inUse,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('first_run_done.ourHome.home_1'), isTrue);

      // Other screens remain in first-run.
      expect(
        container.read(firstRunProvider(CoveScreen.today)),
        FirstRunState.firstRun,
      );
      expect(
        container.read(firstRunProvider(CoveScreen.calendar)),
        FirstRunState.firstRun,
      );
      expect(
        container.read(firstRunProvider(CoveScreen.routines)),
        FirstRunState.firstRun,
      );
      expect(
        container.read(firstRunProvider(CoveScreen.expenses)),
        FirstRunState.firstRun,
      );
      expect(
        container.read(firstRunProvider(CoveScreen.commitments)),
        FirstRunState.firstRun,
      );
      expect(
        container.read(firstRunProvider(CoveScreen.activity)),
        FirstRunState.firstRun,
      );
    });
  });
}
