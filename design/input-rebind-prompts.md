# Rebinding, prompts, aim-line

Status: current plan  
Read when: rebinding, on-screen prompts, or aim-line  


## Rebinding

Pause → Settings → Controls.

- Two pools: Keyboard / mouse and Gamepad. A selector at the top of the page switches the list. Switching rebuilds the rows for that pool.
- The selector wraps both ways (Keyboard ↔ Gamepad). D-pad and arrow keys are discrete. Left-stick X switches once per push past a deadzone and must return to center before another switch. Left-stick Y stays vertical menu navigation.
- First row after the selector is Reset Controls (that pool only). Confirm via `confirm_dlg.gd` before restocking defaults. Cancel / B / Esc backs out and returns focus to Reset.
- **Single home.** `scripts/input/binds/table.gd` lists every action once: id, label, default keys / mouse / pad buttons / axes, and which pools the page may rebind. `defaults.gd` fills the InputMap from it, Reset Controls restocks from it, the page lists from it, saves cover its ids, and `Pad` tracks pad buttons through the InputMap. No other script names a bind; change a default there only. Pad reset restocks left-stick move axes as well as buttons.
- Every player action is rebindable: move (keyboard), attack, special, dash, target lock, interact, map, inventory, potion, food, look mode (pad), pause menu, menu tab left / right, item tip, item drop, crystal map zoom. Esc and Start bind like any other input.
- Two slots per action. A new bind that collides inside the same pool swaps with the other action’s slot; a swap that would leave the other action with no bind in that pool is refused. Both outcomes show a toast ("{input} binding swapped!" or "Can't swap {input}: {action} would be left with no input."), through `App.toast` and also in the Controls footer (the HUD toast sits under the pause menu). Cross-pool events are ignored.
- Capture: choosing a slot shows `...` and the page takes the next key or pad button before any menu handler, so Esc, Start, Space, Backspace, B, `[`, `]`, LB and RB all bind. A key that currently goes Back in menus (`ui_cancel` or `pause`: Esc, Backspace, B, Start by default) asks first: a confirm names the input and the action, Confirm binds it, Cancel (or Back again) keeps the old bind and ends capture. Safety nets so capture never traps: the Back input of the *other* pool (pad B or Start while capturing a key; Esc or Backspace while capturing a pad button) cancels at once, clicking the capturing slot again cancels, and leaving the Controls page ends capture. There is no timeout. Mouse clicks still use normal button handling; a click on empty space binds that mouse button.
- Fixed on purpose, not on the page: gamepad sticks (move and aim stay on the axes) and menu navigation (`ui_*`: Enter / A accept, Esc / Backspace / B back, arrows / WASD / D-pad move). They are the root of interfacing with the game, so no rebinding can lock a player out. Also fixed: Alt+Enter, and on web F1 as an extra pause. Esc stays Back inside menus even when it is rebound for the world.
- First boot and Reset bind keyboard actions to **physical** key positions (`physical_keycode`), so QWERTY W stays the same cap as Dvorak `,`. Glyphs follow the player’s layout.
- Bind name left-aligned. Assigned glyph(s) right-aligned. Empty slot is an em dash. D-pad chips read UP / DOWN / LEFT / RIGHT, not “DPAD UP”.

`binds.gd` is the facade (`collect` / `apply` / `register` / `reset_pool`). Slot math lives in `binds_pool.gd`. The Controls page is `binds_page.gd`. Smoke P7 (`scripts/debug/smoke/smoke_binds.gd`) asserts the table rules, swap / refuse results, the Back-key confirm, the cancel safety nets, toasts, and hint tokens.

## On-screen prompts

Prompts follow **last used** input. One scheme at a time. `Pad.note_event` sets `Pad.mode` from a joy event (pad) or a key / mouse event (kb). `Prompts.scheme()` reads that flag. `App._input` notes every event so GUI-consumed mouse / key traffic still flips the scheme. `Pad` pulses `PromptView` when the scheme changes.

`PromptView.pulse()` redraws every registered glyph host, not only the footer: tab chips, gear stats paging, confirm strips, and `PromptView.footer` bars. Gear paging rows store `page_prev` / `page_next` flags so pulse resolves Q / E on keyboard and LT / RT on pad. LMB / RMB never page the stats card.

While the web touch overlay is active, `Pad.mode` stays pad so world prompts keep pad glyphs. This slice does not add a `touch/` glyph pack.

Do not bake `A`, `B`, `ENTER`, `ESC`, `LMB`, or `RMB` into button captions, hint text, or status lines. Verbs stay on the control; glyphs come from the bind. Text hints write `{action_id}` tokens and pass through `Prompts.fmt`, which swaps in `Prompts.label(action)` (the current scheme’s bind, e.g. Esc, Start, RT). This covers the locale file, camp, splash, fullscreen gate, archive loader, foundation, and debug status lines. The touch overlay draws the pad glyph of each action’s first pad bind.

| Surface | Where the glyph lives |
|---------|------------------------|
| Menus | Footer strip at the bottom-right of the menu panel. Always Select + Back (Recap shows Continue only). Extra actions (drop, tip, zoom) join that strip. |
| Confirm dialog | Own Select + Back strip on the dialog (above the dimmed pause footer). B / Esc / Cancel closes it and restores prior focus. |
| Tab headers | LB / RB (or `[` / `]`) on the left and right of the tab row. The row stretches; it scrolls horizontally when tabs overflow. Glyphs MUST follow the current scheme without waiting for a tab change. |
| Gear stats card | Q / E on keyboard, LT / RT on pad. Not in the footer. Glyphs MUST follow the current scheme without waiting for a focus change. |
| World HUD | `interact` glyph + the verb from `scripts/world/interact.gd`. Locked / spent lines are text only. Look-mode cue under the minimap while look mode or the large map is active. |
| Touch overlay | Pad glyphs on the virtual buttons (`rt`, `lt`, `a`, `b`, `menu`, `view`, `dpad_up`, `dpad_left`). No lock / R3 well. |

Glyph PNGs: `assets/ui/prompts/kb/`, `assets/ui/prompts/pad/`, `assets/ui/prompts/mouse/`. Regenerate with `python3 tools/gen_prompt_glyphs.py`. Keyboard arrows are stemmed arrows on the key cap, not `UP` / `DN` / empty `<` `>` stamps.

Helpers: `Prompts.texture_for(action)`, `Prompts.texture_for_event`, `PromptView.fill`, `PromptView.footer(ui, extra_parts)`, `PromptView.pulse`.

## Aim-line indicator

- Simple opaque visual indicator that extends outward from the player in the direction they are facing/aiming.
- Appearance and length are fully tunable (default style inspired by Heroes of Hammerwatch and similar games; length may optionally scale toward the farthest point the currently equipped weapon can hit).
- Always visible while the player is inside the dungeon; never visible in Placeholdia.
- Always draws the full configured distance (does not respect line-of-sight or stop at walls).
- Toggleable on/off and with an independent opacity slider in Pause → Settings → Graphics.
- On/off state and opacity are persisted with the player profile.
- Fully functional with gamepad, keyboard/mouse, and web-touch aiming (parity required). Touch aim is lock-on while the overlay is active.
