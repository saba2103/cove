# Phase 4.7 — schema v12: owners and pets

Spec: `design/specs/19-owners-and-pets.md`. This is the only step in v2 that changes the
database on your phones. Each prompt ends with `tool/check.sh` exiting 0 and a commit. **No
install on any phone until 4.7f.**

---

## 4.7a — the migration, proven first

````
Read design/specs/19-owners-and-pets.md in full.

1. Bump schemaVersion 11 → 12. Write the migration additively: three `addColumn`s and two
   `createTable`s, with defaults per §1 (existing events and routine events → `both`, list
   items → NULL), set in the same migration with UPDATE statements. Nothing renamed, nothing
   dropped.
2. `dart run drift_dev schema dump` → drift_schemas/drift_schema_v12.json, and generate
   schema-step migration tests (`drift_dev schema steps` / `generate`).
3. Migration tests:
   - a v11 database **populated with every table filled** (several rows each, including
     private records, EMIs, check-ins, pending outbox events) → migrate → every row of every
     table is identical except the new columns; the new columns hold the defaults; the outbox
     is untouched; `user_version` = 12
   - migrate twice (an idempotent open) → no change
   - a v11 **backup file** (made with the existing backup code from that populated database)
     restored into the v12 app → identical rows, defaults filled
   - a v12 backup into a v11 app is refused with the existing "newer schema" message
4. The background paths: the widget tick (`openBackgroundWritableIfSchemaMatches`) and the
   read-only notification connection both refuse a mismatched `user_version`. Add a test that a
   v11 file and a v12 app make the background refuse, and the app applies the intent after it
   migrates.

No UI. Commit as `feat(db): schema v12 — owners and pets, additive, migration proven (4.7a)`.
````

## 4.7b — a migration test on a copy of your real data (Saba approves first)

````
Only if Saba agrees and gives the backup passphrase for this run, as an environment variable
in his terminal. Never write it to a file, a log or the repo.
1. Download the latest Drive backup with the existing backup code, into build/real_v11/
   (gitignored).
2. Restore it into a temporary v11 database file, then run the v12 migration on it.
3. Report per table: the row count before and after (must be equal), and that the new columns
   hold the defaults. Report counts only, never contents.
4. Delete build/real_v11/ and the temporary files, and confirm they're gone.
Don't commit anything from this step.
````

## 4.7c — owners end to end

````
Per §1:
- owner in the add and update payloads for events, list items and routine events
- apply on receive, where a missing key leaves the stored owner unchanged
- display everywhere an owner shows: the ticket owner line, the Day Sheet second line, the
  Today and Calendar rows, the detail sheets
- the AddDraft and Add flow "Whose is it?" step for event, task (with Either) and routine
- the event, task and routine Edit forms get an owner picker in the same style

Tests:
- an add and edit round trip
- an update from a "v11" payload without owner keeps the owner
- the Add step counts updated (event 6, task 4–5, routine 6)

Commit as `feat(owners): whose is it, for events, tasks and routines (4.7c)`.
````

## 4.7d — the routine lanes

````
Routines screen per design/screens/routines.md and routines.png:
- yours on the left, your partner's on the right
- `both` drawn in solid gold spanning the split
- solo routines as frosted glass in their own lane
- tapping a person in the legend fades the other lane; shared gold stays

Goldens: Everyday, Weekdays, Weekend; one person faded; dark and light; 3 widths.
Commit as `feat(routines): two lanes by owner (4.7d)`.
````

## 4.7e — pets as tags

````
Per §2–§3:
- the tables' controllers and sync events
- Our home → Pets (add, rename, archive)
- the "About a pet?" chips on the owner or who step in Add (only when pets exist)
- tag chips on detail sheets, and ⋯ "Tag a pet…" with a picker sheet
- deleting a record removes its tags through PendingDeleteService
- private records' tags are never synced
- the first-launch safety net that fetches and applies unprojected `pet_*` events

Tests for each, including a private expense with a pet tag → zero synced events.
Commit as `feat(pets): pets as tags across records (4.7e)`.
````

## 4.7f — install on both phones, same sitting

````
Only after Saba says go, with both phones on the same Wi-Fi and paired.
1. Saba and Ancy each: Settings → Back up now, and confirm the time updated. Screenshots of the
   four totals on each phone.
2. Read-only signature check on both phones, as before.
3. `adb install -r` on the Fold, then immediately on the Pixel. Never uninstall.
4. On each phone, logcat for the app while it opens: confirm the migration ran (log the
   `user_version` change once, from the app), and report any error.
5. Nobody creates a pet or sets an owner until both phones are confirmed on v12.
````
