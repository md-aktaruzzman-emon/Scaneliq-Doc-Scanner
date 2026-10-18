# AUVYQ Design Language Reference

Map of the "Midnight Protection" design system as defined in `extension/ui/motion.css` (v0.2.0). If this file and `motion.css` disagree, `motion.css` wins — update this file.

## Theme system

- Dark theme is primary and defined on `:root, [data-theme="dark"]`.
- Light theme is an equal citizen, enabled per-surface via `<html data-theme="light">` overrides.
- Components read only tokens. Theme switching means flipping `data-theme` — nothing else.

## Color tokens

| Group | Tokens | Values (dark) |
|---|---|---|
| Backgrounds | `--auvyq-bg-primary` / `-secondary` / `-tertiary` | `#08051A` / `#0D0924` / `#14102F` |
| Surfaces | `--auvyq-surface-primary` / `-secondary` / `-hover` / `-active` | `#171236` / `#1D1745` / `#241E4F` / `#2B245C` |
| Brand | `--auvyq-primary` / `-hover` / `-active`, `--auvyq-indigo`, `--auvyq-blue`, `--auvyq-cyan` | `#5B4BFF` / `#695BFF` / `#493AFF`, `#4338CA`, `#3B82F6`, `#22D3EE` |
| Security states | `--auvyq-protected`, `--auvyq-warning`, `--auvyq-danger`, `--auvyq-info` | `#22C55E`, `#F59E0B`, `#EF4444`, `#38BDF8` |
| Soft state fills | same names + `-soft` | 12% alpha of the state color (e.g. `rgba(34,197,94,0.12)`) |
| Text | `--auvyq-text-primary` / `-secondary` / `-muted` | `#F8FAFC` / `#B8B5D0` / (see `motion.css`) |

Semantic rules:

- Security outcomes map to fixed states: blocked/protected → `protected` green, caution → `warning` amber, threat → `danger` red, informational → `info` blue. Never repurpose a state color for decoration, and never signal a security outcome with brand purple.
- Soft variants are for tinted fills (badges, callout backgrounds); the solid color is for icons, borders, and text on dark fills.

## Spacing and radius

- Spacing scale (4px base): `--space-1: 4px`, `--space-2: 8px`, `--space-3: 12px`, `--space-4: 16px`, `--space-5: 20px`, `--space-6: 24px`, `--space-8: 32px`, `--space-10: 40px`, `--space-12: 48px`.
- Radius scale: `--radius-sm: 6px`, `--radius-md: 10px`, `--radius-lg: 14px`, `--radius-xl: 18px`, `--radius-pill: 999px`.
- Use scale steps only. A one-off `margin: 14px` breaks rhythm; pick `--space-3` or `--space-4`.

## Typography

- Stack: `Inter, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`. No Inter font file is bundled today, so the stack resolves to system fonts on most machines — intentional: MV3 extension pages must not load remote resources, and system fonts keep the popup instant. If Inter-as-designed becomes a requirement, bundle a woff2 locally; never point at a CDN.
- Observed size scale: stat/display 24px/700, body and controls 14–15px, micro labels 11–12px. Body line-height ≥ 1.5.
- Micro labels (11px) are uppercase-tracking territory (e.g. `.brand-name` uses `letter-spacing: 0.18em`); don't go below 11px.

## Motion

- Signature easing: `cubic-bezier(0.22, 1, 0.36, 1)` with ~240ms duration (used by the banner slide-in).
- Motion exists to show state change and spatial continuity, not to decorate.
- A global `@media (prefers-reduced-motion: reduce)` block near the end of `motion.css` neutralizes animations. Any new animation must land inside its coverage — add a rule there if the blanket selector doesn't catch it.

## Shared component classes

`.auvyq-button`, `.auvyq-switch`, and `.auvyq-nav-item` share `:focus-visible` styling (around line 184 of `motion.css`). New interactive elements should either reuse these classes or be added to that focus rule.

## Extending the system

1. Add the token in `motion.css` under **both** theme blocks (dark value + light override).
2. Check contrast of every combination the token will appear in (4.5:1 text, 3:1 large text and UI borders).
3. Consume it via `var(...)` in component CSS — never copy the resolved hex into a component.
4. If the token changes a value the injected banner shows, mirror it in `SHADOW_CSS` in `content/warning-banner.js` (see `surfaces.md`).
