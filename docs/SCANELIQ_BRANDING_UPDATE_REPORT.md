# Scaneliq — Official Brand Logo & Android Branding Update Report

**Project:** Scaneliq (`C:\Scaneliq`)  
**Android Package:** `com.scaneliq.scaneliq`  
**Status:** Verified via static analysis, 180/180 automated tests, and debug + release APK builds (on-device launcher/splash installation unverified; no physical device or emulator attached via `adb`)

---

## 1. Master Brand Artwork Location & Preservation

- **Official Master PNG Asset:** `assets/branding/scaneliq_logo_master.png` (`1024 × 1024`, `627,039` bytes, lossless PNG generated directly from the highest-resolution approved upload `1024 × 1024` without recoloring, cropping, stretching, rotating, blurring, or redrawing)
- **Adaptive Icon Foreground Asset:** `assets/branding/scaneliq_logo_adaptive_foreground.png` (`1024 × 1024`, `666,048` bytes, centered at `92%` / `942 × 942` with feathered edges to fit cleanly inside `flutter_launcher_icons`'s `16%` adaptive `<inset>` safe zone without clipping the four viewfinder corner brackets)
- **Sampled Brand Background Color:** `#031837` (exact outer navy background color of the approved master artwork)
- **Preserved Legacy Backup:** `assets/branding/scaneliq_logo_original.jpg` (`374,641` bytes) kept untouched for historical backup
- **Removed Superseded Legacy Copies:** `assets/branding/scaneliq_logo.jpg`, `assets/branding/scaneliq_logo.png`, `assets/branding/scaneliq_symbol.png` deleted so no build or widget references older or smudged artwork

> [!NOTE]
> `pubspec.yaml` registers `- assets/branding/scaneliq_logo_master.png` explicitly under `flutter: assets:` so legacy backups and adaptive foreground templates are not unnecessarily bundled into the Flutter app binary. Inspection of `app-release.apk` confirmed `assets/flutter_assets/assets/branding/scaneliq_logo_master.png` is bundled cleanly with no obsolete logo copies inside `assets/flutter_assets/`.

---

## 2. Prior Branding Audit Summary

Before this update, the repository referenced legacy branding across:
- `assets/branding/scaneliq_logo.png` & `scaneliq_symbol.png` (older S-ribbon artwork without the four cyan/blue scanner brackets, plus a dark smudge artifact on `scaneliq_symbol.png`)
- `lib/core/widgets/scaneliq_logo.dart` pointing to `assets/branding/scaneliq_logo.png`
- `HomeScreen`, `AppLockScreen`, and `SettingsScreen` rendering the monochrome vector `ScaneliqMark` instead of the full-color official brand artwork
- Android `mipmap-*dpi/` (`launcher_icon.png`, `ic_launcher.png`, `ic_launcher_round.png`), `mipmap-anydpi-v26/` (`launcher_icon.xml`, stale `ic_launcher.xml` / `ic_launcher_round.xml`), `drawable-*dpi/ic_launcher_foreground.png`, `values/colors.xml`, `values/styles.xml`, and `drawable*/launch_background.xml` (previously white `#FFFFFF` launch background without a centered logo drawable)

---

## 3. Android Launcher, Adaptive Icon & Splash Configuration

### Launcher & Adaptive Icons (`flutter_launcher_icons` v0.14.4)
- Updated `pubspec.yaml` `flutter_launcher_icons:` configuration:
  - `android: "launcher_icon"`
  - `ios: false` (note: an earlier run with `ios: true` updated `ios/Runner/Assets.xcassets/AppIcon.appiconset/` PNGs with the new icon before halting on missing `project.pbxproj`)
  - `image_path: "assets/branding/scaneliq_logo_master.png"`
  - `adaptive_icon_background: "#031837"`
  - `adaptive_icon_foreground: "assets/branding/scaneliq_logo_adaptive_foreground.png"`
- Generated and synced all Android density buckets (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`):
  - `mipmap-*dpi/launcher_icon.png`, `ic_launcher.png`, `ic_launcher_round.png` (`43,033` bytes at `xxxhdpi`)
  - `drawable-*dpi/ic_launcher_foreground.png`
  - `mipmap-anydpi-v26/launcher_icon.xml`, `ic_launcher.xml`, `ic_launcher_round.xml`

### Android Launch Splash Screen
- Added centered high-resolution splash drawables across all 5 density buckets:
  - `android/app/src/main/res/drawable-mdpi/launch_logo.png` (`144 × 144`)
  - `android/app/src/main/res/drawable-hdpi/launch_logo.png` (`216 × 216`)
  - `android/app/src/main/res/drawable-xhdpi/launch_logo.png` (`288 × 288`)
  - `android/app/src/main/res/drawable-xxhdpi/launch_logo.png` (`432 × 432`)
  - `android/app/src/main/res/drawable-xxxhdpi/launch_logo.png` (`576 × 576`)
- Updated `android/app/src/main/res/values/colors.xml`:
  - `ic_launcher_background` = `#031837`
  - `splash_background` = `#031837`
- Updated `android/app/src/main/res/drawable/launch_background.xml` and `drawable-v21/launch_background.xml` to use `@color/splash_background` with centered `@drawable/launch_logo`.
- Updated `android/app/src/main/res/values/styles.xml` so `LaunchTheme` inherits `@android:style/Theme.Black.NoTitleBar` with `@drawable/launch_background`, avoiding any white startup flash.

---

## 4. Flutter UI & Test Updates

- `lib/core/widgets/scaneliq_logo.dart`:
  - Added `ScaneliqLogo.masterAssetPath = 'assets/branding/scaneliq_logo_master.png'` with `BoxFit.contain` and `FilterQuality.high`.
  - Preserved `ClipRRect` when `borderRadius > 0` and added an adaptive `0.75px` hairline frame (`Color(0x3838BDF8)` on dark surfaces, `Color(0x1F031837)` on light surfaces) so the dark navy badge reads cleanly on both **Gallery Alabaster** Light and **Carbon Studio** Dark themes.
- `lib/features/documents/presentation/home_screen.dart`:
  - Replaced header `ScaneliqMark(size: 26)` with `ScaneliqLogo(size: 28, borderRadius: 7)`.
- `lib/features/security/presentation/app_lock_screen.dart`:
  - Replaced center `ScaneliqMark(size: 40)` with `ScaneliqLogo(size: 48, borderRadius: 12)`.
- `lib/features/settings/presentation/settings_screen.dart`:
  - Replaced Branding & About `ScaneliqMark(size: 40)` with `ScaneliqLogo(size: 48, borderRadius: 12)`.
  - Added an **About Scaneliq** setting row opening `showAboutDialog` with `ScaneliqLogo(size: 56, borderRadius: 14)`, version `1.0.0+1`, and package identifier `com.scaneliq.scaneliq`.
  - Updated **Open Source Licenses** `applicationIcon` to `ScaneliqLogo(size: 48, borderRadius: 12)`.
- Retained `lib/core/widgets/scaneliq_mark.dart` as a standalone widget class without UI references because `test/phase1_foundation_ui_test.dart` tests `ScaneliqMark` directly as a design-system component.
- `test/logo_test.dart`: Updated to assert `ScaneliqLogo.masterAssetPath`, custom `borderRadius` clipping, and hairline framing across both `Brightness.light` and `Brightness.dark` themes.

---

## 5. Verification Results (Observed After Final Code Edits)

- **`dart format` (5 modified Dart files):** Passed (`Formatted 5 files (5 changed) in 0.13 seconds`)
- **`flutter pub get`:** Succeeded (`Got dependencies!`)
- **`flutter analyze`:** Exited with 1 pre-existing warning (`test/phase10_camscanner_features_test.dart:1:8` unused `dart:io` import); **0 errors** and **0 new warnings** in any modified file
- **`flutter test`:** **`180/180` (`All tests passed!`)**
- **APK Builds:**
  - `flutter build apk --debug`: Passed (`53.9s`) -> `C:\Scaneliq\build\app\outputs\flutter-apk\app-debug.apk` (`326,443,832` bytes)
  - `flutter build apk --release`: Passed (`154.4s`) ->
    - `C:\Scaneliq\build\app\outputs\flutter-apk\app-release.apk` (`152,615,624` bytes)
    - `C:\Scaneliq\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` (`55,422,005` bytes)
    - `C:\Scaneliq\build\app\outputs\flutter-apk\app-armeabi-v7a-release.apk` (`45,917,865` bytes)
    - `C:\Scaneliq\build\app\outputs\flutter-apk\app-x86_64-release.apk` (`58,797,095` bytes)
- **On-Device Verification:** Not tested on a physical Android device or emulator (`adb` found no connected devices). Release build uses debug signing per existing `android/app/build.gradle.kts`.
