# Scaneliq — Complete UI/UX Redesign Specification

**Specification Version:** 2.0.0  
**Design Date:** October 19, 2026  
**Status:** Architecture Baseline & Approved Redesign Specification  
**Design System:** Material 3 + Custom Scaneliq Human Interface Guidelines  
**Target Platforms:** Android (Primary), iOS (Architecture Ready), Windows Desktop (Responsive)  

---

## 1. Executive Summary & Design Vision

### 1.1 The Problem with the Current Frontend
An exhaustive visual and architectural audit of the existing Scaneliq mobile implementation revealed critical UX deficiencies that compromise user trust and efficiency:

1. **Oversized Branding & Viewport Waste:**  
   The current Home screen features a 96-pixel high central logo and descriptive banner occupying nearly 35% of the initial mobile viewport. This pushes actionable content, recent scans, and library search below the fold.
2. **Fragmented & Competing Actions:**  
   The interface presents two giant stacked primary buttons (`Scan document` and `Import`), immediately followed by an 8-item grid of circular icons ("Smart Scanning Modes"). Users face decision paralysis: should they tap "Scan document" or select "Batch" / "ID Card" / "Questions"?
3. **Dual, Inconsistent Scanning Engines:**  
   Tapping "Scan document" opens the Google Play Services modal UI (ML Kit Document Scanner), while tapping "Batch" or "ID Card" launches a custom CameraX viewfinder (`continuous_camera_screen.dart`). These two screens feature completely different styling, button placements, and cancellation behaviors.
4. **Poor Document Hierarchy & Library Browsing:**  
   The Home screen renders recent scans as a basic vertical list without folder breadcrumbs, tag pills, thumbnail aspect-ratio badges, or grid/list view toggles.
5. **Disconnected Tools:**  
   Power features (PDF Merge, PDF Split, Password Encryption, Watermarking, and OCR) are segregated into an isolated "Tools" tab, detached from the documents they operate on. Users cannot easily tap a document in their library and choose "Encrypt" or "Merge" from a contextual action sheet.
6. **Dark Theme High-Contrast Harshness:**  
   The existing dark theme relies on high-contrast `#334155` borders on `#1E293B` surfaces with no layered elevation (surfaces 0, 1, 2, 3), resulting in eye strain during nighttime document scanning.

### 1.2 The Scaneliq Design Vision
Scaneliq is redesigned to feel like an **elite, calm, high-performance productivity instrument**. The design language draws inspiration from Apple Notes, Google Drive Scanner, and Linear, emphasizing:
- **Instant Camera Accessibility:** One-tap initiation with a unified, mode-switchable viewfinder.
- **Generous Document Previews:** Documents and pages take visual center stage.
- **Calm, Unified Theme:** Clean neutral surfaces, deep navy accents (`#021642`), vibrant royal blue actions (`#2563EB`), and refined 16dp squircle geometry.
- **Contextual Workflows:** Tools and operations live directly beside the documents they manipulate.
- **Zero Distractions:** No watermarks, no ads, no fake statistics, and no cluttered dashboards.

---

## 2. Information Architecture & Navigation Model

### 2.1 Navigation Structure

Scaneliq utilizes a **Streamlined Bottom Navigation Bar** combined with a prominent, elevated **Floating Shutter Action**:

```text
┌─────────────────────────────────────────────────────────────┐
│                          SCANELIQ                           │
│                                                             │
│   [Tab 1: Home]     [Tab 2: Files]     [Scan FAB]     [Tab 3: Tools]     [Tab 4: Settings]   │
└─────────────────────────────────────────────────────────────┘
```

1. **Home (`/home`):**
   - Quick search bar with filter chips (All, Recents, Starred, Folders).
   - In-progress scan draft recovery card (if an interrupted session exists).
   - Quick capture shortcuts carousel (Document, ID Card, Batch, Book, Whiteboard).
   - Recent Documents feed with Grid/List layout toggle and multi-select actions.
2. **Files / Library (`/files`):**
   - Complete document repository with nested folder navigation and custom color-coded tags.
   - Advanced filters: Date range, document size, file type (PDF vs JPEG), OCR status.
   - Batch selection mode (Move, Tag, Merge, Share, Delete).
3. **Capture Hub (Central Floating Action Button):**
   - Elevated center button launching the **Unified Scaneliq Viewfinder**.
   - Remembers the user's last selected scanning mode.
4. **Tools Hub (`/tools`):**
   - Quick utility center for non-library files: Direct OCR, 2-in-1 ID Stitcher, PDF Merge & Split, PDF Password Encryptor, Watermark Studio, QR/Barcode Scanner, CountCam, and Offline Document Translator.
5. **Settings & Privacy (`/settings`):**
   - Storage metrics, cache cleanup, default export presets, language & font settings, biometric app lock, and privacy data policies.

---

## 3. Screen-by-Screen Redesign Specification & Text Wireframes

### 3.1 Screen 1: Redesigned Home Screen

**Purpose:** Provide instant access to recent work, live search, and quick capture modes without visual clutter.

```text
┌─────────────────────────────────────────────────────────────┐
│ [Logo 28dp] Scaneliq                         [Search] [⋮]   │
├─────────────────────────────────────────────────────────────┤
│ 🔍 Search documents, tags, or OCR text...                   │
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ ⚡ Unsaved Draft (4 pages)               [Resume] [✕]   │ │
│ │ Contract_Draft_Oct19 · 12 minutes ago                   │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ QUICK CAPTURE                                               │
│ [📄 Document]   [🪪 ID 2-in-1]   [📚 Book]   [📋 Batch]     │
│                                                             │
│ RECENT DOCUMENTS                           [⊞ Grid] [⇅ Sort]│
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐          │
│ │ [Thumbnail]  │ │ [Thumbnail]  │ │ [Thumbnail]  │          │
│ │ Lease_Agrmt  │ │ Lab_Report   │ │ Tax_Invoice  │          │
│ │ 3 pgs · PDF  │ │ 12 pgs · PDF │ │ 1 pg · JPG   │          │
│ │ Today, 11:20 │ │ Yesterday    │ │ Oct 15       │          │
│ └──────────────┘ └──────────────┘ └──────────────┘          │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ [Home]        [Files]       ( 📷 )       [Tools] [Settings]│
└─────────────────────────────────────────────────────────────┘
```

#### Key Functional Improvements:
- **Header:** Replaces the 96px banner with a refined 28px logo in the app bar alongside a clean title and search entry point.
- **Draft Recovery Banner:** High-priority, dismissible card appearing only when unsaved draft pages exist in SQLite.
- **Quick Mode Chips:** Horizontally scrolling pill carousel replacing the heavy 8-item grid.
- **Document Cards:** Elevated rounded squircles (16dp radius) displaying a crisp page thumbnail, document title, page count badge, file type indicator, and timestamp. Long-pressing activates multi-select mode.

---

### 3.2 Screen 2: Unified Camera Viewfinder

**Purpose:** One professional camera viewfinder replacing the two divergent scanner implementations.

```text
┌─────────────────────────────────────────────────────────────┐
│ [✕ Close]                 ⚡ [Auto / On / Off]      [⚙ More] │
│                                                             │
│                                                             │
│               ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐                 │
│                 Cyan Boundary Locking Box                   │
│               │ (Auto-detects paper edges)│                 │
│                                                             │
│               └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘                 │
│                       "Hold Steady"                         │
│                                                             │
│ ◀ Whiteboard  ·  ID Card  · [ DOCUMENT ] ·  Batch  · Book ▶ │
│                                                             │
│ [🖼 Import]              (  🔘 SHUTTER  )          [📄 (4) >]│
└─────────────────────────────────────────────────────────────┘
```

#### Key Functional Improvements:
- **Interactive Mode Selector:** Horizontally swipeable carousel above the shutter button (Document, ID Card, Batch, Book, Whiteboard, QR/Code).
- **Intelligent Edge HUD:** Renders a smooth cyan polygon (`#00F0FF` / `#2563EB`) snapping to detected document boundaries in real time.
- **Shutter Feedback:** Haptic vibration on capture, with a thumbnail animation flying into the bottom-right review badge.
- **Torch Controls:** Tap-to-toggle torch with persistent memory across sessions.
- **Page Counter Badge:** Bottom-right badge shows live accumulated page count; tapping immediately opens the **Review & Organizer Screen**.

---

### 3.3 Screen 3: Page Review & Organizer Screen

**Purpose:** Review captured pages, reorder sequence, add missing pages, and configure export options.

```text
┌─────────────────────────────────────────────────────────────┐
│ [← Back]           Review Pages (5)             [Export PDF]│
├─────────────────────────────────────────────────────────────┤
│ Document Title: [ Lease_Agreement_2026                 ✎ ]  │
│                                                             │
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│ │ Page 1   [⋮] │  │ Page 2   [⋮] │  │ Page 3   [⋮] │        │
│ │ [Thumbnail]  │  │ [Thumbnail]  │  │ [Thumbnail]  │        │
│ │ [Crop] [Rot] │  │ [Crop] [Rot] │  │ [Crop] [Rot] │        │
│ └──────────────┘  └──────────────┘  └──────────────┘        │
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│ │ Page 4   [⋮] │  │ Page 5   [⋮] │  │ [ + Add Page]│        │
│ │ [Thumbnail]  │  │ [Thumbnail]  │  │ Camera/Files │        │
│ │ [Crop] [Rot] │  │ [Crop] [Rot] │  │              │        │
│ └──────────────┘  └──────────────┘  └──────────────┘        │
├─────────────────────────────────────────────────────────────┤
│ QUICK ACTIONS:                                              │
│ [ 🔄 Reorder All ]   [ 🎨 Batch Filter ]   [ 🗑 Delete Page ]│
└─────────────────────────────────────────────────────────────┘
```

#### Key Functional Improvements:
- **Inline Title Editing:** Quick tap-to-rename document title before saving.
- **Drag-to-Reorder Grid:** Smooth reordering with visual elevation on the dragged card; auto-saves new `page_order` to SQLite.
- **Quick Per-Page Controls:** Direct access to Crop and Rotate directly beneath each thumbnail without opening a separate screen.
- **Contextual More Menu (`⋮`):** Retake page, duplicate page, save single page as JPEG, delete page.

---

### 3.4 Screen 4: Interactive Crop & Image Enhancement Editor

**Purpose:** Fine-tune document geometry, perspective warping, and tonal filters.

```text
┌─────────────────────────────────────────────────────────────┐
│ [✕ Cancel]                  Edit Page 1             [✓ Done]│
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                 ● ─────────────────────── ●                 │
│                 │ [Loupe Magnifier 🔍]   │                 │
│                 │                         │                 │
│                 │   Document Preview Area │                 │
│                 │                         │                 │
│                 ● ─────────────────────── ●                 │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ [ ↺ Rotate Left ]   [ ↻ Rotate Right ]   [ ⛶ Reset Corners ]│
├─────────────────────────────────────────────────────────────┤
│ FILTERS:                                                    │
│ [ Original ]  [ ✨ Magic Color ]  [ 📄 Clean B&W ]  [ ⚪ Gray ]│
│                                                             │
│ ADJUSTMENTS:                                                │
│ Brightness  ───○─────────── (+15%)                          │
│ Contrast    ───────○─────── (1.2x)                          │
└─────────────────────────────────────────────────────────────┘
```

#### Key Functional Improvements:
- **Magnified Loupe Corner Drag:** When dragging any of the 4 corner handles, a circular magnifying loupe appears above the user's finger, allowing sub-pixel precision on document corners.
- **Real-Time Perspective Preview:** Utilizes background isolate rendering to keep touch interaction silky smooth.
- **Single-Tap Filter Presets:**
  - *Magic Color:* CamScanner-style vibrant enhancement maximizing legibility of stamps, colored headings, and signatures.
  - *Clean B&W:* High-pass thresholding eliminating background shadows and bleed-through text while keeping black ink crisp.
  - *Grayscale:* 256-level smooth shading for pencil sketches and black-and-white photos.
  - *Whiteboard:* Aggressive glare removal and background whitening for dry-erase boards.

---

### 3.5 Screen 5: Export & Security Bottom Sheet

**Purpose:** Configure output format, quality compression, password protection, and destination.

```text
┌─────────────────────────────────────────────────────────────┐
│ ─── Drag Handle ───                                         │
│ Export Document                                     [✕ Close]│
├─────────────────────────────────────────────────────────────┤
│ FORMAT:                                                     │
│ (●) PDF (Multi-page document)       ( ) JPEG (Individual)   │
│                                                             │
│ QUALITY & FILE SIZE:                                        │
│ [ Standard (200 DPI) ]   [ High (300 DPI) ]   [ Compact ]   │
│ Estimated size: ~1.8 MB                                     │
│                                                             │
│ ADVANCED OPTIONS:                                           │
│ [✓] Embed Searchable OCR Text Layer (Selectable text)       │
│ [ ] Encrypt with Password (AES-256)                         │
│     [ Enter Password...                                   ] │
│ [ ] Add Watermark                                           │
│                                                             │
│ SAVE DESTINATION:                                           │
│ [ 💾 Save to Scaneliq Library ]      [ 📤 Share to Apps... ]│
│ [ 📁 Export to Device Storage (Files) ]                     │
└─────────────────────────────────────────────────────────────┘
```

#### Key Functional Improvements:
- **Estimated File Size Indicator:** Dynamically computes estimated output size based on selected DPI preset (Standard, High, Compact).
- **Searchable PDF Toggle:** Integrates on-device OCR layer embedding directly into the export sheet.
- **Inline AES-256 Encryption:** Allows users to lock the PDF with a password before generating the file.
- **Clear Destination Choices:** Explicitly distinguishes between saving to the internal library, sharing to external apps via Android Sharesheet, and exporting to public storage.

---

### 3.6 Screen 6: Interactive Document Viewer & Search Screen

**Purpose:** Read, inspect, search text, annotate, and manage finalized documents.

```text
┌─────────────────────────────────────────────────────────────┐
│ [← Back]        Lease_Agreement_2026.pdf        [🔍] [Share]│
├─────────────────────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────────────────────┐ │
│ │                                                         │ │
│ │  RESIDENTIAL LEASE AGREEMENT                            │ │
│ │  This agreement is made on this 19th day of October... │ │
│ │  [Highlighted Search Hit: "Tenant"]                    │ │
│ │                                                         │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ Page 1 of 5                                   [ ◄ Prev  Next ► ]│
├─────────────────────────────────────────────────────────────┤
│ [ 🔍 Find Text ]   [ 📝 Annotate ]   [ 🔏 Encrypt ]   [ ⋮ More ]│
└─────────────────────────────────────────────────────────────┘
```

#### Key Functional Improvements:
- **Full-Text In-Document Search:** Type a keyword; all matches are highlighted in yellow directly over the rendered PDF page with smooth jumping between hits.
- **Page Navigation Bar:** Floating bottom capsule showing current page, total pages, and quick-jump slider.
- **Bottom Tool Palette:** Instant access to Find Text, Annotate (highlight/sign), Password Protection, and Page Operations (Merge, Split, Extract).

---

### 3.7 Screen 7: Files & Library Screen

**Purpose:** Comprehensive document organization with folders, tags, search, and batch actions.

```text
┌─────────────────────────────────────────────────────────────┐
│ Files                                        [🔍 Search] [⊞]│
├─────────────────────────────────────────────────────────────┤
│ FOLDERS                                         [ + New ]   │
│ [ 📁 Tax & Invoices (12) ]    [ 📁 Medical (4) ]   [ 📁 IDs ]│
│                                                             │
│ TAGS                                                        │
│ [ 🏷 All ]  [ 🔵 Urgent ]  [ 🟢 Receipts ]  [ 🟣 Contracts ]│
│                                                             │
│ ALL DOCUMENTS (28)                             [ Select All]│
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ [Thumbnail]  Lease_Agreement_2026.pdf                 ⋮ │ │
│ │              5 pgs · 1.8 MB · Today, 11:20 AM           │ │
│ │              [🔵 Urgent] [🟣 Contracts]                 │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │ [Thumbnail]  Pharmacy_Receipt_Oct.jpg                 ⋮ │ │
│ │              1 pg · 420 KB · Yesterday                  │ │
│ │              [🟢 Receipts]                              │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ [Home]        [Files]       ( 📷 )       [Tools] [Settings]│
└─────────────────────────────────────────────────────────────┘
```

#### Key Functional Improvements:
- **Nested Folder Support:** Tap any folder to drill down into sub-folders.
- **Multi-Colored Tags:** Filter documents by multiple overlapping tags simultaneously.
- **Batch Action Toolbar:** Selecting multiple documents opens a bottom action bar: Move to Folder, Add Tags, Merge into Single PDF, Share Batch, Delete to Trash.

---

### 3.8 Screen 8: Unified Tools Hub

**Purpose:** Dedicated utility workspace for processing loose files without cluttering the Home feed.

```text
┌─────────────────────────────────────────────────────────────┐
│ Tools Hub                                                   │
├─────────────────────────────────────────────────────────────┤
│ PDF TOOLS                                                   │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ [ 📄 Merge PDFs ]       Combine multiple files into one │ │
│ │ [ ✂ Split PDF ]         Extract pages or cut into files │ │
│ │ [ 🔒 Encrypt PDF ]      Add AES-256 password security   │ │
│ │ [ 💧 Watermark Studio ] Stamp confidential watermarks   │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ SPECIALIZED CAPTURE MODES                                   │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ [ 🪪 ID 2-in-1 Sheet ]   Front & Back stitched on A4    │ │
│ │ [ 🔲 QR / Barcode ]     Decode codes & export history   │ │
│ │ [ 🔢 CountCam ]         Count physical items via camera │ │
│ │ [ 🌐 Document Translate] Translate OCR text into Bengali │ │
│ └─────────────────────────────────────────────────────────┘ │
│                                                             │
│ OCR & CONVERSION                                            │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ [ 🔤 Instant OCR ]      Extract plain text from photo   │ │
│ │ [ 📄 Searchable PDF ]   Inject text layer into image    │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Design System Tokens & Component Guidelines

### 4.1 Semantic Color System

| Token | Light Theme Value | Dark Theme Value | Usage |
|---|---|---|---|
| `brandPrimary` | `#2563EB` (Royal Blue) | `#3B82F6` (Electric Blue) | Primary buttons, active tabs, search highlights |
| `brandPrimaryPressed` | `#1D4ED8` | `#1D4ED8` | Pressed states, active borders |
| `brandDeep` | `#021642` (Deep Navy) | `#0B192C` (Navy Black) | Header accents, app branding background |
| `brandAccent` | `#00F0FF` (Neon Cyan) | `#00F0FF` (Neon Cyan) | Camera boundary HUD, loupe reticle, badges |
| `surface0` (Canvas) | `#F8FAFC` (Slate 50) | `#090D16` (Deep Midnight) | Scaffold background |
| `surface1` (Cards) | `#FFFFFF` (Pure White) | `#131B2E` (Navy Slate) | Document cards, tool panels, dialogs |
| `surface2` (Elevated) | `#F1F5F9` (Slate 100) | `#1E293B` (Slate 800) | Secondary buttons, chips, search fields |
| `surface3` (Overlay) | `#E2E8F0` (Slate 200) | `#293548` (Slate 700) | Dividers, active selection state |
| `textPrimary` | `#0F172A` (Slate 900) | `#F8FAFC` (Slate 50) | Screen titles, document names, primary labels |
| `textSecondary` | `#64748B` (Slate 500) | `#94A3B8` (Slate 400) | Timestamps, page counts, secondary labels |
| `borderSubtle` | `#E2E8F0` | `#1E293B` | Card outlines, tab bar top border |
| `success` | `#10B981` (Emerald 500) | `#34D399` (Emerald 400) | Operation verified, saved confirmations |
| `warning` | `#F59E0B` (Amber 500) | `#FBBF24` (Amber 400) | Low storage, blur warning, unsaved draft |
| `error` | `#EF4444` (Red 500) | `#F87171` (Red 400) | Deletion, write failure, permission denied |

---

### 4.2 Typography Hierarchy

- **Primary Latin Font:** Inter (bundled variable font).
- **Bangla Companion Font:** Noto Sans Bengali (bundled font with complete conjunct support).

| Hierarchy Level | Font Size (sp) | Font Weight | Line Height | Tracking | Usage |
|---|:---:|:---:|:---:|:---:|---|
| **Display Large** | 28 | SemiBold (600) | 34 | -0.5 | Welcome banner, empty state highlights |
| **Headline Medium** | 22 | SemiBold (600) | 28 | -0.2 | App bar titles, section headers |
| **Title Medium** | 16 | SemiBold (600) | 22 | 0 | Document card titles, dialog headers |
| **Body Large** | 15 | Regular (400) | 22 | 0 | Primary body text, input fields |
| **Body Medium** | 13 | Regular (400) | 18 | 0.1 | Secondary metadata, dates, page numbers |
| **Label Large** | 14 | SemiBold (600) | 20 | 0.2 | Button labels, chip text |
| **Label Small** | 11 | Medium (500) | 14 | 0.4 | Badges, bottom tab labels |

---

### 4.3 Spacing, Geometry & Elevation

- **Base Rhythm:** 8dp grid (4dp optical adjustments for icon alignments).
- **Standard Screen Padding:** 16dp horizontal, 12dp vertical.
- **Corner Radii:**
  - Standard Cards & Dialogs: **16dp** (Squircle).
  - Buttons & Text Fields: **12dp**.
  - Bottom Sheets: **24dp** (Top-left & Top-right).
  - Chips & Filter Pills: **20dp** (Full capsule).
- **Elevation Layers:**
  - Level 0: 0dp shadow (flat canvas).
  - Level 1: 1dp border + 2dp soft blur shadow (document cards).
  - Level 2: 4dp shadow (floating search bar, bottom action bar).
  - Level 3: 8dp shadow (floating camera shutter FAB, bottom sheets).

---

## 5. End-to-End User Journeys

### 5.1 Journey 1: Multi-Page Scan to Searchable PDF
1. User taps the central **Camera FAB** from Home.
2. Viewfinder opens in **Document** mode with auto-capture active.
3. User points camera at paper; cyan boundary locks on and captures Page 1 with haptic feedback.
4. User flips to Page 2, Page 3; pages accumulate in the bottom-right badge (`[📄 3]`).
5. User taps the badge to open **Review Pages**.
6. User reviews thumbnails, drags Page 3 to Page 2, and edits document title to `Contract_Signed`.
7. User taps **Export PDF**; bottom sheet opens.
8. User selects **Standard Quality**, verifies that **Embed Searchable OCR** is toggled on, and taps **Save to Scaneliq**.
9. Background isolate runs OCR text layer injection and PDF compilation.
10. Success modal confirms: `Saved to Scaneliq (1.4 MB)`. Document opens in Viewer with searchable text highlighted.

### 5.2 Journey 2: 2-in-1 ID Card Stitching
1. User opens **Tools Hub** and selects **ID 2-in-1 Sheet**.
2. Viewfinder opens with an ID Card bounding box overlay.
3. User captures front side; UI prompts: *"Now capture the back side"*.
4. User captures back side.
5. App instantly stitches both cards onto a standardized 200 DPI A4 canvas with clean margins and subtle borders.
6. User reviews the combined page and taps **Export PDF** or **Share JPEG**.

### 5.3 Journey 3: Full-Text Library Search
1. User types `"tenancy"` in the Home search bar.
2. Search queries both SQLite document titles and the indexed `document_ocr` full-text table.
3. Result displays document card with a snippet: *"...the **tenancy** shall commence on November 1st..."* and page tag: `Page 2`.
4. User taps the result; Document Viewer opens directly to Page 2 with the word *"tenancy"* highlighted in yellow.

---

## 6. Frontend Migration & Implementation Plan

To execute this redesign smoothly without breaking existing functionality or tests:

1. **Step 1: Theme & Design Tokens Refactoring (`app_theme.dart`)**  
   Introduce the new semantic surface levels (`surface0`, `surface1`, `surface2`), brand deep navy accents, and typography scales without removing existing color references.
2. **Step 2: Navigation Shell Restructure (`main_navigation_shell.dart`)**  
   Implement the 4-tab model (Home, Files, Tools, Settings) with the elevated center Camera FAB.
3. **Step 3: Home Screen Overhaul (`home_screen.dart`)**  
   Replace the 96px header banner with the compact app bar, integrate the Quick Capture carousel, and replace the static list with the responsive document card grid.
4. **Step 4: Unified Camera Viewfinder (`continuous_camera_screen.dart`)**  
   Merge the ML Kit Document Scanner and CameraX implementations into a single mode-switchable viewfinder with live HUD feedback.
5. **Step 5: Review & Editor Polish (`review_pages_screen.dart`, `edit_page_screen.dart`)**  
   Add the loupe corner magnifier, streamline the filter bar, and integrate the new Export Bottom Sheet.
6. **Step 6: Files & Tools Hub Polish (`documents_library_screen.dart`, `tools_screen.dart`)**  
   Implement folder cards, multi-color tags, and contextual document action sheets.
