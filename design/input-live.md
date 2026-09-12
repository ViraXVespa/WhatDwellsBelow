# Input live snapshots

Status: binding design
Read when: live snapshot for binds or web_pad
See also: `design/input.md`, `design/input-gamepad.md`, `design/input-rebind-prompts.md`, `design/input-kb-mouse.md`, `design/input-web-touch.md`, `design/ui.md`, `design/ui-hud.md`, `design/doc-refactor.md`, `design/README.md`

## Live snapshot — PC defaults (`binds.gd`)

These are implementation defaults, not a replacement for rebinding.

| Action | Keys |
|--------|------|
| Move | WASD / arrows (physical positions) |
| Aim | Mouse |
| Attack | LMB hold |
| Special | RMB |
| Dash | Space |
| Target-lock | Q |
| Interact | E / Enter |
| Inventory | I |
| Pause | Esc |
| Map | M |
| Potion | F |
| Food | C |
| Look mode | D-pad Down (pad only) |
| Zoom | Mouse wheel |
| Menu tabs | `[` / `]` |
| Gear tip | Y |
| Gear drop | X |
| Crystal zoom | Tab |
| Display toggle | Alt+Enter (desktop and web, not rebindable) |

`binds.apply_pc_defaults()` strips `KEY_R` from special. README text that still says “R special” is stale relative to live binds.

Q pages stats only while a gear board is open; during gameplay it remains target-lock. E pages stats only while a gear board is open; during gameplay it remains interact. LMB / RMB never page the stats card.

Y is `gear_tip` in the live map. The Animation Browser reuses that action for review-state cycle while the viewer is open.
X is `gear_drop` in the live map. The Animation Browser reuses that action for play/pause while the viewer is open.

## Live snapshot — web gamepad (`web_pad.gd`)

Web builds on GitHub Pages do not get a reliable Godot joypad. When `OS.has_feature("web")`, `scripts/web_pad.gd` reads `navigator.getGamepads()` through `JavaScriptBridge`.

- Polls the first connected pad each frame.
- Standard mapping: axes 0–1 move, 2–3 aim; button 0 A, 1 B; RT/LT attack/special; Start/Back; stick clicks.
- Stick deadzone ≈ 0.24. Button threshold ≈ 0.45.
- Only X / Y are injected as `InputEventJoypadButton`. A / B / Start / Back are flags on `App.web_pad`. The fullscreen gate and any other pre-canvas menu MUST poll those flags and MUST keep a focused `Button` after `Pad.wake_web()` (that helper may `gui_release_focus()` unless `release_gui` is false).
- Player must click the canvas once so the page can receive keyboard / gamepad input. The fullscreen gate focuses `#canvas` itself and then re-grabs the action button.
- Xbox pads work in Chromium-based browsers.
- After scene changes, `App.wake_web_pad()` refreshes the bridge.
- A connected browser pad hides the web touch overlay. `WebPad.browser_pad_connected()` is the shared probe.
