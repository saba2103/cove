# Add — one flow in place of the create forms

Reference: `add.png` (the picker) and `add-steps/` (every step, every review, Added, Again).
Full spec: `design/specs/14-add-flow.md`. Prompts: `product/PROMPTS-PHASE3-ADD.md`.

**This is a rebuild, not a restyle.** The app has six create forms and a create picker
(`calendar/calendar_create_sheet.dart`). The design is one flow. The old form sheets stay,
because Edit still uses them; only the create paths move to Add.

## Rules, in short
- One question per page; answers become tappable crumbs; the dots say how far is left.
- The amount has its own keypad; a time gets a clock face; a day gets an anchored strip.
- **The date is never assumed.** It is preselected to the anchor and always asked.
  The anchor is where + was tapped: the seven days ending at it for an expense, starting at it
  for a task or event.
- Habit, commitment and routine have no date strip; their frequency defines them.
- Privacy lives inside the owner step. Turning private on selects you and disables the partner.
- "Whose is it?" is asked only where an owner is stored: expense, commitment, (habit as
  visibility). Event, task and routine get it in Phase 4 with schema v12.
- **Again** repeats the last expense, task or event made through Add, and blanks the one field
  that changes: the amount for an expense, the day for a task or event.
- It ends on the kind's paper slip, and Add stamps that same paper as the confirmation.
