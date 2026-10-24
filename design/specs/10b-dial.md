# CoveDial — a category

A category is a container, not an entry, so it has no Add equivalent — it only ever appears
on its own detail sheet. Built on `CoveSlip`, **paper variant**.

| | |
|---|---|
| Caps line | `COVE · CATEGORY` |
| Title | the category name, `CoveType.slipTitle` |
| Dial | a donut, 160dp `(literal)` diameter, 12dp `(literal)` stroke. Track in the palette's `rule`. Arc = this category's share of the month's spending, starting at 12 o'clock, clockwise, in the category's colour. |
| Centre | the month's amount in `CoveType.slipFigure`, "this month" in `capsSlip` beneath |
| Below | the last few purchases as receipt-style rows |

## Colour — the trap
Category colours change with the app theme. **On paper, always take them from
`CoveTokens.light`, never from `context.cv`.** In dark mode `context.cv.categoryTravel` is
`#E0C98A`, which is nearly invisible on cream paper. Measured against the darkest paper stop,
every light-mode category colour clears 3:1 (travel is tightest at 3.17).

## Semantics
"Category, Groceries, ₹12,400 this month, 31% of spending, 14 purchases".
