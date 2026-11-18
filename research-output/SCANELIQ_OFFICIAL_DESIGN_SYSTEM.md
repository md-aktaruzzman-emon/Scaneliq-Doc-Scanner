# Scaneliq — Official Master Design System (Concept A: Editorial Gallery Minimal)

**Document Date:** November 18, 2026  
**Approved Visual Source of Truth:** [SCANELIQ_HOME_CONCEPT_A_PREMIUM_MINIMAL.html](file:///C:/Scaneliq/research-output/ux-prototypes/SCANELIQ_HOME_CONCEPT_A_PREMIUM_MINIMAL.html) | [PNG Preview](file:///C:/Scaneliq/research-output/ux-prototypes/SCANELIQ_HOME_CONCEPT_A_PREMIUM_MINIMAL.png)  
**Status:** **OFFICIAL APPROVED MASTER DESIGN** (Supersedes all prior prototypes and rejected themes).

---

## 1. Core Design Philosophy & Strict Guardrails

Scaneliq's visual language is **Editorial Gallery Minimal**—inspired by the content-first restraint of Adobe Scan and fine archival print studios.
- **The Document Is the Hero:** UI chrome retreats into warm alabaster paper (`#FAF9F6`) or matte carbon (`#0D0E11`) separated by `1px` architectural hairlines (`#E6E4DD` / `#23262F`).
- **Single Focal Accent:** **International Ultramarine (`#0052FF` Light / `#3B82F6` Dark)** is reserved exclusively for primary actions (`[📷 Scan]`), active scope underlines, and optical boundary locks.
- **Tactile Paper Thumbnails:** Every document thumbnail renders as a crisp physical sheet (`border-radius: 3px–4px`, `1px solid #D8D6CE`, realistic micro-typography, tables, stamps, or ID frames, and subtle paper drop shadow).
- **Strictly Prohibited Elements (Zero Drift Rule):**
  - **NO** Concept C "Active Desk" recessed wells, "Optical Lens" 4-pill top row, or dark floating glass pill dock.
  - **NO** Concept B dark navy header canopy (`#0B1D33`) or 2×4 emerald workbench matrix on Home.
  - **NO** multi-colored rainbow tool icons, decorative gradients, or heavy card boxes around every list item.

---

## 2. Exact Extracted Color Tokens (From Approved Concept A CSS)

### 2.1 Light Theme — "Gallery Alabaster" (`.theme-light`)
| CSS / Flutter Token | Exact Value | Usage in Concept A | Contrast Ratio |
|---|---|---|---|
| `--bg` (`canvas`) | `#FAF9F6` | Primary screen canvas (Warm Gallery Alabaster) | Base |
| `--surface` | `#FFFFFF` | Featured "Continue working" folio card, floating secondary FAB, sheets | Elevated paper |
| `--surface-subtle` | `#F2F0EB` | Search bar input well, monospaced metadata tags (`.meta-tag`), hover fills | Recessed well |
| `--text-1` | `#141413` | Brand wordmark, primary titles, active scope tab, brand glyph background | `18.1:1` vs `#FFFFFF` |
| `--text-2` | `#5C5B57` | Section headers (`Continue working`), subtitles, file size & date metadata | `6.6:1` vs `#FAF9F6` (AA+) |
| `--text-3` | `#8C8A84` | Inactive scope tabs, search placeholder, `.search-kbd`, overflow `⋯` icons | `3.5:1` (UI controls) |
| `--hairline` | `#E6E4DD` | `1px` structural stream dividers, card borders, bottom nav top border | Structural rule |
| `--accent` | `#0052FF` | **International Ultramarine** — `[📷 Scan]` pill, active tab `2px` underline, text links | `5.5:1` vs `#FFFFFF` (AA) |
| `--accent-soft` | `rgba(0, 82, 255, 0.08)` | Featured folio status pill background (`UNFINISHED · 3 PAGES`) | Subtle tint |
| `--nav-glass` | `rgba(250, 249, 246, 0.88)` | Frosted 3-tab bottom bar (`backdrop-filter: blur(16px)`) | Translucent bar |
| `--paper-shadow` | `0 6px 18px rgba(20,20,19,0.07), 0 1px 3px rgba(20,20,19,0.06)` | Realistic elevation under A4 `.doc-sheet` & `.paper-front` thumbnails | Tactile depth |

### 2.2 Dark Theme — "Carbon Studio" (`.theme-dark`)
| CSS / Flutter Token | Exact Value | Usage in Concept A | Contrast Ratio |
|---|---|---|---|
| `--bg` (`canvas`) | `#0D0E11` | Primary screen canvas (Deep Matte Carbon) | Base |
| `--surface` | `#15171C` | Featured folio card, floating secondary FAB, modal sheets | Elevated graphite |
| `--surface-subtle` | `#1C1F26` | Search bar input well, `.meta-tag` chips, hover states | Recessed slate |
| `--text-1` | `#F4F4F6` | Brand wordmark, document titles, active scope tab, brand glyph fill | `16.8:1` vs `#0D0E11` |
| `--text-2` | `#9CA0AB` | Section headers, subtitles, secondary metadata | `7.1:1` vs `#0D0E11` (AAA) |
| `--text-3` | `#636773` | Inactive scope tabs, placeholders, overflow `⋯` triggers | Muted pewter |
| `--hairline` | `#23262F` | `1px` structural stream dividers, card borders, bottom nav border | Crisp dark rule |
| `--accent` | `#3B82F6` | **Luminous Ultramarine** — `[📷 Scan]` pill, active underline, primary links | `5.2:1` vs `#0D0E11` |
| `--accent-soft` | `rgba(59, 130, 246, 0.14)` | Status pill fill (`UNFINISHED · 3 PAGES`) | Luminous tint |
| `--nav-glass` | `rgba(13, 14, 17, 0.88)` | Frosted 3-tab bottom bar (`backdrop-filter: blur(16px)`) | Carbon glass |
| `--paper-shadow` | `0 8px 22px rgba(0, 0, 0, 0.55)` | Crisp shadow under white A4 document sheets on carbon canvas | High-contrast depth |

### 2.3 Extended Semantic & Optical Studio Tokens (Consistent with Concept A)
| Token | Light Value | Dark Value | Purpose |
|---|---|---|---|
| `--success` / `--success-soft` | `#059669` / `rgba(5,150,105,0.10)` | `#34D399` / `rgba(52,211,153,0.14)` | Paid/Verified stamps, completed export, SHA-256 valid |
| `--warning` / `--warning-soft` | `#B45309` / `rgba(180,83,9,0.10)` | `#FBBF24` / `rgba(251,191,36,0.14)` | Math mismatch warning, temporary lockout countdown |
| `--danger` / `--danger-soft` | `#DC2626` / `rgba(220,38,38,0.10)` | `#F87171` / `rgba(248,113,113,0.14)` | Destructive delete, Trash purge, PIN failure |
| `--camera-bg` | `#090A0D` | `#090A0D` | Always-dark optical camera & crop studio canvas |
| `--camera-quad` | `#0052FF` (stroke) + `#3B82F6` (nodes) | `#3B82F6` (stroke) + `#FFFFFF` (nodes) | Live document boundary detection polygon & loupe ring |

---

## 3. Typography System (Extracted from Approved Concept A)

- **Headings & Titles (`--font-head`):** `'Instrument Sans', 'Inter', -apple-system, sans-serif`
- **Body & Bengali Copy (`--font-body`):** `'Inter', 'Noto Sans Bengali', -apple-system, sans-serif`
- **Technical Metadata & Badges (`--font-mono`):** `'JetBrains Mono', monospace`

| Role | Family | Size | Weight | Tracking | Line Height | Concept A Element |
|---|---|---|---|---|---|---|
| **Brand Wordmark** | `Instrument Sans` | `22px` | `700` | `-0.03em` | `1.1` | `.brand-word` (`Scaneliq`) |
| **Screen Title** | `Instrument Sans` | `20px` | `700` | `-0.025em` | `1.2` | Top bar title on sub-screens (`Folders`, `PDF Suite`, `Settings`) |
| **Folio Headline** | `Instrument Sans` | `15.5px` | `600` | `-0.01em` | `1.3` | `.folio-name` (`Annual Tax Return FY26`) |
| **Stream Row Title** | `Instrument Sans` | `15px` | `600` | `-0.01em` | `1.3` | `.row-title` (`Commercial Lease Agreement`, `বাংলা জমির দলিল`) |
| **Scope Tab Label** | `Instrument Sans` | `14px` | `600` | `0` | `1.2` | `.scope-tab` (`Recent`, `Starred`, `Folders`) |
| **Primary FAB Label** | `Instrument Sans` | `14.5px` | `600` | `0` | `1.0` | `.fab-primary` (`Scan`) |
| **Search Input** | `Inter` | `13.5px` | `400` | `0` | `1.4` | `.search-bar input` |
| **Section Eyebrow** | `Instrument Sans` | `13px` | `600` | `0` | `1.3` | `.section-title` (`Continue working`, `November 2026`) |
| **Section Link** | `Inter` | `12.5px` | `500` | `0` | `1.3` | `.section-action` (`Resume draft`, `All files`) |
| **Row Metadata** | `Inter` (`tabular-nums`) | `12px` | `400` | `0` | `1.35` | `.row-meta` (`2.4 MB · Today, 14:20`) |
| **Bottom Nav Label** | `Inter` | `11px` | `500` / `600` | `0` | `1.2` | `.nav-tab` (`Scans`, `Folders`, `PDF Suite`) |
| **Monospace Pill / Badge** | `JetBrains Mono` | `10px–11px` | `500` | `0.02em` | `1.2` | `.folio-pill`, `.meta-tag` (`PDF · 12P`, `OCR · BN`, `2-IN-1`) |

---

## 4. Layout Geometry, Safe Areas & Spacing System

- **Reference Mobile Viewport:** **`393 × 852` logical pixels**
  - **Top Safe Area / Status Bar:** `47px` height (`14px` top inset, `26px` horizontal padding, `108×28px` dynamic island pill).
  - **Editorial Header:** `12px 24px 14px` padding (`26×26px` brand glyph with `7px` radius + `22px` wordmark; right `40×40px` circular icon buttons).
  - **Search & Scope Zone:** `0 24px 16px` padding; `42px` search bar (`10px` radius); `20px` gap between scope tabs with `1px solid var(--hairline)` bottom rule and `2px solid var(--accent)` active underline.
  - **Main Content Gutter:** **`24px` horizontal padding** (`padding: 4px 24px 110px`).
  - **Stream Row Rhythm:** `15px` horizontal gap between `50×66px` `.doc-sheet` thumbnail and text column; `12px–15px` vertical padding with `1px solid var(--hairline)` bottom border.
  - **Floating Capture Cluster:** `position: absolute; right: 20px; bottom: 92px; gap: 8px` — `[🖼 Import]` (`46×46px` circle) + `[📷 Scan]` (`50px` height, `0 20px` padding, `999px` pill radius, `0 12px 28px rgba(0, 82, 255, 0.32)` shadow).
  - **3-Tab Bottom Navigation Bar:** `82px` total height (`8px 32px 26px` padding, including `134×5px` home indicator at `bottom: 8px`), frosted `var(--nav-glass)` with `1px` top `--hairline`.

---

## 5. Signature Visual Motifs Across All Screens

1. **Hairline Architecture Over Boxed Cards:** Lists, settings, folders, PDF tools, and extracted OCR results use full-width hairline rows (`border-bottom: 1px solid var(--hairline)`) inside `24px` editorial margins. Rounded bordered containers (`14px` radius, `1px solid var(--hairline)`) are reserved strictly for **featured hero folios** (e.g., "Continue working" draft card, active receipt summary card, or active backup vault status card).
2. **Miniature Paper Sheets (`.doc-sheet` / `.paper-front`):** Document thumbnails always render on crisp `#FFFFFF` paper (`border-radius: 3px–4px`, `1px solid #D8D6CE`, `var(--paper-shadow)`) even in Dark Theme—so real paper documents stand out unmistakably against the Carbon Studio (`#0D0E11`) canvas.
3. **Monospaced Technical Signifiers (`.meta-tag` / `.search-kbd`):** Page counts, OCR script codes, encryption badges, and file formats are set in `JetBrains Mono 10px` inside `3px–4px` radius `--surface-subtle` badges (`PDF · 12P`, `OCR · BN`, `AES-256`, `200 DPI`).
