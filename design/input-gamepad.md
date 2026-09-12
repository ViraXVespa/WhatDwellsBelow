# Gamepad and shared menu input

Status: binding design
Read when: gamepad layout, look mode, or universal menus
See also: `design/input.md`, `design/input-rebind-prompts.md`, `design/input-kb-mouse.md`, `design/input-web-touch.md`, `design/input-live.md`, `design/ui.md`, `design/ui-hud.md`, `design/doc-refactor.md`, `design/README.md`

## Target platforms

- PC (primary)
- Web export that runs in modern browsers without requiring special COOP/COEP headers
- Web touch on a mobile user-agent when no physical keyboard or gamepad is present (virtual move stick + right-hand button cluster)
- Design MUST remain fully readable and playable from couch distance on a television (future Xbox / console consideration)

## Input – Gamepad (primary, Xbox layout)

- Left Stick: Movement
- Right Stick: Aim, except while look-mode is on or the large map is open (see Look mode)
- R3: Toggle target-lock (default off). On activation or when current target dies, lock nearest valid enemy in LOS and on-screen. Right-stick deflection cycles to the nearest enemy in that direction after a short delay. Lock breaks when no valid targets remain but stays armed for auto-reacquisition. Second R3 press disengages.
- RT: Hold-to-attack (basic attack of the currently equipped weapon). While a gear board is open, RT pages the stats card forward.
- LT: Special attack of the currently equipped weapon. While a gear board is open, LT pages the stats card back.
- A: Interact. In menus, confirm the focused control or a pending prompt.
- B: Dash. In menus, back one layer, or close the menu at root.
- Y: Gear tip on a gear board. In the secret Animation Browser, Y cycles the current clip’s review state (Good / Repack / Regenerate). World play does not consume Y for combat.
- X: Gear drop on a gear board. In the secret Animation Browser, X toggles play/pause and MUST NOT drop gear.
- D-pad Up: Use equipped potion
- D-pad Left: Use equipped food
- D-pad Right: From gameplay only, open pause on the Inventory tab. MUST NOT jump tabs or fire inventory while any menu is already open (`App.ui_open`). In menus D-pad Right stays `ui_right`.
- D-pad Down: Toggle look mode. World-only and large-map-only. MUST NOT fire as look-mode while pause, debug, recap, title, or any `App.ui_open` menu is up (`ui_down` stays menu navigation). Opening those menus clears look mode.
- Menu / Start: Pause. In an open menu, also acts as back / close.
- View / Back: Toggle large map overlay (game continues running underneath)
- LB / RB: Cycle tabs inside any menu that has tabs. Do not invent a second bumper path.

All controls, gameplay, and interfaces MUST be designed with a gamepad-first intent. Every menu MUST open with a valid initial focus already set so the player can immediately navigate and select using only the gamepad (no requirement to first highlight an element with the mouse).

There is no gamepad chord for display mode. Couch players change it on Pause → Settings → Graphics (`design/ui.md`). Keyboard / mouse uses Alt+Enter (below).

## Look mode

Action `look_mode` (default: D-pad Down). Session flag only; not saved. Pad-only in the rebind list.

World, map closed:

- Off: right stick aims
- On: right stick X = HUD scale, Y = world camera zoom (`App.set_hud_scale` / `App.set_zoom`)

Large map open:

- Off: right stick pans the map when zoomed in past fit
- On: right stick zooms the map toward the player marker

Keyboard / mouse: wheel up zooms in, wheel down zooms out. World camera when the map is closed; map zoom toward the cursor when the map is open. Wheel does not run while look-mode is blocked (menus / debug / recap).

Touch: pinch zooms the same two contexts toward the pinch midpoint, only while the walk stick is not claimed.

Map pan also: mouse drag and one-finger swipe when zoomed in, if the walk stick is not claimed.

`Pad.aim()` returns zero while look mode eats the right stick (`LookCtrl.eats_aim()`).

## Menus (universal)

Shared classifiers live in `scripts/ui/menu_pad.gd`. Any menu with tabs MUST call `Pad.tab_delta(event)` and apply that delta to its tab index. Do not invent a second bumper path.

| Input | Menu effect |
|-------|-------------|
| A / Enter / `ui_accept` | Confirm focused control. Second A confirms a pending prompt. |
| B / Esc / `ui_cancel` | Close a nested layer (re-equip list, Settings detail column, pending prompt). At root, close the menu. |
| LB / RB / `[` / `]` | Cycle tabs when the open menu has a tab strip. |
| Q / LT | Previous gear-board stats page |
| E / RT | Next gear-board stats page |
| I / D-pad Right | Gameplay only: open pause on Inventory. MUST NOT change tabs while a menu is already open. |

Exception: the secret Animation Browser keeps LB / RB = previous / next model, LT / RT = animation list, Y / `gear_tip` = review-state cycle, X / `gear_drop` = play/pause, D-pad = Facing/Animation columns, left stick = speed or frame step, and right stick = facing, per `design/debug.md`. While that viewer is open those chords MUST NOT fire world or gear-board actions (X must not drop gear). Keyboard Y types into the notes field when that field has focus; gamepad Y still cycles.

Menu actions (`ui_*`, pause, tab bumpers, gear tip / drop, crystal zoom) are **not** on the player rebind page.

Touch overlay MUST hide while any menu is open (`App.ui_open`). Menu navigation on a phone is finger-tap on the control, not virtual A / B. D-pad Down in a menu is only `ui_down`.

