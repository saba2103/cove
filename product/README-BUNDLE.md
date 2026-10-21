# Cove v2 — Phase 0/1 bundle

Drop these into the repo root, keeping the paths. Nothing here touches your data.

```
design/tokens.json                 the source of truth, authored at DEVICE scale
tool/gen_tokens.dart               tokens.json -> cove_tokens.dart
tool/check_contrast.py             WCAG gate over the token file
tool/style_gate.dart               the raw-literal ratchet
tool/style_allowlist.txt           68 files, 787 literals, budgets that only go down
tool/check_version.dart            pubspec <-> kCoveCurrentAppVersion
tool/check.sh                      all of the above + analyze + test
lib/core/theme/cove_tokens.dart    GENERATED — committed so you can diff it
test/golden/golden_harness.dart    3 widths x 2 modes per screen
assets/fonts/PlusJakartaSans-*.ttf four static weights (sent separately)
```

## Do these in order

1. **Fonts.** Put the four `.ttf` files and `OFL.txt` in `assets/fonts/`, then add to
   `pubspec.yaml` under the existing `fonts:` block:

   ```yaml
       - family: PlusJakartaSans
         fonts:
           - asset: assets/fonts/PlusJakartaSans-Regular.ttf
             weight: 400
           - asset: assets/fonts/PlusJakartaSans-Medium.ttf
             weight: 500
           - asset: assets/fonts/PlusJakartaSans-SemiBold.ttf
             weight: 600
           - asset: assets/fonts/PlusJakartaSans-Bold.ttf
             weight: 700
   ```
   Leave General Sans in place until the last screen is converted.

2. **Verify the generator.** `dart run tool/gen_tokens.dart` then `git diff`.
   It must come back empty. If it doesn't, the generator is wrong and the
   committed `cove_tokens.dart` is right — fix the generator, not the output.

3. **Wire the theme.** `cove_theme.dart` currently builds from `CoveColors`.
   Have it put `CoveTokens.dark` / `CoveTokens.light` in `ThemeData.extensions`,
   and keep `CoveColors` alongside until the allow-list is empty. Then fill in
   `coveThemeFor()` at the bottom of `golden_harness.dart`.

4. **Snapshot the schema, before any migration.**
   `dart run drift_dev schema dump lib/sync/db/app_database.dart drift_schemas/`
   This captures v11 — the shape your real data is in. Once you're past v11 you
   can never generate it again.

5. **Baseline the goldens** from the app as it is today, before any conversion.
   Those are the "before"; each screen prompt replaces its own, deliberately.

6. **Add `tool/check.sh` to the Definition of Done** in `AGENTS.md`, replacing
   "run flutter analyze and flutter test".

## What the gates buy you

An agent can't claim a screen is done while raw literals remain in it, can't
quietly undo an earlier screen (the golden moves), can't drift the token file
from the generated Dart, and can't ship a colour pair under 4.5:1.

## Two things changed from the design system, on purpose

**The avatar initials never cleared AA.** Measured across the gradients: your gold
was 4.06:1 at best, Ancy's sage 3.34:1. Both now clear 4.5 — gold lifted slightly
(`#D2B38E -> #A47C51`, dark initial, 4.54), sage deepened more visibly
(`#587166 -> #2C3C37`, cream initial, 4.51). Side effect worth having: one person
now reads clearly light and the other clearly dark, so you tell them apart faster.

**`person.both` is a ring, not a fill.** Which is what the decisions doc said all
along — "a shared thing is not owned by either of you, so it gets no fill". The
ring blends the two people's colours rather than using gold, per the Aura note,
which frees gold for one-per-screen. The ampersand is `text.primary`, so it passes
on any surface.

**And one addition:** `size.maxContent = 420`. Page content is capped and centred
on anything wider. Your Fold's inner screen is why.
