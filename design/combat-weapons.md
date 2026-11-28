# Combat — weapons

Status: current plan
Read when: great axe, lightning staff, longbow arrows, special mana
Code: `scripts/combat/player_hit.gd` (facade) + `player_hit/` (`hit_atk.gd` specials and fx, `hit_fx.gd` basics and telegraphs, `hit_core.gd` damage and arrows), `projectile.gd`, `aim_line.gd`, `telegraph.gd`, `scripts/world/player/player_combat.gd`

## Weapon system

The player may equip one of three weapons: Great Axe, Lightning Staff, or Longbow.
Starting weapon is selected in the loadout. Mid-run weapon changes are performed by equipping from the pause-menu inventory.
The shipped weapon overlay sits on the unarmed body clip (art_pipeline). New art does not add a paper-doll pass. Attack and special still use a body clip per weapon class with the weapon layered on top.
Specials for all weapons are activated with A (RMB). A special spends `special_mana` when the windup completes and does not start when mana is short. Mana refills over time (`mana_regen`), from mana orbs, and from potions and food. A new dive starts mana full. After the special active phase, attack/animation recovery lasts one normal attack duration for the equipped weapon. The independent `special_recovery` timer still starts at that phase boundary and gates only another special; normal attacks do not wait for it.

## Great Axe

- Basic attack: Hold-to-attack (X / LMB). Continues automatically while held. Arc and range are tunable. A single swing can hit multiple enemies inside the fan. Line-of-sight requirement is tunable. Damage application MUST be synchronized to the correct animation frame.
- Special (Slam): Short wind-up and recovery. Higher damage multiplier than a basic attack (exact value tunable). Applies a readable stagger (shorter duration against Floor Guardians and the Gate Master). Produces dedicated ground-crack VFX. Uses circular occupancy around the player.

## Lightning Staff

- Basic attack: Hold-to-attack (X / LMB). Weak melee strikes that continue automatically while held. Range and arc are shorter and lower-damage than the Great Axe (exact values tunable). A single strike can hit multiple enemies inside its fan. Line-of-sight requirement is tunable. Damage application MUST be synchronized to the correct animation frame.
- Special: AoE lightning bolt that strikes a targeted area. Possesses a distinct short wind-up. Damage, radius, and any secondary effects are tunable. MUST clearly telegraph the affected area and show when the bolt is active. Uses circular occupancy at the strike point.

## Longbow

- Idle aim: a single straight translucent yellow line at shoulder height, weapon range. Axe and staff keep the ground aim line. Do not stack a second bow telegraph on the idle line. Do not flash the bow path red.
- Basic attack: Hold-to-attack (X / LMB) fires one arrow that travels along that path. The projectile MUST face travel, sit on the line, and test occupancy on the arrow **head** as it moves (`Cover.hit_shot`). Damage application MUST be synchronized to the projectile, not a ground cone.
- Planted bow hits (high coverage) stop the arrow and deal full scaled damage. A glancing hit MAY continue, MAY strike one more enemy, and MUST reduce remaining damage from the first contact’s coverage. After that second body the arrow despawns.
- Breakables do not stop the arrow and do not reduce its damage.
- Special: fires several arrows in a spread (`bow_special_count`, cone, range tunable). Telegraph is one yellow line per shot, not a filled cone. Each arrow is its own occupancy test and may glance independently.
- Live occupancy tests only hosts near the arrow tip (tip radius plus sprite span). Far enemies and breakables are skipped. Sprite sample points are reused for the current process frame. The texel mask is packed once per texture under the loader and reused by every sprite that shows that texture. A non-RGBA8 texture still reads `get_pixel`. Packing the mask did not remove the first great-axe slam stall.
