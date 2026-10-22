# CoveFloatingBar

The navigation. Floats above the content rather than sitting in a well.

| | |
|---|---|
| Height | 56 `(literal)` |
| Radius | `CoveRadius.pill` |
| Fill | `surface.card` at 92% + blur behind |
| Shadow | `elevationBar` |
| Side margin | `CoveSpace.gutter` |
| Bottom margin | `CoveSpace.md` + safe area |
| Page clearance | `CoveSpace.barClearance` (112) bottom padding on every scroll view it covers |
| Seat | pill, `CoveSpace.sm` vertical / `CoveSpace.xs` horizontal padding, `CoveSpace.xs` icon→label gap |
| Seat, selected | `accent.wash` fill, `accent.text` icon and label |
| Icon | 20 `(literal)` · Label `CoveType.capsCard` without caps transform |
| Centre orb | 56 `(literal)`, `accent.fill`, `text.onAccent` |

## Structure

```
Home   ·   Money   ·   [ + ]   ·   Tasks   ·   Calendar
```

Tapping a category detaches Home and shows that category's three seats in the middle:

- **Money** → Expenses · Commitments · More → (EMIs, Year, Savings)
- **Tasks** → Todo · Habits
- **Calendar** → Day · Routines

## Rules

- **The + is always the centre and never a destination.** It opens the Add flow.
- A category with more than three children puts the third seat as **More**, opening a list.
- Labels are measured, not guessed: a 3-seat row gives each seat 59dp of which the label
  gets 48. "Commitments" does not fit — **the bar says "Bills"**.
- Activity is not in the bar. It is the notification icon in the Today header.
