# Web touch input

Status: binding design
Read when: web touch pad / touch HUD input
See also: `design/input.md`, `design/input-gamepad.md`, `design/input-rebind-prompts.md`, `design/input-kb-mouse.md`, `design/input-live.md`, `design/ui.md`, `design/ui-hud.md`, `design/doc-refactor.md`, `design/README.md`

## Input – Web touch (`touch_pad.gd`, `touch_hud.gd`)

Web-only. Not a native Android / iOS export requirement.

Show the overlay when all of these are true:

- `OS.has_feature("web")`
- Mobile user-agent (`navigator.userAgentData.mobile` or a mobile UA string)
- No connected browser gamepad (`navigator.getGamepads()` / Godot joypads)
- No physical keyboard key this session
- Current scene is `camp.tscn` or `dungeon.tscn`
- `App.ui_open` is false

Debug Settings **Force touch overlay** skips the web / UA / keyboard / pad checks for the rest of the session so desktop can preview the cluster. It still hides while `App.ui_open`.

Hide immediately if a gamepad connects or a keyboard key arrives (unless force-show is on). Overlay chrome is dungeon-themed discs drawn in code (no extra PNG pack). Wells stay translucent so the world remains readable under the larger cluster.

No right aim well. Auto-aim / target-lock stays armed for the whole touch session (`Touch.active()` forces `lock_armed`). Facing follows the lock target when one exists, otherwise walk / last facing.

| Control | Behavior |
|---------|----------|
| Left half, below the HUD | Dynamic move stick. Finger-down parks with no chrome. The well appears under that finger only after a directional drag past `TOUCH_DEAD`, and only if pinch is not already active |
| Right-hand cluster | Low-right (about 86% × 78% of the viewport, clamped off the bezel). Small top row: map / food / potion / pause, centered on the 2×2. Large 2×2 under it (25% bigger than the pre-tune wells, grown top-left): attack / special on top, interact / dash on the bottom |
| RT glyph | Hold-to-attack while the finger is down. No double-tap latch |
| LT / B / A glyphs | Special, dash, interact |
| Menu / View glyphs | Pause, map. Map well stays visible in Placeholdia but is disabled (no tap) |
| D-pad Up / Left glyphs | Potion, food |
| Pinch | World or map zoom if the walk stick is not claimed. A parked left finger does not count as claimed |
| Swipe | Pans the large map when zoomed in, if the walk stick is not claimed and the finger did not start on a cluster button |

Touch attack lasts only while the finger is on RT. Open UI, scene change, death / dispel, or pad / keyboard takeover clear it. Touch vectors and button state feed `Pad.move()`, `Pad.held()`, and `Pad.just()` so combat, gather, and interact stay on one path.

Numbers: `TOUCH_DEAD` (0.24) in `design/tunables.md`. Look/pinch/wheel rates live there and on `LookCtrl` runtime copies. Secret debug Settings page can live-edit touch deadzone and look copies.

