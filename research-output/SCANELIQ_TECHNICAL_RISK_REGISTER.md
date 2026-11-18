# Scaneliq — Technical Risk Register & Product Readiness Assessment

**Document Date:** November 18, 2026  
**Workspace:** `C:\Scaneliq`  
**Inputs:** Live code/build inspection (`lib/`, `test/`, `android/`, `pubspec.yaml`), `flutter analyze`, `flutter test`, [SCANELIQ_IMPLEMENTATION_STATUS_AUDIT.md](file:///C:/Scaneliq/research-output/SCANELIQ_IMPLEMENTATION_STATUS_AUDIT.md), and [SCANELIQ_CURRENT_ARCHITECTURE_AUDIT.md](file:///C:/Scaneliq/research-output/SCANELIQ_CURRENT_ARCHITECTURE_AUDIT.md).  
**Protection Rules:** Zero modifications performed to source code, dependencies, database, APKs, or Agent Skills.

---

## 1. Executive Readiness Verdict

Scaneliq has a solid offline document-management core (`139/139` host-VM tests passing across `22` test files) and strong backup/PIN cryptographic primitives (`CloudBackupService` V2, `AppLockService` V3). However, it is **NOT ready for production Play Store release** due to **P0 release blockers**:
1. Android `release` builds are signed with the **debug keystore** and lack explicit R8 minification/shrinking.
2. Zero physical Android device or emulator QA has been executed (`0` connected devices, `0` AVDs), leaving camera, ML Kit Document Scanner, OCR, QR scanning, and biometrics unverified on real Android hardware.
3. Multiple documented capabilities—most notably **Bengali OCR**, **CountCam Object Counting**, and **Cloud Backup/Sync**—exhibit major **documentation-vs-implementation mismatches**.
4. High-cost image and advanced PDF operations run on the **main UI isolate**, and PIN hashes reside in `SharedPreferences` rather than Android KeyStore.

---

## 2. Priority Classification Legend

| Priority | Meaning | Release Gate Impact |
|---|---|---|
| **P0 — Critical / Blocker** | Security, release-signing, hardware-verification, or false-feature blocker | **Must resolve before beta/production ship** |
| **P1 — High** | Severe UX lag, misleading offline/AI capability, or data-durability risk | **Must resolve for v1.0 Public Launch** |
| **P2 — Medium** | Scalability bottleneck, architectural coupling, or maintainability debt | **Target for v1.1 Stabilization** |
| **P3 — Low** | Hygiene, dead dependencies, and minor lint polish | **Resolve opportunistically** |

---

## 3. Master Technical Risk Register

### Summary Matrix

| ID | Risk / Problem Area | Priority | Category | Docs vs Code Mismatch? | Complexity | Target Gate |
|---|---|---|---|---|---|---|
| **RISK-01** | Production Signing & R8/ProGuard Shrinking Missing | **P0** | Release Eng | Yes | Low (0.5–1 day) | Beta / Store |
| **RISK-02** | Zero Android Hardware / Emulator Validation & Camera Lifecycle Bug | **P0** | Compatibility | Yes | Medium (2–3 days) | Beta / Store |
| **RISK-03** | Bengali (`বাংলা`) OCR Mapped to Devanagari (Hindi) Recognizer | **P0** | OCR (`F-31`) | **Critical Mismatch** | High (4–6 days) | Production |
| **RISK-04** | `syncfusion_flutter_pdf` Licensing Unregistered / Audit Required | **P0** | Legal / PDF | Undocumented | Low–Med (1 day legal / 5d swap) | Store Launch |
| **RISK-05** | App-Lock PIN Hash/Salt Stored in `SharedPreferences` (No KeyStore) | **P1** | Security (`F-46`) | Partial | Low–Med (1–2 days) | Production |
| **RISK-06** | Image Processing Pipeline Runs on Main Isolate (UI Jank / OOM Risk) | **P1** | Performance | Undocumented | Medium (2–3 days) | Production |
| **RISK-07** | Advanced PDF Operations Run on Main Isolate (`advanced_pdf_service.dart`) | **P1** | PDF (`F-22..27`) | Undocumented | Medium (2–3 days) | Production |
| **RISK-08** | Cloud Backup & Multi-Device Sync Have Zero Cloud Transport (`F-42`, `F-43`) | **P1** | Sync / Data-Loss | **Critical Mismatch** | High (5–8 days) | Pro / Cloud |
| **RISK-09** | CountCam Uses Latin OCR Text Blocks Instead of Object Detection (`F-11`) | **P1** | Vision (`F-11`) | **Critical Mismatch** | High (4–6 days) | Production |
| **RISK-10** | Online-Only Translation (`GoogleTranslator`) Listed Under Offline Stack (`F-32`) | **P2** | Privacy / Offline | **Mismatch** | Medium (2–3 days) | v1.1 |
| **RISK-11** | SQLite Search Uses `LIKE '%term%'` Instead of FTS5 (`F-30`) | **P2** | Database | **Mismatch** | Medium (2 days) | v1.1 |
| **RISK-12** | Vector PDF Redaction & No `FLAG_SECURE` / Unencrypted SQLite DB at Rest | **P2** | Security / Privacy | Disclosed in UI only | Medium (2–4 days) | Enterprise |
| **RISK-13** | Singleton Coupling & 1,000–1,769 Line Monolithic Presentation Screens | **P2** | Architecture | Minor | High (5–7 days) | Maintainability |
| **RISK-14** | Unused `go_router` Dependency & `flutter analyze` Warning (`test/`) | **P3** | Hygiene / Lint | Yes (0-issues claim) | Low (0.5 day) | Immediate |

---

## 4. Detailed Risk Analysis & Remediation Specifications

### RISK-01 — Production Release Signing & R8 Shrinking Missing (`P0`)
- **Documentation vs Actual Code:** `docs/IMPLEMENTATION_STATUS.md` and Phase 5 report validate release APK generation, whereas `android/app/build.gradle.kts:31-38` explicitly signs `release` builds with `signingConfigs.getByName("debug")` (`TODO: Add your own signing config`) and omits `isMinifyEnabled = true` and `isShrinkResources = true`.
- **User Impact:** Play Store rejects debug-signed APKs/AABs. Worse, future updates cannot upgrade an install signed with a debug key without uninstalling (causing total local document loss since `android:allowBackup="false"`). Without R8 code/resource shrinking, APK size stays inflated (~40.9 MB arm64 / ~110 MB universal).
- **Technical Cause:** `android/app/build.gradle.kts:31-38`; `android/app/proguard-rules.pro:1-16` exists, but minification is not enabled in `buildTypes.release`.
- **Recommended Solution:** Create an upload keystore (`keytool`), externalize credentials in `android/key.properties` (git-ignored), wire `signingConfigs.create("release")` in `build.gradle.kts`, enable `isMinifyEnabled = true` and `isShrinkResources = true`, and add ProGuard keep rules for `syncfusion_flutter_pdf`, `pdfrx`, `sqflite`, `local_auth`, and `mobile_scanner`.
- **Dependencies & Licensing:** Standard Android SDK (`keytool`, `apksigner`); zero third-party license cost.
- **Security & Data-Loss Risk:** Shipping with debug keys exposes users to signature-spoofing and forces uninstall/data-loss on key rotation.
- **Measurable Acceptance Criteria:** `flutter build appbundle --release` and `flutter build apk --release --split-per-abi` succeed using release keystore; `apksigner verify` confirms release certificate (not `CN=Android Debug`); `arm64-v8a` APK size decreases from 40.9 MB and launches cleanly without `ClassNotFoundException`.
- **Complexity:** **Low** (0.5–1 day).

---

### RISK-02 — Zero Android Hardware Validation & Camera Lifecycle Race (`P0`)
- **Documentation vs Actual Code:** `docs/IMPLEMENTATION_STATUS.md` reports "100% operational coverage", yet `adb devices` shows `0` connected phones and `flutter emulators` reports `0` AVDs. Hardware plugins (`google_mlkit_document_scanner`, `camera`, `mobile_scanner`, `google_mlkit_text_recognition`, `local_auth`, `share_plus`) have never run on Android.
- **User Impact:** Real users can experience camera black screens, crash on resume, orientation distortion, failed ML Kit model downloads on first scan, or runtime permission denials on Android 13–15.
- **Technical Cause:**
  - Zero instrumentation/on-device test runs (`integration_test` unused on Android).
  - Concrete lifecycle defect in `lib/features/scanner/presentation/continuous_camera_screen.dart:61-70`: `didChangeAppLifecycleState` calls `_cameraController?.dispose()` on `AppLifecycleState.inactive` without setting `_cameraController = null` or `_isCameraInitialized = false`, and on `resumed` immediately indexes `_cameras[_selectedCameraIndex]` (throwing `RangeError` if `_cameras` is empty or racing with asynchronous disposal).
- **Recommended Solution:** Provision a physical Android test device (Android 10–15) and/or API 35 x86_64 emulator; guard `didChangeAppLifecycleState` with null-reset, `_cameras.isNotEmpty` checks, and serialized dispose/init locking; verify runtime permissions (`CAMERA`, gallery picker scoped storage, `USE_BIOMETRIC`).
- **Dependencies & Licensing:** Physical Android device + Android SDK emulator system image (Apache 2.0).
- **Security & Data-Loss Risk:** Unsaved multi-page capture session can crash on app background/foreground switch before draft persistence runs.
- **Measurable Acceptance Criteria:** All 6 core hardware journeys (ML Kit scanner, `ContinuousCameraScreen` background/resume x5, `ScanCodeScreen`, `OcrService` on-device inference, `local_auth` biometric prompt, `share_plus` intent) pass on at least 2 physical Android API levels (e.g., API 29 & API 34/35) with zero fatal logcat exceptions.
- **Complexity:** **Medium** (2–3 days).

---

### RISK-03 — Bengali (`বাংলা`) OCR Mapped to Wrong Script Engine (`P0`)
- **Documentation vs Actual Code:** `docs/FEATURE_BACKLOG.md` (`F-31`) claims "On-device Indic recognizer with Bengali numeral normalization (`০..৯` <-> `0..9`)". In reality, `lib/features/ocr/data/ocr_service.dart:75-78` routes `OcrScript.bengali` to `TextRecognitionScript.devanagiri`, and `normalizeBanglaNumerals` (`line 145`) only calls `text.replaceAll('\r\n', '\n')`.
- **User Impact:** Scanning Bengali documents (`বাংলা দলিল, রশিদ, বই`) fails completely or outputs garbled Devanagari/Hindi characters because Bengali Unicode (`U+0980–U+09FF`) is distinct from Devanagari (`U+0900–U+097F`).
- **Technical Cause:** `google_mlkit_text_recognition: ^0.17.1` only exposes 5 Google ML Kit v2 scripts (`latin`, `chinese`, `devanagiri`, `japanese`, `korean`); Bengali is not supported by Google ML Kit Text Recognition.
- **Recommended Solution:** Integrate **Tesseract OCR** via platform channels (`tesseract4android` / `tess-two` on Android via JNI, or `flutter_tesseract_ocr` verified for Flutter 3.47 + NDK 28) bundling quantized `ben.traineddata` + `eng.traineddata` (fast best-model), pre-processed with Otsu binarization + deskewing (`ImageProcessingService`), and add genuine Bengali post-processing normalization (e.g., `hasont`/juktakkhor whitespace cleanup & `convertBanglaToAsciiDigits` toggle).
- **Dependencies & Licensing:** Tesseract OCR + `tessdata_fast` (`ben.traineddata` ~2–4 MB) — **Apache License 2.0** (commercial-friendly, offline, no cloud cost). Increases APK size by ~4–8 MB per ABI (can alternatively be downloaded on-demand once via app storage with SHA-256 verification).
- **Security & Data-Loss Risk:** None directly, though poor OCR corrupts searchable PDFs (`F-29`) and full-text search index (`F-30`) for Bengali users.
- **Measurable Acceptance Criteria:** On a benchmark set of 20 real-world Bengali printed documents (mixed `বাংলা` + English + `০-৯` numerals), character accuracy rate (CAR) reaches >= 88% (vs ~0% currently), runs 100% offline in a background isolate, and embeds searchable UTF-8 font text in `PdfService`.
- **Complexity:** **High** (4–6 days).

---

### RISK-04 — `syncfusion_flutter_pdf` Licensing & Compliance Exposure (`P0`)
- **Documentation vs Actual Code:** `pubspec.yaml:53` includes `syncfusion_flutter_pdf: ^35.1.40+1`, imported in `lib/features/pdf/data/advanced_pdf_service.dart:9` and `lib/features/pdf/data/pdf_service.dart:11`. No `SyncfusionLicense.registerLicense(...)` call exists anywhere in `lib/`.
- **User Impact / Legal Risk:** `syncfusion_flutter_pdf` is **NOT MIT/BSD open source**; it is governed by the Syncfusion Commercial / Community License (strict revenue/headcount eligibility limits and attribution/registration requirements). Shipping on Google Play without verifying eligibility or registering a valid license risks copyright/license non-compliance or runtime license warnings.
- **Technical Cause:** Added in Phase 5 without documenting license compliance or registering a license key in `main.dart`.
- **Recommended Solution:**
  - *Option A (Fastest):* Verify whether the developer qualifies for Syncfusion's free Community License (< \$1M gross revenue, <= 5 developers), obtain a license key, and register it cleanly—or purchase a commercial license if exceeding limits.
  - *Option B (Zero proprietary risk):* Long-term, decouple `AdvancedPdfService` behind an interface and migrate merge/split/encrypt/rasterize to native **PDFium + QPDF (Apache 2.0) / PDFBox-Android (Apache 2.0)** via a Kotlin MethodChannel.
- **Dependencies & Licensing:** Syncfusion Community/Commercial License vs Apache 2.0 (`qpdf` / `pdfbox-android`).
- **Measurable Acceptance Criteria:** Documented license determination signed off in repo + either valid `SyncfusionLicense.registerLicense` (via `--dart-define`, not hardcoded in public repo) or full Apache-2.0 native replacement passing all 27 tests in `phase5_advanced_pdf_test.dart`.
- **Complexity:** **Low** (1 day for license compliance setup) / **High** (5–7 days if replacing with native PDFium+QPDF).

---

### RISK-05 — App-Lock PIN Hash & Salt Stored in Plaintext `SharedPreferences` (`P1`)
- **Documentation vs Actual Code:** Phase 5 docs highlight PBKDF2-HMAC-SHA256 (100k iterations) in `AppLockService`. However, `lib/features/security/data/app_lock_service.dart:33-55` persists `_prefPinHash` and `_prefPinSalt` in `SharedPreferences` (plaintext XML in `/data/data/com.scaneliq.scaneliq/shared_prefs/`).
- **User Impact:** A 4-digit PIN only has `10,000` possible inputs. If a device is rooted, exploited via ADB backup/debug build, or inspected forensically, an attacker reading `shared_prefs` can brute-force all 10,000 PBKDF2 digests offline in seconds on a desktop GPU, bypassing the in-app 5-attempt rate limiter.
- **Technical Cause:** Missing `flutter_secure_storage` integration (`Android KeyStore` + `EncryptedSharedPreferences` / AES-GCM key wrapping).
- **Recommended Solution:** Add `flutter_secure_storage` backed by Android KeyStore AES-GCM (`encryptedSharedPreferences: true` or KeyStore RSA/AES cipher on API 23+), migrate existing `v3:` PIN hash + salt from `SharedPreferences` on first init, and enforce biometric-bound KeyStore authentication when biometrics are enabled.
- **Dependencies & Licensing:** `flutter_secure_storage` (BSD-3-Clause); zero backend cost.
- **Security & Data-Loss Risk:** Credential extraction on rooted devices. Migration logic must gracefully handle Android KeyStore `BadPaddingException` / key invalidation after lock-screen reset so users are not permanently locked out of their own documents without recovery.
- **Measurable Acceptance Criteria:** Zero PIN hash/salt keys appear in `SharedPreferences` XML on Android device inspection; `AppLockService` reads/writes solely via hardware-backed KeyStore wrapper; existing PINs migrate transparently on upgrade.
- **Complexity:** **Low–Medium** (1–2 days).

---

### RISK-06 — Image Processing Executes on Main UI Isolate (`P1`)
- **Documentation vs Actual Code:** `lib/features/pdf/data/pdf_service.dart:157, 299` uses `compute()` for PDF rendering and ID card stitching, whereas `lib/core/image_processing/image_processing_service.dart` (1,001 lines) runs **zero** operations in background isolates (`compute` / `Isolate.run` count = `0`).
- **User Impact:** Applying Magic Color, Otsu/Sauvola thresholding, 4-point homography warp, book spread splitting, or vertical long-image stitching (`stitchImageFilesVertically`) on 12MP–48MP camera photos freezes the Flutter UI thread for 500ms–4,000ms per frame, causing ANRs ("App Not Responding") and Out-Of-Memory (OOM) crashes on mid-range Android devices.
- **Technical Cause:** All pixel loops (`applyEditRecipe`, `processImageFile`, `processImageFileToBytes`, `splitBookSpreadFile`, `permanentlyMosaicImageFile`, `stitchImageFilesVertically`) execute directly on the caller's isolate, and `decodeImage` decodes full-resolution bitmaps without preview downsampling in `EditPageScreen` (`1,246` lines).
- **Recommended Solution:** Wrap all `ImageProcessingService` file/byte pipelines in `Isolate.run()` (Dart 3 ergonomic isolate transfer); generate downscaled preview proxy bitmaps (max 1280px edge) for live slider/filter previews in `EditPageScreen` while reserving full-resolution processing for final export/save; configure `cacheWidth`/`cacheHeight` on `Image.file` thumbnails across `HomeScreen` and `DocumentsLibraryScreen`.
- **Dependencies & Licensing:** Built-in Dart 3 `dart:isolate` (`Isolate.run`); zero external dependencies.
- **Security & Data-Loss Risk:** ANR/OOM crash during page editing can lose unsaved edits if draft state has not flushed.
- **Measurable Acceptance Criteria:** UI thread frame times remain `< 16.6 ms` (zero >100ms UI stalls in Flutter DevTools Timeline) while running Magic Color, Sauvola, and 5-image vertical stitch on 4000x3000 JPEGs; peak RSS memory during 10-page batch edit stays `< 250 MB`.
- **Complexity:** **Medium** (2–3 days).

---

### RISK-07 — Advanced PDF Operations Execute on Main UI Isolate (`P1`)
- **Documentation vs Actual Code:** `lib/features/pdf/data/advanced_pdf_service.dart` (`1,423` lines) performs merge, split, JPEG re-compression (`compressPdf` decodes pages), watermarking, encryption, and redaction via `syncfusion_flutter_pdf` synchronously/async on the main isolate (`0` `compute()`/`Isolate.run()` calls).
- **User Impact:** Merging or compressing 30–100 page PDFs stalls progress spinners, drops frames, or triggers Android ANR dialogs. In addition, `compressPdf` on image-heavy PDFs can spike heap memory when loading full `Uint8List` PDF bytes into memory at once.
- **Technical Cause:** Missing isolate boundary around `sf.PdfDocument` load/save and image re-encoding loops in `advanced_pdf_service.dart`.
- **Recommended Solution:** Move all `AdvancedPdfService` byte/file transformations into `Isolate.run()` workers using file paths (`File` I/O inside worker isolate to avoid doubling RAM across isolate message copies) and add cancellation/progress callbacks via `ReceivePort`.
- **Dependencies & Licensing:** Dart 3 `Isolate.run` / `SendPort`; zero cost.
- **Security & Data-Loss Risk:** Interrupted main-thread crash during overwrite risks corrupted export files if not written via `.tmp` + atomic rename.
- **Measurable Acceptance Criteria:** Merging three 20-page PDFs or compressing a 50 MB PDF executes with smooth 60fps UI progress animation and zero frames > 32ms; temporary files are atomically committed and cleaned on failure.
- **Complexity:** **Medium** (2–3 days).

---

### RISK-08 — Cloud Backup & Sync Have Zero Remote Transport (`P1`)
- **Documentation vs Actual Code:** `docs/FEATURE_BACKLOG.md` marks `F-42` ("Auto-upload verified scans to Google Drive, Dropbox, OneDrive, WebDAV") and `F-43` ("Multi-device sync") as `TESTED`. In code, `cloud_backup_service.dart` (593 lines) only writes local `.scaneliq` ZIP archives, and `device_sync_service.dart` (395 lines) only serializes/parses local `EncryptedSyncEnvelope` JSON objects with LWW timestamps.
- **User Impact:** Users rely on `android:allowBackup="false"` thinking cloud backup/sync protects their documents; if their phone is lost, stolen, or uninstalled, **100% of scanned documents are permanently lost** unless manually exported.
- **Technical Cause:** No OAuth 2.0 client (`google_sign_in`), Drive API (`googleapis/drive`), WebDAV HTTP client, or WorkManager background scheduler (`workmanager`) exists in `pubspec.yaml` or `lib/`.
- **Recommended Solution:** Decide product strategy cleanly:
  - *Phase A (Honest UX + Local-First):* Immediately rename UI/docs to "Encrypted Offline Archive (.scaneliq) & Local Device Transfer" until transport ships.
  - *Phase B (True Cloud Sync):* Implement a pluggable `CloudTransportAdapter` starting with **Google Drive `appDataFolder`** (using `google_sign_in` + `googleapis` with user's own Drive quota = **\$0 server infrastructure cost**) and **WebDAV** (Nextcloud/OwnCloud/self-hosted), scheduled via `workmanager` on Wi-Fi/charging, uploading only `SCANELIQ_ENC_V2` E2EE blobs.
- **Dependencies & Licensing:** `google_sign_in` (BSD-3-Clause), `googleapis` (BSD-3-Clause), `workmanager` (MIT), `http` (BSD-3-Clause). Needs Google Cloud OAuth Android client ID (free tier / user's own Drive storage).
- **Security & Data-Loss Risk:** High data-loss risk on device wipe/uninstall; any cloud upload MUST transmit only zero-knowledge E2EE `V2` ciphertext (never raw PDFs/DB).
- **Measurable Acceptance Criteria:** Encrypted `.scaneliq` backup + delta sync manifests upload and restore cleanly across two devices via Google Drive `appDataFolder` or WebDAV while cloud inspection confirms ciphertext-only storage.
- **Complexity:** **High** (5–8 days for Drive + WebDAV + WorkManager).

---

### RISK-09 — CountCam (`F-11`) Counts OCR Text Blocks Instead of Objects (`P1`)
- **Documentation vs Actual Code:** `docs/FEATURE_TRACEABILITY_MATRIX.md` describes `F-11` as "Camera/gallery object counter with categories, detection boxes & manual adjustment." Actual code in `lib/features/scanner/presentation/count_cam_screen.dart:116-131` instantiates `TextRecognizer(script: TextRecognitionScript.latin)` and sets `_estimatedCount = recognizedText.blocks.length` (the selected `_selectedCategory` string such as `'Cartons & Packages'` or `'Books & Notebooks'` is never passed to any detector).
- **User Impact:** Pointing CountCam at pipes, boxes, coins, notebooks, or unlabeled items returns `0` or arbitrary text-line counts, breaking user trust.
- **Technical Cause:** No object detection / blob segmentation / TFLite detection model is wired in `CountCamScreen`.
- **Recommended Solution:** Replace `TextRecognizer` in `CountCamScreen` with either:
  1. `google_mlkit_object_detection` (multi-object detection with bounding boxes, on-device, Apache/Google ML Kit Terms) paired with a custom lightweight TFLite counting/connected-components fallback for dense repetitive objects (coins/bars/sheets), OR
  2. Temporarily gate/hide `CountCam` behind a "Labs / Beta" flag until real object detection is integrated so shipped UI never misleads users.
- **Dependencies & Licensing:** `google_mlkit_object_detection` or `tflite_flutter` (Apache 2.0); adds ~3–8 MB per ABI if bundling a custom TFLite model.
- **Security & Data-Loss Risk:** Low (feature-credibility risk rather than data loss).
- **Measurable Acceptance Criteria:** CountCam detects & draws per-object bounding boxes (`Rect`) on physical items without text labels (e.g., >= 85% recall on standard test images of pens/boxes/coins) and supports tap-to-add / tap-to-remove markers on the image canvas.
- **Complexity:** **High** (4–6 days).

---

### RISK-10 — Online Document Translation Misaligned with 100% Offline Brand Claim (`P2`)
- **Documentation vs Actual Code:** `README.md:38` and `F-44` assert core features run 100% on-device with no network transmission, while `lib/features/scanner/presentation/translate_screen.dart:19, 109, 135` uses `GoogleTranslator` (`translator: ^1.0.4+1`), an unofficial scraping/HTTP wrapper sending text to Google Translate servers (and requiring `INTERNET` permission—note `AndroidManifest.xml` doesn't even declare `<uses-permission android:name="android.permission.INTERNET" />` explicitly, though transitive dependencies/Flutter debug add it!).
- **User Impact:** Translation silently fails offline, breaks if Google changes unofficial translate endpoints, and leaks sensitive scanned document text over the network (even with UI consent prompt).
- **Technical Cause:** Using unofficial HTTP `translator` package instead of Google ML Kit On-Device Translation (`google_mlkit_translation`), plus missing explicit `INTERNET` permission control in `AndroidManifest.xml`.
- **Recommended Solution:** Migrate `TranslateScreen` to `google_mlkit_translation` (on-device downloadable language packs for `en` <-> `bn`, ~30 MB per pack downloaded on user request), keep strict offline fallback messaging when packs aren't downloaded, and declare `INTERNET` only if user explicitly opts into language pack downloads / optional cloud sync.
- **Dependencies & Licensing:** `google_mlkit_translation` (BSD/ML Kit Terms); zero server cost.
- **Measurable Acceptance Criteria:** Airplane-mode translation (`English <-> Bengali`) succeeds after one-time model download; `translator` package removed; no unauthorized network calls occur during translation.
- **Complexity:** **Medium** (2–3 days).

---

### RISK-11 — Full-Text Search Uses Slow SQL `LIKE` Instead of SQLite FTS5 (`P2`)
- **Documentation vs Actual Code:** `docs/FEATURE_BACKLOG.md` (`F-30`) cites "SQLite full-text index." `lib/features/documents/data/app_database_service.dart:96, 871` defines a regular table `document_ocr(document_id, full_text)` and queries `(d.title LIKE ? OR o.full_text LIKE ?)`.
- **User Impact:** Leading-wildcard `LIKE '%term%'` forces full table scans, cannot rank results by relevance/BM25, and struggles with multi-word queries (`"invoice april"`) or snippet highlighting as document count grows past 500–1,000 scans.
- **Technical Cause:** Standard B-tree/plain table schema instead of SQLite `FTS5` virtual table (Note: `sqlite3: ^3.7.1` is already in `pubspec.yaml`, though `sqflite` Android native SQLite availability of FTS5 vs `sqlite3_flutter_libs` must be checked on API 21–35).
- **Recommended Solution:** Create schema v6 migration introducing an `FTS5` (via `sqlite3_flutter_libs` for consistent FTS5 across all Android versions, or FTS4 fallback on stock Android SQLite) virtual table `documents_fts` indexing `title` and `full_text` with `unicode61` tokenizer, kept synchronized via SQLite triggers or repository transactions.
- **Dependencies & Licensing:** `sqlite3_flutter_libs` (MIT) if bundling FTS5 consistently across old Android devices (~1.5–2 MB per ABI).
- **Security & Data-Loss Risk:** Schema migration must be non-destructive (`CREATE VIRTUAL TABLE IF NOT EXISTS` + backfill `INSERT INTO documents_fts ...`), tested with downgrade/upgrade safety.
- **Measurable Acceptance Criteria:** Search across 1,000 multi-page OCR documents returns ranked results + highlighted snippets in `< 30 ms`, verified in `database_persistence_test.dart` schema v5->v6 migration tests.
- **Complexity:** **Medium** (2 days).

---

### RISK-12 — Vector PDF Visual Masking, Missing `FLAG_SECURE`, & Unencrypted SQLite DB (`P2`)
- **Documentation vs Actual Code:**
  - `PdfToolsScreen` truthfully warns about visual masking on vector PDFs (`phase9_release_candidate_test.dart` proved underlying `PdfTextExtractor` still extracts masked vector strings).
  - `MainActivity.kt` (5 lines) does not toggle `WindowManager.LayoutParams.FLAG_SECURE` when App Lock is enabled or sensitive documents are open (allowing Android recents thumbnail screenshots).
  - `scaneliq.db` and `originals/`/`processed/` files are unencrypted on the app-private filesystem (vulnerable only on rooted/unlocked-bootloader devices, not standard sandboxed devices).
- **User Impact:** Sensitive financial/ID scans can appear in Android Recent Apps switcher previews, and users importing third-party digital PDFs may believe black boxes scrubbed underlying text if they miss the subtitle.
- **Technical Cause:** Missing MethodChannel for `FLAG_SECURE`; Syncfusion PDF lacks true vector glyph-stream redaction; plain SQLite (`sqflite`) instead of SQLCipher.
- **Recommended Solution:**
  1. Add a lightweight Kotlin MethodChannel in `MainActivity.kt` to toggle `FLAG_SECURE` when App Lock is enabled (`Privacy Screen Shield` toggle in Settings).
  2. For vector PDF redaction (`F-27`), offer an optional **"Flatten & Redact (Rasterize Pages)"** mode that renders vector pages -> zeros redacted pixel regions via `permanentlyRedactImage` -> rebuilds flattened PDF (100% irreversible text destruction).
  3. Evaluate `sqflite_sqlcipher` only if enterprise vault-level at-rest DB encryption is prioritized (weighing migration complexity & ~3 MB native binary overhead).
- **Dependencies & Licensing:** Native Android `WindowManager` API (built-in); `pdfrx` rasterizer (already installed); optional `sqflite_sqlcipher` (BSD/MIT).
- **Measurable Acceptance Criteria:** Recents preview shows blank/black window when Privacy Shield is active; "Flatten & Redact" produces a PDF from which `PdfTextExtractor` extracts `0` characters of redacted target strings.
- **Complexity:** **Medium** (2–4 days).

---

### RISK-13 — Singleton Coupling & Monolithic 1,000+ Line Presentation Files (`P2`)
- **Documentation vs Actual Code:** 6 presentation screens exceed 1,000 lines (`documents_library_screen.dart` 1,769; `document_viewer_screen.dart` 1,686; `pdf_tools_screen.dart` 1,555; `edit_page_screen.dart` 1,246; `review_pages_screen.dart` 1,033; `home_screen.dart` 1,002) and bypass Riverpod DI by calling `*.instance` singletons directly.
- **User Impact:** Higher regression rate when adding new features (e.g., new scan workflows, AI tools, cloud sync status), duplicated UI logic, and weak widget-test isolation.
- **Technical Cause:** Rapid iterative feature additions directly inside StatefulWidget files rather than Riverpod `AsyncNotifier` controllers + extracted repository providers + modular widget components.
- **Recommended Solution:** Incrementally introduce Riverpod providers (`appDatabaseProvider`, `storageServiceProvider`, `documentsNotifierProvider`) alongside `*.instance` bridges, and decompose the 6 oversized screens into view-models + reusable sub-widgets (< 350 lines per file) following `scaneliq-riverpod-sqlite-architecture`.
- **Dependencies & Licensing:** Existing `flutter_riverpod: ^3.4.3`.
- **Measurable Acceptance Criteria:** All core repositories injected via Riverpod providers with `ProviderScope(overrides: [...])` support in widget tests; no UI screen file exceeds ~400–500 lines; `139+` tests remain green.
- **Complexity:** **High** (5–7 days incremental refactor).

---

### RISK-14 — Unused `go_router` Dependency & Static Analysis Warning (`P3`)
- **Documentation vs Actual Code:** `pubspec.yaml:38` declares `go_router: ^18.1.0`, yet grep confirms `0` imports in `lib/`. Also `flutter analyze` exits with code `1` due to `unused_import` of `dart:io` in `test/phase10_camscanner_features_test.dart:1:8`.
- **User Impact:** Minor unnecessary dependency footprint and failing CI strict-lint checks (`flutter analyze`).
- **Technical Cause:** `main.dart` remained on `MaterialApp` + `Navigator.push`; `dart:io` left over in test file.
- **Recommended Solution:** Remove unused `dart:io` import in `test/phase10_camscanner_features_test.dart` and either implement `GoRouter` declarative deep-link routing (`scaneliq://document/:id`, `share_plus` incoming `ACTION_VIEW`/`ACTION_SEND` intents) or remove `go_router` from `pubspec.yaml`.
- **Dependencies & Licensing:** Existing `go_router` (BSD-3-Clause).
- **Measurable Acceptance Criteria:** `flutter analyze` exits with code `0` (`No issues found!`); `go_router` either powers all route transitions + Android external PDF open intents or is cleanly removed.
- **Complexity:** **Low** (0.5 day to clean lint / 1.5 days to adopt `go_router`).

---

## 5. Dependency & Licensing Risk Summary

| Package / Component | Current Version | License | Commercial / Technical Risk | Action Required |
|---|---|---|---|---|
| `syncfusion_flutter_pdf` | `^35.1.40+1` | **Syncfusion Proprietary / Community** | **HIGH** — No license registered; Community License has revenue/headcount caps | Verify eligibility + register key via `--dart-define`, OR migrate to Apache-2.0 (`qpdf`/`pdfbox-android`) |
| `google_mlkit_text_recognition` | `^0.17.1` | Google APIs Terms / Apache wrapper | **HIGH (Functional)** — Lacks Bengali script | Supplement with Tesseract (`ben.traineddata`, Apache 2.0) |
| `translator` | `^1.0.4+1` | MIT (scrapes Google web) | **MEDIUM** — Online-only, fragile endpoint | Replace with `google_mlkit_translation` (on-device) |
| `flutter_secure_storage` | *Not installed* | BSD-3-Clause | Missing KeyStore PIN protection | Add for `AppLockService` KeyStore storage |
| `sqlite3_flutter_libs` | *Not installed* | MIT | Android stock SQLite FTS5 inconsistency on older APIs | Consider for reliable FTS5 full-text search |
| `pdf` / `pdfrx` | `3.13.1` / `2.6.5` | Apache 2.0 / MIT (PDFium BSD-3) | Low — Safe for commercial distribution | Keep and pair with background isolates |

---

## 6. Recommended Execution Sequencing (When Approved)

1. **Immediate Gate (2–3 days — P0 Release & Lint Hygiene):**
   - Fix `flutter analyze` warning (`RISK-14`).
   - Verify Syncfusion license compliance (`RISK-04`).
   - Configure release keystore + R8/ProGuard (`RISK-01`).
   - Fix `ContinuousCameraScreen` lifecycle guard & test on physical Android hardware / API 35 emulator (`RISK-02`).
2. **Core Quality & Security Hardening (5–7 days — P1):**
   - Move `AppLockService` secrets to `flutter_secure_storage` KeyStore (`RISK-05`).
   - Offload `ImageProcessingService` and `AdvancedPdfService` to `Isolate.run()` + add preview downsampling (`RISK-06`, `RISK-07`).
   - Align CountCam (`RISK-09`) and Cloud Sync labels/implementations (`RISK-08`) with real verified capabilities.
3. **Bangla Differentiator & Search Scalability (6–8 days — P0/P2):**
   - Implement genuine offline Bengali OCR (`tesseract4android` + `ben.traineddata`) (`RISK-03`).
   - Replace online `translator` with `google_mlkit_translation` (`RISK-10`).
   - Upgrade `document_ocr` to SQLite FTS5 (`RISK-11`) and add `FLAG_SECURE` + "Flatten & Redact" (`RISK-12`).
4. **Architecture & Cloud Transport (Sprint 2+ — P1/P2):**
   - Implement Google Drive `appDataFolder` + WebDAV E2EE sync (`RISK-08`), `go_router` deep linking (`RISK-14`), and incremental Riverpod decomposition (`RISK-13`).
