# Input

Status: binding design + live snapshot
Read when: changing controls, menus, web export, or aim
Code: `scripts/input/binds.gd`, `scripts/input/binds_pool.gd`, `scripts/ui/binds_page.gd`, `scripts/input/pad.gd`, `scripts/input/touch_pad.gd`, `scripts/input/look_ctrl.gd`, `scripts/input/prompts.gd`, `scripts/web_pad.gd`, `scripts/ui/touch_hud.gd`, `scripts/ui/menu_pad.gd`, `scripts/ui/prompt_view.gd`, `scripts/ui/confirm_dlg.gd`, `scripts/ui/fs_gate.gd`, `scripts/world/player_lock.gd`, `scripts/world/dungeon_map_act.gd`, `scripts/display_mode.gd`
See also: `design/camera.md`, `design/ui.md`, `design/debug.md`, `design/gear-ui.md`, `design/save-tech.md`

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

## Rebinding

Pause → Settings → Controls.

- Two pools: Keyboard / mouse and Gamepad. A selector at the top of the page switches the list. Switching rebuilds the rows for that pool.
- The selector wraps both ways (Keyboard ↔ Gamepad). D-pad and arrow keys are discrete. Left-stick X switches once per push past a deadzone and must return to center before another switch. Left-stick Y stays vertical menu navigation.
- First row after the selector is Reset Controls (that pool only). Confirm via `confirm_dlg.gd` before restocking defaults. Cancel / B / Esc backs out and returns focus to Reset.
- `binds.gd` facades `ensure_mouse` and `ensure_axis` into `binds_defaults.gd`. Pad reset MUST restock left-stick move axes as well as buttons.
- Exposed actions are gameplay only: move (keyboard), attack, special, dash, target lock, interact, map, inventory, potion, food, look mode (pad). Item tip and drop are not listed.
- Two slots per action. A new bind that collides inside the same pool swaps with the other action’s slot. Cross-pool events are ignored.
- Gamepad left / right sticks cannot be rebound. Move and aim stay on those axes.
- First boot and Reset bind keyboard actions to **physical** key positions (`physical_keycode`), so QWERTY W stays the same cap as Dvorak `,`. Glyphs follow the player’s layout.
- Bind name left-aligned. Assigned glyph(s) right-aligned. Empty slot is an em dash. D-pad chips read UP / DOWN / LEFT / RIGHT, not “DPAD UP”.

`binds.gd` is the facade (`collect` / `apply` / `register` / `ensure_mouse` / `ensure_axis`). Slot math lives in `binds_pool.gd`. The Controls page is `binds_page.gd`.

## On-screen prompts

Prompts follow **last used** input. One scheme at a time. `Pad.note_event` sets `Pad.mode` from a joy event (pad) or a key / mouse event (kb). `Prompts.scheme()` reads that flag. `App._input` notes every event so GUI-consumed mouse / key traffic still flips the scheme. `Pad` pulses `PromptView` when the scheme changes.

`PromptView.pulse()` redraws every registered glyph host, not only the footer: tab chips, gear stats paging, confirm strips, and `PromptView.footer` bars. Gear paging rows store `page_prev` / `page_next` flags so pulse resolves Q / E on keyboard and LT / RT on pad. LMB / RMB never page the stats card.

While the web touch overlay is active, `Pad.mode` stays pad so world prompts keep pad glyphs. This slice does not add a `touch/` glyph pack.

Do not bake `A`, `B`, `ENTER`, `ESC`, `LMB`, or `RMB` into button captions or status lines. Verbs stay on the control; glyphs come from the bind.

| Surface | Where the glyph lives |
|---------|------------------------|
| Menus | Footer strip at the bottom-right of the menu panel. Always Select + Back. Extra actions (drop, tip, zoom) join that strip. |
| Confirm dialog | Own Select + Back strip on the dialog (above the dimmed pause footer). B / Esc / Cancel closes it and restores prior focus. |
| Tab headers | LB / RB (or `[` / `]`) on the left and right of the tab row. The row stretches; it scrolls horizontally when tabs overflow. Glyphs MUST follow the current scheme without waiting for a tab change. |
| Gear stats card | Q / E on keyboard, LT / RT on pad. Not in the footer. Glyphs MUST follow the current scheme without waiting for a focus change. |
| World HUD | `interact` glyph + the verb from `scripts/world/interact.gd`. Locked / spent lines are text only. Look-mode cue under the minimap while look mode or the large map is active. |
| Touch overlay | Pad glyphs on the virtual buttons (`rt`, `lt`, `a`, `b`, `menu`, `view`, `dpad_up`, `dpad_left`). No lock / R3 well. |

Glyph PNGs: `assets/ui/prompts/kb/`, `assets/ui/prompts/pad/`, `assets/ui/prompts/mouse/`. Regenerate with `python tools/gen_prompt_glyphs.py`. Keyboard arrows are stemmed arrows on the key cap, not `UP` / `DN` / empty `<` `>` stamps.

Helpers: `Prompts.texture_for(action)`, `Prompts.texture_for_event`, `PromptView.fill`, `PromptView.footer(ui, extra_parts)`, `PromptView.pulse`.

## Aim-line indicator

- Simple opaque visual indicator that extends outward from the player in the direction they are facing/aiming.
- Appearance and length are fully tunable (default style inspired by Heroes of Hammerwatch and similar games; length may optionally scale toward the farthest point the currently equipped weapon can hit).
- Always visible while the player is inside the dungeon; never visible in Placeholdia.
- Always draws the full configured distance (does not respect line-of-sight or stop at walls).
- Toggleable on/off and with an independent opacity slider in Pause → Settings → Graphics.
- On/off state and opacity are persisted with the player profile.
- Fully functional with gamepad, keyboard/mouse, and web-touch aiming (parity required). Touch aim is lock-on while the overlay is active.

## Input – Keyboard / mouse (fully featured fallback)

All gamepad actions MUST have keyboard/mouse equivalents. Mouse aim + hold-LMB for attack is the default mouse scheme. Player rebinding covers gameplay actions only (see Rebinding).

Mouse wheel zooms world camera or the large map as described under Look mode. It is not a rebindable InputMap combat action.

**Alt+Enter** is a fixed display toggle. It is not an InputMap action and MUST NOT appear on the rebind page. Enter alone stays Interact / confirm. Handled in `App._input` → `DisplayMode.handle_input` so it works while a menu is open.

- Desktop (`DisplayMode.uses_desktop_modes()`): if the window is windowed, apply the last saved fullscreen kind (`display_fs_kind`: borderless or true fullscreen; fresh default is borderless). If the window is already borderless or true fullscreen, return to windowed and leave `display_fs_kind` alone.
- Web / native Android / iOS (`DisplayMode.uses_web_fs_toggle()`): toggle the current fullscreen state through the same path as Pause → Settings → Graphics (`DisplayMode.set_web_fullscreen`). A keydown is a valid gesture for `requestFullscreen`.
- No-op on `xbox`.

**Esc** opens pause (and backs out of menus). On web it MUST NOT exit browser fullscreen. Only Pause → Settings → Graphics and Alt+Enter leave web fullscreen. `DisplayMode.ensure_web_hooks()` installs a capturing `keydown` listener that `preventDefault`s Escape while `document.fullscreenElement` is set and stashes `window.__wdbEsc`. `DisplayMode.consume_web_esc()` / `Pad.pause_just()` turn that flag into pause so camp and dungeon still call `App.pause_menu.toggle()`.

**I** opens pause on Inventory from gameplay only. Same action as D-pad Right. MUST NOT jump tabs while pause or any other `App.ui_open` menu is already up.

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
