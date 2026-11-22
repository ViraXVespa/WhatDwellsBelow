# Gamepad and shared menu input

Status: current plan  
Read when: gamepad layout, look mode, or universal menus  

## Target platforms

- PC (primary)
- Web export that runs in modern browsers without requiring special COOP/COEP headers
- Web touch on a mobile user-agent when no physical keyboard or gamepad is present (virtual move stick + right-hand button cluster)
- Design MUST remain fully readable and playable from couch distance on a television (future Xbox / console consideration)

## Input – Gamepad (primary, Xbox layout)

Default layout (week 13 playtest, `table.gd` LAYOUT 2; saves on older defaults migrate, see Rebinding):

- Left Stick: Movement
- Right Stick: Aim, except while look-mode is on or the large map is open (see Look mode)
- X: Hold-to-attack (basic attack of the equipped weapon). On a gear board, X is gear drop.
- A: Special attack of the equipped weapon ("hard attack"). In menus, confirm the focused control or a pending prompt.
- Y: Interact. On a gear board, gear tip. In the secret Animation Browser, Y cycles the current clip's review state (Good / Repack / Regenerate).
- B: Back only. In menus, back one layer, or close the menu at root. World play does not consume B.
- RB: Dash. In menus RB is the next tab (`tab_right`); a menu-closing press never bleeds into a dash.
- LT / RT: Bow aim / Bow fire, live only with Bow mode on and the longbow equipped (`design/player.md` Bow mode). Off, the triggers do nothing in the world. On a gear board, LT / RT page the stats card (`page_prev` / `page_next`).
- D-pad Down: Toggle target-lock (default off). On activation or when current target dies, lock nearest valid enemy in LOS and on-screen. Right-stick deflection cycles to the nearest enemy in that direction after a short delay. Lock breaks when no valid targets remain but stays armed for auto-reacquisition. Second press disengages.
- D-pad Right: Use equipped potion
- D-pad Left: Use equipped food
- D-pad Up: Map (`map_view`, keyboard M). Adaptive (default) swaps the full map with mini, or with hidden after a second press within 200ms of closing the full map. Cycle, on Settings → UI, steps mini, full, hidden. The game keeps running underneath.
- R3: Toggle look mode (`look_mode`). World-only and large-map-only. MUST NOT fire as look-mode while pause, debug, recap, title, or any `App.ui_open` menu is up. Opening those menus clears look mode.
- View / Back: Character menu: from gameplay only, open pause on the Inventory tab (`inventory`, keyboard I). MUST NOT jump tabs or fire while any menu is already open (`App.ui_open`).
- Menu / Start: Pause (the `pause` bind). In an open menu, also acts as back / close.
- World D-pad presses never fire while a menu is open; in menus the D-pad stays `ui_*` navigation.
- LB / RB: Cycle tabs inside any menu that has tabs. Do not invent a second bumper path.

All controls, gameplay, and interfaces MUST be designed with a gamepad-first intent. Every menu MUST open with a valid initial focus already set so the player can immediately navigate and select using only the gamepad (no requirement to first highlight an element with the mouse).

There is no gamepad chord for display mode. Couch players change it on Pause → Settings → Graphics (ui). Keyboard / mouse uses Alt+Enter (below).

## Look mode

Action `look_mode` (default: R3). Session flag only; not saved. Pad-only in the rebind list.

World, map closed:

- Off: right stick aims
- On: right stick X = HUD scale, Y = world camera zoom (`App.set_hud_scale` / `App.set_zoom`)

Large map open:

- Opens fitted to the revealed area. Zoom back to 1× shows the whole floor, recenters, and disables pan.
- Off: right stick pans the map when zoom is above 1×
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
| B / Esc / Backspace / `ui_cancel` | Close a nested layer (re-equip list, Settings detail column, pending prompt). At root, close the menu. Space and RB (dash) do not dash in menus. |
| LB / RB / `[` / `]` | Cycle tabs when the open menu has a tab strip. Follows the `tab_left` / `tab_right` actions, not fixed keys. |
| Q / LT (`page_prev`) | Previous gear-board stats page. Fixed menu action (`table.gd` MENU). |
| E / RT (`page_next`) | Next gear-board stats page. Fixed menu action (Enter stays confirm). |
| I / View | Gameplay only: open pause on Inventory. MUST NOT change tabs while a menu is already open. |

Exception: the secret Animation Browser keeps LB / RB = previous / next model, LT / RT = animation list, Y / `gear_tip` = review-state cycle, X / `gear_drop` = play/pause, D-pad = Facing/Animation columns, left stick = speed or frame step, and right stick = facing, per debug. While that viewer is open those chords MUST NOT fire world or gear-board actions (X must not drop gear). Keyboard Y types into the notes field when that field has focus; gamepad Y still cycles.

Menu navigation (`ui_*`) is fixed. Pause, tab bumpers, gear tip / drop, and crystal zoom are on the rebind page like every other action; defaults live in `scripts/input/binds/table.gd`.

Touch overlay MUST hide while any menu is open (`App.ui_open`). Menu navigation on a phone is finger-tap on the control, not virtual A / B. D-pad Down in a menu is only `ui_down`.
