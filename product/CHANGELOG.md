# Cove Product Changelog

This document tracks all user-facing changes, architectural upgrades, and engineering refinements across Cove releases in chronological order.

---

## [v1.0-alpha.1] — 2026-09-25

### Added
- **Home-Scoped SQLite Persistence & Cross-Device Sync (`Sep 25, 2026`)**:
  - *Outcome*: Monthly expense budgets, preferred home currency, anniversary dates, and check-in reminders now permanently persist in local SQLite and sync seamlessly across partner devices.
  - *Under the Hood*:
    - Bumped Drift database schema to version `11`.
    - Added `monthlyBudget` and `anniversaryDate` columns to `LocalHomes`.
    - Created dedicated `LocalCheckinReminders` table (`id`, `homeId`, `hour`, `minute`, `message`, `isEnabled`, `createdAt`).
    - Added full CRUD projections in `LocalStateStoreImpl` for `home_currency_updated`, `home_anniversary_updated`, `monthly_budget_updated`, `monthly_budget_cleared`, and `checkin_reminder_*` events.
    - Updated `MonthlyBudgetNotifier`, `CurrencyNotifier`, `HomeMetadataNotifier`, and `ReminderNotifier` to stream reactively from SQLite.
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
