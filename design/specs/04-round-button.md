# CoveRoundButton

Every circular action in the app. Header actions, the add button, the back button,
sheet close, stepper chevrons.

| | |
|---|---|
| Drawn diameter | `CoveSize.buttonRound` (40) |
| Tap target | `CoveSize.hit` (48) — an invisible expansion, never a bigger circle |
| Icon | 20 `(literal)`, 1.7 stroke |
| Gold variant | fill `accent.fill`, icon `text.onAccent` |
| Ghost variant | transparent fill, 1dp `line.strong` border, icon `text.secondary` |
| Press | `accent.wash` overlay, `CoveMotion.quick` |

## Rules

- **Gold means add.** One gold button per screen, maximum. Everything else is ghost.
- The drawn circle is 40 and the target is 48. Do not grow the circle to meet the target
  or shrink the target to match the circle.
- Inline stepper chevrons inside a row or day header are a smaller sibling at 24
  `(literal)` — they are not header actions and do not carry the 48 target.
