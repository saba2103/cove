# Cove v2 Design System Token Pipeline & Ratchet Architecture

This document records the architectural pattern introduced for the v2 Design System (`feature/v2-design-system-revamp`).

---

## 1. Single Source of Truth (`design/tokens.json`)

All visual primitives—colors (across `dark` and `light` modes), spacing (`space`), sizing (`size`), corner radii (`radius`), typography (`type`), motion curves/durations (`motion`), person attribution rings/gradients (`person`), and elevations (`elevation`)—are authored in W3C Design Tokens Community Group (DTCG) format in [`design/tokens.json`](../design/tokens.json).

* **UI Typeface**: `PlusJakartaSans` (weights 400, 500, 600, 700), licensed under the SIL Open Font Licence (`assets/fonts/OFL.txt`). Coexists with `GeneralSans` during incremental migration until the final screen is converted.
* **Display Typeface**: `BodoniModa` for editorial and financial hero figures.

---

## 2. Deterministic Code Generation (`tool/gen_tokens.dart`)

[`tool/gen_tokens.dart`](../tool/gen_tokens.dart) compiles `design/tokens.json` into [`lib/core/theme/cove_tokens.dart`](../lib/core/theme/cove_tokens.dart):

* `CoveSpace`, `CoveSize`, `CoveRadius`: mode-independent `abstract final` constant classes.
* `CoveType`: colorless `TextStyle` constants paired with `CoveTokens` colors at the use site.
* `CoveMotion`: durations (`quick`, `sheet`), cubic easing, and reduced-motion-aware helpers (`CoveMotion.q(context)`, `CoveMotion.s(context)`).
* `CoveTokens`: a `ThemeExtension<CoveTokens>` with `CoveTokens.dark` and `CoveTokens.light` instances, exposed via `context.cv`.

`lib/core/theme/cove_tokens.dart` is committed to version control and must never be edited by hand. Running `dart run tool/gen_tokens.dart` must produce an empty `git diff`.

---

## 3. Automated Quality Gates (`tool/check.sh`)

To guarantee incremental migration without regression, [`tool/check.sh`](../tool/check.sh) enforces:

1. **Token Drift Gate** (`dart run tool/gen_tokens.dart && git diff --exit-code lib/core/theme/cove_tokens.dart`): Ensures `cove_tokens.dart` matches `design/tokens.json` byte-for-byte.
2. **WCAG Contrast Gate** (`python3 tool/check_contrast.py`): Verifies WCAG AA contrast ratios (4.5:1 normal text, 3.0:1 large text / UI components) for every foreground/background pair in both dark and light modes, including translucent overlays.
3. **One-Way Style Ratchet** (`dart run tool/style_gate.dart` + [`tool/style_allowlist.txt`](../tool/style_allowlist.txt)): Scans `lib/features` and `lib/core/widgets` for raw `Color(0x...)`, `fontSize:`, and `BorderRadius.circular(...)` literals. Unlisted files have zero tolerance; listed files have a strict maximum budget that must immediately be tightened or removed when a file is converted.
4. **Version Sync Gate** (`dart run tool/check_version.dart`): Ensures `pubspec.yaml` and `kCoveCurrentAppVersion` in `lib/features/changelog/changelog_models.dart` never drift.
5. **Golden Matrix Harness** ([`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart)): Renders converted screens across three canonical widths (`CoveWidth.cover` 320×780, `CoveWidth.phone` 411×914, `CoveWidth.wide` 840×900) and both `Brightness.dark` and `Brightness.light` modes using offline disk-loaded fonts.
