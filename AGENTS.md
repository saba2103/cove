# Cove Agent Guidelines

Welcome to Cove. When assisting with this codebase, you must strictly adhere to the project's engineering standards.

## Definition of Done (DoD)
Before completing any task that touches code:
1. **Analyze**: Run `flutter analyze` and resolve all warnings and lints (0 issues required).
2. **Test**: Run targeted test files via `flutter test <path>` and ensure all tests pass.
3. **Changelog**: Append an entry to [`product/CHANGELOG.md`](./product/CHANGELOG.md) under the current release with **Outcome** and **Under the Hood** details.
4. **Product Decisions**: Document new product decisions or architectural patterns in the [`product/`](./product/) directory.
5. **Formatting & Numbers**: Use `formatCoveAmount()` from `cove_currency_formatter.dart` for currency numbers (Indian numbering system, clean decimals).

For full details, see [`product/ENGINEERING_PRACTICES.md`](./product/ENGINEERING_PRACTICES.md) and [`.agent/rules/definition_of_done.md`](./.agent/rules/definition_of_done.md).
