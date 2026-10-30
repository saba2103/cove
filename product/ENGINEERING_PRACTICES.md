# Cove Engineering Practices & Definition of Done

This document establishes the official engineering working agreements, quality standards, and Definition of Done (DoD) for Cove. 

---

## 1. Philosophy: Systems Over Memory

In fast-paced product development, human memory decays under delivery pressure. Relying on engineers or AI assistants to "just remember" to write tests, check linters, or update changelogs is an anti-pattern. 

We enforce quality through **deterministic gates, clear checklists, and agent rules**.

---

## 2. The Cove Definition of Done (DoD) Checklist

No feature, architectural refactor, or bug fix is considered **"Done"** until every item in this checklist is satisfied:

```markdown
- [ ] 1. Code Quality & Formatting
      - Respects existing architecture (W3C DTCG token pipeline via `design/tokens.json` → `lib/core/theme/cove_tokens.dart`, Indian numbering via `formatCoveAmount`, Drift SQLite offline-first).
      - Preserves comments, documentation, and existing docstrings.
      - Scoped strictly to the active Home (`LocalHomes`).

- [ ] 2. Static Analysis & Design System Gates
      - `flutter analyze` passes with 0 errors and 0 warnings.
      - `tool/check.sh` passes (`gen_tokens.dart` clean diff, `check_contrast.py`, `style_gate.dart` ratchet, `check_version.dart`).
      - No unused imports or deprecated API usage.

- [ ] 3. Automated Test Verification
      - Unit / widget tests written or updated for the changed logic.
      - Targeted test files run and pass with 100% success rate.
      - Schema changes accompanied by a new `drift_schemas/drift_schema_vN.json` dump, regenerated `test/drift/generated/`, and verified by `test/migration_test.dart`.

- [ ] 4. Changelog Maintenance
      - `product/CHANGELOG.md` updated under the active release section.
      - Follows standard format:
        * Outcome: Plain-language summary of what was accomplished and why.
        * Under the Hood: Technical bullet points detailing files, tables, and algorithms changed.

- [ ] 5. Product & Architectural Documentation
      - If a product decision, versioning nomenclature, or structural rule was altered,
        corresponding documentation in `product/` is created or updated.

- [ ] 6. Physical Device Smoke Test (When Device Connected)
      - App built (`flutter build apk --release`).
      - Installed onto connected test device via ADB.
      - Smoke tested to confirm seamless startup and UI responsiveness.
```

---

## 3. How Industry Leaders Prevent Practices From Being Missed

Leading software teams (Google, Meta, Stripe, Shopify, Airbnb) enforce quality practices across three programmatic layers:

### Layer 1: Pull Request (PR) Checklists
Every Pull Request template automatically loads a required markdown checklist. PR authors must check off test execution, database migration safety, and changelog updates before requesting review.

### Layer 2: Automated CI Bot Gates (Danger.js & Changesets)
Instead of relying on human vigilance, automated bots review PR diffs:
* If files in `lib/` are modified but `product/CHANGELOG.md` is untouched, CI automatically fails the build with a warning:
  > *"⚠️ Code changes detected in `lib/` without an entry in `product/CHANGELOG.md`. Please add an entry or apply the `skip-changelog` label."*
* Tools like `@changesets/cli` prompt developers via CLI to generate atomic changelog entries on branch creation.

### Layer 3: Conventional Commits & Automated Release
Using standard commit prefixes:
* `feat(expenses): cascade currency preference to existing records`
* `fix(activity): resolve home currency from SQLite in formatWithDb`
* `chore(docs): update engineering practices`

Release automation tools (`release-please`, `semantic-release`) parse commit messages to generate changelogs, tag git releases, and increment semver tags automatically on merge.

---

## 4. Antigravity Agent Working Agreement

When paired with Antigravity, the assistant automatically loads `.agent/rules/definition_of_done.md` and `AGENTS.md`. 

The assistant is strictly instructed to:
1. Proactively run `flutter analyze` and targeted `flutter test` commands before completing tasks.
2. Update [`product/CHANGELOG.md`](./CHANGELOG.md) as an atomic step of the task, rather than waiting for user reminders.
3. Keep product documentation synchronized in the `product/` directory.

---

## 5. System Chrome & SafeArea Convention

iOS and Android draw the status bar natively; the app must never draw a second status bar or fake status-bar chrome. See [`design/specs/00-system-chrome.md`](../design/specs/00-system-chrome.md).

1. **System Overlay Style**: Set `SystemUiOverlayStyle` once from the theme (`CoveTheme.overlayStyleFor(Brightness)` in [`lib/core/theme/cove_theme.dart`](../lib/core/theme/cove_theme.dart) and the root `MaterialApp.builder` in [`lib/main.dart`](../lib/main.dart)), never per screen:
   - Light icons (`SystemUiOverlayStyle.light`) on the dark theme; dark icons (`SystemUiOverlayStyle.dark`) on the light theme.
   - Transparent status bar colour (`Colors.transparent`) so `surfaceCanvas` runs underneath it.
2. **Top Inset**: Top inset comes from `MediaQuery.padding.top` (or `MediaQuery.paddingOf(context).top`), never a hardcoded height.
3. **Bottom Inset with Floating Bar**: Pages wearing the floating bar add `MediaQuery.padding.bottom` (or `MediaQuery.paddingOf(context).bottom`) to `CoveSpace.barClearance` for their bottom scroll padding.
4. **Header Spacing**: Content begins immediately below the top inset with no extra top padding of its own — the page header supplies its own top space.
5. **Max-Content Width**: Page content is constrained to `CoveSize.maxContent` (`420 dp`) and centred on wider viewports via [`CoveMaxWidth`](../lib/core/widgets/cove_max_width.dart).

---

## 6. Text Scaling & Reflow Convention (WCAG 1.4.4, 1.4.10)

Every in-app surface must survive `TextScaler.linear(1.3)` and `TextScaler.linear(2.0)` down to `320 dp` (`CoveWidth.cover`) in both Dark and Light modes with the overflow guard active, zero clipped text, and zero ellipsis truncation on meaningful labels:

1. **Reflow, Never Clamp**: Never cap or clamp `MediaQuery.textScalerOf(context)` on in-app widgets. The sole fixed `MediaQueryData` in `lib/` is [`CoveWidgetService._wrapForOffscreenRender`](../lib/features/widgets/cove_widget_service.dart), which rasterizes Android home-screen `RemoteViews` bitmaps (such as the Day Sheet widget) offscreen at their own widget dimensions.
2. **Preserve `1.0x` Geometry**: Gate scaled reflow rules behind `MediaQuery.textScalerOf(context).scale(1.0) > 1.0` or effective-width thresholds (`MediaQuery.sizeOf(context).width / textScale < CoveSize.compactThreshold`) so `1.0x` layouts remain pixel-identical:
   - [`CoveMetricGrid`](../lib/core/widgets/cove_metric_card.dart) stacks to a single full-width column.
   - Side-by-side rows stack via [`CoveReflowRow`](../lib/core/widgets/cove_reflow_row.dart) (single-pass `RenderBox` layout without `IntrinsicWidth`) or responsive `Wrap` / `Column` fallbacks.
   - [`CoveFloatingBar`](../lib/core/widgets/cove_floating_bar.dart) drops text labels to icons-only while preserving the central Add orb.
   - [`AddKeypad`](../lib/features/add/widgets/add_keypad.dart) keys grow taller with scaled digit metrics.
   - Slips (`CoveReceipt`, `CoveTicket`, `CoveVoucher`, `CoveHabitCard`, `CoveBand`, `CoveDial`, `CoveNote`) let their text wrap cleanly across lines.
3. **Automated Gate**: Enforced in `./tool/check.sh` via [`test/golden/text_scale_52_golden_test.dart`](../test/golden/text_scale_52_golden_test.dart).

---

## 7. Orientation Lock & Fold Inner-Screen Landscape Behaviour (`targetSdk 36`, Android 16)

Cove targets **Android 16 (`targetSdk = 36`**, `minSdk = 24` in [`android/app/build.gradle.kts`](../android/app/build.gradle.kts)) and intentionally keeps its portrait lock:
- `android:screenOrientation="portrait"` on `.MainActivity` in [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml) (with no `PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY` opt-out).
- `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` in [`lib/main.dart`](../lib/main.dart).

How Android 16 handles this lock across form factors:
1. **Phones & Fold Cover Screen (`smallestScreenWidthDp < 600dp`)**: On compact displays — such as the Pixel 6 (`411dp` / `485dp` forced density) and the Galaxy Z Fold7 folded cover screen (`320dp`) — Android 16 honours both `android:screenOrientation="portrait"` and `setPreferredOrientations([portraitUp])`, keeping Cove locked to portrait.
2. **Fold Inner Screen & Tablets (`smallestScreenWidthDp >= 600dp`)**: Under Android 16's adaptive-apps platform policy for `targetSdk >= 36`, the system sets `PRIVATE_FLAG_ACTIVITIES_RESIZE_MODE_RESIZEABLE_VIA_SDK_VERSION` and **ignores** `android:screenOrientation="portrait"`, `setPreferredOrientations`, and `resizeableActivity="false"` on any display with `sw >= 600dp`. When the Galaxy Z Fold7 is unfolded (`840×900dp`, `sw = 840dp`) and rotated 90°, Android rotates Cove freely into **`900×840dp` landscape** at full window bounds without letterboxing.
3. **Layout Strategy & Goldens**: Cove introduces **no separate landscape layout** on wide viewports — `AppShell` (`540dp` outer shell) and [`CoveMaxWidth`](../lib/core/widgets/cove_max_width.dart) (`CoveSize.maxContent = 420dp` when viewport width `>= 600dp`) centre the single-column canvas cleanly inside `900×840dp`. [`CoveWidth.wideLandscape`](../test/golden/golden_harness.dart) (`Size(900, 840)`) goldens on `TodayScreen` and `ExpensesScreen` in [`test/golden/screens_golden_test.dart`](../test/golden/screens_golden_test.dart) guard against overflow regressions at the Fold inner screen's landscape dimensions.

---

## 8. Text & Non-Text Contrast Convention (`WCAG 1.4.3, 1.4.11`)

Every text label (`>= 4.5:1`) and every meaningful UI boundary, control outline, focus indicator, or chart reference mark (`>= 3.0:1`) must clear WCAG AA through semantic tokens in [`design/tokens.json`](../design/tokens.json) — never through raw hex literals or ad-hoc `< 0.6` text alphas:

1. **Accent Text vs. Accent Fill**: Body and badge copy drawn in accent gold must use `cv.accentText` (or `cv.accentTint` where muted tint is intended), **never** `cv.accentFill` (whose light-mode fill `#A97C4F` is calibrated for `>= 3:1` control fills, not `4.5:1` text). Text sitting *on* an `accentFill` pill uses `cv.textOnAccent`.
2. **Sky-Backed Labels (`cv.textSky`)**: Text painted directly across Routines' 7-stop day/night sky gradient uses `cv.textSky`, verified at `>= 4.5:1` against every interpolated point of the sky in both dark and light modes.
3. **Decorative Dividers vs. Interactive / Meaningful Boundaries**:
   - `cv.lineHairline` and `cv.lineStrong` are strictly **decorative** dividers and card hairlines (`< 1.5:1`).
   - `cv.lineControl` (`>= 3.0:1` across all 4 app surfaces and all `paper` and `ink` slip stops) is required for interactive control boundaries and meaningful non-text state marks: resting input borders (`CovePillInput`, `InputDecorationTheme`, underline inputs), off-state toggle tracks (`CoveToggleSwitch`, `SwitchThemeData`), unticked checkboxes (`CoveCheckbox`, Day Sheet task boxes, pet picker ticks), action/filter chip borders, empty/upcoming EMI installment ticks, unfilled budget/payoff bar outlines, and chart baselines, pace lines, zero-spend stubs, and year guides.
   - `cv.lineFocus` (`>= 3.0:1` — clearing `>= 4.1:1` across every surface, slip, and sky stop in both modes) is used for focused input borders (`1.5dp`) and the Routines `NOW` indicator line.
   - `cv.paperEdge` (`>= 3.0:1` against both outer light-mode surfaces and inner `paper.{from, via, to}` stops) frames light-mode `CoveSlip` artifacts at a full `1.0dp` clipped stroke.
   - Inside `CoveSlip` artifacts (`CoveVoucher`, `CoveDial`, slip-hosted `CoveCheckbox`), non-text marks use `CoveSlipPalette.mark` (`paper.ink3` on `paper`, `slip.inkMark` on `ink`, both `>= 3.0:1` across every gradient stop).
4. **Automated Gate**: Enforced mechanically in `./tool/check.sh` by [`tool/check_contrast.py`](../tool/check_contrast.py) and runtime pixel-level `textContrastGuideline` checks across all 115 surfaces in [`test/a11y/`](../test/a11y/).
