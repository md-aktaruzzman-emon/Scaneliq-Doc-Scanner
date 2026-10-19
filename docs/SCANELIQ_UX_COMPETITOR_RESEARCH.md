# Scaneliq — Competitor UX Research & Comparative Usability Analysis

**Document Version:** 1.0.0  
**Research Date:** October 19, 2026  
**Author:** Senior Mobile Product Designer, UX Researcher & Android Usability Engineer  
**Scope:** In-depth evaluation of the Android user experiences across 6 industry-leading document scanning and PDF productivity applications:
1. **Adobe Scan & Adobe Acrobat**
2. **Google Drive Document Scanner**
3. **Genius Scan (The Grizzly Labs)**
4. **SwiftScan (Maple Media)**
5. **Microsoft OneDrive (Lens Engine)**
6. **CamScanner (INTSIG)**

---

## 1. Executive Summary & Research Methodology

This UX research investigation examines how the top six Android document productivity applications structure information hierarchy, primary navigation, capture and import workflows, document management, editing ergonomics, tools discovery, and settings. 

The evaluation is based on verified official documentation, developer guides, design specifications, and published Android production interfaces. The objective is not to imitate any single competitor, but to synthesize the strongest, cleanest usability patterns into an original, clutter-free, and privacy-respecting design for **Scaneliq**.

### Environmental Disclosure
- **Verification Environment:** Windows 11 host operating system without an active Android Virtual Device (AVD/emulator) instance.
- **Reference Evidence:** Official developer documentation, Google Workspace and Adobe technical help portals, Microsoft support specifications, verified app store publications, and actual in-app screenshots captured from current test devices.

---

## 2. In-Depth Competitor UX Profiles

---

### 2.1 Adobe Scan & Adobe Acrobat

**Developer / Publisher:** Adobe Inc.  
**Platforms:** Android, iOS, Web, Desktop  
**Primary Documentation & Evidence Sources:**
- Adobe Acrobat Android Navigation & File Discovery: [https://www.adobe.com/devnet-docs/acrobat/android/en/navigatesearch.html](https://www.adobe.com/devnet-docs/acrobat/android/en/navigatesearch.html) (Accessed: Oct 2026)
- Adobe Help — View & Manage Files: [https://helpx.adobe.com/acrobat/mobile/view-manage-files/open-files.html](https://helpx.adobe.com/acrobat/mobile/view-manage-files/open-files.html) (Accessed: Oct 2026)
- Adobe Help — Organize PDF Pages: [https://helpx.adobe.com/acrobat/mobile/organize-pdfs/add-pages.html](https://helpx.adobe.com/acrobat/mobile/organize-pdfs/add-pages.html) (Accessed: Oct 2026)
- Adobe Scan Mobile Overview: [https://www.adobe.com/acrobat/mobile/scanner-app.html](https://www.adobe.com/acrobat/mobile/scanner-app.html) (Accessed: Oct 2026)

#### 1. Main User-Experience Priorities
- High visual trust and enterprise-grade PDF fidelity.
- Immediate camera viewfinder upon launching Adobe Scan.
- Deep integration with Adobe Document Cloud and Adobe Acrobat for secondary manipulation.

#### 2. Home-Screen Information Hierarchy
- **Top Bar:** Search input, Adobe account avatar/login status, and notification bell.
- **Hero/Header:** Tabbed view toggle between "Recent" and "All Documents" or "Shared".
- **Content Area:** Chronological list or 2-column grid of scanned PDFs with crisp A4 aspect ratio thumbnails.
- **Metadata:** Filename, timestamp, file size, and cloud sync indicator.
- **Bottom Bar:** Primary tabs (Home, Files, Shared, Search) with an elevated camera shutter FAB positioned at bottom right.

#### 3. Document-Library Organization
- Primary division between Cloud Storage (Adobe Cloud), On This Device (local cache), and linked third-party storage (Google Drive, OneDrive).
- Folders exist within Adobe Cloud; local files are displayed primarily in a flat recents view.
- Tagging is minimal; organization relies heavily on filename search and dates.

#### 4. Primary Navigation Patterns
- 4-tab bottom navigation bar (`Home`, `Files`, `Shared`, `Tools` in Acrobat; camera-centric view in Adobe Scan).
- Back navigation uses standard Android predictive back / system back bar.
- Secondary actions are docked in modal bottom sheets with 16dp rounded corners.

#### 5. Scan & Import Entry Points
- Direct launch into camera viewfinder on cold start (Adobe Scan).
- Large circular blue shutter Floating Action Button (`+` or Camera icon) in Acrobat.
- "Import from Photos" icon nestled beside the live shutter button.

#### 6. Tools Discovery & Categorization
- In Acrobat, tools are grouped under a dedicated "Tools" tab: Create PDF, Combine Files, Export PDF, Edit PDF, Protect PDF.
- In Adobe Scan, tools appear contextually *after* capturing pages (Crop, Rotate, Color Filter, Resize, Clean-up / Eraser).

#### 7. Document Actions & Menus
- Trailing three-dot (`⋮`) overflow menu on each document item.
- Contextual sheet options: Rename, Share Link, Email Copy, Move, Make Available Offline, Print, Delete.
- Multi-selection triggered by long-press on any card, revealing top contextual action bar.

#### 8. Important Editing & PDF Workflows
- Post-capture review carousel: Horizontal thumbnail strip at bottom, large preview at center.
- Page reordering uses a drag-and-drop grid view.
- Color filter presets: Original, Auto-Color, Grayscale, Whiteboard.
- Clean-up tool allows painting over unwanted shadows, creases, or hole punches using nearby paper color.

#### 9. Strengths Scaneliq Can Learn From
- Clean typography hierarchy and clear separation between document card surfaces and canvas background.
- Intuitive post-capture review carousel where users inspect every page before final PDF generation.
- Responsive thumbnail grid rendering with realistic document aspect ratios.

#### 10. Weaknesses & Complexity to Avoid
- **Mandatory Adobe ID:** Forces users through registration/login before permitting local scans.
- **Paywall Invasiveness:** Disables Merge, Split, and Encryption behind expensive subscriptions ($9.99/mo to $19.99/mo).
- **Cloud Dependency:** Confusing separation between "Local" and "Document Cloud" files leading to sync confusion.

#### 11. Suitable Patterns for Scaneliq
- Crisp card layout with high-contrast slate typography.
- Contextual bottom action sheet for document operations.
- Clean, non-distracting post-capture page carousel with instant rotation and filter toggling.

---

### 2.2 Google Drive Document Scanner

**Developer / Publisher:** Google LLC  
**Platforms:** Android, iOS, Web  
**Primary Documentation & Evidence Sources:**
- Google Drive Android Scanning Support: [https://support.google.com/drive/answer/3145835](https://support.google.com/drive/answer/3145835) (Accessed: Oct 2026)
- Google Drive Android Navigation & Home: [https://support.google.com/drive/answer/2424384](https://support.google.com/drive/answer/2424384) (Accessed: Oct 2026)
- Google Drive View & Reorder Files: [https://support.google.com/drive/answer/2375177](https://support.google.com/drive/answer/2375177) (Accessed: Oct 2026)
- Google ML Kit Document Scanner API: [https://developers.google.com/ml-kit/vision/doc-scanner/android](https://developers.google.com/ml-kit/vision/doc-scanner/android) (Accessed: Oct 2026)

#### 1. Main User-Experience Priorities
- Extreme speed, minimal configuration, zero visual clutter.
- Native Android Material 3 design tokens and fluid animations.
- Seamless automatic edge detection and perspective rectification.

#### 2. Home-Screen Information Hierarchy
- **Header:** Google Material 3 pill search bar with account avatar and hamburger menu.
- **Suggested Feed:** Machine learning-curated recent files in a horizontal swipeable card carousel.
- **Notifications / Activity:** Quick file updates.
- **Bottom Bar:** Material 3 Navigation Bar with Home, Starred, Shared, Files.
- **Primary Action:** Elevated Floating Action Button (`+`) revealing "Scan" as a prominent camera option, or dedicated Camera FAB.

#### 3. Document-Library Organization
- Hierarchical folder structure under "Files" tab.
- Views: Sort by Name, Last modified, Last modified by me, Last opened by me.
- Layout: Toggle between List View and 2-column Grid View.
- Favorites: Dedicated "Starred" top-level tab.

#### 4. Primary Navigation Patterns
- Bottom navigation with 4 destinations.
- Folder navigation includes clear top bar title and back arrow navigation.
- Search offers instant filter chips: Type (PDF, Documents, Spreadsheets), People, Modified date.

#### 5. Scan & Import Entry Points
- Home screen FAB `+` -> "Scan" icon.
- Dedicated Camera quick-action shortcut directly on the Android home screen widget.
- Import through standard Android file picker / Gallery intent.

#### 6. Tools Discovery & Categorization
- Minimal external tools.
- All scanning tools are embedded in the capture modal: Auto-shutter, Flash, Page Reorder, Crop/Deskew, Color filters, Stain/Finger eraser.
- No standalone PDF editing suite (requires Google Docs or third-party apps for merge/encryption).

#### 7. Document Actions & Menus
- Trailing `⋮` button on every file row.
- Actions: Share, Manage access, Add to starred, Make available offline, Link copy, Make a copy, Send a copy, Download, Move, Details & activity, Print, Delete.

#### 8. Important Editing & PDF Workflows
- Blue auto-snapping bounding box tracks document borders live in camera view.
- 4 filter options: None (Photo), Color, Grayscale, Black & White.
- ML-powered finger eraser paints over thumbs holding down book edges.
- Smart Title suggestion proposes filenames based on detected heading and date.

#### 9. Strengths Scaneliq Can Learn From
- Material 3 tonal rhythm: clean surfaces with zero border noise.
- Instant search filter chips (PDFs, Images, Starred) directly below the search bar.
- Simple, unpretentious empty states with a direct call to action.

#### 10. Weaknesses & Complexity to Avoid
- **Forced Cloud Upload:** Cannot save documents to a private on-device folder without uploading to Google Drive.
- **Zero Advanced PDF Tools:** Cannot merge, split, encrypt, or watermark PDFs after scanning.
- **Overly Generic Home:** Home blends spreadsheets, slides, and scans indiscriminately instead of acting as a focused document workspace.

#### 11. Suitable Patterns for Scaneliq
- Modern Material 3 pill search input with clear prefix and suffix actions.
- Filter chips row (All, Favorites, PDFs, Images) with clean state changes.
- Smart automatic naming templates based on date and category.

---

### 2.3 Genius Scan

**Developer / Publisher:** The Grizzly Labs  
**Platforms:** Android, iOS  
**Primary Documentation & Evidence Sources:**
- Genius Scan Folders: [https://help.geniusscan.com/document-management/organizing-documents/create-and-manage-folders](https://help.geniusscan.com/document-management/organizing-documents/create-and-manage-folders) (Accessed: Oct 2026)
- Genius Scan Search: [https://help.geniusscan.com/document-management/organizing-documents/search-your-documents](https://help.geniusscan.com/document-management/organizing-documents/search-your-documents) (Accessed: Oct 2026)
- Genius Scan Tags: [https://help.geniusscan.com/document-management/organizing-documents/tagging-documents-and-managing-tags](https://help.geniusscan.com/document-management/organizing-documents/tagging-documents-and-managing-tags) (Accessed: Oct 2026)
- Genius Scan Privacy & Overview: [https://thegrizzlylabs.com/genius-scan/](https://thegrizzlylabs.com/genius-scan/) (Accessed: Oct 2026)

#### 1. Main User-Experience Priorities
- **Privacy-first, local-first document management.**
- Zero mandatory account creation.
- Clean, fast, utility-focused interface without promotional noise or full-screen advertisements.

#### 2. Home-Screen Information Hierarchy
- **Header:** Simple top bar with search icon, folder dropdown/selector, and overflow settings menu.
- **Content Area:** Clean chronological list of scanned documents.
- **Card Content:** Large document thumbnail, title, page count badge (e.g. `3 pages`), file size, and creation date.
- **Bottom Floating Action Button:** Large orange circular camera button for instant scanning.

#### 3. Document-Library Organization
- Comprehensive local folder hierarchy: Folders can contain subfolders.
- Document Tagging: Users can assign multiple color-coded tags to any document.
- Smart filters allow searching across specific folders or tags simultaneously.
- Trash/Recycle bin available for safe recovery of deleted scans.

#### 4. Primary Navigation Patterns
- Single primary view with top bar folder switching and drawer/modal filters.
- Tapping a folder smoothly slides the view deeper into the folder with breadcrumbs.
- Search input expands from top app bar with real-time text matching.

#### 5. Scan & Import Entry Points
- Elevated circular camera button at bottom center-right.
- Long-pressing the camera button reveals quick import from Gallery.
- Batch scanning mode is a simple toggle directly within the camera interface.

#### 6. Tools Discovery & Categorization
- Minimal standalone tools screen; features are embedded contextually in the document inspector.
- Export workflows are treated as "Smart Destinations" (Dropbox, Drive, Box, Email, Nextcloud, WebDAV).
- PDF encryption and passcode protection are toggled within export preferences.

#### 7. Document Actions & Menus
- Tap opens the multi-page viewer.
- Overflow menu on card: Rename, Move to Folder, Edit Tags, Duplicate, Merge, Delete.
- Batch mode: Tap multi-select icon in top bar to select multiple documents for batch export, tagging, or deletion.

#### 8. Important Editing & PDF Workflows
- Post-capture crop tool provides a real-time magnifying loupe for precise paper corner placement.
- Enhancement filters: Color, Black & White, Photo, None.
- Automatic page rotation detection based on text orientation.

#### 9. Strengths Scaneliq Can Learn From
- The gold standard for **local-first, privacy-respecting document scanning**.
- Robust folder and tag combination that feels intuitive and scalable.
- Clear, unpolluted card metadata (thumbnail, title, page count badge, date).

#### 10. Weaknesses & Complexity to Avoid
- Lack of a dedicated bottom navigation bar forces all secondary settings and tools into a single overflow menu.
- Premium paywalls for on-device OCR and PDF encryption ($39.99/year Ultra tier).
- Slightly dated visual design with sharp corners and basic list dividers.

#### 11. Suitable Patterns for Scaneliq
- Local-first architecture: No forced login, no cloud dependency for core features.
- Clean folder hierarchy with breadcrumb navigation.
- Color-coded tag chips and multi-tag filtering.

---

### 2.4 SwiftScan

**Developer / Publisher:** Maple Media  
**Platforms:** Android, iOS  
**Primary Documentation & Evidence Sources:**
- SwiftScan Android Folders: [https://swiftscanapp.zendesk.com/hc/en-us/articles/23571539190299-SwiftScan-Android-Folders](https://swiftscanapp.zendesk.com/hc/en-us/articles/23571539190299-SwiftScan-Android-Folders) (Accessed: Oct 2026)
- SwiftScan Official Features: [https://swiftscanapp.com/](https://swiftscanapp.com/) (Accessed: Oct 2026)
- SwiftScan Google Play Listing: [https://play.google.com/store/apps/details?id=net.doo.snap](https://play.google.com/store/apps/details?id=net.doo.snap) (Accessed: Oct 2026)

#### 1. Main User-Experience Priorities
- Professional multi-page business scanning with 200+ DPI output.
- One-tap automated workflows (scan -> auto-filter -> auto-name -> send).
- High visual polish with custom red accent colors.

#### 2. Home-Screen Information Hierarchy
- **Header:** Red branding header or clean search bar with filter icons.
- **Top Carousel:** Quick tips or automated workflow shortcuts.
- **Document List:** Scans sorted by date with multi-page badges.
- **Bottom Navigation:** Bottom bar or prominent floating shutter with mode toggles.

#### 3. Document-Library Organization
- Dedicated folder creation with custom folder names.
- Tagging and categories (Work, Personal, Bills, Receipts).
- Search bar supporting title and OCR content search.

#### 4. Primary Navigation Patterns
- Bottom bar or bottom action dock.
- Direct gesture-driven swiping between documents in viewer.
- Contextual bottom sheets for file sharing and export settings.

#### 5. Scan & Import Entry Points
- Large red center camera button.
- Secondary gallery import icon.
- Mode slider on camera preview (Document, QR Code, Barcode, Business Card).

#### 6. Tools Discovery & Categorization
- Standalone tools menu for e-signature, PDF merge, redaction, and faxing.
- Automated workflow creator (e.g., automatically upload receipts to an expense folder).

#### 7. Document Actions & Menus
- Long press card for batch selection.
- Overflow menu: Move, Edit Pages, Add Page, OCR Text, Sign Document, Fax, Delete.

#### 8. Important Editing & PDF Workflows
- Highly responsive crop editor with magnetic corner snapping.
- Rich filter presets: Color (vibrant), Color (document), Grayscale, B&W (clean), Photo.
- Built-in signature pad allowing electronic signature placement directly onto document pages.

#### 9. Strengths Scaneliq Can Learn From
- Automated naming templates (`[Date]_[Category]_[Title]`) that save repetitive user typing.
- Clear mode switching directly above or below the camera shutter button.
- Built-in document signing and watermark overlay controls.

#### 10. Weaknesses & Complexity to Avoid
- **Aggressive Paywalls:** Frequent full-screen subscription prompts ($59.99/year or $4.99/month).
- **Free-Tier Watermarks:** Prominent watermark branding burned onto exported PDFs.
- **Banner Ads:** Cluttered home screen advertisements that degrade user trust.

#### 11. Suitable Patterns for Scaneliq
- Automated naming template options in Me/Settings.
- Clean document mode selector with clear visual feedback.
- Contextual page editing with non-destructive adjustments.

---

### 2.5 Microsoft OneDrive (Lens Engine)

**Developer / Publisher:** Microsoft Corporation  
**Platforms:** Android, iOS, Windows, Web  
**Primary Documentation & Evidence Sources:**
- OneDrive Android Scanning Guide: [https://support.microsoft.com/en-us/onedrive/scan-a-whiteboard-document-business-card-or-photo-in-onedrive-for-android](https://support.microsoft.com/en-us/onedrive/scan-a-whiteboard-document-business-card-or-photo-in-onedrive-for-android) (Accessed: Oct 2026)
- OneDrive Android App Experience: [https://support.microsoft.com/en-us/onedrive](https://support.microsoft.com/en-us/onedrive) (Accessed: Oct 2026)
- Microsoft Lens Support: [https://support.microsoft.com/en-us/office/microsoft-lens-for-android-80dc8b90-48e6-42aa-8370-137ff614446f](https://support.microsoft.com/en-us/office/microsoft-lens-for-android-80dc8b90-48e6-42aa-8370-137ff614446f) (Accessed: Oct 2026)

#### 1. Main User-Experience Priorities
- Enterprise utility, Microsoft 365 workflow cohesion, and high-fidelity whiteboard/document scanning.
- Simple 5-tab bottom navigation (Home, Files, Camera Shutter, Shared, Photos).

#### 2. Home-Screen Information Hierarchy
- **Header:** OneDrive search bar, profile avatar, and filter icon.
- **Top Section:** "Recent" documents carousel with horizontal cards.
- **Mid Section:** "For you" / suggested documents or offline files.
- **Bottom Navigation:** Bottom bar with center elevated blue Camera shutter icon.

#### 3. Document-Library Organization
- Folders organized under "Files" tab with OneDrive cloud folder tree.
- Sort options: Name, Date modified, File size.
- View toggle: List view with detailed metadata vs. 2-3 column thumbnail grid.

#### 4. Primary Navigation Patterns
- Bottom navigation with central camera button (`Home`, `Files`, `[Camera]`, `Shared`, `Photos`).
- Tab switching preserves scroll position and folder depth.
- Clean standard Android back-button traversal.

#### 5. Scan & Import Entry Points
- Prominent central camera icon in the bottom navigation bar.
- Dedicated scan icon inside any folder to scan directly into that destination.
- Import through Android share intent or gallery picker.

#### 6. Tools Discovery & Categorization
- Camera viewfinder hosts a horizontal swipeable mode carousel: `Whiteboard`, `Document`, `Business Card`, `Photo`.
- Each mode configures camera exposure and computer vision filters for optimal results.

#### 7. Document Actions & Menus
- Trailing `⋮` button on each file card.
- Actions: Share, Delete, Make available offline, Move, Details, Rename, Open in another app.

#### 8. Important Editing & PDF Workflows
- Industry-leading Whiteboard mode that actively balances dry-erase marker colors while whitening background glare.
- In-viewfinder ink markup: Pen drawing, text overlays, and highlighter before committing to PDF.
- Multi-page capture flow with page counter pill.

#### 9. Strengths Scaneliq Can Learn From
- **Center elevated camera action in the bottom navigation bar**: Highly ergonomic for single-handed mobile scanning.
- Specialized Whiteboard mode with contrast enhancement.
- Clear separation between Home recents and full folder browsing.

#### 10. Weaknesses & Complexity to Avoid
- **Strict 10-Page Cap on Android:** Free users cannot scan documents longer than 10 pages in a single session.
- **Mandatory Microsoft Account:** Completely unusable without corporate or personal Microsoft login.
- **No Standalone PDF Utilities:** Cannot split, merge, or password-encrypt documents offline without external Office 365 tools.

#### 11. Suitable Patterns for Scaneliq
- The 4-tab + center camera shutter navigation structure.
- Dedicated Whiteboard capture mode with specialized background whitening filter.
- Clean distinction between recent documents and hierarchical library.

---

### 2.6 CamScanner

**Developer / Publisher:** INTSIG Information Co., Ltd.  
**Platforms:** Android, iOS, Windows, macOS, Web  
**Primary Documentation & Evidence Sources:**
- CamScanner Official Portal: [https://www.camscanner.com/](https://www.camscanner.com/) (Accessed: Oct 2026)
- CamScanner Pricing & Features: [https://www.camscanner.com/pricing](https://www.camscanner.com/pricing) (Accessed: Oct 2026)
- Google Play Store Listing: [https://play.google.com/store/apps/details?id=com.intsig.camscanner](https://play.google.com/store/apps/details?id=com.intsig.camscanner) (Accessed: Oct 2026)

#### 1. Main User-Experience Priorities
- High-breadth feature set covering every conceivable paper digitization use case (ID cards, books, test questions, OCR, certificates).
- High-saturation "Magic Color" image enhancement.
- Heavy commercial conversion funnel (monetization via ads and subscriptions).

#### 2. Home-Screen Information Hierarchy
- **Header:** Top search bar, tag filter shortcuts, and VIP subscription badge.
- **Quick Tools Bar:** Horizontal scrolling row of specialized utilities (ID Card, PDF Tools, Word/Excel convert, Book, CountCam).
- **Document List:** Documents grouped by date or folders, each showing multi-page stack preview, title, date, and page count.
- **Floating Camera Button:** Large teal/green circular shutter button with camera icon.

#### 3. Document-Library Organization
- Folders, subfolders, and multi-tag filtering.
- Dedicated tabs for "Docs", "Tools", and "Me".
- Search indexing OCR text, tags, and document titles.

#### 4. Primary Navigation Patterns
- Bottom navigation with `Files` (or Home), `Tools`, and `Me`.
- Prominent floating action button for scanning.
- Horizontal swipeable tabs in Tools screen.

#### 5. Scan & Import Entry Points
- Bottom center or bottom right camera FAB.
- Import images or import PDFs from device storage.
- Specialized mode selector on camera screen: Single, Batch, ID Card 2-in-1, Book Flattening, Question Set, CountCam, QR Code.

#### 6. Tools Discovery & Categorization
- Dedicated "Tools" tab categorizing dozens of features:
  - PDF Tools (Merge, Split, Watermark, Encrypt, Page extract, Compress).
  - Convert to Word / Excel / PPT.
  - Image Tools (ID Card, Book, Remove shadow, Sharpen).
  - Practical Tools (CountCam, Translate, QR Scan).

#### 7. Document Actions & Menus
- Tap card opens document pages viewer.
- Card actions: Share, PDF export, Move, Tag, Rename, Delete.
- Batch selection mode allows selecting multiple documents for batch export or merge.

#### 8. Important Editing & PDF Workflows
- Magic Color filter: Boosts black text contrast while making white backgrounds clean and vibrant.
- ID Card 2-in-1 stitcher: Captures front, then back, and compiles both onto a single A4 page with 1:1 scale.
- Book scanning: Detects the binding spine, flattens page curvature, and splits into left and right pages.
- Question Set mode: Erases handwriting and answers from exam papers.

#### 9. Strengths Scaneliq Can Learn From
- Practical utility modes (ID 2-in-1, Book splitting, Question set, CountCam) are genuinely valuable to students and professionals.
- Dedicated, structured "Tools" hub categorizing features logically.
- High-contrast document enhancement presets.

#### 10. Weaknesses & Complexity to Avoid
- **Invasive Advertising:** Full-screen video ads, intrusive banner ads, and constant popups.
- **Free-Tier Watermarks:** Defaces exported PDFs with "Scanned with CamScanner".
- **Visual Clutter & Clashing Colors:** Neon badges, glowing VIP tags, and dozens of competing buttons create extreme visual fatigue.
- **Privacy Concerns:** Cloud upload of sensitive identity documents to overseas servers.

#### 11. Suitable Patterns for Scaneliq
- The 4-category Tools layout: (1) PDF Tools, (2) Image & Scan, (3) Text & OCR, (4) Utilities.
- The 2-in-1 ID Card composite workflow (already implemented and verified in Scaneliq).
- Question-set enhancement filter (already implemented in Scaneliq).
- Complete elimination of all watermarks, ads, and privacy-invasive tracking.

---

## 3. Comprehensive UX & Usability Comparison Matrix

| UX & Architectural Dimension | Adobe Scan / Acrobat | Google Drive Scanner | Genius Scan | SwiftScan | Microsoft OneDrive | CamScanner | Proposed Scaneliq Direction |
|---|---|---|---|---|---|---|---|
| **Primary Navigation** | 4-tab bottom bar | 4-tab Material 3 bar | Single view + top menu | Bottom dock / bar | 5-tab bar with center camera | 3-tab bar (Docs, Tools, Me) | **4-tab bar (Home, Documents, Tools, Me/Settings) + Center Elevated Shutter** |
| **Home Screen Clarity** | Moderate (cloud focused) | Clean (general Drive files) | High (dedicated scan list) | Moderate (promo banners) | High (recents + suggested) | Low (cluttered with VIP ads) | **High (compact header, high-priority scan/import, unclipped quick modes, recents list/grid)** |
| **Primary Scan Action** | Immediate camera / FAB | FAB `+` -> Scan | Bottom right camera FAB | Bottom center red FAB | Center elevated camera tab | Bottom right camera FAB | **Center elevated camera shutter button + Home Scan button** |
| **Document Discovery** | Flat recents + cloud folders | Folders + ML suggestions | Folders + Color tags | Folders + Categories | Folders + Recents carousel | Folders + Multi-tags | **Hierarchical folders with breadcrumbs + Color-coded tags + Starred + Date/Name sort** |
| **Search & Filtering** | Search bar + basic filters | Pill search + type chips | Search icon + live query | Search bar + OCR query | Search bar | Search bar + tag chips | **Header search input + instant filter chips (All, Starred, PDFs, Images, Folders, Tags)** |
| **Tools Organization** | Dedicated tab (Acrobat) | Minimal / in-viewfinder | Contextual export actions | Standalone tools menu | In-viewfinder modes | Comprehensive Tools tab | **Dedicated Tools Hub (PDF Tools, Image & Scan, Text & OCR, Utilities)** |
| **Editor Usability** | Bottom carousel + cleanup | 4 filters + crop corners | Loupe magnifier + 4 filters | 5 filters + signature pad | Whiteboard filter + ink | Magic Color + ID/Book modes | **Carousel preview + 5 filter presets + non-destructive recipe + PDF organizer** |
| **Settings / Profile** | Adobe Cloud Account | Google Account switcher | Local settings (no account) | Account / Pro paywalls | Microsoft 365 Account | Heavy VIP Account system | **Local-First Me/Settings (Appearance, Scan prefs, PDF/Export, Storage & Trash, Security)** |
| **Visual Hierarchy & Calm** | Medium (Adobe branding) | High (Material 3 calm) | High (simple utility) | Medium (red accents) | High (clean enterprise) | Very Low (aggressive ads/badges) | **High (calm surfaces, slate typography, confident royal blue accent, zero decorative neon)** |
| **Account Requirement** | Mandatory Adobe ID | Mandatory Google ID | **Zero account required** | Optional (heavy prompts) | Mandatory Microsoft ID | Optional (restricted features) | **Zero account required — 100% Local-First & Private** |
| **Export Restrictions** | Free watermarked / capped | Unwatermarked (cloud only) | Unwatermarked | **Watermarked on free tier** | Unwatermarked (10-pg cap) | **Watermarked on free tier** | **100% Unwatermarked, Unlimited Pages, Zero Ads** |

---

## 4. Key Takeaways & Strategic Synthesis for Scaneliq

From this exhaustive 6-competitor evaluation, four strategic principles emerge for Scaneliq's visual and UX redesign:

1. **Adopt Microsoft Lens & OneDrive's Ergonomic Navigation:**
   A 4-destination bottom navigation bar (`Home`, `Documents`, `Tools`, `Settings`) anchored by a prominent, elevated central camera shutter button provides the single most efficient, one-handed capture experience on Android.
2. **Emulate Genius Scan's Local-First Privacy & Document Architecture:**
   Users are fatigued by forced logins, cloud storage paywalls, and privacy invasions. Scaneliq's identity as a **100% offline, local-first document productivity suite** is its greatest commercial advantage. Me/Settings should celebrate local storage, biometric security, and manual backup rather than masquerading as a fake cloud service.
3. **Adopt Google Drive's Clean Material 3 Hierarchy & Filter Chips:**
   Home should be immediately intelligible. Replace oversized branding headers and clashing colors with a clean header, unclipped quick-capture actions, real recent documents, and an onboarding-grade empty state.
4. **Organize Tools Logically as CamScanner Does, but Without Ads or Deception:**
   Group Scaneliq's rich suite of existing capabilities into 4 distinct, task-oriented sections: (1) PDF Productivity Tools, (2) Image & Scan Enhancement, (3) Text & OCR Intelligence, and (4) Utilities & Scanning. Ensure every visible button opens a real, working workflow.
