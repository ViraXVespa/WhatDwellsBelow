# Range-limit and share LOS / separation checks

id: ai-scaling
owner: web
status: open
done-when: LOS rays and separation queries run only for enemies near the player, groups in the same room can share a single aggro/LOS test, behavior is unchanged for the player, gates pass
resume: start a web session and open the ai-scaling task

## Background
Every enemy runs a periodic physics ray (`Combat.los`) and a SepGrid separation query. On web the physics server is single-threaded; many simultaneous checks hitch. Most of those checks are redundant when enemies are far away or when a whole room should wake together.

## Required
- Skip LOS and separation when the enemy is outside a defined range of the player.
- Add a room-level or group-level check so enemies in the same space can enter aggro from one shared test instead of each casting its own ray.
- Preserve current feel: enemies that should see or chase the player still do.

## Acceptance
- No new “enemies ignore me” or “enemies see through walls” bugs.
- Measurable reduction in physics queries when many enemies are present but distant.
