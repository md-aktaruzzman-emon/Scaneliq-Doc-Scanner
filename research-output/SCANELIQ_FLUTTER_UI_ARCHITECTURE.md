# Scaneliq — Flutter UI Implementation Architecture

**Document Date:** November 18, 2026  
**Target Stack:** Flutter `3.47.7`, Dart `3.13.5`, `flutter_riverpod: ^3.4.3`, `go_router: ^18.1.0` (already in `pubspec.yaml`)  
**Principle:** Preserve existing domain logic and verified services (`AppDatabaseService`, `AppStorageService`, `PdfService`, `AdvancedPdfService`, `ImageProcessingService`, `AppLockService`, `CloudBackupService`) while modularizing the presentation layer cleanly—with **zero unnecessary dependencies**.

---

## 1. Solving Current Presentation Bottlenecks

As identified in [SCANELIQ_CURRENT_ARCHITECTURE_AUDIT.md](file:///C:/Scaneliq/research-output/SCANELIQ_CURRENT_ARCHITECTURE_AUDIT.md) and [SCANELIQ_UX_PROBLEM_AUDIT.md](file:///C:/Scaneliq/research-output/SCANELIQ_UX_PROBLEM_AUDIT.md), the current UI layer suffers from:
- **6 monolithic screens (`8,294` combined lines)** mixing layout, modals, business orchestration, and direct `*.instance` calls (`documents_library_screen.dart` 1,769 lines; `document_viewer_screen.dart` 1,686 lines; `pdf_tools_screen.dart` 1,555 lines; `edit_page_screen.dart` 1,246 lines; `review_pages_screen.dart` 1,033 lines; `home_screen.dart` 1,002 lines).
- **Hardcoded colors/font sizes** bypassing `AppTheme` and causing dark-mode invisibility (`Colors.black87`) and sub-`48dp` hit targets.
- **Imperative navigation** ignoring declared `go_router` and pushing duplicate Library screens off-tab.

The new Flutter UI Architecture introduces **4 foundational pillars**:
1. Typed **`ThemeExtension` Design Tokens** (`ScaneliqThemeTokens`).
2. A central **Reusable Component Kit** (`lib/core/ui/`).
3. **Riverpod Provider Wrappers + View Controllers** decoupling UI from `.instance` singletons.
4. **Screen Decomposition** (`<= 350` lines per widget file) + **`go_router` `StatefulShellRoute`**.

---

## 2. Target Presentation Folder Structure

```text
lib/
├── app/
│   ├── router/
│   │   ├── app_router.dart                 # GoRouter StatefulShellRoute + deep link routes
│   │   └── route_paths.dart                # Typed route constants
│   ├── shell/
│   │   ├── main_navigation_shell.dart      # Responsive NavigationBar (<840dp) / NavigationRail (>=840dp)
│   │   └── quick_capture_sheet.dart        # Long-press center shutter source picker
│   └── app.dart                            # ScaneliqApp + ProviderScope + ThemeMode watch
│
├── core/
│   ├── theme/
│   │   ├── scaneliq_tokens.dart            # ThemeExtension<ScaneliqTokens> (light & dark precision palette)
│   │   └── app_theme.dart                  # M3 ThemeData builders (fixes global infinity button trap)
│   ├── ui/                                 # Shared Design System Widget Library
│   │   ├── scaneliq_button.dart            # Primary, Tonal, Outlined (48dp height, safe width)
│   │   ├── scaneliq_document_card.dart     # List & Grid variants with 1:1.35 A4 thumb + 48dp menu
│   │   ├── cached_doc_thumbnail.dart       # Enforces cacheWidth/cacheHeight to stop RAM spikes
│   │   ├── scaneliq_search_pill.dart       # Unified 46dp search bar & tap trigger
│   │   ├── scaneliq_tool_tile.dart         # Monochrome icon well + title + subtitle + chevron
│   │   ├── scaneliq_bottom_sheet.dart      # Standard 24dp sheet wrapper + drag handle
│   │   ├── scaneliq_state_view.dart        # Empty, Shimmer Loading & Calm Retry Error states
│   │   └── min_touch_target.dart           # 48x48dp Semantics-aware touch target enforcer
│   └── [existing services preserved: models/, storage/, image_processing/, services/, widgets/]
│
└── features/
    ├── onboarding/presentation/            # splash_screen.dart, onboarding_screen.dart
    ├── documents/
    │   ├── providers/                      # DI bridges + library_filter_controller.dart + search_provider.dart
    │   └── presentation/
    │       ├── home/                       # home_screen.dart + widgets/ (header, action_bar, draft_card, quick_modes, recent_sliver)
    │       ├── library/                    # documents_library_screen.dart + widgets/ (filter_rail, folder_strip, multi_select_dock)
    │       ├── search/                     # global_search_screen.dart (FTS5 snippet highlights)
    │       ├── viewer/                     # document_viewer_screen.dart + widgets/ (viewer_top_bar, viewer_bottom_dock, more_tools_sheet)
    │       └── trash/                      # trash_screen.dart
    ├── scanner/
    │   ├── providers/                      # scan_session_provider.dart (preserved + extended)
    │   └── presentation/
    │       ├── camera/                     # camera_studio_screen.dart + widgets/ (hud_top_bar, quad_overlay, mode_reel, shutter_dock)
    │       ├── review/                     # review_pages_screen.dart + widgets/ (page_carousel, thumb_reorder_strip, batch_filter_bar)
    │       ├── code/                       # scan_code_screen.dart
    │       ├── count_cam/                  # count_cam_screen.dart
    │       └── translate/                  # translate_screen.dart
    ├── editor/
    │   └── presentation/
    │       ├── edit_page_screen.dart       # Coordinator (<300 lines)
    │       └── widgets/                    # crop_loupe_canvas.dart, filter_thumb_strip.dart, lighting_adjust_panel.dart, cleanup_redact_panel.dart
    ├── pdf/
    │   └── presentation/
    │       ├── pdf_tools_screen.dart       # Categorized visual launcher + source picker
    │       ├── pdf_page_organizer_screen.dart
    │       ├── signature_canvas_screen.dart
    │       └── flows/                      # visual_page_range_sheet.dart, compress_preset_sheet.dart, watermark_studio_sheet.dart
    ├── intelligence/presentation/          # ocr_results_screen.dart, ai_assistant_screen.dart, receipt_scanner_screen.dart, business_card_screen.dart
    ├── security/presentation/              # app_lock_screen.dart (keypad + biometrics)
    └── settings/presentation/              # settings_screen.dart, tools_hub_screen.dart, backup_vault_screen.dart, pro_upgrade_sheet.dart, help_support_screen.dart
```

---

## 3. Design Tokens via Flutter `ThemeExtension`

Instead of scattered static `isDark ? AppColors.surface1Dark : AppColors.surface1Light` ternary checks across 30+ files, expose one cohesive `ThemeExtension`:

```dart
@immutable
class ScaneliqTokens extends ThemeExtension<ScaneliqTokens> {
  final Color canvas;
  final Color surface;
  final Color surfaceMuted;
  final Color borderHairline;
  final Color brandPrimary;
  final Color brandTint;
  final Color scannerAccent;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color warning;
  final Color error;

  const ScaneliqTokens({ ... });
  // light & dark static factories + copyWith + lerp
}

extension ScaneliqContextTheme on BuildContext {
  ScaneliqTokens get tokens => Theme.of(this).extension<ScaneliqTokens>()!;
}
```
- **Benefit:** Every screen writes `context.tokens.surface` and `context.tokens.borderHairline`, eliminating light/dark drift and enabling instant live theme switching (`ThemeMode.system | light | dark`) via a Riverpod `themeModeProvider`.
- **Fixing `AppTheme` Button Sizing Bug:** Remove `minimumSize: const Size(double.infinity, 50)` from global `elevatedButtonTheme` / `outlinedButtonTheme`; set `minimumSize: const Size(64, 48)` globally and provide `ScaneliqButton.primary(expanded: true)` when full width is desired.

---

## 4. Riverpod Dependency Injection & Testability

Wrap existing singletons cleanly in Riverpod providers (`lib/core/providers/service_providers.dart`) without rewriting working database/storage internals:

```dart
final appDatabaseProvider = Provider<AppDatabaseService>((ref) => AppDatabaseService.instance);
final appStorageProvider = Provider<AppStorageService>((ref) => AppStorageService.instance);
final ocrServiceProvider = Provider<OcrService>((ref) => OcrService.instance);
final advancedPdfProvider = Provider<AdvancedPdfService>((ref) => AdvancedPdfService.instance);
final appLockProvider = Provider<AppLockService>((ref) => AppLockService.instance);
final cloudBackupProvider = Provider<CloudBackupService>((ref) => CloudBackupService.instance);

// Reactive ThemeMode provider (replaces static ThemeMode.system in main.dart)
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
```
- **Widget Test Impact:** Tests wrap widgets in `ProviderScope(overrides: [appDatabaseProvider.overrideWithValue(mockDb)])` instead of needing live Android filesystem paths—making every redesigned screen fast and deterministic to widget-test.

---

## 5. Monolithic Screen Decomposition Blueprint

| Legacy File (Current LOC) | Target Split Modules | Primary State Controller |
|---|---|---|
| `documents_library_screen.dart` (`1,769`) | `DocumentsLibraryScreen` (`260`) + `LibraryFilterRail` (`140`) + `FolderStrip` (`120`) + `MultiSelectBottomDock` (`130`) + `FolderDialogs` (`160`) | `libraryFilterProvider` + `selectionControllerProvider` |
| `document_viewer_screen.dart` (`1,686`) | `DocumentViewerScreen` (`280`) + `ViewerBottomDock` (`120`) + `ViewerMoreToolsSheet` (`160`) + `PdfActionDialogs` (`220`) | `documentViewerProvider(docId)` |
| `pdf_tools_screen.dart` (`1,555`) | `ToolsHubScreen` (`260`) + `PdfSourcePicker` (`140`) + `VisualPageRangeSheet` (`180`) + `CompressSheet` (`150`) + `ProtectWatermarkSheets` (`200`) | `pdfToolRunnerProvider` (isolate progress) |
| `edit_page_screen.dart` (`1,246`) | `EditPageScreen` (`240`) + `CropLoupeCanvas` (`260`) + `FilterThumbStrip` (`160`) + `AdjustPanel` (`110`) + `CleanupRedactPanel` (`140`) | `pageEditorProvider(page)` |
| `review_pages_screen.dart` (`1,033`) | `ReviewPagesScreen` (`260`) + `ReviewPageCarousel` (`180`) + `ReorderThumbStrip` (`150`) + `ExportPdfSheet` (`190`) | `scanSessionProvider` (preserved) |
| `home_screen.dart` (`1,002`) | `HomeScreen` (`220`) + `HomeActionBar` (`90`) + `DraftRecoveryCard` (`80`) + `QuickModesGrid` (`100`) + `RecentDocumentsSliver` (`150`) | `recentDocumentsProvider` + `latestDraftProvider` |

---

## 6. Routing & Responsive Adaptation (`go_router`)

- **Shell Routing:** Use `StatefulShellRoute.indexedStack` across `/home`, `/documents`, `/tools`, `/settings`. `StatefulNavigationShell.goBranch(1)` resolves the `"See all"` off-tab navigation bug with zero state loss.
- **Deep Links & External Intents:** Register `/document/:id`, `/search`, `/camera`, `/review`, `/editor`, `/ocr/:id`, `/trash`, `/backup`, `/help`.
- **Responsive Shell:** Below `840dp` width -> `ScaneliqBottomBar` (`64dp` + `SafeArea`). At `>= 840dp` -> `NavigationRail` (`80dp` width) + Extended Scan FAB + 3–5 column adaptive `SliverGrid` (`SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220)`).
- **Performance Guardrails:** `CachedDocThumbnail` wraps every `Image.file` with `cacheWidth: (width * devicePixelRatio).round()` and `FilterQuality.medium`, preventing multi-megapixel bitmap decoding in lists.
