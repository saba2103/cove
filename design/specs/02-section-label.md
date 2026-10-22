# CoveSectionLabel

The caps line that opens a section. The most repeated atom in the app — it was seven
different sizes before the audit, and that is the single most visible inconsistency
when two screens sit side by side.

**There are two. Not three.**

| | Style | Use |
|---|---|---|
| On the page | `CoveType.capsPage` — 12sp / .15em / w700 | A section heading on the scroll surface |
| Inside a thing | `CoveType.capsCard` — 11sp / .14em / w700 | A label within a card, a metric tile, a slip |

Colour `text.tertiary` in both cases.

## Rules

- Page-level labels are followed by a hairline rule in `line.hairline`, full content width.
- A right-hand readout may sit on the same baseline: `CoveType.readout`, `text.tertiary`.
- **Nothing in the app is smaller than 11sp.** If a label feels too big for its box, the
  box is wrong.
- The paper slips keep their own print scale (`CoveType.capsSlip`, .18em). That is
  deliberate — printed matter is not UI — and is the only exception.
