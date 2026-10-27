import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/calendar/calendar_controller.dart';
import 'package:cove/features/calendar/calendar_event_form_sheet.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/expenses/expense_form_sheet.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/subscriptions/subscription_controller.dart';
import 'package:cove/features/subscriptions/subscription_form_sheet.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _kFixedDate = DateTime(2026, 10, 15, 10, 30);

const _kAlexUser = CoveUser(
  id: 'user_alex',
  email: 'alex@cove.test',
  displayName: 'Alex',
);

const _kAlexProfile = UserProfileState(
  displayName: 'Alex',
  email: 'alex@cove.test',
  hasCustomName: true,
);

const _kSarahPartnerProfile = PartnerProfileState(
  displayName: 'Sarah',
  userId: 'user_sarah',
);

class _StubAppDatabase extends Fake implements AppDatabase {
  @override
  Future<void> close() async {}
}

class _FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncData(_kAlexUser);

  @override
  Future<void> signInWithGoogle() async {}

  @override
  void signInWithDemoUser([
    String name = 'Alex',
    String email = 'alex@cove.local',
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
  UserProfileState build() => _kAlexProfile;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => _kSarahPartnerProfile;
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() =>
      const CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee');
}

class _FakeCustomCategoriesNotifier extends CustomCategoriesNotifier {
  @override
  List<String> build() => const ['Pet Care'];
}

class _SpyCalendarController extends Fake implements CalendarController {
  Map<String, dynamic>? capturedUpdate;

  @override
  Future<void> updateEvent({
    required String id,
    required String title,
    String? description,
    required DateTime startTime,
    required DateTime endTime,
    bool isAllDay = false,
    String? location,
    String? recurrence,
    String? owner,
  }) async {
    capturedUpdate = {
      'id': id,
      'title': title,
      'description': description,
      'startTime': startTime,
      'endTime': endTime,
      'isAllDay': isAllDay,
      'location': location,
      'recurrence': recurrence,
      'owner': owner,
    };
  }
}

class _SpyExpenseController extends Fake implements ExpenseController {
  Map<String, dynamic>? capturedUpdate;

  @override
  Future<String> updateExpense({
    required String id,
    required String title,
    required double amount,
    String? currency,
    DateTime? expenseDate,
    required String paidBy,
    String? category,
    String? notes,
    String? paymentMethod,
    bool? isTransfer,
    required ExpenseVisibility oldVisibility,
    ExpenseVisibility visibility = ExpenseVisibility.shared,
  }) async {
    capturedUpdate = {
      'id': id,
      'title': title,
      'amount': amount,
      'currency': currency,
      'expenseDate': expenseDate,
      'paidBy': paidBy,
      'category': category,
      'notes': notes,
      'paymentMethod': paymentMethod,
      'isTransfer': isTransfer,
      'oldVisibility': oldVisibility,
      'visibility': visibility,
    };
    return id;
  }
}

class _SpySubscriptionController extends Fake implements SubscriptionController {
  Map<String, dynamic>? capturedUpdate;

  @override
  Future<void> updateSubscription({
    required String id,
    required String name,
    required double amount,
    String? currency,
    String billingCycle = 'monthly',
    required DateTime nextBillingDate,
    String? category,
    required bool isPrivate,
    DateTime? endDate,
    String? paidBy,
    String? financedThrough,
    int? totalInstallments,
    int? paidInstallments,
  }) async {
    capturedUpdate = {
      'id': id,
      'name': name,
      'amount': amount,
      'currency': currency,
      'billingCycle': billingCycle,
      'nextBillingDate': nextBillingDate,
      'category': category,
      'isPrivate': isPrivate,
      'endDate': endDate,
      'paidBy': paidBy,
      'financedThrough': financedThrough,
      'totalInstallments': totalInstallments,
      'paidInstallments': paidInstallments,
    };
  }
}

List<Override> _baseOverrides({
  CalendarController? calendarController,
  ExpenseController? expenseController,
  SubscriptionController? subscriptionController,
}) {
  final stubDb = _StubAppDatabase();
  return [
    appDatabaseProvider.overrideWithValue(stubDb),
    authProvider.overrideWith(_FakeAuthNotifier.new),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
    partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
    currencyPreferenceProvider.overrideWith(_FakeCurrencyNotifier.new),
    customCategoriesProvider.overrideWith(_FakeCustomCategoriesNotifier.new),
    previousFinancingSourcesProvider.overrideWith(
      (ref) => Future.value(const <String>['HDFC Bank', 'Amex']),
    ),
    if (calendarController != null)
      calendarControllerProvider.overrideWithValue(calendarController),
    if (expenseController != null)
      expenseControllerProvider.overrideWithValue(expenseController),
    if (subscriptionController != null)
      subscriptionControllerProvider.overrideWithValue(subscriptionController),
  ];
}

Widget _wrapSheet(Widget sheet, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: const [CoveTokens.dark],
      ),
      home: Scaffold(
        body: sheet,
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Batch 4.1f Edit Forms Round-Trip Save Verification', () {
    testWidgets(
      'CalendarEventFormSheet opens with existing record and saves exact original values',
      (tester) async {
        final spy = _SpyCalendarController();
        final existing = LocalCalendarEvent(
          id: 'ev_roundtrip_1',
          homeId: 'home_1',
          title: 'Dinner at Sienna',
          description: 'Corner booth reserved under Alex',
          startTime: DateTime(2026, 10, 15, 19, 30),
          endTime: DateTime(2026, 10, 15, 21, 30),
          isAllDay: false,
          location: 'Bandra West',
          recurrence: 'weekly',
          createdBy: 'user_alex',
          createdAt: _kFixedDate,
        );

        await tester.pumpWidget(
          _wrapSheet(
            CalendarEventFormSheet(existing: existing),
            _baseOverrides(calendarController: spy),
          ),
        );
        await tester.pumpAndSettle();

        final saveFinder = find.text('Save Changes');
        await tester.ensureVisible(saveFinder);
        await tester.pumpAndSettle();
        await tester.tap(saveFinder);
        await tester.pumpAndSettle();

        expect(spy.capturedUpdate, isNotNull);
        expect(spy.capturedUpdate!['id'], existing.id);
        expect(spy.capturedUpdate!['title'], existing.title);
        expect(spy.capturedUpdate!['description'], existing.description);
        expect(spy.capturedUpdate!['startTime'], existing.startTime);
        expect(spy.capturedUpdate!['endTime'], existing.endTime);
        expect(spy.capturedUpdate!['isAllDay'], existing.isAllDay);
        expect(spy.capturedUpdate!['location'], existing.location);
        expect(spy.capturedUpdate!['recurrence'], existing.recurrence);
      },
    );

    testWidgets(
      'ExpenseFormSheet opens with existing record and saves exact original values',
      (tester) async {
        final spy = _SpyExpenseController();
        final existing = LocalExpense(
          id: 'exp_roundtrip_1',
          homeId: 'home_1',
          title: 'Earthly Artisanal Groceries',
          amount: 2450.5,
          currency: 'INR',
          category: 'Groceries • Weekly organic box',
          paidBy: 'user_alex',
          splitRatio: 0.5,
          expenseDate: DateTime(2026, 10, 15),
          createdAt: _kFixedDate,
          paymentMethod: 'upi',
          isTransfer: false,
        );

        await tester.pumpWidget(
          _wrapSheet(
            ExpenseFormSheet(initialExpense: existing),
            _baseOverrides(expenseController: spy),
          ),
        );
        await tester.pumpAndSettle();

        final saveFinder = find.text('Update Expense');
        await tester.ensureVisible(saveFinder);
        await tester.pumpAndSettle();
        await tester.tap(saveFinder);
        await tester.pumpAndSettle();

        expect(spy.capturedUpdate, isNotNull);
        expect(spy.capturedUpdate!['id'], existing.id);
        expect(spy.capturedUpdate!['title'], existing.title);
        expect(spy.capturedUpdate!['amount'], existing.amount);
        expect(spy.capturedUpdate!['currency'], existing.currency);
        expect(spy.capturedUpdate!['expenseDate'], existing.expenseDate);
        expect(spy.capturedUpdate!['paidBy'], existing.paidBy);
        expect(spy.capturedUpdate!['category'], 'Groceries');
        expect(spy.capturedUpdate!['notes'], 'Weekly organic box');
        expect(spy.capturedUpdate!['paymentMethod'], existing.paymentMethod);
        expect(spy.capturedUpdate!['isTransfer'], existing.isTransfer);
        expect(spy.capturedUpdate!['oldVisibility'], ExpenseVisibility.shared);
        expect(spy.capturedUpdate!['visibility'], ExpenseVisibility.shared);
      },
    );

    testWidgets(
      'SubscriptionFormSheet opens with existing record and saves exact original values',
      (tester) async {
        final spy = _SpySubscriptionController();
        final existing = LocalSubscription(
          id: 'sub_roundtrip_1',
          homeId: 'home_1',
          name: 'MacBook Pro M4 EMI',
          amount: 12450.0,
          currency: 'INR',
          billingCycle: 'every_7_months',
          nextBillingDate: DateTime(2026, 10, 22),
          endDate: DateTime(2028, 2, 22),
          category: 'Hardware',
          isActive: true,
          isPrivate: false,
          paidBy: 'split',
          financedThrough: 'HDFC Regalia',
          totalInstallments: 24,
          paidInstallments: 8,
          createdBy: 'user_alex',
          createdAt: _kFixedDate,
        );

        await tester.pumpWidget(
          _wrapSheet(
            SubscriptionFormSheet(existing: existing),
            _baseOverrides(subscriptionController: spy),
          ),
        );
        await tester.pumpAndSettle();

        final saveFinder = find.text('Save Changes');
        await tester.ensureVisible(saveFinder);
        await tester.pumpAndSettle();
        await tester.tap(saveFinder);
        await tester.pumpAndSettle();

        expect(spy.capturedUpdate, isNotNull);
        expect(spy.capturedUpdate!['id'], existing.id);
        expect(spy.capturedUpdate!['name'], existing.name);
        expect(spy.capturedUpdate!['amount'], existing.amount);
        expect(spy.capturedUpdate!['currency'], existing.currency);
        expect(spy.capturedUpdate!['billingCycle'], existing.billingCycle);
        expect(
          spy.capturedUpdate!['nextBillingDate'],
          existing.nextBillingDate,
        );
        expect(spy.capturedUpdate!['category'], existing.category);
        expect(spy.capturedUpdate!['isPrivate'], existing.isPrivate);
        expect(spy.capturedUpdate!['endDate'], existing.endDate);
        expect(spy.capturedUpdate!['paidBy'], existing.paidBy);
        expect(
          spy.capturedUpdate!['financedThrough'],
          existing.financedThrough,
        );
        expect(
          spy.capturedUpdate!['totalInstallments'],
          existing.totalInstallments,
        );
        expect(
          spy.capturedUpdate!['paidInstallments'],
          existing.paidInstallments,
        );
      },
    );
  });
}
