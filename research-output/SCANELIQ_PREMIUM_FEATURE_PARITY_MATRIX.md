# SCANELIQ — PREMIUM COMPETITOR FEATURE PARITY MATRIX

**Audit Date:** November 19, 2026  
**Project Location:** `C:\Scaneliq`  
**Competitors Benchmarked:** CamScanner, Adobe Scan, Microsoft Lens, Genius Scan, SwiftScan

---

## 1. Competitor APK Binary Verification (`C:\Scaneliq\Apk i use\`)

Independent ZIP/hash inspection of all five APK files in `C:\Scaneliq\Apk i use\`:

| Filename | Size (Bytes) | SHA-256 | Authenticity Verdict | Inspected Technical Evidence |
|---|---:|---|---|---|
| `Camscanner.apk` | `177,905,307` | `C044977E578339EB9CA4DE5E11E3FB20FA3A80AD130C75A16AE3B9BED0189746` | **Genuine CamScanner APK** | `com.intsig.camscanner`, `13,029` ZIP entries, `arm64-v8a`, `72` native `.so` libraries (`libOCREngine.so`, `libCVNN.so`, `libMNN.so`, `libQREngine.so`, `libdigital_ink.so`, `libEncryptorP.so`, `libcs_rust.so`, `libenhance4draft.so`), TFLite barcode models, `32` Android permissions. |
| `microsoft-lens.apk` | `70,160,483` | `C1BB0C9B881B65FF998C572944B6F40C90531FCEDC2A2608507C11ED90CDF732` | **Genuine Microsoft Lens APK** | `2,586` ZIP entries, `arm64-v8a`, `31` native `.so` libraries (`libOfficeLens.so`, `libpixsdk.OfficeLensProductivity.so`, `libOcsClient.so`), ONNX & TFLite vision models (`assets/clf_model.tflite`, `mnv2_ep42_wb_quant.ort`, `triclass_doc_classifier.ort`), `21` permissions. |
| `adobe.scan.apk` | `15,798,356` | `918AAE7B5E38647D933D50E90525F29512D393A91E03CE8A494D58BA530B21A5` | **NOT Adobe Scan (Uptodown Installer)** | Identical SHA-256 & byte length (`2,230` entries) across all three; embeds `lib/<abi>/libuptodown-native.so`. |
| `geniusscan.apk` | `15,798,356` | `918AAE7B5E38647D933D50E90525F29512D393A91E03CE8A494D58BA530B21A5` | **NOT Genius Scan (Uptodown Installer)** | Exact byte-for-byte duplicate of `adobe.scan.apk` (Uptodown downloader wrapper). |
| `SwiftScan.apk` | `15,798,356` | `918AAE7B5E38647D933D50E90525F29512D393A91E03CE8A494D58BA530B21A5` | **NOT SwiftScan (Uptodown Installer)** | Exact byte-for-byte duplicate of `adobe.scan.apk` (Uptodown downloader wrapper). |

**Verification Standard:** Capabilities for **Adobe Scan**, **Genius Scan**, and **SwiftScan** below are sourced solely from legitimate public product documentation and store disclosures; unconfirmed capabilities are marked `Unknown` rather than guessed. Note also that Microsoft officially retired Microsoft Lens in early 2026 in favor of Microsoft OneDrive built-in scanning; it is retained here for benchmark parity against its installed APK (`microsoft-lens.apk`).

---

## 2. Core Scanning, Enhancement & OCR Parity Matrix

| Capability | Scaneliq (Verified Reality) | CamScanner (APK + Docs) | Adobe Scan (Public Docs) | Microsoft Lens (APK + Docs) | Genius Scan (Public Docs) | SwiftScan (Public Docs) |
|---|---|---|---|---|---|---|
| **Visual Identity & Clean Free Exports** | **Strong:** Concept A Minimal UI, Light/Dark themes, **zero watermarks on free exports** | Forced `"Scanned with CamScanner"` watermark on free tier | Clean exports on Free tier | Clean exports (Free; app retired) | Clean exports on Free tier | Watermarked / restricted sharing on free tier |
| **Live Auto-Edge Camera Detection** | **Partial / Unverified:** Sobel/convex quad + stability lock tested on synthetic frames; live Android camera untested | **Native C++ Vision:** `libCVNN.so` + `libMNN.so` neural edge & surface models | **Adobe Sensei AI** auto-boundary + auto-capture | **On-device ONNX/TFLite:** `triclass_doc_classifier.ort`, `mnv2_ep42_wb_quant.ort` | Fast production real-time auto-capture | Fast real-time AI edge detection |
| **4-Pt Perspective & Filters** | **Strong:** Homography warp, Otsu/Sauvola B&W, Magic Color, Auto Enhance, Sharpen, Before/After slider via `Isolate.run` | Comprehensive filters + AI Moiré / handwriting removal (`libenhance4draft.so`) | Auto-clean, shadows/glare removal, Magic Eraser | Whiteboard, Document, Business Card, Photo modes (`libOfficeLens.so`) | Distortion/shadow cleanup filters | Smart filters + perspective crop |
| **ID Card (2-in-1), Book Split, Long Stitch** | **Implemented:** Dedicated Camera Studio modes & A4/gutter/vertical stitch engines | ID/Passport/Book/Batch/HD scan modes | Forms, ID card, whiteboard, book batching | Whiteboard, Doc, Card | Batch + multi-page capture | Multi-page + QR/Barcode scan |
| **English / Latin OCR** | **Partial / Unverified:** `google_mlkit_text_recognition` Latin wired; zero physical Android test runs | **Native + Cloud:** `libOCREngine.so` + multi-language server OCR | **Free up to 5 pages/batch**, 100 pages with Acrobat Pro | **Free** `lensocr_release` on-device + Microsoft cloud | Paid **Ultra** tier (`~$39.99/yr`) | Paid **VIP** tier (`~$4.99+/mo`) |
| **Bengali (`বাংলা`) OCR** | **BROKEN:** Mapped to `TextRecognitionScript.devanagiri` (Hindi), `normalizeBanglaNumerals` is a no-op, PDF text layer drops non-Latin1 `>255` | Multi-language cloud/OCR engine | Unknown (multi-lang OCR list varies; Bangla unconfirmed) | Cloud/M365 OCR languages vary | Unknown | Unknown |
| **Table Extraction & Office Export (Word/Excel/PPT)** | **MISSING:** Marked `UNAVAILABLE` in `ToolsScreen` | **Yes** (Word, Excel, PPT conversion in VIP) | **Yes** (Word, Excel, PPT via Acrobat Standard/Pro) | **Yes — Free** direct Word `.docx` & PowerPoint `.pptx` | No | No |
| **QR / Barcode Scanner** | **Unverified:** `mobile_scanner` screen wired, zero device/test verification | **Yes:** `libQREngine.so` + `libbarhopper_v3.so` + TFLite | Unknown / Limited | No | No | Yes |
| **Physical Object Counting (`CountCam`)** | **BROKEN:** Counts Latin OCR `recognizedText.blocks.length` instead of objects | Not core CamScanner (handled in specialized counting apps / AI tools) | No | No | No | No |

---

## 3. PDF Productivity, AI, Cloud Sync & Monetization Parity Matrix

| Capability | Scaneliq (Verified Reality) | CamScanner (APK + Docs) | Adobe Scan (Public Docs) | Microsoft Lens (APK + Docs) | Genius Scan (Public Docs) | SwiftScan (Public Docs) |
|---|---|---|---|---|---|---|
| **PDF Viewer (Smooth Scroll, Zoom, Search)** | **Unverified / Partial:** `pdfrx` + thumbnail rail + Jump + `extractTextByPage` notice; native PDFium untested on hardware | Custom PDF engine + smooth multi-page view | Seamless Acrobat mobile viewer handshake | Hands off to OneDrive / Word / PDF reader | Fast local PDF viewer | Fast PDF viewer + search |
| **PDF Annotations (Highlight, Underline, Ink, Note, Shape)** | **Strong:** Full Concept A overlay + non-destructive vector/ink save (Syncfusion main-isolate) | Full markup, comments, freehand (`libdigital_ink.so`) | Basic markup; deep editing requires Acrobat | Pre-export ink drawing only | Markup & annotations | Full annotations |
| **PDF Digital Signature** | **Partial:** Handwritten PNG visual signature overlay only; **zero X.509 certificate PKI signing** | E-signature stamp + enterprise PDF workflows | Deep integration with Adobe Acrobat Sign | No | Visual e-signature | Visual e-signature (VIP) |
| **Merge / Split / Reorder / Watermark / Compress / Password** | **Implemented (Local):** Full organizer, merge, split, compress presets, AES-256 PDF lock (Syncfusion main-isolate; license key unregistered) | VIP subscription paywall for PDF merge/compress/password | Requires **Acrobat Standard/Pro** (`$13–$20/mo`) | No PDF merge/split/encryption toolkit | Paid Ultra features (encryption, PDF tools) | Mostly VIP features |
| **AI Assistant (Summarize, Q&A, Entity Extract)** | **Weak / Partial:** Offline raw Term-Frequency sentence ranking (mislabeled TextRank/TF-IDF); no LLM, no AI date/entity finder | **CamScanner AI Agent:** Natural language search, cross-doc summaries, handwriting removal | **Acrobat AI Assistant** (paid add-on generative Q&A/summary) | Copilot ecosystem via M365 | No generative AI | Automated tagging/smart naming |
| **Translation** | **Partial (Online):** `GoogleTranslator` HTTP with consent modal; zero offline translation | Cloud AI translation | Via Acrobat / cloud workflows | Immersive Reader / M365 cloud | No | No |
| **Cloud Backup & Multi-Device Sync** | **MISSING (Local ZIP/JSON only):** Zero Google Drive, Dropbox, OneDrive, WebDAV, OAuth, or WorkManager sync | **Yes:** Up to 10 GB CamScanner Cloud + Google Drive / OneDrive / Box / Dropbox | **Yes:** Mandatory Adobe Document Cloud sync (`5–20 GB`) across web/desktop/mobile | **Yes:** Automatic sync to OneDrive / OneNote / Teams | **Yes:** Genius Cloud (Ultra) + Drive/Dropbox/OneDrive/WebDAV export | **Yes:** 10+ cloud targets + VIP auto-upload rules |
| **Security & App Lock** | **BROKEN Cold-Start:** Strong PBKDF2-100k + V2 AES-CBC-EtM crypto **undermined by missing `init()` in `main.dart`**, SharedPreferences PIN storage, plain SQLite DB, unencrypted default backup UI, no `FLAG_SECURE` | Account login + folder lock + shared-link expiry passcodes | Adobe ID enterprise auth | Microsoft Account + Intune/MFA | Paid Biometric/Passcode lock + PDF encryption | Face/Touch ID + PDF encryption |
| **Monetization / Billing Architecture** | **MISSING:** Zero IAP packages, paywalls, SKUs, entitlements, or receipt validation | Mature `$4.99–$9.99/mo` or `$49.99–$59.99/yr` freemium funnel | `$12.99–$19.99/mo` Acrobat subscription | Free ecosystem funnel | `$39.99/yr` Ultra subscription | `$4.99+/mo` VIP subscription |
