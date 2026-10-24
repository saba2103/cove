# Phase 3.11 — the detail sheets, as a sequence

Six sheets share one skeleton, so the skeleton is a primitive built first. One prompt at a
time, in order.

`weather_detail_sheet.dart` was never designed — it is Phase 4 (tokens only), not here.
There is no event or routine detail sheet in the app: events open through the Activity
dispatcher (3.11i), and routines have none. Creating new sheets is new behaviour, so it is
out of scope.

---

## 3.11a — fix the paper gold

````
A contrast bug in the paper slips, found while specifying the detail sheets.

CoveSlipPalette.resolve() gives the PAPER variant
`accentFill: CoveTokens.light.accentFill` (#A97C4F). On paper that measures 2.45:1 against
the darkest paper stop — under the 3:1 a meaningful mark needs. It draws the receipt's
viewer-share bar, the habit grid's done cells, the voucher's due ring and the EMI's paid
punches, so all of those are faint on paper (Today in light mode, and every detail sheet).

1. For the paper variant, use `cv.paperAccent` (#76532D, 4.57:1) for accentFill.
   Ink is unaffected.
2. Extend tool/check_contrast.py so the paper stops are checked like the ink stops:
   paper.ink / ink2 / ink3 / accent as text at 4.5:1, and every colour a slip uses as a
   mark (the paper accentFill, statusGood, ink3 as mark, and every LIGHT-mode category
   colour) at 3:1. Report the worst pair.
3. Regenerate the slip goldens and Today's light-mode goldens. Every change should be the
   gold darkening on paper — report anything else. tool/check.sh must exit 0.
````

## 3.11b — the dial

````
Build `CoveDial` on CoveSlip, to design/specs/10b-dial.md. Read the colour section first:
on paper, category colours come from CoveTokens.light, never context.cv.

Goldens: three categories (one small share, one large, one at 0%), paper, both app
brightnesses — confirm the arc reads identically in dark mode. Same Phase 2 rules: tokens
only, (literal) only where the spec marks it, nothing under lib/features changes.
tool/check.sh must exit 0.
````

## 3.11c — the skeleton

````
Build `CoveDetailSheet` in lib/core/widgets/, to design/specs/13-detail-sheet.md.

It takes a kind glyph, a kind label, a context string, a slip widget, a meaning panel
(glyph, title, sub-line), and verbs (Edit plus at most one more, and a list of menu items).
It must know nothing about any particular kind.

- The slip is always the paper variant, in both modes.
- No ✓ in the kind line — the kind action lives in the verb row only.
- At cover width the kind line's context wraps; it never ellipsizes. Measure it at 320dp
  with "COMMITMENT · EVERY MONTH" and "EXPENSE · EATING OUT".
- Goldens with three fillings (expense, habit, EMI) built from fixtures, both modes.
- Same Phase 2 rules. tool/check.sh must exit 0.
````

## 3.11d to 3.11i — one sheet each

For each, say:

> Do task **3.11d** from `product/PROMPTS-PHASE3-SHEETS.md`.

| Task | File | Slip | Budget |
|---|---|---|---|
| 3.11d | `lists/list_item_detail_sheet.dart` | CoveNote | 11 |
| 3.11e | `expenses/expense_detail_sheet.dart` | CoveReceipt | 10 |
| 3.11f | `habits/habit_detail_sheet.dart` | CoveHabitCard | 13 |
| 3.11g | `expenses/category_detail_sheet.dart` | CoveDial | 12 |
| 3.11h | `subscriptions/commitment_detail_sheet.dart` | CoveVoucher (+ EMI punched) | 41 — the largest |
| 3.11i | `activity/activity_detail_sheet.dart` | CoveTicket for events; other kinds route to their own sheet | 6 |

The prompt for each of them:

````
Convert <file> to CoveDetailSheet, to design/specs/13-detail-sheet.md. The slip is <slip>,
paper variant.

- The meaning panel uses the row for this kind in the spec's table, from data that already
  exists. If the spec names a fact the app does not store, omit it and report it.
- Verbs: Edit plus the second verb the spec lists for this kind — and only if this sheet
  already performs that action today. Every other action this sheet has today moves into
  the ⋯ menu. Do not drop any existing action, and do not add a new one. List every action
  before and after so I can see nothing was lost.
- Destructive menu items say what they destroy.
- Delete this file's line from tool/style_allowlist.txt.
- Regenerate this sheet's goldens. tool/check.sh must exit 0.
````

Extra rules for two of them:
- **3.11e (expense):** extract the share arithmetic from expenses_screen.dart into one
  shared helper and use it from both places. Do not write a second copy. A private expense
  shows "Yours alone".
- **3.11h (commitment):** the EMI variant is the punched voucher; Foreclose goes in ⋯ with
  copy that says what foreclosing does. Marking paid must drop the PAID stamp onto the
  voucher and fade the due ring — that is the slip's live state, already built in 3.10e.
