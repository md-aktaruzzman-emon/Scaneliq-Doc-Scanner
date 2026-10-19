# Scaneliq — Master Feature Traceability Matrix

**Document Version:** 2.0.0  
**Last Updated:** October 19, 2026  
**Status Legend:**
- `TESTED`: Implemented and verified via automated test suites (unit, widget, integration, or build packaging).
- `IMPLEMENTED`: Complete in code and connected to workflows; awaiting physical hardware check.
- `PLANNED`: Fully specified in Master Blueprint; scheduled for future roadmap phase.
- `BLOCKED`: Awaiting external hardware (e.g., physical camera sensor) or cloud credentials.
- `NOT PLANNED`: Deliberately excluded (e.g., invasive telemetry, watermarked free tiers).

---

## Complete Feature Traceability Matrix

| ID | Feature Name & Description | Competitor Precedent | Category | Priority | Target Phase | Implementation Status | Technical Dependencies & Primary Files |
|---|---|---|:---:|:---:|:---:|:---:|---|
| **F-01** | **Automatic Document Boundary Detection**<br>Real-time blue/cyan quadrilateral edge locking and auto-snapping | Adobe Scan, Google Drive, Genius Scan, SwiftScan, OneDrive, CamScanner | A | P0 | Phase 2 | **TESTED** | `google_mlkit_document_scanner`<br>`scan_session_provider.dart` |
| **F-02** | **Manual Shutter & Corner Adjustment Fallback**<br>Interactive 4-point corner drag with loupe magnification | All 6 Reference Apps | A | P0 | Phase 2 | **TESTED** | Custom touch handles<br>`edit_page_screen.dart` |
| **F-03** | **Continuous Multi-Page Batch Scanning**<br>Uninterrupted viewfinder capture with live counter and page accumulation | All 6 Reference Apps | A | P0 | Phase 2 | **TESTED** | `camera` (CameraX)<br>`continuous_camera_screen.dart` |
| **F-04** | **Draft Session Persistence & Crash Recovery**<br>Automatic background saving of unfinished scans with Home resumption banner | Genius Scan, Google Drive | A/E | P0 | Phase 2 | **TESTED** | SQLite `is_draft` flag<br>`app_database_service.dart` |
| **F-05** | **Multi-Image & External File Picker Import**<br>Import JPG, PNG, WebP files from gallery with atomic copy to `originals/` | All 6 Reference Apps | A | P0 | Phase 2 | **TESTED** | `file_picker`, `path_provider`<br>`app_storage_service.dart` |
| **F-06** | **ID Card 2-in-1 Sheet Stitching**<br>Front & Back card capture composited onto standard 200 DPI A4 page with borders | CamScanner, Adobe Scan | A/C | P0 | Phase 3 | **TESTED** | Pure Dart `image` package<br>`continuous_camera_screen.dart` |
| **F-07** | **Book Dual-Page Scan & Curvature Flattening**<br>Captures book spreads and flattens curved text lines | CamScanner, Adobe Scan | A/B | P2 | Phase 3 | **IMPLEMENTED** | `continuous_camera_screen.dart`<br>Algorithm: OpenCV / Dart Image |
| **F-08** | **Whiteboard Mode with Glare Removal**<br>High-contrast background whitening preserving vivid dry-erase markers | MS OneDrive, CamScanner | A/B | P0 | Phase 3 | **TESTED** | High-pass color thresholding<br>`app_storage_service.dart` |
| **F-09** | **Question Set / Exam Paper Mode**<br>Multi-page sequential capture optimized for black-and-white print tests | CamScanner | A | P1 | Phase 3 | **TESTED** | `continuous_camera_screen.dart`<br>`test/batch_scanning_test.dart` |
| **F-10** | **QR Code & Barcode Scanner**<br>Real-time code detection with copy, share, flash, and safe URL previews | SwiftScan, CamScanner | A | P0 | Phase 3 | **IMPLEMENTED** | `mobile_scanner`<br>`scan_code_screen.dart` |
| **F-11** | **CountCam (Object Counter)**<br>Camera/gallery counter with category bounding boxes and manual tap adjustment | CamScanner | A | P2 | Phase 8 | **IMPLEMENTED** | `count_cam_screen.dart`<br>ML Kit / Computer Vision |
| **F-12** | **Non-Destructive Image Edit Recipes**<br>Preserves pristine source in `originals/`; edits stored as JSON recipes | Genius Scan, Adobe Scan | B | P0 | Phase 3 | **TESTED** | `document_models.dart`<br>`test/storage_service_test.dart` |
| **F-13** | **Clean Black & White Document Filter**<br>Adaptive binarization eliminating paper shadows while keeping text crisp | All 6 Reference Apps | B | P0 | Phase 3 | **TESTED** | Pure Dart `image`<br>`app_storage_service.dart` |
| **F-14** | **Grayscale & Color Enhancement Presets**<br>Smooth 256-level grayscale and vibrant "Magic Color" contrast enhancement | All 6 Reference Apps | B | P0 | Phase 3 | **TESTED** | `app_storage_service.dart`<br>`edit_page_screen.dart` |
| **F-15** | **Brightness & Contrast Slider Adjustment**<br>Fine-tune luminance (-0.5 to +0.5) and dynamic range (0.5x to 2.0x) | Genius Scan, SwiftScan, CamScanner | B | P0 | Phase 3 | **TESTED** | `edit_recipe_test.dart`<br>`edit_page_screen.dart` |
| **F-16** | **Finger & Stray Shadow Eraser**<br>Touch brush tool to paint over and remove fingers or hole punches | Google Drive, Adobe Scan, CamScanner | B | P2 | Phase 3 | **TESTED** | `ImageProcessingService.applyCleanupPatches`<br>`test/image_processing_test.dart` |
| **F-17** | **Multi-Page A4 PDF Generation**<br>Standardized A4 compilation with JPEG compression and `%PDF-` validation | All 6 Reference Apps | C | P0 | Phase 5 | **TESTED** | `pdf` (Dart)<br>`pdf_service.dart` |
| **F-18** | **High-Definition (HD) Quality Presets**<br>Compact (150 DPI), Standard (200 DPI), High (300 DPI) export choices | Genius Scan, SwiftScan, CamScanner | C | P0 | Phase 5 | **TESTED** | `pdf_service.dart`<br>`review_pages_screen.dart` |
| **F-19** | **Unwatermarked Free PDF & JPEG Export**<br>Clean exports with zero forced promotional watermarks or branding | Genius Scan, Google Drive, Adobe Scan | C | P0 | Phase 5 | **TESTED** | Core Brand Commitment<br>`pdf_service.dart` |
| **F-20** | **Single-Page & Batch JPEG Export**<br>Export individual pages or all pages as discrete JPEGs (`0xFFD8FF` verified) | Genius Scan, CamScanner, Adobe Scan | C | P0 | Phase 5 | **TESTED** | `pdf_service.dart`<br>`review_pages_screen.dart` |
| **F-21** | **High-Performance In-App PDF Viewer**<br>Smooth multi-page PDF rendering powered by Google PDFium C++ engine | Adobe Acrobat, SwiftScan | C | P0 | Phase 5 | **IMPLEMENTED** | `pdfrx` (PDFium)<br>`document_viewer_screen.dart` |
| **F-22** | **PDF Merge (Combine Documents)**<br>Combine two or more separate PDF files into a single unified document | Adobe Acrobat Pro, Genius Ultra, CamScanner Pro | C | P0 | Phase 5 | **TESTED** | `syncfusion_flutter_pdf`<br>`advanced_pdf_service.dart` |
| **F-23** | **PDF Split & Page Extraction**<br>Split multi-page PDF into single pages or extract custom page ranges | Adobe Acrobat Pro, Genius Ultra, CamScanner Pro | C | P0 | Phase 5 | **TESTED** | `syncfusion_flutter_pdf`<br>`advanced_pdf_service.dart` |
| **F-24** | **PDF Password Protection & AES-256 Encryption**<br>Encrypt PDFs with user/owner passwords and customizable permissions | Adobe Acrobat, Genius Ultra, SwiftScan, CamScanner | C | P0 | Phase 5 | **TESTED** | `syncfusion_flutter_pdf`<br>`advanced_pdf_service.dart` |
| **F-25** | **Custom Text Watermarking**<br>Stamp semi-transparent diagonal watermarks across all document pages | CamScanner Pro, Adobe Acrobat Pro | C | P1 | Phase 5 | **TESTED** | `syncfusion_flutter_pdf`<br>`advanced_pdf_service.dart` |
| **F-26** | **PDF Interactive Annotations & Signatures**<br>Add pen signatures, text stamps, notes, and colored highlights | Adobe Acrobat, SwiftScan, OneDrive | C | P2 | Phase 7 | **PLANNED** | Custom painter / Syncfusion PDF |
| **F-27** | **True Content Redaction**<br>Permanently sanitizes and removes underlying text/image bytes | Adobe Acrobat Pro | C | P2 | Phase 7 | **PLANNED** | Syncfusion PDF Redaction Engine |
| **F-28** | **On-Device Optical Character Recognition (OCR)**<br>Extract selectable plain text from scanned pages using on-device ML | Adobe Scan, Genius Ultra, SwiftScan VIP, CamScanner | D | P1 | Phase 6 | **TESTED** | `google_mlkit_text_recognition`<br>`ocr_service.dart` |
| **F-29** | **Searchable PDF Generation (Invisible Text Layer)**<br>Injects invisible OCR text layer matching word bounding boxes | Adobe Scan, Google Drive, Genius Ultra, SwiftScan | D | P1 | Phase 6 | **TESTED** | `pdf_service.dart`<br>`test/pdf_generation_test.dart` |
| **F-30** | **Full-Text Document Library Search**<br>Live search across all scanned pages using SQLite full-text index | Google Drive, OneDrive, Genius Ultra, SwiftScan | D | P1 | Phase 6 | **TESTED** | SQLite `document_ocr` table<br>`app_database_service.dart` |
| **F-31** | **Bangla / Indic Script OCR Integration**<br>Recognize Bengali text using Tesseract / on-device trained language models | CamScanner (Cloud) | D | P2 | Phase 6 | **PLANNED** | Tesseract `ben.traineddata` / Google ML Kit Script |
| **F-32** | **Document Translation (Bengali ↔ English)**<br>Translate recognized OCR text into Bengali, English, and other languages | SwiftScan VIP, CamScanner Pro | D | P1 | Phase 6 | **TESTED** | `translate_screen.dart`<br>`translator` / On-device ML |
| **F-33** | **Business Card Contact Extraction**<br>Extracts Name, Phone, Email, Company; saves to device Contacts | Adobe Scan, OneDrive, Genius Ultra | D | P2 | Phase 8 | **PLANNED** | ML Kit Entity Extraction / Regex |
| **F-34** | **Receipt & Invoice Key-Value Extraction**<br>Automatically parses Merchant, Date, Tax, Total, and Line Items | CamScanner Pro, Genius Ultra | D | P2 | Phase 8 | **PLANNED** | On-device structured NER / Regex |
| **F-35** | **AI Document Summary & Q&A Assistant**<br>Conversational document assistant providing summaries and citations | Adobe Acrobat Studio, SwiftScan VIP | D/H | P3 | Phase 10 | **PLANNED** | LLM API (Gemini/Claude) with consent |
| **F-36** | **Nested Folders & Subfolders Organization**<br>Create hierarchical folder trees to organize documents | Google Drive, CamScanner, Genius Scan | E | P1 | Phase 4 | **PLANNED** | SQLite `folders` table |
| **F-37** | **Color-Coded Tags & Document Labels**<br>Tag documents with customizable colored pills (e.g., Urgent, Taxes) | Genius Scan, SwiftScan, CamScanner | E | P1 | Phase 4 | **PLANNED** | SQLite `tags` table |
| **F-38** | **Smart Filename Templates**<br>Configurable naming syntax (e.g., `[Date]_[Category]_[Counter]`) | Genius Scan Ultra | E | P1 | Phase 4 | **PLANNED** | Template string parser |
| **F-39** | **Trash & Soft-Delete Recovery**<br>30-day retention with restore and permanent purge actions | Google Drive, CamScanner | E | P1 | Phase 4 | **PLANNED** | SQLite `deleted_at` timestamp |
| **F-40** | **Batch Document Management Actions**<br>Select multiple documents to batch move, tag, merge, or delete | All 6 Reference Apps | E | P1 | Phase 4 | **PLANNED** | Multi-select state notifier |
| **F-41** | **System Share Sheet Integration**<br>Send PDFs and JPEGs to WhatsApp, Gmail, Drive via Android Sharesheet | All 6 Reference Apps | F | P0 | Phase 2 | **TESTED** | `share_plus`<br>`review_pages_screen.dart` |
| **F-42** | **Automated Background Cloud Export**<br>Auto-upload verified scans to Google Drive, Dropbox, OneDrive, WebDAV | Genius Ultra, SwiftScan VIP | F | P3 | Phase 11 | **PLANNED** | Cloud Storage APIs / WorkManager |
| **F-43** | **Encrypted Cloud Backup & Multi-Device Sync**<br>Cross-device document synchronization with conflict detection | Adobe Cloud, CamScanner, Genius Cloud | F | P3 | Phase 11 | **PLANNED** | Supabase Auth/Postgres/Storage |
| **F-44** | **100% Offline Local-First Architecture**<br>Zero internet connection required for scanning, editing, OCR, and PDF tools | Genius Scan (Basic) | G | P0 | Phase 1 | **TESTED** | Core Architectural Principle |
| **F-45** | **Zero Mandatory User Accounts**<br>No account wall, registration, or login required to use full local app | Genius Scan (Basic) | G | P0 | Phase 1 | **TESTED** | Core Architectural Principle |
| **F-46** | **Biometric App Lock & PIN Security**<br>Lock document library behind Fingerprint, Face Unlock, or PIN | Genius Ultra, SwiftScan VIP | G | P2 | Phase 7 | **PLANNED** | `local_auth` / Keystore |
| **F-47** | **Automated Stale Temporary File Cleanup**<br>Automatic purges of orphaned `.tmp` files older than 24 hours | Architectural Best Practice | G | P0 | Phase 1 | **TESTED** | `app_storage_service.dart`<br>`test/storage_service_test.dart` |

---

## Traceability Summary Metrics

- **Total Categorized Features:** 47
- **Currently TESTED & Passing:** 25 features (53.2%)
- **Currently IMPLEMENTED (Hardware verification pending):** 5 features (10.6%)
- **Total Operational Coverage:** 30 features (63.8%)
- **PLANNED for Scheduled Phases:** 17 features (36.2%)
- **NOT PLANNED (Anti-patterns rejected):** Mandatory account walls, free-tier watermarks, full-screen ads, covert cloud uploads, unconsented telemetry.
