# Antigravity build prompt — Cove calendar-first restructure

> Paste everything below the line into Antigravity as a single task.

---

You are working in the Cove Flutter repo (Flutter + Riverpod + Supabase, encrypted store-and-forward sync). Restructure the app's information architecture so the **calendar is the launch surface and carries every dated layer**, and the **Today screen becomes the home screen**. Retire the Dashboard.

Read `DESIGN_SYSTEM.md` first and treat it as binding. Read `lib/features/app_shell.dart`, `lib/core/widgets/cove_bottom_nav.dart`, `lib/features/calendar/`, `lib/features/today/` and `lib/features/dashboard/` before changing anything.

## Hard constraints

- **No new colours.** Differentiate the calendar's layers with monoline icons, a caps micro-label and tonal steps of the existing champagne accent (opacity steps on density dots). Terracotta (`accentSecondary`) stays reserved for genuine attention states. No coloured status chips, no emoji, no gamification.
- **Use the existing theme extensions** — `context.colors` and `context.typography`. No new raw hex values, no new `fontFamily:` string literals anywhere.
- Every new tappable row keeps a **48px minimum tap target**; grouped rows live inside one `CoveCard` separated by 1px 6% hairlines, never as separate cards with gaps.
- **Both themes** must be checked, light and dark.
- **Web/desktop parity**: whatever changes in `CoveBottomNav` changes in `CoveWebSidebar` too.
- Every mutation continues to go through the existing sync engine and event pipeline. Do not invent new event types where an existing one fits; follow the patterns already in `lib/sync/`.
- Keep the existing 1000-iteration safety caps in recurrence projection, and keep projection windowed — do not project unbounded ranges.
- Do not weaken or bypass the encryption/outbox path. Do not add analytics or third-party packages.

---

## Move 1 — Calendar becomes the launch view

**`lib/features/app_shell.dart`**

- Default `_currentIndex` to the calendar tab (index 2) so the app opens on the calendar's Day view, on today.
- Reindex the tabs to: `0 = Home (TodayScreen)`, `1 = Commitments (SubscriptionsScreen)`, `2 = Calendar (CalendarScreen)`, `3 = Lists (ListsScreen)`, `4 = Expenses (ExpensesScreen)`. Update `_buildCurrentTab()` accordingly.
- Update the `PopScope` back handling: from any non-calendar tab, back returns to the **calendar** tab; on the calendar tab, keep the existing double-press-to-exit behaviour with the same 2-second window and snackbar.
- Remove the **sun / Today** `IconButton` from the `AppBar` actions — Today is now a tab. Keep the home switcher title, the Routines clock icon, the notifications bell with its unread badge, and the profile avatar.
- Update `_navigateToModule(NotificationModule)` for the new indices: `home → 0`, `subscriptions → 1`, `calendar → 2`, `lists → 3`, `expenses → 4`; `habits` and `activity` keep pushing their screens.

**`lib/core/widgets/cove_bottom_nav.dart`**

- Reorder `navIcons` / `navTooltips` to: Home (`Icons.home_outlined`), Commitments (`Icons.autorenew_outlined`), Calendar (centre, protruding — unchanged), Lists (`Icons.checklist_rtl_outlined`), Expenses (`Icons.account_balance_wallet_outlined`). The protruding centre calendar button stays exactly as designed.

**`lib/core/widgets/cove_web_sidebar.dart`** — mirror the same order and labels.

---

## Move 2 — Five layers land on the calendar day

This is the substantial piece. The calendar currently shows calendar events plus projected subscription renewals. It must show everything dated.

### 2a. Extend the entry model — `lib/features/calendar/calendar_models.dart`

Keep the existing sealed `CalendarEntry` with `CalendarEventEntry` and `CalendarSubscriptionEntry`, and add:

- `CalendarExpenseEntry` — wraps a `LocalExpense`; carries amount, category, payer, payment method. Date = the expense date.
- `CalendarHabitEntry` — wraps a `LocalHabit`; carries habit name, whether it is due on that date (use the existing `lib/features/habits/habit_schedule.dart`), current streak (use `habit_streak_calculator.dart`), the current user's and partner's check-in state for that date, and whether it is private.
- `CalendarTaskEntry` — wraps a `LocalListItem` that carries a due date; carries the parent list's name and completion state. If list items have no due-date field today, add one as a nullable column and migrate additively — existing items keep `null` and simply never appear on the calendar.
- `CalendarRoutineEntry` — wraps a routine block from `lib/features/routines/`, with its time window.
- `CalendarReminderEntry` — wraps a scheduled check-in reminder from `lib/features/reminders/`.

Add a `CalendarLayer` enum: `all, events, commitments, money, rhythms, tasks`. Map each entry type to its layer (`routines` and `reminders` both fall under `tasks`; calendar events under `events`).

Add projection helpers alongside the existing `projectCalendarEvents` / `projectSubscriptions`, following the same windowed pattern.

### 2b. One provider for the unified day

Add a provider (put it in `lib/features/calendar/calendar_controller.dart`) that composes the existing per-module providers — `activeHomeCalendarEventsProvider`, `activeHomeSubscriptionsProvider`, the expense, habit, list-item, routine and reminder providers — into a single `Map<DateTime, List<CalendarEntry>>` for a requested window, sorted chronologically with all-day entries first. Do **not** duplicate module logic; compose the existing sources so a change made anywhere still flows through sync and appears here.

### 2c. Day view — `lib/features/calendar/views/calendar_agenda_view.dart`

Keep the month header with the expand/collapse chevron and the week strip exactly as they are. Below the strip, add:

1. **A layer filter row** — horizontally scrollable chips, one per `CalendarLayer`, each showing a count for the selected day. `All` is selected by default. Selection is per-session state, not persisted (see Open Questions).
2. **A day summary line** under the date heading — e.g. `2 events · 2/4 rhythms · ₹1,240 logged`, figures in Bodoni, built from the day's actual entries.
3. **Rhythms strip** — a horizontally scrollable row of compact habit cards for habits due that day, each with name, streak in Bodoni, and a `CoveCheckbox`. Ticking checks the habit in for that date through the existing habit check-in path. Do **not** strike through a habit's name when checked — drop it to `textMuted` only. Strikethrough stays for list items.
4. **The day timeline** — a time gutter on the left (Bodoni, tabular figures, with a separate small caps AM/PM) and the entry card on the right. All-day entries render first with an "All day" gutter label. Each card carries a monoline glyph, a caps micro-label (`EVENT` / `RENEWAL` / `ROUTINE`), title, subtitle, the partner attribution chip and, where relevant, the two-tick sync indicator and the amount in Bodoni. Routine blocks render in a quieter variant (dashed hairline, no fill).
5. **Due today** — a grouped card of list items due that date, each with a `CoveCheckbox` that completes the item in its list.
6. **Logged** — a grouped card of the day's expenses with a day total in the section header.
7. **Empty states** — distinguish "nothing on this layer" (a filter is hiding things) from "a clear day" (nothing scheduled at all).

### 2d. Month view

- Density dots per day: up to three, derived from the number of **distinct layers** present that day, drawn in champagne at stepped opacity (100% / 55% / 30%). Days with nothing get no dot — habits recurring daily must **not** put a dot on every day in the grid.
- Tapping a day selects it and drops back into Day view on that date.
- Keep the expand-in-place behaviour from the month chevron in the header, so the month reads as a peek rather than a separate destination.
- `views/calendar_year_view.dart` is unreferenced — delete it if nothing imports it.

### 2e. One add sheet

The `+` in the calendar header opens a single bottom sheet listing: Event, Expense, Task, Rhythm, Commitment. Each option opens that module's **existing** form sheet (`CalendarEventFormSheet`, `ExpenseFormSheet`, the list-item add flow, `HabitFormSheet`, the subscription form), pre-filled with the currently selected date. Do not write new forms.

---

## Move 3 — Today becomes Home

**`lib/features/today/today_screen.dart`** keeps its ambient hero, pulse strip, Today's flow, Daily rhythms, Focus tasks and Today's spend. Add, from the retiring Dashboard:

- **Shared this month** — the month total as a Bodoni figure with a comparison line, appended to the Today's spend section rather than as a separate card.
- **Shared lists** — the pill row with open counts per list, each tapping through to that list.
- **Recent activity** — the three most recent formatted activity items with the two-tick indicator, and an "All" affordance into `ActivityScreen`.

Fix the pulse strip while you are there: the Events tile should count calendar **events only**, not events plus renewals, so it agrees with the calendar's own day summary. Label the tasks tile "Tasks" rather than "To-do" so it does not wrap to two lines.

Extend `TodayData` in `today_models.dart` and `today_controller.dart` with the fields these sections need, reusing the providers `dashboard_controller.dart` already uses.

---

## Move 4 — Retire the Dashboard

Once Move 3 is in and verified:

- Remove `DashboardScreen` from the shell and delete `lib/features/dashboard/dashboard_screen.dart`, `dashboard_controller.dart` and `dashboard_models.dart`, migrating any provider still needed into `today_controller.dart`.
- Grep for every remaining reference (tests, notification routing, deep links, the web sidebar) and clean them up. `flutter analyze` must be clean.
- The Activity, Habits, Routines, Reminders, Lists, Expenses and Subscriptions screens are **not** touched.

---

## Move 5 — Tell the user what changed

Add a release entry to the changelog / What's Fresh flow in `lib/features/changelog/` describing: the calendar now opens first and carries everything dated; Today is now the home tab; Dashboard's pieces moved onto Today. Keep the copy in Cove's voice — plain, calm, no exclamation marks.

---

## Acceptance checks

Run these yourself before reporting done:

1. Cold launch lands on the calendar, Day view, today's date, `All` layer.
2. The bottom nav's Home tab shows Today; the calendar centre button returns to the calendar from any tab.
3. Android back: from Lists → calendar; from calendar → double-press exits.
4. A day with an event, a renewal, an expense, a due task and a habit shows all five, and each layer chip narrows to exactly its own entries with correct counts.
5. Ticking a habit on the calendar updates Today's rhythms and the habits screen, and produces one sync event — not two.
6. Ticking a due task on the calendar completes it in its list.
7. Month view shows no dot on a genuinely empty day, and at most three on a busy one; tapping a day opens it.
8. The `+` sheet opens each module's real form with the selected date pre-filled.
9. No reference to Dashboard remains; `flutter analyze` is clean and the existing tests in `test/` pass, with new tests covering the unified-entry projection and the layer filter.
10. Both themes reviewed on a phone-width and a desktop-width layout.

## Open questions — surface these rather than guessing

- Should the layer filter persist between sessions, or reset to `All` each launch? Default to **reset to All** unless told otherwise; sticky filters silently hide things.
- Is three the right density-dot cap once all five layers are live on a real week of data?
- Should Lists sit next to the calendar instead of Home, if Lists turns out to be the more frequently used tab?
