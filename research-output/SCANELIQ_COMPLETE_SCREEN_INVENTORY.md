# Scaneliq — Complete Application Screen, Dialog & Workflow Inventory

**Document Date:** November 18, 2026  
**Approved Master Design:** **Concept A — Editorial Gallery Minimal** ([SCANELIQ_HOME_CONCEPT_A_PREMIUM_MINIMAL.html](file:///C:/Scaneliq/research-output/ux-prototypes/SCANELIQ_HOME_CONCEPT_A_PREMIUM_MINIMAL.html))  
**Source Verification:** Direct inspection of all `38` Dart files in `C:\Scaneliq\lib\` (`17` presentation/widget files + `105` embedded modal dialog/bottom-sheet invocations).

---

## 1. Classification Legend

In strict compliance with Section 4 requirements, every screen and workflow is classified honestly:
1. **`Implemented`** — Feature and UI exist in `lib/` and are verified by automated host tests (`139/139` passing).
2. **`Partially Implemented`** — UI exists, but underlying engine has a verified functional gap (e.g., Bangla OCR routed to Devanagari `RISK-03`; CountCam counting text blocks `RISK-09`; Cloud Backup/Sync operating locally without remote transport `RISK-08`; Vector PDF visual masking `RISK-12`).
3. **`Requires Technical Verification`** — Code and plugin wiring exist (`google_mlkit_document_scanner`, `camera`, `mobile_scanner`, `local_auth`, `share_plus`), but have `0` physical Android device or emulator runs (`RISK-02`).
4. **`Planned`** — Documented in roadmap/blueprint (e.g., Splash/Onboarding screens, Google Drive/WebDAV cloud transport, real Bengali Tesseract engine, FTS5 search), not yet built in `lib/`.
5. **`Not Implemented`** — No backend service, model, or roadmap implementation exists in the current repository (e.g., Push Notifications, User Account Registration/Login, Payment Gateway/In-App Billing).

---

## 2. Existing Dart Presentation Files & Embedded Modal Inventory (`17` Files, `105` Modals)

| # | Dart File (`lib/...`) | Lines | Widget Class(es) | Embedded Modals | Current Visual Condition |
|---|---|---|---|---|---|
| 1 | `main.dart` | 32 | `ScaneliqApp` | 0 | Uses `MaterialApp` directly (`go_router` unused); static `ThemeMode.system`. |
| 2 | `app/main_navigation_shell.dart` | 313 | `MainNavigationShell`, `_NavBarItem` | 0 | Old 4-tab bar + 3-stop gradient glowing center shutter (`#3B82F6`→`#021642`). Needs replacement with Concept A 3-tab bar (`Scans`, `Folders`, `PDF Suite`) + floating right-thumb `[Gallery] [Scan]` cluster. |
| 3 | `core/widgets/scaneliq_logo.dart` | 48 | `ScaneliqLogo` | 0 | Legacy blue image/squircle wrapper; replace with Concept A monochrome `26×26px` viewfinder mark. |
| 4 | `features/documents/presentation/home_screen.dart` | 1,002 | `HomeScreen` | 0 | Old boxed cards, 8-pill carousel, unbounded document list, off-tab `"See all"` push bug. Replace 1:1 with approved **Concept A Home Dashboard**. |
| 5 | `features/documents/presentation/documents_library_screen.dart` | 1,769 | `DocumentsLibraryScreen` | 14 | Monolithic file with 5 stacked header/filter bars, duplicate Favorite star, boxed cards. Redesign to Concept A hairline stream & folder hierarchy. |
| 6 | `features/documents/presentation/document_viewer_screen.dart` | 1,686 | `DocumentViewerScreen` | 19 | Hides 10 actions in a text `PopupMenuButton`; tiny `18dp` zoom buttons; 19 inline `AlertDialog`s for password, compress, watermark, encrypt, details, rename. |
| 7 | `features/documents/presentation/trash_screen.dart` | 412 | `TrashScreen` | 6 | Boxed list with raw dialogs for restore/empty trash. Redesign to Concept A editorial list. |
| 8 | `features/editor/presentation/review_pages_screen.dart` | 1,033 | `ReviewPagesScreen` | 7 | Basic list/grid review with modal `AlertDialog` after PDF export. Redesign to Concept A editorial review stage & bottom sheet export. |
| 9 | `features/editor/presentation/edit_page_screen.dart` | 1,246 | `EditPageScreen` | 0 | 5 overlapping text tabs (`Filters` vs `Binarize` with Otsu/Sauvola jargon), no corner loupe, no live thumbnail filter strip. |
| 10 | `features/scanner/presentation/continuous_camera_screen.dart` | 738 | `ContinuousCameraScreen` | 0 | Neon `tealAccent` / `deepPurpleAccent` guide boxes, `Colors.black87` bar, lifecycle dispose bug (`RISK-02`). |
| 11 | `features/scanner/presentation/scan_code_screen.dart` | 212 | `ScanCodeScreen` | 1 | Basic `mobile_scanner` screen + modal result dialog. |
| 12 | `features/scanner/presentation/count_cam_screen.dart` | 369 | `CountCamScreen` | 0 | Basic dark scaffold; uses Latin OCR text blocks instead of object detection (`RISK-09`). |
| 13 | `features/scanner/presentation/translate_screen.dart` | 372 | `TranslateScreen` | 2 | Plain text fields + online consent dialog (`GoogleTranslator`, `RISK-10`). |
| 14 | `features/pdf/presentation/pdf_tools_screen.dart` | 1,555 | `PdfToolsScreen` | 26 | 12-color rainbow icon boxes (`Colors.pink`, `Colors.orange`, invisible `Colors.black87` in dark mode) + 26 raw text-input `AlertDialog`s printing `/data/user/0/...` paths. |
| 15 | `features/pdf/presentation/pdf_page_organizer_screen.dart` | 782 | `PdfPageOrganizerScreen` | 8 | Grid organizer with 8 modal dialogs for extract/insert/rotate/save. |
| 16 | `features/intelligence/presentation/ai_document_sheet.dart` | 356 | `AiDocumentSheet` | 1 | Modal bottom sheet for offline TextRank summary & Q&A. |
| 17 | `features/intelligence/presentation/business_card_dialog.dart` | 301 | `BusinessCardDialog` | 1 | Cramped `AlertDialog` form for vCard contact extraction. |
| 18 | `features/intelligence/presentation/receipt_dialog.dart` | 416 | `ReceiptDialog` | 1 | Cramped `AlertDialog` for receipt total/tax extraction & CSV export. |
| 19 | `features/security/presentation/app_lock_dialog.dart` | 376 | `AppLockDialog` | 3 | Basic `AlertDialog` with text field for PIN entry/setup instead of a dedicated full-screen tactile keypad. |
| 20 | `features/settings/presentation/settings_screen.dart` | 977 | `SettingsScreen` | 12 | Multi-colored icon circles, read-only Theme tile, developer jargon (`UUIDv4`, `LWW`), 12 modal dialogs/sheets for PIN, timeout, backup, sync. |
| 21 | `features/settings/presentation/tools_screen.dart` | 598 | `ToolsScreen` | 4 | Redundant vertical list with dead `"Share & Export"` snackbar tile and 3 disabled `"Coming soon"` rows. Folded into Concept A **`PDF Suite`** tab. |

---

## 3. Master 65-Screen Target Coverage Inventory & Implementation Status

Every one of the 65 target screens/states requested in Section 5 is mapped below to its current Dart implementation, true functional status, entry point, and Concept A redesign requirement:

### Group A — Main Application (Screens 1–6)
| # | Screen Name | Source Dart File | Implementation Status | Navigation Entry Point | Concept A Redesign Requirement |
|---|---|---|---|---|---|
| 1 | **Home Dashboard** | `home_screen.dart` | **Implemented** | Root Tab 1 (`Scans`) | **Approved Master Design:** Editorial header, OCR search bar, `Recent / Starred / Folders` underline scopes, "Continue working" 3D paper-stack folio, hairline stream, floating `[Gallery] [Scan]` cluster. |
| 2 | **Splash Screen** | `main.dart` / `launch_background.xml` | **Planned** (Native XML only) | Cold App Launch | Minimal Gallery Alabaster (`#FAF9F6`) / Carbon Studio (`#0D0E11`) launch canvas with `36px` monochrome viewfinder glyph & wordmark (`<=400ms`). |
| 3 | **Onboarding** | *None in `lib/`* | **Planned** | First-launch gate | 3-slide editorial typography & paper-preview walkthrough (Zero-Account Vault, Precision Scan & Magic Color, Offline PDF & OCR) + Camera permission priming. |
| 4 | **Main Navigation** | `main_navigation_shell.dart` | **Implemented** | Root App Shell | Concept A 3-tab bottom bar (`Scans`, `Folders`, `PDF Suite`) with frosted `backdrop-filter: blur(16px)`, `1px` `--hairline` top rule, and right-thumb floating `[Gallery] [Scan]` cluster. |
| 5 | **Global Search** | `home_screen.dart` / `documents_library_screen.dart` | **Partially Implemented** (SQL `LIKE`, FTS5 planned `RISK-11`) | Search Bar tap on `Scans` or `Folders` | Dedicated instant search overlay with scope pills (`All`, `OCR Text`, `Titles`, `Tags`), recent queries, and hairline results showing highlighted OCR text snippets in `--font-mono`. |
| 6 | **Notifications** | *None in `lib/`* | **Not Implemented** (Local-first app has no push server) | N/A (System snackbars/banners only) | Disclosed as **In-App Activity & Vault Toast Banners** (non-blocking editorial top/bottom status pills for background PDF/backup completion; no fake push center). |

### Group B — Scanner Experience (Screens 7–18)
| # | Screen Name | Source Dart File | Implementation Status | Navigation Entry Point | Concept A Redesign Requirement |
|---|---|---|---|---|---|
| 7 | **Scanner Camera** | `continuous_camera_screen.dart` + `scan_session_provider.dart` | **Requires Technical Verification** (`RISK-02`) | Floating `[📷 Scan]` button | True-black `#0D0E11` optical studio, minimal top bar (`Close`, `Auto/Manual` pill, `Flash`, `Grid`), bottom mode strip (`Document`, `ID Card`, `Book`, `Whiteboard`, `Receipt`, `Card`, `QR`), tactile white shutter ring, live page-stack counter. |
| 8 | **Automatic Document Detection** | `scan_session_provider.dart` (ML Kit) / `continuous_camera_screen.dart` | **Requires Technical Verification** | Camera default `Auto` state | International Ultramarine (`#0052FF` / `#3B82F6`) `2px` animated quadrilateral boundary lock + corner anchor nodes + subtle status pill (`"Hold steady · Capturing"`). |
| 9 | **Manual Capture** | `continuous_camera_screen.dart` | **Requires Technical Verification** | Top pill toggle `Manual` | Disables auto-shutter timer; displays precision horizon level hairlines and responsive manual shutter trigger. |
| 10 | **Gallery Import** | `home_screen.dart:51` / `continuous_camera_screen.dart` (`file_picker`) | **Implemented** | Floating `[🖼]` button or Camera bottom-left | System picker bridge + Concept A batch import staging sheet showing selected image count, magic-byte validation badge, and auto-crop toggle. |
| 11 | **Scan Preview** | `review_pages_screen.dart` | **Implemented** | Camera `Done / Stack` tap or after Import | Large A4 paper stage on Gallery Alabaster/Carbon background, inline editable title + page counter (`2 of 4`), quick bottom tool rail (`Crop`, `Filters`, `Enhance`, `Rotate`, `Delete`), primary `Save PDF` pill. |
| 12 | **Crop & Perspective Correction** | `edit_page_screen.dart` (`EditTab.crop`) | **Implemented** | Scan Preview → `Crop` | Dark `#0D0E11` studio canvas, Ultramarine 4-point quad handles (`48dp` hit zones), **offset 1.8× circular magnifying loupe**, `Auto Fit` / `Full Page` / `Rotate 90°` actions. |
| 13 | **Image Enhancement** | `edit_page_screen.dart` (`EditTab.adjust` + `cleanup`) | **Implemented** | Scan Preview → `Enhance` | Clean precision sliders (`Brightness`, `Contrast`, `Shadow Flattening` toggle) + `Spot Eraser / Redact` brush tool and `Hold to Compare` original toggle. |
| 14 | **Filter Selection** | `edit_page_screen.dart` (`EditTab.filter` + `binarize`) | **Implemented** | Scan Preview → `Filters` | Unified horizontal ribbon of **7 live miniature page thumbnails** (`Original`, `Magic Color`, `Crisp B&W`, `Adaptive Text`, `Grayscale`, `Whiteboard`, `Color Boost`) + `"Apply to all pages"` toggle. |
| 15 | **Multi-Page Organizer** | `review_pages_screen.dart` / `pdf_page_organizer_screen.dart` | **Implemented** | Scan Preview → `Pages (N)` grid button | 2-column A4 paper grid with monospaced index badges (`01`, `02`, `03`), `+ Add Page` card, multi-select actions (`Rotate`, `Duplicate`, `Extract`, `Delete`). |
| 16 | **Page Reordering** | `review_pages_screen.dart` / `pdf_page_organizer_screen.dart` | **Implemented** | Long-press drag in Organizer or Preview strip | Tactile elevated paper card during drag with Ultramarine insertion slot hairline and immediate SQLite `page_order` sync. |
| 17 | **Document Naming** | `review_pages_screen.dart` + `smart_filename_service.dart` | **Implemented** | Tap Document Title in Preview or Viewer | Clean Concept A bottom sheet with filename input, 1-tap Smart Token pills (`[Date]`, `[Category]`, `[Counter]`), and folder/tag assignment prior to save. |
| 18 | **Document Saving** | `review_pages_screen.dart:41` (`_exportAndSavePdf`) | **Implemented** | Tap `Save PDF` in Scan Preview | Editorial progress sheet (`"Compiling 4 pages · Embedding OCR layer"`) transitioning smoothly into PDF Viewer with `Saved to Vault` confirmation. |

### Group C — PDF Experience (Screens 19–28)
| # | Screen Name | Source Dart File | Implementation Status | Navigation Entry Point | Concept A Redesign Requirement |
|---|---|---|---|---|---|
| 19 | **PDF Viewer** | `document_viewer_screen.dart` (`pdfrx`) | **Implemented** | Tap any document in `Scans` or `Folders` | Paper-first reader with top bar (`Back`, Title, `Search`, `Share`), floating monospaced page pill (`01 / 12`), and clean 5-item bottom dock (`Edit`, `Pages`, `OCR`, `Sign`, `Tools`). |
| 20 | **PDF Editor** | `document_viewer_screen.dart` + `pdf_page_organizer_screen.dart` | **Implemented** | Viewer → `Edit` or `Pages` | Seamless in-place switch between Page Image Re-Edit (`EditRecipe`), Page Structure Organizer (insert/delete/rotate), and Metadata Editor. |
| 21 | **PDF Merge** | `pdf_tools_screen.dart:192` + `batch_merge_service.dart` | **Implemented** | `PDF Suite` → `Merge PDF` or Library Batch Merge | Concept A Document Picker (select from Vault or Device) → Draggable document order list with total page/size summary → `Merge into Single PDF`. |
| 22 | **PDF Split** | `pdf_tools_screen.dart` (`_splitPdf`, `_splitByRanges`, `_extractPages`) | **Implemented** | `PDF Suite` → `Split & Extract` | Visual thumbnail page-range selector (tap pages or enter ranges like `1-3, 5`) replacing raw text-only `AlertDialog`. |
| 23 | **PDF Compression** | `pdf_tools_screen.dart` (`_compressPdf`) + `advanced_pdf_service.dart` | **Implemented** | `PDF Suite` → `Compress` or Viewer → `Tools` | Clean 3-tier editorial radio list (`High Quality 85%`, `Balanced 65%`, `Compact 45%`) showing measured before/after MB savings badge. |
| 24 | **PDF Conversion** | `pdf_service.dart` + `pdf_tools_screen.dart` (`_stitchLongImage`) | **Implemented** (PDF↔JPG, Long Stitch, TXT; Word/Excel not implemented) | `PDF Suite` → `Convert & Export` | Unified conversion sheet for **supported formats**: `PDF to JPEG Images`, `Images to PDF`, `Long Vertical Image Stitch`, `Searchable Text (.txt)`. |
| 25 | **PDF Export** | `review_pages_screen.dart` / `document_viewer_screen.dart` | **Implemented** | `Save / Export` action | Bottom sheet configuring DPI quality (`150 / 200 / 300 DPI`), OCR text layer inclusion, password toggle, and `Save to Device` vs `Share`. |
| 26 | **PDF Annotation** | `pdf_tools_screen.dart` (`_annotatePdf`) + `advanced_pdf_service.dart` | **Implemented** | Viewer → `Sign` or `PDF Suite` → `Annotate` | Direct canvas overlay for highlights, approval stamps (`APPROVED`, `CONFIDENTIAL`, `DRAFT`), text callouts, and watermark placement. |
| 27 | **Digital Signature** | `pdf_tools_screen.dart` (`_annotatePdf`) + `advanced_pdf_service.dart` | **Implemented** | Viewer → `Sign` | Dedicated freehand signature pad (Black, Ultramarine `#0052FF`, Charcoal ink) with saved signature drawer and pinch-to-place page positioning. |
| 28 | **PDF Protection** | `pdf_tools_screen.dart` (`_encryptPdf`, `_unlockPdf`, `_redactPdf`) | **Implemented** (AES-256 + Raster Redact / Vector Masking) | `PDF Suite` → `Protect & Redact` | Clean tabbed sheet: `AES-256 Password Lock`, `Unlock PDF`, and `Permanent Redaction` (clearly distinguishing raster pixel destruction vs vector masking `RISK-12`). |

### Group D — Document Management (Screens 29–38)
| # | Screen Name | Source Dart File | Implementation Status | Navigation Entry Point | Concept A Redesign Requirement |
|---|---|---|---|---|---|
| 29 | **Document Library** | `documents_library_screen.dart` | **Implemented** | Root Tab 1 (`Scans`) & Tab 2 (`Folders`) | Hairline-divided editorial document stream with optional 2-column A4 paper gallery view toggle (zero boxed dashboard clutter). |
| 30 | **Folder Management** | `documents_library_screen.dart` + `app_database_service.dart` | **Implemented** | Root Tab 2 (`Folders`) or Scope `Folders 5` | Clean editorial folder table (`Folder Icon`, `Folder Title`, monospaced file count `14 FILES`, breadcrumb trail, New Subfolder / Rename / Safe Delete sheet). |
| 31 | **Document Details** | `document_viewer_screen.dart:1301` / `pdf_tools_screen.dart:1170` | **Implemented** | Document `⋯` Menu → `Details` | Editorial specification sheet: Title, Folder location, Tags, Page count, Dimensions, File size, AES-256 status, Creation/Modified timestamps, SHA-256 integrity. |
| 32 | **Document Preview** | `home_screen.dart` / `document_viewer_screen.dart` | **Implemented** | Long-press or tap document row | Quick peek drawer / instant paper preview with quick actions (`Open PDF`, `Run OCR`, `Rename`, `Move to Folder`, `Share`, `Trash`). |
| 33 | **Multi-Selection** | `documents_library_screen.dart:47` | **Implemented** | Header `[☑]` button or long-press row | Header morphs to `"3 Selected"` with `Select All` & `Cancel`; rows display crisp Ultramarine selection checks. |
| 34 | **Batch Actions** | `documents_library_screen.dart:282` + `batch_merge_service.dart` | **Implemented** | Bottom dock when `>=1` document selected | Frosted bottom action bar replacing main nav: `Move`, `Tag`, `Merge PDF`, `Share`, `Trash` (plus `TrashScreen` recovery dock). |
| 35 | **Document Search Results** | `documents_library_screen.dart:750` + `app_database_service.dart:869` | **Partially Implemented** (`LIKE` active; FTS5 planned) | Typing in Search Bar | Grouped results (`Matching Titles` + `Matches Inside OCR Text` with monospaced page badge and highlighted text excerpt). |
| 36 | **Document Sharing** | `home_screen.dart:94` / `document_viewer_screen.dart` (`share_plus`) | **Requires Technical Verification** | `Share` icon in Viewer or row menu | Clean pre-share format sheet (`Share as PDF`, `Share as JPEG Pages`, `Share Extracted Text`) invoking Android system Share Sheet. |
| 37 | **Starred Documents** | `home_screen.dart` / `documents_library_screen.dart` | **Implemented** | Home Scope Tab `Starred 7` | Instant in-place filtered stream of starred documents on the approved Concept A Home canvas. |
| 38 | **Recent Documents** | `home_screen.dart` | **Implemented** | Home Scope Tab `Recent 42` | Default chronological feed grouped by month (`November 2026`) with the featured `"Continue working"` draft folio at top. |

### Group E — OCR and AI (Screens 39–45)
| # | Screen Name | Source Dart File | Implementation Status | Navigation Entry Point | Concept A Redesign Requirement |
|---|---|---|---|---|---|
| 39 | **OCR Processing** | `ocr_service.dart` + `tools_screen.dart:28` | **Requires Technical Verification** | Viewer → `OCR` or `PDF Suite` → `OCR` | Calm editorial scanning state showing page preview with animated Ultramarine optical scan line and script indicator (`English / Latin` or `বাংলা`). |
| 40 | **OCR Results** | `tools_screen.dart:107` / `document_viewer_screen.dart` | **Implemented** (Latin verified) | Post-OCR completion | Split view: top interactive page with word bounding boxes (`OcrBoundingBox`), bottom clean typographic reader with `Copy`, `Edit`, `Translate`, `Summarize`, `Export .txt`. |
| 41 | **Bengali OCR** | `ocr_service.dart:75` | **Partially Implemented** (**Bug `RISK-03`:** routes to Devanagari; Tesseract `ben` planned) | OCR Script Selector → `বাংলা (Bengali)` | Dedicated bilingual interface rendered in `Noto Sans Bengali` with numeral converter toggle (`০-৯ ↔ 0-9`) and **transparent engine status badge** (`RISK-03` notice in prototype). |
| 42 | **Extracted Text** | `document_viewer_screen.dart` / `tools_screen.dart` | **Implemented** | OCR Results → `Full Text Reader` | Distraction-free editorial reading & copy view with paragraph blocks, word/character count in `--font-mono`, and 1-tap `Copy All` / `Save Searchable PDF`. |
| 43 | **Translation** | `translate_screen.dart` | **Partially Implemented** (Online `GoogleTranslator` `RISK-10`; offline ML Kit planned) | OCR Results → `Translate` or `PDF Suite` | Editorial dual-pane card (`Source: English / বাংলা` → `Target: বাংলা / English`) with explicit `Online / Offline Pack` privacy indicator pill. |
| 44 | **AI Document Assistant** | `ai_document_sheet.dart` + `ai_document_service.dart` | **Implemented** (100% offline Extractive TextRank + TF-IDF Q&A) | Viewer → `Tools` → `AI Assistant` or `PDF Suite` | Editorial Q&A studio with honest `"On-Device Extractive Engine"` tag, prompt pills (`"Key amounts?"`, `"Main obligations?"`), and cited sentence answers. |
| 45 | **Document Summary** | `ai_document_sheet.dart` + `ai_document_service.dart` | **Implemented** (Offline TextRank) | AI Assistant → `Summary` tab | Clean executive brief card: 3-sentence digest, key bullet takeaways, extracted keyword pills (`--font-mono`), and `Copy Brief` action. |

### Group F — Productivity Tools (Screens 46–49)
| # | Screen Name | Source Dart File | Implementation Status | Navigation Entry Point | Concept A Redesign Requirement |
|---|---|---|---|---|---|
| 46 | **Receipt Scanner** | `receipt_dialog.dart` + `receipt_parser_service.dart` | **Implemented** | `PDF Suite` → `Receipt & Invoice` | Full-screen editorial ledger replacing cramped dialog: cropped receipt preview + structured table (`Merchant`, `Date`, `Subtotal`, `Tax`, `Total`, math check badge) + `Export CSV`. |
| 47 | **Invoice Scanner** | `receipt_dialog.dart` + `receipt_parser_service.dart` | **Implemented** (Shared parser with Receipt) | `PDF Suite` → `Receipt & Invoice` (`Invoice` mode) | Extended commercial invoice view highlighting Invoice #, Vendor, Line Items, VAT/Tax breakdown, and `Save Searchable PDF + CSV`. |
| 48 | **Business Card Scanner** | `business_card_dialog.dart` + `business_card_service.dart` | **Implemented** | `PDF Suite` → `Business Card` | Full-screen editorial contact folio replacing dialog: card image preview + clean hairline form (`Name`, `Role`, `Company`, `Phone`, `Email`, `Website`) + `Export vCard (.vcf)`. |
| 49 | **CountCam** | `count_cam_screen.dart` | **Partially Implemented** (**Bug `RISK-09`:** counts OCR text blocks; TFLite object detector planned) | `PDF Suite` → `CountCam (Beta)` | Dark optical viewport with numbered Ultramarine pin markers (`01`, `02`...), tap-to-add/remove pin interaction, +/- stepper, and clear `Beta` disclosure badge. |

### Group G — Security and Backup (Screens 50–55)
| # | Screen Name | Source Dart File | Implementation Status | Navigation Entry Point | Concept A Redesign Requirement |
|---|---|---|---|---|---|
| 50 | **App Lock** | `app_lock_dialog.dart` + `app_lock_service.dart` | **Implemented** (PBKDF2 100k V3; KeyStore migration planned `RISK-05`) | App Resume barrier or Settings → `App Lock` | Full-screen Gallery Alabaster / Carbon Studio lock barrier with monochrome Scaneliq glyph, 4–6 PIN dots, clean hairline numeric keypad, and 5-attempt lockout timer. |
| 51 | **Biometric Authentication** | `app_lock_service.dart` (`local_auth`) | **Requires Technical Verification** (`RISK-02`) | App Lock barrier biometric button / auto-prompt | Clean fingerprint/face prompt trigger integrated into App Lock barrier with instant fallback to PIN pad. |
| 52 | **Security Settings** | `settings_screen.dart:638` | **Implemented** | Header Gear → `Security & Vault` | Dedicated hairline settings section: `PIN Lock`, `Biometric Unlock`, `Auto-Lock Timer` (`Immediate / 1m / 5m`), `Change PIN`, and planned `Privacy Screen Shield (FLAG_SECURE)`. |
| 53 | **Backup and Restore** | `settings_screen.dart:112` + `cloud_backup_service.dart` | **Implemented** (Local `.scaneliq` AES-256-CBC + HMAC EtM V2) | Settings → `Backup & Restore` | Editorial Vault durability studio: Create Encrypted `.scaneliq` Archive (with passphrase sheet), Restore Archive (with non-destructive preview), SHA-256 verification status. |
| 54 | **Cloud Synchronization** | `settings_screen.dart:207` + `device_sync_service.dart` | **Partially Implemented** (Local E2EE sync envelope & LWW active; remote Drive/WebDAV transport **Planned** `RISK-08`) | Settings → `Encrypted Sync` | Honest UI distinguishing **Active Local E2EE Sync Package Export/Import** from **Planned Google Drive AppData / WebDAV Auto-Sync** (clearly badged `Planned Transport`). |
| 55 | **Account Settings** | *None in `lib/`* (`F-45` Zero Mandatory Accounts) | **Not Implemented / By Design Local-First** | Settings → `Vault Identity` | Redesigned as **"Local Device & Zero-Account Identity"** (displays editable Device Name for E2EE sync envelopes and confirms zero cloud account requirement). |

### Group H — Premium and General Settings (Screens 56–65)
| # | Screen Name | Source Dart File | Implementation Status | Navigation Entry Point | Concept A Redesign Requirement |
|---|---|---|---|---|---|
| 56 | **Premium Subscription** | *None in `lib/`* (`F-19` Free Unwatermarked Core) | **Planned / Proposed Optional Pro** | Settings → `Scaneliq Pro` | Editorial comparison sheet showing **Free Forever Core** (Unlimited local scans, zero watermarks, local OCR/PDF) vs **Proposed Pro Cloud/AI Add-on** (clearly marked `Proposed / No Payment Gateway Connected`). |
| 57 | **Subscription Management** | *None in `lib/`* | **Not Implemented** | Settings → `Scaneliq Pro` → `Manage` | Clean informational state confirming all local features are currently unlocked in the Local-First Edition. |
| 58 | **General Settings** | `settings_screen.dart` | **Implemented** | Top Header Gear icon (`⚙`) on Home | Clean hairline-grouped editorial preferences page replacing multi-colored circles and developer jargon. |
| 59 | **Scanner Settings** | `settings_screen.dart:834` + `smart_filename_service.dart` | **Implemented** | Settings → `Scanner Defaults` | Default Capture Mode (`Auto` / `Manual`), Default Filter (`Magic Color` / `Original` / `B&W`), Smart Filename Template builder (`[Date]_[Category]_[Counter]`). |
| 60 | **PDF Settings** | `settings_screen.dart:810` + `pdf_service.dart` | **Implemented** | Settings → `PDF & Export Defaults` | Default Page Size (`ISO A4` / `US Letter` / `Fit Image`), Default DPI (`150 / 200 / 300 DPI`), Auto-embed Searchable OCR Layer toggle. |
| 61 | **Appearance Settings** | `settings_screen.dart:785` + `app_theme.dart` | **Partially Implemented** (Read-only tile in code; live switcher designed) | Settings → `Appearance` | Interactive 3-way segmented selector: **`Gallery Alabaster (Light)`**, **`Carbon Studio (Dark)`**, and **`System`** (fixing the non-clickable tile in `settings_screen.dart:786`). |
| 62 | **Language Settings** | `settings_screen.dart:614` + `ocr_service.dart` | **Partially Implemented** (`RISK-03` Bengali OCR engine gap) | Settings → `Language & OCR Scripts` | Primary OCR Script default (`English / Latin`, `বাংলা (Bengali — Planned Tesseract Fix)`, `Devanagari`) + Numeral Format preference (`0-9` vs `০-৯`). |
| 63 | **Storage Management** | `settings_screen.dart:560` + `app_storage_service.dart` + `trash_screen.dart` | **Implemented** | Settings → `Storage & Trash` | Storage breakdown (`Originals`, `Processed Cache`, `Exported PDFs`, `Temp`), `Clean Stale Temp Files` action, and direct entry to **`Trash & 30-Day Recovery`**. |
| 64 | **Help and Support** | *Minimal in `settings_screen.dart`* | **Planned / Prototype Screen** | Settings → `Help & Support` | Editorial FAQ accordion (`2-in-1 ID Scan`, `Encrypted Backups`, `Searchable PDFs`), Privacy Architecture pledge, and diagnostic log export. |
| 65 | **About Scaneliq** | `settings_screen.dart:510, 848` | **Implemented** | Settings → `About Scaneliq` | Brand mark, Version `1.0.0+1`, Local-First Privacy Charter, and `showLicensePage` Open-Source Licenses viewer. |
