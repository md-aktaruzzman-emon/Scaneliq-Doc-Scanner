# SCANELIQ — FINAL TEST & BUILD VERIFICATION REPORT

**Executed:** November 19, 2026  
**Environment:** Windows 11 (`Microsoft Windows [Version 10.0.26300.9974]`) · Flutter `3.47.7` · Dart `3.13.5` · Android SDK `36.0.0` · OpenJDK `17.0.20.1` · `0` attached Android devices (`flutter devices` confirmed)

---

## 1. Verification Commands & Latest Observed Results

| Verification Check | Exact Command | Outcome | Scope / Notes |
|---|---|---|---|
| **Formatting Check** | `dart format lib/... test/...` | **PASSED** (`12` formatted, `10` modified) | Applied across Stage 9–12 sources & tests |
| **Static Analyzer** | `flutter analyze --no-pub` | **PASSED (`0` issues)** | Verified across full `lib/` and `test/` after final edit |
| **Full Automated Test Suite** | `flutter test --no-pub` | **PASSED (`201` passed, `0` failed, `0` skipped)** | Ran across all **33 test files** in `test/` after final edit (`00:27`) |
| **Android Release R8 APK Build** | `flutter build apk --release --split-per-abi --no-pub` | **PASSED (`Exit 0`, `295.5s`)** | Compiled Kotlin (`TesseractOcrEngine.kt`, `MainActivity.kt`), `tesseract4android:4.9.0`, ML Kit, `pdfrx`, Play Billing with `isMinifyEnabled = true` & `isShrinkResources = true` |

---

## 2. Generated Android Split Release Artifacts

- `build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk` (`76.4 MB`)
- `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` (`95.5 MB`)
- `build\app\outputs\flutter-apk\app-x86_64-release.apk` (`101.3 MB`)

---

## 3. Complete Test File Inventory (`33` Files)

1. `advanced_pdf_service_test.dart`
2. `batch_scanning_test.dart`
3. `database_persistence_test.dart` *(expanded with Schema v6 FTS5 bilingual search, operator-injection safety, nested hierarchy & deep `duplicateDocument` checks)*
4. `document_models_test.dart`
5. `edit_recipe_test.dart`
6. `image_processing_test.dart`
7. `logo_test.dart`
8. `navigation_and_screens_test.dart`
9. `organization_and_batch_test.dart`
10. `pdf_generation_test.dart`
11. `phase10_camscanner_features_test.dart`
12. `phase1_foundation_ui_test.dart`
13. `phase2_audit_and_repair_test.dart`
14. `phase2_navigation_and_screens_test.dart`
15. `phase3_advanced_features_test.dart` *(including legacy CSV & V2/V1 sync compatibility)*
16. `phase3_scanner_camera_test.dart`
17. `phase4_filter_and_pdf_repair_test.dart`
18. `phase4_scan_editor_test.dart`
19. `phase5_advanced_pdf_test.dart` *(expanded with `flattenAndRedactPdf` & `exportPdfToImages`)*
20. `phase5_pdf_engine_test.dart`
21. `phase6_functional_verification_test.dart`
22. `phase7_end_to_end_integration_test.dart`
23. `phase8_security_and_privacy_test.dart`
24. `phase9_release_candidate_test.dart`
25. `scanner_workflow_test.dart`
26. `stage6_bengali_ocr_and_pdf_test.dart` *(new: Bengali + Mixed Bn-En Tesseract preprocessing, numeral normalizer, Table CSV/MD extractor, `NotoSansBengali` UTF-8 PDF searchability)*
27. `stage7_translation_and_ai_test.dart` *(new: Offline ML Kit translation pack flow, Unicode TextRank, entity/date/amount extractor, semantic vault search)*
28. `stage8_countcam_and_invoice_test.dart` *(new: `ObjectCounterService` blank=0 & object clustering, Invoice #, PO #, TIN/BIN, Due Date, Discount, Bengali numerals)*
29. `stage9_cloud_sync_and_privacy_test.dart` *(new: `PrivacyShieldService` `FLAG_SECURE`, DeviceSync V2 AES-256-CBC EtM + V1 compat, Offline Sync Queue, WebDAV `MockClient` MKCOL/PUT/PROPFIND/GET round-trip & OAuth credential blocker)*
30. `stage10_subscription_and_entitlements_test.dart` *(new: Free quota exhaustion/reset, Pro unlimited unlock, `PlayBillingAdapter` stream purchase/restore & missing-SKU handling)*
31. `stage12_e2e_workflows_test.dart` *(new: full multi-stage E2E pipeline test)*
32. `storage_service_test.dart`
33. `widget_test.dart`

---

## 4. Honest Host vs Device Testing Boundary

Host tests execute on Dart VM (`sqflite_common_ffi`, image isolate codecs, Syncfusion pure-Dart PDF, `MockClient` HTTP, and channel/adapter seams) and **cannot execute ARM/x86 Android JNI libraries directly**. Therefore, hardware behaviors (`CameraController`, live `TessBaseAPI` inference speed/RAM on real paper photos, `MlKit` model downloads/APK weights, `pdfrx` GPU/PDFium gestures, and biometric system UI) remain explicitly classified as **Implemented & R8-Compiled — Physical Device QA Pending**.
