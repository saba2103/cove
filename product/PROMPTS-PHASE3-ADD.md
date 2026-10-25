# Phase 3.12 — Add, as a sequence

Six create forms and a create picker become one flow, to `design/specs/14-add-flow.md`.
Eight prompts, in order. Each one ends with `tool/check.sh` exiting 0 and a commit.

**Settled before this started (25 Oct):**
- No schema change. "Whose is it?" for events, tasks and routines waits for Phase 4
  (schema v12, in the same migration as pets).
- Add creates. Edit keeps using the existing form sheets.
- Nothing shown in the flow is invented: suggestions, Again and hints come from the user's
  own records, or don't appear.

Rules for every prompt below:
- Tokens only. `(literal)` only where the spec marks it. A size with no token → add it to
  `design/tokens.json`, regenerate, report it.
- Partner name from the partner profile, never a literal. No example names in code or copy.
- `clock.now()` for every date. Goldens use `goldenMatrix` (3 widths × 2 modes).
- Don't change any controller's behaviour. If Add needs something a controller doesn't
  offer, stop and report it.

---

## 3.12a — the drafts, as data

````
Read design/specs/14-add-flow.md in full first.

Build the Add flow's state as pure Dart, with no widgets, in lib/features/add/add_draft.dart
(split into files per kind if it's long):

- `AddKind` enum: event, expense, task, habit, commitment, routine.
- One immutable draft per kind (`ExpenseDraft`, `EventDraft`, …) holding exactly the answers
  §5 lists for that kind, with copyWith.
- `List<AddStep> stepsFor(draft, context)`: the ordered steps for that draft *right now*.
  The context carries: anchor date, today, whether a partner exists, list count, and whether
  the flow was opened from a list. The EMI steps appear only for an EMI; Which list only under
  §5's conditions.
- `bool isAnswered(step)` and `bool isComplete`.
- `toCreateArgs()`: the exact named arguments for the controller call in §5, as a plain value
  object per kind. No controller is called here.
- `anchoredDays(kind, anchor)`: the seven dates of §4.
- `nextBillingDate(...)` for month-day and next-date (§3), never before today.
- `dayLabel(date, today)`: Today / Yesterday / Tomorrow / weekday, plus `, 5 Oct`.

Unit tests (test/features/add/), all with a fixed clock:
1. Expense anchored days end at the anchor; task and event days start at it; a calendar
   anchor three days out shifts all three.
2. Expense who/split/private → every (paidBy, visibility) combination the current
   ExpenseFormSheet can create, and none it can't. Read the form to build that list, and put
   the list in the test.
3. Habit: each How-often option produces the same `cadence` string and `targetDaysPerWeek`
   that HabitFormSheet produces for the same choice. Use HabitSchedule both ways.
4. Commitment: monthly on the 8th when today is the 10th → the 8th of next month; on the
   10th when today is the 10th → today. Quarterly/yearly next-date never before today. EMI
   requires total ≥ 1 and paid < total.
5. Routine: Mon–Fri finds an existing routine whose daysJson is exactly [1,2,3,4,5], and a new
   name is produced (Everyday / Weekdays / Weekend / `Mon, Wed, Fri`) when none matches.
   endMinutes caps at 1439.
6. Steps: an expense has 7, an event 5, a task 3 or 4, a habit 4, a commitment 7 (monthly)
   or 9 (EMI), a routine 5. In a home with no partner, the partner options are gone but the
   private toggle remains.

Nothing under lib/features changes except the new add/ folder. tool/check.sh must exit 0.
Commit as `feat(add): draft models for the Add flow, tested as data (3.12a)`.
````

## 3.12b — what the slips need

````
To design/specs/14-add-flow.md §8 and §9.

1. CoveSlip gets an optional stamp. Move the voucher's PAID stamp into that shared
   implementation so CoveVoucher uses it too — the voucher's goldens must not change.
   The ADDED stamp is the same widget with different text.
2. An optional visibility line on every slip (§8).
3. Optional field taps on each of CoveReceipt, CoveTicket, CoveNote, CoveHabitCard,
   CoveVoucher and the new CoveBand: a map from that slip's fields to callbacks, 48dp targets,
   semantics `Change {field}`. With no map, every slip behaves and looks exactly as it does now.
4. Build CoveBand in lib/core/widgets/slips/ (§9), on CoveSlip, implementing CoveSlipObject.
5. Build CoveAddMark(kind) (§1): the six small paper marks. Match add.png.

Goldens: CoveBand (a 15-minute and a 2-hour routine; weekdays and every day), each slip with
the ADDED stamp, each slip with both visibility lines, all at 3 widths × 2 modes. Every
existing slip golden must be unchanged — list any that moved and why.
Nothing under lib/features changes. tool/check.sh must exit 0.
Commit as `feat(slips): stamp, visibility line, field taps, CoveBand, CoveAddMark (3.12b)`.
````

## 3.12c — the step pieces

````
To design/specs/14-add-flow.md §2–§4, and design/screens/add-steps/*.png.

Build these in lib/features/add/widgets/ (they belong to Add, not the system): the keypad, the
day strip (+ Another date), the month-day grid, the next-date picker, the clock face, the week
toggles, the choice list, the person tiles with toggle rows, the crumbs, the progress
segments, and the step foot (visibility chip + Next).

- Use the existing primitives inside them (CoveAvatar, CoveToggleSwitch, CoveSheet,
  CoveRoundButton). If a piece wants to duplicate one, stop and report why.
- Cover width rules (§3): 48dp targets, horizontal scroll for the strip and toggles.
- Each piece is a dumb widget: value in, callback out. No providers inside.

Goldens for each piece at 3 widths × 2 modes, matching the reference PNGs. Add a test that at
320dp no target is under 48×48. tool/check.sh must exit 0.
Commit as `feat(add): the step pieces (3.12c)`.
````

## 3.12d — the flow, for Expense and Event

````
Build the Add flow in lib/features/add/add_flow.dart, to design/specs/14-add-flow.md:
the picker (§1), the step page (§2), review, Add and Added (§7). It runs on the drafts from
3.12a and the pieces from 3.12b–c. `AddFlow.show(context, {AddKind? kind, DateTime? anchor,
String? listId})` — with a kind it skips the picker.

Wire Expense and Event end to end through their controllers (the same calls the old create
forms make). Habit, Task, Commitment and Routine tiles are visible but show a "Coming in
3.12e/f" toast for now — they get wired next.

Do not change any existing entry point yet; reach the flow from a debug route or a test only.

Tests:
- Walk an expense through all 7 steps; Add calls logExpense once with the draft's args.
- Walk an event; createEvent gets start + 1 hour as endTime; All day uses the form's all-day times.
- Tapping a crumb goes to that step and keeps later answers; tapping a slip field goes to
  that step and Next returns to review.
- A failing controller keeps the draft and shows the error toast.
Goldens: the picker, each expense step, the expense review, the Added state — 3 widths ×
2 modes. tool/check.sh must exit 0.
Commit as `feat(add): the flow, with expense and event (3.12d)`.
````

## 3.12e — Task and Habit

````
Wire Task and Habit into AddFlow, to design/specs/14-add-flow.md §5.

- Task: Which list only under §5's conditions; with no lists, Name the list creates one
  first through the list controller; No particular day → dueDate null. The review is CoveNote.
- Habit: How often with Pick the days revealing the week toggles on the same page; the
  cadence and target come from the 3.12a serialiser; Who can see it → visibility. The review
  is CoveHabitCard in its no-history state — don't build a new habit token.

Tests walking each kind to Add, asserting the controller args. Goldens of both reviews and of
the Which list and How often steps. tool/check.sh must exit 0.
Commit as `feat(add): task and habit (3.12e)`.
````

## 3.12f — Commitment and Routine

````
Wire Commitment and Routine into AddFlow, to design/specs/14-add-flow.md §5.

- Commitment: monthly, quarterly, yearly and EMI paths; the EMI steps only for EMI; Paid from
  suggestions are the home's real financedThrough values; Both of you → paidBy 'split';
  private selects you. The review is CoveVoucher, punched for an EMI.
- Routine: For how long sets endMinutes; Which days finds or creates the routine set (3.12a)
  — creating a set and its event is two controller calls; if the second fails, report what
  the user is left with and don't leave an empty set silently. The review is CoveBand.

Tests for each path (monthly, quarterly, yearly, EMI with 3 of 12 paid; routine into an
existing set and into a new one). Goldens of the cycle step, the next-date step, the EMI
steps, and both reviews. tool/check.sh must exit 0.
Commit as `feat(add): commitment and routine (3.12f)`.
````

## 3.12g — Again

````
Add Again to the picker, to design/specs/14-add-flow.md §6.

- Store the last expense, task or event created through Add as {kind, id} in local
  preferences (use the app's existing preferences mechanism, not a new one).
- The row shows only if that record still exists in the database. Read its values from the
  record, not from a cached copy.
- Tapping it starts the kind with everything carried except the one blank field, lands on
  that step with the carried line, and Next goes straight to review.

Tests: after adding an expense, the picker shows Again with its title, category and amount;
deleting that expense removes the row; Again leaves the amount empty and Next lands on review;
habits, commitments and routines never become Again. Goldens of the picker with the row and
of the carried amount step. tool/check.sh must exit 0.
Commit as `feat(add): Again (3.12g)`.
````

## 3.12h — the switch-over

````
Point every create path at AddFlow.

1. Find every place that opens a create form today: every `XFormSheet.show(...)` call
   without an existing record, `CalendarCreateSheet.show`, and the quick-add task sheet
   inside calendar_create_sheet.dart. List them all first, with what each opens now.
2. Replace each with `AddFlow.show` with the right kind and anchor (a calendar day passes its
   date; a list passes its listId). Calls that open a form with an existing record are
   Edit — leave them alone.
3. Transfers: Add doesn't make transfers (§5). If ExpenseFormSheet's create mode is the only
   way to record one, add a header action "Record a transfer" on the Expenses screen that
   opens ExpenseFormSheet preset to Transfer — only if that header has fewer than 3 actions;
   otherwise stop and report.
4. The routines screen: if its add button manages routine sets (not routine events), keep
   that and report it; if it adds a routine event, point it at AddFlow(kind: routine).
5. Delete calendar_create_sheet.dart once nothing uses it, and its line in
   tool/style_allowlist.txt. The old form sheets stay (Edit uses them); don't touch their
   allow-list lines.
6. Report a before → after table of every entry point, and anything that was creatable
   before and isn't now. That list must be empty, or each item must say where it is still
   creatable.

Regenerate the goldens of every screen whose entry point changed (they shouldn't move
visually — report any that do). tool/check.sh must exit 0.
Commit as `feat(add): every create path opens Add (3.12h)`.
````

---

## After 3.12

**3.13 — the floating bar goes live.** `CoveFloatingBar` was built in Phase 2 but the app
shell still uses `CoveBottomNav`. 3.13 swaps it in, with + opening `AddFlow`. It comes after
Add so the + has somewhere to go. The prompt will be written when 3.12 is green.
