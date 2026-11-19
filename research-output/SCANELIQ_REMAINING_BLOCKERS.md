# SCANELIQ — REMAINING BLOCKERS & EXTERNAL PREREQUISITES

**Last Verified:** November 19, 2026

No code bugs, lint errors, or failing automated tests remain inside the Dart/Kotlin repository. All remaining blockers stem strictly from **hardware availability, external vendor accounts/credentials, or platform tooling absent on this Windows workstation**.

---

## 1. Physical Android Hardware Runtime Verification (`UNVERIFIED ON DEVICE`)

- **Gap:** `flutter devices` reported `0` attached Android phones or emulators on this host.
- **Affected Capabilities:**
  - `TesseractOcrEngine.kt` (`cz.adaptech.tesseract4android:tesseract4android:4.9.0`) runtime extraction of real noisy Bengali (`ben.traineddata`) and Mixed (`ben+eng`) camera captures on Android ART.
  - `google_mlkit_translation` language pack download & inference + `google_mlkit_object_detection` on-device latency.
  - `CameraController` (`camera_android_camerax` / Camera2) hardware preview, flash torch, tap-to-focus, and camera lens switch.
  - `pdfrx` PDFium interactive pinch-zoom, text selection handles, and `exportPdfToImages` native C++ FFI execution.
  - `local_auth` biometric prompt, `PrivacyShieldService` (`WindowManager.LayoutParams.FLAG_SECURE` recent-apps blur), and `SharePlus` Android share sheets.
- **Required Owner Action:** Install `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` (or debug APK) via USB debugging on a real Android phone and run an interactive smoke check across Camera -> Bengali OCR -> Searchable PDF -> Viewer -> Flatten Redact -> AppLock/FLAG_SECURE.

---

## 2. Production Play Signing Keystore (`RISK-01`)

- **Gap:** `android/key.properties` is intentionally excluded (`.gitignore`) and must never contain dummy keys. While R8 minification (`isMinifyEnabled = true`, `isShrinkResources = true`) is active and verified, unsigned/debug-signed fallback builds cannot be uploaded to Google Play Console.
- **Required Owner Action:** Generate/locate your upload `.jks` keystore, copy `android/key.properties.example` to `android/key.properties` with real credentials, and run `flutter build appbundle --release`.

---

## 3. Google Play Billing Console SKUs & Server Verification (`Stage 10`)

- **Gap:** `SubscriptionService` connects to `in_app_purchase` (`PlayBillingAdapter`) cleanly and reports `StoreBillingStatus.storeUnavailableOrUnconfigured` when products are absent. Live purchases require Play Console merchant activation.
- **Required Owner Action:** Register subscription products `scaneliq_pro_monthly` and `scaneliq_ultra_monthly` in Google Play Console under `com.scaneliq.scaneliq` and (for production anti-fraud hardening) add a Play Developer API backend verifier.

---

## 4. OAuth Cloud Provider Credentials (Google Drive / Dropbox / OneDrive) (`Stage 9`)

- **Gap:** Self-hosted **WebDAV (Nextcloud/OwnCloud)** sync works end-to-end with KeyStore credentials today. Managed OAuth clouds (`Google Drive`, `Dropbox`, `OneDrive`) honestly return `CloudTransferStatus.requiresCredentials` because no OAuth App IDs or redirect URIs are registered.
- **Required Owner Action:** If turnkey Google Drive / Dropbox / OneDrive backup is required beyond WebDAV, register Android OAuth 2.0 SHA-1 client IDs and pass `--dart-define=GOOGLE_DRIVE_CLIENT_ID=...` at build time.

---

## 5. Legal / Commercial License Compliance (`RISK-04`)

- **Gap:** `syncfusion_flutter_pdf` requires either Syncfusion Community License eligibility (< \$1M annual gross revenue, < 5 developers) or a paid commercial license before commercial Play Store distribution. (`AppComplianceConfig` logs startup status and Settings displays disclosure.)
- **Required Owner Action:** Confirm eligibility or build with `--dart-define=SYNCFUSION_LICENSE_ACK=community|commercial` / `--dart-define=SYNCFUSION_LICENSE_KEY=...`.

---

## 6. Incomplete iOS Runner (`RISK-15`) & Deferred Scope

- **iOS Platform:** Requires macOS + Xcode (`flutter create --platforms=ios .` & CocoaPods) — cannot be compiled or tested on Windows.
- **Deferred Premium Niches (Out of Current MVP Scope):**
  1. Cryptographic X.509 PKI PDF certificate signatures (visual drawn/image stamps are implemented).
  2. Binary Microsoft Word `.docx` document writer (`.txt`, Markdown, `.csv` tables, and searchable Unicode `.pdf` are implemented).
  3. Dedicated offline handwriting (ICR) model.
