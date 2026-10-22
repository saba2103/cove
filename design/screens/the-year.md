# The year — `lib/features/subscriptions/commitments_helicopter_screen.dart`

Reference: `the-year.png` · Budget: 10

## Order
1. `CovePageHeader` — back, the **year number as the title**, two separate chevron buttons.
2. Change-on-the-month chart with the current month marked.
3. Month ledger table: month · ± delta · each person · total.
4. Footer row: year-over-year.

## Rules
- Ledger rows carry **no fill, no radius and no side stroke**. The current month is tinted with a gold name and warmed hairlines — that is the only emphasis.
- The ± delta column uses `money.more` / `money.less` **with its sign**. There is no split bar on this screen.
- The prior-year comparison total is a **placeholder**, not a real figure. Keep it visibly provisional; do not invent a calculation for it.
