# Cove Product Changelog

This document tracks all user-facing changes, architectural upgrades, and engineering refinements across Cove releases in chronological order.

---

## [v2.0-alpha.1] — 2026-10-22

### Fixed
- **`CoveRoundButton` Gold Variant Pressed-State Darkening (`Oct 22, 2026`)**:
  - *Outcome*: Corrected the gold variant's press overlay in [`design/specs/04-round-button.md`](../design/specs/04-round-button.md) and [`lib/core/widgets/cove_round_button.dart`](../lib/core/widgets/cove_round_button.dart) so pressing the primary gold button visibly darkens the circle in both dark (`RGB(216, 185, 140)` → `RGB(190, 163, 123)`) and light (`RGB(169, 124, 79)` → `RGB(149, 109, 70)`) modes instead of laying `accent.wash` over `accent.fill`.
  - *Under the Hood*:
    - Updated [`design/specs/04-round-button.md`](../design/specs/04-round-button.md) to specify `accent.wash` for the ghost variant and `Colors.black` at `12%` alpha (`0.12`) over `accent.fill` for the gold variant.
    - Updated `_CoveRoundButtonState` in [`lib/core/widgets/cove_round_button.dart`](../lib/core/widgets/cove_round_button.dart) and regenerated the 6 `round_button.{cover,phone,wide}.{dark,light}.png` goldens.
- **Golden Harness `AppShell` 540dp Constraint & Explicit Overflow Allow-List (`Oct 22, 2026`)**:
  - *Outcome*: Screen goldens now wrap each screen in the same centred `540 dp` constraint that `AppShell` applies on device, and replaced the blanket `RenderFlex` overflow suppression with an explicit `<screen>.<width>` allow-list of the 5 known pre-revamp overflow pairs so any new overflow fails immediately.
  - *Under the Hood*:
    - Added optional `wrap` and `allowedOverflows` parameters (plus `wrapInAppShellConstraint`) to `goldenMatrix` in [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart).
    - Replaced `_withLegacyCoverOverflowIgnored` in [`test/golden/screens_golden_test.dart`](../test/golden/screens_golden_test.dart) with `_kKnownLegacyOverflows` (`today_screen.cover`, `calendar_screen.cover`, `expenses_screen.cover`, `subscriptions_screen.phone`, `subscriptions_screen.cover`) and regenerated the 28 `.wide.` goldens in `test/golden/goldens/`.

### Added
- **`CovePageHeader` Primitive & Multi-State Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Built [`CovePageHeader`](../lib/core/widgets/cove_page_header.dart) (and the `28 dp` [`CoveHeaderPill`](../lib/core/widgets/cove_page_header.dart) EMI `"What if…"` exception) with a `56 dp` minimum height (`20 dp` top padding + `36 dp` `CoveType.title` line box) that grows cleanly when multi-word titles wrap, `CoveSpace.gutter` horizontal padding, baseline-aligned `CoveType.readout` in `text.tertiary` separated by `CoveSpace.md`, and leading/trailing [`CoveRoundButton`](../lib/core/widgets/cove_round_button.dart) slots whose `40 dp` drawn circles sit flush to the gutter while preserving their `48 dp` hit targets.
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_page_header.dart`](../lib/core/widgets/cove_page_header.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) reading `context.cv`, `CoveType`, `CoveSpace`, `CoveSize`, `CoveRadius`, and `CoveMotion.q(context)` with zero raw style literals or `Brightness` branches.
    - Added [`test/golden/page_header_golden_test.dart`](../test/golden/page_header_golden_test.dart) and generated all 6 `page_header.{cover,phone,wide}.{dark,light}.png` goldens plus geometry and alphabetic-baseline assertions.
- **`CoveAvatar` Primitive & Multi-Rung Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Built [`CoveAvatar`](../lib/core/widgets/cove_avatar.dart) across all four size rungs (`inline` 24, `row` 28, `header` 32, `profile` 64) and three household attribution states (`CovePerson.a` creator, `CovePerson.b` joiner, and `CovePerson.both` unfilled `1.5 dp` gradient ring with `&`), keyed strictly to `home.createdBy` with Libre Bodoni `w500` initials at `0.44 × diameter`.
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_avatar.dart`](../lib/core/widgets/cove_avatar.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) using `context.cv` (`personA`/`personALabel`, `personB`/`personBLabel`, `personBothRing`/`personBothLabel`), `CoveSize`, `CoveType.title`, and a custom `_GradientRingPainter` for the unfilled `both` ring.
    - Added [`test/golden/avatar_golden_test.dart`](../test/golden/avatar_golden_test.dart) and generated all 6 `avatar.{cover,phone,wide}.{dark,light}.png` goldens.
- **`CoveRoundButton` Primitive & Multi-State Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Built [`CoveRoundButton`](../lib/core/widgets/cove_round_button.dart) for all circular header, back, add, sheet-close, and inline stepper actions, with a `40 dp` drawn circle (`CoveSize.buttonRound`) inside an invisible `48 dp` tap target (`CoveSize.hit`), `gold` and `ghost` variants, `accent.wash` press overlay (`CoveMotion.q`), and a `24 dp` `.stepper` sibling.
  - *Under the Hood*:
    - Added [`lib/core/widgets/cove_round_button.dart`](../lib/core/widgets/cove_round_button.dart) (exported via [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) reading `context.cv`, `CoveSize`, and `CoveMotion.q(context)` with zero raw style literals or `Brightness` branches.
    - Added [`test/golden/round_button_golden_test.dart`](../test/golden/round_button_golden_test.dart) and generated all 6 `round_button.{cover,phone,wide}.{dark,light}.png` goldens plus hit-target ring assertions.
- **System Chrome Overlay Style, SafeArea Convention & `CoveMaxWidth` (`Oct 22, 2026`)**:
  - *Outcome*: Established the single-source-of-truth `SystemUiOverlayStyle` from `CoveTheme` (light icons on dark mode, dark icons on light mode, transparent status bar so `surfaceCanvas` runs underneath), documented the `SafeArea` and `CoveSpace.barClearance` inset conventions in [`product/ENGINEERING_PRACTICES.md`](./ENGINEERING_PRACTICES.md), and added the [`CoveMaxWidth`](../lib/core/widgets/cove_max_width.dart) container widget with wide-viewport goldens.
  - *Under the Hood*:
    - Added `CoveTheme.overlayStyleFor(Brightness)` in [`lib/core/theme/cove_theme.dart`](../lib/core/theme/cove_theme.dart) and wired it into `AppBarTheme.systemOverlayStyle` and the root `AnnotatedRegion<SystemUiOverlayStyle>` in [`lib/main.dart`](../lib/main.dart); verified via [`test/theme_tokens_test.dart`](../test/theme_tokens_test.dart).
    - Documented the system chrome and `SafeArea` inset rules (`MediaQuery.padding.top`, `CoveSpace.barClearance + MediaQuery.padding.bottom`, no extra top padding above page headers) in §5 of [`product/ENGINEERING_PRACTICES.md`](./ENGINEERING_PRACTICES.md).
    - Added [`lib/core/widgets/cove_max_width.dart`](../lib/core/widgets/cove_max_width.dart) (exported from [`lib/core/widgets/widgets.dart`](../lib/core/widgets/widgets.dart)) constraining child width to `CoveSize.maxContent` (`420 dp`) and centring on wider viewports, plus [`test/golden/cove_max_width_golden_test.dart`](../test/golden/cove_max_width_golden_test.dart) (`cove_max_width.wide.{dark,light}.png`).
    - Committed [`design/specs/`](../design/specs/) (`00-system-chrome.md` through `09-floating-bar.md`) and [`product/PROMPTS-PHASE2.md`](./PROMPTS-PHASE2.md).
- **Version Bump to `2.0.0-alpha.1+1` & Screenshot Font Cleanup (`Oct 22, 2026`)**:
  - *Outcome*: Bumped Cove to `2.0.0-alpha.1+1` (`v2.0-alpha.1`) across `pubspec.yaml`, the in-app changelog, `AboutCoveScreen`, and the milestone ledger, and aligned the screenshot generation tests with `LibreBodoni`.
  - *Under the Hood*:
    - Updated `pubspec.yaml` to `version: 2.0.0-alpha.1+1` and `kCoveCurrentAppVersion` in [`lib/features/changelog/changelog_models.dart`](../lib/features/changelog/changelog_models.dart) to `'2.0.0-alpha.1'`.
    - Added the **v2.0-alpha.1 — The Design System** entry to `kChangelogItems` in [`lib/features/changelog/changelog_models.dart`](../lib/features/changelog/changelog_models.dart) and updated [`test/changelog_test.dart`](../test/changelog_test.dart).
    - Updated [`lib/features/home/about_cove_screen.dart`](../lib/features/home/about_cove_screen.dart) to display `v2.0-alpha.1 (1)` and added the `v2.0-alpha.1` row to §2 of [`product/versioning_and_git_strategy.md`](./versioning_and_git_strategy.md).
    - Replaced `BodoniModa-Medium.ttf` font loading in [`test/generate_screenshots_test.dart`](../test/generate_screenshots_test.dart) and [`test/generate_commitments_screenshots_test.dart`](../test/generate_commitments_screenshots_test.dart) with `LibreBodoni-Regular.ttf` and `LibreBodoni-Medium.ttf`.

---

## [v1.0-alpha.1] — 2026-09-25

### Fixed
- **Two-Decimal Precision for Non-Integer Currency Amounts (`Oct 22, 2026`)**:
  - *Outcome*: Currency amounts with non-zero paise/cents now always display two decimal places (e.g. `₹42.50` and `₹12,34,567.50` instead of `₹42.5`), while whole-number amounts continue to omit `.00` cleanly (e.g. `₹42`).
  - *Under the Hood*:
    - Updated `_coveDecimalAmountFormat` in [`lib/core/utils/cove_currency_formatter.dart`](../lib/core/utils/cove_currency_formatter.dart) from `NumberFormat('#,##,##0.##', 'en_IN')` to `NumberFormat('#,##,##0.00', 'en_IN')`, keeping `_coveIntegerAmountFormat` and the `roundedCents % 100 == 0` branch intact.
    - Restored the `$42.50` expectation in [`test/expenses_test.dart`](../test/expenses_test.dart) and added unit tests in [`test/user_requests_batch_test.dart`](../test/user_requests_batch_test.dart) covering `42.5 -> "42.50"`, `42.57 -> "42.57"`, `42.0 -> "42"`, `0 -> "0"`, `1234567.5 -> "12,34,567.50"`, and `0.005 -> "0.01"`.
- **Prevent Duplicate Bottom Sheets on Push Notification Tap (`Oct 07, 2026`)**:
  - *Outcome*: Tapping a push notification now opens exactly one entity detail bottom sheet (e.g. expense, commitment, list item, habit, or calendar event), eliminating stacked duplicate bottom sheets.
  - *Under the Hood*:
    - Removed redundant `ref.listen(notificationPayloadNavigationProvider)` in `AppShell` that was duplicating the `_navSub = notifService.onNavigateToPayload.listen` stream listener.
    - Added an opening mutex and a 1500ms entity debounce in `NotificationDetailDispatcher.openDetailForNotification` to safely drop concurrent or rapid duplicate dispatches.
    - Enforced `Navigator.of(context).popUntil((route) => route.isFirst)` right before presenting any notification detail sheet to ensure no previously open sheet or modal remains underneath.
    - Debounced duplicate OS tap callbacks within 1000ms in `NotificationService.onNotificationTapped` (preventing dual triggers from `getNotificationAppLaunchDetails` and `onDidReceiveNotificationResponse`).
    - Added automated widget test in `test/notifications_test.dart` verifying concurrent dispatches open exactly one bottom sheet.
- **Foreclosed & Completed EMI Year Projections in Helicopter View (`Oct 07, 2026`)**:
  - *Outcome*: Foreclosed and completed EMIs now preserve their past paid installment months in the 12-month Helicopter Year View, while correctly stopping further EMI calculations on and after the foreclosure or completion cutoff. Inactive loans no longer vanish completely from the year view as if they never existed.
  - *Under the Hood*:
    - In `CommitmentProjectionUtils.projectYear`, adjusted the inactive filter to only exclude open-ended subscriptions (`if (!sub.isActive && !sub.isEmi) continue;`), allowing finite commitments (EMIs) to evaluate past active months.
    - Enhanced `_isEmiActiveInMonth` to determine the loan's initial start month via `endDate - (totalInstallments - 1)` (or `createdAt`) and the foreclosure cutoff month via `sub.nextBillingDate`.
    - Excluded months on or after the foreclosure cutoff while keeping all months between loan start and cutoff active.
    - Added unit tests in `test/subscriptions_test.dart` validating month-by-month projections for foreclosed, completed, and cancelled commitments.

### Added
- **Theme Serves `CoveTokens`, `CoveType`, and Token-Mapped `ColorScheme`/`TextTheme` (`Oct 22, 2026`)**:
  - *Outcome*: `CoveTheme.darkTheme` and `CoveTheme.lightTheme` now register `CoveTokens.dark` and `CoveTokens.light` alongside the existing `CoveColors` and `CoveTypography` extensions, and map Material's `ColorScheme` and `TextTheme` directly from `CoveTokens` and `CoveType` so `context.cv` and Material defaults resolve consistently across both modes while unconverted screens continue to coexist.
  - *Under the Hood*:
    - Registered `CoveTokens.dark` and `CoveTokens.light` in `ThemeData.extensions` in [`lib/core/theme/cove_theme.dart`](../lib/core/theme/cove_theme.dart) and re-exported `cove_tokens.dart` without altering `CoveColors`.
    - Mapped `ColorScheme` (`primary: tokens.accentFill`, `onPrimary: tokens.textOnAccent`, `error: tokens.statusAlert`, `surface: tokens.surfaceCard`, `onSurface: tokens.textPrimary`) and `TextTheme` (`displayLarge: CoveType.heroFigure`, `displayMedium: CoveType.cardFigure`, `titleLarge`/`headline*`/`displaySmall: CoveType.title`, `titleMedium`/`labelLarge: CoveType.rowTitle`, `titleSmall`/`bodyMedium: CoveType.readout`, `bodyLarge: CoveType.body`, `bodySmall: CoveType.rowSub`, `labelMedium: CoveType.capsPage`, `labelSmall: CoveType.capsCard`) in [`lib/core/theme/cove_theme.dart`](../lib/core/theme/cove_theme.dart).
    - Added [`test/theme_tokens_test.dart`](../test/theme_tokens_test.dart) verifying `context.cv` resolves in both `Brightness.dark` and `Brightness.light` and matches `CoveTokens` (`surfaceCanvas`, `textPrimary`, `accentFill`).
    - Regenerated all 84 screen goldens in `test/golden/goldens/` and verified every diff is attributable to `CoveTokens` / `CoveType`.
- **Libre Bodoni Display Typeface with Native `₹` Glyph (`Oct 22, 2026`)**:
  - *Outcome*: Replaced the display typeface `BodoniModa` with `LibreBodoni` across all editorial titles and financial hero/card figures so the Indian Rupee symbol (`₹`, U+20B9) renders natively in the display serif rather than falling back to a system font, while preserving vertical rhythm (cap height 754 vs 750 per 1000 em).
  - *Under the Hood*:
    - Added `assets/fonts/LibreBodoni-Regular.ttf` (400) and `assets/fonts/LibreBodoni-Medium.ttf` (500), appended the Libre Bodoni copyright notice to `assets/fonts/OFL.txt`, registered `LibreBodoni` in `pubspec.yaml`, and removed `BodoniModa` (`assets/fonts/BodoniModa-Medium.ttf`).
    - Updated `type.familyDisplay` in [`design/tokens.json`](../design/tokens.json) to `LibreBodoni` and regenerated [`lib/core/theme/cove_tokens.dart`](../lib/core/theme/cove_tokens.dart).
    - Replaced all `'BodoniModa'` / `GoogleFonts.bodoniModa` references across `lib/` ([`lib/core/theme/cove_typography.dart`](../lib/core/theme/cove_typography.dart), [`lib/core/widgets/cove_splash_screen.dart`](../lib/core/widgets/cove_splash_screen.dart), [`lib/core/widgets/cove_streak_badge.dart`](../lib/core/widgets/cove_streak_badge.dart), [`lib/features/home/about_cove_screen.dart`](../lib/features/home/about_cove_screen.dart), [`lib/features/calendar/views/calendar_month_view.dart`](../lib/features/calendar/views/calendar_month_view.dart), [`lib/features/calendar/views/calendar_agenda_view.dart`](../lib/features/calendar/views/calendar_agenda_view.dart), [`lib/features/today/today_screen.dart`](../lib/features/today/today_screen.dart), [`lib/features/expenses/monthly_budget_sheet.dart`](../lib/features/expenses/monthly_budget_sheet.dart), and [`lib/features/subscriptions/emi_tracker_screen.dart`](../lib/features/subscriptions/emi_tracker_screen.dart)).
    - Updated [`loadCoveFonts`](../test/golden/golden_harness.dart) in [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart) to load both `LibreBodoni` weights and regenerated all 84 baseline goldens in `test/golden/goldens/`.
- **Material Icon Font Rendering in Golden Harness & Regenerated Baselines (`Oct 22, 2026`)**:
  - *Outcome*: All 84 baseline screen goldens now render actual Material icons instead of fallback tofu boxes, and the golden harness fails fast if `MaterialIcons-Regular.otf` cannot be resolved from the Flutter SDK.
  - *Under the Hood*:
    - Updated [`loadCoveFonts`](../test/golden/golden_harness.dart) in [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart) to resolve `$FLUTTER_ROOT` at runtime (via `Platform.environment['FLUTTER_ROOT']` with `Platform.resolvedExecutable` fallback), fail explicitly if `$FLUTTER_ROOT/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf` is missing, and register it with `FontLoader('MaterialIcons')`. Confirmed zero `CupertinoIcons` usage across `lib/`.
    - Regenerated all 84 baseline PNGs in `test/golden/goldens/` and verified `today_screen.phone.dark.png`, `profile_screen.phone.light.png`, and `calendar_create_sheet.phone.dark.png`.
- **Baseline Multi-Viewport Screen Goldens (`Oct 22, 2026`)**:
  - *Outcome*: Captured 84 deterministic "before" golden snapshots across all 14 Cove screens and representative sheets (3 widths: Fold cover 320dp, phone 411dp, Fold inner wide 840dp × 2 modes: dark and light) to serve as the visual baseline before the v2 design system conversion.
  - *Under the Hood*:
    - Wired `coveThemeFor(Brightness)` in [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart) to the existing `CoveTheme.darkTheme` and `CoveTheme.lightTheme` factories and registered `GeneralSans` and `BodoniModa` font families in `loadCoveFonts()` for offline deterministic glyph rendering.
    - Added [`test/golden/screens_golden_test.dart`](../test/golden/screens_golden_test.dart) covering `today_screen`, `calendar_screen`, `expenses_screen`, `subscriptions_screen`, `emi_tracker_screen`, `commitments_helicopter_screen`, `routine_screen`, `activity_screen`, `home_settings_screen`, `profile_screen`, `calendar_create_sheet`, `expense_detail_sheet`, `lists_screen`, and `habits_screen` using stubbed Riverpod providers and fixed seed data (zero database connections or network calls).
    - Committed all 84 baseline PNGs in `test/golden/goldens/`.
- **Drift v11 Schema Snapshot & Data-Preserving Migration Safety Gate (`Oct 22, 2026`)**:
  - *Outcome*: Captured an immutable snapshot of live production database schema v11 across all 17 household tables and locked in automated schema verification, a full 17-table data-preservation migration test, and a schema snapshot ratchet guard before any v2 changes begin.
  - *Under the Hood*:
    - Dumped schema v11 to [`drift_schemas/drift_schema_v11.json`](../drift_schemas/drift_schema_v11.json) via `dart run drift_dev schema dump` and generated versioned schema & step-by-step helpers in [`test/drift/generated/`](../test/drift/generated/).
    - Added [`test/migration_test.dart`](../test/migration_test.dart) with three gates: a snapshot ratchet ensuring `AppDatabase.schemaVersion` never exceeds the newest snapshot in `drift_schemas/`, a `SchemaVerifier` check validating v11 against the snapshot, and a data-preserving migration test that populates all 17 tables at v11 with non-default values across every column and verifies zero field loss after migrating to `schemaVersion`.
- **v2 Design System Token Pipeline & Quality Gates (`Oct 22, 2026`)**:
  - *Outcome*: Laid the foundation for the v2 design system revamp (`feature/v2-design-system-revamp`) without touching any existing screen or widget. Registered the new `PlusJakartaSans` UI typeface alongside `GeneralSans` and `BodoniModa`, added its SIL Open Font Licence (`assets/fonts/OFL.txt`), and wired deterministic token generation, WCAG contrast checks, a one-way style-literal ratchet gate, and golden test scaffolding.
  - *Under the Hood*:
    - Registered `PlusJakartaSans` (weights 400, 500, 600, 700) in `pubspec.yaml` and added `assets/fonts/OFL.txt`.
    - Added W3C DTCG single source of truth [`design/tokens.json`](../design/tokens.json) and code generator [`tool/gen_tokens.dart`](../tool/gen_tokens.dart), emitting [`lib/core/theme/cove_tokens.dart`](../lib/core/theme/cove_tokens.dart) (`CoveTokens`, `CoveSpace`, `CoveSize`, `CoveRadius`, `CoveType`, `CoveMotion`, and `BuildContext.cv`).
    - Added automated gates: [`tool/check_contrast.py`](../tool/check_contrast.py) (WCAG AA contrast verification across dark & light modes), [`tool/style_gate.dart`](../tool/style_gate.dart) + [`tool/style_allowlist.txt`](../tool/style_allowlist.txt) (ratchet enforcing zero raw `Color(...)`, `fontSize:`, or `BorderRadius.circular(...)` in converted files), [`tool/check_version.dart`](../tool/check_version.dart), and [`tool/check.sh`](../tool/check.sh).
    - Added multi-viewport/multi-mode golden test harness [`test/golden/golden_harness.dart`](../test/golden/golden_harness.dart) (`CoveWidth.cover`, `CoveWidth.phone`, `CoveWidth.wide` × dark/light) and resolved Riverpod 3 `Override` import and analyzer lints across `tool/` and `test/golden/`.
    - Architectural pattern documented in [`product/ENGINEERING_PRACTICES.md`](./ENGINEERING_PRACTICES.md) and [`product/design_system_tokens.md`](./design_system_tokens.md).
- **Nightly Automatic Google Drive Backup (`Oct 22, 2026`)**:
  - *Outcome*: Once Google Drive and a recovery passphrase are set up, Cove now backs itself up every night around 2:00 AM on Wi-Fi — no tapping required. Nights with no changes are skipped so the 10 kept backups stay meaningful, and if Drive access is ever lost, Settings says so plainly instead of failing silently. Time, Wi-Fi-only and on/off are adjustable under **Settings → Backup & Restore**.
  - *Under the Hood*:
    - New `BackupService` (shared manual/automatic pipeline): `run(automatic:)` with outcomes `uploaded`, `skippedUnchanged` (SHA-256 snapshot fingerprint via `pointycastle`), `skippedRecent` (< 20 h), `notConfigured`, `needsReconnect`, `failed`; automatic runs never throw and persist `cove_backup_auto_*` status.
    - New `WorkmanagerBackupScheduler` (`workmanager` ^0.10.10): unique 24 h periodic job `cove-nightly-backup`, initial delay to the chosen local time, `unmetered`/`connected` network + battery-not-low constraints, exponential backoff from 30 min; `KEEP` on launch, `REPLACE` on settings change.
    - `coveBackgroundDispatcher` + `BackgroundBackupRunner` run the backup in a background isolate with silent Play-services Drive authorization (no Activity required); reuses the app's DB connection if executed in the main isolate.
    - `DriveBackupController` refactored onto `BackupService`; adds `setAutoEnabled`/`setAutoTime`/`setAutoWifiOnly`, `refresh()` (called on app resume) and schedule sync on launch from `AppShell`.
    - Settings: **Nightly Backup** toggle with live last-run status, **Backup Time** picker, **Wi-Fi Only** toggle.
    - Tests: 15 new cases in `test/drive_backup_test.dart` (skip rules, reconnect/failed handling, fingerprint stability, scheduling/persistence); `test/notifications_test.dart` switch count scoped to notification toggles.
    - Decision record updated: [`product/backup_and_recovery.md`](./backup_and_recovery.md) §5a.
- **Real End-to-End Encrypted Google Drive Backup & Restore (`Oct 22, 2026`)**:
  - *Outcome*: "Back Up Now" now actually backs up. Your whole household — every list, expense, commitment, habit, calendar event, activity entry, the home encryption keys and local preferences — is encrypted on the phone with a recovery passphrase and saved to a private, hidden folder in your own Google Drive. On a new or reset phone, sign in, tap **Restore from Google Drive backup**, enter the passphrase, and everything comes back; anything newer catches up from your partner automatically. The previous simulated backup UI (fake "18 hours ago", fake pending counts, non-functional nightly window) has been removed.
  - *Under the Hood*:
    - New `lib/features/backup/` module: `BackupCrypto` (Argon2id m=19 MiB/t=2 KEK → per-backup random DEK, AES-256-GCM with `cove-backup/v1` AAD, gzip via `archive`), `BackupSnapshotService` (generic transactional `SELECT *` export of all Drift tables + `HomeKeyStore` keys + `cove_*` secure prefs; atomic full-replace restore with schema-tolerant column intersection and `markTablesUpdated`), `GoogleDriveBackupRemote` (`google_sign_in` 7 authorization-only flow, `drive.appdata` scope, `appDataFolder` upload/list/download/delete, 401 token refresh), and `DriveBackupController` Riverpod state machine (connect, set/change passphrase, backup, keep newest 10, restore).
    - Passphrase-derived key stored in Keystore-backed `EncryptedSharedPreferences`; restoring on a new phone adopts the backup's key so future backups need no re-entry.
    - `SyncEngineImpl.resyncAfterRestore` clears the in-memory dedupe cache and replays the Supabase log after a restore.
    - Settings `Backup & Restore` rebuilt as `DriveBackupSection`; onboarding gains a "Restore from Google Drive backup" entry (Android only; web shows an availability note).
    - Removed mock `BackupStatusState`/`BackupStatusNotifier`; `CovePillInput` gains `obscureText`.
    - Added `archive` as a direct dependency.
    - Tests: new `test/drive_backup_test.dart` (crypto round-trip, wrong passphrase, tamper detection, snapshot fidelity, stream notification, schema tolerance, retention, full new-phone restore); updated `test/profile_settings_test.dart`.
    - Decision record: [`product/backup_and_recovery.md`](./backup_and_recovery.md).
- **Financed Through Support for Ongoing Subscriptions (`Oct 07, 2026`)**:
  - *Outcome*: Users can now specify and view the payment source (card, bank, or person) for ongoing subscriptions (e.g. "Amex Gold", "HDFC Regalia", "Apple Card") in addition to finite EMIs. Financing sources appear in commitment list cards, detail sheets, month breakdown sheets, calendar agenda renewal entries, and activity feeds.
  - *Under the Hood*:
    - In `SubscriptionFormSheet`, elevated the `FINANCED THROUGH` input field with real-time history suggestions directly below the commitment type selector so it is accessible for all commitment types.
    - Removed `isEmiSelected` gate from `effectiveFinancedThrough` so sources are persisted and dispatched via sync for standard subscriptions.
    - Updated `SubscriptionsScreen` subtitle builder to append `· via <source>` for regular subscriptions.
    - Updated `CommitmentDetailSheet` to display the "Financed Through" row for any commitment with a valid source.
    - Surfaced payment source in `MonthCommitmentsSheet` tile subtitles and `CalendarAgendaView` renewal entries.
    - Included payment source in `ActivityFormatter` and `NotificationFormatter` event subtitles.
    - Added full end-to-end unit and widget test coverage in `test/subscriptions_test.dart`.
- **Home-Scoped SQLite Persistence & Cross-Device Sync (`Sep 25, 2026`)**:
  - *Outcome*: Monthly expense budgets, preferred home currency, anniversary dates, and check-in reminders now permanently persist in local SQLite and sync seamlessly across partner devices.
  - *Under the Hood*:
    - Bumped Drift database schema to version `11`.
    - Added `monthlyBudget` and `anniversaryDate` columns to `LocalHomes`.
    - Created dedicated `LocalCheckinReminders` table (`id`, `homeId`, `hour`, `minute`, `message`, `isEnabled`, `createdAt`).
    - Added full CRUD projections in `LocalStateStoreImpl` for `home_currency_updated`, `home_anniversary_updated`, `monthly_budget_updated`, `monthly_budget_cleared`, and `checkin_reminder_*` events.
    - Updated `MonthlyBudgetNotifier`, `CurrencyNotifier`, `HomeMetadataNotifier`, and `ReminderNotifier` to stream reactively from SQLite.
- **End-to-End Home Currency Consistency (`Sep 25, 2026`)**:
  - *Outcome*: The active Home's currency preference (e.g. INR `₹`) is now the single authoritative source of truth across all screens, activity feeds, detail sheets, and notifications. Activity logs and undo handlers no longer default to USD `$`.
  - *Under the Hood*:
    - `ActivityFormatter.formatWithDb` queries `db.localHomes` by `homeId` if currency symbol is not yet loaded into memory, guaranteeing correct symbol resolution.
    - `ActivityFormatter.getCurrencySymbol` honors `fallbackSymbol` whenever currency is USD or omitted.
    - `PreferencesController.setCurrency` cascades new currency preference to all existing SQLite `localExpenses` and `localSubscriptions` records for the active home.
    - `LocalStateStoreImpl` projects `home_currency_updated` events to cascade update `localExpenses` and `localSubscriptions` across devices.
    - `ActivityEventDetailSheet` undo handlers fallback to `currencyPreferenceProvider.code` rather than hardcoded `'USD'`.
- **Contextual Notification Deep Linking (`Sep 25, 2026`)**:
  - *Outcome*: Tapping an expense, commitment, or list push notification now opens the exact item's detail bottom sheet directly on top of the screen instead of simply navigating to the generic tab.
  - *Under the Hood*:
    - Enhanced FCM payload parser in `NotificationService` to capture `entityId` and `actionType`.
    - Added `NotificationDetailDispatcher` to resolve entities asynchronously from Drift SQLite and present the respective modal sheet with navigation stack pop-until guards.

---

## [v1.0-alpha.1] — 2026-09-20 to 2026-09-22

### Added
- **EMI Tracker & Loan Foreclosure (`Sep 20, 2026`)**:
  - *Outcome*: Dedicated household EMI overview with total debt burden, multi-select loan payoff simulation, and one-tap foreclosure confirmation with optional ledger recording.
  - *Under the Hood*:
    - Bodoni Moda hero burden card, sticky `MultiSelectBurdenBar`, and foreclosure projection controller.
- **Two-Tick Sync Delivery Reconciliation (`Sep 22, 2026`)**:
  - *Outcome*: Single ticks (`savedLocally`) automatically advance to double ticks (`syncedToPartner`) reliably, even if the partner device received the payload while the sender was offline.
  - *Under the Hood*:
    - Added `reconcileDeliveryConfirmations()` to batch-query persistent Supabase `event_deliveries` on launch, pull-to-refresh, and upload flush.
- **Push Notification Background Navigation Fix (`Sep 22, 2026`)**:
  - *Outcome*: Tapping system notifications reliably opens the corresponding module even when the app was killed or cold-launched.
  - *Under the Hood*:
    - Added `FLUTTER_NOTIFICATION_CLICK` intent filter in `AndroidManifest.xml`.
    - Implemented `consumePendingNavigationModule()` in `NotificationService` and `AppShell`.

---

## [v1.0-alpha.1] — 2026-09-19

### Changed
- **Calendar-First Architecture & Today Sanctuary (`Sep 19, 2026`)**:
  - *Outcome*: Cove launches directly into your day on the calendar, carrying five quiet layers: events, commitments, money, rhythms, and tasks. Today is the home tab gathering monthly spend totals, shared list pills, and recent activity into one calm flow.
  - *Under the Hood*:
    - Unified 5-layer calendar provider, additive due-date database schema, Day view layer filters, Bodoni time gutters, and retired Dashboard architecture.

---

## [v0.6-alpha] — 2026-09-17

### Added
- **Commitments Helicopter View (`Sep 17, 2026`)**:
  - Full-screen 12-month bird's-eye commitments grid with 50/50 partner attribution toggles and drill-down sheets.
- **Clean Decimals (`Sep 17, 2026`)**:
  - Smart decimal formatting (`formatCoveAmount`) that strips zero decimals (e.g. ₹250 instead of ₹250.00) while preserving non-zero cents and paise.
- **Personal Profile Studio (`Sep 17, 2026`)**:
  - Custom photo portraits, camera capture, and minimal initial avatars with frame-0 offline caching.

---

## [v0.5-alpha] — 2026-09-17

### Added
- **Partner-First "Paid By" Details (`Sep 17, 2026`)**:
  - Clear "You" vs partner name attribution replacing cryptic UUID hashes across commitments and expense ledgers.

---

## [v0.4-alpha] — 2026-09-15

### Added
- **Silent Background Sync (`Sep 15, 2026`)**:
  - Zero-spinner, zero-modal sync engine preserving undisturbed reading and typing.
- **Strict Annual Renewal Timing (`Sep 15, 2026`)**:
  - Calendar math pinning recurring annual renewals strictly to their scheduled calendar day.

---

## [v0.3-alpha] — 2026-09-12

### Added
- **Zero-Knowledge End-to-End Encryption (`Sep 12, 2026`)**:
  - Argon2id key derivation + XChaCha20-Poly1305 AEAD payload encryption ensuring domestic privacy.

---

## [v0.2-alpha] — 2026-09-08 to 2026-09-10

### Added
- **Two-Tick Visual Confirmation (`Sep 10, 2026`)**:
  - Visual single tick vs double tick status indicator for partner sync.
- **Daily Rhythms & Mutual Cheers (`Sep 8, 2026`)**:
  - Shared recurring habit tracking with mutual cheering animations.

---

## [v0.1-alpha] — 2026-09-05

### Added
- **Offline-First Foundation & Multi-Currency Support (`Sep 5, 2026`)**:
  - Drift SQLite local database, optimistic mutation pipeline with outbox queues, and support for INR, USD, EUR, GBP, and JPY.
