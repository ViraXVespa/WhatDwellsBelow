# Web touch input

Status: current plan  
Read when: web touch pad / touch HUD input  

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

Hide immediately if a gamepad connects or a keyboard key arrives (unless force-show is on). Overlay chrome is dungeon-themed discs drawn in code (no extra PNG pack). Wells stay translucent dark discs with light ink so the world stays readable under them. Buttons are labelled with what they do (Attack, Special, Dash, Use, Map, Pause), never pad glyphs. While the overlay is up, world prompt chips for those actions show the button's word in its ring, not a pad glyph (`prompts.gd` `touch_word` / `word_chip`; `layout_check.gd` `touch_prompt` in `dungeon-touch-controls`). On a touch device the overlay redraws every frame (lock glow, item counts, Bow mode and camp dimming change without a signal).

Geometry is one pure function, `touch_hud/hud_layout.gd` `compute(canvas, insets, bow)`, shared by drawing, hit-testing and the check. Sizes are canvas units on the 1080-tall canvas, scaled by the short side (clamped 0.75–1.25), sized for a phone held sideways: Attack about 13 mm, the other thumb buttons about 9.5 mm, item slots about 7 mm. Everything sits inside the safe area (CSS `env(safe-area-inset-*)` on web, the display safe area on mobile, `Touch.safe_insets`), and the playfield centre (the middle 30% × 40%) stays clear.

Target lock starts armed on touch (`apply_pref`); the lock slot toggles it like T / D-pad Down. Facing follows the lock target when one exists, otherwise walk / last facing.

| Control | Behavior |
|---------|----------|
| Left side, below the HUD card (x ≤ 45%, y ≥ 25%) | Floating move stick. A finger down anywhere in the zone claims the stick there; dragging steers. The idle ring bottom-left marks the zone |
| Attack | Bottom-right corner, the biggest button. Hold-to-attack while the finger is down. No double-tap latch |
| Special / Dash / Use | Fanned on the right thumb's arc around Attack: left, up-left, up. Use is interact |
| Potion / Food / Target lock | Item slots in a row above the arc (a column up the right edge on a 4:3 canvas). Potion and food show the HUD item icon and count; the lock slot is a crosshair that glows while armed |
| Map / Pause | Two small chips at the top centre, clear of the HUD card and the minimap |
| Bow mode aim stick | With Bow mode on and the longbow equipped, Attack becomes a stick: finger down aims and fires, dragging steers the shot (past `TOUCH_DEAD`); a plain tap fires at the lock / facing |
| Camp | Map, food, potion and lock dim and ignore taps; the rest stay live |
| Pinch | World or map zoom if the walk stick is not claimed |
| Swipe | Pans the large map when zoomed in, if the walk stick is not claimed and the finger did not start on a button |

Touch attack lasts only while the finger is on Attack. Open UI, scene change, death / dispel, or pad / keyboard takeover clear it. Touch vectors and button state feed `Pad.move()`, `Pad.aim()`, `Pad.held()`, and `Pad.just()` so combat, gather, and interact stay on one path.

Check: `dungeon-touch-controls` flow (`debug/touch_layout_check.gd`): layout over phone / 16:9 / 4:3 canvases with and without notch insets and Bow mode, planted overlap / off-screen / centre faults, then live screen touches on every button, the move stick and the bow stick.

Numbers: `TOUCH_DEAD` (0.24) in the tunables gate; button radii in `hud_layout.gd`. Look/pinch/wheel rates live in tunables and on `LookCtrl` runtime copies. Secret debug Settings page can live-edit touch deadzone and look copies.
