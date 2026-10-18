# Pre-Delivery UX Checklist (AUVYQ surfaces)

Run this before declaring any UI task done. Every item here has broken a real extension UI at some point. If an item fails, fix it before delivery — do not mark it "known issue" silently.

## Theming & color

- [ ] Checked in **both** `data-theme="dark"` and `data-theme="light"`.
- [ ] No new hard-coded hex/rgba in component CSS — everything flows through `--auvyq-*` / `--space-*` / `--radius-*` tokens defined in `ui/motion.css` (exception: injected banner's `SHADOW_CSS`, see below).
- [ ] New color combinations verified at 4.5:1 contrast for text (3:1 large text/UI borders) in both themes.
- [ ] Security outcomes use the state colors (`protected` / `warning` / `danger` / `info`), never brand purple or decoration colors.

## Interaction & accessibility

- [ ] Every interactive element is keyboard reachable, in a sensible tab order, with a visible `:focus-visible` style (join the shared rule in `motion.css` around line 184 if it's a new element type).
- [ ] `cursor: pointer` on all clickable elements, including clickable rows/cards.
- [ ] Icon-only controls have an accessible label (`aria-label`); decorative SVGs are `aria-hidden="true"`. No emoji as icons.
- [ ] Click/touch targets are at least ~24px; 44px where the surface allows (popup space is tight — pad, don't shrink the hit area).
- [ ] New animations are covered by the `prefers-reduced-motion` block in `motion.css` (and inside `SHADOW_CSS` for the banner).

## Text & content

- [ ] No text clipped without a path to the full value (title/expand). Tested with a long domain and 200% text zoom.
- [ ] All user-visible strings go through `chrome.i18n` (`__MSG_*__`); no hard-coded prose.
- [ ] Empty, loading, and error states exist for every async data region.

## Surface-specific

- [ ] **Popup**: still 300px wide, no horizontal scroll, under ~600px tall; no flow that requires leaving the popup (it closes on focus loss).
- [ ] **Dashboard**: settings persist via `chrome.storage` and restore correctly; destructive actions confirm inline.
- [ ] **Onboarding**: permissions explained before requested; keyboard completable; skippable.
- [ ] **Site report**: long domains ellipsize with full value accessible; lists grouped with counts.
- [ ] **Injected banner**: closed shadow DOM intact; literal colors in `SHADOW_CSS` still mirror current token values; own `prefers-reduced-motion` rule present; no `window.confirm` (modal inside shadow root); dismissible.

## Hygiene

- [ ] If new tokens were added, they exist in **both** theme blocks in `motion.css`.
- [ ] No remote resources (fonts, scripts, images) referenced from extension pages — MV3 forbids remote code and the store requires bundled assets.
- [ ] `npm test` still passes (some tests, e.g. `mv3-hygiene`, cover UI-adjacent constraints).
