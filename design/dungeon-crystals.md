# Dungeon — floor crystals

Status: current plan  
Read when: transport decades, warp silence, spur length

## Floor crystals

- Each floor places the entrance crystal at spawn plus extra crystals in combat rooms.
- Crystal labels and placement bands use walk-distance CL only (`Threat.walk_level`). `enemy_cl_jitter` applies to enemies, not crystals.
- The entrance crystal is always `floor_lo` (CL 1 on floor 1).
- A placement band is `crystal_cl_band` combat levels wide (tunables-world). At most one non-dead-end crystal per band. A band is not required to receive a crystal.
- Extra crystals MUST keep `crystal_min_sep` from the entrance and from each other. Separation is checked on the final cell after the room snap.
- Dead-end crystals ignore the per-band cap. They still need a long spur (`crystal_deadend_len`), `crystal_deadend_sep` from spawn, and `crystal_min_sep` from every other crystal.
- Layout lives in `crystal_place.gd`. Bind, warp, silence, menus, and safe-zone volumes live in `net.gd`. Safe zones use Area3D `SafeVolume` nodes (radius `crystal_arrive_r`). On `body_entered`, non-pursuing / non-aggroed enemies are reversed; occupancy is tracked with a volume counter. Clear / relocate is a one-shot (no per-frame walk).
- The entrance crystal is bound on arrival. Any other crystal is unbound until the player clears enemies in its area (`crystal_clear_r`) and interacts.
- Bound crystals open the transport menu. They do not descend.
- Local Transport Network unlocks when at least two crystals on the current floor are bound. Selecting a bound crystal teleports the player there and silences nearby spawn jobs.
- Floor Transport Network unlocks when `prog.deepest` is greater than the current floor. It lists every reached floor. Past a set number of reachable floors, the list is grouped (1–10, 11–20, …; tunables-economy). The current floor is disabled. Unreached floors in a decade folder stay disabled.
- Floor hops land at the destination floor’s entrance crystal. Boss-defeated state is remembered per floor for the current run.
- Activated crystals stay enemy-free at `crystal_arrive_r` so a hop does not drop the player into a pack. Enforcement is event-driven via the SafeVolume (reverse on entry for non-pursuing enemies; `volume_clear` checks occupancy).

Verbs and Placeholdia loadout crystal: interactables.
