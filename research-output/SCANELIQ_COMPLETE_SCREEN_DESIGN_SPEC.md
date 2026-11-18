# Scaneliq — Complete Application Screen Design Specification (Concept A: Editorial Gallery Minimal)

**Document Date:** November 18, 2026  
**Approved Master Foundation:** **Concept A — Editorial Gallery Minimal** ([SCANELIQ_HOME_CONCEPT_A_PREMIUM_MINIMAL.html](file:///C:/Scaneliq/research-output/ux-prototypes/SCANELIQ_HOME_CONCEPT_A_PREMIUM_MINIMAL.html))  
**Viewport Standard:** `393 × 852` Logical Pixels (`47px` top safe area, `24px` editorial horizontal margins, `82px` frosted 3-tab bottom bar)  
**Themes:** Light (`Gallery Alabaster #FAF9F6`) & Dark (`Carbon Studio #0D0E11`) with `International Ultramarine (#0052FF / #3B82F6)`.

---

## Universal Concept A Screen Anatomy

Every screen in Scaneliq adheres to the same 5 structural rules established by the approved Concept A Home Dashboard:
1. **Header (`padding: 12px 24px 14px`):** Left brand lockup (`26×26px` monochrome glyph + `Instrument Sans 22px w700` title) or `← Back` + `Instrument Sans 20px w700` page title; right `40×40px` circular icon hit targets (`--surface-subtle` hover/press).
2. **Surface Hierarchy:** Full-bleed `--bg` canvas (`#FAF9F6` / `#0D0E11`). Rows are separated by `1px solid var(--hairline)` (`#E6E4DD` / `#23262F`) without surrounding card boxes. Only featured hero objects (like the active draft folio or active document stage) sit on an elevated `--surface` container (`14px` radius, `1px solid var(--hairline)`).
3. **Document Previews (`.doc-sheet`):** Always rendered on true `#FFFFFF` paper (`3px–4px` radius, `1px solid #D8D6CE`, `var(--paper-shadow)`) with realistic micro-typography, tables, seals, and signatures.
4. **Technical Signifiers:** Format, page count, script, and encryption badges use `JetBrains Mono 10px` inside `--surface-subtle` (`3px–4px` radius) or `--accent-soft` pills.
5. **Empty / Loading / Error / Success States:**
   - *Empty:* Hairline-framed miniature paper sheet outline (`56×74px`), `Instrument Sans 17px w600` title, `Inter 13px` `--text-2` description, and one `#0052FF` pill CTA.
   - *Loading:* Editorial hairline skeleton rows pulsing between `--surface-subtle` and `--hairline`, or top `2px` Ultramarine progress hairline.
   - *Error:* `--danger-soft` inline banner (`1px solid` `--danger` at 25% opacity) with calm explanation and `Retry` link (zero raw `/data/user/0/...` paths).
   - *Success:* Floating bottom-above-nav pill toast (`--text-1` surface, `--bg` text, `#059669` check dot or Ultramarine action link).

---

## GROUP A — MAIN APPLICATION (Screens 1–6)

### 1. Home Dashboard *(Approved Master Screen — Preserved 1:1)*
- **Header:** Monochrome `26×26px` viewfinder glyph + `Scaneliq` (`22px w700`) | Right: Multi-Select (`☑`) & Settings (`⚙`).
- **Search & Scope Strip:** `42px` `--surface-subtle` search bar (`"Search titles or recognized text…"` + `OCR` mono badge) + underlined scope tabs (`Recent 42`, `Starred 7`, `Folders 5`) with `2px solid var(--accent)` active underline + sort trigger.
- **Featured Folio (`Continue working`):** `--surface` card (`14px` radius, `1px solid var(--hairline)`) featuring a 3D rotated `.folio-paper-stack` (`68×88px`), `UNFINISHED · 3 PAGES` Ultramarine mono pill, `Annual Tax Return FY26`, `"Edited 14 mins ago · Magic Color"`, and inline `Add pages` + `Save PDF` links.
- **Editorial Document Stream:** Grouped by month (`November 2026` + `All files` link); borderless `.stream-row` items (`50×66px` `.doc-sheet` thumbnail + `15px` title + `.meta-tag` mono badge + file size + timestamp + `⋯` menu).
- **Primary Actions & Navigation:** Bottom-right floating cluster (`46×46px` circular Gallery Import + `50px` pill `[📷 Scan]` in `#0052FF`) above the frosted 3-tab bottom bar (`Scans`, `Folders`, `PDF Suite`).

### 2. Splash Screen *(Planned Cold-Start Transition)*
- **Layout:** Centered `44×44px` monochrome `--text-1` rounded-square viewfinder glyph + `Scaneliq` (`Instrument Sans 26px w700`, `-0.03em`) on pure `--bg` (`#FAF9F6` Light / `#0D0E11` Dark). Bottom safe-area caption: `LOCAL-FIRST DOCUMENT VAULT` in `JetBrains Mono 10px` (`--text-3`). Transitions in `<= 400ms` with zero white flash.

### 3. Onboarding *(Planned 3-Slide Editorial Walkthrough)*
- **Header:** Minimal `Scaneliq` lockup left | `Skip` (`Inter 13px w500`, `--text-2`) right.
- **Main Stage:** Large realistic layered A4 paper specimen centered on `--bg` demonstrating:
  - *Slide 1:* **Optical Precision** — Skewed photo snapping into a crisp A4 sheet with Ultramarine `#0052FF` corner nodes.
  - *Slide 2:* **Searchable OCR & বাংলা** — Magnified text highlight showing English & `বাংলা` recognition + searchable PDF layer.
  - *Slide 3:* **100% On-Device Vault** — Zero mandatory accounts, zero watermarks, AES-256 local encryption.
- **Footer:** 3 progress hairlines (`24px × 2px`, active in `--accent`) + full-width `48px` `#0052FF` pill button (`Continue` / `Enable Camera & Start`).

### 4. Main Navigation *(Concept A 3-Tab Frosted Bar + Floating Capture Cluster)*
- **Destinations:**
  1. **`Scans`** (Document icon) — Approved Home Dashboard with `Recent`, `Starred`, `Folders` scopes.
  2. **`Folders`** (Folder icon) — Dedicated Hierarchical Folder Architecture & Vault Browser.
  3. **`PDF Suite`** (4-square grid icon) — Editorial PDF, OCR, AI & Specialized Scanner Workbench.
- **Floating Capture Cluster:** Visible on `Scans` and `Folders` tabs (`right: 20px; bottom: 92px`) for instant 1-tap right-thumb scanning or gallery import.

### 5. Global Search
- **Header:** Active focused `42px` search input (`Auto-focus`, clear `✕` button) + `Cancel` text button.
- **Scope Filter Hairline Bar:** Underlined scopes: `All Results` | `OCR Text` | `File Titles` | `Folders & Tags`.
- **Main Content:**
  - *Before Typing:* `Recent Searches` hairline list (`Tax Return`, `খতিয়ান ৪১২`, `Lease`, `Invoice #884`) + `Filter by Tag` mono pills (`PDF`, `OCR · BN`, `RECEIPT`, `2-IN-1`, `LOCKED`).
  - *Live Results:* Stream rows where matches inside OCR text display an indented 2-line excerpt quote box (`border-left: 2px solid var(--accent)`, `--font-mono 11px`) highlighting the matched word in Ultramarine and citing the exact page (`PAGE 04`).

### 6. In-App Activity & Vault Banners *(Replaces Unsupported Push Notifications)*
- **Status:** Since Scaneliq is 100% offline/local-first without remote push servers, system notifications are represented as **non-blocking Editorial Vault Banners** sliding below the top header (`10px` radius, `--surface`, `1px solid var(--hairline)`, Ultramarine or Emerald status dot, e.g., `"PDF compiled · 12 pages indexed for OCR"` with `Open` link).

---

## GROUP B — SCANNER EXPERIENCE (Screens 7–18)

### 7. Scanner Camera *(Special High-Craft Optical Studio)*
- **Surface:** Always-dark `--camera-bg` (`#090A0D`) so paper edges achieve maximum optical contrast.
- **Top Control Bar (`52px`, translucent `rgba(13,14,17,0.75)`):**
  - Left: `✕ Close` (`40×40px`).
  - Center: Interactive **`Auto · Manual`** capsule toggle (`JetBrains Mono 11px`, Ultramarine `#3B82F6` active dot when `Auto` is armed) + `Flash (Off/Torch)` + `Grid (3×3)`.
  - Right: `⚙ Camera Settings` quick popover (Resolution, Shutter Sound, Auto-Deskew).
- **Viewfinder Canvas (`flex: 1`):** Edge-to-edge camera feed (`520px` height) with subtle rule-of-thirds hairlines when Grid is active.
- **Document Mode Strip (Above Shutter):** Clean horizontal typographic selector (`Instrument Sans 13px w600`): `Batch` · **`Document`** (active `#3B82F6` underline) · `ID Card 2-in-1` · `Book` · `Whiteboard` · `Receipt` · `QR`.
- **Bottom Shutter Dock (`116px` height):**
  - **Left (`52×66px`):** **Captured Page Stack Thumbnail** (real miniature paper preview of last captured page + `#0052FF` mono badge `03` top-right) — or `Gallery Import` (`[🖼]`) when `0` pages captured.
  - **Center (`72×72px`):** **Precision Shutter Button** (`2px` outer `#FFFFFF` ring + `58px` solid white inner disc; morphs into an animated `#3B82F6` progress ring during auto-capture lock).
  - **Right:** `Review (3) →` pill button in `#0052FF` once `>= 1` page is captured.

### 8. Automatic Document Detection
- **Visual Overlay on Viewfinder:** Real-time `2px` International Ultramarine (`#3B82F6`) quadrilateral polygon tracking the paper edges with `rgba(59, 130, 246, 0.10)` translucent fill and `10px` white-centered Ultramarine corner anchor circles.
- **Feedback Pill:** Floating centered pill at bottom of viewfinder: `"Hold steady · Capturing page 4"` in `JetBrains Mono 11px` with subtle 0→100% fill bar.

### 9. Manual Capture
- **Visual State:** Toggling top pill to `Manual` removes the auto-countdown ring, displays a subtle center **2-axis spirit level crosshair** (`1px` hairlines turning `#3B82F6` when phone is parallel to desk), and fires immediately on shutter tap.
- **Specialized Mode Overlays:**
  - *ID Card 2-in-1:* Crisp `1.5px` dashed white `ID-1` card frame (`85.6 × 54 mm` ratio) with top mono badge `STEP 1 OF 2 · FRONT SIDE`.
  - *Book Mode:* Center vertical spine hairline with `PAGE L` and `PAGE R` mono markers.

### 10. Gallery Import Staging Sheet
- **Trigger:** Tapping `[🖼]` floating button on Home or inside Camera.
- **Layout (Concept A Bottom Sheet):** Header `"Import from Device"` + file picker trigger (`JPG, PNG, WebP, PDF`). Shows selected thumbnails in a horizontal paper strip with toggles: `Auto-crop document boundaries` (ON) and `Apply Magic Color filter` (ON) + primary `#0052FF` CTA `"Import 3 Pages to Editor"`.

### 11. Scan Preview (Editorial Review Stage)
- **Header:** `← Retake / Add` | Inline tappable Document Title (`Annual_Tax_Return_FY26` + edit pencil icon) | Right: `Save PDF` primary `#0052FF` pill (`36px` height).
- **Main Document Stage:** Large centered A4 paper preview (`270×370px`) resting on Gallery Alabaster / Carbon canvas with realistic paper shadow, page indicator pill (`PAGE 02 OF 04` in `--font-mono`), and floating corner `Hold to Compare Original` button.
- **Page Thumbnail Ribbon:** Horizontal strip of `44×58px` miniature pages (`01`, `02`, `03`, `04` + `+ Add` dashed sheet) supporting tap-to-switch and drag-to-reorder.
- **Bottom Editorial Tool Bar (`64px`, hairline top border):** 5 clean monochrome icon+label actions: **`Crop`**, **`Filters`**, **`Enhance`**, **`Rotate 90°`**, **`Organize`**.

### 12. Crop & Perspective Correction
- **Canvas:** Dark `#0D0E11` high-contrast framing around the full uncropped source photo.
- **Interactive Quad & Magnifying Loupe:** `2px` `#3B82F6` quad lines connecting 4 draggable corner handles (`24px` visible ring, `48×48px` touch zone) + 4 mid-edge handles. Dragging any corner displays an offset **`88×88px` circular 1.8× Magnifying Loupe** (`2px solid #3B82F6` border, precision crosshair) above the thumb.
- **Bottom Bar:** `Auto Detect` | `Full Image` | `Rotate 90°` | Primary `#0052FF` `Apply Crop`.

### 13. Image Enhancement (Lighting, Contrast & Cleanup)
- **Stage:** Live downsampled A4 preview + top-right `Original | Edited` split-wipe toggle.
- **Controls Panel (Hairline-divided bottom dock):**
  - Sub-mode switch: `Lighting & Contrast` vs `Spot Eraser & Redact`.
  - *Lighting:* Precision thin-track sliders (`--hairline` track, `#0052FF` fill, `18px` thumb) for `Brightness (-50 to +50)` and `Contrast (0.5× to 2.0×)`, plus a single hairline row toggle: `Flatten Paper Shadows`.
  - *Eraser & Redact:* Segmented pill (`Erase Finger/Hole` | `Blackout Redact` | `Mosaic Pixelate`) + brush size slider + `Undo`.

### 14. Filter Selection (Live Miniature Paper Strip)
- **Unifies Legacy `Filters` + `Binarize` Tabs:** Presents **7 live miniature A4 thumbnails** (`56×74px` each) rendered from the user's actual page:
  1. `Original` (Raw photo)
  2. `Magic Color` (Signature shadow-free white paper + vivid ink — Default)
  3. `Crisp B&W` (Otsu high-contrast monochrome)
  4. `Adaptive Text` (Sauvola uneven-lighting text recovery)
  5. `Grayscale` (256-level neutral tone)
  6. `Whiteboard` (Glare elimination)
  7. `Ink Boost` (High saturation for stamps/signatures)
- **Batch Toggle:** Hairline switch at bottom: `Apply Magic Color to all 4 pages` (ON).

### 15. Multi-Page Organizer & 16. Page Reordering
- **Header:** `← Back to Preview` | `Organize 4 Pages` | `Select` / `Done`.
- **Grid Canvas:** 2-column A4 paper grid (`156×210px` cards) on `--bg` with `16px` gap. Each sheet shows a top-left `JetBrains Mono` index badge (`01`, `02`, `03`, `04`), subtle rotation degree pill if rotated, and bottom-right quick `↻` rotate & `🗑` delete icons.
- **Page Reordering (`Screen 16`):** Dragging any sheet elevates it (`scale(1.03)`, deeper paper shadow) and draws a `2px solid #0052FF` vertical drop-slot indicator between target pages. Final tile in grid is a hairline-dashed `+ Add Page (Camera / Gallery)` sheet.

### 17. Document Naming (Smart Filename Sheet)
- **Layout (Bottom Sheet):**
  - Title input field with clear `✕` button (`Annual_Tax_Return_FY26`).
  - **Smart Token Bar (`smart_filename_service.dart`):** Tap-to-insert mono pills: `+ [Date: 2026-11-18]`, `+ [Category]`, `+ [Time]`, `+ [Counter: 001]`.
  - **Quick Organization:** Inline `Folder` selector row (`📁 Tax & Finance ▾`) and `Tags` multi-select pills (`TAX`, `URGENT`, `VERIFIED`).

### 18. Document Saving (Compilation & Vault Commit)
- **Visual State:** Clean bottom sheet showing live step checklist:
  1. `✓ Applying Magic Color & perspective warp (4/4 pages)`
  2. `✓ Extracting on-device OCR text layer`
  3. `● Compiling A4 PDF & verifying %PDF- header…`
- Automatically transitions into **Screen 19 (PDF Viewer)** with a bottom toast: `"Saved to Vault · 4 pages searchable"`.

---

## GROUP C — PDF EXPERIENCE (Screens 19–28)

### 19. PDF Viewer
- **Header (`56px`, `--bg` with bottom `--hairline`):** `← Back` | Document Title (`Commercial Lease Agreement`) + `PDF · 12P` mono subtitle | Right: `🔍 Search in PDF`, `🔖 Bookmark`, `↑ Share`.
- **Reading Stage:** Continuous vertical A4 paper stream on `--surface-subtle` (`#F2F0EB` Light / `#090A0D` Dark) so white pages have crisp boundary contrast. Floating bottom-right monospaced pill: `01 / 12 · 100%` (tap to open Jump-to-Page / Bookmarks drawer; includes `48×48px` accessible `-` / `+` zoom buttons).
- **Concept A 5-Action Bottom Dock (`68px`, frosted `--nav-glass`):**
  - **`Edit Pages`** | **`Organize`** | **`OCR Text`** | **`Sign & Stamp`** | **`PDF Tools ⋯`**

### 20. PDF Editor (Unified In-Place Mode)
- Triggered from Viewer's `Edit Pages` or `Organize` dock buttons: switches the Viewer into an interactive page-workbench where the user can tap any page to open **Crop/Filter Editor (Screens 12–14)**, insert new scanned pages or external PDFs, rotate/delete pages, or edit PDF metadata (`Title`, `Author`) and re-save atomically.

### 21. PDF Merge
- **Entry:** `PDF Suite` tab → `Merge PDFs` (or Library Multi-Select → `Merge`).
- **Layout:**
  - Step 1: Select 2+ documents from Scaneliq Vault list (or `+ Browse Device PDF`).
  - Step 2: Reorderable hairline list of selected PDFs showing miniature page-1 `.doc-sheet`, filename, and page count (`12P + 6P = 18 Pages Total · ~4.2 MB`).
  - Footer: Output filename field + primary `#0052FF` pill `Merge 2 PDFs (18 Pages)`.

### 22. PDF Split & Extract
- **Entry:** `PDF Suite` → `Split & Extract`.
- **Visual Thumbnail Picker (Replaces Raw Text Dialog):** Displays the source PDF's pages as a 3-column selectable miniature paper grid (`01`..`12`). Users tap pages visually (selected sheets get a `2px solid #0052FF` border + check badge) OR type custom range chips (`1-3`, `5`, `8-12`) with mode switch: `Extract into 1 PDF` vs `Split into Separate 1-Page PDFs`.

### 23. PDF Compression
- **Entry:** `PDF Suite` → `Compress PDF` or Viewer → `PDF Tools`.
- **Layout:** Displays current file size (`2.40 MB`) above 3 hairline radio rows:
  - **`High Quality (300 DPI · ~85% JPEG)`** — Est. `1.75 MB (-27%)`
  - **`Balanced Archive (200 DPI · ~65% JPEG)`** *(Recommended)* — Est. `980 KB (-59%)`
  - **`Maximum Compression (150 DPI · ~45% JPEG)`** — Est. `520 KB (-78%)`
- Post-compression state displays measured before/after bar and `Save Compressed Copy`.

### 24. PDF Conversion (Supported Formats Only)
- **Entry:** `PDF Suite` → `Convert Format`.
- **Honest Capability Matrix:**
  - `PDF → High-Res JPEG Pages (.jpg)` (**Implemented**)
  - `Multi-Page Scan → Long Vertical Image Stitch (.jpg)` (**Implemented** via `stitchImageFilesVertically`)
  - `PDF → Extracted Plain Text (.txt)` (**Implemented** via `OcrService`)
  - *Note:* Word (`.docx`) and Excel (`.xlsx`) are explicitly omitted or marked `Not Implemented` in accordance with strict truthfulness rules.

### 25. PDF Export Sheet
- **Layout:** Modal bottom sheet from Viewer/Preview configuring:
  - Format: `Searchable PDF` | `Flattened Image PDF` | `Individual JPEGs`.
  - Resolution: `Compact (150 DPI)` | `Standard (200 DPI)` | `Archival (300 DPI)`.
  - Security: `Apply AES-256 Password` toggle + `Add Watermark` toggle.
  - Dual CTAs: `Save to Device Storage` (secondary hairline button) + `Share Document` (primary `#0052FF` pill).

### 26. PDF Annotation & Watermarking
- **Entry:** Viewer → `Sign & Stamp` or `PDF Suite` → `Watermark & Stamp`.
- **Layout:** Live A4 page preview with floating tool switch:
  - **`Watermark`:** Presets (`CONFIDENTIAL`, `DRAFT`, `COPY`, `ORIGINAL`) or custom text, opacity slider (`10%–80%`), diagonal `-45°` vs horizontal toggle, page filter (`All`, `First Only`, `Odd/Even`).
  - **`Stamps & Callouts`:** Editorial rectangular vector stamps (`APPROVED`, `PAID`, `VOID` with date) and yellow/ultramarine text highlighters.

### 27. Digital Signature Studio
- **Entry:** Viewer → `Sign & Stamp` → `Signature`.
- **Layout:**
  - **Draw Pad:** Crisp white signature card (`180px` height) with baseline rule + 3 authentic fountain-pen ink swatches (`Carbon Black #141413`, `Archive Blue #0052FF`, `Legal Crimson #B91C1C`) + stroke thickness toggle.
  - **Placement Stage:** Places transparent vector/PNG signature box onto the target PDF page with corner resize handle and `Flatten & Save PDF` CTA.

### 28. PDF Protection & Redaction
- **Entry:** `PDF Suite` → `Protect & Redact` or Viewer → `PDF Tools`.
- **3 Clean Sub-Modes:**
  1. **`Lock with AES-256`:** User password + Owner password fields, show/hide eye icon, strength indicator, and `Encrypt PDF`.
  2. **`Remove Password`:** Verify current password → export unlocked copy.
  3. **`Sanitize & Redact` (`RISK-12` Compliant):** Let user draw blackout/mosaic rectangles over sensitive regions with an explicit mode selector:
     - *`Permanent Raster Redaction (Recommended)`* — Zeros underlying image pixels (`0x000000`) and scrubs metadata.
     - *`Vector Overlay Masking`* — Draws visual blackout box (includes clear warning that underlying vector text streams require raster flattening for forensic destruction).

---

## GROUP D — DOCUMENT MANAGEMENT (Screens 29–38)

### 29. Document Library (`Scans` & `Folders` Views)
- **Visual Structure:** Preserves Concept A's hairline-divided `.doc-stream` (`50×66px` `.doc-sheet` thumbnail + `15px` title + `.meta-tag` mono badge + size/date + `⋯` menu). Includes a top-right view-mode toggle switching smoothly between **Editorial Hairline List** and **2-Column A4 Paper Gallery** (`162×216px` paper sheets with bottom title/meta caption).

### 30. Folder Management (`Folders` Tab — Tab 2)
- **Header:** `Folders` (`Instrument Sans 22px w700`) | Right: `+ New Folder` (`40×40px`) & `Sort`.
- **Breadcrumb Bar (When inside a folder):** Monospaced trail `VAULT / TAX & FINANCE / 2026` (`1px` bottom `--hairline`).
- **Folder Rows (Hairline Architecture, Not Grid Boxes):** Each folder row (`padding: 14px 0`, `border-bottom: 1px solid var(--hairline)`) displays a crisp minimal folder outline icon (`22px`), Folder Name (`15px w600`), subfolder & file count badge (`14 FILES · 2 SUBFOLDERS` in `--font-mono`), and `⋯` menu (`Rename`, `New Subfolder`, `Move`, `Delete Folder` with safe `Move files to Root` vs `Move to Trash` choice).

### 31. Document Details (Specification Sheet)
- **Layout (Editorial Bottom Sheet):** Miniature A4 preview + editable title + hairline key-value specification table:
  - `Format`: `PDF 1.7 (Searchable OCR Layer)`
  - `Pages & Size`: `12 Pages · ISO A4 (210 × 297 mm) · 2.41 MB`
  - `Location`: `Vault / Legal & ID`
  - `Security`: `Unencrypted` (or `AES-256 Locked`)
  - `Integrity (SHA-256)`: `918aae7b…530b21a5` (`--font-mono 11px`)
  - `Modified`: `Nov 18, 2026 · 14:20`

### 32. Document Quick Preview (Action Drawer)
- Triggered by tapping `⋯` on any document row in `Scans` or `Folders`:
- **Layout:** Bottom sheet showing the document's `.doc-sheet` thumbnail, title, and page summary at top, followed by hairline action rows: `Open in PDF Viewer`, `Extract Text (OCR)`, `Rename & Smart Tags`, `Move to Folder`, `Star / Unstar`, `Protect with AES-256`, `Share Document`, and `Move to Trash` (`--danger` text).

### 33. Multi-Selection & 34. Batch Actions
- **Multi-Selection (`Screen 33`):** Tapping `[☑]` in the top header or long-pressing any row replaces the top header with: `✕ Cancel` | **`3 Selected`** (`Instrument Sans 18px w700`) | `Select All (42)`. Each `.stream-row` shifts right `12px` to reveal a `22×22px` circular checkbox (filled `#0052FF` with white check when selected).
- **Batch Action Dock (`Screen 34`):** Replaces the 3-tab bottom bar and hides the floating `[Scan]` cluster with a frosted `82px` action dock: **`Move`** | **`Tag`** | **`Merge PDF`** | **`Share`** | **`Trash`** (`--danger`).

### 35. Document Search Results
- Embedded seamlessly inside **Screen 5 (Global Search)** and inline `Scans` filtering: displays matching count (`4 RESULTS FOR "LEASE"` in `--font-mono`), separating title matches from full-text OCR snippet matches with highlighted query terms.

### 36. Document Sharing
- **Layout (Share Pre-Flight Sheet):** Allows 1-tap format choice (`PDF Document · 2.4 MB`, `Individual JPEG Images (.zip)`, or `Extracted OCR Text (.txt)`), optional `Flatten annotations / remove metadata` toggle, and primary `#0052FF` `Share via Android…` button.

### 37. Starred Documents & 38. Recent Documents
- Operated directly via the **Approved Concept A Home Scope Tabs** (`Recent 42` | `Starred 7` | `Folders 5`). Switching to `Starred 7` filters the editorial stream in-place to starred items with a subtle gold/ultramarine star indicator next to the `.meta-tag`.

---

## GROUP E — OCR AND AI (Screens 39–45)

### 39. OCR Processing
- **Layout:** Centered A4 page preview on `--bg` with a horizontal `#0052FF` optical laser hairline sweeping top-to-bottom (`animation: 1.6s ease-in-out`). Bottom status block: `RECOGNIZING TEXT · PAGE 1 OF 6` (`--font-mono 11px`), active script pill (`English / Latin` or `বাংলা Script`), and `Cancel`.

### 40. OCR Results (Interactive Bounding-Box & Reader View)
- **Header:** `← Back` | `OCR Results (Page 1/6)` | `Copy All` (`#0052FF` link).
- **Top Interactive Page Map (`42%` height):** Page image overlaid with clickable `#0052FF` translucent bounding boxes (`OcrBoundingBox`). Tapping any box highlights the corresponding paragraph below.
- **Bottom Editorial Text Reader (`58%` height):** Clean `--surface` sheet with segmented bar (`Recognized Text` | `Translate` | `AI Brief`), editable text paragraphs in `Inter 14.5px` (`line-height: 1.6`), and bottom action bar: `Copy`, `Export .txt`, `Embed in Searchable PDF`.

### 41. Bengali OCR (`বাংলা` Script Workspace)
- **Typography:** Rendered in `Noto Sans Bengali 15px` (`line-height: 1.65`) for crisp conjunct (`যুক্তাক্ষর`) legibility.
- **Specialized Controls:**
  - Script selector pill: `বাংলা (Bengali)` | `English` | `Mixed BN+EN`.
  - **Numeral Converter Toggle (`ocr_service.dart:123`):** 1-tap switch between Bengali digits (`০ ১ ২ ৩ ৪ ৫ ৬ ৭ ৮ ৯`) and ASCII digits (`0 1 2 3 4 5 6 7 8 9`).
  - **Honest Technical Status Banner (`RISK-03`):** Clearly displays a prototype engineering note: *"Latin & Numeral normalization active · Native Tesseract `ben.traineddata` integration scheduled per RISK-03 (currently falls back to ML Kit Indic recognizer)."*

### 42. Extracted Text (Full-Screen Editorial Reader)
- **Layout:** Distraction-free typographic reader (`padding: 20px 24px`) with top monospaced stats bar (`1,420 WORDS · 8,910 CHARS · 98% CONFIDENCE`), inline text editing, search-and-replace within extracted text, and export to `.txt` or clipboard.

### 43. Translation
- **Header:** `← Back` | `Document Translation` | Privacy mode badge (`ONLINE · GOOGLE TRANSLATE` per `RISK-10`, with `Offline ML Kit Pack` shown as `Planned`).
- **Language Bar:** `English ▾` `⇄` `বাংলা (Bengali) ▾` separated by a `1px` `--hairline`.
- **Dual Editorial Panes:** Top `Source Excerpt` (collapsible, `--text-2` `13px`) separated by a hairline from the bottom `Translated Output` (`--text-1` `15px` in `Noto Sans Bengali` / `Inter`), with bottom actions: `Copy Translation`, `Swap`, `Share`.

### 44. AI Document Assistant & 45. Document Summary
- **Engine Transparency Badge:** Top monospaced pill `ON-DEVICE EXTRACTIVE ENGINE · TEXTRANK & TF-IDF (100% OFFLINE)`.
- **Mode Switcher:** `Executive Summary (Screen 45)` | `Ask Document Q&A (Screen 44)`.
- **Screen 45 — Document Summary:**
  - **Executive Digest:** 3-sentence high-signal summary set in `Instrument Sans 15px w500` inside a `--surface` folio box.
  - **Key Takeaways:** Numbered hairline list (`01`, `02`, `03` in `--font-mono`).
  - **Top Keywords:** Monospaced tag row (`LEASE`, `$84,200`, `RENEWAL`, `CLAUSE 8`).
- **Screen 44 — AI Q&A Assistant:**
  - Suggested question pills (`"What is the total amount?"`, `"When is the termination date?"`).
  - Question input bar at bottom; answers render as editorial citation cards showing the matched document passage, confidence score (`CONFIDENCE 92%`), and a clickable `JUMP TO PAGE 03` link.

---

## GROUP F — PRODUCTIVITY TOOLS (Screens 46–49)

### 46. Receipt Scanner & 47. Invoice Scanner
- **Replaces Cramped `ReceiptDialog` with Full Editorial Ledger Screen:**
- **Mode Toggle:** `Retail Receipt (Screen 46)` | `Commercial Invoice (Screen 47)`.
- **Top Preview Strip:** Cropped receipt thumbnail + monospaced verification badge (`✓ MATH VERIFIED: SUBTOTAL + TAX = TOTAL` in `--success`, or `--warning` if discrepancy detected by `receipt_parser_service.dart`).
- **Structured Hairline Ledger Table:**
  - `Merchant / Vendor`: `Square Pharmaceuticals Ltd.` (editable)
  - `Invoice / Receipt #`: `INV-2026-884` (`--font-mono`)
  - `Date & Currency`: `2026-11-12 · BDT (৳)`
  - **Line Items Section:** Hairline rows (`12× Paracetamol 500mg Box — ৳ 4,200.00`).
  - **Totals Block:** `Subtotal: ৳ 4,200.00` | `VAT (15%): ৳ 630.00` | **`Grand Total: ৳ 4,830.00`** (`Instrument Sans 18px w700`).
- **Primary Actions:** `Export CSV Spreadsheet` + `Save Searchable Receipt PDF`.

### 48. Business Card Scanner
- **Replaces `BusinessCardDialog` with Full Editorial Contact Folio:**
- **Top Card Stage:** Horizontal `1.75:1` cropped business card preview resting on `--surface-subtle` with paper shadow.
- **Hairline Contact Fields (`business_card_service.dart`):**
  - `Full Name`, `Job Title`, `Organization`, `Mobile Phone`, `Work Email`, `Website`, `Office Address` — each in a clean hairline row with inline edit & 1-tap copy icon.
- **Primary Actions:** `Export vCard 3.0 (.vcf)` (`#0052FF` primary pill) + `Share Contact`.

### 49. CountCam *(Partially Implemented — Beta Disclosure)*
- **Honest Status Banner (`RISK-09`):** Top pill `BETA · TEXT-BLOCK & MANUAL PIN COUNTER (TFLITE OBJECT MODEL PLANNED)`.
- **Viewport:** Dark studio canvas showing captured photo overlaid with circular Ultramarine numbered pins (`01`, `02`..`14`). Users can **tap anywhere on the photo** to add or remove a count pin interactively.
- **Bottom Counter Bar:** Large monospaced readout (`14 ITEMS`), category tag (`Boxes / Labels / Inventory`), `-1` / `+1` `48×48px` buttons, and `Export Annotated Image`.

---

## GROUP G — SECURITY AND BACKUP (Screens 50–55)

### 50. App Lock (Full-Screen Editorial PIN Barrier) & 51. Biometric Authentication
- **Replaces `AppLockDialog` Text-Input Popup:**
- **Layout (`393 × 852` Full Screen on `--bg`):**
  - Top: Monochrome `32×32px` Scaneliq glyph + `Vault Locked` (`Instrument Sans 22px w700`) + `"Enter your security PIN or use biometrics"` (`--text-2`).
  - **PIN Indicator:** 4 (or 6) crisp `12px` circles (`1.5px solid var(--text-1)`, filling solid `#0052FF` as digits are tapped).
  - **Cryptographic Badge:** `PBKDF2-HMAC-SHA256 · 100,000 ITERATIONS` (`--font-mono 9.5px`, `--text-3`).
  - **Hairline Numeric Keypad (`3×4` Grid):** Generous `68×56px` minimal typographic digit keys (`Instrument Sans 24px w600`), bottom-left **Biometric Trigger (`Screen 51` Fingerprint/Face icon)**, bottom-right `⌫ Backspace`.
  - **Lockout State:** After 5 failed attempts, keypad dims and displays a monospaced countdown timer (`LOCKED OUT · RETRY IN 00:28`).

### 52. Security Settings
- **Header:** `← Settings` | `Security & Privacy Vault`.
- **Hairline Settings Rows:**
  - `App Lock (PIN)` — Toggle switch (`ON/OFF`)
  - `Biometric Unlock (Fingerprint / Face)` — Toggle switch (*Requires physical hardware verification*)
  - `Auto-Lock Timeout` — Selector (`Immediately`, `After 1 minute`, `After 5 minutes`)
  - `Change Security PIN` — Opens PIN verification → new PIN flow
  - `Privacy Screen Shield (FLAG_SECURE)` — Toggle switch badged `Planned (RISK-12)` (hides app preview in Android Recents)
  - `KeyStore Hardware Backing` — Status row badged `Planned Migration from SharedPreferences (RISK-05)`.

### 53. Backup and Restore (Local `.scaneliq` Encrypted Archives)
- **Header:** `← Settings` | `Backup & Restore`.
- **Vault Summary Folio (`--surface` card):** `42 DOCUMENTS · 5 FOLDERS · 48.6 MB` | `ENCRYPTION: AES-256-CBC + HMAC-SHA256 (EtM V2)`.
- **Section 1 — Create Encrypted Backup:**
  - Passphrase input + confirm passphrase + `Create .scaneliq Backup Archive` (`#0052FF` pill).
  - Output confirmation shows generated filename, SHA-256 checksum, and `Save / Share Archive`.
- **Section 2 — Restore Backup:**
  - `Select .scaneliq or .zip Archive` → verifies HMAC-SHA256 & Zip-Slip safety → previews document/folder counts → `Restore Non-Destructively`.

### 54. Cloud Synchronization
- **Header:** `← Settings` | `Multi-Device Synchronization`.
- **Section 1 — Active Local E2EE Sync Envelopes (`device_sync_service.dart`):**
  - Export / Import encrypted `.json` sync envelope with Last-Write-Wins (LWW) conflict resolution across devices via local share/cable.
- **Section 2 — Automated Cloud Transport (`Planned — RISK-08`):**
  - Cleanly badged **`PLANNED ROADMAP INTEGRATION`** rows for `Google Drive (AppData E2EE Vault)` and `WebDAV (Nextcloud / Self-Hosted)`—explicitly informing the user that remote cloud transport is not connected in the current build.

### 55. Account Settings (Local Vault Identity)
- **Header:** `← Settings` | `Vault Identity`.
- **Design:** Celebrates Scaneliq's **Zero Mandatory Account (`F-45`)** architecture:
  - Status Folio: `"No Cloud Account Required — Your documents belong solely to this device."`
  - Editable `Local Device Label` (`Emon's Pixel 8 Pro`) used solely to tag E2EE sync envelopes.

---

## GROUP H — PREMIUM AND GENERAL SETTINGS (Screens 56–65)

### 56. Premium Subscription & 57. Subscription Management *(Proposed / Non-Intrusive)*
- **Truthfulness Banner:** Explicitly marked **`PROPOSED DESIGN · NO PAYMENT GATEWAY CONNECTED — ALL LOCAL FEATURES UNLOCKED`**.
- **Editorial Tier Comparison (`Screen 56`):**
  - **`Local-First Core (Free Forever — Active)`:** Unlimited camera scans, zero watermarks, Magic Color & B&W filters, PDF Merge/Split/Compress/AES-256, on-device OCR, local encrypted `.scaneliq` backups.
  - **`Scaneliq Cloud & AI Pro (Proposed Optional Add-On)`:** Automated background E2EE Cloud Sync, generative cloud AI document workflows, cross-team signature vaults.
- **Subscription Management (`Screen 57`):** Displays current status: `Edition: Scaneliq 1.0 Local-First Complete (All On-Device Tools Active)`.

### 58. General Settings (Master Settings Hub)
- **Reached via:** Top-right Gear icon (`⚙`) on the approved Home Dashboard.
- **Layout:** Clean editorial hairline sections (zero rainbow circles, zero developer jargon):
  1. `Appearance` → **Screen 61 (`Gallery Alabaster Light` / `Carbon Studio Dark` / `System`)**
  2. `Scanner Defaults` → **Screen 59**
  3. `PDF & Export Defaults` → **Screen 60**
  4. `Language & OCR Scripts` → **Screen 62**
  5. `Security & App Lock` → **Screen 52**
  6. `Backup, Restore & Sync` → **Screens 53–54**
  7. `Storage & Trash (3 Deleted)` → **Screen 63**
  8. `Scaneliq Edition & Pro` → **Screens 56–57**
  9. `Help, Privacy & About` → **Screens 64–65**

### 59. Scanner Settings
- Hairline rows for: `Default Capture Mode` (`Auto Detection` / `Manual`), `Default Filter` (`Magic Color` / `Original` / `Crisp B&W`), `Auto-Save Interrupted Scans as Drafts` (`ON`), and `Smart Filename Template` (`Scan_[Date]_[Time]`).

### 60. PDF Settings
- Hairline rows for: `Default Page Format` (`ISO A4` / `US Letter` / `Fit to Image`), `Default Export Quality` (`Balanced 200 DPI` / `Archival 300 DPI` / `Compact 150 DPI`), `Auto-Embed Searchable OCR Layer` (`ON`), and `Unwatermarked Exports` (`Always ON — Brand Guarantee`).

### 61. Appearance Settings
- **Fixes Read-Only Bug in `settings_screen.dart:786`:**
- Side-by-side live miniature preview cards of **`Gallery Alabaster (Light)`** (`#FAF9F6`), **`Carbon Studio (Dark)`** (`#0D0E11`), and **`Follow System`** with instant live theme switching across the entire app.

### 62. Language Settings
- Interface Language (`English`, `বাংলা — Planned UI Localization`) + Default OCR Recognition Script (`English / Latin`, `বাংলা (Bengali — Planned Tesseract Fix)`, `Devanagari`) + Default Numeral Representation (`0–9` vs `০–৯`).

### 63. Storage Management & Trash Recovery
- **Storage Breakdown Bar (`app_storage_service.dart`):** Visual horizontal proportion bar (`Originals: 28.4 MB`, `Processed Cache: 8.2 MB`, `Exported PDFs: 11.4 MB`, `Temp: 0.6 MB`) + `Clear Temp & Processed Cache` button.
- **Trash & 30-Day Recovery (`trash_screen.dart`):** Hairline list of soft-deleted documents showing `27 DAYS LEFT` mono badge, 1-tap `Restore`, and `Empty Trash Permanently` (`--danger`).

### 64. Help and Support
- Clean expandable hairline FAQ drawers (`How 2-in-1 ID Card scanning works`, `Verifying AES-256 PDF & backup encryption`, `Why Scaneliq requires no user account`, `Bengali OCR roadmap status`), plus `Export Anonymized Diagnostic Log`.

### 65. About Scaneliq
- Monochrome `40×40px` Scaneliq viewfinder emblem, `Scaneliq v1.0.0 (Build 1)`, `Flutter 3.47.7 · Dart 3.13.5 · SQLite v5`, Local-First Privacy Manifesto, and `Open-Source Software Licenses`.
