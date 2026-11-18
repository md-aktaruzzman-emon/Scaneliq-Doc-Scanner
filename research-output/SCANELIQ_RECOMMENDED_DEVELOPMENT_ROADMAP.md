# SCANELIQ — RECOMMENDED DEVELOPMENT ROADMAP

**Target Outcome:** Resolve all P0 release blockers, convert partial/broken modules into verified commercial workflows, and achieve sustainable parity with CamScanner, Adobe Scan, and Genius Scan.

---

## Stage A — P0 Pre-Beta Hardening & Store Compliance (Estimated 1.5–2 Weeks)

1. **Close Cold-Start App Lock Bypass & Secure Key Storage:**
   - Initialize `await AppLockService.instance.init();` inside `main.dart` before `runApp`.
   - Migrate PIN hashes, salts, and lockout metadata from `SharedPreferences` into `flutter_secure_storage` (Android KeyStore / iOS Keychain).
2. **Configure Release Signing & R8 Shrinking:**
   - Generate release upload keystore via `keytool`, wire `android/key.properties` in `android/app/build.gradle.kts`, and enable `isMinifyEnabled = true` and `isShrinkResources = true`.
3. **Syncfusion License Compliance (`RISK-04`):**
   - Register an eligible Syncfusion Community/Commercial license key in `main.dart` (or plan post-v1.0 migration to native Apache 2.0 PDFium + QPDF).
4. **Physical Android Device Hardware Verification (`Android 10–15`):**
   - Execute full end-to-end device QA covering `ContinuousCameraScreen` lifecycle/permissions, ML Kit Document Scanner, `OcrService` Latin OCR accuracy, `pdfrx` PDFium scroll/pinch/selection/password prompts, `ScanCodeScreen`, `local_auth` biometrics, and Android `SharePlus` intents.
5. **Fix Broken Bengali (`বাংলা`) OCR & UTF-8 Searchable PDF:**
   - Integrate on-device Tesseract Android (`ben.traineddata` + `eng.traineddata` via Apache 2.0 channel) with image binarization preprocessing, wire real `convertBanglaToAsciiDigits` normalization, and embed a UTF-8 Unicode font (`NotoSansBengali`) in `PdfService.generatePdf`.

---

## Stage B — P1 Stability, Security & Launch Essentials (Estimated 2–3 Weeks)

1. **Background Isolate Refactor for PDF & Image Tools:**
   - Move `AdvancedPdfService` (`merge`, `split`, `compress`, `watermark`, `encrypt`, `annotate`, `redact`) and `PdfService.exportPageAsJpeg` / `splitBookSpreadFile` / `stitchImageFilesVertically` onto `Isolate.run()`.
   - Add `cacheWidth` to `ScaneliqPaperThumbnail`, `TrashScreen`, `_buildFallbackImageViewer`, and `CountCamScreen`.
2. **Default Backup Passphrase & Privacy Controls:**
   - Add mandatory/optional passphrase prompt in `SettingsScreen._createBackup()` and `_restoreBackup()` so backups leverage V2 AES-256-CBC-EtM.
   - Add `FLAG_SECURE` toggle in `MainActivity.kt` via `MethodChannel` and wire a touch-redaction brush to `ImageProcessingService.permanentlyRedactImage()`.
3. **Resolve or Reposition Broken `CountCam`:**
   - Replace `TextRecognizer` text-block counting with a quantized TFLite object/instance counter (e.g., YOLOv8-nano/MobileNet) or cleanly remove CountCam from v1.0 release tools.
4. **Finish Core Vault & Viewer Wiring Gaps:**
   - Unify `PdfToolsScreen._annotatePdf` to launch `DocumentViewerScreen(startInAnnotateMode: true)`.
   - Enable subfolder selection in `_showMoveFolderSheet`, invoke `purgeExpiredTrash(30d)` on startup, implement `duplicateDocument()`, and wire `FileCategoryFilter.images`.
5. **Subscription & Monetization Engine (v1.0 Commercial Release Gate):**
   - Add `in_app_purchase` / RevenueCat SDK, define Free vs Pro tiers (keeping clean unwatermarked basic scans as Scaneliq's competitive wedge, gating Cloud Sync, AI Assistant, Unlimited Batch OCR, and Office Exports), and verify Google Play Console purchase + restore flows.

---

## Stage C — P1/P2 Cloud Continuity, FTS5 & AI Parity (Estimated 3–4 Weeks)

1. **True Cloud Backup & Multi-Device Sync:**
   - Integrate Google Drive AppData (`google_sign_in` + Drive REST v3) and optional WebDAV/Dropbox exports with incremental media + SQLite sync, background `workmanager` upload queue, and AES-GCM encrypted envelopes replacing the legacy 1,000-iter XOR sync stub.
2. **SQLite FTS5 Search & Offline Translation:**
   - Migrate `document_ocr` search from `LIKE '%term%'` to FTS5 virtual tables with highlighted snippets.
   - Replace online-only `GoogleTranslator` with `google_mlkit_translation` downloadable offline models for Bn<->En and multi-language translation + `.txt`/PDF export.
3. **Genuine AI Assistant & Office Conversions:**
   - Upgrade `AiDocumentService` with true entity extraction (dates, invoice numbers, currency totals, organizations) and optional opt-in cloud/local LLM Q&A + vault-wide semantic search.
   - Add Table Extraction + Word (`.docx`) / Excel (`.xlsx`) export pipeline.

---

## Stage D — P3 Multi-Platform & Enterprise Expansion

- Regenerate full **iOS Runner** (`Info.plist`, `AppDelegate.swift`, `Runner.xcodeproj`) on macOS Xcode, verify Metal/AVFoundation camera + Vision/Tesseract OCR, and add optional **X.509 certificate PDF signing** for legal/enterprise users.
