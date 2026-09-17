# Player avatar, movement, and facing

Status: binding design  
Read when: movement, collision, character select, eight-dir body
Code: `scripts/world/player.gd`, `player_anim.gd`, `player_anim_load.gd`, `player_anim_loco.gd`, `facing.gd`  


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

## Live snapshot

`PLAYER_BODY = Vector3(0.42, 0.78, 0.32)`, `PLAYER_H = 1.55`, `MOVE_EPS = 0.12`, `WALK_FPS = 8`.  
`App.character_type` is `"male"` or `"female"`.  
Live `player_anim.gd` plays unarmed `idle` stills, a short `idle_to_walk`, looping `walk`, and a short stop (`walk_to_idle` or reversed `idle_to_walk` from `loc_foot`) from the locked Bible I2V harvest (`assets/sprites/player/{male,female}/`). Packer (`tools/pack_locomotion.py`) cuts start/stop as the last/first few frames around one self-similar stride loop. Basic attacks and specials are unarmed Down oneshot harvest (`tools/pack_oneshot.py`) for great-axe / staff / longbow on both genders (specials currently copy the attack Down strip); missing facings fall back to Down. **Those Down attack/special strips are placeholders.** Replace them at the next week’s first Grok Build session (User bringing a new I2V pipeline). `pack_oneshot.py` lock_x uses the 128 idle still, not the raw Bible cell. Basic attack frames play by `atk_t / duration`, not `atk_fps`. Gather / death / Dispel still use older baked sheets. Equip overlays remain stats-adjacent carry art and no longer replace the idle still. Engine blood pools for death / “Dispel” are not shipped yet.

Spawn loads idle stills (and equip overlays) for all eight facings. Walk / `idle_to_walk` / `walk_to_idle` for a facing load on the first stick that needs that facing (`PlayerAnimLoad.ensure_loco`). Down attack / special load on the first swing or gather (`ensure_attack`). Title → Play hub warmup (`PlayerAnim.warmup` / `warmup_texs`, driven from `AppFlow._warmup_hub`) applies whatever clips are already loaded — idle stills at spawn — while the body stays visible under the solid loader sheet. It does not hide the sprite. A tiny `move_and_slide` is restored to the spawn point so the first real stick is not the first physics or GPU use. Extract-wake does not run that pass.
