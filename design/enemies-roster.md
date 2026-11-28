# Enemies — roster and types

Status: current plan
Read when: monster variety, suggested roles, named monsters, new enemy type
Code: `scripts/combat/roster.gd`, `scripts/combat/enemy/enemy_setup.gd`, `scripts/data/balance/enemies.gd`

## Enemy variety

- A roster of normal enemy types, with a minimum mix on every floor (counts: tunables-world).
- Enemies MUST have varied attack patterns, movement types (hopping, walking, flying, etc.), and appearances so they feel distinct in combat.
- Palette swaps and stat swaps between floors are used to increase perceived variety.
- Enemies should use a variety of classic fantasy representations (slimes, goblins, orcs, etc.).
- All enemies MUST feel distinct from one another and remain visually consistent with the dungeon style and tone of the game.

## Art and I2V

Enemy frames follow art_pipeline. New enemy art is a subject on that door. Do not start an enemy bible. There is not a second enemy pipeline.

## Roles present in demo

The following are suggested starting roles, not a closed or mandatory roster. A new or different role is a design decision: Grok Build asks the User through `ask_user_question` (never picks one), and the role must keep combat readable and meet the floor-variety rules in this section.  
Suggested starting roles:

- Bruiser (melee)
- Ranged
- Tank
- Mage

Floor Guardians (floors 1–4) and the Gate Master (floor 5) MUST have high health and durability on top of their other stats. They are not required to be melee or close-range; ranged, mage, mixed, or other readable attack styles are allowed. Unique telegraphs are encouraged. Special spawn / door / chest rules already defined still apply. Tank remains only a suggested starting template, not a required boss type.

## Named monsters

- Appear randomly every few floors (named monster rate: tunables-world).
- Slightly larger variants of their normal counterparts.
- Name is randomly generated via a syllable-combination and randomization system.
- Name appears beneath the enemy model in yellow text with a thin black border.
- Each named monster receives a few stronger variants of the normal enemy’s attacks (example for ranged: three projectiles at the normal rate, or two projectiles at a faster rate).
- When a “vanquish specific named enemy” quest is active, that exact named monster (name and type locked on quest acceptance) is the only named monster that can appear until the quest is completed.

## Roster

| Id | Family |
|----|--------|
| slime, goblin, orc, skeleton, bat, spider, wolf, beetle | melee |
| archer, wisp | ranged |
| shaman, imp | mage |

12 normal types. Named names use PRE / MID / SUF syllable arrays.

Enemy combat level keys: the tunables gate. Player-facing CL feel: combat.

## Add an enemy type (live files)

One id (`wolf`) lives in: `roster.gd` (`IDS`, `POOLS` so every floor keeps at least 5 types, the `_all()` row: role, move, dmg, spd, range, def, size, arc; no hp), `scripts/data/balance/enemies.gd` (`IDS` plus the live row, the one source of hp; its `e_<id>_*` keys feed `App.bal` and the debug menu, and `Roster.def` prefers them over the `roster.gd` row), art `assets/sprites/enemies/<id>/idle_down.png` (`enemy_setup.gd` loads it by id; produce it through art_pipeline), then the roster and HP lines above and the HP row in the tunables gate. Prove with smoke 4. A new role or family, or any 13th type even inside an existing family, is the User's call: ask (`ask_user_question`), never add one on your own. The Bot never adds enemy types.
- Hall travelers: kind `hall`, one enemy spaced along long corridor runs (spacing: tunables-world), placed from the floor seed and skipped on ambush cells. Ambushes stay the surprise trap. Room packs are unchanged.
