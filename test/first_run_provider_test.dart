import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/providers/first_run_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer createContainer({
    String homeId = 'home_1',
  }) {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeHomeIdProvider.overrideWith(() => _TestActiveHomeNotifier(homeId)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('firstRunProvider rule (design/specs/16-first-run.md §3)', () {
    test('1. An empty home -> all seven screens are true', () async {
      final container = createContainer();
      await pumpEventQueue();

      for (final screen in CoveScreen.values) {
        expect(
          container.read(firstRunProvider(screen)),
          isTrue,
          reason: 'Expected $screen to be in first-run on an empty home',
        );
      }

      final prefs = await SharedPreferences.getInstance();
      for (final screen in CoveScreen.values) {
        expect(prefs.getBool(screen.prefKey), isNull);
      }
    });

    test(
      '2. One expense -> Expenses, Today and Calendar false, the rest true; '
      'delete that expense -> still false',
      () async {
        final container = createContainer();
        await pumpEventQueue();

        // Insert one expense into the home.
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

        expect(container.read(firstRunProvider(CoveScreen.expenses)), isFalse);
        expect(container.read(firstRunProvider(CoveScreen.today)), isFalse);
        expect(container.read(firstRunProvider(CoveScreen.calendar)), isFalse);

        expect(container.read(firstRunProvider(CoveScreen.routines)), isTrue);
        expect(
          container.read(firstRunProvider(CoveScreen.commitments)),
          isTrue,
        );
        expect(container.read(firstRunProvider(CoveScreen.activity)), isTrue);
        expect(container.read(firstRunProvider(CoveScreen.ourHome)), isTrue);

        // Verify `first_run_done.<screen>` preferences were flipped.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('first_run_done.expenses'), isTrue);
        expect(prefs.getBool('first_run_done.today'), isTrue);
        expect(prefs.getBool('first_run_done.calendar'), isTrue);
        expect(prefs.getBool('first_run_done.routines'), isNull);
        expect(prefs.getBool('first_run_done.commitments'), isNull);
        expect(prefs.getBool('first_run_done.activity'), isNull);
        expect(prefs.getBool('first_run_done.ourHome'), isNull);

        // Delete that expense -> Expenses, Today and Calendar stay false.
        await db.deleteExpense('exp_1');
        await pumpEventQueue();

        expect(container.read(firstRunProvider(CoveScreen.expenses)), isFalse);
        expect(container.read(firstRunProvider(CoveScreen.today)), isFalse);
        expect(container.read(firstRunProvider(CoveScreen.calendar)), isFalse);
        expect(container.read(firstRunProvider(CoveScreen.routines)), isTrue);
        expect(
          container.read(firstRunProvider(CoveScreen.commitments)),
          isTrue,
        );
        expect(container.read(firstRunProvider(CoveScreen.activity)), isTrue);
        expect(container.read(firstRunProvider(CoveScreen.ourHome)), isTrue);

        // Even a brand-new ProviderContainer reading from SharedPreferences stays false.
        final restarted = createContainer();
        await restarted.read(firstRunSharedPrefsProvider.future);
        await pumpEventQueue();
        expect(restarted.read(firstRunProvider(CoveScreen.expenses)), isFalse);
        expect(restarted.read(firstRunProvider(CoveScreen.today)), isFalse);
        expect(restarted.read(firstRunProvider(CoveScreen.calendar)), isFalse);
      },
    );

    test('3. A home with a joined partner -> Our home false', () async {
      final container = createContainer();
      await pumpEventQueue();
      expect(container.read(firstRunProvider(CoveScreen.ourHome)), isTrue);

      // Partner joins the home.
      container.read(activeHomeHasPartnerProvider.notifier).setHasPartner(true);
      await pumpEventQueue();

      expect(container.read(firstRunProvider(CoveScreen.ourHome)), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('first_run_done.ourHome'), isTrue);

      // Other screens remain in first-run.
      expect(container.read(firstRunProvider(CoveScreen.today)), isTrue);
      expect(container.read(firstRunProvider(CoveScreen.calendar)), isTrue);
      expect(container.read(firstRunProvider(CoveScreen.routines)), isTrue);
      expect(container.read(firstRunProvider(CoveScreen.expenses)), isTrue);
      expect(container.read(firstRunProvider(CoveScreen.commitments)), isTrue);
      expect(container.read(firstRunProvider(CoveScreen.activity)), isTrue);
    });

    test(
      '4. Partner join recorded in DB or partnerProfile also flips Our home to false',
      () async {
        final container = createContainer();
        await pumpEventQueue();
        expect(container.read(firstRunProvider(CoveScreen.ourHome)), isTrue);

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

        expect(container.read(firstRunProvider(CoveScreen.ourHome)), isFalse);
      },
    );
  });
}
