# UI (door)

Status: current plan  
Read when: pause panels, fullscreen drape, play-menu

| Job | Open |
|-----|------|
| color tokens, playable surfaces | `design/ui-theme.md` |
| title poster, loading bar, fs-gate | `design/ui-title-web.md` |
| gauntlet strip, pip cluster | `design/ui-hud.md` |
| inventory tab, skills tab, system page | `design/ui-pause.md` |
| recap reel, ghost vendor pane, quest pane, banner | `design/ui-run-flow.md` |
| loadout tray, tooltip shell | `design/ui-gear-entry.md` |
| restyle, builders, skin hooks, scrollbar hiding | `design/ui-style.md` |
| legend keycaps, bindings legend | `design/ui-unit-controls.md` |
| smithing readout, cost breakdown | `design/ui-unit-anvil.md` |
| enter-dungeon footer, weapon tool choice | `design/ui-unit-loadout.md` |
| send-all banking, banked lines | `design/ui-unit-extract.md` |
| pawn counter, snack prices | `design/ui-unit-ghost-shop.md` |
| tally sequence, finale bars | `design/ui-unit-recap.md` |
| pinned parchment, offer cutouts | `design/ui-unit-quest-board.md` |
| greeting line, hello bubble | `design/ui-unit-receptionist.md` |

Remaining screens are units, worked in her order: `python tools/start_build_slice.py --door ui`, then `--next` after each is committed. Each unit job prints its own flow, docs and files.

Gear board layout / anvil tabs / slot plates live in gear_ui. ui.gear_entry only keeps the short UI entry sections.
