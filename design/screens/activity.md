# Activity — `lib/features/activity/activity_screen.dart`

Reference: `activity.png` · Budget: 12

Reached from the notification icon in the Today header. **Not a nav destination.**

## Order
1. `CovePageHeader` — back, "Activity", unread count, "Mark all read".
2. Digest card on top: no collapse, a chevron day stepper, one paragraph per person.
3. Day-grouped feed, kinds rendered as their forms.

## Rules
- Day headers put the date on the **left** and Today/Yesterday on the **right**; named days drop the date.
- Unread = a gold ring **plus** full-strength type. Read items drop to `text.secondary`. Colour never alone.
- Items are grouped when they arrived together ("six things, in one go"), not listed individually.
