# 18 — Home-screen widgets (Android)

From *Cove, Put Together* · On the home screen. Reference images:
`design/screens/widgets/{home,arc,slip,led,sheet}-{dark,light}.png`.

Four widgets, each one of the app's own objects shrunk to answer one question, read in under
a second. Bodoni (Libre Bodoni) for every figure, house caps for section heads, the two
person avatars for who added what, **one gold per widget, nothing red**.

## Rendering

- `home_widget` + Android App Widgets. RemoteViews can't draw these, so each widget is a
  Flutter-rendered bitmap (`HomeWidget.renderFlutterWidget`). Interactive rows are
  transparent RemoteViews hit areas laid over the bitmap, at the same positions.
- **Theme follows the system** (a widget sits on the wallpaper, not inside the app). Dark:
  the ink card. Light: the paper card. Both semi-transparent over the wallpaper. Android
  can't blur the wallpaper, so the card is a solid fill at about 88% opacity with the accent
  hairline.
- **When it refreshes:** whenever the app commits a change that affects a widget (the app
  re-renders it), after a widget tick, and every 30 minutes via WorkManager. The Day Arc's
  "now" hairline moves on each refresh. Never more than every 15 minutes in the background.
- **Privacy:** never show another person's private records. The viewer's own private
  expenses count in their own figures only where the app's screens already count them.
- **Empty states** use the first-run voice, one line: "Nothing booked today", "Groceries is
  empty", "No money has moved this month". No sample data.

## The four widgets

**1. Day Arc · 2×2.** A 24-hour ring. Today's routine bands and events are arcs on it, in
gold at two strengths (booked solid; tentative or solo-partner fainter). The hairline is
now. Habit dots sit on the rim at their times: filled when kept, outlined when not. The centre
shows the next or current thing: time in Bodoni (`1:30`), title under it.
**Tap:** opens Calendar · Day.

**2. The Slip · 4×2.** One list (the user picks which when adding the widget; default the
most-used list). Header: list name in display face, `{n} OPEN` caps on the right. The first
three open items, each with a checkbox, title and the adder's avatar. Foot: `+{n} more ·
tap to tick`. **Tap a row:** ticks it (§ Ticking). **Tap the header or foot:** opens that
list.

**3. The Ledger · 4×2.** Left: `SHARED THIS MONTH` caps; the total in Bodoni; a line
comparing to the same point last month (`₹4,120 ahead of September by this point · 26 days
left`, or `behind`, or nothing in the first month); a split bar of who paid the shared
total (`You ₹28,940` / `{partner} ₹23,240`). It reads as who carried the month, never as a
debt. Right column: `RENEWS`, the next commitment due, when (`Tomorrow` / weekday / date),
and its amount. **Tap:** opens Expenses (left) or that commitment (right).

**4. Day Sheet · 4×4.** A printed page. The masthead: the day number in Bodoni, the month in
italic, then the weekday caps, the weather line, and the first habit due today. Then today's
lines in time order (events, routines, tasks due today), each with the time, title, and a
second line of who and context. Lines that are over are dimmed. The base: `HABITS` with one
dot per habit due today, and `TODAY` with today's spend in Bodoni.
**Tap a task line:** ticks it. **Tap a habit dot:** ticks today's check-in, but only for your
own habits. Partner habits are drawn but not tappable. **Tap an event or routine line:**
opens it in the app. Events and routines have no "done" state.

## Ticking from the widget

Saba chose ticks that happen inside the widget without opening the app. This writes to the
database from a background process, so it follows the rules 3.14c learned the hard way:

1. **The tick becomes an intent first.** `{id, kind: list_item | habit_checkin, recordId,
   toDone, at}`, appended to a durable intent log in local preferences *before* anything else.
   The widget re-renders straight away with the tick shown.
2. **If the app is alive** (its port is registered and it sends a receipt within 1 second),
   the app applies the intent through the normal controller, exactly like a tick on screen.
3. **If the app isn't alive,** the background isolate applies it through the same controller
   code, on its **own unshared, writable** connection: `busy_timeout 5000`, no migrations,
   and it refuses to run if the file's `user_version` doesn't match the app's `schemaVersion`.
   One transaction for the record and its outbox event. Then it tries a sync push within an
   8-second budget. If the push fails, the outbox entry waits for the app.
4. **Exactly once.** An intent is marked applied in the same flow. On every app start, any
   unapplied intent is applied. Applying is idempotent: if the record is already in the
   wanted state, it's marked applied without writing.
5. **Never a key, never a migration, never a delete** from the background.

## Sizes

Minimum and target cells: Arc 2×2; Slip and Ledger 4×2; Day Sheet 4×4. On resize, content
reflows; it never scales text down below the type scale. At 3-cell width, the Slip shows two
rows and the Ledger hides its right column.
