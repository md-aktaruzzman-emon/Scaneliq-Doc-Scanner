# CamScanner & Adobe Scan — Comparative Design & UX Analysis

**Document Date:** November 18, 2026  
**Target Product:** Scaneliq  
**Verification Sources & Transparency Disclosure:**
1. **CamScanner (`C:\Scaneliq\Apk i use\Camscanner.apk`, `com.intsig.camscanner` v7.29.5.2611120000):** Inspected via static APK inspection (`aapt dump badging`, `AndroidManifest.xml`, ZIP asset tree, UI JSON schemas `cs_list_more_en.json` & `local_scene_recommend_data.json`, native libraries, and Flutter module assets). **Limitation:** No physical Android device or configured AVD emulator was available in this environment, so live emulator screenshots were not captured; dynamic UX flows combine APK activity/asset evidence with verified public CamScanner UI documentation.
2. **Adobe Scan:** As confirmed in earlier audits, `C:\Scaneliq\Apk i use\adobe.scan.apk` is an Uptodown App Store installer (`com.uptodown` v7.45), **not** Adobe Scan. Therefore, all Adobe Scan observations in this report are strictly derived from **official Adobe Scan product documentation and published public UX references**—not unverified APK guesses.

---

## 1. Strategic Positioning of Both Reference Apps

| Dimension | CamScanner (`v7.29.5` Static APK + Public UX) | Adobe Scan (Public Product Docs & UX Studies) | Scaneliq Opportunity |
|---|---|---|---|
| **Core Product DNA** | **Feature Powerhouse / Swiss-Army Toolkit** (404 Activities, hybrid Native + Flutter AI modules, 897 assets) | **Zero-Friction Capture Appliance** (Single-purpose scan -> auto-save -> Adobe ecosystem handoff) | **Calm, All-in-One Powerhouse** (Adobe Scan clarity + CamScanner utility breadth, zero bloat) |
| **Visual Personality** | Energetic emerald-teal (`#19C594`) + bright promotional badges, dense utility grids, Lottie/PAG animations | Restrained slate/white minimalism + signature Adobe Cobalt/Blue (`#1473E6`), generous whitespace | **Quiet Precision:** Cobalt Ink (`#1E40AF`) + Optical Emerald (`#0D9488`) on warm archival canvas (`#F6F7F9`) |
| **Onboarding / Auth Friction** | Optional sign-in prompt, aggressive VIP trial upsells (`guide_gp_premium_v6_native.json`) | **Mandatory Adobe ID / Google / Apple login gate** before first use | **Zero Mandatory Account:** Instant open-and-scan; optional local PIN/Biometrics |
| **Monetization UX Impact** | Heavy ad SDK footprint (`TT_PANGOLIN`, GDT ads, `AppLaunchAdActivity`), locked format icons (`ic_doc_*_locked_v665.webp`) | Clean UI, but locks multi-file PDF tools, compression, and >25-page OCR behind Acrobat Premium (\$9.99–\$19.99/mo) | **Clean Freemium / Pro:** Unwatermarked core PDF + full local tools free; zero third-party ads or pop-up traps |

---

## 2. Structural & APK-Verified Insights (CamScanner vs. Adobe Scan)

### A. Verified CamScanner Architecture Insights (`Camscanner.apk`)
Static analysis of `Camscanner.apk` reveals *why* CamScanner's interface behaves the way it does:
- **Hybrid Native + Flutter Architecture:** CamScanner embeds a Flutter module (`libflutter.so`, `libapp.so` at 43.5 MB, `assets/flutter_assets/packages/agent/...`) specifically for modern AI assistants, document conversion panels, and structured card workflows while keeping ultra-fast camera capture in native Android (`ImageScannerActivity`, `ModelCaptureActivity`, `BatchModeActivity`) backed by C++ libraries (`libpagescanner.so` 12.6 MB, `libmagicenhancer.so` 5.5 MB, `libopencv.so` 6.5 MB, `liblongImageStitch.so`, `libpdfium.so`).
- **Task-Grouped Tools Schema (`assets/cs_list_more_en.json`):** CamScanner organizes its "More / Tools" hub into clear grouped sections (`PDF Edit`, `Format Conversion` -> Word/Excel/PPT/Long Image, `Print & Send to PC`), rather than one undifferentiated list.
- **Visual Capture Onboarding (`assets/capture_guide2_*.jpg`):** Uses clean visual illustrated framing guides for Documents, Trimming, Enhancement, and Certificates instead of paragraphs of text.
- **Micro-Feedback Assets:** Ships dedicated Lottie/PAG state animations (`images_lottie_pagelist_edit`, `lottie_first_in_ocr_result`, `cs_ai_multi_image_edit_loading.pag`) so processing waits feel responsive and alive.
- **UX Anti-Patterns Evident in APK:** Ships `AppLaunchAdActivity`, `EmptyForFgDialogActivity`, `cancel_renew_recall_label_en.pag` (churn-prevention guilt dialogs), and locked tool badges (`ic_doc_pdf_locked_v665.webp`)—causing visual noise and user distrust.

### B. Verified Adobe Scan UX Principles (Public References)
- **Auto-Capture First:** Adobe Scan opens directly into or within 1 tap of a live auto-edge camera that displays an animated blue quadrilateral + steady indicator ("Hold steady... Looking for document") and fires the shutter automatically—removing photography guesswork.
- **Clean Bottom Mode Wheel:** A single horizontal pill/text selector (`Whiteboard`, `Book`, `Document`, `ID Card`, `Business Card`) sits directly above the shutter without surrounding neon frames.
- **Thumb-Zone Preview & Batch Counter:** Captured pages animate down into a bottom-right/left thumbnail stack badge (`1`, `2`, `3`), letting users scan 20 pages continuously without interruption.
- **Tactile Post-Capture Toolbar:** Crop uses magnified **corner loupes** (zoomed circle under the user's thumb so the finger never hides the paper corner!); Cleanup brush lets users paint out fingers/shadows cleanly; Filters are previewed visually.
- **Post-Save Context:** Tapping "Save PDF" opens a clean viewer with direct inline pill actions (`Share`, `OCR / Search`, `Open in Acrobat`, `More`) instead of hiding basic actions in a 10-item text overflow menu.

---

## 3. Fifteen-Axis Comparative UX Breakdown

| Axis | CamScanner Pattern | Adobe Scan Pattern | Scaneliq Redesign Direction |
|---|---|---|---|
| **1. Home Screen Layout** | Top search bar + quick action icon strip (Smart Scan, ID Card, PDF Tools) + promo banners + Recent Scans list | Minimal header + 2-tab switch (`Recent` / `All Scans`) + clean thumbnail cards + dual floating Camera/Gallery buttons | **Focused Workspace:** Compact greeting/brand bar → Search trigger → Clean Quick-Scan Strip (4 primary intents) → Draft Banner (only if active) → Recent 4–6 Scans + direct tab jump (`Documents`) |
| **2. Navigation** | Bottom bar: `Home` \| `Files` \| `Tools` \| `Me` + prominent floating Camera/Gallery FAB cluster on right/center | 2-tab top/bottom switch (`Home` / `All Scans`) + persistent bottom-right Camera & Gallery FABs + top-left Settings gear | **4-Tab Precision Bar + Integrated Center Scan Trigger:** `Home` \| `Documents` \| **[Scan]** \| `Tools` \| `Settings` (with long-press/chevron sheet for Gallery/PDF import) |
| **3. Scanner Experience** | Fast native viewfinder, mode selector carousel, instant single/batch switch, visual tips, dark unobtrusive HUD | Ultra-clean full-bleed viewfinder, live quad border, auto-capture countdown indicator, minimal top bar (Flash, Auto/Manual) | **Unified Camera Suite:** Merge ML Kit & `ContinuousCameraScreen` aesthetics into one edge-to-edge dark HUD (`#000000` canvas, `#0D9488` / `#2DD4BF` optical quad, top utility pill, bottom thumb-zone mode reel + shutter + gallery + page stack) |
| **4. Capture Workflow** | Tap Shutter -> Auto-crop quad preview -> Filter -> Multi-page strip -> Save | Auto-snap -> Stacks smoothly in corner thumbnail -> Tap stack -> Review Carousel (`Crop`, `Rotate`, `Filter`, `Cleanup`, `Reorder`, `Save PDF`) | **Zero-Friction Flow:** Continuous capture -> tap live page stack pill -> **Review Carousel** (swipeable full-size page cards, quick-fix toolbar) -> `Save PDF` |
| **5. Editing Interface** | Horizontal visual filter strip (`Original`, `Lighten`, `Magic Color`, `Gray`, `B&W`, `B&W2`) + 4-corner loupe crop | Clean bottom 6-icon dock (`Add Page`, `Reorder`, `Crop`, `Rotate`, `Filter`, `Cleanup`, `Resize`) with visual filter thumbnails | **Consolidate 5 Tabs -> 4 Visual Tools:** `Crop & Rotate` (with corner loupe), `Enhance` (7 **live thumbnail preview** cards unifying Filters + crisp B&W modes), `Adjust` (Brightness/Contrast/Shadow), `Erase / Redact` (Brush + Mosaic) |
| **6. PDF Experience** | Dedicated PDF viewer + bottom edit bar + rich toolbox (`Merge`, `Split`, `Compress`, `Sign`, `Watermark`, `Word/Excel`) | Crisp Acrobat-powered viewer + top Share + Search + bottom action bar (`Comment`, `Fill & Sign`, `Modify`) | **Viewer-First Dock:** Fullscreen paper viewer + subtle top bar (Title, Search, Share) + ergonomic bottom dock (`Edit`, `Organize`, `OCR`, `Tools Sheet`)—eliminating the 10-item text overflow menu |
| **7. Document Organization** | Nested folders, color tags, list/grid switch, multi-select bottom action bar | Flat/folder scans list, search by OCR text or name, date grouping, overflow actions | **Clean Library:** Collapsible filter pill strip (`All`, `Starred`, `PDFs`, `Receipts`, `Cards`, `Tags`) + single clean AppBar (`Search`, `View Toggle`, `New Folder`, `Overflow: Trash / Select`) |
| **8. Typography** | Clean sans-serif (`Roboto` / Noto), dense 12–13sp metadata, uppercase section labels | Adobe Clean geometric sans, generous vertical breathing room (`16–18sp` titles, `13sp` metadata), high legibility | **Plus Jakarta Sans** (headings) + **Inter** (UI & tabular numbers for sizes/pages/dates) + **Noto Sans Bengali** (`বাংলা` first-class legibility) |
| **9. Colors** | White cards on `#F5F6F8` gray + emerald green `#19C594` + promotional orange/gold VIP accents | `#FFFFFF` / `#F8F9FA` surfaces + `#1473E6` Adobe Blue + `#2C2C2C` dark mode slate | **Restrained Dual-Tone:** Light canvas `#F6F7F9` + white `#FFFFFF` paper cards + **Cobalt Ink `#1E40AF`** + **Optical Emerald `#0D9488`**. Dark canvas `#0B0F17` + slate `#141923` (zero neon cyan!) |
| **10. Spacing & Density** | Tighter utility grids (`8–12dp` gaps), dense 4-column icon matrices in Tools | Spacious (`16–20dp` margins, `12–16dp` vertical card rhythm) | **8dp Precision Grid:** `16dp` screen gutters, `12dp` card gaps, `24dp` section breathing room; crisp `1px` borders over heavy elevation |
| **11. Iconography** | Custom dual-tone illustrated vector icons for tools; outline icons for nav | Adobe Spectrum crisp thin-stroke rounded line icons (`1.5–1.75dp` stroke) | **Unified Rounded Line Icons (`24dp`)** inside neutral tinted wells (`#EDEFF3` / `#1D2432`) with single-hue Cobalt/Graphite tint—banning 12-color rainbow boxes |
| **12. Buttons** | Pill CTAs for VIP, solid rounded rectangles for Save/Done, floating dual FAB | Pill/capsule primary buttons (`#1473E6`), clear icon+label buttons, minimal shadows | Consistent `12dp` rounded rectangular CTAs (`48dp` height, intrinsic width in Rows, full-width only in modals) + pill filter chips (`20dp`) |
| **13. Interaction Patterns** | Long-press multi-select, swipe-to-reveal page actions, drag-and-drop grid reorder | Drag corners with finger-offset zoom loupe, horizontal page swipe, quick inline rename | Magnifying loupe on corner crop, drag-handle page reorder, long-press contextual batch dock, swipe-down dismiss on sheets, tactile haptics |
| **14. Visual Hierarchy** | High capability visibility, occasionally disrupted by VIP badges & ad cards | Unmatched calm focus on the document content itself (paper thumbnails are the hero) | **Document-First Hierarchy:** Let crisp A4 paper thumbnails & clear typographic contrast lead; tuck secondary utility choices into clean grouped Tools & sheets |
| **15. Accessibility** | Variable hit areas in dense tool grids; strong contrast on main buttons | Strict `48dp` touch zones, TalkBack labels, clear text sizing | **100% `>= 48×48dp` Hit Targets**, minimum `4.5:1` WCAG AA contrast on all tertiary text (`#6B7280` on white), dynamic font scaling up to `1.3x`, Bengali RTL/script fallbacks |

---

## 4. Key Takeaways: How Scaneliq Can Surpass Both

1. **Take Adobe Scan's Calm Paper-First Clarity:** Give document thumbnails real `1:1.41` aspect previews, generous whitespace, magnifying crop loupes, and effortless auto-capture.
2. **Take CamScanner's Specialized Productivity Breadth:** Retain Scaneliq's rich feature set (ID Card 2-in-1, Book Split, Whiteboard, Magic Color, Merge/Split/Compress/Encrypt, OCR, Receipts, Business Cards, AI Q&A, CountCam) organized into clean, visual, icon-grid workspaces rather than text-heavy `ListTile` walls.
3. **Eliminate Both Competitors' Biggest Flaws:**
   - Zero forced account login (beats Adobe Scan).
   - Zero ads, zero watermarks, zero VIP nag popups, zero rainbow clutter (beats CamScanner).
   - First-class **English + Bengali (`বাংলা`)** typography and local-first privacy vault.
