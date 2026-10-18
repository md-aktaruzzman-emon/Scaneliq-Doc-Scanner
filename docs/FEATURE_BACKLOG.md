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
| **F-01** | **Camera Edge & Batch Scanner** | Google ML Kit document scanner with auto/manual edge detection & multi-page capture | P0 | A/B | **IMPLEMENTED** | `lib/features/scanner/presentation/scan_session_provider.dart` | Blocked on physical camera hardware; APK bundled & badging verified |
| **F-02** | **Multi-Image & File Picker** | Multi-file import (JPG, PNG, WebP) with atomic copy to `originals/` | P0 | A/B | **TESTED** | `lib/core/storage/app_storage_service.dart` | `test/storage_service_test.dart` |
| **F-03** | **Draft Session Recovery** | Persistent recovery of unfinished scan sessions with Home banner | P0 | A/B | **TESTED** | `lib/features/documents/data/app_database_service.dart` | `test/database_persistence_test.dart` |
| **F-04** | **Non-Destructive Page Editor** | Rotation (90° steps), Grayscale, B&W high-contrast, Brightness/Contrast recipes | P0 | B | **TESTED** | `lib/core/models/document_models.dart`, `lib/features/editor/presentation/edit_page_screen.dart` | `test/edit_recipe_test.dart` |
| **F-05** | **Page Organizer & Reordering** | Drag-and-drop page reordering, page deletion, retake page | P0 | B | **TESTED** | `lib/features/editor/presentation/review_pages_screen.dart` | `test/database_persistence_test.dart` |
| **F-06** | **PDF Generation & A4 Formatting** | Multi-page PDF creation with JPEG compression, atomic tmp export & magic header check | P0 | A/E | **TESTED** | `lib/features/pdf/data/pdf_service.dart` | `test/pdf_generation_test.dart` |
| **F-07** | **In-App PDF Viewer** | Smooth PDF viewing with PDFium engine via pdfrx | P0 | A/E | **IMPLEMENTED** | `lib/features/documents/presentation/document_viewer_screen.dart` | Packaged in arm64/universal release APKs |
| **F-08** | **Single Page JPEG Export & Share** | Export individual processed page as JPEG with SOI validation & system share sheet | P0 | A/E | **TESTED** | `lib/features/pdf/data/pdf_service.dart`, `lib/features/documents/presentation/document_viewer_screen.dart` | `test/edit_recipe_test.dart` |
| **F-09** | **Document Library & Search** | Real-time title search, sorting (Newest, Oldest, A-Z, Z-A), Favorites toggle | P0 | C | **TESTED** | `lib/features/documents/presentation/documents_library_screen.dart` | `test/database_persistence_test.dart` |
| **F-10** | **On-Device Image OCR** | Extract selectable text from scans & external images using ML Kit Latin recognizer | P0 | D | **IMPLEMENTED** | `lib/features/ocr/data/ocr_service.dart`, `lib/features/settings/presentation/tools_screen.dart` | Packaged in APK; tested on engine level |
| **F-11** | **PDF Merge (Combine Documents)** | Merge two or more existing PDF files into a single consolidated PDF document | P0 | E | **IN PROGRESS** | `lib/features/pdf/data/advanced_pdf_service.dart`, `lib/features/pdf/presentation/pdf_tools_screen.dart` | Unit & integration tests pending |
| **F-12** | **PDF Split & Page Extraction** | Split multi-page PDF into single pages or extract specific page ranges | P0 | E | **IN PROGRESS** | `lib/features/pdf/data/advanced_pdf_service.dart` | Unit & integration tests pending |
| **F-13** | **PDF Password Protection & Encryption** | Encrypt PDF files with 128-bit/256-bit user passwords & permissions | P0 | E | **IN PROGRESS** | `lib/features/pdf/data/advanced_pdf_service.dart` | Unit & integration tests pending |
| **F-14** | **PDF Watermarking & Page Numbering** | Add text/confidential watermarks & standard page numbers across all pages | P1 | E | **NOT STARTED** | `lib/features/pdf/data/advanced_pdf_service.dart` | To be scheduled |
| **F-15** | **OCR Full-Text Database Indexing** | Store page OCR text in SQLite with full-text search capability | P1 | D | **NOT STARTED** | `lib/features/documents/data/app_database_service.dart` | To be scheduled |
| **F-16** | **Searchable PDF Creation** | Generate PDFs with invisible OCR text layer matching scanned image coordinates | P1 | D/E | **NOT STARTED** | `lib/features/pdf/data/pdf_service.dart` | To be scheduled |
| **F-17** | **Receipt & Invoice Extraction** | Deterministic extraction of Merchant, Date, Total, Tax, and Currency | P1 | F | **NOT STARTED** | `lib/features/extraction/data/extraction_service.dart` | To be scheduled |
| **F-18** | **Business Card Contact Extraction** | Extract Name, Phone, Email, Company with one-tap contact creation | P1 | F | **NOT STARTED** | `lib/features/extraction/data/business_card_service.dart` | To be scheduled |
| **F-19** | **Folders & Tags Organization** | Document organization via custom folders, tags, and category filters | P1 | C | **NOT STARTED** | `lib/features/documents/data/app_database_service.dart` | To be scheduled |
| **F-20** | **Recycle Bin / Trash Recovery** | Soft-delete with 30-day trash bin and permanent wipe protection | P1 | C | **NOT STARTED** | `lib/features/documents/data/app_database_service.dart` | To be scheduled |
| **F-21** | **AI Document Assistant** | Document summarization, key points, Q&A, and translation with explicit consent | P2 | G | **NOT STARTED** | `lib/features/ai_assistant/` | Requires user API configuration |
| **F-22** | **Cloud Backup & Sync** | Optional account sync to Supabase/Google Drive with conflict resolution | P2 | H | **NOT STARTED** | `lib/features/cloud_sync/` | Requires backend project credentials |
| **F-23** | **One-Tap Workflow Automation** | Configurable one-tap macros (e.g. Scan -> B&W -> Encrypt PDF -> Share) | P2 | I | **NOT STARTED** | `lib/features/automation/` | To be scheduled |
