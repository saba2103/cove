# CoveRow

The most repeated element in the app. A 3px drift here reads as a change of rhythm
between pages even when no single row looks wrong.

| | |
|---|---|
| Height | `CoveSize.row` (52) — the token is the HEIGHT; vertical padding is derived as `(row − content) / 2` |
| Horizontal padding | `CoveSpace.hitPlate` (12) |
| Negative margin | `−CoveSpace.hitPlate`, so the pressed/hover plate bleeds past the text to the gutter edge |
| Plate radius | `CoveRadius.inline` |
| Leading avatar | `CoveSize.avatarRow` (28) |
| Gap, avatar → text | `CoveSpace.md` |
| Title | `CoveType.rowTitle` in `text.primary` |
| Sub-line | `CoveType.rowSub` in `text.tertiary` |
| Trailing amount | `CoveType.cardFigure` in `text.primary`, Libre Bodoni |
| Divider | `line.hairline`, inset to the text edge, never under the last row |

## Rules

- The hit plate is what makes a row feel pressable without a visible container. Do not
  substitute a filled card.
- **Money sits in the right margin as a Bodoni figure.** Never a chip, never coloured by
  default — colour on an amount means something specific (`money.more` / `money.less`)
  and must always be accompanied by a sign or a word.
- A row with no avatar keeps the same height; the text simply starts at the gutter.
- Tap target is the whole row, not the text.
