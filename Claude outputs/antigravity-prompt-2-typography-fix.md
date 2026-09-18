# Antigravity build prompt — Cove typography, one source of truth

> Paste everything below the line into Antigravity as a single task. Run it independently of the restructure prompt; they don't overlap.

---

You are working in the Cove Flutter repo. Typography is rendering inconsistently across the app. Fix the causes, not the symptoms, and leave the codebase with exactly one place that defines type.

`DESIGN_SYSTEM.md` §3 is the intended scale. **General Sans stays the UI face and Bodoni Moda stays the display face** — this task is not a typeface change.

## What is actually wrong (verified in the repo, don't re-litigate, just fix)

1. **Bodoni is fetched over the network at runtime.** `GoogleFonts.bodoniModa(...)` is called at 11 sites — `lib/core/theme/cove_typography.dart` (×3), `lib/features/today/today_screen.dart` (×4), `lib/features/home/about_cove_screen.dart` (×2), `lib/features/dashboard/dashboard_screen.dart` (×1), `lib/core/widgets/cove_streak_badge.dart` (×1). On first run, offline, or a slow network these silently fall back to the platform default, which is the mismatch that shows up in the app. Worse, passing `textStyle: TextStyle(fontFamily: 'BodoniModa')` into `GoogleFonts.bodoniModa()` does **not** make it use the bundled asset — the Google font family wins, so `assets/fonts/BodoniModa-Medium.ttf` is currently dead weight for those styles.

2. **Only one Bodoni weight is bundled, and no italic.** `pubspec.yaml` declares `BodoniModa` with a single asset at weight 500. The code asks for `w400`, `w600`, `w700` and `FontStyle.italic` in several places (the Today greeting, the quote lines, the About screen, the Today section heading). Flutter fakes those — synthetic bolding and a sheared oblique — which on a high-contrast didone looks visibly wrong.

3. **128 raw `fontFamily: 'GeneralSans'` literals** are scattered across feature files with hand-tuned sizes and weights instead of going through `context.typography`, so the scale drifts screen to screen.

4. **An undeclared font family is referenced.** `lib/core/widgets/cove_web_sidebar.dart:88` sets `fontFamily: 'CormorantGaramond'`, which is declared nowhere in `pubspec.yaml` — it renders as the platform default.

5. **`fontFamily: 'monospace'`** appears at 8 sites in `lib/features/changelog/`. That is a platform alias, not a declared family, so it renders differently on Android, web and desktop.

6. **Figures are not tabular.** Amounts, totals, streaks and calendar dates use proportional figures, so columns of numbers jitter as values change.

## What to do

### 1. Drop the runtime font dependency

- Remove the `google_fonts` package from `pubspec.yaml` and every import of it. All faces ship as bundled assets.
- Replace every `GoogleFonts.bodoniModa(...)` call site with the matching token from `CoveTypography` (add a token if none fits — see step 3). No call site constructs its own Bodoni `TextStyle`.

### 2. Bundle the real Bodoni weights

Add the missing static Bodoni Moda assets under `assets/fonts/` and declare them in `pubspec.yaml` under the existing `BodoniModa` family:

- Regular 400, Medium 500, SemiBold 600, Bold 700
- Italic 400 and Italic 500 (`style: italic` in the pubspec font entry)

Bodoni Moda is SIL Open Font License, so shipping the static instances is fine — keep the licence file with the assets. If you'd rather ship the variable font, instance it to those weights at build time rather than relying on runtime synthesis.

Then verify: no text in the app requests a Bodoni weight or style that isn't declared. If a design calls for a weight outside that set, change the design, not the rasteriser.

### 3. Make `CoveTypography` the only definition of type

In `lib/core/theme/cove_typography.dart`:

- Define every style from `DESIGN_SYSTEM.md` §3 with the bundled families via plain `TextStyle(fontFamily: ...)` — `displayLarge`, `headline`, `title`, `bodyMedium`, `bodyRegular`, `caption`, `largeNumber` — and add the tokens the app actually needs but currently improvises:
  - `displayItalic` — Bodoni italic, for the greeting and quote lines
  - `headlineBold` — Bodoni 700, for the names line
  - `sectionLabel` — the ~10px caps label with 0.14em tracking used as section headers throughout
  - `microLabel` — the ~8.5–9px caps label used inside pulse cards and entry rows
  - `amount` — Bodoni 500 with **tabular figures**
  - `mono` — a declared monospace family for the changelog (bundle one, e.g. JetBrains Mono Regular, rather than the `'monospace'` alias)
- Add `fontFeatures: [FontFeature.tabularFigures()]` to `largeNumber`, `amount` and any style used for dates, times, streaks or counts.
- Keep `CoveTypography.fromColors`, `copyWith` and `lerp` in sync with every token you add.

### 4. Migrate the call sites

- Replace all 128 `fontFamily: 'GeneralSans'` literals with the appropriate `context.typography.<token>`, using `.copyWith(color: ...)` only for colour. Where a call site's size or weight doesn't match any token, snap it to the nearest token rather than preserving the drift — list anything you had to change by more than 1px in your summary so it can be reviewed.
- Replace the 4 raw `fontFamily: 'BodoniModa'` literals (`cove_splash_screen.dart`, `monthly_budget_sheet.dart` ×3) with tokens.
- Replace `CormorantGaramond` in `cove_web_sidebar.dart` with the Bodoni display token.
- Replace the 8 `'monospace'` literals in `lib/features/changelog/` with the new `mono` token.

### 5. Lock it down

- Add a test (or a `dart analyze` custom lint / a small CI script) that fails if `GoogleFonts`, a raw `fontFamily:` string, or a hardcoded `FontWeight` + `fontSize` pair appears anywhere outside `lib/core/theme/`. This is the part that stops the drift coming back.
- Update `DESIGN_SYSTEM.md` §3 to list the final token set, the bundled font files and their weights, and a one-line rule: *type is only ever consumed through `context.typography`.*

## Acceptance checks

1. `grep -r "GoogleFonts" lib/` returns nothing; `google_fonts` is gone from `pubspec.yaml` and `pubspec.lock`.
2. `grep -rn "fontFamily:" lib/` returns hits only inside `lib/core/theme/`.
3. Airplane mode, fresh install, first launch: every Bodoni heading, figure, greeting and italic quote renders in real Bodoni Moda — no platform-default fallback anywhere.
4. Every italic and bold Bodoni in the app is a real cut, not a synthesised one. Compare the Today greeting and the About screen against the bundled specimens.
5. Amounts in the expenses list, the commitments total and the calendar day totals stay column-aligned as digits change.
6. `flutter analyze` is clean, the tests in `test/` pass, and the new guard test fails when you deliberately reintroduce a raw `fontFamily` literal.
7. Spot-check both themes at phone and desktop width — the type scale should read identically on both.

## Out of scope

Do not change the typefaces themselves, the colour tokens, the component geometry or any screen's layout. If fixing a call site would visibly change a layout, note it in your summary and leave the layout alone.
