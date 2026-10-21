# Cove Product Changelog

This document tracks all user-facing changes, architectural upgrades, and engineering refinements across Cove releases in chronological order.

---

## [v1.0-alpha.1] — 2026-09-25

### Fixed
- **Prevent Duplicate Bottom Sheets on Push Notification Tap (`Oct 07, 2026`)**:
  - *Outcome*: Tapping a push notification now opens exactly one entity detail bottom sheet (e.g. expense, commitment, list item, habit, or calendar event), eliminating stacked duplicate bottom sheets.
  - *Under the Hood*:
    - Removed redundant `ref.listen(notificationPayloadNavigationProvider)` in `AppShell` that was duplicating the `_navSub = notifService.onNavigateToPayload.listen` stream listener.
    - Added an opening mutex and a 1500ms entity debounce in `NotificationDetailDispatcher.openDetailForNotification` to safely drop concurrent or rapid duplicate dispatches.
    - Enforced `Navigator.of(context).popUntil((route) => route.isFirst)` right before presenting any notification detail sheet to ensure no previously open sheet or modal remains underneath.
    - Debounced duplicate OS tap callbacks within 1000ms in `NotificationService.onNotificationTapped` (preventing dual triggers from `getNotificationAppLaunchDetails` and `onDidReceiveNotificationResponse`).
    - Added automated widget test in `test/notifications_test.dart` verifying concurrent dispatches open exactly one bottom sheet.
- **Foreclosed & Completed EMI Year Projections in Helicopter View (`Oct 07, 2026`)**:
  - *Outcome*: Foreclosed and completed EMIs now preserve their past paid installment months in the 12-month Helicopter Year View, while correctly stopping further EMI calculations on and after the foreclosure or completion cutoff. Inactive loans no longer vanish completely from the year view as if they never existed.
  - *Under the Hood*:
    - In `CommitmentProjectionUtils.projectYear`, adjusted the inactive filter to only exclude open-ended subscriptions (`if (!sub.isActive && !sub.isEmi) continue;`), allowing finite commitments (EMIs) to evaluate past active months.
    - Enhanced `_isEmiActiveInMonth` to determine the loan's initial start month via `endDate - (totalInstallments - 1)` (or `createdAt`) and the foreclosure cutoff month via `sub.nextBillingDate`.
    - Excluded months on or after the foreclosure cutoff while keeping all months between loan start and cutoff active.
    - Added unit tests in `test/subscriptions_test.dart` validating month-by-month projections for foreclosed, completed, and cancelled commitments.

### Added
- **Real End-to-End Encrypted Google Drive Backup & Restore (`Oct 22, 2026`)**:
  - *Outcome*: "Back Up Now" now actually backs up. Your whole household — every list, expense, commitment, habit, calendar event, activity entry, the home encryption keys and local preferences — is encrypted on the phone with a recovery passphrase and saved to a private, hidden folder in your own Google Drive. On a new or reset phone, sign in, tap **Restore from Google Drive backup**, enter the passphrase, and everything comes back; anything newer catches up from your partner automatically. The previous simulated backup UI (fake "18 hours ago", fake pending counts, non-functional nightly window) has been removed.
  - *Under the Hood*:
    - New `lib/features/backup/` module: `BackupCrypto` (Argon2id m=19 MiB/t=2 KEK → per-backup random DEK, AES-256-GCM with `cove-backup/v1` AAD, gzip via `archive`), `BackupSnapshotService` (generic transactional `SELECT *` export of all Drift tables + `HomeKeyStore` keys + `cove_*` secure prefs; atomic full-replace restore with schema-tolerant column intersection and `markTablesUpdated`), `GoogleDriveBackupRemote` (`google_sign_in` 7 authorization-only flow, `drive.appdata` scope, `appDataFolder` upload/list/download/delete, 401 token refresh), and `DriveBackupController` Riverpod state machine (connect, set/change passphrase, backup, keep newest 10, restore).
    - Passphrase-derived key stored in Keystore-backed `EncryptedSharedPreferences`; restoring on a new phone adopts the backup's key so future backups need no re-entry.
    - `SyncEngineImpl.resyncAfterRestore` clears the in-memory dedupe cache and replays the Supabase log after a restore.
    - Settings `Backup & Restore` rebuilt as `DriveBackupSection`; onboarding gains a "Restore from Google Drive backup" entry (Android only; web shows an availability note).
    - Removed mock `BackupStatusState`/`BackupStatusNotifier`; `CovePillInput` gains `obscureText`.
    - Added `archive` as a direct dependency.
    - Tests: new `test/drive_backup_test.dart` (crypto round-trip, wrong passphrase, tamper detection, snapshot fidelity, stream notification, schema tolerance, retention, full new-phone restore); updated `test/profile_settings_test.dart`.
    - Decision record: [`product/backup_and_recovery.md`](./backup_and_recovery.md).
- **Financed Through Support for Ongoing Subscriptions (`Oct 07, 2026`)**:
  - *Outcome*: Users can now specify and view the payment source (card, bank, or person) for ongoing subscriptions (e.g. "Amex Gold", "HDFC Regalia", "Apple Card") in addition to finite EMIs. Financing sources appear in commitment list cards, detail sheets, month breakdown sheets, calendar agenda renewal entries, and activity feeds.
  - *Under the Hood*:
    - In `SubscriptionFormSheet`, elevated the `FINANCED THROUGH` input field with real-time history suggestions directly below the commitment type selector so it is accessible for all commitment types.
    - Removed `isEmiSelected` gate from `effectiveFinancedThrough` so sources are persisted and dispatched via sync for standard subscriptions.
    - Updated `SubscriptionsScreen` subtitle builder to append `· via <source>` for regular subscriptions.
    - Updated `CommitmentDetailSheet` to display the "Financed Through" row for any commitment with a valid source.
    - Surfaced payment source in `MonthCommitmentsSheet` tile subtitles and `CalendarAgendaView` renewal entries.
    - Included payment source in `ActivityFormatter` and `NotificationFormatter` event subtitles.
    - Added full end-to-end unit and widget test coverage in `test/subscriptions_test.dart`.
- **Home-Scoped SQLite Persistence & Cross-Device Sync (`Sep 25, 2026`)**:
  - *Outcome*: Monthly expense budgets, preferred home currency, anniversary dates, and check-in reminders now permanently persist in local SQLite and sync seamlessly across partner devices.
  - *Under the Hood*:
    - Bumped Drift database schema to version `11`.
    - Added `monthlyBudget` and `anniversaryDate` columns to `LocalHomes`.
    - Created dedicated `LocalCheckinReminders` table (`id`, `homeId`, `hour`, `minute`, `message`, `isEnabled`, `createdAt`).
    - Added full CRUD projections in `LocalStateStoreImpl` for `home_currency_updated`, `home_anniversary_updated`, `monthly_budget_updated`, `monthly_budget_cleared`, and `checkin_reminder_*` events.
    - Updated `MonthlyBudgetNotifier`, `CurrencyNotifier`, `HomeMetadataNotifier`, and `ReminderNotifier` to stream reactively from SQLite.
- **End-to-End Home Currency Consistency (`Sep 25, 2026`)**:
  - *Outcome*: The active Home's currency preference (e.g. INR `₹`) is now the single authoritative source of truth across all screens, activity feeds, detail sheets, and notifications. Activity logs and undo handlers no longer default to USD `$`.
  - *Under the Hood*:
    - `ActivityFormatter.formatWithDb` queries `db.localHomes` by `homeId` if currency symbol is not yet loaded into memory, guaranteeing correct symbol resolution.
    - `ActivityFormatter.getCurrencySymbol` honors `fallbackSymbol` whenever currency is USD or omitted.
    - `PreferencesController.setCurrency` cascades new currency preference to all existing SQLite `localExpenses` and `localSubscriptions` records for the active home.
    - `LocalStateStoreImpl` projects `home_currency_updated` events to cascade update `localExpenses` and `localSubscriptions` across devices.
    - `ActivityEventDetailSheet` undo handlers fallback to `currencyPreferenceProvider.code` rather than hardcoded `'USD'`.
- **Contextual Notification Deep Linking (`Sep 25, 2026`)**:
  - *Outcome*: Tapping an expense, commitment, or list push notification now opens the exact item's detail bottom sheet directly on top of the screen instead of simply navigating to the generic tab.
  - *Under the Hood*:
    - Enhanced FCM payload parser in `NotificationService` to capture `entityId` and `actionType`.
    - Added `NotificationDetailDispatcher` to resolve entities asynchronously from Drift SQLite and present the respective modal sheet with navigation stack pop-until guards.

---

## [v1.0-alpha.1] — 2026-09-20 to 2026-09-22

### Added
- **EMI Tracker & Loan Foreclosure (`Sep 20, 2026`)**:
  - *Outcome*: Dedicated household EMI overview with total debt burden, multi-select loan payoff simulation, and one-tap foreclosure confirmation with optional ledger recording.
  - *Under the Hood*:
    - Bodoni Moda hero burden card, sticky `MultiSelectBurdenBar`, and foreclosure projection controller.
- **Two-Tick Sync Delivery Reconciliation (`Sep 22, 2026`)**:
  - *Outcome*: Single ticks (`savedLocally`) automatically advance to double ticks (`syncedToPartner`) reliably, even if the partner device received the payload while the sender was offline.
  - *Under the Hood*:
    - Added `reconcileDeliveryConfirmations()` to batch-query persistent Supabase `event_deliveries` on launch, pull-to-refresh, and upload flush.
- **Push Notification Background Navigation Fix (`Sep 22, 2026`)**:
  - *Outcome*: Tapping system notifications reliably opens the corresponding module even when the app was killed or cold-launched.
  - *Under the Hood*:
    - Added `FLUTTER_NOTIFICATION_CLICK` intent filter in `AndroidManifest.xml`.
    - Implemented `consumePendingNavigationModule()` in `NotificationService` and `AppShell`.

---

## [v1.0-alpha.1] — 2026-09-19

### Changed
- **Calendar-First Architecture & Today Sanctuary (`Sep 19, 2026`)**:
  - *Outcome*: Cove launches directly into your day on the calendar, carrying five quiet layers: events, commitments, money, rhythms, and tasks. Today is the home tab gathering monthly spend totals, shared list pills, and recent activity into one calm flow.
  - *Under the Hood*:
    - Unified 5-layer calendar provider, additive due-date database schema, Day view layer filters, Bodoni time gutters, and retired Dashboard architecture.

---

## [v0.6-alpha] — 2026-09-17

### Added
- **Commitments Helicopter View (`Sep 17, 2026`)**:
  - Full-screen 12-month bird's-eye commitments grid with 50/50 partner attribution toggles and drill-down sheets.
- **Clean Decimals (`Sep 17, 2026`)**:
  - Smart decimal formatting (`formatCoveAmount`) that strips zero decimals (e.g. ₹250 instead of ₹250.00) while preserving non-zero cents and paise.
- **Personal Profile Studio (`Sep 17, 2026`)**:
  - Custom photo portraits, camera capture, and minimal initial avatars with frame-0 offline caching.

---

## [v0.5-alpha] — 2026-09-17

### Added
- **Partner-First "Paid By" Details (`Sep 17, 2026`)**:
  - Clear "You" vs partner name attribution replacing cryptic UUID hashes across commitments and expense ledgers.

---

## [v0.4-alpha] — 2026-09-15

### Added
- **Silent Background Sync (`Sep 15, 2026`)**:
  - Zero-spinner, zero-modal sync engine preserving undisturbed reading and typing.
- **Strict Annual Renewal Timing (`Sep 15, 2026`)**:
  - Calendar math pinning recurring annual renewals strictly to their scheduled calendar day.

---

## [v0.3-alpha] — 2026-09-12

### Added
- **Zero-Knowledge End-to-End Encryption (`Sep 12, 2026`)**:
  - Argon2id key derivation + XChaCha20-Poly1305 AEAD payload encryption ensuring domestic privacy.

---

## [v0.2-alpha] — 2026-09-08 to 2026-09-10

### Added
- **Two-Tick Visual Confirmation (`Sep 10, 2026`)**:
  - Visual single tick vs double tick status indicator for partner sync.
- **Daily Rhythms & Mutual Cheers (`Sep 8, 2026`)**:
  - Shared recurring habit tracking with mutual cheering animations.

---

## [v0.1-alpha] — 2026-09-05

### Added
- **Offline-First Foundation & Multi-Currency Support (`Sep 5, 2026`)**:
  - Drift SQLite local database, optimistic mutation pipeline with outbox queues, and support for INR, USD, EUR, GBP, and JPY.
