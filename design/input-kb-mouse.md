# Keyboard / mouse

Status: binding design  
Read when: keyboard / mouse fallback  


## Input – Keyboard / mouse (fully featured fallback)

All gamepad actions MUST have keyboard/mouse equivalents. Mouse aim + hold-LMB for attack is the default mouse scheme. Every player action is rebindable (see Rebinding); menu navigation and sticks are fixed.

Mouse wheel zooms world camera or the large map as described under Look mode. It is not a rebindable InputMap combat action.

**Alt+Enter** is a fixed display toggle. It is not an InputMap action and MUST NOT appear on the rebind page. Enter alone stays Interact / confirm. Handled in `App._input` → `DisplayMode.handle_input` so it works while a menu is open.

- Desktop (`DisplayMode.uses_desktop_modes()`): if the window is windowed, apply the last saved fullscreen kind (`display_fs_kind`: borderless or true fullscreen; fresh default is borderless). If the window is already borderless or true fullscreen, return to windowed and leave `display_fs_kind` alone.
- Web / native Android / iOS (`DisplayMode.uses_web_fs_toggle()`): toggle the current fullscreen state through the same path as Pause → Settings → Graphics (`DisplayMode.set_web_fullscreen`). A keydown is a valid gesture for `requestFullscreen`.
- No-op on `xbox`.

**Esc** opens pause by default (rebindable) and always backs out of menus; Backspace backs out too. **Space** is dash only: it does nothing in menus and is not a confirm key (Enter, E, pad A confirm). On web it MUST NOT exit browser fullscreen. Only Pause → Settings → Graphics and Alt+Enter leave web fullscreen. `DisplayMode.ensure_web_hooks()` installs a capturing `keydown` listener that `preventDefault`s Escape while `document.fullscreenElement` is set and stashes `window.__wdbEsc`. `DisplayMode.consume_web_esc()` / `Pad.pause_just()` turn that flag into pause when Esc is the pause bind; otherwise the page hands Esc to the game as a normal key press so it fires its bound action (or is captured by the rebind page). F1 is always pause on web.

**I** opens pause on Inventory from gameplay only. Same action as D-pad Right. MUST NOT jump tabs while pause or any other `App.ui_open` menu is already up.
