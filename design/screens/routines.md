# Routines — `lib/features/routines/routine_screen.dart`

Reference: `routines.png` · Budget: 8

A routine is **the shape of a day**, not a habit. Habits are rings; routines are bands on a time strip. Never merge the two.

## Order
1. `CovePageHeader` — "Routines", gold add.
2. Filter chips: Everyday · Weekdays · Weekend.
3. Two-person legend.
4. The day canvas — a dusk-to-dawn strip with routine bands laid across it, yours on the left and your partner's on the right, with a NOW marker.

## Rules
- Bands are positioned by real time, not by order in a list.
- The sky behind the strip shifts with the hour — that gradient is part of the component, not decoration to drop.
