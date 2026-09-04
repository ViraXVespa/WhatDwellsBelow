# Input

Status: binding design + live snapshot
Read when: changing controls, menus, web export, or aim
Code: `scripts/input/binds.gd`, `scripts/input/pad.gd`, `scripts/input/prompts.gd`, `scripts/web_pad.gd`, `scripts/ui/menu_pad.gd`, `scripts/ui/prompt_view.gd`
See also: `design/camera.md`, `design/ui.md`, `design/debug.md`, `design/gear-ui.md`

## Target platforms

- PC (primary)
- Web export that runs in modern browsers without requiring special COOP/COEP headers
- Design MUST remain fully readable and playable from couch distance on a television (future Xbox / console consideration)

## Input – Gamepad (primary, Xbox layout)

- Left Stick: Movement
- Right Stick: Aim
- R3: Toggle target-lock (default off). On activation or when current target dies, lock nearest valid enemy in LOS and on-screen. Right-stick deflection cycles to the nearest enemy in that direction after a short delay. Lock breaks when no valid targets remain but stays armed for auto-reacquisition. Second R3 press disengages.
- RT: Hold-to-attack (basic attack of the currently equipped weapon). While a gear board is open, RT pages the stats card forward.
- LT: Special attack of the currently equipped weapon. While a gear board is open, LT pages the stats card back.
- A: Interact. In menus, confirm the focused control or a pending prompt.
- B: Dash. In menus, back one layer, or close the menu at root.
- D-pad Up: Use equipped potion
- D-pad Left: Use equipped food
- Menu / Start: Pause. In an open menu, also acts as back / close.
- View / Back: Toggle large map overlay (game continues running underneath)
- LB / RB: Cycle tabs inside any menu that has tabs. Do nothing in menus that have no tabs.

All controls, gameplay, and interfaces MUST be designed with a gamepad-first intent. Every menu MUST open with a valid initial focus already set so the player can immediately navigate and select using only the gamepad (no requirement to first highlight an element with the mouse).

## Menus (universal)

Shared classifiers live in `scripts/ui/menu_pad.gd`. Any menu with tabs MUST call `Pad.tab_delta(event)` and apply that delta to its tab index. Do not invent a second bumper path.

| Input | Menu effect |
|-------|-------------|
| A / Enter / `ui_accept` | Confirm focused control. Second A confirms a pending prompt. |
| B / Esc / `ui_cancel` | Close a nested layer (re-equip list, rebind page, pending prompt). At root, close the menu. |
| LB / RB / `[` / `]` | Cycle tabs when the open menu has a tab strip. |
| Q / LT | Previous gear-board stats page |
| E / RT | Next gear-board stats page |

Exception: the secret Animation Browser keeps LB / RB = previous / next model and LT / RT = animation list, per `design/debug.md`.

## On-screen prompts

Prompts follow **last used** input. One scheme at a time. `Pad.note_event` sets `Pad.mode` from a joy event (pad) or a key / mouse event (kb). `Prompts.scheme()` reads that flag. `menu_pad.gd` notes the event on menu traffic and calls `PromptView.pulse()` so open footers redraw.

Do not bake `A`, `B`, `ENTER`, `ESC`, `LMB`, or `RMB` into button captions or status lines. Verbs stay on the control; glyphs come from the bind.

| Surface | Where the glyph lives |
|---------|------------------------|
| Menus | Footer strip at the bottom-right of the menu panel. Always Select + Back. Extra actions (drop, tip, zoom) join that strip. |
| Tab headers | LB / RB (or `[` / `]`) on the left and right of the tab row. The row stretches; it scrolls horizontally when tabs overflow. |
| Gear stats card | Q / E on keyboard, LT / RT on pad. Not in the footer. |
| World HUD | `interact` glyph + the verb from `scripts/world/interact.gd`. Locked / spent lines are text only. |

Glyph PNGs: `assets/ui/prompts/kb/`, `assets/ui/prompts/pad/`, `assets/ui/prompts/mouse/`. Regenerate with `python tools/gen_prompt_glyphs.py`.

Helpers: `Prompts.texture_for(action)`, `PromptView.fill`, `PromptView.footer(ui, extra_parts)`.

Extra bindable actions used by prompts: `tab_left`, `tab_right`, `gear_tip`, `gear_drop`, `crystal_zoom`.

## Aim-line indicator

- Simple opaque visual indicator that extends outward from the player in the direction they are facing/aiming.
- Appearance and length are fully tunable (default style inspired by Heroes of Hammerwatch and similar games; length may optionally scale toward the farthest point the currently equipped weapon can hit).
- Always visible while the player is inside the dungeon; never visible in Placeholdia.
- Always draws the full configured distance (does not respect line-of-sight or stop at walls).
- Toggleable on/off and with an independent opacity slider in the System tab of the pause menu.
- On/off state and opacity are persisted with the player profile.
- Fully functional with both gamepad and keyboard/mouse aiming (parity required).

## Input – Keyboard / mouse (fully featured fallback)

All gamepad actions MUST have keyboard/mouse equivalents. Mouse aim + hold-LMB for attack is the default mouse scheme. Rebinding of all actions is required.

## Live snapshot — PC defaults (`binds.gd`)

These are implementation defaults, not a replacement for rebinding.

| Action | Keys |
|--------|------|
| Move | WASD / arrows |
| Aim | Mouse |
| Attack | LMB hold |
| Special | RMB |
| Dash | Space |
| Target-lock | Q |
| Interact | E / Enter |
| Pause | Esc |
| Map | M |
| Potion | F |
| Food | C |
| Menu tabs | `[` / `]` |
| Gear tip | Y |
| Gear drop | X |
| Crystal zoom | Tab |

`binds.apply_pc_defaults()` strips `KEY_R` from special. README text that still says “R special” is stale relative to live binds.

Q pages stats only while a gear board is open; during gameplay it remains target-lock. E pages stats only while a gear board is open; during gameplay it remains interact. LMB / RMB never page the stats card.

## Live snapshot — web gamepad (`web_pad.gd`)

Web builds on GitHub Pages do not get a reliable Godot joypad. When `OS.has_feature("web")`, `scripts/web_pad.gd` reads `navigator.getGamepads()` through `JavaScriptBridge`.

- Polls the first connected pad each frame.
- Standard mapping: axes 0–1 move, 2–3 aim; button 0 A, 1 B; RT/LT attack/special; Start/Back; stick clicks.
- Stick deadzone ≈ 0.24. Button threshold ≈ 0.45.
- Player must click the canvas once so the page can receive keyboard / gamepad input.
- Xbox pads work in Chromium-based browsers.
- After scene changes, `App.wake_web_pad()` refreshes the bridge.