# Player avatar, movement, and facing

Status: current plan  
Read when: movement, collision, character select, eight-dir body
Code: `scripts/world/player.gd`, `player_anim.gd`, `anim_load.gd`, `anim_loco.gd`, `facing.gd`, `player/bow_mode.gd`  

## Character selection

- On first load the player chooses a male or female character.
- The character type may be switched later from the pause menu.
- 8 directions, male/female animation parity, and the shipped paper-doll overlays: art_pipeline. New frames come from that pipeline. Do not start a Bible or an I2V unit.
- Male and female characters each require a complete, dedicated voice-over set of equal scope. Neither set is optional or derivative of the other.

## Movement

- Dash i-frames and trail VFX: combat.
- Movement MUST feel responsive and weighty on both gamepad and keyboard.

## Bow mode

Settings > Gameplay **Bow mode** (saved as `bow_mode`, off by default; `world/player/bow_mode.gd`).

- Off: the longbow fires on Attack (X / LMB / touch Attack) toward the facing or lock target, like every weapon. Aim (LT / Shift) and Fire (RT) do nothing in the world.
- On, with the longbow equipped: hold Aim (LT, Shift, or the touch bow stick) to aim. The right stick, mouse or bow stick steers; the walk slows to the attack pace and does not turn the aim; a manual aim outranks target lock; the aim line shows even when it is off in Settings. Fire (RT, or the bow stick while held) shoots; Attack still shoots too.
- Other weapons ignore Bow mode. Check: `dungeon-bow-mode` flow (`debug/bow_mode_check.gd`).

## Collision and body

- Prefer collision that matches the actual art silhouette / paper-doll bounds rather than a simple cylinder.
- The player SHOULD depth-sort against walls, props, enemies, and other world objects using implied real-world positions. Popping MUST be avoided wherever possible; it is not explicitly forbidden.

## Facing and animation system

- 8-directional facing derived from aim direction using smooth radial detection (not movement direction). Direction names match the Character Bible: Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right.
- New character art is art_pipeline. Do not start an I2V unit or a pack job.
- In-game idle is the directional key still for the facing the player is aiming. It is not an I2V breath loop.
- Required player **body** states at minimum: `idle` (key still), `idle_to_walk`, `walk`, `walk_to_idle`, `attack_great_axe` / `attack_staff` / `attack_longbow`, `special_great_axe` / `special_staff` / `special_longbow`, `gather_pickaxe` / `gather_hatchet`, death, “Dispel”.
- `idle_to_walk` and `walk_to_idle` MUST exist for every facing. Playback MUST play the start transition when leaving idle into walk and a stop transition when coming to rest, rather than popping between the key still and a mid-stride walk frame.
- Start and stop are a few frames each, not a third of the clip. Walk is one looping stride cycle (both lead feet).
- The engine tracks which foot is leading in the walk loop. Stopping on the same lead foot that started the step plays `idle_to_walk` reversed; stopping on the opposite lead foot plays `walk_to_idle`.
- Those start / cycle / stop clips are the shipped walk per facing. A replacement clip waits on art_pipeline.
- Attack, special, and gather body clips are unarmed. The live weapon overlay sits on that clip. New art does not add a paper-doll pass.
- “Dispel” is ritual seppuku: the avatar draws a small knife, kneels, makes one abdominal cut, and collapses. That knife belongs to this clip. It is not an equipped overlay.
- Death is a hit collapse to a downed hold. Death and “Dispel” both end on a downed body. Neither I2V paints blood.

## Body, clips and loading

Body and move numbers: tunables. Character is male or female.

- Locomotion: unarmed idle stills, a short start, looping walk and a short stop, from the locked Bible I2V harvest (`assets/sprites/player/{male,female}/`, packed by `tools/media.py pack-loco`).
- Basic attacks and specials are unarmed Down oneshot strips (`tools/media.py pack-oneshot`) for every weapon on both genders; specials copy the attack strip and missing facings fall back to Down. **Those Down strips are placeholders** until the content pipeline replaces them.
- Attack frames play by attack progress, not a fixed fps. Gather / death / Dispel use baked sheets. Equip overlays are carry art and do not replace the idle still. No engine blood pools.
- Loading: idle stills and overlays load at spawn for all eight facings; walk clips per facing on the first stick that needs it; attack / special on the first swing. Title → Play warmup draws the loaded stills under the loader sheet with the body visible, without uploading every walk frame. Extract-wake skips it.
