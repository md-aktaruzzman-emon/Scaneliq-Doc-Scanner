# SCANELIQ — COMPLETE PRODUCT FEATURE AUDIT

**Audit Date:** November 19, 2026  
**Project Directory:** `C:\Scaneliq`  
**Audit Type:** Strictly Read-Only Technical & Functional Audit (Zero edits to source, build configs, DB, APKs, or skills)  
**Approved Visual Baseline:** Concept A — Editorial Gallery Minimal (`Gallery Alabaster #FAF9F6`, `Carbon Studio #0D0E11`, `International Ultramarine #0052FF / #3B82F6`)

---

## 1. Documentation & Prior Phase Verification Check

All 15 referenced planning, design, audit, and Phase 1–5 reports under `C:\Scaneliq\research-output\` are present on disk:
- Baseline Audits & Design Specs (`SCANELIQ_IMPLEMENTATION_STATUS_AUDIT.md`, `SCANELIQ_CURRENT_ARCHITECTURE_AUDIT.md`, `SCANELIQ_TECHNICAL_RISK_REGISTER.md`, `SCANELIQ_COMPLETE_SCREEN_INVENTORY.md`, `SCANELIQ_OFFICIAL_DESIGN_SYSTEM.md`, `SCANELIQ_COMPLETE_SCREEN_DESIGN_SPEC.md`, `SCANELIQ_COMPONENT_LIBRARY.md`, `SCANELIQ_NAVIGATION_AND_USER_FLOWS.md`, `SCANELIQ_FLUTTER_UI_IMPLEMENTATION_PLAN.md`, `SCANELIQ_FINAL_UX_VALIDATION_REPORT.md`)
- Phase Reports (`SCANELIQ_PHASE1_FLUTTER_IMPLEMENTATION_REPORT.md` through `SCANELIQ_PHASE5_PDF_IMPLEMENTATION_REPORT.md`)
- Generated Flutter Screenshot Sets (`flutter-phase3`: `8` PNGs, `flutter-phase4`: `11` PNGs, `flutter-phase5`: `13` PNGs)

**Crucial Finding:** Phases 1–5 UI/UX redesign and local engine upgrades genuinely transformed the visual shell (`go_router` root wiring, Concept A tokens, Camera Studio lifecycle lock, non-destructive Scan Editor via `Isolate.run`, PDF Annotations/Signature/Watermark/Page Organizer). However, **several critical backend defects documented in the baseline audit remain unfixed**, and **one critical regression/bug was uncovered in `AppLockService` cold-start initialization**.

---

## 2. Summary Statistics (157 Audited Features)

| Classification | Count | Share |
|---|---:|---:|
| **FULLY IMPLEMENTED** | **61** | 38.9% |
| **PARTIALLY IMPLEMENTED** | **55** | 35.0% |
| **UI ONLY** | **0** | 0.0% |
| **BACKEND ONLY** | **1** | 0.6% |
| **BROKEN** | **3** | 1.9% |
| **UNVERIFIED** | **7** | 4.5% |
| **MISSING** | **29** | 18.5% |
| **PLANNED** | **1** | 0.6% |
| **Total Features Audited** | **157** | **100%** |

> *Notes on hidden sub-feature traps:* Although no top-level inventory row is pure `UI ONLY`, `CountCam` (`BROKEN`) includes a decorative category selector (`Boxes / Cartons`, `Pipes / Rods`, etc.) that alters nothing, and `Filtering` (`PARTIALLY IMPLEMENTED`) defines `FileCategoryFilter.images` in its enum with zero filtering logic. Likewise, while only `Conflict resolution` (LWW on local JSON sync envelopes) sits as top-level `BACKEND ONLY`, three additional capabilities have unused backend implementations without UI/schedulers: `ImageProcessingService.permanentlyRedactImage`/`permanentlyMosaicImage`, `AppDatabaseService.purgeExpiredTrash()`, and extra templates in `SmartFilenameService`.

---

## 3. Master Feature Matrix (All 157 Features Across Categories A–K)

| Feature | Category | Status | UI | Backend | Tests | Device Verified | Evidence | Priority |
|---|---|---|---|---|---|---|---|---|
| Live camera preview | Scanning & Camera | UNVERIFIED | Yes | Yes | Mocked backend | No | `continuous_camera_screen.dart`; `camera_studio_controller.dart` (`FlutterCameraBackend`) | P0 |
| Automatic document detection | Scanning & Camera | PARTIALLY IMPLEMENTED | Yes | Yes | Synthetic image tests | No | `document_edge_detector.dart` (`DocumentEdgeDetector.detect`); `scan_session_provider.dart` | P0 |
| Automatic capture | Scanning & Camera | PARTIALLY IMPLEMENTED | Yes | Yes | Mocked stability test | No | `document_edge_detector.dart` (`DocumentStabilityTracker`); `scanner_studio_provider.dart` | P1 |
| Manual capture | Scanning & Camera | PARTIALLY IMPLEMENTED | Yes | Yes | Mocked widget test | No | `scanner_studio_provider.dart` (`captureManual`); `FlutterCameraBackend.takePicture` | P0 |
| Flash control | Scanning & Camera | PARTIALLY IMPLEMENTED | Yes | Yes | Unit/widget mock | No | `scanner_studio_provider.dart` (`cycleFlashMode`); `camera_studio_controller.dart` | P1 |
| Focus and exposure | Scanning & Camera | PARTIALLY IMPLEMENTED | Yes | Yes | Widget tap test | No | `continuous_camera_screen.dart`; `camera_studio_controller.dart` (`focusAtPoint`) | P2 |
| Camera switching | Scanning & Camera | PARTIALLY IMPLEMENTED | Yes | Yes | Mocked test | No | `scanner_studio_provider.dart` (`switchCamera`); `camera_studio_controller.dart` | P2 |
| Gallery import | Scanning & Camera | FULLY IMPLEMENTED | Yes | Yes | Unit + widget tests | No | `gallery_import_service.dart` (`GalleryImportService`); `scan_session_provider.dart` (`importFiles`) | P3 |
| Multi-page scanning | Scanning & Camera | PARTIALLY IMPLEMENTED | Yes | Yes | Batch + session tests | No | `scan_session_provider.dart`; `batch_scanning_test.dart`; `phase3_scanner_camera_test.dart` | P0 |
| Capture review | Scanning & Camera | FULLY IMPLEMENTED | Yes | Yes | Widget tests | No | `review_pages_screen.dart` (`ReviewPagesScreen`) | P3 |
| Retake | Scanning & Camera | FULLY IMPLEMENTED | Yes | Yes | Widget test | No | `review_pages_screen.dart` (`_retakePage`); `scanner_studio_provider.dart`; `replacePageFile` | P3 |
| Page deletion (scan session) | Scanning & Camera | FULLY IMPLEMENTED | Yes | Yes | Unit + widget tests | No | `scan_session_provider.dart` (`removePage`); `phase3_scanner_camera_test.dart` | P3 |
| Capture session recovery | Scanning & Camera | FULLY IMPLEMENTED | Yes | Yes | DB persistence tests | No | `scan_session_provider.dart` (`_persistDraft`); `latestDraftProvider`; `home_screen.dart` | P3 |
| Document boundary detection | Scanning & Camera | PARTIALLY IMPLEMENTED | Yes | Yes | Synthetic image tests | No | `document_edge_detector.dart`; `image_processing_service.dart` (`autoDetectDocumentQuad`) | P1 |
| Perspective correction (capture) | Scanning & Camera | FULLY IMPLEMENTED | Yes | Yes | Unit image tests | No | `image_processing_service.dart` (`applyPerspectiveWarp`); `image_processing_test.dart` | P3 |
| Camera lifecycle handling | Scanning & Camera | PARTIALLY IMPLEMENTED | Yes | Yes | Lifecycle unit/widget test | No | `continuous_camera_screen.dart:73` (`didChangeAppLifecycleState` -> `handleAppLifecycleState`) | P0 |
| Large image handling | Scanning & Camera | PARTIALLY IMPLEMENTED | Yes | Partial | Guard unit tests | No | `gallery_import_service.dart` (`80MB`); missing `cacheWidth` in `ScaneliqPaperThumbnail`, `TrashScreen`, `FallbackViewer`, `CountCam` | P1 |
| Automatic crop | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `phase4_scan_editor_test.dart` | No | `image_processing_service.dart` (`autoDetectDocumentQuadFromFile`); `edit_page_screen.dart:191` | P3 |
| Manual four-corner crop | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `phase4_scan_editor_test.dart` | No | `editor_preview_stage.dart`; `edit_page_screen.dart` (`EditTab.crop`) | P3 |
| Perspective correction (editor) | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `image_processing_test.dart`; `phase4_scan_editor_test.dart` | No | `image_processing_service.dart`; `edit_page_screen.dart` | P3 |
| Rotation | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `phase4_scan_editor_test.dart` | No | `edit_page_screen.dart` (`_rotateBy`); `image_processing_service.dart` | P3 |
| Original filter | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `phase4_scan_editor_test.dart` | No | `document_models.dart` (`PageFilter.original`) | P3 |
| Auto enhancement | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `phase4_scan_editor_test.dart` | No | `image_processing_service.dart` (`applyAutoEnhance`); `PageFilter.autoEnhance` | P3 |
| Magic Color | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `image_processing_test.dart`; `phase4_scan_editor_test.dart` | No | `image_processing_service.dart`; `PageFilter.magicColor` | P3 |
| Grayscale | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `phase4_scan_editor_test.dart` | No | `image_processing_service.dart`; `PageFilter.grayscale` | P3 |
| Black & White | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `image_processing_test.dart`; `phase4_scan_editor_test.dart` | No | `image_processing_service.dart`; Otsu & Sauvola modes | P3 |
| Brightness | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `edit_recipe_test.dart`; `phase4_scan_editor_test.dart` | No | `edit_page_screen.dart`; `image_processing_service.dart` (buffer clone fix) | P3 |
| Contrast | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `edit_recipe_test.dart`; `phase4_scan_editor_test.dart` | No | `edit_page_screen.dart`; `image_processing_service.dart` | P3 |
| Sharpness | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `phase4_scan_editor_test.dart` | No | `image_processing_service.dart` (`applySharpness` 3x3); `EditRecipe.sharpness` | P3 |
| Before/after comparison | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `phase4_scan_editor_test.dart` | No | `editor_preview_stage.dart` (`_buildBeforeAfterComparison`) | P3 |
| Undo and redo | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `phase4_scan_editor_test.dart` | No | `edit_history_controller.dart` (`EditHistoryStack`, `MultiPageEditHistory`) | P3 |
| Non-destructive editing | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `edit_recipe_test.dart`; `phase4_scan_editor_test.dart` | No | `AppStorageService` `originals/`; `EditRecipe` v2 JSON in SQLite | P3 |
| Multi-page editing | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `phase4_scan_editor_test.dart` | No | `edit_page_screen.dart`; `scan_session_provider.dart` (`syncEditedPages`) | P3 |
| High-resolution export | Image Editing | FULLY IMPLEMENTED | Yes | Yes | `phase4_scan_editor_test.dart`; `pdf_generation_test.dart` | No | `processImageFileToBytesInIsolate`; `PdfService.exportPageAsJpeg` & `generatePdf` | P2 |
| Document library | Document Management | FULLY IMPLEMENTED | Yes | Yes | `phase2_navigation_and_screens_test.dart` | No | `documents_library_screen.dart`; `app_database_service.dart` | P3 |
| Folder creation | Document Management | FULLY IMPLEMENTED | Yes | Yes | `organization_and_batch_test.dart`; `phase2_navigation_and_screens_test.dart` | No | `app_database_service.dart:303` (`createFolder`); `_showCreateFolderSheet` | P3 |
| Folder renaming | Document Management | FULLY IMPLEMENTED | Yes | Yes | `organization_and_batch_test.dart`; `phase2_navigation_and_screens_test.dart` | No | `app_database_service.dart:322` (`renameFolder`); `_showRenameFolderSheet` | P3 |
| Folder deletion | Document Management | FULLY IMPLEMENTED | Yes | Yes | `organization_and_batch_test.dart` | No | `app_database_service.dart:430` (`deleteFolder`); `_showDeleteFolderSheet` | P3 |
| Move documents | Document Management | PARTIALLY IMPLEMENTED | Partial | Yes | `organization_and_batch_test.dart` | No | `app_database_service.dart:755`; `documents_library_screen.dart:400` (queries `parentId: null` only — nested folders unreachable) | P2 |
| Copy documents | Document Management | MISSING | No | No | None | No | Absent from `AppDatabaseService` & UI | P2 |
| Rename documents | Document Management | FULLY IMPLEMENTED | Yes | Yes | `database_persistence_test.dart` | No | `app_database_service.dart:991` (`renameDocument`); `_renameDocumentWithSmartNaming` | P3 |
| Starred documents | Document Management | FULLY IMPLEMENTED | Yes | Yes | `phase2_navigation_and_screens_test.dart` | No | `app_database_service.dart:980` (`toggleFavorite`); Home & Library | P3 |
| Recent documents | Document Management | FULLY IMPLEMENTED | Yes | Yes | `phase1_foundation_ui_test.dart`; `phase2_navigation_and_screens_test.dart` | No | `home_screen.dart:319`; `app_database_service.dart:895` (`modified_at DESC`) | P3 |
| Document search | Document Management | PARTIALLY IMPLEMENTED | Yes | Partial | `database_persistence_test.dart` | No | `app_database_service.dart:869-874` (`LIKE '%term%'`, not FTS5) | P1 |
| Sorting | Document Management | FULLY IMPLEMENTED | Yes | Yes | `navigation_and_screens_test.dart` | No | `documents_library_screen.dart:940`; `home_screen.dart:301` | P3 |
| Filtering | Document Management | PARTIALLY IMPLEMENTED | Partial | Yes | `organization_and_batch_test.dart` | No | `documents_library_screen.dart:29,914-938,982` (`FileCategoryFilter.images` unimplemented, returns `0`) | P2 |
| Multi-selection | Document Management | FULLY IMPLEMENTED | Yes | Yes | `organization_and_batch_test.dart` | No | `home_screen.dart:127`; `documents_library_screen.dart:89`; `trash_screen.dart:22` | P3 |
| Batch actions | Document Management | FULLY IMPLEMENTED | Yes | Yes | `organization_and_batch_test.dart` | No | `documents_library_screen.dart:1557` (`_buildBatchDock`); `batch_merge_service.dart` | P3 |
| Document sharing | Document Management | PARTIALLY IMPLEMENTED | Yes | Yes | Mock/UI | No | `share_plus` in Home/Library/Viewer/Review (Android share intent unverified on device) | P0 |
| Document duplication | Document Management | MISSING | No | No | None | No | Page duplicate exists only (`ScanSessionNotifier.duplicatePage`, Organizer) | P2 |
| Document metadata | Document Management | FULLY IMPLEMENTED | Yes | Yes | `database_persistence_test.dart`; `phase5_pdf_engine_test.dart` | No | `document_models.dart`; `scaneliq_document_widgets.dart`; `showPdfMetadataSheet` | P3 |
| Document recovery | Document Management | PARTIALLY IMPLEMENTED | Yes | Yes | `organization_and_batch_test.dart` | No | `trash_screen.dart`; `app_database_service.dart:727` (`purgeExpiredTrash` never called) | P2 |
| PDF viewing | PDF Viewer & Editing | UNVERIFIED | Yes | Yes | Test canvas override | No | `document_viewer_screen.dart:1134` (`PdfViewer.file` via `pdfrx`) | P0 |
| Smooth scrolling | PDF Viewer & Editing | UNVERIFIED | Yes | Yes | None live | No | `document_viewer_screen.dart:1139` (`PanAxis.free`) | P1 |
| Pinch-to-zoom | PDF Viewer & Editing | UNVERIFIED | Yes | Yes | UI `+/-` zoom only | No | `document_viewer_screen.dart` (`_pdfController.zoomUp/Down`) | P1 |
| Page navigation | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `document_viewer_screen.dart` (`_jumpToPage`, `_showJumpToPageDialog`) | P3 |
| Thumbnail navigation | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `document_viewer_screen.dart` (`_showThumbnailRail`) | P3 |
| PDF text search | PDF Viewer & Editing | PARTIALLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `document_viewer_screen.dart` (`PdfTextSearcher` + `extractTextByPage` + OCR prompt) | P1 |
| Text selection | PDF Viewer & Editing | UNVERIFIED | Partial | Yes | None | No | `pdfrx` `PdfTextSelectionParams` default `enabled = true`, no custom toolbar callback | P2 |
| Highlight | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `pdf_annotation_studio.dart`; `advanced_pdf_service.dart` (`applyAnnotations`) | P3 |
| Underline | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `pdf_annotation_studio.dart`; `advanced_pdf_service.dart` (`PdfAnnotationType.underline`) | P3 |
| Freehand annotation | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `pdf_annotation_studio.dart`; `advanced_pdf_service.dart` (`PdfAnnotationType.freehand`) | P3 |
| Text notes | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `pdf_annotation_studio.dart`; `advanced_pdf_service.dart` (`PdfAnnotationType.text`) | P3 |
| Shapes | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `pdf_annotation_studio.dart`; `PdfShapeKind` (`rectangle`, `circle`, `arrow`, `line`) | P3 |
| Digital signature | PDF Viewer & Editing | PARTIALLY IMPLEMENTED | Yes | Partial | `phase5_pdf_engine_test.dart` | No | `signature_studio_sheet.dart` (visual PNG overlay only; X.509 PKI MISSING; `pdf_tools_screen._annotatePdf` legacy dialog) | P2 |
| Watermark | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_advanced_pdf_test.dart`; `phase5_pdf_engine_test.dart` | No | `watermark_studio_sheet.dart`; `advanced_pdf_service.dart` (`addWatermark`, runs on main isolate) | P3 |
| Page rotation | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `pdf_page_organizer_screen.dart`; `advanced_pdf_service.dart:382` (`rotatePages`) | P3 |
| Page reordering | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `pdf_page_organizer_screen.dart`; `advanced_pdf_service.dart:336` (`reorderPages`) | P3 |
| Page insertion | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `pdf_page_organizer_screen.dart`; `insertPagesFromPdf` & `insertImageAsPage` | P3 |
| Page deletion (PDF) | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `pdf_page_organizer_screen.dart`; `advanced_pdf_service.dart:443` (`deletePages`) | P3 |
| Page extraction | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `pdf_page_organizer_screen.dart`; `advanced_pdf_service.dart:502` (`extractPages`) | P3 |
| PDF merge | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `advanced_pdf_service_test.dart`; `phase5_pdf_engine_test.dart` | No | `advanced_pdf_service.dart` (`mergePdfs`); `pdf_tools_screen.dart` | P3 |
| PDF split | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `advanced_pdf_service_test.dart`; `phase5_pdf_engine_test.dart` | No | `advanced_pdf_service.dart` (`splitPdfIntoPages`, `splitPdfByRanges`) | P3 |
| PDF compression | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_advanced_pdf_test.dart`; `phase5_pdf_engine_test.dart` | No | `advanced_pdf_service.dart:780` (`compressPdf`, runs on main isolate) | P2 |
| Image-to-PDF | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `pdf_generation_test.dart` | No | `pdf_service.dart` (`generatePdf` via `compute`); `insertImageAsPage` | P3 |
| PDF-to-image | PDF Viewer & Editing | PARTIALLY IMPLEMENTED | Yes | Partial | `edit_recipe_test.dart`; `pdf_generation_test.dart` | No | `document_viewer_screen.dart:758` (exports scanned source images; cannot rasterize arbitrary external PDF via PDFium) | P2 |
| PDF export | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `pdf_generation_test.dart`; `phase5_pdf_engine_test.dart` | No | `advanced_pdf_service.dart` (`_saveDocumentSafely`); `AppStorageService.exportsDir` | P3 |
| PDF sharing | PDF Viewer & Editing | PARTIALLY IMPLEMENTED | Yes | Yes | None hardware | No | `document_viewer_screen.dart:785` (`_shareDocument` via `SharePlus`) | P0 |
| Password protection | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_advanced_pdf_test.dart`; `phase9_release_candidate_test.dart` | No | `advanced_pdf_service.dart` (`encryptPdf` AES-256) | P3 |
| Password-protected PDF opening | PDF Viewer & Editing | PARTIALLY IMPLEMENTED | Yes | Yes | Service verify/unlock tested | No | `document_viewer_screen.dart` (`_promptPassword`); `removePassword` | P1 |
| PDF metadata | PDF Viewer & Editing | FULLY IMPLEMENTED | Yes | Yes | `phase5_pdf_engine_test.dart` | No | `advanced_pdf_service.dart` (`inspectPdf`, `updateMetadata`); `showPdfMetadataSheet` | P3 |
| English OCR | OCR & Intelligence | PARTIALLY IMPLEMENTED | Yes | Yes | Mock/pipeline only | No | `ocr_service.dart` (`TextRecognitionScript.latin`); zero hardware Android run | P0 |
| **Bengali OCR** | OCR & Intelligence | **BROKEN** | Yes | Broken | Unit test for Bangla missing | No | `ocr_service.dart:75-78` maps `OcrScript.bengali` -> `TextRecognitionScript.devanagiri`; `:145` no-op `\r\n` | **P0** |
| Mixed Bengali-English OCR | OCR & Intelligence | MISSING | No | No | None | No | `ocr_service.dart` | P0 |
| Text extraction | OCR & Intelligence | PARTIALLY IMPLEMENTED | Yes | Yes | `extractTextByPage` tested | No | `advanced_pdf_service.dart` (`extractTextByPage`); `ocr_service.dart` | P0 |
| OCR result editing | OCR & Intelligence | PARTIALLY IMPLEMENTED | Partial | Yes | None | No | `receipt_dialog.dart` & `business_card_dialog.dart` edit parsed fields only | P2 |
| Copy extracted text | OCR & Intelligence | FULLY IMPLEMENTED | Yes | Yes | Widget/manual | No | `Clipboard.setData` in `translate_screen.dart`, `ai_document_sheet.dart`, viewer | P3 |
| Export extracted text | OCR & Intelligence | PARTIALLY IMPLEMENTED | Yes | Yes | Unit parser tests | No | CSV (`ReceiptParserService`) & vCard (`BusinessCardService`), no plain `.txt` / `.docx` export | P2 |
| Searchable PDF | OCR & Intelligence | PARTIALLY IMPLEMENTED | Yes | Partial | `pdf_generation_test.dart` | No | `pdf_service.dart:123,200-230` (strips `>255` non-Latin1 chars such as Bengali to spaces) | P1 |
| OCR-based document search | OCR & Intelligence | PARTIALLY IMPLEMENTED | Yes | Partial | `database_persistence_test.dart` | No | `app_database_service.dart:871` (`document_ocr LIKE '%term%'`, no FTS5) | P1 |
| Table extraction | OCR & Intelligence | MISSING | No | No | None | No | `tools_screen.dart:414` (`PDF to Word / Excel Conversion` marked `UNAVAILABLE`) | P2 |
| Receipt data extraction | OCR & Intelligence | PARTIALLY IMPLEMENTED | Yes | Yes | `phase10` / service tests | No | `receipt_parser_service.dart`; `receipt_dialog.dart` | P2 |
| Invoice data extraction | OCR & Intelligence | PARTIALLY IMPLEMENTED | Yes | Yes | Shared receipt tests | No | `receipt_parser_service.dart:75,135` (shared regex parser; no PO#/line-tax/invoice fields) | P2 |
| Business card extraction | OCR & Intelligence | PARTIALLY IMPLEMENTED | Yes | Yes | `phase10_camscanner_features_test.dart` | No | `business_card_service.dart`; `business_card_dialog.dart` | P2 |
| Handwriting recognition | OCR & Intelligence | MISSING | No | No | None | No | No handwriting OCR engine | P3 |
| Text translation | Translation | PARTIALLY IMPLEMENTED | Yes | Online API | None live | No | `translate_screen.dart:19,135` (`GoogleTranslator` online with consent dialog) | P2 |
| Document translation | Translation | PARTIALLY IMPLEMENTED | Partial | Online API | None | No | `translate_screen.dart:62` (single image Latin OCR + paste only; no multi-page PDF translation) | P2 |
| Bengali-English translation | Translation | PARTIALLY IMPLEMENTED | Yes | Online API | None | No | `translate_screen.dart:33` (online works; camera/image Bn->En OCR broken) | P1 |
| English-Bengali translation | Translation | PARTIALLY IMPLEMENTED | Yes | Online API | None | No | `translate_screen.dart:25` (online `GoogleTranslator` HTTP only) | P2 |
| Multiple language support | Translation | PARTIALLY IMPLEMENTED | Yes | Online API | None | No | `translate_screen.dart:30-40` (7 target langs + auto) | P3 |
| Offline translation | Translation | MISSING | No | No | None | No | Zero ML Kit On-Device Translation integration | P2 |
| Translation export | Translation | PARTIALLY IMPLEMENTED | Partial | Yes | None | No | `translate_screen.dart:328-352` (`Clipboard` + `SharePlus`; no PDF/TXT export) | P3 |
| Document summarization | AI Document Assistant | PARTIALLY IMPLEMENTED | Yes | Heuristic | `phase10_camscanner_features_test.dart` | No | `ai_document_service.dart:196` (raw TF + lead boost; mislabeled TextRank; no LLM) | P2 |
| Ask questions about documents | AI Document Assistant | PARTIALLY IMPLEMENTED | Yes | Heuristic | `phase10_camscanner_features_test.dart` | No | `ai_document_service.dart:265` (raw TF cosine word overlap) | P2 |
| Extract key information | AI Document Assistant | PARTIALLY IMPLEMENTED | Yes | Heuristic | Unit test | No | `ai_document_service.dart:220` (`topKeywords` top 6 words) | P2 |
| Explain document contents | AI Document Assistant | MISSING | No | No | None | No | No explanatory/generative AI | P2 |
| Identify important dates | AI Document Assistant | MISSING | No | No | None | No | Absent in `AiDocumentService` (single date regex in `ReceiptParserService` only) | P2 |
| Identify names and amounts | AI Document Assistant | MISSING | No | No | None | No | Absent in `AiDocumentService` (`BusinessCardService`/`ReceiptParserService` only) | P2 |
| Structured information extraction | AI Document Assistant | PARTIALLY IMPLEMENTED | Yes | Heuristic | Unit test | No | Receipt CSV & Business Card vCard only; no general schema extractor | P2 |
| AI-assisted document search | AI Document Assistant | MISSING | No | No | None | No | Vault uses SQL `LIKE` only; zero embeddings/semantic search | P2 |
| Document-based question answering | AI Document Assistant | PARTIALLY IMPLEMENTED | Yes | Heuristic | `phase10_camscanner_features_test.dart` | No | `ai_document_sheet.dart:260`; `ai_document_service.dart:265` | P2 |
| Receipt scanner | Productivity Tools | PARTIALLY IMPLEMENTED | Yes | Heuristic | `phase10` / unit tests | No | `receipt_dialog.dart`; `receipt_parser_service.dart` | P2 |
| Invoice scanner | Productivity Tools | PARTIALLY IMPLEMENTED | Yes | Heuristic | Shared receipt tests | No | Aliases `ReceiptDialog` & `ReceiptParserService` | P2 |
| Business card scanner | Productivity Tools | PARTIALLY IMPLEMENTED | Yes | Heuristic | `phase10_camscanner_features_test.dart` | No | `business_card_dialog.dart`; `business_card_service.dart` | P2 |
| **CountCam** | Productivity Tools | **BROKEN** | Yes | Wrong impl | `phase10` UI/flow | No | `count_cam_screen.dart:116-135` (`TextRecognizer` Latin `blocks.length`, not objects; decorative dropdown) | **P1** |
| ID card scanning | Productivity Tools | FULLY IMPLEMENTED | Yes | Yes | `phase2_audit_and_repair_test.dart`; `pdf_generation_test.dart` | No | `ScanMode.idCard`; `PdfService.stitchIdCard2In1` | P3 |
| Batch scanning | Productivity Tools | PARTIALLY IMPLEMENTED | Yes | Yes | `batch_scanning_test.dart`; `phase3_scanner_camera_test.dart` | No | `ScanSessionNotifier`; `ContinuousCameraScreen` | P1 |
| Book scanning | Productivity Tools | FULLY IMPLEMENTED | Yes | Yes | `phase2_audit_and_repair_test.dart`; `image_processing_test.dart` | No | `ScanMode.book`; `splitBookSpreadFile` (main isolate) | P2 |
| Long document scanning | Productivity Tools | FULLY IMPLEMENTED | Yes | Yes | `image_processing_test.dart` | No | `pdf_tools_screen.dart` (`_stitchLongImage`); `stitchImageFilesVertically` (main isolate) | P2 |
| QR/barcode recognition | Productivity Tools | UNVERIFIED | Yes | Yes | None | No | `scan_code_screen.dart` (`mobile_scanner`) | P1 |
| Document templates | Productivity Tools | MISSING | No | No | None | No | `smart_filename_service.dart` filename patterns only | P3 |
| **App lock** | Security & Privacy | **BROKEN** | Yes | Partial | Isolated service test | No | `main.dart` omits `AppLockService.instance.init()`; `app_lock_service.dart:62` returns `false` on cold launch | **P0** |
| PIN authentication | Security & Privacy | PARTIALLY IMPLEMENTED | Yes | Yes | `phase8` & `phase9` tests | No | `app_lock_service.dart` (PBKDF2-100k, constant-time, lockout); stored in plain `SharedPreferences` + cold-start bug | P0 |
| Biometric authentication | Security & Privacy | UNVERIFIED | Yes | Yes | None hardware | No | `local_auth`; `USE_BIOMETRIC`; `FlutterFragmentActivity` (hardware untested + cold-start bug) | P0 |
| Secure storage | Security & Privacy | PARTIALLY IMPLEMENTED | No | Partial | `storage_service_test.dart` | No | App sandbox + `allowBackup=false`; missing `flutter_secure_storage` / Android KeyStore | P1 |
| Document encryption | Security & Privacy | PARTIALLY IMPLEMENTED | Partial | Partial | `phase9_release_candidate_test.dart` | No | `encryptPdf` AES-256 export; `scaneliq.db` & `originals/` plaintext at rest | P1 |
| Encrypted backups | Security & Privacy | PARTIALLY IMPLEMENTED | Partial | Yes | `phase8` & `phase9` tests | No | `CloudBackupService` V2 AES-CBC-EtM tested; `settings_screen.dart:121` calls without password prompt | P1 |
| Secure export | Security & Privacy | PARTIALLY IMPLEMENTED | Yes | Yes | `phase5` & `phase9` tests | No | `encryptPdf` available via tool; normal shares unencrypted | P2 |
| Session protection | Security & Privacy | PARTIALLY IMPLEMENTED | Yes | Partial | Unit timeout test | No | `main_navigation_shell.dart:73-93`; broken on cold launch until Settings initializes `AppLockService` | P0 |
| Privacy controls | Security & Privacy | PARTIALLY IMPLEMENTED | Yes | Partial | Manifest/dialog checks | No | `allowBackup=false`, `usesCleartextTraffic=false`; no `FLAG_SECURE`, no raster redaction UI | P1 |
| Screenshot protection | Security & Privacy | MISSING | No | No | None | No | `MainActivity.kt` lacks `FLAG_SECURE` | P1 |
| Sensitive document handling | Security & Privacy | PARTIALLY IMPLEMENTED | Partial | Yes | `phase9_release_candidate_test.dart` | No | `applyRedaction` visual mask; `permanentlyRedactImage` pixel zeroing **BACKEND ONLY** | P1 |
| Authentication lifecycle | Security & Privacy | PARTIALLY IMPLEMENTED | Yes | Partial | Unit test | No | `main_navigation_shell.dart`; bypassed on cold start | P0 |
| Data deletion | Security & Privacy | PARTIALLY IMPLEMENTED | Yes | Yes | `database_persistence_test.dart` | No | `permanentlyDelete` cleans disk + DB; `purgeExpiredTrash` uncalled | P2 |
| Local backup | Backup & Sync | FULLY IMPLEMENTED | Yes | Yes | `phase8` & `phase9` tests | No | `cloud_backup_service.dart` (`createBackupArchive`); `settings_screen.dart:118` | P3 |
| Restore | Backup & Sync | FULLY IMPLEMENTED | Yes | Yes | `phase8` & `phase9` tests | No | `cloud_backup_service.dart` (`restoreBackupArchive`) | P3 |
| Encrypted backup (Sync module) | Backup & Sync | PARTIALLY IMPLEMENTED | Partial | Yes | `phase8` & `phase9` tests | No | `CloudBackupService` V2 tested; Settings UI skips passphrase input | P1 |
| Google Drive integration | Backup & Sync | MISSING | No | No | None | No | Zero Drive SDK / OAuth in codebase | P1 |
| Dropbox integration | Backup & Sync | MISSING | No | No | None | No | Zero Dropbox SDK | P2 |
| OneDrive integration | Backup & Sync | MISSING | No | No | None | No | Zero Microsoft Graph SDK | P2 |
| WebDAV integration | Backup & Sync | MISSING | No | No | None | No | Zero HTTP/WebDAV client | P2 |
| Multi-device synchronization | Backup & Sync | PLANNED | Disabled row | Local envelope only | `phase6` envelope test | No | `tools_screen.dart:425` (`PLANNED`); `device_sync_service.dart` (local JSON metadata envelope only, XOR cipher) | P1 |
| Conflict resolution | Backup & Sync | BACKEND ONLY | No | Partial | `phase6` sync test | No | `device_sync_service.dart:272` (`processIncomingEnvelope` LWW on `modified_at` metadata only) | P2 |
| Offline synchronization queue | Backup & Sync | MISSING | No | No | None | No | Zero sync outbox or `workmanager` | P1 |
| Backup scheduling | Backup & Sync | MISSING | No | No | None | No | Manual export only | P2 |
| Backup recovery | Backup & Sync | FULLY IMPLEMENTED | Yes | Yes | `phase8` & `phase9` tests | No | `cloud_backup_service.dart:300` (`restoreBackupArchive` atomic checks) | P3 |
| Free plan | Subscription & Premium | MISSING | No | No | None | No | No tier/plan architecture in `lib/` | P1 |
| Premium plan | Subscription & Premium | MISSING | No | No | None | No | No SKU definitions | P1 |
| Subscription management | Subscription & Premium | MISSING | No | No | None | No | No account/subscription settings | P2 |
| Purchase integration | Subscription & Premium | MISSING | No | No | None | No | Zero `in_app_purchase` / RevenueCat in `pubspec.yaml` | P1 |
| Restore purchases | Subscription & Premium | MISSING | No | No | None | No | Zero billing restore | P1 |
| Premium feature gating | Subscription & Premium | MISSING | No | No | None | No | All local features open | P1 |
| Usage limits | Subscription & Premium | MISSING | No | No | None | No | Zero quota tracking | P2 |
| Subscription status | Subscription & Premium | MISSING | No | No | None | No | No entitlement state | P1 |
| Payment verification | Subscription & Premium | MISSING | No | No | None | No | No receipt validation | P1 |
| Subscription expiration | Subscription & Premium | MISSING | No | No | None | No | No expiry/grace logic | P1 |
| Entitlement management | Subscription & Premium | MISSING | No | No | None | No | Zero entitlement repository | P1 |
