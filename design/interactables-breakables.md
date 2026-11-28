# Interactables — breakables and HP orbs

Status: current plan
Read when: pots and barrels, HP orbs, smash sound
Code: `scripts/world/breakable.gd`, `scripts/world/pickup.gd`

## Breakables (pots / barrels)

- Destroyed on a single player hit.
- Chance to drop gold and/or an HP orb (walk-over pickup).
- Clear smash VFX and SFX required.

## HP orbs

Walk-over HP orbs (`pickup.gd`) apply `orb_heal`. If the player is already at full HP, the orb stays on the ground and retries after a short wait.
