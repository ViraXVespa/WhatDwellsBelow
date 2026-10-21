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

- Backdrop `assets/ui/load_background.jpg` full-bleed, no global dim. A centered paper card holds the title and buttons. Play is primary; Updates and Archives are secondary. New changelog rows are bold dried-ink, not gold.
- While Updates is open, the title buttons take no focus and Close is focused. Right stick and mouse wheel scroll the opaque overlay body.

## Web fullscreen gate wiring

Web boots into the gate while the session still needs it. Two themed buttons keep focus after the pad wakes, accept A / B / Start / Back, and the gate leaves to splash once fullscreen or standalone is true. `scripts/display_mode.gd` owns platform buckets, window modes, landscape lock, Esc hooks and the PWA prompt.

## Loading bar (`loader.gd`)

One overlay on `App` (layer 110) survives scene changes and covers Title → Placeholdia.

- A step eases to its start, then creeps toward its end while it works. A milestone caps at 99%; only `finish()` shows 100%. The shown value never goes back, and the fill and % label always agree.
- Each step's share of the bar is its expected time (per-platform defaults, then this machine's last runs). The camp build and warm-up frame block about a second on web, so the bar moves on right after them.
- Visual: full-viewport dim, paper card, ink heading, status, percent, and a 720×20 ink fill on a brown track, centered on the visible rect.
- Web landing bar (`tools/web_shell.html`): download fills to 85%; during wasm compile and engine start the fill eases toward 97% on the compositor; 100% only once the engine has started.
- Diagnose with `?wdb-loader-trace` and `python tools/load_bars.py` (`--site DIR`, `--desktop`).
