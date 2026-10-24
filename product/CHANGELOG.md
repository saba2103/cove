# Cove Product Changelog

This document tracks all user-facing changes, architectural upgrades, and engineering refinements across Cove releases in chronological order.

---

## [v2.0-alpha.1] — 2026-10-22

### Changed
- **Task 3.11e — `ExpenseDetailSheet` Converted to `CoveDetailSheet` & `CoveReceipt` with Shared Share Arithmetic (`Oct 25, 2026`)**:
  - *Outcome*: Converted [`ExpenseDetailSheet`](../lib/features/expenses/expense_detail_sheet.dart) to [`CoveDetailSheet`](../lib/core/widgets/cove_detail_sheet.dart) with a paper-variant [`CoveReceipt`](../lib/core/widgets/slips/cove_receipt.dart) slip ([`design/specs/13-detail-sheet.md`](../design/specs/13-detail-sheet.md)), displaying `EXPENSE · {CATEGORY}` in the kind line, the receipt with purchase row, split bar (`{Your name}'s share ({pct}%)` vs `{Partner's name}'s ({pct}%)` for shared expenses), deterministic barcode, meaning panel (`"{share} is your half"` when `splitRatio == 0.5` or `"{share} is your share"` for custom splits with `"{who} paid"`, and `"Yours alone"` with `"Not part of the shared total"` when `splitRatio <= 0.0`), the `Edit` verb pill button, and `"Delete this expense"` in the `⋯` overflow menu.
  - *Under the Hood*:
    - Extracted shared expense share arithmetic (`ExpenseShareBreakdown`, `computeExpenseShare`), category normalizer (`cleanExpenseCategoryName`), notes parser (`extractExpenseNotes`), and payment-method formatter (`formatExpensePaymentMethod`) into [`lib/features/expenses/expense_controller.dart`](../lib/features/expenses/expense_controller.dart) and used them in both [`expenses_screen.dart`](../lib/features/expenses/expenses_screen.dart) and [`expense_detail_sheet.dart`](../lib/features/expenses/expense_detail_sheet.dart).
    - Deleted `lib/features/expenses/expense_detail_sheet.dart 10` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (53 files / 497 literals remaining), added widget tests in [`test/golden/detail_sheet_golden_test.dart`](../test/golden/detail_sheet_golden_test.dart) covering shared (`50/50` and `70/30`) vs. private (`splitRatio <= 0`) expenses, and regenerated all 6 `expense_detail_sheet.{cover,phone,wide}.{dark,light}.png` goldens.
- **Task 3.11d — `ListItemDetailSheet` Converted to `CoveDetailSheet` & `CoveNote` (`Oct 25, 2026`)**:
  - *Outcome*: Converted [`ListItemDetailSheet`](../lib/features/lists/list_item_detail_sheet.dart) to [`CoveDetailSheet`](../lib/core/widgets/cove_detail_sheet.dart) with a paper-variant [`CoveNote`](../lib/core/widgets/slips/cove_note.dart) slip (`design/specs/13-detail-sheet.md`), showing `TASK · {LISTNAME}` in the kind line, the ruled task row (with live checkbox toggle and struck-through done state) on the paper slip, the meaning panel (`"On {list}"` when open or `"Done by {name}"` when completed, with `"Added by {name} · {date}"` beneath), `Edit` and `Done` / `Not done` verbs in the pill button row, and `"Delete this task"` in the `⋯` overflow menu.
  - *Under the Hood*:
    - Introduced the [`CoveSlipObject`](../lib/core/widgets/slips/cove_slip.dart) interface across all seven slip widgets (`CoveSlip`, `CoveReceipt`, `CoveTicket`, `CoveNote`, `CoveHabitCard`, `CoveVoucher`, `CoveDial`) so [`CoveDetailSheet`](../lib/core/widgets/cove_detail_sheet.dart) verifies `widget is CoveSlipObject && widget.variant == CoveSlipVariant.paper` through a single interface check.
    - Updated the `320dp` cover-width test in [`test/golden/detail_sheet_golden_test.dart`](../test/golden/detail_sheet_golden_test.dart) to assert that the kind line never ellipsizes or overflows without requiring a specific line count.
    - Deleted `lib/features/lists/list_item_detail_sheet.dart 11` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (54 files / 507 literals remaining) and generated 6 `list_item_detail_sheet.{cover,phone,wide}.{dark,light}.png` goldens in [`test/golden/screens_golden_test.dart`](../test/golden/screens_golden_test.dart).
- **Task 3.11c — `CoveDetailSheet` Shared Detail Sheet Skeleton (`Oct 25, 2026`)**:
  - *Outcome*: Built [`CoveDetailSheet`](../lib/core/widgets/cove_detail_sheet.dart) (`CoveDetailMeaningPanel`, `CoveDetailVerb`, `CoveDetailMenuItem`) on [`CoveSheet`](../lib/core/widgets/cove_sheet.dart) to [`design/specs/13-detail-sheet.md`](../design/specs/13-detail-sheet.md), taking a `20dp` `(literal)` kind glyph, kind label (`CoveType.capsPage` / `text.primary`), context string (`· {context}` in `text.tertiary` that wraps at cover width and never ellipsizes, with no `✓` in the kind line), a paper-variant slip widget (`CoveSpace.md` below the kind line), a meaning panel (`surface.row` fill, `CoveRadius.card`, `CoveSpace.md` padding, `CoveSpace.gutter` above, `24dp` `(literal)` leading glyph, title in `CoveType.rowTitle` / `text.primary`, sub-line in `CoveType.rowSub` / `text.tertiary`), equal-width verb pill buttons (`CoveSpace.lg` above, `Edit` plus at most one kind action, `CoveSize.hit` height, `1dp` `line.strong` border, `CoveSpace.md` gap), trailing ghost `CoveRoundButton`s for `⋯` (overflow menu) and `✕` (close), and ordinal semantics reading the slip's state first followed by the meaning panel.
  - *Under the Hood*:
    - Added [`test/golden/detail_sheet_golden_test.dart`](../test/golden/detail_sheet_golden_test.dart) and generated 18 goldens (`detail_sheet_expense`, `detail_sheet_habit`, `detail_sheet_emi` across `cover`, `phone`, `wide` and both brightnesses), plus `320dp` cover-width wrapping measurements for `"COMMITMENT · EVERY MONTH"` and `"EXPENSE · EATING OUT"`, semantics ordering checks, and overflow menu dispatch tests.
- **Task 3.11b — `CoveDial` Category Spending Share Slip (`Oct 25, 2026`)**:
  - *Outcome*: Built [`CoveDial`](../lib/core/widgets/slips/cove_dial.dart) (`CoveCategory`) on [`CoveSlip`](../lib/core/widgets/slips/cove_slip.dart) to [`design/specs/10b-dial.md`](../design/specs/10b-dial.md), featuring the `COVE · CATEGORY` caps line (`CoveType.capsSlip`), category title (`CoveType.slipTitle`), `160dp` `(literal)` donut dial with `12dp` `(literal)` stroke (track in `palette.rule`, clockwise spending-share arc from 12 o'clock), centred month total in `CoveType.slipFigure` with `"THIS MONTH"` in `CoveType.capsSlip` beneath, receipt-style recent purchase rows below a `1dp` `4/4` dashed rule, light-token category colour resolution on paper (`CoveTokens.light`, never `context.cv`, so every arc clears `>= 3:1` in both dark and light app themes), and WCAG 4.1.2 semantics (`"Category, Groceries, ₹12,400 this month, 68% of spending, 14 purchases"`).
  - *Under the Hood*:
    - Added [`test/golden/dial_golden_test.dart`](../test/golden/dial_golden_test.dart) and generated 12 goldens (`dial` and `dial_zero` across `cover`, `phone`, `wide` and both brightnesses) covering large-share (`68%`), small-share (`12%` Travel), and `0%` share categories on paper.
- **Task 3.11a — Paper Slip `accentFill` Contrast Fix & Paper Stop Contrast Gate (`Oct 25, 2026`)**:
  - *Outcome*: Updated [`CoveSlipPalette.resolve()`](../lib/core/widgets/slips/cove_slip.dart) so `CoveSlipVariant.paper` uses `cv.paperAccent` (`#76532D`, `4.57:1` on `paper.to`) for `accentFill` instead of `CoveTokens.light.accentFill` (`#A97C4F`, which measured `2.45:1` on `paper.to`), ensuring the receipt's viewer-share bar, the habit grid's done cells, the voucher's due ring, and the EMI's paid punches clear the `3:1` mark contrast floor on paper.
  - *Under the Hood*:
    - Extended [`tool/check_contrast.py`](../tool/check_contrast.py) to verify all three paper gradient stops (`paper.from`, `paper.via`, `paper.to`) against `paper.ink`, `paper.ink2`, `paper.ink3`, and `paper.accent` as text at `>= 4.5:1` (worst: `paper.accent` on `paper.to` at `4.57:1`) and against every mark colour used on a paper slip (`paper.accent` as `accentFill`, `status.good`, `paper.ink3` as mark, and all 8 light-mode `category.*` colours) at `>= 3.0:1` (worst: `category.travel` on `paper.to` at `3.17:1`).
    - Regenerated the affected slip goldens (`receipt`, `habit_card`, `habit_card_paper`, `voucher_paper`) and `today_screen` light-mode goldens.
- **Today "Due tomorrow" Section — Strict Today/Tomorrow Filtering, Dynamic Label, and Quiet Empty Line (`Oct 25, 2026`)**:
  - *Outcome*: Fixed three issues in [`TodayScreen`](../lib/features/today/today_screen.dart)'s commitments section:
    1. Removed the fallback to all active commitments when nothing is due today or tomorrow, showing only commitments whose `nextBillingDate` is today or tomorrow according to `clock.now()`.
    2. Computed the section label from the items shown (`"Due today"`, `"Due tomorrow"`, or `"Due today and tomorrow"`).
    3. Removed the fabricated `"No commitments due"` `CoveVoucher` when nothing is due today or tomorrow, rendering a quiet line (`"Nothing due tomorrow. Next: {name} on {date}."` from the next upcoming commitment, or `"Nothing due."` if there are none at all) instead.
  - *Under the Hood*:
    - Added 5 widget tests in [`test/today_and_cove_page_test.dart`](../test/today_and_cove_page_test.dart) covering items due today only, tomorrow only, both, none-with-next, and none at all.
- **Injectable Time (`package:clock`) & Deterministic Clock-Pinned Goldens (`Oct 25, 2026`)**:
  - *Outcome*: Replaced every `DateTime.now()` call across `lib/features/` and `lib/core/widgets/` with `clock.now()` from `package:clock` (leaving `lib/sync/` untouched), and pinned all `goldenMatrix` runs in [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart) inside `withClock(clock ?? kDefaultGoldenClock, ...)` where `kDefaultGoldenClock = Clock.fixed(DateTime(2026, 10, 15, 10, 30))` (Thursday morning, matching `_kFixedDate`).
  - *Under the Hood*:
    - Added [`test/clock_guard_test.dart`](../test/clock_guard_test.dart) to fail if `DateTime.now(` appears anywhere under `lib/features/` or `lib/core/widgets/`.
    - Regenerated the 30 time-dependent screen goldens (`activity_screen`, `calendar_screen`, `habits_screen`, `subscriptions_screen`, `today_screen`) and verified consecutive golden suite runs pass deterministically without `--update-goldens`.
- **Task 3.10h — "Today" (`TodayScreen`) Converted to Cove Slip Primitives, `CoveCarousel`, and `CoveLetter` (`Oct 25, 2026`)**:
  - *Outcome*: Converted [`TodayScreen`](../lib/features/today/today_screen.dart) to the v2 "Today" morning briefing layout ([`design/screens/today.md`](../design/screens/today.md) & [`design/screens/today.png`](../design/screens/today.png)), arranged top to bottom as:
    1. Screen-local `_TodayHeader` (home name with chevron, token-styled weather chip, ghost `CoveRoundButton` bell with an `8dp` `(literal)` `accent.fill` unread dot, and `CoveAvatar.header` for the viewer — never `CovePerson.both`, without modifying `CovePageHeader`).
    2. Date line (`CoveSectionLabel.page` with city readout).
    3. Greeting (`CoveType.greeting`: `"Good morning,"` italic in `accent.tint`, then viewer's name in roman `text.primary`).
    4. 2×2 `CoveMetricGrid` (`Spent today`, `Events`, `Habits`, `The list`, collapsing to 1 column below `CoveSize.compactThreshold`).
    5. `On the calendar` — `CoveTicket`s in a `CoveCarousel` (`CoveSlipVariant.ink` in dark mode, `CoveSlipVariant.paper` in light mode).
    6. `Habits` — `CoveHabitCard`s in a `CoveCarousel` with 21-day streak grids and interactive check-in toggles.
    7. `Spent today` — one `CoveReceipt` holding the day's purchases, `CovePerson.a` / `CovePerson.b` split bar, and deterministic barcode.
    8. `The list` — one `CoveNote` holding the open tasks with ruled lines and interactive completion checkboxes.
    9. `Due tomorrow` — `CoveVoucher`s in a `CoveCarousel` reading the existing subscriptions/commitments provider.
    10. `The Letter` — `CoveLetter` recomposed on every build via `composeDayLetter()` over today's live data, passing the home's actual currency symbol (`currency.symbol`) and each commitment's real `nextBillingDate` (`dueDate`), with tappable inline links navigating to the corresponding item or section.
    11. Footer (`"Two lives. One calm home."` italic in `CoveType.slipTitle` + encryption reassurance line).
    - **Intentional Design Change**: Removed the legacy **Recent activity** section from `TodayScreen` per [`design/screens/today.md`](../design/screens/today.md); activity is now reached exclusively from the notification bell in `_TodayHeader`.
  - *Under the Hood*:
    - Deleted `lib/features/today/today_screen.dart 34` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (55 files / 518 literals remaining) with zero raw style literals in `today_screen.dart`.
    - Removed `'today_screen.cover'` from `_kKnownLegacyOverflows` in [`test/golden/screens_golden_test.dart`](../test/golden/screens_golden_test.dart), emptying the legacy screen overflow backlog (`_kKnownLegacyOverflows = {}`).
    - Updated [`test/today_and_cove_page_test.dart`](../test/today_and_cove_page_test.dart) and regenerated all 6 `today_screen.{cover,phone,wide}.{dark,light}.png` goldens.
- **Task 3.10g — `composeDayLetter()` Pure Rule-Based Day Letter Composer & `CoveLetter` Widget (`Oct 25, 2026`)**:
  - *Outcome*: Built the pure, deterministic [`composeDayLetter(DayLetterInput)`](../lib/features/today/letter/compose_day_letter.dart) composer (`LetterSpan`, `LetterSpanStyle`, `LetterTarget`, `LetterTargetKind`) and [`CoveLetter`](../lib/features/today/letter/cove_letter.dart) widget in `lib/features/today/letter/` to [`design/specs/11-day-letter.md`](../design/specs/11-day-letter.md), producing up to six sentences in fixed order (`The day`, `The calendar`, `Habits`, `Money`, `Commitments`, `Lists`) with verbatim record names, numbers 1–9 as words and 10+ as digits, disambiguated times with relative part of the day (`"at seven this evening"` / `"at 7:30 this morning"`, `<12:00` morning, `12:00–16:59` afternoon, `17:00–20:59` evening, `21:00+` tonight), required `currencySymbol` formatted via `formatCoveCurrency()`, top-two expense joining with `"and"` only when neither title contains `—`, `–`, `,`, or `;` (otherwise naming only the larger item), `DayLetterCommitment.dueDate` filtered against the injected clock for `"today"` vs `"tomorrow"` (and `"₹X goes out today and ₹Y tomorrow."` when both exist), tappable `accent.fill`-underlined links (`CoveType.letter`), and `Libre Bodoni Italic` (`text.secondary` for lists, `text.tertiary` for the first-run empty-home prompt).
  - *Under the Hood*:
    - Added [`test/day_letter_test.dart`](../test/day_letter_test.dart) (19 unit tests covering all spec fixtures, time day-part disambiguation, today/tomorrow commitment date resolution, required `currencySymbol`, compound-title punctuation guard on two-item money dominance, determinism, target presence on every link span, lakh Indian grouping, verbatim odd-casing/punctuation preservation, and zero `DateTime.now` references in `lib/features/today/letter/`) and [`test/golden/day_letter_golden_test.dart`](../test/golden/day_letter_golden_test.dart) (6 `day_letter.{cover,phone,wide}.{dark,light}.png` goldens across three fixtures).
- **Task 3.10f — `CoveCarousel` Horizontal Slip Carousel (`Oct 25, 2026`)**:
  - *Outcome*: Built [`CoveCarousel`](../lib/core/widgets/cove_carousel.dart) in `lib/core/widgets/` to [`design/specs/12-carousel.md`](../design/specs/12-carousel.md), rendering a single item at full content width (`100%` inside `CoveSpace.gutter` horizontal padding) with no pager, and multiple items at `82%` of content width (`CoveCarousel.kItemWidthRatio`) aligned to `CoveSpace.gutter` (`20dp`) with a `CoveSpace.md` (`12dp`) gap so the next item peeks, snapping to item while respecting `CoveMotion.q` and Reduce Motion (`MediaQuery.disableAnimationsOf`), non-interactive pager dots below (`CoveSpace.md` gap, `6×6dp` inactive dots in `line.strong`, `20×6dp` active dot in `accent.fill` with `CoveRadius.pill`, `CoveSpace.sm` between), and assistive-tech position announcements (`"2 of 3"`) with `onIncrease` / `onDecrease` navigation.
  - *Under the Hood*:
    - Added [`test/golden/carousel_golden_test.dart`](../test/golden/carousel_golden_test.dart) and generated 6 `carousel.{cover,phone,wide}.{dark,light}.png` goldens showcasing 1, 2, and 5 items across all viewport widths and brightnesses.
- **Task 3.10e — `CoveVoucher` Commitment & Punched EMI Slip (`Oct 25, 2026`)**:
  - *Outcome*: Built [`CoveVoucher`](../lib/core/widgets/slips/cove_voucher.dart) (`CoveVoucherState { due, paid }`) on [`CoveSlip`](../lib/core/widgets/slips/cove_slip.dart) to [`design/specs/10-paper-objects.md`](../design/specs/10-paper-objects.md), featuring the `1dp` perforated rail `12dp` in from the left edge, `COVE · EVERY MONTH` caps line, title in `CoveType.slipTitle`, amount in `CoveType.slipFigure` with `"a month"` in `CoveType.readout`, `64dp` `1dp` dashed `accent.fill` due circle holding only the day (`CoveType.slipTitle`) and month (`CoveType.capsSlip`) (omitting `"DUE"` per the `11sp` floor), `paid` state with rotated `−8°` outlined `PAID` stamp in `status.good` and faded rule-colour circle, punched EMI variant (`totalInstallments` dots with `paidInstallments` filled in `accent.fill` and remaining outlined), and WCAG 4.1.2 semantics (`"Voucher, AC instalment, ₹3,974, due 22 October, paid"` and `"EMI, 12 of 48 paid"`).
  - *Under the Hood*:
    - Added [`test/golden/voucher_golden_test.dart`](../test/golden/voucher_golden_test.dart) and generated 12 goldens (`voucher` and `voucher_paper` across `cover`, `phone`, `wide` and both brightnesses) covering `due`, `paid`, and EMI punched states.
- **Task 3.10d — `CoveNote` Ruled List Slip & `CoveHabitCard` Streak Slip (`Oct 25, 2026`)**:
  - *Outcome*: Built [`CoveNote`](../lib/core/widgets/slips/cove_note.dart) (`CoveNoteItem`) and [`CoveHabitCard`](../lib/core/widgets/slips/cove_habit_card.dart) on [`CoveSlip`](../lib/core/widgets/slips/cove_slip.dart) to [`design/specs/10-paper-objects.md`](../design/specs/10-paper-objects.md):
    - `CoveNote`: `4dp` top corners and `CoveRadius.card` (`20dp`) bottom corners, full-width ruled lines every `32dp` in `palette.rule`, `CoveCheckbox` + `CoveType.slipTitle` item titles with `addedBy` in tertiary text, and done items struck through in `palette.secondary`.
    - `CoveHabitCard`: `COVE · HABIT` caps line, `CoveType.slipTitle` title, cadence line, top-right `CoveCheckbox`, `1dp` `4/4` dashed rule, 7×3 21-day streak grid (`10dp` cells, `CoveSpace.xs` gap, `2dp` radius; done in `accent.fill`, missed as `1dp` outline in `slip.inkMark` on ink / `paper.ink3` on paper, today ringed in `1.5dp` `accent.fill`), and primary run count in `CoveType.slipFigure` + `DAYS RUNNING` in `CoveType.capsSlip`, with WCAG 4.1.2 semantics (`"Habit, Morning walk, done today, 23 days running"`).
  - *Under the Hood*:
    - Added [`test/golden/note_habit_card_golden_test.dart`](../test/golden/note_habit_card_golden_test.dart) and generated 18 goldens (`note`, `habit_card`, `habit_card_paper` across `cover`, `phone`, `wide` and both brightnesses).
- **Task 3.10c — `CoveReceipt` Torn-Edge Spending Slip (`Oct 25, 2026`)**:
  - *Outcome*: Built [`CoveReceipt`](../lib/core/widgets/slips/cove_receipt.dart) (`CoveReceiptItem`, `CoveReceiptSplit`, `CoveBarcodeBar`) on [`CoveSlip`](../lib/core/widgets/slips/cove_slip.dart) to [`design/specs/10-paper-objects.md`](../design/specs/10-paper-objects.md), featuring `8dp × 6dp` torn zigzag top and bottom edges with `0dp` corner radius, centred header (`CoveType.capsSlip` + `CoveType.slipTitle` + `CoveType.capsSlip`), `1dp` `4/4` dashed rules, purchase rows with `CoveAvatar.inline`, `8dp` hover plate radius, and right-aligned `CoveType.readout` amounts, `TOTAL` row with `CoveType.slipFigure`, `4dp` pill-radius split bar with both names and amounts written beside it (WCAG 1.4.1), deterministic `24dp` barcode strip derived from `recordId`, and WCAG 4.1.2 semantics (`"Receipt, Wednesday, total ₹5,631, 3 items"`).
  - *Under the Hood*:
    - Added [`test/golden/receipt_golden_test.dart`](../test/golden/receipt_golden_test.dart) covering 1-item and 3-item receipts in `paper` and `ink` across both brightnesses and `cover` (`320dp`) width, and verified two consecutive golden runs produce byte-identical SHA-256 outputs.
- **Task 3.10b — `CoveSlip` Shared Frame & `CoveTicket` Event Slip (`Oct 25, 2026`)**:
  - *Outcome*: Built [`CoveSlip`](../lib/core/widgets/slips/cove_slip.dart) (`CoveSlipVariant { paper, ink }`, `CoveSlipPalette`, `CoveSlipScope`) and [`CoveTicket`](../lib/core/widgets/slips/cove_ticket.dart) in `lib/core/widgets/slips/` to the contract in [`design/specs/10-paper-objects.md`](../design/specs/10-paper-objects.md), with caller-selected `paper` / `ink` variants (never inferred from ambient brightness), `168°` 3-stop gradient fills (`46%` middle stop), `slip.inkText3` tertiary and `slip.inkAlertText` alert text on ink, light-mode-only `paper.edge` hairline + `elevationPaper` on paper, `112dp` right stub with `16dp` top/bottom semicircle perforation notches and `1dp` `4/4` dashed perforation line, `2dp` left accent spine, and full WCAG 4.1.2 semantics.
  - *Under the Hood*:
    - Added [`test/golden/ticket_golden_test.dart`](../test/golden/ticket_golden_test.dart) and generated all 6 `ticket.{cover,phone,wide}.{dark,light}.png` goldens covering `paper` and `ink` variants across both brightnesses.
- **Task 3.10a — Paper Object & Letter Tokens, `LibreBodoni-Italic` Font & Ink Contrast Gate (`Oct 25, 2026`)**:
  - *Outcome*: Registered `assets/fonts/LibreBodoni-Italic.ttf` (`weight: 400`, `style: italic`) in [`pubspec.yaml`](../pubspec.yaml) and [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart), added the flat `slip` colour group (`inkFrom`, `inkVia`, `inkTo`, `inkText3`, `inkAlertText`, `inkMark`) and four display typography roles (`greeting`, `letter`, `slipTitle`, `slipFigure`) to [`design/tokens.json`](../design/tokens.json), regenerated [`lib/core/theme/cove_tokens.dart`](../lib/core/theme/cove_tokens.dart), and extended [`tool/check_contrast.py`](../tool/check_contrast.py) to verify all text (`>= 4.5:1`) and mark (`>= 3.0:1`) pairs across all three ink gradient stops.
  - *Under the Hood*:
    - Added `"slip"` to the colour groups list in [`tool/gen_tokens.dart`](../tool/gen_tokens.dart) (`45 colours x 2 modes`).
    - Verified worst ink text pair is `slip.inkAlertText` (`#DC988A`) on `slip.inkFrom` (`#1A4541`) at `4.52:1` (against `4.5:1` floor) and worst ink mark pair is `slip.inkMark` (`#909993`) on `slip.inkFrom` (`#1A4541`) at `3.63:1` (against `3.0:1` floor).
- **Task 3.3 — "The Year" (`CommitmentsHelicopterScreen`) Converted to Cove Primitives (`Oct 24, 2026`)**:
  - *Outcome*: Converted [`CommitmentsHelicopterScreen`](../lib/features/subscriptions/commitments_helicopter_screen.dart) to the v2 "The Year" layout (`design/screens/the-year.md` & `design/screens/the-year.png`), featuring `CovePageHeader` (back `CoveRoundButton`, the selected year number as the title, and two ghost `CoveRoundButton` year chevrons in `actions`), the `"CHANGE ON THE MONTH"` diverging month-over-month chart with the current month marked by a gold pill callout and gold axis initial (`J F M A M J J A S O N D`), the screen-local `_MonthLedgerTable` (`MONTH · +/- · <Person A> · <Person B> · TOTAL`) with zero row fill, radius, or side stroke, current month marked solely by a gold month name (`accent.text`) and warmed hairlines above and below, `money.more` / `money.less` signed deltas, and the `YEAR` footer row where the prior-year comparison renders as `—` in `text.tertiary` with no invented calculation.
  - *Under the Hood*:
    - Deleted `lib/features/subscriptions/commitments_helicopter_screen.dart 10` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (56 files / 552 literals remaining) with zero raw style literals or `Brightness` branches.
    - Wrapped page content in [`CoveMaxWidth`](../lib/core/widgets/cove_max_width.dart) with `CoveSpace.barClearance + MediaQuery.paddingOf(context).bottom` scroll clearance and regenerated all 6 `commitments_helicopter_screen.{cover,phone,wide}.{dark,light}.png` goldens.
- **Task 3.9 — "Expenses" (`ExpensesScreen`) Converted to Cove Primitives (`Oct 24, 2026`)**:
  - *Outcome*: Converted [`ExpensesScreen`](../lib/features/expenses/expenses_screen.dart) to the v2 "Expenses" layout (`design/screens/expenses.md` & `design/screens/expenses.png`), featuring `CovePageHeader` ("Expenses", month + total as the baseline readout, and gold `+` `CoveRoundButton`), the hero card (month total in `CoveType.heroFigure`, Expenditure/Transfers segmented pill, pace comparison line against last month using `money.more` / `money.less` always with a word beside it, monthly budget progress bar with a `TODAY` marker, and household `CovePerson.a` / `CovePerson.b` split bar), the `"EVERY DAY THIS MONTH"` bar chart annotated directly on the graph (`"N DAYS STILL TO COME"` / `"drawn at the pace you are keeping"` and `"₹X A DAY"` above the horizontal pace line), four `CoveMetricCard` pace tiles in `CoveMetricGrid` (`Pace now`, `On this pace`, `Budget runs out`, `Per day from here`), `"WHERE IT WENT"` category breakdown using `category.*` tokens and named in text (tapping a category isolates it in the bar and purchase rows below; long-pressing opens `CategoryDetailSheet`), and `"EVERY PURCHASE"` with an independent ledger month switcher (`CoveRoundButton.stepper`) and date-grouped `CoveRow` list (`CoveAvatar.row`, category/payment subtitle, amount in `CoveType.cardFigure` via `formatCoveAmount()`, and `CoveSyncTick`).
  - *Under the Hood*:
    - Deleted `lib/features/expenses/expenses_screen.dart 43` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (57 files / 562 literals remaining) with zero raw style literals or `Brightness` branches.
    - Removed `'expenses_screen.cover'` from `_kKnownLegacyOverflows` in [`test/golden/screens_golden_test.dart`](../test/golden/screens_golden_test.dart), updated [`test/expenses_test.dart`](../test/expenses_test.dart), and regenerated all 6 `expenses_screen.{cover,phone,wide}.{dark,light}.png` goldens.
- **Task 3.8 — "Commitments" (`SubscriptionsScreen`) Converted to Cove Primitives (`Oct 23, 2026`)**:
  - *Outcome*: Converted [`SubscriptionsScreen`](../lib/features/subscriptions/subscriptions_screen.dart) to the v2 "Commitments" layout (`design/screens/commitments.md` & `design/screens/commitments.png`), featuring `CovePageHeader` ("Commitments" + gold `+` `CoveRoundButton`), the Monthly/Annually total card with concentric top-right arc rings, overlapping `CoveAvatar.inline` household attribution filter pill, proportional `EMIs` / `Subs` / `Savings` split bar, cycle combination toggle, and shared/private commitment counts, `"THE RUNWAY"` header with ghost `CoveRoundButton` links to `EmiTrackerScreen` (`EMI Outstanding`) and `CommitmentsHelicopterScreen` (`Helicopter View`) plus the stepped runway mini chart (`TODAY` pill + `'27` / `'28` / `'29` year markers), `All` / `Subs` / `EMIs` / `Savings` segment filter pills, and date-grouped `CoveRow` blocks with `CoveAvatar.row` payer avatars, kind tags (`SUB`, `EMI`, `SIP`, `RENT`, `SERVICE`, `HOME`, `INSURANCE`, `PETS`), installment/split subtitles, `via <financedThrough>` source tags, `cv.statusAlert` due-soon/overdue dot + word markers (WCAG 1.4.1), and Libre Bodoni amounts via `formatCoveAmount()`.
  - *Under the Hood*:
    - Deleted `lib/features/subscriptions/subscriptions_screen.dart 28` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (58 files / 605 literals remaining) with zero raw style literals or `Brightness` branches.
    - Removed `'subscriptions_screen.phone'` and `'subscriptions_screen.cover'` from `_kKnownLegacyOverflows` in [`test/golden/screens_golden_test.dart`](../test/golden/screens_golden_test.dart), updated [`test/subscriptions_test.dart`](../test/subscriptions_test.dart), and regenerated all 6 `subscriptions_screen.{cover,phone,wide}.{dark,light}.png` goldens.
- **Task 3.7 — "EMIs" (`EmiTrackerScreen`) Converted to Cove Primitives (`Oct 23, 2026`)**:
  - *Outcome*: Converted [`EmiTrackerScreen`](../lib/features/subscriptions/emi_tracker_screen.dart) to the v2 "EMIs" layout (`design/screens/emis.md` & `design/screens/emis.png`), featuring `CovePageHeader` (back `CoveRoundButton`, "EMIs", and the `28 dp` `CoveHeaderPill` `"What if…"`), the three summary cards (when it all closes hero card in `CoveType.heroFigure` with mini-staircase silhouette, `EACH MONTH` card with proportional who-split bar across `CovePerson.a` / `CovePerson.both` / `CovePerson.b`, and `LEFT TO PAY` card with paid-% bar, collapsing to a single column below `CoveSize.compactThreshold`), the interactive `"WHEN IT GETS LIGHTER"` · `"tap the steps"` staircase graph with tappable step callouts, sort pills (`By who`, `Ends first`, `Biggest`), and payer-grouped ledger cards (`CoveAvatar.inline` + uppercase payer & count + group `/mo` total) with punched installment vouchers (`paidInstallments` punched in `accent.fill`, remaining unpunched in `line.strong`), plus long-press and `"What if…"` pill selection (WCAG 2.5.1) that recomputes the what-if tray and free-by date without any `"Save as a plan"` action.
  - *Under the Hood*:
    - Deleted `lib/features/subscriptions/emi_tracker_screen.dart 40` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (59 files / 633 literals remaining) with zero raw style literals or `Brightness` branches, formatting all amounts with `formatCoveAmount()`.
    - Wrapped page content in [`CoveMaxWidth`](../lib/core/widgets/cove_max_width.dart) with `CoveSpace.barClearance + MediaQuery.paddingOf(context).bottom` scroll clearance, updated [`test/emi_tracker_test.dart`](../test/emi_tracker_test.dart), and regenerated all 6 `emi_tracker_screen.{cover,phone,wide}.{dark,light}.png` goldens.
- **Task 3.6 — "Calendar" (`CalendarScreen` + `CalendarAgendaView`) Converted to Cove Primitives (`Oct 23, 2026`)**:
  - *Outcome*: Converted [`CalendarScreen`](../lib/features/calendar/calendar_screen.dart) and [`CalendarAgendaView`](../lib/features/calendar/views/calendar_agenda_view.dart) to the v2 "Calendar" Day-only layout (`design/screens/calendar.md` & `design/screens/calendar.png`), featuring `CovePageHeader` (month name + year readout, `CoveRoundButton.stepper` chevrons for month switching, and gold `+` `CoveRoundButton`), the horizontally scrollable selected-month date strip with content pips, the selected day line (`"Wednesday, Oct 21 · today"`), `CoveMetricGrid` (`SPENT`, `EVENTS`, `HABITS`, `THE LIST`), four sections in fixed order (`EVENTS` → `HABITS` → `SPENT` → `THE LIST`, showing quiet empty lines when empty, with undated tasks appearing on the day added and when ticked also on the day struck), and the prominent Commitments due card at the foot.
  - *Under the Hood*:
    - Deleted `lib/features/calendar/calendar_screen.dart 4` and `lib/features/calendar/views/calendar_agenda_view.dart 33` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (60 files / 673 literals remaining) with zero raw style literals or `Brightness` branches.
    - Removed `'calendar_screen.cover'` from `_kKnownLegacyOverflows` in [`test/golden/screens_golden_test.dart`](../test/golden/screens_golden_test.dart), updated [`test/calendar_test.dart`](../test/calendar_test.dart), and regenerated all 6 `calendar_screen.{cover,phone,wide}.{dark,light}.png` goldens.
- **Task 3.5 — "Settings" (`ProfileScreen`) Converted to Cove Primitives (`Oct 23, 2026`)**:
  - *Outcome*: Converted [`ProfileScreen`](../lib/features/profile/profile_screen.dart) to the v2 "Settings" layout (`design/screens/settings.md` & `design/screens/settings.png`), featuring `CovePageHeader` (back `CoveRoundButton` + "Settings"), the single-person user profile card (`CoveAvatar.profile` for the signed-in user alone, never `CovePerson.both`), six `CoveSectionLabel.page` + `CoveRow` sections (`Preferences` with 3-way Light/Dark/System segmented control, `Currency`, and `Monthly budget` via `formatCoveCurrency()`; `Notifications` with 5 module toggles and `Check-in reminders`; `Backup & restore` reflecting live `DriveBackupState` with `Google Drive`, `Recovery Passphrase`, `Last Backup`, `Backup window` via `showTimePicker` for WCAG 2.5.7 keyboard input, `Restore`, and `Back Up Now`; `Household` with the couple row linking to `HomeSettingsScreen` (`Our home`) and `Pair a new phone` QR sheet via `CoveSheet`; `About Cove` with `What's new`, `Roadmap & wishlist`, and `How Cove keeps this private`; and `Account` with a single foot row opening a `CoveSheet` containing `Sign Out`, `Leave Home`, and `Delete Local Data` with explicit consequence sub-lines), and the `Cove $kCoveCurrentAppVersion` secondary-text foot label.
  - *Under the Hood*:
    - Deleted `lib/features/profile/profile_screen.dart 14` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (62 files / 710 literals remaining) with zero raw style literals or `Brightness` branches.
    - Wrapped page content in [`CoveMaxWidth`](../lib/core/widgets/cove_max_width.dart) with `CoveSpace.barClearance + MediaQuery.paddingOf(context).bottom` scroll clearance, updated [`test/profile_settings_test.dart`](../test/profile_settings_test.dart) and [`test/notifications_test.dart`](../test/notifications_test.dart), and regenerated all 6 `profile_screen.{cover,phone,wide}.{dark,light}.png` goldens.
- **Task 3.4 — "Activity" (`ActivityScreen`) Converted to Cove Primitives (`Oct 23, 2026`)**:
  - *Outcome*: Converted [`ActivityScreen`](../lib/features/activity/activity_screen.dart) to the v2 "Activity" layout (`design/screens/activity.md` & `design/screens/activity.png`), featuring `CovePageHeader` (back `CoveRoundButton`, "Activity" title, unread count readout, and `CoveHeaderPill` "Mark all read" action), the top Digest card (day stepper using `CoveRoundButton.stepper` and one paragraph per person with `CoveAvatar.inline` for `CovePerson.a` and `CovePerson.b`), and the day-grouped feed with left-aligned date + middle hairline + right-aligned `TODAY`/`YESTERDAY`/weekday headers, `CoveAvatar.row` unread gold rings + full-strength type vs read `text.secondary` type, batch-collapsed list additions (`"N things, in one go"`), and kind-specific artifacts (list item pills, Libre Bodoni ledger amounts via `formatCoveAmount()`, habit double-ring check-ins, and calendar event tickets).
  - *Under the Hood*:
    - Deleted `lib/features/activity/activity_screen.dart 12` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (63 files / 724 literals remaining) with zero raw style literals or `Brightness` branches.
    - Wrapped page content in [`CoveMaxWidth`](../lib/core/widgets/cove_max_width.dart) with `CoveSpace.barClearance + MediaQuery.paddingOf(context).bottom` scroll clearance and regenerated all 6 `activity_screen.{cover,phone,wide}.{dark,light}.png` goldens.
- **Task 3.2 — "Routines" (`RoutineScreen`) Converted to Cove Primitives (`Oct 23, 2026`)**:
  - *Outcome*: Converted [`RoutineScreen`](../lib/features/routines/routine_screen.dart) to the v2 "Routines" layout (`design/screens/routines.md` & `design/screens/routines.png`), featuring `CovePageHeader` ("Routines" + gold `+` `CoveRoundButton`), pill-shaped routine filter chips with event counts, the two-person household legend (`CoveAvatar.inline` for `CovePerson.a` and `CovePerson.b` keyed strictly to `home.createdBy`), and the rounded 24-hour day canvas with a dusk-to-dawn sky gradient (`CoveTokens`-derived), real-time routine event bands, and a `NOW` indicator.
  - *Under the Hood*:
    - Deleted `lib/features/routines/routine_screen.dart 8` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (64 files / 736 literals remaining) with zero raw style literals or `Brightness` branches.
    - Wrapped page content in [`CoveMaxWidth`](../lib/core/widgets/cove_max_width.dart) with `CoveSpace.barClearance + MediaQuery.paddingOf(context).bottom` scroll clearance and regenerated all 6 `routine_screen.{cover,phone,wide}.{dark,light}.png` goldens.
- **Task 3.1 — "Our home" (`HomeSettingsScreen`) Converted to Cove Primitives (`Oct 23, 2026`)**:
  - *Outcome*: Converted [`HomeSettingsScreen`](../lib/features/home/home_settings_screen.dart) to the v2 "Our home" Front Door layout (`design/screens/our-home.md` & `design/screens/our-home.png`), featuring `CovePageHeader` (back + edit home actions), the double-line arch illustration with a scrolling radial glow, creator & joiner names (`CoveType.title` + italic `CoveType.heroFigure` `&`), Together / In Cove dates, four Almanac `CoveMetricCard` tiles in `CoveMetricGrid` (`Commitments`, `Budget` formatted via `formatCoveCurrency`, `Lists`, `Habits`), `Who lives here` profile avatars (`CoveAvatar.profile` for `CovePerson.a` and `CovePerson.b` without role captions), `This home` `CoveRow` list (`Name`, `Where`, `Our dates`, `Currency`, `Keys` invite QR sheet via `CoveSheet`, and `Leave Home`), and the encryption reassurance footer.
  - *Under the Hood*:
    - Removed `lib/features/home/home_settings_screen.dart 4` from [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (65 files / 744 literals remaining) with zero raw style literals or `Brightness` branches.
    - Wrapped page content in [`CoveMaxWidth`](../lib/core/widgets/cove_max_width.dart) with `CoveSpace.barClearance + MediaQuery.paddingOf(context).bottom` scroll clearance and regenerated all 6 `home_settings_screen.{cover,phone,wide}.{dark,light}.png` goldens.

### Fixed
- **`CovePageHeader` Typed Multi-Action Support (`actions: List<CoveRoundButton>`, `<= 3`) & Full-Size Calendar Chevrons (`Oct 24, 2026`)**:
  - *Outcome*: Replaced `trailingAccessory` (`Widget?`) and single `action` (`CoveRoundButton?`) on [`CovePageHeader`](../lib/core/widgets/cove_page_header.dart) with `final List<CoveRoundButton> actions` (default `const []`, asserting `actions.length <= 3` and `!b.isStepper`), laid out right-aligned with `CoveSpace.sm` (`8 dp`) between drawn `40 dp` circles and full `48 dp` hit targets (`CoveSize.hit`), while allowing `actions`/`leading` and `trailingPill` to coexist. Upgraded Calendar's month-switching chevrons in [`CalendarAgendaView`](../lib/features/calendar/views/calendar_agenda_view.dart) from `24 dp` inline steppers to full `40 dp` / `48 dp`-hit ghost `CoveRoundButton`s, and migrated Commitments' empty-state header in [`SubscriptionsScreen`](../lib/features/subscriptions/subscriptions_screen.dart) onto `actions`.
  - *Under the Hood*:
    - Updated [`design/specs/01-page-header.md`](../design/specs/01-page-header.md) to codify "one button size, up to three actions", `actions`/`trailingPill` coexistence, and full `CoveRoundButton` header chevrons.
    - Updated [`test/golden/page_header_golden_test.dart`](../test/golden/page_header_golden_test.dart) with a 3-action Calendar showcase and `320 dp` measurement assertions, and regenerated the `page_header`, `calendar_screen`, and `subscriptions_screen` goldens.
- **`CoveMetricGrid` Single-Column Collapse Below `CoveSize.compactThreshold` (`360 dp`) (`Oct 23, 2026`)**:
  - *Outcome*: Promoted the `360 dp` compact viewport threshold to [`CoveSize.compactThreshold`](../lib/core/theme/cove_tokens.dart) in [`design/tokens.json`](../design/tokens.json) (shared by [`CoveFloatingBar`](../lib/core/widgets/cove_floating_bar.dart) and [`CoveMetricGrid`](../lib/core/widgets/cove_metric_card.dart)) so [`CoveMetricGrid`](../lib/core/widgets/cove_metric_card.dart) renders as a single column below `360 dp`, expanding inner card width at `320 dp` (`cover`) from `108 dp` to `254 dp` and preventing `28 sp` Libre Bodoni figures like `₹85,000` (`110.7 dp`) or `"1 overdue"` (`117.1 dp`) from wrapping mid-value.
  - *Under the Hood*:
    - Added `compactThreshold` (`360 dp`) under `size` in [`design/tokens.json`](../design/tokens.json) and regenerated [`lib/core/theme/cove_tokens.dart`](../lib/core/theme/cove_tokens.dart) via `dart run tool/gen_tokens.dart`.
    - Updated [`CoveMetricGrid`](../lib/core/widgets/cove_metric_card.dart), [`CoveFloatingBar`](../lib/core/widgets/cove_floating_bar.dart), [`design/specs/06-metric-card.md`](../design/specs/06-metric-card.md), and [`design/specs/09-floating-bar.md`](../design/specs/09-floating-bar.md), and regenerated the `metric_card`, `floating_bar_*`, and `home_settings_screen` goldens.
- **`CoveFloatingBar` `CoveType.barLabel` Role, `< 360dp` Icon-Only Threshold & Unconstrained Label-Fit Audit (`Oct 23, 2026`)**:
  - *Outcome*: Added `CoveType.barLabel` (`11 sp` / `w600` / `lineHeight 14` / `letterSpacing 0`, `PlusJakartaSans`) to [`design/tokens.json`](../design/tokens.json) so mixed-case bar labels no longer inherit `CoveType.capsCard`'s `1.54 dp` uppercase tracking, added a `360 dp` viewport width threshold below which [`CoveFloatingBar`](../lib/core/widgets/cove_floating_bar.dart) renders icons only across all states, updated [`design/specs/09-floating-bar.md`](../design/specs/09-floating-bar.md) with the exact `320 dp` seat arithmetic (`47.3 dp` seat / `39.3 dp` label), and rewrote the label-fit audit in [`test/golden/floating_bar_golden_test.dart`](../test/golden/floating_bar_golden_test.dart) to assert unconstrained text width against available width across `320`, `390`, `411`, and `840 dp`.
  - *Under the Hood*:
    - Added `barLabel` under `type` in [`design/tokens.json`](../design/tokens.json) and regenerated [`lib/core/theme/cove_tokens.dart`](../lib/core/theme/cove_tokens.dart) via `dart run tool/gen_tokens.dart`.
    - Updated [`lib/core/widgets/cove_floating_bar.dart`](../lib/core/widgets/cove_floating_bar.dart), [`design/specs/09-floating-bar.md`](../design/specs/09-floating-bar.md), [`test/golden/floating_bar_golden_test.dart`](../test/golden/floating_bar_golden_test.dart), and regenerated the 30 `floating_bar_{rest,money,tasks,calendar,more}.{cover,phone,wide}.{dark,light}.png` goldens.
- **`CoveRoundButton` Gold Variant Pressed-State Darkening (`Oct 22, 2026`)**:
  - *Outcome*: Corrected the gold variant's press overlay in [`design/specs/04-round-button.md`](../design/specs/04-round-button.md) and [`lib/core/widgets/cove_round_button.dart`](../lib/core/widgets/cove_round_button.dart) so pressing the primary gold button visibly darkens the circle in both dark (`RGB(216, 185, 140)` → `RGB(190, 163, 123)`) and light (`RGB(169, 124, 79)` → `RGB(149, 109, 70)`) modes instead of laying `accent.wash` over `accent.fill`.
  - *Under the Hood*:
    - Updated [`design/specs/04-round-button.md`](../design/specs/04-round-button.md) to specify `accent.wash` for the ghost variant and `Colors.black` at `12%` alpha (`0.12`) over `accent.fill` for the gold variant.
    - Updated `_CoveRoundButtonState` in [`lib/core/widgets/cove_round_button.dart`](../lib/core/widgets/cove_round_button.dart) and regenerated the 6 `round_button.{cover,phone,wide}.{dark,light}.png` goldens.
- **Golden Harness `AppShell` 540dp Constraint & Explicit Overflow Allow-List (`Oct 22, 2026`)**:
  - *Outcome*: Screen goldens now wrap each screen in the same centred `540 dp` constraint that `AppShell` applies on device, and replaced the blanket `RenderFlex` overflow suppression with an explicit `<screen>.<width>` allow-list of the 5 known pre-revamp overflow pairs so any new overflow fails immediately.
  - *Under the Hood*:
    - Added optional `wrap` and `allowedOverflows` parameters (plus `wrapInAppShellConstraint`) to `goldenMatrix` in [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart).
    - Replaced `_withLegacyCoverOverflowIgnored` in [`test/golden/screens_golden_test.dart`](../test/golden/screens_golden_test.dart) with `_kKnownLegacyOverflows` (`today_screen.cover`, `calendar_screen.cover`, `expenses_screen.cover`, `subscriptions_screen.phone`, `subscriptions_screen.cover`) and regenerated the 28 `.wide.` goldens in `test/golden/goldens/`.

### Added
- **`CoveFloatingBar` Primitive, 5-State Golden Suite & Empirical Label-Fit Audit (`Oct 23, 2026`)**:
  - *Outcome*: Built [`CoveFloatingBar`](../lib/core/widgets/cove_floating_bar.dart) as a stateless primitive driven by an explicit [`CoveFloatingBarState`](../lib/core/widgets/cove_floating_bar.dart) across all 5 states (`rest`, `money`, `tasks`, `calendar`, and `more` overflow open), with `56 dp` bar height, `CoveRadius.pill` (`999 dp`) radius, `surface.card` at `92%` alpha + backdrop blur and `elevationBar` shadow, `CoveSpace.gutter` (`20 dp`) side margin, `CoveSpace.md` (`12 dp`) + `MediaQuery.padding.bottom` bottom margin, detached `Home` pill, `56 dp` centre/right `[+]` orb (`accent.fill` / `text.onAccent`), and the `More` overflow popover (`EMIs`, `Year`, `Savings`).
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_floating_bar.dart`](../lib/core/widgets/cove_floating_bar.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) reading `context.cv`, `CoveSize`, `CoveSpace`, `CoveRadius`, `CoveType`, and `CoveMotion.q(context)` with zero raw style literals or `Brightness` branches.
    - Added [`test/golden/floating_bar_golden_test.dart`](../test/golden/floating_bar_golden_test.dart) generating all 30 goldens across `floating_bar_{rest,money,tasks,calendar,more}.{cover,phone,wide}.{dark,light}.png` plus an empirical label-fit audit across `320 dp`, `390 dp`, `411 dp`, and `840 dp` (`420 dp` `maxContent`).
- **`CoveToast` & `CoveToastHost` Primitives and Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Built [`CoveToast`](../lib/core/widgets/cove_toast.dart) and [`CoveToastHost`](../lib/core/widgets/cove_toast.dart) anchored at `inset + CovePageHeader.kMinHeight + CoveSpace.md` (`inset + 56 + 12 dp`) below the page header, with `CoveSpace.sm` (`8 dp`) vertical and `CoveSpace.gutter` (`20 dp`) horizontal padding, `CoveRadius.pill` radius, `surface.row` fill, `1 dp` `accent.fill` border, `CoveType.readout` (`text.primary`) message, a real `Undo` button in `accent.text` with a `48 dp` (`CoveSize.hit`) tap target that does not grow the drawn pill height, single-toast replacement (never stacking), and WCAG 2.2.1 timing adjustment (pausing on focus and extending when a screen reader is active).
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_toast.dart`](../lib/core/widgets/cove_toast.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) reading `context.cv`, `CoveSpace`, `CoveRadius`, `CoveSize`, and `CoveType` with zero raw style literals or `Brightness` branches.
    - Added [`test/golden/toast_golden_test.dart`](../test/golden/toast_golden_test.dart) and generated all 6 `toast.{cover,phone,wide}.{dark,light}.png` goldens plus device-position, `48 dp` hit-target, single-toast replacement, and WCAG 2.2.1 timing assertions.
- **`CoveSheet` & `CoveSheetBackdrop` Primitives and Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Built [`CoveSheet`](../lib/core/widgets/cove_sheet.dart) and [`CoveSheetBackdrop`](../lib/core/widgets/cove_sheet.dart) with `32 dp` (`CoveRadius.sheet`) top corners, `40 dp` (`CoveRadius.device`) bottom corners where the sheet meets the screen edge, `surface.sheet` fill, `CoveSpace.gutter` horizontal / `CoveSpace.md` top / `CoveSpace.lg + MediaQuery.padding.bottom` bottom padding, a centred `36 × 4 dp` `line.strong` grab handle (`CoveSpace.md` below), `surface.scrim` backdrop, `CoveMotion.s(context)` (`320 ms` / `0 ms` with Reduce Motion) + `CoveMotion.easing` transition, stacked sheet-over-sheet support with identical radii, and scrim-tap / drag dismissal gated by `isMidCommit`.
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_sheet.dart`](../lib/core/widgets/cove_sheet.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) reading `context.cv`, `CoveRadius`, `CoveSpace`, `CoveSize`, `CoveType`, and `CoveMotion.s(context)` with zero raw style literals or `Brightness` branches.
    - Added [`test/golden/sheet_golden_test.dart`](../test/golden/sheet_golden_test.dart) and generated all 6 `sheet.{cover,phone,wide}.{dark,light}.png` goldens plus grab-handle, stacked-radius, and `isMidCommit` dismissal-lock assertions.
- **`CoveMetricCard` & `CoveMetricGrid` Primitives and Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Built [`CoveMetricCard`](../lib/core/widgets/cove_metric_card.dart) and [`CoveMetricGrid`](../lib/core/widgets/cove_metric_card.dart) with a flat `surface.card` fill, `20 dp` (`CoveRadius.card`) radius, `1 dp` `line.hairline` border, `12 dp` (`CoveSpace.md`) all-round padding, `CoveType.capsCard` label (`text.tertiary`), Libre Bodoni `CoveType.cardFigure` value (`accent.tint` by default plus semantic tones), required `CoveType.rowSub` context sub-line (`text.tertiary`), and a two-per-row grid (`CoveSpace.md` gap) that constrains to `CoveSize.maxContent` (`420 dp`) and centres on wider viewports.
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_metric_card.dart`](../lib/core/widgets/cove_metric_card.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) reading `context.cv`, `CoveRadius`, `CoveSpace`, `CoveSize`, and `CoveType` with zero raw style literals or `Brightness` branches.
    - Added [`test/golden/metric_card_golden_test.dart`](../test/golden/metric_card_golden_test.dart) and generated all 6 `metric_card.{cover,phone,wide}.{dark,light}.png` goldens plus grid-gap, equal-height, and wide-centring assertions.
- **`CoveRow` Primitive & Multi-State Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Built [`CoveRow`](../lib/core/widgets/cove_row.dart) with a `52 dp` height (`CoveSize.row`, vertical padding derived as `(row - content) / 2`), a `-12 dp` (`-CoveSpace.hitPlate`) bleeding `surface.row` hit plate (`CoveRadius.inline` `16 dp`), optional `28 dp` leading [`CoveAvatar`](../lib/core/widgets/cove_avatar.dart) (`CoveSize.avatarRow`) separated by `CoveSpace.md` (`12 dp`), `CoveType.rowTitle` (`text.primary`) and `CoveType.rowSub` (`text.tertiary`) text stack, Libre Bodoni `CoveType.cardFigure` trailing amount (`text.primary`, `money.more`, `money.less`), and a `line.hairline` divider inset to the text edge (`40 dp` with avatar, `0 dp` without) omitted on the last row.
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_row.dart`](../lib/core/widgets/cove_row.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) reading `context.cv`, `CoveSize`, `CoveSpace`, `CoveRadius`, `CoveType`, and `CoveMotion.q(context)` with zero raw style literals or `Brightness` branches.
    - Added [`test/golden/row_golden_test.dart`](../test/golden/row_golden_test.dart) and generated all 6 `row.{cover,phone,wide}.{dark,light}.png` goldens plus height, hit-plate bleed, and divider-inset assertions.
- **`CoveSectionLabel` Primitive & Multi-State Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Built [`CoveSectionLabel`](../lib/core/widgets/cove_section_label.dart) with its two strict variants (`CoveSectionLabelVariant.page` on `CoveType.capsPage` `12 sp / .15 em / w700` followed by a full-width `line.hairline` rule, and `CoveSectionLabelVariant.card` on `CoveType.capsCard` `11 sp / .14 em / w700` for card/tile interiors) in `text.tertiary`, plus an optional right-hand `CoveType.readout` on the same alphabetic baseline.
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_section_label.dart`](../lib/core/widgets/cove_section_label.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) reading `context.cv`, `CoveType`, and `CoveSpace` with zero raw style literals or `Brightness` branches.
    - Added [`test/golden/section_label_golden_test.dart`](../test/golden/section_label_golden_test.dart) and generated all 6 `section_label.{cover,phone,wide}.{dark,light}.png` goldens plus typography, hairline-rule, and alphabetic-baseline assertions.
- **`CovePageHeader` Primitive & Multi-State Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Built [`CovePageHeader`](../lib/core/widgets/cove_page_header.dart) (and the `28 dp` [`CoveHeaderPill`](../lib/core/widgets/cove_page_header.dart) EMI `"What if…"` exception) with a `56 dp` minimum height (`20 dp` top padding + `36 dp` `CoveType.title` line box) that grows cleanly when multi-word titles wrap, `CoveSpace.gutter` horizontal padding, baseline-aligned `CoveType.readout` in `text.tertiary` separated by `CoveSpace.md`, and leading/trailing [`CoveRoundButton`](../lib/core/widgets/cove_round_button.dart) slots whose `40 dp` drawn circles sit flush to the gutter while preserving their `48 dp` hit targets.
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_page_header.dart`](../lib/core/widgets/cove_page_header.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) reading `context.cv`, `CoveType`, `CoveSpace`, `CoveSize`, `CoveRadius`, and `CoveMotion.q(context)` with zero raw style literals or `Brightness` branches.
    - Added [`test/golden/page_header_golden_test.dart`](../test/golden/page_header_golden_test.dart) and generated all 6 `page_header.{cover,phone,wide}.{dark,light}.png` goldens plus geometry and alphabetic-baseline assertions.
- **`CoveAvatar` Primitive & Multi-Rung Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Built [`CoveAvatar`](../lib/core/widgets/cove_avatar.dart) across all four size rungs (`inline` 24, `row` 28, `header` 32, `profile` 64) and three household attribution states (`CovePerson.a` creator, `CovePerson.b` joiner, and `CovePerson.both` unfilled `1.5 dp` gradient ring with `&`), keyed strictly to `home.createdBy` with Libre Bodoni `w500` initials at `0.44 × diameter`.
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_avatar.dart`](../lib/core/widgets/cove_avatar.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) using `context.cv` (`personA`/`personALabel`, `personB`/`personBLabel`, `personBothRing`/`personBothLabel`), `CoveSize`, `CoveType.title`, and a custom `_GradientRingPainter` for the unfilled `both` ring.
    - Added [`test/golden/avatar_golden_test.dart`](../test/golden/avatar_golden_test.dart) and generated all 6 `avatar.{cover,phone,wide}.{dark,light}.png` goldens.
- **`CoveRoundButton` Primitive & Multi-State Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Built [`CoveRoundButton`](../lib/core/widgets/cove_round_button.dart) for all circular header, back, add, sheet-close, and inline stepper actions, with a `40 dp` drawn circle (`CoveSize.buttonRound`) inside an invisible `48 dp` tap target (`CoveSize.hit`), `gold` and `ghost` variants, `accent.wash` press overlay (`CoveMotion.q`), and a `24 dp` `.stepper` sibling.
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_round_button.dart`](../lib/core/widgets/cove_round_button.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) reading `context.cv`, `CoveSize`, and `CoveMotion.q(context)` with zero raw style literals or `Brightness` branches.
    - Added [`test/golden/round_button_golden_test.dart`](../test/golden/round_button_golden_test.dart) and generated all 6 `round_button.{cover,phone,wide}.{dark,light}.png` goldens plus hit-target ring assertions.
- **System Chrome Overlay Style, SafeArea Convention & `CoveMaxWidth` (`Oct 22, 2026`)**:
  - *Outcome*: Established the single-source-of-truth `SystemUiOverlayStyle` from `CoveTheme` (light icons on dark mode, dark icons on light mode, transparent status bar so `surfaceCanvas` runs underneath), documented the `SafeArea` and `CoveSpace.barClearance` inset conventions in [`product/ENGINEERING_PRACTICES.md`](./ENGINEERING_PRACTICES.md), and added the [`CoveMaxWidth`](../lib/core/widgets/cove_max_width.dart) container widget with wide-viewport goldens.
  - *Under the Hood*:
    - Added `CoveTheme.overlayStyleFor(Brightness)` in [`lib/core/theme/cove_theme.dart`](../lib/core/theme/cove_theme.dart) and wired it into `AppBarTheme.systemOverlayStyle` and the root `AnnotatedRegion<SystemUiOverlayStyle>` in [`lib/main.dart`](../lib/main.dart); verified via [`test/theme_tokens_test.dart`](../test/theme_tokens_test.dart).
    - Documented the system chrome and `SafeArea` inset rules (`MediaQuery.padding.top`, `CoveSpace.barClearance + MediaQuery.padding.bottom`, no extra top padding above page headers) in §5 of [`product/ENGINEERING_PRACTICES.md`](./ENGINEERING_PRACTICES.md).
    - Added [`lib/core/widgets/cove_max_width.dart`](../lib/core/widgets/cove_max_width.dart) (exported from [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) constraining child width to `CoveSize.maxContent` (`420 dp`) and centring on wider viewports, plus [`test/golden/cove_max_width_golden_test.dart`](../test/golden/cove_max_width_golden_test.dart) (`cove_max_width.wide.{dark,light}.png`).
    - Committed [`design/specs/`](../design/specs/) (`00-system-chrome.md` through `09-floating-bar.md`) and [`product/PROMPTS-PHASE2.md`](./PROMPTS-PHASE2.md).
- **Version Bump to `2.0.0-alpha.1+1` & Screenshot Font Cleanup (`Oct 22, 2026`)**:
  - *Outcome*: Bumped Cove to `2.0.0-alpha.1+1` (`v2.0-alpha.1`) across `pubspec.yaml`, the in-app changelog, `AboutCoveScreen`, and the milestone ledger, and aligned the screenshot generation tests with `LibreBodoni`.
  - *Under the Hood*:
    - Updated `pubspec.yaml` to `version: 2.0.0-alpha.1+1` and `kCoveCurrentAppVersion` in [`lib/features/changelog/changelog_models.dart`](../lib/features/changelog/changelog_models.dart) to `'2.0.0-alpha.1'`.
    - Added the **v2.0-alpha.1 — The Design System** entry to `kChangelogItems` in [`lib/features/changelog/changelog_models.dart`](../lib/features/changelog/changelog_models.dart) and updated [`test/changelog_test.dart`](../test/changelog_test.dart).
    - Updated [`lib/features/home/about_cove_screen.dart`](../lib/features/home/about_cove_screen.dart) to display `v2.0-alpha.1 (1)` and added the `v2.0-alpha.1` row to §2 of [`product/versioning_and_git_strategy.md`](./versioning_and_git_strategy.md).
    - Replaced `BodoniModa-Medium.ttf` font loading in [`test/generate_screenshots_test.dart`](../test/generate_screenshots_test.dart) and [`test/generate_commitments_screenshots_test.dart`](../test/generate_commitments_screenshots_test.dart) with `LibreBodoni-Regular.ttf` and `LibreBodoni-Medium.ttf`.

---

## [v1.0-alpha.1] — 2026-09-25

### Fixed
- **Two-Decimal Precision for Non-Integer Currency Amounts (`Oct 22, 2026`)**:
  - *Outcome*: Currency amounts with non-zero paise/cents now always display two decimal places (e.g. `₹42.50` and `₹12,34,567.50` instead of `₹42.5`), while whole-number amounts continue to omit `.00` cleanly (e.g. `₹42`).
  - *Under the Hood*:
    - Updated `_coveDecimalAmountFormat` in [`lib/core/utils/cove_currency_formatter.dart`](../lib/core/utils/cove_currency_formatter.dart) from `NumberFormat('#,##,##0.##', 'en_IN')` to `NumberFormat('#,##,##0.00', 'en_IN')`, keeping `_coveIntegerAmountFormat` and the `roundedCents % 100 == 0` branch intact.
    - Restored the `$42.50` expectation in [`test/expenses_test.dart`](../test/expenses_test.dart) and added unit tests in [`test/user_requests_batch_test.dart`](../test/user_requests_batch_test.dart) covering `42.5 -> "42.50"`, `42.57 -> "42.57"`, `42.0 -> "42"`, `0 -> "0"`, `1234567.5 -> "12,34,567.50"`, and `0.005 -> "0.01"`.
- **Prevent Duplicate Bottom Sheets on Push Notification Tap (`Oct 07, 2026`)**:
  - *Outcome*: Tapping a push notification now opens exactly one entity detail bottom sheet (e.g. expense, commitment, list item, habit, or calendar event), eliminating stacked duplicate bottom sheets.
  - *Under the Hood*:
    - Removed redundant `ref.listen(notificationPayloadNavigationProvider)` in `AppShell` that was duplicating the `_navSub = notifService.onNavigateToPayload.listen` stream listener.
    - Added an opening mutex and a 1500ms entity debounce in `NotificationDetailDispatcher.openDetailForNotification` to safely drop concurrent or rapid duplicate dispatches.
    - Enforced `Navigator.of(context).popUntil((route) => route.isFirst)` right before presenting any notification detail sheet to ensure no previously open sheet or modal remains underneath.
    - Debounced duplicate OS tap callbacks within 1000ms in `NotificationService.onNotificationTapped` (preventing dual triggers from `getNotificationAppLaunchDetails` and `onDidReceiveNotificationResponse`).
    - Added automated widget test in `test/notifications_test.dart` verifying concurrent dispatches open exactly one bottom sheet.
- **Foreclosed & Completed EMI Year Projections in Helicopter View (`Oct 07, 2026`)**:
  - *Outcome*: Foreclosed and completed EMIs now preserve their past paid installment months in the 12-month Helicopter Year View, while correctly stopping further EMI calculations on and after the foreclosure or completion cutoff. Inactive loans no longer vanish completely from the year view as if they never existed.
  - *Under the Hood*:
    - In `CommitmentProjectionUtils.projectYear`, adjusted the inactive filter to only exclude open-ended subscriptions (`if (!sub.isActive && !sub.isEmi) continue;`), allowing finite commitments (EMIs) to evaluate past active months.
    - Enhanced `_isEmiActiveInMonth` to determine the loan's initial start month via `endDate - (totalInstallments - 1)` (or `createdAt`) and the foreclosure cutoff month via `sub.nextBillingDate`.
    - Excluded months on or after the foreclosure cutoff while keeping all months between loan start and cutoff active.
    - Added unit tests in `test/subscriptions_test.dart` validating month-by-month projections for foreclosed, completed, and cancelled commitments.

### Added
- **Theme Serves `CoveTokens`, `CoveType`, and Token-Mapped `ColorScheme`/`TextTheme` (`Oct 22, 2026`)**:
  - *Outcome*: `CoveTheme.darkTheme` and `CoveTheme.lightTheme` now register `CoveTokens.dark` and `CoveTokens.light` alongside the existing `CoveColors` and `CoveTypography` extensions, and map Material's `ColorScheme` and `TextTheme` directly from `CoveTokens` and `CoveType` so `context.cv` and Material defaults resolve consistently across both modes while unconverted screens continue to coexist.
  - *Under the Hood*:
    - Registered `CoveTokens.dark` and `CoveTokens.light` in `ThemeData.extensions` in [`lib/core/theme/cove_theme.dart`](../lib/core/theme/cove_theme.dart) and re-exported `cove_tokens.dart` without altering `CoveColors`.
    - Mapped `ColorScheme` (`primary: tokens.accentFill`, `onPrimary: tokens.textOnAccent`, `error: tokens.statusAlert`, `surface: tokens.surfaceCard`, `onSurface: tokens.textPrimary`) and `TextTheme` (`displayLarge: CoveType.heroFigure`, `displayMedium: CoveType.cardFigure`, `titleLarge`/`headline*`/`displaySmall: CoveType.title`, `titleMedium`/`labelLarge: CoveType.rowTitle`, `titleSmall`/`bodyMedium: CoveType.readout`, `bodyLarge: CoveType.body`, `bodySmall: CoveType.rowSub`, `labelMedium: CoveType.capsPage`, `labelSmall: CoveType.capsCard`) in [`lib/core/theme/cove_theme.dart`](../lib/core/theme/cove_theme.dart).
    - Added [`test/theme_tokens_test.dart`](../test/theme_tokens_test.dart) verifying `context.cv` resolves in both `Brightness.dark` and `Brightness.light` and matches `CoveTokens` (`surfaceCanvas`, `textPrimary`, `accentFill`).
    - Regenerated all 84 screen goldens in `test/golden/goldens/` and verified every diff is attributable to `CoveTokens` / `CoveType`.
- **Libre Bodoni Display Typeface with Native `₹` Glyph (`Oct 22, 2026`)**:
  - *Outcome*: Replaced the display typeface `BodoniModa` with `LibreBodoni` across all editorial titles and financial hero/card figures so the Indian Rupee symbol (`₹`, U+20B9) renders natively in the display serif rather than falling back to a system font, while preserving vertical rhythm (cap height 754 vs 750 per 1000 em).
  - *Under the Hood*:
    - Added `assets/fonts/LibreBodoni-Regular.ttf` (400) and `assets/fonts/LibreBodoni-Medium.ttf` (500), appended the Libre Bodoni copyright notice to `assets/fonts/OFL.txt`, registered `LibreBodoni` in `pubspec.yaml`, and removed `BodoniModa` (`assets/fonts/BodoniModa-Medium.ttf`).
    - Updated `type.familyDisplay` in [`design/tokens.json`](../design/tokens.json) to `LibreBodoni` and regenerated [`lib/core/theme/cove_tokens.dart`](../lib/core/theme/cove_tokens.dart).
    - Replaced all `'BodoniModa'` / `GoogleFonts.bodoniModa` references across `lib/` ([`lib/core/theme/cove_typography.dart`](../lib/core/theme/cove_typography.dart), [`lib/core/widgets/cove_splash_screen.dart`](../lib/core/widgets/cove_splash_screen.dart), [`lib/core/widgets/cove_streak_badge.dart`](../lib/core/widgets/cove_streak_badge.dart), [`lib/features/home/about_cove_screen.dart`](../lib/features/home/about_cove_screen.dart), [`lib/features/calendar/views/calendar_month_view.dart`](../lib/features/calendar/views/calendar_month_view.dart), [`lib/features/calendar/views/calendar_agenda_view.dart`](../lib/features/calendar/views/calendar_agenda_view.dart), [`lib/features/today/today_screen.dart`](../lib/features/today/today_screen.dart), [`lib/features/expenses/monthly_budget_sheet.dart`](../lib/features/expenses/monthly_budget_sheet.dart), and [`lib/features/subscriptions/emi_tracker_screen.dart`](../lib/features/subscriptions/emi_tracker_screen.dart)).
    - Updated [`loadCoveFonts`](../test/golden/golden_harness.dart) in [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart) to load both `LibreBodoni` weights and regenerated all 84 baseline goldens in `test/golden/goldens/`.
- **Material Icon Font Rendering in Golden Harness & Regenerated Baselines (`Oct 22, 2026`)**:
  - *Outcome*: All 84 baseline screen goldens now render actual Material icons instead of fallback tofu boxes, and the golden harness fails fast if `MaterialIcons-Regular.otf` cannot be resolved from the Flutter SDK.
  - *Under the Hood*:
    - Updated [`loadCoveFonts`](../test/golden/golden_harness.dart) in [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart) to resolve `$FLUTTER_ROOT` at runtime (via `Platform.environment['FLUTTER_ROOT']` with `Platform.resolvedExecutable` fallback), fail explicitly if `$FLUTTER_ROOT/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf` is missing, and register it with `FontLoader('MaterialIcons')`. Confirmed zero `CupertinoIcons` usage across `lib/`.
    - Regenerated all 84 baseline PNGs in `test/golden/goldens/` and verified `today_screen.phone.dark.png`, `profile_screen.phone.light.png`, and `calendar_create_sheet.phone.dark.png`.
- **Baseline Multi-Viewport Screen Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Captured 84 deterministic "before" golden snapshots across all 14 Cove screens and representative sheets (3 widths: Fold cover 320dp, phone 411dp, Fold inner wide 840dp × 2 modes: dark and light) to serve as the visual baseline before the v2 design system conversion.
  - *Under the Hood*:
    - Wired `coveThemeFor(Brightness)` in [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart) to the existing `CoveTheme.darkTheme` and `CoveTheme.lightTheme` factories and registered `GeneralSans` and `BodoniModa` font families in `loadCoveFonts()` for offline deterministic glyph rendering.
    - Added [`test/golden/screens_golden_test.dart`](../test/golden/screens_golden_test.dart) covering `today_screen`, `calendar_screen`, `expenses_screen`, `subscriptions_screen`, `emi_tracker_screen`, `commitments_helicopter_screen`, `routine_screen`, `activity_screen`, `home_settings_screen`, `profile_screen`, `calendar_create_sheet`, `expense_detail_sheet`, `lists_screen`, and `habits_screen` using stubbed Riverpod providers and fixed seed data (zero database connections or network calls).
    - Committed all 84 baseline PNGs in `test/golden/goldens/`.
- **Drift v11 Schema Snapshot & Data-Preserving Migration Safety Gate (`Oct 22, 2026`)**:
  - *Outcome*: Captured an immutable snapshot of live production database schema v11 across all 17 household tables and locked in automated schema verification, a full 17-table data-preservation migration test, and a schema snapshot ratchet guard before any v2 changes begin.
  - *Under the Hood*:
    - Dumped schema v11 to [`drift_schemas/drift_schema_v11.json`](../drift_schemas/drift_schema_v11.json) via `dart run drift_dev schema dump` and generated versioned schema & step-by-step helpers in [`test/drift/generated/`](../test/drift/generated/).
    - Added [`test/migration_test.dart`](../test/migration_test.dart) with three gates: a snapshot ratchet ensuring `AppDatabase.schemaVersion` never exceeds the newest snapshot in `drift_schemas/`, a `SchemaVerifier` check validating v11 against the snapshot, and a data-preserving migration test that populates all 17 tables at v11 with non-default values across every column and verifies zero field loss after migrating to `schemaVersion`.
- **v2 Design System Token Pipeline & Quality Gates (`Oct 22, 2026`)**:
  - *Outcome*: Laid the foundation for the v2 design system revamp (`feature/v2-design-system-revamp`) without touching any existing screen or widget. Registered the new `PlusJakartaSans` UI typeface alongside `GeneralSans` and `BodoniModa`, added its SIL Open Font Licence (`assets/fonts/OFL.txt`), and wired deterministic token generation, WCAG contrast checks, a one-way style-literal ratchet gate, and golden test scaffolding.
  - *Under the Hood*:
    - Registered `PlusJakartaSans` (weights 400, 500, 600, 700) in `pubspec.yaml` and added `assets/fonts/OFL.txt`.
    - Added W3C DTCG single source of truth [`design/tokens.json`](../design/tokens.json) and code generator [`tool/gen_tokens.dart`](../tool/gen_tokens.dart), emitting [`lib/core/theme/cove_tokens.dart`](../lib/core/theme/cove_tokens.dart) (`CoveTokens`, `CoveSpace`, `CoveSize`, `CoveRadius`, `CoveType`, `CoveMotion`, and `BuildContext.cv`).
    - Added automated gates: [`tool/check_contrast.py`](../tool/check_contrast.py) (WCAG AA contrast verification across dark & light modes), [`tool/style_gate.dart`](../tool/style_gate.dart) + [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (ratchet enforcing zero raw `Color(...)`, `fontSize:`, or `BorderRadius.circular(...)` in converted files), [`tool/check_version.dart`](../tool/check_version.dart), and [`tool/check.sh`](../tool/check.sh).
    - Added multi-viewport/multi-mode golden test harness [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart) (`CoveWidth.cover`, `CoveWidth.phone`, `CoveWidth.wide` × dark/light) and resolved Riverpod 3 `Override` import and analyzer lints across `tool/` and `test/golden/`.
    - Architectural pattern documented in [`product/ENGINEERING_PRACTICES.md`](./ENGINEERING_PRACTICES.md) and [`product/design_system_tokens.md`](./design_system_tokens.md).
- **Nightly Automatic Google Drive Backup (`Oct 22, 2026`)**:
  - *Outcome*: Once Google Drive and a recovery passphrase are set up, Cove now backs itself up every night around 2:00 AM on Wi-Fi — no tapping required. Nights with no changes are skipped so the 10 kept backups stay meaningful, and if Drive access is ever lost, Settings says so plainly instead of failing silently. Time, Wi-Fi-only and on/off are adjustable under **Settings → Backup & Restore**.
  - *Under the Hood*:
    - New `BackupService` (shared manual/automatic pipeline): `run(automatic:)` with outcomes `uploaded`, `skippedUnchanged` (SHA-256 snapshot fingerprint via `pointycastle`), `skippedRecent` (< 20 h), `notConfigured`, `needsReconnect`, `failed`; automatic runs never throw and persist `cove_backup_auto_*` status.
    - New `WorkmanagerBackupScheduler` (`workmanager` ^0.10.10): unique 24 h periodic job `cove-nightly-backup`, initial delay to the chosen local time, `unmetered`/`connected` network + battery-not-low constraints, exponential backoff from 30 min; `KEEP` on launch, `REPLACE` on settings change.
    - `coveBackgroundDispatcher` + `BackgroundBackupRunner` run the backup in a background isolate with silent Play-services Drive authorization (no Activity required); reuses the app's DB connection if executed in the main isolate.
    - `DriveBackupController` refactored onto `BackupService`; adds `setAutoEnabled`/`setAutoTime`/`setAutoWifiOnly`, `refresh()` (called on app resume) and schedule sync on launch from `AppShell`.
    - Settings: **Nightly Backup** toggle with live last-run status, **Backup Time** picker, **Wi-Fi Only** toggle.
    - Tests: 15 new cases in `test/drive_backup_test.dart` (skip rules, reconnect/failed handling, fingerprint stability, scheduling/persistence); `test/notifications_test.dart` switch count scoped to notification toggles.
    - Decision record updated: [`product/backup_and_recovery.md`](./backup_and_recovery.md) §5a.
- **Real End-to-End Encrypted Google Drive Backup & Restore (`Oct 22, 2026`)**:
  - *Outcome*: "Back Up Now" now actually backs up. Your whole household — every list, expense, commitment, habit, calendar event, activity entry, the home encryption keys and local preferences — is encrypted on the phone with a recovery passphrase and saved to a private, hidden folder in your own Google Drive. On a new or reset phone, sign in, tap **Restore from Google Drive backup**, enter the passphrase, and everything comes back; anything newer catches up from your partner automatically. The previous simulated backup UI (fake "18 hours ago", fake pending counts, non-functional nightly window) has been removed.
  - *Under the Hood*:
    - New `lib/features/backup/` module: `BackupCrypto` (Argon2id m=19 MiB/t=2 KEK → per-backup random DEK, AES-256-GCM with `cove-backup/v1` AAD, gzip via `archive`), `BackupSnapshotService` (generic transactional `SELECT *` export of all Drift tables + `HomeKeyStore` keys + `cove_*` secure prefs; atomic full-replace restore with schema-tolerant column intersection and `markTablesUpdated`), `GoogleDriveBackupRemote` (`google_sign_in` 7 authorization-only flow, `drive.appdata` scope, `appDataFolder` upload/list/download/delete, 401 token refresh), and `DriveBackupController` Riverpod state machine (connect, set/change passphrase, backup, keep newest 10, restore).
    - Passphrase-derived key stored in Keystore-backed `EncryptedSharedPreferences`; restoring on a new phone adopts the backup's key so future backups need no re-entry.
    - `SyncEngineImpl.resyncAfterRestore` clears the in-memory dedupe cache and replays the Supabase log after a restore.
    - Settings `Backup & Restore` rebuilt as `DriveBackupSection`; onboarding gains a "Restore from Google Drive backup" entry (Android only; web shows an availability note).
    - Removed mock `BackupStatusState`/`BackupStatusNotifier`; `CovePillInput` gains `obscureText`.
    - Added `archive` as a direct dependency.
    - Tests: new `test/drive_backup_test.dart` (crypto round-trip, wrong passphrase, tamper detection, snapshot fidelity, stream notification, schema tolerance, retention, full new-phone restore); updated `test/profile_settings_test.dart`.
    - Decision record: [`product/backup_and_recovery.md`](./backup_and_recovery.md).
- **Financed Through Support for Ongoing Subscriptions (`Oct 07, 2026`)**:
  - *Outcome*: Users can now specify and view the payment source (card, bank, or person) for ongoing subscriptions (e.g. "Amex Gold", "HDFC Regalia", "Apple Card") in addition to finite EMIs. Financing sources appear in commitment list cards, detail sheets, month breakdown sheets, calendar agenda renewal entries, and activity feeds.
  - *Under the Hood*:
    - In `SubscriptionFormSheet`, elevated the `FINANCED THROUGH` input field with real-time history suggestions directly below the commitment type selector so it is accessible for all commitment types.
    - Removed `isEmiSelected` gate from `effectiveFinancedThrough` so sources are persisted and dispatched via sync for standard subscriptions.
    - Updated `SubscriptionsScreen` subtitle builder to append `· via <source>` for regular subscriptions.
    - Updated `CommitmentDetailSheet` to display the "Financed Through" row for any commitment with a valid source.
    - Surfaced payment source in `MonthCommitmentsSheet` tile subtitles and `CalendarAgendaView` renewal entries.
    - Included payment source in `ActivityFormatter` and `NotificationFormatter` event subtitles.
    - Added full end-to-end unit and widget test coverage in `test/subscriptions_test.dart`.
- **Home-Scoped SQLite Persistence & Cross-Device Sync (`Sep 25, 2026`)**:
  - *Outcome*: Monthly expense budgets, preferred home currency, anniversary dates, and check-in reminders now permanently persist in local SQLite and sync seamlessly across partner devices.
  - *Under the Hood*:
    - Bumped Drift database schema to version `11`.
    - Added `monthlyBudget` and `anniversaryDate` columns to `LocalHomes`.
    - Created dedicated `LocalCheckinReminders` table (`id`, `homeId`, `hour`, `minute`, `message`, `isEnabled`, `createdAt`).
    - Added full CRUD projections in `LocalStateStoreImpl` for `home_currency_updated`, `home_anniversary_updated`, `monthly_budget_updated`, `monthly_budget_cleared`, and `checkin_reminder_*` events.
    - Updated `MonthlyBudgetNotifier`, `CurrencyNotifier`, `HomeMetadataNotifier`, and `ReminderNotifier` to stream reactively from SQLite.
- **End-to-End Home Currency Consistency (`Sep 25, 2026`)**:
  - *Outcome*: The active Home's currency preference (e.g. INR `₹`) is now the single authoritative source of truth across all screens, activity feeds, detail sheets, and notifications. Activity logs and undo handlers no longer default to USD `$`.
  - *Under the Hood*:
    - `ActivityFormatter.formatWithDb` queries `db.localHomes` by `homeId` if currency symbol is not yet loaded into memory, guaranteeing correct symbol resolution.
    - `ActivityFormatter.getCurrencySymbol` honors `fallbackSymbol` whenever currency is USD or omitted.
    - `PreferencesController.setCurrency` cascades new currency preference to all existing SQLite `localExpenses` and `localSubscriptions` records for the active home.
    - `LocalStateStoreImpl` projects `home_currency_updated` events to cascade update `localExpenses` and `localSubscriptions` across devices.
    - `ActivityEventDetailSheet` undo handlers fallback to `currencyPreferenceProvider.code` rather than hardcoded `'USD'`.
- **Contextual Notification Deep Linking (`Sep 25, 2026`)**:
  - *Outcome*: Tapping an expense, commitment, or list push notification now opens the exact item's detail bottom sheet directly on top of the screen instead of simply navigating to the generic tab.
  - *Under the Hood*:
    - Enhanced FCM payload parser in `NotificationService` to capture `entityId` and `actionType`.
    - Added `NotificationDetailDispatcher` to resolve entities asynchronously from Drift SQLite and present the respective modal sheet with navigation stack pop-until guards.

---

## [v1.0-alpha.1] — 2026-09-20 to 2026-09-22

### Added
- **EMI Tracker & Loan Foreclosure (`Sep 20, 2026`)**:
  - *Outcome*: Dedicated household EMI overview with total debt burden, multi-select loan payoff simulation, and one-tap foreclosure confirmation with optional ledger recording.
  - *Under the Hood*:
    - Bodoni Moda hero burden card, sticky `MultiSelectBurdenBar`, and foreclosure projection controller.
- **Two-Tick Sync Delivery Reconciliation (`Sep 22, 2026`)**:
  - *Outcome*: Single ticks (`savedLocally`) automatically advance to double ticks (`syncedToPartner`) reliably, even if the partner device received the payload while the sender was offline.
  - *Under the Hood*:
    - Added `reconcileDeliveryConfirmations()` to batch-query persistent Supabase `event_deliveries` on launch, pull-to-refresh, and upload flush.
- **Push Notification Background Navigation Fix (`Sep 22, 2026`)**:
  - *Outcome*: Tapping system notifications reliably opens the corresponding module even when the app was killed or cold-launched.
  - *Under the Hood*:
    - Added `FLUTTER_NOTIFICATION_CLICK` intent filter in `AndroidManifest.xml`.
    - Implemented `consumePendingNavigationModule()` in `NotificationService` and `AppShell`.

---

## [v1.0-alpha.1] — 2026-09-19

### Changed
- **Calendar-First Architecture & Today Sanctuary (`Sep 19, 2026`)**:
  - *Outcome*: Cove launches directly into your day on the calendar, carrying five quiet layers: events, commitments, money, rhythms, and tasks. Today is the home tab gathering monthly spend totals, shared list pills, and recent activity into one calm flow.
  - *Under the Hood*:
    - Unified 5-layer calendar provider, additive due-date database schema, Day view layer filters, Bodoni time gutters, and retired Dashboard architecture.

---

## [v0.6-alpha] — 2026-09-17

### Added
- **Commitments Helicopter View (`Sep 17, 2026`)**:
  - Full-screen 12-month bird's-eye commitments grid with 50/50 partner attribution toggles and drill-down sheets.
- **Clean Decimals (`Sep 17, 2026`)**:
  - Smart decimal formatting (`formatCoveAmount`) that strips zero decimals (e.g. ₹250 instead of ₹250.00) while preserving non-zero cents and paise.
- **Personal Profile Studio (`Sep 17, 2026`)**:
  - Custom photo portraits, camera capture, and minimal initial avatars with frame-0 offline caching.

---

## [v0.5-alpha] — 2026-09-17

### Added
- **Partner-First "Paid By" Details (`Sep 17, 2026`)**:
  - Clear "You" vs partner name attribution replacing cryptic UUID hashes across commitments and expense ledgers.

---

## [v0.4-alpha] — 2026-09-15

### Added
- **Silent Background Sync (`Sep 15, 2026`)**:
  - Zero-spinner, zero-modal sync engine preserving undisturbed reading and typing.
- **Strict Annual Renewal Timing (`Sep 15, 2026`)**:
  - Calendar math pinning recurring annual renewals strictly to their scheduled calendar day.

---

## [v0.3-alpha] — 2026-09-12

### Added
- **Zero-Knowledge End-to-End Encryption (`Sep 12, 2026`)**:
  - Argon2id key derivation + XChaCha20-Poly1305 AEAD payload encryption ensuring domestic privacy.

---

## [v0.2-alpha] — 2026-09-08 to 2026-09-10

### Added
- **Two-Tick Visual Confirmation (`Sep 10, 2026`)**:
  - Visual single tick vs double tick status indicator for partner sync.
- **Daily Rhythms & Mutual Cheers (`Sep 8, 2026`)**:
  - Shared recurring habit tracking with mutual cheering animations.

---

## [v0.1-alpha] — 2026-09-05

### Added
- **Offline-First Foundation & Multi-Currency Support (`Sep 5, 2026`)**:
  - Drift SQLite local database, optimistic mutation pipeline with outbox queues, and support for INR, USD, EUR, GBP, and JPY.
