# Edge cases and failure modes

Status: binding design
Read when: changing death, bag, save, Extraction Gates, tools, artifacts, or confirmations
See also: `design/ui.md`, `design/inventory.md`, `design/save-tech.md`, `design/debug.md`

## “Dispel” or death on floor 1 with empty bag

- Full recap screen is still shown.
- The exact flavor line “They lived just to die. What a waste.” MUST appear.
- All normal XP-drain and permanent-fragment logic still executes (even if values are zero).

## Bag full

- When the player walks over any loot while the bag is at capacity, the item is not picked up.
- A clear toast is displayed.
- The item remains on the ground and can be picked up later if space is made.

## Death or “Dispel” during gathering / dash / special

- All actions are immediately interrupted.
- The appropriate death or “Dispel” animation sequence begins with no residual movement, gathering hits, or i-frames carrying over.

## Multiple Extraction Gates / shops

- Hard limit: maximum one Ghost Shop per floor.
- Hard limit: three Extraction Gates per floor, each in its own safe room, not near one another.
- Generation MUST respect these caps.

## Save corruption or missing save

- Primary save is attempted first.
- On any failure to load or parse, the game silently falls back to the backup of the last successfully loaded save.
- If the backup also fails, a completely fresh dungeon delver is created.
- No partial or corrupted data is ever presented to the player.
- The same primary + backup rules apply independently to the two Automated Playtest save files.

## Locked stairs / boss door

- Stairs are inaccessible while the Floor Guardian or Gate Master is alive.
- They remain behind the visible boss door.
- Once the boss is defeated the door opens and the stairs become usable.
- No additional toast is required beyond the door state itself; the visual lock is sufficient.

## Tool type lock

- Once a tool type (pickaxe or hatchet) is selected at loadout, the player cannot equip the other type during that run even if one is found.

## Artifact sets

- Set bonuses only count artifacts currently carried or equipped in the active run.
- Artifacts are never extractable and are lost on death or “Dispel”.

## Secret debug sequence

- The shoulder-button sequence MUST be performed exactly as specified.
- No feedback is given on partial or failed attempts so that regular players remain unaware of the menu’s existence.
- Opening the menu is the only confirmation of success.

## Automated Playtest interruption

- Any running or queued automated playthrough can be interrupted at any time.
- All telemetry and run data collected up to the interruption point are preserved.

## Other failure modes

- Attempting to use a potion or food when none is equipped/available produces a clear toast and no effect.
- Attempting to use food of the same type while its heal-over-time is still running does not consume another item.
- Attempting to forge without sufficient resources produces a clear failure message and no consumption of partial materials.
- All confirmation prompts (“Dispel”, Delete Save, major extractions, character switch, etc.) MUST be cancellable and MUST NOT be triggerable by accident with a single button press.