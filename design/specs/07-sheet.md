# CoveSheet

Every bottom sheet: add, detail, pickers.

| | |
|---|---|
| Top radius | `CoveRadius.sheet` (32) |
| Bottom radius | `CoveRadius.device` (40) where it meets the screen edge |
| Fill | `surface.sheet` |
| Padding | `CoveSpace.gutter` horizontal, `CoveSpace.md` top, `CoveSpace.lg` bottom + safe area |
| Grab handle | 36 × 4 `(literal)`, `line.strong`, centred, `CoveSpace.md` below |
| Scrim | `surface.scrim` |
| Motion | `CoveMotion.sheet` with `CoveMotion.easing`; `CoveMotion.s(context)` so Reduce Motion collapses it |

## Rules

- `CoveRadius.device` is a stand-in for the hardware corner. Read it from the OS where
  you can; never invent a different number.
- A sheet over a sheet uses the same radii. The 26-vs-24 difference that used to exist was
  invisible alone and obvious when they stacked.
- Dismissable by drag and by scrim tap, unless the flow is mid-commit.
