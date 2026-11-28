# Menu transitions

Status: current plan
Read when: fade, transitions checkbox  
Code: `scripts/ui/ui_session.gd`, `scripts/ui/menu_fade.gd`  

Playtest (w13): every menu opened as a hard cut, a bright full-screen journal or cream panel in one frame over a dark dungeon ("like a flash bang"). Menus now fade.

## Rules

- Setting: Settings > UI > **Menu transitions**, a checkbox, on by default, saved as `menu_fx` with the other preferences. Off restores the old instant open and close.
- Every menu layer that opens through `UiSession.open` / `close` fades: pause menu, inventory / extract / shop / vendor / anvil / loadout / quest / receptionist / controls / flavor panels, Floor Crystal, recap. The archives browser and the large dungeon map call the same helper. No menu has its own fade code.
- Open: the whole layer, its dim backdrop included, fades in over 0.15 s (ease out). Close: it fades out over 0.12 s (ease in). Opening again mid-fade continues from the current alpha.
- Input never waits for a fade. Focus lands on the first frame and a pad press during the fade-in works. On close the game gets the pad, the unpause and `App.ui_open = false` on the same frame. The fading-out layer is a ghost: drawn, `PROCESS_MODE_DISABLED` (no `_input`, no click, no `ui_accept`), with no focus. A Back chip tap that closed it is released at once.
- The large map fades in and closes at once (its zoom and pan read the layer, so it never ghosts). Confirm slips and the title "What's new" card fade in and close at once.
- Tab changes and page changes inside an open menu stay instant.
- Side panels (the gear re-equip list) do not slide: their placement runs a frame late (`TipPlace.near`), so a slide would fight it. They appear with their menu.
- The dim backdrop already existed (pause journal dim 0.78 under an opaque journal; panels dim the world). The flash was the hard cut, not a missing backdrop. The backdrop now fades in with the menu.

## Code

`scripts/ui/menu_fade.gd`: `fade_in(layer)`, `fade_out(layer, free_after)`, `ghosting(layer)`, `pop_in(control)`, `enabled` (the setting). One `CanvasModulate` named `menu_fade` per layer carries the alpha, so the layer's own child modulates (map opacity, chip tints) stay theirs. A layer that rebuilds by wiping its children must keep that node (`crystal_ui.gd` does). Hooks: `scripts/ui/ui_session.gd` (open / close), `archives_ui.gd`, `confirm_dlg.gd`, `title/news_show.gd`, `world/dungeon/dungeon_boot.gd` (`_set_map_state`). Setting row: `scripts/ui/pause_settings/page_ui.gd`.

A closed menu can be visible for 0.12 s. Code that asks "is this menu up" reads its `open` flag, not `visible`.

## Proof

Flow `camp-menu-fade` (smoke) with `scripts/debug/menu_fade_check.gd`: mid fade-in and at-rest focus, a pad press mid-fade, the ghost (game unpaused, no focus, a forced `ui_accept` does not fire), six rapid toggles settle, setting off is instant, and two planted ghost faults (still processing, keeps focus) are caught. Flow `dungeon-map-fade`: the large map mid-fade, at rest, closed. Phase 6 escape sweep: every hub menu closes on every Back input with nothing held.

## Camp HUD bar under menus

The camp `PlayHud` bar hides while any camp menu is open (`App.ui_open`) and comes back when it closes (`scripts/world/camp/camp_hud.gd` `follow_menus`, re-hooked when the hub moves between viewports, as the shot tool's capture mount does), so no panel top sits under it. Proof: flow `camp-menu-fade` (`scripts/debug/layout_check.gd` `hud_clear`, planted `hud_plant`).
