# Antigravity Master Prompt — Scaneliq Product Research, Competitor Feature Audit, UX Redesign, and Blueprint Update

## 1. Your role

Act as a senior product researcher, mobile UX/UI researcher, Flutter product architect, document-scanning specialist, PDF engineering researcher, OCR/AI researcher, privacy/security reviewer, and technical product planner.

My existing product is **Scaneliq**, an Android-first document scanner and PDF productivity app. I am unhappy with the current frontend design, and the implementation does not include all of the features I requested in the master blueprint.

For this task, your goal is to **research first, analyze the existing application, create a complete feature and UX plan, and update the master Markdown blueprint**. I want a high-quality research document that can guide a later implementation phase.

**Important: Do not start implementing features or redesigning Flutter screens in this task. Do not make speculative code changes. The deliverable for this task is the researched, expanded, implementation-ready Markdown blueprint plus any concise supporting planning document that is genuinely useful.** After updating the document, stop and report what you researched and changed so I can review the plan before the next development task.

## 2. Inspect the project and locate the source of truth

Work in the existing Scaneliq repository and local workspace. Expected GitHub repository:

`https://github.com/md-aktaruzzman-emon/scaneliq-doc-scanner`

Find and read the complete existing master blueprint. It may be named `Scaneliq_Master_Blueprint_Improved.md`, `SCANELIQ_MASTER_BLUEPRINT.md`, or similar. Do not assume the exact name; locate the real file in the workspace, especially under `docs/`.

Also inspect, as available:

- `docs/IMPLEMENTATION_STATUS.md`
- `docs/FEATURE_BACKLOG.md`
- `README.md`
- `pubspec.yaml`
- Current `lib/` structure and navigation/screens
- Theme/design token files
- Existing app logo and branding assets
- Current feature implementation and tests
- Recent Git changes and `git status`

If the current app can be launched in the available environment, inspect it and capture screenshots of the existing screens for the UX audit. If it cannot be run, state that limitation; do not pretend you inspected running UI. Use code inspection and existing screenshots as secondary evidence.

Preserve the current repository, original logo, source code, Git history, and existing user edits. Do not recreate the app. Do not commit or push anything unless the repository workflow and task context clearly require it; the primary deliverable is the updated research blueprint.

## 3. Research requirements — use current sources

Perform fresh online research before writing the final plan. Use official product websites, official support/help pages, official pricing/plan pages, official Google Play or Apple App Store listings, release notes, and official developer documentation where relevant.

Research these six product families separately:

1. **Adobe Scan and Adobe Acrobat** — distinguish capabilities of the scanning app from capabilities available only in Acrobat, Acrobat Pro/Premium, web, or desktop plans.
2. **Google Drive document scanner** — distinguish mobile scan features from broader Drive search, OCR/indexing, storage, and ecosystem integrations.
3. **Genius Scan** — include its free/paid tiers, OCR, organization, export automation, cloud features, and security/privacy characteristics.
4. **SwiftScan** — include scanning, OCR, search, workflows, cloud export/sync, PDF work tools, and paid/platform-dependent capabilities.
5. **Microsoft OneDrive** — distinguish OneDrive’s scan workflow and OCR behavior from features provided by Microsoft 365 or other Microsoft apps.
6. **CamScanner** — include scanning, OCR, PDF editing/conversion, annotation/security, cloud, and premium capabilities.

Starting points for official research (follow relevant links and look for newer documentation):

- Adobe Scan: https://www.adobe.com/acrobat/mobile/scanner-app.html
- Acrobat mobile subscription features: https://helpx.adobe.com/acrobat/mobile/subscription-refunds/about-subscriptions.html
- Google Drive scanning: https://support.google.com/drive/answer/3145835?co=GENIE.Platform%3DAndroid&hl=en
- Genius Scan: https://thegrizzlylabs.com/genius-scan/
- Genius Scan plan comparison: https://thegrizzlylabs.com/genius-scan/pricing
- SwiftScan features: https://swiftscan.app/en/features.html
- OneDrive Android scanning: https://support.microsoft.com/en-us/onedrive/scan-a-whiteboard-document-business-card-or-photo-in-onedrive-for-android
- OneDrive OCR: https://support.microsoft.com/en-us/onedrive/how-to-use-optical-character-recognition-to-read-pdfs-in-onedrive
- CamScanner: https://www.camscanner.com/

Do not limit yourself to these starting URLs if newer official documentation is available. Record when you checked the source. Prefer first-party sources. Third-party reviews can be supplementary, but must not be the only evidence for a feature or plan claim.

For every important feature, record:
- Product name
- Feature / user outcome
- Whether it is confirmed by an official source, partially supported, unclear, or not found
- Free, paid/Pro, account, platform, region, or provider dependency where documented
- Source URL and source title
- Research date
- Implication for Scaneliq

Do not invent feature support, Pro plan availability, pricing, language support, or compatibility. If feature availability varies, state that clearly. Do not claim all six products have a feature unless sources support that statement.

## 4. Competitor feature matrix — make the union comprehensive

Create an extensive, deduplicated feature inventory covering every relevant publicly documented capability found across the six products. Include feature parity with their paid/Pro tiers, not just free scanning features.

At minimum, investigate these capability groups and expand them when research finds more:

### A. Capture and scanning
- Auto document-boundary detection and automatic capture
- Manual capture fallback
- Multi-page and batch scanning
- Retake, append, replace, reorder, and delete page
- Perspective correction, deskew, rotation, crop, and corner adjustment
- Flash/torch controls when available
- Color, grayscale, black-and-white, and document-specific modes
- Cleanup for minor shadows, glare, stains, fingers, or background noise where technically feasible
- Scan modes for documents, receipts, invoices, books, IDs, business cards, whiteboards, photos, and forms
- Import images and existing PDFs
- High-resolution output and quality choices
- QR/barcode capture if relevant and confirmed

### B. Image enhancement and editing
- Non-destructive editing
- Before/after preview
- Background whitening, contrast, sharpness, denoise, and enhancement presets
- Document-type presets
- Original restoration
- Consistent edits across PDF and image exports
- Limitations and expected failure cases

### C. PDF creation and advanced PDF operations
- Single and multipage PDF
- JPEG/image export
- Searchable PDF and OCR text layer
- Page size/orientation options
- Merge, split, extract pages, insert/replace/duplicate/delete/reorder/rotate pages
- Compress/optimize PDF
- Watermarks, page numbers, headers/footers
- Annotations, highlights, comments, drawing, stamps, signatures
- Fillable PDF forms
- Password protection and PDF encryption
- Genuine content redaction
- PDF/A/archive support if documented and feasible
- PDF to Word/Excel/PowerPoint/text/images and conversion quality limits
- PDF preview/viewer, search, bookmarks where applicable, print/share
- File size, quality presets, output validation, error recovery

### D. OCR and document intelligence
- Text extraction, copy, edit/correct recognized text
- OCR by page and batch OCR
- Full-text search and highlighted snippets
- Searchable PDFs
- Language coverage and script limitations
- Business-card recognition and contact extraction
- Receipt/invoice extraction and structured data export
- Smart filenames and auto-document categorization
- Tables to CSV/XLSX where supported
- Confidence/quality issues and user review

### E. Document library and productivity
- Folders and subfolders
- Tags/labels
- Sorting, filtering, favorites, pins, recents
- Search by title, text, date, type, folder, tags
- Trash, restore, permanent deletion
- Smart naming templates
- Duplicate detection
- Batch actions
- One-tap workflow shortcuts
- Auto-export and rules-based routing
- Document metadata and saved searches

### F. Sharing, cloud, sync, and collaboration
- Android Sharesheet, email, print, and local export
- User-selected export destinations
- Google Drive, OneDrive, Dropbox, iCloud, WebDAV or other provider integrations where officially supported
- User-configured auto-upload
- Cloud backup and multi-device sync
- Sync queues, retry/pause, conflict resolution, version/history behavior
- Web/desktop access where supported
- Team/business functions and sharing, where documented
- Authentication, OAuth, account deletion, quota and cost dependencies

### G. Privacy and security
- Local/offline processing and storage behavior
- Accounts and cloud defaults
- App lock/passcode/biometrics where supported
- PDF encryption/password protection
- Real redaction vs visual masking
- Data deletion and backup controls
- Encryption at rest/in transit and any end-to-end encryption claims, with evidence
- Enterprise/privacy compliance claims only when substantiated

### H. AI and automation
- AI scan cleanup
- Summaries, document Q&A, translation, key points, study notes
- Smart extraction and classification
- One-tap workflows
- AI/provider requirements, online processing, cost, user consent, and reliability

For every feature, distinguish **confirmed competitor feature**, **Scaneliq requirement**, **recommended implementation method**, and **open question/dependency**.

Do not copy competitor code, logos, trademarks, exact screens, proprietary wording, or protected assets. The goal is to learn from publicly documented capability categories and create original Scaneliq implementations.

## 5. Explicitly research all Pro and premium functionality

Do not stop at the free feature list. For each app, investigate its current paid/Pro offerings and make a separate premium feature matrix.

Distinguish:
- Features included in the scanner app itself
- Features available only in a related PDF editor app
- Features requiring paid subscriptions
- Features requiring an account or cloud plan
- Features that rely on external provider APIs
- Features that are unavailable on Android or vary by platform/region
- Features whose current availability cannot be verified

The long-term goal is to cover all **relevant and legally/technically feasible feature categories** across these products, including premium categories. Do not promise to reproduce another company's exact commercial service, proprietary model, private API, or subscription entitlement. Instead, define equivalent Scaneliq functionality through original implementation and clearly identify dependencies, costs, licensing, and limitations.

Create a **feature traceability matrix** so every researched feature appears in at least one of these outcomes:
- Required for Scaneliq
- Planned for a later phase
- Optional / evaluate
- Not planned, with a specific reason
- Blocked pending a specific external dependency

Do not silently omit any researched feature.

## 6. UX/UI research — the current Scaneliq frontend needs a real redesign

I do not like the current Scaneliq frontend design. Do not merely adjust colors or add a few cards. Research the user experience, information architecture, visual hierarchy, screen layouts, and interaction patterns of the six reference apps.

Use current official screenshots, store listing screenshots, product demonstrations, help guides, and official videos where available. If the visual sources cannot be accessed, state that clearly and do not pretend you inspected them.

Study:
- First launch and onboarding
- Main/home screen hierarchy
- Primary scan action and import flow
- Camera/scanner interface
- Page review and crop tools
- Enhancement/editor controls
- Document library, folders, and search
- PDF viewer and PDF editing screens
- Export and share flows
- OCR and full-text search
- Advanced PDF tools
- Settings, security, cloud, and subscription surfaces

For each product, note what works well, what is complex, and which patterns might be appropriate for Scaneliq. Do not copy exact UI layouts. Make a product-specific and original Scaneliq design proposal.

### Deliver a complete Scaneliq UI/UX specification

Include:
1. Current UI audit based on actual files/screenshots, with evidence and specific problems.
2. UX goals and key user personas/use cases.
3. Information architecture and navigation map.
4. Proposed primary navigation and why it fits the complete feature set.
5. Screen-by-screen redesign specification.
6. Text wireframes for every important screen and major modal/sheet.
7. Screen hierarchy and primary/secondary actions.
8. Navigation and back behavior.
9. End-to-end flows for scanning, editing, OCR, PDF tools, export, and cloud/AI.
10. Empty, loading, progress, success, error, offline, permission-denied, retry, conflict, and recovery states.
11. Accessibility, font scaling, touch targets, contrast, reduced motion, and screen-reader requirements.
12. Responsive behavior for different Android screen sizes; note future iOS/desktop differences.
13. A consistent visual design system and component library.
14. A migration plan from the current UI to the new design without breaking existing behavior.

### Visual design direction

Create a premium, clean, modern document-productivity app that feels professional and cohesive. Keep the existing Scaneliq identity and original logo, but do not assume the current frontend is correct.

Research and recommend:
- Light and dark theme palettes
- Semantic color tokens
- Typography and type scale
- Spacing system
- Button/input/card/dialog/bottom-sheet components
- Icons and icon consistency
- Elevation and borders
- Animation and motion rules
- Page thumbnails and document previews
- Loading/progress treatments
- Accessibility contrast

Avoid cluttered dashboards, arbitrary gradients, overly decorative 3D elements throughout the app, fake statistics, excessive cards, inconsistent icons, and features hidden behind confusing navigation.

The scanner should remain fast and focused, while advanced tools should be discoverable without crowding the main screen. Make simple scanning easy for beginners and advanced PDF workflows discoverable for power users.

Do not implement this redesign in code during this task. Specify it thoroughly in the updated blueprint so I can review the design plan before implementation.

## 7. Technology stack research and architecture plan

Audit the current Flutter/Dart stack and research technically viable choices for the expanded product. Do not add packages blindly.

Evaluate and document the technologies or service categories needed for:
- Flutter/Dart application architecture
- Android native integration/Kotlin
- Camera/scanner engine
- Automatic edge detection and perspective correction
- Image enhancement/OpenCV or alternatives
- PDF rendering/viewing
- PDF generation
- Existing-PDF editing, annotation, encryption, form filling and redaction
- OCR with English and Bangla support
- Full-text search/indexing and Bangla Unicode normalization
- Local database and migrations
- Filesystem, import, export, and Android sharing
- Background job handling
- Optional cloud authentication, storage, database and sync
- Provider integrations (Drive/OneDrive/other cloud destinations)
- AI provider integration or local inference
- Payments/subscription support if later required
- Automated and real-device testing
- CI/CD, release signing, app distribution and crash diagnostics

For each technology or package recommendation, record:
- Why it is needed
- Main alternatives
- Android/Flutter compatibility
- Maintenance status and documentation
- Licensing and commercial-use restrictions
- Cost/API/credential requirements
- APK size and performance implications
- Privacy/security implications
- Limitations and lock-in risks
- Proof-of-concept tests required before commitment

Do not assume the existing Dart `pdf` library can perform every advanced PDF editing task. Separate PDF generation from editing/rendering/encryption/redaction when needed. Do not call redaction secure unless the underlying content can truly be removed.

For OCR, test supported language scripts rather than assuming Latin recognition provides Bangla support. For cloud and AI integrations, distinguish frontend code from the backend, credentials, policies, and external service required to make it functional.

## 8. Privacy, security, and reliability plan

Create requirements for:
- Local-first operation
- No mandatory account for basic scanning
- No automatic document upload by default
- Explicit consent for cloud and online AI features
- Appropriate OAuth and secure credential handling
- Safe local data storage and export
- Data deletion and backup semantics
- Sync conflicts and versioning
- Sensitive-content-safe logging
- Dependency and license review
- Password handling
- Genuine redaction
- File validation and malformed PDF/image defenses
- Recovery after interrupted operations
- Storage-full and low-memory behavior
- Uninstall implications for app-private files

Do not make unsupported security or privacy promises. Mark high-risk features that need specialist review.

## 9. Complete implementation roadmap and acceptance criteria

Create a realistic roadmap for the *whole* target feature set. Phases are an implementation sequence, not permission to remove advanced requirements from the backlog.

At minimum, assess these phases:

- Phase 0: Research, existing-app audit, requirements and UX blueprint
- Phase 1: Design-system and navigation redesign
- Phase 2: Capture/import, robust page management and persistence
- Phase 3: Advanced image processing and presets
- Phase 4: Library, folders, tags, smart naming, trash and search foundations
- Phase 5: PDF viewer, creation, page manipulation and compression
- Phase 6: OCR, Bangla evaluation, full-text search and searchable PDF
- Phase 7: annotations, forms, signing, encryption and safe redaction
- Phase 8: receipts/invoices/business-card extraction and conversions
- Phase 9: configurable workflows and export automation
- Phase 10: optional AI assistant and provider integration
- Phase 11: optional cloud backup, sync and third-party storage integrations
- Phase 12: release hardening, performance, privacy and device verification

Reorder phases if research reveals a better dependency sequence, and explain why.

For each phase, include:
- Goals and deliverables
- Features included
- Dependencies and technical decisions
- Required database/schema changes
- UI/UX screens affected
- Unit/widget/integration/device tests
- Acceptance criteria
- External accounts, credentials, licensing or costs
- Risks and fallback plans
- Definition of done

Assign priorities such as P0, P1, P2, P3, and P4. Include rough effort estimates only as planning estimates and state the assumptions; do not make unsupported promises about exact delivery dates.

## 10. Update the master Markdown file carefully

The main requested deliverable is a complete update of the existing `Scaneliq_Master_Blueprint_Improved.md` (or the actual current master blueprint filename).

Requirements:
- Locate the exact file before editing.
- Preserve all useful existing content; do not truncate it or replace it with a short summary.
- Back up the original file first, or create a dated/versioned copy in `docs/archive/`.
- Consolidate duplicate requirements while preserving all unique requirements.
- Correct inaccurate or outdated feature claims based on research, documenting the reason.
- Update the table of contents and internal links.
- Add a version, research date, and change log.
- Make sources directly clickable with source title, publisher, relevant finding, and checked date.
- Separate researched facts, Scaneliq product decisions, assumptions, and unresolved questions.
- Include a full cross-reference from competitor feature to Scaneliq requirement and roadmap phase.
- Include the complete redesigned UX/UI specification.
- Include technology recommendations and rationale.
- Include a feature backlog and acceptance criteria.
- Include a section for known limitations, dependencies, operating costs, and legal/licensing issues.
- Do not describe planned features as already implemented.

The updated master blueprint must be detailed enough for a coding agent to implement future work without guessing what each feature is supposed to do.

If useful, also create:
- `docs/SCANELIQ_COMPETITOR_RESEARCH.md`
- `docs/SCANELIQ_UX_REDESIGN_SPEC.md`
- `docs/FEATURE_TRACEABILITY_MATRIX.md`

These supporting documents must not conflict with the master blueprint. Link them from its table of contents. The master blueprint remains the single source of truth.

## 11. Strict scope for this task — research and documents only

For this task:

- Do not implement new Flutter features.
- Do not rewrite existing Dart screens.
- Do not change the app's business logic.
- Do not change package dependencies unless strictly necessary to run a read-only audit; do not do so without recording the reason.
- Do not change branding assets.
- Do not produce a superficial visual makeover instead of research.
- Do not claim that code was tested or a feature was implemented when it was not.

Focus on research, analysis, feature completeness, UX redesign planning, technology selection, and updating the Markdown blueprint.

After the blueprint update is complete, stop and provide a concise report. Wait for my review before beginning implementation from the new plan.

## 12. Final quality checklist

Before finishing, verify that:

- All six competitor products were researched separately.
- Free and Pro/premium feature families are distinguished where information is available.
- Important feature claims have direct sources.
- Platform, subscription, account, region, and external-service limits are recorded.
- The full union of relevant competitor features is mapped to Scaneliq requirements.
- Every feature has a disposition and none was silently omitted.
- The current frontend was audited using actual evidence where available.
- A coherent original Scaneliq UX/UI redesign is fully specified.
- The technology stack and architecture reflect actual implementation needs.
- The roadmap includes realistic dependencies, risks, acceptance criteria, and tests.
- The original master blueprint was backed up and useful content preserved.
- The updated file is complete, structured, cross-linked, and readable.
- Planned, implemented, tested, and blocked features are clearly distinguished.
- No source code changes were made during this research-only task.

## Start now

Inspect the existing Scaneliq repository, research all six products using current official sources, analyze the present application and its frontend, create the complete feature traceability matrix, formulate a significantly improved original Scaneliq UX/UI design, research the necessary technology stack, and update the master Markdown blueprint with a detailed implementation plan.

**Do not start coding yet. I want the research-backed, complete, updated blueprint first. I will review it before asking you to implement the new features and redesign.**
