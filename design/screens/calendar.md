# Calendar — `lib/features/calendar/calendar_screen.dart` + `views/calendar_agenda_view.dart`

Reference: `calendar.png` · Budget: 4 + 33 · Overflow: `calendar_screen.cover`

Day view only. **There is no month view** — it was folded into this screen and must not come back.

## Order
1. `CovePageHeader` — month name + year, chevrons for month switching, gold add.
2. Date strip — the selected month's dates only, horizontally scrollable, pips under days that have content.
3. Selected day line: "Wednesday, Oct 21 · today".
4. `CoveMetricCard` row — spent, events, habits, the list.
5. Sections in fixed order: Events → Habits → Spent → The list.
6. Commitments due, given prominence — this is where renewals are noticed.

## Rules
- The date strip shows **only the selected month**. Switching months is the chevrons, not scrolling past the boundary.
- A task with no date appears on the day it was **added**; when ticked it also appears on the day it was **struck**.
- Section order never changes, even when a section is empty — an empty section shows its label and a quiet line.
