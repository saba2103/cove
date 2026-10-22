# EMIs — `lib/features/subscriptions/emi_tracker_screen.dart`

Reference: `emis.png` · Budget: 40

## Order
1. `CovePageHeader` — back button, "EMIs", and the **"What if…" pill** on the right (28dp, the one labelled header action in the app).
2. Three cards: when it all closes · the monthly EMI with a who-split bar · left-to-pay with a paid-% bar.
3. The staircase graph — "tap the steps".
4. Ledger rows grouped by who pays.

## Rules
- Long-press a row for what-if ("if we close this one"), which recomputes the tray and the free-by date. The header pill is the **discoverable** route to the same thing — long-press alone fails WCAG 2.5.1.
- There is **no "Save as a plan"**. It was removed for promising a feature that does not exist. Do not reintroduce it.
- An EMI is a commitment that counts down: render its voucher punched, not stamped.
