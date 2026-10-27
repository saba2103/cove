# Phase 4.5 — every corner a squircle (100% smoothing)

Decided 27 Oct: every rounded corner in the app uses Figma's corner smoothing at **100%**, via
the `figma_squircle` approach (`SmoothRectangleBorder`, `ClipSmoothRect`), and the radii go
up about **20%**, snapped to the 4dp grid, so corners keep the same visual roundness.

| Token | Now | New |
|---|---|---|
| radius.inline | 16 | **20** |
| radius.card | 20 | **24** |
| radius.hero | 28 | **32** |
| radius.sheet | 32 | **40** |
| radius.device | 40 | **48** |
| radius.pill | 999 | 999 (fully round, unchanged) |
| radius.smoothing | — | **1.0** (new) |

**Not affected:** circles and pills (already fully round), and anything Android draws
(notifications, launcher icon, system dialogs).

**Short shapes:** where `(1 + smoothing) × radius` is more than half the shorter side, the
smoothing reduces automatically. Radius is never reduced. That's the package's
non-preserving mode, and it's expected (a 52dp row plate gets about 60%).

**Hairlines:** every border is drawn **inside** the shape, the same way everywhere, so a
stroke is never half-clipped where a card meets a clip edge. One golden zooms in on a corner
to prove the line is the same thickness on the straight edge and through the curve.

Run in order. Each ends with `tool/check.sh` exiting 0 and a commit. Do 4.5 after 4.4d is
installed on the Fold and the widgets have been checked.

---

## 4.5a — the token, one shape, and the gate

````
Read product/PROMPTS-PHASE4-SQUIRCLE.md in full.

1. Dependency: use `figma_squircle` at its latest stable version, pinned. If it doesn't
   support our Flutter/Dart version or looks unmaintained, vendor its path maths (MIT, keep the
   licence and attribution) into lib/core/shape/ instead, and say which you did.
2. Tokens: in design/tokens.json, change the radii as the table says and add
   `radius.smoothing = 1.0`. Regenerate with `dart run tool/gen_tokens.dart`, and commit the
   regenerated cove_tokens.dart. CoveRadius gains `smoothing`.
3. One helper, lib/core/shape/cove_shape.dart:
   - `CoveShape.border(radius, {side})` → a SmoothRectangleBorder at CoveRadius.smoothing,
     with the border drawn inside
   - `CoveShape.clip(radius, child)`
   - `CoveShape.decoration(radius, {color, gradient, side, shadows})` → a ShapeDecoration
   - per-corner variants for sheets (top corners only)
   Shadows follow the smooth outline, not a rounded rectangle.
4. Theme: in cove_theme.dart, every shaped Material theme uses CoveShape: cards, dialogs,
   bottom sheets, popup menus, snack bars, chips, buttons, and input borders. Write a
   CoveInputBorder (an InputBorder drawing the smooth path) if OutlineInputBorder can't.
5. The gate: extend tool/style_gate.dart with a second, separate allow-list
   tool/shape_allowlist.txt (same ratchet rules: budgets only go down, and you delete a line,
   never lower it). It counts `BorderRadius.circular`, `BorderRadius.only`,
   `BorderRadius.vertical`, `BorderRadius.all`, `Radius.circular`, `RoundedRectangleBorder`,
   `ClipRRect`, `RRect.from` and `borderRadius:` under lib/ — except inside lib/core/shape/.
   Start it at today's counts (about 437 in 89 files).
6. Goldens:
   - CoveShape at each radius, both modes
   - the zoomed corner, proving hairline thickness is equal on the edge and in the curve
   - a 52dp row plate showing the reduced smoothing
7. Report: the package or vendored choice, and the starting shape_allowlist totals.

Nothing under lib/features changes yet, except what the theme changes on its own. List
which screen goldens moved because of the theme alone. Commit as
`feat(shape): squircle token, CoveShape, theme and the shape gate (4.5a)`.
````

## 4.5b — primitives

````
Convert lib/core/widgets/ (everything except slips/) to CoveShape. Delete each file's line from
tool/shape_allowlist.txt. Same before/after contact sheet as Phase 4.1
(build/shape_batches/4.5b.png). Every visible change must be either the smoother corner or
the 20% radius increase. Anything else is a bug.
Commit as `style(shape): primitives take the squircle (4.5b)`.
````

## 4.5c — the slips

````
The paper objects build their own paths (ticket notches, receipt teeth, voucher punches, the
band, the habit card, the note). Give each one's rounded corners the same 100% smoothing,
using the same maths as CoveShape (expose a `smoothCornerPath` helper from lib/core/shape/).
Keep the notches, teeth and punches exactly where they are. Paper and ink, both modes,
goldens regenerated and compared. Delete the slips' lines from the shape allow-list.
Commit as `style(shape): slips take the squircle (4.5c)`.
````

## 4.5d to 4.5f — the screens, in three batches

````
Do batch <4.5x> of product/PROMPTS-PHASE4-SQUIRCLE.md, with the same rules as 4.5b:
CoveShape everywhere, delete each file's line, a before/after contact sheet, and the
overflow guard on.
````

| Batch | Files |
|---|---|
| **4.5d** | Today, Calendar, Routines, Activity, Our home, Settings, the floating bar, the Android widgets' Flutter views |
| **4.5e** | Expenses, Commitments, The year, EMIs, every detail sheet, the Add flow |
| **4.5f** | everything left (forms, dialogs, Lists, Habits, changelog, onboarding, weather) |

At the end of 4.5f, tool/shape_allowlist.txt must be **empty**. Remove the file, and keep the
gate as a hard rule: no raw radius anywhere outside lib/core/shape/.

## 4.5g — performance on the slower phone

````
Smooth shapes are paths, not rounded rectangles. Measure the cost on Ancy's Pixel 6 class of
device:
- Profile build: scroll Lists (50 items), Expenses (a full month) and Today, and open and close
  a detail sheet 10 times.
- Report frame times (p50, p90, worst) against the same flows on the commit before 4.5a.
- Anything over 16ms p90: cache the path per size first. If it's still slow, stop and report;
  don't fall back to plain rounded corners without Saba's say-so.
If no Pixel 6 is connected, use the Fold in profile mode and say so.
Commit any fixes as `perf(shape): squircle paths cached where it matters (4.5g)`.
````
