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
