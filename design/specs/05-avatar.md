# CoveAvatar

Who did what, answered by a circle rather than a word.

| Rung | Token | Where |
|---|---|---|
| Inline | `CoveSize.avatarInline` (24) | inside a sentence |
| Row | `CoveSize.avatarRow` (28) | a list row |
| Header | `CoveSize.avatarHeader` (32) | a header or card head |
| Profile | `CoveSize.avatarProfile` (64) | a profile or the home page |

Initial is Libre Bodoni at 0.44 × diameter, w500.

| Person | Fill | Initial |
|---|---|---|
| A — the home's **creator** | `personA` gradient | `personALabel` |
| B — the **joiner** | `personB` gradient | `personBLabel` |
| Both | **unfilled** — 1.5dp ring of `personBothRing` | `personBothLabel`, an ampersand |

## Rules

- **Keyed to `home.createdBy`, never to the viewer.** Both phones must agree on who is
  which colour, or a shared ledger becomes unreadable.
- **`both` has no fill.** A shared thing is owned by neither. The ring blends the two
  people's colours; it is not gold, because gold is reserved for one action per screen.
- 24 is the one off-grid size, set by the cap height of the 15sp text it sits in. It is a
  type-scale number, not a spacing one. Do not "fix" it to 24→28.
- Initials only. No photos, no emoji.
