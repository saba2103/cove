# Phase 2 — the primitives

Ten prompts, in this order. Each builds one widget in `lib/core/widgets/`, from
`CoveTokens` / `CoveType` / `CoveSpace` / `CoveRadius` only, with a golden.

Doing these before any screen is what makes Phase 3 cheap: converting a screen becomes
"replace this hand-rolled row with `CoveRow`" rather than thirteen separate restatements
of the design system.

**Every prompt follows the same shape.** Substitute the component:

> Build `<Widget>` in `lib/core/widgets/`, to the contract in
> `design/specs/<NN>-<name>.md`. Read that file first — it is the spec, and every number
> in it is already device scale.
>
> Rules:
> - Take every value from `CoveTokens`, `CoveType`, `CoveSpace`, `CoveRadius` or
>   `CoveMotion`. A raw literal is allowed ONLY where the spec marks one `(literal)`.
> - Do not modify any existing screen. Nothing under `lib/features/` changes in this task.
> - The widget must work in both brightnesses without branching on `Brightness` — read
>   `context.cv` and let the theme decide.
> - Respect `MediaQuery.disableAnimationsOf` via `CoveMotion.q()` / `.s()` for any motion.
> - Expose a `CoveSize.hit` tap target where the spec calls for one, without growing the
>   drawn size.
>
> Then add `test/golden/<name>_golden_test.dart` using `goldenMatrix` with a small
> demo harness showing the component in each state the spec names. Generate, commit.
>
> `tool/check.sh` must exit 0, and `tool/style_allowlist.txt` must still read
> 66 files / 748 literals — this task adds no literals and converts no screen.

## Order

| # | Spec | Widget |
|---|---|---|
| 2.0 | `00-system-chrome.md` | **not a widget** — set `SystemUiOverlayStyle` from the theme and establish the SafeArea convention. Delete nothing yet. |
| 2.1 | `01-page-header.md` | `CovePageHeader` |
| 2.2 | `02-section-label.md` | `CoveSectionLabel` |
| 2.3 | `04-round-button.md` | `CoveRoundButton` — before the header needs it |
| 2.4 | `05-avatar.md` | `CoveAvatar` |
| 2.5 | `03-row.md` | `CoveRow` — needs the avatar |
| 2.6 | `06-metric-card.md` | `CoveMetricCard` |
| 2.7 | `07-sheet.md` | `CoveSheet` |
| 2.8 | `08-toast.md` | `CoveToast` |
| 2.9 | `09-floating-bar.md` | `CoveFloatingBar` — the largest; its own golden per category state |

Build 2.3 and 2.4 before 2.1 and 2.5 — the header needs the button and the row needs the
avatar, and building a dependency twice is how two versions of it end up in the codebase.

## What to watch

- **A spec number appearing as a literal.** If the agent writes `52` instead of
  `CoveSize.row`, the style gate will not catch it (the gate only looks for colours, font
  sizes and radii). Read the diff.
- **A widget that branches on `Brightness`.** That means it is not reading the theme, and
  it will drift the moment a token changes.
- **A golden that only shows one state.** The spec names states; the golden should show
  them.
