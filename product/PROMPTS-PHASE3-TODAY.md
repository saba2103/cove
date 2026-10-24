# Phase 3.10 — Today, as a sequence

Today was the one screen with an unresolved A/B in the prototype. Version **02, the paper**
was chosen, with a **rule-based Letter**. It depends on objects that don't exist yet, so
3.10 is eight prompts, not one. Run them in order, one at a time.

Band (routine) and dial (category) are not needed by Today — they come with 3.11.

---

## 3.10a — tokens, fonts, contrast gate

````
Prepare the tokens and fonts the paper objects and the Letter need. No widgets yet.

1. Fonts. `assets/fonts/LibreBodoni-Italic.ttf` is new (weight 400, italic, carries ₹,
   cap height 754 matching the roman). Register it in the existing LibreBodoni family in
   pubspec.yaml with `weight: 400` and `style: italic`. Load it in the golden harness too.

2. Tokens. In design/tokens.json add a flat colour group `slip` (flat keys — the generator
   does not support nested groups), single-valued:
     inkFrom #1A4541 · inkVia #133734 · inkTo #0E2A28
     inkText3 #A3ABA6       (tertiary text on ink; text.tertiary fails there at 3.63:1)
     inkAlertText #DC988A   (alert words on ink; status.alertText fails at 3.61:1)
     inkMark #909993        (empty streak cells — non-text, 3.63:1 against a 3:1 floor)
   Add "slip" to the colour groups list in tool/gen_tokens.dart.

   Add four typography roles under `type`:
     greeting    display 36sp w400 lineHeight 40 letterSpacing 0
     letter      display 21sp w400 lineHeight 36 letterSpacing 0
     slipTitle   display 22sp w400 lineHeight 28 letterSpacing -0.01
     slipFigure  display 32sp w500 lineHeight 36 letterSpacing 0
   Italic is applied at the use site with copyWith(fontStyle: FontStyle.italic); it is not
   a separate role.

3. Contrast gate. Extend tool/check_contrast.py so the ink stops are checked like surfaces:
   text.primary, text.secondary, accent.text, money.more, money.less, slip.inkText3 and
   slip.inkAlertText must clear 4.5:1 on all three ink stops; accent.fill and slip.inkMark
   must clear 3:1. Run it and report the worst pair.

4. Regenerate cove_tokens.dart, commit the diff. tool/check.sh must exit 0.
````

## 3.10b — the slip frame and the ticket

````
Build `CoveSlip` and `CoveTicket` in lib/core/widgets/slips/, to
design/specs/10-paper-objects.md ("The shared frame" and "CoveTicket"). Read the whole spec
first — the frame is shared by all five objects, so get it right before anything else.

- `CoveSlipVariant { paper, ink }` is chosen by the caller. The widget must not infer it
  from brightness.
- On ink, tertiary text is slip.inkText3 and alert words are slip.inkAlertText — never
  text.tertiary or status.alertText, which fail contrast there.
- Expose state as semantics, per the spec's last section.
- Goldens via goldenMatrix: the ticket in paper and ink, both brightnesses.
- Same rules as the Phase 2 template: tokens only, raw literals only where the spec marks
  (literal), nothing under lib/features changes, allow-list unchanged. tool/check.sh exit 0.
````

## 3.10c — the receipt

````
Build `CoveReceipt` on `CoveSlip`, to design/specs/10-paper-objects.md ("CoveReceipt").

- Torn zigzag edges top and bottom, radius 0.
- The split bar writes both names and amounts beside it; colour never carries the split alone.
- The barcode pattern MUST be derived deterministically from the record id. If it is random
  per render, every golden changes every run — run the golden suite twice and confirm
  byte-identical output.
- Goldens: a one-item and a three-item receipt, paper and ink, both brightnesses, plus
  cover width to confirm amounts don't wrap. Same Phase 2 rules. tool/check.sh exit 0.
````

## 3.10d — the note and the habit card

````
Build `CoveNote` and `CoveHabitCard` on `CoveSlip`, to design/specs/10-paper-objects.md.

- CoveNote uses the existing CoveCheckbox. Done items strike through and drop to secondary.
- CoveHabitCard's streak grid is 21 cells: done in accent.fill, missed as an outline in
  slip.inkMark (ink) or paper.ink3 (paper), today ringed. The run count is always in text;
  the grid is supplementary.
- Goldens: a note with mixed done/open items; a habit card at 0, 7 and 23 days running.
  Paper and ink, both brightnesses. Same Phase 2 rules. tool/check.sh exit 0.
````

## 3.10e — the voucher

````
Build `CoveVoucher` on `CoveSlip`, to design/specs/10-paper-objects.md ("CoveVoucher").

- The due circle is 64dp and holds the day and the month only. Do NOT put "DUE" inside it:
  the prototype fits it at 6.5px, which is 8.5sp at device scale, under our 11sp floor.
- States: due, paid (PAID stamp, circle fades), and the EMI punched variant (N dots, paid
  filled). Semantics must read out the state and, for an EMI, "12 of 48 paid".
- Goldens for all three states. Same Phase 2 rules. tool/check.sh exit 0.
````

## 3.10f — the carousel

````
Build `CoveCarousel` in lib/core/widgets/, to design/specs/12-carousel.md.

- One item renders full width with no pager.
- Item width is 82% of content width; first item aligned to the gutter; next item peeks.
- Announce "2 of 3" to assistive tech; Reduce Motion respected for the snap.
- Goldens: one, two and five items; cover width. Same Phase 2 rules. tool/check.sh exit 0.
````

## 3.10g — the Letter

````
Build the Letter, to design/specs/11-day-letter.md. Read the whole spec before writing code.

1. `composeDayLetter(DayLetterInput) → List<LetterSpan>` in lib/features/today/letter/ —
   a PURE function. No widgets, no providers, no DateTime.now(); the clock and all facts
   arrive in DayLetterInput. Deterministic: same input, same spans.

2. Unit tests BEFORE the widget, with fixtures for: an empty first-run day; a clear day;
   a quiet day matching the spec's sentences; a busy day; money with one dominant item;
   money with two items over 75%; habits all done by both; habits mixed; commitments due
   tomorrow; several lists. Plus: determinism (compose twice, compare); every link span has
   a target; Indian grouping on a lakh figure; no DateTime.now() anywhere in the letter
   folder (grep it in the test).

3. Names are VERBATIM. "Call with Amma" stays "Call with Amma". Do not paraphrase,
   shorten or re-case any user-entered title — add a test that asserts a title with odd
   casing and punctuation passes through unchanged.

4. Then `CoveLetter`, which renders spans in CoveType.letter: links underlined in
   accent.fill and tappable; italic spans in Libre Bodoni Italic, text.secondary.
   Goldens for three fixtures.

5. tool/check.sh exit 0.
````

## 3.10h — Today

````
Convert lib/features/today/today_screen.dart, to design/screens/today.md and
design/screens/today.png. Read today.md fully — it overrides the generic Phase 3 template
in two places: the header is screen-local, and the Recent activity section is removed.

- Use CoveTicket, CoveHabitCard, CoveReceipt, CoveNote, CoveVoucher, CoveCarousel and
  CoveLetter. Do not build any slip locally.
- Slips are ink in dark mode, paper in light mode.
- The Letter is composeDayLetter() over today's real data, recomposed every build.
- Build _TodayHeader as described. Do NOT modify CovePageHeader.
- Delete today_screen.dart's line from tool/style_allowlist.txt, and delete
  'today_screen.cover' from the overflow backlog — the suite must stay green without it.
  That empties the backlog.
- Regenerate Today's six goldens and inspect them against today.png. tool/check.sh exit 0.
````
