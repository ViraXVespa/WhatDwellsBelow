# Player — Bow mode

Status: current plan
Read when: Bow mode, LT steer, RT shoots
Code: `scripts/world/bow_mode.gd`, `scripts/world/player/player_lock.gd`, `scripts/world/player/player_tick.gd`

## Bow mode

Settings > Gameplay **Bow mode** (saved as `bow_mode`, off by default; `scripts/world/bow_mode.gd`).

- Off: the longbow fires on Attack (X / LMB / touch Attack) toward the facing or lock target, like every weapon. Aim (LT / Shift) and Fire (RT) do nothing in the world.
- On, with the longbow equipped: hold Aim (LT, Shift, or the touch bow stick) to aim. The right stick, mouse or bow stick steers; the walk slows to the attack pace and does not turn the aim; a manual aim outranks target lock; the aim line shows even when it is off in Settings. Fire (RT, or the bow stick while held) shoots; Attack still shoots too.
- Other weapons ignore Bow mode. Check: `dungeon-bow-mode` flow (`debug/bow_mode_check.gd`).
