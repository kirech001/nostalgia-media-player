# PLAN — Windows Media Player 8 (Windows XP) visual authenticity

Status: active
Owner of execution: GPT 6.1 Sol
Repo: `D:\Kirech Media Player` (no git; files are edited in place)

## 0. Goal

Make the UI of Kirech Media Player visually indistinguishable-in-spirit from the
default **Windows Media Player 8.0 for Windows XP** skin, while keeping every
player function working (playback, playlist, seek, volume, visualizations,
theater mode, window controls, menus, About).

This is **not** a modern redesign. No Fluent, no WMP 9/10/11/12, no Spotify look,
no "minimalism". Target: 2001 Luna-era desktop software.

## 1. Hard rules

1. **Do not change architecture or playback logic** unless a task explicitly asks.
2. **Do not add dependencies** (no frameworks, no CSS libs, no icon packs).
3. Keep existing file names and structure. Entry points:
   - `ui/index.html`, `ui/style.css`, `ui/controls.css`, `ui/app.js`
   - `src/main.rs` (window + `wmp://` asset routes)
4. New static asset = add it **both** to `include_bytes!` and to `serve()` in
   `src/main.rs`.
5. **Do not invent WMP 8 elements.** If a detail is not verified, mark it
   `UNVERIFIED` in `docs/MAP-WMP8.md` and leave the current behavior.
6. Work in stage order A → B → C → D → E. Do not skip the reference gate.
7. Never claim "done" without a build + screenshots + a functional check.
8. Keep the already-agreed look of `ui/controls.css` (silver bezels, blue glass
   transport). Only extend it, don't restyle from zero.

## 2. Current baseline (verified, 2026-11)

- Build is green: `cargo build --release` → `Finished release profile`.
  PowerShell may print a NativeCommandError and return exit code 1 while the
  build actually succeeded — trust the `Finished` line.
- Window: inner `1000×690`, min `880×600`, custom frame (no native decorations).
  Outer size at 100% DPI is `1016×698`. Window controls are HTML (`#btn-close`,
  `#btn-min`, `#btn-max`) and send IPC (`close`, `minimize`, `maximize`).
- `wmp://` routes: `/`, `/style.css`, `/controls.css`, `/app.js` only.
- Layout: `.shell` = `grid-template-columns: 248px minmax(0,1fr)`,
  rows `minmax(0,1fr) 92px 22px`.
  - col 1 / rows 1–2: `aside.playlist-pane` (Title / Artist / Length list,
    pane header with `+` and `×`, `Total Time`, `canvas#console-viz`).
  - col 2 / row 1: `section.stage` (`canvas#viz`, `video#media`, overlay,
    viz switch, drop hint).
  - col 2 / row 2: `section.console` (transport, seek, volume, clock).
  - row 3 spans: `footer.statusbar`.
- `@media (max-width: 960px)` narrows the playlist pane to `196px`.
- Theater mode: `#app.theater` hides menubar + playlist pane, stage takes the
  full width.
- Playlist rows are a 3-column grid matching the header
  (`minmax(0,2fr) minmax(0,1fr) 52px`); active row has a play mark, zebra
  striping and a blue gradient.
- Dead code from the old left rail / Info Center / Media Library / stub views has
  been removed. `renderPlaylist()` is the only list renderer now.
- The media layer is a plain `<video>` element; WebView2 plays
  mp3/flac/wav/ogg/m4a/mp4/webm. WMA/WMV/MKV/AVI need libmpv — out of scope.

Known cosmetic risks to review in stage D:
- `#viz` bars palette is a modern cyan/blue; WMP 8 "Bars" is teal/green-blue.
- Titlebar gradient / caption buttons may be too "flat XP" vs WMP 8.
- Menu bar font/spacing, statusbar segment separators.
- Seek/volume thumbs and their hit areas.
- Partial padding consistency between playlist header, list and total row.

## 3. Stage A — UI audit (1 pass, ~30–40 min)

Deliverable: `docs/AUDIT-WMP8.md`.

1. Inventory the live UI from the actual files (not from memory):
   regions, element ids/classes, sizes, colors, gradients, fonts.
2. For every region record: current look → WMP 8 look → evidence.
3. Find **verified** references before any visual change:
   - user-provided images (ask the user; check `C:\Users\киря\Downloads\` for
     player screenshots — the known file there is a *mini player*, not full mode);
   - archive.org snapshots of `windowsmedia.com` / microsoft.com WMP 8 pages;
   - Wikimedia/Wikipedia media of WMP 8;
   - vintage screenshot galleries (winhistory.de, guidebookgallery archive).
4. Reference gate: if a region has no verifiable reference, do not redesign it.
   Record it as `TODO(unverified)` and move on.

Exit criteria: audit doc exists, every region is either "evidence-backed" or
explicitly marked unverified, and the gap list is short and actionable.

## 4. Stage B — Design mapping (~30 min)

Deliverable: `docs/MAP-WMP8.md` + a token block at the top of `ui/style.css`
(do **not** introduce a build step; CSS custom properties are fine).

Map:
- palette: Luna blue caption gradient, playlist pane silver, list selection
  blue, workspace black/blue, statusbar silver;
- type: Tahoma 11px base, 8–9px secondary, bold headers;
- metrics: titlebar 30–32px, menubar 22–24px, console height, statusbar 20–22px,
  playlist pane width, row height;
- controls: bezel radii, inner highlights, pressed offsets, disabled states;
- each existing selector that will change, in a table:
  `selector → change → evidence → risk`.

Rules: no new selectors that duplicate an existing component; extend the
existing ones. Mark anything speculative.

Exit criteria: mapping table covers 100% of the regions from stage A, no
`UNVERIFIED` item is scheduled for implementation without user approval.

## 5. Stage C — Implementation (main work)

Order matters; build + screenshot after each sub-step.

- **C1. Titlebar + menubar**: caption gradient, caption text/icon, min/max/close
  glyph sizing and hover/pressed states; menubar background, label padding,
  popup border/shadow/hover.
- **C2. Playlist pane**: header (title + buttons), column header, row metrics,
  zebra/selection/play-mark, empty state, `Total Time` row, mini visualization
  frame. Must stay usable at 196px width: truncation, no horizontal overflow.
- **C3. Stage**: background gradient/vignette, track title/sub typography
  placement, viz switcher chip, drop-hint styling; video letterboxing.
- **C4. Console / transport**: keep `controls.css` language; align button
  diameters, spacing, seek track/fill/thumb, volume, clock; disabled states for
  prev/next when the playlist is empty.
- **C5. Statusbar**: segment separators, text sizes, colors, `Stereo` and
  extension segment behavior.
- **C6. Dialog + menus**: About dialog frame, titlebar, buttons, focus; menu
  open/close behavior (open on mousedown, close on outside click, Escape).

Exit criteria: every scheduled item from the map is implemented; no layout
overflow at 1000×690, 880×600, 196px pane, and theater mode.

## 6. Stage D — Visual review

Deliverable: `docs/VISUAL-REVIEW.md` + screenshots in `docs/shots/`.

Required shots (app window, not mockups):
1. default empty state, 1000×690
2. playlist with 4+ tracks, one active
3. menu open (File and Help)
4. About dialog
5. narrow window 880×600
6. theater mode (F11)
7. video playing (letterboxed)

Checklist per shot: alignment to a 1px grid, no clipped text, no doubled
borders, consistent corner radii, correct gradient direction, readable contrast,
hover/pressed states, no leftover modern accents.

Exit criteria: zero P1 (broken/unreadable/misaligned) and zero P2 (visibly wrong
vs evidence) findings; P3 wishes documented but not blocking.

## 7. Stage E — Regression check

Functional matrix (must all pass):
- add files via File → Add Files, via drag & drop, via `+` in playlist header;
- add folder; clear playlist; total time updates; empty state returns;
- click a row → plays it; active row + play mark update;
- play/pause toggle (button + Space), stop, next, previous (buttons + keys);
- seek by click and drag; time labels update both directions;
- volume slider + wheel + mute; clock stays correct;
- visualization switch (Bars/Waves/Ambience) via chip and View menu;
- theater mode F11 / View → Full Screen, and exit;
- About from Help; Escape closes it;
- window min/max/close, drag by titlebar, resize edges within min size;
- no JS exceptions in the console during the whole pass;
- `cargo build --release` is green and the exe starts.

Deliverable: `docs/REGRESSION-WMP8.md` with pass/fail per item and evidence.

## 8. Verification harness (important)

Screenshots:
- `PrintWindow(hwnd, dc, 2)` (`PW_RENDERFULLCONTENT`) works and captures the
  WebView2 surface.
- **Pitfall:** if the player window is occluded by another app, Chromium may
  stop compositing, so screenshots show a stale frame and menu/hover changes
  never appear. Make sure the window is actually visible (topmost, unoccluded,
  restored) before judging a screenshot.
- **Pitfall:** `SetForegroundWindow` can silently fail. Before sending clicks,
  verify that the window under the click point belongs to the player process
  (`WindowFromPoint` → `GetAncestor(GA_ROOT)` → `GetWindowThreadProcessId`).
  If it doesn't, move/raise the window or ask the user to click.
- Clicks require real input (`mouse_event`/`SendInput`) at absolute screen
  coordinates; `PostMessage` into WebView2 does not work.

Preferred deterministic option (optional, use if available):
`WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--remote-debugging-port=9222`, then CDP:
`http://127.0.0.1:9222/json` → WebSocket → `Runtime.evaluate`,
`Page.captureScreenshot`, `Input.dispatchMouseEvent`. This gives DOM-level
checks and screenshots without window occlusion problems.

Test media: generate short WAV files with PowerShell
(`[System.IO.File]::WriteAllBytes` + a hand-built RIFF header) into
`docs/testmedia/`; they are disposable and must not be committed/kept in `ui/`.

Logs: a JS error should be treated as a failure even if the UI looks fine.

## 9. Report format for the executor

After each stage write a short note in the same doc:
`what changed → files touched → evidence (shot/command) → open items`.
At the end reply with:
1. stage status A–E,
2. list of changed files,
3. screenshots paths,
4. known deviations from WMP 8 and why,
5. anything the user must confirm.

## 10. Out of scope

- Mini player / two-window mode (separate future task).
- libmpv / WMA / WMV / MKV support.
- Skins engine, media library database, CD ripping, radio tuner.
- Any network features.
