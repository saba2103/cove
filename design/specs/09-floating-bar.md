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
| Icon | 20 `(literal)` · Label `CoveType.barLabel` (11sp / w600 / lineHeight 14 / letterSpacing 0) |
| Label threshold | 360dp `(literal)` — below 360dp viewport width the bar renders icons only (no seat labels) in every state |
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
- Labels are measured, not guessed: at 320dp (`cover`) a detached 3-seat row gives each seat
  47.3dp of which the label gets 39.3dp (once the 56dp detached Home pill, 56dp `[+]` orb,
  two 8dp gaps, and 10dp pill padding/border are deducted from the 280dp bar footprint), so
  below 360dp the bar renders icons only. Above 360dp (`phone` 390dp gives 70.7dp seat /
  62.7dp label; 411dp gives 77.7dp seat / 69.7dp label), "Commitments" (76.4dp in
  `CoveType.barLabel`) still does not fit at 390dp or 411dp — **the bar says "Bills"**.
- Activity is not in the bar. It is the notification icon in the Today header.
