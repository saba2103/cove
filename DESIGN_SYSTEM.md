# Cove Design System

This document is the **single source of truth** for visual design across all Cove features, platforms, and screens. It defines exact color tokens, typography, component geometry, spacing, motion, and interaction states.

---

## 1. Core Philosophy & Visual Identity

Cove’s visual character is **editorial, quiet, grounded, and architectural**. It draws inspiration from understated Scandinavian interiors and finely printed stationery rather than bright, noisy consumer software.

- **Warm Champagne Accent**: A sophisticated, muted metallic tone (`#D8B98C` in dark mode, deepened to `#A97C4F` in light mode for AA contrast) brings warmth without shouting.
- **Large-Number Presence**: Totals, amounts, and dates use **Bodoni Moda** with a specialized luminous tint (`#EAD3AC` in dark) that commands quiet authority without heavy drop shadows.
- **Calm Surface Hierarchy**: Surfaces differentiate via tonal steps and delicate hairline borders rather than artificial elevations or drop shadows.
- **Restraint Over Decoration**: Zero gamification, zero bouncy animations, zero colorful status chips.

---

## 2. Color Token Tables

### Dark Theme (Default)
| Token Name | Hex / Value | Description & Intent |
|---|---|---|
| `bg-dark` | `#0B1F1E` | Deep obsidian teal; base background of screens. |
| `surface-card-dark` | `#12302E` | Elevated surface for cards, dialogs, and navigation container. |
| `surface-row-dark` | `#0F2624` | Grouped list row fill, inputs, and recessed containers. |
| `accent-primary-dark` | `#D8B98C` | Muted champagne; primary interactive accent, active tabs/icons, checkboxes. |
| `accent-tint-dark` | `#EAD3AC` | Lighter champagne tint for large Bodoni Moda numerical totals. |
| `accent-secondary` | `#C46D5E` | Muted terracotta; strictly reserved for genuine attention-needed moments (e.g. overdue billing, destructive action confirmation). |
| `text-primary-dark` | `#F3ECE2` | Warm off-white; primary text, high-contrast headings. |
| `text-muted-dark` | `rgba(243, 236, 226, 0.55)` | Secondary labels, descriptions, and metadata (~55% opacity). |
| `text-subtle-dark` | `rgba(243, 236, 226, 0.40)` | Inactive states, placeholder text, hairline icons (~40% opacity). |
| `border-hairline-dark` | `rgba(243, 236, 226, 0.06)` | 1px dividers between grouped rows and card boundaries. |

### Light Theme
| Token Name | Hex / Value | Description & Intent |
|---|---|---|
| `bg-light` | `#F4EDE3` | Warm linen oat; base background of screens. |
| `surface-light` | `#FFFCF8` | Warm porcelain white; cards, sheets, grouped list containers. |
| `surface-row-light` | `#F8F3EC` | Subtle row hover or recessed pill inputs. |
| `accent-primary-light` | `#A97C4F` | Deepened champagne amber; calibrated for crisp contrast against linen. |
| `accent-tint-light` | `#A97C4F` | Shared with primary accent in light mode for balanced density. |
| `accent-secondary` | `#B85B4C` | Muted terracotta for warnings/alerts. |
| `text-primary-light` | `#1C2E2C` | Deep ink teal; primary readable copy. |
| `text-muted-light` | `rgba(28, 46, 44, 0.55)` | Secondary labels, descriptions (~55% opacity). |
| `text-subtle-light` | `rgba(28, 46, 44, 0.40)` | Placeholder text, inactive tab items (~40% opacity). |
| `border-hairline-light` | `rgba(28, 46, 44, 0.06)` | 1px border on cards and between grouped rows. |

---

## 3. Typography Scale

Cove pairs an editorial serif for large display figures with a modernist geometric sans for dense household information:

1. **Bodoni Moda** (`FontWeight.w500`): Display, numbers, monetary totals, hero headlines, dates.
2. **General Sans** (`FontWeight.w400`, `w500`, `w600`): UI labels, body paragraphs, dense grocery rows, buttons, metadata.

| Style Role | Font Family | Weight | Size (sp) | Line Height | Tracking | Context |
|---|---|---|---|---|---|---|
| `display-large` | Bodoni Moda | 500 | 36px | 1.15 | -0.5px | Hero metric (e.g. Monthly subscription total `$184`). |
| `headline` | Bodoni Moda | 500 | 26px | 1.20 | -0.3px | Screen greetings ("Good morning, Alex"), Section totals. |
| `title` | General Sans | 600 | 18px | 1.25 | 0.0px | Section headers ("Subscriptions", "Groceries"). |
| `body-medium` | General Sans | 500 | 15px | 1.35 | 0.0px | List item titles, standard button labels. |
| `body-regular` | General Sans | 400 | 14px | 1.40 | 0.0px | Secondary descriptions, timestamps, metadata. |
| `caption` | General Sans | 400 | 12px | 1.30 | +0.2px | Activity feed timestamps, auxiliary badges, fine print. |

---

## 4. Spacing & Layout Grid

Generous whitespace breathes serenity into everyday coordination:
- **Spacing Scale**: `4px`, `8px`, `12px`, `16px`, `24px`, `32px`, `48px`.
- **Screen Margins**: `20px` horizontal padding on mobile; max-width `480px` on web / desktop centered column.
- **Card Padding**: `18px` or `20px` internal padding for grouped cards.
- **Row Separation**: Never use vertical card gaps for items in the same collection. Group them inside a single `CoveCard` separated by a `1px` 6%-opacity hairline border.

---

## 5. Motion Principles

- **Pacing**: Deliberate, calm, and slow (300ms–400ms durations).
- **Easing**: Soft cubic eases (`Curves.easeInOutCubic` or `Curves.easeOutQuart`).
- **Forbidden**: No bouncing springs, no celebratory confetti particles, no gamified shaking or pulse rings.
- **Transitions**: Gentle cross-fades and smooth height expansions.

---

## 6. Iconography Rules

- **Stroke Weight**: Thin line only, **1.5px to 1.6px stroke width**.
- **Bounding Box**: Standard size **18px to 22px**.
- **Style**: Monoline, uncluttered, rounded terminal caps.
- **Exception**: The checked state of the checkbox uses a filled rounded-square container with a dark checkmark inside. All other iconography remains strictly outline/thin-stroke.

---

## 7. Two-Tick Delivery-Status Indicator

Cove uses a purposeful, understated visual language for item delivery synchronization:

```
State 1: Saved on this device
    ✓ (Single thin checkmark, 1.5px stroke, text-muted color)

State 2: Synced to partner's device
    ✓✓ (Two horizontally overlapping thin checkmarks, 1.5px stroke, text-muted color)
```

- **Deliberately Understated**: Both states render in muted text color (`text-muted`). They **never** flash green, blue, or champagne gold.
- **Strictly Two States**: There is **no third "Seen / Read" tick**. Cove honors mutual trust and peace of mind over surveillance.

---

## 8. Reusable Component Inventory

### 1. Card (`CoveCard`)
- **Radius**: `18px` border radius (`BorderRadius.circular(18)`).
- **Elevation**: Flat (elevation 0). Separation comes purely from the surface color step (`#12302E` dark / `#FFFCF8` light) and light mode's `1px solid rgba(28,46,44,0.06)` border.
- **Padding**: `16px` or `20px`.

### 2. Grouped List Row (`CoveGroupedRow`)
- Rows live together inside a single card container.
- Individual rows have a minimum tap target of `48px`.
- Separated by `1px` hairline divider at ~6% opacity.
- First and last items automatically clip to the card radius.

### 3. Pill Button (`CovePillButton`)
- **Radius**: `999px` (capsule).
- **Primary Variant**: Solid champagne background (`#D8B98C` dark / `#A97C4F` light), dark text (`#0B1F1E` / `#FFFCF8`).
- **Secondary / Outline Variant**: Transparent fill, 1.5px hairline border, text-primary color.
- **Height**: `48px` default, `40px` compact.

### 4. Pill Input (`CovePillInput`)
- **Radius**: `999px` capsule.
- **Background**: Dark mode `#0F2624`, Light mode `#F8F3EC`.
- **Border**: None or 1px hairline border.
- **Typography**: 14px General Sans with placeholder text at 40% opacity.
- **Prefix / Suffix**: Thin-line icon or subtle submission trigger.

### 5. Tab Row (`CoveTabRow`)
- Text-based tabs (e.g., "Groceries", "Packing", "Wishlist").
- Active tab indicated **strictly by a 2px champagne underline** offset `6px` below text.
- No pill background, no solid tabs, no floating chips.

### 6. Checkbox (`CoveCheckbox`)
- **Unchecked**: Rounded-square outline (`18x18px`, `5px` corner radius, `1.5px` stroke in `text-muted`).
- **Checked**: Solid champagne fill (`#D8B98C` / `#A97C4F`), dark micro-checkmark (`#0B1F1E` / `#FFFFFF`).
- **Row Interaction**: When checked, accompanying row title transitions to `text-muted` with strikethrough.

### 7. Toggle Switch (`CoveToggleSwitch`)
- **Dimensions**: `48px` width, `28px` height.
- **On State**: Solid champagne pill background, white/dark round knob sliding to the right.
- **Off State**: Outline-only pill with `1.5px` hairline border, muted knob docked on the left.

### 8. Bottom Navigation (`CoveBottomNav`)
- **Layout**: 5 evenly spaced icons:
  1. Dashboard (`Icons.dashboard_outlined` or custom thin-line)
  2. Subscriptions (`Icons.repeat_outlined`)
  3. Lists (`Icons.checklist_outlined`)
  4. Expenses (`Icons.account_balance_wallet_outlined`)
  5. More (`Icons.more_horiz_outlined`)
- **Labels**: **No text labels**.
- **Active State**: Primary champagne accent tint.
- **Inactive State**: Muted text tint (~40% opacity).
- **Border**: Hairline top border (`1px` ~6% opacity) with flat surface background.

### 9. Streak Indicator (`CoveStreakIndicator`)
- Displays an integer streak count in **Bodoni Moda** alongside a subtle caption ("days").
- Strictly **no flame graphics, no emojis, no celebratory shields**.

### 10. Activity / Feed Row (`CoveActivityRow`)
- Clean horizontal row displaying avatar/initial dot, action phrase ("Sarah checked off Oats"), and relative timestamp ("12m ago").
- Accompanied by the two-tick sync indicator on the far right.

### 11. Empty State (`CoveEmptyState`)
- Serene, unhurried placeholder: thin-stroke editorial icon, 16px title, 14px muted subtitle.

### 12. Loading State (`CoveLoading`)
- Gentle, low-contrast indeterminate arc or pulsing placeholder shimmer in champagne hue, avoiding aggressive spinners.
