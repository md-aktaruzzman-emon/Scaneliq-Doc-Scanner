# Mobile-First Document Scanner — Master Product & Technical Blueprint

**Document type:** Product Requirements Document (PRD) + Functional UX Specification + Technical Architecture + Data/Processing Logic + Competitor Feature Map + QA Plan  
**Project status:** Planning baseline; not a claim that any feature has been implemented  
**Primary platform:** Android first  
**Recommended app framework:** Flutter + Dart, with Android-native adapters where necessary  
**Future platforms:** iOS next; Windows desktop after the mobile core is stable  
**Working name:** TBD — choose an original name and identity later  
**Last reviewed:** 15 October 2026  

> **Purpose of this file:** This is the single source of truth for what the app should become, what it learns from the six reference scanner apps, how the app should behave, how data moves through the system, the technical terms and architecture, and how each release should be tested. Treat unchecked features as planned, not implemented.

> **UX reference note:** The latest attachment available in this conversation is an AUVYQ Chrome-extension security-audit prompt, not a scanner-app visual design or screen mockup. This document uses the mobile UX structure from the earlier scanner specification and defines required screen behavior. Exact colors, spacing, typography, icon style, and component appearance must be matched against the intended visual reference once that actual reference image/file is available. Do not invent a claim that the missing visual design has been copied.

---

## 0. Executive Decision Summary

Build a dependable Android-first scanner that takes a paper document through this complete journey:

**Capture or import → review pages → correct scan → arrange pages → create PDF/JPEG → save locally → find later → share/export.**

The first release must do this well before it attempts to become an all-in-one AI or cloud platform.

### Core product principles

1. **Local-first:** scanning, page correction, PDF creation, and local document management should not require sign-in or routine internet access.
2. **Original preservation:** never overwrite the only copy of the captured/imported page during crop, filter, OCR, compression, or export.
3. **Reliable outcomes:** success messages must follow verified file/database operations, not just a button tap.
4. **Progressive complexity:** basic scanning stays simple; advanced PDF/OCR/AI tools can be added without cluttering the camera workflow.
5. **Honest language support:** test English and Bangla OCR separately. Do not claim Bangla OCR based only on an engine supporting other scripts.
6. **Cross-platform-ready, not cross-platform-first:** design service boundaries so iOS and later Windows are possible, but prove the Android experience first.
7. **Use competitor capabilities as inspiration, not as a copy target:** create original code, brand, icons, wording, navigation, and visuals.
8. **No false premium promises:** a feature is not “supported” until the relevant workflow has been tested on the target platform.

### Release priorities

| Priority | Meaning | Main scope |
|---|---|---|
| **P0 — Android MVP** | Required for the first usable release | Capture/import, multi-page review, crop/rotate/enhance, PDF/JPEG export, local library, filename search, share, safe recovery |
| **P1 — OCR release** | Adds searchable content | English OCR, Bangla OCR evaluation/implementation, copy text, full-text search, searchable PDF if word positions and fonts work |
| **P2 — Pro PDF tools** | Advanced document productivity | Merge/split/extract/reorder existing PDF pages, compression, annotations, PDF encryption, compatible forms |
| **P3 — Smart/cloud** | Larger engineering and operational scope | AI summaries/Q&A, translation, smart extraction, cross-device sync, accounts, subscriptions, teams |
| **Later platform** | Only after mobile behavior is stable | iOS release, then a real Windows desktop workflow |

---

## 1. Product Definition

### 1.1 Product vision

Make it easy to convert paper documents and existing images into clean, organized, searchable, and shareable digital documents from a phone. Make the app useful to students, office workers, teachers, researchers, freelancers, and people who need to scan forms, bills, notes, certificates, receipts, or contracts.

### 1.2 Main jobs the app must do

- Digitize a paper document with a phone camera.
- Combine several pages into one document.
- Fix perspective, rotation, lighting, and contrast when possible.
- Save a readable PDF or image file.
- Locate an old scan without needing to remember exactly when it was created.
- Share an exported copy with another application or save it to a user-selected location.
- Later: search the actual words inside a scan, including tested English and Bangla workflows.
- Later: do advanced PDF tasks and optional AI-assisted document work.

### 1.3 Target users and key needs

| User group | Common use cases | Important needs |
|---|---|---|
| Students | Class notes, assignments, handouts, book pages, certificates | Multi-page capture, readable black-and-white scans, compact PDFs, offline access, text search |
| Teachers/researchers | Papers, worksheets, printed references, study notes | OCR quality, page ordering, searchable PDF, exportable text, reliable archive |
| Office workers | Forms, contracts, letters, receipts, invoices | Document naming, PDF sharing, password protection later, clear output quality |
| Freelancers/small businesses | Receipts, agreements, business cards | Fast processing, folders/tags, repeatable workflows, data extraction later |
| Privacy-conscious users | Sensitive forms and personal records | Local storage, no forced account, explicit cloud consent, safe deletion |
| Users with budget Android devices | Everyday documents under limited CPU/RAM/storage | Low memory use, reliable manual capture, efficient image handling |

### 1.4 Product scope boundaries

**In scope now:** Android capture and import, page correction, basic filters, PDF/JPEG export, local document management, export/share, safe persistence, error handling.

**In scope later:** OCR, full-text search, advanced PDF editing, security options, AI-assisted processing, cloud sync, subscriptions, business/team features, iOS, Windows.

**Not an MVP requirement:** training a custom OCR model from scratch, mandatory user accounts, automatic uploads, full collaborative document-management service, universal support for every scanner device, guaranteed editable Office conversion, perfect handwriting recognition, or perfect removal of all shadows/creases.

### 1.5 Product success metrics

Establish numeric thresholds after prototypes and tests, rather than inventing performance claims. Collect these metrics from controlled internal test runs, not from private document content:

- Completion rate of scan-to-PDF flow.
- Time from starting capture to saved PDF.
- Automatic crop success rate and manual-correction rate.
- PDF open/validation success rate.
- Failed export rate and recovery success rate.
- App crash rate and memory use on representative phones.
- File size and readability for several export presets.
- English and Bangla OCR Character Error Rate (CER) / Word Error Rate (WER).
- Number of user steps/taps in key flows, measured in usability testing.

Do not transmit scanned text, document images, filenames, URLs, or other sensitive content as analytics.

---

## 2. What We Learn from the Six Reference Apps

Feature availability can change by app version, Android/iOS platform, region, plan, account status, and rollout. The table below records feature families described by public product pages and help articles available at review time. It is not a guarantee that every feature is available to every user or free of charge.

### 2.1 Competitor feature map

| Reference app | Useful capability families to learn from | How our app should use the idea |
|---|---|---|
| **Adobe Scan / Acrobat** | Automatic document detection; fast/bulk scanning; straighten/crop; filters and cleanup; OCR/editable text; business-card extraction; folders; PDF/JPEG export; selected AI summaries/Q&A; password options and integration with Acrobat tools. Some tools and capacity are plan-dependent. | Prioritize dependable capture, scan cleanup, page reorder/preview, OCR, and simple document organization. Put AI, conversion, and advanced PDF editing in later phases. |
| **Google Drive scanner** | Scan flow integrated with storage; auto/manual capture; edge outline; crop/rotate and filter adjustments; searchable PDF saved to Drive; a simple capture-to-save flow. | Keep capture simple and allow manual fallback. Save locally first. Add an explicit optional “save/export to Drive” integration only when the user chooses it and the API is implemented. |
| **Genius Scan** | Scanner-first workflow; local/on-device processing emphasized in its privacy information; tags/content search and metadata; smart filename templates; PDF encryption; OCR/searchable PDFs; backup/sync and exports to storage providers in advanced plans. | Use local-first as a product principle; add tags/templates and OCR search once the foundation works; evaluate integrations without requiring an account for local use. |
| **SwiftScan** | Color optimization; PDF/JPEG output; OCR and full-text search; repeatable one-tap workflows; cloud auto-upload/sync options. | Introduce export profiles and saved workflows after core export is stable. Never auto-upload without clear user configuration and consent. |
| **Microsoft OneDrive** | Document, whiteboard, business-card, and photo scan modes; flash control; multi-page capture; crop/rotate/filter; save into OneDrive; OCR capabilities rolling out for selecting/copying scanned PDF text. | Support purpose-specific scan modes where they measurably improve results. Make cloud saving optional; keep local save/export independent. |
| **CamScanner** | Auto-enhancement; OCR and text extraction; PDF/JPEG and selected text/Office outputs; annotations/watermarks; tags and text search; password protection; sharing, printing/fax options and cross-device sync. Some features are premium or account-dependent. | Add annotations, advanced export, PDF protection, and integrations in stages. Treat conversion accuracy and provider costs as explicit release gates. |

### 2.2 Competitor-sourced feature inventory

The full feature plan includes the useful capability families found across all six references:

- Fast and multi-page scanning.
- Auto edge detection and perspective correction.
- Manual crop/rotation as a fallback.
- Color, grayscale, black-and-white, and other enhancement presets.
- Cleanup of minor stains/shadows/fingers where feasible.
- PDF/JPEG export and page arrangement.
- Searchable PDFs, OCR text extraction and text search.
- Document folders, tags, sorting, naming templates and smart renaming.
- Business-card/receipt/invoice extraction.
- Merge/split/extract/reorder PDF pages.
- Compression, PDF encryption/password protection, annotations, highlights and form filling.
- Selected PDF-to-Office/text conversion where quality is acceptable.
- One-tap export workflows and user-configured automation.
- Optional cloud backup and multi-device synchronization.
- Optional printing, storage-provider integrations and business/team features.
- AI summary, translation, and document Q&A as later, consent-based capabilities.

### 2.3 What not to copy

Do not copy any competitor’s source code, trademarks, logos, exact screen layouts, proprietary wording, private APIs, or licensed assets. Reproduce capability categories through original design and implementation. Before claiming a capability is a competitor weakness or advantage, test the current app version and record the plan, OS, date, and observed behavior.

### 2.4 Competitor sources

- Adobe Scan on Google Play: https://play.google.com/store/apps/details?id=com.adobe.scan.android
- Google Drive scanning help: https://support.google.com/drive/answer/3145835?co=GENIE.Platform%3DAndroid&hl=en
- Genius Scan privacy/security overview: https://help.geniusscan.com/security-and-privacy/privacy-and-security-overview
- Genius Scan app listing: https://play.google.com/store/apps/details?id=com.thegrizzlylabs.geniusscan
- SwiftScan features: https://swiftscan.app/en/features.html
- OneDrive Android scanning: https://support.microsoft.com/en-us/onedrive/scan-a-whiteboard-document-business-card-or-photo-in-onedrive-for-android
- OneDrive OCR for scanned PDFs: https://support.microsoft.com/en-us/onedrive/how-to-use-optical-character-recognition-to-read-pdfs-in-onedrive
- CamScanner app listing: https://play.google.com/store/apps/details?id=com.intsig.camscanner

---

## 3. Functional UX Specification — Android First

**This section defines information architecture, screen responsibilities, interactions, and states. It does not claim to reproduce an unavailable visual reference image.** Keep the design touch-friendly, calm, readable, and uncluttered. The camera should prioritize document capture over promotion or secondary tools.

### 3.1 Navigation model

Recommended main navigation:

- **Home:** primary Scan action, Import action, recent documents, unfinished drafts.
- **Documents:** saved document library, folders/tags, search and filters.
- **Tools:** OCR, PDF operations, compression and other tools as they become available. Hide unavailable tools or mark them clearly as planned; do not show fake active buttons.
- **Settings:** appearance, language, storage, privacy, permissions, backup/sync, help, about.

The Scan action should be the strongest primary action and easy to reach. Do not force the user through an account screen before local scanning. Use Android back behavior consistently; warn before leaving a draft that contains unsaved work.

### 3.2 First launch and onboarding

**Purpose:** Explain what the app does and set correct expectations without a long tutorial.

Requirements:
- Explain that core scans are stored locally by default.
- Do not request camera permission until the user starts scanning or selects a feature requiring it.
- Explain why a permission is needed in plain language.
- Explain optional account/cloud/AI features only when relevant; do not present them as mandatory.
- Allow skipping optional setup.
- Provide a route to privacy information and app settings.
- Handle “Don't allow” with a usable import workflow and an explanation of how to enable the permission later.

### 3.3 Home screen

Must provide:
- Primary **Scan document** action.
- **Import** action for gallery images and supported files.
- Recent documents with filename/title, date, page count, and useful status.
- A visible way to reopen an unfinished scan.
- Search entry point.
- A helpful empty state if no documents exist.
- Processing/export errors that can be retried without losing saved pages.

Should not provide:
- Fake statistics or decorative metrics that have no functional value.
- An account wall before basic use.
- Promotions covering the primary action.
- Buttons that lead to empty/placeholder pages without explaining their status.

### 3.4 Camera/capture screen

Required behavior:
- Start camera only after permission and lifecycle checks.
- Show live preview and page boundary when automatic detection is available.
- Support auto capture only when stable detection is reliable; otherwise manual shutter remains available.
- Show flash/torch controls if hardware supports them.
- Show current page count, retake/delete, finish/review, exit, and import fallback.
- Avoid capture while camera is not initialized or after the screen is disposed.
- Handle camera permission revoked in Android Settings.
- On capture, write a temporary file, validate it, commit it to persistent storage, and record it in the database before treating the page as saved.
- When leaving a session, offer resume/discard choices if saved draft pages exist.

### 3.5 Crop and review screen

Required behavior:
- Display the image with four adjustable crop corners when manual correction is supported.
- Correct perspective after corner selection.
- Rotate left/right.
- Reset crop/rotation.
- Retake and confirm actions.
- Keep the original source even if crop processing fails.
- Validate that crop corners are within image bounds and ordered consistently.
- If automatic edge detection confidence is low, show the image and let the user crop manually instead of blocking the flow.

### 3.6 Multi-page organizer

Required behavior:
- Show page thumbnails and total count.
- Add more pages.
- Reorder by drag-and-drop with an accessible alternative where practical.
- Rotate, replace/retake, edit, duplicate (optional), and delete a page.
- Confirm destructive actions when they might cause data loss.
- Persist ordering after every confirmed reorder; store ordering in `page_order`, not filenames.
- Continue to export even if OCR is pending or failed.

### 3.7 Page enhancement/editor

Initial controls:
- Original.
- Auto/color enhancement (only if tested).
- Grayscale.
- Black-and-white.
- Rotation/crop.
- Brightness/contrast only after predictable behavior is available.
- Reset and restore original.
- Before/after preview where practical.

Later controls:
- Shadow/glare reduction.
- Background whitening.
- Denoise/sharpen.
- Stain/finger cleanup.
- Book-page flattening.
- Document-type-specific presets.

Do not promise that cleanup can recover hidden or uncaptured detail. Never silently erase stamps, signatures, handwriting, diagrams, colored notes, or meaningful background information.

### 3.8 Save/export screen

MVP options:
- Filename.
- PDF or JPEG output.
- Page order/selected range if implemented.
- Quality/size option with simple explanation, not unexplained technical controls.
- A4 or source-aspect sizing where appropriate.
- Preview before export.
- User-selected output location using Android's document picker or a safe in-app library location.
- Share after successful export.

Later options:
- Searchable PDF.
- OCR text sidecar/TXT export.
- PDF compression presets.
- Password encryption.
- Watermark/page numbers.
- PDF/A and Office conversions only after validation.

Do not show “Saved” until the output is verified. Do not overwrite an existing export silently. If export fails, preserve the draft and offer Retry.

### 3.9 Document viewer

MVP:
- Display the saved PDF or page sequence.
- Zoom/page navigation.
- Show name, date, page count and file size if available.
- Rename, share/export, favorite, duplicate if implemented, move if folders are implemented, and delete.
- Show clear missing/corrupted-file messages.

Later:
- Search recognized text.
- Highlight search results.
- Bookmarks and PDF annotations.
- Form field editing when supported by the PDF engine.
- Safe redaction, if it can remove underlying content rather than just hiding it visually.

### 3.10 Library and search

MVP:
- Recent/All documents.
- Filename search.
- Sort by newest, oldest, name, and file size.
- Filter by folder or favorite when those features are present.
- Empty, loading, permission, and database-error states.

Later:
- Tags and nested folders.
- OCR full-text search.
- Document type/date filters.
- Search snippets with page references.
- Duplicate detection using hash and optional visual similarity.
- Saved searches, bulk actions and smart categories.

### 3.11 Trash/recovery

- Prefer soft delete first: set `deleted_at` instead of immediately deleting files.
- Provide restore and permanent deletion as distinct operations.
- Show whether the original scan, processed cache, export, or all copies will be deleted.
- A recovery mechanism must account for app crashes during deletion.
- Permanent deletion should be clearly explained; do not claim forensic secure deletion on flash storage without evidence.

### 3.12 Settings, privacy and storage

Include:
- Preferred export type and quality.
- Default scan filter.
- Theme and app language.
- OCR language preferences (when OCR exists).
- Storage usage and cache cleanup controls.
- Permissions help.
- Privacy policy/data practices.
- Backup/sync settings only after those features exist.
- App lock/biometrics only after correct platform security integration.
- Export all user data and delete account/cloud copies once accounts exist.

### 3.13 UX quality rules

- Thumb-friendly controls and readable labels.
- System text-size accommodations where feasible.
- Screen-reader labels for icon-only controls.
- Visible progress for long tasks.
- Clear disabled states and actionable errors.
- Color must not be the only warning indicator.
- Respect Android back navigation and lifecycle.
- Avoid unnecessary animations and respect reduced-motion preferences when supported.
- Keep the capture screen uncluttered.
- No visually active control may be a no-op.

---

## 4. Complete Feature Requirements

### 4.1 Capture and import

**P0**
- Camera capture.
- Manual capture.
- Single and multi-page scan session.
- Save page immediately after capture.
- Manual crop fallback.
- Camera/gallery import.
- Review pages before final PDF.
- Retake/delete a page.
- Recover drafts after app interruption.
- Support JPG/JPEG and PNG image imports where practical.
- File-size and format validation.

**P1/P2**
- Auto capture with stable edge detection.
- Flash/torch.
- Blur, low-light and incomplete-page warnings.
- Receipts, invoices, notes, book pages, ID cards, business cards, whiteboards and forms as specialized modes.
- Batch capture and optional capture shortcuts.
- Curved-book flattening, glare/shadow cleanup and advanced cleanup after testing.

**Import boundaries**
- Use Android system file picker/Storage Access Framework for user-selected files.
- Do not request broad file permissions when a system picker provides the necessary access.
- Check the actual MIME/content rather than trusting only the filename extension.
- Preserve the imported source or make the preservation policy explicit.
- Treat corrupted/unsupported files as errors, not empty successful imports.

### 4.2 Image-processing pipeline

Recommended logical pipeline:

1. Acquire camera image or import source.
2. Read and normalize EXIF orientation.
3. Decode only the resolution needed for the current operation.
4. Detect page boundary; return confidence score when available.
5. Apply manual/automatic crop and perspective correction.
6. Apply selected filter and enhancement recipe.
7. Verify output dimensions and decode validity.
8. Save processed output to a temporary file.
9. Commit atomically and update the database.
10. Invalidate thumbnail/OCR caches if the relevant source or edit recipe changed.

Terms:
- **Edge detection:** identifies boundaries between regions, e.g. a page edge.
- **Quadrilateral/corners:** four page boundary points.
- **Perspective transform / homography:** maps a skewed four-corner page into a rectangular view.
- **Deskew:** corrects small angular tilt.
- **EXIF orientation:** image metadata that tells software how a photo should be rotated.
- **DPI/PPI:** image resolution relevant to print/OCR; avoid blindly upscaling low-resolution images and pretending detail was recovered.
- **Binarization:** converts an image to black/white. Otsu is a global threshold technique; adaptive methods handle uneven lighting better in some cases.

Keep the pipeline modular. Begin with capabilities already offered by the chosen scanner engine; add custom OpenCV/native processing only when there is a tested requirement.

### 4.3 Non-destructive edit model

Store an **edit recipe** rather than overwriting the original image. Example:

```json
{
  "schemaVersion": 1,
  "cropNormalized": [[0.05, 0.04], [0.95, 0.04], [0.96, 0.96], [0.04, 0.96]],
  "rotationDegrees": 0,
  "filter": "grayscale",
  "brightness": 0.0,
  "contrast": 1.0
}
```

Coordinates here are normalized examples, not final implementation constants. Define and test the coordinate convention before implementation.

Logic:
- Original image + edit recipe → processed image.
- Reset clears the recipe or restores its default.
- Changing crop/orientation/filter invalidates processed-image cache.
- Changing image content or geometry invalidates OCR for that page.
- UI displays the current saved/unsaved edit state accurately.
- If re-render fails, preserve the last successfully processed output and the original.

### 4.4 PDF creation

**P0: image pages to PDF**
- Multi-page PDF output.
- Page order matches organizer order.
- A4 and/or source aspect ratio; avoid distortion.
- Orientation correct.
- Compression/quality defaults chosen by test.
- JPEG images embedded without unnecessary double-compression when supported by the library.
- Preview generated PDF.
- Export one page as JPEG.
- Write output to a temporary path and validate before committing.
- If filename exists, ask or choose a collision-safe name rather than silently overwriting.

**Export algorithm**

1. Load document and pages ordered by `page_order`.
2. Validate that the source or processed image exists for every selected page.
3. Normalize orientation.
4. Process pages sequentially or in a small bounded batch to control memory.
5. Generate PDF page with the correct dimensions and aspect ratio.
6. Write to `name.pdf.tmp` (or a unique temporary path).
7. Validate the completed output by reopening/parsing it where supported and checking page count.
8. Atomically rename/move the temporary output to the final name.
9. Store export metadata and report success only after commit.
10. On any failure, remove incomplete temporary output and preserve the original scan/draft.

**Later PDF operations**
- Merge files.
- Split by page ranges.
- Extract selected pages.
- Reorder, rotate, insert, duplicate, replace and delete pages.
- Compress with a preview/size estimate.
- Set page numbers, headers/footers and watermarks.
- Add highlights, text notes, drawings, stamps and image signatures.
- Fill interactive forms when supported.
- Password-protect/encrypt exported PDF.
- PDF/A for archival use, if validated.
- PDF to DOCX/XLSX/PPTX/TXT/image only when conversion quality, licensing, and dependencies are acceptable.

**PDF terminology**
- **MediaBox:** PDF page's physical page boundary; common PDF units are points, with 72 points per inch. A4 is approximately 595 × 842 points.
- **Image XObject:** an image embedded in PDF content.
- **OCR text layer:** selectable/searchable text positioned over or alongside a page image.
- **PDF/A:** family of PDF archival standards; separate validation is needed to claim compliance.
- **Redaction:** securely removes underlying content; a black rectangle drawn over text is not real redaction.
- **Image signature vs digital signature:** a picture of a signature is not equivalent to a certificate-backed cryptographic digital signature.

### 4.5 OCR (Optical Character Recognition)

**P1 target:** English OCR; Bangla OCR only after benchmarking.

Requirements:
- OCR should never be required to save, view, export or share the original document.
- Recognize one page at a time and run heavy work as background processing where suitable.
- Store page-level text, language, engine/model version, timestamp, status, and word/line boxes if returned.
- Let users inspect and correct OCR text.
- Copy recognized text.
- Search indexed OCR text.
- Build searchable PDFs only when the engine provides enough coordinates to position text correctly.
- Ensure Unicode Bangla text and font shaping/copying behave correctly.
- Support retry after failure without creating duplicate records.
- OCR jobs should be cancelled or invalidated if the underlying processed image changes.

**Engine decision**
- Evaluate ML Kit for languages it currently supports well, particularly English.
- Bengali/Bangla is not listed among ML Kit Text Recognition v2's currently enumerated supported language entries reviewed for this plan. Tesseract provides Bengali trained data (`ben`), but that availability does not guarantee production-quality results in every document. Compare both engine candidates and any other feasible engines with real samples.
- Keep an `OcrEngine` interface so an engine can be changed without rewriting search or document services.
- Decide whether each engine is local/offline, its model size, performance, license, maintenance, and supported Android versions.

Example logical interface:

```dart
abstract interface class OcrEngine {
  Future<OcrResult> recognize({
    required File image,
    required String languageCode,
  });
}

class OcrResult {
  final String text;
  final List<OcrBlock> blocks;
  final String engineVersion;
  // Add confidence/status fields when the chosen engine exposes them.
}
```

This is architectural pseudocode; it is not compiled implementation code.

**OCR quality tests**
- Printed English.
- Printed Bangla.
- Mixed Bangla + English.
- Numbers, dates, currency, tables and multi-column layouts.
- Small text, low light, blur, skew, shadows, colored backgrounds and compression artifacts.
- Camera images and imported PDFs/images.

Measure **CER (Character Error Rate)** and **WER (Word Error Rate)** against manually checked ground truth. Record each category separately; do not rely on anecdotal examples. Handwriting recognition remains experimental unless specifically benchmarked.

### 4.6 Bangla search and Unicode

Bangla characters may use composed/decomposed Unicode sequences. Apply a consistent Unicode normalization policy such as NFC before indexing and querying; validate this on real Bangla data. SQLite FTS5 can be evaluated for full-text indexing, but its tokenizer behavior for Bangla must be tested rather than assumed. If the tokenizer segments terms poorly, use a dedicated search-normalization/indexing strategy.

For a searchable PDF with Bangla text, confirm that:
- An appropriate Unicode font is embedded or otherwise reliably available.
- Glyph shaping is correct.
- Text selection/copy produces useful Unicode.
- Word boxes align with the visible text.
- Searching across Bangla conjuncts/marks works after normalization.

### 4.7 Document library and management

**P0**
- Recent/all documents.
- Stable document identity independent of filename.
- Filename search, rename, preview, sort, favorite, export/share, delete.
- Show creation date, page count, size when known.
- Missing/corrupt file state.
- Recovery of unfinished drafts.

**P1/P2**
- Nested folders.
- Tags/labels.
- Smart filename templates, e.g. user template based on date/type.
- Suggest a filename from OCR or document metadata, with user confirmation.
- Batch operations.
- Duplicate detection using SHA-256 file fingerprint; optional perceptual hashing for visual duplicates after privacy/performance evaluation.
- Trash with configurable retention (proposed default: 30 days, confirm in user settings/product requirements).
- Export/import manifest and recovery tools.

### 4.8 Export, system sharing, and printing

- PDF and JPEG export first.
- TXT/OCR export after OCR works.
- Android Sharesheet support to send a file to installed apps.
- Use content URIs / `FileProvider` or approved platform APIs rather than exposing raw private file paths.
- Use Storage Access Framework for user-chosen save locations where suitable.
- Print integration can be added later and tested against Android's print framework/providers.
- Remote fax is optional and requires a provider, cost/privacy analysis, regional availability review, and clear user confirmation.
- Share/export must not automatically upload to a cloud service unless the user explicitly selects that target.

### 4.9 AI and document intelligence — later phase

Potential capabilities:
- Summarize a user-selected document.
- Generate key points or study notes.
- Ask questions about a document and cite relevant page numbers/sections where available.
- Translate recognized text (Bangla ↔ English is a potential priority; quality needs review).
- Suggest filename, category, date, receipt/invoice number, merchant, totals or contact details.
- Extract table data into CSV/XLSX where accuracy is acceptable.
- Detect likely document type and suggest a folder/tag.

Rules:
- Ask before sending document content to an online service.
- Explain provider/model, data flow, and possible cost in understandable wording.
- Never imply generated summary/Q&A is guaranteed correct.
- Show source snippets/page references for answers whenever possible.
- Allow user review/correction before saving extracted business data.
- Provide a local-only alternative where possible, or clearly mark a feature as online-only.
- Provide retry and cancel; AI failures do not affect original files.

### 4.10 Optional cloud and cross-device sync — later phase

Required if built:
- Explicit opt-in account setup.
- Upload/download queue and status.
- Pause/resume/retry for interrupted transfers.
- Choose which documents and data types sync.
- Device/session list and sign-out.
- Version/conflict detection; never silently overwrite one version with another.
- Backup verification and restore testing.
- Storage quota and data-retention rules.
- Account and cloud-data deletion path.
- Encrypted network transport.
- Key management, authentication, authorization, and threat modeling.
- Clear privacy disclosure for metadata, OCR text, thumbnails, filenames and originals.

Do not promise end-to-end encryption unless keys remain under user control and the design is implemented and independently reviewed. TLS/HTTPS alone is transport encryption, not end-to-end encryption.

### 4.11 Security and privacy

MVP principles:
- No mandatory account.
- No automatic upload of scans.
- No document-content analytics or diagnostic logging.
- Store source files in app-private storage by default, with explicit user-controlled export.
- Request only the permissions required for the chosen implementation.
- Avoid broad storage permissions when a picker/provider can grant access to selected files.
- Clean up temporary files with recovery-aware logic.
- Use Android system-secure storage for sensitive tokens/secrets if any are introduced.
- Review dependencies, licenses, network behavior, and app permissions before release.
- Explain the consequence of uninstalling the app: app-private files may be removed; encourage user export/backup of documents they expect to retain.
- Keep export paths and filenames free from unexpected data leakage in logs.

Later:
- App lock/PIN/biometrics using platform-approved APIs.
- Encryption at rest for specific sensitive material when threat model and implementation justify it.
- Encrypted PDF export.
- True PDF redaction.
- Data-retention controls and optional encrypted backup archive.

**Important distinction:** A document stored only in an app-private directory may be removed when the app is uninstalled. Files users expect to keep independently should be exported to user-selected/shared storage or backed up with consent.

### 4.12 Accessibility, localization and quality

- Screen-reader semantics/labels for icon actions.
- Minimum touch-target dimensions aligned with platform guidance.
- Sufficient contrast and non-color-only status.
- Dynamic text sizing where practical.
- English UI first; Bangla UI can be added with careful human review.
- UI localization and Bangla OCR are separate delivery items.
- Date/number/currency formatting should not assume one locale.
- Test long text, mixed-language filenames, Bangla search, orientation, and small screens.

---

## 5. Android-First Technical Architecture

### 5.1 Recommended baseline stack

| Layer | Candidate | Rationale / decision gate |
|---|---|---|
| Application framework | Flutter + Dart | Shared Android/iOS code and possible later Windows reuse; isolate platform APIs behind adapters. |
| State management | Choose one: Provider, Riverpod, or another consistent solution | Do not use several competing state-management patterns without reason. |
| Navigation | Flutter Navigator or `go_router` | Keep routes typed/centralized where useful; choose one. |
| Local relational database | SQLite via Drift | Document metadata, pages, tags, jobs, OCR status and migrations. Validate mobile setup and future desktop compatibility. |
| File paths/directories | `path_provider` plus Android file APIs | Store original/processed files separately from database rows. |
| Camera/scanner | Android ML Kit Document Scanner API integration OR CameraX/custom capture pipeline | Test both only enough to make an evidence-based choice; do not commit before verifying output access, lifecycle and offline expectations. |
| Image processing | Native scanner tools first; OpenCV/custom operations only as required | Minimize custom CV work until there is a verified need. |
| PDF generation | Dart `pdf` package as a candidate | Prototype multi-page and large-file outputs. This does not automatically supply every advanced existing-PDF editor feature. |
| Existing PDF editing | Separate PDF engine/library if required | Evaluate page operations, annotations, encryption, form handling, license, platform support and cost individually. |
| OCR | `OcrEngine` interface with separately tested engines | Engine can be replaced without changing the document domain model. |
| Sharing/import | Android Sharesheet, Storage Access Framework and carefully selected Flutter plugins | Keep file access user-controlled. |
| Background jobs | App job manager; Android WorkManager integration when justified | Use durable jobs for long work when platform limits permit; do not assume every job can continue indefinitely in the background. |
| Cloud/backend | None for MVP | Introduce only when sync or online AI is an approved product decision. |

Flutter platform support: https://docs.flutter.dev/reference/supported-platforms  
Flutter architecture recommendations: https://docs.flutter.dev/app-architecture/recommendations  
Drift (SQLite): https://pub.dev/packages/drift  
Dart PDF package: https://pub.dev/packages/pdf

### 5.2 Scanner engine decision: native scanner vs custom camera

**Option A — Android ML Kit Document Scanner API**

Potential benefits:
- Provides a built-in scanning UI and document edge/crop/filter workflow.
- Can return JPEG pages and/or a PDF depending on options.
- On-device scanning processing.
- Avoids implementing every edge/camera detail from scratch.

Constraints to validate:
- The UI is provided by the API and is less customizable than a wholly custom camera screen.
- Models, scanning logic and UI resources are dynamically delivered through Google Play services; first use may need a download/initialization step.
- Current official docs list Android API level 21+ and a minimum total RAM requirement, but the app’s actual Flutter and dependency versions may require a higher baseline. Choose the Android minimum after testing the complete stack.
- Check the exact returned content URIs/files, page ordering, persistence rights, error/cancel handling and compatibility with the desired UX.
- Design a fallback if the scanner service is unavailable or unsupported on a device.

Official docs: https://developers.google.com/ml-kit/vision/doc-scanner/android

**Option B — Custom camera with CameraX via native Android integration**

Potential benefits:
- Full control over the capture-screen design and camera interaction.
- Can integrate a custom edge outline, guidance, and draft-saving model.

Costs/risks:
- More engineering for camera lifecycle, edge detection, perspective transform, manual corners, image cleanup, blur checks and device compatibility.
- More test cases and risk of quality differences across Android phones.
- Camera, CV and storage code must be carefully separated from Flutter UI.

CameraX photo capture docs: https://developer.android.com/media/camera/camerax/take-photo

**Decision procedure:** build a small proof of concept for each feasible approach. Compare whether page images are retrievable, UI flexibility, first-use network needs, offline fallback, quality, crash behavior, package maintenance, license, and engineering effort. If exact scanner-screen visual matching is essential, custom capture may be necessary. If speed and proven scanning behavior matter more, native scanning may be the better MVP choice. Record the decision and reasoning in the repository.

### 5.3 Architecture pattern

Use a practical separation of concerns:

```text
Presentation (screens/widgets)
        ↓ events / state
View models / controllers
        ↓ use cases
Domain models + use cases
        ↓ interfaces
Repositories and services
        ↓
SQLite (metadata) + local file storage + platform adapters
```

Feature modules:

- `scanner`: camera/scanner adapter, capture sessions, page capture.
- `page_editor`: edit recipe, crop/rotate/filter preview.
- `documents`: library, folders, tags, search, trash.
- `pdf`: PDF creation and later editing adapters.
- `ocr`: engine interface, OCR jobs, results and language validation.
- `export`: destination chooser, sharing, collision handling and verification.
- `settings`: local settings, privacy, theme, language.
- `core`: errors, logging policy, permissions, storage, file checks, IDs and utilities.

### 5.4 Suggested repository structure

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme/
    localization/
  core/
    errors/
    logging/
    permissions/
    storage/
    file_system/
    ids/
    utils/
  features/
    scanner/
      data/
      domain/
      presentation/
    page_editor/
      data/
      domain/
      presentation/
    documents/
      data/
      domain/
      presentation/
    pdf/
      data/
      domain/
      presentation/
    export/
      data/
      domain/
      presentation/
    ocr/
      data/
      domain/
      presentation/
    settings/
      data/
      domain/
      presentation/
  shared/
    models/
    services/
    widgets/
test/
integration_test/
assets/
docs/
```

Only create files when a feature actually needs them. Keep the project understandable for one developer; this is a guideline, not a requirement to implement every folder on day one.

### 5.5 Background processing and memory

- Heavy image transformations, PDF creation, hashing and OCR must not block user interaction.
- In Dart, use isolates or suitable background/plugin execution for CPU-heavy pure-Dart work where appropriate; native plugins have their own threading constraints and cannot automatically be called from every isolate.
- Decode thumbnails at reduced resolution.
- Keep only the current page at full resolution where practical.
- Process PDF pages sequentially or in small bounded batches.
- Show progress and allow cancellation if the underlying operation can safely stop.
- Persist long-running job state so the app can show a failed/pending task after restart.
- Use Android WorkManager only where it fits its execution/foreground-service constraints; do not assume it grants unlimited background processing.

---

## 6. Storage Model, Database and State Logic

### 6.1 Local storage layout

Example only; use platform-safe paths from Android APIs rather than hard-coded absolute paths.

```text
app-data/
  originals/
  processed/
  exports/
  thumbnails/
  ocr-cache/
  temporary/
  recovery/
```

**Originals** are captured/imported source images. **Processed** files are renderable derivatives. **Exports** are finalized output files that the user selected to save into the app library. **Temporary** contains incomplete work that is never shown as a successful output. Avoid duplicating the same large image unnecessarily, but never sacrifice recoverability for minor storage savings.

### 6.2 Initial database entities

```sql
-- Pseudocode schema. Final SQL types, constraints and migration code must be implemented/tested.

documents(
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  modified_at INTEGER NOT NULL,
  status TEXT NOT NULL,
  page_count INTEGER NOT NULL DEFAULT 0,
  folder_id TEXT NULL,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  deleted_at INTEGER NULL,
  export_path TEXT NULL
);

pages(
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  page_order INTEGER NOT NULL,
  original_path TEXT NOT NULL,
  processed_path TEXT NULL,
  edit_recipe_json TEXT NOT NULL,
  sha256 TEXT NULL,
  width INTEGER NULL,
  height INTEGER NULL,
  status TEXT NOT NULL,
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
);

folders(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  parent_id TEXT NULL,
  created_at INTEGER NOT NULL
);

tags(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

document_tags(
  document_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  PRIMARY KEY(document_id, tag_id),
  FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
  FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

ocr_results(
  id TEXT PRIMARY KEY,
  page_id TEXT NOT NULL,
  language_code TEXT NOT NULL,
  text_content TEXT NOT NULL,
  boxes_json TEXT NULL,
  engine_id TEXT NOT NULL,
  engine_version TEXT NULL,
  status TEXT NOT NULL,
  updated_at INTEGER NOT NULL,
  FOREIGN KEY(page_id) REFERENCES pages(id) ON DELETE CASCADE
);

jobs(
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  target_id TEXT NOT NULL,
  status TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error_code TEXT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  next_run_at INTEGER NULL
);

export_history(
  id TEXT PRIMARY KEY,
  document_id TEXT NOT NULL,
  format TEXT NOT NULL,
  output_path TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
```

This is a reference schema, not ready-to-run production SQL. Add indices, CHECK constraints, database versioning and migrations. Choose whether deleted documents keep page rows for trash recovery; do not combine soft delete with cascading hard-delete behavior accidentally.

Recommended indexes:
- `pages(document_id, page_order)`.
- `jobs(status, next_run_at)`.
- `documents(modified_at)` and other fields used in sorting.
- Full-text index for OCR only after tokenizer/language tests.

### 6.3 Key database rules

- Use UUIDs (stable unique IDs) instead of filenames as primary keys.
- Apply schema versioning and migrations; app updates must not wipe user documents.
- Use transactions for related metadata changes.
- Enable/check foreign-key enforcement.
- Consider SQLite WAL mode after validating the selected database package and recovery behavior.
- Treat file paths and stored values as untrusted because files can be removed externally, storage may be corrupt, and older app versions may have different schemas.
- A database row is not proof that a file exists; verify it before opening/exporting.

### 6.4 Save-before-proceed algorithm

```text
capture/import image
  → write unique temporary file
  → flush/close file
  → verify that image decodes and dimensions are valid
  → optionally calculate SHA-256 checksum
  → atomically rename into originals/<page-id>.<ext>
  → database transaction inserts/updates page and draft metadata
  → update UI to show page as saved
```

If any step fails:
- Do not show success.
- Do not replace the last good original.
- Delete temporary artifacts when safe or retain them in recovery if necessary.
- Report the failure and allow Retry.
- Reconcile file/database state at the next startup.

Atomic rename behavior depends on filesystem location; create the temporary file on the same filesystem/directory where possible. A database transaction cannot make a file operation and a database commit one truly atomic transaction; the design must account for crashes between steps using job states and startup reconciliation.

### 6.5 State machines

Document lifecycle example:

```text
new → draft → ready → exporting → exported
            ↘ failed/recovery
any retained state → trashed → purged
```

Page lifecycle example:

```text
capturing → captured → edit_pending → processed
                    ↘ processing_failed → retry
```

OCR job example:

```text
queued → running → done
                 ↘ failed → retry (bounded) → failed_final
```

State changes must be validated and persisted. Do not let the UI say `exported` while the file is still being written. Running a job twice should not create duplicate exports or duplicate OCR rows: design idempotent operations.

### 6.6 Startup reconciliation

At app start or in a controlled recovery task:
- Find temporary files older than a conservative cutoff; delete only when known to be abandoned and not referenced by an active job.
- Identify files without database rows; move recoverable ones to a recovery area or present a recovery action rather than deleting blindly.
- Identify rows whose files are missing; mark them unavailable and show a useful error.
- Restore resumable drafts from persisted page rows.
- Reconcile incomplete export/OCR jobs.
- Never silently destroy valid user data as a “repair.”

---

## 7. Android Platform Details

### 7.1 Permissions

- Request camera permission only if the chosen custom camera pipeline needs it. ML Kit Document Scanner may use the permission handled through Google Play services, so validate the exact selected approach.
- Use system file picker for selected images/PDFs where possible.
- Avoid broad storage permissions without a demonstrated requirement.
- Ask for notification permission only if meaningful user-visible background notifications are implemented and needed.
- Explain optional account/network permissions or access at the feature point that needs them.

### 7.2 Storage Access Framework and export

Use Android's Storage Access Framework/system picker when letting a user choose an import or destination. Keep working files in app-private storage. Export copies into user-selected/shared storage when the user expects them to remain available independently of the app. Do not assume app-private files survive uninstall.

Android references:
- App-specific storage: https://developer.android.com/training/data-storage/app-specific
- Storage Access Framework: https://developer.android.com/guide/topics/providers/document-provider

### 7.3 App lifecycle

Handle:
- App backgrounded during camera session.
- Activity/process killed during export/OCR.
- Camera unavailable because another app is using it.
- Device rotation/configuration change.
- Permission revoked while app is not running.
- OS memory pressure.
- Storage almost full.
- App update and database migration.

### 7.4 Offline behavior and first-use caveat

Core library, page correction, PDF generation and local export should function offline. Some third-party document-scanning APIs may download components on first use; if the app chooses one, it must test and explain first-use behavior and provide a manual/custom fallback if offline first-use is an actual product requirement. Online AI, cloud backup and web services must be optional and must never block local document access.

Android offline-first guidance: https://developer.android.com/topic/architecture/data-layer/offline-first

---

## 8. Error Handling and Reliability Requirements

### 8.1 Capture errors

- Permission denied/revoked.
- Camera initialization failed.
- Capture cancelled.
- Insufficient storage.
- Image write or decode failed.
- Unsupported scanner API/device.
- Automatic edge detection failed or confidence too low.

Expected behavior: recover where possible, show a plain-language message, preserve earlier pages and allow manual capture/import.

### 8.2 Processing errors

- Image decode/crop/transform fails.
- Output image is too large or not valid.
- OCR engine not available or language model missing.
- User exits during processing.

Expected behavior: preserve original and last known-good derivative; allow retry or skip OCR; never block access to the source.

### 8.3 Export errors

- Destination not writable or permission expired.
- Filename collision.
- Device runs out of storage.
- PDF generator throws an exception.
- Exported PDF cannot be reopened/validated.

Expected behavior: keep draft data; remove or quarantine incomplete output; explain exact safe next action; never report success early.

### 8.4 Import/security errors

- Unsupported MIME type.
- Extension does not match actual content.
- Corrupted or hostile file content.
- Very large image/PDF.
- File provider disappears or access is revoked.

Expected behavior: validate at boundaries, enforce reasonable file size limits, fail safely, and do not crash the whole library.

---

## 9. Testing and Acceptance Criteria

Testing must be planned before implementation. Use unit tests, widget tests, integration tests and physical-device tests. Flutter testing guidance: https://docs.flutter.dev/testing/overview

### 9.1 Unit tests

- Filename collision handling.
- Stable ID generation.
- Page ordering and reorder persistence.
- Edit-recipe validation and cache invalidation.
- Document/page/job state transitions.
- Repository logic and database migrations.
- Export status/error handling.
- OCR normalization and indexing.
- Duplicate detection logic if added.

### 9.2 Widget tests

- Home empty/recent states.
- Permission-denied messaging.
- Page review, delete confirmation and retake interactions.
- Export options and progress/error/retry states.
- Library search and sort.
- Trash restore/permanent-delete confirmation.
- Accessibility semantics and large text where practical.

### 9.3 Integration/device tests

- Capture one page → save → restart → reopen.
- Capture 5+ pages → reorder → export → verify PDF page order.
- Apply a filter → restore original.
- Import image → export PDF.
- Deny camera permission → import remains usable.
- Interrupt export → no corrupt final PDF and no lost draft pages.
- Run with airplane mode enabled.
- Run with low storage or simulate write failure.
- Verify system share/export behavior.
- Open exported PDF in a separate PDF reader.
- Test small screens, different camera capabilities, older supported Android hardware, and different OS versions.

### 9.4 OCR quality tests

Build a private, consented or synthetic test corpus with manually verified reference text. Test English, Bangla and mixed documents separately. Report CER/WER and document category. Do not send test content to cloud services unless intentionally approved for that test.

### 9.5 Required release rules

- Reordering changes `page_order`, not original filenames.
- Same original + same edit recipe should produce equivalent expected page output within any documented lossy processing behavior.
- Re-export never silently overwrites the previous export.
- App/process termination during export leaves no corrupt output marked as finished.
- OCR failure never blocks save, PDF export or sharing.
- Missing files are not shown as valid/openable documents.
- Core scanning/export works with no sign-in and no ordinary network connection, subject to clearly documented first-use component requirements of the chosen scanner engine.
- No private document content is uploaded unexpectedly.

### 9.6 MVP completion checklist

- [ ] Android app builds and opens on a physical phone.
- [ ] Camera permissions are handled correctly.
- [ ] A single page can be captured and persisted.
- [ ] Multiple pages can be captured, reviewed and reordered.
- [ ] Page crop, rotation and basic filter work.
- [ ] Original capture remains recoverable after editing.
- [ ] One multi-page PDF can be generated, validated and opened externally.
- [ ] JPEG export works for a page.
- [ ] Document library survives restart.
- [ ] Filename search, rename, share and delete work.
- [ ] Failed save/export leaves the source safe and offers recovery.
- [ ] Low storage and permission errors do not crash the app.
- [ ] Core flow works offline under the stated scanner engine constraints.
- [ ] No feature is advertised as implemented if it is actually a placeholder.

---

## 10. Roadmap and Deliverables

Move to the next phase only when the current one meets its acceptance criteria. The sequence below is a dependency order, not a delivery-time promise.

### Phase 0 — Technical proof of concept

**Tasks**
- Confirm Flutter/Android build environment.
- Prototype candidate scanner engine(s).
- Confirm JPEG page output and persistence.
- Create a PDF from several images and validate it externally.
- Run initial English and Bangla OCR samples.
- Review dependency maintenance, license and platform constraints.

**Deliverable:** a small runnable prototype and a written technical decision log.

### Phase 1 — Foundation

**Tasks**
- Git repository, `.gitignore`, README, formatting, linting and test harness.
- App shell, navigation and screen states.
- Local file storage and database schema/migrations.
- UUIDs, temporary-file policy, error handling and privacy-safe logging.

**Deliverable:** app saves/reopens test files after restart.

### Phase 2 — Capture and drafts

**Tasks**
- Capture one page.
- Save page before proceeding.
- Multi-page drafts.
- Retake/delete and session resume.
- Permission/lifecycle/recovery handling.

**Deliverable:** multi-page scan can survive app restart without losing committed pages.

### Phase 3 — Correction and page organizer

**Tasks**
- Crop, perspective correction, rotation, filters.
- Edit recipes and cached processed files.
- Thumbnail generation and page ordering.

**Deliverable:** user corrects and reorders a multi-page document while keeping originals.

### Phase 4 — PDF/JPEG export and library

**Tasks**
- PDF generation and validation.
- JPEG export.
- Filename collisions, destination selection, share.
- Library, filename search, sort, rename, favorite and delete/trash.

**Deliverable:** complete scan-to-save-to-find-to-share MVP flow.

### Phase 5 — Reliability release

**Tasks**
- Device test suite, low-storage tests, startup reconciliation.
- Fix data-loss, memory and scan-quality issues.
- Build test APK and collect feedback from real users.

**Deliverable:** Android MVP release candidate; no unresolved critical data-loss issue in the tested scope.

### Phase 6 — OCR and searchable documents

**Tasks**
- English OCR engine integration.
- Bangla OCR benchmark and selected engine integration if quality passes.
- Page-level OCR store, text correction, copy, search index, retry states.
- Searchable PDF only if font and word-coordinate tests pass.

**Deliverable:** users can search recognized text in supported test documents.

### Phase 7 — Advanced PDF Pro tools

**Tasks**
- Merge/split/extract.
- Reorder/rotate/insert/replace pages in imported PDFs.
- Compression and quality comparison.
- Encryption/password protection.
- Annotations/highlights/forms according to library capabilities.

**Deliverable:** each advertised tool has its own tests and library/license validation.

### Phase 8 — Smart features and optional services

**Tasks**
- Smart names/categories and receipt/invoice extraction.
- AI summaries/translation/Q&A with consent and source references.
- Cloud sync prototype, upload queue, conflict UI, backup/restore.
- Cost and privacy review.

**Deliverable:** each online capability is optional, disclosed, recoverable, and cost-limited.

### Phase 9 — iOS release

**Tasks**
- iOS scanner adapter and permission/lifecycle behavior.
- File import/export and share testing.
- Layout/accessibility/release testing.

**Deliverable:** tested iOS version; do not assume Android plugins work identically.

### Phase 10 — Windows desktop

**Tasks**
- Reuse domain services where practical.
- Desktop file dialogs, drag/drop, batch queue, keyboard shortcuts.
- Large files, directory monitoring (optional), physical scanner/webcam integration only if researched and validated.

**Deliverable:** real desktop workflow, not a stretched mobile layout.

---

## 11. Free / Pro / Business Plan Proposal

Do not finalize prices until user research and cost modelling are complete. Avoid locking people out of their existing documents because a subscription expires.

| Edition | Proposed scope |
|---|---|
| **Free** | Local scanning; essential page correction; multi-page PDF/JPEG; local library; filename search; standard sharing/export; offline basic workflow; no mandatory account; no watermark on basic export as a product-value hypothesis to validate. |
| **Pro** | Advanced PDF editing; OCR/full-text search quotas; searchable PDF; compression; PDF protection; annotations/forms; smart filename templates; automation/batch features; advanced conversions only where reliable; optional online AI quotas and expanded sync/storage if offered. |
| **Business/Team (later)** | Shared/team libraries; role-based permissions; centralized billing/licenses; admin/device policies; batch workflows; receipt/invoice data extraction; support commitments. |

Costs to model before enabling paid services:
- Cloud storage, bandwidth, and backup retention.
- Online AI and OCR usage.
- PDF/conversion library licenses.
- App-store billing and support overhead.
- Security review and privacy compliance.
- Customer-support workload.

---

## 12. Project Management Rules for Antigravity / AI Coding Tools

Use this file as the product source of truth. When asking an AI coding agent to implement a task:

1. State the exact phase and one feature to implement.
2. Ask it to inspect the existing repository before editing.
3. Ask it to check the Git working tree and preserve user changes.
4. Ask it to identify required files/packages and explain the plan briefly.
5. Require implementation, tests and actual command output.
6. Require an acceptance checklist for normal, error and recovery paths.
7. Ask it to review the diff for unintended changes and verify the final code.
8. Do not let it claim tests/build/runtime verification if it did not run them.
9. Do not ask it to build every feature in one giant generation step.
10. Keep main branch buildable; commit after small verified units of work. Do not force-push or discard local changes to resolve errors.

### GitHub task template

```markdown
## Feature
[Name]

## Priority / Phase
[P0/P1/P2/P3 + roadmap phase]

## Purpose
[User problem this solves]

## Requirements
- [Requirement]
- [Requirement]

## Acceptance criteria
- [Observable expected result]
- [Error/recovery behavior]

## Tests
- [Unit/widget/integration/device test]

## Dependencies / risks
[Packages, permissions, licenses, platform limits]

## Completion evidence
[Commands run, result, files changed, known gaps]
```

### Definition of done

A task is finished only when:
- The feature follows this specification or the spec is intentionally updated.
- It is implemented, not merely represented by a button or mock UI.
- Normal behavior and important failures are handled.
- Appropriate regression tests are added.
- Relevant tests/build/lint are run and results recorded.
- The final diff is reviewed.
- No claim exceeds the verification performed.

---

## 13. Main Technical Terms Glossary

| Term | Meaning in this project |
|---|---|
| **MVP** | Minimum Viable Product: the first usable release that solves a core problem. |
| **PRD** | Product Requirements Document: goals, users, features, priorities and acceptance conditions. |
| **UX / UI** | UX is the user’s flow and behavior; UI is the visible presentation and controls. |
| **Flutter / Dart** | App framework/language for shared mobile code with platform-specific integrations. |
| **MVVM** | Model–View–ViewModel: a way to separate display from UI state and domain/data work. |
| **Repository pattern** | A component that presents a stable interface for reading/writing data regardless of underlying storage. |
| **Service / adapter** | Component that performs a capability or isolates platform-specific API differences. |
| **SQLite / Drift** | Local relational database / type-safe Dart layer over SQLite. |
| **UUID v4** | Random unique identifier, independent of filename. |
| **SHA-256** | Hash/checksum algorithm useful for fingerprinting file contents and detecting exact duplicates/corruption; not encryption. |
| **Atomic write/rename** | Write a complete temporary file then commit it so incomplete output is not mistaken for a completed file. File+database operations still require recovery logic. |
| **WAL mode** | SQLite write-ahead logging mode; choose and test for the app’s concurrency/recovery needs. |
| **Schema migration** | Versioned database changes that preserve user data while the app evolves. |
| **Scoped storage / SAF** | Android file-access model and picker framework that lets users grant access to selected files/destinations. |
| **Content URI / FileProvider** | Platform-safe way to grant another app access to a file without exposing an unrestricted private filesystem path. |
| **EXIF** | Metadata commonly stored in images, including orientation. |
| **Edge detection / quadrilateral** | Finding a page outline and its four corners. |
| **Homography / perspective transform** | Mathematical mapping that flattens a skewed page into a rectangle. |
| **Deskew** | Correcting small angle/rotation in a scan. |
| **Denoise / sharpening** | Image processing that reduces noise or enhances edges; too much can damage characters. |
| **Binarization** | Convert grayscale/color pixels to black/white; global and adaptive threshold methods behave differently. |
| **OCR** | Optical Character Recognition: extracting text from an image or scanned PDF. |
| **CER / WER** | Character Error Rate / Word Error Rate; metrics for comparing OCR to known correct text. |
| **Word bounding box** | Coordinates for the position of recognized text on the page, needed for search highlighting or text-layer alignment. |
| **NFC normalization** | Unicode normalization form that can make canonically equivalent text comparable; validate carefully for Bangla search. |
| **FTS5** | SQLite full-text search extension; tokenizer quality for Bangla must be verified. |
| **Searchable PDF** | PDF with visible page image plus an aligned text layer that supports selection/search. |
| **PDF MediaBox** | PDF page boundary size, measured in points (72 points per inch). |
| **PDF/A** | Standards family for long-term PDF archiving; validation required before claiming compliance. |
| **PDF encryption** | Protection of PDF contents with supported cryptographic algorithms and password rules. |
| **Digital signature** | Cryptographic identity/integrity mechanism; differs from placing an image of a handwritten signature. |
| **Redaction** | Permanent removal of sensitive underlying page/PDF content, not just covering it visually. |
| **Isolate/background processing** | Run CPU-heavy work away from visible interaction where supported; plugin/platform calls may have constraints. |
| **WorkManager** | Android scheduling API for persistent background work under system limits. |
| **Idempotency** | Repeating a job produces the same intended outcome without duplicate side effects. |
| **Exponential backoff** | Retry strategy where wait time increases after repeated failure. |
| **Conflict resolution** | Handling two divergent document versions during sync without silent data loss. |
| **Soft delete** | Mark an item deleted first so it can be restored before permanent purge. |
| **Threat model** | A structured view of sensitive assets, attackers, entry points, likely misuse and mitigations. |
| **Data at rest / in transit** | Data stored on a device/server / data moving over a network. |
| **TLS** | Transport encryption for network connections; alone it does not mean end-to-end encryption. |

---

## 14. Open Decisions to Resolve Before the Relevant Phase

Do not block the MVP on every long-term question. Resolve each decision when it affects implementation.

### Before coding the scanner
- [ ] Choose native ML Kit Document Scanner vs custom CameraX pipeline based on prototype evidence.
- [ ] Decide whether the UX requires full camera UI customization.
- [ ] Confirm fallback on devices without the needed scanning service/RAM.
- [ ] Confirm acceptable minimum Android version based on the chosen Flutter/plugins.

### Before PDF work
- [ ] PDF generation library and license.
- [ ] Maximum tested page count / image size for MVP target devices.
- [ ] Initial export presets and output quality.
- [ ] Existing-PDF import scope.

### Before OCR
- [ ] English engine.
- [ ] Bangla engine and test corpus.
- [ ] Local model size and runtime performance.
- [ ] Search tokenizer and Bangla normalization approach.
- [ ] Whether OCR word boxes/fonts support searchable PDF output accurately.

### Before Pro release
- [ ] PDF library supports each advertised edit operation.
- [ ] Encryption, password and key-handling design reviewed.
- [ ] Conversion quality and license/cost evaluated.
- [ ] Exact Free/Pro feature limits and pricing researched.

### Before cloud/AI
- [ ] Provider(s), privacy policy, consent language, retention and deletion rules.
- [ ] Authentication/authorization model.
- [ ] Sync conflict/version behavior.
- [ ] Operating costs, quotas and abuse controls.
- [ ] Whether local fallback exists for each feature.

### Before final visual implementation
- [ ] Attach/provide the intended scanner-app UX design reference (the latest attached file currently available is not a visual scanner design).
- [ ] Confirm color palette, typography, shape/radius, icon style, dark/light mode and target screenshots.
- [ ] Create a screen-by-screen mapping from the reference into this app while preserving the functional requirements here.

---

## 15. Official Technical References

Recheck these URLs before implementation because library APIs and platform requirements can change.

### Flutter / architecture / packages
- Flutter supported platforms: https://docs.flutter.dev/reference/supported-platforms
- Flutter architecture recommendations: https://docs.flutter.dev/app-architecture/recommendations
- Drift SQLite layer: https://pub.dev/packages/drift
- Flutter Drift setup: https://pub.dev/packages/drift_flutter
- Dart PDF creation library: https://pub.dev/packages/pdf
- Document scanner Flutter plugin candidate: https://pub.dev/packages/flutter_doc_scanner

### Android camera, scanner and storage
- ML Kit Android document scanner: https://developers.google.com/ml-kit/vision/doc-scanner/android
- CameraX image capture: https://developer.android.com/media/camera/camerax/take-photo
- Android app-specific storage: https://developer.android.com/training/data-storage/app-specific
- Android Storage Access Framework: https://developer.android.com/guide/topics/providers/document-provider
- Android offline-first architecture: https://developer.android.com/topic/architecture/data-layer/offline-first

### OCR
- ML Kit Text Recognition v2 language list: https://developers.google.com/ml-kit/vision/text-recognition/v2/languages
- Tesseract language data: https://github.com/tesseract-ocr/tessdata
- Tesseract Bengali trained data: https://github.com/tesseract-ocr/tessdata/blob/main/script/Bengali.traineddata

### Product research
- Adobe Scan: https://play.google.com/store/apps/details?id=com.adobe.scan.android
- Google Drive scan help: https://support.google.com/drive/answer/3145835?co=GENIE.Platform%3DAndroid&hl=en
- Genius Scan security/privacy: https://help.geniusscan.com/security-and-privacy/privacy-and-security-overview
- SwiftScan features: https://swiftscan.app/en/features.html
- OneDrive Android scan help: https://support.microsoft.com/en-us/onedrive/scan-a-whiteboard-document-business-card-or-photo-in-onedrive-for-android
- OneDrive OCR help: https://support.microsoft.com/en-us/onedrive/how-to-use-optical-character-recognition-to-read-pdfs-in-onedrive
- CamScanner: https://play.google.com/store/apps/details?id=com.intsig.camscanner

---

## Final Product Rule

The first app release is successful when a user can scan, correct, save, reopen, find, and share a multi-page PDF reliably on Android—without losing the original pages or requiring an account. All Pro and competitor-inspired capabilities belong in the roadmap, but each must be delivered only after the required engine, data flow, privacy, cost, and testing work is complete.
