# Cove Definition of Done (DoD) & Engineering Guidelines

This rule is active for all engineering tasks in the Cove repository. Every time you make changes to code, you must adhere to this checklist before finalizing your response.

---

## 1. Quality & Linting Protocol
* Always run `flutter analyze` after code changes.
* Ensure **0 errors** and **0 warnings**. Clean up any unused imports or deprecated APIs immediately.
* Preserve all existing comments, docstrings, and architectural design invariants.
* Use `formatCoveAmount()` from `cove_currency_formatter.dart` for currency formatting (respecting the Indian numbering system and clean decimals).

---

## 2. Automated Test Verification
* Whenever modifying application logic, controllers, or database schemas, identify the relevant test files in `test/`.
* Run targeted tests via `flutter test <test_file_path>`.
* Ensure 100% test pass rate. If existing tests fail due to updated expectations (e.g. number formatting or new properties), update the test expectations deliberately to maintain test coverage.

---

## 3. Mandatory Changelog Maintenance
* **Never conclude a feature or bug fix without updating [`product/CHANGELOG.md`](../../product/CHANGELOG.md)**.
* Add an entry under the active version release section:
  - **Outcome**: Plain language explanation of the user-visible or architectural benefit.
  - **Under the Hood**: Bulleted technical breakdown of modified files, database tables, and algorithms.

---

## 4. Product Decision Documentation
* If a conversation establishes a new product decision, versioning rule, naming convention, or core invariant:
  - Document it in the `product/` directory (e.g., `product/versioning_and_git_strategy.md`, `product/ENGINEERING_PRACTICES.md`).
  - Keep product documentation current and linked in your summary.

---

## 5. Physical Device Smoke Testing
* If an Android device is connected via ADB (check `adb devices`):
  - When the user asks to build or install, build release APK: `flutter build apk --release`.
  - Stream install onto the device: `adb -s <device_id> install -r build/app/outputs/flutter-apk/app-release.apk`.
  - Launch the app: `adb -s <device_id> shell monkey -p com.app.cove -c android.intent.category.LAUNCHER 1`.
