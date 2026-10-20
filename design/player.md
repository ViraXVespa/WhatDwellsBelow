# Player avatar, movement, and facing

Status: current plan  
Read when: movement, collision, character select, eight-dir body
Code: `scripts/world/player.gd`, `player_anim.gd`, `anim_load.gd`, `anim_loco.gd`, `facing.gd`  

## Character selection

- On first load the player chooses a male or female character.
- The character type may be switched later from the pause menu.
- 8-dir Bible layout, male/female animation parity, and paper-doll overlay law: art_pipeline.
- Male and female characters each require a complete, dedicated voice-over set of equal scope. Neither set is optional or derivative of the other.

## Movement

- Dash i-frames and trail VFX: combat.
- Movement MUST feel responsive and weighty on both gamepad and keyboard.

## Collision and body

- Prefer collision that matches the actual art silhouette / paper-doll bounds rather than a simple cylinder.
- The player SHOULD depth-sort against walls, props, enemies, and other world objects using implied real-world positions. Popping MUST be avoided wherever possible; it is not explicitly forbidden.

## Facing and animation system

- 8-directional facing derived from aim direction using smooth radial detection (not movement direction). Direction names match the Character Bible: Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right.
- Character art is generated and assembled according to art_pipeline. I2V unit and pack jobs stay on that door's Job table.
- In-game idle is the directional key still for the facing the player is aiming. It is not an I2V breath loop.
- Required player **body** states at minimum: `idle` (key still), `idle_to_walk`, `walk`, `walk_to_idle`, `attack_great_axe` / `attack_staff` / `attack_longbow`, `special_great_axe` / `special_staff` / `special_longbow`, `gather_pickaxe` / `gather_hatchet`, death, “Dispel”.
- `idle_to_walk` and `walk_to_idle` MUST exist for every facing. Playback MUST play the start transition when leaving idle into walk and a stop transition when coming to rest, rather than popping between the key still and a mid-stride walk frame.
- Start and stop are a few frames each, not a third of the clip. Walk is one looping stride cycle (both lead feet).
- The engine tracks which foot is leading in the walk loop. Stopping on the same lead foot that started the step plays `idle_to_walk` reversed; stopping on the opposite lead foot plays `walk_to_idle`.
- Those start / cycle / stop clips are cut from one walk I2V per facing (`tools/i2v_seeds.py` `--action walk`). They are not separate I2V units unless the User rejects that clip and asks for another pass.
- Attack, special, and gather I2V / body clips are unarmed. Overlay composite: art_pipeline §19.2.4.
- “Dispel” is ritual seppuku: the avatar draws a small knife, kneels, makes one abdominal cut, and collapses. That knife belongs to this clip. It is not an equipped overlay.
- Death is a hit collapse to a downed hold. Death and “Dispel” both end on a downed body. Neither I2V paints blood. The engine draws a blood pool under that pose.

## Body, clips and loading

Body and move numbers: tunables. Character is male or female.

- Locomotion: unarmed idle stills, a short start, looping walk and a short stop, from the locked Bible I2V harvest (`assets/sprites/player/{male,female}/`, packed by `tools/pack_locomotion.py`).
- Basic attacks and specials are unarmed Down oneshot strips (`tools/pack_oneshot.py`) for every weapon on both genders; specials copy the attack strip and missing facings fall back to Down. **Those Down strips are placeholders.** Replace them at the next week's first Grok Build session (User bringing a new I2V pipeline).
- Attack frames play by attack progress, not a fixed fps. Gather / death / Dispel use baked sheets. Equip overlays are carry art and do not replace the idle still. No engine blood pools.
- Loading: idle stills and overlays load at spawn for all eight facings; walk clips per facing on the first stick that needs it; attack / special on the first swing. Title → Play warmup draws the loaded stills under the loader sheet with the body visible, without uploading every walk frame. Extract-wake skips it.
