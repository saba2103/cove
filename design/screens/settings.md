# Settings — `lib/features/profile/profile_screen.dart`

Reference: `settings.png` · Budget: 14

Six sections in the app's own words: Preferences · Notifications · Backup & restore · Household · About Cove · Account.

## Order
1. `CovePageHeader` — back, "Settings".
2. The user alone in the first card — **their own avatar, not `both`**.
3. The six sections as `CoveRow` lists.

## Rules
- The couple is a row under **Household** that navigates to Our home; it is not the first card.
- Every row opens something real. No dead rows.
- Times are set on a **conventional clock dial**, and the dial needs a non-drag alternative (WCAG 2.5.7).
- Cards show the **name only** — no last four, no bank.
- Version is secondary text, never a row title.
- Destructive actions live behind one door at the foot, each saying what it actually destroys.
- Backup & restore is now real (Drive, Argon2id passphrase). Reflect its true state; never show a hardcoded "last backed up".
