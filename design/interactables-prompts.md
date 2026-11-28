# Interactables — stairs, crystals, prompts

Status: current plan
Read when: descend glyph, waypoint beacons, clear-area text, readable labels
Code: `scripts/world/interact/interact_prompt.gd`, `scripts/world/floor_crystal.gd`, `scripts/ui/hud.gd`, `scripts/input/prompts.gd`

## Stairs

Lock and “deeper only”: dungeon.

- Interaction prompt is a last-used `interact` glyph plus the verb “Descend”. First use arms confirm; second use descends. Locked copy is text only (“Locked. Defeat the guardian.”).

## Floor crystals

- Placeholdia’s loadout crystal is unchanged: it opens loadout / enter dungeon.
- In-dungeon crystals are waypoints, not descend points.
- Placement, bind, and network unlocks: dungeon.
- Other crystals show “Clear the area to activate.” until nearby enemies and pending spawn jobs are gone, then the verb “Activate crystal” with the `interact` glyph.
- A bound crystal opens the transport menu: Local Transport Network, Floor Transport Network, Back.
- Crystal map zoom is `crystal_zoom` (Tab / Y). That bind appears in the menu footer, not in the zoom status line.
- Interaction prompts MUST stay TV-readable and gamepad-first. Do not prefix world verbs with `A:`.

## Interact prompt strings

World `prompt` strings are verbs only (`Descend`, `Gather`, `Activate crystal`, `Open guardian`, `Step the plate`, `Pull lever`, `Open chest`). `hud.gd` attaches the current-scheme `interact` glyph. Hostile crystals use text-only “Clear the area to activate.” Used chests use text-only “Empty.” Stairs confirm is a second press; crystals never call `next_floor`.

## HUD prompt

`App.interact_prompt` is the verb only. `hud.gd` attaches the current-scheme `interact` glyph. Scheme flips with last-used input (input).
