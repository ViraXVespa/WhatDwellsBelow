# Combat — dash, adrenaline, lock

Status: current plan
Read when: dash iframes, adrenaline rush, target-lock pointer
Code: `scripts/world/player/player_combat.gd`, `scripts/world/player/player_lock.gd`, `scripts/app/app_run.gd`

## Dash

- Activated with RB (Space).
- Full i-frames for the entire duration.
- Clear trail VFX required.

## Adrenaline Rush

- Triggers after sufficient kills in a short window (exact threshold tunable).
- Effects while active:
  - Increased movement speed
  - Stacking XP bonus (capped; tunables-combat)
  - Flaming aura on the player
  - Continuous wooshing / crackling sound
- Starts with a warcry.
- No cooldown, but the effect times out if the player stops killing.
- MUST keep killing to maintain the state.
- The aura `Sprite3D` stays hidden until adrenaline raises its alpha. It MUST NOT spawn as a default opaque quad.

## Target-lock

See input for full behavior.
