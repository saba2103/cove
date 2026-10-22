# CoveToast

The brief confirmation, usually carrying an Undo.

| | |
|---|---|
| Position | below the status-bar inset AND any page header, above the content acted on |
| Padding | `CoveSpace.sm` vertical, `CoveSpace.gutter` horizontal |
| Radius | `CoveRadius.pill` |
| Fill | `surface.row`, 1dp `accent.fill` border |
| Text | `CoveType.readout` in `text.primary` |
| Undo | `accent.text`, a real button with a `CoveSize.hit` target |

## Rules

- **It was positioned against whatever header happened to be on that screen**, which put
  it in three different places. It is positioned against the device now: inset + header
  height + `CoveSpace.md`.
- **Dismissal is not purely time-based when an Undo is present.** WCAG 2.2.1: an
  assistive-technology user must be able to reach it. Pause on focus, and extend when a
  screen reader is active.
- One at a time. A second replaces the first; they never stack.
