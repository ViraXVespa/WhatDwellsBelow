# Web and mobile fullscreen

Status: current plan  
Read when: browser gesture, PWA standalone, orientation, Esc swallow  
Code: `scripts/display_mode/mode_desk.gd`, `scripts/display_mode/mode_hooks.gd`, `scripts/display_mode/mode_env.gd`, `scripts/display_mode/mode_web.gd`

- A browser lets a page go fullscreen only from a user gesture. `App.web_fullscreen` is the saved preference; the gestures are the gate button (`try_fullscreen_gesture`), the Settings Graphics toggle (`toggle_web_fullscreen`) and Alt+Enter.
- The request fullscreens the page root, not `#canvas`, so the touch keyboard's hidden input stays focusable; the canvas is the fallback. The order is pinned by `REQUEST_FS_JS` and smoke P1.
- `ensure_web_hooks()` installs the page listeners once: a capturing keydown that swallows Esc while the page is fullscreen (it reports Esc as 2 and F1 as 1 in `window.__wdbEsc`), the close chords, and keyboard lock on fullscreen change. `consume_web_esc()` reads and clears the flag each frame; when Esc is not the pause bind it is replayed as a normal Escape press (`send_esc`).
- Esc never leaves web fullscreen; Settings Graphics and Alt+Enter do.
- `is_fullscreen_now()` and `is_standalone()` read the page (`fullscreenElement`, `display-mode` media queries, `navigator.standalone`). `wants_gate()` is true on web only, outside xbox, when the page is neither fullscreen nor standalone and `sessionStorage` has no `wdb_fs_gate_seen`; `mark_gate_seen()` sets it. The seen flag is not a save key.
- `web_kind()` buckets the user agent: `ios`, `android` or `web`. The gate's copy and action follow it. Off the web it reports `ios` or `android` by feature tag, else `web`.
- `lock_landscape()` asks `screen.orientation.lock("landscape")` from the same gestures; iPhone Safari tabs may ignore it. `viewport_portrait()` feeds the gate's rotate line.
- Android and iOS builds (not web) toggle `WINDOW_MODE_FULLSCREEN` / windowed through `set_web_fullscreen`.
- `try_install_prompt()` fires the stashed PWA install prompt, if any, after the fullscreen request.
