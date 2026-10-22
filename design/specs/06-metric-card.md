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
- Two per row at phone width. At `CoveSize.maxContent` and above the grid does not grow
  past two — it centres.
