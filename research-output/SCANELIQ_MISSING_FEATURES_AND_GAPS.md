# SCANELIQ — MISSING FEATURES & TECHNICAL GAPS ANALYSIS

**Audit Date:** November 19, 2026  
**Project Directory:** `C:\Scaneliq`

This document classifies every missing, broken, unverified, or partial capability by severity (**P0 – Critical Production Blocker** through **P3 – Optional Enhancement**) based on verified source code inspection.

---

## P0 — Critical Production Blockers (Must Fix Before Beta / Store Upload)

### 1. App Lock Cold-Start Security Bypass & Insecure PIN Persistence
- **What is missing/broken:** `AppLockService.instance.init()` (`app_lock_service.dart:58`) is **never called** in `lib/main.dart`. It is only invoked when the user opens `SettingsScreen` (`settings_screen.dart:48`). Before Settings is visited on a cold app launch, `AppLockService._prefs` is `null`, causing `isAppLockEnabled` (line 62) and `hasPinSet` (line 70) to return `false` — bypassing `MainNavigationShell._checkLockRequirements()` completely. Additionally, PIN hashes, salts, and lockout counters sit in plain `SharedPreferences` rather than Android KeyStore (`flutter_secure_storage`).
- **Why it matters & user impact:** Anyone opening a locked user's phone on cold launch gains immediate unrestricted access to all scanned IDs, invoices, and private PDFs.
- **Technical dependency:** Call `await AppLockService.instance.init();` in `main.dart` alongside `AppStorageService.instance.init()`, and migrate sensitive lock state into `flutter_secure_storage` (backed by Android KeyStore AES/RSA).
- **Complexity:** Low (`1–2` days).
- **Required testing:** Integration test verifying `AppLockScreen` mounts immediately on cold launch when lock is enabled before visiting Settings + KeyStore migration test on Android device.

### 2. Android Debug Release Signing & Missing R8 Shrinking (`build.gradle.kts`)
- **What is missing:** `android/app/build.gradle.kts:34` sets `signingConfig = signingConfigs.getByName("debug")` inside `buildTypes.release` and omits `isMinifyEnabled = true` and `isShrinkResources = true`.
- **Why it matters & user impact:** Google Play rejects debug-signed APKs/AABs. Worse, any test release installed with a debug certificate forces users to uninstall (losing all local documents since `android:allowBackup="false"`) before upgrading to a properly signed build.
- **Technical dependency:** `keytool` upload keystore + git-ignored `android/key.properties` + verified `proguard-rules.pro` rules for ML Kit, Syncfusion, `pdfrx` (PDFium JNI), `sqflite`, `local_auth`, and `mobile_scanner`.
- **Complexity:** Low (`0.5–1` day).
- **Required testing:** `flutter build appbundle --release` + `apksigner verify` + smoke test release APK on Android device to verify zero R8 missing-class crashes.

### 3. Zero Physical Android Device Verification (Camera, ML Kit, PDFium, OCR, Biometrics)
- **What is missing/unverified:** Zero `adb` devices or emulators have ever executed the app. Seven critical runtime features (`Live camera preview`, `PDF viewing` via native `pdfrx`, `Smooth scrolling`, `Pinch-to-zoom`, `Text selection`, `QR/barcode recognition`, `Biometric authentication`) plus live ML Kit Document Scanner & ML Kit OCR runtime accuracy remain completely unverified on real Android hardware (API 29–35).
- **Why it matters & user impact:** Camera2 stream failures, orientation flips, PDFium native `.so` ABI crashes, permission denial edge cases, or out-of-memory bitmap crashes only manifest on real devices.
- **Technical dependency:** Physical Android devices across at least two API levels (e.g., Android 10 & Android 14/15).
- **Complexity:** Medium (`2–3` days).
- **Required testing:** Full hardware QA pass covering camera auto-capture, batch scan, background/resume 5x, gallery permissions on Android 13+, live `pdfrx` multi-page rendering, ML Kit OCR accuracy, `local_auth` biometric prompt, and OS `share_plus` intent.

### 4. Bengali (`বাংলা`) OCR & Mixed Bn-En Recognition Broken
- **What is missing/broken:** `ocr_service.dart:75-78` routes `OcrScript.bengali` to `TextRecognitionScript.devanagiri` (Hindi), `normalizeBanglaNumerals()` (`ocr_service.dart:145-148`) only normalizes `\r\n` -> `\n` without calling numeral helpers, and `PdfService.generatePdf` (`pdf_service.dart:200-206`) strips Unicode code points `>255` to spaces because Helvetica lacks Bengali glyphs.
- **Why it matters & user impact:** Scaneliq's flagship differentiator (`Noto Sans Bengali` typography, Bengali docs, Bn<->En translation) produces garbage Devanagari characters or empty searchable PDFs on real Bengali documents.
- **Technical dependency:** On-device Tesseract (`tesseract4android` JNI channel with quantized `ben.traineddata` + `eng.traineddata` under Apache 2.0) + embedded UTF-8 Unicode font (`NotoSansBengali`) in `PdfService`.
- **Complexity:** High (`4–6` days).
- **Required testing:** Benchmark suite of 20+ real printed Bengali & mixed Bengali-English scans asserting character accuracy >= 88% and valid searchable UTF-8 PDF text selection.

### 5. `syncfusion_flutter_pdf` Commercial License Unregistered
- **What is missing:** `pubspec.yaml:53` bundles `syncfusion_flutter_pdf ^35.1.40+1` (Essential Studio proprietary license: Community License only for `< $1M` revenue and `< 5` developers; otherwise commercial paid license required) with zero `SyncfusionLicense.registerLicense(...)` call in `lib/`.
- **Why it matters & user impact:** Legal/store redistribution risk when publishing commercially on Google Play.
- **Technical dependency:** Register verified Community/Commercial key in `main.dart` OR migrate merge/split/compress/encrypt/annotate to Apache 2.0 native QPDF / PDFium.
- **Complexity:** Low (`1` day legal registration) to Medium (`5` days migration).
- **Required testing:** License compliance verification + full regression pass of `advanced_pdf_service_test.dart` and `phase5_pdf_engine_test.dart`.

---

## P1 — Essential Product Functionality (Required for Competitive v1.0 Public Launch)

### 6. Unencrypted Default Backups in Settings UI (`SettingsScreen._createBackup`)
- **What is missing:** `CloudBackupService` (`cloud_backup_service.dart`) implements authenticated PBKDF2-100k + AES-256-CBC-EtM (`V2`), yet `SettingsScreen._createBackup()` (`settings_screen.dart:121`) and `_restoreBackup()` (`184`) invoke it **without** prompting for an encryption password, exporting plaintext `.scaneliq` ZIP archives by default.
- **User impact & fix:** Sensitive scans shared via ZIP are unencrypted by default. Add mandatory/optional passphrase sheet before export and decryption prompt on restore. Complexity: Low (`0.5` day).

### 7. CountCam Uses OCR Text Blocks Instead of Physical Object Counting
- **What is missing/broken:** `count_cam_screen.dart:116-135` calls `TextRecognizer(script: TextRecognitionScript.latin)` and displays `recognizedText.blocks.length` under a decorative category selector (`Boxes / Cartons`, `Pipes / Rods`, etc.).
- **User impact & fix:** Counting pipes, pills, or boxes yields `0` or false numbers because objects lack Latin text. Either integrate a real on-device TFLite object/instance detector model or cleanly remove/re-scope CountCam before launch so users aren't misled. Complexity: High (`4–5` days).

### 8. Main-Isolate PDF & Remaining Image Processing Bottlenecks (`ANR` / Jank Risk)
- **What is missing:** `AdvancedPdfService` (`advanced_pdf_service.dart`) executes **all** merge, split, compress (`_compressDocumentPages`), watermark, encrypt, redact, and annotation operations synchronously on the UI isolate. Similarly, `PdfService.exportPageAsJpeg`, `ImageProcessingService.splitBookSpreadFile`, and `ImageProcessingService.stitchImageFilesVertically` still run on the UI isolate, and 4 image widgets omit `cacheWidth`.
- **User impact & fix:** Compressing or merging 20+ high-res scan pages freezes Flutter animations and risks Android ANR dialogs. Refactor to `Isolate.run()` + add `cacheWidth` on remaining thumbnails. Complexity: Medium (`2–3` days).

### 9. No Real Cloud Backup / Multi-Device Sync Transport (Local Archives Only)
- **What is missing:** Zero cloud storage SDKs (`Google Drive`, `Dropbox`, `OneDrive`, `WebDAV`), zero OAuth flows, zero outbound sync queue, and zero background scheduling (`workmanager`). `DeviceSyncService` only writes/reads local JSON envelopes with a custom 1,000-iter XOR stream cipher transferring SQLite metadata rows (no binary images or PDFs).
- **User impact & fix:** Losing or breaking a phone causes total irreversible loss of all scanned documents unless the user manually exported `.scaneliq` ZIPs. Implement Google Drive AppData (`google_sign_in` + REST upload/delta sync) + `workmanager` background queue. Complexity: High (`6–10` days).

### 10. No Subscription / In-App Purchase / Entitlement Architecture
- **What is missing:** Complete absence of `in_app_purchase` / RevenueCat, plan definitions (`Free`, `Pro`, `Ultra`), paywalls, restore purchases, receipt validation, and quota limits.
- **User impact & fix:** Impossible to monetize paid cloud storage, AI assistant, or Pro PDF tools or compete sustainably against CamScanner/Genius Scan/SwiftScan. Complexity: Medium-High (`4–6` days).

### 11. Screenshot Protection (`FLAG_SECURE`), Raster Redaction UI & Encrypted DB
- **What is missing:** `MainActivity.kt` does not set `WindowManager.LayoutParams.FLAG_SECURE` (allowing screenshots and Android Recent Apps task switcher previews of sensitive documents); `ImageProcessingService.permanentlyRedactImage` / `Mosaic` has zero UI wiring; SQLite `scaneliq.db` and `originals/` sit plaintext on disk.
- **User impact & fix:** Add privacy toggle for `FLAG_SECURE`, build touch-brush UI wired to `permanentlyRedactImage` for destructive bitmap redaction, and evaluate SQLCipher for DB-at-rest encryption. Complexity: Medium (`3–5` days).

---

## P2 — Important Premium Capabilities (Competitive Differentiators)

- **SQLite FTS5 Search (`app_database_service.dart:871`):** Replace full-table `LIKE '%term%'` scan on `document_ocr` with FTS5 virtual table + match snippet highlighting (`2` days).
- **Word / Excel / PPT Export & Table Extraction:** Currently marked `UNAVAILABLE`; competitors (CamScanner, Adobe Scan, Microsoft Lens) convert scans to `.docx` / `.xlsx` (`6–8` days via layout table analyzer or cloud API).
- **True AI Assistant (LLM / Entity Extraction):** Replace raw Term-Frequency `AiDocumentService` (currently mislabeled TextRank/TF-IDF) with real semantic summarization, natural-language explanation, date/name/amount extraction, and vault-wide semantic search (`5–8` days).
- **Offline Translation (`google_mlkit_translation`):** Replace online-only `GoogleTranslator` with downloadable offline Bn<->En ML Kit translation models + `.txt`/PDF export (`2–3` days).
- **PDF-to-Image External Rasterization & `PdfToolsScreen` Wiring:** Use `pdfrx` page rendering to convert any arbitrary imported PDF page into JPEG/PNG, and wire `PdfToolsScreen._annotatePdf` directly to `DocumentViewerScreen(startInAnnotateMode: true)` instead of its legacy stamp dialog (`1–2` days).
- **Document Copy / Duplicate, Nested Folder Move & Trash Auto-Purge:** Implement full `duplicateDocument()`, fix `_showMoveFolderSheet` (`documents_library_screen.dart:400`) to traverse nested subfolders, wire `FileCategoryFilter.images`, and invoke `purgeExpiredTrash()` on app startup (`1–2` days).

---

## P3 — Optional / Platform Expansion & Maintainability

- **Complete iOS Runner Project (`ios/`):** `Info.plist`, `AppDelegate.swift`, and `Runner.xcodeproj` are missing; requires `flutter create --platforms=ios .` on macOS Xcode if targeting App Store (`3–5` days).
- **X.509 Certificate Digital Signatures:** Upgrade optional enterprise signing beyond visual PNG overlays (`4–6` days).
- **Handwriting Recognition & Document/Form Templates:** Resume/ID/form templates and handwritten note OCR (`5+` days).
- **Architecture Decomposition:** Unify remaining imperative `Navigator.push` calls into `go_router` routes and split >1,000-line screen files (`documents_library_screen.dart` 1,769+ lines, `pdf_tools_screen.dart`, `home_screen.dart`) (`4–6` days).
