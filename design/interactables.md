# Interactables and world objects

Status: binding design
Read when: changing gathering, Extraction Gates, shops, shrines, puzzles, or crystals
Code: `scripts/world/gather_node.gd`, `breakable.gd`, `interact.gd`, `floor_crystal.gd`, `crystal_net.gd`, `pickup.gd`, `dungeon_props.gd`, `scripts/ui/hud.gd`, `scripts/input/prompts.gd`
See also: `design/inventory.md`, `design/dungeon.md`, `design/ui.md`, `design/input.md`

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

## Extraction Gates

- Provide the extraction / mailing interface. There are no in-dungeon clerks.
- Each gate is a mechanical wall fixture (microwave-like housing with a portal viewport) built into a **north wall**, three wall tiles wide. Only that facing ships.
- Three gates per floor. Each sits in its own enemy-free safe room. Rooms spawn in different areas of the floor and MUST NOT be near one another.
- The player may extract any mail-legal goods at any gate (ore, wood, root, gold, and bag items). Artifacts and forged holds still cannot be mailed.
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
- Cracked walls have higher HP than normal breakables (suggested start: 8).
- Dead-end chests and trap-room chests may optionally contain Artifacts in addition to normal loot.

## Stairs

- Stairs only allow travel deeper.
- Stairs remain locked behind the boss door until the Floor Guardian or Gate Master is defeated.
- Interaction prompt is a last-used `interact` glyph plus the verb “Descend”. First use arms confirm; second use descends. Locked copy is text only (“Locked. Defeat the guardian.”).

## Floor crystals

- Placeholdia’s loadout crystal is unchanged: it opens loadout / enter dungeon.
- In-dungeon crystals are waypoints, not descend points.
- The entrance crystal is already bound. Other crystals show “Clear the area to activate.” until nearby enemies and pending spawn jobs are gone, then the verb “Activate crystal” with the `interact` glyph.
- A bound crystal opens the transport menu: Local Transport Network, Floor Transport Network, Back.
- Local Transport Network is locked until a second crystal on this floor is bound.
- Floor Transport Network is locked until the player has reached a floor deeper than the current one.
- Crystal map zoom is `crystal_zoom` (Tab / Y). That bind appears in the menu footer, not in the zoom status line.
- Interaction prompts MUST stay TV-readable and gamepad-first. Do not prefix world verbs with `A:`.

## HUD prompt

`App.interact_prompt` is the verb only. `hud.gd` attaches the current-scheme `interact` glyph. Scheme flips with last-used input (`design/input.md`).