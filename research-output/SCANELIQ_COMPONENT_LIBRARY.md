# Scaneliq — Official Component Library Specification (Concept A: Editorial Gallery Minimal)

**Document Date:** November 18, 2026  
**Design System Source:** [SCANELIQ_OFFICIAL_DESIGN_SYSTEM.md](file:///C:/Scaneliq/research-output/SCANELIQ_OFFICIAL_DESIGN_SYSTEM.md)  
**Rule:** Every component in this library is derived directly from the approved Concept A HTML/CSS and replaces legacy Material 3 rounded-card templates.

---

## 1. Navigation & Header Components

### 1.1 `EditorialHeader` (`.header`)
- **Geometry:** `padding: 12px 24px 14px`, full width (`393px`).
- **Root Variant:** Left `.brand-lockup` (`26×26px` rounded-7px `--text-1` box containing a `15×15px` `--bg` viewfinder SVG + `Instrument Sans 22px w700` `-0.03em` wordmark). Right `.header-actions` (`40×40px` circular `.icon-hit` targets with `6px` gap).
- **Sub-Screen Variant:** Left `40×40px` `←` back hit target + `Instrument Sans 20px w700` screen title (`-0.025em`) + right contextual action pill or icon.

### 1.2 `SearchAndScopeStrip` (`.search-zone`)
- **Search Bar (`.search-bar`):** `height: 42px`, `border-radius: 10px`, `background: var(--surface-subtle)`, `padding: 0 14px`. Left `16px` magnifying glass (`--text-2`), `Inter 13.5px` input, right `.search-kbd` monospaced tag (`JetBrains Mono 10px`, `padding: 2px 6px`, `border: 1px solid var(--hairline)`, `border-radius: 4px`).
- **Editorial Scope Tabs (`.scope-tabs`):** Full-width flex row with `border-bottom: 1px solid var(--hairline)` and `padding-bottom: 10px`. Each `.scope-tab` uses `Instrument Sans 14px w600` (`--text-3` inactive, `--text-1` active with `border-bottom: 2px solid var(--accent)` and `.scope-count` in `JetBrains Mono 11px`).

### 1.3 `FrostedBottomNav` (`.bottom-nav`)
- **Geometry:** `height: 82px` (`padding: 8px 32px 26px`), fixed bottom, `background: var(--nav-glass)`, `backdrop-filter: blur(16px)`, `border-top: 1px solid var(--hairline)`.
- **3 Destinations:** **`Scans`** | **`Folders`** | **`PDF Suite`** (`20×20px` stroke icon + `Inter 11px` label; `--text-3` `w500` inactive, `--text-1` `w600` active). Includes `134×5px` `.home-indicator` pill at `bottom: 8px`.

### 1.4 `ThumbZoneCaptureCluster` (`.fab-cluster`)
- **Position:** `position: absolute; right: 20px; bottom: 92px; gap: 8px; z-index: 20`.
- **Secondary Import FAB (`.fab-secondary`):** `46×46px` circle, `background: var(--surface)`, `border: 1px solid var(--hairline)`, `box-shadow: 0 10px 24px rgba(0,0,0,0.14)`, `19px` gallery icon (`--text-1`).
- **Primary Scan Pill (`.fab-primary`):** `height: 50px`, `padding: 0 20px`, `border-radius: 999px`, `background: var(--accent)` (`#0052FF` / `#3B82F6`), `#FFFFFF` camera icon (`18px`) + `Instrument Sans 14.5px w600` `"Scan"`, `box-shadow: 0 12px 28px rgba(0,82,255,0.32)`.

---

## 2. Document & Paper Components

### 2.1 `FeaturedFolioCard` (`.folio-card`)
- **Purpose:** Used at most once per screen for the active draft (`Continue working`) or featured summary.
- **Container:** `padding: 14px`, `border-radius: 14px`, `background: var(--surface)`, `border: 1px solid var(--hairline)`, `gap: 16px`.
- **3D Paper Stack (`.folio-paper-stack`):** `68×88px` stage containing `.paper-back` (`rotate(4deg) translate(3px, 1px)`) behind `.paper-front` (`#FFFFFF`, `border-radius: 4px`, `border: 1px solid #D8D6CE`, `box-shadow: var(--paper-shadow)`).
- **Typography & Actions:** `.folio-pill` (`JetBrains Mono 10px`, `color: var(--accent)`, `background: var(--accent-soft)`, `border-radius: 4px`), `.folio-name` (`Instrument Sans 15.5px w600`), `.folio-sub` (`Inter 12px`, `--text-2`), and inline text links (`Inter 12px w600`).

### 2.2 `HairlineStreamRow` (`.stream-row`) & `MiniatureDocSheet` (`.doc-sheet`)
- **Row Geometry:** `padding: 12px 0`, `gap: 15px`, `border-bottom: 1px solid var(--hairline)` — **never wrapped in a rounded card box**.
- **Miniature A4 Sheet (`.doc-sheet`):** `50×66px`, `background: #FFFFFF` (in both Light and Dark themes!), `border-radius: 3px`, `border: 1px solid #D8D6CE`, `box-shadow: var(--paper-shadow)`, `padding: 5px`. Renders realistic miniature document structure (header line, paragraph bars, miniature data table, red seal `.sheet-seal`, signature line `.mini-sig`, or dual ID boxes `.sheet-id-box`).
- **Content Column:** `.row-title` (`Instrument Sans 15px w600`, single-line ellipsis) above `.row-meta` (`Inter 12px`, `--text-2`, `tabular-nums`) starting with `.meta-tag` (`JetBrains Mono 10px`, `padding: 1px 5px`, `border-radius: 3px`, `background: var(--surface-subtle)`).
- **Trailing Trigger (`.row-more`):** `36×36px` visual circle with `48×48dp` invisible hit padding around horizontal 3-dot icon (`--text-3`).

---

## 3. Scanner, Editor & Studio Components

### 3.1 `OpticalViewfinderQuad`
- **Polygon:** `2px solid var(--accent)` (`#0052FF` / `#3B82F6`), `fill: rgba(59, 130, 246, 0.10)`, `10px` circular corner anchors (`#FFFFFF` center, `2px` Ultramarine ring).
- **Magnifying Loupe (`CropLoupe`):** `88×88px` circle offset `64px` above active touch coordinates, `2px solid var(--accent)` border, `1.8×` magnified bitmap slice, `1px` center crosshair.

### 3.2 `LiveFilterThumbnailStrip`
- **Item Geometry:** `56×74px` miniature `#FFFFFF` paper sheet previewing the actual page bitmap under each filter (`Original`, `Magic Color`, `Crisp B&W`, `Adaptive`, `Grayscale`, `Whiteboard`, `Ink Boost`), `4px` radius, `2px solid var(--accent)` active border, `Inter 11px w600` caption below.

### 3.3 `ViewerActionDock`
- **Geometry:** `height: 68px`, frosted `var(--nav-glass)`, `border-top: 1px solid var(--hairline)`, 5 equal columns (`Edit`, `Pages`, `OCR`, `Sign`, `Tools`) with `19px` monochrome stroke icon + `10.5px` label.

---

## 4. Sheets, Tables, Inputs & State Components

### 4.1 `HairlineSpecTable` & `HairlineSettingsRow`
- **Settings / Tool Row:** Full-width hairline row (`padding: 14px 0`, `border-bottom: 1px solid var(--hairline)`), left `20px` monochrome `--text-1` stroke icon (no colored background circle!), `Instrument Sans 15px w600` title + `Inter 12px` `--text-2` subtitle, right value badge (`JetBrains Mono 11px`) or minimal switch (`38×22px`, `--accent` when ON) or chevron.

### 4.2 `EditorialBottomSheet`
- **Surface:** `background: var(--bg)` (or `var(--surface)` in dark mode), `border-top-left-radius: 22px`, `border-top-right-radius: 22px`, `border-top: 1px solid var(--hairline)`, `padding: 12px 24px 32px`, top `36×4px` `--hairline` grab bar.

### 4.3 `EditorialPillButton`
- **Primary:** `height: 46px`, `border-radius: 999px` (or `10px` rectangular variant in forms), `background: var(--accent)`, `color: #FFFFFF`, `Instrument Sans 14px w600`.
- **Secondary Hairline:** `height: 46px`, `border-radius: 999px` (or `10px`), `background: var(--surface)`, `border: 1px solid var(--hairline)`, `color: var(--text-1)`.
