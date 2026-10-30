// Complete fixture registry for Cove Phase 5 accessibility tests (5.0+).
//
// Reuses the deterministic golden fixture states across:
//   1. Every screen (populated, variants, floating-bar insets, first-run, auth,
//      onboarding, recovery, splash)
//   2. Every sheet, modal, and dialog (detail sheets, edit/form sheets, utility
//      sheets, backup sheets, pet picker, pairing views, dialogs)
//   3. Every Add flow step across all 6 AddKinds (picker, Again, Expense 1..7 +
//      Added, Event 1..6, Task 1..5 + NameTheList, Habit 1..4, Commitment
//      standard 1..7 + Yearly + EMI 1..9, Routine 1..6)
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:cove/core/theme/cove_tokens.dart';
import 'package:cove/core/widgets/cove_avatar.dart';
import 'package:cove/core/widgets/cove_floating_bar.dart';
import 'package:cove/core/widgets/cove_splash_screen.dart';
import 'package:cove/core/widgets/cove_sync_tick.dart';
import 'package:cove/features/activity/activity_controller.dart';
import 'package:cove/features/activity/activity_detail_sheet.dart';
import 'package:cove/features/activity/activity_models.dart';
import 'package:cove/features/activity/activity_read_status_controller.dart';
import 'package:cove/features/activity/activity_screen.dart';
import 'package:cove/features/add/add_draft.dart';
import 'package:cove/features/add/add_flow.dart';
import 'package:cove/features/add/widgets/add_day_strip.dart';
import 'package:cove/features/auth/auth_controller.dart';
import 'package:cove/features/auth/sign_in_screen.dart';
import 'package:cove/features/backup/drive_backup_controller.dart';
import 'package:cove/features/backup/drive_backup_remote.dart';
import 'package:cove/features/backup/drive_backup_sheets.dart';
import 'package:cove/features/calendar/calendar_controller.dart';
import 'package:cove/features/calendar/calendar_event_form_sheet.dart';
import 'package:cove/features/calendar/calendar_models.dart';
import 'package:cove/features/calendar/calendar_screen.dart';
import 'package:cove/features/calendar/views/calendar_month_view.dart';
import 'package:cove/features/changelog/changelog_screen.dart';
import 'package:cove/features/changelog/whats_fresh_modal.dart';
import 'package:cove/features/expenses/category_detail_sheet.dart';
import 'package:cove/features/expenses/expense_controller.dart';
import 'package:cove/features/expenses/expense_detail_sheet.dart';
import 'package:cove/features/expenses/expense_form_sheet.dart';
import 'package:cove/features/expenses/expenses_screen.dart';
import 'package:cove/features/expenses/monthly_budget_controller.dart';
import 'package:cove/features/expenses/monthly_budget_sheet.dart';
import 'package:cove/features/habits/habit_controller.dart';
import 'package:cove/features/habits/habit_detail_sheet.dart';
import 'package:cove/features/habits/habit_form_sheet.dart';
import 'package:cove/features/habits/habits_screen.dart';
import 'package:cove/features/home/about_cove_screen.dart';
import 'package:cove/features/home/create_home_screen.dart';
import 'package:cove/features/home/home_settings_screen.dart';
import 'package:cove/features/home/home_switcher_sheet.dart';
import 'package:cove/features/home/join_home_screen.dart';
import 'package:cove/features/home/missing_home_key_screen.dart';
import 'package:cove/features/home/onboarding_choice_screen.dart';
import 'package:cove/features/lists/create_list_dialog.dart';
import 'package:cove/features/lists/list_controller.dart';
import 'package:cove/features/lists/list_item_detail_sheet.dart';
import 'package:cove/features/lists/lists_screen.dart';
import 'package:cove/features/notifications/notification_controller.dart';
import 'package:cove/features/notifications/notification_models.dart';
import 'package:cove/features/pets/pet_controller.dart';
import 'package:cove/features/pets/pet_tag_widgets.dart';
import 'package:cove/features/profile/currency_selector_sheet.dart';
import 'package:cove/features/profile/delete_data_dialog.dart';
import 'package:cove/features/profile/edit_home_dialog.dart';
import 'package:cove/features/profile/edit_partner_profile_dialog.dart';
import 'package:cove/features/profile/edit_profile_dialog.dart';
import 'package:cove/features/profile/home_metadata_controller.dart';
import 'package:cove/features/profile/partner_profile_controller.dart';
import 'package:cove/features/profile/preferences_controller.dart';
import 'package:cove/features/profile/profile_screen.dart';
import 'package:cove/features/profile/user_profile_controller.dart';
import 'package:cove/features/reminders/reminder_controller.dart';
import 'package:cove/features/reminders/reminder_models.dart';
import 'package:cove/features/reminders/reminders_screen.dart';
import 'package:cove/features/roadmap/roadmap_controller.dart';
import 'package:cove/features/roadmap/roadmap_screen.dart';
import 'package:cove/features/routines/routine_controller.dart';
import 'package:cove/features/routines/routine_event_form_sheet.dart';
import 'package:cove/features/routines/routine_form_sheet.dart';
import 'package:cove/features/routines/routine_models.dart';
import 'package:cove/features/routines/routine_screen.dart';
import 'package:cove/features/subscriptions/commitment_detail_sheet.dart';
import 'package:cove/features/subscriptions/commitment_projection_utils.dart';
import 'package:cove/features/subscriptions/commitments_helicopter_screen.dart';
import 'package:cove/features/subscriptions/emi_tracker_screen.dart';
import 'package:cove/features/subscriptions/month_commitments_sheet.dart';
import 'package:cove/features/subscriptions/subscription_controller.dart';
import 'package:cove/features/subscriptions/subscription_form_sheet.dart';
import 'package:cove/features/subscriptions/subscriptions_screen.dart';
import 'package:cove/features/today/today_controller.dart';
import 'package:cove/features/today/today_models.dart';
import 'package:cove/features/today/today_screen.dart';
import 'package:cove/features/weather/weather_controller.dart';
import 'package:cove/features/weather/weather_model.dart';
import 'package:cove/features/weather/widgets/weather_detail_sheet.dart';
import 'package:cove/features/widgets/cove_slip_widget.dart';
import 'package:cove/sync/db/app_database.dart';
import 'package:cove/sync/key_management/home_key_store.dart';
import 'package:cove/sync/key_management/pairing_approval_sheet.dart';
import 'package:cove/sync/key_management/pairing_payload.dart';
import 'package:cove/sync/key_management/pairing_qr_view.dart';
import 'package:cove/sync/key_management/pairing_relay.dart';
import 'package:cove/sync/providers/active_home_provider.dart';
import 'package:cove/sync/providers/cove_sync_providers.dart';
import 'package:cove/sync/providers/first_run_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_backup_remote.dart';
import 'a11y_harness.dart';
import 'a11y_skips.dart';

// ---------------------------------------------------------------------------
// Deterministic Golden Seed Data
// ---------------------------------------------------------------------------

final DateTime kA11yFixedDate = DateTime(2026, 10, 15, 10, 30);
final DateTime kA11yFixedCreatedAt = DateTime(2026, 1, 10, 9, 0);
final DateTime kA11yFixedAnniversary = DateTime(2023, 6, 15);
final DateTime kA11yFixedEndDate = DateTime(2027, 6, 15);
final DateTime kA11yFirstRunDate = DateTime(2026, 10, 21, 9, 41);
final DateTime kA11yAddFixedDate = DateTime(2026, 10, 5, 10, 30);
final DateTime kA11yAddToday = DateTime(2026, 10, 5);
final DateTime kA11yAddTomorrow = DateTime(2026, 10, 6);

final Clock kA11yFirstRunClock = Clock.fixed(kA11yFirstRunDate);
final Clock kA11yAddClock = Clock.fixed(kA11yAddFixedDate);

const CoveUser _kAlexUser = CoveUser(
  id: 'user_alex',
  email: 'alex@cove.test',
  displayName: 'Alex',
);

const UserProfileState _kAlexProfile = UserProfileState(
  displayName: 'Alex',
  email: 'alex@cove.test',
  hasCustomName: true,
);

const PartnerProfileState _kSarahPartnerProfile = PartnerProfileState(
  displayName: 'Sarah',
  userId: 'user_sarah',
  hasCustomName: true,
);

const CoveUser _kSabaUser = CoveUser(
  id: 'user_saba',
  email: 'saba@cove.app',
  displayName: 'Saba',
);

const UserProfileState _kSabaProfile = UserProfileState(
  displayName: 'Saba',
  email: 'saba@cove.app',
);

const PartnerProfileState _kAncyPartnerProfile = PartnerProfileState(
  displayName: 'Ancy',
  userId: 'user_ancy',
  hasCustomName: true,
);

final LocalHome _kSeedHome1 = LocalHome(
  id: 'home_1',
  name: 'Our Home',
  description: 'Alex & Sarah Sanctuary',
  icon: 'cottage',
  currency: 'INR',
  monthlyBudget: 85000.0,
  anniversaryDate: kA11yFixedAnniversary,
  createdAt: kA11yFixedCreatedAt,
  createdBy: 'user_alex',
);

final LocalHome _kSeedHome2 = LocalHome(
  id: 'home_2',
  name: 'Weekend Cabin',
  description: 'Alibaug Getaway',
  icon: 'cabin',
  currency: 'INR',
  createdAt: kA11yFixedCreatedAt,
  createdBy: 'user_alex',
);

final HomeMetadataState _kSeedHomeMetadata = HomeMetadataState(
  homeId: 'home_1',
  anniversaryDate: kA11yFixedAnniversary,
  formattedTogetherDuration: 'Together for 3 years, 4 months',
);

final DriveBackupState _kSeedBackupState = DriveBackupState(
  isLoaded: true,
  isConnected: true,
  accountEmail: 'alex@cove.test',
  hasPassphrase: true,
  lastBackupAt: kA11yFixedDate,
  lastBackupSizeBytes: 48 * 1024,
  autoEnabled: true,
  autoTime: const TimeOfDay(hour: 2, minute: 0),
  autoWifiOnly: true,
  autoLastRunAt: kA11yFixedDate,
);

final WeatherData _kSeedWeather = WeatherData(
  temperatureC: 27.0,
  apparentTemperatureC: 28.0,
  condition: 'Mainly clear',
  weatherCode: 1,
  isDay: true,
  cityName: 'Mumbai',
  latitude: 19.0760,
  longitude: 72.8777,
  updatedAt: kA11yFixedDate,
  isLiveGps: true,
);

final List<LocalPet> _kSeedPets = <LocalPet>[
  LocalPet(
    id: 'pet_lyla',
    homeId: 'home_1',
    name: 'Lyla',
    createdAt: kA11yFixedCreatedAt,
    createdBy: 'user_alex',
    isArchived: false,
  ),
  LocalPet(
    id: 'pet_milo',
    homeId: 'home_1',
    name: 'Milo',
    createdAt: kA11yFixedCreatedAt,
    createdBy: 'user_sarah',
    isArchived: true,
  ),
];

final List<LocalPetTag> _kSeedPetTags = <LocalPetTag>[
  LocalPetTag(
    id: 'ptag_1',
    homeId: 'home_1',
    petId: 'pet_lyla',
    recordKind: PetRecordKind.expense,
    recordId: 'exp_1',
    createdAt: kA11yFixedDate,
  ),
];

final List<LocalExpense> _kSeedExpenses = <LocalExpense>[
  LocalExpense(
    id: 'exp_1',
    homeId: 'home_1',
    title: 'Farmers Market Produce',
    amount: 1450.50,
    currency: 'INR',
    paidBy: 'user_alex',
    splitRatio: 0.5,
    expenseDate: kA11yFixedDate,
    category: 'Groceries',
    paymentMethod: 'upi',
    isTransfer: false,
    createdAt: kA11yFixedDate,
  ),
  LocalExpense(
    id: 'exp_2',
    homeId: 'home_1',
    title: 'Electricity & Fiber Internet',
    amount: 3200.0,
    currency: 'INR',
    paidBy: 'user_sarah',
    splitRatio: 0.5,
    expenseDate: DateTime(2026, 10, 12, 18, 0),
    category: 'Home & Utilities',
    paymentMethod: 'card',
    isTransfer: false,
    createdAt: DateTime(2026, 10, 12, 18, 0),
  ),
];

final List<LocalExpense> _kOverBudgetExpenses = <LocalExpense>[
  LocalExpense(
    id: 'exp_over_1',
    homeId: 'home_1',
    title: 'Kitchen Remodel & Appliances',
    amount: 225664.0,
    currency: 'INR',
    paidBy: 'user_alex',
    splitRatio: 0.5,
    expenseDate: kA11yFixedDate,
    category: 'Home & Utilities',
    paymentMethod: 'card',
    isTransfer: false,
    createdAt: kA11yFixedDate,
  ),
  _kSeedExpenses[1],
];

final List<LocalSubscription> _kSeedSubscriptions = <LocalSubscription>[
  LocalSubscription(
    id: 'sub_1',
    homeId: 'home_1',
    name: 'Apple One Family',
    amount: 365.0,
    currency: 'INR',
    billingCycle: 'monthly',
    nextBillingDate: DateTime(2026, 10, 20),
    category: 'Entertainment',
    isActive: true,
    isPrivate: false,
    createdBy: 'user_alex',
    createdAt: kA11yFixedCreatedAt,
    paidBy: 'split',
    financedThrough: 'HDFC Regalia',
  ),
  LocalSubscription(
    id: 'sub_emi_1',
    homeId: 'home_1',
    name: 'Home Solar Panel Loan',
    amount: 8500.0,
    currency: 'INR',
    billingCycle: 'monthly',
    nextBillingDate: DateTime(2026, 10, 25),
    category: 'Home & Utilities',
    isActive: true,
    isPrivate: false,
    createdBy: 'user_alex',
    createdAt: kA11yFixedCreatedAt,
    endDate: kA11yFixedEndDate,
    paidBy: 'user_alex',
    financedThrough: 'SBI Home Finance',
    totalInstallments: 12,
    paidInstallments: 6,
  ),
];

final MonthCommitmentSummary _kSeedMonthCommitmentSummary =
    MonthCommitmentSummary(
  year: 2026,
  month: 10,
  items: <ProjectedCommitmentItem>[
    ProjectedCommitmentItem(
      subscription: _kSeedSubscriptions[1],
      projectedDate: DateTime(2026, 10, 25),
      amount: 8500.0,
      isEmi: true,
      isAnnual: false,
    ),
    ProjectedCommitmentItem(
      subscription: _kSeedSubscriptions[0],
      projectedDate: DateTime(2026, 10, 20),
      amount: 365.0,
      isEmi: false,
      isAnnual: false,
    ),
  ],
);

final List<LocalCalendarEvent> _kSeedCalendarEvents = <LocalCalendarEvent>[
  LocalCalendarEvent(
    id: 'cal_1',
    homeId: 'home_1',
    title: 'Dinner with Sarah at Bastian',
    description: 'Table reserved for 8:00 PM',
    startTime: DateTime(2026, 10, 15, 20, 0),
    endTime: DateTime(2026, 10, 15, 22, 0),
    isAllDay: false,
    location: 'Bandra West',
    recurrence: 'weekly',
    createdAt: kA11yFixedCreatedAt,
    createdBy: 'user_alex',
  ),
];

final List<LocalList> _kSeedLists = <LocalList>[
  LocalList(
    id: 'list_1',
    homeId: 'home_1',
    name: 'Groceries',
    isArchived: false,
    createdAt: kA11yFixedCreatedAt,
    createdBy: 'user_alex',
  ),
  LocalList(
    id: 'list_2',
    homeId: 'home_1',
    name: 'Weekend Errands',
    isArchived: false,
    createdAt: kA11yFixedCreatedAt,
    createdBy: 'user_sarah',
  ),
];

final List<LocalListItem> _kSeedListItems = <LocalListItem>[
  LocalListItem(
    id: 'item_1',
    homeId: 'home_1',
    listId: 'list_1',
    title: 'Sourdough country loaf',
    notes: 'From Subko Cacao',
    dueDate: kA11yFixedDate,
    isCompleted: false,
    createdAt: kA11yFixedCreatedAt,
    createdBy: 'user_alex',
  ),
  LocalListItem(
    id: 'item_2',
    homeId: 'home_1',
    listId: 'list_1',
    title: 'Organic oat milk (2 cartons)',
    isCompleted: true,
    completedAt: kA11yFixedDate,
    completedBy: 'user_sarah',
    createdAt: kA11yFixedCreatedAt,
    createdBy: 'user_sarah',
  ),
];

final List<LocalHabit> _kSeedHabits = <LocalHabit>[
  LocalHabit(
    id: 'habit_1',
    homeId: 'home_1',
    name: 'Morning Walk Together',
    cadence: 'daily',
    targetDaysPerWeek: 7,
    isArchived: false,
    createdAt: kA11yFixedCreatedAt,
    createdBy: 'user_alex',
  ),
  LocalHabit(
    id: 'habit_2',
    homeId: 'home_1',
    name: 'Evening Reading (30m)',
    cadence: 'daily',
    targetDaysPerWeek: 7,
    isArchived: false,
    createdAt: kA11yFixedCreatedAt,
    createdBy: 'user_sarah',
  ),
  LocalHabit(
    id: 'habit_3',
    homeId: 'home_1',
    name: 'Journaling & Breathwork',
    cadence: 'custom:1,3,5@07:30',
    targetDaysPerWeek: -3,
    isArchived: false,
    createdAt: kA11yFixedCreatedAt,
    createdBy: 'user_alex',
  ),
];

final List<LocalHabitCheckin> _kSeedHabitCheckins = <LocalHabitCheckin>[
  LocalHabitCheckin(
    id: 'chk_1',
    homeId: 'home_1',
    habitId: 'habit_1',
    checkinDate: '2026-10-15',
    memberId: 'user_alex',
    createdAt: kA11yFixedDate,
  ),
  LocalHabitCheckin(
    id: 'chk_2',
    homeId: 'home_1',
    habitId: 'habit_1',
    checkinDate: '2026-10-15',
    memberId: 'user_sarah',
    createdAt: kA11yFixedDate,
  ),
];

final List<Routine> _kSeedRoutines = <Routine>[
  Routine(
    id: 'routine_1',
    homeId: 'home_1',
    name: 'Weekdays',
    days: const <int>[1, 2, 3, 4, 5],
    createdAt: kA11yFixedCreatedAt,
  ),
  Routine(
    id: 'routine_2',
    homeId: 'home_1',
    name: 'Everyday',
    days: const <int>[1, 2, 3, 4, 5, 6, 7],
    createdAt: kA11yFixedCreatedAt,
  ),
  Routine(
    id: 'routine_3',
    homeId: 'home_1',
    name: 'Weekend',
    days: const <int>[6, 7],
    createdAt: kA11yFixedCreatedAt,
  ),
];

final List<RoutineEvent> _kSeedRoutineEvents = <RoutineEvent>[
  RoutineEvent(
    id: 'rev_1',
    routineId: 'routine_1',
    homeId: 'home_1',
    title: 'Coffee together',
    startMinutes: 390,
    endMinutes: 420,
    category: 'Meals',
    owner: 'both',
    notes: '15g coffee, 250ml water',
    createdAt: kA11yFixedCreatedAt,
  ),
  RoutineEvent(
    id: 'rev_2',
    routineId: 'routine_1',
    homeId: 'home_1',
    title: 'Morning Pour-Over & Stretch',
    startMinutes: 420,
    endMinutes: 480,
    category: 'Wellness',
    owner: 'user_alex',
    createdAt: kA11yFixedCreatedAt,
  ),
  RoutineEvent(
    id: 'rev_3',
    routineId: 'routine_1',
    homeId: 'home_1',
    title: 'Morning Yoga',
    startMinutes: 420,
    endMinutes: 480,
    category: 'Fitness',
    owner: 'user_sarah',
    createdAt: kA11yFixedCreatedAt,
  ),
  RoutineEvent(
    id: 'rev_4',
    routineId: 'routine_1',
    homeId: 'home_1',
    title: 'Deep Focus Block',
    startMinutes: 540,
    endMinutes: 660,
    category: 'Work',
    owner: 'user_alex',
    createdAt: kA11yFixedCreatedAt,
  ),
];

final List<FormattedActivityItem> _kSeedActivities = <FormattedActivityItem>[
  FormattedActivityItem(
    id: 'act_1',
    homeId: 'home_1',
    actorId: 'user_alex',
    actorName: 'You',
    actionText: 'logged ₹1,450.50 for Farmers Market Produce',
    detailSubtitle: 'Groceries · Shared 50/50',
    eventType: 'expense_logged',
    module: ActivityModule.expenses,
    icon: Icons.receipt_long_outlined,
    timestamp: kA11yFixedDate,
    timeAgo: '2h ago',
    syncStatus: CoveSyncStatus.syncedToPartner,
    isPrivate: false,
    isLocalActor: true,
    entityId: 'exp_1',
  ),
  FormattedActivityItem(
    id: 'act_2',
    homeId: 'home_1',
    actorId: 'user_sarah',
    actorName: 'Sarah',
    actionText: "checked off 'Organic oat milk (2 cartons)' in Groceries",
    eventType: 'list_item_toggled',
    module: ActivityModule.lists,
    icon: Icons.check_circle_outline_rounded,
    timestamp: kA11yFixedDate.subtract(const Duration(hours: 3)),
    timeAgo: '5h ago',
    syncStatus: CoveSyncStatus.syncedToPartner,
    isPrivate: false,
    isLocalActor: false,
    entityId: 'item_2',
  ),
];

final List<CheckinReminder> _kSeedReminders = <CheckinReminder>[
  CheckinReminder(
    id: 'rem_1',
    hour: 20,
    minute: 30,
    message: 'A quiet moment for us • Check in on our sanctuary',
    isEnabled: true,
    createdAt: kA11yFixedDate,
  ),
  CheckinReminder(
    id: 'rem_2',
    hour: 9,
    minute: 0,
    message: 'Morning coffee alignment & today’s rhythm',
    isEnabled: false,
    createdAt: kA11yFixedDate,
  ),
];

final List<LocalRoadmapItem> _kSeedRoadmapItems = <LocalRoadmapItem>[
  LocalRoadmapItem(
    id: 'wish_1',
    homeId: 'home_1',
    title: 'Shared Spotify evening queue',
    description: 'Link our favourite playlists for dinner prep',
    isCompleted: false,
    createdBy: 'user_alex',
    createdAt: DateTime(2026, 10, 12),
  ),
  LocalRoadmapItem(
    id: 'wish_2',
    homeId: 'home_1',
    title: 'Anniversary countdown slip',
    description: 'A warm paper keepsake on Today',
    isCompleted: false,
    createdBy: 'user_sarah',
    createdAt: DateTime(2026, 10, 15),
  ),
  LocalRoadmapItem(
    id: 'wish_3',
    homeId: 'home_1',
    title: 'Encrypted Google Drive backup',
    description: 'Nightly zero-knowledge backup',
    isCompleted: true,
    completedAt: DateTime(2026, 10, 18),
    createdBy: 'user_alex',
    createdAt: DateTime(2026, 10, 1),
  ),
];

final TodayData _kSeedTodayData = TodayData(
  events: <TodayEventItem>[
    TodayEventItem(
      id: 'cal_1',
      title: 'Dinner with Sarah at Bastian',
      startTime: DateTime(2026, 10, 15, 20, 0),
      endTime: DateTime(2026, 10, 15, 22, 0),
      location: 'Bandra West',
    ),
  ],
  eventsOnlyCount: 1,
  habits: <TodayHabitItem>[
    TodayHabitItem(
      habit: _kSeedHabits[0],
      habitId: 'habit_1',
      habitName: 'Morning Walk Together',
      userCheckedInToday: true,
      partnerCheckedInToday: true,
      partnerAcknowledged: true,
      streak: 12,
      isPrivate: false,
      isOwnedByCurrentUser: true,
    ),
    TodayHabitItem(
      habit: _kSeedHabits[1],
      habitId: 'habit_2',
      habitName: 'Evening Reading (30m)',
      userCheckedInToday: false,
      partnerCheckedInToday: true,
      partnerAcknowledged: false,
      streak: 5,
      isPrivate: false,
      isOwnedByCurrentUser: false,
    ),
  ],
  focusTasks: <TodayListItem>[
    TodayListItem(
      item: _kSeedListItems[0],
      id: 'item_1',
      title: 'Sourdough country loaf',
      listId: 'list_1',
      listName: 'Groceries',
      isCompleted: false,
    ),
  ],
  openTasksCount: 1,
  listsSummary: const <TodayListSummary>[
    TodayListSummary(listId: 'list_1', name: 'Groceries', openCount: 1),
    TodayListSummary(listId: 'list_2', name: 'Weekend Errands', openCount: 0),
  ],
  todayExpenses: <TodayExpenseItem>[
    TodayExpenseItem(
      id: 'exp_1',
      title: 'Farmers Market Produce',
      amount: 1450.50,
      category: 'Groceries',
      paymentMethod: 'upi',
      payerName: 'You',
      isCurrentUser: true,
      expenseDate: kA11yFixedDate,
    ),
  ],
  todaySpendTotal: 1450.50,
  sharedMonthExpensesTotal: 4650.50,
  hasPartner: true,
  userName: 'Alex',
  partnerName: 'Sarah',
  morningQuote: 'Small shared rituals build a quiet sanctuary.',
);

final SlipSummary _kSeedSlipSummary = SlipSummary(
  listId: 'list_1',
  listName: 'Groceries',
  openCount: 1,
  openItems: const <SlipItemRow>[
    SlipItemRow(
      id: 'item_1',
      title: 'Sourdough country loaf',
      createdBy: 'user_alex',
      person: CovePerson.a,
      actorInitial: 'A',
    ),
  ],
  availableLists: const <SlipListChoiceOption>[
    SlipListChoiceOption(
      id: 'list_1',
      name: 'Groceries',
      openCount: 1,
      totalCount: 2,
      isMostUsed: true,
    ),
    SlipListChoiceOption(
      id: 'list_2',
      name: 'Weekend Errands',
      openCount: 0,
      totalCount: 0,
      isMostUsed: false,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Provider Stubs
// ---------------------------------------------------------------------------

class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _map = <String, String>{};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _map[key] = value;
    } else {
      _map.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _map[key];
}

class _StubAppDatabase extends Fake implements AppDatabase {
  @override
  Future<int> purgeOrphanedAndArchivedListItems([String? activeHomeId]) async =>
      0;

  @override
  Future<int> clearProfileActivityEvents() async => 0;

  @override
  Future<void> close() async {}
}

class _FakeAuthNotifier extends Notifier<AsyncValue<CoveUser?>>
    implements AuthNotifier {
  final CoveUser _user;
  _FakeAuthNotifier([this._user = _kAlexUser]);

  @override
  AsyncValue<CoveUser?> build() => AsyncData(_user);

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

class _FakeActivePartnerNotifier extends ActiveHomePartnerNotifier {
  final bool _hasPartner;
  _FakeActivePartnerNotifier([this._hasPartner = true]);

  @override
  bool build() => _hasPartner;
}

class _FakePartnerProfileNotifier extends PartnerProfileNotifier {
  final PartnerProfileState _profile;
  _FakePartnerProfileNotifier([this._profile = _kSarahPartnerProfile]);

  @override
  PartnerProfileState build() => _profile;
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  final UserProfileState _profile;
  _FakeUserProfileNotifier([this._profile = _kAlexProfile]);

  @override
  UserProfileState build() => _profile;
}

class _FakeCurrencyNotifier extends CurrencyNotifier {
  @override
  CurrencyOption build() =>
      const CurrencyOption(code: 'INR', symbol: '₹', name: 'Indian Rupee');
}

class _FakeMonthlyBudgetNotifier extends MonthlyBudgetNotifier {
  final double? _budget;
  _FakeMonthlyBudgetNotifier([this._budget = 85000.0]);

  @override
  double? build() => _budget;
}

class _FakeWeatherNotifier extends WeatherNotifier {
  @override
  WeatherData? build() => _kSeedWeather;

  @override
  Future<void> refreshWeather({bool force = false}) async {}
}

class _FakeNotificationPrefsNotifier extends NotificationPreferencesNotifier {
  @override
  NotificationPreferences build() => const NotificationPreferences();
}

class _FakeActivityReadStatusNotifier extends ActivityReadNotifier {
  @override
  ActivityReadState build() => const ActivityReadState();

  @override
  Future<void> markAllAsRead() async {}
}

class _FakeReminderNotifier extends ReminderNotifier {
  final List<CheckinReminder> _items;
  _FakeReminderNotifier([this._items = const <CheckinReminder>[]]);

  @override
  List<CheckinReminder> build() => _items;
}

class _FakeHomeMetadataNotifier extends HomeMetadataNotifier {
  @override
  HomeMetadataState build() => _kSeedHomeMetadata;
}

class _FakeCustomCategoriesNotifier extends CustomCategoriesNotifier {
  @override
  List<String> build() => const <String>['Pet Care'];
}

class _StubRoutineController extends RoutineController {
  _StubRoutineController(super.ref);

  @override
  Future<void> seedDefaultRoutinesIfEmpty() async {}
}

class _StubListController extends ListController {
  _StubListController(super.ref);

  @override
  Future<void> ensureDefaultLists() async {}
}

class _FakeAddAgainNotifier extends AddAgainPreferenceNotifier {
  final AddAgainPreference? _pref;
  _FakeAddAgainNotifier([this._pref]);

  @override
  AddAgainPreference? build() => _pref;
}

List<Override> buildPopulatedOverrides({
  List<LocalExpense>? expenses,
  List<CheckinReminder>? reminders,
  FakeBackupRemote? backupRemote,
  PairingRelay? pairingRelay,
}) {
  final fakeStorage = _FakeSecureStorage();
  final keyStore = HomeKeyStore(storage: fakeStorage);
  final stubDb = _StubAppDatabase();
  final resolvedRemote = backupRemote ?? FakeBackupRemote();

  return <Override>[
    for (final screen in CoveScreen.values)
      firstRunProvider(screen).overrideWithValue(FirstRunState.inUse),
    appDatabaseProvider.overrideWithValue(stubDb),
    homeKeyStoreProvider.overrideWithValue(keyStore),
    backupRemoteProvider.overrideWithValue(resolvedRemote),
    backupSchedulerProvider.overrideWithValue(FakeBackupScheduler()),
    pairingRelayProvider.overrideWithValue(
      pairingRelay ?? InMemoryPairingRelay(),
    ),
    authProvider.overrideWith(_FakeAuthNotifier.new),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    activeHomeProvider.overrideWith((ref) => Stream.value(_kSeedHome1)),
    userHomesProvider.overrideWith(
      (ref) => Stream.value(<LocalHome>[_kSeedHome1, _kSeedHome2]),
    ),
    activeHomeHasPartnerProvider.overrideWith(_FakeActivePartnerNotifier.new),
    partnerProfileProvider.overrideWith(_FakePartnerProfileNotifier.new),
    userProfileProvider.overrideWith(_FakeUserProfileNotifier.new),
    currencyPreferenceProvider.overrideWith(_FakeCurrencyNotifier.new),
    monthlyBudgetProvider.overrideWith(_FakeMonthlyBudgetNotifier.new),
    homeMetadataProvider.overrideWith(_FakeHomeMetadataNotifier.new),
    customCategoriesProvider.overrideWith(_FakeCustomCategoriesNotifier.new),
    previousFinancingSourcesProvider.overrideWith(
      (ref) => Future.value(const <String>['HDFC Bank', 'Amex']),
    ),
    weatherProvider.overrideWith(_FakeWeatherNotifier.new),
    notificationPreferencesProvider.overrideWith(
      _FakeNotificationPrefsNotifier.new,
    ),
    activityReadStatusProvider.overrideWith(
      _FakeActivityReadStatusNotifier.new,
    ),
    unreadActivityCountProvider.overrideWith((ref) => 0),
    checkinRemindersProvider.overrideWith(
      () => _FakeReminderNotifier(reminders ?? _kSeedReminders),
    ),
    activeHomeRoadmapProvider.overrideWith(
      (ref) => Stream.value(_kSeedRoadmapItems),
    ),
    activeHomePetsProvider.overrideWith((ref) => Stream.value(_kSeedPets)),
    activeHomePetTagsProvider.overrideWith(
      (ref) => Stream.value(_kSeedPetTags),
    ),
    activeHomeExpensesProvider.overrideWith(
      (ref) => Stream.value(expenses ?? _kSeedExpenses),
    ),
    activeHomeSubscriptionsProvider.overrideWith(
      (ref) => Stream.value(_kSeedSubscriptions),
    ),
    activeHomeCalendarEventsProvider.overrideWith(
      (ref) => Stream.value(_kSeedCalendarEvents),
    ),
    activeHomeListsProvider.overrideWith((ref) => Stream.value(_kSeedLists)),
    activeHomeAllListItemsProvider.overrideWith(
      (ref) => Stream.value(_kSeedListItems),
    ),
    activeHomeListItemsProvider('list_1').overrideWith(
      (ref) => Stream.value(
        _kSeedListItems.where((i) => i.listId == 'list_1').toList(),
      ),
    ),
    activeHomeListItemsProvider('list_2').overrideWith(
      (ref) => Stream.value(
        _kSeedListItems.where((i) => i.listId == 'list_2').toList(),
      ),
    ),
    activeHomeHabitsProvider.overrideWith((ref) => Stream.value(_kSeedHabits)),
    activeHomeAllHabitCheckinsProvider.overrideWith(
      (ref) => Stream.value(_kSeedHabitCheckins),
    ),
    activeHomeRoutinesProvider.overrideWith(
      (ref) => Stream.value(_kSeedRoutines),
    ),
    activeHomeAllRoutineEventsProvider.overrideWith(
      (ref) => Stream.value(_kSeedRoutineEvents),
    ),
    routineEventsProvider('routine_1').overrideWith(
      (ref) => Stream.value(_kSeedRoutineEvents),
    ),
    routineEventsProvider('routine_2').overrideWith(
      (ref) => Stream.value(const <RoutineEvent>[]),
    ),
    routineEventsProvider('routine_3').overrideWith(
      (ref) => Stream.value(const <RoutineEvent>[]),
    ),
    routineControllerProvider.overrideWith(
      (ref) => _StubRoutineController(ref),
    ),
    listControllerProvider.overrideWith((ref) => _StubListController(ref)),
    activeHomeOutboxProvider.overrideWith(
      (ref) => Stream.value(const <LocalOutboxEvent>[]),
    ),
    todayDataProvider.overrideWithValue(_kSeedTodayData),
    slipSummaryProvider.overrideWithValue(_kSeedSlipSummary),
    unifiedCalendarEntriesProvider.overrideWith((ref, window) {
      return <DateTime, List<CalendarEntry>>{
        DateTime(2026, 10, 15): <CalendarEntry>[
          CalendarEventEntry(_kSeedCalendarEvents.first),
        ],
        DateTime(2026, 10, 20): <CalendarEntry>[
          CalendarSubscriptionEntry(
            subscription: _kSeedSubscriptions.first,
            renewalDate: DateTime(2026, 10, 20),
          ),
        ],
      };
    }),
    coveEmitActionProvider.overrideWithValue(
      ({
        required String eventType,
        required Map<String, dynamic> payload,
        String? targetHomeId,
      }) async {},
    ),
  ];
}

List<Override> buildFirstRunOverrides() {
  final stubDb = _StubAppDatabase();
  final firstRunHome = LocalHome(
    id: 'home_1',
    name: 'The Nest',
    description: 'Bengaluru',
    currency: 'INR',
    createdAt: kA11yFirstRunDate,
    createdBy: 'user_saba',
  );

  return <Override>[
    for (final screen in CoveScreen.values)
      firstRunProvider(screen).overrideWithValue(FirstRunState.firstRun),
    appDatabaseProvider.overrideWithValue(stubDb),
    authProvider.overrideWith(() => _FakeAuthNotifier(_kSabaUser)),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    activeHomeProvider.overrideWith((ref) => Stream.value(firstRunHome)),
    userHomesProvider.overrideWith(
      (ref) => Stream.value(<LocalHome>[firstRunHome]),
    ),
    activeHomeHasPartnerProvider.overrideWith(
      () => _FakeActivePartnerNotifier(false),
    ),
    partnerProfileProvider.overrideWith(
      () => _FakePartnerProfileNotifier(_kAncyPartnerProfile),
    ),
    userProfileProvider.overrideWith(
      () => _FakeUserProfileNotifier(_kSabaProfile),
    ),
    currencyPreferenceProvider.overrideWith(_FakeCurrencyNotifier.new),
    monthlyBudgetProvider.overrideWith(() => _FakeMonthlyBudgetNotifier(null)),
    weatherProvider.overrideWith(_FakeWeatherNotifier.new),
    notificationPreferencesProvider.overrideWith(
      _FakeNotificationPrefsNotifier.new,
    ),
    activityReadStatusProvider.overrideWith(
      _FakeActivityReadStatusNotifier.new,
    ),
    activityFeedProvider.overrideWith(
      (ref) => Stream.value(const <FormattedActivityItem>[]),
    ),
    unreadActivityCountProvider.overrideWith((ref) => 0),
    checkinRemindersProvider.overrideWith(() => _FakeReminderNotifier()),
    activeHomePetsProvider.overrideWith(
      (ref) => Stream.value(const <LocalPet>[]),
    ),
    activeHomePetTagsProvider.overrideWith(
      (ref) => Stream.value(const <LocalPetTag>[]),
    ),
    activeHomeExpensesProvider.overrideWith(
      (ref) => Stream.value(const <LocalExpense>[]),
    ),
    activeHomeSubscriptionsProvider.overrideWith(
      (ref) => Stream.value(const <LocalSubscription>[]),
    ),
    activeHomeCalendarEventsProvider.overrideWith(
      (ref) => Stream.value(const <LocalCalendarEvent>[]),
    ),
    activeHomeListsProvider.overrideWith(
      (ref) => Stream.value(const <LocalList>[]),
    ),
    activeHomeAllListItemsProvider.overrideWith(
      (ref) => Stream.value(const <LocalListItem>[]),
    ),
    activeHomeHabitsProvider.overrideWith(
      (ref) => Stream.value(const <LocalHabit>[]),
    ),
    activeHomeAllHabitCheckinsProvider.overrideWith(
      (ref) => Stream.value(const <LocalHabitCheckin>[]),
    ),
    activeHomeRoutinesProvider.overrideWith(
      (ref) => Stream.value(const <Routine>[]),
    ),
    activeHomeAllRoutineEventsProvider.overrideWith(
      (ref) => Stream.value(const <RoutineEvent>[]),
    ),
    routineControllerProvider.overrideWith(
      (ref) => _StubRoutineController(ref),
    ),
    listControllerProvider.overrideWith((ref) => _StubListController(ref)),
    activeHomeOutboxProvider.overrideWith(
      (ref) => Stream.value(const <LocalOutboxEvent>[]),
    ),
  ];
}

List<Override> buildAddFlowOverrides({
  List<LocalList>? lists,
  List<LocalPet>? pets,
  AddAgainPreference? againPreference,
}) {
  final recentExpenses = <LocalExpense>[
    LocalExpense(
      id: 'exp_again_1',
      homeId: 'home_1',
      title: "Namdhari's",
      amount: 2140,
      currency: 'INR',
      expenseDate: DateTime(2026, 10, 3),
      paidBy: 'user_saba',
      splitRatio: 0.5,
      category: 'Groceries',
      paymentMethod: 'card',
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
  ];

  final defaultLists = <LocalList>[
    LocalList(
      id: 'list_grocery',
      homeId: 'home_1',
      name: 'Grocery',
      isArchived: false,
      createdAt: kA11yAddToday,
      createdBy: 'user_saba',
    ),
    LocalList(
      id: 'list_home',
      homeId: 'home_1',
      name: 'Home',
      isArchived: false,
      createdAt: kA11yAddToday,
      createdBy: 'user_saba',
    ),
    LocalList(
      id: 'list_travel',
      homeId: 'home_1',
      name: 'Travel',
      isArchived: false,
      createdAt: kA11yAddToday,
      createdBy: 'user_saba',
    ),
  ];

  return <Override>[
    appDatabaseProvider.overrideWithValue(_StubAppDatabase()),
    activeHomeIdProvider.overrideWith(_FakeActiveHomeNotifier.new),
    authProvider.overrideWith(() => _FakeAuthNotifier(_kSabaUser)),
    activeHomeProvider.overrideWith(
      (ref) => Stream<LocalHome?>.value(
        LocalHome(
          id: 'home_1',
          name: 'Our Home',
          currency: 'INR',
          createdBy: 'user_saba',
          createdAt: kA11yAddToday,
        ),
      ),
    ),
    activeHomeHasPartnerProvider.overrideWith(_FakeActivePartnerNotifier.new),
    activeHomeListsProvider.overrideWith(
      (ref) => Stream<List<LocalList>>.value(lists ?? defaultLists),
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
      (ref) => Stream<List<LocalExpense>>.value(recentExpenses),
    ),
    activeHomeCalendarEventsProvider.overrideWith(
      (ref) => Stream<List<LocalCalendarEvent>>.value(
        const <LocalCalendarEvent>[],
      ),
    ),
    activeHomePetsProvider.overrideWith(
      (ref) => Stream<List<LocalPet>>.value(pets ?? const <LocalPet>[]),
    ),
    activeHomePetTagsProvider.overrideWith(
      (ref) => Stream<List<LocalPetTag>>.value(const <LocalPetTag>[]),
    ),
    userProfileProvider.overrideWith(
      () => _FakeUserProfileNotifier(_kSabaProfile),
    ),
    partnerProfileProvider.overrideWith(
      () => _FakePartnerProfileNotifier(_kAncyPartnerProfile),
    ),
    currencyPreferenceProvider.overrideWith(_FakeCurrencyNotifier.new),
    customCategoriesProvider.overrideWith(_FakeCustomCategoriesNotifier.new),
    addAgainPreferenceProvider.overrideWith(
      () => _FakeAddAgainNotifier(againPreference),
    ),
  ];
}

// ---------------------------------------------------------------------------
// Host Helpers
// ---------------------------------------------------------------------------

Widget _sheetHost(Widget sheet) => Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: sheet,
      ),
    );

Widget _dialogHost(Widget dialog) => Scaffold(
      body: Center(
        child: dialog,
      ),
    );

class _AddFlowStage extends StatelessWidget {
  final Widget child;

  const _AddFlowStage({required this.child});

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

class _EditHomeDialogHost extends ConsumerWidget {
  const _EditHomeDialogHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(activeHomeProvider).value;
    if (home == null) return const SizedBox.shrink();
    return _sheetHost(const EditHomeDialog());
  }
}

Widget _wrapWithFloatingBar(Widget page, CoveFloatingBarState barState) {
  return Stack(
    children: <Widget>[
      Positioned.fill(child: wrapInAppShellConstraint(page)),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: CoveFloatingBar(
          state: barState,
          onSeatTap: (_) {},
          onAddTap: () {},
          onOverflowItemTap: (_) {},
        ),
      ),
    ],
  );
}

A11ySurface _surface({
  required String id,
  required String title,
  required String category,
  required Widget Function() build,
  required List<Override> Function() overrides,
  Widget Function(Widget)? wrap,
  Clock? clock,
  EdgeInsets insets = EdgeInsets.zero,
  Duration? customPumpDuration,
  Future<void> Function(WidgetTester tester)? afterPump,
}) {
  return A11ySurface(
    id: id,
    title: title,
    category: category,
    build: build,
    overrides: overrides,
    wrap: wrap,
    clock: clock,
    insets: insets,
    customPumpDuration: customPumpDuration,
    afterPump: afterPump,
    skips: kA11yBaselineSkips[id] ?? const <A11yCheckKey, String>{},
  );
}

// ---------------------------------------------------------------------------
// 1. Screen Surfaces
// ---------------------------------------------------------------------------

List<A11ySurface> buildScreenA11ySurfaces() {
  const simulatedInsets = EdgeInsets.only(top: 32, bottom: 24);

  return <A11ySurface>[
    _surface(
      id: 'today_screen',
      title: 'TodayScreen (populated)',
      category: 'Screens',
      build: () => const TodayScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'today_screen_scrolled_bottom',
      title: 'TodayScreen (populated, scrolled to bottom slips)',
      category: 'Screens',
      build: () => const TodayScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
      afterPump: (tester) async {
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -600));
          await tester.pumpAndSettle();
        }
      },
    ),
    _surface(
      id: 'today_screen_floating_bar',
      title: 'TodayScreen + CoveFloatingBar (rest, phone insets)',
      category: 'Screens',
      build: () => _wrapWithFloatingBar(
        const TodayScreen(),
        const CoveFloatingBarState.rest(selectedId: 'home'),
      ),
      overrides: buildPopulatedOverrides,
      insets: simulatedInsets,
    ),
    _surface(
      id: 'today_screen_first_run',
      title: 'TodayScreen (first-run)',
      category: 'Screens',
      build: () => const TodayScreen(),
      overrides: buildFirstRunOverrides,
      wrap: wrapInAppShellConstraint,
      clock: kA11yFirstRunClock,
    ),
    _surface(
      id: 'calendar_screen',
      title: 'CalendarScreen (agenda view)',
      category: 'Screens',
      build: () => CalendarScreen(
        initialEvents: _kSeedCalendarEvents,
        initialSubscriptions: _kSeedSubscriptions,
        initialSelectedDate: kA11yFixedDate,
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'calendar_month_view',
      title: 'CalendarMonthView',
      category: 'Screens',
      build: () => Scaffold(
        body: CalendarMonthView(
          events: _kSeedCalendarEvents,
          subscriptions: _kSeedSubscriptions,
          outboxEvents: const <LocalOutboxEvent>[],
          selectedDate: kA11yFixedDate,
          onSelectDate: (_) {},
          onAddEvent: () {},
        ),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'calendar_screen_first_run',
      title: 'CalendarScreen (first-run)',
      category: 'Screens',
      build: () => CalendarScreen(initialSelectedDate: kA11yFirstRunDate),
      overrides: buildFirstRunOverrides,
      wrap: wrapInAppShellConstraint,
      clock: kA11yFirstRunClock,
    ),
    _surface(
      id: 'expenses_screen',
      title: 'ExpensesScreen (populated)',
      category: 'Screens',
      build: () => ExpensesScreen(initialExpenses: _kSeedExpenses),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'expenses_screen_over_budget',
      title: 'ExpensesScreen (over budget, 6-digit)',
      category: 'Screens',
      build: () => ExpensesScreen(initialExpenses: _kOverBudgetExpenses),
      overrides: () => buildPopulatedOverrides(expenses: _kOverBudgetExpenses),
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'expenses_screen_floating_bar',
      title: 'ExpensesScreen + CoveFloatingBar (money, phone insets)',
      category: 'Screens',
      build: () => _wrapWithFloatingBar(
        ExpensesScreen(initialExpenses: _kSeedExpenses),
        const CoveFloatingBarState.money(selectedId: 'expenses'),
      ),
      overrides: buildPopulatedOverrides,
      insets: simulatedInsets,
    ),
    _surface(
      id: 'expenses_screen_first_run',
      title: 'ExpensesScreen (first-run)',
      category: 'Screens',
      build: () => const ExpensesScreen(),
      overrides: buildFirstRunOverrides,
      wrap: wrapInAppShellConstraint,
      clock: kA11yFirstRunClock,
    ),
    _surface(
      id: 'subscriptions_screen',
      title: 'SubscriptionsScreen / Commitments (populated)',
      category: 'Screens',
      build: () => const SubscriptionsScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'subscriptions_screen_first_run',
      title: 'SubscriptionsScreen / Commitments (first-run)',
      category: 'Screens',
      build: () => const SubscriptionsScreen(),
      overrides: buildFirstRunOverrides,
      wrap: wrapInAppShellConstraint,
      clock: kA11yFirstRunClock,
    ),
    _surface(
      id: 'emi_tracker_screen',
      title: 'EmiTrackerScreen',
      category: 'Screens',
      build: () => EmiTrackerScreen(initialSubscriptions: _kSeedSubscriptions),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'commitments_helicopter_screen',
      title: 'CommitmentsHelicopterScreen (The Year)',
      category: 'Screens',
      build: () => CommitmentsHelicopterScreen(
        subscriptions: _kSeedSubscriptions,
        initialYear: 2026,
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'routine_screen',
      title: 'RoutineScreen (populated two-lane)',
      category: 'Screens',
      build: () => const RoutineScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'routine_screen_first_run',
      title: 'RoutineScreen (first-run)',
      category: 'Screens',
      build: () => const RoutineScreen(),
      overrides: buildFirstRunOverrides,
      wrap: wrapInAppShellConstraint,
      clock: kA11yFirstRunClock,
    ),
    _surface(
      id: 'lists_screen',
      title: 'ListsScreen',
      category: 'Screens',
      build: () => ListsScreen(
        initialLists: _kSeedLists,
        initialItems: _kSeedListItems,
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'habits_screen',
      title: 'HabitsScreen',
      category: 'Screens',
      build: () => HabitsScreen(
        initialHabits: _kSeedHabits,
        initialCheckins: _kSeedHabitCheckins,
        currentUser: _kAlexUser,
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'activity_screen',
      title: 'ActivityScreen (populated)',
      category: 'Screens',
      build: () => ActivityScreen(initialActivities: _kSeedActivities),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'activity_screen_first_run',
      title: 'ActivityScreen (first-run)',
      category: 'Screens',
      build: () => const ActivityScreen(),
      overrides: buildFirstRunOverrides,
      wrap: wrapInAppShellConstraint,
      clock: kA11yFirstRunClock,
    ),
    _surface(
      id: 'home_settings_screen',
      title: 'HomeSettingsScreen / Our home (populated)',
      category: 'Screens',
      build: () => const HomeSettingsScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'home_settings_screen_scrolled_pets',
      title: 'HomeSettingsScreen / Our home (scrolled to Pets section)',
      category: 'Screens',
      build: () => const HomeSettingsScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
      afterPump: (tester) async {
        final petRow = find.byKey(const ValueKey('our_home_pet_row_pet_lyla'));
        if (petRow.evaluate().isNotEmpty) {
          await tester.ensureVisible(petRow);
          await tester.pumpAndSettle();
        }
      },
    ),
    _surface(
      id: 'home_settings_screen_first_run',
      title: 'HomeSettingsScreen / Our home (first-run)',
      category: 'Screens',
      build: () => const HomeSettingsScreen(),
      overrides: buildFirstRunOverrides,
      wrap: wrapInAppShellConstraint,
      clock: kA11yFirstRunClock,
    ),
    _surface(
      id: 'profile_screen',
      title: 'ProfileScreen (with DriveBackupSection)',
      category: 'Screens',
      build: () => ProfileScreen(
        initialProfile: _kAlexProfile,
        initialHome: _kSeedHome1,
        initialHomes: <LocalHome>[_kSeedHome1, _kSeedHome2],
        initialHomeMetadata: _kSeedHomeMetadata,
        initialDriveBackupState: _kSeedBackupState,
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'profile_screen_scrolled_bottom',
      title: 'ProfileScreen (scrolled to DriveBackupSection & Danger Zone)',
      category: 'Screens',
      build: () => ProfileScreen(
        initialProfile: _kAlexProfile,
        initialHome: _kSeedHome1,
        initialHomes: <LocalHome>[_kSeedHome1, _kSeedHome2],
        initialHomeMetadata: _kSeedHomeMetadata,
        initialDriveBackupState: _kSeedBackupState,
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
      afterPump: (tester) async {
        final scrollable = find.byType(Scrollable);
        if (scrollable.evaluate().isNotEmpty) {
          await tester.drag(scrollable.first, const Offset(0, -700));
          await tester.pumpAndSettle();
        }
      },
    ),
    _surface(
      id: 'about_cove_screen',
      title: 'AboutCoveScreen',
      category: 'Screens',
      build: () => const AboutCoveScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'changelog_screen',
      title: 'ChangelogScreen',
      category: 'Screens',
      build: () => const ChangelogScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'reminders_screen',
      title: 'RemindersScreen (populated)',
      category: 'Screens',
      build: () => const RemindersScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'roadmap_screen',
      title: 'RoadmapScreen (populated)',
      category: 'Screens',
      build: () => const RoadmapScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'sign_in_screen',
      title: 'SignInScreen',
      category: 'Screens',
      build: () => const SignInScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'onboarding_choice_screen',
      title: 'OnboardingChoiceScreen',
      category: 'Screens',
      build: () => const OnboardingChoiceScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'create_home_screen',
      title: 'CreateHomeScreen',
      category: 'Screens',
      build: () => const CreateHomeScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'join_home_screen',
      title: 'JoinHomeScreen (manual code entry)',
      category: 'Screens',
      build: () => const JoinHomeScreen(initialShowManualInput: true),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'missing_home_key_screen',
      title: 'MissingHomeKeyScreen',
      category: 'Screens',
      build: () => const MissingHomeKeyScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'cove_splash_screen',
      title: 'CoveSplashScreen',
      category: 'Screens',
      build: () => const CoveSplashScreen(showProgress: true),
      overrides: buildPopulatedOverrides,
      customPumpDuration: const Duration(milliseconds: 1100),
    ),
  ];
}

// ---------------------------------------------------------------------------
// 2. Sheet, Modal & Dialog Surfaces
// ---------------------------------------------------------------------------

List<A11ySurface> buildSheetA11ySurfaces() {
  final totalMonthSpend = _kSeedExpenses.fold<double>(
    0.0,
    (acc, e) => acc + e.amount,
  );
  final sampleSymmetricKey = Uint8List.fromList(
    List<int>.generate(32, (i) => (i + 11) % 256),
  );
  final sampleJoinerPubKey = Uint8List.fromList(
    List<int>.generate(32, (i) => (i * 7 + 3) % 256),
  );
  final samplePairingPayload = PairingPayload(
    homeId: 'home_1',
    homeName: 'Our Home',
    symmetricKey: sampleSymmetricKey,
    inviterId: 'user_alex',
    inviterName: 'Alex',
    createdAt: kA11yFixedDate,
  );
  final samplePairingRequest = PairingRequestRecord(
    id: 'req_1',
    code: '482915',
    joinerId: 'user_sarah',
    joinerName: 'Sarah',
    joinerPublicKey: base64Encode(sampleJoinerPubKey),
    status: 'pending',
    createdAt: kA11yFixedDate.toUtc(),
  );

  FakeBackupRemote buildSeededBackupRemote() {
    final remote = FakeBackupRemote(email: 'alex@cove.test');
    final meta = RemoteBackupFile(
      id: 'backup_1',
      createdAt: kA11yFixedDate,
      sizeBytes: 48 * 1024,
      deviceLabel: 'Pixel 6',
    );
    remote.files['backup_1'] = (meta, Uint8List.fromList(const <int>[1, 2, 3]));
    return remote;
  }

  return <A11ySurface>[
    _surface(
      id: 'expense_detail_sheet',
      title: 'ExpenseDetailSheet (with pet tag chip)',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(ExpenseDetailSheet(expense: _kSeedExpenses.first)),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'list_item_detail_sheet',
      title: 'ListItemDetailSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        ListItemDetailSheet(
          item: _kSeedListItems.first,
          listName: _kSeedLists.first.name,
        ),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'habit_detail_sheet',
      title: 'HabitDetailSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        HabitDetailSheet(
          habit: _kSeedHabits.first,
          checkins: _kSeedHabitCheckins,
        ),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'category_detail_sheet',
      title: 'CategoryDetailSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        CategoryDetailSheet(
          initialCategoryName: 'Groceries',
          allExpenses: _kSeedExpenses,
          totalMonthSpend: totalMonthSpend,
        ),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'commitment_detail_sheet',
      title: 'CommitmentDetailSheet (subscription)',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        CommitmentDetailSheet(subscription: _kSeedSubscriptions.first),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'commitment_detail_sheet_emi',
      title: 'CommitmentDetailSheet (EMI)',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        CommitmentDetailSheet(subscription: _kSeedSubscriptions[1]),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'calendar_event_detail_sheet',
      title: 'CalendarEventDetailSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        CalendarEventDetailSheet(event: _kSeedCalendarEvents.first),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'activity_event_detail_sheet',
      title: 'ActivityEventDetailSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        ActivityEventDetailSheet(item: _kSeedActivities[1]),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'calendar_event_form_sheet',
      title: 'CalendarEventFormSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        CalendarEventFormSheet(existing: _kSeedCalendarEvents.first),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'expense_form_sheet',
      title: 'ExpenseFormSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        ExpenseFormSheet(initialExpense: _kSeedExpenses.first),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'subscription_form_sheet',
      title: 'SubscriptionFormSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        SubscriptionFormSheet(existing: _kSeedSubscriptions[1]),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'routine_event_form_sheet',
      title: 'RoutineEventFormSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        RoutineEventFormSheet(
          routineId: 'routine_1',
          event: _kSeedRoutineEvents.first,
        ),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'routine_form_sheet',
      title: 'RoutineFormSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        RoutineFormSheet(routine: _kSeedRoutines.first),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'habit_form_sheet',
      title: 'HabitFormSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        HabitFormSheet(existing: _kSeedHabits[2]),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'monthly_budget_sheet',
      title: 'MonthlyBudgetSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(const MonthlyBudgetSheet()),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'month_commitments_sheet',
      title: 'MonthCommitmentsSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        MonthCommitmentsSheet(summary: _kSeedMonthCommitmentSummary),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'weather_detail_sheet',
      title: 'WeatherDetailSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(WeatherDetailSheet(weather: _kSeedWeather)),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'home_switcher_sheet',
      title: 'HomeSwitcherSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(const HomeSwitcherSheet()),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'currency_selector_sheet',
      title: 'CurrencySelectorSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(const CurrencySelectorSheet()),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'backup_passphrase_sheet',
      title: 'BackupPassphraseSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(const BackupPassphraseSheet()),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'restore_backup_sheet',
      title: 'RestoreBackupSheet (pick backup step)',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(const RestoreBackupSheet()),
      overrides: () => buildPopulatedOverrides(
        backupRemote: buildSeededBackupRemote(),
      ),
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'pet_tag_picker_sheet',
      title: 'PetTagPickerSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        const PetTagPickerSheet(
          recordKind: PetRecordKind.expense,
          recordId: 'exp_1',
        ),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'add_another_date_sheet',
      title: 'AddAnotherDateSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        AddAnotherDateSheet(
          initialDate: kA11yAddToday,
          today: kA11yAddToday,
          onSelected: (_) {},
        ),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'slip_list_picker_sheet',
      title: 'SlipListPickerSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(const SlipListPickerSheet()),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'edit_profile_dialog',
      title: 'EditProfileDialog',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(const EditProfileDialog()),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'edit_home_dialog',
      title: 'EditHomeDialog',
      category: 'Sheets & Dialogs',
      build: () => const _EditHomeDialogHost(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'edit_partner_profile_dialog',
      title: 'EditPartnerProfileDialog',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(const EditPartnerProfileDialog()),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'delete_data_dialog',
      title: 'DeleteDataDialog',
      category: 'Sheets & Dialogs',
      build: () => _dialogHost(const DeleteDataDialog()),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'create_list_dialog',
      title: 'CreateListDialog',
      category: 'Sheets & Dialogs',
      build: () => _dialogHost(const CreateListDialog()),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'whats_fresh_modal',
      title: 'WhatsFreshModal',
      category: 'Sheets & Dialogs',
      build: () => const Scaffold(body: WhatsFreshModal()),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'pairing_qr_view',
      title: 'PairingQrView',
      category: 'Sheets & Dialogs',
      build: () => Scaffold(
        body: SingleChildScrollView(
          child: PairingQrView(
            payload: samplePairingPayload,
            onDone: () {},
          ),
        ),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'pairing_approval_sheet',
      title: 'PairingApprovalSheet',
      category: 'Sheets & Dialogs',
      build: () => _sheetHost(
        PairingApprovalSheet(
          request: samplePairingRequest,
          shownPublicKey: sampleJoinerPubKey,
          homeName: 'Our Home',
          onApprove: () {},
          onDecline: () {},
        ),
      ),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
    ),
    _surface(
      id: 'add_reminder_sheet',
      title: 'RemindersScreen → _AddReminderSheet',
      category: 'Sheets & Dialogs',
      build: () => const RemindersScreen(),
      overrides: () => buildPopulatedOverrides(
        reminders: const <CheckinReminder>[],
      ),
      wrap: wrapInAppShellConstraint,
      afterPump: (tester) async {
        final btn = find.text('+ Add Check-in Reminder');
        await tester.ensureVisible(btn);
        await tester.pumpAndSettle();
        await tester.tap(btn);
        await tester.pumpAndSettle();
      },
    ),
    _surface(
      id: 'roadmap_wish_form_sheet',
      title: 'RoadmapScreen → _WishFormSheet',
      category: 'Sheets & Dialogs',
      build: () => const RoadmapScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
      afterPump: (tester) async {
        await tester.tap(find.text('+ Wish'));
        await tester.pumpAndSettle();
      },
    ),
    _surface(
      id: 'home_pet_name_dialog',
      title: 'HomeSettingsScreen → _PetNameDialog',
      category: 'Sheets & Dialogs',
      build: () => const HomeSettingsScreen(),
      overrides: buildPopulatedOverrides,
      wrap: wrapInAppShellConstraint,
      afterPump: (tester) async {
        final petRow = find.byKey(const ValueKey('our_home_pet_row_pet_lyla'));
        await tester.ensureVisible(petRow);
        await tester.pumpAndSettle();
        await tester.tap(petRow);
        await tester.pumpAndSettle();
      },
    ),
  ];
}

// ---------------------------------------------------------------------------
// 3. Add Flow Step Surfaces (All 6 AddKinds & Every AddStep)
// ---------------------------------------------------------------------------

List<A11ySurface> buildAddFlowA11ySurfaces() {
  final sampleExpenseDraft = ExpenseDraft(
    amount: 2140,
    title: "Namdhari's",
    expenseDate: kA11yAddToday,
    category: 'Groceries',
    payer: ExpensePayer.you,
    splitHalfAndHalf: true,
    isPrivate: false,
    paymentMethod: 'upi',
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
    petIds: const <String>{'pet_lyla'},
  );

  final carriedExpenseDraft = ExpenseDraft(
    amount: null,
    title: "Namdhari's",
    expenseDate: kA11yAddToday,
    category: 'Groceries',
    payer: ExpensePayer.you,
    splitHalfAndHalf: true,
    isPrivate: false,
    paymentMethod: 'card',
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
  );

  final sampleEventDraft = EventDraft(
    title: 'Dinner at Toit',
    day: kA11yAddTomorrow,
    hour: 20,
    minute: 0,
    isAllDay: false,
    location: 'Indiranagar',
    owner: CommitmentOwner.both,
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
  );

  final sampleTaskDraft = TaskDraft(
    title: 'Gas cylinder',
    listId: 'list_home',
    dueDate: kA11yAddTomorrow,
    noParticularDay: false,
    owner: TaskOwner.you,
    listCount: 3,
    openedFromList: false,
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
  );

  final zeroListTaskDraft = TaskDraft(
    title: 'Gas cylinder',
    newListName: 'Household',
    dueDate: kA11yAddTomorrow,
    noParticularDay: false,
    owner: TaskOwner.either,
    listCount: 0,
    openedFromList: false,
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
  );

  final sampleHabitDraft = HabitDraft(
    name: 'Morning walk',
    frequencyOption: HabitFrequencyOption.pickDays,
    customDays: const <int>{1, 3, 5},
    visibility: HabitVisibility.shared,
    hasPartner: true,
  );

  final monthlyCommitmentDraft = CommitmentDraft(
    name: 'Spotify Duo',
    amount: 149,
    cycle: CommitmentCycleOption.everyMonth,
    dayOfMonth: 8,
    paidFrom: 'BOB',
    owner: CommitmentOwner.you,
    isPrivate: false,
    today: kA11yAddToday,
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
  );

  final yearlyCommitmentDraft = CommitmentDraft(
    name: 'Car insurance',
    amount: 14200,
    cycle: CommitmentCycleOption.everyYear,
    dueMonth: 11,
    dayOfMonth: 15,
    paidFrom: 'HDFC Regalia',
    owner: CommitmentOwner.both,
    isPrivate: false,
    today: kA11yAddToday,
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
  );

  final emiCommitmentDraft = CommitmentDraft(
    name: 'AC — the instalment',
    amount: 3974,
    cycle: CommitmentCycleOption.emi,
    totalInstallments: 12,
    paidInstallments: 3,
    dayOfMonth: 5,
    paidFrom: 'BOB',
    owner: CommitmentOwner.both,
    isPrivate: false,
    today: kA11yAddToday,
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
  );

  final sampleRoutineDraft = RoutineDraft(
    title: 'Morning tea',
    startMinutes: 8 * 60,
    durationMinutes: 30,
    days: const <int>{1, 2, 3, 4, 5},
    owner: CommitmentOwner.both,
    viewerUserId: 'user_saba',
    partnerUserId: 'user_ancy',
    hasPartner: true,
  );

  A11ySurface addStep({
    required String id,
    required String title,
    required Widget child,
    List<Override> Function()? overrides,
  }) {
    return _surface(
      id: id,
      title: title,
      category: 'Add Flow',
      build: () => _AddFlowStage(child: child),
      overrides: overrides ?? buildAddFlowOverrides,
      clock: kA11yAddClock,
    );
  }

  return <A11ySurface>[
    // Root picker (plain + with Again row)
    addStep(
      id: 'add_picker',
      title: 'AddFlow Picker (6 kinds)',
      child: const AddFlow(),
    ),
    addStep(
      id: 'add_picker_with_again',
      title: 'AddFlow Picker (with Again row)',
      child: AddFlow(
        againSummary: AddAgainSummary(
          kind: AddKind.expense,
          titleAndContext: 'Toit · Dining',
          lastReadout: '₹1,280',
          onTap: () {},
        ),
      ),
    ),

    // 1. Expense (7 steps + Again carried amount + Added confirmation)
    addStep(
      id: 'add_expense_1_amount',
      title: 'AddFlow Expense Step 1 — How much? (expenseAmount)',
      child: AddFlow(
        initialKind: AddKind.expense,
        initialDraft: sampleExpenseDraft,
        initialStepIndex: 0,
      ),
    ),
    addStep(
      id: 'add_expense_1_amount_again_carried',
      title: 'AddFlow Expense Step 1 — Again carried amount',
      child: AddFlow(
        initialKind: AddKind.expense,
        initialDraft: carriedExpenseDraft,
        initialStepIndex: 0,
        initialCarriedLine:
            "Namdhari's · Groceries · Card — last time ₹2,140",
      ),
    ),
    addStep(
      id: 'add_expense_2_title',
      title: 'AddFlow Expense Step 2 — What for? (expenseTitle)',
      child: AddFlow(
        initialKind: AddKind.expense,
        initialDraft: sampleExpenseDraft,
        initialStepIndex: 1,
      ),
    ),
    addStep(
      id: 'add_expense_3_when',
      title: 'AddFlow Expense Step 3 — When? (expenseWhen)',
      child: AddFlow(
        initialKind: AddKind.expense,
        initialDraft: sampleExpenseDraft,
        initialStepIndex: 2,
      ),
    ),
    addStep(
      id: 'add_expense_4_category',
      title: 'AddFlow Expense Step 4 — Which category? (expenseCategory)',
      child: AddFlow(
        initialKind: AddKind.expense,
        initialDraft: sampleExpenseDraft,
        initialStepIndex: 3,
      ),
    ),
    addStep(
      id: 'add_expense_5_who_paid',
      title: 'AddFlow Expense Step 5 — Who paid? + About a pet? (expenseWhoPaid)',
      child: AddFlow(
        initialKind: AddKind.expense,
        initialDraft: sampleExpenseDraft,
        initialStepIndex: 4,
      ),
      overrides: () => buildAddFlowOverrides(pets: _kSeedPets),
    ),
    addStep(
      id: 'add_expense_6_payment_method',
      title: 'AddFlow Expense Step 6 — On what? (expensePaymentMethod)',
      child: AddFlow(
        initialKind: AddKind.expense,
        initialDraft: sampleExpenseDraft,
        initialStepIndex: 5,
      ),
    ),
    addStep(
      id: 'add_expense_7_review',
      title: 'AddFlow Expense Step 7 — Review (CoveReceipt)',
      child: AddFlow(
        initialKind: AddKind.expense,
        initialDraft: sampleExpenseDraft,
        initialStepIndex: 6,
      ),
    ),
    addStep(
      id: 'add_expense_added',
      title: 'AddFlow Expense Added confirmation state',
      child: AddFlow(
        initialKind: AddKind.expense,
        initialDraft: sampleExpenseDraft,
        initialStepIndex: 6,
        initialIsAdded: true,
      ),
    ),

    // 2. Event (6 steps)
    addStep(
      id: 'add_event_1_title',
      title: 'AddFlow Event Step 1 — What is happening? (eventTitle)',
      child: AddFlow(
        initialKind: AddKind.event,
        initialDraft: sampleEventDraft,
        initialStepIndex: 0,
      ),
    ),
    addStep(
      id: 'add_event_2_day',
      title: 'AddFlow Event Step 2 — Which day? (eventDay)',
      child: AddFlow(
        initialKind: AddKind.event,
        initialDraft: sampleEventDraft,
        initialStepIndex: 1,
      ),
    ),
    addStep(
      id: 'add_event_3_time',
      title: 'AddFlow Event Step 3 — What time? (eventTime / AddClockFace)',
      child: AddFlow(
        initialKind: AddKind.event,
        initialDraft: sampleEventDraft,
        initialStepIndex: 2,
      ),
    ),
    addStep(
      id: 'add_event_4_location',
      title: 'AddFlow Event Step 4 — Where? (eventLocation)',
      child: AddFlow(
        initialKind: AddKind.event,
        initialDraft: sampleEventDraft,
        initialStepIndex: 3,
      ),
    ),
    addStep(
      id: 'add_event_5_whose',
      title: 'AddFlow Event Step 5 — Whose is it? (eventWhose)',
      child: AddFlow(
        initialKind: AddKind.event,
        initialDraft: sampleEventDraft,
        initialStepIndex: 4,
      ),
    ),
    addStep(
      id: 'add_event_6_review',
      title: 'AddFlow Event Step 6 — Review (CoveTicket)',
      child: AddFlow(
        initialKind: AddKind.event,
        initialDraft: sampleEventDraft,
        initialStepIndex: 5,
      ),
    ),

    // 3. Task (all 5 steps + taskNameTheList when 0 lists)
    addStep(
      id: 'add_task_1_title',
      title: 'AddFlow Task Step 1 — What needs doing? (taskTitle)',
      child: AddFlow(
        initialKind: AddKind.task,
        initialDraft: sampleTaskDraft,
        initialStepIndex: 0,
      ),
    ),
    addStep(
      id: 'add_task_2_which_list',
      title: 'AddFlow Task Step 2 — Which list? (taskWhichList)',
      child: AddFlow(
        initialKind: AddKind.task,
        initialDraft: sampleTaskDraft,
        initialStepIndex: 1,
      ),
    ),
    addStep(
      id: 'add_task_2_name_the_list',
      title: 'AddFlow Task Step 2 — Name the list (taskNameTheList, 0 lists)',
      child: AddFlow(
        initialKind: AddKind.task,
        initialDraft: zeroListTaskDraft,
        initialStepIndex: 1,
      ),
      overrides: () => buildAddFlowOverrides(lists: const <LocalList>[]),
    ),
    addStep(
      id: 'add_task_3_by_when',
      title: 'AddFlow Task Step 3 — By when? (taskByWhen)',
      child: AddFlow(
        initialKind: AddKind.task,
        initialDraft: sampleTaskDraft,
        initialStepIndex: 2,
      ),
    ),
    addStep(
      id: 'add_task_4_whose',
      title: 'AddFlow Task Step 4 — Whose is it? (taskWhose)',
      child: AddFlow(
        initialKind: AddKind.task,
        initialDraft: sampleTaskDraft,
        initialStepIndex: 3,
      ),
    ),
    addStep(
      id: 'add_task_5_review',
      title: 'AddFlow Task Step 5 — Review (CoveNote)',
      child: AddFlow(
        initialKind: AddKind.task,
        initialDraft: sampleTaskDraft,
        initialStepIndex: 4,
      ),
    ),

    // 4. Habit (4 steps)
    addStep(
      id: 'add_habit_1_name',
      title: 'AddFlow Habit Step 1 — What is the habit? (habitName)',
      child: AddFlow(
        initialKind: AddKind.habit,
        initialDraft: sampleHabitDraft,
        initialStepIndex: 0,
      ),
    ),
    addStep(
      id: 'add_habit_2_how_often',
      title: 'AddFlow Habit Step 2 — How often? (habitHowOften + week toggles)',
      child: AddFlow(
        initialKind: AddKind.habit,
        initialDraft: sampleHabitDraft,
        initialStepIndex: 1,
      ),
    ),
    addStep(
      id: 'add_habit_3_visibility',
      title: 'AddFlow Habit Step 3 — Together or yours? (habitVisibility)',
      child: AddFlow(
        initialKind: AddKind.habit,
        initialDraft: sampleHabitDraft,
        initialStepIndex: 2,
      ),
    ),
    addStep(
      id: 'add_habit_4_review',
      title: 'AddFlow Habit Step 4 — Review (CoveHabitCard)',
      child: AddFlow(
        initialKind: AddKind.habit,
        initialDraft: sampleHabitDraft,
        initialStepIndex: 3,
      ),
    ),

    // 5. Commitment (7 standard steps + yearly next-date + EMI steps + EMI review)
    addStep(
      id: 'add_commitment_1_name',
      title: 'AddFlow Commitment Step 1 — What is it called? (commitmentName)',
      child: AddFlow(
        initialKind: AddKind.commitment,
        initialDraft: monthlyCommitmentDraft,
        initialStepIndex: 0,
      ),
    ),
    addStep(
      id: 'add_commitment_2_amount',
      title: 'AddFlow Commitment Step 2 — How much each time? (commitmentAmount)',
      child: AddFlow(
        initialKind: AddKind.commitment,
        initialDraft: monthlyCommitmentDraft,
        initialStepIndex: 1,
      ),
    ),
    addStep(
      id: 'add_commitment_3_how_often',
      title: 'AddFlow Commitment Step 3 — How often does it come? (commitmentHowOften)',
      child: AddFlow(
        initialKind: AddKind.commitment,
        initialDraft: monthlyCommitmentDraft,
        initialStepIndex: 2,
      ),
    ),
    addStep(
      id: 'add_commitment_4_when_due_monthly',
      title: 'AddFlow Commitment Step 4 — Which day of the month? (AddMonthDayGrid)',
      child: AddFlow(
        initialKind: AddKind.commitment,
        initialDraft: monthlyCommitmentDraft,
        initialStepIndex: 3,
      ),
    ),
    addStep(
      id: 'add_commitment_4_when_due_yearly',
      title: 'AddFlow Commitment Step 4 — When is the next one due? (AddNextDatePicker)',
      child: AddFlow(
        initialKind: AddKind.commitment,
        initialDraft: yearlyCommitmentDraft,
        initialStepIndex: 3,
      ),
    ),
    addStep(
      id: 'add_commitment_4_emi_total',
      title: 'AddFlow Commitment EMI Step 4 — How many instalments? (commitmentEmiTotal)',
      child: AddFlow(
        initialKind: AddKind.commitment,
        initialDraft: emiCommitmentDraft,
        initialStepIndex: 3,
      ),
    ),
    addStep(
      id: 'add_commitment_5_emi_paid',
      title: 'AddFlow Commitment EMI Step 5 — How many paid already? (commitmentEmiPaid)',
      child: AddFlow(
        initialKind: AddKind.commitment,
        initialDraft: emiCommitmentDraft,
        initialStepIndex: 4,
      ),
    ),
    addStep(
      id: 'add_commitment_5_paid_from',
      title: 'AddFlow Commitment Step 5 — Paid from where? (commitmentPaidFrom)',
      child: AddFlow(
        initialKind: AddKind.commitment,
        initialDraft: monthlyCommitmentDraft,
        initialStepIndex: 4,
      ),
    ),
    addStep(
      id: 'add_commitment_6_whose',
      title: 'AddFlow Commitment Step 6 — Whose is it? (commitmentWhose)',
      child: AddFlow(
        initialKind: AddKind.commitment,
        initialDraft: monthlyCommitmentDraft,
        initialStepIndex: 5,
      ),
    ),
    addStep(
      id: 'add_commitment_7_review',
      title: 'AddFlow Commitment Step 7 — Review (CoveVoucher standard)',
      child: AddFlow(
        initialKind: AddKind.commitment,
        initialDraft: monthlyCommitmentDraft,
        initialStepIndex: 6,
      ),
    ),
    addStep(
      id: 'add_commitment_9_emi_review',
      title: 'AddFlow Commitment EMI Step 9 — Review (CoveVoucher punched EMI)',
      child: AddFlow(
        initialKind: AddKind.commitment,
        initialDraft: emiCommitmentDraft,
        initialStepIndex: 8,
      ),
    ),

    // 6. Routine (6 steps)
    addStep(
      id: 'add_routine_1_title',
      title: 'AddFlow Routine Step 1 — What is the ritual? (routineTitle)',
      child: AddFlow(
        initialKind: AddKind.routine,
        initialDraft: sampleRoutineDraft,
        initialStepIndex: 0,
      ),
    ),
    addStep(
      id: 'add_routine_2_when',
      title: 'AddFlow Routine Step 2 — What time? (routineWhen / AddClockFace)',
      child: AddFlow(
        initialKind: AddKind.routine,
        initialDraft: sampleRoutineDraft,
        initialStepIndex: 1,
      ),
    ),
    addStep(
      id: 'add_routine_3_duration',
      title: 'AddFlow Routine Step 3 — For how long? (routineDuration)',
      child: AddFlow(
        initialKind: AddKind.routine,
        initialDraft: sampleRoutineDraft,
        initialStepIndex: 2,
      ),
    ),
    addStep(
      id: 'add_routine_4_days',
      title: 'AddFlow Routine Step 4 — Which days? (routineDays / AddWeekToggles)',
      child: AddFlow(
        initialKind: AddKind.routine,
        initialDraft: sampleRoutineDraft,
        initialStepIndex: 3,
      ),
    ),
    addStep(
      id: 'add_routine_5_whose',
      title: 'AddFlow Routine Step 5 — Whose is it? (routineWhose)',
      child: AddFlow(
        initialKind: AddKind.routine,
        initialDraft: sampleRoutineDraft,
        initialStepIndex: 4,
      ),
    ),
    addStep(
      id: 'add_routine_6_review',
      title: 'AddFlow Routine Step 6 — Review (CoveBand)',
      child: AddFlow(
        initialKind: AddKind.routine,
        initialDraft: sampleRoutineDraft,
        initialStepIndex: 5,
      ),
    ),
  ];
}
