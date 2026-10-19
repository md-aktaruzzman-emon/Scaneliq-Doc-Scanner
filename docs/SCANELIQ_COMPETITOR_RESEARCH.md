# Scaneliq — Competitor Product & Technical Research Report

**Document Version:** 2.0.0  
**Research Date:** October 19, 2026  
**Author:** Senior Product Architect, Mobile UX Researcher & Security Engineer  
**Scope:** Detailed evaluation of 6 reference mobile document scanners and PDF productivity platforms:  
1. **Adobe Scan & Adobe Acrobat**  
2. **Google Drive Document Scanner**  
3. **Genius Scan (The Grizzly Labs)**  
4. **SwiftScan (Maple Media)**  
5. **Microsoft OneDrive (Lens Engine)**  
6. **CamScanner (INTSIG)**  

---

## 1. Executive Research Summary

To build Scaneliq into an elite, privacy-conscious, and commercially viable document productivity platform, we conducted a rigorous audit of the top 6 document scanning and PDF applications. Our research examined both **free baseline capabilities** and **premium/Pro subscription offerings**, cross-referencing official product documentation, store listings, help articles, and technical architecture specifications.

### Strategic Landscape & Opportunity for Scaneliq

| Competitor | Primary Business Model | Major Strengths | Critical Weaknesses & User Frustrations | Scaneliq Strategic Advantage |
|---|---|---|---|---|
| **Adobe Scan / Acrobat** | Freemium + Heavy Cloud Subscription ($9.99/mo to $19.99/mo) | High-fidelity OCR, Acrobat ecosystem integration, clean edge detection | Mandatory Adobe Account; 25-page scan limit on free tier; aggressive upsells to desktop Acrobat | **Zero account required for local scanning; unlimited pages; local-first privacy** |
| **Google Drive Scanner** | Free (Bundled with Google Workspace / Drive) | Native Android integration, automatic blue boundary snapping, zero cost | Mandatory Google Account; forces cloud upload; lacks advanced PDF editing, signing, or encryption | **100% offline workflow; full local PDF toolkit (merge, split, encrypt, watermark)** |
| **Genius Scan** | Freemium + Tiered Subscriptions (Plus $1.99/mo, Ultra $39.99/yr) | Privacy-first marketing, on-device processing, clean UI, automated cloud workflows | Advanced OCR, cloud export, and encryption locked behind Ultra tier ($39.99/yr) | **Generous free on-device OCR and PDF encryption; transparent, predictable features** |
| **SwiftScan** | Freemium + High Subscription / Lifetime ($59.99/yr or lifetime promo) | 200+ DPI quality, one-tap automated workflows, rich filter presets | Aggressive paywalls; free version has ads and watermarks; confusing VIP vs Pro naming | **Ad-free, watermark-free core experience; straightforward tool organization** |
| **Microsoft OneDrive** | Bundled with Microsoft 365 / OneDrive Storage | Document, Whiteboard, and Business Card modes; Office 365 search integration | Strict 10-page scan limit on Android free tier; no standalone local library; cloud-dependent | **No arbitrary page caps; dedicated local document library with custom tagging** |
| **CamScanner** | Heavy Freemium + Aggressive Paywalls ($49.99/yr to $59.99/yr) | 40+ language OCR, specialized modes (ID 2-in-1, Book flattening, CountCam) | Free version degrades output with watermarks, invasive ads, privacy concerns, high subscription cost | **No watermarks on free exports; complete on-device privacy; clean professional design** |

---

## 2. In-Depth Competitor Profiles & Feature Breakdown

### 2.1 Adobe Scan & Adobe Acrobat

**Developer / Publisher:** Adobe Inc.  
**Platforms:** Android, iOS, Web, Windows/macOS (via Acrobat)  
**Primary Documentation Sources:**
- Adobe Scan Mobile Overview: [https://www.adobe.com/acrobat/mobile/scanner-app.html](https://www.adobe.com/acrobat/mobile/scanner-app.html) (Checked: Oct 2026)
- Acrobat Mobile Subscriptions: [https://helpx.adobe.com/acrobat/mobile/subscription-refunds/about-subscriptions.html](https://helpx.adobe.com/acrobat/mobile/subscription-refunds/about-subscriptions.html) (Checked: Oct 2026)
- Adobe Acrobat Plans & Pricing: [https://www.adobe.com/acrobat/pricing.html](https://www.adobe.com/acrobat/pricing.html) (Checked: Oct 2026)

#### Core & Free Capabilities:
- **Automatic Document Capture:** Live camera viewfinder automatically detects document borders, straightens angles, and captures when steady.
- **Scan Modes:** Whiteboard, Book, Form, Document, ID Card, Business Card.
- **Auto-OCR:** Runs optical character recognition automatically in the cloud/background, outputting a searchable PDF.
- **Image Cleanup:** Cleans up minor creases, shadows, stains, and hand-written marks using basic image filters.
- **Business Card Extraction:** Detects name, phone, email, and company, allowing one-tap saving to device Contacts.
- **Output Formats:** Multi-page PDF and JPEG exports.

#### Pro / Premium Capabilities (Acrobat Premium / Scan Subscription):
- **Page Cap Increase:** Increases scan page limit from 25 pages to 100 pages per document.
- **Combine Files (Merge):** Merge multiple separate scan sessions or existing PDFs into a single file directly on mobile.
- **Export to Office:** Converts scanned PDFs into fully editable Microsoft Word (`.docx`), Excel (`.xlsx`), and PowerPoint (`.pptx`) formats.
- **Password Protection:** Adds 128-bit/256-bit AES password encryption to PDFs.
- **Cloud Storage:** Upgrades Adobe Document Cloud storage from 2 GB to 20 GB (or 100 GB in full Acrobat Pro).
- **Acrobat AI Assistant ($24.99/mo tier):** Conversational Q&A with documents, automatic summaries, key takeaway extraction, cross-document synthesis.

#### Key Takeaways for Scaneliq:
1. Provide a generous multi-page experience without artificial 25-page caps.
2. Implement local PDF merge, split, and encryption on-device without requiring an expensive cloud subscription.
3. Structure OCR as an asynchronous pipeline so user scanning is never stalled by cloud processing.

---

### 2.2 Google Drive Document Scanner

**Developer / Publisher:** Google LLC  
**Platforms:** Android (integrated into Google Drive & Google Files), iOS (Google Drive)  
**Primary Documentation Sources:**
- Google Drive Scanning Support: [https://support.google.com/drive/answer/3145835](https://support.google.com/drive/answer/3145835) (Checked: Oct 2026)
- Google Workspace Updates (Drive Scanner UI Update): [https://workspaceupdates.googleblog.com/](https://workspaceupdates.googleblog.com/) (Checked: Oct 2026)
- Android ML Kit Document Scanner API: [https://developers.google.com/ml-kit/vision/doc-scanner/android](https://developers.google.com/ml-kit/vision/doc-scanner/android) (Checked: Oct 2026)

#### Core & Free Capabilities:
- **Instant Launcher Entry:** Dedicated Camera scan button in Drive home screen and home widget shortcut.
- **Auto vs. Manual Capture:** Blue quadrilateral bounding box locks onto paper in real-time; automatically triggers shutter when framed properly.
- **Multi-Page Compilation:** Sequentially adds pages to a single session.
- **Crop & Rotation Adjustment:** Interactive corner dragging with magnified loupe preview.
- **Filter Presets:** None (Original), Color, Grayscale, Black & White.
- **Stain & Finger Eraser:** ML-assisted cleanup tool allowing users to paint over and remove stray fingers or shadows.
- **Smart Title Suggestions:** Automatically recommends descriptive filenames based on document content, date, and user location (in supported regions).
- **Cloud Storage Sync:** Instantly uploads completed PDF to the user's Google Drive folder.
- **Cloud OCR & Search:** Drive server-side indexing makes all scanned text searchable across the entire Google Drive ecosystem.

#### Limitations & Gaps:
- **Zero Offline / Local-First Support:** Cannot save to an app-private local library without uploading to Google Drive.
- **No PDF Security Tools:** Cannot password-protect, encrypt, or watermark files.
- **No Advanced Page Tools:** Cannot merge, split, or reorder pages once the document has been saved to Drive.

#### Key Takeaways for Scaneliq:
1. Scaneliq leverages the same native Google ML Kit Document Scanner engine on Android, guaranteeing equivalent world-class boundary detection and perspective correction.
2. Scaneliq differentiates by offering a **100% offline, local-first library** with zero forced cloud uploads.

---

### 2.3 Genius Scan

**Developer / Publisher:** The Grizzly Labs (Paris, France)  
**Platforms:** Android, iOS  
**Primary Documentation Sources:**
- Genius Scan Product Page: [https://thegrizzlylabs.com/genius-scan/](https://thegrizzlylabs.com/genius-scan/) (Checked: Oct 2026)
- Genius Scan Pricing & Tiers: [https://thegrizzlylabs.com/genius-scan/pricing](https://thegrizzlylabs.com/genius-scan/pricing) (Checked: Oct 2026)
- Privacy & Security Overview: [https://help.geniusscan.com/security-and-privacy/privacy-and-security-overview](https://help.geniusscan.com/security-and-privacy/privacy-and-security-overview) (Checked: Oct 2026)

#### Free Tier ("Basic"):
- **Core Scanning:** Unlimited scans, high-resolution capture, perspective correction, batch capture mode.
- **Clean Output:** No advertisements, no forced watermarks.
- **Multi-page PDF & JPEG:** Generates standard PDFs and images.
- **Basic Library:** Document renaming, tagging, and local folder management.

#### Paid Tiers ("Plus" at ~$11.99/yr, "Ultra" at $39.99/yr or $4.99/mo):
- **On-Device OCR (Ultra):** Offline text recognition generating searchable PDFs and selectable text extraction.
- **Automated Cloud Workflows (Ultra):** Background auto-export to Dropbox, Google Drive, Microsoft OneDrive, Box, Evernote, Nextcloud, WebDAV, FTP, and SMB network shares.
- **Smart Renaming Templates (Ultra):** Dynamic variables in filenames (e.g., `[Date]-[Tag]-[Counter]`).
- **PDF Encryption & Passcode (Ultra):** 128-bit/256-bit AES encryption with password protection and biometric (Fingerprint/Face Unlock) app lock.
- **PDF/A Compliance (Ultra):** Formats documents for long-term archiving standards.
- **Auto-Deletion Rules (Ultra):** Automatically moves local files to trash after a verified cloud export.

#### Key Takeaways for Scaneliq:
1. Genius Scan proves that users highly value a **privacy-first, ad-free, local scanner**.
2. Scaneliq should adopt Genius Scan's smart naming templates (`[Date]_[Category]_[Title]`) and automated export routing.
3. Bring PDF encryption, biometric app lock, and on-device OCR into Scaneliq's core and Pro roadmap.

---

### 2.4 SwiftScan

**Developer / Publisher:** Maple Media  
**Platforms:** Android, iOS  
**Primary Documentation Sources:**
- SwiftScan Official Features: [https://swiftscan.app/en/features.html](https://swiftscan.app/en/features.html) (Checked: Oct 2026)
- Maple Media Privacy & Product Policy: [https://maplemedia.io/](https://maplemedia.io/) (Checked: Oct 2026)
- SwiftScan App Store Listing: [https://apps.apple.com/app/swiftscan-document-scanner/id834854351](https://apps.apple.com/app/swiftscan-document-scanner/id834854351) (Checked: Oct 2026)

#### Core Features & Free Tier:
- **Scan Quality:** 200+ DPI scanning engine with automatic edge detection and blur reduction.
- **Supported Media:** Documents, receipts, sketches, whiteboards, business cards, QR codes, and barcodes.
- **Basic Filters:** Color, Grayscale, B&W, and Photo mode.
- **System Share:** Exports to system share sheet or local storage.
- *Free Tier Drawbacks:* Includes banner advertisements, promotional popups, and watermarks on exported files.

#### VIP / Pro Subscription Tiers ($59.99/yr or $4.99/mo):
- **Ad & Watermark Removal:** Removes all branding watermarks and ads.
- **AI-Powered OCR:** Text recognition in over 20 languages; full-text search across all saved scans.
- **AI Assistant:** Document summarization, translation, and key point extraction.
- **PDF Editing & Annotations:** Highlights, pen drawings, sticky notes, electronic signatures.
- **PDF Manipulation:** Merge, reorder, delete, and insert pages.
- **Cloud Auto-Upload:** Automatic sync to iCloud, Google Drive, Dropbox, Box, OneDrive, Evernote, and WebDAV.
- **Mobile Faxing:** Built-in fax transmission service across 50+ countries (per-page credits or subscription bundle).

#### Key Takeaways for Scaneliq:
1. Users strongly dislike SwiftScan's aggressive pricing ($59.99/yr) and free-tier watermarks.
2. Scaneliq will never place watermarks on basic PDF exports.
3. SwiftScan's one-tap cloud workflow (Scan → Auto-Filter → Auto-Name → Send to Folder) is an excellent UX pattern to implement in Scaneliq Phase 9.

---

### 2.5 Microsoft OneDrive (Microsoft Lens Engine)

**Developer / Publisher:** Microsoft Corporation  
**Platforms:** Android, iOS, Web, Windows  
**Primary Documentation Sources:**
- OneDrive Android Scanning Guide: [https://support.microsoft.com/en-us/onedrive/scan-a-whiteboard-document-business-card-or-photo-in-onedrive-for-android](https://support.microsoft.com/en-us/onedrive/scan-a-whiteboard-document-business-card-or-photo-in-onedrive-for-android) (Checked: Oct 2026)
- OneDrive OCR Text Extraction: [https://support.microsoft.com/en-us/onedrive/how-to-use-optical-character-recognition-to-read-pdfs-in-onedrive](https://support.microsoft.com/en-us/onedrive/how-to-use-optical-character-recognition-to-read-pdfs-in-onedrive) (Checked: Oct 2026)

#### Core Features & Capabilities:
- **Integrated Lens Engine:** Leverages the battle-tested Microsoft Lens computer vision algorithm.
- **4 Dedicated Capture Modes:**
  1. *Document Mode:* High-contrast black/white optimization, deskewing, and edge detection for paper.
  2. *Whiteboard Mode:* Aggressive glare reduction, background color balancing, and sharpening of dry-erase markers.
  3. *Business Card Mode:* Crops small cards and extracts contact details into Microsoft Outlook contacts.
  4. *Photo Mode:* Preserves true color gamut, shadows, and subtle gradations without aggressive thresholding.
- **Multi-Page Limits:** Free Android client limits multi-page scanning to 10 pages; iOS supports up to 30 pages.
- **In-App Annotations:** Drawing, text overlay, and signature stamping before saving.
- **Ecosystem OCR:** Cloud-based OCR indexes text for search within OneDrive and Microsoft 365, with copy/paste text extraction available in web/desktop viewers.

#### Key Takeaways for Scaneliq:
1. Microsoft's Whiteboard mode is the industry benchmark for removing glare from dry-erase boards; Scaneliq's image pipeline must replicate this with high-contrast background whitening.
2. Avoid arbitrary 10-page caps on Android.

---

### 2.6 CamScanner

**Developer / Publisher:** INTSIG Information Co., Ltd.  
**Platforms:** Android, iOS, Web, Windows/macOS  
**Primary Documentation Sources:**
- CamScanner Official Portal: [https://www.camscanner.com/](https://www.camscanner.com/) (Checked: Oct 2026)
- CamScanner Pricing & Features: [https://www.camscanner.com/pricing](https://www.camscanner.com/pricing) (Checked: Oct 2026)
- Google Play Store Listing: [https://play.google.com/store/apps/details?id=com.intsig.camscanner](https://play.google.com/store/apps/details?id=com.intsig.camscanner) (Checked: Oct 2026)

#### Free Tier Features:
- Standard document and photo scanning.
- Basic auto-crop and magic color filter (very popular high-vibrancy contrast enhancement).
- Multi-page document creation.
- *Free Tier Drawbacks:* Prominent watermarks on all exports ("Scanned with CamScanner"); intrusive full-screen video ads; persistent push notifications; strict OCR preview limits (only shows snippets).

#### Premium Subscription ($4.99–$9.99/mo or $49.99–$59.99/yr):
- **Watermark & Ad Removal:** Clean, unbranded PDFs and images.
- **High-Definition (HD) Scans:** Unlocks full 300+ DPI raw camera resolution.
- **Extensive OCR (40+ Languages):** Full text extraction, editable Word (`.docx`), Excel (`.xlsx`), and PowerPoint (`.pptx`) export.
- **Specialized Scanning Modes:**
  - *ID Card / Passport 2-in-1:* Combines front and back of cards onto a single A4 page with 1:1 scale.
  - *Book Scanner:* Two-page split capture with automatic curved-page flattening and thumb/finger removal.
  - *Question Set Mode:* Erases handwritten answers from test papers for re-practice.
  - *CountCam:* Automatically counts physical objects (pipes, pills, rebar, boxes) using object detection.
- **Advanced PDF Tools:** Merge multiple PDFs, split pages, extract ranges, custom security watermarks, AES encryption, and electronic signature stamping.
- **10 GB+ Cloud Storage:** Cross-device synchronization across Android, iOS, iPadOS, Mac, and Web.

#### Key Takeaways for Scaneliq:
1. CamScanner has the widest breadth of utility modes (ID 2-in-1, Book flattening, CountCam, Question set).
2. Users intensely complain about its price ($49.99/yr), privacy policies, and free watermarks.
3. Scaneliq has already implemented ID 2-in-1 stitching, Question set, Book, CountCam heuristics, and QR code scanning. Scaneliq can dominate this segment by providing these features with **zero ads, zero watermarks, and 100% on-device privacy**.

---

## 3. Comprehensive Competitor Capability Matrix

| Capability Category | Specific Feature | Adobe Scan | Google Drive | Genius Scan | SwiftScan | MS OneDrive | CamScanner | Scaneliq Requirement & Status |
|---|---|:---:|:---:|:---:|:---:|:---:|:---:|---|
| **Capture & Modes** | Auto Edge Detection | Free | Free | Free | Free | Free | Free | **Required (P0) — TESTED** |
| | Manual Corner Adjustment | Free | Free | Free | Free | Free | Free | **Required (P0) — TESTED** |
| | Multi-Page Batch Scan | Max 25 Free (100 Pro) | Free | Free | Free | Max 10 (Android) | Pro Only (Free limited) | **Required (P0) — TESTED** |
| | Continuous Shutter Viewfinder | Partial | Auto/Manual | Free | Free | Free | Free | **Required (P0) — TESTED** |
| | ID Card 2-in-1 Stitching | Pro | No | No | No | No | Free / Pro | **Required (P0) — TESTED** |
| | Book Dual-Page & Flattening | Partial | No | No | No | No | Pro | **Required (P2) — IMPLEMENTED** |
| | Whiteboard & Glare Removal | Free | Free | Free | Free | Free (Excellent) | Free | **Required (P0) — TESTED** |
| | Question Set / Exam Mode | No | No | No | No | No | Pro | **Required (P1) — TESTED** |
| | QR & Barcode Scanner | No | No | No | Free | No | Free | **Required (P0) — TESTED** |
| | Object Counter (CountCam) | No | No | No | No | No | Pro | **Required (P2) — IMPLEMENTED** |
| **Image Enhancement** | Magic Color / Auto Contrast | Free | Free | Free | Free | Free | Free | **Required (P0) — TESTED** |
| | Clean B&W Document Filter | Free | Free | Free | Free | Free | Free | **Required (P0) — TESTED** |
| | Grayscale Filter | Free | Free | Free | Free | Free | Free | **Required (P0) — TESTED** |
| | Brightness & Contrast Sliders | Pro | No | Free | Free | No | Pro | **Required (P0) — TESTED** |
| | Non-Destructive Edit Recipe | Free | Free | Free | Free | Free | Free | **Required (P0) — TESTED** |
| | Finger & Stain Eraser | Pro | Free (Basic) | No | No | No | Pro | **Planned (P2)** |
| **PDF Engineering** | Multi-Page A4 PDF Generation | Free | Free | Free | Free | Free | Free (Watermarked) | **Required (P0) — TESTED** |
| | Unwatermarked PDF Export | Free | Free | Free | Pro Only | Free | Pro Only | **Required (P0) — TESTED** |
| | Single & Batch JPEG Export | Free | Free | Free | Free | Free | Free | **Required (P0) — TESTED** |
| | PDF Merge / Combine | Pro Only | No | Pro Only | Pro Only | No | Pro Only | **Required (P0) — TESTED** |
| | PDF Split & Page Extraction | Pro (Acrobat) | No | Pro Only | Pro Only | No | Pro Only | **Required (P0) — TESTED** |
| | PDF AES-256 Encryption | Pro (Acrobat) | No | Ultra Tier | Pro Only | No | Pro Only | **Required (P0) — TESTED** |
| | Custom Text Watermarking | Pro (Acrobat) | No | Ultra Tier | Pro Only | No | Pro Only | **Required (P1) — TESTED** |
| | PDF Compression Optimization | Pro (Acrobat) | No | Free (3 levels) | Pro Only | No | Pro Only | **Planned (P1)** |
| | Electronic Signatures | Free (Acrobat) | No | Free | Pro Only | Free | Pro Only | **Planned (P2)** |
| | Redaction (True Sanitization) | Pro (Acrobat) | No | No | No | No | No | **Planned (P2)** |
| **OCR & Intelligence** | On-Device Latin OCR | Free | No (Cloud) | Ultra Tier | Pro Only | No (Cloud) | Pro Only | **Required (P1) — TESTED** |
| | Searchable PDF (Text Layer) | Free (Cloud) | Free (Cloud) | Ultra Tier | Pro Only | No (Cloud) | Pro Only | **Required (P1) — TESTED** |
| | Full-Text Library Search | Free (Cloud) | Free (Cloud) | Ultra Tier | Pro Only | Free (Cloud) | Pro Only | **Required (P1) — TESTED** |
| | Bangla / Indic Script OCR | No | No (Basic) | No | No | No | Pro (Cloud) | **Planned (P1/P2)** |
| | Business Card Contact Sync | Free | No | Ultra Tier | Pro Only | Free | Pro Only | **Planned (P2)** |
| | Receipt / Invoice Data Extract | Pro | No | Ultra Tier | Pro Only | No | Pro Only | **Planned (P2)** |
| | Document Translation | No | No | No | Pro (AI) | No | Pro Only | **Required (P1) — TESTED** |
| | AI Summary & Q&A Assistant | Pro ($24.99/mo) | No | No | Pro Only | No | Pro Only | **Planned (P3)** |
| **Productivity & Cloud** | Folders & Subfolders | Free | Free | Free | Free | Free | Free | **Planned (P1)** |
| | Color Tags & Labels | No | No | Free | Free | No | Free | **Planned (P1)** |
| | Smart Naming Templates | No | Free (US only) | Ultra Tier | Pro Only | No | No | **Planned (P1)** |
| | Automated Cloud Export | Cloud Only | Drive Only | Ultra Tier | Pro Only | OneDrive Only | Pro Only | **Planned (P3)** |
| | Cross-Device Sync | Cloud Only | Drive Only | Ultra Tier | Pro Only | OneDrive Only | Pro Only | **Planned (P3)** |
| | 100% Offline Local-First | Partial | No | Yes | Partial | No | No | **Core Value — TESTED** |
| | Zero Account Required | No | No | Yes | Yes | No | No | **Core Value — TESTED** |

---

## 4. Key Strategic Recommendations for Scaneliq

1. **Eliminate Freemium Pain Points:**  
   Every major competitor irritates users with either:
   - High subscription fees ($39.99–$69.99/year).
   - Embarrassing watermarks on exported PDFs (CamScanner, SwiftScan free).
   - Mandatory accounts and cloud storage lock-in (Adobe, Google Drive, OneDrive).  
   *Scaneliq will provide a permanent, unwatermarked, ad-free, local-first core scanner for free.*

2. **Differentiate with Advanced PDF Utility:**  
   Tools that Adobe Acrobat, Genius Scan Ultra, and CamScanner lock behind $40–$70/year paywalls (PDF Merge, PDF Split, AES-256 Encryption, Searchable PDF generation, and ID Card 2-in-1 Stitching) are already engineered into Scaneliq's local engine. Elevating these into a cohesive, beautiful user experience will make Scaneliq irresistible to power users, students, and professionals.

3. **Solve the UI/UX Cohesion Problem:**  
   The current Scaneliq frontend suffers from visual clutter, giant branding banners, and fragmented scanning modes. By adopting an industry-leading **Clean Ergonomic Navigation System** (focused camera viewfinder, streamlined home feed, smart tab structure, and integrated document inspector), Scaneliq will match the elegance of Apple and Material 3 design standards.
