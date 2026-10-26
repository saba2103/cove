# Phase 4.2 — first run

To `design/specs/16-first-run.md`, with the reference images in `design/screens/first-run/`.
Three prompts, in order.

Before them, one small fix left over from 4.1.

---

## 4.2-pre — habit menu tap target

````
The overflow fix in 217c2c6 gave the habit row's ⋯ PopupMenuButton
`tapTargetSize: shrinkWrap` and zero padding, on top of its 24×24 constraints. Its tap
target is now 24dp, and the minimum is 48. Keep the icon at its visual size but restore a
48×48 hit area (CoveSize.hit), without bringing the overflow back at 320dp. Add a test that
every tappable control on HabitsScreen is at least 48×48 at 320, 411 and 840.
tool/check.sh must exit 0. Commit as `fix(habits): menu tap target back to 48dp (4.2-pre)`.
````

## 4.2a — the pieces and the rule

````
Read design/specs/16-first-run.md in full, and look at every image in
design/screens/first-run/.

1. Build `CoveSeedCard` and `CoveStarterRow` in lib/core/widgets/ (§1, §2), including the
   seven line illustrations as one `CoveSeedArt(kind)` widget, drawn with paths. No image
   assets.
2. Build the first-run rule (§3) as one provider: `firstRunProvider(CoveScreen)` → bool. It
   reads the database with the counts each screen needs and the `first_run_done.<screen>`
   preference, and sets the preference the first time it sees data.
3. Unit tests for the rule: an empty home → all seven true; one expense → Expenses, Today and
   Calendar false, the rest true; delete that expense → still false; a home with a joined
   partner → Our home false.
4. Goldens for CoveSeedCard (with and without a button, with an alt line) and CoveStarterRow,
   3 widths × 2 modes, with the overflow guard.

Nothing under lib/features changes yet. tool/check.sh must exit 0.
Commit as `feat(first-run): seed card, starter rows and the first-run rule (4.2a)`.
````

## 4.2b — Today, Calendar, Routines

````
Give Today, Calendar and Routines their first-run states, to design/specs/16-first-run.md §4,
matching 01-today, 02-calendar and 03-routines.

- The screen switches on firstRunProvider. In first run, the frame of the page (header,
  figures, labels, bar) stays as it is, and the seed card and quiet lines replace the content.
- Copy exactly as the spec, with {partner} from the partner profile ("your partner" before
  they join). No gendered pronouns.
- Every button and starter row opens Add with the kind or preset the spec names.
- Goldens of each first-run state, 3 widths × 2 modes, with the overflow guard. The in-use
  goldens must not change. List any that do.
- Tests: each screen leaves first run after its first record, and doesn't return after delete.

tool/check.sh must exit 0. Commit as `feat(first-run): Today, Calendar, Routines (4.2b)`.
````

## 4.2c — Expenses, Commitments, Activity, Our home

````
The same for Expenses, Commitments, Activity and Our home, matching 04 to 07.

- Expenses' "Not set" budget card opens the existing monthly budget sheet.
- Commitments' starter rows open Add with monthly / EMI / no preset (the EMI preset already
  exists from 3.12).
- Our home uses the real home name, city and creation time, and the real pairing code. Send a
  key opens the existing invite flow.
- The same golden, overflow and test rules as 4.2b.

tool/check.sh must exit 0. Commit as
`feat(first-run): Expenses, Commitments, Activity, Our home (4.2c)`.
````
