# Player avatar, movement, and facing

Status: binding design
Read when: changing movement, collision, facing, or character select
Code: `scripts/world/player.gd`, `player_anim.gd`, `facing.gd`
See also: `design/input.md`, `design/combat.md`, `design/art-pipeline.md`

## Character selection

- On first load the player chooses a male or female character.
- The character type may be switched later from the pause menu.
- Both character types MUST be fully animated and kept in parity so that all weapon paper-doll appearances and animations function correctly on either without special per-gender tweaks.
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
- Required player states at minimum: idle, walk, attack (per weapon), special (per weapon), gathering (mining/woodcutting), death, “Dispel”.
- Each weapon requires its own paper-doll equip appearance and associated animations.
- Male and female player characters MUST maintain full animation parity.
- All directional variants of the same animation state MUST contain exactly the same number of frames.

## Live snapshot

`PLAYER_BODY = Vector3(0.42, 0.78, 0.32)`, `PLAYER_H = 1.55`, `MOVE_EPS = 0.12`, `WALK_FPS = 8`.
`App.character_type` is `"male"` or `"female"`.