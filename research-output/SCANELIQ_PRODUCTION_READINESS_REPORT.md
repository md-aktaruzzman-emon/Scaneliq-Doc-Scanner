# SCANELIQ — PRODUCTION READINESS & TECHNICAL QUALITY AUDIT REPORT

**Audit Date:** November 19, 2026  
**Project Directory:** `C:\Scaneliq`  
**Verification Standard:** Strictly Read-Only Inspection (`lib/`, `test/`, `android/`, `ios/`, `pubspec.yaml`) + Live Tool Execution

---

## 1. Live Verification Results

| Check | Command | Observed Result | Scope & Limitations |
|---|---|---|---|
| **Static Analysis** | `flutter analyze --no-pub` | **`1` issue** (pre-existing `unused_import` in `test/phase10_camscanner_features_test.dart:1:8`); **`0` errors, `0` new warnings** | Covers full `lib/` and `test/` trees. |
| **Automated Test Suite** | `flutter test --no-pub --timeout 30s` | **`179 / 179` passed** across 27 test files in `25s` | Executed on Windows host VM using `sqflite_common_ffi`, `FakeScannerCameraBackend`, synthetic specimen images, Syncfusion PDF verification, and widget test canvas overrides (`pdfCanvasBuilder`). |
| **Physical Hardware QA** | `adb devices` | **`0` connected devices / `no adb`** | Camera2 streaming, ML Kit Document Scanner, ML Kit Latin OCR inference, PDFium native `pdfrx` rendering/pinch/selection, `mobile_scanner`, `local_auth` biometrics, and Android OS `SharePlus` remain **unverified on physical devices**. |
| **Build & Release Check** | `android/app/build.gradle.kts` | **Debug signing + No R8 shrink** | `buildTypes.release` assigns `signingConfigs.getByName("debug")` and omits `isMinifyEnabled = true` / `isShrinkResources = true`. `ios/` lacks `Info.plist`, `AppDelegate.swift`, and `Runner.xcodeproj`. |

### Test Suite Coverage Gaps Identified
- **Missing Hardware Integration Tests:** Zero tests execute `FlutterCameraBackend`, `OcrService` native recognizer, `MobileScanner`, `local_auth` biometric prompt, or native `PdfViewer.file` PDFium rendering on Android.
- **Unverified Network APIs:** `TranslateScreen` (`GoogleTranslator`) has zero live/mocked HTTP test assertions.
- **Unverified Cold-Start Security Integration:** `AppLockService` unit tests pass because tests manually call `.init()`, masking the **production cold-start bypass bug** where `lib/main.dart` omits `AppLockService.instance.init()`.
- **Pre-existing Lint Warning:** `test/phase10_camscanner_features_test.dart:1:8` unused `dart:io` import.

---

## 2. Revisit of Previous Technical Risk Register (`RISK-01` .. `RISK-14`)

Verified directly against current source code (Post-Phases 1–5):

| Risk ID | Risk Description | Prior Status | Current Verified Status | Current Code Evidence |
|---|---|---|---|---|
| **RISK-01** | Debug Release Signing & Missing R8 Minify | OPEN | **STILL OPEN (`P0`)** | `android/app/build.gradle.kts:34` still assigns `signingConfigs.getByName("debug")` and lacks `isMinifyEnabled = true` / `isShrinkResources = true`. |
| **RISK-02** | Zero Android Hardware Verification + Camera Lifecycle Race | OPEN | **PARTIALLY FIXED (`P0`)** | **Code race FIXED** in Phase 3 (`continuous_camera_screen.dart:73` + `ScannerCameraBackend` serialized `_opLock` + safe dispose). **Hardware device QA remains OPEN** (`0` Android devices). |
| **RISK-03** | Bengali OCR Mapped to Devanagari + No-op Numerals | OPEN | **STILL OPEN (`P0` Broken)** | `ocr_service.dart:75-78` still maps `OcrScript.bengali` -> `devanagiri`; `:145-148` `normalizeBanglaNumerals` only replaces `\r\n` -> `\n`; `pdf_service.dart:200` strips non-Latin1 `>255` characters. |
| **RISK-04** | `syncfusion_flutter_pdf` Licensing Unregistered | OPEN | **STILL OPEN (`P0`)** | `pubspec.yaml:53` Proprietary Essential Studio license (`Community <$1M & <5 devs`); zero `SyncfusionLicense.registerLicense` calls anywhere in `lib/`. |
| **RISK-05** | PIN Storage in `SharedPreferences` + Cold-Start AppLock Init Bug | Partial | **WORSENED / `P0`** | Strong PBKDF2-100k + constant-time compare + lockout confirmed, **but** `lib/main.dart` omits `AppLockService.instance.init()` (cold-start bypass until Settings is opened!) and hashes remain in `SharedPreferences`. |
| **RISK-06** | Image Processing on Main Isolate | OPEN | **MOSTLY FIXED (`P1`)** | **FIXED in Phase 4 Editor** via `Isolate.run` (`processImageFileToBytesInIsolate`, `processEncodedSourceBytesInIsolate`, `autoDetectDocumentQuadFromFile`, 640px preview cache). Legacy synchronous calls remain in `PdfService.exportPageAsJpeg`, `splitBookSpreadFile`, and `stitchImageFilesVertically`. |
| **RISK-07** | Advanced PDF Ops Execute on Main Isolate | OPEN | **STILL OPEN (`P1`)** | `advanced_pdf_service.dart` executes all merge, split, compress (`_compressDocumentPages`), watermark, encrypt, redact, and annotate tasks on the main UI isolate. |
| **RISK-08** | Zero Cloud Backup Transport + Unencrypted Settings Default | OPEN | **STILL OPEN (`P1`)** | Zero Google Drive / Dropbox / OneDrive / WebDAV / WorkManager. Plus `SettingsScreen._createBackup()` (`:121`) omits password prompt, generating unencrypted ZIPs despite working V2 AES-EtM crypto. |
| **RISK-09** | CountCam Uses Latin OCR Blocks Instead of Objects | OPEN | **STILL OPEN (`P1` Broken)** | `count_cam_screen.dart:116-135` counts `recognizedText.blocks.length` with decorative category UI. |
| **RISK-10** | Online-Only Translation Listed Under Offline Features | OPEN | **STILL OPEN (`P2`)** | `translate_screen.dart:19,135` uses `GoogleTranslator` HTTP (consent modal present; zero offline ML Kit models). |
| **RISK-11** | SQLite Search Uses `LIKE` Instead of FTS5 | OPEN | **STILL OPEN (`P2`)** | `app_database_service.dart:871` still uses `LIKE '%term%'`; `purgeExpiredTrash()` (`:727`) uncalled; `_showMoveFolderSheet` (`:400`) lists root folders only. |
| **RISK-12** | Vector PDF Masking, Missing `FLAG_SECURE`, Plain SQLite | OPEN | **STILL OPEN (`P1/P2`)** | Visual mask honestly warned; `MainActivity.kt` lacks `FLAG_SECURE`; `sqflite` is plaintext; `permanentlyRedactImage` raster pixel destruction has zero UI trigger. |
| **RISK-13** | Monolithic UI Screens & Global Singleton Coupling | OPEN | **IMPROVED (`P2`)** | Phase 4–5 extracted `CameraStudioController`, `EditHistoryController`, `EditorPreviewStage`, `PdfAnnotationStudio`, `SignatureStudioPanel`, `WatermarkStudioPanel`. Monolithic >1,000-line legacy screens remain in `documents_library_screen.dart` (`1,769+`), `pdf_tools_screen.dart`, `home_screen.dart`. |
| **RISK-14** | Unused `go_router` + Pre-existing Lint Warning | OPEN | **PARTIALLY FIXED (`P3`)** | **`go_router` IS now wired** in `main.dart` & `app_router.dart` (`StatefulShellRoute` 3 tabs + `/settings`, `/review-pages`, `/trash`), though deep sub-screens still mix `Navigator.push`. Pre-existing warning in `test/phase10_camscanner_features_test.dart:1:8` remains. |
| **NEW-15** | **Incomplete iOS Runner Stub (`ios/`)** | New | **NEWLY VERIFIED (`P1`)** | `ios/Runner/Info.plist`, `AppDelegate.swift`, and `Runner.xcodeproj` are absent; iOS builds cannot run without regenerating platform runner files on macOS. |

---

## 3. Product Readiness Score (Weighted Assessment)

**Methodology:** Scores are calculated conservatively from the verified **157-feature matrix** (`FULLY IMPLEMENTED` = 1.0, `PARTIALLY IMPLEMENTED` = 0.5, `UNVERIFIED` = 0.4, `BACKEND ONLY` = 0.25, `BROKEN`/`MISSING`/`PLANNED` = 0.0) adjusted explicitly for live P0 security, hardware-verification, and architectural blockers. **No score inflation is applied.**

| Category | Weight | Category Score (/100) | Weighted Contribution | Primary Evidence Driving Score |
|---|---:|---:|---:|---|
| Scanning and Camera | 15% | 55 | 8.25 | Solid Concept A studio, `ScannerCameraBackend` lock, review/retake/drafts, perspective warp; capped by zero physical Android camera/ML Kit run |
| Image Editing | 10% | 90 | 9.00 | Strongest area: all 17 editor features verified via `Isolate.run`, non-destructive `EditRecipe` v2, interactive compare/crop/4-pt warp |
| Document Management | 10% | 72 | 7.20 | Complete SQLite v5 folders/tags/trash/batch/sort; missing doc Copy/Duplicate, nested move targets, FTS5, auto Trash purge, `images` filter |
| PDF Functionality | 15% | 68 | 10.20 | Strong annotations/visual sign/watermark/organizer/merge/split/compress/AES lock; `pdfrx` PDFium untested on hardware, X.509 missing, main-isolate Syncfusion, external PDF->img missing |
| OCR and Translation | 15% | 28 | 4.20 | Latin searchable PDF & online Google Translate work cleanly; **Bengali OCR broken**, >255 glyphs stripped from PDF text, zero offline translation/tables/handwriting |
| AI Productivity | 10% | 30 | 3.00 | ID Card 2-in-1, Book split, Long stitch & Receipt/Card regex work; `AiDocumentService` is TF-only heuristic, **`CountCam` broken** (OCR block proxy), no entity extraction |
| Security and Privacy | 10% | 42 | 4.20 | Strong crypto primitives (`PBKDF2-100k`, V2 `AES-CBC-EtM`), `allowBackup=false`; **broken cold-start `AppLockService.init()`**, plain Prefs & SQLite, no `FLAG_SECURE`, unencrypted default backup UI |
| Backup and Sync | 5% | 28 | 1.40 | Local `.scaneliq` ZIP backup/restore with Zip Slip + SHA-256 works well; zero cloud storage transports, OAuth, or background sync queue |
| Performance and Stability | 5% | 55 | 2.75 | Phase 4 Isolate previews & `PdfService` `compute()` solid; `AdvancedPdfService` synchronous on main isolate, missing R8 shrink, 4 uncached image viewers |
| Premium and Monetization | 5% | 0 | 0.00 | Zero subscription plans, billing packages, entitlements, or paywalls |
| **TOTAL WEIGHTED SCORE** | **100%** | — | **50.2 / 100** | **Pre-Beta / Prototype-Strong Local Engine — Not Commercial Store-Ready** |

---

## 4. Candid Competitiveness Verdict

**Question:** *If Scaneliq were released today, would it genuinely compete with CamScanner and Adobe Scan? Why or why not?*

### Honest Answer: **Not yet — it would compete well aesthetically and as an offline local utility, but it would fail Google Play retention, Bengali-market trust, and commercial parity against CamScanner and Adobe Scan.**

**What is already genuinely competitive / strong:**
- **Editorial Visual Quality & Clean UX:** The Phase 1–5 Concept A (`Gallery Alabaster` / `Carbon Studio`) execution looks cohesive, modern, and restrained compared to cluttered scanner apps.
- **Scan Editor (`90/100`):** Non-destructive `EditRecipe` v2, 4-point projective warp, Auto-Enhance/Magic Color/Otsu/Sauvola filters, sharpness convolution, Before/After slider, and multi-page Isolate previews genuinely rival paid editor tools.
- **Offline Local PDF Toolkit (Clean Free Exports):** Unwatermarked A4 PDFs, merge/split/compress, interactive highlight/ink/shape annotations, live watermark studio, page organizer, and AES-256 PDF password protection without forcing an Adobe/CamScanner login.
- **Local Cryptographic Primitives:** `CloudBackupService` V2 (`PBKDF2` + `AES-CBC-EtM`) and `AppLockService` V3 (`PBKDF2` + constant-time check) are well-engineered at the algorithm level.

**Why releasing today would fail commercial competition:**
1. **Unverified Core Hardware Flows & Release Blockers:** Release APK currently signs with the debug key (`RISK-01`), lacks Syncfusion license registration (`RISK-04`), and has **never been run on a real Android phone** (live camera, ML Kit Doc Scanner, PDFium viewing/zooming, QR, and biometrics remain untested on device).
2. **Broken Cold-Start Security:** App Lock silently fails to prompt on cold launch because `AppLockService.instance.init()` is missing from `main.dart`.
3. **Broken Bengali OCR (`OcrScript.bengali` -> Devanagari):** Any Bengali user attempting to scan Bangla documents gets Hindi/garbage or stripped empty PDF text layers.
4. **No Cloud Sync or Cross-Device Continuity:** Both Adobe Scan and CamScanner center user lock-in on instant cloud sync (5–20 GB Document Cloud / Drive / OneDrive). Losing a phone with Scaneliq today means losing every scan unless manually backed up.
5. **No Word/Excel Export, Real Generative AI, or Monetization:** Office export is unavailable, "CountCam" and "AI Assistant" rely on misleading/limited heuristics compared to CamScanner's AI Agent, and zero Play Billing infrastructure exists.
