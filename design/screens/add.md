# Add — `lib/features/calendar/calendar_create_sheet.dart` and the six form sheets

Reference: `add.png` · Budget: 8 (+ the form sheets)

**This is the largest structural change in Phase 3.** The app has six separate form
sheets; the design is ONE flow. Converting it is a rebuild, not a restyle — treat it as
its own prompt, possibly several.

## Shape
One question per page, large and centred. Answers become tappable crumbs along the top.
The amount has its own 52pt keypad so the system keyboard never appears. The last step is
**the kind's paper slip** (receipt / ticket / note / ring / voucher / band), then Add.

## Rules
- Tapping any field on the review slip jumps to that step and returns to the slip.
- **The date is never assumed.** An expense asks "When?" like everything else. The day picker runs on real dates anchored where the + was tapped: the seven days **ending** at the anchor for an expense (a spend already happened), the seven days **starting** at it for a task or event.
- Habit and Routine have **no date step** — the frequency defines them.
- "Whose is it?" and "Can the other person see it?" are **two separate questions**, with the privacy toggle living inside the owner step. Turning on private also selects the user; Ancy/Both are disabled while it is on.
- **Again** repeats the last repeatable entry — Expense, Task and Event only. It carries everything over and blanks the one field that changes: the amount for an expense, the day for a task or event.
