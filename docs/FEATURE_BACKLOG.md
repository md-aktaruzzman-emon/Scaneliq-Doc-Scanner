# Scaneliq — Master Feature Backlog & Traceability Matrix

**Blueprint Source:** [Scaneliq_Master_Blueprint_Improved.md](file:///c:/Scaneliq/docs/Scaneliq_Master_Blueprint_Improved.md)  
**Last Updated:** 2026-10-19  
**Status Legend:**
- `NOT STARTED`: Requirement defined, awaiting scheduled phase.
- `IN PROGRESS`: Actively being engineered.
- `IMPLEMENTED`: Code and workflows complete and connected.
- `TESTED`: Verified via unit, widget, integration, or build test suites.
- `BLOCKED`: Awaiting hardware (physical Android camera) or user-supplied credentials.

---

## Complete Feature Matrix

| ID | Feature Name | Description | Priority | Phase | Status | Primary Source Files | Verification Tests |
|---|---|---|:---:|:---:|:---:|---|---|
| **F-00** | **Design System & Navigation Overhaul** | Centralized semantic tokens (`surface0–3`, `#021642`, `#2563EB`, `#00F0FF`), 4-tab shell with elevated shutter, modern Home, Files, Tools, and Settings screens | P0 | 1 | **TESTED** | `lib/core/theme/app_theme.dart`, `lib/app/main_navigation_shell.dart`, `lib/features/documents/presentation/home_screen.dart`, `lib/features/documents/presentation/documents_library_screen.dart`, `lib/features/settings/presentation/tools_screen.dart`, `lib/features/settings/presentation/settings_screen.dart` | `test/navigation_and_screens_test.dart`, `test/widget_test.dart` |
| **F-01** | **Camera Edge & Batch Scanner** | Google ML Kit document scanner with auto/manual edge detection & multi-page capture | P0 | A/B | **IMPLEMENTED** | `lib/features/scanner/presentation/scan_session_provider.dart` | Blocked on physical camera hardware; APK bundled & badging verified |
| **F-02** | **Multi-Image & File Picker** | Multi-file import (JPG, PNG, WebP) with atomic copy to `originals/` | P0 | A/B | **TESTED** | `lib/core/storage/app_storage_service.dart` | `test/storage_service_test.dart` |
| **F-03** | **Draft Session Recovery** | Persistent recovery of unfinished scan sessions with Home banner | P0 | A/B | **TESTED** | `lib/features/documents/data/app_database_service.dart` | `test/database_persistence_test.dart` |
| **F-04** | **Non-Destructive Page Editor** | Rotation (90° steps), Grayscale, B&W high-contrast, Whiteboard & Text+ filters, Brightness/Contrast | P0 | B | **TESTED** | `lib/core/models/document_models.dart`, `lib/features/editor/presentation/edit_page_screen.dart` | `test/edit_recipe_test.dart`, `test/batch_scanning_test.dart` |
| **F-05** | **Page Organizer & Reordering** | Drag-and-drop page reordering, page deletion, retake page | P0 | B | **TESTED** | `lib/features/editor/presentation/review_pages_screen.dart` | `test/database_persistence_test.dart`, `test/batch_scanning_test.dart` |
| **F-06** | **PDF Generation & A4 Formatting** | Multi-page PDF creation with JPEG compression, atomic tmp export & magic header check | P0 | A/E | **TESTED** | `lib/features/pdf/data/pdf_service.dart` | `test/pdf_generation_test.dart`, `test/batch_scanning_test.dart` |
| **F-07** | **In-App PDF Viewer** | Smooth PDF viewing with PDFium engine via pdfrx | P0 | A/E | **IMPLEMENTED** | `lib/features/documents/presentation/document_viewer_screen.dart` | Packaged in arm64/universal release APKs |
| **F-08** | **Single & Batch JPEG Export & Share** | Export individual page or all pages as JPEG with SOI validation & system share sheet | P0 | A/E | **TESTED** | `lib/features/pdf/data/pdf_service.dart`, `lib/features/editor/presentation/review_pages_screen.dart` | `test/edit_recipe_test.dart`, `test/batch_scanning_test.dart` |
| **F-09** | **Document Library & Search** | Real-time title search, sorting (Newest, Oldest, A-Z, Z-A), Favorites toggle | P0 | C | **TESTED** | `lib/features/documents/presentation/documents_library_screen.dart` | `test/database_persistence_test.dart` |
| **F-10** | **On-Device Image OCR** | Extract selectable text from scans & external images using ML Kit Latin recognizer | P0 | D | **IMPLEMENTED** | `lib/features/ocr/data/ocr_service.dart`, `lib/features/settings/presentation/tools_screen.dart` | Packaged in APK; tested on engine level |
| **F-11** | **PDF Merge (Combine Documents)** | Merge two or more existing PDF files into a single consolidated PDF document | P0 | E | **TESTED** | `lib/features/pdf/data/advanced_pdf_service.dart`, `lib/features/pdf/presentation/pdf_tools_screen.dart` | `test/advanced_pdf_service_test.dart` |
| **F-12** | **PDF Split & Page Extraction** | Split multi-page PDF into single pages or extract specific page ranges | P0 | E | **TESTED** | `lib/features/pdf/data/advanced_pdf_service.dart`, `lib/features/pdf/presentation/pdf_tools_screen.dart` | `test/advanced_pdf_service_test.dart` |
| **F-13** | **PDF Password Protection & Encryption** | Encrypt PDF files with 128-bit/256-bit user passwords & permissions | P0 | E | **TESTED** | `lib/features/pdf/data/advanced_pdf_service.dart`, `lib/features/pdf/presentation/pdf_tools_screen.dart` | `test/advanced_pdf_service_test.dart` |
| **F-14** | **PDF Watermarking & Page Numbering** | Add text/confidential watermarks across all pages | P1 | E | **TESTED** | `lib/features/pdf/data/advanced_pdf_service.dart`, `lib/features/pdf/presentation/pdf_tools_screen.dart` | `test/advanced_pdf_service_test.dart` |
| **F-15** | **Continuous Batch Camera Mode** | In-app CameraX continuous viewfinder, live shutter, live thumbnail & badge counter | P0 | B | **TESTED** | `lib/features/scanner/presentation/continuous_camera_screen.dart` | `test/batch_scanning_test.dart` |
| **F-16** | **ID Card Scanner Mode** | Front & back card capture with guidance frame overlay | P0 | B | **IMPLEMENTED** | `lib/features/scanner/presentation/continuous_camera_screen.dart` | Viewfinder guide & sub-step verified |
| **F-17** | **Question Set Scanner Mode** | Continuous multi-page exam/assignment scanner with sequential order | P0 | B | **TESTED** | `lib/features/scanner/presentation/continuous_camera_screen.dart` | `test/batch_scanning_test.dart` |
| **F-18** | **Book Scanner Mode** | Textbook & reading material capture mode preserving page sequence | P0 | B | **TESTED** | `lib/features/scanner/presentation/continuous_camera_screen.dart` | `test/batch_scanning_test.dart` |
| **F-19** | **Whiteboard Scanner Mode** | Presentation & board scanner with vivid color preservation & background whitening filter | P0 | B | **TESTED** | `lib/features/scanner/presentation/continuous_camera_screen.dart` | `test/batch_scanning_test.dart` |
| **F-20** | **Scan Code (QR & Barcodes)** | Real-time barcode & QR scanner with copy, share, flash & safe URL previews | P0 | B | **IMPLEMENTED** | `lib/features/scanner/presentation/scan_code_screen.dart` | Packaged & mobile_scanner verified |
| **F-21** | **CountCam (Object Counter)** | Camera/gallery object counter with categories, detection boxes & manual adjustment | P0 | B | **IMPLEMENTED** | `lib/features/scanner/presentation/count_cam_screen.dart` | Detection & adjustment verified |
| **F-22** | **Translate (Document Translation)** | Extract OCR text and translate into Bengali, English, and other languages | P0 | D | **IMPLEMENTED** | `lib/features/scanner/presentation/translate_screen.dart` | Translation engine integrated |
| **F-23** | **Cloud Backup & Sync** | Optional account sync to Supabase/Google Drive with conflict resolution | P2 | H | **NOT STARTED** | `lib/features/cloud_sync/` | Requires backend project credentials |
