# The paper objects — `lib/core/widgets/slips/`

Every record in Cove is a physical slip: the voice guide's "shared notebook on the kitchen
counter", made literal. One object per kind, built once, used in three places:

| Used in | Variant |
|---|---|
| Today (dark mode) | **ink** — the slip cut from the app green |
| Today (light mode) | **paper** |
| Detail sheets, both modes | **paper** |
| Add flow review step, both modes | **paper** |

The variant is chosen by the CALLER, never inferred from brightness inside the widget.
`enum CoveSlipVariant { paper, ink }`.

All numbers are device scale. `(literal)` marks a value no token covers.

## The shared frame — `CoveSlip`

| | paper | ink |
|---|---|---|
| Fill | gradient 168°: `paper.from` → `paper.via` 46% → `paper.to` | gradient 168°: `slip.ink.from` → `slip.ink.via` 46% → `slip.ink.to` |
| Title / body | `paper.ink` | `text.primary` |
| Secondary | `paper.ink2` | `text.secondary` |
| Tertiary | `paper.ink3` | **`slip.ink.text3`** — NOT `text.tertiary`, which fails at 3.63:1 on ink |
| Accent | `paper.accent` | `accent.text` |
| Alert words | `status.alertText` | **`slip.ink.alertText`** — `status.alertText` fails at 3.61:1 on ink |
| Rules / dashes | `paper.rule` | `line.strong` |
| Edge | `paper.edge` hairline + `elevationPaper`, light mode only | none |
| Radius | `CoveRadius.card` | `CoveRadius.card` |
| Inner padding | `CoveSpace.gutter` | same |

Every slip opens with a caps line in `CoveType.capsSlip` — `COVE · RECEIPT`, `COVE · PLAN`,
`COVE · HABIT`, `COVE · GROCERY LIST`, `COVE · EVERY MONTH` — then a title in
`CoveType.slipTitle`.

## The five objects Today needs

### CoveTicket — an event
- Main body left: caps line, title, date line, "Both of you" / owner line.
- **Stub** on the right, 112 `(literal)` wide: caps `STARTS`, the hour in `CoveType.slipFigure`, the meridiem in `capsSlip`.
- Between them a **perforation**: 1dp dashed line (dash 4 / gap 4 `(literal)`) in the rule colour, with a 16dp `(literal)` semicircle notch bitten out at the top and bottom edge.
- A 2dp `(literal)` accent spine down the left edge.

### CoveReceipt — the day's spending, or one expense
- **Torn edges** top and bottom: a zigzag, teeth 8dp wide × 6dp tall `(literal)`. Radius 0 — torn paper has no corners.
- Centred header: caps line, the day in `slipTitle`, a caps sub-line.
- Dashed rule, then line items as rows: avatar (`CoveAvatar.inline`), title + sub-line, amount right in `CoveType.readout`. Row hover plate radius 8 `(literal)`.
- Dashed rule, `TOTAL` caps left, total right in `CoveType.slipFigure`.
- **Split bar**: the viewer's share in `accent.fill`, the partner's in the rule colour, 4dp `(literal)` tall, pill radius — with both names and amounts written beside it. Colour never carries the split alone.
- **Barcode** strip, 24dp `(literal)` tall, then the date in caps. The bar pattern must be **derived deterministically from the record id** — never random per render, or every golden changes every run.

### CoveHabitCard — a habit, compact
- Caps line, title, cadence line ("every day · both of you"), check state top right using `CoveCheckbox`.
- **Streak grid**: the last 21 days as 7 columns × 3 rows. Cells 10dp `(literal)`, gap `CoveSpace.xs`, radius 2 `(literal)`.
  - done → `accent.fill`
  - missed → 1dp outline in **`slip.ink.mark`** on ink (3.63:1) / `paper.ink3` on paper
  - today → a 1.5dp `accent.fill` ring around the cell
- Right of the grid: the run in `slipFigure` with `DAYS RUNNING` in caps beneath.
- The grid is supplementary; the run count is the primary fact and is always in text.

### CoveNote — a list, ruled
- Top corners 4 `(literal)`, bottom corners `CoveRadius.card` — the top edge reads as torn from a pad.
- Ruled lines every 32dp `(literal)` in the rule colour, under the caps line and every item.
- Items: `CoveCheckbox` + title in `slipTitle`, "added by Ancy" beneath in tertiary. Done items strike through and drop to secondary.

### CoveVoucher — a commitment
- Perforated **rail** down the left: 1dp dashed line 12dp `(literal)` in from the edge.
- Caps line ("COVE · EVERY MONTH"), title, the amount in `slipFigure` with "a month" in readout.
- **Due circle** top right, 64dp `(literal)`, 1dp dashed `accent.fill` ring: the day number in `slipTitle`, the month in `capsSlip` beneath.
  - The prototype also fits `DUE` inside the circle at 6.5px. **At device scale that is 8.5sp, under the 11sp floor.** Drop `DUE` from inside the circle — the section label already says it.
- Live states (detail sheets): **PAID** stamp — caps, outlined, rotated −8°, in `status.good`; the due circle fades to the rule colour.
- **EMI variant** — the same voucher, **punched**: a grid of N dots for N instalments (48 for a 4-year loan), paid filled, remaining outlined. An EMI counts down; a subscription renews.

## Semantics (WCAG 4.1.2)

Every slip exposes its state as text to assistive tech, not just as drawing:
`"Receipt, Wednesday, total ₹5,631, 3 items"` · `"Voucher, AC instalment, ₹3,974, due 22 October, paid"`
· `"Habit, Morning walk, done today, 23 days running"` · `"EMI, 12 of 48 paid"`.
