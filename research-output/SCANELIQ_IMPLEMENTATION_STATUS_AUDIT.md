# Scaneliq — Implementation Status Audit Report

**Audit Date:** November 18, 2026  
**Workspace:** `C:\Scaneliq`  
**Audit Method:** Independent inspection of `lib/`, `test/`, `android/`, `pubspec.yaml`, `docs/`, plus live execution of `flutter analyze` and `flutter test`.  
**Protection Compliance:** Zero modifications made to Dart/Android source code, `pubspec.yaml`, `pubspec.lock`, SQLite database, APKs, or installed Agent Skills.

---

## 1. Executive Summary & Live Verification Baseline

Previous project documentation (`docs/IMPLEMENTATION_STATUS.md`, `docs/FEATURE_BACKLOG.md`, `docs/SCANELIQ_PHASE5_RELEASE_CANDIDATE_REPORT.md`) claimed **100% operational coverage (48/48 features)** and **0 static analysis issues**.

Independent verification of the actual codebase confirms a strong core foundation—especially in local document storage, non-destructive editing, PDF manipulation, and cryptography—while exposing **important discrepancies** between documentation claims and actual implementation.

### Live Verification Results (Executed 2026-11-18)

| Check | Command | Observed Output | Status |
|---|---|---|---|
| **Static Analysis** | `flutter analyze` | **1 issue found:** `warning - Unused import: 'dart:io'` in `test/phase10_camscanner_features_test.dart:1:8` | **WARN** (Docs claimed 0) |
| **Automated Tests** | `flutter test` | **139 / 139 tests passed** across 22 test files in ~22s (Windows VM + `sqflite_common_ffi`) | **PASS** (Host VM only) |
| **Android Device / Emulator** | `adb devices` / `flutter emulators` | 0 physical Android devices connected; 0 AVDs configured | **UNVERIFIED ON ANDROID** |
| **Git Working Tree** | `git status --short` | Tracked source files (`lib/`, `android/`, `test/`, `pubspec.*`) completely clean | **PASS** |

---

## 2. Critical Discrepancies Between Docs & Actual Code

1. **Bangla / Indic OCR (`F-31`) — Misrepresented Script Support:**
   - **Docs Claim:** "On-device Indic recognizer with Bengali numeral normalization (`০..৯` <-> `0..9`)."
   - **Actual Code (`lib/features/ocr/data/ocr_service.dart:75-78`):** Maps `OcrScript.bengali` to `TextRecognitionScript.devanagiri`. Google ML Kit's `google_mlkit_text_recognition` does **not** include a Bengali (`বাংলা`) script recognizer (`devanagari` is for Hindi/Marathi/Sanskrit). Furthermore, `normalizeBanglaNumerals()` (line 145) only runs `text.replaceAll('\r\n', '\n')`. Real Bengali script OCR is **not implemented**.
2. **CountCam (`F-11`) — Text Block Counter, Not Object Detector:**
   - **Docs Claim:** "Camera/gallery object counter with categories, detection boxes & manual adjustment."
   - **Actual Code (`lib/features/scanner/presentation/count_cam_screen.dart:116-131`):** Uses `TextRecognizer(script: TextRecognitionScript.latin)` and sets `_estimatedCount = recognizedText.blocks.length`. It counts OCR text blocks, not physical objects (no object detection model is integrated).
3. **Cloud Backup (`F-42`) & Multi-Device Sync (`F-43`) — Local Envelopes Only, No Cloud Transport:**
   - **Docs Claim:** "Automated Background Cloud Export (Google Drive, Dropbox, OneDrive, WebDAV)" and "Cross-device document synchronization."
   - **Actual Code (`cloud_backup_service.dart`, `device_sync_service.dart`):** `CloudBackupService` creates/restores local encrypted `.scaneliq` ZIP archives; `DeviceSyncService` creates/parses local JSON `EncryptedSyncEnvelope` payloads with Last-Write-Wins (LWW) logic. **Zero cloud provider SDKs, OAuth flows, or HTTP/WebSocket sync transports exist.**
4. **Document Translation (`F-32`) — Online Only:**
   - **Docs Claim:** Listed alongside 100% offline features.
   - **Actual Code (`lib/features/scanner/presentation/translate_screen.dart:19, 109, 135`):** Uses `GoogleTranslator` from `translator` (`^1.0.4+1`), which transmits document text over the internet to Google Translate servers (disclosed in the UI dialog). No offline ML Kit translation model is used.
5. **Declarative Routing (`go_router`) — Declared but Unused:**
   - `pubspec.yaml` declares `go_router: ^18.1.0`, but `lib/main.dart` uses `MaterialApp(home: const MainNavigationShell())` and screens use imperative `Navigator.push(MaterialPageRoute(...))`.
6. **Android Release Signing & Shrinking (`android/app/build.gradle.kts`):**
   - `buildTypes.release` currently signs with `signingConfigs.getByName("debug")` (`TODO: Add your own signing config`) and does not set `isMinifyEnabled = true` or `isShrinkResources = true`.
7. **Full-Text Search (`F-30`) — `LIKE` Query Instead of FTS5:**
   - `AppDatabaseService` (`line 871`) runs `(d.title LIKE ? OR o.full_text LIKE ?)`, not a SQLite FTS4/FTS5 virtual index.

---

## 3. Feature-by-Feature Verification Matrix (F-00 to F-47)

| ID | Feature | Documented Status | Audited Reality Status | Verification Evidence & Gaps |
|---|---|---|---|---|
| **F-00** | Design System & 4-Tab Shell | TESTED | **IMPLEMENTED & TESTED** | `app_theme.dart`, `main_navigation_shell.dart`. `go_router` unused; uses `IndexedStack` + `Navigator.push`. |
| **F-01** | Auto Document Boundary Detection | TESTED | **IMPLEMENTED (HARDWARE UNTESTED)** | `google_mlkit_document_scanner` wired in `scan_session_provider.dart`. Requires Android device to verify camera capture. |
| **F-02** | Manual Shutter & 4-Point Corner Warp | TESTED | **IMPLEMENTED & UNIT TESTED** | `ImageProcessingService` projective homography tested in `image_processing_test.dart`. |
| **F-03** | Continuous Multi-Page Batch Scan | TESTED | **IMPLEMENTED (HARDWARE UNTESTED)** | `continuous_camera_screen.dart` uses `camera` plugin; batch state flow tested in `batch_scanning_test.dart`. |
| **F-04** | Draft Session Persistence | TESTED | **IMPLEMENTED & TESTED** | SQLite `is_draft` flag & recovery verified in `database_persistence_test.dart`. |
| **F-05** | Multi-Image / File Picker Import | TESTED | **IMPLEMENTED & TESTED** | `file_picker` + `AppStorageService.copyToOriginals` with magic-byte validation. |
| **F-06** | ID Card 2-in-1 Sheet Stitching | TESTED | **IMPLEMENTED & TESTED** | Verified in `phase2_audit_and_repair_test.dart` and `pdf_generation_test.dart`. |
| **F-07** | Book Dual-Page Spread Split | TESTED | **IMPLEMENTED & TESTED** | `splitBookSpreadFile` verified in `phase2_audit_and_repair_test.dart`. |
| **F-08** | Whiteboard Mode / Glare Removal | TESTED | **IMPLEMENTED & TESTED** | `ImageProcessingService` tested in `image_processing_test.dart`. |
| **F-09** | Question Set / Exam Paper Mode | TESTED | **IMPLEMENTED & TESTED** | `continuous_camera_screen.dart` + Otsu B&W preset. |
| **F-10** | QR Code & Barcode Scanner | IMPLEMENTED | **IMPLEMENTED (HARDWARE UNTESTED)** | `mobile_scanner` in `scan_code_screen.dart`; untested on physical camera. |
| **F-11** | CountCam (Object Counter) | IMPLEMENTED | **PARTIAL / PROXY IMPLEMENTATION** | Counts ML Kit Latin OCR text blocks (`count_cam_screen.dart`), not general physical objects. |
| **F-12** | Non-Destructive Edit Recipes | TESTED | **IMPLEMENTED & TESTED** | Immutable `originals/` + JSON `EditRecipe` verified in `edit_recipe_test.dart`. |
| **F-13** | Clean B&W Filter (Otsu / Sauvola) | TESTED | **IMPLEMENTED & TESTED** | Verified in `image_processing_test.dart`. |
| **F-14** | Grayscale & Magic Color Presets | TESTED | **IMPLEMENTED & TESTED** | Verified in `image_processing_test.dart` & `phase10_camscanner_features_test.dart`. |
| **F-15** | Brightness & Contrast Sliders | TESTED | **IMPLEMENTED & TESTED** | Verified in `edit_recipe_test.dart`. |
| **F-16** | Finger & Stray Shadow Eraser | TESTED | **IMPLEMENTED & TESTED** | Patch cleanup verified in `image_processing_test.dart`. |
| **F-17** | Multi-Page A4 PDF Generation | TESTED | **IMPLEMENTED & TESTED** | `pdf_service.dart` (`pdf` package) verified in `pdf_generation_test.dart`. |
| **F-18** | HD Quality Presets (150/200/300 DPI) | TESTED | **IMPLEMENTED & TESTED** | Verified in `pdf_generation_test.dart`. |
| **F-19** | Unwatermarked Free Exports | TESTED | **IMPLEMENTED & TESTED** | Verified in `pdf_generation_test.dart`. |
| **F-20** | Single & Batch JPEG Export | TESTED | **IMPLEMENTED & TESTED** | Verified in `edit_recipe_test.dart` & `pdf_generation_test.dart`. |
| **F-21** | In-App PDF Viewer & Search | TESTED | **IMPLEMENTED & WIDGET TESTED** | `pdfrx` viewer in `document_viewer_screen.dart`. |
| **F-22** | PDF Merge | TESTED | **IMPLEMENTED & TESTED** | `AdvancedPdfService.mergePdfs` (`syncfusion_flutter_pdf`) verified. |
| **F-23** | PDF Split & Page Extraction | TESTED | **IMPLEMENTED & TESTED** | `splitPdfIntoPages` & `splitPdfByRanges` verified. |
| **F-24** | PDF Password & AES-256 Encryption | TESTED | **IMPLEMENTED & TESTED** | Verified in `phase5_advanced_pdf_test.dart` & `phase9_release_candidate_test.dart`. |
| **F-25** | Custom Text Watermarking | TESTED | **IMPLEMENTED & TESTED** | Verified in `phase5_advanced_pdf_test.dart`. |
| **F-26** | PDF Annotations & Signatures | TESTED | **IMPLEMENTED & TESTED** | `syncfusion_flutter_pdf` annotations verified in `phase3_advanced_features_test.dart`. |
| **F-27** | Content Redaction / Visual Masking | TESTED | **IMPLEMENTED (SPLIT CAPABILITY)** | Raster pixel zeroing & mosaic (`ImageProcessingService`) are permanently destructive; vector PDF redaction is visual masking + metadata scrub (correctly labeled in UI). |
| **F-28** | On-Device Latin OCR | TESTED | **IMPLEMENTED (LATIN ONLY)** | `google_mlkit_text_recognition`; requires Android/iOS runtime for live inference. |
| **F-29** | Searchable Sandwich PDF | TESTED | **IMPLEMENTED & TESTED** | Invisible OCR text layer verified in `pdf_generation_test.dart`. |
| **F-30** | Full-Text Document Search | TESTED | **IMPLEMENTED (SQL LIKE)** | Uses `LIKE %term%` on `document_ocr`, not FTS5 virtual tables. |
| **F-31** | Bangla / Indic Script OCR | TESTED | **GAP / MISCONFIGURED** | Mapped to `TextRecognitionScript.devanagiri`; true Bengali (`বাংলা`) script is not supported by ML Kit Text Recognition v1/v2 in `ocr_service.dart`. |
| **F-32** | Document Translation (Bn ↔ En) | TESTED | **IMPLEMENTED (ONLINE ONLY)** | Uses `GoogleTranslator` HTTP calls (`translate_screen.dart`), not offline translation. |
| **F-33** | Business Card Contact Extraction | TESTED | **IMPLEMENTED & TESTED** | Heuristic/regex parser + vCard 3.0 export (`business_card_service.dart`). |
| **F-34** | Receipt & Invoice Extraction | TESTED | **IMPLEMENTED & TESTED** | Heuristic/regex parser + CSV export (`receipt_parser_service.dart`). |
| **F-35** | AI Document Summary & Q&A | TESTED | **IMPLEMENTED (EXTRACTIVE ONLY)** | Offline TextRank + TF-IDF sentence ranking (`ai_document_service.dart`). |
| **F-36** | Nested Folders & Cycle Prevention | TESTED | **IMPLEMENTED & TESTED** | Verified in `organization_and_batch_test.dart`. |
| **F-37** | Color-Coded Tags | TESTED | **IMPLEMENTED & TESTED** | Verified in `organization_and_batch_test.dart`. |
| **F-38** | Smart Filename Templates | TESTED | **IMPLEMENTED & TESTED** | Verified in `organization_and_batch_test.dart`. |
| **F-39** | Trash & 30-Day Soft Delete | TESTED | **IMPLEMENTED & TESTED** | Verified in `organization_and_batch_test.dart`. |
| **F-40** | Batch Document Actions | TESTED | **IMPLEMENTED & TESTED** | Verified in `organization_and_batch_test.dart`. |
| **F-41** | System Share Sheet | TESTED | **IMPLEMENTED (HARDWARE UNTESTED)** | `share_plus` wired in `document_viewer_screen.dart`. |
| **F-42** | Automated Cloud Backup | TESTED | **LOCAL ARCHIVE ONLY** | Encrypted `.scaneliq` ZIP (PBKDF2 + AES-256-CBC EtM) verified locally; **no cloud upload transport**. |
| **F-43** | Encrypted Multi-Device Sync | TESTED | **LOCAL ENVELOPE ONLY** | `EncryptedSyncEnvelope` + LWW conflict resolution tested locally; **no remote sync transport**. |
| **F-44** | Offline Local-First Core | TESTED | **IMPLEMENTED** | Core scan, edit, PDF, and SQLite work offline (except `TranslateScreen`). |
| **F-45** | Zero Mandatory Accounts | TESTED | **IMPLEMENTED** | No login/auth gate in app. |
| **F-46** | Biometric App Lock & PIN Security | TESTED | **IMPLEMENTED (PIN TESTED / BIO UNTESTED)** | PBKDF2-HMAC-SHA256 (100k iters), constant-time check, lockout verified. Hash/salt stored in `SharedPreferences` (not KeyStore). Physical biometrics untested. |
| **F-47** | Stale Temp File Cleanup | TESTED | **IMPLEMENTED & TESTED** | Verified in `storage_service_test.dart`. |

---

## 4. Additional Recent Features (Post F-47)

Inspected in `lib/core/image_processing/image_processing_service.dart` and `test/phase10_camscanner_features_test.dart`:
- **Mosaic / Pixelate Redaction (`permanentlyMosaicImageFile`):** Implemented and tested.
- **Long Image Vertical Stitching (`stitchImageFilesVertically`):** Implemented and tested.

---

## 5. Summary of True Readiness

- **Strongest Verified Areas:** Local file sandbox (`AppStorageService`), SQLite relational persistence (`AppDatabaseService`), non-destructive `EditRecipe` + pure Dart image processing (`ImageProcessingService`), PDF manipulation (`PdfService`, `AdvancedPdfService`), and V2/V3 cryptography (`CloudBackupService`, `AppLockService`).
- **Key Gaps to Address Before Production:**
  1. Replace `signingConfigs.debug` with a real release keystore and enable R8 `isMinifyEnabled` / `isShrinkResources` in `android/app/build.gradle.kts`.
  2. Fix genuine Bengali OCR (`F-31`) via a real Bengali-capable engine (e.g., Tesseract `ben.traineddata` or dedicated Indic OCR model) instead of `devanagiri`.
  3. Move PIN/salt storage from `SharedPreferences` to Android KeyStore-backed `flutter_secure_storage`.
  4. Offload `ImageProcessingService` operations to background isolates (`compute()` / `Isolate.run()`) to prevent UI jank on high-megapixel scans.
  5. Execute real-device Android QA for camera, ML Kit Document Scanner, ML Kit OCR, `mobile_scanner`, `local_auth`, and `share_plus`.
