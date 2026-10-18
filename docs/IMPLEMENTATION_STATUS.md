# Scaneliq Implementation Status

**Status Document Version:** 1.0.0  
**Updated:** 2026-10-18  
**Current Phase:** Phase 0 — Environment and Proof of Concept / Phase 1 — Project Foundation  

---

## 1. Executive Summary

| Item | Status | Notes |
|---|---|---|
| **App Name** | **Scaneliq** | Consistent across project |
| **Blueprint** | Found & Stored | [Scaneliq_Master_Blueprint_Improved.md](file:///C:/Scaneliq/docs/Scaneliq_Master_Blueprint_Improved.md) |
| **Official Logo** | Integrated (Original) | [scaneliq_logo_original.jpg](file:///C:/Scaneliq/assets/branding/scaneliq_logo_original.jpg) (1024x1024) |
| **Flutter SDK** | Installing (C:\flutter) | Cloning stable branch via Git |
| **Git Remote** | Configured | `https://github.com/md-aktaruzzman-emon/scaneliq-doc-scanner.git` (main) |

---

## 2. Phase-by-Phase Checklist

### Phase 0: Environment & Proof of Concept
- [x] Inspect workspace and system environment.
- [x] Locate and safely store the official blueprint in `docs/`.
- [x] Locate, inspect (1024x1024 RGB) and store official logo in `assets/branding/scaneliq_logo_original.jpg`.
- [/] Set up Flutter toolchain (in progress).
- [ ] Prototype scanner integration (`flutter_doc_scanner` / Android ML Kit Doc Scanner).
- [ ] Verify image capture, persistence, and multi-page PDF generation via Dart `pdf`.

### Phase 1: Project Foundation & Branding
- [ ] Flutter project initialization with package identifier `com.scaneliq.app`.
- [ ] Asset registration in `pubspec.yaml` for official logo and typography.
- [ ] Material 3 centralized theme tokens (`brandPrimary: #2563EB`, dark & light modes).
- [ ] Typography integration: Inter & Noto Sans Bengali.
- [ ] Riverpod state management & `go_router` navigation architecture.
- [ ] Drift/SQLite local persistence foundation with database schema and migrations.

### Phase 2: Functional UI & Navigation
- [ ] Home Screen with primary **Scan document** action and **Import**.
- [ ] Documents Library with search, sort, and favorites.
- [ ] Scanner / Capture screen with multi-page support.
- [ ] Multi-page Review / Organizer with reorder, retake, and delete.
- [ ] Crop & Enhancement Editor (original, grayscale, B&W, rotation).
- [ ] Export & Save screen (PDF / JPEG) with verified save confirmation.
- [ ] Document Viewer.

---

## 3. Technical Decisions & Decisions Log
1. **Logo Integrity**: The official logo supplied is a 1024x1024 24bpp RGB image featuring a stylized 'S' wrapping a folded document in a blue scan viewfinder, with the wordmark "Scaneliq" below. Saved uncompressed and unaltered at `assets/branding/scaneliq_logo_original.jpg`.
2. **Local-first Architecture**: No account wall, no forced cloud uploads. All documents stored in app-private storage by default with explicit user export.
