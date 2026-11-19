# SCANELIQ — PREMIUM COMPETITOR PARITY FINAL REPORT

**Date:** November 19, 2026  
**Benchmark Competitors:** CamScanner, Adobe Scan, Microsoft Lens, SwiftScan, Genius Scan  
**Verified Evidence Basis:** Code inspection + `201` automated tests + Android split-APK R8 release compilation (`com.scaneliq.scaneliq` v`2.67.0+26700`).  
*(Note from competitor APK verification: CamScanner & Microsoft Lens were directly inspected APKs; Adobe Scan, SwiftScan, and Genius Scan parity comparisons reflect verified official product documentation because downloaded third-party files were wrappers.)*

---

## 1. Domain-by-Domain Competitive Standing

| Product Area | Pre-Audit Gap | Post-Remediation Scaneliq Capability | Competitive Position |
|---|---|---|---|
| **Camera Capture & Crop** | Frame-processing deadlock risk on background/resume | Lifecycle-resilient `ScannerStudioNotifier`, quad detection, Perspective warp, ID Card 2-in-1, Book split, Auto/Manual capture | **Competitive locally** (camera hardware test on physical Android pending) |
| **Image Enhancement** | Book split, redact, mosaic, stitch ran on UI isolate; missing thumbnail `cacheWidth` | Full `Isolate.run()` offload + Magic Color, Otsu/Sauvola B&W, Whiteboard, Shadow removal, bounded `cacheWidth` decoding | **At parity** with Genius Scan / Adobe Scan; cleaner Concept A UI than CamScanner |
| **Bengali & Multilingual OCR** | CRITICAL: Mapped `OcrScript.bengali` to Devanagari; `normalizeBanglaNumerals` broken | Dedicated `TesseractOcrEngine.kt` (`ben` & `ben+eng`), Isolate binarization preprocessing, working Bengali numeral normalization, Table CSV/Markdown extraction, `.txt` export | **Differentiator** in Bengali/Mixed offline OCR architecture (JNI accuracy awaits device specimen test) |
| **Searchable PDF & Annotations** | Bengali chars stripped to spaces in PDF text layer; vector redactions left raw text extractable | Embedded `NotoSansBengali-Regular.ttf` UTF-8 overlay, PDFium `pdfrx` PDF-to-image, irreversible `flattenAndRedactPdf`, interactive `RasterRedactionScreen`, Isolate PDF merge/split/compress/encrypt | **Strong parity** with Genius Scan & CamScanner Pro on offline PDF manipulation |
| **CountCam & Business Docs** | CountCam counted Latin OCR text blocks instead of objects; Invoice lacked PO/Tax ID/Due Date | `ObjectCounterService` (ML Kit Object Detection + Isolate cluster segmentation) + Invoice #, PO #, TIN/BIN, Due Date, Discount, Bengali currency + inline edit | **Competitive** with CamScanner CountCam (accuracy on real clutter awaits handset test) |
| **Offline Translation & AI** | Online-only translator; TF keyword heuristics mislabeled as TextRank; no entity extractor | Offline `google_mlkit_translation` packs + script detection, true TextRank, Unicode entity/date/amount extraction, explanation & semantic vault search | **Ahead of Lens / Adobe Scan** on local privacy-preserving AI; trails CamScanner Cloud LLM only where cloud keys aren't provided |
| **Vault Search & Library** | SQL `LIKE` search only; nested Move unreachable; no Duplicate Document; `images` filter = 0 | SQLite v6 FTS5 (`unicode61`) with snippets, deep `duplicateDocument`, nested `getFolderHierarchy()`, working `Images` filter, auto trash purge | **Full parity** on local vault organization |
| **Security & Privacy** | Cold-start AppLock bypass; plaintext SharedPreferences PIN; no `FLAG_SECURE`; weak sync XOR | Cold-start `AppLockService.init()` pre-`runApp`, Android KeyStore secrets, `FLAG_SECURE` shield, V2 AES-256-CBC EtM sync + backup passphrases | **Superior privacy stance** to ad/telemetry-heavy competitors |
| **Cloud Sync & Monetization** | Zero remote transport; zero subscription tiers or Play Billing | Real HTTPS WebDAV sync + scheduling + V2 E2EE, `Free/Pro/Ultra` quotas + `in_app_purchase` billing (managed Drive/Dropbox/Play SKUs need owner console setup) | **Ready for self-hosted WebDAV users**; **trails all 5 competitors** until first-party managed cloud & Play SKUs go live |

---

## 2. Commercial Competitiveness Verdict

Scaneliq has transitioned from a **promising prototype with several broken or stubbed engines** into a **cohesive, privacy-first, Bangladesh-ready & international document workspace**:

- **Where Scaneliq matches or beats top competitors today (verified locally):** zero-watermark exports, offline Bengali (`বাংলা`) + Mixed Bn-En Tesseract & Unicode searchable PDF architecture, on-device irreversible Flatten & Scrub PDF redaction + Raster Mosaic Studio, local FTS5 bilingual search, self-hosted WebDAV HTTPS sync with V2 AES-256-CBC EtM, and transparent local-first privacy (`FLAG_SECURE` + Android KeyStore).
- **Where Scaneliq still lags prior to public Play Store scale:** physical handset QA sign-off (`adb` camera/ML Kit/Tesseract run), Google Play Console subscription SKUs + backend receipt verification, and turnkey Google Drive / OneDrive / Dropbox OAuth credentials.
