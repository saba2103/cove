# Phase 3.14 — notifications, as a sequence

To `design/specs/15-notifications.md`. Four prompts, in order. Read the spec's opening
section first: this changes how notifications are delivered, not just their wording.

**The order of the rollout matters.** The app changes (3.14a–c) must be on **both phones**
before the server change (3.14d) is deployed. Today's app does nothing with a data-only
message, so deploying the server first would make notifications stop on any phone that
hasn't been updated yet.

Rules for every prompt below:
- No schema change. Don't change what any event's payload contains.
- Partner name from the partner profile; home name from the home. No literals.
- `clock.now()` everywhere; tests use a fixed clock.

---

## 3.14a — the copy, as data

````
Read design/specs/15-notifications.md in full.

Build lib/features/notifications/notification_copy.dart, a pure function with no
Flutter, plugins or providers:

  NotificationCopy? composeNotification(DecryptedEvent event, NotificationContext ctx)

It returns null when the event is never sent (§3); otherwise a title, a body, the batch key
(the list id, for list events; null otherwise), a group key (the module), and the line this
event contributes to a batch (`+ item` / `✓ item` / `− item`).

`NotificationContext` carries what the copy needs and the event doesn't: partner name, home
name, currency symbol, today, the viewer's user id, unticked items left in the list, the
habit's current streak, and whether the event was created by the viewer. The caller fills it
in. This function does no lookups.

Tests (test/features/notifications/notification_copy_test.dart), table-driven, one row per
line of §2 and one per bullet of §3. Expected strings copied from the spec. Include:
- `five left` vs `nothing left`, and `eleven left` → `11 left`
- a streak of 1 (no "days running") vs 23 (`Twenty-three days running.` → number words up to
  99, digits beyond)
- `{when}` for an event two days out, eight days out, and all-day
- an EMI's last-instalment month
- `subscription_cancelled` says "paused"
- a removal returns a ride-along line but is marked as unable to start a card
- an event created by the viewer → null

Replace NotificationFormatter's use for push copy with this. Keep NotificationFormatter only if
the in-app Activity list still uses it, and say whether it does. tool/check.sh must exit 0.
Commit as `feat(notifications): the Quiet Ledger copy, tested as data (3.14a)`.
````

## 3.14b — batching, as data

````
To design/specs/15-notifications.md §5.

Build lib/features/notifications/notification_batcher.dart, a pure state machine with no
plugins:

  BatchDecision offer(NotificationCopy copy, DateTime now)

The decision is: show new (id), replace (same id, with the combined body and lines), ride
along (removal into an open batch → replace), or drop (a removal with no open batch). Batches
are keyed by list id. The window is 90s from the batch's first change. `closeBatch(listId)` is
for when the user opens that list. State must survive being rebuilt from a small JSON blob,
because the background handler runs in a fresh isolate each time. Provide toJson/fromJson and
keep it in local preferences.

Tests with a fixed clock:
- one add → plain card
- add then tick at +30s → the same id, `Ancy made two changes`, two lines in order
- four changes including a removal → `four changes`, four lines
- a change at +91s → a new card with a new id
- a removal with no open batch → drop
- Groceries and Coorg trip interleaved → two independent batches
- closeBatch → the next change starts fresh
- state round-trips through JSON mid-batch

tool/check.sh must exit 0. Commit as `feat(notifications): 90-second batching per list (3.14b)`.
````

## 3.14c — the pipeline on the phone

````
Wire it together, to design/specs/15-notifications.md §4–§6.

1. One path, used by both the foreground handler (onMessage) and the background handler
   (`_firebaseMessagingBackgroundHandler` in main.dart, which today only logs):
   data message → fetch and decrypt that event → build NotificationContext from the local
   database (read only) → composeNotification → NotificationBatcher → show, replace or drop
   as a local notification.
2. The background handler runs in its own isolate. Open what it needs there: Firebase, the
   Supabase session, the home key from secure storage, and the Drift database. **Read-only:
   it must never write to the database or the outbox.** The app syncs as usual when it opens.
   If the main isolate is alive at the same time, make sure the two can't corrupt each other.
   Explain how you guaranteed that.
3. An 8-second budget. On any failure or timeout, show the fallback (§4) and log the reason
   (no content).
4. While the app's old messages are still arriving (they carry a `notification` block, so
   Android shows them itself), don't show a second copy. Only act on data-only messages.
5. Rendering per §6: InboxStyle for batches, onlyAlertOnce on replace, a group key per
   module, and the new monochrome `ic_stat_cove` (make it from the Cove mark; white on
   transparent; 24dp in mdpi through xxxhdpi) tinted `accent.fill`.
6. Opening a list in the app calls closeBatch for it and cancels its card.
7. Taps route through the existing notification dispatcher; a batch opens the list.
8. Check-in reminders use the §2 copy.

Tests with fakes for FCM, the decrypt step and the plugin:
- the happy path for one expense
- a decrypt failure → the fallback within the budget
- a timeout → the fallback
- a list batch across two background invocations (state from preferences)
- a message with a notification block → nothing shown by us
- nothing in the pipeline writes to the database (assert on the DB)

Don't touch supabase/. tool/check.sh must exit 0.
Commit as `feat(notifications): decrypt, compose, batch and show on the phone (3.14c)`.
````

## 3.14d — the server sends data only

````
Change supabase/functions/notify-partner/index.ts so the FCM v1 message is data-only:
- no `notification` block, and no title or body anywhere in the message
- data: home_id, event_id, event_type, module
- Android priority HIGH, so it is delivered promptly while the phone sleeps
- no collapse key (batching is the phone's job now)

Keep the server-side silent filter, but make it match the spec's §3 wherever event_type alone
decides (for example expense_updated, list_renamed, routine_*). Events that need the content
(a toggle to done vs not done) still go to the phone, which decides.

**Don't deploy it.** Add a "Deploying notify-partner" section to supabase/README.md that
covers:
- the prerequisite: both phones already run a build that includes 3.14c
- the deploy command
- how to roll back (redeploy the previous version from git, naming the commit)
- a two-phone check: add an expense and three grocery items on one phone, and see one
  expense card and one batched Groceries card on the other

tool/check.sh must exit 0.
Commit as `feat(notify-partner): data-only push; the phone writes the copy (3.14d)`.
````
