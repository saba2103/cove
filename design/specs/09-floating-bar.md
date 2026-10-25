# CoveFloatingBar

The navigation. Floats above the content rather than sitting in a well.

| | |
|---|---|
| Height | 56 `(literal)` |
| Radius | `CoveRadius.pill` (pill & detached Home circle), `CoveRadius.card` (More card) |
| Fill | `surface.card` at 92% + blur behind |
| Border | `accent.fill` at 14%, 1dp `(literal)` hairline on the pill, detached Home circle, and More card |
| Shadow | `elevationBar` |
| Side margin | `CoveSpace.gutter` |
| Bottom margin | `CoveSpace.md` + safe area |
| Backdrop fade | 136 `(literal)` tall gradient from transparent (`surface.canvas` at 0%) to `surface.canvas` behind the bar |
| Page clearance | `CoveSpace.barClearance` (112) bottom padding on every scroll view it covers |
| Seat | pill, `CoveSpace.sm` vertical / `CoveSpace.xs` horizontal padding, `CoveSpace.xs` icon→label gap |
| Seat, selected | `accent.wash` fill, `accent.text` icon and label |
| Icon | 20 `(literal)` · Label `CoveType.barLabel` (11sp / w600 / lineHeight 14 / letterSpacing 0) |
| Label threshold | `CoveSize.compactThreshold` (360dp) — below 360dp viewport width the bar renders icons only (no seat labels) in every state |
| Detached Home circle | 56 `(literal)` circle on the left in category modes, `surface.card` at 92% + blur, `accent.fill` at 14% hairline, `elevationBar` shadow, muted icon (`text.secondary`, icon only) |
| Add orb | 56 `(literal)` circle on the right (`CoveSpace.sm` gap from the pill), `accent.fill`, `text.onAccent` |

## Structure

At rest — one pill holding the four destinations (`Home` selected), and the gold `+` orb as a separate circle to the right of the pill with a gap of `CoveSpace.sm`. The `+` is never inside the pill:

```
[ Home  ·  Money  ·  Tasks  ·  Calendar ]   ( + )
```

In a category — `Home` becomes its own 56dp circle on the left (card fill with muted icon, same accent hairline and bar shadow as the pill), then `CoveSpace.sm` gap, then the pill with that category's seats, then `CoveSpace.sm` gap, then the gold `+` orb on the right:

- **Money** → `( Home )   [ Expenses · Bills · More ]   ( + )`
- **Tasks** → `( Home )   [ Todo · Habits ]   ( + )`
- **Calendar** → `( Home )   [ Day · Routines ]   ( + )`

**More (Money)** — a card that lifts above the bar (`CoveSpace.sm` gap), full bar width, radius `CoveRadius.card`, `accent.fill` at 14% hairline and `elevationBar` shadow, one row per destination (`icon`, `label`, `chevron`): `EMIs`, `The year`. Tapping outside closes it.

## Rules

- **The `+` orb is always a separate circle on the right and never inside the pill.** It opens the Add flow.
- A category with more than three children puts the third seat as **More**, lifting a full-bar-width card above the bar. Tapping outside closes it.
- The page dissolves under the bar via a 136dp gradient from transparent to `surface.canvas` rather than being cut abruptly by the floating chrome.
- Labels are measured, not guessed: at 320dp (`cover`, 280dp bar footprint) the 4-seat rest pill (`280 - 56 - 8 = 216dp`, `206dp` inner) gives each seat 51.5dp (43.5dp inner), and a detached 3-seat category pill (`280 - 56 - 8 - 56 - 8 = 152dp`, `142dp` inner) gives each seat 47.3dp of which the label gets 39.3dp — so below 360dp the bar renders icons only and all four rest seats fit cleanly at 320dp. Above 360dp (`phone` 390dp gives 70.7dp seat / 62.7dp label in Money; 411dp gives 77.7dp seat / 69.7dp label), "Commitments" (76.4dp in `CoveType.barLabel`) still does not fit at 390dp or 411dp — **the bar says "Bills"**.
- Activity is not in the bar. It is the notification icon in the Today header.
