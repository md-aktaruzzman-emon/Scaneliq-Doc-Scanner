# Scaneliq — UX Redesign Implementation Roadmap

**Document Date:** November 18, 2026  
**Prerequisite Gate:** Explicit User Approval of Design System, Screen Specifications & Visual Prototypes.  
**Alignment:** Sequenced to align cleanly with P0/P1 technical risk remediations in [SCANELIQ_TECHNICAL_RISK_REGISTER.md](file:///C:/Scaneliq/research-output/SCANELIQ_TECHNICAL_RISK_REGISTER.md) without breaking existing services or tests (`139/139` passing).

---

## Phase Overview & Estimated Effort

| Phase | Focus Area | Key Deliverables | Complexity |
|---|---|---|---|
| **UX-1** | Design Tokens, ThemeExtension & Core UI Kit | `ScaneliqTokens`, fixed `AppTheme` (Light/Dark), `lib/core/ui/` reusable kit, live `ThemeMode` | Low–Med (2–3 days) |
| **UX-2** | Navigation Shell, Onboarding & Home Dashboard | `go_router` `StatefulShellRoute`, 4-tab bar + solid Center Scan trigger, Splash, Onboarding, redesigned `HomeScreen` | Medium (3–4 days) |
| **UX-3** | Document Library, Global Search & Folder UX | Decomposed `DocumentsLibraryScreen` (no 5-bar header stack), Multi-Select Dock, Search Overlay (+ FTS5 ready) | Medium (3–4 days) |
| **UX-4** | Unified Camera Studio, Review Carousel & Page Editor | Edge-to-edge Camera HUD, Review Carousel, 4-tool `EditPageScreen` with corner loupe & 7 live filter thumbs (isolate-backed) | High (5–6 days) |
| **UX-5** | PDF Viewer Dock, Tools Bento Hub & PDF Flows | `ViewerBottomDock`, refactored `ToolsHubScreen` (no rainbow clutter / no dead tiles), Visual Page Picker for Split/Merge/Compress | Medium–High (4–5 days) |
| **UX-6** | Intelligence, Security Vault & Settings Polish | Dedicated OCR/Bangla, Receipt, Business Card, AI Q&A, Signature Canvas, App Lock keypad, Backup Vault, Help, Pro sheet | High (5–6 days) |
| **UX-7** | Accessibility, Tablet Responsive QA & Visual Regression | `48dp` target audit, TalkBack verification, golden/widget tests, physical Android device camera & theme QA | Medium (3 days) |

---

## Detailed Phase Execution Plan

### Phase UX-1 — Precision Paper Design System & Component Kit
- **Changes:**
  - Create `lib/core/theme/scaneliq_tokens.dart` implementing `Precision Light` (`#F6F7F9`, `#FFFFFF`, `#1E40AF`, `#0D9488`) and `Obsidian Slate` (`#0B0F17`, `#141923`, `#60A5FA`, `#2DD4BF`) — removing `#00F0FF` neon cyan and rainbow tool colors.
  - Fix `AppTheme` button `minimumSize` (`Size(64, 48)` instead of `Size(double.infinity, 50)`).
  - Build shared `lib/core/ui/` components (`ScaneliqButton`, `ScaneliqDocumentCard`, `CachedDocThumbnail` with `cacheWidth`, `ScaneliqSearchPill`, `ScaneliqToolTile`, `ScaneliqStateView`, `MinTouchTarget`).
  - Wire Riverpod `themeModeProvider` and `service_providers.dart`.
- **Acceptance Criteria:** Widget unit tests verify Light & Dark contrast, `cacheWidth` memory clamping, and `>= 48×48dp` hit boxes on all interactive component kit elements.

### Phase UX-2 — `go_router` Shell, Splash, Onboarding & Home Redesign
- **Changes:**
  - Wire `go_router` `StatefulShellRoute.indexedStack` in `lib/app/router/app_router.dart` (`Home`, `Documents`, `Tools`, `Settings`).
  - Redesign `MainNavigationShell` with clean `64dp` bar + solid Cobalt Center Scan pill (long-press Quick Capture sheet) + `NavigationRail` at `>= 840dp`.
  - Add branded `SplashScreen` and skippable 3-slide `OnboardingScreen` with camera permission priming.
  - Refactor `HomeScreen` into clean modular widgets: Compact Header -> Search Pill -> `Scan Document` + `Import` -> Conditional Draft Banner -> 4 Quick Modes -> Top 6 `Recent Scans` (`See all` switches to Tab 1 via `goBranch(1)`).
- **Acceptance Criteria:** `navigation_and_screens_test.dart` and `widget_test.dart` pass; tapping `See all` switches tab without pushing a bottom-bar-less duplicate Library.

### Phase UX-3 — Document Library, Folders & Search Experience
- **Changes:**
  - Modularize `documents_library_screen.dart` (1,769 -> <300 line coordinator + sub-widgets).
  - Collapse AppBar to 3 clean actions + single filter chip rail + dropdown `Folders` / `Tags` sheets (reclaiming ~40% vertical viewport height).
  - Implement animated `MultiSelectBottomDock` (`Move`, `Tag`, `Merge PDF`, `Share`, `Trash`).
  - Build `GlobalSearchScreen` showing OCR snippet highlights.
- **Acceptance Criteria:** Zero duplicate Favorite controls; all Library actions work under `ProviderScope` overrides in widget tests.

### Phase UX-4 — Unified Camera Studio, Review Carousel & Page Studio Editor
- **Changes:**
  - Merge camera visual style into edge-to-edge dark HUD (`CameraStudioScreen`) with mode wheel (`Document`, `ID Card`, `Book`, `Whiteboard`, `Receipt`, `Card`, `QR`), Auto/Manual toggle, live `#2DD4BF` quad overlay, and fix `ContinuousCameraScreen` lifecycle controller race (`RISK-02`).
  - Upgrade `ReviewPagesScreen` with swipeable full-size page carousel + bottom drag-reorder strip + batch filter chips.
  - Redesign `EditPageScreen` into 4 intuitive tools (`Crop + 1.8x Magnifying Loupe`, `Enhance` with **7 live miniature preview thumbnails**, `Adjust`, `Clean & Redact`), backed by `Isolate.run()` worker pipelines (`RISK-06`).
- **Acceptance Criteria:** Crop/Enhance UI runs with zero frames >16.6ms during filter preview generation; `edit_recipe_test.dart` and `scanner_workflow_test.dart` remain green.

### Phase UX-5 — PDF Viewer Bottom Dock & Visual Tools Hub
- **Changes:**
  - Redesign `DocumentViewerScreen` to replace the 10-item `PopupMenu` with an ergonomic 5-item `ViewerBottomDock` + grouped `More Tools` sheet and `48dp` accessibility zoom controls.
  - Replace `ToolsScreen` rainbow/dead-placeholder list and `PdfToolsScreen` text-input dialogs with a unified `ToolsHubScreen` (Bento grid using monochrome `brandTint` icon wells) and visual `PdfSourcePicker` + `VisualPageRangeSheet` (tapping page thumbnails instead of typing `"1, 3, 5-8"`).
  - Remove raw internal paths (`/data/user/0/...`) from all success dialogs.
- **Acceptance Criteria:** Every tool on `ToolsHubScreen` routes to a real implemented feature (zero dead `"Coming soon"` / snackbar-only stubs); `advanced_pdf_service_test.dart` & `phase5_advanced_pdf_test.dart` pass.

### Phase UX-6 — Intelligence Screens, Security Vault, Settings & Pro
- **Changes:**
  - Elevate Business Card, Receipt Ledger, OCR Results (with honest English / `বাংলা` script switcher aligned with `RISK-03`), AI Summary & Q&A, and Signature Canvas from cramped `AlertDialog` popups into cohesive screens/full-height sheets.
  - Upgrade `SettingsScreen`: interactive Light/Dark/System picker, clean non-jargon Backup & Storage Vault copy (`RISK-08` aligned), `AppLockScreen` tactile keypad + `FLAG_SECURE` Privacy Shield toggle (`RISK-12`), `HelpSupportScreen`, and non-intrusive `ProUpgradeSheet`.
- **Acceptance Criteria:** `SettingsScreen` toggles live theme switching cleanly; zero developer acronyms (`UUIDv4`, `LWW`) appear in primary user subtitles.

### Phase UX-7 — Accessibility, Responsive Layout & On-Device QA
- **Changes:**
  - Run automated semantic & touch-target assertions (`>= 48×48dp` across all interactive controls) + `1.3x` font scale overflow tests + tablet `840dp` responsive layout tests.
  - Execute full hardware test pass on physical Android phone (Camera, ML Kit Scanner, OCR, QR, Biometrics, Share).
- **Acceptance Criteria:** `flutter analyze` = 0 issues, full test suite + golden tests pass, real Android APK verified cleanly.
