# Scaneliq — Master Product, UX & Technical Blueprint (Expanded Implementation Edition)

**Document Type:** Expanded Product Requirements Document (PRD) + Comprehensive UX/UI Specification + Technical Architecture + Data Processing Engine + 6-Competitor Research Analysis + Feature Traceability Matrix + QA/Release Gate Plan  
**Project Status:** Active Architecture Baseline & Implementation Specification  
**Primary Platform:** Android First (Target SDK 36, Min SDK 21)  
**App Framework:** Flutter 3.47+ & Dart 3.13+, with Android-Native (Kotlin/CameraX) adapters where necessary  
**Future Platforms:** iOS Next; Windows Desktop after Mobile Core is Mature  
**Product Name:** **Scaneliq**  
**Package / Application ID:** `com.scaneliq.scaneliq`  
**Revision:** 2.0.0 — Research-Backed Expanded Master Edition (October 19, 2026)  
**Original Backup:** [docs/archive/Scaneliq_Master_Blueprint_Improved_original_backup_20261019.md](file:///c:/Scaneliq/docs/archive/Scaneliq_Master_Blueprint_Improved_original_backup_20261019.md)  
**Supporting Documentation Suite:**
- [docs/SCANELIQ_COMPETITOR_RESEARCH.md](file:///c:/Scaneliq/docs/SCANELIQ_COMPETITOR_RESEARCH.md) — Exhaustive 6-competitor capability, pricing, and Free vs Pro analysis.
- [docs/SCANELIQ_UX_REDESIGN_SPEC.md](file:///c:/Scaneliq/docs/SCANELIQ_UX_REDESIGN_SPEC.md) — Comprehensive frontend overhaul, screen wireframes, and design tokens.
- [docs/FEATURE_TRACEABILITY_MATRIX.md](file:///c:/Scaneliq/docs/FEATURE_TRACEABILITY_MATRIX.md) — 47-feature mapping across competitors, priorities, and roadmap phases.
- [docs/IMPLEMENTATION_STATUS.md](file:///c:/Scaneliq/docs/IMPLEMENTATION_STATUS.md) — Live code verification and test suite status report.
- [docs/Scaneliq_Research_and_Blueprint_Update_Prompt.md](file:///c:/Scaneliq/docs/Scaneliq_Research_and_Blueprint_Update_Prompt.md) — Master instructions and research directives.

---

## Contents

- [0. Executive Decision Summary](#0-executive-decision-summary)
  - [0.1 Scaneliq Brand Identity and Design System](#01-scaneliq-brand-identity-and-design-system)
- [1. Product Definition & Vision](#1-product-definition--vision)
  - [1.1 Vision and Core Jobs](#11-vision-and-core-jobs)
  - [1.2 Target User Personas](#12-target-user-personas)
  - [1.3 Product Scope Boundaries & Anti-Goals](#13-product-scope-boundaries--anti-goals)
- [2. Competitor Research & Market Analysis](#2-competitor-research--market-analysis)
  - [2.1 The 6 Reference Products](#21-the-6-reference-products)
  - [2.2 Free vs. Pro/Premium Feature Comparison](#22-free-vs-propremium-feature-comparison)
  - [2.3 Strategic Market Opportunity for Scaneliq](#23-strategic-market-opportunity-for-scaneliq)
- [3. Complete UI/UX Redesign Specification](#3-complete-uiux-redesign-specification)
  - [3.1 Audit of the Current Frontend](#31-audit-of-the-current-frontend)
  - [3.2 Information Architecture & Navigation Map](#32-information-architecture--navigation-map)
  - [3.3 Screen-by-Screen Specifications & Wireframes](#33-screen-by-screen-specifications--wireframes)
  - [3.4 Interaction Rules, Feedback & Micro-Animations](#34-interaction-rules-feedback--micro-animations)
  - [3.5 Responsive Behavior & Accessibility](#35-responsive-behavior--accessibility)
- [4. Complete Feature Requirements & Catalogue](#4-complete-feature-requirements--catalogue)
  - [4.1 Category A: Capture & Scanning Modes](#41-category-a-capture--scanning-modes)
  - [4.2 Category B: Image Enhancement & Non-Destructive Editing](#42-category-b-image-enhancement--non-destructive-editing)
  - [4.3 Category C: PDF Creation, Compression & Advanced PDF Tools](#43-category-c-pdf-creation-compression--advanced-pdf-tools)
  - [4.4 Category D: OCR, Searchable PDFs & Document Intelligence](#44-category-d-ocr-searchable-pdfs--document-intelligence)
  - [4.5 Category E: Document Library, Folders, Tags & Batch Actions](#45-category-e-document-library-folders-tags--batch-actions)
  - [4.6 Category F: System Sharing & Cloud Export](#46-category-f-system-sharing--cloud-export)
  - [4.7 Category G: Security, Privacy & Local-First Guarantees](#47-category-g-security-privacy--local-first-guarantees)
  - [4.8 Category H: Optional AI Assistance](#48-category-h-optional-ai-assistance)
- [5. Android-First Technical Architecture](#5-android-first-technical-architecture)
  - [5.1 Evaluated Technology Stack & Dependency Plan](#51-evaluated-technology-stack--dependency-plan)
  - [5.2 Scanner Engine Decision: Native Scanner vs. Custom Viewfinder](#52-scanner-engine-decision-native-scanner-vs-custom-viewfinder)
  - [5.3 Clean Architectural Separation & Directory Structure](#53-clean-architectural-separation--directory-structure)
  - [5.4 Background Processing, Isolates & Memory Management](#54-background-processing-isolates--memory-management)
- [6. Storage Model, Database Schema & State Machines](#6-storage-model-database-schema--state-machines)
  - [6.1 Local Storage Layout](#61-local-storage-layout)
  - [6.2 Relational SQLite Database Schema](#62-relational-sqlite-database-schema)
  - [6.3 Save-Before-Proceed Pipeline & Atomic Commits](#63-save-before-proceed-pipeline--atomic-commits)
  - [6.4 Formal State Machines](#64-formal-state-machines)
  - [6.5 Startup Reconciliation & Crash Recovery](#65-startup-reconciliation--crash-recovery)
- [7. Android Platform Details & OS Integration](#7-android-platform-details--os-integration)
- [8. Error Handling, Resilience & Recovery Policies](#8-error-handling-resilience--recovery-policies)
- [9. Testing Strategy, Acceptance Gates & Verification Plan](#9-testing-strategy-acceptance-gates--verification-plan)
- [10. Complete Phased Implementation Roadmap (Phases 0–12)](#10-complete-phased-implementation-roadmap-phases-012)
- [11. Commercial Model: Free vs. Pro Feature Tiers](#11-commercial-model-free-vs-pro-feature-tiers)
- [12. Rules for AI Coding Agents & Engineering Standards](#12-rules-for-ai-coding-agents--engineering-standards)
- [13. Comprehensive Technical Terms Glossary](#13-comprehensive-technical-terms-glossary)
- [14. Open Technical Decisions & Risk Log](#14-open-technical-decisions--risk-log)
- [15. Official Documentation & Research References](#15-official-documentation--research-references)
- [16. Ready-to-Use Implementation Brief for Future Tasks](#16-ready-to-use-implementation-brief-for-future-tasks)

---

## 0. Executive Decision Summary

Build **Scaneliq**, a world-class, privacy-first, Android-centric document scanner and PDF productivity platform that takes paper documents through a dependable lifecycle:

$$\text{Capture/Import} \longrightarrow \text{Review} \longrightarrow \text{Enhance/Crop} \longrightarrow \text{Organize} \longrightarrow \text{Compile PDF/JPEG} \longrightarrow \text{Index OCR} \longrightarrow \text{Persist Locally} \longrightarrow \text{Share/Export}$$

### Core Product Principles

1. **Local-First & Offline-Complete:** Core scanning, edge correction, image enhancement, PDF compilation, OCR, and document management operate 100% on-device with zero required internet access or mandatory account creation.
2. **Strict Non-Destructive Preservation:** The original raw image captured by the camera sensor or imported from the gallery is never overwritten. All crops, rotations, and filters are stored as lightweight JSON edit recipes.
3. **No False Success States:** A file is never presented as saved, exported, or encrypted until its atomic disk write and database transaction have been verified on the filesystem.
4. **Zero Annoyance Guarantee:** No forced watermarks on exported PDFs or images, no full-screen interstitial advertisements, and no coercive paywalls.
5. **Progressive Complexity:** Everyday mobile scanning remains instant, fast, and accessible to beginners, while professional PDF tools (Merge, Split, AES-256 Encryption, Watermarking, and Searchable PDF) are discoverable without crowding the viewfinder.
6. **Rigorous Language Support:** English and Bengali (Bangla) OCR and text rendering are benchmarked independently with dedicated Unicode normalization.
7. **Clean Original Identity:** Inspired by the functional strengths of the six market leaders, but implemented through 100% original Dart/Flutter architecture, unique UI/UX styling, original branding, and platform-native integration.

---

### 0.1 Scaneliq Brand Identity and Design System

#### Brand Identity Attributes
| Attribute | Decision |
|---|---|
| **Official App Name** | **Scaneliq** |
| **Short Description** | Private Document Scanner, Searchable PDF Creator & Document Library |
| **English Tagline** | *Scan documents. Keep everything organized.* |
| **Bangla Tagline** | *আপনার ডকুমেন্ট, এক জায়গায় সুরক্ষিত* |
| **Visual Symbol** | 3D Glossy Ribbon forming an "S" framing a pristine white document sheet |
| **Brand Colors** | Deep Navy (`#021642`), Royal Blue (`#2563EB`), Electric Accent (`#00F0FF`) |
| **Typography** | Latin: **Inter** · Bengali / Mixed: **Noto Sans Bengali** |
| **Design Language** | Material 3 + Custom Human Interface Tokens with 16dp squircle geometry |

#### Master Color Tokens
Defined centrally in `lib/core/theme/app_theme.dart`.

| Semantic Token | Light Mode Value | Dark Mode Value | Functional Purpose |
|---|---|---|---|
| `brandPrimary` | `#2563EB` | `#3B82F6` | Primary actions, camera shutter accents, active tabs |
| `brandPrimaryPressed` | `#1D4ED8` | `#1D4ED8` | Button pressed states, focused borders |
| `brandDeep` | `#021642` | `#0B192C` | Official launcher icon background, deep app bar accents |
| `brandAccent` | `#00F0FF` | `#00F0FF` | Viewfinder boundary lock outline, magnifier reticle, badges |
| `surface0` (Canvas) | `#F8FAFC` | `#090D16` | Main scaffold background |
| `surface1` (Cards) | `#FFFFFF` | `#131B2E` | Document cards, bottom sheets, dialogs |
| `surface2` (Elevated) | `#F1F5F9` | `#1E293B` | Search input fields, filter pills, secondary buttons |
| `surface3` (Overlay) | `#E2E8F0` | `#293548` | Dividers, active selection backgrounds |
| `textPrimary` | `#0F172A` | `#F8FAFC` | Screen headlines, document titles, primary text |
| `textSecondary` | `#64748B` | `#94A3B8` | Timestamps, page count badges, metadata |
| `borderSubtle` | `#E2E8F0` | `#1E293B` | Subtle card borders, sheet outlines |
| `success` | `#10B981` | `#34D399` | Verified operations, saved checkmarks |
| `warning` | `#F59E0B` | `#FBBF24` | Low storage alerts, blur warnings, draft indicators |
| `error` | `#EF4444` | `#F87171` | Deletion, write failures, permission denials |

---

## 1. Product Definition & Vision

### 1.1 Vision and Core Jobs
Scaneliq transforms a smartphone into a high-precision, private document digitization suite. It replaces bulky hardware flatbed scanners and expensive, ad-bloated commercial apps for everyday users.

Core User Jobs:
1. **Digitize Paper Instantly:** Convert physical contracts, receipts, book pages, assignments, and IDs into high-contrast digital scans.
2. **Multi-Page Compilation:** Sequentially scan 5, 20, or 50 pages into a single cohesive document with verified ordering.
3. **Enhance Legibility:** Automatically deskew, crop, whiten background shadows, and sharpen faint ink.
4. **Searchable PDF Archival:** Generate standardized A4 PDFs containing an invisible selectable OCR text layer for instant searchability in external viewers.
5. **Local Library Retrieval:** Retrieve any past document instantly via filename, folder, tag, or inside-text keyword search without cloud latency.
6. **Advanced PDF Manipulation:** Merge multi-part documents, split chapters, extract pages, and encrypt sensitive records with AES-256 passwords on-device.

### 1.2 Target User Personas
- **Students & Academics:** Capturing lecture slides, book chapters, homework, and exam question sets; requiring multi-page batch capture, compact file sizes, and full-text keyword search.
- **Freelancers & Small Business Owners:** Scanning client agreements, tax invoices, and business cards; requiring crisp B&W contrast, unwatermarked exports, and automated cloud routing.
- **Office Professionals & Field Workers:** Scanning multi-page contracts, official forms, and dry-erase whiteboards; requiring password encryption, page reordering, and instant PDF merging.
- **Privacy-Conscious Users:** Scanning medical histories, passports, and banking records; strictly demanding local-first storage, zero forced accounts, and guaranteed zero telemetry.

### 1.3 Product Scope Boundaries & Anti-Goals
- **In Scope for Immediate Releases:** Android camera capture, continuous batch scanning, automatic edge detection, non-destructive cropping, filter presets, A4 PDF generation, single/batch JPEG export, local SQLite persistence, searchable PDF generation, full-text search, PDF merge/split/encryption/watermarking, QR code decoding, and ID card 2-in-1 stitching.
- **In Scope for Later Phases:** Bengali (Bangla) OCR benchmarking, nested folders/tags, automated cloud export (Google Drive, Dropbox, WebDAV), opt-in encrypted sync, and local/cloud AI document summaries.
- **Strict Anti-Goals:**
  - *No Mandatory Account Walls:* Users must never be blocked from scanning because they lack an account.
  - *No Free Watermarks:* Scaneliq will never deface user exports with promotional branding.
  - *No Document-Content Telemetry:* User scan bytes, OCR text, and filenames are never logged or transmitted to analytics services.
  - *No Cloud Lock-In:* Local export to user-accessible device storage remains first-class.

---

## 2. Competitor Research & Market Analysis

*(For the complete in-depth report with full citations, pricing tiers, and direct references, see [docs/SCANELIQ_COMPETITOR_RESEARCH.md](file:///c:/Scaneliq/docs/SCANELIQ_COMPETITOR_RESEARCH.md).)*

### 2.1 The 6 Reference Products
Our research evaluated:
1. **Adobe Scan & Acrobat Mobile** (Adobe Inc.)
2. **Google Drive Document Scanner** (Google LLC)
3. **Genius Scan** (The Grizzly Labs)
4. **SwiftScan** (Maple Media)
5. **Microsoft OneDrive / Lens Engine** (Microsoft Corporation)
6. **CamScanner** (INTSIG Information Co., Ltd.)

### 2.2 Free vs. Pro/Premium Feature Comparison

| Capability | Adobe Scan | Google Drive | Genius Scan | SwiftScan | MS OneDrive | CamScanner | Scaneliq Roadmap Position |
|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| **Core Boundary Detection** | Free | Free | Free | Free | Free | Free | **P0 (Implemented & Tested)** |
| **Watermark-Free Export** | Free | Free | Free | Pro Only ($60/yr) | Free | Pro Only ($50/yr) | **P0 (Free Guarantee)** |
| **Max Page Limit** | 25 (100 Pro) | Unlimited | Unlimited | Unlimited | 10 (Android) | Unlimited | **P0 (Unlimited Free)** |
| **PDF Merge / Split** | Pro Only | No | Pro Only ($40/yr) | Pro Only | No | Pro Only | **P0 (Tested Local Feature)** |
| **PDF AES-256 Encryption** | Pro Only | No | Pro Only ($40/yr) | Pro Only | No | Pro Only | **P0 (Tested Local Feature)** |
| **On-Device OCR** | Free (Cloud) | Free (Cloud) | Pro Only ($40/yr) | Pro Only | Free (Cloud) | Pro Only | **P1 (Tested On-Device)** |
| **Searchable PDF Output** | Free (Cloud) | Free (Cloud) | Pro Only ($40/yr) | Pro Only | Free (Cloud) | Pro Only | **P1 (Tested On-Device)** |
| **ID Card 2-in-1 Mode** | Pro Only | No | No | No | No | Free / Pro | **P0 (Tested Local Feature)** |
| **Offline Privacy** | Low (Cloud) | Low (Cloud) | High (On-Device)| Medium | Low (Cloud) | Low (Cloud) | **P0 (100% Local-First)** |

### 2.3 Strategic Market Opportunity for Scaneliq
The competitor landscape is polarized between **cloud-locked ecosystems** (Google Drive, OneDrive, Adobe) that require accounts and upload files to remote servers, and **aggressive freemium apps** (CamScanner, SwiftScan) that punish free users with watermarks, ads, and $50–$70/year subscriptions.

**Scaneliq’s Winning Formula:**
- Provide the privacy, speed, and clean design of Genius Scan.
- Deliver the advanced PDF utility (Merge, Split, Encrypt, Watermark, Searchable PDF) of Adobe Acrobat Pro and CamScanner Premium.
- Package everything into an **ad-free, unwatermarked, local-first mobile suite** with zero mandatory registration.

---

## 3. Complete UI/UX Redesign Specification

*(For complete text wireframes, component specifications, and user journeys, see [docs/SCANELIQ_UX_REDESIGN_SPEC.md](file:///c:/Scaneliq/docs/SCANELIQ_UX_REDESIGN_SPEC.md).)*

### 3.1 Audit of the Current Frontend
The current Scaneliq frontend suffers from five primary design bottlenecks:
1. **Oversized Banner:** The 96px centered logo on the Home screen wastes vertical viewport.
2. **Button Stacking & Redundancy:** Stacked `Scan document` and `Import` buttons clash with the 8-item circular mode grid.
3. **Fragmented Scanning UX:** ML Kit Document Scanner modal and custom CameraX viewfinder have conflicting visual layouts.
4. **Flat Document List:** Recent scans lack folder grouping, tag filtering, and view toggles.
5. **Dark Mode Harshness:** Stark borders and lack of elevation layering cause visual fatigue.

### 3.2 Information Architecture & Navigation Map
Scaneliq adopts a **4-Tab Navigation Shell + Central Floating Camera Shutter**:

```text
                               ┌────────────────────────┐
                               │   SCANELIQ APP ROOT    │
                               └───────────┬────────────┘
                                           │
         ┌───────────────────┬─────────────┴─────────────┬───────────────────┐
         ▼                   ▼                           ▼                   ▼
   [ Tab 1: Home ]    [ Tab 2: Files ]            [ Tab 3: Tools ]    [ Tab 4: Settings ]
   - Search Bar       - Nested Folders            - PDF Merge         - Storage Metrics
   - Draft Card       - Color Tags                - PDF Split         - Cache Cleaner
   - Mode Carousel    - Document Grid/List        - PDF Encrypt       - Biometric Lock
   - Recent Scans     - Multi-Select Batch        - ID 2-in-1 Sheet   - Export Presets
                                  │               - QR / Code         - Privacy Policy
                                  │               - Instant OCR
                                  ▼               - Translator
                     ┌────────────────────────┐
                     │  CENTRAL SHUTTER FAB   │
                     │  Unified Mode Camera   │
                     └────────────────────────┘
```

### 3.3 Screen-by-Screen Specifications & Wireframes

#### Home Screen Wireframe
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
│ QUICK CAPTURE MODES                                         │
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

#### Unified Camera Viewfinder Wireframe
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

#### Interactive Crop & Filter Editor Wireframe
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

### 3.4 Interaction Rules, Feedback & Micro-Animations
- **Haptic Touch:** Short haptic feedback on camera shutter, page reorder lift, and corner drag engagement.
- **Corner Loupe:** Dragging any quadrilateral corner summons a 64dp magnified circle 40dp above the finger, eliminating finger occlusion.
- **Card Animations:** Reordering pages utilizes a smooth 200ms spring curve; deleted pages collapse with a fade-and-shrink transition.
- **Status Banners:** Destructive actions (Move to Trash, Delete Page) display a 4-second Snackbar with an immediate **"UNDO"** action.

### 3.5 Responsive Behavior & Accessibility
- **Touch Target Standard:** Minimum interactive hit target size is 48 × 48 dp.
- **Dynamic Text Scaling:** UI layouts accommodate system font scaling up to 200% without text clipping.
- **Screen Reader Semantics:** Every icon button includes an explicit `tooltip` and `Semantics(label: ...)` tag.
- **Contrast Ratios:** Text-to-surface contrast exceeds WCAG 2.1 AA standards (minimum 4.5:1 for normal text, 3:1 for large headlines).

---

## 4. Complete Feature Requirements & Catalogue

*(For the exhaustive 47-feature matrix mapping status and dependencies, see [docs/FEATURE_TRACEABILITY_MATRIX.md](file:///c:/Scaneliq/docs/FEATURE_TRACEABILITY_MATRIX.md).)*

### 4.1 Category A: Capture & Scanning Modes
- **F-01: Automatic Document Boundary Detection:** Live camera feed calculates paper contour and displays a cyan bounding box; automatically captures when steady. *(TESTED)*
- **F-02: Manual Shutter Fallback:** Allows manual shutter actuation at any time with full interactive corner adjustment. *(TESTED)*
- **F-03: Continuous Multi-Page Batch Capture:** Viewfinder remains open after each photo; pages accumulate in memory and persist immediately to SQLite drafts. *(TESTED)*
- **F-04: Draft Session Persistence:** Interrupted sessions (incoming calls, low battery) are restored upon next app launch via a Home screen banner. *(TESTED)*
- **F-05: Multi-Image & File Import:** Import JPG, PNG, WebP, and PDF files from external apps or device storage via system file picker. *(TESTED)*
- **F-06: ID Card 2-in-1 Sheet Stitching:** Step 1 captures front side, Step 2 captures back side; engine stitches both onto a standardized A4 page with clean borders. *(TESTED)*
- **F-07: Book Dual-Page & Flattening:** Captures open book spreads, separates left/right pages, and corrects curved text lines. *(IMPLEMENTED)*
- **F-08: Whiteboard Mode:** Optimizes contrast for dry-erase boards, eliminating glare and boosting marker colors. *(TESTED)*
- **F-09: Question Set Mode:** Sequential multi-page capture optimized for high-contrast test papers and assignments. *(TESTED)*
- **F-10: QR & Barcode Decoder:** Real-time decoding of standard 1D/2D barcodes with copy, share, and safe URL previews. *(IMPLEMENTED)*
- **F-11: CountCam Object Counter:** Computer vision counter for inventory items (pipes, pills, rebar) with manual count adjustment. *(IMPLEMENTED)*

### 4.2 Category B: Image Enhancement & Non-Destructive Editing
- **F-12: Non-Destructive Edit Recipes:** Raw captures in `originals/` remain bit-for-bit unaltered. Edits are recorded as JSON recipes (`rotationDegrees`, `cropNormalized`, `filter`, `brightness`, `contrast`). *(TESTED)*
- **F-13: Clean B&W Document Filter:** Adaptive thresholding removing shadows, bleed-through, and yellowed paper tones. *(TESTED)*
- **F-14: Grayscale & Magic Color:** 256-shade grayscale and vibrant color contrast boost. *(TESTED)*
- **F-15: Brightness & Contrast Tuning:** Manual sliders adjusting luminance and contrast dynamic range. *(TESTED)*
- **F-16: Finger & Stain Eraser:** Inpainting brush tool allowing users to paint over and remove fingers or hole punches. *(PLANNED)*

### 4.3 Category C: PDF Creation, Compression & Advanced PDF Tools
- **F-17: Multi-Page A4 PDF Compilation:** Compiles ordered pages into standard ISO A4 PDF format with JPEG compression. *(TESTED)*
- **F-18: Quality & DPI Presets:** Compact (150 DPI), Standard (200 DPI), and High (300 DPI) export choices with estimated file size indicators. *(TESTED)*
- **F-19: Unwatermarked PDF Export:** Clean, unbranded exports for all users. *(TESTED)*
- **F-20: Single & Batch JPEG Export:** Export individual pages or all pages as discrete JPEGs. *(TESTED)*
- **F-21: High-Performance PDF Viewer:** Integrated viewer powered by the Google PDFium C++ engine via `pdfrx`. *(IMPLEMENTED)*
- **F-22: PDF Merge (Combine Documents):** Consolidate multiple PDF documents into a single master PDF. *(TESTED)*
- **F-23: PDF Split & Page Extraction:** Split a multi-page PDF into single pages or extract custom page ranges. *(TESTED)*
- **F-24: PDF Password Protection (AES-256):** Encrypt PDF files with user/owner passwords and customizable permission flags. *(TESTED)*
- **F-25: Custom Text Watermarking:** Add semi-transparent diagonal watermarks across all document pages. *(TESTED)*
- **F-26: PDF Annotations & Signatures:** Draw freehand signatures, add sticky text notes, and highlight passages. *(PLANNED)*
- **F-27: True Redaction:** Permanently removes underlying text and image bytes from the PDF stream. *(PLANNED)*

### 4.4 Category D: OCR, Searchable PDFs & Document Intelligence
- **F-28: On-Device Latin OCR:** Fast text recognition using on-device machine learning with zero network calls. *(TESTED)*
- **F-29: Searchable PDF Generation:** Embeds an invisible, selectable OCR text layer precisely matching word coordinates over page images. *(TESTED)*
- **F-30: Full-Text Library Search:** Live keyword search across all scanned pages using SQLite full-text tables. *(TESTED)*
- **F-31: Bengali (Bangla) OCR Integration:** On-device Indic/Bengali script recognition via Tesseract `ben.traineddata` or specialized ML models. *(PLANNED)*
- **F-32: Document Translation:** Translates recognized OCR text between Bengali, English, and other languages. *(TESTED)*
- **F-33: Business Card Contact Extraction:** Automatically parses Name, Email, Phone, Company, and saves directly to Contacts. *(PLANNED)*
- **F-34: Receipt & Invoice Key-Value Extraction:** Automatically extracts Merchant, Date, Tax, Total, and Line Items. *(PLANNED)*
- **F-35: AI Document Assistant:** Local/cloud LLM assistant providing document summaries, key points, and citation-backed Q&A. *(PLANNED)*

### 4.5 Category E: Document Library, Folders, Tags & Batch Actions
- **F-36: Nested Folders & Subfolders:** Organize documents into custom hierarchical directories. *(PLANNED)*
- **F-37: Color-Coded Tags:** Apply multiple colored tags (Urgent, Tax, Receipts) to documents for quick filtering. *(PLANNED)*
- **F-38: Smart Naming Templates:** Configurable dynamic filename syntax (e.g., `[Date]_[Category]_[Title]`). *(PLANNED)*
- **F-39: Trash & Soft-Delete:** 30-day recovery retention with restore and permanent purge actions. *(PLANNED)*
- **F-40: Multi-Select Batch Actions:** Select multiple documents to batch move, tag, merge, or delete. *(PLANNED)*

### 4.6 Category F: System Sharing & Cloud Export
- **F-41: System Share Sheet Integration:** Share PDFs and JPEGs to WhatsApp, Gmail, Drive, or nearby devices via Android Sharesheet. *(TESTED)*
- **F-42: Automated Cloud Export:** Auto-upload verified scans to Google Drive, Dropbox, OneDrive, or WebDAV in the background. *(PLANNED)*
- **F-43: Multi-Device Sync:** Optional encrypted synchronization across devices with conflict resolution. *(PLANNED)*

### 4.7 Category G: Security, Privacy & Local-First Guarantees
- **F-44: 100% Offline Local-First:** Core operations function completely without internet access. *(TESTED)*
- **F-45: Zero Mandatory Accounts:** No registration or login required to access all local features. *(TESTED)*
- **F-46: Biometric App Lock:** Secure document library behind Fingerprint, Face Unlock, or PIN. *(PLANNED)*
- **F-47: Automated Temporary File Cleanup:** Automatic purge of orphaned `.tmp` files older than 24 hours. *(TESTED)*

### 4.8 Category H: Optional AI Assistance
- **F-35 / AI Assistant:** Conversational Q&A, executive summaries, and study notes with explicit user consent and clear data-transfer disclosures. *(PLANNED)*

---

## 5. Android-First Technical Architecture

### 5.1 Evaluated Technology Stack & Dependency Plan

| Architectural Layer | Selected Production Package | Version Constraint | Justification & Selection Gate |
|---|---|---|---|
| **App Framework** | Flutter SDK | `^3.47.7` | High-performance multi-platform UI engine |
| **Language** | Dart SDK | `^3.13.5` | Strict null-safety, async isolates, pure-Dart processing |
| **State Management** | `flutter_riverpod` | `^3.4.3` | Compile-time safe, testable reactive state providers |
| **Local Database** | `sqflite` & `sqlite3` | `^2.4.4+2` | ACID-compliant relational storage with transaction support |
| **File Storage** | `path_provider` & `path` | `^2.1.6` | Platform-safe app-private directory resolution |
| **PDF Generation** | `pdf` (Dart) | `^3.13.1` | Pure-Dart multi-page PDF generation with invisible text layers |
| **PDF Manipulation** | `syncfusion_flutter_pdf` | `^35.1.40+1` | Industrial-grade PDF merge, split, watermark, and AES-256 encryption |
| **PDF Viewing** | `pdfrx` | `^2.6.5` | Native Google PDFium rendering engine for smooth zoom/pan |
| **Document Scanner** | `google_mlkit_document_scanner` | `^0.6.1` | Google Play Services native document boundary detection |
| **Camera Viewfinder** | `camera` (CameraX) | `^0.12.1` | Low-level camera control for continuous batch capture |
| **Text Recognition** | `google_mlkit_text_recognition` | `^0.17.1` | On-device machine learning OCR (Latin scripts) |
| **Code Scanning** | `mobile_scanner` | `^7.4.2` | High-speed real-time barcode and QR code decoding |
| **Image Processing** | `image` (Dart) | `^4.12.0` | Pure Dart image manipulation (rotation, filters, resize) |
| **System Sharing** | `share_plus` | `^13.3.1` | Platform-native Android `Intent.ACTION_SEND` Sharesheet |
| **File Picker** | `file_picker` | `^13.1.0` | System document picker for image and PDF imports |
| **Identifiers** | `uuid` | `^4.6.0` | RFC4122 v4 UUID generation for stable document/page IDs |
| **Typography** | `google_fonts` | `^9.0.0` | Dynamic font resolution (Inter & Noto Sans Bengali) |
| **Translation** | `translator` | `^1.0.4+1` | Text translation wrapper with privacy notice guard |

---

### 5.2 Scanner Engine Decision: Native Scanner vs. Custom Viewfinder

Scaneliq adopts a **Hybrid Unified Scanner Strategy**:
1. **Primary Camera Viewfinder (`continuous_camera_screen.dart`):**  
   An in-app CameraX viewfinder providing a persistent, customizable interface. Users seamlessly swipe between **Document**, **ID Card**, **Batch**, **Book**, and **Whiteboard** modes.
2. **Google ML Kit Document Scanner Integration (`scan_session_provider.dart`):**  
   Accessible via one tap for users who prefer Google's automated scanning UI with built-in perspective correction.
3. **Architectural Convergence:**  
   In Phase 2, the custom viewfinder integrates Google ML Kit boundary detection directly onto the live camera stream, delivering the best of both worlds: full brand styling and instant auto-edge detection.

---

### 5.3 Clean Architectural Separation & Directory Structure

```text
lib/
├── main.dart                                # Application bootstrapping & initialization
├── app/
│   └── main_navigation_shell.dart          # 4-tab bottom navigation with central shutter FAB
├── core/
│   ├── models/
│   │   └── document_models.dart             # Core domain models (ScannedDocument, ScannedPage, EditRecipe)
│   ├── storage/
│   │   └── app_storage_service.dart         # Atomic file writes, path resolution, stale cleanup
│   ├── theme/
│   │   └── app_theme.dart                   # Semantic color tokens, typography, dark/light themes
│   └── widgets/
│       └── scaneliq_logo.dart               # Official brand logo widget
└── features/
    ├── documents/
    │   ├── data/
    │   │   └── app_database_service.dart    # SQLite schema, transactions, migrations, full-text search
    │   └── presentation/
    │       ├── home_screen.dart             # Redesigned Home screen
    │       ├── documents_library_screen.dart# Files & library screen with folders/tags
    │       └── document_viewer_screen.dart  # PDFium document viewer & in-text search
    ├── editor/
    │   └── presentation/
    │       ├── review_pages_screen.dart     # Page organizer & export configuration
    │       └── edit_page_screen.dart        # Loupe crop & filter tuning screen
    ├── scanner/
    │   └── presentation/
    │       ├── continuous_camera_screen.dart# Unified camera viewfinder
    │       ├── scan_session_provider.dart   # Reactive scan session state notifier
    │       ├── scan_code_screen.dart        # QR/Barcode scanner
    │       ├── count_cam_screen.dart        # Object counter
    │       └── translate_screen.dart        # Document translator
    ├── pdf/
    │   ├── data/
    │   │   ├── pdf_service.dart             # Searchable A4 PDF generator
    │   │   └── advanced_pdf_service.dart    # Merge, split, encrypt, watermark engine
    │   └── presentation/
    │       └── pdf_tools_screen.dart        # Dedicated PDF tools interface
    ├── ocr/
    │   └── data/
    │       └── ocr_service.dart             # ML Kit text recognition & coordinate mapping
    └── settings/
        └── presentation/
            ├── settings_screen.dart         # App settings & privacy policies
            └── tools_screen.dart            # Unified Tools hub
```

---

### 5.4 Background Processing, Isolates & Memory Management
- **Dart Isolates (`compute()`):** All heavy image transformations (Otsu thresholding, 90° rotation, JPEG compression) and PDF generation execute in background worker isolates, preventing UI frame drops or Android ANR (Application Not Responding) dialogs.
- **Sub-Pixel Thumbnails:** The Home and Library screens never load full-resolution 12-megapixel images into memory; cached 200×300 thumbnails are loaded on demand.
- **Bounded Buffer Processing:** PDF compilation processes pages sequentially rather than decoding 50 full-resolution bitmaps into RAM simultaneously.

---

## 6. Storage Model, Database Schema & State Machines

### 6.1 Local Storage Layout

All files are stored in Android app-private storage (`/data/user/0/com.scaneliq.scaneliq/app_flutter/`):

```text
app_flutter/
├── originals/            # Pristine, bit-for-bit unedited raw camera photos & imported files
│   └── <page_id>.jpg
├── processed/            # Cached rendered derivatives generated from originals + EditRecipe
│   └── <page_id>_proc.jpg
├── thumbnails/           # Low-resolution 200x300 previews for fast scrolling
│   └── <page_id>_thumb.jpg
├── exports/              # Finalized multi-page PDFs and exported JPEGs
│   └── <document_id>.pdf
└── temporary/            # Work-in-progress files (.tmp), purged automatically after 24 hours
    └── <random_uuid>.tmp
```

---

### 6.2 Relational SQLite Database Schema

Implemented in `lib/features/documents/data/app_database_service.dart` (Schema Version 3):

```sql
-- Core Documents Table
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TEXT NOT NULL,
  modified_at TEXT NOT NULL,
  page_count INTEGER NOT NULL DEFAULT 0,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  export_path TEXT,
  is_draft INTEGER NOT NULL DEFAULT 0,
  folder_id TEXT,
  deleted_at TEXT
);

-- Pages Table (Strict Foreign Key Cascade)
CREATE TABLE pages (
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  page_order INTEGER NOT NULL,
  original_path TEXT NOT NULL,
  processed_path TEXT,
  rotation_degrees INTEGER NOT NULL DEFAULT 0,
  filter_name TEXT NOT NULL DEFAULT 'original',
  brightness REAL NOT NULL DEFAULT 0.0,
  contrast REAL NOT NULL DEFAULT 1.0,
  width INTEGER,
  height INTEGER,
  FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
);

-- Full-Text OCR Search Table
CREATE TABLE document_ocr (
  document_id TEXT PRIMARY KEY,
  ocr_text TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE
);

-- Indices for High-Speed Querying
CREATE INDEX idx_pages_document_id ON pages (document_id);
CREATE INDEX idx_pages_order ON pages (document_id, page_order);
CREATE INDEX idx_documents_draft ON documents (is_draft);
CREATE INDEX idx_documents_modified ON documents (modified_at DESC);
```

---

### 6.3 Save-Before-Proceed Pipeline & Atomic Commits

To eliminate corrupt files and partial writes:

```text
1. Capture/Import Image
      │
2. Write to unique temporary file: temporary/<uuid>.tmp
      │
3. Flush & Close File Descriptor
      │
4. Verify Image Validity (Decode header & check dimensions > 0)
      │
5. Atomic Filesystem Rename: temporary/<uuid>.tmp → originals/<page_id>.jpg
      │
6. SQLite Transaction:
   BEGIN TRANSACTION;
     INSERT INTO pages (id, document_id, page_order, original_path, ...) VALUES (...);
     UPDATE documents SET page_count = page_count + 1 WHERE id = ...;
   COMMIT;
      │
7. Update UI State (Page successfully committed)
```

If any failure occurs prior to step 6, the `.tmp` file is deleted, and no orphaned record is inserted into SQLite.

---

### 6.4 Formal State Machines

#### Document Lifecycle
```text
[NEW SESSION] ──► [DRAFT (is_draft = 1)] ──► [EXPORTING] ──► [FINALIZED (is_draft = 0)]
                        │                                          │
                        ▼                                          ▼
                  [CRASH/KILLED]                             [MOVED TO TRASH]
                        │                                          │
                        ▼                                          ▼
                  [RECOVERED VIA BANNER]                     [PURGED / RESTORED]
```

#### Page Lifecycle
```text
[CAPTURED] ──► [ORIGINAL SAVED] ──► [EDIT RECIPE APPLIED] ──► [PROCESSED DERIVATIVE]
                                           │
                                           ▼
                                 [RESET TO ORIGINAL]
```

---

### 6.5 Startup Reconciliation & Crash Recovery
Every time Scaneliq launches:
1. **Stale Temporary Cleanup:** Scans `temporary/` and deletes all `.tmp` files with `lastModified > 24 hours`.
2. **Draft Reconciliation:** Queries `documents WHERE is_draft = 1`. If valid pages exist, displays the Home resumption banner. If zero pages exist, cleanly purges the empty draft record.
3. **Missing File Safeguard:** Verifies that file paths recorded in SQLite actually exist on disk; missing files are flagged gracefully rather than crashing the viewer.

---

## 7. Android Platform Details & OS Integration

- **Permissions Policy:** Requests `android.permission.CAMERA` only when the user taps to scan. Never requests camera access during app launch or onboarding.
- **Scoped Storage & SAF:** Utilizes Android Storage Access Framework (`FilePicker`) for user-selected imports and exports, requiring zero broad `MANAGE_EXTERNAL_STORAGE` permissions.
- **Android Sharesheet:** Employs platform-approved `FileProvider` (`content://`) URIs via `share_plus` to securely share PDFs and JPEGs without exposing raw file paths.
- **Lifecycle Resilience:** The camera controller gracefully unbinds in `didChangeAppLifecycleState(AppLifecycleState.paused)` and reinitializes on `resumed`, preventing camera sensor locks.

---

## 8. Error Handling, Resilience & Recovery Policies

| Error Scenario | Detection Mechanism | Immediate Fallback | User Recovery Action |
|---|---|---|---|
| **Camera Sensor Busy** | `CameraException` caught | Viewfinder displays retry card | *"Camera unavailable. Tap to retry or import from gallery."* |
| **Low Disk Space (< 50MB)** | `StatFs` check before write | Abort write before capture | *"Device storage is full. Free up space to continue scanning."* |
| **Corrupt Image Import** | Image decode throws exception | Discard imported file | *"Selected file could not be read. Please choose a valid image."* |
| **PDF Generation Error** | `PdfException` caught | Draft remains 100% safe | *"PDF export failed. Your pages are saved. Tap to retry."* |
| **OCR Failure** | ML Kit exception caught | Skip text layer injection | PDF exports as standard raster PDF; OCR retries in background. |

---

## 9. Testing Strategy, Acceptance Gates & Verification Plan

### 9.1 Multi-Tier Test Suite
1. **Unit Tests (Pure Dart):**
   - Edit recipe serialization/deserialization (`test/edit_recipe_test.dart`).
   - SQLite relational queries, cascade deletes, and draft flags (`test/database_persistence_test.dart`).
   - Non-destructive original preservation (`test/storage_service_test.dart`).
   - Searchable PDF generation and `%PDF-` header validation (`test/pdf_generation_test.dart`).
   - Advanced PDF merge, split, encryption, and watermark verification (`test/advanced_pdf_service_test.dart`).
2. **Widget Tests (Flutter Harness):**
   - 4-tab navigation shell switching (`test/navigation_and_screens_test.dart`).
   - Home screen recent document cards and draft resumption banner (`test/widget_test.dart`).
   - Scaneliq logo rendering and brand tokens (`test/logo_test.dart`).
3. **Integration & Build Tests:**
   - 10-page continuous batch capture, deletion, reordering, and multi-page export (`test/batch_scanning_test.dart`).
   - `flutter analyze`: Zero static analysis issues required.
   - `flutter build apk --release --split-per-abi`: Verified clean compilation for `armeabi-v7a`, `arm64-v8a`, and `x86_64`.

---

## 10. Complete Phased Implementation Roadmap (Phases 0–12)

```text
Phase 0: Research, Audit & Blueprint ──► Phase 1: Design System & Navigation Overhaul
                                                   │
Phase 3: Image Enhancement & Modes  ◄── Phase 2: Unified Viewfinder & Persistence
      │
      ├──► Phase 4: Library, Folders & Tags
      │
      ├──► Phase 5: PDF Engine, Viewer & Compression
      │
      ├──► Phase 6: On-Device OCR & Bangla Benchmarking
      │
      ├──► Phase 7: PDF Annotations, Signatures & Redaction
      │
      ├──► Phase 8: Data Extraction (Receipts, Cards, Invoices)
      │
      ├──► Phase 9: Automated Export Routing & Workflows
      │
      ├──► Phase 10: Optional AI Document Assistant
      │
      ├──► Phase 11: Encrypted Cloud Backup & Multi-Device Sync
      │
      └──► Phase 12: Release Hardening & Store Distribution
```

| Phase | Title | Primary Deliverables | Target Priority | Status |
|---|---|---|:---:|:---:|
| **Phase 0** | **Research, Audit & Blueprint** | Competitor research report, UX redesign spec, master blueprint update | P0 | **COMPLETE** |
| **Phase 1** | **Design System & Navigation Overhaul** | Implement `surface0-3` tokens, 4-tab shell + central shutter FAB, compact Home header | P0 | **NEXT IN LINE** |
| **Phase 2** | **Unified Viewfinder & Persistence** | Consolidate ML Kit & CameraX viewfinders into one swipeable mode interface | P0 | Scheduled |
| **Phase 3** | **Image Enhancement & Modes** | Loupe magnifier corner drag, Magic Color filter, inpainting finger eraser | P0 | Scheduled |
| **Phase 4** | **Library, Folders & Tags** | Nested folders, multi-colored tags, grid/list toggle, batch selection actions | P1 | Scheduled |
| **Phase 5** | **PDF Engine, Viewer & Compression** | PDF compression optimization, in-document text search, interactive page reordering | P0 | Scheduled |
| **Phase 6** | **On-Device OCR & Bangla Evaluation** | Integrate Tesseract `ben.traineddata` for Bengali, benchmark CER/WER | P1 | Scheduled |
| **Phase 7** | **PDF Annotations, Signatures & Redaction**| Freehand pen signing, text notes, true byte-level PDF content sanitization | P2 | Scheduled |
| **Phase 8** | **Data Extraction (Cards & Invoices)** | Structured regex & ML parsing for business cards and receipt line items | P2 | Scheduled |
| **Phase 9** | **Automated Export Workflows** | Configurable one-tap export rules (e.g., Auto-B&W → Auto-Name → Share) | P2 | Scheduled |
| **Phase 10** | **Optional AI Document Assistant** | Document summarization, citation-backed Q&A, and study notes with consent | P3 | Scheduled |
| **Phase 11** | **Encrypted Cloud Backup & Sync** | Supabase opt-in account sync, upload queues, conflict resolution | P3 | Scheduled |
| **Phase 12** | **Release Hardening & Distribution** | R8 minification verification, Google Play Store AAB packaging, release notes | P0 | Scheduled |

---

## 11. Commercial Model: Free vs. Pro Feature Tiers

Scaneliq adopts a transparent, user-respecting commercial model:

| Capability Tier | Free Baseline Plan (Permanent) | Scaneliq Pro ($1.99/mo or $14.99/yr) |
|---|---|---|
| **Scanning Volume** | **Unlimited scans & pages** | **Unlimited scans & pages** |
| **Watermarks** | **Zero watermarks** | **Zero watermarks** |
| **Advertisements** | **Zero advertisements** | **Zero advertisements** |
| **Core Enhancements** | Auto-crop, Magic Color, B&W, Grayscale | All Free filters + Finger/Stain Eraser |
| **PDF Generation** | Multi-page A4 PDF & JPEG export | Multi-page A4 PDF & JPEG export |
| **PDF Tools** | Standard PDF viewing | PDF Merge, Split, Password Encryption, Watermarking |
| **OCR & Search** | On-device OCR text extraction | Searchable PDF injection & Full-text Library Indexing |
| **Organization** | Standard library search & favorites | Nested folders, color tags, smart naming templates |
| **Specialized Modes** | ID Card 2-in-1, QR Scanner | Book flattening, CountCam, Business card contact sync |
| **Cloud & Sync** | Manual export via Android Sharesheet | Automated cloud export & encrypted multi-device sync |

---

## 12. Rules for AI Coding Agents & Engineering Standards

When an AI coding agent or developer implements tasks in this repository:
1. **Strict Non-Destructive Code Edits:** Never discard working tests or existing features.
2. **Verify on Physical/Emulator Targets:** Never declare a feature "tested" unless automated tests have executed and passed.
3. **No Phantom Controls:** Every visible button, tile, or switch must perform a functional operation or display a disabled state.
4. **Preserve Clean Toolchain:** Maintain 0 issues in `flutter analyze` and 100% pass rates in `flutter test`.
5. **Atomic Commit Protocol:** Small, verified Git commits with conventional commit messages (e.g., `feat(scanner): ...`, `fix(ui): ...`).

---

## 13. Comprehensive Technical Terms Glossary

- **ACID:** Atomicity, Consistency, Isolation, Durability — database transaction guarantees.
- **ANR:** Application Not Responding — Android OS freeze warning triggered when the main thread blocks for > 5 seconds.
- **Binarization:** Converting color or grayscale pixels into binary 1-bit black and white (Otsu adaptive thresholding).
- **CER / WER:** Character Error Rate / Word Error Rate — mathematical benchmarks for OCR accuracy against ground truth.
- **Content URI:** Platform-safe Android `content://` URI managed via `FileProvider` to share files without exposing raw storage paths.
- **Deskew:** Detecting and correcting angular tilt in captured document images.
- **DPI:** Dots Per Inch — print and scan resolution metric (150 DPI = Compact, 200 DPI = Standard, 300 DPI = High-Definition).
- **Homography:** Mathematical 3×3 matrix projection mapping an angled quadrilateral into a planar rectangular view.
- **Loupe:** Circular magnifying reticle displayed above the user's touch contact point during corner adjustment.
- **PDF/A:** ISO-standardized subset of PDF designed for long-term digital preservation and archival.
- **Redaction:** Permanent cryptographic and byte-level removal of sensitive text or image content from a PDF stream.
- **Searchable PDF:** A standard PDF containing visible raster images overlaid with an invisible, selectable OCR text font layer.
- **Squircle:** A mathematical intermediate between a square and a circle (superellipse), utilized for Scaneliq's 16dp rounded card geometry.

---

## 14. Open Technical Decisions & Risk Log

| Decision ID | Open Architectural Question | Evaluated Options | Recommended Resolution & Gate |
|---|---|---|---|
| **DEC-01** | Bengali (Bangla) OCR Engine | A) Tesseract OCR with `ben.traineddata`<br>B) Google ML Kit Devanagari/Indic model<br>C) Cloud OCR API fallback | **Benchmark in Phase 6:** Prototype both local Tesseract and ML Kit; measure CER on 50 printed Bengali document samples before shipping. |
| **DEC-02** | Custom Viewfinder Edge Detection | A) ML Kit Document Scanner modal<br>B) Real-time OpenCV / ML Kit segmentation on CameraX stream | **Phase 2 Convergence:** Integrate ML Kit live frame analyzer into `continuous_camera_screen.dart` for custom branded HUD. |
| **DEC-03** | Cloud Backend Provider | A) Self-hosted Supabase<br>B) Supabase Managed Cloud<br>C) Direct Google Drive / Dropbox API | **Phase 11:** Recommend Supabase Managed Cloud for encrypted auth, relational metadata sync, and row-level security. |

---

## 15. Official Documentation & Research References

### 15.1 Flutter & Native Toolchain
- Flutter Architecture Recommendations: [https://docs.flutter.dev/app-architecture/recommendations](https://docs.flutter.dev/app-architecture/recommendations)
- Dart PDF Creation Engine: [https://pub.dev/packages/pdf](https://pub.dev/packages/pdf)
- Syncfusion Flutter PDF Engine: [https://pub.dev/packages/syncfusion_flutter_pdf](https://pub.dev/packages/syncfusion_flutter_pdf)
- PDFium Flutter Viewer (`pdfrx`): [https://pub.dev/packages/pdfrx](https://pub.dev/packages/pdfrx)
- Android ML Kit Document Scanner: [https://developers.google.com/ml-kit/vision/doc-scanner/android](https://developers.google.com/ml-kit/vision/doc-scanner/android)
- Android CameraX Documentation: [https://developer.android.com/media/camera/camerax](https://developer.android.com/media/camera/camerax)

### 15.2 Competitor Research Sources
- Adobe Scan Overview: [https://www.adobe.com/acrobat/mobile/scanner-app.html](https://www.adobe.com/acrobat/mobile/scanner-app.html) (Checked: Oct 2026)
- Acrobat Mobile Subscriptions: [https://helpx.adobe.com/acrobat/mobile/subscription-refunds/about-subscriptions.html](https://helpx.adobe.com/acrobat/mobile/subscription-refunds/about-subscriptions.html) (Checked: Oct 2026)
- Google Drive Scanner Documentation: [https://support.google.com/drive/answer/3145835](https://support.google.com/drive/answer/3145835) (Checked: Oct 2026)
- Genius Scan Pricing & Architecture: [https://thegrizzlylabs.com/genius-scan/pricing](https://thegrizzlylabs.com/genius-scan/pricing) (Checked: Oct 2026)
- SwiftScan Mobile Features: [https://swiftscan.app/en/features.html](https://swiftscan.app/en/features.html) (Checked: Oct 2026)
- Microsoft OneDrive Mobile Scanning: [https://support.microsoft.com/en-us/onedrive/scan-a-whiteboard-document-business-card-or-photo-in-onedrive-for-android](https://support.microsoft.com/en-us/onedrive/scan-a-whiteboard-document-business-card-or-photo-in-onedrive-for-android) (Checked: Oct 2026)
- CamScanner Official Portal: [https://www.camscanner.com/](https://www.camscanner.com/) (Checked: Oct 2026)

---

## 16. Ready-to-Use Implementation Brief for Future Tasks

When prompting an AI coding agent or developer for implementation:

```text
You are the implementation engineer for Scaneliq, an Android-first document scanner and PDF productivity app.
The project blueprint is in docs/Scaneliq_Master_Blueprint_Improved.md. Treat that document as the product source of truth.
Supporting specifications:
- docs/SCANELIQ_UX_REDESIGN_SPEC.md (UI/UX design system, wireframes, and screen specs)
- docs/FEATURE_TRACEABILITY_MATRIX.md (Feature tracking and priority matrix)
- docs/SCANELIQ_COMPETITOR_RESEARCH.md (Competitor benchmark and pricing data)

MISSION:
Implement Phase 1 of the roadmap:
1. Update lib/core/theme/app_theme.dart with the full semantic token suite (surface0, surface1, surface2, brandDeep #021642, brandPrimary #2563EB, brandAccent #00F0FF).
2. Restructure lib/app/main_navigation_shell.dart into the 4-tab model (Home, Files, Tools, Settings) with the elevated center Camera Shutter FAB.
3. Redesign lib/features/documents/presentation/home_screen.dart to remove the oversized 96px banner, replace stacked buttons with the Quick Mode Carousel, and render recent document cards in a responsive squircle grid.
4. Ensure all 36 automated tests pass, flutter analyze reports 0 issues, and release APK builds cleanly.
```

---

*Scaneliq Master Blueprint v2.0.0 — Verified and Established October 19, 2026.*
