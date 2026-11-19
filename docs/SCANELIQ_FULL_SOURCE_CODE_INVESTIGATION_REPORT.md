# SCANELIQ — Full Static Source-Code Investigation Report

**Project Workspace:** `c:\Scaneliq`  
**Package / Application ID:** `scaneliq` / `com.scaneliq.scaneliq`  
**Declared Version:** `2.67.0+26700` ([pubspec.yaml](file:///c:/Scaneliq/pubspec.yaml#L1-L19))  
**Investigation Scope:** 100% Pure Static Source-Code Reading & Architecture/Defect Investigation (Zero source edits executed; zero tests, static analysis commands, or APK builds executed.)  

---

## Executive Summary

A complete file-by-file reading of the entire Scaneliq Flutter application (`74 / 74` Dart files in `lib/`), its automated test suite (`34 / 34` Dart files in `test/`), its Android native integration (`android/app/src/main/**` and Gradle/Proguard configs), project configuration files, bundled assets, and primary architecture/audit documentation reveals a **feature-rich local-first architecture undermined by several severe data-integrity, coordinate-geometry, and cross-screen wiring defects**.

Most critically:
1. **Silent Cascading Data Loss in SQLite (`CRITICAL`):** `AppDatabaseService.saveDocument`, `saveDocumentWithPages`, `CloudBackupService`, and `DeviceSyncService` use `ConflictAlgorithm.replace` (`INSERT OR REPLACE`) on `documents`, which deletes and re-inserts the parent row. Because `pages`, `document_tags`, `document_ocr`, and `document_bookmarks` all declare `FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE`, **updating metadata on any existing document (`saveDocument`) silently destroys all of its pages, tags, OCR index text, and bookmarks**, while **saving edited pages (`saveDocumentWithPages`) silently wipes tags, OCR text, and bookmarks**.
2. **Broken Searchable PDF Coordinates & Literal `$1` OCR Corruption (`CRITICAL`):** `PdfService.generatePdf` divides **unscaled** original image OCR bounding boxes by **post-resize** image dimensions (`out.width` / `out.height`) whenever an image exceeds `maxEdgePx`, shifting or clipping the invisible OCR layer off the page. Separately, `OcrService.normalizeBanglaNumerals` uses Dart's `String.replaceAll(..., r'$1')` (which does not interpolate regex capture groups), injecting literal `"$1"` strings before `,`, `;`, or `:` whenever whitespace precedes punctuation.
3. **Broken Core Scan -> Review -> View -> Edit Loop (`CRITICAL`):** Completing capture in `ReviewPagesScreen` opens `DocumentViewerScreen` with `pages: const []` (empty in-memory page list), and editing inside `DocumentViewerScreen._openPageEditorSheet` invokes a synchronous callback that discards edits/reordering/duplications on all pages other than the initial page while racing SQLite persistence against `_regeneratePdf()`.
4. **Why the 34-File Test Suite Missed These Bugs:** Inline test SQLite tables omit `ON DELETE CASCADE` or avoid `saveDocument` updates on populated child rows; searchable PDF tests use `600x800` images (below `maxEdgePx`, so zero resize occurs); Bengali numeral tests lack space before `:`; and UI/integration tests either mock services or stop before checking multi-page viewer/editor round-trips.

---

## A. Reading Coverage & Complete Source-Reading Ledger

All Dart source files in `lib/` and `test/`, all Android native manifests/Kotlin/XML/Gradle/Proguard files, and project configuration files were inspected completely.

### A.1 Coverage Summary

| Area | Coverage | Exact Count | Notes |
| --- | --- | --- | --- |
| Flutter Application Source (`lib/`) | **100% Read** | **74 / 74 `.dart` files** | Every line read across core, models, navigation, theme, widgets, database, storage, image processing, scanner, editor, PDF, OCR, intelligence, security, cloud sync, settings, subscription |
| Automated Test Suite (`test/`) | **100% Read** | **34 / 34 `.dart` files** | Read as supporting evidence of design intent and coverage gaps |
| Android Native Source (`android/app/src/main/`) | **100% Read** | **11 / 11 source/res files** | `AndroidManifest.xml`, `MainActivity.kt`, `TesseractOcrEngine.kt`, drawables, mipmaps, values/styles |
| Android & Root Project Configuration | **100% Read** | **14 files** | `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `.gitignore`, `.metadata`, `scaneliq.iml`, `generate_launcher_icons.py`, `skills-lock.json`, `.flutter-plugins-dependencies`, Android Gradle/wrapper/proguard/properties/key example |
| Assets (`assets/`) | **100% Inventoried** | **6 files** | Verified exact paths and byte sizes matching `pubspec.yaml` and Kotlin/Dart loaders |
| Documentation (`docs/` & `research-output/`) | **Core Blueprints, Traceability & Remediation Docs Read** | **9 key documents** | Read Master Blueprint, Feature Traceability Matrix, Master Functional Inventory, Functional Audit, Final Repair Report, Phase 5 RC Report, Final Feature Matrix, Remediation Final Report, Remediation Master Tracker |
| Third-Party Package Signature Checks | **Targeted Verification** | **2 SDK/Pub files** | Checked `file_picker-13.1.0/lib/src/file_picker.dart` and Flutter `reorderable_list.dart` to eliminate false positives |

### A.2 Complete Flutter Source Ledger (`lib/` — 74 / 74 Files)

| # | File Path | Lines | Status |
| --- | --- | --- | --- |
| 1 | `lib/main.dart` | 62 | Read 100% |
| 2 | `lib/app/main_navigation_shell.dart` | 1 | Read 100% |
| 3 | `lib/core/config/app_compliance_config.dart` | 49 | Read 100% |
| 4 | `lib/core/image_processing/image_processing_service.dart` | 1211 | Read 100% |
| 5 | `lib/core/models/document_models.dart` | 679 | Read 100% |
| 6 | `lib/core/navigation/app_router.dart` | 146 | Read 100% |
| 7 | `lib/core/navigation/app_routes.dart` | 20 | Read 100% |
| 8 | `lib/core/navigation/main_navigation_shell.dart` | 132 | Read 100% |
| 9 | `lib/core/services/scan_preferences_service.dart` | 156 | Read 100% |
| 10 | `lib/core/services/smart_filename_service.dart` | 118 | Read 100% |
| 11 | `lib/core/storage/app_storage_service.dart` | 246 | Read 100% |
| 12 | `lib/core/theme/app_theme.dart` | 332 | Read 100% |
| 13 | `lib/core/theme/scaneliq_colors.dart` | 117 | Read 100% |
| 14 | `lib/core/theme/scaneliq_radius.dart` | 31 | Read 100% |
| 15 | `lib/core/theme/scaneliq_spacing.dart` | 34 | Read 100% |
| 16 | `lib/core/theme/scaneliq_tokens.dart` | 231 | Read 100% |
| 17 | `lib/core/theme/scaneliq_typography.dart` | 188 | Read 100% |
| 18 | `lib/core/widgets/scaneliq_bottom_nav.dart` | 236 | Read 100% |
| 19 | `lib/core/widgets/scaneliq_buttons.dart` | 252 | Read 100% |
| 20 | `lib/core/widgets/scaneliq_content_widgets.dart` | 331 | Read 100% |
| 21 | `lib/core/widgets/scaneliq_document_widgets.dart` | 498 | Read 100% |
| 22 | `lib/core/widgets/scaneliq_logo.dart` | 70 | Read 100% |
| 23 | `lib/core/widgets/scaneliq_mark.dart` | 93 | Read 100% |
| 24 | `lib/core/widgets/scaneliq_overlays.dart` | 183 | Read 100% |
| 25 | `lib/core/widgets/scaneliq_search_field.dart` | 97 | Read 100% |
| 26 | `lib/features/cloud_sync/data/cloud_backup_service.dart` | 592 | Read 100% |
| 27 | `lib/features/cloud_sync/data/cloud_transport_service.dart` | 563 | Read 100% |
| 28 | `lib/features/cloud_sync/data/device_sync_service.dart` | 571 | Read 100% |
| 29 | `lib/features/documents/data/app_database_service.dart` | 1464 | Read 100% |
| 30 | `lib/features/documents/data/batch_merge_service.dart` | 112 | Read 100% |
| 31 | `lib/features/documents/presentation/document_viewer_screen.dart` | 1643 | Read 100% |
| 32 | `lib/features/documents/presentation/documents_library_screen.dart` | 1716 | Read 100% |
| 33 | `lib/features/documents/presentation/home_screen.dart` | 1100 | Read 100% |
| 34 | `lib/features/documents/presentation/trash_screen.dart` | 412 | Read 100% |
| 35 | `lib/features/editor/presentation/edit_history_controller.dart` | 108 | Read 100% |
| 36 | `lib/features/editor/presentation/edit_page_screen.dart` | 1389 | Read 100% |
| 37 | `lib/features/editor/presentation/raster_redaction_screen.dart` | 453 | Read 100% |
| 38 | `lib/features/editor/presentation/review_pages_screen.dart` | 1362 | Read 100% |
| 39 | `lib/features/editor/presentation/widgets/editor_preview_stage.dart` | 653 | Read 100% |
| 40 | `lib/features/intelligence/data/ai_document_service.dart` | 682 | Read 100% |
| 41 | `lib/features/intelligence/data/business_card_service.dart` | 322 | Read 100% |
| 42 | `lib/features/intelligence/data/receipt_parser_service.dart` | 349 | Read 100% |
| 43 | `lib/features/intelligence/presentation/ai_document_sheet.dart` | 525 | Read 100% |
| 44 | `lib/features/intelligence/presentation/business_card_dialog.dart` | 300 | Read 100% |
| 45 | `lib/features/intelligence/presentation/receipt_dialog.dart` | 511 | Read 100% |
| 46 | `lib/features/ocr/data/ocr_service.dart` | 509 | Read 100% |
| 47 | `lib/features/pdf/data/advanced_pdf_service.dart` | 1922 | Read 100% |
| 48 | `lib/features/pdf/data/pdf_service.dart` | 431 | Read 100% |
| 49 | `lib/features/pdf/presentation/pdf_page_organizer_screen.dart` | 763 | Read 100% |
| 50 | `lib/features/pdf/presentation/pdf_tools_screen.dart` | 1753 | Read 100% |
| 51 | `lib/features/pdf/presentation/widgets/pdf_annotation_studio.dart` | 1186 | Read 100% |
| 52 | `lib/features/pdf/presentation/widgets/pdf_metadata_and_bookmarks_sheets.dart` | 356 | Read 100% |
| 53 | `lib/features/pdf/presentation/widgets/signature_studio_sheet.dart` | 451 | Read 100% |
| 54 | `lib/features/pdf/presentation/widgets/watermark_studio_sheet.dart` | 501 | Read 100% |
| 55 | `lib/features/scanner/data/camera_studio_controller.dart` | 257 | Read 100% |
| 56 | `lib/features/scanner/data/document_edge_detector.dart` | 664 | Read 100% |
| 57 | `lib/features/scanner/data/gallery_import_service.dart` | 198 | Read 100% |
| 58 | `lib/features/scanner/data/object_counter_service.dart` | 387 | Read 100% |
| 59 | `lib/features/scanner/data/translation_service.dart` | 267 | Read 100% |
| 60 | `lib/features/scanner/presentation/continuous_camera_screen.dart` | 1049 | Read 100% |
| 61 | `lib/features/scanner/presentation/count_cam_screen.dart` | 506 | Read 100% |
| 62 | `lib/features/scanner/presentation/scan_code_screen.dart` | 211 | Read 100% |
| 63 | `lib/features/scanner/presentation/scan_session_provider.dart` | 705 | Read 100% |
| 64 | `lib/features/scanner/presentation/scanner_studio_provider.dart` | 749 | Read 100% |
| 65 | `lib/features/scanner/presentation/translate_screen.dart` | 524 | Read 100% |
| 66 | `lib/features/scanner/presentation/widgets/camera_studio_overlays.dart` | 616 | Read 100% |
| 67 | `lib/features/security/data/app_lock_service.dart` | 575 | Read 100% |
| 68 | `lib/features/security/data/privacy_shield_service.dart` | 75 | Read 100% |
| 69 | `lib/features/security/presentation/app_lock_dialog.dart` | 32 | Read 100% |
| 70 | `lib/features/security/presentation/app_lock_screen.dart` | 586 | Read 100% |
| 71 | `lib/features/settings/presentation/settings_screen.dart` | 1484 | Read 100% |
| 72 | `lib/features/settings/presentation/tools_screen.dart` | 721 | Read 100% |
| 73 | `lib/features/subscription/data/subscription_service.dart` | 425 | Read 100% |
| 74 | `lib/features/subscription/presentation/subscription_sheet.dart` | 260 | Read 100% |

### A.3 Android Native, Config, Asset & Test Ledger

- **Android Native (`android/app/src/main/` — 11 / 11 files read):**
  - `android/app/src/main/kotlin/com/scaneliq/scaneliq/MainActivity.kt` (94 lines)
  - `android/app/src/main/kotlin/com/scaneliq/scaneliq/TesseractOcrEngine.kt` (109 lines)
  - `android/app/src/main/AndroidManifest.xml` (54 lines; plus debug & profile manifests)
  - `android/app/src/main/res/drawable/launch_background.xml` (9 lines), `drawable-v21/launch_background.xml` (9 lines)
  - `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` (9 lines), `ic_launcher_round.xml` (9 lines), `launcher_icon.xml` (9 lines)
  - `android/app/src/main/res/values/colors.xml` (5 lines), `values/styles.xml` (9 lines), `values-night/styles.xml` (18 lines)
- **Android Build & Root Project Configs:**
  - `pubspec.yaml` (133 lines; Dart SDK `^3.13.5`, `version: 2.67.0+26700`), `pubspec.lock`, `analysis_options.yaml` (34 lines; `package:flutter_lints/flutter.yaml`), `.gitignore`, `.metadata`, `scaneliq.iml` (17 lines), `generate_launcher_icons.py` (234 lines), `skills-lock.json` (149 lines), `.flutter-plugins-dependencies`
  - `android/build.gradle.kts`, `android/app/build.gradle.kts` (84 lines; `tesseract4android:4.9.0`, `isMinifyEnabled = true`, `isShrinkResources = true`, conditional release signing fallback to debug if `key.properties` absent), `android/app/proguard-rules.pro` (33 lines), `android/gradle.properties`, `android/settings.gradle.kts`, `android/local.properties`, `android/key.properties.example`, `android/.gitignore`, `android/scaneliq_android.iml`, `android/gradle/wrapper/gradle-wrapper.properties`
- **Bundled Assets (`assets/` — 6 files verified on disk):**
  - `assets/branding/scaneliq_logo_adaptive_foreground.png` (666,048 bytes)
  - `assets/branding/scaneliq_logo_master.png` (627,039 bytes)
  - `assets/branding/scaneliq_logo_original.jpg` (374,641 bytes — not declared in `pubspec.yaml`)
  - `assets/fonts/NotoSansBengali-Regular.ttf` (463,668 bytes)
  - `assets/tessdata/ben.traineddata` (855,841 bytes)
  - `assets/tessdata/eng.traineddata` (4,113,088 bytes)
- **Automated Tests (`test/` — 34 / 34 files read):**
  `advanced_pdf_service_test.dart` (140), `batch_scanning_test.dart` (147), `database_persistence_test.dart` (540), `document_models_test.dart` (106), `edit_recipe_test.dart` (103), `image_processing_test.dart` (479), `logo_test.dart` (75), `navigation_and_screens_test.dart` (95), `organization_and_batch_test.dart` (495), `pdf_generation_test.dart` (306), `phase10_camscanner_features_test.dart` (108), `phase1_foundation_ui_test.dart` (486), `phase2_audit_and_repair_test.dart` (231), `phase2_navigation_and_screens_test.dart` (428), `phase3_advanced_features_test.dart` (439), `phase3_scanner_camera_test.dart` (860), `phase4_filter_and_pdf_repair_test.dart` (353), `phase4_scan_editor_test.dart` (647), `phase5_advanced_pdf_test.dart` (733), `phase5_pdf_engine_test.dart` (636), `phase6_functional_verification_test.dart` (265), `phase7_end_to_end_integration_test.dart` (306), `phase8_security_and_privacy_test.dart` (349), `phase9_release_candidate_test.dart` (494), `repair_regression_workflows_test.dart` (285), `scanner_workflow_test.dart` (317), `stage10_subscription_and_entitlements_test.dart` (178), `stage12_e2e_workflows_test.dart` (266), `stage6_bengali_ocr_and_pdf_test.dart` (222), `stage7_translation_and_ai_test.dart` (197), `stage8_countcam_and_invoice_test.dart` (144), `stage9_cloud_sync_and_privacy_test.dart` (430), `storage_service_test.dart` (138), `widget_test.dart` (75).
- **Documentation Read (`docs/` & `research-output/`):**
  - `docs/Scaneliq_Master_Blueprint_Improved.md` (804 lines)
  - `docs/FEATURE_TRACEABILITY_MATRIX.md` (76 lines)
  - `docs/SCANELIQ_MASTER_FUNCTIONAL_INVENTORY.md` (124 lines)
  - `docs/SCANELIQ_FUNCTIONAL_AUDIT.md` (364 lines)
  - `docs/SCANELIQ_FINAL_REPAIR_REPORT.md` (196 lines)
  - `docs/SCANELIQ_PHASE5_RELEASE_CANDIDATE_REPORT.md` (322 lines)
  - `research-output/SCANELIQ_FINAL_FEATURE_MATRIX.md` (167 lines)
  - `research-output/SCANELIQ_REMEDIATION_FINAL_REPORT.md` (64 lines)
  - `research-output/SCANELIQ_REMEDIATION_MASTER_TRACKER.md` (51 lines)

---

## B. Application Architecture Understanding

### B.1 Entrypoint & Startup Flow (`lib/main.dart`)
1. `main()` initializes bindings, initializes `AppStorageService.instance.init()`, `ScanPreferencesService.instance.init()`, `AppLockService.instance.init()`, `PrivacyShieldService.instance.init()`, and logs `AppComplianceConfig.logStartupDiagnostics()`.
2. Launches unawaited `_runStartupHousekeeping()` (`lib/main.dart:29-34`) to purge stale `.tmp` files and expired 30-day Trash records (`AppDatabaseService.instance.purgeExpiredTrash()`).
3. Runs `ProviderScope(child: ScaneliqApp())` wrapping `MaterialApp.router` with Gallery Alabaster (light) and Carbon Studio (dark) Material 3 themes (`app_theme.dart`, `scaneliq_colors.dart`, `scaneliq_tokens.dart`).

### B.2 Navigation & App Lock Gate (`lib/core/navigation/`)
- **`GoRouter` (`app_router.dart`):**
  - `StatefulShellRoute.indexedStack` inside `MainNavigationShell` hosts 3 bottom-navigation branches:
    1. `/scans` (`HomeScreen`)
    2. `/folders` (`DocumentsLibraryScreen`)
    3. `/pdf-suite` (`PdfToolsScreen`)
  - Standalone push routes: `/settings` (`SettingsScreen`), `/review-pages` (`ReviewPagesScreen`), `/trash` (`TrashScreen`).
  - Numerous secondary workflows (`ContinuousCameraScreen`, `DocumentViewerScreen`, `EditPageScreen`, `RasterRedactionScreen`, `PdfPageOrganizerScreen`, `ToolsScreen`, `CountCamScreen`, `ScanCodeScreen`, `TranslateScreen`) are pushed directly via `Navigator.of(context).push(MaterialPageRoute(...))`.
- **Navigation Shell (`main_navigation_shell.dart`):**
  - Exposes `ScaneliqShellScope` (`InheritedWidget`) and listens to `WidgetsBindingObserver.didChangeAppLifecycleState` (`line 78`) to check `AppLockService` timeout requirements and push/overlay `AppLockScreen`.
  - Notice `ToolsScreen` exists and is reachable as a utility workbench, while PDF tools live inside the `/pdf-suite` bottom tab (`PdfToolsScreen`).

### B.3 State Management & Singleton Layer
Scaneliq mixes **three state patterns**:
1. **Riverpod (`flutter_riverpod: ^3.4.3`):**
   - `scanSessionProvider` (`ScanSessionNotifier` holding active capture pages, batch draft ID, active `ScannedDocument` metadata).
   - `scannerStudioProvider` (`ScannerStudioNotifier` managing `CameraStudioController`, live luma stream, `DocumentStabilityTracker`, ID card 2-step state, flash, zoom, auto-capture).
   - Data providers (`documentsListProvider`, `searchedDocumentsProvider`, `foldersListProvider`, `tagsListProvider`, `latestDraftProvider`) that UI screens must explicitly `ref.invalidate(...)` after mutations.
2. **Global Mutable Singletons (`.instance`):**
   `AppDatabaseService`, `AppStorageService`, `ScanPreferencesService`, `AppLockService`, `PrivacyShieldService`, `OcrService`, `PdfService`, `AdvancedPdfService`, `AiDocumentService`, `BusinessCardService`, `ReceiptParserService`, `TranslationService`, `ObjectCounterService`, `CloudBackupService`, `CloudTransportService`, `DeviceSyncService`, `SubscriptionService`.
3. **Local `StatefulWidget` State:** Large presentation screens (`HomeScreen` 1100 lines, `DocumentsLibraryScreen` 1716 lines, `DocumentViewerScreen` 1643 lines, `ReviewPagesScreen` 1362 lines, `EditPageScreen` 1389 lines, `PdfToolsScreen` 1753 lines, `SettingsScreen` 1484 lines) manage significant business logic directly inside State classes.

### B.4 Local Storage, SQLite Vault & FTS5
- **Filesystem Vault (`app_storage_service.dart`):**
  Managed under app documents directory (`ScaneliqVault`):
  - `originals/` — immutable source captures
  - `processed/` — rendered/filtered page variants
  - `exports/` — generated/edited PDFs and exported JPEGs/CSVs/vCards
  - `temp/` — intermediate processing/crop/backup staging cleaned after 24h
- **Relational + Full-Text Database (`app_database_service.dart`):**
  - Tables: `folders` (self-referencing `parent_id`), `tags`, `documents` (`folder_id`, `export_path`, `page_count`, `is_favorite`, `is_draft`, `deleted_at`, timestamps), `pages` (`document_id`, `page_index`, `original_path`, `processed_path`, JSON `edit_recipe`), `document_tags` (`document_id`, `tag_id`), `document_ocr` (`document_id`, `full_text`), `document_bookmarks` (`id`, `document_id`, `page_index`, `title`), and `documents_fts` (FTS5 virtual table with `fts4` fallback, `buildFtsMatchQuery`, `searchDocumentsWithSnippets`).
  - **Foreign Keys Enabled:** Declares `ON DELETE CASCADE` on `folders.parent_id`, `pages.document_id`, `document_tags.document_id`, `document_tags.tag_id`, `document_ocr.document_id`, and `document_bookmarks.document_id`.

### B.5 Image Processing, PDF, OCR & Android Native Engines
- **Non-Destructive Image Pipeline (`document_models.dart`, `image_processing_service.dart`):**
  - Edits are modeled as JSON `EditRecipe` (crop rect, 4-point `PerspectiveQuad`, rotation, `PageFilter`, brightness/contrast/sharpness, shadow correction, `CleanupPatch` eraser stamps, `BinarizationMode`).
  - Pure-Dart `image` package operations execute via `Isolate.run` (`autoDetectDocumentQuad`, `applyPerspectiveWarp`, `processRecipe`, adaptive Sauvola/Otsu/MagicColor/Whiteboard filters, `applyCleanupPatches`, `permanentlyMosaicImage`).
- **Dual PDF Stack (`pdf_service.dart`, `advanced_pdf_service.dart`):**
  - `pdf` (`^3.13.1`): Generates multi-page A4/Letter/Fit-Image PDFs with `NotoSansBengali-Regular.ttf` and invisible searchable OCR overlays (`PdfService.generatePdf`), plus 2-in-1 ID card stitching (`stitchIdCard2In1`) and JPEG export (`exportPageAsJpeg`).
  - `pdfrx` (`^2.6.5`): High-speed PDFium rendering (`PdfViewer.file`), in-viewer text search, thumbnails, and rasterization (`exportPdfToImages`).
  - `syncfusion_flutter_pdf` (`^35.1.40+1`): Merge, split by pages/ranges, AES-256 encryption, custom text/image watermarking, text extraction, interactive annotation flattening (`PdfAnnotationStudio` + `applyAnnotations`), page reorganization, compression, and pixel-level raster redaction (`flattenAndRedactPdf`).
- **Dual OCR Pipeline (`ocr_service.dart`, `MainActivity.kt`, `TesseractOcrEngine.kt`):**
  - Latin script routes to `google_mlkit_text_recognition`.
  - `OcrScript.bengali` and `OcrScript.mixedBengaliEnglish` (`ben+eng`) route over Android `MethodChannel('com.scaneliq.scaneliq/tesseract')` to `TesseractOcrEngine.kt` (`cz.adaptech.tesseract4android:tesseract4android:4.9.0`), copying bundled `assets/tessdata/ben.traineddata` & `eng.traineddata` to app files dir and running LSTM recognition on a single-thread Java executor.
  - Preprocesses images (contrast/binarization) and normalizes Bengali/English output (`OcrService.normalizeBanglaNumerals`).

### B.6 Security, Cloud Sync & Subscription Architecture
- **Security (`app_lock_service.dart`, `privacy_shield_service.dart`, `MainActivity.kt`):**
  - PINs hashed with PBKDF2-HMAC-SHA256 + per-user random salt, persisted in `FlutterSecureStorage` (Android Keystore/Tink) with failed-attempt exponential lockout and optional `local_auth` biometrics (`FlutterFragmentActivity`).
  - Screen-capture protection (`FLAG_SECURE`) toggled via `MethodChannel('com.scaneliq.scaneliq/security')`.
- **Cloud Backup & Multi-Device Sync (`cloud_backup_service.dart`, `cloud_transport_service.dart`, `device_sync_service.dart`):**
  - `.scaneliq` ZIP archives with optional AES-256 encryption (`encrypt` + `pointycastle`), SQLite table serialization + `exports/` + `originals/` binaries.
  - WebDAV transport (`MKCOL`/`PUT`/`PROPFIND`/`GET` via `package:http`) storing credentials in `FlutterSecureStorage`.
  - P2P/Sync V2 PBKDF2 + AES-256-CBC Encrypt-then-MAC encrypted envelopes with Last-Write-Wins (`modified_at`) timestamp merge.
- **Monetization (`subscription_service.dart`, `subscription_sheet.dart`):**
  - Integrates `in_app_purchase` (`^3.3.1`) and tracks feature usage quotas (`SubscriptionQuotaFeature`: `ocrExtraction`, `aiSummary`, `offlineTranslation`, `countCam`, `batchPdfExport`) locally via `SharedPreferences`.

---

## C. Complete Feature-to-Code Map

### C.1 Master Blueprint Features (`F-01` – `F-47`) vs Verified Live Behavior

*Source specification: [Scaneliq_Master_Blueprint_Improved.md](file:///c:/Scaneliq/docs/Scaneliq_Master_Blueprint_Improved.md) & [FEATURE_TRACEABILITY_MATRIX.md](file:///c:/Scaneliq/docs/FEATURE_TRACEABILITY_MATRIX.md).*

| ID | Feature | Documented Claim | Live Execution Chain (`UI -> Provider/Ctrl -> Service -> Model -> DB/Storage -> Output`) | Actual Verified Status |
| --- | --- | --- | --- | --- |
| **F-01** | Auto Document Boundary Detection | TESTED | `ContinuousCameraScreen` -> `ScannerStudioNotifier.processFrame` -> `DocumentEdgeDetector.detect` -> `PerspectiveQuad` overlay | **PARTIAL / DEFECTIVE** (`YUV` raw sensor frame not rotated by `sensorOrientation`; overlay stretched in `Stack`) |
| **F-02** | Manual Shutter & Corner Adjustment | TESTED | `EditPageScreen` -> `EditorPreviewStage` -> `EditRecipe.perspectiveQuad` -> `ImageProcessingService` | **PARTIAL / DEFECTIVE** (Letterbox coordinate mismatch in `EditorPreviewStage`; multi-page edits discarded from Viewer) |
| **F-03** | Continuous Multi-Page Batch Scan | TESTED | `ContinuousCameraScreen` -> `ScannerStudioNotifier` -> `ScanSessionNotifier.addCapturedFile` -> `AppStorageService` -> `AppDatabaseService` -> `ReviewPagesScreen` | **WORKING** (with draft recovery; camera hardware itself requires device verification) |
| **F-04** | Draft Session Persistence & Recovery | TESTED | `ScanSessionNotifier._persistDraft` -> `AppDatabaseService.saveDocumentWithPages` -> `latestDraftProvider` -> `HomeScreen` draft card -> `ReviewPagesScreen` | **PARTIAL / DEFECTIVE** (`ConflictAlgorithm.replace` cascade-wipes tags/OCR/bookmarks on resave) |
| **F-05** | Multi-Image & File Picker Import | TESTED | `ReviewPagesScreen` / `DocumentsLibraryScreen` -> `FilePicker.pickFiles` -> `GalleryImportService.validateFiles` -> `ScanSessionNotifier` | **PARTIAL** (`DocumentsLibraryScreen._importFiles` bypasses `GalleryImportService` validation and `ScanPreferencesService`) |
| **F-06** | ID Card 2-in-1 Sheet Stitching | TESTED | `ContinuousCameraScreen` -> `ScannerStudioNotifier.captureManual` (`idCardStep`) -> `PdfService.stitchIdCard2In1` -> `ScanSessionNotifier.replaceWithSinglePage` | **BROKEN** (`replaceWithSinglePage` wipes ALL earlier session pages instead of appending stitched sheet, orphans old files, never resets `idCardStep`) |
| **F-07** | Book Dual-Page Scan & Flattening | TESTED | `ContinuousCameraScreen` (`Book` mode) -> `ImageProcessingService.splitBookSpread` -> `ScanSessionNotifier` | **IMPLEMENTED (HW UNVERIFIED)** |
| **F-08** | Whiteboard Glare Removal | TESTED | `PageFilter.whiteboard` / capture mode -> `ImageProcessingService` -> processed JPEG | **IMPLEMENTED** |
| **F-09** | Question Set / Exam Paper Mode | TESTED | `ContinuousCameraScreen` mode -> `ScanSessionNotifier` -> `PageFilter.cleanBw` | **IMPLEMENTED** |
| **F-10** | QR Code & Barcode Scanner | IMPLEMENTED | `ToolsScreen` -> `ScanCodeScreen` (`mobile_scanner`) -> URL/text action sheet | **IMPLEMENTED (HW UNVERIFIED)** |
| **F-11** | CountCam (Object Counter) | IMPLEMENTED | `CountCamScreen` -> `SubscriptionService.consumeQuota` -> `ObjectCounterService.detectObjects` (ML Kit + cluster counter) -> `_CountBoxesPainter` | **PARTIAL / DEFECTIVE** (`BoxFit.contain` letterbox coordinate mismatch on boxes & tap markers; preset switch double-charges quota) |
| **F-12** | Non-Destructive Edit Recipes | TESTED | `EditPageScreen` -> `EditHistoryStack` -> `EditRecipe` JSON in SQLite `pages.edit_recipe` -> `ImageProcessingService.processRecipe` | **PARTIAL / DEFECTIVE** (`copyWith` / `fromMap` gaps; extreme crop throws `ArgumentError`; multi-page save broken from Viewer) |
| **F-13** | Clean Black & White Filter | TESTED | `EditPageScreen` -> `PageFilter.cleanBw` / `BinarizationMode` (`otsu`, `sauvola`) -> `ImageProcessingService` | **IMPLEMENTED** |
| **F-14** | Grayscale & Magic Color Presets | TESTED | `EditPageScreen` -> `PageFilter.grayscale` / `magicColor` -> `ImageProcessingService` | **IMPLEMENTED** |
| **F-15** | Brightness & Contrast Sliders | TESTED | `EditPageScreen` -> `EditRecipe.brightness` / `contrast` / `sharpness` -> `ImageProcessingService` | **IMPLEMENTED** |
| **F-16** | Finger & Stray Shadow Eraser | TESTED | `EditPageScreen` -> `CleanupPatch` -> `ImageProcessingService.applyCleanupPatches` | **PARTIAL / DEFECTIVE** (`clamp(3, w~/4)` throws if `w < 12`; blur loop reads `dst` instead of `src`; letterbox tap offset) |
| **F-17** | Multi-Page A4 PDF Generation | TESTED | `ReviewPagesScreen` / `DocumentViewerScreen` -> `PdfService.generatePdf` -> `AppStorageService.exportsDir` | **PARTIAL / DEFECTIVE** (`ReviewPagesScreen` passes empty `pages` to Viewer after creation) |
| **F-18** | HD Quality Presets (150/200/300 DPI) | TESTED | `SettingsScreen` -> `ScanPreferencesService` (`PdfQualityPreset`) -> `PdfService.generatePdf` | **PARTIAL** (Respected by `ReviewPagesScreen`/`Viewer`, ignored by `DocumentsLibraryScreen` & `ToolsScreen` share flows) |
| **F-19** | Unwatermarked Free PDF & JPEG Export | TESTED | `PdfService.generatePdf` / `exportPageAsJpeg` | **IMPLEMENTED** |
| **F-20** | Single-Page & Batch JPEG Export | TESTED | `ReviewPagesScreen` / `DocumentViewerScreen` -> `PdfService.exportPageAsJpeg` / `SharePlus` | **PARTIAL / BROKEN** (`DocumentViewerScreen` `'Export Pages as JPEG'` fails on freshly scanned docs because `pages` list is empty) |
| **F-21** | High-Performance PDF Viewer & Search | TESTED | `DocumentViewerScreen` -> `pdfrx` `PdfViewer.file` -> `PdfTextSearcher` -> `document_bookmarks` | **PARTIAL / DEFECTIVE** (Missing `ValueKey` on `PdfViewer.file` leaves stale PDF rendered after edits; `_zoomFactor` doesn't track pinch zoom; thumbnail strip desyncs from `_totalPages`) |
| **F-22** | PDF Merge | TESTED | `PdfToolsScreen` / `HomeScreen` (`BatchMergeService`) -> `AdvancedPdfService.mergePdfs` -> SQLite `saveDocumentWithPages` | **IMPLEMENTED** |
| **F-23** | PDF Split & Page Extraction | TESTED | `PdfToolsScreen` -> `AdvancedPdfService.splitPdfIntoPages` / `splitPdfByRanges` -> `saveDocument` | **PARTIAL** (Controllers leaked in split dialogs; viewer/organizer callers risk `saveDocument` cascade) |
| **F-24** | PDF Password Protection (AES-256) | TESTED | `PdfToolsScreen` -> `AdvancedPdfService.encryptPdf` (`syncfusion_flutter_pdf`) -> `saveDocument` | **PARTIAL / DEFECTIVE** (Updates via `saveDocument` trigger `ON DELETE CASCADE` wipe on child rows) |
| **F-25** | Custom Text Watermarking | TESTED | `PdfToolsScreen` -> `WatermarkStudioSheet` -> `AdvancedPdfService.addWatermark` | **PARTIAL / DEFECTIVE** (Un-awaited or `saveDocument` cascade risks on existing doc) |
| **F-26** | PDF Annotations & Signatures | TESTED | `DocumentViewerScreen` -> `PdfAnnotationStudio` + `SignatureStudioSheet` -> `AdvancedPdfService.applyAnnotations` | **PARTIAL / DEFECTIVE** (Negative-width/height lines/arrows break `_hitTest`, eraser & drag bounds; live underline shifts on release; signature box shows hardcoded `'VISUAL SIGNATURE'` text; `saveDocument` wipes children) |
| **F-27** | True Content Redaction | TESTED | `PdfToolsScreen` -> `AdvancedPdfService.flattenAndRedactPdf` / `RasterRedactionScreen` -> `permanentlyMosaicImageFile` | **BROKEN / DEFECTIVE** (`flattenAndRedactPdf` forces A4 portrait on all pages; `PdfToolsScreen` hardcodes `width: 500`; `RasterRedactionScreen` forces `AspectRatio(0.72)` + `BoxFit.fill` and does not save into SQLite Vault) |
| **F-28** | On-Device Latin OCR | TESTED | `OcrService.extractText` (`OcrScript.latin`) -> `google_mlkit_text_recognition` -> `PageOcrResult` | **IMPLEMENTED (HW UNVERIFIED)** |
| **F-29** | Searchable PDF Generation | TESTED | `PdfService.generatePdf` (`ocrResultsByPage`) -> `pw.Font.ttf` (`NotoSansBengali-Regular.ttf`) + invisible positioned text | **BROKEN** (Divides original-res `OcrBoundingBox` by resized `out.width`/`out.height`, misaligning/clipping text on any image > `maxEdgePx`; no font fallback for non-Bengali Unicode) |
| **F-30** | Full-Text Document Library Search | TESTED | `HomeScreen` / `DocumentsLibraryScreen` -> `AppDatabaseService.searchDocumentsWithSnippets` (`documents_fts` + `buildFtsMatchQuery`) | **PARTIAL / DEFECTIVE** (Works on direct DB writes, but `saveDocument` cascade deletes `document_ocr` and Cloud/Device Sync bypass `documents_fts` population) |
| **F-31** | Bangla / Indic Script OCR | TESTED | `OcrService.extractText` (`bengali` / `mixedBengaliEnglish`) -> `MainActivity.kt` -> `TesseractOcrEngine.kt` -> `normalizeBanglaNumerals` | **BROKEN** (`normalizeBanglaNumerals` injects literal `"$1"` before space+`[,;:]`; native activity executor lacks destroy/lifecycle guard; recreates `TessBaseAPI` on full-res bitmap per call) |
| **F-32** | Document Translation | TESTED | `TranslateScreen` -> `TranslationService.translate` (`google_mlkit_translation` + `translator` fallback) -> `exportAsPdf` | **PARTIAL / DEFECTIVE** (`Download Offline Packs` button hardcoded to `_downloadEnBnPacks` regardless of chosen languages; `ShareParams` omits `mimeType: 'application/pdf'`) |
| **F-33** | Business Card Contact Extraction | TESTED | `BusinessCardDialog` -> `BusinessCardService.extractFromImage` -> `.vcf` `exportVCardFile` | **PARTIAL** (Unchecked `setState` after `await` if dialog dismissed; hardcodes `mixedBengaliEnglish`) |
| **F-34** | Receipt & Invoice Extraction | TESTED | `ReceiptDialog` -> `ReceiptParserService.extractFromImage` -> `parseDecimalAmount` -> `exportCsvFile` | **DEFECTIVE** (`parseDecimalAmount` fails on integer totals without `.dd`; hardcodes `mixedBengaliEnglish`; unchecked `setState`; 4 leaked `TextEditingController`s) |
| **F-35** | AI Document Summary & Q&A | TESTED | `AiDocumentSheet` -> `AiDocumentService` (extractive local summary/QA/entities + `semanticSearchVault`) | **PARTIAL** (`ExternalAiProvider` consent/hook defined in service but completely unwired in `AiDocumentSheet`; unchecked `setState`) |
| **F-36** | Nested Folders Organization | TESTED | `DocumentsLibraryScreen` -> `AppDatabaseService.createFolder` / `getFolderHierarchy` / `getFolderAncestors` | **PARTIAL / DEFECTIVE** (`Scan to Folder` loses `_currentFolderId`; backup/sync folder imports lack topological parent-before-child ordering) |
| **F-37** | Color-Coded Tags | TESTED | `DocumentsLibraryScreen` / `DocumentViewerScreen` -> `AppDatabaseService` `tags` & `document_tags` | **PARTIAL / DEFECTIVE** (`document_tags` wiped on any `saveDocument` / `saveDocumentWithPages` call due to `ON DELETE CASCADE`) |
| **F-38** | Smart Filename Templates | TESTED | `SettingsScreen` -> `ScanPreferencesService` -> `SmartFilenameService.resolveUniqueFilename` -> `AppDatabaseService.renameDocument` | **PARTIAL / DEFECTIVE** (`duplicateDocument` and `renameDocument` can collide and overwrite existing export PDFs on disk) |
| **F-39** | Trash & Soft-Delete Recovery | TESTED | `HomeScreen` / `DocumentsLibraryScreen` -> `softDelete` -> `TrashScreen` -> `restoreDocument` / `permanentlyDelete` / `purgeExpiredTrash` | **IMPLEMENTED** |
| **F-40** | Batch Document Actions | TESTED | `HomeScreen` / `DocumentsLibraryScreen` multi-select -> move, tag, `BatchMergeService`, delete | **PARTIAL / DEFECTIVE** (`home_screen.dart:170` & `documents_library_screen.dart:808` batch tag/move/favorite paths or `saveDocument` calls risk cascade wipe) |
| **F-41** | System Share Sheet Integration | TESTED | `SharePlus.instance.share(ShareParams(...))` across Viewer, Library, Tools, PdfTools, Translate, Redaction | **PARTIAL** (Several share calls omit `mimeType` and fail to refresh library/prefs) |
| **F-42** | Automated Background Cloud Export | TESTED | `SettingsScreen` -> `CloudTransportService` (WebDAV HTTP) + `CloudBackupService` -> `.scaneliq` ZIP | **BROKEN / UNWIRED** (`isScheduledBackupDue` is never called anywhere; WebDAV sheet skips saving edits if password field left blank and `'Upload Now'` sends unencrypted backup) |
| **F-43** | Encrypted Cloud Backup & Multi-Device Sync | TESTED | `SettingsScreen` -> `CloudBackupService` / `DeviceSyncService` -> AES-256 ZIP / V2 AES-256-CBC JSON -> LWW merge | **BROKEN / DEFECTIVE** (`DeviceSyncService` exports raw sender OS filepaths, omits `document_ocr`/`document_bookmarks`/binaries, unconditionally overwrites `pages`; `SettingsScreen` never invalidates Riverpod providers after restore/import; `CloudBackupService` keys binaries by `p.basename`) |
| **F-44** | 100% Offline Local-First | TESTED | Local SQLite, Vault, pure-Dart image engine, offline Tesseract & ML Kit | **PARTIAL** (`scaneliq_typography.dart` calls `GoogleFonts` runtime loader instead of bundled local fonts except NotoSansBengali) |
| **F-45** | Zero Mandatory User Accounts | TESTED | Direct entry to `/scans` with no auth wall | **IMPLEMENTED** |
| **F-46** | Biometric App Lock & PIN Security | TESTED | `MainNavigationShell` -> `AppLockScreen` -> `AppLockService` (PBKDF2 + `FlutterSecureStorage` + `local_auth`) -> `PrivacyShieldService` | **PARTIAL / DEFECTIVE** (Auto-submit depends on `SharedPreferences` `app_lock_ui_pin_length` without a manual Submit button -> lockout risk if prefs cleared/desynced; `FLAG_SECURE` waits until Dart `init()`) |
| **F-47** | Automated Stale Temp Cleanup | TESTED | `main.dart` `_runStartupHousekeeping` -> `AppStorageService.purgeOldTemp` & `purgeExpiredTrash` | **IMPLEMENTED** (Non-unique `${pageId}_tmp` temp filenames in `AppStorageService` can collide under concurrency) |

### C.2 Reconciliation Against the 157-Feature Matrix (`research-output/SCANELIQ_FINAL_FEATURE_MATRIX.md`)

`research-output/SCANELIQ_FINAL_FEATURE_MATRIX.md` summarizes a **157-feature parity baseline** across **59 representative table rows** (`#1–#17`, `#35–#52`, `#58`, `#65–#66`, `#75–#78`, `#82–#91`, `#95`, `#115`, `#120–#121`, `#124`, `#141–#142`) and already marks **Feature #65 (X.509 PKI Digital Signature)**, **#95 (Handwriting Recognition)**, and **#121 (Document Template Packs)** as `MISSING / DEFERRED`. Against the live Dart/Kotlin code:
- **Camera & Capture (`#1–#17`):** Claimed `FULLY IMPLEMENTED` / `HW UNVERIFIED`, yet `#2`/`#14`/`#15` suffer camera sensor rotation + overlay mismatch (`document_edge_detector.dart`, `continuous_camera_screen.dart`), and ID Card Stitching breaks batch sessions (`scanner_studio_provider.dart:585`).
- **Library, Organization & Search (`#35–#52`):** Claimed `FULLY IMPLEMENTED`, yet `#44` (`documents_fts`) is de-synchronized by `saveDocument` cascade wipes, `CloudBackupService`, and `DeviceSyncService`, and `#46` (`Images` filter in `documents_library_screen.dart:954-958`) contains duplicate/redundant `if (hasPdf)` branches.
- **PDF Suite (`#58`, `#65–#66`, `#75–#78`):** Claims `#76` PDF-to-image, `#66` Watermark, `#78` Share are complete, yet `PdfToolsScreen._compressPdf` and `_pdfToImages` omit DB vault registration & `mimeType`, `_stitchLongImage` duplicates files and passes `exportPath: null`, and `flattenAndRedactPdf` breaks non-A4 page dimensions.
- **OCR, Translation & Intelligence (`#82–#91`, `#115`):** Claims `#83/#84/#89/#115` are `FULLY IMPLEMENTED`, yet `#83/#84` (`OcrService.normalizeBanglaNumerals`) injects `$1`, `#89` (`PdfService.generatePdf`) misaligns OCR boxes on resized pages, and `#115` (`CountCamScreen`) misplaces overlay boxes/taps on letterboxed images and double-charges quota on preset switches.
- **Cloud, Sync & Subscription (`#141–#142`, Stage 10):** Auto-backup scheduling (`isScheduledBackupDue`) is completely unwired, multi-device sync lacks binary files and OCR/bookmarks, and `SubscriptionService` quotas are enforced only in `CountCamScreen` (`count_cam_screen.dart:115`) while completely un-metered in OCR, AI Summary, Offline Translation, and Batch PDF Export.

---

## D. Data Type Error Report

| ID | File & Symbol | Line(s) | Actual Code / Type | Expected Type / Behavior | Why It Fails | Affected Features | Severity | Confidence |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **DT-01** | `lib/features/documents/presentation/document_viewer_screen.dart` `_openPageEditorSheet` & `lib/features/editor/presentation/edit_page_screen.dart` `onApply` | `edit_page_screen.dart:422-438`, `document_viewer_screen.dart:470-507` | `void Function(EditRecipe) onApply` (synchronous `void` callback invoked inside `async` save flow) | `Future<void> Function(...)` awaited before regeneration, accepting full edited page list | `_saveAndApply()` invokes synchronous `widget.onApply(...)`; in `DocumentViewerScreen`, `onApply` fires unawaited `async` DB writes (`saveDocumentWithPages` + `_regeneratePdf()`), racing with `Navigator.pop` and PDF reload while discarding multi-page changes | F-02, F-12, F-17 | **CRITICAL** | **CONFIRMED** |
| **DT-02** | `lib/core/models/document_models.dart` `PerspectiveQuad.fromMap` & `CleanupPatch.fromMap` | `document_models.dart:411-419, 466-469` | `(map['x1'] as num).toDouble()`, `(map['radius'] as num).toDouble()` (non-nullable cast) | Safe nullable parse with fallback `(map['x1'] as num?)?.toDouble() ?? ...` | Legacy/corrupted/partial JSON maps missing any coordinate key throw a `TypeError` (`type 'Null' is not a subtype of type 'num'`) during `DocumentPage.fromMap`, crashing library load instead of recovering default quad/skipping patch | F-04, F-12, F-16 | **HIGH** | **CONFIRMED** |
| **DT-03** | `lib/core/models/document_models.dart` `EditRecipe.fromMap` | `document_models.dart:588, 597, 604, 623` | Checks `is Map<String, dynamic>`, casts `as int?` for `rotationDegrees` and `recipeVersion` | Accepts `Map<dynamic, dynamic>` and parses integers via `(val as num?)?.toInt()` | Cross-isolate messages, test fixtures, or backup JSON deserializing untyped `Map` or `double`-encoded JSON integers (e.g., `90.0` or `1.0`) fail the strict type check (`is Map<String, dynamic>`) or throw `TypeError` on `as int?` | F-12, F-42, F-43 | **MEDIUM** | **CONFIRMED** |
| **DT-04** | `lib/core/models/document_models.dart` `ScannedDocument.copyWith` & `DocumentPage.copyWith` | `document_models.dart:154, 249` | Standard nullable optional parameters (`String? exportPath`, `String? processedPath`) with `?? this.exportPath` | Explicit `clearExportPath` / `clearProcessedPath` flag or sentinel value | Impossible to reset `exportPath` back to `null` (e.g., reverting to unexported draft) or clear `processedPath` back to `null` (resetting edits to raw original) via `copyWith` | F-04, F-12 | **MEDIUM** | **CONFIRMED** |
| **DT-05** | `lib/features/intelligence/data/receipt_parser_service.dart` `parseDecimalAmount` | `receipt_parser_service.dart:242-255` | `RegExp(r'\d+(?:,\d{3})*(?:\.\d{2})')` requires `.dd` decimals and ignores integer totals | Parse both `500.00` and integer currency strings like `৳ 500`, `Total: 1200` into `double?` | Regex patterns requiring fractional `.dd` decimals return `null` on integer totals common in Bangladeshi/local receipts (e.g. `Total 500`), leaving `ParsedReceipt.totalAmount` at `0.0` | F-34 | **HIGH** | **CONFIRMED** |
| **DT-06** | `lib/features/pdf/data/pdf_service.dart` `generatePdf` searchable OCR coordinate scaling | `pdf_service.dart:54-60, 275` | `final scaledX = dx + (box.left / out.width) * renderedW;` (`double` dividing unscaled pixel `box.left` by post-resize `int out.width`) | Divide by original image dimensions `(preResizeWidth, preResizeHeight)` or scale `OcrBoundingBox` into `out` pixel space | Type-valid Dart arithmetic produces silent domain/unit mismatch (`original px / resized px`), yielding ratios `> 1.0` whenever `originalEdge > maxEdgePx` | F-29 | **CRITICAL** | **CONFIRMED** |
| **DT-07** | `ShareParams` `XFile` calls in `pdf_tools_screen.dart`, `document_viewer_screen.dart`, `translate_screen.dart`, `raster_redaction_screen.dart` | `pdf_tools_screen.dart:758, 1075`, `document_viewer_screen.dart:746, 878`, `translate_screen.dart:509`, `raster_redaction_screen.dart:186` | `XFile(path)` without explicit `mimeType` | `XFile(path, mimeType: 'application/pdf')` or `'image/jpeg'` | Omitting MIME metadata causes Android Sharesheet target filtering to misclassify or hide PDF/image receivers (contrasting with `pdf_tools_screen.dart:621, 1509` and `tools_screen.dart:303` which do set `mimeType`) | F-41 | **LOW** | **CONFIRMED** |

---

## E. Programming Bug Report

### E.1 Critical Bugs

#### BUG-01 — `INSERT OR REPLACE` (`ConflictAlgorithm.replace`) + `ON DELETE CASCADE` Silently Wipes Child Tables on Existing Documents
- **Files & Lines:**
  - Schema FKs: [app_database_service.dart](file:///c:/Scaneliq/lib/features/documents/data/app_database_service.dart#L79-L284) (`ON DELETE CASCADE` on lines `79, 111, 120, 142-143, 155, 205, 221, 246-247, 284, 1403`)
  - Upsert methods: `saveDocument` (`lines 976-981`), `saveDocumentWithPages` (`lines 987-1010`), `CloudBackupService.restore` ([cloud_backup_service.dart:506, 531, 542, 575](file:///c:/Scaneliq/lib/features/cloud_sync/data/cloud_backup_service.dart#L506-L575)), `DeviceSyncService.importSyncPackage` ([device_sync_service.dart:538](file:///c:/Scaneliq/lib/features/cloud_sync/data/device_sync_service.dart#L538))
  - Affected Callers: [home_screen.dart:170](file:///c:/Scaneliq/lib/features/documents/presentation/home_screen.dart#L170), [documents_library_screen.dart:808](file:///c:/Scaneliq/lib/features/documents/presentation/documents_library_screen.dart#L808), [document_viewer_screen.dart:206, 292, 499](file:///c:/Scaneliq/lib/features/documents/presentation/document_viewer_screen.dart#L206-L499), [pdf_page_organizer_screen.dart:183, 321](file:///c:/Scaneliq/lib/features/pdf/presentation/pdf_page_organizer_screen.dart#L183-L321), [tools_screen.dart:294](file:///c:/Scaneliq/lib/features/settings/presentation/tools_screen.dart#L294), [scan_session_provider.dart:648](file:///c:/Scaneliq/lib/features/scanner/presentation/scan_session_provider.dart#L648).
- **Actual Behavior:** SQLite executes `INSERT OR REPLACE` by first `DELETE`-ing the colliding primary-key row in `documents` and then `INSERT`-ing the new row. Because SQLite foreign keys enforce `ON DELETE CASCADE`, calling `saveDocument(existingDoc)` **permanently deletes every row in `pages`, `document_tags`, `document_ocr`, and `document_bookmarks` for that document**. Calling `saveDocumentWithPages` deletes `document_tags`, `document_ocr`, and `document_bookmarks`. Furthermore, in `DocumentViewerScreen` (`line 499`), saving pages and then calling `_regeneratePdf()` (`line 206`) deletes the newly saved pages immediately afterward.
- **Expected Behavior:** Updating an existing document row must use `INSERT ... ON CONFLICT(id) DO UPDATE SET ...` (or targeted `UPDATE` when existing) so foreign-key children are preserved untouched.
- **Affected Features:** F-04, F-12, F-17, F-21, F-22, F-24, F-25, F-26, F-30, F-37, F-40, F-42, F-43.
- **Why Tests Missed It:** `test/database_persistence_test.dart`, `test/organization_and_batch_test.dart`, and `test/phase5_pdf_engine_test.dart` construct inline test DBs/fixtures that either omit `ON DELETE CASCADE` or do not call `saveDocument(existing)` and assert surviving `pages`/`tags`/`document_ocr`/`document_bookmarks` rows afterward.
- **Severity / Confidence:** `CRITICAL` / `CONFIRMED`.

#### BUG-02 — Searchable PDF Invisible OCR Bounding Boxes Misaligned Whenever Image Exceeds `maxEdgePx`
- **Files & Lines:** [pdf_service.dart:54-60, 275, 282-284](file:///c:/Scaneliq/lib/features/pdf/data/pdf_service.dart#L275-L284)
- **Actual Behavior:** `_processPagesInIsolate` downscales pages exceeding `input.maxEdgePx` (`1754`, `2338`, or `3508` px depending on `PdfQualityPreset`), returning `out.width x out.height`. Inside `generatePdf`, `scaledX = dx + (box.left / out.width) * renderedW` (and equivalent `scaledY`/`scaledW`/`scaledH`) divides **full-resolution** OCR coordinates (`box`) computed prior to resizing by **downscaled** `out.width`/`out.height`. Additionally, `boxFont = boxHasUnicode ? unicodeFont : null` (`lines 282-284`) uses `NotoSansBengali-Regular.ttf` without a `fontFallback` list for other Unicode symbols/scripts.
- **Expected Behavior:** OCR bounding boxes must be normalized against the source image dimensions in which OCR ran (or scaled proportionally before division by `out.width`/`out.height`), and `pw.TextStyle` should supply `fontFallback` covering ASCII/Latin/punctuation glyphs.
- **Affected Features:** F-18, F-28, F-29, F-31.
- **Why Tests Missed It:** `test/pdf_generation_test.dart:202` and `test/stage6_bengali_ocr_and_pdf_test.dart:169` pass `600x800` images, which are smaller than `maxEdgePx` (`1754+`), so no resize occurs (`original == out`).
- **Severity / Confidence:** `CRITICAL` / `CONFIRMED`.

#### BUG-03 — `OcrService.normalizeBanglaNumerals` Injects Literal `"$1"` Into OCR Output
- **Files & Lines:** [ocr_service.dart:460-479](file:///c:/Scaneliq/lib/features/ocr/data/ocr_service.dart#L460-L479) (`line 468`)
- **Actual Behavior:** Line `468` executes:
  ```dart
  normalized = normalized.replaceAll(RegExp(r'[ \t]+([,;:])'), r'$1');
  ```
  In Dart, `String.replaceAll` treats the second argument as a literal string, NOT a regex backreference (`replaceAllMapped` is required for group substitution). Every occurrence of whitespace before `,`, `;`, or `:` (e.g., `"Total : 500"`, `"Name , Date"`) becomes `"Total$1 500"`, `"Name$1 Date"`.
- **Expected Behavior:** Use `replaceAllMapped(RegExp(r'[ \t]+([,;:])'), (m) => m.group(1)!)` so spacing is normalized cleanly without corrupting extracted text, receipts, business cards, FTS search, or translation input.
- **Affected Features:** F-28, F-30, F-31, F-32, F-33, F-34, F-35.
- **Why Tests Missed It:** `test/stage6_bengali_ocr_and_pdf_test.dart:93` uses `'তারিখ: ১২/০৫/২০২৬ ।'`, which contains spaces before `।` (handled earlier) and **no space** before `:`, never matching `[ \t]+([,;:])`.
- **Severity / Confidence:** `CRITICAL` / `CONFIRMED`.

#### BUG-04 — `ReviewPagesScreen` Opens `DocumentViewerScreen` With Empty `pages` List
- **Files & Lines:** [review_pages_screen.dart:80-88, 125-128, 199-203](file:///c:/Scaneliq/lib/features/editor/presentation/review_pages_screen.dart#L80-L203), [document_viewer_screen.dart:533, 847, 1439](file:///c:/Scaneliq/lib/features/documents/presentation/document_viewer_screen.dart#L533-L1439)
- **Actual Behavior:** After `saveDocumentWithPages` commits the scanned pages to SQLite, `ReviewPagesScreen` constructs a `ScannedDocument` omitting `pages: session.pages` (leaving `pages = const []`) and pushes `DocumentViewerScreen(document: finalizedDoc)`. Immediately in the viewer, features relying on `widget.document.pages`—immediate OCR extraction (`533`), `'Export Pages as JPEG'` (`847`), thumbnail rail page previews (`1439`), and page editing—fail or see zero pages until the user exits and reloads from SQLite.
- **Expected Behavior:** Pass `pages: session.pages` on `finalizedDoc` (and make `DocumentViewerScreen` hydrate pages from DB if `pages.isEmpty && pageCount > 0`).
- **Affected Features:** F-03, F-17, F-20, F-21, F-28, F-31.
- **Why Tests Missed It:** Unit/widget tests inspect `ReviewPagesScreen` and `DocumentViewerScreen` separately with pre-populated mock documents rather than exercising the post-save viewer transition end-to-end.
- **Severity / Confidence:** `CRITICAL` / `CONFIRMED`.

#### BUG-05 — `EditPageScreen` Discards Multi-Page Edits From `DocumentViewerScreen` & Races Async DB/PDF Updates
- **Files & Lines:** [edit_page_screen.dart:422-438](file:///c:/Scaneliq/lib/features/editor/presentation/edit_page_screen.dart#L422-L438), [document_viewer_screen.dart:470-507](file:///c:/Scaneliq/lib/features/documents/presentation/document_viewer_screen.dart#L470-L507)
- **Actual Behavior:** Inside `EditPageScreen._saveAndApply`:
  ```dart
  final allInSession = _editablePages.every(...);
  if (allInSession && sessionState.pages.isNotEmpty) {
    ...
  } else {
    widget.onApply(initialTarget.editRecipe);
  }
  ```
  When opened from `DocumentViewerScreen`, `allInSession` is `false`. Therefore, **all edits, reorders, rotations, and duplications performed on pages other than `initialTarget` are silently discarded**, and only `initialTarget.editRecipe` is passed synchronously back via `void Function(EditRecipe) onApply`. Meanwhile `DocumentViewerScreen._openPageEditorSheet` invokes unawaited async `saveDocumentWithPages` (`499`) and `_regeneratePdf()`, causing DB writes, cascade deletes (`BUG-01`), and PDF regeneration to race each other.
- **Expected Behavior:** Support an async `Future<void> Function(List<DocumentPage>)? onApplyPages` callback awaited before `Navigator.pop`, persisting all modified/reordered pages atomically before regenerating the PDF.
- **Affected Features:** F-02, F-12, F-13, F-14, F-15, F-16, F-17.
- **Why Tests Missed It:** `test/phase4_scan_editor_test.dart` tests `EditPageScreen` primarily when backed by `scanSessionProvider` (where `allInSession == true`), never multi-page viewer editing.
- **Severity / Confidence:** `CRITICAL` / `CONFIRMED`.

---

### E.2 High-Severity Bugs

#### BUG-06 — ID Card 2-in-1 Mode Wipes Entire Capture Session, Orphans Files, and Fails to Reset Step
- **Files & Lines:** [scanner_studio_provider.dart:561-592](file:///c:/Scaneliq/lib/features/scanner/presentation/scanner_studio_provider.dart#L561-L592), [scan_session_provider.dart:584-604](file:///c:/Scaneliq/lib/features/scanner/presentation/scan_session_provider.dart#L584-L604)
- **Actual Behavior:** After capturing front (`idCardStep == 0 -> 1`) and back sides (`idCardStep == 1`), `ScannerStudioNotifier` calls `await sessionNotifier.replaceWithSinglePage(stitchedJpg)`. `replaceWithSinglePage` replaces ALL `state.pages` with the single `[stitchedJpg]` page (erasing any documents captured earlier in the batch, leaving their files orphaned on disk) and never resets `state = state.copyWith(idCardStep: 0)`.
- **Expected Behavior:** Replace only the front/back temporary pair (or append the stitched A4 page and clean up temporary side files) and reset `idCardStep` to `0`.
- **Severity / Confidence:** `HIGH` / `CONFIRMED`.

#### BUG-07 — Camera Sensor Orientation Ignored in Live Edge Detection + Unaligned Overlay Geometry
- **Files & Lines:** [document_edge_detector.dart:24-72, 175](file:///c:/Scaneliq/lib/features/scanner/data/document_edge_detector.dart#L24-L175), [camera_studio_controller.dart:200-217](file:///c:/Scaneliq/lib/features/scanner/data/camera_studio_controller.dart#L200-L217), [continuous_camera_screen.dart:587-611](file:///c:/Scaneliq/lib/features/scanner/presentation/continuous_camera_screen.dart#L587-L611)
- **Actual Behavior:** `CameraFrameData.fromCameraImage` reads raw `yuv420` sensor buffer dimensions (`image.width x image.height`, typically landscape on Android) without rotating by `CameraDescription.sensorOrientation`. `DocumentEdgeDetector` therefore outputs landscape-oriented `PerspectiveQuad` coordinates, which `ContinuousCameraScreen` renders across a full-screen `Stack` (`line 587`) rather than aligned inside the portrait `Center(child: AspectRatio(...))` camera preview (`line 592`), and later attaches as the capture `EditRecipe` quad on EXIF-upright JPEGs.
- **Expected Behavior:** Rotate/transform incoming `CameraFrameData` coordinates according to `sensorOrientation` and lens facing, and map normalized overlay coordinates exclusively over the computed preview `Rect`.
- **Severity / Confidence:** `HIGH` / `CONFIRMED`.

#### BUG-08 — Letterbox (`BoxFit.contain`) & Aspect-Ratio Distortions Across Editor, CountCam, and Redaction Overlays
- **Files & Lines:**
  - `EditorPreviewStage`: [editor_preview_stage.dart:165, 173, 185](file:///c:/Scaneliq/lib/features/editor/presentation/widgets/editor_preview_stage.dart#L165-L185)
  - `CountCamScreen`: [count_cam_screen.dart:143, 233-246, 452-505](file:///c:/Scaneliq/lib/features/scanner/presentation/count_cam_screen.dart#L143-L505)
  - `RasterRedactionScreen`: [raster_redaction_screen.dart:126, 305, 334](file:///c:/Scaneliq/lib/features/editor/presentation/raster_redaction_screen.dart#L126-L334)
- **Actual Behavior:**
  1. `EditorPreviewStage` renders crop handles, perspective corner handles, and cleanup patches over a container-sized overlay atop a `BoxFit.contain` image whose rendered box may be letterboxed vertically/horizontally, shifting touch coordinates relative to image pixels; split compare (`ClipRect`) overlays unwarped `Original` over warped `Enhanced`.
  2. `CountCamScreen` stacks `_CountBoxesPainter` and `_handleCanvasTap` across the full `Stack` while rendering `Image.file(..., fit: BoxFit.contain)`, causing bounding boxes and manual object markers to drift off objects whenever container aspect ratio differs from photo aspect ratio.
  3. `RasterRedactionScreen` forces `AspectRatio(aspectRatio: 0.72)` (`line 305`) and `BoxFit.fill` (`line 334`), stretching landscape photos, and saves mosaiced JPEGs without adding/updating a Vault entry in SQLite.
- **Expected Behavior:** Compute actual rendered image `Rect` using decoded image dimensions and `applyBoxFit(BoxFit.contain, ...)` (like PDF annotation coordinate mapping) and persist redacted outputs into Vault/SQLite cleanly.
- **Severity / Confidence:** `HIGH` / `CONFIRMED`.

#### BUG-09 — `PdfAnnotationStudio` Negative-Span Vector Shapes Fail Selection/Eraser, Underline Shifts, Signature Displays Placeholder
- **Files & Lines:** [pdf_annotation_studio.dart:187-200, 294-319, 397-420, 614, 632-698](file:///c:/Scaneliq/lib/features/pdf/presentation/widgets/pdf_annotation_studio.dart#L187-L698)
- **Actual Behavior:**
  1. `PdfShapeKind.line` and `PdfShapeKind.arrow` store signed (`dx`, `dy`) deltas in `width`/`height` (`lines 408-420`). When drawn right-to-left or bottom-to-top (`width < -0.04` or `height < -0.04`), `_hitTest` constructs `Rect.fromLTWH(item.x - 0.02, item.y - 0.02, item.width + 0.04, item.height + 0.04)` with negative width/height—returning an empty/inverted rect that **cannot be tapped, moved, or erased** (`BUG-09a`).
  2. `_handlePanUpdate` clamps `(x).clamp(0.0, 1.0 - item.width)` which breaks/throws `ArgumentError` when `item.width < 0` makes `1.0 - item.width > 1.0` or `width > 1.0` (`BUG-09b`).
  3. Live underline drag preview draws at `y = a.dy`, while committed underline paints at bottom of rect (`y + 0.008 * H`), visibly jumping downward on pen up.
  4. Placed visual signatures render a hardcoded `'VISUAL SIGNATURE'` placeholder label (`line 614`) in the studio preview rather than the captured PNG bytes.
- **Expected Behavior:** Normalize `Rect` (`minX..maxX, minY..maxY`) + segment distance hit-testing for `line`/`arrow`, clamp bounds properly, align underline preview and committed Y coordinate, and decode/render actual signature `Uint8List` preview.
- **Severity / Confidence:** `HIGH` / `CONFIRMED`.

#### BUG-10 — `ImageProcessingService` `clamp` Crashes, Cleanup Reads Modified `dst`, and Per-Pixel Allocation
- **Files & Lines:** [image_processing_service.dart:34-40, 217-255, 828-851](file:///c:/Scaneliq/lib/core/image_processing/image_processing_service.dart#L34-L851)
- **Actual Behavior:**
  1. `crop` bounds at `lines 36, 39` execute `.clamp(10, working.width - x)` and `.clamp(10, working.height - y)`. If `x > working.width - 10` or `y > working.height - 10` (or `working.width < 10`), `min > max` throws `ArgumentError`.
  2. `applyCleanupPatches` (`line 830`) calls `(patch.radius * w).round().clamp(3, w ~/ 4)`, which throws `ArgumentError` whenever `w < 12`, and `line 851` samples blurred neighbor pixels from `dst` (partially overwritten) instead of unmodified `src`.
  3. `_sampleBilinear` (`lines 217-255`) allocates `img.Image(width: 1, height: 1)` on **every single pixel** during perspective warping—creating millions of short-lived image objects for a 12 MP capture.
- **Severity / Confidence:** `HIGH` / `CONFIRMED`.

#### BUG-11 — `AdvancedPdfService.flattenAndRedactPdf` Forces A4 Portrait & `PdfToolsScreen` Hardcodes Width `500`
- **Files & Lines:** [advanced_pdf_service.dart:1752-1865](file:///c:/Scaneliq/lib/features/pdf/data/advanced_pdf_service.dart#L1752-L1865) (`lines 1858-1861`), [pdf_tools_screen.dart:1283-1285](file:///c:/Scaneliq/lib/features/pdf/presentation/pdf_tools_screen.dart#L1283-L1285) (`x: 50`, `width: 500`)
- **Actual Behavior:** `flattenAndRedactPdf` creates `final newPage = flatDoc.pages.add();` without matching the source page's `size`/orientation (`flatDoc.pageSettings`), stretching landscape, Legal, or receipt PDFs into A4 portrait. In `PdfToolsScreen`, manual PDF redaction inputs hardcode A4 dimensions (`width: 500`, `x: 50`) rather than reading source page bounds or supporting visual selection.
- **Severity / Confidence:** `HIGH` / `CONFIRMED`.

#### BUG-12 — `DocumentViewerScreen` Stale PDF Cache, Desynced Thumbnail Rail, and Static Zoom Label
- **Files & Lines:** [document_viewer_screen.dart:59, 92, 134, 1109, 1219, 1321-1349, 1424-1439](file:///c:/Scaneliq/lib/features/documents/presentation/document_viewer_screen.dart#L1109-L1439)
- **Actual Behavior:**
  1. `PdfViewer.file` (`line 1219`) has no revision `Key` incorporating file timestamp/modification generation; overwriting `_activeDoc.exportPath` after annotation, page reorder, or re-filter leaves PDFium rendering cached stale bytes until reopening the screen.
  2. `_zoomFactor` state only updates on `-`/`+` toolbar buttons (`1321-1349`) and drifts out of sync with pinch-to-zoom gestures.
  3. `_buildThumbnailStrip` (`1424-1439`) relies on `widget.document.pages` rather than `_totalPages` / PDFium pages, failing on imported PDFs or empty-page docs (`BUG-04`).
- **Severity / Confidence:** `HIGH` / `CONFIRMED`.

#### BUG-13 — `CloudBackupService` & `DeviceSyncService` Data-Integrity Gaps & `SettingsScreen` Unwired / Unsafe Cloud Flows
- **Files & Lines:**
  - [cloud_backup_service.dart:207, 225, 467-575](file:///c:/Scaneliq/lib/features/cloud_sync/data/cloud_backup_service.dart#L207-L575)
  - [device_sync_service.dart:338-348, 473-551](file:///c:/Scaneliq/lib/features/cloud_sync/data/device_sync_service.dart#L338-L551)
  - [cloud_transport_service.dart:139](file:///c:/Scaneliq/lib/features/cloud_sync/data/cloud_transport_service.dart#L139)
  - [settings_screen.dart:447-880](file:///c:/Scaneliq/lib/features/settings/presentation/settings_screen.dart#L447-L880) (`lines 496, 649-675, 867`)
- **Actual Behavior:**
  1. **Scheduled Auto-Backup is Phantom:** `CloudTransportService.isScheduledBackupDue` (`line 139`) has **zero callers** anywhere in `lib/`.
  2. **WebDAV Settings Silently Drop Changes & Upload Unencrypted:** In `_openWebDavCloudSheet` (`settings_screen.dart:649-650`), modifying endpoint URL, username, or remote folder without re-typing a password leaves `passCtrl.text.isEmpty` and skips saving changes (or blocks save), while `'Upload Now'` (`lines 660+`) exports an unencrypted archive when no passphrase prompt is shown.
  3. **Backup & Sync Do Not Rebuild FTS5 or Sort Nested Folders Topologically:** Inserting `folders` in arbitrary DB query order risks `FOREIGN KEY (parent_id)` constraint failures when a child folder precedes its parent, and `documents_fts` is never rebuilt after restore/sync import. `CloudBackupService` also flattens ZIP entries by `p.basename(...)` (`207, 225`), risking filename collisions across documents.
  4. **`DeviceSyncService` Unusable Across Devices:** Exports `docs`, `folders`, `tags`, `document_tags` ONLY—omitting `document_ocr`, `document_bookmarks`, and ALL actual image/PDF files while writing raw sender OS paths (`export_path`, `original_path`, `processed_path`) into SQLite and unconditionally replacing `pages` (`line 538`) even when the local `documents` row is newer (`LWW` skips parent overwrite but overwrites `pages` anyway!).
  5. **UI Not Refreshed After Restore/Import:** `SettingsScreen._restoreBackup` and `_openSyncModal` never invalidate `documentsListProvider`, `foldersListProvider`, `tagsListProvider`, or `latestDraftProvider`.
- **Severity / Confidence:** `HIGH` / `CONFIRMED`.

#### BUG-14 — `AppDatabaseService.duplicateDocument` & `renameDocument` Can Overwrite Colliding Export PDFs on Disk
- **Files & Lines:** [app_database_service.dart:1018-1106, 1325-1365](file:///c:/Scaneliq/lib/features/documents/data/app_database_service.dart#L1018-L1365)
- **Actual Behavior:** When renaming a document (`renameDocument`) or duplicating one (`duplicateDocument`) produces a filename matching an existing export PDF in `exportsDir`, direct `renameSync`/`copySync` overwrites the unrelated document's exported PDF instead of allocating a unique suffixed path via `SmartFilenameService.resolveUniqueFilename`.
- **Severity / Confidence:** `HIGH` / `CONFIRMED`.

#### BUG-15 — `CountCamScreen` Double-Charges Quota on Preset Switch; Other Paid Features Unmetered
- **Files & Lines:** [count_cam_screen.dart:115, 290-310](file:///c:/Scaneliq/lib/features/scanner/presentation/count_cam_screen.dart#L115-L310), [subscription_service.dart:370-425](file:///c:/Scaneliq/lib/features/subscription/data/subscription_service.dart#L370-L425)
- **Actual Behavior:** Switching object category preset on an already-loaded image re-runs `_detectObjects()` which calls `consumeQuota(SubscriptionQuotaFeature.countCam)` again, charging free-tier daily quota twice (or blocking preset switching at quota `0`). Conversely, `ocrExtraction`, `aiSummary`, `offlineTranslation`, and `batchPdfExport` never call `checkQuota` or `consumeQuota` anywhere in the codebase, and `SubscriptionService` is never refreshed at app startup.
- **Severity / Confidence:** `HIGH` / `CONFIRMED`.

---

### E.3 Medium & Low Severity Bugs

#### BUG-16 — `TranslateScreen` Offline Download Button Always Downloads English+Bengali Only
- **Files & Lines:** [translate_screen.dart:76, 171-185, 278](file:///c:/Scaneliq/lib/features/scanner/presentation/translate_screen.dart#L76-L278)
- **Actual Behavior:** The `"Offline Language Packs"` button invokes `_downloadEnBnPacks()`, downloading only `en` and `bn` ML Kit models even when the user selected Hindi, Arabic, Spanish, French, German, or Chinese.
- **Severity / Confidence:** `MEDIUM` / `CONFIRMED`.

#### BUG-17 — `PdfToolsScreen` Duplicate Files, Unregistered Outputs & Un-Disposed Controllers
- **Files & Lines:** [pdf_tools_screen.dart:146-147, 407, 513-608, 654-770, 802, 876, 1027-1084](file:///c:/Scaneliq/lib/features/pdf/presentation/pdf_tools_screen.dart#L146-L1084)
- **Actual Behavior:**
  1. `_stitchLongImage` (`513-608`) saves the stitched image to BOTH `exportsDir` and `originalsDir`, persists `exportPath: null` (`576`), and pushes `DocumentViewerScreen` without `exportPath`.
  2. `_compressPdf` and `_pdfToImages` generate output files without registering/updating records in SQLite Vault (and `PdfToolsScreen` lines `1424`, `1465` invoke `saveDocument`).
  3. Dialog `TextEditingController`s at lines `146, 147, 407, 802, 876` are never disposed.
- **Severity / Confidence:** `MEDIUM` / `CONFIRMED`.

#### BUG-18 — `DocumentsLibraryScreen` Filter Bug, Lost Folder Context & Leaked Controllers
- **Files & Lines:** [documents_library_screen.dart:126, 159, 231, 492, 601, 729, 934-958](file:///c:/Scaneliq/lib/features/documents/presentation/documents_library_screen.dart#L126-L958)
- **Actual Behavior:**
  1. `_filterAndSortDocs` (`lines 955-957`) has two consecutive `if (hasPdf)` branches where the second unconditionally rejects any PDF instead of distinguishing PDF-backed docs vs pure image scans cleanly.
  2. `'Scan to Folder'` does not preserve `_currentFolderId` on newly created session output.
  3. `_importFiles` (`line 126`) uses raw `FilePicker.pickFiles` directly instead of `GalleryImportService` size/magic-byte validation.
  4. Five dialog `TextEditingController`s (`159, 231, 492, 601, 729`) are leaked without `.dispose()`.
- **Severity / Confidence:** `MEDIUM` / `CONFIRMED`.

#### BUG-19 — `SettingsScreen`, `ToolsScreen`, and `ReceiptDialog` Controller Leaks & Missing `mounted` Guards
- **Files & Lines:**
  - `SettingsScreen`: [settings_screen.dart:372, 457, 531-534, 705-706](file:///c:/Scaneliq/lib/features/settings/presentation/settings_screen.dart#L372-L706) (`passCtrl` in backup/restore/sync dialogs and `urlCtrl`/`userCtrl`/`passCtrl`/`folderCtrl`/`nameCtrl` are never disposed — only `ctrl` at `line 304` is disposed)
  - `ToolsScreen`: [tools_screen.dart:129, 294](file:///c:/Scaneliq/lib/features/settings/presentation/tools_screen.dart#L129-L294) (`editController` leaked; `saveDocument` cascade risk + missing provider invalidation & `ScanPreferencesService` usage)
  - `ReceiptDialog`, `BusinessCardDialog`, `AiDocumentSheet`: [receipt_dialog.dart:50-60, 100-103](file:///c:/Scaneliq/lib/features/intelligence/presentation/receipt_dialog.dart#L50-L103), [business_card_dialog.dart:70-85](file:///c:/Scaneliq/lib/features/intelligence/presentation/business_card_dialog.dart#L70-L85), [ai_document_sheet.dart:74-132](file:///c:/Scaneliq/lib/features/intelligence/presentation/ai_document_sheet.dart#L74-L132) — call `setState` after `await` before checking `if (mounted)`, and `ReceiptDialog` leaks 4 inline edit `TextEditingController`s (`100-103`).
- **Severity / Confidence:** `MEDIUM` / `CONFIRMED`.

#### BUG-20 — `AppLockScreen` Auto-Submit PIN Length Desync Lockout Risk & `AppStorageService` Non-Unique Temp Names
- **Files & Lines:**
  - [app_lock_screen.dart:68, 74, 93, 161-167, 219](file:///c:/Scaneliq/lib/features/security/presentation/app_lock_screen.dart#L68-L219)
  - [app_storage_service.dart:120, 147](file:///c:/Scaneliq/lib/core/storage/app_storage_service.dart#L120-L147)
- **Actual Behavior:**
  1. Unlocking auto-submits strictly when `_enteredPin.length == _pinLength` (`4` default or `app_lock_ui_pin_length` from unencrypted `SharedPreferences`), with no manual `Unlock` button or 4/6 toggle on unlock. If `SharedPreferences` is cleared while PBKDF2 hash remains in `FlutterSecureStorage` for a 6-digit PIN, `_pinLength` defaults to `4` and auto-submits at 4 digits—locking the user out permanently until biometric unlock or app reinstall.
  2. `AppStorageService` constructs deterministic temp filenames (`'${pageId}_tmp.$extension'`, `'${pageId}_copy_tmp.$extension'`), risking write collisions if concurrent exports/writes target the same page, and `renameSync` between app dirs can fail across filesystems if storage volumes differ.
- **Severity / Confidence:** `MEDIUM` / `CONFIRMED`.

#### BUG-21 — Native `MainActivity.kt` & `TesseractOcrEngine.kt` Lifecycle & Memory Overhead; Offline Font Loading
- **Files & Lines:**
  - [MainActivity.kt:34-61, 90-93](file:///c:/Scaneliq/android/app/src/main/kotlin/com/scaneliq/scaneliq/MainActivity.kt#L34-L93)
  - [TesseractOcrEngine.kt:57-107](file:///c:/Scaneliq/android/app/src/main/kotlin/com/scaneliq/scaneliq/TesseractOcrEngine.kt#L57-L107)
  - [scaneliq_typography.dart:10, 18, 26, 34](file:///c:/Scaneliq/lib/core/theme/scaneliq_typography.dart#L10-L34), [pubspec.yaml:97-101](file:///c:/Scaneliq/pubspec.yaml#L97-L101)
- **Actual Behavior:**
  1. `MainActivity.onDestroy` shuts down `ocrExecutor`, yet queued background tasks can still invoke `runOnUiThread { result.success(...) }` after activity detachment/teardown without an alive/attached guard. `FLAG_SECURE` starts `false` at `MainActivity.onCreate` until Dart initializes `PrivacyShieldService`, leaving a brief app-switcher snapshot window on cold start.
  2. `TesseractOcrEngine.recognizeImage` allocates, initializes (`tess.init`), and recycles a fresh `TessBaseAPI` on every call over full-resolution images without downscaling or engine reuse.
  3. `scaneliq_typography.dart` invokes `GoogleFonts.instrumentSans()`, `inter()`, `jetBrainsMono()`, `notoSansBengali()` dynamically, whereas only `assets/fonts/NotoSansBengali-Regular.ttf` is bundled locally (`pubspec.yaml:101`). Strictly offline devices (`F-44`) will silently fall back to Android Roboto for `Instrument Sans` / `Inter` / `JetBrains Mono` unless bundled offline.
- **Severity / Confidence:** `MEDIUM` / `CONFIRMED`.

### E.4 Cleared Hypotheses (Verified Non-Bugs — Do NOT "Fix")
- **`ReorderableListView.onReorderItem` (`documents_library_screen.dart:639`, `pdf_page_organizer_screen.dart:447`):** Verified against Flutter 3.47 `reorderable_list.dart:83` (`onReorderItem` pre-adjusts `newIndex` for removal at `oldIndex`). Both `documents_library_screen.dart:641-642` and `pdf_page_organizer_screen.dart:283-284` call `removeAt(oldIdx)` then `insert(newIdx, ...)` directly **without** subtracting 1. Correct as written.
- **`FilePicker.pickFiles` (`documents_library_screen.dart:126`):** Verified in `file_picker-13.1.0/lib/src/file_picker.dart:24-94` that `pickFiles` has no `allowMultiple` parameter and natively enables multi-file selection (`pickFile` is the single-file method). Correct as written.

---

## F. High-Priority Risks

1. **Catastrophic Silent Vault Corruption (`CRITICAL` — Likelihood: High / Impact: Total Page & Metadata Loss):**
   Every metadata toggle (favorite, move folder, rename/export update, PDF regenerate, batch edit) on an existing scanned document flows into `AppDatabaseService.saveDocument` (`ConflictAlgorithm.replace`), firing `ON DELETE CASCADE` across `pages`, `document_tags`, `document_ocr`, and `document_bookmarks`. Users lose pages, tags, and searchability with zero error dialog.
2. **Searchable PDF & Bengali OCR Fidelity Breakdown (`CRITICAL` — Likelihood: High / Impact: Broken Core Differentiator):**
   Real-world smartphone camera photos (`~3000x4000 px`) always exceed `maxEdgePx` (`1754`–`3508`), guaranteeing `BUG-02` breaks invisible text alignment on every real camera scan. Meanwhile any Bengali/English invoice/form containing `"Label : Value"` triggers `BUG-03`, injecting `"Label$1 Value"`.
3. **Sync, Cloud Backup & Lockout Data Hazards (`HIGH` — Likelihood: Medium-High / Impact: User Lockout / Cloud Overwrite):**
   - `AppLockScreen` auto-submit PIN length mismatch (`SharedPreferences` vs `FlutterSecureStorage`) can lock out users who don't use biometrics.
   - `DeviceSyncService` writes sender device paths onto recipient SQLite tables (`BUG-13`), creating broken file cards across Android devices.
   - `SettingsScreen` `'Upload Now'` sends unencrypted ZIP archives while silently ignoring WebDAV settings edits if the password box is empty.
4. **Native Memory Pressure / OOM & Frame Drops (`HIGH` — Likelihood: Medium / Impact: Crashes on 3–4 GB RAM Android Phones):**
   Per-pixel `1x1` `img.Image` allocations in `ImageProcessingService._sampleBilinear` (`lines 217-255`), un-reused full-res `TessBaseAPI` calls in `TesseractOcrEngine.kt`, and un-disposed `TextEditingController`s across modal workflows accumulate native/Dart heap pressure.
5. **Commercial Play Store Release Blockers (`HIGH`):**
   `AppComplianceConfig` (`app_compliance_config.dart:12-24`) reads `syncfusionLicenseKey`, `syncfusionLicenseAck`, and `googleDriveClientId` via `--dart-define` / `String.fromEnvironment`, `android/app/build.gradle.kts:56-60` falls back to **debug signing** if `android/key.properties` is absent, and `SubscriptionService` lacks startup billing refresh plus quota gating across OCR/AI/Translation/PDF exports.

---

## G. Feature Connection Problems

| Flow | Broken Link in Chain | Exact Disconnection & Consequence |
| --- | --- | --- |
| **Capture -> Save -> View** | `ReviewPagesScreen` -> `DocumentViewerScreen` | [review_pages_screen.dart:80-199](file:///c:/Scaneliq/lib/features/editor/presentation/review_pages_screen.dart#L80-L199) saves pages to DB but opens viewer with `pages: const []`; OCR, JPEG export, and thumbnail strip immediately break (`BUG-04`). |
| **View -> Multi-Page Edit -> Regenerate PDF** | `DocumentViewerScreen._openPageEditorSheet` -> `EditPageScreen.onApply` | Synchronous `void Function(EditRecipe)` discards edits on other pages (`edit_page_screen.dart:438`), races DB write (`499`) + cascade delete (`206`) + `PdfViewer.file` without cache-busting `Key` (`BUG-01, BUG-05, BUG-12`). |
| **ID Card Mode -> Batch Session** | `ScannerStudioNotifier` -> `ScanSessionNotifier.replaceWithSinglePage` | [scanner_studio_provider.dart:585](file:///c:/Scaneliq/lib/features/scanner/presentation/scanner_studio_provider.dart#L585) replaces the entire session list with 1 page instead of merging/adding the stitched ID sheet, wiping prior captures (`BUG-06`). |
| **Cloud Auto-Backup Setting -> Runtime** | `SettingsScreen` -> `CloudTransportService.isScheduledBackupDue` | [cloud_transport_service.dart:139](file:///c:/Scaneliq/lib/features/cloud_sync/data/cloud_transport_service.dart#L139) is **orphaned**; neither `main.dart` housekeeping nor `SettingsScreen` nor capture completion ever triggers scheduled backup uploads (`BUG-13`). |
| **Backup Restore / Sync Import -> Home/Library UI** | `SettingsScreen._restoreBackup` / `_openSyncModal` -> Riverpod providers | Never calls `ref.invalidate(documentsListProvider)` / `foldersListProvider` / `tagsListProvider` / `latestDraftProvider`; restored scans stay invisible until app restart (`BUG-13`). |
| **Library `'Scan to Folder'` -> Save** | `DocumentsLibraryScreen` -> `ContinuousCameraScreen` -> `ScanSessionNotifier` | Selected `_currentFolderId` is not bound to the new session/draft, saving documents to Root instead of the open folder (`BUG-18`). |
| **PdfTools Output -> SQLite Library** | `PdfToolsScreen._compressPdf` / `_pdfToImages` / `RasterRedactionScreen` -> `AppDatabaseService` | Compressed PDFs, extracted images, and mosaiced redactions write to disk without creating/updating Vault DB entries; `_stitchLongImage` stores `exportPath: null` (`BUG-08, BUG-17`). |
| **Subscription Quotas -> Premium Feature Gates** | `SubscriptionService.consumeQuota` -> Feature Screens | Only [count_cam_screen.dart:115](file:///c:/Scaneliq/lib/features/scanner/presentation/count_cam_screen.dart#L115) checks/consumes quota; OCR, AI Assistant, Offline Translation, and Batch PDF Export ignore entitlements completely (`BUG-15`). |
| **AI External Cloud Hook -> UI** | `AiDocumentService.ExternalAiProvider` -> `AiDocumentSheet` | Opt-in external LLM consent/provider interface (`ai_document_service.dart:90, 111`) has zero UI controls or configuration inside `AiDocumentSheet` (`F-35`). |
| **Scan Preferences -> OCR / Share Callers** | `ScanPreferencesService` -> `ReceiptParserService`, `BusinessCardService`, `Library`, `ToolsScreen` | `ReceiptParserService` & `BusinessCardService` default to `mixedBengaliEnglish` instead of `defaultOcrScript`; `DocumentsLibraryScreen` & `ToolsScreen` share flows bypass quality/page-format/auto-OCR preferences. |
| **Offline Fonts Theme -> Assets** | `scaneliq_typography.dart` -> `pubspec.yaml` `assets/fonts/` | Requests `Instrument Sans`, `Inter`, and `JetBrains Mono` from `GoogleFonts` at runtime while only `NotoSansBengali-Regular.ttf` is bundled on disk (`BUG-21`). |

---

## H. Technical Recommendations

1. **Replace `ConflictAlgorithm.replace` With Safe Upsert Helpers (`AppDatabaseService`):**
   - Introduce `_upsertDocumentMetadata(DatabaseExecutor db, ScannedDocument doc)` using SQL `INSERT INTO documents (...) VALUES (...) ON CONFLICT(id) DO UPDATE SET title=excluded.title, folder_id=excluded.folder_id, ...` (explicitly preserving `created_at` and triggering zero `ON DELETE CASCADE`).
   - Do the same for `pages`, updating/reconciling `pages` in a transaction by comparing existing IDs and deleting only removed pages, NEVER deleting the parent `documents` row.
   - Maintain `documents_fts` centrally inside `saveDocument`, `saveDocumentWithPages`, `duplicateDocument`, `restore`, and `importSyncPackage`.
2. **Introduce Shared Coordinate-Mapping & Scaling Utilities:**
   - **Image/PDF OCR Scaling (`pdf_service.dart`):** Track `preResizeWidth` and `preResizeHeight` alongside `out` in `_PageProcessingOutput` (or rescale `OcrBoundingBox` coordinates into `out` pixel dimensions inside the worker isolate). Add font fallback list for non-Bengali Unicode glyphs.
   - **UI Overlay BoxFit Mapping:** Extract one shared helper calculating rendered image `Rect` from `(Size containerSize, Size imageSize, BoxFit.contain)` (matching `PdfAnnotationStudio`) and reuse it across `EditorPreviewStage`, `CountCamScreen`, `RasterRedactionScreen`, and `ContinuousCameraScreen` camera preview.
   - **Signed Vector Annotation Shapes (`pdf_annotation_studio.dart`):** Normalize `Rect.fromPoints(start, end)` for hit-testing, selection frames, and clamping while preserving signed `dx`/`dy` vector direction strictly for line/arrow painting.
3. **Unify Capture-to-Viewer & Multi-Page Viewer Editing Contracts:**
   - Ensure `ReviewPagesScreen` passes hydrated `pages` into `DocumentViewerScreen`, and make `DocumentViewerScreen` load pages asynchronously if passed an un-hydrated `ScannedDocument`.
   - Replace `EditPageScreen.onApply` (`void Function(EditRecipe)`) with `Future<void> Function(List<DocumentPage>)? onApplyPages` awaited before closing; assign a `ValueKey('${_activeDoc.exportPath}:${_pdfRevision}')` to `PdfViewer.file` so regenerated PDFs reload immediately.
   - Fix `ScannerStudioNotifier` ID Card stitching so `replacePairAndAppend` or `addStitchedIdPage` appends the card sheet without discarding prior batch pages and resets `idCardStep = 0`.
4. **Harden Regexes, `ImageProcessingService` Bounds, and Allocation Hotspots:**
   - Change [ocr_service.dart:468](file:///c:/Scaneliq/lib/features/ocr/data/ocr_service.dart#L468) to `replaceAllMapped(RegExp(r'[ \t]+([,;:])'), (m) => m.group(1)!)`.
   - Guard minimum dimensions before `clamp` in `crop` and `applyCleanupPatches`; read neighbor blur samples from `src` (not `dst`); rewrite `_sampleBilinear` to return `(int r, int g, int b, int a)` record and invoke `dst.setPixelRgba(...)` without per-pixel `img.Image(width: 1, height: 1)` allocations.
   - Expand `ReceiptParserService.parseDecimalAmount` to accept integer totals and read default script from `ScanPreferencesService`.
5. **Fix Cloud Backup, Device Sync, Security Lock & Quota Wiring:**
   - Topologically sort `folders` (roots before children) in `CloudBackupService` and `DeviceSyncService`; key backup archive entries by unique relative vault IDs (`<docId>/<pageId>.jpg`) rather than `p.basename`; wire `isScheduledBackupDue` into startup housekeeping / post-scan trigger; bundle/embed `data` files in P2P/device sync; always `ref.invalidate(...)` Riverpod providers after restore/sync/folder mutations.
   - Add a `min(pinLength)` + explicit `Submit` button (and optional 4/6 toggle) on `AppLockScreen` unlock, and apply `FLAG_SECURE` early inside `MainActivity.onCreate` from shared native preference when enabled.
   - Dispose all local dialog `TextEditingController`s inside `try/finally` blocks or dedicated Stateful dialog widgets, and guard all `setState` calls after `await` with `if (!mounted) return;`.

---

## I. Recommended Repair Order

Execute fixes strictly in dependency order to prevent cascading regressions across tests and UI:

| Phase | Target Components | Why This Order Comes First |
| --- | --- | --- |
| **Phase 1: Database, Storage & Model Safety (Foundation)** | `AppDatabaseService` (`ON CONFLICT DO UPDATE`, topological folder restore, `documents_fts` sync, unique filename collision checks in `renameDocument`/`duplicateDocument`), `AppStorageService` (UUID temp names, safe move fallback), `document_models.dart` (safe `fromMap` casts + `clear*` `copyWith`), **+ new regression tests proving `ON DELETE CASCADE` preservation**. | Fixes silent data loss (`BUG-01`, `BUG-14`, `BUG-20`, `DT-02`–`DT-04`) before any UI or PDF repair re-saves documents. |
| **Phase 2: OCR, Regex & Image-Processing Engine Accuracy** | `ocr_service.dart` (`replaceAllMapped` `$1` fix), `pdf_service.dart` (searchable PDF bbox scaling + fallback font), `image_processing_service.dart` (`clamp` guards, `src` read, zero-alloc `_sampleBilinear`), `TesseractOcrEngine.kt` & `MainActivity.kt` lifecycle/downscaling, **+ high-res (>2000px) & punctuation regression tests**. | Ensures every exported PDF and OCR string generated by downstream viewer/editor/intelligence flows is valid (`BUG-02`, `BUG-03`, `BUG-10`, `BUG-21`). |
| **Phase 3: Capture -> Review -> Viewer -> Editor Loop** | `document_edge_detector.dart` & `continuous_camera_screen.dart` (sensor orientation & preview rect overlay), `scanner_studio_provider.dart` (ID card batch preservation), `review_pages_screen.dart` (pass hydrated pages), `edit_page_screen.dart` & `document_viewer_screen.dart` (async multi-page `onApplyPages`, `PdfViewer` revision `Key`, zoom/thumbnail sync), `editor_preview_stage.dart` (`BoxFit.contain` box). | Repairs the flagship end-to-end scanning user journey (`BUG-04`–`BUG-08`, `BUG-12`, `DT-01`). |
| **Phase 4: PDF Suite, Annotations & True Redaction** | `pdf_annotation_studio.dart` (normalized line/arrow hit-testing, underline alignment, real signature PNG preview), `advanced_pdf_service.dart` (`flattenAndRedactPdf` page size preservation), `pdf_tools_screen.dart` & `raster_redaction_screen.dart` (Vault registration, `AspectRatio`/`BoxFit.contain`, `mimeType`, shared UI state). | Stabilizes all pro PDF productivity & redaction tools (`BUG-08`, `BUG-09`, `BUG-11`, `BUG-17`, `DT-07`). |
| **Phase 5: Cloud Backup, WebDAV, Device Sync & App Security** | `cloud_backup_service.dart`, `device_sync_service.dart`, `settings_screen.dart` (topological folders, FTS rebuild, WebDAV passwordless metadata edit, passphrase enforcement, `isScheduledBackupDue` hook, Riverpod invalidation), `app_lock_screen.dart` & `MainActivity.kt` (PIN unlock resilience + cold-start `FLAG_SECURE`). | Secures multi-device data portability and eliminates lockout & unencrypted-backup risks (`BUG-13`, `BUG-20`, `BUG-21`). |
| **Phase 6: Intelligence, Quotas, Filtering, Preferences & Widget Cleanup** | `count_cam_screen.dart` (BoxFit overlay + preset quota dedup), `subscription_service.dart` (startup refresh + remaining feature quotas), `translate_screen.dart` (selected-pair pack downloads), `receipt_parser_service.dart` (integer totals + prefs script), `documents_library_screen.dart` (`_filterAndSortDocs`, `GalleryImportService`, folder context), `tools_screen.dart`, controller disposal & `mounted` guards, offline bundled fonts (`scaneliq_typography.dart`), **followed by full device QA**. | Polishes parity features, closes UI/memory leaks, and prepares Play Store RC with release keystore & compliance flags (`BUG-15`, `BUG-16`, `BUG-18`, `BUG-19`, `DT-05`). |
