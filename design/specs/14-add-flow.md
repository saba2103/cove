# 14 — Add: One Thing at a Time

Reference: `design/screens/add.png` (the picker) and `design/screens/add-steps/*.png`
(every step type, the six reviews, the Added state, Again). The PNGs are the prototype at
×2; convert to device scale the usual way (prototype px × 1.3, snapped to 4) and map to
existing tokens. If a size has no token, add one to `design/tokens.json`, regenerate, and
report it. Do not hard-code a new literal.

Add **creates** records. Editing stays on the existing form sheets (every detail sheet's Edit
already opens them). Add replaces only the create paths.

---

## 1. The picker

A `CoveSheet` (not full height).

- Eyebrow `ADD` in capsPage. When opened from a dated surface (a calendar day, a day on
  Today) the eyebrow reads `ADD · THU 8 OCT`. Close button on the right.
- Six tiles, two columns, in this order: **Event** "a plan, an outing" · **Expense**
  "something spent" · **Task** "to do, by a day" · **Habit** "something you keep up" ·
  **Commitment** "a bill that renews" · **Routine** "the shape of a day".
- Each tile carries a small paper mark of the slip that kind prints: event ticket, receipt,
  note with a checkbox, habit ring, voucher with a due ring, routine band. These are drawn
  icons in the paper colours (`CoveTokens.light` paper stops), not Material icons. One
  `CoveAddMark(kind)` widget draws all six.
- Under the tiles, the **Again** row, only when there is something to repeat (§6).

## 2. The step page

A full-height `CoveSheet`. From top to bottom:

1. **Top row:** back (on step 1 it returns to the picker, or closes if the flow was opened
   for one kind), eyebrow `EXPENSE · 3 OF 7` (the kind in capsPage, the count in tertiary),
   close.
2. **Progress:** one segment per step, filled up to and including the current one. The
   count changes when a conditional step appears or disappears (EMI, Which list).
3. **Crumbs:** one pill for each answered step before this one, showing the answer (`₹2,140`,
   `Namdhari's`, `Today`, `Groceries`). Tapping one goes to that step. Wrap to as many lines
   as needed; never ellipsize an answer.
4. **The question**, centred, display face. One question per page.
5. **The body** for the step type (§3).
6. **Foot:** on the left, the visibility chip (eye icon + "Both can see it" / lock +
   "Only you can see it"). On the right, a gold **Next →**, disabled until the step has an
   answer. On a **pick** step (any step where you tap one option), picking moves on by itself;
   Next is still there for when you come back to a step that's already answered.

Opening the flow never shows the system keyboard except on a **text** step.

## 3. Step types

| Type | Body | Answer |
|---|---|---|
| **amount** | Hero figure (₹ small, figure large, display face). Below it, a carried line when the step came from Again. Then a 3 × 4 keypad: 1–9, `00`, `0`, delete. Each key is `CoveSize.row` (52) tall. At most 7 digits. Whole rupees only — paise are set through Edit. | `int` rupees > 0 |
| **text** | One underlined input, autofocused, with the keyboard. Under it, up to five suggestion chips: the user's own most-used titles for this kind from the last 90 days, most frequent first. If there are none, no chips. **Never a hard-coded example name.** Placeholder text is a plain instruction (`Type a name`), not an example. An optional text step also has a `Skip` chip. | trimmed, non-empty unless optional |
| **choice** | A list of option rows (radius inline). A row can carry a colour swatch (category) or a second line in tertiary (`twelve times a year`). Picking moves on. | one option |
| **person** | Two or three large person tiles with `CoveAvatar` (you, partner, and for some kinds `Both of you` with the unfilled ring). Under them, toggle rows (`CoveToggleSwitch`) — see each kind in §5. Picking a person moves on only when no toggle row is shown; otherwise Next moves on. | per kind |
| **day** | A strip of seven day cells (weekday caps + date), anchored (§4). The anchor cell has a gold ring; the selected cell is filled. Under the strip, the full label (`Today, 5 Oct`). Under that, a quiet text button `Another date` that opens a month picker on a `CoveSheet`. Picking a cell moves on. | a date |
| **month-day** | A 7-column grid of 1–28 (commitments renew on one of the first 28 days, so every month has it). Hint above: `It renews on this day, every month.` | 1–28 |
| **next-date** | For a quarterly or yearly commitment: a row of month chips (this month and the next eleven), then the 1–28 grid. Hint: `When is the next one due?` | a date on or after today |
| **time** | `08 : 00` display with the hour and minute as two tappable boxes and an AM/PM pair, above a clock face with twelve positions. Hour mode first; picking an hour switches to minutes (5-minute steps). For an event only, an `All day` chip under the face. | hour + minute, or all day |
| **week** | Seven toggles, M T W T F S S, Monday first. Hint: `5 days a week` / `Every day`. At least one must be on. | set of weekdays |
| **review** | §7. | — |

**Cover width (< `CoveSize.compactThreshold`):** the day strip and the week toggles keep 48dp
targets and scroll horizontally, with the anchor or first selected cell scrolled into view. The
keypad and the clock face shrink to fit the width; the keys never drop below 48dp tall.

## 4. Anchored days

- The **anchor** is the date the flow was opened for (a tapped calendar day), otherwise today
  (`clock.now()`).
- **Expense:** the seven days **ending** at the anchor (a spend has already happened).
- **Task and event:** the seven days **starting** at the anchor.
- When the anchor is not today, a carried line sits above the strip: `Starting from Thu 8 Oct
  — the day you tapped +. Change it here.`
- The day is **always asked**. It is preselected to the anchor, but the step is never
  skipped and never filled in silently.
- Labels: `Today`, `Yesterday`, `Tomorrow`, else the weekday name, then `, 5 Oct`.

## 5. The six kinds

Partner names come from the partner profile, never a literal. In a home with no partner yet,
partner and `Both` options are hidden, and the visibility toggles stay (a partner may join
later, and everything not private is waiting for them).

### Expense — 7 steps → `ExpenseController.logExpense`
1. **How much?** amount
2. **What for?** text → `title`
3. **When?** day (ending at anchor) → `expenseDate` (keep the current form's time-of-day rule)
4. **Which category?** choice: the home's categories with their colour swatches, then
   `New category` (uses the existing `addCategory`) → `category`
5. **Who paid?** person: you · partner. Toggle rows: **Split it half and half** (on by
   default) and **Keep it private** — "Only you will see it — it stays out of {partner}'s
   Cove". Private selects you, turns Split off and disables the partner tile.
   Mapping: split on → `shared`; split off → `partnerCanSee`; private → `privateToMe`.
   It produces every combination the current `ExpenseFormSheet` can create except
   (partner, private), which Add leaves out on purpose — private selects you. Edit can
   still produce it.
6. **On what?** choice: Card · UPI · Cash · Skip → `paymentMethod` `card`/`upi`/`cash`/null
7. review → receipt

A **transfer** is not an expense and is not in Add. It stays on `ExpenseFormSheet`.

### Event — 5 steps → `CalendarController.createEvent`
1. **What is it?** text → `title`
2. **Which day?** day (starting at anchor)
3. **What time?** time, with `All day`. `endTime` = start + 1 hour, the same default as
   the current form; all-day uses the current form's all-day times.
4. **Where?** optional text with Skip → `location`
5. review → ticket

No "Whose is it?" — events don't store an owner yet (Phase 4, schema v12). The ticket's
owner line reads `Both of you`, same as the event detail sheet.

### Task — 3 or 4 steps → `ListController.addItem`
1. **What needs doing?** text → `title`
2. **Which list?** choice of the home's unarchived lists, *only* when there is more than one
   and the flow wasn't opened from a list. If there are no lists, this step is a text step,
   **Name the list**, and the list is created first with the existing list controller.
3. **By when?** day (starting at anchor), plus a `No particular day` option under the strip
   → `dueDate` or null
4. review → note

No "Whose is it?" — tasks don't store an owner yet (Phase 4).

### Habit — 4 steps → `HabitController.createHabit`
1. **What is the habit?** text → `name`
2. **How often?** choice: Every day · Weekdays · Weekends · Pick the days. Pick the days
   reveals the week toggles on the same page, with Next. Serialise exactly the way
   `HabitFormSheet` does through `HabitSchedule` (same `cadence` string, same
   `targetDaysPerWeek`) — a test proves it.
3. **Who can see it?** choice: `Both of you` · `Only you` → `visibility`. (A habit is always
   kept by the person who makes it; the partner's habits are read-only for you.)
4. review → habit card

### Commitment — 7 to 9 steps → `SubscriptionController.createSubscription`
1. **What is it?** text → `name`
2. **How much, each time?** amount
3. **How often does it come?** choice: Every month "twelve times a year" · Every quarter
   "four times a year" · Every year "once, on a date" · It ends — an EMI "a number of
   instalments" → `billingCycle` `monthly`/`quarterly`/`annual`/`monthly` + EMI fields
4. *EMI only:* **How many instalments in all?** keypad (whole number ≥ 1) → `totalInstallments`
5. *EMI only:* **How many are paid already?** keypad, `0` allowed, less than the total →
   `paidInstallments`
6. **Which day of the month?** month-day (monthly and EMI) → `nextBillingDate` = the next
   occurrence of that day on or after today. **When is the next one due?** next-date
   (quarterly and yearly) → `nextBillingDate`.
7. **Paid from?** text with suggestion chips of the home's existing `financedThrough` values
   (real values only), plus Skip → `financedThrough`
8. **Whose is it?** person: you · partner · Both of you (Both = `split`, the value the
   current form uses). Toggle row: Keep it private (selects you) → `paidBy`, `isPrivate`
9. review → voucher (the punched EMI voucher for an EMI)

### Routine — 5 steps → `RoutineController.createRoutineEvent`
1. **What is it?** text → `title`
2. **When, usually?** time → `startMinutes`
3. **For how long?** choice: 15 min · 30 min · 45 min · 1 hour · 2 hours →
   `endMinutes` = start + length, capped at 23:59
4. **Which days?** week (default Mon–Fri) → finds the routine whose `daysJson` holds exactly
   these days. If none exists, create one first with `createRoutine`, named `Everyday`,
   `Weekdays`, `Weekend`, or the short days joined (`Mon, Wed, Fri`).
5. review → band

No "Whose is it?" — routine events don't store an owner yet (Phase 4).

### Asked nowhere in Add (still set through Edit)
Expense notes and paise · event description, end time, recurrence · task notes · habit
reminder time · commitment category and end date · routine category and notes.

## 6. Again

- Remembers the last **expense, task or event** created through Add on this device: its kind
  and record id, in local preferences. Habits, commitments and routines renew themselves, so
  they never land here.
- The picker shows the row only if that record still exists: `Again: Namdhari's · Groceries`
  with `last ₹2,140` on the right (task: `last by Monday`; event: `last Thursday`).
- Tapping it opens the flow with every answer carried over except **one**: the amount for an
  expense, the day for a task or event. It lands on that step with a carried line
  (`Namdhari's · Groceries · Card — last time ₹2,140`), and Next goes straight to review.

## 7. Review, Add, Added

- Question: **Does this look right?**
- The kind's slip, paper variant, built from the draft: receipt · ticket · note · habit card
  (no-history state) · voucher · band.
- Every field on the slip that came from a step is tappable and goes to that step; Next from
  there returns to review. The slip's whole-card `onTap` is not used here.
- Under the slip: `Tap anything above to change it.`
- Foot: the visibility chip, and gold **Add expense** / **Add event** / … (lower-case kind).
- On Add: write through the controller (the same call the old form made, so sync and outbox
  events are identical). The question becomes **Added.**, an **ADDED** stamp lands on the slip
  (`CoveMotion`), fields stop being tappable, and the foot becomes a text button **Add another**
  (restarts the same kind, blank) and gold **Done** (closes).
- A failed write shows the error toast, keeps the draft, and leaves Add enabled.
- Nothing else is said after Add. Notification timing is Phase 4 — don't promise it.

## 8. Slips need two additions (3.12b)

- **Stamp:** `CoveSlip` gets an optional stamp (text + whether it has landed). Generalise
  the voucher's PAID stamp into it so PAID and ADDED are one implementation.
- **Visibility line:** an optional footer line on every slip — eye/lock glyph + `BOTH CAN SEE
  IT` / `ONLY YOU CAN SEE IT` in capsSlip, tertiary.
- **Field taps:** each slip takes an optional map from its fields to callbacks. A tappable
  field gets a 48dp target and the semantics label `Change {field}`.

## 9. The band (new slip, 3.12b)

`CoveBand` — the routine slip. Paper or ink like the others.

- `COVE · ROUTINE` caps, title in slipTitle.
- A 24-hour track, radius inline, the day's span in a soft tint. The routine sits on it as a
  hatched block from start to end, in accentFill, positioned by real minutes. Under the track,
  ticks `12 AM · 6 · 12 PM · 6 · 12`.
- A row of seven day dots, Monday first, filled for the routine's days.
- Caption: `8:00 – 8:30 AM`.
- Minimum block width so a 15-minute routine stays visible: 8dp.

## 10. Data rules

- No schema change. Every field written exists today.
- No invented data: suggestions, hints and Again come from the user's own records or not at all.
- All dates from `clock.now()`; goldens pinned with `kDefaultGoldenClock`.
- The flow's state is a pure draft model per kind (`AddDraft`), with `isComplete` and a
  method that returns the controller arguments. It is unit-tested as data before any widget
  uses it.
