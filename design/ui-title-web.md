# Title, web fullscreen gate, loading

Status: current plan  
Read when: title / play menu, web fullscreen gate, loader  

## Title / play menu

`scripts/title.gd` is the play menu. Overlay body lives in `scripts/title/news.gd`. The card MUST show `Version: {label}` from `version.json` at all times.

Buttons, top to bottom: Play (or Play — Male / Play — Female), Updates, Archives.

When the current label is newer than saved `last_seen_game_ver`, a “what’s new” overlay MUST appear on this menu before Play is used. Updates opens the same overlay on demand.

- Gamepad-first. A / Start or B / Esc dismisses, writes `last_seen_game_ver` to the current label, saves, and focuses Play.
- Overlay always lists every `changelog.json` entry, newest first (current series baked into JSON).
- Entries with `label` greater than `last_seen_game_ver` render bold dried-ink. First launch or wiped save: only the current build is marked new; older JSON rows still list.
- Older series: keep the in-series list, plus one control that opens `https://viraxvespa.github.io/WhatDwellsBelow/changelog/`.
- Body shape on screen: build label as a heading, key points, optional subpoints, then the Summary line. Markdown (`**bold**`, `` `code` ``) renders.
- Long lists scroll with mouse wheel and right stick. D-pad only moves Close / Earlier weeks.
- Text sits on a solid title-card panel. Play / Updates / Archives MUST NOT take focus while the overlay is open.

Archives opens the shared two-column browser (archives). It is title-only. Pause Settings MUST NOT list Archives.

## Web fullscreen gate

On the web export only, `scripts/boot.gd` MUST open `scenes/fs_gate.tscn` before the credit splash when `DisplayMode.wants_gate()` is true. Desktop and Xbox feature-tag boots stay boot → splash.

Show the gate once per browser tab session (`sessionStorage`). Skip it when the page is already fullscreen, or when the PWA is already standalone (`display-mode: standalone` / `navigator.standalone`). Smoke boot routes MUST still skip splash and the gate.

Copy and the action button MUST follow the UA bucket:

- Desktop web — Fullscreen requests canvas fullscreen from the tap. Chromium may also fire the stashed PWA install prompt.
- Android web — same tap; label may read Fullscreen / Install.
- iOS web — Safari cannot open Add to Home Screen from script. Action is Try fullscreen (requestFullscreen, usually a no-op on iPhone). Body tells the player Share → Add to Home Screen → Add, with Open as Web App on.

Gamepad-first: first focus is the action button and MUST stay on a gate button for the whole card. `Pad.wake_web()` may focus the canvas and drop GUI focus; the gate MUST grab the action button again afterward. A / Start / `ui_accept` confirms the focused control. B / Esc / Continue marks the session seen and goes to splash. Because `web_pad.gd` does not inject A / B as Godot joy events, the gate MUST also poll `App.web_pad` A / B / Start / Back.

`requestFullscreen` is asynchronous. The gate MUST watch `DisplayMode.is_fullscreen_now()` / standalone and advance to splash as soon as fullscreen actually lands (Fullscreen button, A, or Alt+Enter). Do not leave the card up after a successful enter. iOS stays on the card after Try only when fullscreen did not actually happen.

If the viewport is taller than wide, the card MUST say to rotate to landscape. Landscape lock is attempted from the same gesture (save_tech).

## Title card and Updates overlay

`title.gd` builds the card and focus graph. `news.gd` builds the overlay.
- Title backdrop is `assets/ui/load_background.jpg` full-bleed (no global dim). A centered paper card sits behind the title and the buttons. Play is the primary weight. Updates and Archives are secondary. New changelog rows are bold dried-ink, not gold.
Play / Updates / Archives drop to `FOCUS_NONE` while the overlay is open. Close is the focused control. Right stick and mouse wheel move `ScrollContainer.scroll_vertical`. Overlay body is a `RichTextLabel` on an opaque panel.

## Web fullscreen gate wiring

`scripts/ui/fs_gate.gd` on `scenes/fs_gate.tscn`. `scripts/display_mode.gd` owns platform buckets, window modes, sessionStorage, landscape lock, Esc hooks, and the PWA install prompt. `scripts/boot.gd` routes web → gate when the session still needs it. The gate rebuilds two themed buttons, keeps focus after `wake_web`, polls `App.web_pad` for A / B / Start / Back, and leaves to splash when fullscreen or standalone becomes true.

## Loading bar (`loader.gd`)

`CanvasLayer` layer 110 on `App`. Survives scene changes. Title → Placeholdia uses `App.play_from_menu` → `AppFlow.play_from_menu_async`.

- `begin(heading, status)` shows the overlay at 0%.
- `set_status(text)`
- `set_progress(v)` marks a milestone really reached (capped at 99%); `stage(from, to)` starts a step: the bar eases to `from`, then creeps toward `to` while the step works; `stage_at(from, to, u)` is sub-progress inside a step. The shown value never goes back.
- The fill and the % label draw the same value (label floored, 100% only from `finish()`).
- `finish()` fills to 100%, hides, calls `App.wake_web_pad()`.
- `?wdb-loader-trace` prints one `LOADTRACE` row per frame; `python tools/load_bars.py --site DIR` charts both bars cold and cached.

Visual: full-viewport dim, a paper card, ink heading, status, percent, and a 720×20 ink fill on a brown track. Positions are computed from `get_viewport().get_visible_rect()` so the overlay stays centered on desktop and the no-threads web export.

Play → camp pacing: each step's share of the bar is its expected time (`scripts/ui/loader_weights.gd`: per-platform defaults measured on web and desktop, then this machine's last runs from `user://loader_steps.cfg`); the fps settle has time-based sub-progress. `python tools/load_bars.py --desktop` charts the desktop loader cold and warm. The camp build and the warm-up frame each block for about a second on web; the bar cannot redraw inside them, so it moves on right after.

Web landing bar (`tools/web_shell.html`): one eased value draws the fill and the %; download bytes fill to 85%; after the last byte the page's main thread is blocked by wasm compile and engine start, so the % label steps aside and the fill eases toward 97% on the compositor (scaleX transition); it reads 100% only when the engine has started.
