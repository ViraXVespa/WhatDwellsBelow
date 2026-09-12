# Rebinding, prompts, aim-line

Status: binding design
Read when: rebinding, on-screen prompts, or aim-line
See also: `design/input.md`, `design/input-gamepad.md`, `design/input-kb-mouse.md`, `design/input-web-touch.md`, `design/input-live.md`, `design/ui.md`, `design/ui-hud.md`, `design/doc-refactor.md`, `design/README.md`

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

