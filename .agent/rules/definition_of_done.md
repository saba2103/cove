# Cove Definition of Done (DoD) & Engineering Guidelines

This rule is active for all engineering tasks in the Cove repository. Every time you make changes to code, you must adhere to this checklist before finalizing your response.

---

## 1. Mechanical Verification Gate (`./tool/check.sh`)
* Run `./tool/check.sh` and require it to exit 0 (`all green`).
* This single script covers:
  - `flutter analyze` (0 errors and 0 warnings required; clean up any unused imports or deprecated APIs immediately)
  - The token contrast gate (`python3 tool/check_contrast.py`)
  - Tokens being in sync with `design/tokens.json` (`dart run tool/gen_tokens.dart` + `git diff --exit-code lib/core/theme/cove_tokens.dart`)
  - The style ratchet (`dart run tool/style_gate.dart`)
  - Version-string agreement (`dart run tool/check_version.dart`)
  - The full test suite including goldens (`flutter test`)
* Preserve all existing comments, docstrings, and architectural design invariants.

---

## 2. Mandatory Changelog Maintenance
* **Never conclude a feature or bug fix without updating [`product/CHANGELOG.md`](../../product/CHANGELOG.md)**.
* Add an entry under the active version release section:
  - **Outcome**: Plain language explanation of the user-visible or architectural benefit.
  - **Under the Hood**: Bulleted technical breakdown of modified files, database tables, and algorithms.

---

## 3. Product Decision Documentation
* If a conversation establishes a new product decision, versioning rule, naming convention, or core invariant:
  - Document it in the `product/` directory (e.g., `product/versioning_and_git_strategy.md`, `product/ENGINEERING_PRACTICES.md`).
  - Keep product documentation current and linked in your summary.

---

## 4. Formatting & Numbers
* Use `formatCoveAmount()` from `cove_currency_formatter.dart` for currency numbers (Indian numbering system, clean decimals).
* Amounts render through `formatCoveAmount()` and never through `toStringAsFixed` in display code — input-field prefill is the exception.

---

## 5. Physical Device Smoke Testing
* If an Android device is connected via ADB (check `adb devices`):
  - When the user asks to build or install, build release APK: `flutter build apk --release`.
  - Stream install onto the device: `adb -s <device_id> install -r build/app/outputs/flutter-apk/app-release.apk`.
  - Launch the app: `adb -s <device_id> shell monkey -p com.app.cove -c android.intent.category.LAUNCHER 1`.
