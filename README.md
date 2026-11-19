<p align="center">
  <img src="assets/branding/scaneliq_logo_master.png" alt="Scaneliq Official Logo" width="120" />
</p>

<h1 align="center">Scaneliq — Local-First Document Scanner &amp; PDF Studio</h1>

<p align="center">
  <strong>Android Package ID:</strong> <code>com.scaneliq.scaneliq</code> &bull;
  <strong>Version:</strong> <code>2.67.0+26700</code> &bull;
  <strong>Architecture:</strong> Offline-First Flutter + Kotlin Native Engines
</p>

---

## Overview

**Scaneliq** is an offline-first Android document scanner, bilingual OCR (**English + Bengali / বাংলা**), PDF productivity suite, and encrypted local document vault built with Flutter/Dart, Riverpod, GoRouter, SQLite FTS5, Syncfusion PDF, PDFium (`pdfrx`), ML Kit, and Android native `tesseract4android`.

- **Zero Mandatory Accounts & Local-First Privacy:** Every scan, perspective warp, Otsu/Sauvola enhancement, OCR extraction, searchable PDF generation, and offline AI summary runs locally on device with zero cloud lock-in (`allowBackup="false"`, `usesCleartextTraffic="false"`).
- **Editorial Gallery Minimal Design (Concept A):** *Gallery Alabaster* (`#FAF9F6`) Light theme, *Carbon Studio* (`#0D0E11`) Dark theme, and *International Ultramarine* (`#0052FF` / `#3B82F6`) accents across a 3-tab `StatefulShellRoute` navigation shell (`Scans`, `Folders`, `PDF Suite`).

---

## Key Capabilities

| Area | Implemented Capabilities |
|---|---|
| **Document Capture & Modes** | Continuous batch scanning, ML Kit boundary detection, manual 4-point homography corner warp with loupe, gallery multi-import (`<= 80 MB`, magic-byte verified), ID Card 2-in-1 A4 sheet stitching, Book Spread center split, Whiteboard glare cleanup, Exam / Question Set B&W preset, QR/Barcode scanner (`mobile_scanner`), CountCam object counter. |
| **Non-Destructive Image Editor** | Immutable `originals/` preservation paired with JSON `EditRecipe` v2, 9 filters (`Original`, `Auto Enhance`, `Magic Color`, `Grayscale`, `B&W Otsu`, `Sauvola`, `Whiteboard`, `Lighten`, `Darken`), brightness/contrast/sharpness sliders, touch cleanup eraser, Undo/Redo history stack, split-wipe compare, single-pass PDF/JPEG export. |
| **PDF Productivity & Viewer** | Multi-page A4 & Letter PDFs at `Compact 150 / Balanced 200 / High 300 DPI`, zero watermarks, in-app `pdfrx` viewer with text search/page jump/bookmarks, Merge (with isolated page cloning), Split (pages/ranges), Page Organizer (reorder/rotate/duplicate/extract/insert), Compression, AES-256 Encryption/Unlock, Text & Image Watermarking, Annotations & Visual Signatures, Irreversible Flatten-and-Redact & Raster Pixel/Mosaic Redaction, PDF-to-Images, Long Vertical Image Stitch, Metadata Inspector. |
| **Bengali & English OCR + AI** | Mixed **Bengali + English** offline OCR (`TesseractOcrEngine.kt` `tesseract4android:4.9.0` + `ben.traineddata`/`eng.traineddata`), UTF-8 searchable PDFs (`NotoSansBengali-Regular.ttf`), Table CSV/Markdown extraction, offline ML Kit Translation (`Bn ↔ En`), Business Card vCard 3.0 extractor, Invoice/Receipt math-checked parser, Offline TextRank AI summary + entity/Q&A assistant. |
| **Vault, Sync & Security** | SQLite v6 FTS5 (`unicode61`) bilingual search with snippets, nested cycle-safe folders, color tags, Smart Filename templates (`[Date]`, `[Title]`, `[Time]`, `[Category]`, `[Counter]`), 30-day Trash auto-purge, encrypted `.scaneliq` ZIP backups & multi-device E2EE Sync V2 (PBKDF2-100k + AES-256-CBC Encrypt-then-MAC), WebDAV HTTPS sync with Android KeyStore credentials, cold-start AppLock PIN/Biometrics, `FLAG_SECURE` privacy shield, live storage breakdown & temp cache cleaner. |

---

## Project Structure

```text
scaneliq/
├── assets/
│   ├── branding/                     # scaneliq_logo_master.png & adaptive foreground
│   ├── fonts/                        # NotoSansBengali-Regular.ttf (UTF-8 searchable PDF)
│   └── tessdata/                     # eng.traineddata, ben.traineddata
├── android/app/src/main/kotlin/com/scaneliq/scaneliq/
│   ├── MainActivity.kt               # FLAG_SECURE + Tesseract OCR platform channels
│   └── TesseractOcrEngine.kt         # tesseract4android 4.9.0 JNI bridge
├── docs/
│   ├── SCANELIQ_MASTER_FUNCTIONAL_INVENTORY.md
│   ├── SCANELIQ_COMPLETE_PROJECT_REPAIR_REPORT.md
│   ├── Scaneliq_Master_Blueprint_Improved.md
│   ├── FEATURE_BACKLOG.md
│   └── FEATURE_TRACEABILITY_MATRIX.md
├── lib/
│   ├── main.dart                     # App startup (Storage, Preferences, AppLock, PrivacyShield, Trash purge)
│   ├── app/                          # App router export & shell wrapper
│   ├── core/                         # Concept A theme/tokens, models, Isolate image processing, storage, ScanPreferencesService, SmartFilenameService
│   └── features/
│       ├── documents/                # Home, Documents Library, Trash, Viewer, SQLite v6 FTS5, BatchMergeService
│       ├── scanner/                  # Camera Studio, ScanSession, Translation, CountCam, QR/Barcode
│       ├── editor/                   # EditPage, ReviewPages, EditHistory, RasterRedaction
│       ├── pdf/                      # PdfService (single-pass + searchable), AdvancedPdfService, PdfTools, PageOrganizer, Annotations/Watermark/Signature
│       ├── ocr/                      # OcrService (ML Kit + Tesseract JNI + OcrTableExtractor)
│       ├── intelligence/             # TextRank AI Assistant, BusinessCardService, ReceiptParserService
│       ├── cloud_sync/               # Encrypted Backup, WebDAV transport, DeviceSync V2
│       ├── security/                 # AppLock (PBKDF2-100k + KeyStore), PrivacyShield (FLAG_SECURE)
│       └── settings/                 # Tools Hub, Settings & Preferences, Help & Compliance
└── test/                             # 34 automated unit, integration, crypto, PDF, image & widget test suites (205 tests)
```

---

## Build & Verification Commands

> **Toolchain:** Flutter `3.47.7` · Dart `3.13.5` · Android SDK `36.0.0` · OpenJDK `17.0.20.1`

```bash
# Install packages
flutter pub get

# Format & static analysis (expected: 0 issues)
dart format lib test
flutter analyze --no-pub

# Run full automated test suite (expected: 205/205 passing across 34 test suites)
flutter test --no-pub --reporter expanded

# Build Android APKs
flutter build apk --debug --no-pub
flutter build apk --release --split-per-abi --no-pub
```

> **Note on Release Signing & Play Billing:** For Play Store uploads, copy `android/key.properties.example` to `android/key.properties` with your release `.jks` keystore, configure Play Console SKUs (`scaneliq_pro_monthly`, `scaneliq_ultra_monthly`), and provide Syncfusion license compliance flags (`--dart-define=SYNCFUSION_LICENSE_ACK=community|commercial`). Detailed audit and verification status is tracked in [`docs/SCANELIQ_COMPLETE_PROJECT_REPAIR_REPORT.md`](docs/SCANELIQ_COMPLETE_PROJECT_REPAIR_REPORT.md).
