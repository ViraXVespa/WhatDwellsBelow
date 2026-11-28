# UI (door)

Status: current plan  
Read when: pause panels, fullscreen drape, play-menu  
Code: `scripts/ui/` except the gear board and the archives screen, plus `scripts/data/tutorial_pages.gd` (code map row UI; gdhealth group `ui`)

Reach-in rule: screens open the gear board through `gear_board.gd` entry points and give it host methods (`place_gear_tip`, `inv_*` on ProgressUI); nothing below the screens (input, data, world, gameplay) loads UI code. Map pan and the player cell come from `dungeon.gd` methods; touch button words from `touch_pad.gd`.

| Job | Open |
|-----|------|
| color tokens, playable surfaces | `design/ui-theme.md` |
| title poster, loading bar, fs-gate | `design/ui-title-web.md` |
| gauntlet strip, pip cluster | `design/ui-hud.md` |
| inventory tab, skills tab, settings page | `design/ui-pause.md` |
| recap reel, ghost vendor pane, quest pane, banner | `design/ui-run-flow.md` |
| loadout tray, tooltip shell | `design/ui-gear-entry.md` |
| restyle, builders, skin hooks, scrollbar hiding | `design/ui-style.md` |
| fade, transitions checkbox | `design/ui-transitions.md` |
| legend keycaps, bindings legend | `design/ui-unit-controls.md` |
| smithing readout, cost breakdown | `design/ui-unit-anvil.md` |
| enter-dungeon footer, weapon tool choice | `design/ui-unit-loadout.md` |
| send-all banking, banked lines | `design/ui-unit-extract.md` |
| pawn counter, snack prices | `design/ui-unit-ghost-shop.md` |
| tally sequence, finale bars | `design/ui-unit-recap.md` |
| pinned parchment, offer cutouts | `design/ui-unit-quest-board.md` |
| talk cycle, ask topics | `design/ui-unit-receptionist.md` |

Remaining screens are units, worked in her order: `python tools/slice.py start --door ui`, as many as fit one session (`--unit-done` at each Complete). Each unit job prints its own flow, docs and files.

Gear board layout / anvil tabs / slot plates live in gear_ui. ui.gear_entry only keeps the short UI entry sections.
