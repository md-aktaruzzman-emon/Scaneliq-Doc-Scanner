# SCANELIQ — REMEDIATION FINAL REPORT

**Date:** November 19, 2026  
**Project:** `C:\Scaneliq` (`com.scaneliq.scaneliq`) · Version `2.67.0+26700` (user version preserved)  
**Git Recovery Baseline:** `backup/pre-remediation` (`c48e69f`)  
**Design System Preserved:** Concept A — Editorial Gallery Minimal (`Gallery Alabaster #FAF9F6`, `Carbon Studio #0D0E11`, `International Ultramarine #0052FF / #3B82F6`)

---

## 1. Executive Summary

Following the baseline audit of **157 audited capabilities** and **15 cross-cutting risk items (`RISK-01`..`RISK-15`)**, all 12 remediation stages have been executed against the live Flutter codebase (`lib/`, `android/`, `assets/`, `test/`).

Every verified P0 and P1 security defect, broken engine stub, main-isolate UI block, missing database index/action, and unbuilt native bridge identified during the audit was systematically engineered, tested, and verified on host plus compiled into Android split release APKs with R8 minification active:

- **Static Analysis (`flutter analyze --no-pub`):** `No issues found!` (`0` errors, `0` warnings, `0` infos).
- **Automated Test Suite (`flutter test --no-pub`):** **201 passed, 0 failed, 0 skipped** across **33 Dart test files** (up from 180 baseline tests).
- **Android Release Build (`flutter build apk --release --split-per-abi --no-pub`):** Exited `0` in `295.5s` with `isMinifyEnabled = true`, `isShrinkResources = true`, Kotlin JNI engines (`TesseractOcrEngine.kt`, `MainActivity.kt`), JitPack (`cz.adaptech.tesseract4android:tesseract4android:4.9.0`), bundled `assets/tessdata/` + `NotoSansBengali-Regular.ttf`, and ML Kit/Billing dependencies:
  - `build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk` (`76.4 MB`)
  - `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` (`95.5 MB`)
  - `build\app\outputs\flutter-apk\app-x86_64-release.apk` (`101.3 MB`)

---

## 2. Summary of Engineering Fixes Delivered Across Stages 1–12

### Security, Privacy & Release Engineering (Stages 1 & 9A/9C)
1. **Cold-Start AppLock Fix (`lib/main.dart`, `lib/features/security/data/app_lock_service.dart`):** `AppLockService.instance.init()` now executes *before* `runApp()`, hydrating synchronous `_hasPinCached` and `_lockoutUntilEpochCached` so cold launches cannot bypass PIN/biometric barriers before visiting Settings.
2. **Android KeyStore Secret Storage:** Added `SecureKeyValueStore` (`FlutterSecureStorageKeyStore`) in `app_lock_service.dart`, automatically migrating and scrubbing `app_lock_pin_hash`, `app_lock_pin_salt`, `app_lock_failed_attempts`, and `app_lock_lockout_until_epoch` out of plaintext `SharedPreferences`.
3. **Android Screen Privacy Shield (`FLAG_SECURE`):** Implemented `com.scaneliq.scaneliq/security` in [`MainActivity.kt`](file:///c:/Scaneliq/android/app/src/main/kotlin/com/scaneliq/scaneliq/MainActivity.kt), wrapped in [`PrivacyShieldService`](file:///c:/Scaneliq/lib/features/security/data/privacy_shield_service.dart), initialized in `main.dart`, and wired to a toggle in [`SettingsScreen`](file:///c:/Scaneliq/lib/features/settings/presentation/settings_screen.dart).
4. **Irreversible PDF & Raster Redaction (`flattenAndRedactPdf`, [`RasterRedactionScreen`](file:///c:/Scaneliq/lib/features/editor/presentation/raster_redaction_screen.dart)):** Added `flattenAndRedactPdf()` to `AdvancedPdfService` (rasterizing vector PDFs, zeroing selected pixel bounds, and producing flat non-extractable image-only PDFs) alongside an interactive Concept A **Raster Pixel / Mosaic Studio** backed by `Isolate.run` `permanentlyRedactImageFile` / `permanentlyMosaicImageFile`, wired into [`PdfToolsScreen`](file:///c:/Scaneliq/lib/features/pdf/presentation/pdf_tools_screen.dart).
5. **Release Signing Template & R8 ProGuard (`android/app/build.gradle.kts`, `proguard-rules.pro`, `android/key.properties.example`, `.gitignore`):** Enabled `isMinifyEnabled = true` and `isShrinkResources = true`, added keep rules for `tesseract4android`, ML Kit, `pdfrx` PDFium JNI, SQLite, SecureStorage, Play Billing, and Biometrics, and excluded signing secrets from Git.
6. **Syncfusion Compliance Disclosure (`lib/core/config/app_compliance_config.dart`):** Added `--dart-define` holders (`SYNCFUSION_LICENSE_KEY`, `SYNCFUSION_LICENSE_ACK`, `GOOGLE_DRIVE_CLIENT_ID`) and Settings compliance status disclosure without hardcoding any secret keys.

### Scanner, Image Processing & Memory Safety (Stages 2, 3, 11)
1. **Camera Lifecycle Recovery (`lib/features/scanner/presentation/scanner_studio_provider.dart`):** Resets `_isFrameProcessing = false` on pause and retries `initializeCamera()` on resume unless `permissionDenied`.
2. **Isolate Concurrency Offload (`lib/core/image_processing/image_processing_service.dart`, `lib/features/pdf/data/pdf_service.dart`):** Moved `splitBookSpreadFile`, `permanentlyRedactImageFile`, `permanentlyMosaicImageFile`, `stitchImageFilesVertically`, and `exportPageAsJpeg` off the UI thread into `Isolate.run()`.
3. **Bounded Thumbnail & Image Decoding:** Audited all `Image.file(...)` calls across `lib/` and added bounded `cacheWidth` decoding to `ScaneliqPaperThumbnail` (`240px`), `TrashScreen` (`180px`), `DocumentViewerScreen` fallback viewer (`1600px`), `WatermarkStudioSheet` (`200px`), `RasterRedactionScreen` (`1400px`), and `CountCamScreen` (`1200px`).

### Document Library, SQLite v6 FTS5 & PDF Engine (Stages 4 & 5)
1. **SQLite Schema v6 & Bilingual FTS5 Search (`lib/features/documents/data/app_database_service.dart`):** Added `documents_fts` virtual table (`fts5` `unicode61` with automatic `fts4` fallback), automatic CRUD/Trash indexing, safe `buildFtsMatchQuery`, `searchDocumentsWithSnippets`, `FolderTreeEntry` (`getFolderHierarchy`), and deep `duplicateDocument()` cloning files, pages, tags, OCR, and FTS entries.
2. **UI Wiring (`home_screen.dart`, `documents_library_screen.dart`):** Fixed nested-folder selection in `_showMoveFolderSheet`, wired `Duplicate Document` menu actions, implemented `FileCategoryFilter.images` (`Images` scope tab no longer returns `0`), and scheduled non-blocking `purgeExpiredTrash()` on startup in `main.dart`.
3. **PDF Isolate Engine & PDFium Rasterization (`lib/features/pdf/data/advanced_pdf_service.dart`, `pdf_tools_screen.dart`):** Offloaded `reorderPages`, `rotatePages`, `mergePdfs`, `splitPdfIntoPages`, `compressPdf`, `encryptPdf`, and `removePassword` to `Isolate.run()`, implemented `exportPdfToImages` via `pdfrx` PDFium rasterization, and unified `_annotatePdf` onto `DocumentViewerScreen(startInAnnotateMode: true)`.

### Genuine Bengali OCR, Searchable PDF, Offline Translation, AI & CountCam (Stages 6, 7, 8)
1. **Genuine Bengali & Mixed Bn-En Offline OCR:** Removed the broken Devanagari mapping; bundled Apache-2.0 `assets/tessdata/ben.traineddata` + `eng.traineddata`, configured JitPack `tesseract4android:4.9.0`, built [`TesseractOcrEngine.kt`](file:///c:/Scaneliq/android/app/src/main/kotlin/com/scaneliq/scaneliq/TesseractOcrEngine.kt), added Isolate grayscale/contrast OCR preprocessing + working `normalizeBanglaNumerals`, added `OcrTableExtractor` (CSV & Markdown table export) and `.txt` export, and wired editable OCR result review in `ToolsScreen` & `DocumentViewerScreen`.
2. **UTF-8 Searchable Bengali PDFs (`lib/features/pdf/data/pdf_service.dart`):** Embedded SIL OFL `assets/fonts/NotoSansBengali-Regular.ttf` into `PdfService.generatePdf` invisible text overlay so Bengali + English OCR text extracts intact via `PdfTextExtractor`.
3. **Offline Translation (`lib/features/scanner/data/translation_service.dart`, `translate_screen.dart`):** Integrated `google_mlkit_translation` offline language pack download/delete/translate with Bn/script detection, explicit opt-in online fallback, and `.txt`/`.pdf` export.
4. **Upgraded Unicode AI Document Assistant (`lib/features/intelligence/data/ai_document_service.dart`, `ai_document_sheet.dart`):** Replaced TF heuristics with genuine power-iteration TextRank (`d = 0.85`), Unicode Bn+En sentence tokenization (`।`), `extractEntities` (English & Bengali dates, amounts, IDs, emails, phones, orgs), `explainDocument`, `semanticSearchVault`, and explicit `ExternalAiProvider` hook.
5. **Real CountCam & Dedicated Invoice Parser:** Created [`ObjectCounterService`](file:///c:/Scaneliq/lib/features/scanner/data/object_counter_service.dart) combining `google_mlkit_object_detection` + Isolate morphological 8-connected cluster segmentation with interactive category presets (`CountCamScreen`) and tap-to-add/remove markers; upgraded `ReceiptParserService` & `ReceiptDialog` for Invoice #, PO #, TIN/BIN Tax ID, Due Date, Discount, Bengali numerals/Taka (`৳`), and inline editing.

### Cloud Sync, WebDAV, DeviceSync V2 & Play Billing (Stages 9B & 10)
1. **DeviceSync V2 Cryptography & Offline Queue (`lib/features/cloud_sync/data/device_sync_service.dart`):** Upgraded `createEncryptedEnvelope()` from 1000-iter XOR to `version: '2.0'` **PBKDF2-100k + AES-256-CBC + HMAC-SHA256 Encrypt-then-MAC** (retaining legacy `1.0` reader compatibility) and added persisted `OfflineSyncOperation` queue management.
2. **Settings Backup Passphrases & Real WebDAV Cloud Client (`lib/features/cloud_sync/data/cloud_transport_service.dart`, `settings_screen.dart`):** Added optional AES-256 passphrase prompts for archive export/restore, built real HTTPS WebDAV (`MKCOL`, `PUT`, `PROPFIND`, `GET`) with Android KeyStore credentials and Daily/Weekly schedule checks, while Google Drive / Dropbox / OneDrive explicitly report `requiresCredentials` when OAuth IDs are unset.
3. **Subscription Tiers, Quotas & Play Billing (`lib/features/subscription/`):** Added `Free` / `Pro` / `Ultra` tiers, daily quota metering, `SubscriptionSheet`, and genuine `in_app_purchase` Play Billing stream wiring (reporting `storeUnavailableOrUnconfigured` cleanly until Play Console SKUs are created).

---

## 3. Scope Boundaries Remaining Out-of-Box

Full details are documented in [`SCANELIQ_REMAINING_BLOCKERS.md`](./SCANELIQ_REMAINING_BLOCKERS.md):
1. **No physical Android handset / AVD attached on this Windows host** → Runtime execution of Camera2, ML Kit detectors, `tesseract4android` ART JNI execution, `local_auth`, `FLAG_SECURE` window overlay, `pdfrx` touch gestures, and `SharePlus` remains **UNVERIFIED ON DEVICE HARDWARE** despite clean release APK compilation.
2. **External Console / Signing Secrets Omitted Intentionally:** Google Play upload keystore (`key.properties`), Play Console subscription SKUs (`scaneliq_pro_monthly`, `scaneliq_ultra_monthly`), OAuth client IDs (Google Drive/Dropbox/OneDrive), external LLM keys, and Syncfusion revenue/license declaration belong to the release owner.
3. **iOS Platform Stub (`RISK-15`):** Requires macOS + Xcode for runner regeneration.
