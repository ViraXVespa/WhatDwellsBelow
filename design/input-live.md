# Input defaults and web pad

Status: current plan  
Read when: desktop defaults, navigator gamepads  
Code: `scripts/input/binds/table.gd`, `scripts/input/binds/defaults.gd`, `scripts/input/binds/letter_fit.gd`, `scripts/input/web_pad.gd`

## Defaults (`scripts/input/binds/table.gd`)

`table.gd` is the only place defaults are written; this table mirrors it. Every row is rebindable on Pause → Settings → Controls.

| Action | Keys |
|--------|------|
| Move | WASD / arrows (physical positions) |
| Aim | Mouse |
| Attack | LMB hold |
| Special | RMB |
| Dash | Space |
| Target-lock | T (by key label) |
| Interact | E / Enter |
| Inventory | I |
| Pause | Esc / Start (web: also F1) |
| Map | M |
| Potion | P (by key label) |
| Food | F (by key label) |
| Bow aim (Bow mode) | Shift hold (pad LT; Bow fire is pad RT only, LMB fires on keyboard) |
| Look mode | R3 (pad only) |
| Zoom | Mouse wheel |
| Menu tabs | `[` / `]` (LB / RB) |
| Gear tip | Y |
| Gear drop | X |
| Crystal zoom | Tab |
| Display toggle | Alt+Enter (desktop and web, not rebindable) |

`defaults.gd` also strips Space from Godot’s `ui_accept` / `ui_select`, so Space never confirms in a menu.

P / F / T are `letter` rows: they bind the logical keycode (the key's printed label), so they stay on P / F / T on AZERTY, QWERTZ and Dvorak. When a letter's label sits on a key a play bind already holds by position (Colemak prints F on QWERTY E, Interact), `letter_fit.gd` moves only that letter to the first free near key (G H V C B R Z N; Colemak Food goes to G); the save still records the letter. Desktop reads the layout from the OS; web (no layout query) learns it from the first clashing press, which is released so it fires only the position action. Check: camp-controls `colemak` + planted `colemak_plant`. Position keys (WASD, E, Space, I, M) bind `physical_keycode`. Gamepad defaults: input.platforms_gamepad. Gear stats paging is the fixed menu pair `page_prev` / `page_next` (Q / E, LT / RT), not a world bind. LMB / RMB never page the stats card.

Y is `gear_tip` in the live map. The Animation Browser reuses that action for review-state cycle while the viewer is open.
X is `gear_drop` in the live map. The Animation Browser reuses that action for play/pause while the viewer is open.

## Web gamepad (`web_pad.gd`)

Web builds on GitHub Pages do not get a reliable Godot joypad. When `OS.has_feature("web")`, `scripts/input/web_pad.gd` reads `navigator.getGamepads()` through `JavaScriptBridge`.

- Polls the first connected pad each frame.
- Standard mapping: axes 0–1 move, 2–3 aim; button 0 A, 1 B; RT/LT (buttons 7/6) Bow fire / Bow aim; Start/Back; stick clicks.
- Stick deadzone ≈ 0.24. Button threshold ≈ 0.45.
- Only X / Y are injected as `InputEventJoypadButton`. A / B / Start / Back are flags on `App.web_pad`. The fullscreen gate and any other pre-canvas menu MUST poll those flags and MUST keep a focused `Button` after `Pad.wake_web()` (that helper may `gui_release_focus()` unless `release_gui` is false).
- Player must click the canvas once so the page can receive keyboard / gamepad input. The fullscreen gate focuses `#canvas` itself and then re-grabs the action button.
- Xbox pads work in Chromium-based browsers.
- After scene changes, `App.wake_web_pad()` refreshes the bridge.
- A connected browser pad hides the web touch overlay. `WebPad.js_pad_any()` is the shared probe.
