# System chrome — NOT a widget

The prototype draws a status bar because a web page has none. **The app must not.**
iOS and Android draw it, and reproducing it would double it.

What the app owns instead:

| | |
|---|---|
| Overlay style | `SystemUiOverlayStyle.light` on dark theme, `.dark` on light theme. Set it from the theme, once, not per screen. |
| Status bar colour | Transparent. The canvas runs under it. |
| Top inset | `MediaQuery.padding.top`. Never a hardcoded height. |
| Bottom inset | `MediaQuery.padding.bottom`, added to `CoveSpace.barClearance` on pages wearing the floating bar. |

**The prototype's dots and clock are scaffolding. Do not build them.**

The one thing to carry over: content begins immediately below the inset with no extra
padding of its own — the page header supplies its own top space.
