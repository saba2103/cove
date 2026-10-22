# Detail sheets — `expense_detail_sheet.dart` and siblings

Reference: `detail-sheets.png` · Budget: 10 + 41 + 13 + 11 + 6 + 12

One skeleton, eight fillings: Expense · Event · Task · Habit · Commitment · EMI · Routine · Category.

## Order
1. `CoveSheet`.
2. A kind line.
3. **The kind's paper slip** — the same object the Add flow ends on, from one shared widget.
4. One real sentence about the record.
5. A meaning panel.
6. One verb.

## Rules
- The slip carries **live state**: marking rent paid drops the PAID stamp onto the voucher and fades the due circle; ticking a task strikes the note; paying an EMI fills another punch.
- Adding shows the **plan**; viewing shows the **live state**. Same object, different content — that is correct, not a bug.
- The visibility line rides on the slip and is **read-only** here. Changing it is a verb in the ⋯ menu: "Make it private" / "Make it shared again".
- Slip state must be exposed as semantics, not just drawn (Paid, Done, 12 of 48) — WCAG 4.1.2.
