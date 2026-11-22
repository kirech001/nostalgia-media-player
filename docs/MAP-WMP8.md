# Stage B — evidence-to-selector map

See `AUDIT-WMP8.md` for source provenance. R1/R2 are WMP 8, R3/R4 generic XP. Measured screenshot colours guide CSS approximations; hex values are **not claimed as extracted original skin resources**.

## Tokens and fixed metrics

- Caption: XP blue `#0058ee` / `#3593ff` / `#003dba`, white Tahoma 13px bold; 32px high (keep usable frame).
- Menu/dialog: XP beige `#ece9d8`, black `#000`, selection blue `#316ac5`; menu 24px (keep current metric).
- Frame: metallic cool silver `#e4e4eb`, `#b0b1c0`, shadow `#77788b`, periwinkle `#677fc0`.
- Playlist/stage: `#000`, off-white `#efefef`, muted `#b5b5bd`; playing green `#00ff00`.
- Sliders: green `#00d62b` / `#8bff72` inside retained silver bezels; 24px hit boxes.
- Typography: Tahoma 11px base, 10px secondary, 11px header bold, metadata artist 14px / title 20px regular.
- Layout unchanged: 248/196px left pane; 92px console, 22px status; 1000×690 default and 880×600 minimum; 20px list rows with 3 matching columns.
- Controls retain current 29px secondary / 38px play / 26px speaker, 2–3px small bezel radii and 1px pressed offset. No new component layer.

## Implementation map (100% of audit regions)

| Step | Existing selector / code | Change | Evidence | Risk |
| --- | --- | --- | --- | --- |
| B | `:root` / body / shell | Token block at top; reuse fixed metrics; no runtime behavior | R1–R4 + baseline constraints | Low |
| C1 | `.titlebar`, `::after`, `.title-text`, `.title-left`, `.win-btn`, `.win-close` | XP blue caption, remove center seam/glow/letterspacing, pixel-sized glyphs + pressed feedback | R2/R4 | Low, drag/IPC unchanged |
| C1 | `.menubar`, `.menu-label`, `.menu-pop`, `.menu-pop button`, `.menu-sep` | Beige strip, compact square labels, restrained 1px inset popup bevel, no broad modern shadow | R2 strip, R4 generic XP | Low |
| C2 | `.playlist-pane`, `.pane-header`, `.pane-title`, `.pane-btn`, `.pane-body`, `.pl-cols` | Neutral silver frame/black list, shared 6px inset, remove title tracking; exact same widths and grid | R1/R2 palette | Low |
| C2 | `.pl-list`, `.pl-item`, `.pl-artist`, `.pl-dur`, `.pl-playmark` | Near-black zebra, pale row text; retain existing selected blue fill; green playing marker | R1/R2 black list/green playing cue | Low; no renderer restructuring |
| C2 | `.pl-empty`, `.pl-empty-art`, `.pl-empty-hint`, `.pl-total`, `.pane-viz`, `#console-viz` | Adapt inherited palette/readability and silver mini-viz bezel only | R1/R2 black list/Total Time/silver frame | Low; do not claim empty/mini arrangement historical |
| C3 | `.stage-bg`, `bgFill()` | Black stage for Bars/Waves; no change to sampling or animation | R1/R2 | Low, presentation only |
| C3 | `.stage-overlay`, `.track-title`, `.track-sub` | Existing metadata to top left, artist above title, regular white type; reserve text bounds | R1/R2 | Low; video contain untouched |
| C3 | `.stage-tools`, `.tiny-btn`, `.viz-name` | Bottom-left black/plain arrows+label; remove chip glass/blur | R1/R2 | Low; same ids/handlers |
| C4 | `.console` | Silver/periwinkle housing, existing blue-glass transports untouched | R1/R2 + hard constraint | Low |
| C4 | `.seek-*`, `.vol-*`, `.seekbar`, `.volbar` in controls.css | Green fills, silver capsule thumb, 24px hit box; track still uses full pointer fraction | R1/R2 + usability | Low; bindSlider untouched |
| C4 | `renderPlaylist()`, `.tp:disabled` | Set `disabled` on prev/next when empty only; muted bezel; re-enable on add | Explicit C4 task; R1 gray glyph language | Low; playback functions untouched |
| C5 | `.statusbar`, `.sb-item`, `.sb-grow`, `.sb-dim`, `#status-text`, `#status-ext` | Neutral silver, short inset separators, ellipsis long status; hide empty extension segment | R4 generic XP; existing semantics | Low |
| C6 | `.dialog`, `.dialog-title`, `.dialog-x`, `.xp-button` | Generic XP blue border/caption/beige field + default/focus/pressed styles | R3/R4 | Low |
| C6 | `.menu-label` / menu handlers / About open-close handlers | Native button labels, expanded state, keyboard/escape/outside-click, trap/return About focus | Explicit C6 / current behavior, usability not original art claim | Low; do not touch media logic |
| Preserve | `.shell`, theater selectors, `#media`, window handlers, routing | No structure/window/media architecture changes, no new static assets/routes | Hard constraints | None |
| Preserve | `.wmp-orb`, `.clock`, `.drop-hint`, `drawBars`, `drawMini`, `drawWaves`, `drawAmbience` (except `bgFill`) | Leave unverified details alone | Gate below | None |

## Deferred details — not scheduled for speculative implementation

- `TODO(unverified)` **WMP 8 Bars/mini analyzer exact palette**: R1/R2 only show Ambience: Water. The proposed teal palette has no verified pixels; retain current custom animation/palette/reflection. Current modes are approximations, not original Microsoft visualizers.
- `TODO(unverified)` **WMP 8 About body, large logo, version/copyright layout**: generic XP Notepad is not proof of WMP contents. Keep Nostalgic Edition disclosure, orb and body arrangement.
- `TODO(unverified)` **multicolour caption icon**: R2 thumbnail proves a different icon, but not enough detail to redraw it accurately; existing orb stays.
- `TODO(unverified)` **empty-state note/text, duplicate mini viz, clock, +/× header, exact Title/Artist/Length columns**: current usability extensions retained; do not invent a historical rationale.
- `TODO(unverified)` **playlist active selection gradient**: playing text is green in R1/R2, but neither screenshot proves the selected-row background. Retain agreed current blue selected row; only green playmark is evidence-backed.
- `TODO(unverified)` **popup hover and per-command artwork**: no WMP 8 menu-open image obtained; no fake historical icons, accelerator labels or menu items will be added. Generic XP menu treatment is explicitly an approximation.
- `TODO(unverified)` **bottom Stereo/extension status segments and drop hint**: retain semantics. Stereo is an existing fixed label, not detected channel metadata. Drop hint remains existing art.

## Verified but constrained deviations

R1/R2 place task navigation at left, playlist at right, and have a sculpted frame. Restoring dead task rail/stub views or changing the user's prescribed shell is forbidden, so those differences remain. Blue-glass transport must remain as agreed, although original has paler controls and a compact two-tier housing. R2 justifies the ordinary XP outer title/menu frame; it does not eliminate the missing inner sculpted outline. No claim of indistinguishable/pixel-perfect WMP 8 is warranted.

## Validation contract

Before implementation, `assert-wmp8.js` evaluates stage-specific rendered guarantees (RED baseline). Re-run with each embedded release build. Screenshots after **each** C1–C6; final actual-window state matrix in `VISUAL-REVIEW.md`; playback/UI matrix in `REGRESSION-WMP8.md`. Raw evidence is kept locally, never uploaded. No Node/npm/test libraries are introduced; PowerShell talks to the opted-in WebView2 CDP endpoint.

Stage B note: complete region map + explicit constraints, tokens scheduled → this document and top-of-style.css token block → R1/R2/R3/R4 → no unverified replacement scheduled; exact full-mode geometry and unverified details need user confirmation/reference for further work.
