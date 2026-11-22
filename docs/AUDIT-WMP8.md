# Stage A — WMP 8 authenticity audit

Date: 2026-11-22. Scope: the existing single Rust/wry window, not a new skin engine.
Read before edits: `PLAN-WMP8.md`, `README.md`, all four UI entry files, `src/main.rs`.

## Reference register / gate

| ID | Verified source | Local evidence | What it proves |
| --- | --- | --- | --- |
| R1 | [GUIdebook, XP Pro / Media Player 8, view 1](https://guidebookgallery.org/screenshots/winxppro#mediaplayer) | `references/guidebook-wmp8-full.png` (670×482) | Sculpted periwinkle/silver full-mode frame, black playlist, white text, lime playing text/readout, green sliders, silver circular transport; artist above large title at top of black stage. |
| R2 | Same page, view 2; actual URL ends **`winxppro-1-2.png`**, not `winxppro-2-1.png` | `references/guidebook-wmp8-classic-frame.png` (678×536) | Same WMP 8 inside an XP blue system caption, File/View/Play/Tools/Help on beige menu strip, white caption glyphs, orange/red close button. Confirms which outer-frame treatment is historically possible. |
| R3 | [GUIdebook XP application About](https://guidebookgallery.org/screenshots/winxppro#aboutapplication) | `references/guidebook-xp-about-application.png` | Generic XP **Notepad**, not WMP: blue dialog caption, beige surface, compact OK button. Only generic XP dialog chrome is evidence-backed. |
| R4 | [GUIdebook XP Notepad](https://guidebookgallery.org/screenshots/winxppro#notepad) | `references/guidebook-xp-notepad.png` | Generic XP typography/menu/caption metrics and understated bevels. Not evidence for WMP-specific menu entries. |
| R5 | User-local `C:\Users\киря\Downloads\Windows media player.jfif` | Read in place; not shipped | Mini/skin-mode player, wrong mode for this task; excluded from full-mode mapping. |
| B0 | Existing app, actual WebView2/CDP capture | `shots/A-baseline-1000x690.png`, `shots/A-baseline-1000x690-native.png` | Baseline only, **not historical evidence**. `docs/screenshot.png` and root `check-*.png` are also prior app captures, not WMP references. |

GUIdebook labels the two screenshots **Media Player 8**; its gallery dates to 2002–2006. Do not substitute the adjacent Server 2003/WMP 9 images. Wikipedia's current hero is WMP 12 and its Bars mini-player image is WMP 11: both excluded. The archive.org search returned modern third-party skins and installer collections, not verified full-mode pixels. Web search integration returned HTTP 402; direct gallery retrieval worked. No full-mode user reference was found in Downloads. `winhistory-xphome4.jpg` turned out to be Help and Support, so it is not a player reference.

## Actual UI inventory and gaps

All sizes are CSS px at 100% Windows DPI. Tahoma 11px base; secondary sizes 9.5–10px. No UI build step. The four embedded routes already cover all proposed changes; no new runtime images are needed.

| Region / existing selectors | Baseline | WMP 8 observation / action | Gate |
| --- | --- | --- | --- |
| Frame `#app`, `.titlebar`, `.title-text`, `.win-btn`, `.wmp-orb` | 1px dark border; 32px caption, dark navy double/gloss band; 12px spaced/glowing title; 22×20 buttons; blue play orb | R2 supports XP blue caption with 13px caption and compact buttons. Remove artificial middle gloss seam/glow. Detailed multicolour WMP icon cannot be reconstructed confidently from tiny screenshot: retain orb. | Caption backed R2/R4; icon `TODO(unverified)`. |
| `.menubar`, `.menu-label`, `.menu-pop` | 24px pale blue gradient; rounded labels; white popups with broad 8px shadow | R2 beige system-menu strip, tightly spaced Tahoma. Map to XP menu surface/1px bevel; keep actual five menus and commands. Popup contents/hover pixels not shown by R2. | Strip backed R2; precise WMP popup art `TODO(unverified)`; use conservative XP chrome only. |
| `.shell`, `.playlist-pane` | 248px left pane, 196px below 960; rows stage / 92px console / 22px status; silver-blue pane | Real full mode has left task rail and right playlist. User explicitly removed the dead task rail and requires existing structure: **do not restore or move panes**. | Historical location backed R1/R2, intentionally not implemented under scope. |
| `.pane-header`, `.pane-title`, `.pane-btn`, `.pl-cols` | 29px header; 20×18 +/×; white three-column list; 20px column band | R1/R2 support cool silver/periwinkle framing and black list. Keep current three columns, add/clear and truncation; reduce modern blue tint/letterspacing. | Frame/list palette backed; these exact buttons/columns `TODO(unverified)` and retained. |
| `.pl-item`, `.pl-title`, `.pl-artist`, `.pl-dur`, `.pl-playmark` | ~20px grid rows, zebra, glossy blue active fill + white playmark; 52px length | R1/R2 black playlist with white text and green playing text. Map plain rows to black/near-black and pale text, green active playmark. Do not invent the full selection highlight: retain existing blue selection gradient. | Base palette/playing cue backed; active selection treatment `TODO(unverified)`. |
| `.pl-empty`, `.pl-total`, `.pane-viz`, `#console-viz` | White empty guidance, 32px note; blue-gray total and mini analyzer | Total Time at lower right of black playlist verified. Empty copy/note and duplicate mini viz are current usability features, not established WMP 8 full-mode details. Adapt surrounding/list palette only; preserve content and positions. | Total/list black backed R1/R2; empty copy and mini-viz arrangement `TODO(unverified)`. |
| `.stage-bg`, `.stage-overlay`, `.track-title`, `.track-sub` | Blue vignette; bottom metadata, 15px bold glowing title | R1/R2 black stage; artist first, title below at top, white regular type. Move existing metadata, reserve width, use black stage. Video already `object-fit:contain`. | Backed R1/R2. |
| `.stage-tools`, `.tiny-btn`, `.viz-name`, `.drop-hint` | Bottom-right glass/blur chip; dashed blurred drop overlay | R1/R2 bottom-left visualization arrows + plain bold label on black. Remove glass/blur **from chip**, use existing arrows. Drop overlay not evidenced: unchanged. | Switch backed; drop hint `TODO(unverified)`. |
| `drawBars`, `drawMini`, `bgFill`, `drawWaves`, `drawAmbience` | Modern blue/cyan glow, reflection and animated idle spectrum | R1/R2 show Ambience: Water only. Black backdrop is supported; exact Bars teal/green palette is **not** proven by this source. Do not recolour the bars speculatively, do not rename custom modes to claim original engines. | Backdrop backed; exact visualization engines/palettes `TODO(unverified)`. |
| `.console`, `.tp`, `.tp-main`, `.seek-*`, `.vol-*`, `.spk`, `.clock` | 92px pale blue console; agreed silver bezels/blue glass; thin blue progress; 14px slider hit box | R1/R2 silver/periwinkle control housing and green tracks; retain agreed blue glass and geometry, make tracks green, enlarge invisible hit box to 24px. Empty prev/next currently **not disabled** (baseline runtime assertion). Wall clock has no R1 counterpart: unchanged. | Housing/green tracks backed; clock and precise geometry retained deviation. |
| `.statusbar`, `.sb-item`, `#status-fmt`, `#status-ext` | 22px silver-blue, full-height single separator; fixed Stereo, extension text | R1/R2 put green song/time readout under stage; current bottom status layout must stay. Use neutral silver and short inset dividers only as generic XP treatment (R4). Keep Stereo semantics, do not imply codec/channel detection. | Specific WMP segments `TODO(unverified)`; generic bevels only. |
| `.modal`, `.dialog`, `.dialog-title`, `.xp-button` | Beige about card with blue gradient caption; no dialog role, no focus capture/return | R3 verifies **XP dialog chrome**, not WMP About layout. Improve generic frame/caption/OK; preserve honest Nostalgic Edition text. Add modal focus without touching playback. | Chrome backed R3; exact WMP About body/logo `TODO(unverified)`. |
| Theater/window edges/video | Current F11/IPC/6px resize hit zones, letterboxing | Existing functionality, not an authenticity redesign. Regression-test at 1000×690 and 880×600. | Preserve. |

## Short actionable gap list

1. Replace dark invented caption sheen / blue menu strip with verified XP outer-frame option.
2. Use black list + neutral metallic framing, preserve compact grid and selection mechanics.
3. Flatten stage backdrop and use verified top metadata / bottom-left viz strip.
4. Extend agreed transport with green tracks, larger hit boxes and real disabled empty prev/next.
5. Tighten generic silver status bevels without inventing metadata.
6. Make existing About chrome XP-like and focus-safe; retain honest non-Microsoft contents.

State contract: empty offers add-files; metadata probing may show `--:--` (partial); playable import starts playback (success); unsupported/failed decode shows status message (error); file/folder access uses native user chooser (permission/cancel); no network/loading view is introduced. Target viewports: **1000×690**, **880×600**, native theater viewport. Primary action remains add files / play. This is a constrained authenticity improvement, not a claim of exact replication of the sculpted full-mode outline.

Stage A note: audited source + actual app, saved R1–R4 and baseline shots → docs/reference files only; UI unchanged → evidence above → exact Bars/About art and incompatible full-mode geometry remain open, explicitly gated.
