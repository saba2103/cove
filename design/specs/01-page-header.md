# CovePageHeader

The title block at the top of a destination. One per screen, directly below the status
bar inset.

| | |
|---|---|
| Height | 56 `(literal)` — grows if the title wraps |
| Padding | `CoveSpace.gutter` horizontal, 20 top `(literal)`, 0 bottom |
| Title | `CoveType.title` — 28sp Libre Bodoni w500 on a 36dp line box |
| Trailing readout | `CoveType.readout` in `text.tertiary`, baseline-aligned to the title |
| Actions | up to three `CoveRoundButton`s (`actions.length <= 3`), right-aligned with `CoveSpace.sm` between drawn circles and the trailing edge flush to the gutter |
| Gap, title → readout | `CoveSpace.md` |

## Rules

- **One button size, up to three actions.** Every header button — back, add, close, menu,
  and month-switching chevrons — is a full `CoveRoundButton` (`CoveSize.buttonRound` 40dp
  drawn inside a `CoveSize.hit` 48dp target). Up to three trailing `actions` sit
  right-aligned with `CoveSpace.sm` (8dp) between drawn circles. Header chevrons (such as
  Calendar's previous/next month buttons) are primary navigation and must be full ghost
  `CoveRoundButton`s, never `CoveRoundButton.stepper` (which is reserved for inline
  chevrons inside rows and day headers).
- **The back button and the add button are the same object**, differing only in fill.
- **Actions and the header pill may coexist.** Never put a generic labelled pill in a
  header — "+ Add" beside a page called Commitments is redundant. The one exception is a
  control whose verb has no glyph — the EMI "What if…" — which is a pill at 28 height
  `(literal)`. `actions` (and `leading` back) and `trailingPill` may coexist (e.g. back +
  "What if…" pill on EMIs).
- The readout is a fact, not a control: `October · ₹38,420`, sentence case, never a button.
- Title and readout share a baseline. Do not centre them to each other.
