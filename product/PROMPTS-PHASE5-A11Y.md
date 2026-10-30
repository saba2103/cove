# Phase 5 — accessibility

The bar is **WCAG 2.2 AA**, applied to a native app through WCAG2ICT. The gaps come from
`claude/cove-standards-assessment.md` (21 Oct). Android is the platform:
- **TalkBack** (screen reader)
- **Switch Access** and **Voice Access**
- **Font size** and **Display size** settings
- **Remove animations**

Until a real audit has been done, Cove says "designed following WCAG 2.2 AA", never
"conforms" or "certified".

Rules for every prompt: no visual change beyond what accessibility requires; the overflow
guard stays on; tool/check.sh exits 0; one commit per prompt. Device checks run in the
isolated test app (`com.app.cove.perf` or similar), never by sending input to the real Cove.

---

## 5.0 — find out where we stand

````
Add an accessibility test suite, test/a11y/, that pumps every screen, sheet and Add step using
the existing golden fixtures, at 411dp, light and dark, and runs Flutter's guideline matchers:
`androidTapTargetGuideline` (48×48), `labeledTapTargetGuideline`, and
`textContrastGuideline`. Don't fix anything yet. Write build/a11y_baseline.md listing every
failure by screen and widget, and commit only the suite, with the failing cases marked
`skip:` and a reason that names the prompt that will fix them (5.1–5.5). The skips must be
gone by the end of Phase 5.
Commit as `test(a11y): baseline audit across every screen (5.0)`.
````

## 5.1 — everything has a name and a state (WCAG 1.1.1, 1.3.1, 4.1.2)

````
1. Every tappable control has a spoken label that says what it does ("Add", "Close", "More
   actions for Netflix"). Icon-only round buttons included.
2. Section labels are headings (`Semantics(header: true)`), so TalkBack's heading navigation
   works.
3. Rows merge into one announcement: "Namdhari's, ₹2,140, Groceries, paid by Ancy, today".
   Money is spoken as words ("two thousand one hundred forty rupees"), not "rupee sign 2140".
4. **Slip state is semantic.** For example:
   - ticket: "Dinner at Toit, Thursday 8 PM, both of you"
   - voucher: "Netflix, ₹199 a month, due Friday, paid"
   - EMI: "Car loan, 12 of 48 paid"
   - habit card: "Morning walk, kept today, 23 days running"
   - note: "Gas cylinder, done"
   Ticking a checkbox announces the new state.
5. **Text alternatives for drawn things:**
   - the Year chart and the EMI staircase: a one-sentence summary plus a "Read as a table"
     action that opens the same numbers as a list
   - the category dial, the Day Arc and the routines sky: a summary of what they show
   - the Our home arch and other decorative art: excluded from semantics
6. The widgets: each RemoteViews hit area has a content description. Each widget bitmap has
   one that summarises it ("Groceries, 4 open").
7. Remove the 5.1 skips from test/a11y/ and add semantics tests for the slips and charts.

Commit as `feat(a11y): names, headings, slip states and text alternatives (5.1)`.
````

## 5.2 — text at 200% (WCAG 1.4.4, 1.4.10)

````
1. Add golden and overflow runs at `TextScaler.linear(1.3)` and `(2.0)` for every screen, at 320
   and 411dp, both modes. No overflow, no clipped text, no ellipsis on labels that matter.
2. Fix layouts by reflowing, never by capping the text scale:
   - metric grids stack to one column
   - side-by-side rows stack
   - the floating bar drops to icons only
   - the Add keypad keys grow taller
   - slips let their text wrap (the Day Sheet widget is a bitmap and keeps its own sizes)
3. Any place that clamps textScaler today: remove the clamp, or report why it must stay.

Commit as `feat(a11y): layouts hold at 200% text (5.2)`.
````

## 5.3 — no drag required, and a keyboard works (WCAG 2.1.1, 2.5.7, 2.4.7)

````
1. **Clock face:** tapping the hours or minutes box opens the number keyboard to type the value.
   Add − / + buttons beside the display that step by 1 hour and 5 minutes. Dragging stays.
2. **Amount keypad:**
   - a hardware keyboard works (digits, Backspace, Enter = Next)
   - a pasted amount ("2,140" or "₹2140.50") is accepted (whole rupees, as now)
   - each key's label is spoken ("one", "double zero", "delete")
3. **Focus:** a visible focus ring (accent, 2dp, following the squircle) on every focusable
   control. Logical focus order in sheets and the Add flow. A sheet traps focus and returns it
   to the control that opened it.
4. Long-press-only actions get a visible alternative (the EMI what-if already has one; find
   any others).
5. Tests: the Add expense flow completed entirely with a hardware keyboard; a time set without
   dragging.

Commit as `feat(a11y): keyboard, typed time and focus (5.3)`.
````

## 5.4 — time and motion (WCAG 2.2.1, 2.3.3)

````
1. **Undo toasts:** when `MediaQuery.accessibleNavigationOf(context)` is true (TalkBack or
   Switch Access on), a toast with Undo stays until dismissed or acted on. It's announced as a
   live region. PendingDeleteService must keep the delete pending for as long as that toast is
   up.
2. **Reduce motion:** when `MediaQuery.disableAnimationsOf(context)` is true (Android "Remove
   animations"), every CoveMotion duration becomes zero: sheets, the stamp landing, the
   carousel, chart draw-ins, the bar detaching.
3. Tests for both.

Commit as `feat(a11y): undo waits for assistive tech; motion respects the setting (5.4)`.
````

## 5.5 — orientation and non-text contrast (WCAG 1.3.4, 1.4.11)

````
1. **Orientation:** main.dart locks portrait. Remove the lock. Layouts are already width-driven
   (the 420dp cap only at ≥ 600dp). Add goldens in landscape at phone size (e.g. 891×411) for
   Today, Expenses, a detail sheet and the Add flow. Fix any overflow.
2. **Non-text contrast at 3:1:** extend tool/check_contrast.py to every UI boundary and state
   mark, in both modes and on both slip variants:
   - empty and upcoming EMI punches (both measured at 1.4:1 and 2.1:1 on 21 Oct)
   - the slip edge in light mode (1.1:1)
   - toggles, the unticked checkbox, input borders, the focus ring, chart gridlines that carry
     meaning
   Fix through token values. Report each pair before and after.

Commit as `feat(a11y): any orientation; every mark visible (5.5)`.
````

## 5.6 — on the phones

````
1. In the isolated test app on the Fold: turn on TalkBack with adb, walk every screen with
   uiautomator dumps, and report any control without a description and any reading-order
   problem. Turn TalkBack off afterwards.
2. Write build/a11y_manual_check.md: a 10-minute checklist Saba and Ancy can do by hand on
   the real app.
   - TalkBack: add an expense, tick a list item, undo a delete
   - Font size at maximum: open each tab
   - Remove animations: open a sheet
   - Rotate to landscape
3. Investigate the single slow first frame (around 60ms) seen in 4.5g's profile run on the Fold.
   Report its cause, and fix it only if it's in our code.
4. All test/a11y/ skips are gone; report the final pass count.

Commit as `test(a11y): device pass and manual checklist (5.6)`.
````
