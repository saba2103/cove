# Cove Agent Guidelines

Welcome to Cove. When assisting with this codebase, you must strictly adhere to the project's engineering standards.

## Definition of Done (DoD)
Before completing any task that touches code:
1. **Check Gate**: Run `./tool/check.sh` and require it to exit 0. This single script covers `flutter analyze` (0 issues), the token contrast gate (`tool/check_contrast.py`), tokens being in sync with `design/tokens.json` (`tool/gen_tokens.dart` + `git diff`), the style ratchet (`tool/style_gate.dart`), version-string agreement (`tool/check_version.dart`), and the full test suite including goldens (`flutter test`).
2. **Changelog**: Append an entry to [`product/CHANGELOG.md`](./product/CHANGELOG.md) under the current release with **Outcome** and **Under the Hood** details.
3. **Product Decisions**: Document new product decisions or architectural patterns in the [`product/`](./product/) directory.
4. **Formatting & Numbers**: Use `formatCoveAmount()` from `cove_currency_formatter.dart` for currency numbers (Indian numbering system, clean decimals).
   Amounts render through `formatCoveAmount()` and never through `toStringAsFixed` in display code — input-field prefill is the exception.

For full details, see [`product/ENGINEERING_PRACTICES.md`](./product/ENGINEERING_PRACTICES.md) and [`.agent/rules/definition_of_done.md`](./.agent/rules/definition_of_done.md).
