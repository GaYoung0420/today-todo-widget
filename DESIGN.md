---
name: Focus Todo
description: A calm menu-bar focus utility for todos, Pomodoro sessions, notes, and website blocking.
colors:
  primary: "#5645D4"
  primary-pressed: "#4534B3"
  primary-light: "#EDE9FC"
  brand-navy: "#0A1530"
  brand-navy-deep: "#070F24"
  canvas: "#FFFFFF"
  surface: "#F6F5F4"
  surface-soft: "#FAFAF9"
  widget: "#FCFCFB"
  memo-background: "#FEF7D6"
  hairline: "#E5E3DF"
  hairline-soft: "#EDE9E4"
  hairline-strong: "#C8C4BE"
  ink: "#1A1A1A"
  charcoal: "#37352F"
  slate: "#5D5B54"
  steel: "#787671"
  stone: "#A4A097"
  muted: "#BBB8B1"
  error: "#E03131"
  success: "#1AAE39"
  error-light: "#FFF0F0"
  peach: "#FFE8D4"
  rose: "#FDE0EC"
  mint: "#D9F3E1"
  lavender: "#E6E0F5"
  sky: "#DCECFA"
  yellow: "#F9E79F"
typography:
  heading:
    fontFamily: "Pretendard Variable"
    fontSize: "20px"
    fontWeight: 600
  body:
    fontFamily: "Pretendard Variable"
    fontSize: "15px"
    fontWeight: 400
  caption:
    fontFamily: "Pretendard Variable"
    fontSize: "14px"
    fontWeight: 400
  micro:
    fontFamily: "Pretendard Variable"
    fontSize: "13px"
    fontWeight: 600
  timer:
    fontFamily: "Pretendard Variable"
    fontSize: "46px"
    fontWeight: 600
rounded:
  sm: "6px"
  md: "8px"
  lg: "12px"
  widget: "12px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "16px"
  lg: "20px"
  xl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.canvas}"
    rounded: "{rounded.md}"
    height: "34px"
    padding: "0 12px"
  button-primary-pressed:
    backgroundColor: "{colors.primary-pressed}"
    textColor: "{colors.canvas}"
    rounded: "{rounded.md}"
    height: "34px"
    padding: "0 12px"
  widget-surface:
    backgroundColor: "{colors.widget}"
    textColor: "{colors.charcoal}"
    rounded: "{rounded.widget}"
  shortcut-badge:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.slate}"
    rounded: "4px"
    height: "18px"
    padding: "0 5px"
---

# Design System: Focus Todo

## 1. Overview

**Creative North Star: "A Tidy Desk Timer"**

Focus Todo should feel like a small, well-kept desktop object: present when needed, quiet when ignored, and precise at menu-bar scale. The visual system is compact, warm-neutral, and slightly tactile, with soft dividers, restrained purple accents, and Korean labels that stay short.

The interface serves a product workflow, not a brand moment. It should prioritize scan speed, stable dimensions, and low cognitive load over expressive layout. The current system uses fixed-size floating panels, soft surfaces, hairline borders, compact controls, and brief hover affordances.

**Key Characteristics:**
- Compact floating panels with stable widths and heights.
- Warm neutral surfaces, charcoal text, and a single calm purple accent.
- Small icons and labels that reveal actions without crowding rows.
- Inline additions, lightweight settings, and timer controls that keep the user in flow.
- Minimal motion, used only to clarify state changes.

## 2. Colors

The palette is a warm-neutral desktop system with a focused violet accent and small semantic colors for success, blocking, memo, and category tags.

### Primary
- **Focus Violet** (#5645D4): The main accent for active tasks, Pomodoro progress, selected affordances, and focused calls to action.
- **Pressed Violet** (#4534B3): The pressed state for primary controls.
- **Soft Violet Wash** (#EDE9FC): A quiet selected background or focus-mode chip background.

### Secondary
- **Rest Green** (#1AAE39): Rest mode and successful Pomodoro completion.
- **Block Red** (#E03131): Website blocking status, destructive or attention-needed blocker states.
- **Memo Paper** (#FEF7D6): The memo panel background, used only for note-taking context.

### Tertiary
- **Peach, Rose, Mint, Lavender, Sky, Yellow** (#FFE8D4, #FDE0EC, #D9F3E1, #E6E0F5, #DCECFA, #F9E79F): Soft tag and supporting colors. Use sparingly so they read as gentle categorization, not decoration.

### Neutral
- **Canvas** (#FFFFFF): Main panel background in the current codebase.
- **Surface** (#F6F5F4): Button, badge, and hover surface.
- **Surface Soft** (#FAFAF9): Inline add row and soft inactive areas.
- **Widget** (#FCFCFB): Floating widget base.
- **Hairline Stack** (#E5E3DF, #EDE9E4, #C8C4BE): Dividers and widget outlines.
- **Charcoal, Slate, Steel, Stone, Muted** (#37352F, #5D5B54, #787671, #A4A097, #BBB8B1): Text hierarchy from primary readable text to disabled or secondary metadata.

### Named Rules

**The Violet Rarity Rule.** Use Focus Violet for task-critical state only: active, selected, progress, and primary action. It should not become a decorative wash across every panel.

**The Warm Neutral Rule.** Prefer `surface`, `surface-soft`, and `widget` over stark white for new surfaces. The existing `canvas` token is allowed where the platform panel needs maximum clarity.

## 3. Typography

**Display Font:** Pretendard Variable  
**Body Font:** Pretendard Variable  
**Label/Mono Font:** Pretendard Variable with monospaced digits where timers or counters change.

**Character:** The typography should feel native, compact, and calm. Pretendard supports Korean UI labels cleanly, and the scale should stay tight enough for floating panels without making the app feel cramped.

### Hierarchy
- **Timer** (600, 46px): Large Pomodoro time display when a dedicated timer surface has room.
- **Heading** (600, 20px): Larger panel titles or empty states. Avoid using this inside dense rows.
- **Body** (400 or 500, 15px): Settings rows, standard controls, and readable paragraph-like content.
- **Caption** (400 or 600, 14px): Panel headers, memo labels, and medium-emphasis compact text.
- **Micro** (600, 13px): Widget headers, row labels, pills, shortcuts, and tight controls.
- **Tiny Status** (500 to 600, 9px to 11px): Timer helper text, counters, badges, and metadata.

### Named Rules

**The One-Line Panel Rule.** In compact widgets, primary row text should stay one line and truncate cleanly. Expand detail in memo or settings panels instead of increasing row height.

## 4. Elevation

The system is mostly flat and uses tonal layering, clipping, and hairline borders for depth. Shadows exist as tokens, but current floating widgets lean on crisp outlines and subtle surface gradients more than visible drop shadows.

### Shadow Vocabulary
- **Widget Shadow** (`black 18%`): Reserved for floating widget separation if shadow rendering is reintroduced.
- **Floating Shadow** (`black 24%`): Reserved for larger floating panels, especially memo or settings.
- **Soft Shadow** (`black 10%`): Used by cards or primary circular controls when a small lifted response is needed.

### Named Rules

**The Flat-Until-Useful Rule.** Do not add shadows just to make panels look premium. Use elevation for focus, drag separation, or active controls only.

## 5. Components

### Buttons
- **Shape:** Rectangular primary buttons use 8px radius. Circular timer buttons use exact circular frames.
- **Primary:** Focus Violet background, Canvas text, 34px height, 12px horizontal padding.
- **Pressed:** Switch to Pressed Violet or reduce opacity for icon-only circular controls.
- **Icon Buttons:** 20px to 30px square frames, neutral tint, surface background only when helpful.
- **Timer Controls:** Primary play or pause is charcoal with canvas icon; secondary controls are surface with steel icons.

### Chips
- **Mode Chips:** Compact capsules with mode color on a soft mode background.
- **Shortcut Badges:** 18px high, surface background, slate text, 4px radius, hairline stroke.
- **Status Chips:** Use semantic color plus soft tint, such as red on error-light for blocked sites.

### Cards / Containers
- **Corner Style:** 12px continuous radius for floating panels and widgets.
- **Background:** Widget panels use a near-white warm gradient or the widget token. Memo uses memo-background.
- **Border:** Hairline outlines are the main depth device. Use soft inner highlights only on floating widget surfaces.
- **Internal Padding:** Headers use 12px horizontal padding. Settings content uses 14px horizontal padding. Rows stay compact and predictable.

### Inputs / Fields
- **Inline Todo Input:** Appears in the task list flow, not a modal. Use surface-soft background and micro text.
- **Memo Editor:** Uses Pretendard 13px with line spacing, hidden scroll background, and a split preview.
- **Focus:** Prefer platform-native focus where possible, with clear row state and no decorative glow.
- **Error / Disabled:** Use Block Red for true blocking or destructive status only. Muted and Stone handle disabled or secondary text.

### Navigation
- **Menu Bar:** The app starts from a `MenuBarExtra`, so menu labels should remain direct and short.
- **Settings Tabs:** Three compact text tabs with a 2px charcoal underline for selected state.
- **Panel Headers:** Centered title, optional right-side status or shortcut badge, 46px height, bottom hairline.

## 6. Do's and Don'ts

**Do:**
- Keep panels compact and stable.
- Use purple only for active focus, progress, selected state, or primary action.
- Keep Korean labels short enough for fixed-width widgets.
- Prefer inline controls for add, memo, timer, and blocker flows.
- Use hairline borders and warm neutral surfaces before adding shadow.
- Preserve keyboard shortcuts and visible shortcut badges where they improve repeat use.

**Don't:**
- Do not turn the app into a dashboard, kanban board, or analytics surface.
- Do not add loud gradients, glass blur, neon dark mode, or decorative reward animations.
- Do not rely on color alone for active, completed, blocked, or paused state.
- Do not introduce nested card layouts inside the floating panels.
- Do not make hover-only actions the only way to complete critical workflows.
- Do not use long explanatory UI copy in compact widgets.
