---
name: ux-for-extension
description: "UI/UX design guidance for the AUVYQ Chrome extension's interfaces. Use whenever a task touches how the extension looks, feels, animates, or reads: building or restyling any file under extension/ui/ (popup, dashboard, onboarding, site report), adding controls, stats, or settings, changing colors, spacing, typography, or motion, reviewing UI for accessibility/polish, or editing the injected warning banner (content/warning-banner.js). Not for ad-blocking engine logic (filters, rules, service worker) — that belongs to the chrome-extension-developer skill."
---

# UX for Extension — AUVYQ UI Design Guidance

This skill keeps every AUVYQ surface (popup, dashboard, onboarding, site report, injected banner) visually consistent and accessible. Architecture questions — service workers, message passing, manifest permissions — go to the `chrome-extension-developer` skill instead; this one is about what the user sees and touches.

## Ground rule: tokens before pixels

`extension/ui/motion.css` is the single source of truth for the "Midnight Protection" design system. Before writing or approving any UI code, read it. Components never hard-code theme colors, spacing, or radii — they use `--auvyq-*`, `--space-*`, and `--radius-*` tokens so dark and light themes stay in sync from one definition point.

The one sanctioned exception: **injected content-script UI** (the warning banner). Extension stylesheets do not load on host pages, so CSS variables are undefined there and `SHADOW_CSS` in `content/warning-banner.js` must use literal values that mirror the tokens. When tokens change, update `SHADOW_CSS` to match.

## Workflow

1. **Identify the surface** the task touches, then read that surface's section in `references/surfaces.md` — each surface has hard constraints (popup width, focus-loss behavior, shadow-DOM isolation) that change what "good" looks like.
2. **For visual decisions** (color, spacing, type, motion), use the token reference in `references/design-language.md`. If a needed value doesn't exist as a token, add it in `motion.css` — do not inline a one-off.
3. **Before delivering**, run the pre-delivery checklist in `references/checklist.md`. It is short; every item has failed in real extensions before.

The references are a map of the system as of v0.2.0 (2026-09-07). The code is the territory — if a reference and `motion.css` disagree, trust `motion.css` and update the reference.

## Universal rules (every surface)

- **Both themes, every time.** Dark is primary; light is an equal citizen via `[data-theme="light"]`. Any change must be checked in both. A color that only works in one theme is a bug.
- **Contrast 4.5:1 minimum** for text (3:1 for large text). The existing tokens pass; any *new* color combination must be verified in both themes before shipping.
- **Keyboard users exist.** `motion.css` defines `:focus-visible` styles for `.auvyq-button`, `.auvyq-switch`, and `.auvyq-nav-item`. Any new interactive element joins that list — never `outline: none` without a replacement.
- **Respect reduced motion.** `motion.css` has a global `prefers-reduced-motion` block (around line 391). New animations must be covered by it. Motion should convey meaning (state change, spatial continuity), never decorate.
- **Icons are inline SVG**, `aria-hidden="true"` when decorative, with an accessible text label when meaningful. Never use emoji as icons — they render inconsistently across platforms and fail screen readers.
- **Text must reflow, not clip.** Popup is 300px wide; site domains and localized strings get long. Ellipsize only with an accessible path to the full value (title, expandable row), and test at 200% text zoom.
- **`cursor: pointer` on everything clickable**, including cards and rows that act as buttons.
- **User-visible strings go through `chrome.i18n`** (`__MSG_*__` in HTML/manifest). No hard-coded English prose in markup.

## Surface quick reference

| Surface | Files | Hard constraint |
|---|---|---|
| Popup | `ui/popup/popup.html` + `popup.css` | Fixed 300px width; Chrome clamps popups at 800×600; closes on focus loss |
| Dashboard / options | `ui/dashboard/dashboard.html` + `dashboard.css` | Full page (`options_page` in manifest); settings persist via `chrome.storage` |
| Onboarding | `ui/onboarding/onboarding.html` + `onboarding.css` | First-run flow; permission asks must be honest and minimal |
| Site report | `ui/site-report/report.html` + `report.css` | Per-site data; every data region needs loading/empty/error states |
| Injected banner | `content/warning-banner.js` | Closed shadow DOM; literal colors mirroring tokens; must not disturb host page |

Details, rationale, and patterns per surface: `references/surfaces.md`.

## Optional external research

For style/palette/typography research beyond this extension (e.g., designing a marketing page), the user has downloaded the ui-ux-pro-max skill repo to `C:\Users\Md Aktaruzzman Emon\Downloads\ui-ux-pro-max-skill-main\ui-ux-pro-max-skill-main`. Its Python search tool (`<repo>/.claude/skills/ui-ux-pro-max/scripts/search.py`, needs Python 3) can be run read-only for lookups. That location is a Downloads folder — if the script is missing, skip it rather than guessing; this skill's own references cover the extension surfaces fully.
