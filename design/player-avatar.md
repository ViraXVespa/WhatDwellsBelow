# Player — character and body

Status: current plan
Read when: male or female pick, matching voiceover, silhouette bounds
Code: `scripts/world/player/player_setup.gd`, `scripts/world/player/ground.gd`, `scripts/world/player/near_interact.gd`

## Character selection

- On first load the player chooses a male or female character.
- The character type may be switched later from the pause menu.
- 8 directions, male/female animation parity, and the shipped paper-doll overlays: art_pipeline. New frames come from that pipeline. Do not start a Bible or an I2V unit.
- Male and female characters each require a complete, dedicated voice-over set of equal scope. Neither set is optional or derivative of the other.

## Collision and body

- Prefer collision that matches the actual art silhouette / paper-doll bounds rather than a simple cylinder.
- The player SHOULD depth-sort against walls, props, enemies, and other world objects using implied real-world positions. Popping MUST be avoided wherever possible; it is not explicitly forbidden.
