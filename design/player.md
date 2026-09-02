design/player.md

# Player avatar, movement, and facing

Status: binding design  
Read when: changing movement, collision, facing, or character select  
Code: `scripts/world/player.gd`, `player_anim.gd`, `facing.gd`  
See also: `design/input.md`, `design/combat.md`, `design/art-pipeline.md`

## Character selection

- On first load the player chooses a male or female character.
- The character type may be switched later from the pause menu.
- Both character types MUST be fully animated and kept in parity so that weapon and tool paper-doll **layers** composite correctly on either body without special per-gender tweaks.
- Male and female characters each require a complete, dedicated voice-over set of equal scope. Neither set is optional or derivative of the other.

## Movement

- Dash grants complete invulnerability frames for its entire duration and leaves a clear trail VFX.
- Movement MUST feel responsive and weighty on both gamepad and keyboard.

## Collision and body

- Prefer collision that matches the actual art silhouette / paper-doll bounds rather than a simple cylinder.
- The player SHOULD depth-sort against walls, props, enemies, and other world objects using implied real-world positions. Popping MUST be avoided wherever possible; it is not explicitly forbidden.

## Facing and animation system

- 8-directional facing derived from aim direction using smooth radial detection (not movement direction). Directions exactly match the Character Bible layout: Up, Down, Left, Right, Up-Left, Up-Right, Down-Left, Down-Right.
- Character art is generated and assembled according to the mandatory pipeline in `design/art-pipeline.md`.
- In-game idle is the directional key still for the facing the player is aiming. It is not an I2V breath loop.
- Required player **body** states at minimum: `idle` (key still), `idle_to_walk`, `walk`, `walk_to_idle`, attack body clip per weapon class, special body clip per weapon class, gathering body clip per tool class, death, “Dispel”.
- `idle_to_walk` and `walk_to_idle` MUST exist for every facing. Playback MUST play the start transition when leaving idle into walk and the stop transition when coming to rest, rather than popping between the key still and a mid-stride walk frame.
- Those start / cycle / stop clips are cut from one walk I2V per facing (`tools/i2v_seeds.py` `--action walk`). They are not separate I2V units unless the User rejects that clip and asks for another pass.
- Body clips are unarmed. Each weapon and tool is a paper-doll overlay composited onto those clips (`design/art-pipeline.md` §19.4). Do not ship a full baked character animation set per weapon.
- Male and female player characters MUST maintain full animation parity.
- All directional variants of the same animation state MUST contain exactly the same number of frames.

## Live snapshot

`PLAYER_BODY = Vector3(0.42, 0.78, 0.32)`, `PLAYER_H = 1.55`, `MOVE_EPS = 0.12`, `WALK_FPS = 8`.  
`App.character_type` is `"male"` or `"female"`.  
Live `player_anim.gd` still loads per-weapon baked sheets and a static `equip_*` overlay, and it does not yet play `idle_to_walk` / `walk_to_idle`. That is behind this binding and is not a third system — patch live toward layers + transition states when the User orders that engine slice.