# Title, web fullscreen gate, loading

Status: binding design
Read when: title / play menu, web fullscreen gate, loader
See also: `design/ui.md`, `design/ui-theme.md`, `design/ui-hud.md`, `design/ui-pause.md`, `design/ui-run-flow.md`, `design/ui-gear-entry.md`, `design/gear-ui.md`, `design/hub.md`, `design/input.md`, `design/doc-refactor.md`

## Title / play menu

`scripts/title.gd` is the play menu. Overlay body lives in `scripts/title_news.gd`. The card MUST show `Version: {label}` from `version.json` at all times.

Buttons, top to bottom: Play (or Play — Male / Play — Female), Updates, Archives.

When the current label is newer than saved `last_seen_game_ver`, a “what’s new” overlay MUST appear on this menu before Play is used. Updates opens the same overlay on demand.

- Gamepad-first. A / Start or B / Esc dismisses, writes `last_seen_game_ver` to the current label, saves, and focuses Play.
- Overlay always lists every `changelog.json` entry, newest first (current series baked into JSON).
- Entries with `label` greater than `last_seen_game_ver` render bold / gold. First launch or wiped save: only the current build is marked new; older JSON rows still list.
- Older series: keep the in-series list, plus one control that opens `https://viraxvespa.github.io/WhatDwellsBelow/changelog/`.
- Body shape on screen: build label as a heading, key points, optional subpoints, then the Summary line. Markdown (`**bold**`, `` `code` ``) renders.
- Long lists scroll with mouse wheel and right stick. D-pad only moves Close / Earlier weeks.
- Text sits on a solid title-card panel. Play / Updates / Archives MUST NOT take focus while the overlay is open.

Archives opens the shared two-column browser (`design/archives.md`). It is title-only. Pause Settings MUST NOT list Archives.

## Web fullscreen gate

On the web export only, `scripts/boot.gd` MUST open `scenes/fs_gate.tscn` before the credit splash when `DisplayMode.wants_gate()` is true. Desktop and Xbox feature-tag boots stay boot → splash.

Show the gate once per browser tab session (`sessionStorage`). Skip it when the page is already fullscreen, or when the PWA is already standalone (`display-mode: standalone` / `navigator.standalone`). Smoke boot routes MUST still skip splash and the gate.

Copy and the action button MUST follow the UA bucket:

- Desktop web — Fullscreen requests canvas fullscreen from the tap. Chromium may also fire the stashed PWA install prompt.
- Android web — same tap; label may read Fullscreen / Install.
- iOS web — Safari cannot open Add to Home Screen from script. Action is Try fullscreen (requestFullscreen, usually a no-op on iPhone). Body tells the player Share → Add to Home Screen → Add, with Open as Web App on.

Gamepad-first: first focus is the action button and MUST stay on a gate button for the whole card. `Pad.wake_web()` may focus the canvas and drop GUI focus; the gate MUST grab the action button again afterward. A / Start / `ui_accept` confirms the focused control. B / Esc / Continue marks the session seen and goes to splash. Because `web_pad.gd` does not inject A / B as Godot joy events, the gate MUST also poll `App.web_pad` A / B / Start / Back.

`requestFullscreen` is asynchronous. The gate MUST watch `DisplayMode.is_fullscreen_now()` / standalone and advance to splash as soon as fullscreen actually lands (Fullscreen button, A, or Alt+Enter). Do not leave the card up after a successful enter. iOS stays on the card after Try only when fullscreen did not actually happen.

If the viewport is taller than wide, the card MUST say to rotate to landscape. Landscape lock is attempted from the same gesture (`design/save-tech.md`).

## Live snapshot — title

`title.gd` builds the card and focus graph. `title_news.gd` builds the overlay.
Play / Updates / Archives drop to `FOCUS_NONE` while the overlay is open. Close is the focused control. Right stick and mouse wheel move `ScrollContainer.scroll_vertical`. Overlay body is a `RichTextLabel` on an opaque panel.

## Live snapshot — web fullscreen gate

`scripts/ui/fs_gate.gd` on `scenes/fs_gate.tscn`. `scripts/display_mode.gd` owns platform buckets, window modes, sessionStorage, landscape lock, Esc hooks, and the PWA install prompt. `scripts/boot.gd` routes web → gate when the session still needs it. The gate rebuilds two themed buttons, keeps focus after `wake_web`, polls `App.web_pad` for A / B / Start / Back, and leaves to splash when fullscreen or standalone becomes true.

## Live snapshot — loading bar (`loader.gd`)

`CanvasLayer` layer 110 on `App`. Survives scene changes. Title → Placeholdia uses `App.play_from_menu` → `AppFlow.play_from_menu_async`.

- `begin(heading, status)` shows the overlay and seeds the bar so it is never stuck at 0%.
- `set_status(text)`
- `set_progress(0..1)` only raises the target.
- `_process` eases `_shown` toward the target.
- `finish()` snaps to 100%, hides, calls `App.wake_web_pad()`.

Visual: full-viewport dim, heading, status, percent, 720×20 gold fill on a dark track. Positions are computed from `get_viewport().get_visible_rect()` so the overlay stays centered on desktop and the no-threads web export.

Play → camp pacing in `scripts/app_flow.gd`:
- Preload listed hub assets up to about 70%, with status lines for camp / tiles / buildings / delver / music.
- Ease toward 90% while still on the title scene.
- `go_camp()` (scene instantiate may hitch; the bar is already near the end).
- After camp is ready, ease 92% → 100% with “The square holds.”, then hide.
