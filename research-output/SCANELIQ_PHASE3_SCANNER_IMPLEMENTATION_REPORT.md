# SCANELIQ — PHASE 3 SCANNER CAMERA & DOCUMENT CAPTURE ENGINE REPORT

**Phase Status:** Complete (Host-Side Verified; Physical Android Device Validation Pending)  
**Approved Design Direction:** **Concept A — Editorial Gallery Minimal** + Always-Dark Optical Studio (`#090A0D`)  
**Date:** November 19, 2026  
**Project Directory:** `C:\Scaneliq`

---

## 1. VERIFICATION SUMMARY

| Verification Check | Result | Notes |
|---|---|---|
| `flutter analyze` (after Phase 3 edits) | `1` pre-existing warning (`test/phase10_camscanner_features_test.dart:1:8`) | `0` errors, `0` new warnings across all created/modified Phase 3 files. |
| `flutter test test/phase3_scanner_camera_test.dart` | **`10 / 10` passed** | Unit tests (edge detection, stability tracker, gallery validation) + widget/integration tests (init, permission denied, error recovery, manual capture, double-tap protection, auto/manual toggle, multi-page, gallery import, lifecycle pause/resume, Review screen retake/delete/PDF finish, `320×640` overflow check, auto detection quad attachment). |
| Real Hardware Validation | **Not executed on physical device** | `adb` / Android physical device or emulator not attached in host environment; all `CameraController` paths were verified via the `ScannerCameraBackend` abstraction (`FakeScannerCameraBackend`). |

---

## 2. ARCHITECTURE INSPECTED & MODULAR STRUCTURE

### Dependencies Verified (`pubspec.yaml` — unmodified)
- `camera: ^0.12.1` (`CameraController`, image frame streaming, flash/focus/exposure, lens switching)
- `google_mlkit_document_scanner: ^0.6.1` (preserved as selectable native fallback via `ScanSessionNotifier.startScannerCapture()` and `retakePage()`)
- `file_picker: ^13.1.0` (`FilePicker.pickFiles` multi-select image picker)
- `image: ^4.12.0` (CPU image decoding/processing)
- `flutter_riverpod: ^3.4.3`
- `AndroidManifest.xml` already declares `android.permission.CAMERA`, `android.hardware.camera`, and `android.hardware.camera.autofocus` (`required="false"`).

### Separated Phase 3 Components
1. **Camera Controller & Lifecycle (`lib/features/scanner/data/camera_studio_controller.dart`):**
   - `ScannerCameraBackend` interface + production `FlutterCameraBackend` serializing camera init/dispose/stream/capture operations through an async lock (`_opLock`).
   - Maps `CameraException` permission codes (`CameraAccessDenied`, `CameraAccessDeniedWithoutPrompt`, `CameraAccessRestricted`) cleanly to explicit `CameraStudioStatus` states (`permissionDenied`, `permissionPermanentlyDenied`, `noCamera`, `error`).
   - Cleanly stops `startImageStream` prior to `takePicture` and disposal to prevent Android Camera2 deadlocks.
2. **Genuine Document Edge & Stability Detection (`lib/features/scanner/data/document_edge_detector.dart`):**
   - `CameraFrameData.fromCameraImage(...)` extracts luminance directly from YUV420/NV21 plane 0 (or BT.601 luma from BGRA8888) and `fromImageBytes`/`fromImageFile` for image analysis.
   - `DocumentEdgeDetector.detect(...)` downsamples frames to `<= 88px` max dimension, evaluates mean luminance (`lowLight < 34`), frame-to-frame motion delta (`unstableMotion`), border-vs-center tonal separation, Sobel gradient magnitude, 3×3 neighbor denoising, and fits a convex `PerspectiveQuad` checked for area `[0.14, 0.94]` and non-degenerate edge span — never emitting decorative rectangles on uniform/dark frames.
   - `DocumentStabilityTracker` accumulates stability across `4` low-drift frames (`maxCornerDrift <= 0.038`) and enforces a `2500ms` post-capture cooldown + scene-shift gate to prevent duplicate auto-captures.
3. **Gallery Validation & Ingestion (`lib/features/scanner/data/gallery_import_service.dart`):**
   - Multi-image picking via `FilePicker.pickFiles`, validating extension (`jpg/jpeg/png/webp`), non-empty size `<= 80 MB`, magic-byte headers (`AppStorageService.isValidImageBytes`), and dimensions, reporting cancelled selection and per-file rejections cleanly.
4. **Riverpod Studio Coordinator (`lib/features/scanner/presentation/scanner_studio_provider.dart`):**
   - `ScannerStudioNotifier` orchestrating initialization epochs, lifecycle pause/resume disposal & recovery, `AUTO`/`MANUAL` toggle, `FlashMode` (`off -> auto -> torch`), `ResolutionPreset` (`medium`, `high`, `veryHigh`), lens switching, tap-to-focus/exposure, Book Spread spin-splitting, ID Card 2-step stitching, retake replacement, and gallery import.
5. **Optical Studio & Overlays (`continuous_camera_screen.dart` + `widgets/camera_studio_overlays.dart`):**
   - Dedicated Always-Dark Optical Studio (`#090A0D` / `#101218`) with real Ultramarine `#3B82F6` quadrilateral overlay + anchor nodes, `3×3` framing grid, ID-1 card / Book spine / Whiteboard guides, tap-to-focus reticle, and explicit Permission Denied / Camera Unavailable recovery panels with direct Gallery Import fallback.
6. **Capture Review Stage (`lib/features/editor/presentation/review_pages_screen.dart`):**
   - Concept A editorial Capture Review screen (`PAGE 01 OF XX` badge, large preview, inline rename, `Retake`, `Continue Editing` -> `EditPageScreen`, `Add Page`, `Delete`, page left/right reorder, 2-in-1 ID card prompt, horizontal thumbnail strip, and `Finish Capture` OCR + PDF save).
7. **Scan Session & Storage (`lib/features/scanner/presentation/scan_session_provider.dart`):**
   - Serialized SQLite draft persistence (`_activePersist`), capture timestamps map (`captureTimestamps`), source pixel dimension tracking, and non-destructive original retention under `originalsDir`.

---

## 3. FILES CREATED & MODIFIED IN PHASE 3

### Created Files
- `lib/features/scanner/data/camera_studio_controller.dart`
- `lib/features/scanner/data/document_edge_detector.dart`
- `lib/features/scanner/data/gallery_import_service.dart`
- `lib/features/scanner/presentation/scanner_studio_provider.dart`
- `lib/features/scanner/presentation/widgets/camera_studio_overlays.dart`
- `test/phase3_scanner_camera_test.dart`
- `research-output/ux-prototypes/flutter-phase3/` (8 PNG screenshots: `01_SCANNER_CAMERA_STUDIO.png` through `08_CAMERA_ERROR_STATE.png`)

### Modified Files
- `lib/features/scanner/presentation/continuous_camera_screen.dart`
- `lib/features/scanner/presentation/scan_session_provider.dart`
- `lib/features/editor/presentation/review_pages_screen.dart`
- `lib/features/documents/presentation/home_screen.dart`
- `lib/features/documents/presentation/documents_library_screen.dart`
- `lib/core/navigation/app_router.dart`

---

## 4. KNOWN LIMITATIONS & HARDWARE VALIDATION GAPS

- **Hardware-Dependent Items Unverified (No Connected Android Device/Emulator):**
  Live `CameraController` sensor preview orientation, real Android Runtime Camera permission prompts, YUV420 live frame throughput on mid-range SoCs, hardware torch behavior, tap-to-focus metering hardware response, and background/foreground camera HAL rebinding must be verified on a physical Android device before release.
- **Native Font Rendering in Offline Test Captures:** `pubspec.yaml` intentionally remains unmodified without bundled `.ttf` assets under `assets/fonts/`, so host headless widget tests fallback cleanly rather than fetching Google Fonts over network.
- **Full Image Enhancement Editor:** Intentionally deferred to **Phase 4** (`EditPageScreen`).
