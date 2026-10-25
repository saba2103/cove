import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/add/add_flow.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/habits/habit_controller.dart';
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
  final fixedTomorrow = DateTime(2026, 10, 6);

  List<Override> buildGoldenOverrides() {
    final homeLists = <LocalList>[
      LocalList(
        id: 'list_grocery',
        homeId: 'home_1',
        name: 'Grocery',
        isArchived: false,
        createdAt: fixedToday,
        createdBy: 'user_saba',
      ),
      LocalList(
        id: 'list_home',
        homeId: 'home_1',
        name: 'Home',
        isArchived: false,
        createdAt: fixedToday,
        createdBy: 'user_saba',
      ),
      LocalList(
        id: 'list_travel',
        homeId: 'home_1',
        name: 'Travel',
        isArchived: false,
        createdAt: fixedToday,
        createdBy: 'user_saba',
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
        (ref) => Stream<List<LocalList>>.value(homeLists),
      ),
      activeHomeAllListItemsProvider.overrideWith(
        (ref) => Stream<List<LocalListItem>>.value(const <LocalListItem>[]),
      ),
      activeHomeHabitsProvider.overrideWith(
        (ref) => Stream<List<LocalHabit>>.value(const <LocalHabit>[]),
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

  final fullTaskDraft = TaskDraft(
    title: 'Gas cylinder',
    listId: 'list_home',
    dueDate: fixedTomorrow,
    noParticularDay: false,
    listCount: 3,
    openedFromList: false,
  );

  final fullHabitDraft = HabitDraft(
    name: 'Morning walk',
    frequencyOption: HabitFrequencyOption.pickDays,
    customDays: const <int>{1, 3, 5},
    visibility: HabitVisibility.shared,
    hasPartner: true,
  );

  testWidgets(
    '1. AddFlow task step 2 (Which list?) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_task_2_which_list',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.task,
            initialDraft: fullTaskDraft,
            initialStepIndex: 1,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '2. AddFlow task step 4 (Review — CoveNote) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_task_4_review',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.task,
            initialDraft: fullTaskDraft,
            initialStepIndex: 3,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '3. AddFlow habit step 2 (How often? with Pick the days week toggles) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_habit_2_how_often',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.habit,
            initialDraft: fullHabitDraft,
            initialStepIndex: 1,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );

  testWidgets(
    '4. AddFlow habit step 4 (Review — CoveHabitCard in no-history state) golden matrix (3 widths × 2 modes)',
    (tester) async {
      await goldenMatrix(
        tester,
        'add_flow_habit_4_review',
        _AddFlowGoldenStage(
          child: AddFlow(
            initialKind: AddKind.habit,
            initialDraft: fullHabitDraft,
            initialStepIndex: 3,
          ),
        ),
        overrides: buildGoldenOverrides(),
        clock: fixedClock,
      );
    },
  );
}
