# 19 — Owners and pets (schema v12)

The only database change in v2. Additive only: new nullable columns and new tables, nothing
renamed, nothing dropped. A v11 backup restores into v12 cleanly (restore matches columns by
name and fills new ones with their defaults).

## 1. Owners

"Whose is it?" for events, tasks and routines, as the Add design always asked.

| Table | New column | Values | Existing rows |
|---|---|---|---|
| `local_calendar_events` | `owner TEXT NULL` | a member's user id, or `both` | `both` (that's what every event already shows) |
| `local_list_items` | `owner TEXT NULL` | a member's user id, `both`, or `either` | `NULL` = no owner, displayed as nothing |
| `local_routine_events` | `owner TEXT NULL` | a member's user id, or `both` | `both` |

- **Sync:** `owner` rides in the existing add and update payloads. **An update payload without
  an `owner` key leaves the stored owner unchanged.** A v11 app editing a record must never
  wipe an owner a v12 app set.
- **Display:** a member's id shows their name; `both` shows "Both of you"; `either` shows
  "Either of you". The event ticket's owner line (today always "Both of you") now uses the
  real value.

## 2. Pets, as tags

For now pets are only labels you can put on records. No feeding, walk or vet tracking.

- `local_pets`: `id`, `home_id`, `name`, `created_at`, `created_by`, `is_archived`.
- `local_pet_tags`: `id`, `home_id`, `pet_id`, `record_kind` (expense · event · task · habit ·
  commitment · routine_event), `record_id`, `created_at`. One row per (pet, record).
- **Sync events:** `pet_created`, `pet_renamed`, `pet_archived`, `pet_tag_added`,
  `pet_tag_removed`. Deleting a record removes its tags (deferred with the record, through
  PendingDeleteService).
- **Privacy:** a tag on a private record is itself private (never synced), exactly like the
  record.

## 3. UI (undesigned, so built from existing primitives)

- **Our home → Pets:** a section with a CoveRow per pet. Add a pet; tap one to rename; archive
  it from ⋯. Archived pets stay on old records, greyed out.
- **Add:**
  - Event, task and routine gain the **Whose is it?** step from the original design, as
    person tiles: you · partner · Both of you, plus Either for a task. It goes after the
    content steps and before review.
  - If the home has at least one pet, every kind's owner or who step shows a row underneath:
    **"About a pet?"** with one chip per pet (multi-select, optional).
- **Detail sheets:** pet tags as small chips under the meaning panel. ⋯ gets "Tag a pet…" /
  "Change pets…", which opens a pet picker sheet.
- **Routines screen:** the two lanes from `design/screens/routines.md`. Yours on the left,
  your partner's on the right, and shared routines (`both`) in solid gold spanning both lanes.

## 4. Rollout rule

A v11 app that receives `pet_*` events, or owner fields, ignores them. It may also mark
unknown events as applied, so they'd be lost on that phone. So:

- **Update both phones in the same sitting**, before anyone creates a pet or sets an owner.
- The v12 app, on its first launch after migrating, asks the server for any `pet_*` events for
  the home it hasn't projected, and applies them. This is a safety net if one phone lagged.
