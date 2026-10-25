import 'package:cove/features/auth/auth_controller.dart';
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

import 'golden_harness.dart';

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

final _kSeedCalendarEvent = LocalCalendarEvent(
  id: 'ev_1',
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

final _kSeedExpense = LocalExpense(
  id: 'exp_1',
  homeId: 'home_1',
  title: 'Earthly Artisanal Groceries',
  amount: 2450.0,
  currency: 'INR',
  category: 'Groceries • Weekly organic box',
  paidBy: 'user_alex',
  splitRatio: 0.5,
  expenseDate: DateTime(2026, 10, 15),
  createdAt: _kFixedDate,
  paymentMethod: 'upi',
  isTransfer: false,
);

final _kSeedSubscription = LocalSubscription(
  id: 'sub_1',
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

List<Override> _createOverrides() {
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
  ];
}

Widget _sheetHost(Widget sheet) {
  return Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: sheet,
    ),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Batch 4.1f Edit Forms Goldens (3 widths × 2 modes)', () {
    testWidgets('edit_41f_calendar_event_form_sheet', (tester) async {
      await goldenMatrix(
        tester,
        'edit_41f_calendar_event_form_sheet',
        _sheetHost(
          CalendarEventFormSheet(
            existing: _kSeedCalendarEvent,
          ),
        ),
        overrides: _createOverrides(),
        wrap: wrapInAppShellConstraint,
      );
    });

    testWidgets('edit_41f_expense_form_sheet', (tester) async {
      await goldenMatrix(
        tester,
        'edit_41f_expense_form_sheet',
        _sheetHost(
          ExpenseFormSheet(
            initialExpense: _kSeedExpense,
          ),
        ),
        overrides: _createOverrides(),
        wrap: wrapInAppShellConstraint,
      );
    });

    testWidgets('edit_41f_subscription_form_sheet', (tester) async {
      await goldenMatrix(
        tester,
        'edit_41f_subscription_form_sheet',
        _sheetHost(
          SubscriptionFormSheet(
            existing: _kSeedSubscription,
          ),
        ),
        overrides: _createOverrides(),
        wrap: wrapInAppShellConstraint,
        allowedOverflows: const {
          'edit_41f_subscription_form_sheet.cover',
          'edit_41f_subscription_form_sheet.phone',
          'edit_41f_subscription_form_sheet.wide',
        },
      );
    });
  });
}
