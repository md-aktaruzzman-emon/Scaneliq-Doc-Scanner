# Scaneliq — Complete Screen-by-Screen UX Redesign Specification (32 Screens)

**Document Date:** November 18, 2026  
**Design System:** [SCANELIQ_PREMIUM_DESIGN_SYSTEM.md](file:///C:/Scaneliq/research-output/SCANELIQ_PREMIUM_DESIGN_SYSTEM.md) ("Precision Paper")  
**Navigation:** [SCANELIQ_NAVIGATION_AND_USER_FLOWS.md](file:///C:/Scaneliq/research-output/SCANELIQ_NAVIGATION_AND_USER_FLOWS.md)  
**Scope:** Complete redesign across all **32 core screens and feature workflows**, giving special ergonomic focus to **Home Dashboard (#3)**, **Scanner Camera (#4–6)**, and **Document Library (#15–17)**.

---

## Global Design Standards Applied to Every Screen

- **Colors & Themes:** Light (`canvas #F6F7F9`, `surface #FFFFFF`, `brandPrimary #1E40AF`, `scannerAccent #0D9488`, `borderHairline #E2E5EB`); Dark (`canvasDark #0B0F17`, `surfaceDark #141923`, `brandPrimaryDark #60A5FA`, `scannerAccentDark #2DD4BF`, `borderHairlineDark #262F40`).
- **Typography:** `Plus Jakarta Sans` (display/headers) + `Inter` (body/metadata with `tabularFigures`) + `Noto Sans Bengali` fallback (`বাংলা`).
- **Accessibility Baseline:** Every interactive button, icon, star, menu, and chip enforces a minimum **`48×48dp`** hit area, WCAG AA `>= 4.5:1` contrast, explicit `Semantics` labels, and `MediaQuery` text-scaling resilience up to `1.3x`.
- **No Anti-Patterns:** Zero raw internal file paths (`/data/user/0/...`), zero developer jargon (`UUIDv4`, `Otsu variance`, `LWW`), zero 12-color rainbow icon clutter, zero intrusive ad popups.

---

## PRIORITY HERO SCREENS (Sections 8, 9 & 10 Deep Specs)

### Screen 3 — Home Dashboard *(High-Priority Hero)*
- **Purpose:** Serve as a calm, single-handed launchpad for immediate scanning, resuming interrupted scans, jumping into key scan modes, and opening recent documents—*without* duplicating the full Document Library.
- **ASCII Wireframe (390×844 Mobile):**
```text
┌─────────────────────────────────────────┐
│ [Logo] Scaneliq          [🔍] [☁️ Sync] │  <- 56dp Compact Top Bar (zero tagline bloat)
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐  │
│  │ 🔍  Search docs, OCR text, tags… │  │  <- 46dp Interactive Search Pill (taps open Search)
│  └───────────────────────────────────┘  │
│                                         │
│  ┌─────────────────────┐ ┌───────────┐  │
│  │ 📷  Scan Document   │ │ ↑ Import  │  │  <- 52dp Primary Cobalt CTA + Tonal Import
│  └─────────────────────┘ └───────────┘  │
│                                         │
│  [If active draft:]                     │
│  ┌───────────────────────────────────┐  │
│  │ ⏳ Resume "Receipt_Nov18" (3 pgs) │  │  <- Dismissible Amber-Hairline Banner
│  └───────────────────────────────────┘  │
│                                         │
│  Quick Modes                            │  <- TitleLarge (17sp)
│  [📄 Batch] [🪪 ID Card] [📖 Book] [📊+] │  <- Clean 4-col neutral-well icon grid (no clipping)
│                                         │
│  Recent Scans              See all →    │  <- Switches directly to Tab 1 (Documents)
│  ┌───────────────────────────────────┐  │
│  │ ┌──┐ Annual Tax Return 2026    ⋮ │  │  <- Capped at 6 recent items; List/Grid toggle
│  │ │📄│ 6 pages · PDF · 2h ago       │  │     on section header; 1:1.32 A4 paper thumb
│  │ └──┘                              │  │
│  └───────────────────────────────────┘  │
├─────────────────────────────────────────┤
│  Home   Docs   [ 📷 Scan ]   Tools   Me │  <- 64dp Bar + Solid Cobalt Center Pill
└─────────────────────────────────────────┘
```
- **Visual Hierarchy:** 1) `Scan Document` + `Import` action pair (`52dp`); 2) Conditional Draft Banner; 3) 4-item clean Quick Mode tiles (`Batch`, `ID Card`, `Book`, `All Tools` -> switches to Tools tab); 4) Top 6 `Recent Scans` with `See all` switching Tab `0 -> 1`.
- **Colors & Typography:** `canvas` background; `#FFFFFF`/`#141923` elevated paper cards with `1px` `borderHairline`; `headlineSmall` brand title; `titleMedium` card names.
- **Empty / Loading / Error States:**
  - *Empty:* Crisp outlined scanner illustration in `brandTint` circle, `"Your private document vault"`, `"Scan receipts, IDs, or notes — stored 100% on your device"`, single `Scan First Document` CTA.
  - *Loading:* 4 shimmer skeleton document rows matching `72dp` card height.
  - *Error:* Calm inline retry banner if SQLite initialization fails.
- **Flutter Considerations:** Decompose `home_screen.dart` (currently `1,002` lines) into `HomeHeader`, `HomeActionBar`, `DraftRecoveryCard`, `QuickModesGrid`, `RecentDocumentsSliver` driven by `recentDocumentsProvider` (limit 6) and `navigationTabProvider`. Always pass `cacheWidth: 160` / `cacheWidth: 400` on `Image.file`.

---

### Screens 4, 5 & 6 — Unified Scanner Camera, Automatic Capture & Manual Capture *(High-Priority Hero)*
- **Purpose:** Consolidate ML Kit Document Scanner and `ContinuousCameraScreen` into a single, distraction-free, thumb-operable dark camera studio.
- **Layout Structure (Edge-to-Edge `#000000`):**
  - **Top HUD Pill (`56dp` safe area):** `Close (✕)` | `Auto / Manual` toggle pill (`#2DD4BF` active dot) | `Flash (Off/Auto/Torch)` | `Grid (3×3)` | `Camera Settings (⚙)`.
  - **Center Live Viewfinder:** Full-bleed preview + subtle animated `#2DD4BF` **Optical Emerald Quadrilateral** (`Screen 5 — Auto Capture`) displaying status pill `"Hold steady..."` -> crisp haptic + white flash pulse on lock; **Screen 6 — Manual Capture** hides auto-snap countdown and enables tactile manual shutter anytime with optional tilt leveler line.
  - **Bottom Thumb Zone (`hudGlass` backdrop blur):**
    - Horizontal **Mode Wheel** directly above shutter: `Document`, `ID Card`, `Book`, `Whiteboard`, `Receipt`, `Business Card`, `QR Code`.
    - Primary Row: **Live Thumbnail Stack** (`52×52dp` rounded preview + Cobalt pill badge `"3"`) | **72dp Tactile Shutter Ring** (white outer ring, solid inner disc that morphs into Emerald countdown arc during auto-capture) | **Gallery Import** (`48×48dp` icon button) or **Done (✓)** pill once pages >= 1.
- **Mode-Specific Guides (Restrained, Zero Neon Boxes):**
  - `ID Card`: Clean subtle `1.5dp` translucent white `ID-1` dashed frame with calm top chip `"Step 1 of 2 · Front Side"`.
  - `Book`: Thin `1dp` vertical center spine guide + subtle `"Left | Right"` top pill.
  - `Whiteboard`: Minimal corner brackets only.
- **Error / Permission States:** If camera permission denied or hardware unavailable, display calm full-screen permission recovery card with `Open App Settings` + `Import Photo Instead` fallback.
- **Flutter Considerations:** Fix `didChangeAppLifecycleState` race in `continuous_camera_screen.dart:61-70` (null-reset controller, lock init/dispose); isolate edge-detection frame throttling (`<= 10 fps` on 720p YUV frames).

---

### Screens 15, 16 & 17 — Document Library, Folder Management & Global Search *(High-Priority Hero)*
- **Purpose:** Clean, high-capacity file explorer without the existing 5-bar header pile-up.
- **Layout Structure (`DocumentsLibraryScreen`):**
  - **Clean Top AppBar (`56dp`):** Title `"Documents"` (or Folder Name with back arrow) + **3 clean icons max**: `View Mode (Grid/List)` | `New Folder` | `Overflow Menu (Select Multiple, Sort By, Trash)`. *(Removes duplicate Star icon & frees 40% vertical space!)*
  - **Unified Search + Filter Row:**
    - `46dp` Search Pill (`"Search titles, OCR text, tags..."`) — tapping launches **Screen 17 (Search)** or filters live.
    - Single horizontal scrollable **Chip Rail (`40dp`)**: `All`, `Starred`, `PDFs`, `Receipts`, `Cards`, plus compact `Folders (N)` & `Tags ▾` dropdown chips (opening clean bottom filter sheets instead of stacking 3 separate horizontal chip rows!).
  - **Folder Cards (`Screen 16 — Folder Management`):** Clean compact folder strip/grid (`Folder Icon`, `Folder Name`, `Item count`, 48dp `⋮` menu for Rename / Move / Delete with Trash-vs-Root safety modal) + single compact breadcrumb pill only when nested.
  - **Multi-Select Contextual Action Dock:** Long-press any card -> Top bar shows `"3 Selected"` + `Select All`; Bottom Navigation smoothly slides down and is replaced by **Contextual Dock**: `Move`, `Tag`, `Merge PDF`, `Share`, `Trash`.
- **Screen 17 — Global Search:** Dedicated full-screen/overlay search triggered from Home or Library Search Pill; features instant filter chips (`All`, `Text in Scan`, `Folders`, `Tags`), recent search history pills, and SQLite FTS5 results displaying **highlighted OCR text snippets** (`"...Total: ৳1,450..."`) with matching term bolded in Cobalt Ink.
- **Flutter Considerations:** Break 1,769-line `documents_library_screen.dart` into `LibraryAppBar`, `LibraryFilterBar`, `FolderStrip`, `DocumentGridView`, `DocumentListView`, `MultiSelectBottomDock`. Enforce `cacheWidth` on all thumbnails.

---

## ALL REMAINING SCREENS (1–32 Complete Specifications)

### 1. Splash Screen
- **Purpose:** Smooth branded cold-start transition while `AppStorageService` & `AppLockService` initialize (`<= 400ms`).
- **Layout & Visuals:** Centered `72dp` Scaneliq Precision Mark on clean `canvas` (`#F6F7F9` light / `#0B0F17` dark), subtle wordmark `"Scaneliq"` in `Plus Jakarta Sans w700`, minimal `"Local-First Vault"` caption at bottom.
- **Accessibility / Flutter:** Native `LaunchTheme` matched 1:1 to Flutter first frame so zero color flash occurs; skips immediately if App Lock barrier must appear.

### 2. Onboarding (3 Slides, Skippable)
- **Purpose:** Communicate Scaneliq's core privacy & productivity advantages on first install and prime Camera permission politely.
- **Layout:** Clean full-height pager: 1) *"Scan & Enhance in Seconds"* (edge detection + Magic Color visual); 2) *"100% On-Device Privacy & Bangla Support"* (no mandatory account, zero watermarks, English + `বাংলা`); 3) *"Smart PDF Suite & AI Vault"* -> CTA `"Enable Camera & Start"` + `"Skip for Now"`.
- **States / Accessibility:** Page indicator dots (`8dp` Cobalt pill), `Skip` button (`48dp` target) top-right; persisted via `has_completed_onboarding` flag.

### 7. Scan Preview (Multi-Page Review Carousel)
- **Purpose:** Bridge camera capture and final PDF saving—allowing rapid review, page reordering, batch filter application, and quick naming.
- **Layout:** Top bar (`Back`, editable inline Title Chip with Smart Filename template button, `Save PDF` primary pill). Center: Large swipeable `PageView` card (`1:1.41` paper card + `"Page 2 of 5"` pill + quick corner `Rotate ↻`, `Retake`, `Delete` icon pills). Bottom: Horizontal **Thumbnail Strip** (drag-to-reorder + `+ Add Page` tile) + **Batch Filter Strip** (`Original`, `Magic Color`, `Crisp B&W`, `Grayscale`).
- **States:** Loading overlay per page while isolate pre-renders; empty fallback returns cleanly to Camera if last page deleted.

### 8. Crop & Perspective Correction
- **Purpose:** Precision 4-point quad adjustment when automatic edge detection needs user fine-tuning.
- **Layout:** Dark neutral `#0F172A` canvas framing the original uncropped photo; `#2DD4BF` (`2dp`) quad edges + `24dp` circular corner handles (with **`48dp` invisible touch radius**). While dragging any handle, a **`96dp` circular magnifying loupe (1.8× zoom)** floats `64dp` above the finger with a crosshair!
- **Bottom Controls:** `Auto Detect` (re-snap), `Full Image` (reset corners), `Rotate 90°`, `Apply`.
- **Flutter Considerations:** Isolate-backed projective homography on `Apply`; live canvas `CustomPainter` with zero main-thread bitmap allocations during drag.

### 9. Image Enhancement & 10. Filters (Unified "Enhance Studio")
- **Purpose:** Eliminate the confusing `Filters` vs. `Binarize` tab split and technical Otsu/Sauvola terminology.
- **Layout:** Top large preview canvas (hold **"Compare"** eye pill for original before/after split!). Bottom dock with **3 clean tabs** (`Presets`, `Adjust`, `Clean & Redact`):
  - **Presets (`Screen 10`):** Horizontal carousel of **7 live miniature page thumbnails** generated from downsampled `180px` proxy: `Original`, `Auto Enhance`, `Magic Color`, `Document B&W` *(Otsu)*, `Adaptive Text` *(Sauvola)*, `Grayscale`, `Whiteboard`.
  - **Adjust (`Screen 9`):** Clean tactile sliders for `Brightness`, `Contrast`, `Sharpness`, and a single `"Even Lighting / Shadow Removal"` switch.
  - **Clean & Redact:** `Spot Eraser` (brush out fingers/holes) + `Mosaic / Blackout` privacy brush.
- **Flutter Considerations:** Pre-render all 7 `180px` thumbnail strips concurrently inside a single `Isolate.run` batch when opening Editor.

### 11. Page Organizer
- **Purpose:** Manage multi-page document structure visually (`PdfPageOrganizerScreen` redesign).
- **Layout:** Clean 2–3 column thumbnail grid with bold page index badges (`1`, `2`, `3`). Drag-and-drop handles to reorder. Multi-select mode enables bottom dock: `Rotate`, `Duplicate`, `Extract New PDF`, `Insert PDF/Photo`, `Delete`.
- **States:** Empty check guards against 0-page save; loading skeleton grid for large external PDFs via `pdfrx` thumbnail cache.

### 12. PDF Export & Share Sheet
- **Purpose:** Fast, transparent export configuration without jarring modal prompts.
- **Layout (Modal Bottom Sheet):** Top file summary (`"Invoice_Nov18.pdf · 4 pages"`). Segmented Quality Picker (`Small 150 DPI` / `Balanced 200 DPI` / `High 300 DPI` with estimated MB!), Page Size (`A4`, `Letter`, `Fit`), Toggle (`Embed Searchable OCR Text`, `Password Protect`), and dual bottom CTAs: `Save to Device` | `Share Now`.
- **Loading / Error:** Determinate page-by-page progress bar (`"Building page 2 of 4..."`); atomic `.tmp` verification before share intent.

### 13. PDF Viewer
- **Purpose:** Smooth, high-contrast paper reading and instant post-scan tool access.
- **Layout:** Top bar (`Back`, Document Title + Tap-to-Rename, `Search 🔍`, `Bookmarks 🔖`, `Share ↑`). Fullscreen `pdfrx` continuous vertical canvas with subtle `"3 / 12"` floating pill (tap to jump to page, pinch/double-tap zoom + optional accessibility `+/-` `48dp` buttons).
- **Bottom Action Dock (Replaces 10-item `PopupMenu`):** 5 clear icon+label actions: `Edit`, `Organize`, `OCR Text`, `Sign`, `More Tools` (opens grouped sheet: Compress, Watermark, Password, AI Summary, Export Images, Open External, Details).
- **States:** Password-protected prompt sheet cleanly themed; `Error` banner keeps fallback `Regenerate PDF` & `View Raw Pages` safety net.

### 14. PDF Editing
- **Purpose:** Unified entry into non-destructive page edits, inserting/deleting PDF pages, metadata editing, and flattening annotations.
- **Layout:** Launches directly from Viewer's `Edit` / `Organize` / `Sign` dock actions, preserving the PDF's link back to its SQLite `ScannedDocument` record so edits update the saved export cleanly.

### 18. OCR Results & 19. Bangla OCR
- **Purpose:** Inspect, copy, edit, search, and export recognized text—including true **English + Bengali (`বাংলা`)** support once `RISK-03` Tesseract integration lands.
- **Layout (Split/Sheet Canvas):**
  - Top half: Interactive page thumbnail with `#0D9488` bounding-box highlights (tap any paragraph box to select).
  - Bottom half: Clean editable text reader (`Noto Sans Bengali` + `Inter`, `16sp`, `1.6` line height) with Script selector pill (`Auto / English`, `বাংলা (Bengali)`, `Devanagari`), numeric normalizer toggle (`০-৯ ↔ 0-9`), and action row: `Copy All`, `Share .txt`, `Translate`, `Summarize (AI)`, `Save Searchable PDF`.
- **States:** Honest badge showing engine status (`"On-Device Bengali Engine Ready"` vs `"Download Bengali Pack (3 MB)"` — never silently running Devanagari for Bengali!).

### 20. Translation
- **Purpose:** Clean side-by-side / stacked document translation (`English ↔ বাংলা` and global languages).
- **Layout:** Top language pill bar (`Source [Auto ▾] ⇄ Target [বাংলা ▾]`) + **Offline Pack Status Pill** (`"On-Device"` via `google_mlkit_translation` vs explicit `"Online Mode"` consent notice). Clean stacked Source Card -> Translated Output Card with `Copy`, `Save as Note/PDF`, and `Swap` (`48dp` target).

### 21. AI Document Assistant
- **Purpose:** Dedicated conversational & structured insight screen for long PDFs (`AiDocumentSheet` upgraded to full-height interactive sheet/screen).
- **Layout:** Document context pill (`"Contract_2026.pdf · 12 pages"`). Tabbed or stacked cards:
  - **Executive Summary Card:** 3-sentence digest + bulleted Key Takeaways + Keyword chips.
  - **Ask Document (Q&A):** Quick suggested prompt chips (`"What is the total amount?"`, `"Key deadlines?"`), chat message bubbles with **clickable page/sentence citations** (`Page 2`), and offline TextRank/TF-IDF transparency badge (`"Offline Extractive Engine"`).

### 22. Receipt Scanner & 23. Invoice Scanner
- **Purpose:** Specialized expense digitization workflow (`ReceiptDialog` -> dedicated workspace).
- **Layout:**
  - **Capture:** Camera `Receipt` mode auto-crops tall narrow receipts (auto-suggests vertical stitching for multi-part receipts!).
  - **Extracted Ledger View:** Side-by-side preview + structured card: `Merchant Name` (editable), `Date`, `Category Tag` (`Food`, `Travel`, `Office`, `Utilities`), `Currency` (`৳ / $ / €`), **Line Items Table**, `Subtotal / Tax / Tip / Total` with green `"Math Verified ✓"` or amber `"Check Total ⚠"` badge.
  - **Export:** 1-tap `Export CSV` / `Save PDF` / `Add to Expense Folder`.

### 24. Business Card Scanner
- **Purpose:** Instant contact digitization (`BusinessCardDialog` -> full visual contact card editor).
- **Layout:** Top cropped horizontal Business Card preview (`1.75:1` ratio) + editable clean form fields (`Full Name`, `Job Title`, `Company`, `Phone(s)`, `Email`, `Website`, `Address`). Bottom CTAs: `Save to Phone Contacts`, `Export vCard (.vcf)`, `Copy Details`.

### 25. CountCam
- **Purpose:** Visual object counting for inventory/stacks (requires `RISK-09` real object detector or clear `Beta` labeling).
- **Layout:** Camera/Gallery preview with numbered circular pin overlays (`1`, `2`, `3`...) over detected items + subtle bounding boxes (`#2DD4BF`). Bottom bar: Large tabular count badge (`"24 items"`), `Tap image to add/remove markers` toggle, Category pill, `- / +` `48dp` adjusters, `Save Annotated Image`.

### 26. PDF Tools (Tools Tab Hub + Dedicated Tool Flows)
- **Purpose:** Clean, visual bento grid replacing the 12-color rainbow list + dead placeholders (`tools_screen.dart` & `pdf_tools_screen.dart`).
- **Layout (4 Clean Visual Sections on `Tools` Tab):**
  1. **Capture Modes (Compact 4-col Icon Grid):** `ID Card 2-in-1`, `Book Split`, `Whiteboard`, `Receipt`, `Business Card`, `QR & Barcode`, `CountCam`, `Long Stitch`.
  2. **PDF Utilities (2-Column Bento Cards, monochrome Cobalt-tinted wells):** `Merge PDFs`, `Split & Extract`, `Compress PDF`, `Organize Pages`, `Sign & Stamp`, `Watermark`, `Protect / Unlock`, `Flatten & Redact`.
  3. **OCR & Intelligence:** `Extract Text (OCR)`, `Bangla OCR`, `Translate`, `AI Summary & Q&A`.
  4. *(Eliminates fake `"Share & Export"` SnackBar tile and dead `"Coming soon"` placeholders.)*

### 27. Signature & Annotations
- **Purpose:** Tactile freehand signing & document markup directly over PDF pages (`pdf_tools_screen.dart` modal -> dedicated canvas).
- **Layout:** Live scrollable PDF page canvas + Floating Bottom Pen Dock: `Draw Signature` (saves reusable transparent PNG signatures locally in vault!), `Text Note`, `Date Stamp`, `Highlight`, `Ink Color` (`Black`, `Cobalt Blue`, `Crimson Red` — 3 authentic ink colors only!), `Stroke Width`, `Undo / Redo`, `Save`.

### 28. Security & App Lock
- **Purpose:** Transparent vault security center (`Settings -> Security` + Lock Barrier).
- **Layout:**
  - **Lock Barrier Screen:** Centered Scaneliq mark, `"Vault Locked"`, clean 4–6 dot PIN indicator + tactile `3×4` keypad (`56dp` circular keys) + Biometric fingerprint/face button. Clear lockout countdown ring after 5 wrong attempts.
  - **Security Settings Sub-Screen:** `PIN Lock Switch`, `Biometric Unlock Switch`, `Auto-Lock Timer` (`Immediate`, `30s`, `1m`, `5m`), `Privacy Screen Shield (FLAG_SECURE)` toggle, `Change PIN`, `Android KeyStore Status Badge`.

### 29. Backup & Restore
- **Purpose:** Honest, trustworthy data durability hub eliminating `"UUIDv4"` / `"LWW"` developer jargon and fake "cloud" labels until transport ships.
- **Layout:**
  - **Vault Health Card:** `"42 Documents · 184 MB Stored Locally"` + `"Last Backup: Nov 18, 2026"`.
  - **Section 1 — Encrypted Offline Archive (`.scaneliq`):** `Create Encrypted Backup` (passphrase strength meter, AES-256-CBC + HMAC integrity), `Restore from Archive` (shows preview count of docs/folders before non-destructive merge).
  - **Section 2 — Cloud Sync (When Phase B Transport Ships):** Google Drive AppData / WebDAV connection card with clear `End-to-End Encrypted` lock badge, Wi-Fi-only toggle, and human-readable sync history (`"Synced 42 files · Today 3:15 PM"`).

### 30. Settings
- **Purpose:** Clean, scannable preference hierarchy free of technical clutter.
- **Layout (5 Grouped Cards on `canvas`):**
  1. **Workspace Status Card:** Compact Scaneliq Logo + `"Local-First Mode"` + `"Vault Ready"` pill (links to Backup & Storage).
  2. **Appearance & Language:** Interactive **Theme Mode Segmented Sheet (`System` / `Light` / `Dark`)** *(fixes current read-only tile!)*, **OCR Script Defaults (`English`, `বাংলা Bengali`, `Auto`)**.
  3. **Scan & PDF Defaults:** Default Filter (`Auto` / `Magic Color` / `B&W`), Page Size (`A4` / `Letter`), Export Quality (`200 DPI` / `300 DPI`), Smart Filename Template Builder (`[Date]_[Category]_[Title]`).
  4. **Security & Trash:** App Lock & Biometrics, Privacy Screen Shield, **Trash & 30-Day Recovery**.
  5. **About & Help:** Help & Support, Open Source Licenses, App Version (`v1.0.0`).

### 31. Premium Subscription (Optional / Non-Intrusive Pro Experience)
- **Purpose:** Present Scaneliq Pro value respectfully—**never** blocking existing local documents, adding forced ads, or nagging on app launch.
- **Layout:** Clean editorial sheet reachable via Settings/Tools `"Scaneliq Pro"` subtle badge: Hero headline `"Upgrade Your Document Studio"`, clear side-by-side comparison (`Free Forever`: Unlimited scans, zero watermarks, local vault, basic PDF & OCR vs. `Pro`: Batch Cloud E2EE Sync, Advanced AI & Receipt Ledgers, Multi-file Batch Merge/Compress, Custom Signatures/Redaction), transparent pricing toggle (`Monthly` / `Annual Save 40%`), explicit `"Restore Purchase"` & `"No ads. Your scans stay yours even if you cancel."` guarantee.

### 32. Help & Support
- **Purpose:** Self-service troubleshooting, gesture hints, and privacy transparency.
- **Layout:** Searchable FAQ cards (`"How to scan 2-in-1 ID cards"`, `"Enabling offline Bengali OCR"`, `"Recovering deleted scans from Trash"`), Storage & Cache Diagnostics (`"Clear 14 MB Temp Cache"` button—safe non-destructive cleanup!), Privacy Guarantee summary, and Feedback / Bug Report mailto/export diagnostics sheet (anonymized log export, never includes documents).
