# Phase 3 — the screens

Twelve prompts. Each converts one screen to the primitives, deletes its line from
`tool/style_allowlist.txt`, and deletes its entry from the overflow backlog in
`test/golden/screens_golden_test.dart` if it had one.

## The template

> Convert `<screen file>` to the Cove primitives.
>
> Read first, in this order:
>   1. `design/screens/<name>.md` — the rules for this screen
>   2. `design/screens/<name>.png` — the finished design, full scroll height
>   3. `design/specs/` — the primitive contracts
>
> The image is the layout; the spec is the law. **Never measure a number off the image** —
> it is a 318dp-wide prototype and every dimension in it is pre-scale. Take dimensions
> from `CoveSpace` / `CoveSize` / `CoveRadius` and type from `CoveType`.
>
> Rules:
> - Use the existing primitives. Do not build a local row, header, avatar, card, sheet or
>   toast — if one does not fit, STOP and tell me what is missing rather than forking it.
> - Every colour, size, radius and text style comes from the tokens. When you are done,
>   this file's line must be DELETED from `tool/style_allowlist.txt`, not lowered.
> - Wrap the page content in `CoveMaxWidth`.
> - Bottom scroll padding is `CoveSpace.barClearance + MediaQuery.padding.bottom`,
>   replacing whatever `SizedBox` currently stands in for it.
> - Behaviour does not change. No new features, no removed features, no renamed routes.
>   If the design implies behaviour the app does not have, report it; do not build it.
> - If this screen has an entry in the overflow backlog, it must be removed and the suite
>   must stay green WITHOUT it — that is how we know the overflow is fixed rather than
>   suppressed.
>
> Then regenerate this screen's 6 goldens, inspect all six yourself, and report what
> changed. `tool/check.sh` must exit 0.

## Order

Ramp up. The first three are small enough that a flaw in the template is cheap to fix.

| # | Screen | File | Budget | Overflow |
|---|---|---|---|---|
| 3.1 | Our home | `home/home_settings_screen.dart` | 4 | — |
| 3.2 | Routines | `routines/routine_screen.dart` | 8 | — |
| 3.3 | The year | `subscriptions/commitments_helicopter_screen.dart` | 10 | — |
| 3.4 | Activity | `activity/activity_screen.dart` | 12 | — |
| 3.5 | Settings | `profile/profile_screen.dart` | 14 | — |
| 3.6 | Calendar | `calendar/calendar_screen.dart` + `views/calendar_agenda_view.dart` | 4 + 33 | cover |
| 3.7 | EMIs | `subscriptions/emi_tracker_screen.dart` | 40 | — |
| 3.8 | Commitments | `subscriptions/subscriptions_screen.dart` | 28 | **cover + phone** |
| 3.9 | Expenses | `expenses/expenses_screen.dart` | 43 | cover |
| 3.10 | Today | `today/today_screen.dart` | 34 | cover |
| 3.11 | Detail sheets | 6 files | 10+41+13+11+6+12 | — |
| 3.12 | Add | the six form sheets → one flow | 8 + sheets | — |

**3.12 is a rebuild, not a conversion.** Six separate form sheets collapse into one
"One Thing at a Time" flow. Do not attempt it as a single prompt — it needs its own
sequence, and it should come last, when every primitive it depends on is proven.

## What to watch

- **A local widget that duplicates a primitive.** The commonest failure. If a screen grows
  its own `_Row` or `_Header`, the primitive did not fit and you need to know why.
- **An allow-list line lowered instead of deleted.** Means literals remain.
- **An overflow entry still present after conversion.** Means the layout bug survived.
- **Behaviour changes smuggled in as "improvements".** Phase 3 is a restyle.
