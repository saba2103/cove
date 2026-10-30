// Baseline accessibility skip registry for Phase 5 (5.0).
//
// Populated from the 5.0 baseline audit (`build/a11y_baseline.md`).
// Trimmed Phase 5 scope: 5.0, 5.2, and a revised 5.5.
// Failures belonging to 5.1, 5.3, 5.4, or 5.6 are marked
// `'launch blocker, deferred'`; all 18 contrast checks tagged `'5.5'` were
// resolved through tokens and removed in 5.5 so they run actively in
// `flutter test` and `./tool/check.sh`.
import 'package:flutter/material.dart';

import 'a11y_harness.dart';

const String kLaunchBlockerDeferredReason = 'launch blocker, deferred';

const Map<String, Map<A11yCheckKey, String>> kA11yBaselineSkips =
    <String, Map<A11yCheckKey, String>>{
  // Screens — TodayScreen (populated)
  'today_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — TodayScreen (populated, scrolled to bottom slips)
  'today_screen_scrolled_bottom': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
  },
  // Screens — TodayScreen + CoveFloatingBar (rest, phone insets)
  'today_screen_floating_bar': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — TodayScreen (first-run)
  'today_screen_first_run': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — ExpensesScreen (populated)
  'expenses_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — ExpensesScreen (over budget, 6-digit)
  'expenses_screen_over_budget': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — ExpensesScreen + CoveFloatingBar (money, phone insets)
  'expenses_screen_floating_bar': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — SubscriptionsScreen / Commitments (populated)
  'subscriptions_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — EmiTrackerScreen
  'emi_tracker_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — CommitmentsHelicopterScreen (The Year)
  'commitments_helicopter_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — RoutineScreen (populated two-lane)
  'routine_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
  },
  // Screens — ListsScreen
  'lists_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — HabitsScreen
  'habits_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — ActivityScreen (populated)
  'activity_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — ProfileScreen (with DriveBackupSection)
  'profile_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — ProfileScreen (scrolled to DriveBackupSection & Danger Zone)
  'profile_screen_scrolled_bottom': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — AboutCoveScreen
  'about_cove_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
  },
  // Screens — ChangelogScreen
  'changelog_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
  },
  // Screens — RemindersScreen (populated)
  'reminders_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — RoadmapScreen (populated)
  'roadmap_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Screens — CreateHomeScreen
  'create_home_screen': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
  },
  // Sheets & Dialogs — CalendarEventFormSheet
  'calendar_event_form_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — ExpenseFormSheet
  'expense_form_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — SubscriptionFormSheet
  'subscription_form_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — RoutineEventFormSheet
  'routine_event_form_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — RoutineFormSheet
  'routine_form_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — HabitFormSheet
  'habit_form_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — MonthlyBudgetSheet
  'monthly_budget_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — MonthCommitmentsSheet
  'month_commitments_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — HomeSwitcherSheet
  'home_switcher_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — CurrencySelectorSheet
  'currency_selector_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — BackupPassphraseSheet
  'backup_passphrase_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — RestoreBackupSheet (pick backup step)
  'restore_backup_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — SlipListPickerSheet
  'slip_list_picker_sheet': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
  },
  // Sheets & Dialogs — EditProfileDialog
  'edit_profile_dialog': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — EditHomeDialog
  'edit_home_dialog': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — EditPartnerProfileDialog
  'edit_partner_profile_dialog': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.labeledTapTarget): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — DeleteDataDialog
  'delete_data_dialog': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.light, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.textContrast): kLaunchBlockerDeferredReason, // 5.1
  },
  // Sheets & Dialogs — CreateListDialog
  'create_list_dialog': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
  },
  // Sheets & Dialogs — WhatsFreshModal
  'whats_fresh_modal': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
  },
  // Sheets & Dialogs — PairingQrView
  'pairing_qr_view': <A11yCheckKey, String>{
    (Brightness.light, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
    (Brightness.dark, A11yGuidelineKind.androidTapTarget): kLaunchBlockerDeferredReason, // 5.1 / 5.3 / 5.6
  },
};
