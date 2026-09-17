# Cove: Complete Product Specification, Feature Architecture & Future Roadmap

A definitive, attribute-level master specification for **Cove**—the private digital sanctuary designed exclusively for modern couples.

---

## 1. Product Philosophy & Strategic Positioning

### The "Quiet Luxury Sanctuary for Two" Thesis
Most couple tools fail because they are either:
1. **Cold spreadsheets / generic finance apps** (Splitwise, Mint, Excel) that treat intimate relationships like transactional roommate arrangements.
2. **Juvenile / gimmick quiz apps** (Paired, Between) that clutter the screen with emojis, intrusive ads, and therapy quizzes that couples abandon after 90 days.

**Cove is positioned as a Digital Sanctuary:**
* **Intimacy through Utility**: Cove focuses on the unsexy, high-frequency friction points of shared domestic life—who paid the electric bill, how many installments are left on the sofa EMI, what time dinner is scheduled on weekdays, and maintaining morning meditation together.
* **Quiet Luxury Aesthetic**: Editorial serif typography (*Cormorant Garamond*), crisp modern body text (*General Sans*), warm deep slate backgrounds (`#0B1F1E`), and muted champagne gold accents (`#D4AF37`).
* **Zero-Knowledge Privacy Guarantee**: No third-party trackers, no bank-credential scraping that disconnects every month, and zero ad networks. 100% of data is encrypted on-device with the couple's private Home Key.
* **Offline-First Speed**: Built on Flutter and embedded SQLite (`Drift`), rendering every screen in under 16 milliseconds without waiting on network spin wheels.

---

## 2. Product Personality & Tone of Voice

### A. The 4 Brand Voice Tenets
1. **Understated, Not Gimmicky**: Speak like a discreet private concierge, never like a gamified cartoon. No pushy exclamation marks or guilt trips.
2. **Dignified & Partner-Centric**: Language always honors both partners as equals (*"Paid by You"*, *"Paid by Sarah"*, *"Split (50/50)"*).
3. **Calm Transparency**: Financial language is clear, factual, and stress-free (*"Household balance is settled"*, rather than *"You owe Alex \$45"*).
4. **Private by Design**: Reassure without being overly technical (*"Private to your device"*, *"Encrypted with your Home Key"*).

### B. UX Microcopy Matrix

| Context | Standard / Bad App Copy | The Cove Sanctuary Copy |
| :--- | :--- | :--- |
| **New Commitment** | "Add recurring subscription" | *"New Commitment"* |
| **Payer Selection** | "Who paid?" (User 1 / User 2) | *[ You ] [ Split (50/50) ] [ Partner ]* |
| **Financing Source** | "Payment method" | *FINANCED THROUGH · Card, Person, or Bank* |
| **EMI Status** | "Installment 3 of 12" | *3/12 paid · via HDFC Regalia* |
| **Debt Settlement** | "Pay debt / Settle up" | *"Settle Balance"* & *"All settled in the sanctuary"* |
| **Habit Streak** | "5 day streak! Don't break it!" | *5 days together 🌿* |
| **Private Toggle** | "Hide from group" | *Private to this device · 0 bytes sent to cloud* |
| **Empty Routine** | "No routines found. Click add." | *"Your day, in rhythm. Tap any hour to shape your routine."* |
| **Version Update** | "Check out what's new!" | *"What's New in the Sanctuary"* |

---

## 3. Attribute-Level Feature Architecture

### Module 1: The App Shell & "Today" Sanctuary Dashboard

The home dashboard is the central hearth of the couple's day, harmonizing weather, active daily routine blocks, mutual habit progress, and upcoming renewals into one glanceable view.

#### Field-Level Attributes & Behaviors
* **Sanctuary Header**:
  * `home_name`: Custom string (default: *"Sanctuary"*).
  * `partner_avatar`: High-resolution network photo or luxury serif monogram fallback (`Cormorant Garamond`, bold, gold/champagne background).
  * `partner_presence`: Dynamic status indicator (*"Synced 2m ago"*).
  * `weather_widget`: Ambient temperature and conditions pill for the couple's home city.
* **Quick Navigation Strip**:
  * Dedicated icon button for **Daily Routines** (`Icons.schedule_outlined`) positioned immediately to the left of the Today icon button.
  * Bottom navigation bar: *Today*, *Expenses*, *Commitments*, *Routines*, *More*.

---

### Module 2: Expenses & Shared Household Ledger

A real-time, zero-friction ledger for joint groceries, dining, utilities, travel, and rent.

```
┌────────────────────────────────────────────────────────┐
│                   TOTAL EXPENDITURE                    │
│                        ₹24,850                         │
│             Groceries 42% · Dining 28% · Bills 30%     │
│ ┌───────────────┬──────────────┬─────────────────────┐ │
│ │  Groceries    │    Dining    │      Utilities      │ │
│ └───────────────┴──────────────┴─────────────────────┘ │
│                                                        │
│  ● Groceries ₹10,400  ● Dining ₹6,950  ● Bills ₹7,500  │
└────────────────────────────────────────────────────────┘
```

#### Field-Level Schema & Validation
* `id` (`TEXT` / UUID, Primary Key): Unique event-sourced transaction identifier.
* `title` (`TEXT`, Required): Description of expense (e.g. *"Whole Foods Market"*).
* `amount` (`REAL`, Required): Non-negative numerical value formatted to 2 decimal places.
* `currency` (`TEXT`, Required): 3-letter ISO code (e.g. `USD`, `INR`, `EUR`, `GBP`).
* `category` (`TEXT`, Required): *Groceries*, *Dining*, *Utilities*, *Home*, *Transport*, *Entertainment*, *Health*, *Other*.
* `paid_by` (`TEXT`, Required): User ID of the paying partner, or `'split'` for 50/50 joint contributions.
* `split_mode` (`TEXT`, Required):
  * `'equal'` (50/50 split).
  * `'you_full'` (100% attributed to creator).
  * `'partner_full'` (100% attributed to partner).
  * `'custom'` (Custom percentage or exact dollar split).
* `is_private` (`BOOLEAN`, Default: `false`): When `true`, transaction is stored strictly on the local SQLite table and completely bypassed by the sync engine.
* `expense_date` (`DATETIME`, Required): Date of expenditure.

#### Advanced Capabilities
* **Continuous Multi-Segment Category Progress Bar**:
  * Proportionate horizontal colored bar representing category distributions.
  * Curated luxury palette: Emerald (`#10B981`) for Groceries, Ochre (`#F59E0B`) for Dining, Teal (`#06B6D4`) for Utilities, Terracotta (`#F97316`) for Transport.
  * Interactive legend chips: tapping a category filters the ledger to that category.
* **Instant Balance Settlement**:
  * Mathematical netting algorithm: calculates running mutual balance continuously.
  * 1-tap "Settle Balance" modal that records a neutralizing settlement record without deleting history.

---

### Module 3: Commitments, Subscriptions & Finite EMI Tracker

Unified tracking of ongoing recurring services (Netflix, Spotify, Cloud Storage) and finite debt obligations (Apple iPhone EMI, Car Loan, Furniture Installments).

#### Field-Level Schema & Validation
* `id` (`TEXT`, Primary Key): UUID.
* `name` (`TEXT`, Required): Service or debt name (e.g. *"MacBook Pro EMI"*, *"Netflix 4K"*).
* `amount` (`REAL`, Required): Recurring cost per cycle.
* `currency` (`TEXT`, Required): Currency code.
* `billing_cycle` (`TEXT`, Required):
  * `'monthly'`: Recurs every 30/31 days.
  * `'annual'`: Recurs every 365 days.
  * `'every_N_months'`: Custom intervals (e.g. `every_7_months` for 6+1 broadband plans).
* `next_billing_date` (`DATETIME`, Required): Next payment trigger date.
* `end_date` (`DATETIME`, Nullable):
  * When `null`: Ongoing open-ended subscription.
  * When `DateTime`: Finite loan/EMI maturity date.
* `total_installments` (`INTEGER`, Nullable): Total tenure in months (e.g. `12`, `24`, `36`).
* `paid_installments` (`INTEGER`, Nullable): Installments paid so far (e.g. `3`).
* `financed_through` (`TEXT`, Nullable): Bank, credit card, or lender (e.g. *"HDFC Regalia"*, *"Apple Card"*, *"Dad"*).
* `paid_by` (`TEXT`, Required): `myId`, `partnerId`, or `'split'` (for 50/50 shared commitments).
* `is_active` (`BOOLEAN`, Default: `true`): Pause/reactivate toggle.
* `is_private` (`BOOLEAN`, Default: `false`): Device-only privacy toggle.

#### Advanced Capabilities
* **Real-Time Financing Source Autocompletion**:
  * Prominent **"FINANCED THROUGH"** field placed directly below Commitment Type.
  * Dynamic query of existing sources merged with popular presets (`HDFC Bank`, `ICICI Bank`, `SBI Card`, `Amex`, `Axis Bank`, `Apple Card`, `Credit Card`, `Personal Loan`, `Friend / Family`).
  * Live keystroke filtering displays matching tap-to-select chips with clear button.
* **Interactive Tenure & Tag Preview**:
  * Quick tenure chips (`3`, `6`, `9`, `12`, `18`, `24`, `36` mos) + stepper.
  * Paid installments stepper with live formatted tag pill: `${paid}/${total} paid` (e.g. `3/12 paid`).
  * Automatic maturity date recalculation based on billing cycle and remaining tenure.
* **Card Subtitle Attribution**:
  * Active/Paused card subtitle renders rich context:  
    `Paid by You · via HDFC Regalia · 3/12 paid · renews in 14 days`.
* **Cycle Consolidation Toggle**:
  * Switcher allowing couples to view monthly vs annual commitments strictly separated, or unified (*"Monthly converted to annual"* / *"Annual converted to monthly"*).

---

### Module 4: Daily Routines (24-Hour Vertical Day Timeline)

A dedicated operational scheduling system designed to harmonize the daily flow of two busy partners.

```
06:00 ─── Morning Coffee & Reading [06:00 - 07:00] (Emerald)
07:00 ─── Gym Session [07:15 - 08:30] (Teal)
08:00
09:00 ─── Focused Work Block [09:00 - 13:00] (Slate)
13:00 ─── Shared Lunch [13:00 - 14:00] (Amber)
      ─── ● Current Time (13:25) ────────────────────────
```

#### Field-Level Schema & Validation
* **`LocalRoutines` Table**:
  * `id` (`TEXT`, Primary Key): UUID.
  * `name` (`TEXT`, Required): Tab label (e.g. *"Weekday (Mon – Fri)"*, *"Saturday"*, *"Sunday"*).
  * `days_of_week` (`TEXT`, Required): Comma-separated integer list representing active days (`1,2,3,4,5` for Mon–Fri).
  * `is_active` (`BOOLEAN`, Default: `true`).
* **`LocalRoutineEvents` Table**:
  * `id` (`TEXT`, Primary Key): UUID.
  * `routine_id` (`TEXT`, Foreign Key): Associated routine tab.
  * `title` (`TEXT`, Required): Activity name (e.g. *"Morning Meditation"*, *"Deep Work"*, *"Dinner & Walk"*).
  * `start_time` (`TEXT`, Required): 24-hour time format (`"07:30"`).
  * `end_time` (`TEXT`, Required): 24-hour time format (`"08:45"`).
  * `category` (`TEXT`, Required): *Health*, *Work*, *Quality Time*, *Chores*, *Leisure*, *Personal*.
  * `color` (`TEXT`, Required): Hex code for vertical border stripe and card background tint.
  * `notes` (`TEXT`, Nullable): Bullet points or instructions.

#### Advanced Capabilities
* **Pre-configured Routine Tabs**: Automatically pre-seeds *"Weekday (Mon – Fri)"*, *"Saturday"*, and *"Sunday"* tabs.
* **Continuous 24-Hour Timeline Canvas**: Seamless vertical scroll from 12:00 AM to 11:00 PM with clean hourly grid lines.
* **Dynamic Time-Block Layout**: Proportionately scales block height based on duration (`(endMinutes - startMinutes) * pixelRatio`).
* **Real-Time Live Indicator Line**: Red pulsating dot and horizontal rule indicating the exact current time of day if the active routine applies to today.
* **Grid Tap-to-Schedule**: Tapping any vacant hour slot opens the schedule sheet pre-filled with that start time.

---

### Module 5: Mutual Habits & Shared Rituals

Fosters mutual growth and positive daily accountability without toxic gamification.

#### Field-Level Schema & Validation
* `id` (`TEXT`, Primary Key): UUID.
* `title` (`TEXT`, Required): Habit name (e.g. *"10k Steps"*, *"Read 20 Pages"*, *"No Screens After 10 PM"*).
* `category` (`TEXT`, Required): *Wellness*, *Fitness*, *Mindset*, *Home*, *Bonding*.
* `target_days` (`TEXT`, Required): Active days mask (`"mon,tue,wed,thu,fri,sat,sun"`).
* `is_joint` (`BOOLEAN`, Default: `true`): Whether completion requires both partners or either partner.
* **Completions Table (`LocalHabitCompletions`)**:
  * `habit_id` + `completion_date` + `user_id`: Records date and user completion stamps.

#### Advanced Capabilities
* **Streak & Rest-Day Engine**:
  * Calculates current and best streaks with graceful rest-day tolerance.
  * Golden celebration particle glow upon completing all mutual habits for the day.
* **Real-Time Partner Ticks**: Visual indication when your partner has completed their half of a joint habit.

---

### Module 6: Shared Calendar & Multi-Year View

Coordinates joint doctor visits, vacations, anniversaries, family events, and bill due dates.

#### Field-Level Capabilities
* **Day, Week, Month & Year Views**:
  * Day view integrates routine time blocks alongside calendar events.
  * Month view displays event dots and renewal badges.
  * Year view displays high-level 12-month calendar grid with `<` and `>` arrow chevrons for seamless year-by-year navigation.
* **Calendar Event Form Sheet**: Supports title, location, start/end timestamps, alert reminders, and shared vs private flags.

---

### Module 7: Shared Lists & Household Notes

Lightweight, real-time shared lists for groceries, packing, date night bucket lists, and home improvement.

#### Field-Level Schema
* `id` (`TEXT`, Primary Key): UUID.
* `list_id` (`TEXT`, Required): Category reference (*"Groceries"*, *"Home Setup"*, *"Wishlist"*).
* `title` (`TEXT`, Required): Item text.
* `is_completed` (`BOOLEAN`, Default: `false`).
* `completed_by` (`TEXT`, Nullable): User attribution.
* `order_index` (`INTEGER`, Required): Drag-and-drop sort order.

---

### Module 8: Security, Zero-Knowledge Crypto & Sync Protocol

The technological foundation that makes Cove private, resilient, and ultra-low-cost.

#### Core Technical Specifications
* **Key Derivation & Storage**:
  * Private Home Key generated on-device via `libsodium` (XChaCha20-Poly1305 / Ed25519).
  * Persisted strictly in hardware-backed keystores: **Android Keystore** and **iOS Keychain** via `flutter_secure_storage`.
* **Zero-Knowledge Event Sourcing**:
  * All mutations are written locally to SQLite (`Drift`) first, then encrypted into an encrypted JSON blob (`payload_ciphertext`) before reaching the cloud relay (`home_events`).
  * Supabase backend acts purely as a dumb encrypted mailbox; it possesses **zero knowledge** of transaction amounts, names, or routines.
* **Peer Pairing Protocol**:
  * Generates high-density QR code containing base64-encoded Home Key + 6-digit numeric backup pairing code.
  * 1-tap WhatsApp/SMS deep link auto-populates credentials on Partner 2's device.

---

## 4. Future Product Roadmap (v1.1 to v2.5)

```
2026 Q4: v1.1 "The Intimacy & Glances Pass"
┌────────────────────────────────────────────────────────┐
│ • iOS & Android Home Screen Widgets (Today Routine)    │
│ • Photo Attachment to Expenses (Milestone Memories)   │
│ • Custom Home Ambient Audio (Calm Rain, Fireplace)     │
└────────────────────────────────────────────────────────┘
                           │
                           ▼
2027 Q1: v1.2 "Household Intelligence & Export"
┌────────────────────────────────────────────────────────┐
│ • Automated Recurring Bill Alerts (Push 48h before)    │
│ • Monthly Financial & Habit PDF Export (for budgeting) │
│ • Multi-Currency Real-Time Travel Pool                 │
└────────────────────────────────────────────────────────┘
                           │
                           ▼
2027 Q2: v1.3 "Wearable & Ambient Extension"
┌────────────────────────────────────────────────────────┐
│ • Apple Watch & Wear OS Complications (1-tap habits)   │
│ • Siri Shortcuts & Google Assistant ("Log grocery")   │
│ • iPad & Android Foldable Expanded Dual-Pane Canvas    │
└────────────────────────────────────────────────────────┘
                           │
                           ▼
2027 Q3-Q4: v2.0 "The Connected Sanctuary"
┌────────────────────────────────────────────────────────┐
│ • Smart Receipt OCR (On-Device Apple/Google Vision AI) │
│ • Joint Annual Relationship Retrospective ("Our Year") │
│ • Encrypted Cloud Vault for Home Documents & Deeds     │
└────────────────────────────────────────────────────────┘
```

### Detailed Roadmap Features

#### v1.1: The Intimacy & Glances Pass (Target: Month 2)
* **Home Screen Widgets**:
  * Small Widget: Mutual habit completion progress ring + partner status.
  * Medium Widget: 24h Routine Timeline showing current and next scheduled time block.
* **Memory Receipts**: Option to attach a single photo memory to any shared expense (e.g. date night photo attached to the dinner bill).
* **Ambient Soundscapes**: Optional subtle background white noise (soft rain, wood hearth) while planning the week in Cove.

#### v1.2: Household Intelligence & Data Portability (Target: Month 4)
* **Proactive Bill Alerts**: Push notifications 48h before a subscription or EMI renews, allowing couples to cancel unwanted trials before getting charged.
* **Elegant PDF & CSV Statements**: 1-tap generation of a beautifully styled monthly household summary for personal accounting.
* **Multi-Currency Travel Mode**: Automatically tag expenses to a specific vacation trip (e.g. *"Tokyo 2026"*), converting foreign currencies to home currency in real-time.

#### v1.3: Wearables & Ecosystem Deepening (Target: Month 6)
* **Apple Watch & Wear OS Apps**:
  * Glance current routine time block directly from the wrist.
  * 1-tap check-off for daily habits.
* **Foldable Tablet Optimization**: Full dual-pane view on Samsung Galaxy Z Fold and iPad (Ledger on the left, Category Progress and Details on the right).

#### v2.0: The Connected Sanctuary (Target: Month 12)
* **On-Device Receipt OCR**: Take a photo of a restaurant or supermarket receipt; on-device Apple Vision / Google ML Kit parses item totals and auto-fills the expense form without sending any unencrypted image to cloud servers.
* **"Our Year in Sanctuary"**: An intimate year-end retrospective showing total household savings, completed habits, hours spent together in routines, and top milestones.
