# Surface Constraints — Popup, Dashboard, Onboarding, Site Report, Injected Banner

Each AUVYQ surface lives under different Chrome-imposed constraints. Read the section for the surface you're touching before designing or editing.

## Popup (`extension/ui/popup/`)

The popup is the extension's face: 300px wide, calm, spacious. Hard constraints:

- **Fixed 300px width** (`.auvyq-popup`). Content must reflow inside it — no horizontal scroll, ever. Test with the longest realistic domain name and with 200% text zoom.
- **Chrome clamps popups at 800×600**; keep the popup comfortably under 600px tall. If content grows past that, cut or restructure — a popup is for status and quick actions, not document reading. Deep work links out to the dashboard.
- **The popup closes the moment it loses focus.** Any flow that requires the user to look at, copy from, or interact with another window will destroy the popup mid-task. Destructive or complex actions belong in the dashboard; confirmation dialogs must live inside the popup's own DOM.
- Stats read at a glance: the three-stat grid (`.stats`) leads with the number (24px/700), label under it (11px). Stat numbers count up live — give them `font-variant-numeric: tabular-nums` so digits don't jitter as they change.
- Every toggle/action in the popup must take effect immediately and show its result inline — users don't press "Save" in a popup.

## Dashboard / options page (`extension/ui/dashboard/`)

Registered as `options_page` in the manifest; a full browser tab, so normal page-layout rules apply.

- Navigation uses `.auvyq-nav-item`; keep sections shallow (one level). Settings pages get skimmed, not read — pair every control with a plain-language label and a one-line description of what it does.
- Every setting persists via `chrome.storage` (`sync` for user preferences that should follow the user, `local` for large or machine-specific data) and reflects stored state on load. A settings page that forgets or shows wrong initial state is worse than no setting.
- Destructive actions (reset stats, disable protection) require inline confirmation, not `window.confirm`.
- Provide real content for data regions: loading, empty (first run — zero stats is normal, don't render an error), and error states. Never ship a blank region.

## Onboarding (`extension/ui/onboarding/`)

First-run flow; sets expectations for permissions and value.

- Permission requests must be honest and minimal: explain what each permission does for *the user*, in one sentence, before the browser's own prompt appears. Never pre-ask permissions the current step doesn't need.
- Show progress (step X of Y) and let the user go back without losing choices.
- The flow must be completable with keyboard only, and skippable — power users bail on forced tours.

## Site report (`extension/ui/site-report/`)

Per-site breakdown opened from the popup/dashboard.

- Domain names are user data: long, IDN-encoded, or mixed-script. Ellipsize with an accessible full value (title attribute or expandable row), never `overflow: hidden` alone.
- Every region that renders async data needs loading/empty/error handling (see dashboard rules).
- Blocked-item lists should group by category with counts first; detail on demand (progressive disclosure), not a wall of rows.

## Injected warning banner (`extension/content/warning-banner.js`)

The only AUVYQ UI that renders inside someone else's page — and the most hostile environment.

- **Closed shadow DOM** (`attachShadow({ mode: 'closed' })`) with an inline `<style>` — verified current implementation. Never inject styles into the host document's head; host CSS or an aggressive site could mangle or weaponize them.
- **Extension stylesheets don't load on host pages**, so `--auvyq-*` variables are undefined there. `SHADOW_CSS` therefore uses literal values (`#1D1745` surface, `#F8FAFC` text, `#EF4444` danger border). These mirror tokens by hand — when tokens change in `motion.css`, update `SHADOW_CSS` to match, or the banner drifts from the brand.
- `position: fixed; z-index: 2147483647` (max int) keeps the banner above host content including overlays; the slide-in animates `transform` (compositor-friendly, no layout thrash).
- The banner must not alter host layout beyond its own footprint, and must be dismissible. Confirmations (e.g. typed confirmation for risky actions) render as modals inside the shadow root — never `window.confirm`, which the host page can spoof or intercept.
- Carry the reduced-motion guarantee into `SHADOW_CSS` with its own `@media (prefers-reduced-motion: reduce)` rule — the global block in `motion.css` cannot reach content-script UI.
- The banner appears on pages the user did not expect to be warned about. One clear sentence of what happened beats a paragraph of threat detail; detail lives behind a "learn more" affordance.
