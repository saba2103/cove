# CoveDetailSheet — `lib/core/widgets/cove_detail_sheet.dart`

One skeleton, many fillings. Every record opens into this. Reference:
`design/screens/detail-sheets.png` (an expense) — the image is the layout, this is the law.

## The skeleton, top to bottom

| Part | Contract |
|---|---|
| Sheet | `CoveSheet` — nothing new about the container |
| **Kind line** | a 20dp `(literal)` kind glyph, the kind in `CoveType.capsPage` / `text.primary`, then `· {context}` in `text.tertiary` (the category, the list, the cadence). Trailing: a ghost `CoveRoundButton` ⋯ (menu) and ✕ (close). At cover width the context may wrap to a second line — **never ellipsize it**. |
| **The slip** | the kind's object, **paper variant, in both modes**, full content width, `CoveSpace.md` below the kind line. Carries live state (PAID stamp, struck note, filled punch). |
| **Meaning panel** | `surface.row` fill, `CoveRadius.card`, `CoveSpace.md` padding, `CoveSpace.gutter` above. A 24dp `(literal)` leading glyph, a title in `CoveType.rowTitle` / `text.primary`, one sub-line in `CoveType.rowSub` / `text.tertiary`. |
| **Verbs** | `CoveSpace.lg` above. **Edit**, plus at most ONE kind action. Pill buttons, equal width, `CoveSpace.md` gap, height `CoveSize.hit`, 1dp `line.strong` border, label `CoveType.rowTitle`. Everything else the sheet can do goes in the ⋯ menu. |

The prototype also shows a ✓ in the kind line. **It is dropped:** the kind action already
lives in the verb row, and the same action in two places is one too many.

## The meaning panel — from existing data only

| Kind | Title | Sub-line |
|---|---|---|
| Expense, shared | "{share} is your half" when the split is exactly 50/50, otherwise "{share} is your share" | "{who} paid" |
| Expense, private | "Yours alone" | "Not part of the shared total" |
| Commitment | "Renews {date}" | "{amount} a month/a year · via {financedThrough}" |
| EMI | "{paid} of {total} paid" | "Ends {date} · {remaining} left" |
| Habit | "{run} days running" | "Best {best} · {cadence}" |
| Task | "On {list}" — or "Done by {name}" when done | "Added by {name} · {date}" |
| Category | "{amount} this month" | "{n} purchases · {pct}% of spending" |
| Event | "{weekday}, {date} · {time}" | "{location} · {who}" |

**Not built in Phase 3**, because the data does not exist — report them, don't build them:
- The prototype's "…added to your 50/50 balance with Ancy" — there is no running-balance model.
- "A pub under Groceries? Move to Eating out" — there is no category-suggestion feature.

The expense share must come from the split logic `expenses_screen.dart` already uses.
Extract it into a shared helper; do not write a second copy of the arithmetic. Note that
`splitRatio` also encodes visibility (`ExpenseVisibilityExtension.fromSplitRatio`) — a
private expense has no "half".

## Verbs — existing actions only

| Kind | Second verb |
|---|---|
| Expense | — (Edit only) |
| Commitment | Mark paid |
| EMI | Mark paid · Foreclose goes in ⋯ |
| Habit | Check in / Undo check-in |
| Task | Done / Not done |
| Category | — |
| Event | — |

**Every verb and menu item must map to an action the current sheet already performs.** If
the current sheet has an action not listed here, keep it in ⋯. If this table names one the
app cannot perform, omit it and report it. Destructive items in ⋯ say what they destroy:
"Delete this expense", never "Delete".

## Rules
- The visibility line on the slip is read-only here.
- The sheet's semantics read the slip's state first, then the meaning panel.
- Nothing in the skeleton is screen-specific. A filling supplies a kind, a context, a slip,
  a panel and verbs — nothing else.
