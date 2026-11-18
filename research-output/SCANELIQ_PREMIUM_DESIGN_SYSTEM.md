# Scaneliq — Premium Visual Identity & Design System ("Precision Paper")

**Document Date:** November 18, 2026  
**Design Language Name:** **Precision Paper**  
**Brand Positioning:** Editorial calm, optical precision, zero-noise privacy vault.  
**Replaces:** Legacy `AppColors` (`#2563EB` + `#00F0FF` neon cyan + arbitrary Material rainbow icons).

---

## 1. Visual Identity & Brand Direction

- **Design Ethos:** Treat every scanned document like **crisp archival paper** resting on a quiet desk. UI chrome never competes with the user's documents—no neon accents, no 3-stop gradients, no heavy drop shadows, and no multi-colored rainbow icon grids.
- **Signature Motifs:**
  - **1px Hairline Precision:** Elevation comes from clean tonal surface stepping (`canvas` → `surface` → `surfaceElevated`) + crisp `1px` borders, reserving soft shadow solely for floating camera triggers and modal sheets.
  - **Dual-Anchor Accent Restraint:** **Cobalt Ink (`#1E40AF`)** drives all primary actions and navigation focus; **Optical Emerald (`#0D9488`)** is reserved strictly for active optical boundary detection, live capture locks, and verification states.
  - **Bilingual Typographic Parity:** First-class Latin (`Plus Jakarta Sans` / `Inter`) + Bengali (`Noto Sans Bengali`) rendering with tabular figures (`tnum`) for page counts, dates, and byte sizes.

---

## 2. Complete Color System (Light, Dark & Scanner Tokens)

### 2.1 Light Theme Tokens (`Precision Light`)
| Token Name | Hex | Role & Usage | Contrast Note |
|---|---|---|---|
| `brandPrimary` | `#1E40AF` | Primary CTAs, active nav indicator text/icon, key links | `8.59:1` vs White (AAA) |
| `brandPrimaryPressed` | `#1E3A8A` | Pressed / active state of primary buttons | `10.3:1` vs White |
| `brandTint` | `#EEF2FF` | Subtle selected nav pill, active chip fill, hero icon well | `1.12:1` subtle tint |
| `brandSecondary` | `#0F172A` | High-authority secondary ink / dark badges | `17.8:1` vs White |
| `scannerAccent` | `#0D9488` | **Optical Emerald** — Auto-edge quad overlay, scan lock, live OCR highlights | `3.9:1` vs White (UI graphical AAA) |
| `scannerAccentSoft` | `#CCFBF1` | Subtle fill inside detected quad polygon | 20% opacity overlay |
| `canvas` (`surface0`) | `#F6F7F9` | Root scaffold background (warm archival off-white) | Base |
| `surface` (`surface1`) | `#FFFFFF` | Document cards, grouped lists, tool cards, bottom bar | Elevated paper |
| `surfaceMuted` (`surface2`) | `#EDEFF3` | Search pills, inactive filter chips, icon container wells | Sub-surface |
| `surfaceOverlay` (`surface3`) | `#E2E5EB` | Pressed list states, subtle hover/divider tracks | Hairline |
| `textPrimary` | `#111827` | Document titles, screen headers, primary body copy | `16.4:1` vs `#FFFFFF` |
| `textSecondary` | `#4B5563` | Subtitles, timestamps, page counts, folder breadcrumbs | `7.56:1` vs `#FFFFFF` (AAA) |
| `textTertiary` | `#6B7280` | Hints, placeholders, disabled/caption metadata *(fixes old `#98A2B3` fail)* | `4.83:1` vs `#FFFFFF` (AA Pass) |
| `borderHairline` | `#E2E5EB` | `1px` structural card/input/sheet borders | Subtle separation |
| `success` | `#15803D` | Export complete, valid signature, OCR active badge | `5.02:1` vs White |
| `warning` | `#B45309` | Unfinished draft banner, offline model pending | `5.02:1` vs White |
| `error` | `#B91C1C` | Delete, Trash purge, PIN failure, validation error | `6.47:1` vs White |

### 2.2 Dark Theme Tokens (`Obsidian Slate` — Zero Neon Cyan)
| Token Name | Hex | Role & Usage |
|---|---|---|
| `brandPrimaryDark` | `#60A5FA` | Primary interactive icons, active tab tint, text links, focus rings |
| `brandPrimaryFillDark` | `#2563EB` | Filled primary button background (paired with `#FFFFFF` label: `5.17:1`) |
| `brandTintDark` | `#1E293B` | Selected pill fill & icon well background |
| `scannerAccentDark` | `#2DD4BF` | Optical edge detection quad & capture indicator in dark camera/viewer |
| `canvasDark` (`surface0`) | `#0B0F17` | Root OLED-friendly dark canvas |
| `surfaceDark` (`surface1`) | `#141923` | Document cards, bottom bar, grouped settings cards |
| `surfaceMutedDark` (`surface2`) | `#1D2432` | Search inputs, unselected chips, secondary tonal buttons |
| `surfaceOverlayDark` (`surface3`) | `#262F40` | Dividers, active hover/pressed states |
| `textPrimaryDark` | `#F3F4F6` | Headings & primary labels (`15.2:1` vs `#141923`) |
| `textSecondaryDark` | `#9CA3AF` | Metadata, dates, subtitles (`6.4:1` vs `#141923`) |
| `textTertiaryDark` | `#6B7280` | Placeholders & inactive captions |
| `borderHairlineDark` | `#262F40` | `1px` crisp card/sheet borders |
| `successDark` / `warningDark` / `errorDark` | `#4ADE80` / `#FBBF24` / `#F87171` | High-legibility semantic foreground accents on dark surfaces |

### 2.3 Camera & Viewfinder Dedicated HUD Tokens (Always Dark Mode)
| Token | Value | Usage |
|---|---|---|
| `hudCanvas` | `#000000` | True black camera framing |
| `hudGlass` | `rgba(17, 24, 39, 0.72)` | Translucent top pill & bottom mode bar (`BackdropFilter` blur `12dp`) |
| `hudQuadActive` | `#2DD4BF` (2.5dp stroke) | Locked document boundary polygon + corner dots |
| `hudQuadSearching` | `rgba(255, 255, 255, 0.55)` | Unstable/searching boundary hint |
| `hudShutterRing` | `#FFFFFF` (`3dp`) + `#FFFFFF` inner disc (`60dp`) | Tactile camera shutter; morphs to `#2DD4BF` ring during auto-capture countdown |

### 2.4 Strictly Scoped Tag Palette (Tags & Folders ONLY)
To replace the 12-color rainbow clutter across tools, color coding is banned from navigation/tools and restricted solely to user-assigned **Tags/Folders**:
- Slate Blue (`#2563EB`), Sage Green (`#059669`), Warm Amber (`#D97706`), Violet (`#7C3AED`). Rendered as compact `8dp` dot + subtle 10% tint pill.

---

## 3. Typography System

- **Display & Headings:** `Plus Jakarta Sans` (Fallback: `Noto Sans Bengali`, `Roboto`, `sans-serif`) — Crisp geometric authority for titles and brand headers.
- **UI, Body & Metadata:** `Inter` (Fallback: `Noto Sans Bengali`, `Roboto`, `sans-serif`) with `FontFeature.tabularFigures()` applied to all page counts, byte sizes, dates, and timers.

| Token | Font | Size | Weight | Line Height | Letter Spacing | Usage |
|---|---|---|---|---|---|---|
| `displayMedium` | Plus Jakarta Sans | `24sp` | `w700` | `1.25` (`30sp`) | `-0.4` | Onboarding hero, Empty state titles |
| `headlineSmall` | Plus Jakarta Sans | `20sp` | `w700` | `1.30` (`26sp`) | `-0.3` | Screen AppBar titles (`Documents`, `Tools`) |
| `titleLarge` | Plus Jakarta Sans | `17sp` | `w600` | `1.35` (`23sp`) | `-0.2` | Section headers (`Recent Scans`, `PDF Suite`) |
| `titleMedium` | Inter | `15sp` | `w600` | `1.35` (`20sp`) | `-0.1` | Document card titles, grouped list row titles |
| `bodyLarge` | Inter | `15sp` | `w400` | `1.45` (`22sp`) | `0.0` | Dialog copy, OCR extracted text reader |
| `bodyMedium` | Inter | `13sp` | `w400` | `1.40` (`18sp`) | `0.0` | Row subtitles, folder descriptions |
| `bodySmall` | Inter | `12sp` | `w400` | `1.35` (`16sp`) | `0.1` | Timestamps, `4 pages · 1.2 MB`, helper captions |
| `labelLarge` | Inter | `14sp` | `w600` | `1.20` (`17sp`) | `0.1` | Primary/Secondary CTA buttons |
| `labelMedium` | Inter | `12sp` | `w600` | `1.20` (`14sp`) | `0.1` | Filter chips, nav labels, status pills |
| `labelSmall` | Inter | `11sp` | `w600` | `1.15` (`13sp`) | `0.2` | Micro badges (`PDF`, `PRO`, page count badges) |

---

## 4. Layout Grid, Spacing, Geometry & Elevation

### 4.1 8dp Precision Spacing Scale
- `xs = 4dp` (inline icon-to-text micro gaps)
- `sm = 8dp` (chip spacing, tight metadata rows)
- `md = 12dp` (between stacked cards in lists, 2-column grid gutters)
- `lg = 16dp` (**standard horizontal screen margin** and internal card padding)
- `xl = 24dp` (**section-to-section vertical spacing**)
- `xxl = 32dp` (onboarding & empty-state vertical rhythm)

### 4.2 Breakpoints & Responsive Grid
- **Compact Phone (`< 600dp`):** `16dp` outer padding; `2`-column document grid (`0.72` aspect ratio); `4`-column quick tool icons.
- **Large Phone / Foldable (`600–839dp`):** `24dp` outer padding; `3`-column document grid; side-by-side editor preview + control rail in landscape.
- **Tablet (`>= 840dp`):** NavigationRail (`80dp` left rail) replacing bottom bar; `4`–`5` column document grid; split-pane Document Library + PDF Viewer preview.

### 4.3 Radius & Dimensions Standard
| Element | Radius / Dimension | Rule |
|---|---|---|
| Bottom Navigation Bar | `64dp` height (+ `SafeArea`) | Top `1px` `borderHairline`; zero heavy box-shadow |
| Center Camera Pill Trigger | `56×44dp` capsule (`22dp` radius) or `52dp` squircle (`16dp` radius) | Solid `brandPrimary` (light) / `brandPrimaryFillDark` (dark); **NO gradient** |
| AppBar / Top Toolbar | `56dp` height | Flat `canvas` background (`scrolledUnderElevation: 0`) |
| Document Card (List) | `72dp` min height, `14dp` radius | `44×58dp` (`1:1.32` A4 ratio) paper thumbnail with `1px` border |
| Document Card (Grid) | `14dp` radius | Top `1:1.35` cached thumbnail (`cacheWidth: 420`) + bottom 2-line footer |
| Primary / Secondary Buttons | `48dp` height, `12dp` radius | **Never** `double.infinity` width inside `ThemeData` (wrap explicitly when full-width is desired) |
| Icon Hit Target | **Minimum `48×48dp`** | Enforced via `IconButton` constraints / `ConstrainedBox` on every tap target |
| Search Field / Pill | `46dp` height, `12dp` radius | `surfaceMuted` fill, `1px` focus ring |
| Filter Chips | `36dp` height (`48dp` vertical tap wrapper), `18dp` pill radius | Clean outline/tonal state |
| Bottom Sheets & Modals | `24dp` top radius (sheets), `16dp` (dialogs) | Top drag handle `36×4dp` centered |

---

## 5. Component Specifications (Anti-Clutter Rules)

1. **Unified Tool Tile / Grid Card:**
   - Icon sits inside a neutral `40×40dp` container (`surfaceMuted` fill, single monochrome `textPrimary` or `brandPrimary` line icon `20dp`)—eliminating the 12-color rainbow boxes.
2. **Document Card (`ScaneliqDocumentCard`):**
   - Displays genuine crisp paper thumbnail (with subtle `1px` page-border hairline), **Title** (`maxLines: 1`), **Single metadata line** (`"5 pages · PDF · Nov 18"` in tabular figures), subtle optional **Tag dot**, and an explicit `48×48dp` overflow menu button (Rename, Share, Organize Pages, Move, Export JPEG, Delete). Star/Favorite lives cleanly in long-press or quick-menu—or as a `48dp` safe hit area—never a `24dp` corner touch target.
3. **Contextual Multi-Select Dock:**
   - Replaces bottom navigation during selection mode with a crisp `64dp` floating bottom dock: `Move`, `Tag`, `Merge PDF`, `Share`, `Trash`.
4. **Empty, Loading & Error States (`ScaneliqStateView`):**
   - **Empty:** Monochrome custom vector/line badge (`64dp` circle in `brandTint`), clear 1-line headline, concise 2-line helper copy, max 1 primary CTA.
   - **Loading:** Shimmer skeleton cards matching actual list/grid geometry instead of blank centered spinners; modal file ops show a determinate/indeterminate pill card with file name & Cancel button.
   - **Error:** Inline calm banner (`error` 8% tint + `1px` border + explicit `Retry` button); never dump raw exception stack traces or `/data/user/0/...` paths to the user.

---

## 6. Figma-Ready Token Export Summary

```json
{
  "scaneliq.color.light": {
    "brand.primary": "#1E40AF",
    "brand.pressed": "#1E3A8A",
    "brand.tint": "#EEF2FF",
    "scanner.emerald": "#0D9488",
    "canvas": "#F6F7F9",
    "surface": "#FFFFFF",
    "surface.muted": "#EDEFF3",
    "border.hairline": "#E2E5EB",
    "text.primary": "#111827",
    "text.secondary": "#4B5563",
    "text.tertiary": "#6B7280",
    "semantic.success": "#15803D",
    "semantic.warning": "#B45309",
    "semantic.error": "#B91C1C"
  },
  "scaneliq.color.dark": {
    "brand.primary": "#60A5FA",
    "brand.fill": "#2563EB",
    "brand.tint": "#1E293B",
    "scanner.emerald": "#2DD4BF",
    "canvas": "#0B0F17",
    "surface": "#141923",
    "surface.muted": "#1D2432",
    "border.hairline": "#262F40",
    "text.primary": "#F3F4F6",
    "text.secondary": "#9CA3AF",
    "text.tertiary": "#6B7280"
  },
  "scaneliq.radius": { "xs": 8, "sm": 12, "md": 14, "lg": 16, "xl": 24, "pill": 999 },
  "scaneliq.spacing": { "xs": 4, "sm": 8, "md": 12, "lg": 16, "xl": 24, "xxl": 32 }
}
```
