# Enemies

Status: binding design + live snapshot
Read when: changing roster, AI, bosses, or combat-level scaling
Code: `scripts/combat/enemy.gd`, `roster.gd`, `telegraph.gd`
See also: `design/skills.md`, `design/dungeon.md`

## Enemy variety

- Minimum of 12 different types of normal enemies.
- At least 5 different types appear on each floor.
- Enemies MUST have varied attack patterns, movement types (hopping, walking, flying, etc.), and appearances so they feel distinct in combat.
- Palette swaps and stat swaps between floors are used to increase perceived variety.
- Enemies should use a variety of classic fantasy representations (slimes, goblins, orcs, etc.).
- All enemies MUST feel distinct from one another and remain visually consistent with the dungeon style and tone of the game.

## Roles present in demo

The following are suggested starting roles, not a closed or mandatory roster. Grok Build MAY invent additional or different roles so long as combat stays readable and the floor-variety rules in this section are met.
Suggested starting roles:
- Bruiser (melee)
- Ranged
- Tank
- Mage

Floor Guardians (floors 1–4) and the Gate Master (floor 5) MUST have high health and durability on top of their other stats. They are not required to be melee or close-range; ranged, mage, mixed, or other readable attack styles are allowed. Unique telegraphs are encouraged. Special spawn / door / chest rules already defined still apply. Tank remains only a suggested starting template, not a required boss type.

## Named monsters

- Appear randomly at a rate of roughly once every 3 floors.
- Slightly larger variants of their normal counterparts.
- Name is randomly generated via a syllable-combination and randomization system.
- Name appears beneath the enemy model in yellow text with a thin black border.
- Each named monster receives a few stronger variants of the normal enemy’s attacks (example for ranged: three projectiles at the normal rate, or two projectiles at a faster rate).
- When a “vanquish specific named enemy” quest is active, that exact named monster (name and type locked on quest acceptance) is the only named monster that can appear until the quest is completed.

## Attack telegraphs and feel

- All enemy attacks MUST have clear, readable wind-ups.
- Melee (Bruiser / Tank): visible wind-up pose → lunge. Direction locks at the start of the wind-up.
- Ranged: visible draw / charge pose → projectile release. Direction locks on draw.
- Mage / other non-melee styles: visible charge / cast pose → readable area or projectile. Direction or target locks at the start of the telegraph.
- All telegraphs respect line-of-sight.

## AI behavior

Enemies require line-of-sight to begin attacking or chasing.
When LOS is lost they may briefly hunt the last-seen position, then return to idle.
Enemies MUST also drop pursuit if the distance to the player exceeds a tunable leash range, even if they still have LOS. After dropping pursuit they return to idle / their post. This exists so a player who is overwhelmed can flee combat instead of being chased indefinitely.
Exact leash distance, hunt duration after lost LOS, and re-aggro rules are tunable via the secret debug menu.
Implement clean steering, separation, and stuck-handling appropriate for the orthographic Camera3D live path.
Flee event occurs an average of 2 times per floor on a full clear: after the group has taken sufficient damage, the fastest enemy in the encounter flashes a clear “!” overhead, receives a small but noticeable speed boost, and flees to spawn reinforcements. No other telegraph is required beyond the “!”.

## Idle / pressure spawns

If the player remains idle too long outside a safe room, or stops revealing new map area for a tunable duration, additional enemies MUST spawn around the player.
- MUST NOT spawn inside safe rooms (clerk, ghost shop, puzzle).
- Idle timer, no-reveal timer, spawn count, and spawn radius are tunable via the secret debug menu.
- Purpose: the dungeon stays reactive if the player camps or stalls exploration.

## Death presentation

1. Play death animation.
2. Drop loot (XP, gold, possible gear / Artifact).
3. Body disappears cleanly.

No lingering corpses required.

## Loot

- XP and gold amounts scale with floor and role.
- Gear drop chance and rarity (white / green / blue) are tunable.
- Floor Guardians and Gate Master always drop the special chest (guaranteed equipment that may include blue rarity + one Artifact) in addition to normal drops.

## Live snapshot — roster (`roster.gd`)

| Id | Family |
|----|--------|
| slime, goblin, orc, skeleton, bat, spider, wolf, beetle | melee |
| archer, wisp | ranged |
| shaman, imp | mage |

12 normal types. Named names use PRE / MID / SUF syllable arrays.

Live AI defaults: leash 9, hunt 1.8, reaggro 0.6, aggro 7.5, flee speed ×1.45, idle 24 s, no-reveal 22 s, pressure count 3 / radius 5 / cd 18. Wind-ups: melee 0.42, ranged 0.38, mage 0.55, recover 0.35.

Enemy combat level keys: `design/skills.md` and `design/tunables.md`.