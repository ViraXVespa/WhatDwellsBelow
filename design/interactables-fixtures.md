# Interactables — gates, ghost shop, shrine, campfire

Status: current plan
Read when: microwave housing, pawned goods, blessing buff, campfire sit
Code: `scripts/world/interact/interact_act.gd`, `scripts/world/interact/interact_fx.gd`

## Extraction Gates

- Provide the extraction / mailing interface. There are no in-dungeon clerks.
- Each gate is a mechanical wall fixture (microwave-like housing with a portal viewport) built into a **north wall**, three wall tiles wide. Only that facing ships.
- Count, safe rooms, and separation: dungeon. Mail-legal goods: inventory.meta.
- Dialogue is minimal; the main interaction is a clean, TV-readable list.
- A gate becomes inactive after the extract menu closes **if anything was mailed** that visit. Cancel with nothing sent: the gate stays active.
- Inactive: lamps off, viewport sealed by dungeon wall, banner reads INACTIVE. Active and inactive share the same metal shading so later world lighting can apply to both.

## Ghost Shop

- Appears on approximately one in three floors.
- Always in a safe room.
- Sells a few Artifacts, with a cap on how many the player may buy per visit (tunables-economy).
- Sells snacks at a fixed price (tunables-economy).
- Allows pawning of gear for a very low return.
- Uses a distinct hopeful-but-eerie voice style (implementation may be text + SFX for the demo).
- Distinct ghost / shopkeep sprite required.

## Shrine

- On interaction grants a temporary damage buff (size and duration: tunables-economy).
- Buff MUST appear on the HUD with a visible timer.
- One use per floor.

## Campfire

- One-sit heal.
- Safe interaction.
