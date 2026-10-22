# CovePageHeader

The title block at the top of a destination. One per screen, directly below the status
bar inset.

| | |
|---|---|
| Height | 56 `(literal)` — grows if the title wraps |
| Padding | `CoveSpace.gutter` horizontal, 20 top `(literal)`, 0 bottom |
| Title | `CoveType.title` — 28sp Libre Bodoni w500 on a 36dp line box |
| Trailing readout | `CoveType.readout` in `text.tertiary`, baseline-aligned to the title |
| Action | one `CoveRoundButton`, trailing edge flush to the gutter |
| Gap, title → readout | `CoveSpace.md` |

## Rules

- **A header has exactly one button size.** Back, add, close, menu — all
  `CoveSize.buttonRound`. There is no second size.
- **The back button and the add button are the same object**, differing only in fill.
- Never a labelled pill in a header. The page title already says what the page is, so
  "+ Add" beside a page called Commitments is redundant. The one exception is a control
  whose verb has no glyph — the EMI "What if…" — which is a pill at 28 height `(literal)`.
- The readout is a fact, not a control: `October · ₹38,420`, sentence case, never a button.
- Title and readout share a baseline. Do not centre them to each other.
