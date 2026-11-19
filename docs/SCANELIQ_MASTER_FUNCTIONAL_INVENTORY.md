# SCANELIQ — MASTER FUNCTIONAL INVENTORY & POST-REPAIR AUDIT LEDGER

**Generated / Updated:** November 19, 2026  
**Workspace Authoritative Source:** Local workspace `C:\Scaneliq` (`main` @ `624b607`, Version `2.67.0+26700`, `backup/pre-remediation` @ `c48e69f`)  
**Baseline Tool Checks Verified Prior to Repair:**
- `flutter pub get`: resolved cleanly (`0` conflicts)
- `flutter analyze`: `No issues found!`
- `flutter test --reporter expanded`: `201` passed, `0` failed, `0` skipped
- `flutter build apk --debug`: `Exit 0` (`102.0s`)
- `flutter devices` / `flutter emulators`: `0` Android devices or AVDs attached on host (`Windows`, `Chrome`, `Edge` only)

**Post-Repair Verification Checkpoints (Current Workspace State):**
- `dart format lib test`: `Formatted 108 files (0 changed)`
- `flutter analyze --no-pub`: `No issues found!` (`0` errors, `0` warnings, `0` infos)
- `flutter test --no-pub --reporter expanded`: `205` passed, `0` failed, `0` skipped across `34` test suites (includes `test/repair_regression_workflows_test.dart`)
- `flutter build apk --debug --no-pub`: `Exit 0` (`40.3s` -> `build\app\outputs\flutter-apk\app-debug.apk`)
- Release split APKs (`flutter build apk --release --split-per-abi --no-pub`): Exit `0` (`110.7s`, R8 minification & resource shrinking active) -> `app-armeabi-v7a-release.apk` (`80,210,628` bytes / `76.5 MB`), `app-arm64-v8a-release.apk` (`100,232,720` bytes / `95.6 MB`), `app-x86_64-release.apk` (`106,338,680` bytes / `101.4 MB`).

---

## 1. Documentation Authority & Conflict Resolution

| Authority Tier | Documents Classified | Rule Applied |
|---|---|---|
| **Current UX & Visual Identity Spec** | `research-output/SCANELIQ_OFFICIAL_DESIGN_SYSTEM.md`, `SCANELIQ_COMPLETE_SCREEN_DESIGN_SPEC.md`, `SCANELIQ_COMPLETE_SCREEN_INVENTORY.md`, `SCANELIQ_NAVIGATION_AND_USER_FLOWS.md`, `SCANELIQ_FLUTTER_UI_ARCHITECTURE.md`, `SCANELIQ_COMPONENT_LIBRARY.md`, `docs/SCANELIQ_BRANDING_UPDATE_REPORT.md` | **Concept A — Editorial Gallery Minimal** (`Gallery Alabaster #FAF9F6`, `Carbon Studio #0D0E11`, `International Ultramarine #0052FF / #3B82F6`), 3-tab shell (`Scans`, `Folders`, `PDF Suite`), `scaneliq_logo_master.png` (`2.67.0+26700`). |
| **Current Product Spec & Security Architecture** | `docs/Scaneliq_Master_Blueprint_Improved.md`, `docs/FEATURE_BACKLOG.md` (F-00..F-47), `docs/FEATURE_TRACEABILITY_MATRIX.md`, `docs/SCANELIQ_PHASE5_RELEASE_CANDIDATE_REPORT.md`, `research-output/SCANELIQ_PHASE1..5_*_REPORT.md` | Authoritative feature behavior, PBKDF2-100k PIN/V2 AES-256-CBC EtM crypto, non-destructive `EditRecipe` v2, honest PDF Visual Masking vs Raster/Flattened pixel zeroing, Concept A Phase 1–5 specs. |
| **Remediation & Audit Snapshots** | `docs/SCANELIQ_FINAL_REPAIR_REPORT.md`, `docs/SCANELIQ_FUNCTIONAL_AUDIT.md`, `docs/SCANELIQ_FUNCTIONAL_AUDIT_REPORT.md`, `docs/SCANELIQ_PHASE3..4_*_REPORT.md`, `research-output/SCANELIQ_COMPLETE_FEATURE_AUDIT.md`, `SCANELIQ_REMEDIATION_FINAL_REPORT.md`, `SCANELIQ_REMAINING_BLOCKERS.md` | Used as historical context and baseline audit ledger; **overruled whenever live code inspection disproves a claim**. |
| **Superseded / Historical / Outdated** | `README.md`, `docs/archive/Scaneliq_Master_Blueprint_Improved_original_backup_20261019.md`, `docs/IMPLEMENTATION_STATUS.md`, `research-output/SCANELIQ_COMPLETE_UX_REDESIGN_SPEC.md` (earlier 32-screen "Precision Paper" draft before Concept A) | Preserved historically; **never** used to override Concept A or latest Phase 1–5 / Stage 1–12 behavior. |

### Key Documentation Conflicts Resolved Against Live Code
1. **Scan Modes vs Hub Accessibility:** Camera Studio supports 6 `ScanMode` values (`document`, `batch`, `idCard`, `book`, `whiteboard`, `questionSet`), yet `HomeScreen` only enters `ScanMode.batch` and `ToolsScreen` only exposes `ScanMode.document`.
2. **Tools Hub Disconnected Stubs vs Implemented Features:** `tools_screen.dart` still renders `"Share & Export"` as a toast-only message and `"Cloud Backup & Multi-device Sync"` as `onTap: null` / `PLANNED`, contradicting implemented sharing, WebDAV sync, and E2EE sync features.
3. **Export Options & Smart Filename Promises (`F-18`, `F-38`):** Docs specify Quality DPI presets (`Compact 150 / Balanced 200 / High 300 DPI`), Page Size (`A4 / Letter`), Searchable OCR toggle/script, and Smart Filename token pills (`[Date]`, `[Category]`, `[Time]`, `[Counter]`), none of which are exposed interactively in `ReviewPagesScreen` or `SettingsScreen`.
4. **Live Code Defect Contradicting `FINAL_REPAIR_REPORT` & `PHASE4_REPORT`:** Inspection of `PdfService.generatePdf` (`lib/features/pdf/data/pdf_service.dart:172`) and `exportPageAsJpeg` (`line 353`) revealed a **double-processing bug**: they load `page.processedPath ?? page.originalPath` AND apply `page.editRecipe` a second time (causing double rotation, double crop, and filter stacking on edited scans).

---

## 2. Newly Discovered & Repaired Execution-Chain Defects

| Defect ID | Severity | Location | Broken Baseline Chain | Post-Repair Resolution & Verification | Status |
|---|---|---|---|---|---|
| **DEF-LIVE-01** | **P0** | `lib/features/pdf/data/pdf_service.dart`, `document_viewer_screen.dart`, `scan_preferences_service.dart` | `updatePageRecipe` already renders `editRecipe` to `processedPath`; `generatePdf` / `exportPageAsJpeg` / `_exportPagesAsImages` loaded `processedPath` and re-applied `editRecipe`, causing double rotation (`90°->180°`), double crop, and double brightness/contrast, while ignoring DPI/format presets. | Added `PdfService.resolveSinglePassSource(page)` (always reads `originalPath` + `editRecipe` once; falls back to `processedPath` + clean recipe only if original is missing), wired `PdfQualityPreset` (`150/200/300 DPI`) & `PdfPageFormatOption` (`A4/Letter`), and routed `_exportPagesAsImages` through `PdfService.exportPageAsJpeg`. Verified in `repair_regression_workflows_test.dart`. | **REPAIRED & VERIFIED** |
| **DEF-LIVE-02** | **P0** | `lib/features/documents/data/batch_merge_service.dart` | `mergeDocuments` shared `originalPath` strings from source documents without cloning files; permanently deleting a source document deleted the merged document's source page files on disk. | Added isolated cloning of each merged page via `AppStorageService.instance.copyToOriginals(...)` and returned `newDoc.copyWith(exportPath: pdfFile.path, pages: combinedPages)`. Verified in `repair_regression_workflows_test.dart`. | **REPAIRED & VERIFIED** |
| **DEF-LIVE-03** | **P1** | `pdf_tools_screen.dart`, `pdf_page_organizer_screen.dart`, `document_viewer_screen.dart` | `_stitchLongImage()` wrote a `.jpg` path into PDF `exportPath`; `PdfToolsScreen`, `DocumentViewerScreen`, and `PdfPageOrganizerScreen` skipped provider invalidation; `_showSuccessDialog` leaked raw filesystem path; `_showEncryptDialog` skipped DB/state update; `_regeneratePdf` dropped OCR layer. | Fixed `_stitchLongImage` to save a real raster `ScannedDocument` with copied `originalPath` (`exportPath: null`), added `_registerSplitFilesInVault`, persisted extracted organizer PDFs in SQLite, added `_invalidateLibraryProviders()`, sanitized success dialog to basename/byte size, updated viewer active document & DB on encryption, and preserved searchable OCR boxes on `_regeneratePdf`. | **REPAIRED & VERIFIED** |
| **DEF-LIVE-04** | **P1** | `home_screen.dart`, `scaneliq_document_widgets.dart` | Home `_shareDocument` refused to share scans lacking `exportPath`; Home `⋯` menu lacked Rename/Move to Folder; multi-select `"Folders"` button discarded selection; draft folio lacked `"Discard Draft"`. | `_shareDocument` now compiles missing PDFs on demand and persists `exportPath`; `_showDocumentActionsSheet` adds `Rename & Smart Name` & `Move to Folder`; `_buildSelectionActionDock` provides live batch `Move`, `Merge`, & `Trash`; `ScaneliqFeaturedFolioCard` exposes wired `_discardDraft`. | **REPAIRED & VERIFIED** |
| **DEF-LIVE-05** | **P1** | `lib/features/settings/presentation/tools_screen.dart` | `"Share & Export"` only showed a toast; `"Cloud Backup & Multi-device Sync"` was non-tappable (`onTap: null`); `ID Card 2-in-1`, `Book Spread`, `Whiteboard`, `Question Set`, `PDF to Images`, and `Redact & Mosaic Studio` lacked Tools Hub entry points. | Wired live `_openShareExportSheet()` vault picker + auto-PDF compile/share; wired `WebDAV & Encrypted Vault Sync` to Settings; added **Specialized Capture Modes** (`ID Card 2-in-1 Sheet`, `Book Spread Split`, `Whiteboard Glare Clean`, `Exam / Question Set Scan`), `PDF to Images (JPEG)`, `Redact & Mosaic Studio`, and `Pixel / Mosaic Image Redactor`. Verified via `repair_regression_workflows_test.dart` & `navigation_and_screens_test.dart`. | **REPAIRED & VERIFIED** |
| **DEF-LIVE-06** | **P1** | `lib/features/editor/presentation/review_pages_screen.dart` | Missing Quality DPI (`150/200/300`), A4/Letter & OCR script options, Smart Filename token pills in title sheet, Quick Batch Filter strip (`applyFilterToPages`), and Book Spread split action on imported photos. | Initialized defaults from `ScanPreferencesService`, added `PDF Export Options` modal (DPI, Page Size, Searchable OCR toggle + script), Smart Filename token chips (`+ Smart Template`, `+ [Date]`, `+ [Time]`), Quick Batch Filter strip, and `Split Spread` card action. | **REPAIRED & VERIFIED** |
| **DEF-LIVE-07** | **P1** | `settings_screen.dart`, `app_storage_service.dart`, `scan_preferences_service.dart` | Static `"Default Page Format"`, `"Auto-Crop"`, `"OCR Languages"`; zero Smart Filename template selector; zero Storage Breakdown MB metrics + cache cleanup action; zero persisted `ScanPreferencesService`. | Created & initialized `ScanPreferencesService` in `main.dart`; added `StorageUsageBreakdown`, `calculateStorageBreakdown()`, and `clearTemporaryCache()` in `AppStorageService`; wired live storage breakdown & cleanup dialog plus interactive selectors in `SettingsScreen`. Verified in `repair_regression_workflows_test.dart`. | **REPAIRED & VERIFIED** |
| **DEF-LIVE-08** | **P2** | `ai_document_sheet.dart`, `business_card_service.dart`, `receipt_dialog.dart` | Image pickers hardcoded default Latin script instead of honoring `ScanPreferencesService.defaultOcrScript`, breaking Bengali card/receipt/document scans from those modals. | Updated `BusinessCardService` default script to `OcrScript.mixedBengaliEnglish` and wired `AiDocumentSheet` + pickers to pass `ScanPreferencesService.instance.defaultOcrScript`. | **REPAIRED & VERIFIED** |

---

## 3. Complete Discovered Functional Inventory

### Group 1 — UX Foundation & Navigation (F-00 + Shell Specs)
1. **F-00: Concept A Design System & Tokens** — `scaneliq_colors.dart`, `scaneliq_tokens.dart`, `scaneliq_radius.dart`, `scaneliq_spacing.dart`, `scaneliq_typography.dart`, `app_theme.dart`. Entry: Global. Expected: Alabaster Light / Carbon Studio Dark / Ultramarine accent + persistent `themeModeProvider`. Baseline: **WORKING**.
2. **NAV-01: 3-Tab `StatefulShellRoute` Shell & Router** — `app_router.dart`, `main_navigation_shell.dart`. Entry: Root app launch (`Scans`, `Folders`, `PDF Suite`). Expected: Switch tabs without state loss, push `/settings`, `/review-pages`, `/trash`. Baseline: **WORKING**.
3. **NAV-02: Official Scaneliq Brand Identity & Launcher Icons** — `scaneliq_logo.dart`, `assets/branding/scaneliq_logo_master.png`, Android mipmap/splash drawables. Entry: App icon, Splash, Home header, Settings About. Baseline: **WORKING**.
4. **NAV-03: Adaptive Tablet NavigationRail / Responsive Grids** — Documented in `SCANELIQ_FLUTTER_UI_ARCHITECTURE.md`. Current app uses `ScaneliqSpacing.adaptiveHorizontalPadding` across single-column shells without dedicated `NavigationRail` breakpoint. Baseline: **PARTIALLY WORKING** (responsive padding works; rail optional/deferred).

### Group 2 — Camera & Capture Modes (F-01 .. F-11 + UX Camera Specs)
5. **F-01: Automatic Document Boundary Detection & ML Kit Scanner** — `document_edge_detector.dart`, `scanner_studio_provider.dart`, `scan_session_provider.dart`. Entry: Home Capture FAB / Camera Studio / ML Kit fallback. Baseline: **IMPLEMENTED (HW UNVERIFIED)** (`0` Android devices attached).
6. **F-02: Manual Shutter & 4-Point Corner Perspective Adjustment** — `scanner_studio_provider.dart`, `edit_page_screen.dart`, `editor_preview_stage.dart`, `image_processing_service.dart` (Paul Heckbert inverse homography + loupe). Baseline: **WORKING (Host) / HW UNVERIFIED (Camera)**.
7. **F-03: Continuous Multi-Page Batch Scanning** — `ContinuousCameraScreen`, `ScannerStudioNotifier`, `ScanSessionNotifier`. Baseline: **IMPLEMENTED (HW UNVERIFIED)**.
8. **F-04: Draft Session Persistence & Crash Recovery** — `AppDatabaseService.getLatestDraft()`, `ScanSessionNotifier._persistDraft()`, `HomeScreen` folio card + `_discardDraft` (`DEF-LIVE-04`). Post-Repair: **WORKING**.
9. **F-05: Multi-Image & File Picker Gallery Import (`<= 80 MB`, Magic Bytes)** — `GalleryImportService`, `HomeScreen._importFiles`, `DocumentsLibraryScreen._importFiles`, `ReviewPagesScreen`. Post-Repair: **WORKING**.
10. **F-06: ID Card 2-in-1 Guided Capture & A4 Stitching** — `ScannerStudioNotifier`, `PdfService.stitchIdCard2In1`, `ReviewPagesScreen._stitch2In1IdCard`, `ToolsScreen` direct tile (`DEF-LIVE-05`). Post-Repair: **WORKING (Host) / HW UNVERIFIED (Camera)**.
11. **F-07: Book Dual-Page Spread Split** — `ImageProcessingService.splitBookSpreadFile` (`Isolate.run`), `ScannerStudioNotifier`, `ToolsScreen` direct tile (`DEF-LIVE-05`), `ReviewPagesScreen` `Split Spread` action (`DEF-LIVE-06`). Post-Repair: **WORKING**.
12. **F-08: Whiteboard Mode with Glare Removal** — `PageFilter.whiteboard`, `ImageProcessingService.applyWhiteboard`, `ScanMode.whiteboard`, `ToolsScreen` direct tile (`DEF-LIVE-05`). Post-Repair: **WORKING (Host) / HW UNVERIFIED (Camera)**.
13. **F-09: Question Set / Exam Paper Mode** — `ScanMode.questionSet` (`PageFilter.blackAndWhite` + Otsu), `ToolsScreen` direct tile (`DEF-LIVE-05`). Post-Repair: **WORKING (Host) / HW UNVERIFIED (Camera)**.
14. **F-10: QR Code & Barcode Scanner (`mobile_scanner`)** — `ScanCodeScreen`. Entry: `ToolsScreen`. Post-Repair: **IMPLEMENTED (HW UNVERIFIED)**.
15. **F-11: CountCam Object Counter** — `ObjectCounterService` (ML Kit Object Detector + Isolate 8-connected morphological clusters), `CountCamScreen` with category presets & tap markers. Post-Repair: **WORKING (Host) / HW UNVERIFIED (ML Kit/Camera)**.
16. **CAM-01: Camera Lifecycle Pause/Resume, Flash (`Off/Auto/Torch`), Grid (`3×3`), Lens Switch, Resolution Preset, Tap Focus/Exposure, Auto Quad Toggle** — `ScannerStudioNotifier`, `ContinuousCameraScreen`, `camera_studio_overlays.dart`. Post-Repair: **IMPLEMENTED (HW UNVERIFIED)**.

### Group 3 — Non-Destructive Image Editing & Processing (F-12 .. F-16 + UX Editor Specs)
17. **F-12: Non-Destructive `EditRecipe` v2 & Original File Preservation** — `document_models.dart`, `ScanSessionNotifier.updatePageRecipe`, `PdfService.resolveSinglePassSource` (`DEF-LIVE-01`). Post-Repair: **WORKING** (single-pass export verified in `repair_regression_workflows_test.dart`).
18. **F-13: Crisp Black & White Thresholding (Otsu & Sauvola)** — `computeOtsuThreshold`, `applySauvolaBinarization` (`ImageProcessingService`). Post-Repair: **WORKING**.
19. **F-14: Color & Lightening Filters (`Original`, `Auto Enhance`, `Magic Color`, `Grayscale`, `Enhanced Text`, `Lighten`, `Darken`, `Color Boost`, `Whiteboard`) + Batch Filter** — `EditPageScreen`, `ImageProcessingService`, `ScanSessionNotifier.applyFilterToPages`, `ReviewPagesScreen` Quick Batch Filter strip (`DEF-LIVE-06`). Post-Repair: **WORKING**.
20. **F-15: Brightness, Contrast & Sharpness Sliders** — `EditPageScreen._buildAdjustmentSliders`. Baseline: **WORKING**.
21. **F-16: Finger & Hole-Punch Cleanup Patch Eraser** — `EditPageScreen._buildRotateAndCleanupControls`, `applyCleanupPatches`, `_CleanupPatchesPainter`. Baseline: **WORKING**.
22. **EDIT-01: Undo/Redo History Stack (`MultiPageEditHistory`) & Split-Wipe Before/After Compare** — `edit_history_controller.dart`, `editor_preview_stage.dart`. Baseline: **WORKING**.
23. **EDIT-02: Multi-Page Editor Switching, Duplication & Page Reordering (`Move Left/Right`, Strip)** — `EditPageScreen`, `ReviewPagesScreen`. Baseline: **WORKING**.

### Group 4 — PDF Engine, Viewer & Productivity Workbench (F-17 .. F-27 + Unlisted PDF Specs)
24. **F-17: Multi-Page PDF Generation + Syncfusion Structural Validation** — `PdfService.generatePdf` with single-pass rendering (`DEF-LIVE-01`). Post-Repair: **WORKING**.
25. **F-18: HD Quality / DPI Presets (`Compact 150 / Standard 200 / High 300 DPI`) & Page Format (`A4 / Letter`)** — `ScanPreferencesService`, `PdfService.generatePdf`, `ReviewPagesScreen` `PDF Export Options` sheet, `SettingsScreen` (`DEF-LIVE-01`, `06`, `07`). Post-Repair: **WORKING**.
26. **F-19: Zero Forced Watermarks on Exports** — Verified in `PdfService`. Post-Repair: **WORKING**.
27. **F-20: Single-Page & Batch JPEG Export** — `PdfService.exportPageAsJpeg` (single-pass), `ReviewPagesScreen._exportAllPagesAsJpegs`, `DocumentViewerScreen._exportPagesAsImages` (`DEF-LIVE-01`). Post-Repair: **WORKING**.
28. **F-21: In-App PDF Viewer, Text Search, Bookmarks, Page Jump, Thumbnail Rail & Fallback Image Viewer** — `DocumentViewerScreen` (`pdfrx` + `PdfTextSearcher` + `extractTextByPage` + provider sync `DEF-LIVE-03`). Post-Repair: **WORKING (Host) / HW UNVERIFIED (PDFium Touch)**.
29. **F-22: PDF Merge** — `AdvancedPdfService.mergePdfs`, `PdfToolsScreen._mergePdfs`, `BatchMergeService.mergeDocuments` with isolated file cloning (`DEF-LIVE-02`, `03`). Post-Repair: **WORKING**.
30. **F-23: PDF Split (Single Pages & Custom Ranges) & Page Extraction** — `AdvancedPdfService`, `PdfToolsScreen` (`_registerSplitFilesInVault`), `PdfPageOrganizerScreen` (`DEF-LIVE-03`). Post-Repair: **WORKING**.
31. **F-24: PDF AES-256 Password Protection, Unlock & Remove Password** — `AdvancedPdfService.encryptPdf`/`verifyPassword`/`removePassword`, `PdfToolsScreen`, `DocumentViewerScreen._showEncryptDialog` with DB & active doc sync (`DEF-LIVE-03`). Post-Repair: **WORKING**.
32. **F-25: Custom Text & Image Watermarking (`WatermarkStudioPanel`)** — `watermark_studio_sheet.dart`, `AdvancedPdfService.addWatermark`. Post-Repair: **WORKING**.
33. **F-26: PDF Annotations (`Highlight`, `Underline`, `Freehand`, `Text Note`, `Shapes`) & Visual Signatures (`SignatureStudioPanel`)** — `pdf_annotation_studio.dart`, `signature_studio_sheet.dart`. *(Visual signature overlay implemented; X.509 PKI cert signing deferred.)* Post-Repair: **WORKING (Visual Markup) / DEFERRED (X.509 PKI)**.
34. **F-27: PDF Visual Masking, Irreversible Flatten & Scrub (`flattenAndRedactPdf`) & Raster Pixel/Mosaic Studio** — `AdvancedPdfService`, `RasterRedactionScreen`, `PdfToolsScreen._redactPdf`, `ToolsScreen` tiles (`DEF-LIVE-05`). Post-Repair: **WORKING**.
35. **PDF-01: PDF Page Organizer (`Rotate`, `Reorder`, `Duplicate`, `Delete`, `Insert PDF/Image`)** — `PdfPageOrganizerScreen` + SQLite extraction persistence & provider sync (`DEF-LIVE-03`). Post-Repair: **WORKING**.
36. **PDF-02: PDF Compression Engine (High/Balanced/Smaller)** — `AdvancedPdfService.compressPdf` (`Isolate.run`). Post-Repair: **WORKING**.
37. **PDF-03: PDF-to-Images (`pdfrx` PDFium Rasterizer) & Long Vertical Image Stitch** — `AdvancedPdfService.exportPdfToImages`, `ImageProcessingService.stitchImageFilesVertically`, `PdfToolsScreen._stitchLongImage` (now registers real raster `ScannedDocument` with copied `originalPath` instead of `.jpg` in `exportPath`), `ToolsScreen` `PDF to Images (JPEG)` tile (`DEF-LIVE-03`, `05`). Post-Repair: **WORKING**.
38. **PDF-04: PDF Metadata Inspector/Editor & Outlines** — `inspectPdf`, `updateMetadata`, `addOutlineBookmarks`, `showPdfMetadataSheet`. Post-Repair: **WORKING**.

### Group 5 — OCR, Translation & Document Intelligence (F-28 .. F-35)
39. **F-28: On-Device English/Latin OCR (`google_mlkit_text_recognition`) & Editable OCR Export (`.txt`)** — `OcrService`, `ToolsScreen`, `DocumentViewerScreen`. Post-Repair: **IMPLEMENTED (HW UNVERIFIED)**.
40. **F-29: Searchable UTF-8 PDF Generation (`NotoSansBengali-Regular.ttf`)** — `PdfService.generatePdf`, `DocumentViewerScreen._regeneratePdf` (preserves OCR text layer `DEF-LIVE-03`). Post-Repair: **WORKING**.
41. **F-30: Full-Text Library Search (`SQLite v6 FTS5 unicode61` + Snippets)** — `AppDatabaseService`. Post-Repair: **WORKING**.
42. **F-31: Genuine Bengali (`বাংলা`) & Mixed Bn-En Offline OCR + Table CSV/Markdown Extractor** — `TesseractOcrEngine.kt` (`tesseract4android:4.9.0`), `ben.traineddata`, `eng.traineddata`, `OcrService`, `OcrTableExtractor`. Post-Repair: **WORKING (Host Pipeline) / HW UNVERIFIED (Android ART)**.
43. **F-32: Document Translation (Offline ML Kit Packs + Opt-In Online Fallback + `.txt`/`.pdf` Export)** — `TranslationService`, `TranslateScreen`. Post-Repair: **WORKING (Host) / HW UNVERIFIED (ML Kit Pack Download)**.
44. **F-33: Business Card Extractor & vCard 3.0 Export** — `BusinessCardService` (`defaultOcrScript` & mixed Bengali/English default `DEF-LIVE-08`), `BusinessCardDialog`. Post-Repair: **WORKING**.
45. **F-34: Receipt & Invoice Key-Value Parser, Math Check, Bengali Numerals & Inline Editor** — `ReceiptParserService`, `ReceiptDialog` (`DEF-LIVE-08`). Post-Repair: **WORKING**.
46. **F-35: Offline AI Assistant (TextRank Summary, Key Info, Entities/Dates/Amounts, Explanation, Q&A, Semantic Vault Search)** — `AiDocumentService`, `AiDocumentSheet` (`ScanPreferencesService.instance.defaultOcrScript`, `DEF-LIVE-08`). Post-Repair: **WORKING**.

### Group 6 — Library, Folders, Tags, Cloud Sync, Security & Monetization (F-36 .. F-47 + Stages 9–10)
47. **F-36: Nested Folders, Cycle-Safe Ancestry & Hierarchy Picker** — `AppDatabaseService`, `DocumentsLibraryScreen`, `HomeScreen` single & multi-select `Move to Folder` (`DEF-LIVE-04`). Post-Repair: **WORKING**.
48. **F-37: Color-Coded Tags & Multi-Tag Filtering** — `AppDatabaseService`, `DocumentsLibraryScreen`. Post-Repair: **WORKING**.
49. **F-38: Smart Filename Templates (`SmartFilenameService`)** — Service verified, wired into `ReviewPagesScreen` token chips, `SettingsScreen` template selector, `HomeScreen` `Rename & Smart Name`, `DocumentsLibraryScreen`, and `BatchMergeService` (`DEF-LIVE-04`, `06`, `07`). Post-Repair: **WORKING**.
50. **F-39: 30-Day Soft-Delete Trash, Recovery & Auto-Purge** — `AppDatabaseService`, `TrashScreen`, startup `main.dart`. Post-Repair: **WORKING**.
51. **F-40: Batch Actions (Select All, Move, Tag, Merge, Trash)** — `DocumentsLibraryScreen`, `HomeScreen._buildSelectionActionDock` (`Move`, `Merge`, `Trash` `DEF-LIVE-04`). Post-Repair: **WORKING**.
52. **F-41: System Share Sheet (`SharePlus` + Auto-Compile Missing PDF)** — `DocumentsLibraryScreen`, `HomeScreen._shareDocument` (`DEF-LIVE-04`), `ToolsScreen._openShareExportSheet` (`DEF-LIVE-05`). Post-Repair: **WORKING**.
53. **F-42: Local Encrypted `.scaneliq` Backup & WebDAV Cloud Sync + Schedule** — `CloudBackupService`, `CloudTransportService`, `SettingsScreen`, `ToolsScreen` (`DEF-LIVE-05`). Post-Repair: **WORKING (Host / MockClient) / BLOCKED (Google Drive/Dropbox/OneDrive OAuth IDs)**.
54. **F-43: Multi-Device E2EE Sync V2 (`PBKDF2-100k + AES-256-CBC EtM`) + LWW Merge + Offline Queue** — `DeviceSyncService`, `SettingsScreen`. Post-Repair: **WORKING**.
55. **F-44 & F-45: Local-First Architecture & Zero Mandatory Accounts** — `AndroidManifest.xml` (`allowBackup="false"`, `usesCleartextTraffic="false"`), immediate Home entry. Post-Repair: **WORKING**.
56. **F-46: Cold-Start AppLock, KeyStore Secrets, 5-Attempt Lockout, Biometrics & `FLAG_SECURE` Shield** — `AppLockService`, `PrivacyShieldService`, `MainActivity.kt`, `MainNavigationShell`, `main.dart`. Post-Repair: **WORKING (Host) / HW UNVERIFIED (Biometrics & WindowManager)**.
57. **F-47: Storage Path Hygiene & Live Storage Breakdown / Cache Cleanup** — Startup `cleanStaleTempFiles()`, `AppStorageService.calculateStorageBreakdown()`, `clearTemporaryCache()`, `SettingsScreen` Storage dialog (`DEF-LIVE-07`). Post-Repair: **WORKING**.
58. **SUB-01: Subscription Plans (`Free/Pro/Ultra`), Daily Quotas & `in_app_purchase` Play Billing** — `SubscriptionService`, `SubscriptionSheet`, `SettingsScreen`, `CountCamScreen`. Post-Repair: **WORKING (Host Quotas/Adapter) / BLOCKED (Play Console SKUs)**.
59. **GEN-01: Scan/PDF Preferences (`ScanPreferencesService`: `qualityPreset`, `pageFormat`, `defaultOcrScript`, `autoEmbedSearchableOcr`, `smartFilenameTemplate`, `defaultFilter`) & Interactive Settings** — Wired across `main.dart`, `SettingsScreen`, `ReviewPagesScreen`, `DocumentViewerScreen`, `AiDocumentSheet` (`DEF-LIVE-07`). Post-Repair: **WORKING**.
