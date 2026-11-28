# Input (door)

Status: current plan  
Read when: device binds, aim  
Code: `scripts/input/` (`Pad` `pad.gd`, `Binds` `binds.gd` + `binds/`, `prompts.gd`, `look_ctrl.gd`, `touch_pad.gd`), `scripts/input/web_pad.gd` (code map row Input; gdhealth group `input`)

| Job | Open |
|-----|------|
| face buttons, Xbox layout | `design/input-gamepad.md` |
| rebind prompts, remap grid | `design/input-rebind-prompts.md` |
| WASD walk, LMB, Alt display toggle | `design/input-kb-mouse.md` |
| canvas thumbs, touch-HUD | `design/input-web-touch.md` |
| desktop defaults, navigator gamepads | `design/input-live.md` |

Input sits below the screens and the world: nothing in `scripts/input/` loads UI, world or app code. Pad tells the UI that the device mode flipped through `Pad.mode_changed` (App wires the prompt repaint at boot); look mode drives the dungeon map through the dungeon scene's `map_zoom_at` / `map_zoom_player` / `map_pan_by`. Screens call `Pad`, `Binds` and `Prompts`, never a `binds/` helper.
