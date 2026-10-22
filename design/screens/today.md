# Today — `lib/features/today/today_screen.dart`

Reference: `today.png` · Allow-list budget: 34 · Overflow backlog: `today_screen.cover`

The home screen. Visual, not a list of lists — this is the one page judged on how it feels.

## Order
1. `CovePageHeader` — home name left (opens Our home), weather, notifications, profile avatar right. The profile avatar is **the user's own**, never `both`.
2. Date line, then a Bodoni greeting: "Good morning, Saba."
3. `CoveMetricCard` grid — spent today, events, habits, the list.
4. Sections, each with `CoveSectionLabel` + a title row carrying an add action on the right: Today (events) · Habits · Spent · The list · Renewing soon.
5. **The Letter** — a prose paragraph describing the day, in Bodoni, with figures and nouns underlined as links.
6. Footer: "Two lives. One calm home." + the encryption line.

## Rules
- Every record renders as **its kind's object**, not a generic row: expenses as receipt slips, events as tickets, habits as rings, tasks as ruled notes, commitments as stamped vouchers. Use `CoveRow` only where the reference shows a plain row.
- Where a section has several items, it is a **carousel**, not a stack — the page is long enough.
- **The Letter is rewritten on every load.** Never cache it, never show a timestamp, never claim it was "written" at a time.
- Tapping an item opens that item. Tapping anywhere else in a section opens that section's page.
- No "Both can see it" captions anywhere on this screen.
