import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/add/add_flow.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

class _GoldenAuthNotifier extends AuthNotifier {
  @override
  AsyncValue<CoveUser?> build() => const AsyncValue.data(
        CoveUser(id: 'user_saba', email: 'saba@cove.app', displayName: 'Saba'),
      );
}

class _GoldenUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState(
        displayName: 'Saba',
        email: 'saba@cove.app',
      );
}

class _GoldenPartnerProfileNotifier extends PartnerProfileNotifier {
  @override
  PartnerProfileState build() => const PartnerProfileState(
        displayName: 'Ancy',
        userId: 'user_ancy',
        hasCustomName: true,
      );
}

class _GoldenCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() => const CurrencyOption(
        code: 'INR',
        symbol: '₹',
        name: 'Indian Rupee',
      );
}

class _GoldenCustomCategoriesNotifier extends CustomCategoriesNotifier {
  @override
  List<String> build() => const <String>[];
}

/// Renders [child] anchored to the bottom of a `surface.canvas` backdrop,
/// matching the modal sheet presentation of `AddFlow.show`.
class _AddFlowGoldenStage extends StatelessWidget {
  final Widget child;

  const _AddFlowGoldenStage({required this.child});

  @override
  Widget build(BuildContext context) {
    final cv = context.cv;
    return Scaffold(
      backgroundColor: cv.surfaceCanvas,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: CoveSize.maxContent),
          child: child,
        ),
      ),
    );
  }
}

void main() {
  final fixedClock = Clock.fixed(DateTime(2026, 10, 5, 10, 30));
  final fixedToday = DateTime(2026, 10, 5);

  List<Override> buildGoldenOverrides() {
    final recentExpenses = <LocalExpense>[
      LocalExpense(
        id: 'exp_1',
        homeId: 'home_1',
        title: "Namdhari's",
        amount: 1420,
        currency: 'INR',
        expenseDate: DateTime(2026, 10, 3),
        paidBy: 'user_saba',
        splitRatio: 0.5,
        category: 'Groceries',
        paymentMethod: 'upi',
        isTransfer: false,
        createdAt: DateTime(2026, 10, 3),
      ),
      LocalExpense(
        id: 'exp_2',
        homeId: 'home_1',
        title: 'Blue Tokai',
        amount: 640,
        currency: 'INR',
        expenseDate: DateTime(2026, 10, 2),
        paidBy: 'user_saba',
        splitRatio: 0.5,
        category: 'Dining',
        paymentMethod: 'upi',
        isTransfer: false,
        createdAt: DateTime(2026, 10, 2),
      ),
      LocalExpense(
        id: 'exp_3',
        homeId: 'home_1',
        title: 'Toit',
        amount: 1280,
        currency: 'INR',
        expenseDate: DateTime(2026, 10, 1),
        paidBy: 'user_saba',
        splitRatio: 0.5,
        category: 'Dining',
        paymentMethod: 'card',
        isTransfer: false,
        createdAt: DateTime(2026, 10, 1),
      ),
      LocalExpense(
        id: 'exp_4',
        homeId: 'home_1',
        title: 'BESCOM',
        amount: 1850,
        currency: 'INR',
        expenseDate: DateTime(2026, 9, 28),
        paidBy: 'user_saba',
        splitRatio: 0.5,
        category: 'Utilities',
        paymentMethod: 'upi',
        isTransfer: false,
        createdAt: DateTime(2026, 9, 28),
      ),
      LocalExpense(
        id: 'exp_5',
        homeId: 'home_1',
        title: 'Swiggy Instamart',
        amount: 520,
        currency: 'INR',
        expenseDate: DateTime(2026, 9, 25),
        paidBy: 'user_saba',
        splitRatio: 0.5,
        category: 'Groceries',
        paymentMethod: 'upi',
        isTransfer: false,
        createdAt: DateTime(2026, 9, 25),
      ),
    ];

    return <Override>[
      authProvider.overrideWith(_GoldenAuthNotifier.new),
      activeHomeProvider.overrideWith(
        (ref) => Stream<LocalHome?>.value(
          LocalHome(
            id: 'home_1',
            name: 'Our Home',
            currency: 'INR',
            createdBy: 'user_saba',
            createdAt: fixedToday,
          ),
        ),
      ),
      activeHomeListsProvider.overrideWith(
        (ref) => Stream<List<LocalList>>.value(const <LocalList>[]),
      ),
      activeHomeExpensesProvider.overrideWith(
        (ref) => Stream<List<LocalExpense>>.value(recentExpenses),
      ),
      activeHomeCalendarEventsProvider.overrideWith(
        (ref) => Stream<List<LocalCalendarEvent>>.value(
          const <LocalCalendarEvent>[],
        ),
      ),
      userProfileProvider.overrideWith(_GoldenUserProfileNotifier.new),
      partnerProfileProvider.overrideWith(_GoldenPartnerProfileNotifier.new),
      currencyPreferenceProvider.overrideWith(_GoldenCurrencyNotifier.new),
      customCategoriesProvider.overrideWith(
        _GoldenCustomCategoriesNotifier.new,
      ),
    ];
  }

  ExpenseDraft buildSampleExpenseDraft() {
    return ExpenseDraft(
      amount: 2140,
      title: "Namdhari's",
      expenseDate: fixedToday,
      category: 'Groceries',
      payer: ExpensePayer.you,
      splitHalfAndHalf: true,
      isPrivate: false,
      paymentMethod: 'upi',
      viewerUserId: 'user_saba',
      partnerUserId: 'user_ancy',
      hasPartner: true,
    );
  }

  testWidgets('1. AddFlow picker golden matrix (3 widths × 2 modes)', (
    tester,
  ) async {
    await goldenMatrix(
      tester,
      'add_flow_picker',
      _AddFlowGoldenStage(
        child: AddFlow(
          againSummary: AddAgainSummary(
            kind: AddKind.expense,
            titleAndContext: 'Toit · Dining',
            lastReadout: '₹1,280',
            onTap: () {},
          ),
        ),
      ),
      overrides: buildGoldenOverrides(),
      clock: fixedClock,
    );
  });

  testWidgets(
    '2. AddFlow expense step 1 (How much?) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_expense_1_amount',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.expense,
            initialDraft: buildSampleExpenseDraft(),
            initialStepIndex: 0,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '3. AddFlow expense step 2 (What for?) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_expense_2_title',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.expense,
            initialDraft: buildSampleExpenseDraft(),
            initialStepIndex: 1,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '4. AddFlow expense step 3 (When?) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_expense_3_when',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.expense,
            initialDraft: buildSampleExpenseDraft(),
            initialStepIndex: 2,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '5. AddFlow expense step 4 (Which category?) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_expense_4_category',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.expense,
            initialDraft: buildSampleExpenseDraft(),
            initialStepIndex: 3,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '6. AddFlow expense step 5 (Who paid?) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_expense_5_who',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.expense,
            initialDraft: buildSampleExpenseDraft(),
            initialStepIndex: 4,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '7. AddFlow expense step 6 (On what?) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_expense_6_payment',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.expense,
            initialDraft: buildSampleExpenseDraft(),
            initialStepIndex: 5,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '8. AddFlow expense step 7 (Review) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_expense_7_review',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.expense,
            initialDraft: buildSampleExpenseDraft(),
            initialStepIndex: 6,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '9. AddFlow expense Added state golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_expense_8_added',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.expense,
            initialDraft: buildSampleExpenseDraft(),
            initialStepIndex: 6,
            initialIsAdded: true,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );
}
