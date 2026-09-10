# Project Brief: Cove

**Cove** is a private, shared "home operating system" designed exclusively for exactly two people (a couple) living together. It serves as a unified, serene anchor for their joint everyday life.

It is built for personal use first (the founder and his wife) rather than public distribution. The architectural priority is exceptional clarity, maintainability, end-to-end privacy, and calm aesthetics rather than speculative multi-tenant scaling.

---

## 1. Product Thesis

Living together requires coordination, but existing family and productivity tools introduce friction, corporate formality, or toxic dynamics:

- **No Task Assignment or Delegation**: Traditional task and project apps feature "Assignee" fields. In a partnership, assigning tasks creates an unhealthy manager-subordinate dynamic ("I assigned you the laundry"). In Cove, **there is never an "assigned-to" field anywhere in the application**. 
- **Transparent Mutual Ownership**: Everything in Cove belongs to the Home. Actions, items, and entries show who created or checked them, but ownership is always visible and shared by default.
- **Calm, Low-Friction Presence**: The app operates like a fine physical household ledger or counter clock. It does not badger, guilt, or artificially manufacture engagement.
- **First-Class Dual Themes**: The home is lived in at midnight under dim lamps and at noon in bright sunlight. Both dark and light themes are designed with bespoke tonal palettes, treated with equal reverence.

---

## 2. Full v1 Feature List

1. **Dashboard**
   - At-a-glance daily briefing: upcoming calendar items, pending list items, active habit streaks, recent shared expenses, and monthly subscription tally.
   - Distinctive Bodoni Moda numerical headlines tinted with the primary champagne accent.
2. **Subscriptions**
   - Recurring shared commitment tracker with renewal cadence (monthly/annual), cost breakdown, billing dates, and category tags.
   - Combined monthly burn tally.
3. **Shared Lists**
   - Groceries, home supplies, packing lists, shared wishlists.
   - Clean grouped rows with hairline dividers, rounded-square checkboxes, and quick pill-input field for rapid entry.
4. **Expenses**
   - Lightweight shared ledger for household purchases and split tracking.
   - Simple tally of who paid what with running balance, without complex accounting debt graphs.
5. **Habit Tracking**
   - Daily joint or individual rhythm tracking (e.g., morning walk, plant watering, reading).
   - Plain numerical streak counter in Bodoni Moda (explicitly without animated flames or gamified badges).
6. **Lightweight Calendar**
   - Minimalist shared schedule for joint dinners, appointments, travel, and social commitments.
   - Focused on the current week and month ahead without corporate scheduling bloat.
7. **Activity Log**
   - Subtle, reverse-chronological household event feed ("Sarah checked off Almond milk", "Alex logged Groceries ($42)").
   - Gives quiet reassurance that household tasks are taken care of without checking in via text.
8. **Notifications**
   - Gentle, purposeful push notifications delivered via Firebase Cloud Messaging (FCM) when a partner completes or adds a shared item.
9. **Profile, Preferences & Settings**
   - Partner presence, home name, notification toggles, theme switcher (Dark / Light / System).
   - Direct partner invite / pairing interface.
10. **Google Drive Backup & Restore**
    - Manual and automated encrypted snapshots exported directly to the user's private Google Drive storage.
    - Zero backend access to backups.
11. **Authentication & Pairing**
    - Frictionless Google Sign-In via Supabase Auth.
    - Direct Home creation flow with out-of-band / QR code key exchange for pairing the partner.

---

## 3. Sync & Security Model

Cove is engineered around the principle that **the cloud is a blind, untrusted pipe**.

```
[Device A (Sarah)]                                      [Device B (Alex)]
  │                                                            ▲
  │ 1. Mutation (e.g. Add Item)                                │
  ▼                                                            │
[Local Drift SQLite] (Local Source of Truth)                   │
  │                                                            │ 6. Decrypt with Home Key &
  │ 2. Encrypt event payload with                              │    Apply to Local SQLite
  │    Shared Home Key (libsodium)                             │
  ▼                                                            │
[Encrypted Ciphertext Payload]                                 │
  │                                                            │
  │ 3. Send over TLS                                           │ 5. Realtime push or poll
  ▼                                                            │
[Supabase Backend (Blind Relay)] ──────────────────────────────┘
  - Stores ciphertext & sequence metadata
  - Never possesses Home Key
  - WhatsApp-style store-and-forward queue
```

- **Local Source of Truth**: The UI reads and writes exclusively to an on-device SQLite database (managed with Drift). The app is 100% functional offline.
- **End-to-End Encryption with libsodium**: Every state change produces an immutable event. The event payload is encrypted on-device using a symmetric key (`crypto_secretbox_easy` or XChaCha20-Poly1305) before transmission.
- **Blind Relay Architecture**: Supabase (PostgreSQL + Realtime) acts strictly as a blind relay and store-and-forward mailbox. Supabase stores encrypted blobs, event IDs, timestamps, and home identifiers. It cannot inspect list item names, costs, habits, or dates.
- **Zero-Knowledge Home Key Exchange**: The shared symmetric Home Key is generated locally when the first partner creates the Home. It is transferred to the second partner during pairing (e.g., via a secure local QR code or direct out-of-band exchange). The key is stored in the device's secure hardware enclave (Keychain / Keystore) and **never touches Supabase**.
- **Store-and-Forward**: If the partner's device is offline, Supabase buffers the encrypted events. When the partner's device comes online, it pulls the new events in causal order, decrypts them locally, and applies them to its Drift database.

---

## 4. Explicitly Out of Scope for v1

To maintain focus and avoid scope bloat:
- **No Long-Form Notes / Rich Text**: Lists are items, not unstructured document editors.
- **No Relationship Content or Daily Questions**: Cove is a household OS, not a therapy or couples-trivia app.
- **No Gamification beyond Simple Numbers**: No points, confetti bursts, animated flame streaks, leveling up, or badges.
- **No "Read / Seen" Receipts**: The delivery state model is strictly two states:
  - `One Tick`: Saved locally on this device.
  - `Two Ticks`: Synced and acknowledged by the partner's device.
  - **Never three ticks or colored read receipts.** There is no tracking of whether your partner opened or viewed an item.

---

## 5. Technical Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Client Framework** | Flutter 3.x (Dart 3.x) | Cross-platform targeting Android and Web with identical fidelity. |
| **State Management** | Riverpod (`flutter_riverpod`) | Declarative, testable, dependency-injected state containers. |
| **Local Database** | Drift (`drift`, `sqlite3_flutter_libs`, `drift_flutter`) | Type-safe, reactive local SQLite database as primary source of truth. |
| **Cryptography** | `sodium_libs` / libsodium | On-device symmetric authenticated encryption for event payloads. |
| **Relay Backend** | Supabase (`supabase_flutter`) | Managed PostgreSQL, Supabase Auth, and Realtime websocket blind relay. |
| **Authentication** | Google Sign-In (`google_sign_in`) | Single-tap authentication linked into Supabase Auth. |
| **Cloud Messaging** | Firebase Cloud Messaging (`firebase_messaging`) | Background push notifications for partner event alerts. |
| **External Backup** | Google Drive API (`googleapis`) | User-controlled encrypted archive upload/download. |
| **Typography** | `google_fonts` (Bodoni Moda) + bundled General Sans | Distinctive, elegant editorial display paired with clean functional UI text. |
