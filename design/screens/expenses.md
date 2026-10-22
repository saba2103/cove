# Expenses — `lib/features/expenses/expenses_screen.dart`

Reference: `expenses.png` · Budget: 43 (the largest) · Overflow: `expenses_screen.cover`

## Order
1. `CovePageHeader` — "Expenses", month + total as the baseline readout.
2. Hero card: month total in `CoveType.heroFigure`, the pace line against last month, a budget bar with a TODAY marker.
3. Every day this month — a bar chart, annotated on the graph itself rather than described in a paragraph below it.
4. Pace cards: paid now / on the card / about to land.
5. Where it went — eight categories with their own colours, tap one to isolate it in the bar and the rows below.
6. Every purchase — date-grouped `CoveRow` list with avatars, category dot, card, amount.

## Rules
- **Every metric is a comparison**, never a bare number: pace vs last month, projection vs budget, what a day can cost from here.
- The ledger has **its own month switcher**; browsing August must not disturb the standing month in the hero above.
- Category colours come from `category.*` tokens and are also named in text — colour never carries the meaning alone.
- Amounts use `money.more` / `money.less` only with a sign or a word beside them.
