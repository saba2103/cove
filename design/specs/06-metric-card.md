# CoveMetricCard

The small stat tiles under a page header.

| | |
|---|---|
| Radius | `CoveRadius.card` (20) |
| Fill | `surface.card` |
| Border | 1dp `line.hairline` |
| Padding | `CoveSpace.md` all round |
| Label | `CoveType.capsCard` in `text.tertiary` |
| Value | `CoveType.cardFigure` in `accent.tint`, Libre Bodoni |
| Sub-line | `CoveType.rowSub` in `text.tertiary` |
| Grid gap | `CoveSpace.md` |

## Rules

- **16 was four different radii before the audit** — 12 on Calendar, 14 on Expenses, 15 on
  Today. It is `CoveRadius.card` everywhere now, with no screen-specific variant.
- No radial glow, no gradient fill. The card is flat.
- A metric is a fact plus its context: the value, and one line saying what it is measured
  against. A value alone is not a metric.
- Two per row at phone width (`≥ CoveSize.compactThreshold`, 360dp). Below
  `CoveSize.compactThreshold` (360dp), the grid collapses to a **single column**: at 320dp
  (`cover`) a 2-column grid gives each card 134dp outer width and only 108dp inner content
  width (`(320 − 40 gutter − 12 gap) / 2 − 24 padding − 2 border`), whereas `₹85,000` in
  `CoveType.cardFigure` (28sp Libre Bodoni) measures 110.2dp and wraps mid-number to
  `₹85,00 / 0`, and `"1 overdue"` (117.1dp) wraps to two lines. A single column at 320dp
  gives each card 280dp outer width and **254dp** inner content width. Figures never use
  `FittedBox`/`scaleDown` or `TextOverflow.ellipsis`.
- At `CoveSize.maxContent` and above the grid does not grow past two — it centres.
