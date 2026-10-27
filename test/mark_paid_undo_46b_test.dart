import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/subscriptions/commitment_detail_sheet.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/db/local_state_store_impl.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthNotifier extends AuthNotifier {
  final CoveUser _user;
  _TestAuthNotifier(this._user);

  @override
  AsyncValue<CoveUser?> build() => AsyncValue.data(_user);
}

class _ActiveHomeIdStub extends ActiveHomeNotifier {
  final String? _initial;
  _ActiveHomeIdStub(this._initial);

  @override
  String? build() => _initial;
}

class _EmittedEvent {
  final String eventType;
  final Map<String, dynamic> payload;

  const _EmittedEvent({
    required this.eventType,
    required this.payload,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    SharedPreferences.setMockInitialValues({});
  });

  group('4.6b — Undoing Mark paid', () {
    testWidgets(
      'mark paid with logging → undo → the commitment is back as before and that expense is gone',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.into(db.localHomes).insertOnConflictUpdate(
              LocalHomesCompanion.insert(
                id: 'home-1',
                name: 'Test Home',
                createdBy: 'user-saba',
                createdAt: DateTime.utc(2026, 1, 1),
              ),
            );

        final store = LocalStateStoreImpl(db);
        final emittedEvents = <_EmittedEvent>[];
        var seq = 0;

        final subBefore = LocalSubscription(
          id: 'sub-apple-one',
          homeId: 'home-1',
          name: 'Apple One',
          amount: 365.0,
          currency: 'INR',
          billingCycle: 'monthly',
          nextBillingDate: DateTime(2026, 10, 15),
          category: 'Entertainment',
          isActive: true,
          isPrivate: false,
          createdBy: 'user-saba',
          createdAt: DateTime(2026, 1, 1),
          endDate: null,
          paidBy: 'user-saba',
          financedThrough: 'HDFC Infinia',
          totalInstallments: null,
          paidInstallments: null,
        );
        await db.into(db.localSubscriptions).insert(subBefore);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              activeHomeIdProvider
                  .overrideWith(() => _ActiveHomeIdStub('home-1')),
              activeHomeProvider.overrideWith(
                (ref) => Stream.value(
                  LocalHome(
                    id: 'home-1',
                    name: 'Test Home',
                    createdAt: DateTime.utc(2026, 1, 1),
                    createdBy: 'user-saba',
                    currency: 'INR',
                  ),
                ),
              ),
              authProvider.overrideWith(
                () => _TestAuthNotifier(
                  const CoveUser(
                    id: 'user-saba',
                    email: 'saba@cove.app',
                    displayName: 'Saba',
                  ),
                ),
              ),
              coveEmitActionProvider.overrideWithValue(({
                required String eventType,
                required Map<String, dynamic> payload,
                String? targetHomeId,
              }) async {
                emittedEvents.add(
                  _EmittedEvent(
                    eventType: eventType,
                    payload: Map<String, dynamic>.from(payload),
                  ),
                );
                await store.applyEvent(
                  eventId: 'ev-${++seq}-$eventType',
                  homeId: targetHomeId ?? 'home-1',
                  eventType: eventType,
                  payload: payload,
                  timestamp: clock.now().toUtc(),
                  authorId: 'user-saba',
                );
              }),
            ],
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => CommitmentDetailSheet.show(
                      context,
                      subBefore,
                    ),
                    child: const Text('Open Commitment'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open CommitmentDetailSheet
        await tester.tap(find.text('Open Commitment'));
        await tester.pumpAndSettle();

        // Tap "Mark paid" -> dialog opens; tick "Log to household Expenses"
        await tester.tap(find.text('Mark paid'));
        await tester.pumpAndSettle();

        expect(
          find.text('Log to household Expenses'),
          findsOneWidget,
        );
        await tester.tap(find.text('Log to household Expenses'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirm Renewal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify the expense was created and logged via expenseController
        final expensesAfterMarkPaid =
            await db.select(db.localExpenses).get();
        expect(expensesAfterMarkPaid.length, 1);
        final createdExpenseId = expensesAfterMarkPaid.single.id;
        expect(
          expensesAfterMarkPaid.single.title,
          'Apple One (Renewal)',
        );
        expect(
          emittedEvents.any((e) => e.eventType == 'expense_logged'),
          isTrue,
        );

        // Verify the commitment advanced to 15 Nov 2026
        final subAfterMarkPaid =
            (await db.select(db.localSubscriptions).get()).single;
        expect(subAfterMarkPaid.nextBillingDate, DateTime(2026, 11, 15));

        // Tap Undo on the toast
        final snackBarAction =
            tester.widget<SnackBarAction>(find.byType(SnackBarAction));
        snackBarAction.onPressed();
        await tester.pumpAndSettle();

        // 1. Commitment is back as before
        final subAfterUndo =
            (await db.select(db.localSubscriptions).get()).single;
        expect(subAfterUndo.id, subBefore.id);
        expect(subAfterUndo.name, subBefore.name);
        expect(subAfterUndo.amount, subBefore.amount);
        expect(subAfterUndo.billingCycle, subBefore.billingCycle);
        expect(subAfterUndo.nextBillingDate, subBefore.nextBillingDate);
        expect(subAfterUndo.category, subBefore.category);
        expect(subAfterUndo.isActive, subBefore.isActive);
        expect(subAfterUndo.paidBy, subBefore.paidBy);
        expect(subAfterUndo.financedThrough, subBefore.financedThrough);

        // 2. That expense is gone (deleted through expenseController so it syncs)
        final expensesAfterUndo = await db.select(db.localExpenses).get();
        expect(expensesAfterUndo, isEmpty);
        final deleteEvents = emittedEvents
            .where((e) => e.eventType == 'expense_deleted')
            .toList();
        expect(deleteEvents.length, 1);
        expect(deleteEvents.single.payload['id'], createdExpenseId);
      },
    );

    testWidgets(
      'mark paid without logging → undo → commitment is back as before and no expense is touched',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1400));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final db = AppDatabase(NativeDatabase.memory());
        await db.into(db.localHomes).insertOnConflictUpdate(
              LocalHomesCompanion.insert(
                id: 'home-1',
                name: 'Test Home',
                createdBy: 'user-saba',
                createdAt: DateTime.utc(2026, 1, 1),
              ),
            );

        final store = LocalStateStoreImpl(db);
        final emittedEvents = <_EmittedEvent>[];
        var seq = 0;

        final subBefore = LocalSubscription(
          id: 'sub-apple-one',
          homeId: 'home-1',
          name: 'Apple One',
          amount: 365.0,
          currency: 'INR',
          billingCycle: 'monthly',
          nextBillingDate: DateTime(2026, 10, 15),
          category: 'Entertainment',
          isActive: true,
          isPrivate: false,
          createdBy: 'user-saba',
          createdAt: DateTime(2026, 1, 1),
          endDate: null,
          paidBy: 'user-saba',
          financedThrough: 'HDFC Infinia',
          totalInstallments: null,
          paidInstallments: null,
        );
        await db.into(db.localSubscriptions).insert(subBefore);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            activeHomeIdProvider
                .overrideWith(() => _ActiveHomeIdStub('home-1')),
            activeHomeProvider.overrideWith(
              (ref) => Stream.value(
                LocalHome(
                  id: 'home-1',
                  name: 'Test Home',
                  createdAt: DateTime.utc(2026, 1, 1),
                  createdBy: 'user-saba',
                  currency: 'INR',
                ),
              ),
            ),
            authProvider.overrideWith(
              () => _TestAuthNotifier(
                const CoveUser(
                  id: 'user-saba',
                  email: 'saba@cove.app',
                  displayName: 'Saba',
                ),
              ),
            ),
            coveEmitActionProvider.overrideWithValue(({
              required String eventType,
              required Map<String, dynamic> payload,
              String? targetHomeId,
            }) async {
              emittedEvents.add(
                _EmittedEvent(
                  eventType: eventType,
                  payload: Map<String, dynamic>.from(payload),
                ),
              );
              await store.applyEvent(
                eventId: 'ev-${++seq}-$eventType',
                homeId: targetHomeId ?? 'home-1',
                eventType: eventType,
                payload: payload,
                timestamp: clock.now().toUtc(),
                authorId: 'user-saba',
              );
            }),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });

        // Seed an unrelated pre-existing expense to verify it is untouched
        final existingExpenseId = await container
            .read(expenseControllerProvider)
            .logExpense(
              title: 'Morning Coffee',
              amount: 250.0,
              paidBy: 'user-saba',
            );
        emittedEvents.clear();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: CoveTheme.darkTheme,
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => CommitmentDetailSheet.show(
                      context,
                      subBefore,
                    ),
                    child: const Text('Open Commitment'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open CommitmentDetailSheet
        await tester.tap(find.text('Open Commitment'));
        await tester.pumpAndSettle();

        // Tap "Mark paid" with "Log to household Expenses" left unticked
        await tester.tap(find.text('Mark paid'));
        await tester.pumpAndSettle();

        expect(
          find.text('Log to household Expenses'),
          findsOneWidget,
        );

        await tester.tap(find.text('Confirm Renewal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // No expense was logged
        expect(
          emittedEvents.where((e) => e.eventType == 'expense_logged'),
          isEmpty,
        );
        expect((await db.select(db.localExpenses).get()).length, 1);

        // Tap Undo on the toast
        final snackBarAction =
            tester.widget<SnackBarAction>(find.byType(SnackBarAction));
        snackBarAction.onPressed();
        await tester.pumpAndSettle();

        // Commitment is restored as before
        final subAfterUndo =
            (await db.select(db.localSubscriptions).get()).single;
        expect(subAfterUndo.nextBillingDate, subBefore.nextBillingDate);

        // No expense was created or deleted; pre-existing expense is untouched
        expect(
          emittedEvents.where(
            (e) =>
                e.eventType == 'expense_logged' ||
                e.eventType == 'expense_deleted',
          ),
          isEmpty,
        );
        final remainingExpenses = await db.select(db.localExpenses).get();
        expect(remainingExpenses.length, 1);
        expect(remainingExpenses.single.id, existingExpenseId);
        expect(remainingExpenses.single.title, 'Morning Coffee');
      },
    );
  });
}
