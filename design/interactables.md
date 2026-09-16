# Interactables and world objects

Status: binding design  
Read when: changing gathering, Extraction Gates, shops, shrines, or puzzles  
Code: `scripts/world/gather_node.gd`, `breakable.gd`, `interact.gd`, `interact_act.gd`, `interact_prompt.gd`, `interact_chest.gd`, `interact_fx.gd`, `dungeon_props.gd`, `dungeon_props_place.gd`, `floor_crystal.gd`, `crystal_net.gd`, `pickup.gd`, `scripts/ui/hud.gd`, `scripts/input/prompts.gd`  


## Mining nodes

- Nodes have a small number of hits (baseline 3–5).
- Player approaches and interacts; gathering animation plays while stationary.
- Every 2.4 seconds the node takes one hit and a reward is rolled immediately.
- Reward chance and quality are influenced by Mining level, pickaxe quality, and node type.
- No progress bar is shown.
- Node is destroyed after its hit count is exhausted.

## Wood nodes

- Nodes have a higher number of hits (baseline 6–10).
- Player approaches and interacts; gathering animation plays while stationary.
- Every 1.2 seconds the node takes one hit and a reward is rolled immediately.
- Successful gather rate is approximately 50 % lower than mining nodes.
- Reward chance and quality are influenced by Woodcutting level, hatchet quality, and node type.
- No progress bar is shown.
- Node is destroyed after its hit count is exhausted.

## Breakables (pots / barrels)

- Destroyed on a single player hit.
- Chance to drop gold and/or an HP orb (walk-over pickup).
- Clear smash VFX and SFX required.

## Live snapshot — HP orbs

Walk-over HP orbs (`pickup.gd`) apply `orb_heal`. If the player is already at full HP, the orb stays on the ground and retries after a short wait.

## Extraction Gates

- Provide the extraction / mailing interface. There are no in-dungeon clerks.
- Each gate is a mechanical wall fixture (microwave-like housing with a portal viewport) built into a **north wall**, three wall tiles wide. Only that facing ships.
- Count, safe rooms, and separation: the dungeon door. Mail-legal goods: the inventory / meta job.
- Dialogue is minimal; the main interaction is a clean, TV-readable list.
- A gate becomes inactive after the extract menu closes **if anything was mailed** that visit. Cancel with nothing sent: the gate stays active.
- Inactive: lamps off, viewport sealed by dungeon wall, banner reads INACTIVE. Active and inactive share the same metal shading so later world lighting can apply to both.

## Ghost Shop

- Appears on approximately one in three floors.
- Always in a safe room.
- Sells 2–4 Artifacts (player may buy a maximum of two per visit).
- Sells snacks at a fixed price (baseline 25 g).
- Allows pawning of gear for a very low return.
- Uses a distinct hopeful-but-eerie voice style (implementation may be text + SFX for the demo).
- Distinct ghost / shopkeep sprite required.

## Shrine

- On interaction grants a temporary damage buff (+20 % baseline, 45 s duration).
- Buff MUST appear on the HUD with a visible timer.
- One use per floor.

## Campfire

- One-sit heal.
- Safe interaction.

## Artifact chests, pressure plates, levers, gates, cracked walls

- Puzzle elements are never required for progression and never appear on the critical path to stairs.
- Puzzle rooms are safe rooms. Every piece MUST sit on a free floor cell inside that room. Do not use fixed offsets from room center.
- If the room cannot hold the full kit, shrink it. Order: paired gate, then plate **or** lever (never both), then a visible chest, then a hidden chest plus an adjacent cracked wall. Skip a later piece rather than placing outside the room.
- A room gets one activator: a pressure plate **or** a lever, chosen at spawn. Both toggle the paired gate on a rising edge and latch it. Stepping off a plate does not close the gate. Stepping on again toggles it closed.
- Plate prompt verb is “Step the plate”. Lever prompt verb is “Pull lever”.
- Cracked walls have higher HP than normal breakables (suggested start: 8). Breaking one reveals its linked hidden chest.
- Dead-end chests and puzzle chests may optionally contain Artifacts in addition to normal loot.
- There is no open-chest sprite yet. A used chest (`chest`, `base_chest`, `puzzle_chest`) fades and tints in place and keeps the “Empty.” prompt for the rest of the floor.

## Live snapshot — puzzle rooms

`dungeon_props_place.spawn_puzzle` walks clear cells inside the room rectangle and takes what fits. `interact_act.plate_held` stores `pressed` on the plate and only calls `toggle_gates` when the player first enters the 0.7 radius. `interact_fx.paint_used_chest` sets sprite modulate to a faded brown after open.

## Stairs

Lock and “deeper only”: the dungeon door.

- Interaction prompt is a last-used `interact` glyph plus the verb “Descend”. First use arms confirm; second use descends. Locked copy is text only (“Locked. Defeat the guardian.”).

## Floor crystals

- Placeholdia’s loadout crystal is unchanged: it opens loadout / enter dungeon.
- In-dungeon crystals are waypoints, not descend points.
- Placement, bind, and network unlocks: the dungeon door.
- Other crystals show “Clear the area to activate.” until nearby enemies and pending spawn jobs are gone, then the verb “Activate crystal” with the `interact` glyph.
- A bound crystal opens the transport menu: Local Transport Network, Floor Transport Network, Back.
- Crystal map zoom is `crystal_zoom` (Tab / Y). That bind appears in the menu footer, not in the zoom status line.
- Interaction prompts MUST stay TV-readable and gamepad-first. Do not prefix world verbs with `A:`.

## Live snapshot — interact prompts

World `prompt` strings are verbs only (`Descend`, `Gather`, `Activate crystal`, `Open the guardian door`, `Step the plate`, `Pull lever`, `Open chest`). `hud.gd` attaches the current-scheme `interact` glyph. Hostile crystals use text-only “Clear the area to activate.” Used chests use text-only “Empty.” Stairs confirm is a second press; crystals never call `next_floor`.

## HUD prompt

`App.interact_prompt` is the verb only. `hud.gd` attaches the current-scheme `interact` glyph. Scheme flips with last-used input (the input door).
