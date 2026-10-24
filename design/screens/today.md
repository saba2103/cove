# Today — `lib/features/today/today_screen.dart`

Reference: `today.png` — **version 02, the paper.** (The earlier `today.png` showed version
01 and contradicted this spec. Both were in the prototype behind a toggle; 02 was chosen on
25 Oct 2026.)

Allow-list budget: 34 · Overflow backlog: `today_screen.cover` — the last entry on it.

The home screen. The one page judged on how it feels.

## Order
1. **Header** — screen-local, NOT `CovePageHeader` (see below): the home name with a chevron (opens the home switcher), weather chip, notification bell, the viewer's avatar.
2. Date line — `CoveSectionLabel.page` with the city as its right-hand readout.
3. Greeting — `CoveType.greeting`: "Good morning," in italic `accent.tint`, then the name in roman `text.primary`.
4. `CoveMetricGrid` — spent today, events, habits, the list. Single column below `CoveSize.compactThreshold`.
5. **On the calendar** — `CoveTicket`, carousel when more than one.
6. **Habits** — `CoveHabitCard` in a `CoveCarousel`.
7. **Spent today** — one `CoveReceipt` holding the day's purchases, with the split bar.
8. **The list** — one `CoveNote` with the open items.
9. **Due tomorrow** — `CoveVoucher`s in a `CoveCarousel`.
10. **The Letter** — `CoveLetter` over `composeDayLetter()`.
11. Footer — "Two lives. One calm home." italic, then the encryption line.

Each section head is `CoveSectionLabel.page` with a count readout and a ghost
`CoveRoundButton` add on the right.

## The header is screen-local, deliberately
It holds a tappable title-with-chevron, a weather chip and an avatar — none of which are
`CoveRoundButton`s, and `CovePageHeader.actions` is typed to `CoveRoundButton` on purpose.
Only Today has this header, so by the rule of two it is not a primitive. Build it as
`_TodayHeader` in this file, composed only of existing primitives: `CoveAvatar.header` for
the viewer (never `both`), `CoveRoundButton` ghost for the bell with an 8dp `(literal)`
`accent.fill` unread dot, and the weather badge restyled with tokens. **Do not modify
`CovePageHeader` to accommodate it.**

## Rules
- Slips are the **ink** variant in dark mode and **paper** in light mode.
- Tapping an item opens that item; tapping elsewhere in a section opens the section's page.
- No "Both can see it" captions.
- The **Recent activity** section in today's app is removed from this screen. Activity is
  reached from the bell. That is a decided design change, not an accidental deletion — note
  it in the changelog.
- "Due tomorrow" reads the existing commitments provider. No new data model.
- Bottom padding is `CoveSpace.barClearance` plus the bottom inset.
