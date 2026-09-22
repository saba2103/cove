import 'package:cove/core/theme/cove_theme.dart';
import 'package:cove/features/activity/activity_read_status_controller.dart';
import 'package:cove/features/app_shell.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_screen.dart';
import 'package:cove/features/expenses/expenses_screen.dart';
import 'package:cove/features/lists/lists_screen.dart';
import 'package:cove/features/notifications/notification_controller.dart';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:cove/features/notifications/notification_service.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/routines/routine_screen.dart';
import 'package:cove/features/subscriptions/subscriptions_screen.dart';
import 'package:cove/features/today/today_screen.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  final AsyncValue<CoveUser?> initial;

  FakeAuthNotifier(this.initial);

  @override
  AsyncValue<CoveUser?> build() => initial;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void signInWithDemoUser([String name = 'Alex', String email = 'alex@cove.local']) {}

  @override
  Future<void> signOut() async {}
}

class FakeActiveHomeNotifier extends Notifier<String?>
    implements ActiveHomeNotifier {
  final String? initial;

  FakeActiveHomeNotifier(this.initial);

  @override
  String? build() => initial;

  @override
  void setActiveHome(String homeId) {
    state = homeId;
  }
}

class FakeActivePartnerNotifier extends ActiveHomePartnerNotifier {
  @override
  bool build() => true;
}

class FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() {
    return const PartnerProfileState(displayName: 'Sophia');
  }
}

class FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() {
    return const UserProfileState(displayName: 'Alex', email: 'alex@example.com');
  }
}

class FakeWeatherNotifier extends WeatherNotifier {
  @override
  WeatherData? build() => null;

  @override
  Future<void> refreshWeather({bool force = false}) async {}
}

class FakeNotificationService extends NotificationService {
  FakeNotificationService({super.onNavigate, NotificationModule? initialPending}) {
    if (initialPending != null) {
      onNotificationTapped(CoveNotificationPayload(
        homeId: 'home_123',
        module: initialPending,
        eventType: 'generic',
        title: 'Test',
        body: 'Test',
      ));
    }
  }

  @override
  Future<void> initializeLocalNotifications() async {}

  @override
  Future<void> initializeFcm({String? fallbackToken}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testUser = const CoveUser(
    id: 'user_alex',
    email: 'alex@example.com',
    displayName: 'Alex',
  );

  final testHome = LocalHome(
    id: 'home_123',
    name: 'Haven Sanctuary',
    createdAt: DateTime(2026, 1, 1),
    createdBy: 'user_alex',
    currency: 'USD',
  );

  List<Override> createBaseOverrides() {
    return [
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      authProvider.overrideWith(() => FakeAuthNotifier(AsyncValue.data(testUser))),
      activeHomeIdProvider.overrideWith(() => FakeActiveHomeNotifier('home_123')),
      activeHomeProvider.overrideWith((ref) => Stream.value(testHome)),
      userHomesProvider.overrideWith((ref) => Stream.value([testHome])),
      activeHomeHasPartnerProvider.overrideWith(FakeActivePartnerNotifier.new),
      partnerProfileProvider.overrideWith(FakePartnerProfileNotifier.new),
      userProfileProvider.overrideWith(FakeUserProfileNotifier.new),
      unreadActivityCountProvider.overrideWith((ref) => 0),
      weatherProvider.overrideWith(FakeWeatherNotifier.new),
      activeHomeCalendarEventsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeSubscriptionsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeHabitsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeAllHabitCheckinsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeListsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeAllListItemsProvider.overrideWith((ref) => Stream.value([])),
      activeHomeExpensesProvider.overrideWith((ref) => Stream.value([])),
      activeHomeRoutinesProvider.overrideWith((ref) => Stream.value([])),
      activeHomeAllRoutineEventsProvider.overrideWith((ref) => Stream.value([])),
      coveEmitActionProvider.overrideWithValue((
        {required String eventType,
        required Map<String, dynamic> payload,
        String? targetHomeId}) async {}),
    ];
  }

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: createBaseOverrides(),
      child: MaterialApp(
        theme: CoveTheme.darkTheme,
        home: const AppShell(),
      ),
    );
  }

  group('Calendar-First Back Navigation Rules Tests', () {
    testWidgets('1. App launches with Calendar (index 2) as default surface', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CalendarScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('2. Back button from Home/Today tab (index 0) returns to Calendar (index 2)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CalendarScreen), findsOneWidget);

      // Tap Home tab (index 0)
      await tester.tap(find.byIcon(Icons.home_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byType(CalendarScreen), findsNothing);

      // Simulate system back button
      final didPop = await tester.binding.handlePopRoute();
      expect(didPop, isTrue);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Must return to Calendar
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.byType(TodayScreen), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('3. Back button from Subscriptions (index 1), Lists (index 3), Expenses (index 4) returns to Calendar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Commitments tab (index 1)
      await tester.tap(find.byIcon(Icons.autorenew_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SubscriptionsScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CalendarScreen), findsOneWidget);

      // Lists tab (index 3)
      await tester.tap(find.byIcon(Icons.checklist_rtl_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ListsScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CalendarScreen), findsOneWidget);

      // Expenses tab (index 4)
      await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ExpensesScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CalendarScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('4. Single back on Calendar shows toast; double back exits app', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool popSystemCalled = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'SystemNavigator.pop') {
            popSystemCalled = true;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CalendarScreen), findsOneWidget);

      // First back press on Calendar
      await tester.binding.handlePopRoute();
      await tester.pump();

      // Shows 'Press back again to exit' SnackBar
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(popSystemCalled, isFalse);

      // Second back press within 2 seconds
      await tester.binding.handlePopRoute();
      await tester.pump();

      // SystemNavigator.pop invoked
      expect(popSystemCalled, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('5. Pushed page (RoutineScreen) pops back to AppShell and does not close app', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open RoutineScreen via appbar icon
      await tester.tap(find.byTooltip('Routines'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RoutineScreen), findsOneWidget);

      // Press back
      final popped = await tester.binding.handlePopRoute();
      expect(popped, isTrue);
      await tester.pumpAndSettle();

      // Successfully back to AppShell / CalendarScreen
      expect(find.byType(RoutineScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(CalendarScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('6. Cold launch from notification routes directly to respective page (Subscriptions)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final overrides = createBaseOverrides();
      // Override notification service with a pending subscriptions module
      overrides[0] = notificationServiceProvider.overrideWithValue(
        FakeNotificationService(initialPending: NotificationModule.subscriptions),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const AppShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Must open directly to SubscriptionsScreen, NOT default CalendarScreen
      expect(find.byType(SubscriptionsScreen), findsOneWidget);
      expect(find.byType(CalendarScreen), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('7. In-app notification tap switches tab and dismisses any open modal/screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeNotif = FakeNotificationService();
      final overrides = createBaseOverrides();
      overrides[0] = notificationServiceProvider.overrideWithValue(fakeNotif);

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: CoveTheme.darkTheme,
            home: const AppShell(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CalendarScreen), findsOneWidget);

      // Open a modal/pushed route (e.g. Routines)
      await tester.tap(find.byTooltip('Routines'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(RoutineScreen), findsOneWidget);

      // Now tap a notification for Expenses
      fakeNotif.onNotificationTapped(const CoveNotificationPayload(
        homeId: 'home_123',
        module: NotificationModule.expenses,
        eventType: 'expense_logged',
        title: 'Expenses',
        body: 'New expense logged',
      ));

      await tester.pump();
      await tester.pumpAndSettle();

      // RoutineScreen was popped and ExpensesScreen is now visible
      expect(find.byType(RoutineScreen), findsNothing);
      expect(find.byType(ExpensesScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
