import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/expenses/monthly_budget_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/subscriptions/subscription_controller.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/features/widgets/cove_ledger_widget.dart';
import 'package:cove/features/widgets/cove_widget_service.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingWidgetBridge implements CoveWidgetPlatformBridge {
  final List<String> renderedKeys = <String>[];
  final Map<String, Size> renderedSizes = <String, Size>{};
  final Map<String, Object?> savedData = <String, Object?>{};
  final List<String> updatedProviders = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<String> renderFlutterWidget(
    Widget widget, {
    required String key,
    required Size logicalSize,
  }) async {
    renderedKeys.add(key);
    renderedSizes[key] = logicalSize;
    return '/tmp/home_widget/$key.png';
  }

  @override
  Future<bool?> saveWidgetData<T>(String id, T? data) async {
    savedData[id] = data;
    return true;
  }

  @override
  Future<bool?> updateWidget({
    required String androidName,
    required String qualifiedAndroidName,
  }) async {
    updatedProviders.add(qualifiedAndroidName);
    return true;
  }

  @override
  Future<Uri?> initiallyLaunchedFromHomeWidget() async => null;

  @override
  Stream<Uri?> get widgetClicked => const Stream<Uri?>.empty();
}

class _FakeWidgetScheduler implements WidgetRefreshScheduler {
  int scheduleCalls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> schedulePeriodicRefresh() async {
    scheduleCalls++;
  }

  @override
  Future<void> cancel() async {}
}

const CoveUser _kUser = CoveUser(
  id: 'user_1',
  email: 'saba@cove.local',
  displayName: 'Saba',
);

class _FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncData(_kUser);

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void signInWithDemoUser([
    String name = 'Saba',
    String email = 'saba@cove.local',
  ]) {}

  @override
  Future<void> signOut() async {}
}

class _FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  @override
  String? build() => 'home_1';

  @override
  void setActiveHome(String homeId) => state = homeId;
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState(
        displayName: 'Saba',
        email: 'saba@cove.local',
      );
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => const PartnerProfileState(
        displayName: 'Ancy',
        hasCustomName: true,
      );
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() =>
      const CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee');
}

class _FakeMonthlyBudgetNotifier extends MonthlyBudgetNotifier {
  @override
  double? build() => 85000.0;
}

class _FakeWeatherNotifier extends WeatherNotifier {
  @override
  WeatherData? build() => null;

  @override
  Future<void> refreshWeather({bool force = false}) async {}
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('4.4a — Home-Screen Widget Plumbing & The Ledger', () {
    test(
      '1. AndroidManifest and appwidget-provider XMLs register Arc 2x2, Slip 4x2, Ledger 4x2, and Day Sheet 4x4 with previews and min sizes',
      () {
        final manifest = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
        expect(manifest, contains('.widgets.CoveDayArcWidgetProvider'));
        expect(manifest, contains('.widgets.CoveSlipWidgetProvider'));
        expect(manifest, contains('.widgets.CoveLedgerWidgetProvider'));
        expect(manifest, contains('.widgets.CoveDaySheetWidgetProvider'));
        expect(manifest, contains('@xml/cove_day_arc_widget_info'));
        expect(manifest, contains('@xml/cove_slip_widget_info'));
        expect(manifest, contains('@xml/cove_ledger_widget_info'));
        expect(manifest, contains('@xml/cove_day_sheet_widget_info'));

        final arcXml = File(
          'android/app/src/main/res/xml/cove_day_arc_widget_info.xml',
        ).readAsStringSync();
        expect(arcXml, contains('android:targetCellWidth="2"'));
        expect(arcXml, contains('android:targetCellHeight="2"'));
        expect(arcXml, contains('android:minWidth="110dp"'));
        expect(arcXml, contains('android:minHeight="110dp"'));
        expect(arcXml, contains('@drawable/widget_preview_arc'));

        final slipXml = File(
          'android/app/src/main/res/xml/cove_slip_widget_info.xml',
        ).readAsStringSync();
        expect(slipXml, contains('android:targetCellWidth="4"'));
        expect(slipXml, contains('android:targetCellHeight="2"'));
        expect(slipXml, contains('android:minWidth="250dp"'));
        expect(slipXml, contains('android:minResizeWidth="180dp"'));
        expect(slipXml, contains('@drawable/widget_preview_slip'));

        final ledgerXml = File(
          'android/app/src/main/res/xml/cove_ledger_widget_info.xml',
        ).readAsStringSync();
        expect(ledgerXml, contains('android:targetCellWidth="4"'));
        expect(ledgerXml, contains('android:targetCellHeight="2"'));
        expect(ledgerXml, contains('android:minWidth="250dp"'));
        expect(ledgerXml, contains('android:minResizeWidth="180dp"'));
        expect(ledgerXml, contains('@drawable/widget_preview_ledger'));

        final sheetXml = File(
          'android/app/src/main/res/xml/cove_day_sheet_widget_info.xml',
        ).readAsStringSync();
        expect(sheetXml, contains('android:targetCellWidth="4"'));
        expect(sheetXml, contains('android:targetCellHeight="4"'));
        expect(sheetXml, contains('android:minWidth="250dp"'));
        expect(sheetXml, contains('android:minHeight="250dp"'));
        expect(sheetXml, contains('@drawable/widget_preview_day_sheet'));

        for (final preview in [
          'widget_preview_arc.png',
          'widget_preview_slip.png',
          'widget_preview_ledger.png',
          'widget_preview_day_sheet.png',
        ]) {
          expect(
            File('android/app/src/main/res/drawable-nodpi/$preview')
                .existsSync(),
            isTrue,
          );
          expect(
            File('android/app/src/main/res/drawable-night-nodpi/$preview')
                .existsSync(),
            isTrue,
          );
        }
      },
    );

    test(
      '2. Re-rendering from the app triggers when expenses or commitments change, and 30-min background refresh enforces 15-min floor',
      () async {
        final bridge = _RecordingWidgetBridge();
        final scheduler = _FakeWidgetScheduler();
        final service = CoveWidgetService(
          bridge: bridge,
          scheduler: scheduler,
        );

        final expensesStream = StreamController<List<LocalExpense>>.broadcast();
        final subsStream =
            StreamController<List<LocalSubscription>>.broadcast();
        addTearDown(() async {
          await expensesStream.close();
          await subsStream.close();
        });

        final oct5 = DateTime(2026, 10, 5, 9, 41);

        await withClock(Clock.fixed(oct5), () async {
          final container = ProviderContainer(
            overrides: [
              coveWidgetServiceProvider.overrideWithValue(service),
              authProvider.overrideWith(_FakeAuthNotifier.new),
              activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
              activeHomeProvider.overrideWith(
                (ref) => Stream.value(
                  LocalHome(
                    id: 'home_1',
                    name: 'The Nest',
                    currency: 'INR',
                    createdAt: DateTime(2026, 9, 1),
                    createdBy: 'user_1',
                  ),
                ),
              ),
              userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
              partnerProfileProvider.overrideWith(
                _FakePartnerProfileNotifier.new,
              ),
              currencyPreferenceProvider.overrideWith(
                _FakeCurrencyNotifier.new,
              ),
              monthlyBudgetProvider.overrideWith(
                _FakeMonthlyBudgetNotifier.new,
              ),
              expensesReferenceDateProvider.overrideWithValue(oct5),
              commitmentsReferenceDateProvider.overrideWithValue(oct5),
              activeHomeExpensesProvider.overrideWith(
                (ref) => expensesStream.stream,
              ),
              activeHomeSubscriptionsProvider.overrideWith(
                (ref) => subsStream.stream,
              ),
              activeHomeCalendarEventsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              activeHomeRoutinesProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              activeHomeAllRoutineEventsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              activeHomeHabitsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              activeHomeAllHabitCheckinsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              activeHomeListsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              activeHomeAllListItemsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              weatherProvider.overrideWith(_FakeWeatherNotifier.new),
            ],
          );
          addTearDown(container.dispose);

          final sub = container.listen(
            coveWidgetAutoSyncProvider,
            (_, _) {},
            fireImmediately: true,
          );
          addTearDown(sub.close);

          expensesStream.add([
            LocalExpense(
              id: 'e1',
              homeId: 'home_1',
              title: 'Rent',
              amount: 28940,
              currency: 'INR',
              paidBy: 'user_1',
              splitRatio: 0.5,
              expenseDate: DateTime(2026, 10, 3),
              isTransfer: false,
              createdAt: DateTime(2026, 10, 3),
            ),
          ]);
          subsStream.add([
            LocalSubscription(
              id: 'sub_1',
              homeId: 'home_1',
              name: 'Spotify Duo',
              amount: 249,
              currency: 'INR',
              billingCycle: 'monthly',
              nextBillingDate: DateTime(2026, 10, 6),
              isActive: true,
              isPrivate: false,
              createdAt: DateTime(2026, 9, 6),
            ),
          ]);

          await Future<void>.delayed(const Duration(milliseconds: 10));
          await container.pump();
          await Future<void>.delayed(const Duration(milliseconds: 20));

          expect(
            bridge.renderedKeys,
            containsAll([
              CoveWidgetService.ledgerDarkKey,
              CoveWidgetService.ledgerLightKey,
              CoveWidgetService.ledgerCompactDarkKey,
              CoveWidgetService.ledgerCompactLightKey,
            ]),
          );
          expect(
            bridge.savedData[CoveWidgetService.ledgerNextCommitmentIdKey],
            'sub_1',
          );
          expect(
            bridge.updatedProviders,
            contains('com.app.cove.widgets.CoveLedgerWidgetProvider'),
          );

          // Background refresh: first run at T+0 succeeds; second run at T+5m is
          // throttled (< 15 min floor); third run at T+30m re-renders.
          bridge.renderedKeys.clear();
          await service.runBackgroundRefresh(nowOverride: oct5);
          expect(bridge.renderedKeys, isNotEmpty);

          bridge.renderedKeys.clear();
          await service.runBackgroundRefresh(
            nowOverride: oct5.add(const Duration(minutes: 5)),
          );
          expect(bridge.renderedKeys, isEmpty);

          await service.runBackgroundRefresh(
            nowOverride: oct5.add(const Duration(minutes: 30)),
          );
          expect(
            bridge.renderedKeys,
            contains(CoveWidgetService.ledgerDarkKey),
          );
        });
      },
    );

    testWidgets(
      '3. CoveLedgerWidget hides the right RENEWS column when resized to 3-cell width (< 240dp)',
      (tester) async {
        final oct5 = DateTime(2026, 10, 5, 9, 41);
        final expenses = ExpensesStandingSummary.compute(
          allExpenses: [
            LocalExpense(
              id: 'e1',
              homeId: 'home_1',
              title: 'Rent',
              amount: 28940,
              currency: 'INR',
              paidBy: 'user_1',
              splitRatio: 0.5,
              expenseDate: DateTime(2026, 10, 3),
              isTransfer: false,
              createdAt: DateTime(2026, 10, 3),
            ),
          ],
          currentUserId: 'user_1',
          myName: 'Saba',
          partnerName: 'Ancy',
          creatorId: 'user_1',
          currency: const CurrencyOption(
            code: 'INR',
            symbol: '₹',
            name: 'Indian Rupee',
          ),
          monthlyBudget: 85000,
          referenceDate: oct5,
        );
        final commitments = CommitmentsSummary.compute(
          [
            LocalSubscription(
              id: 'sub_1',
              homeId: 'home_1',
              name: 'Spotify Duo',
              amount: 249,
              currency: 'INR',
              billingCycle: 'monthly',
              nextBillingDate: DateTime(2026, 10, 6),
              isActive: true,
              isPrivate: false,
              createdAt: DateTime(2026, 9, 6),
            ),
          ],
          referenceDate: oct5,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: CoveTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200, // 3-cell width (< 240dp)
                  height: 176,
                  child: CoveLedgerCard(
                    expenses: expenses,
                    commitments: commitments,
                  ),
                ),
              ),
            ),
          ),
        );

        expect(find.text('SHARED THIS MONTH'), findsOneWidget);
        expect(find.text('₹28,940'), findsOneWidget);
        expect(find.text('RENEWS'), findsNothing);
        expect(find.text('Spotify Duo'), findsNothing);
      },
    );
  });
}
