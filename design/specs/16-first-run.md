# 16 — First run

From *Cove, Put Together* (the "First run" toggle). Reference images:
`design/screens/first-run/01-today.png` … `07-our-home.png` (prototype ×2. Convert to device
scale the usual way and map to tokens).

Seven screens have a first-run state: **Today, Calendar, Routines, Expenses, Commitments,
Activity, Our home**. The rest (The year, EMIs, Notifications, Settings, Add, detail
sheets, the widget) are "not applicable on first run" and keep their existing empty
behaviour.

## The principle

"Nothing here is made up." A first-run screen shows the real frame of the page (header,
the figures as `—`, section labels), says plainly that nothing is here yet, and offers one
gold action. It **never** shows sample data, placeholder slips or example names.

## 1. The seed card (new primitive, `CoveSeedCard`)

The block every first-run screen is built around:

- A card, radius card, with a **dashed** hairline border (`line.strong`) and a soft gold
  glow behind the top centre (`accent.fill` at low alpha, radial). This is the only place
  that glow is used.
- A line illustration, 48dp, `accent.text`, stroke only. One per screen: sprout (Today),
  calendar (Calendar), stacked bands (Routines), rupee coin (Expenses), renew arrows
  (Commitments), wave (Activity), key (Our home).
- Title, display face, centred.
- Body, rowSub, `text.secondary`, centred, at most four lines at phone width.
- One gold pill button with a `+` (CovePillButton primary).
- Optional "alt" line under it, caps or small text in `text.tertiary`.

## 2. Starter rows (new primitive, `CoveStarterRow`)

Under some seed cards: a list of rows, each with a glyph in a rounded square, a title, a
second line, and a chevron. Each one opens Add for a specific kind.

## 3. When a screen is in first run

A screen is in first run when the **whole home** has nothing of what that screen shows. One
logged expense ends Expenses' first run forever, even if it is later deleted. In that case
the screen shows its normal empty states. Precisely:

| Screen | First run while |
|---|---|
| Today | the home has no expenses, events, habits, list items, commitments or routines |
| Calendar | the home has no dated records at all (events, expenses, tasks with a due date, habit check-ins) |
| Routines | the home has no routine events |
| Expenses | the home has never had an expense |
| Commitments | the home has never had a commitment |
| Activity | the activity log is empty |
| Our home | the home has one member (the partner hasn't joined) |

"Never had" needs a flag that survives deletes. Store `first_run_done.<screen>` in local
preferences, set the first time the screen sees data. No schema change.

## 4. Each screen

Copy is exact. `{partner}` is the partner's display name. Before the partner has joined,
use "your partner". No gendered pronouns anywhere: the design's "her phone" / "waiting for
her" become the phrasing below.

**Today**
- Header and date line as normal. The four figures show `—` with second lines `nothing yet`,
  `nothing on`, `none kept yet`, `nothing on it`.
- Seed: sprout · **Your first day in Cove** · "Nothing here is made up. The page fills as the
  two of you put things in it — one line is enough to start." · **Add the first thing** (opens
  the Add picker) · alt: "Or try one of these:"
- Starter rows: **Log what you spent today** "a coffee, the auto, the groceries" (Add ·
  expense) · **Start the grocery list** "{partner} can add to it too" (Add · task) · **Put
  something on the calendar** "the thing you keep forgetting" (Add · event).
- The Letter section: caps label, then the quiet line "The letter writes itself once there is
  a day to read." with **"Come back tomorrow morning."** on the next line.

**Calendar** — the week strip and the four figures (`—`) as normal. Seed: calendar · **An empty
{Weekday}** · "Events, spending, habits and list lines all land on a date. Put one here and
the day starts holding things." · **Add to today** (Add picker, anchored to the selected day;
the label says "Add to {weekday}" when the day isn't today) · alt: "Nothing is due this month
either."

**Routines** — Seed: bands · **Two days, not yet drawn** · "A routine is the shape a day
repeats — the walk, the standing call, lights out. Add a few and the sky fills in behind
them." · **Add a routine** · alt: "Yours on the left, {partner}'s on the right." Below it, the
Everyday and Weekdays sections with count `0` and the quiet line "Nothing repeats yet."
(Until owners exist in v12, keep the alt line anyway. It describes the page the design
promises.)

**Expenses** — The Spent card shows `—` "this month". The Budget card shows **Not set** "tap to
set one" (opens the budget sheet). Seed: coin · **No money has moved** · "Log one purchase
and this page starts working: the pace, the projection, who paid what, and a dial of where
it went." · **Log an expense** · alt: "A budget makes the rest of it mean something."
Below: the EVERY DAY THIS MONTH label with "The chart needs a few days before it can say
anything useful." and the WHERE IT WENT label with "Categories appear as you use them —
nothing to set up first."

**Commitments** — Seed: renew arrows · **Nothing renews yet** · "Rent, the EMIs, the
subscriptions you forget about. Add them once and Cove counts them down for you." · **Add a
commitment** · alt: "Start with rent — it is the one you already know." Starter rows: **Rent
or maintenance** "the one that never changes" (Add · commitment, monthly preselected) · **An
EMI you are paying off** "so you can see when it ends" (Add · commitment, EMI preselected) ·
**A subscription** "the ones that renew quietly" (Add · commitment). Below: THE RUNWAY label
with "The runway draws itself once there is something to pay off."

**Activity** — Seed (no button): wave · **Nothing has happened yet** · "When {partner} adds
something, ticks something off or marks a bill paid, it shows up here." · alt: "Cove never
sends a notification you did not ask for." Then the TODAY label and "Quiet."

**Our home** (partner not joined) — The arch illustration, the home name, "{City} · made
{relative time}", then the two people: you, and a `+` ring labelled **Invite** / "your
partner". Seed: key · **A home with one person in it** · "Cove only becomes itself when there
are two of you. Send a key — everything you add before your partner joins is waiting for
them." · **Send a key** (opens the existing invite / QR flow) · alt: "Or share a code ·
{CODE}" with the real pairing code, in accent. If there's no code yet, generate one the
existing way, or leave the alt line out.

## 5. Rules

- Bars, headers and the + work exactly as on the in-use screens.
- Every action opens something that already exists: Add (with a kind or preset), the budget
  sheet, the invite flow. No new flows.
- Goldens for each first-run screen, 3 widths × 2 modes, and a test that each one leaves
  first run after its first record and doesn't come back after that record is deleted.
