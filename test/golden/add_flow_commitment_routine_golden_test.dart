import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/slips/cove_voucher.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/add/add_flow.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/routines/routine_models.dart';
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
      activeHomeAllListItemsProvider.overrideWith(
        (ref) => Stream<List<LocalListItem>>.value(const <LocalListItem>[]),
      ),
      activeHomeHabitsProvider.overrideWith(
        (ref) => Stream<List<LocalHabit>>.value(const <LocalHabit>[]),
      ),
      activeHomeSubscriptionsProvider.overrideWith(
        (ref) => Stream<List<LocalSubscription>>.value(
          const <LocalSubscription>[],
        ),
      ),
      activeHomeRoutinesProvider.overrideWith(
        (ref) => Stream<List<Routine>>.value(const <Routine>[]),
      ),
      activeHomeAllRoutineEventsProvider.overrideWith(
        (ref) => Stream<List<RoutineEvent>>.value(const <RoutineEvent>[]),
      ),
      activeHomeExpensesProvider.overrideWith(
        (ref) => Stream<List<LocalExpense>>.value(const <LocalExpense>[]),
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

  final monthlyDraft = CommitmentDraft(
    name: 'Spotify Duo',
    amount: 149,
    cycle: CommitmentCycleOption.everyMonth,
    dayOfMonth: 8,
    paidFrom: 'BOB',
    owner: CommitmentOwner.you,
    isPrivate: false,
    today: fixedToday,
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
  );

  final yearlyDraft = CommitmentDraft(
    name: 'Car insurance',
    amount: 14200,
    cycle: CommitmentCycleOption.everyYear,
    dueMonth: 11,
    dayOfMonth: 15,
    paidFrom: 'HDFC Regalia',
    owner: CommitmentOwner.both,
    isPrivate: false,
    today: fixedToday,
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
  );

  final emiDraft = CommitmentDraft(
    name: 'AC — the instalment',
    amount: 3974,
    cycle: CommitmentCycleOption.emi,
    totalInstallments: 12,
    paidInstallments: 3,
    dayOfMonth: 5,
    paidFrom: 'BOB',
    owner: CommitmentOwner.both,
    isPrivate: false,
    today: fixedToday,
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
  );

  final routineDraft = RoutineDraft(
    title: 'Morning tea',
    startMinutes: 8 * 60, // 8:00 AM
    durationMinutes: 30, // -> 8:30 AM (510)
    days: const <int>{1, 2, 3, 4, 5},
  );

  testWidgets(
    '1. AddFlow commitment step 3 (How often does it come? — cycle step) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_commitment_3_cycle',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.commitment,
            initialDraft: monthlyDraft,
            initialStepIndex: 2,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '2. AddFlow commitment step 4 (When is the next one due? — next-date step) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_commitment_4_next_date',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.commitment,
            initialDraft: yearlyDraft,
            initialStepIndex: 3,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '3. AddFlow commitment EMI step 4 (total instalments) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_commitment_4_emi_total',
        _AddFlowGoldenStage(
          child: AddFlow(
            key: const ValueKey('emi_step_4_total'),
            initialKind: AddKind.commitment,
            initialDraft: emiDraft,
            initialStepIndex: 3,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '4. AddFlow commitment EMI step 5 (paid instalments) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_commitment_5_emi_paid',
        _AddFlowGoldenStage(
          child: AddFlow(
            key: const ValueKey('emi_step_5_paid'),
            initialKind: AddKind.commitment,
            initialDraft: emiDraft,
            initialStepIndex: 4,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '5. AddFlow commitment step 7 review (CoveVoucher standard) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_commitment_7_review',
        _AddFlowGoldenStage(
          child: AddFlow(
            key: const ValueKey('commitment_step_7_review'),
            initialKind: AddKind.commitment,
            initialDraft: monthlyDraft,
            initialStepIndex: 6,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '6. AddFlow commitment step 9 EMI review (CoveVoucher punched EMI, 12 instalments, 3 paid) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_commitment_9_emi_review',
        _AddFlowGoldenStage(
          child: AddFlow(
            key: const ValueKey('commitment_step_9_emi_review'),
            initialKind: AddKind.commitment,
            initialDraft: emiDraft,
            initialStepIndex: 8,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );

      final voucher = tester.widget<CoveVoucher>(find.byType(CoveVoucher));
      expect(voucher.isEmi, isTrue);
      expect(voucher.totalInstallments, equals(12));
      expect(voucher.paidInstallments, equals(3));
    },
  );

  testWidgets(
    '7. AddFlow routine step 5 (Review — CoveBand) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_routine_5_review',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.routine,
            initialDraft: routineDraft,
            initialStepIndex: 4,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );
}
