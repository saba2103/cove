# 15 — Notifications: the Quiet Ledger

From *Cove, Put Together* · Notifications ("How Cove Speaks"). Only Android ships, so only
the Android rendering matters. What is ours is **the copy and the timing**; the system draws
everything else (app name, chevron, time, the tinted icon).

## Why this is more than a copy change

Today the server (`supabase/functions/notify-partner`) sends an FCM **notification**
message with generic text it writes itself, such as "Ancy • Expenses / Ancy logged a new
expenditure". The server can't do better, because it can't read the event: everything is
end-to-end encrypted. Only the partner's phone can decrypt "Coffee beans — dark roast" or
"₹820".

So the design needs the server to send a **data-only** message (`home_id`, `event_id`,
`event_type`, `module`, and nothing readable). The phone then decrypts that event, writes the
copy, decides whether it is sent at all, batches it, and shows it as a local notification.
When anything in that chain fails, the phone falls back to one honest line (§4). It never
falls back to silence.

## 1. Voice

- **Subject first.** The title is the thing that changed: the list name, the habit name,
  the event title, or the section (`Expenses`, `Commitments`, `Habits`, `Shared lists`).
  Never `Ancy · Expenses`.
- **The body is one clause**, beginning with the partner's name from the partner profile.
- Record titles are **verbatim**: no lowercasing, no paraphrasing.
- Money is plain body text in the system font, formatted with the home's currency
  (`₹24,000`). No emoji, no exclamation marks.
- Numbers of things are words up to ten (`five left`, `two changes`), digits after.

## 2. What is sent

| Event | Title | Body |
|---|---|---|
| `list_item_added` | list name | `Ancy added {item}` |
| `list_item_toggled` → done | list name | `Ancy ticked off {item} — {n} left` (n = unticked items left in that list; `nothing left` at 0) |
| `list_created` | `Shared lists` | `Ancy started a new list — {name}` |
| `expense_logged` | `Expenses` | `Ancy logged {amount} for {title}` |
| `habit_checkin_toggled` → kept | habit name | `Ancy kept it.` + ` {N} days running.` when that habit's current streak is 2 or more |
| `habit_created` | `Habits` | `Ancy added a habit — {name}` |
| `calendar_event_added` | event title | `Ancy put it in for {when}` |
| `calendar_event_updated`, date or time changed | event title | `Ancy moved it to {when}` |
| `calendar_event_deleted` | event title | `Ancy cancelled it — {day}` |
| `subscription_added` | `Commitments` | `Ancy added {name} — {amount} {a month / a year / every 3 months}` |
| `subscription_added`, EMI | `Commitments` | `Ancy added an EMI — {amount} a month to {Mon YYYY of the last instalment}` |
| `subscription_cancelled` | `Commitments` | `Ancy paused {name} — {amount} {a month…} back` (the app calls it Pause, so the notification does too) |
| `member_joined` | the home's name | `Ancy joined. You are both in.` |
| check-in reminder (local, scheduled) | the reminder's label, else `Evening` | `A quiet moment, together.` |

`{when}`: `Saturday, 7:30 PM` within the next six days. Further out: `Sat 14 Nov, 7:30 PM`.
All-day events have no time. `{day}` is the same without the time.

## 3. What is never sent

Written in the same voice for the in-app Activity list, but never put on the lock screen:

- An item put back on a list (toggled to not done) · an item edited · a list renamed,
  archived, deleted or reordered · completed items cleared
- An expense changed or removed
- A habit unchecked · a habit cheered ("saw that you kept it") · a habit edited or removed
- A commitment changed, restarted or deleted
- A profile, name, avatar, currency, budget, anniversary or home setting changed
- Routines, roadmap items and check-in reminder edits, in any form
- Anything about a private record. Private records never sync, so this should be impossible;
  assert it anyway.
- Anything the user did themselves on another device

**A removal never starts a card.** If a card for that same list is already out and still
inside its window (§5), the removal rides along as a `−` line inside it. Otherwise it stays
silent.

## 4. The fallback

If the phone can't produce the copy within **8 seconds** — no key, no session, decrypt
failed, event not found — it shows:

| Title | Body |
|---|---|
| the home's name | `Ancy made a change. Open to see it.` |

Tapping it opens Activity. The fallback is logged with its reason (no content) so it can be
counted in testing.

## 5. Batching

- **The batch key is the list**, not the event type. An add and a tick on Groceries merge.
  Groceries and Coorg trip never do. Only list events batch. Every other event is its own card.
- **The window is 90 seconds** from the first change in the batch.
- A single change is a plain card (§2). The second change inside the window **replaces** that
  same notification (same id and tag) with:
  - title: list name
  - body: `Ancy made {two} changes`
  - one line per change, oldest first: `+ Coffee beans — dark roast` · `✓ Curd, 500g` ·
    `− Dishwasher tablets`. This is Android's InboxStyle, with the lines under the body.
- Replacements don't buzz again (`onlyAlertOnce`).
- After the window closes, the next change starts a new card.
- If the user opens that list in the app, its batch closes and the card is cancelled.

## 6. Rendering (Android)

- Channel `cove_partner_activity`, as today. Group by module so the system stacks Lists,
  Expenses and so on.
- Small icon: a monochrome silhouette of the Cove mark (`ic_stat_cove`, white on
  transparent), tinted with `accent.fill`. Today the launcher icon is used, which Android
  turns into a white square.
- Tapping a card opens the record's detail sheet. The existing notification dispatcher
  already routes these. A batch opens the list.
