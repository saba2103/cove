# Cove Backup & Recovery: Google Drive (E2EE) Decision Record

This document records how Cove backs up and restores a household's data, the security model behind it, and the operational setup it depends on.

---

## 1. Why Backup Exists Alongside Sync

Cove already keeps an encrypted event log in Supabase (`home_events`) and a full local copy on each partner's phone. That covers **one** lost phone: the partner's device still holds the home key and the server log can rebuild the other phone.

It does **not** cover:
- Both phones lost/reset at once (the home key exists only on devices, so the server log becomes unreadable).
- A single-member home (no partner device to re-pair from).
- Local-only state that never syncs (custom categories, tab order, read markers).

Google Drive backup closes this gap.

---

## 2. Product Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Storage location | Google Drive **`appDataFolder`** (`drive.appdata` scope) | Hidden, app-private folder in the user's own Drive. Cove cannot read any other Drive files; users can't accidentally edit/delete backups; non-restricted scope (no paid security review). |
| Encryption model | **Recovery passphrase** (user-chosen, min 8 chars) | Only model that survives "both phones lost". Encrypting with the home key alone would make backups useless in exactly the scenario they exist for. |
| Passphrase entry | **Once per device** | The derived key (not the passphrase) is stored in Android Keystore-backed secure storage; subsequent backups need no prompt. Restoring on a new phone stores it automatically. |
| Forgotten passphrase | **Unrecoverable by design** | Zero-knowledge: Cove never sees the passphrase or derived key. UI warns to save it in a password manager. |
| Changing passphrase | Allowed; affects **future** backups only | Existing Drive backups stay locked with the passphrase they were made with. |
| Restore semantics | **Full replace** of local data, atomically | Predictable. Events that reached the server after the backup are replayed automatically from Supabase. |
| Retention | Newest **10** backups | Bounded Drive usage, enough history to roll back a bad day. |
| Platforms (v1) | **Android only** | Web shows "Available in the Cove Android app". iOS project does not exist yet. |
| Scheduling | Manual **"Back Up Now"** + **Nightly automatic backup** (Oct 22, 2026) | See §5a. The earlier fake "Nightly at 02:00 AM" row was replaced by a real WorkManager job. |

> [!IMPORTANT]
> **Honesty invariant:** backup UI must only ever show real state. No placeholder timestamps, counts or schedules. The previous mock (`BackupStatusNotifier`) was deleted for this reason.

---

## 3. Cryptographic Design

```mermaid
flowchart LR
    P["Recovery passphrase"] -->|"Argon2id (m=19 MiB, t=2, p=1, 16-byte salt)"| KEK["KEK (256-bit)"]
    DEK["Random DEK per backup (256-bit)"] -->|"AES-256-GCM (KEK)"| W["wrap"]
    S["Snapshot JSON → gzip"] -->|"AES-256-GCM (DEK)"| D["data"]
    W --> E["Envelope (.cove)"]
    D --> E
    KDF["kdf params + salt (clear)"] --> E
```

- **Envelope** (`BackupEnvelope`, UTF-8 JSON): `format`, `v`, `createdAt`, `schemaVersion`, `appVersion`, `kdf` (clear) + `wrap` and `data` (sealed).
- **AAD**: every GCM operation binds `cove-backup/v1` as associated data.
- **Wrong passphrase** fails fast on the tiny `wrap` blob (`BackupWrongPassphraseException`); tampering with `data` fails the GCM tag (`BackupFormatException`).
- Argon2id runs in a background isolate (`compute`) — ~160 ms on Apple Silicon, ~0.5–1 s on mid-range Android.
- Nothing in clear metadata reveals household content.

---

## 4. Snapshot Contents

`BackupSnapshotService` captures:
1. **Every Drift table**, read generically (`SELECT *`) inside one transaction for a point-in-time view. Raw SQLite values are preserved (blobs tagged `$b64`).
2. **All home symmetric keys** from `HomeKeyStore` (union of registered ids and `local_homes`).
3. **`cove_*` secure-storage preferences**, excluding `cove_home_key_*`, `cove_registered_home_ids` and `cove_backup_*`.

**Restore** (single transaction): `DELETE` + `INSERT OR REPLACE` per table, inserting only columns that exist in the current schema (forward-compatible with schema bumps). Backups from a **newer** schema are refused. After commit: `markTablesUpdated` wakes every stream (AuthGate transitions from onboarding to the app automatically), keys and prefs are written, active home is set, and `SyncEngineImpl.resyncAfterRestore` clears the in-memory dedupe cache and replays the server log.

---

## 5. User Flows

- **Settings → Backup & Restore**: Google Drive (Connect/Disconnect), Recovery Passphrase (set/change), Last Backup (real time + size), **Back Up Now**, **Restore**.
- **Back Up Now** chains: connect (if needed) → set passphrase (if needed) → upload → prune.
- **New phone**: Sign in → onboarding → **"Restore from Google Drive backup"** → pick backup → passphrase → review summary → restore.

---

## 5a. Nightly Automatic Backup

| Decision | Choice | Rationale |
|---|---|---|
| Default | **On** as soon as Drive is connected and a passphrase is set | Backups people must remember don't happen. Existing users get nightly backups after updating, with no action needed. Turn off via **Nightly Backup** toggle. |
| Time | **Around 2:00 AM** local, user-adjustable | Phone is usually idle, charging and on Wi-Fi. Android (Doze/battery saver) may shift it; WorkManager catches up as soon as constraints allow. UI says "Around…" to stay honest. |
| Network | **Wi-Fi only** by default (toggle for mobile data) | Avoid surprise data usage. |
| Battery | Requires battery-not-low | Never compete with a dying phone. |
| Unchanged data | **Skipped** (SHA-256 fingerprint of the snapshot) | Identical nightly copies would push genuinely different backups out of the 10-slot retention window. "Last Backup" time is still refreshed because the existing backup is current. |
| Recent backup | Skipped if any backup succeeded in the last **20 h** | A manual backup in the evening already covers the night. |
| Lost Drive access | Run records `needsReconnect`; Settings shows "Automatic backup paused — reconnect Google Drive." | Background code can never show the Google consent sheet; failing loudly in Settings beats failing silently. Cleared on the next successful backup or reconnect. |
| Network/Drive errors | Returned as retryable → WorkManager exponential backoff (from 30 min) | Transient problems self-heal. |
| Manual backups | Always upload, even if unchanged | A user tapping "Back Up Now" expects a fresh copy. |

**Mechanics:** `WorkmanagerBackupScheduler` registers a unique 24 h periodic job (`cove-nightly-backup`) with an initial delay to the next chosen time. App launch re-registers with `KEEP` (timer untouched); changing time/network/toggle re-registers with `REPLACE`. The job runs `coveBackgroundDispatcher` → `BackgroundBackupRunner` → `BackupService.run(automatic: true)` in a background isolate, opening its own read connection to `cove_db` (or reusing the app's live connection if WorkManager runs it in the main isolate). Google Drive tokens are obtained silently via the Play services Identity API, which needs no Activity. Outcomes are stored under `cove_backup_auto_*` and shown in Settings ("On · last ran Oct 22, 2:03 AM" / "nothing new to back up" / "didn't finish, will retry").

---

## 6. One-Time Google Cloud Setup (required for Drive access)

Firebase project: `cove-home-app` (number `633452066662`).

1. **Enable the Drive API**: Google Cloud Console → APIs & Services → Library → *Google Drive API* → Enable.
2. **OAuth consent screen**: configure (External, Testing). Add scope `.../auth/drive.appdata`. Add both founders' Google accounts as **test users**.
3. **Android OAuth client**: Credentials → Create credentials → OAuth client ID → *Android*, package `com.app.cove`, SHA-1 of the signing key.
   - Debug/current release signing (debug keystore): `F9:7F:C3:B0:F5:85:C2:B2:10:5C:2C:5E:84:C8:7D:57:75:62:F1:00`
   - When a real upload/release keystore (or Play App Signing) is introduced, **add its SHA-1 as an additional Android client**, or Drive auth will fail with `DEVELOPER_ERROR`.
4. No code change or `google-services.json` update is required for authorization-only access.

---

## 7. Follow-ups

- Local notification when nightly backup has been paused (needs reconnect) for more than 3 days.
- Web support (Google Identity Services token client + web OAuth client).
- "Verify passphrase" reminder every few months so users don't forget it.

---

## 8. Code Map

| File | Responsibility |
|---|---|
| `lib/features/backup/backup_crypto.dart` | Argon2id KDF, AES-256-GCM envelope, gzip |
| `lib/features/backup/backup_snapshot_service.dart` | Generic DB/keys/prefs export & atomic restore |
| `lib/features/backup/backup_service.dart` | Shared backup pipeline (manual + automatic), fingerprint skip, status keys |
| `lib/features/backup/backup_scheduler.dart` | WorkManager nightly job, background dispatcher/runner |
| `lib/features/backup/drive_backup_remote.dart` | `BackupRemote` interface + Google Drive `appDataFolder` implementation |
| `lib/features/backup/drive_backup_controller.dart` | Riverpod state machine: connect, passphrase, backup, prune, restore |
| `lib/features/backup/drive_backup_section.dart` | Settings section + flow orchestration |
| `lib/features/backup/drive_backup_sheets.dart` | Passphrase sheet, restore sheet |
| `test/drive_backup_test.dart` | Crypto, snapshot and end-to-end controller tests (fake Drive) |
