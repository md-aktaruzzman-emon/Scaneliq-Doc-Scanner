# SCANELIQ — FLUTTER UI IMPLEMENTATION PLAN (CONCEPT A: EDITORIAL GALLERY MINIMAL)

**Approved Master Design:** `SCANELIQ_HOME_CONCEPT_A_PREMIUM_MINIMAL` (Concept A — Editorial Gallery Minimal)  
**Target Codebase:** `C:\Scaneliq\lib\`  
**Baseline Quality Gate:** `139 / 139` passing tests (`flutter test`), `0` errors (`flutter analyze`)  
**Planning Constraint:** This document is the engineering execution blueprint. **Zero Flutter source files, dependencies, or SQLite schemas have been modified during this phase.**

---

## 1. ARCHITECTURAL GOALS & NON-DESTRUCTIVE MIGRATION PRINCIPLES

1. **100% Concept A Visual Fidelity:** Replace the legacy indigo/violet gradient theme (`lib/core/theme/app_theme.dart`) and dense 20-card grid home screen (`lib/features/home/presentation/home_screen.dart`) with Concept A's **Gallery Alabaster** (`#FAF9F6`) light theme, **Carbon Studio** (`#0D0E11`) dark theme, **International Ultramarine** (`#0052FF` / `#3B82F6`) surgical accent, and `1px` warm architectural hairline borders (`#E6E4DD` / `#23262F`).
2. **Consolidate to 3 Top-Level Destinations:** Replace the legacy 4-tab bar (`Documents`, `Tools`, `Backup`, `Settings`) with Concept A's 3-tab frosted bottom navigation bar (`Scans`, `Folders`, `PDF Suite`) and move `Settings & Vault` to the top-right header action on `Scans`.
3. **Activate Declarative `go_router` Navigation:** `go_router: ^18.1.0` is already installed in `pubspec.yaml` (`line 36`) but currently unused (`RISK-07`). Implement `lib/core/routing/app_router.dart` using `StatefulShellRoute.indexedStack` for the 3 primary tabs and full-screen modal routes (`/camera`, `/editor/:draftId`, `/viewer/:docId`, `/ocr/:docId`, `/settings`, `/lock`) with a global `AppLockService` redirect guard.
4. **Decompose the 6 Monolithic Screens (`1,002–1,769` LOC):** Break down `home_screen.dart` (`1,769` LOC), `pdf_tools_screen.dart` (`1,696` LOC), `scanner_screen.dart` (`1,477` LOC), `ocr_screen.dart` (`1,431` LOC), `settings_screen.dart` (`1,073` LOC), and `cloud_backup_screen.dart` (`1,002` LOC) into focused presentation screens and reusable Concept A widgets while keeping all 19 data/domain services (`AppDatabaseService`, `PdfService`, `ImageProcessorService`, `OcrService`, `AppLockService`, `CloudBackupService`, `DeviceSyncService`, `DocumentAiService`, `ReceiptOcrService`, `BusinessCardService`, `ExportService`, etc.) intact.

---

## 2. TARGET FLUTTER DIRECTORY STRUCTURE (`lib/`)

```text
lib/
├── main.dart                                      # Wires ProviderScope + MaterialApp.router + AppLock lifecycle observer
├── core/
│   ├── routing/
│   │   └── app_router.dart                        # NEW: go_router StatefulShellRoute (3 tabs) + AppLock redirect guard
│   ├── theme/
│   │   ├── app_theme.dart                         # REFACTOR: Concept A Light (Gallery Alabaster) & Dark (Carbon Studio)
│   │   ├── scaneliq_tokens.dart                   # NEW: ThemeExtension<ScaneliqTokens> for exact Concept A tokens
│   │   └── scaneliq_typography.dart               # NEW: Instrument Sans + Inter + Noto Sans Bengali + JetBrains Mono
│   └── widgets/                                   # NEW: Concept A Reusable Design System Widget Library
│       ├── editorial_header.dart                  # Brand lockup / sub-screen back header + 40x40 circular icon hits
│       ├── search_and_scope_strip.dart            # 42dp subtle search trigger + OCR badge + underline scope tabs
│       ├── continue_working_folio_card.dart       # Physical 2-sheet rotated paper stack + unfinished draft actions
│       ├── editorial_stream_row.dart              # 74dp hairline row + 50x66 paper thumbnail + JetBrains Mono tag
│       ├── floating_capture_cluster.dart          # Right-thumb [46dp Gallery] + [50dp #0052FF Scan Pill]
│       ├── frosted_bottom_nav.dart                # 82dp BackdropFilter(blur: 16) 3-tab bar (Scans | Folders | PDF Suite)
│       ├── hairline_setting_row.dart              # 1px bottom border row with toggle / mono badge / chevron
│       └── editorial_bottom_sheet.dart            # 22dp top radius modal sheet with 36x4dp grab handle
├── features/
│   ├── home/
│   │   └── presentation/
│   │       ├── home_screen.dart                   # REFACTOR (<380 LOC): Concept A Scans dashboard + multi-select bar
│   │       ├── global_search_screen.dart          # NEW: Screen 5 & 35 FTS5 OCR snippet search view
│   │       └── onboarding_screen.dart             # NEW: Screens 2 & 3 3-slide editorial walkthrough
│   ├── folders/
│   │   └── presentation/
│   │       └── folders_vault_screen.dart          # NEW (Tab 2): Screen 30 cycle-safe folder hierarchy & breadcrumbs
│   ├── scanner/
│   │   └── presentation/
│   │       ├── scanner_screen.dart                # REFACTOR: Screen 7 & 8 dark optical camera studio (#090A0D)
│   │       ├── scan_editor_screen.dart            # NEW: Screens 11–18 4-mode editor (Crop, 7 Filters, Enhance, Pages)
│   │       ├── book_scan_screen.dart              # REFACTOR: Restyled to Concept A camera studio tokens
│   │       ├── qr_scanner_screen.dart             # REFACTOR: Restyled to Concept A camera studio tokens
│   │       └── count_cam_screen.dart              # REFACTOR: Screen 49 with explicit Beta pin-counter disclosure
│   ├── pdf/
│   │   └── presentation/
│   │       ├── pdf_suite_screen.dart              # REFACTOR (Tab 3): Hairline index of all 14 PDF, OCR & Ledger tools
│   │       ├── pdf_viewer_screen.dart             # NEW: Screen 19 paper canvas viewer + 5-action bottom dock
│   │       └── widgets/                           # Modular sub-tool sheets (Merge, Split, Compress, Sign, AES-256)
│   ├── ocr/
│   │   └── presentation/
│   │       ├── ocr_ai_screen.dart                 # REFACTOR: Screens 39–45 4-tab OCR, বাংলা, Translate & Offline AI
│   │       ├── receipt_scanner_screen.dart        # REFACTOR: Screens 46–47 Receipt & Invoice Ledger + math badge
│   │       └── business_card_screen.dart          # REFACTOR: Screen 48 Business Card Contact Folio (.vcf)
│   └── settings/
│       └── presentation/
│           ├── settings_screen.dart               # REFACTOR: Screens 55–65 hairline settings & vault overview
│           ├── app_lock_screen.dart               # NEW: Screens 50–51 full-screen PBKDF2 PIN keypad & biometric gate
│           └── backup_vault_screen.dart           # REFACTOR: Screens 53–54 .scaneliq V2 archive & sync status
```

---

## 3. THEME EXTENSION & DESIGN TOKENS (`lib/core/theme/scaneliq_tokens.dart`)

Every color, border, shadow, and radius from `SCANELIQ_OFFICIAL_DESIGN_SYSTEM.md` will be exposed via a strongly typed `ThemeExtension<ScaneliqTokens>` so zero hardcoded colors appear in feature widgets:

```dart
@immutable
class ScaneliqTokens extends ThemeExtension<ScaneliqTokens> {
  final Color bg;
  final Color surface;
  final Color surfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color hairline;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color danger;
  final Color navGlass;
  final List<BoxShadow> paperShadow;

  const ScaneliqTokens({
    required this.bg,
    required this.surface,
    required this.surfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.hairline,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
    required this.navGlass,
    required this.paperShadow,
  });

  /// Light Mode — Gallery Alabaster (Approved Concept A Default)
  static const light = ScaneliqTokens(
    bg: Color(0xFFFAF9F6),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF2F0EB),
    textPrimary: Color(0xFF141413),
    textSecondary: Color(0xFF5C5B57),
    textMuted: Color(0xFF8C8A84),
    hairline: Color(0xFFE6E4DD),
    accent: Color(0xFF0052FF),
    accentSoft: Color(0x140052FF),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    navGlass: Color(0xEBFAF9F6),
    paperShadow: [
      BoxShadow(color: Color(0x14141413), blurRadius: 8, offset: Offset(0, 2)),
      BoxShadow(color: Color(0x0A141413), blurRadius: 2, offset: Offset(0, 1)),
    ],
  );

  /// Dark Mode — Carbon Studio (Approved Concept A Dark Companion)
  static const dark = ScaneliqTokens(
    bg: Color(0xFF0D0E11),
    surface: Color(0xFF15171C),
    surfaceSubtle: Color(0xFF1C1F26),
    textPrimary: Color(0xFFF4F4F6),
    textSecondary: Color(0xFF9CA0AB),
    textMuted: Color(0xFF636773),
    hairline: Color(0xFF23262F),
    accent: Color(0xFF3B82F6),
    accentSoft: Color(0x243B82F6),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    navGlass: Color(0xEB0D0E11),
    paperShadow: [
      BoxShadow(color: Color(0x73000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );
  // copyWith & lerp omitted for brevity
}
```

---

## 4. DECLARATIVE ROUTING & APP LOCK LIFECYCLE (`lib/core/routing/app_router.dart`)

```dart
final appRouterProvider = Provider<GoRouter>((ref) {
  final lockState = ref.watch(appLockSessionProvider);

  return GoRouter(
    initialLocation: '/scans',
    redirect: (context, state) {
      if (lockState.isLocked && state.matchedLocation != '/lock') {
        return '/lock?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaneliqAppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/scans', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/folders', builder: (_, __) => const FoldersVaultScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/pdf-suite', builder: (_, __) => const PdfSuiteScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/search', builder: (_, __) => const GlobalSearchScreen()),
      GoRoute(path: '/camera', builder: (_, __) => const ScannerScreen()),
      GoRoute(path: '/editor/:id', builder: (_, s) => ScanEditorScreen(docId: s.pathParameters['id']!)),
      GoRoute(path: '/viewer/:id', builder: (_, s) => PdfViewerScreen(docId: s.pathParameters['id']!)),
      GoRoute(path: '/ocr/:id', builder: (_, s) => OcrAiScreen(docId: s.pathParameters['id']!)),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/backup', builder: (_, __) => const BackupVaultScreen()),
      GoRoute(path: '/lock', builder: (_, s) => AppLockScreen(returnTo: s.uri.queryParameters['from'])),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    ],
  );
});
```

---

## 5. PHASED IMPLEMENTATION SEQUENCE & EFFORT ESTIMATES

| Phase | Scope | Files Created / Refactored | Verification Gate |
| :--- | :--- | :--- | :--- |
| **Phase 1: Tokens & Core Widgets** | Implement `ScaneliqTokens`, `ScaneliqTypography`, and the 8 reusable Concept A widgets in `lib/core/widgets/`. | `app_theme.dart`, `scaneliq_tokens.dart`, `scaneliq_typography.dart`, 8 widget files | Widget unit tests for Light (`#FAF9F6`) & Dark (`#0D0E11`) token rendering + `flutter analyze`. |
| **Phase 2: Shell, Router & Home (`Scans`)** | Wire `app_router.dart` (`StatefulShellRoute`), refactor `home_screen.dart` to Concept A layout (`Continue working` folio + hairline stream + `[Gallery] [Scan]` cluster), add `global_search_screen.dart` & `folders_vault_screen.dart`. | `main.dart`, `app_router.dart`, `home_screen.dart`, `global_search_screen.dart`, `folders_vault_screen.dart` | Widget tests for 3-tab switching, scope tabs (`Recent`, `Starred`, `Folders`), and multi-select batch bar. |
| **Phase 3: Optical Camera & Scan Editor** | Refactor `scanner_screen.dart` to `#090A0D` studio with `#3B82F6` quad nodes + mode switcher; extract `scan_editor_screen.dart` (Crop loupe, 7-filter ribbon, Enhance, Reorder grid). | `scanner_screen.dart`, `scan_editor_screen.dart`, `book_scan_screen.dart`, `qr_scanner_screen.dart` | Existing `image_processor_service_test.dart` + new editor widget tests pass. |
| **Phase 4: PDF Viewer & PDF Suite (Tab 3)** | Build `pdf_viewer_screen.dart` with 5-action dock; refactor `pdf_tools_screen.dart` into `pdf_suite_screen.dart` + modular tool sheets (`Merge`, `Split`, `Compress`, `Sign`, `AES-256`). | `pdf_viewer_screen.dart`, `pdf_suite_screen.dart`, 5 tool sheet widgets | Existing `pdf_service_test.dart` & `phase10_camscanner_features_test.dart` pass. |
| **Phase 5: OCR, বাংলা, AI & Settings Vault** | Refactor `ocr_screen.dart`, `receipt_scanner_screen.dart`, `business_card_screen.dart`, `count_cam_screen.dart`, `settings_screen.dart`, `app_lock_screen.dart`, `backup_vault_screen.dart`. | 7 feature presentation files | Full `139+` test suite green (`flutter test`) + `0` lint warnings (`flutter analyze`). |
