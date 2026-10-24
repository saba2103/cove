# CoveCarousel — `lib/core/widgets/cove_carousel.dart`

Several objects of one kind, side by side, so a long page stays short.

| | |
|---|---|
| Item width | 82% of the content width `(literal ratio)` — the next item peeks |
| Gap | `CoveSpace.md` |
| Leading inset | `CoveSpace.gutter`, so the first item aligns with the page text |
| Snap | to item |
| Pager | below, `CoveSpace.md` gap. Dots 6×6dp `(literal)` in `line.strong`; the active dot 20×6dp `(literal)` in `accent.fill`, pill radius; `CoveSpace.sm` between |

## Rules
- **One item renders full-width with no pager.** A carousel of one is not a carousel.
- Pager dots are not tap targets. Swiping and screen-reader "next" are the navigation.
- Respect `CoveMotion` and Reduce Motion for the snap animation.
- Announce position to assistive tech: "2 of 3".
