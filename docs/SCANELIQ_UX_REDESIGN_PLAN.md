# Scaneliq — Complete UX Redesign Plan & Implementation Roadmap

**Document Version:** 1.0.0  
**Date:** October 19, 2026  
**Author:** Senior Mobile Product Designer & Flutter UI Architect  
**Project:** Scaneliq — Document Scanner & PDF Productivity App  
**Working Directory:** `C:\Scaneliq`  

---

## 1. Baseline UX Audit & Current Design Problems

An exhaustive inspection of the actual user screenshots (`.user_uploaded/media_*.jpg`) and production Flutter source code (`lib/features/documents/presentation/home_screen.dart`, `documents_library_screen.dart`, `tools_screen.dart`, `settings_screen.dart`) identified the following critical usability defects:

### 1.1 Home Screen Deficiencies
1. **Vertical Space Inefficiency:**  
   The screen starts with a bulky header and tagline, followed by two massive side-by-side buttons ("Scan document" flex 3, "Import" flex 2), taking up valuable viewport space before any document content is reached.
2. **Text Truncation in Scanning Modes:**  
   The "Smart Scanning Modes" carousel contains horizontal cards where longer mode labels are truncated (e.g., "Questio..." on compact viewports), impairing readability and polish.
3. **Mid-Screen Search Dislocation:**  
   The document search bar is placed between the quick scanning modes and the recent documents section. This disrupts standard Android visual hierarchy, where search belongs prominently in the top app bar or top pinned section.
4. **Weak First-Use / Empty States:**  
   When no documents are present, the empty state displays a generic circle with basic text rather than an inspiring, actionable onboarding flow.

### 1.2 Documents Library Deficiencies
1. **Ambiguous Tab Naming:**  
   The shell bottom bar labeled this screen "Documents" in some areas and "Files" in others.
2. **Rainbow Category Dots:**  
   Filter chips utilized arbitrary multicolored dots (yellow, green, blue, purple) that introduced visual clutter without conveying meaningful status.
3. **Empty State Lack of Guidance:**  
   When a folder or filter returns no documents, the empty state merely states "No documents in this view" without offering clear actions to scan, import, or clear filters.

### 1.3 Tools Screen Deficiencies
1. **Inconsistent Screen Header:**  
   AppBar displayed "Document Tools" while the tab bar label is "Tools".
2. **Confusing Status Indicators:**  
   Action cards such as "Share & Export" displayed a green trailing checkmark (`Icons.check_circle_outline`), misleading users into thinking a task had completed.
3. **Redundant Modes:**  
   Quick capture modes already present on Home were repeated indiscriminately on Tools without clear categorization.

### 1.4 Settings / Me Deficiencies
1. **Technical Settings Dump:**  
   Settings lacked a coherent personal workspace identity, exposing raw system storage paths (`/data/user/0/...`) and flat toggle lists without clear semantic grouping.
2. **Missing Workspace Customization:**  
   Lacked dedicated scan preferences (default capture mode, auto-crop toggle) and PDF export templates (`[Date]_[Title]`).

---

## 2. Research Findings Applied from the 6 Competitors

| Competitor Pattern | Lesson Applied to Scaneliq Redesign |
|---|---|
| **Microsoft OneDrive / Lens** | **4-Tab Bottom Bar + Elevated Central Camera Shutter:** The most ergonomic single-handed scanning layout for Android. Users can trigger a scan instantly from any screen. |
| **Genius Scan** | **Local-First Privacy & Folder/Tag Architecture:** Full offline utility without mandatory accounts, paywalls, or cloud lock-in. Clean folder hierarchy with breadcrumbs and multi-tag filtering. |
| **Google Drive Scanner** | **Clean Material 3 Rhythm & Filter Chips:** High-contrast text, clear neutral surfaces, and instant filter pills (All, Favorites, PDFs, Images). |
| **CamScanner (Positive)** | **Task-Oriented Tools Workspace:** Grouping utilities into 4 logical categories: (1) PDF Tools, (2) Image & Scan, (3) Text & OCR, and (4) Utilities. |
| **Adobe Scan** | **Uncluttered Document Cards:** High-fidelity thumbnail cards with clear page badges, readable filenames, and contextual action sheets. |
| **SwiftScan** | **Smart Naming Templates:** Allowing users to configure naming templates (`[Date]_[Category]_[Title]`) directly in workspace preferences. |

---

## 3. Proposed Navigation & Information Architecture

### 3.1 Global Navigation Model
The application is structured into **4 primary tabs** plus an **elevated central shutter action**:

```text
┌────────────────────────────────────────────────────────────────────────┐
│                                SCANELIQ                                │
│                                                                        │
│   [Tab 0: Home]   [Tab 1: Documents]   (📷 SCAN)   [Tab 2: Tools]   [Tab 3: Settings]  │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Tab 0: Home (`HomeScreen`):**
   - Compact app bar with official Scaneliq logo and quick search trigger.
   - High-priority Scan and Import action row.
   - Unfinished scan draft recovery banner (interactive Resume/Discard).
   - "Smart Modes" quick capture strip with clear, unclipped labels ("Batch", "ID Card", "Q&A Exam", "Book", "Whiteboard", "QR Code", "CountCam", "Translate").
   - "Recent Documents" section with Grid/List layout toggle and "See All" shortcut leading to Documents.
   - Onboarding-grade empty state with clear calls to action.
2. **Tab 1: Documents (`DocumentsLibraryScreen`):**
   - Top search bar with clear title and folder/tag management.
   - Filter chips row (All, Favorites, PDFs, Images, Folders, Tags).
   - Hierarchical folder navigation with breadcrumbs.
   - Sort selector (Newest, Oldest, Name A-Z, Name Z-A) and List/Grid toggle.
   - Multi-selection mode for batch actions (Move, Tag, Favorite, Share, Delete, Merge).
   - Tailored empty states for All, Search, Folders, Favorites, and Trash.
3. **Elevated Center Shutter Action:**
   - Always-accessible circular elevated button with royal blue gradient.
   - Launches primary document capture session directly from anywhere in the app.
4. **Tab 2: Tools (`ToolsScreen`):**
   - Clean "Tools" header.
   - Task-oriented 4-section layout:
     1. **PDF Productivity Tools:** Merge, Split, Organize Pages, Compress, Watermark, Password Encrypt/Decrypt (tapping opens `PdfToolsScreen`).
     2. **Image & Scan Enhancement:** Filters, Image OCR, 2-in-1 ID Stitcher, Book Splitter, Whiteboard.
     3. **Text & OCR Intelligence:** Instant Image OCR, Business Card extractor, Receipt extractor, AI Document summary sheet.
     4. **Utilities & Scanning:** QR/Barcode scanner, CountCam, Document Translator.
5. **Tab 3: Settings / Workspace (`SettingsScreen`):**
   - Personal local workspace identity:
     1. **Appearance:** System default / Light / Dark mode.
     2. **Scan & Capture Preferences:** Default capture mode, auto-crop, high-quality capture.
     3. **PDF & Export Preferences:** Default export format, smart naming template (`[Date]_[Title]`), compression defaults.
     4. **Storage & Trash:** Actual document storage calculation, cache cleanup, Trash manager.
     5. **Privacy & Security:** Biometric App Lock, PIN protection, local backup & restore, local-first safety pledge.
     6. **Branding & About:** Official Scaneliq branding, version, open-source acknowledgements.

---

## 4. Visual Design System: Tokens, Typography & Color Palette

### 4.1 Color Palette & Design Rationale
- **Brand Primary:** `#2563EB` (Royal Blue) — Communicates trust, focus, and clarity.
- **Brand Primary Pressed:** `#1D4ED8` (Deep Royal Blue).
- **Brand Deep:** `#021642` (Deep Navy) — Secondary grounding tone.
- **Brand Light:** `#EFF6FF` (Soft Blue Tint) — Selected chips and highlight backgrounds.

#### Layered Light Theme Surfaces
- **Canvas Background (`surface0`):** `#F8FAFC` (Slate 50) — Subtle, calm, low eye-strain.
- **Cards & Sheets (`surface1`):** `#FFFFFF` (Pure White) — Elevated, clean contrast.
- **Inputs & Secondary Surfaces (`surface2`):** `#F1F5F9` (Slate 100) — Soft pill inputs and secondary buttons.
- **Dividers & Subtle Borders (`surface3` / `borderSubtle`):** `#E2E8F0` (Slate 200).

#### Layered Dark Theme Surfaces
- **Canvas Background (`surface0`):** `#090D16` (Deep Midnight).
- **Cards & Sheets (`surface1`):** `#131B2E` (Navy Slate).
- **Inputs & Secondary Surfaces (`surface2`):** `#1E293B` (Slate 800).
- **Dividers & Borders (`surface3` / `borderSubtle`):** `#293548` (Slate 700).

#### Semantic Status Tokens
- **Success:** `#16803C` (Emerald Green) — Confirmed operations and success toasts.
- **Warning:** `#B54708` (Amber) — Draft alerts and caution confirmations.
- **Error:** `#B42318` (Crimson) — Destructive deletions and critical failures.
- **Focus:** `#0EA5E9` (Sky Blue) — Input active borders.

### 4.2 Typography & Spacing System
- **Fonts:** `GoogleFonts.inter()` as primary typeface with `GoogleFonts.notoSansBengali()` fallbacks for full bilingual English/Bengali rendering.
- **Headings:**
  - `headlineMedium`: 22sp, SemiBold, -0.2 tracking.
  - `titleLarge`: 18sp, SemiBold, -0.1 tracking.
  - `titleMedium`: 15sp, SemiBold, 0.0 tracking.
- **Body & Labels:**
  - `bodyLarge`: 15sp, Regular, 1.45 line-height.
  - `bodyMedium`: 13sp, Regular, 1.4 line-height.
  - `labelLarge`: 14sp, SemiBold, 0.1 tracking.
- **Spacing Scale:** 4dp, 8dp, 12dp, 16dp, 20dp, 24dp, 32dp.
- **Border Radii:**
  - Chips / Pills: 20dp.
  - Cards & Containers: 16dp.
  - Buttons & Inputs: 12dp.
  - Shutter Button: 18dp.

---

## 5. Screen-by-Screen Implementation Plan

### 5.1 Home Screen (`lib/features/documents/presentation/home_screen.dart`)
- **Header:** Compact row featuring `ScaneliqLogo(size: 28)`, "Scaneliq" title, and clear actions.
- **Scan & Import Action Row:** Primary Scan button (`#2563EB`) and tonal Import button (`#F1F5F9`), sized comfortably at 48dp height.
- **Draft Recovery:** Real-time stream watching `latestDraftProvider`. If an active draft exists, render an amber-tinted recovery banner with "Resume" and "Discard".
- **Quick Modes Carousel:** Clean scrollable pill row with verified icons and unclipped titles:
  - "Batch" (`Icons.burst_mode_rounded`)
  - "ID Card" (`Icons.badge_outlined`)
  - "Q&A Exam" (`Icons.quiz_outlined`)
  - "Book" (`Icons.menu_book_outlined`)
  - "Whiteboard" (`Icons.co_present_outlined`)
  - "QR Code" (`Icons.qr_code_scanner_rounded`)
  - "CountCam" (`Icons.calculate_outlined`)
  - "Translate" (`Icons.translate_rounded`)
- **Recent Documents:** Real database records from `documentsListProvider`. Grid / List toggle button. Trailing overflow action sheet with Share, Favorite, and Delete. "See all" button leading to Documents tab.
- **Empty State:** High-polish empty state with scanning illustration icon, supportive copy, and an elevated "Scan your first document" button.

### 5.2 Documents Library (`lib/features/documents/presentation/documents_library_screen.dart`)
- **Header & Search:** Prominent search text field with real-time query matching across document titles.
- **Filter Bar:** Clean pill chips: `All`, `Favorites`, `PDFs`, `Images`.
- **Folder Navigation:** Hierarchical breadcrumbs (`Home / Work / Receipts`). Tap folder to dive deeper; tap breadcrumb to navigate back.
- **Sort & Layout Bar:** Document count badge, Sort dropdown (Newest, Oldest, Name A-Z, Name Z-A), and Grid/List toggle.
- **Document Cards:** Uniform 16dp squircle cards displaying crisp thumbnail, title, page badge (`3 pgs · PDF`), date, and trailing `⋮` action menu.
- **Batch Selection Mode:** Long-press to activate multi-select. Contextual bottom action bar: Move to Folder, Add Tags, Favorite, Share, Delete, Merge into PDF.

### 5.3 Tools Screen (`lib/features/settings/presentation/tools_screen.dart`)
- **Header:** Clean "Tools" or "Productivity & OCR Tools".
- **Section 1: PDF Productivity Tools:**
  - Merge PDFs, Split PDFs, Organize Pages, Compress PDF, Watermark Studio, Password Protect.
  - Tapping opens the verified `PdfToolsScreen` and launches existing functional dialogs.
- **Section 2: Image & Scan Enhancement:**
  - Direct Image OCR, 2-in-1 ID Card Stitcher, Book Splitter, Whiteboard cleaner.
- **Section 3: Text & OCR Intelligence:**
  - Instant Image OCR, Business Card extractor dialog, Receipt extractor dialog, AI Document summary sheet.
- **Section 4: Utilities & Scanning:**
  - QR / Barcode Scanner, CountCam object counter, Offline Document Translator.
- **Clean Visual Presentation:** Eliminate deceptive green checkmark icons. Use consistent 44dp colored icon squares with clear titles and subtitles.

### 5.4 Settings / Workspace Screen (`lib/features/settings/presentation/settings_screen.dart`)
- **Header:** "Settings" with clean subtitle.
- **Section 1: Appearance:** Light, Dark, System Theme switcher.
- **Section 2: Scanner Preferences:** Default scan mode, auto-crop toggle, high-resolution capture toggle.
- **Section 3: PDF & Export Preferences:** Default export format (PDF/JPEG), smart naming template (`[Date]_[Title]`), default PDF compression preset.
- **Section 4: Storage & Trash:** Real local storage calculator, cache clearing tool, Trash shortcut.
- **Section 5: Privacy & Security:** PIN lock toggle, Biometric lock toggle, Auto-lock timeout selector, Backup archive export (`.zip`/`.scaneliq`), Backup restore tool, Local-First document safety pledge.
- **Section 6: Branding & About:** Official Scaneliq logo, version number, licenses, and acknowledgements.

---

## 6. Regression Protection & Test Coverage Strategy

### 6.1 Critical Workflows to Protect
1. **Filters & Image Processing:** Ensure all 5 filter presets (Original, Magic Color, Clean B&W, Grayscale, Whiteboard) remain intact and applied to final outputs.
2. **PDF Generation & Opening:** Ensure generated PDFs remain valid, openable by the in-app viewer, and uncorrupted.
3. **Specialized Scan Modes:** Ensure Book splitting, 2-in-1 ID card, Question set, QR scanning, and CountCam execute without exceptions.
4. **Existing Test Suite:** Maintain 100% pass rate across all 118 existing automated tests in `test/`.

### 6.2 Test Suite Execution Plan
- Run `dart format .` to maintain code formatting standards.
- Run `flutter analyze` to ensure 0 lint errors or warnings.
- Run `flutter test` to verify all 118 unit, widget, and integration tests pass.
- Run `flutter build apk --debug` to verify production compilation.

---

## 7. Implementation Checklist & Acceptance Criteria

- [x] Conduct competitor UX research across 6 major Android apps.
- [x] Author `docs/SCANELIQ_UX_COMPETITOR_RESEARCH.md`.
- [x] Author `docs/SCANELIQ_UX_REDESIGN_PLAN.md`.
- [x] Author `docs/SCANELIQ_UX_REDESIGN_SPEC.md`.
- [ ] Refactor `lib/core/theme/app_theme.dart` with refined tokens, surfaces, and typography.
- [ ] Refactor `lib/app/main_navigation_shell.dart` with 4 tabs + elevated center shutter.
- [ ] Refactor `lib/features/documents/presentation/home_screen.dart` with compact header, quick actions, recents, and draft banner.
- [ ] Refactor `lib/features/documents/presentation/documents_library_screen.dart` with search, filter chips, breadcrumb folders, and batch actions.
- [ ] Refactor `lib/features/settings/presentation/tools_screen.dart` with 4-section workspace.
- [ ] Refactor `lib/features/settings/presentation/settings_screen.dart` with clean Me/Workspace organization.
- [ ] Run `dart format .`, `flutter analyze`, and `flutter test` (all 118 tests pass).
- [ ] Run `flutter build apk --debug`.
- [ ] Author `docs/SCANELIQ_UI_IMPLEMENTATION_REPORT.md`.
