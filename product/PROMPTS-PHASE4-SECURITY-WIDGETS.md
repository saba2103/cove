# Phase 4.3 — invites and keys · Phase 4.4 — widgets

Specs: `design/specs/17-invite-and-keys.md`, `design/specs/18-widgets.md`.
Widget references: `design/screens/widgets/`.

Rules for every prompt: no Drift schema change; never print a key or a payload; never write to
the database from a background isolate except as 18-widgets.md § Ticking allows; tool/check.sh
must exit 0.

---

## 4.3a — what's on the server (read-only)

````
Using the Supabase CLI on this Mac (project dklecfmiccevnkhxnwmo), run read-only queries only,
and write the results to build/security_check.md (gitignored). Don't commit it.
- pairing_codes: total rows; rows past expires_at; oldest and newest created time; whether
  the payload column is non-empty for each (yes/no only).
- homes: the ids and updated time of every row whose description starts with `pairing:`.
- Never select or print payload or description contents.
Then stop. Change nothing.
````

## 4.3b — no more invented keys

````
To design/specs/17-invite-and-keys.md §3.
Remove the key self-heal from SyncEngineImpl.start and from the join path near line 360. If the
active home has no key on this phone, sync doesn't start and the app shows the full-screen
"This phone doesn't have your home's key" state, with Restore from backup (the existing Drive
restore) and Join again with a code.
Tests:
- a missing key → no key generated, no sync started, the state shown
- a restore puts the key back → sync starts
- creating a new home still generates its key
Commit as `fix(sync): a missing key means restore, never a new key (4.3b)`.
````

## 4.3c — the approved-code invite

````
To design/specs/17-invite-and-keys.md §1, §2, §4.
1. App: the keyless code, the join request with a fresh keypair, the two matching words
   (include the 2,048-word list as a Dart const, and test the derivation), the approval sheet
   on the inviter's phone, the sealed payload, and cleanup. The QR path no longer calls
   createPairingCode for its payload. Remove the homes.description fallback entirely.
2. Server: a migration in supabase/migrations/ with the table and RLS changes from §4, plus SQL
   that deletes every pairing_codes row and clears `pairing:` descriptions. **Don't run it.**
3. Tests:
   - end to end with two fake clients and a fake server: A creates, B requests, the words
     match, A approves, B opens the sealed key
   - a swapped public key → the words differ
   - Not them → B never gets a key
   - an expired code → rejected
   - a fourth request on a code → rejected
   - nothing written to the server ever contains the key (scan every write in the fake)
Commit as `feat(home): approved-code invite; the server never sees the key (4.3c)`.
````

## 4.3d — apply on the server (only after Saba approves the SQL)

````
Show Saba the migration SQL in full. After he says go:
`supabase db push` for project dklecfmiccevnkhxnwmo. Then re-run the 4.3a queries and append the
result to build/security_check.md: zero pairing_codes rows with a payload column, and zero
`pairing:` descriptions.
````

---

## 4.4a — widget plumbing and the Ledger

````
Read design/specs/18-widgets.md in full and look at every image in design/screens/widgets/.
1. Add home_widget. Register four Android widget providers (Arc 2×2, Slip 4×2, Ledger 4×2,
   Day Sheet 4×4) with previews and minimum sizes. Wire Flutter bitmap rendering, the
   30-minute WorkManager refresh, and re-rendering from the app whenever data affecting a
   widget changes.
2. Build the Ledger (read-only), light and dark following the system. The figures come from the
   same providers Expenses and Commitments use. Don't compute them a second time.
3. Goldens of the Ledger's Flutter widget: dark, light, empty month, first month (no
   comparison line), no commitments.
Commit as `feat(widgets): plumbing and the Ledger (4.4a)`.
````

## 4.4b — the Day Arc

````
The Day Arc, read-only, per §1, with routines, events, habit rim dots, the now hairline, and the
centre showing the current or next thing. Goldens across a day (morning, midday, night, empty
day), dark and light. Commit as `feat(widgets): the Day Arc (4.4b)`.
````

## 4.4c — the Slip, and ticking from a widget

````
Per §2 and § Ticking. This is the risky one, so follow § Ticking exactly.
1. The Slip, with list choice when it's added, defaulting to the most-used list.
2. The intent log, app-alive forwarding (with a receipt, like 3.14c), and the background apply
   path on its own writable connection with the schema-version check.
3. Tests against a real temporary SQLite file:
   - the app alive → the app applies it, the background opens no connection
   - the app dead → the background applies it once; the outbox has exactly one event
   - the app starting while the background writes → both succeed, nothing lost, and migrations
     still run
   - a crash after the write but before "applied" is marked → app start doesn't apply it twice
   - a schema-version mismatch → the background refuses; the app applies it on start
   - ticking an already-ticked item → no write
Commit as `feat(widgets): the Slip, with safe ticks from the home screen (4.4c)`.
````

## 4.4d — the Day Sheet

````
Per §4, reusing the 4.4c tick path for tasks and your own habits. Partner habit dots are not
tappable; event and routine lines open the app. Goldens: a full day, an empty day, dark and
light. Commit as `feat(widgets): the Day Sheet (4.4d)`.
````
