#!/usr/bin/env python3
"""Fails the build if any Cove token pair misses its WCAG 2.2 AA floor.

Text >= 4.5:1 on every surface, slip stop, and sky stop it can land on.
Non-text UI boundaries and state marks >= 3:1 (WCAG 1.4.11) across both modes
(dark, light) and both slip variants (paper, ink):
  - empty and upcoming EMI punches (slip punch dots, due rings, card ticks)
  - the light-mode slip edge (against outer light surfaces and inner paper stops)
  - toggles (off-track border, off-thumb, on-track fill, on-thumb)
  - the unticked checkbox (and ticked fill + checkmark)
  - input borders (resting and error borders on surfaces and slips)
  - the focus ring (line.focus on surfaces and slips)
  - meaningful chart lines (grid/pace/zero/track lines, category & dial arcs,
    sky NOW line across all 7 sky gradient stops)
"""
import json
import pathlib
import sys

d = json.load(open(pathlib.Path(__file__).parent.parent / 'design/tokens.json'))


def rgb(h):
    h = h.lstrip('#')
    if len(h) == 8:
        return tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) + (int(h[6:8], 16) / 255,)
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) + (1.0,)


def over(fg, bg):
    a = fg[3]
    return tuple(fg[i] * a + bg[i] * (1.0 - a) for i in range(3)) + (1.0,)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3)) + (1.0,)


def lum(c):
    def f(v):
        v = v / 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4

    return 0.2126 * f(c[0]) + 0.7152 * f(c[1]) + 0.0722 * f(c[2])


def cr(fg, bg):
    if len(fg) == 4 and fg[3] < 1.0:
        fg = over(fg, bg)
    L1, L2 = sorted((lum(fg), lum(bg)), reverse=True)
    return (L1 + 0.05) / (L2 + 0.05)


def val(g, n, m):
    v = d[g][n]['$value']
    return v[m] if isinstance(v, dict) and m in v else v


def sky_stops(mode):
    night = rgb(val('surface', 'canvas', mode))
    card = rgb(val('surface', 'card', mode))
    row = rgb(val('surface', 'row', mode))
    dawn = mix(card, rgb(val('accent', 'fill', mode)), 0.28)
    morning = mix(card, rgb(val('category', 'pets', mode)), 0.14)
    midday = mix(card, rgb(val('category', 'fuel', mode)), 0.14)
    dusk = mix(card, rgb(val('accent', 'fill', mode)), 0.24)
    twilight = mix(row, rgb(val('money', 'more', mode)), 0.14)
    pre_dawn = row
    return [
        ('night', night),
        ('dawn', dawn),
        ('morning', morning),
        ('midday', midday),
        ('dusk', dusk),
        ('twilight', twilight),
        ('preDawn', pre_dawn),
    ]


TEXT = [
    ('text', 'primary'),
    ('text', 'secondary'),
    ('text', 'tertiary'),
    ('accent', 'text'),
    ('accent', 'tint'),
    ('status', 'alertText'),
    ('money', 'more'),
    ('money', 'less'),
    ('status', 'good'),
]

# Non-text UI boundaries, state marks, and meaningful chart lines on surfaces:
# - line.control: empty/upcoming EMI card ticks, toggle off-track border,
#   unticked checkbox border, resting input border, chart pace/zero/grid/track lines
# - line.focus: focus ring / focused input border
# - accent.fill: toggle on-track, ticked checkbox fill, paid/due EMI tick, chart data stroke/bars
# - status.alert: overdue EMI tick, over-budget bar, error input border
# - status.good: settled state mark
# - text.secondary: toggle off-thumb inside off-track
# - text.tertiary: unticked checkbox / habit dot outline
SURFACE_MARKS = [
    ('line', 'control'),
    ('line', 'focus'),
    ('accent', 'fill'),
    ('status', 'alert'),
    ('status', 'good'),
    ('text', 'secondary'),
    ('text', 'tertiary'),
]

fails = []


def require(label, fg, bg, floor):
    r = cr(fg, bg)
    if r < floor:
        fails.append(f"{label} = {r:.2f} (need {floor:.1f})")


# 1. Dark & light app surfaces (canvas, card, row, sheet)
for mode in ('dark', 'light'):
    surfaces = {k: rgb(val('surface', k, mode)) for k in ('canvas', 'card', 'row', 'sheet')}

    for g, n in TEXT:
        c = rgb(val(g, n, mode))
        for sn, sv in surfaces.items():
            require(f"{mode}: {g}.{n} on surface.{sn}", c, sv, 4.5)

    for g, n in SURFACE_MARKS:
        c = rgb(val(g, n, mode))
        for sn, sv in surfaces.items():
            require(f"{mode} mark: {g}.{n} on surface.{sn}", c, sv, 3.0)

    # Toggle on-thumb & ticked checkbox checkmark on accent.fill
    require(
        f"{mode}: text.onAccent on accent.fill",
        rgb(val('text', 'onAccent', mode)),
        rgb(val('accent', 'fill', mode)),
        4.5,
    )

    # Category marks & chart series on every surface in both modes
    for k in d['category']:
        cat_c = rgb(val('category', k, mode))
        for sn, sv in surfaces.items():
            require(f"{mode} chart/mark: category.{k} on surface.{sn}", cat_c, sv, 3.0)

    # Routines sky gradient: text.sky >= 4.5:1 and NOW line (line.focus) >= 3.0:1
    # across every stop and every interpolated point between stops
    stops = sky_stops(mode)
    sky_text = rgb(val('text', 'sky', mode))
    sky_now = rgb(val('line', 'focus', mode))
    for i in range(len(stops) - 1):
        s0_name, s0_col = stops[i]
        s1_name, s1_col = stops[i + 1]
        worst_text = min(cr(sky_text, mix(s0_col, s1_col, t / 20.0)) for t in range(21))
        if worst_text < 4.5:
            fails.append(
                f"{mode} sky: text.sky on {s0_name}->{s1_name} = {worst_text:.2f} (need 4.5)"
            )
        worst_now = min(cr(sky_now, mix(s0_col, s1_col, t / 20.0)) for t in range(21))
        if worst_now < 3.0:
            fails.append(
                f"{mode} sky chart: line.focus (NOW) on {s0_name}->{s1_name} = {worst_now:.2f} (need 3.0)"
            )


# 2. Paper slip variant (paper.from, paper.via, paper.to) + light-mode slip edge
paper_stops = {k: rgb(val('paper', k, 'light')) for k in ('from', 'via', 'to')}
PAPER_TEXT = [
    ('paper', 'ink'),
    ('paper', 'ink2'),
    ('paper', 'ink3'),
    ('paper', 'accent'),
    ('status', 'good'),
]
# Non-text marks on paper:
# - paper.ink3: empty/upcoming EMI punches, paid faded due-circle, missed streak cells, CoveDial track
# - paper.accent: paid EMI punches, due-circle ring, done streak cells, today ring
# - line.control / line.focus / text.tertiary / accent.fill / status.alert: innerTheme controls & checkboxes
# - category.* (light): CoveDial category share arcs
PAPER_MARKS = [
    ('paper', 'ink3'),
    ('paper', 'accent'),
    ('status', 'good'),
    ('status', 'alert'),
    ('line', 'control'),
    ('line', 'focus'),
    ('text', 'tertiary'),
] + [('category', k) for k in d['category']]

for g, n in PAPER_TEXT:
    c = rgb(val(g, n, 'light'))
    for sn, sv in paper_stops.items():
        require(f"paper text: {g}.{n} on paper.{sn}", c, sv, 4.5)

for g, n in PAPER_MARKS:
    c = rgb(val(g, n, 'light'))
    for sn, sv in paper_stops.items():
        require(f"paper mark: {g}.{n} on paper.{sn}", c, sv, 3.0)

# Light-mode slip edge (paper.edge): must clear 3:1 against outer light surfaces
# AND against inner paper stops (composited over paper if translucent).
edge_light = rgb(val('paper', 'edge', 'light'))
edge_dark = rgb(val('paper', 'edge', 'dark'))
if edge_dark[3] != 0.0:
    fails.append(f"dark paper.edge must stay transparent (alpha={edge_dark[3]:.2f})")
light_surfaces = {k: rgb(val('surface', k, 'light')) for k in ('canvas', 'card', 'row', 'sheet')}
for pn, pv in paper_stops.items():
    rendered_edge = over(edge_light, pv) if edge_light[3] < 1.0 else edge_light
    require(f"light slip edge: paper.edge on paper.{pn}", rendered_edge, pv, 3.0)
    for sn, sv in light_surfaces.items():
        require(
            f"light slip edge: paper.edge (at paper.{pn}) vs surface.{sn}",
            rendered_edge,
            sv,
            3.0,
        )


# 3. Ink slip variant (slip.inkFrom, slip.inkVia, slip.inkTo)
ink_stops = {k: rgb(val('slip', k, 'dark')) for k in ('inkFrom', 'inkVia', 'inkTo')}
INK_TEXT = [
    ('text', 'primary'),
    ('text', 'secondary'),
    ('accent', 'text'),
    ('money', 'more'),
    ('money', 'less'),
    ('status', 'good'),
    ('slip', 'inkText3'),
    ('slip', 'inkAlertText'),
]
# Non-text marks on ink:
# - slip.inkMark: empty/upcoming EMI punches, paid faded due-circle, missed streak cells, CoveDial track
# - accent.fill: paid EMI punches, due-circle ring, done streak cells, today ring
# - line.control / line.focus / text.tertiary / status.alert: innerTheme controls & checkboxes
# - category.* (dark): CoveDial category share arcs on ink
INK_MARKS = [
    ('slip', 'inkMark'),
    ('accent', 'fill'),
    ('status', 'good'),
    ('status', 'alert'),
    ('line', 'control'),
    ('line', 'focus'),
    ('text', 'tertiary'),
] + [('category', k) for k in d['category']]

for g, n in INK_TEXT:
    c = rgb(val(g, n, 'dark'))
    for sn, sv in ink_stops.items():
        require(f"ink text: {g}.{n} on slip.{sn}", c, sv, 4.5)

for g, n in INK_MARKS:
    c = rgb(val(g, n, 'dark'))
    for sn, sv in ink_stops.items():
        require(f"ink mark: {g}.{n} on slip.{sn}", c, sv, 3.0)


# 4. Person avatar initials across person gradients
for p, l in (('a', 'aLabel'), ('b', 'bLabel')):
    g = d['person'][p]['$value']
    lab = rgb(d['person'][l]['$value'])
    f, t = rgb(g['from']), rgb(g['to'])
    worst = min(cr(lab, mix(f, t, x / 100.0)) for x in range(101))
    if worst < 4.5:
        fails.append(f"person.{p} initial across its gradient = {worst:.2f} (need 4.5)")
# person.both is unfilled: its ring endpoints clear 3:1 or sit beside text.primary ampersand

if fails:
    print("CONTRAST GATE FAILED\n" + "\n".join("  ! " + f for f in fails))
    sys.exit(1)
print("contrast gate: all pairs pass")
