# Scaneliq — Current Architecture Audit Report

**Audit Date:** November 18, 2026  
**Workspace:** `C:\Scaneliq`  
**Scope:** Structural, dependency, state-management, persistence, concurrency, security, and Android build configuration audit of the existing Flutter codebase (`38` Dart files in `lib/`, `22` test files in `test/`).  
**Protection Compliance:** Zero source-code, dependency, database, or APK modifications performed.

---

## 1. High-Level Module & Codebase Inventory

Scaneliq follows a **feature-first folder layout** under `lib/core/` and `lib/features/`, anchored by `lib/app/main_navigation_shell.dart`.

### Directory & File Size Distribution (Verified)
- **`lib/main.dart`** (32 lines) — Initializes `AppStorageService` and wraps `ScaneliqApp` in `ProviderScope`.
- **`lib/app/main_navigation_shell.dart`** (313 lines) — 4-tab `IndexedStack` shell (Home, Docs, Tools, Settings), central scanner launcher, and `WidgetsBindingObserver` app-lock lifecycle barrier.
- **`lib/core/`** (6 files):
  - `image_processing/image_processing_service.dart` (1,001 lines)
  - `models/document_models.dart` (670 lines)
  - `theme/app_theme.dart` (552 lines)
  - `storage/app_storage_service.dart` (173 lines)
  - `services/smart_filename_service.dart` (119 lines)
  - `widgets/scaneliq_logo.dart` (48 lines)
- **`lib/features/`** (30 files across 7 feature modules):
  - **`documents/`:** `documents_library_screen.dart` (1,769 lines), `document_viewer_screen.dart` (1,686 lines), `app_database_service.dart` (1,129 lines), `home_screen.dart` (1,002 lines), `trash_screen.dart` (412 lines), `batch_merge_service.dart` (93 lines).
  - **`pdf/`:** `pdf_tools_screen.dart` (1,555 lines), `advanced_pdf_service.dart` (1,423 lines), `pdf_page_organizer_screen.dart` (782 lines), `pdf_service.dart` (353 lines).
  - **`editor/`:** `edit_page_screen.dart` (1,246 lines), `review_pages_screen.dart` (1,033 lines).
  - **`scanner/`:** `continuous_camera_screen.dart` (738 lines), `scan_session_provider.dart` (445 lines), `translate_screen.dart` (372 lines), `count_cam_screen.dart` (369 lines), `scan_code_screen.dart` (212 lines).
  - **`intelligence/`:** `receipt_dialog.dart` (416 lines), `ai_document_sheet.dart` (356 lines), `ai_document_service.dart` (351 lines), `business_card_service.dart` (317 lines), `business_card_dialog.dart` (301 lines), `receipt_parser_service.dart` (227 lines).
  - **`settings/`:** `settings_screen.dart` (977 lines), `tools_screen.dart` (598 lines).
  - **`cloud_sync/`:** `cloud_backup_service.dart` (593 lines), `device_sync_service.dart` (395 lines).
  - **`security/`:** `app_lock_service.dart` (386 lines), `app_lock_dialog.dart` (376 lines).
  - **`ocr/`:** `ocr_service.dart` (170 lines).

---

## 2. Dependency & Toolchain Audit (`pubspec.yaml` & Gradle)

- **Flutter / Dart SDK:** Flutter `3.47.7` (stable), Dart `3.13.5`, OpenJDK `17.0.20.1`.
- **Android Configuration (`android/app/build.gradle.kts`):**
  - `namespace = "com.scaneliq.scaneliq"`, `applicationId = "com.scaneliq.scaneliq"`
  - `compileSdk`, `minSdk`, `targetSdk`, `ndkVersion`, `versionCode`, `versionName` inherit Flutter Gradle defaults.
  - `compileOptions` / `kotlin.compilerOptions`: Java 17 / JVM 17.
  - **Release Build Gap:** `buildTypes.release` currently assigns `signingConfig = signingConfigs.getByName("debug")` and does not explicitly enable `isMinifyEnabled = true` or `isShrinkResources = true`.
- **Android Manifest (`android/app/src/main/AndroidManifest.xml`):**
  - Minimal permissions: `CAMERA`, `USE_BIOMETRIC`.
  - Privacy hardening enabled: `android:allowBackup="false"`, `android:fullBackupContent="false"`, `android:usesCleartextTraffic="false"`.
- **Unused / Partially Unused Dependencies:**
  - `go_router: ^18.1.0` is declared in `pubspec.yaml`, but `lib/main.dart` uses `MaterialApp` directly with imperative `Navigator.push`.
  - `riverpod_generator: ^4.0.9` / `build_runner: ^2.16.2` are in `dev_dependencies`, while `ScanSessionNotifier` uses manual `NotifierProvider`.

---

## 3. State Management & Navigation Architecture

### Current Pattern
- **Mixed Riverpod + Singleton + Local `StatefulWidget`:**
  - `ScanSessionNotifier` (`lib/features/scanner/presentation/scan_session_provider.dart`) uses Riverpod's `Notifier<ScanSessionState>`.
  - Virtually all data, storage, PDF, OCR, security, and sync services are implemented as **global static singletons** (`AppDatabaseService.instance`, `AppStorageService.instance`, `AppLockService.instance`, `OcrService.instance`, `CloudBackupService.instance`, `DeviceSyncService.instance`, `AiDocumentService.instance`).
  - Presentation screens (`HomeScreen`, `DocumentsLibraryScreen`, `DocumentViewerScreen`, `PdfToolsScreen`, `SettingsScreen`) call `.instance` directly inside `StatefulWidget` methods rather than consuming Riverpod repository/service providers.
- **Navigation:**
  - Root shell uses `IndexedStack` across 4 tabs, with imperative `Navigator.push(MaterialPageRoute(...))` for sub-flows. No declarative URL/deep-link routing is active.

### Architectural Risks
1. **Tight Coupling & Testability:** Direct `.instance` calls inside 1,000–1,769 line UI screens prevent clean Riverpod provider overrides in widget tests.
2. **Monolithic UI Screens:** Six presentation files exceed 1,000 lines (`documents_library_screen.dart` at 1,769 lines, `document_viewer_screen.dart` at 1,686 lines, `pdf_tools_screen.dart` at 1,555 lines, `edit_page_screen.dart` at 1,246 lines, `review_pages_screen.dart` at 1,033 lines, `home_screen.dart` at 1,002 lines), mixing UI layout, dialog builders, file I/O, and database orchestration.

---

## 4. Data, Storage & Persistence Architecture

### A. File System Sandbox (`AppStorageService`)
Manages 4 isolated subdirectories inside `getApplicationDocumentsDirectory()`:
- `originals/` — Immutable source images (`saveOriginalPage`, `copyToOriginals` with atomic `.tmp` write + rename and magic-byte validation for JPEG, PNG, WebP).
- `processed/` — Cached rendered outputs from non-destructive `EditRecipe` evaluation.
- `exports/` — Generated PDF and JPEG outputs.
- `temp/` — Scratch staging area with automatic 24-hour stale file cleanup (`cleanStaleTempFiles()`).

### B. SQLite Schema (`AppDatabaseService` — `scaneliq.db`, Version 5)
Foreign keys enabled (`PRAGMA foreign_keys = ON;`).

| Table | Purpose | Key Relations / Constraints |
|---|---|---|
| `folders` | Hierarchical folder tree | `parent_id -> folders(id) ON DELETE CASCADE` |
| `documents` | Document metadata, draft/favorite/trash flags | `folder_id -> folders(id) ON DELETE SET NULL`, `deleted_at` soft-delete |
| `pages` | Ordered pages, original/processed paths, JSON `edit_recipe_json` | `document_id -> documents(id) ON DELETE CASCADE` |
| `document_ocr` | Extracted full text per document | `document_id -> documents(id) ON DELETE CASCADE` |
| `tags` | Color-coded labels (`name UNIQUE`) | Standalone lookup |
| `document_tags` | Many-to-many document-tag mapping | Composite PK `(document_id, tag_id)` with `ON DELETE CASCADE` |
| `document_bookmarks` | In-app page bookmarks | `document_id -> documents(id) ON DELETE CASCADE` |

**Indexes:** `idx_pages_doc_order`, `idx_docs_modified`, `idx_docs_folder`, `idx_docs_deleted`, `idx_folders_parent`, `idx_doc_tags_doc`, `idx_doc_tags_tag`, plus bookmark index.  
**Search Limitation:** `searchQuery` uses SQL `LIKE '%term%'` on `documents.title` and `document_ocr.full_text` rather than SQLite FTS5, which will degrade in latency as the library scales to thousands of OCR-indexed pages.

---

## 5. Processing, Concurrency & Performance Architecture

- **PDF Generation (`lib/features/pdf/data/pdf_service.dart`):** Uses Flutter `compute()` to offload PDF/image compilation to a background isolate.
- **Image Processing (`lib/core/image_processing/image_processing_service.dart`):** Pure-Dart `image` package implementation for 4-point projective homography, Otsu/Sauvola thresholding, Magic Color, whiteboard glare removal, cleanup patches, mosaic redaction, book spread splitting, and vertical stitching. **Gap:** None of the `ImageProcessingService` public methods currently dispatch work via `compute()` or `Isolate.run()`, meaning high-resolution image operations execute on the main UI isolate.
- **OCR (`lib/features/ocr/data/ocr_service.dart`):** Caches `TextRecognizer` instances by `TextRecognitionScript`. Currently maps `OcrScript.bengali` to `TextRecognitionScript.devanagiri` (which does not recognize Bengali script).

---

## 6. Security & Cryptography Architecture

- **App Lock (`AppLockService`):**
  - RFC 2898 PBKDF2-HMAC-SHA256 (`pointycastle`), 100,000 iterations (`v3:100000:<salt>:<hash>`), constant-time verification, 5-attempt lockout with 30-second cooldown, and legacy V1/V2 auto-migration.
  - **Gap:** Salt and hash are persisted in `SharedPreferences` instead of hardware-backed Android KeyStore (`flutter_secure_storage`).
- **Encrypted Backups (`CloudBackupService` V2):**
  - PBKDF2-HMAC-SHA256 (100,000 iterations, 16-byte random salt) deriving 64 bytes (32-byte $K_{enc}$ + 32-byte $K_{mac}$).
  - AES-256-CBC (`encrypt` package) + HMAC-SHA256 Encrypt-then-MAC (MAC verified in constant time *before* decryption).
  - Zip Slip path-traversal check prior to archive extraction.
- **PDF Security & Redaction:**
  - `AdvancedPdfService` supports AES-256 PDF password encryption (`syncfusion_flutter_pdf`).
  - Raster image redaction/mosaic (`permanentlyRedactImageFile`, `permanentlyMosaicImageFile`) permanently overwrites pixels; vector PDF redaction performs visual blackout + metadata scrubbing.

---

## 7. Key Architectural Recommendations (Summary for Next Phase)

1. **Decouple Singletons via Riverpod Providers & Decompose Monolithic Screens:** Split 1,000+ line screens into smaller widgets/controllers and inject repositories/services through Riverpod providers.
2. **Isolate Worker Pool for `ImageProcessingService`:** Move decode/warp/filter/stitch pipelines off the main isolate using `Isolate.run()` / `compute()`.
3. **Adopt `go_router` or Remove Unused Dependency:** Either wire `go_router` in `lib/main.dart` for deep links and clean navigation, or remove it from `pubspec.yaml`.
4. **Upgrade Search to SQLite FTS5 & Fix Bangla OCR:** Add an FTS5 virtual table for instant full-text search and integrate a real Bengali OCR engine (`ben.traineddata` / dedicated model).
5. **Release Signing & KeyStore Hardening:** Configure proper release `signingConfig`, enable R8 `isMinifyEnabled`/`isShrinkResources`, and migrate `AppLockService` secrets to `flutter_secure_storage`.
