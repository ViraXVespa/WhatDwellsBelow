# Scene legs: title, Placeholdia, dungeon

Status: current plan  
Read when: loader handoff, descent, next floor, expedition ending  
Code: `scripts/app/app_flow.gd`, `scripts/app/flow_hub.gd`, `scripts/app/flow_leg.gd`, `scripts/app/app_run.gd`

| Leg | Entry | Steps |
|-----|-------|-------|
| Title → Placeholdia | `App.play_from_menu` | loader up, hub preload list, `go_camp`, wait for the camp scene and its build, hub warm-up, loader finish |
| Placeholdia → dungeon | `App.enter_dungeon` (crystal board) | enter cover, wait painted, save, pack the dungeon scene, `begin_run` → `go_dungeon` |
| Next floor | `App.next_floor` | keep hp, floor + 1, deepest, `go_dungeon` |
| Run end | `App.end_run(cond, killer)` | player exit animation, then `finish_end`: end sound, telemetry end, recap (or `go_camp` with no recap) |
| Any → title | `App.go_title` | hide overlay, stop music, unpause, change scene |

- `flow_leg.gd` holds the two steps every leg repeats: `change_scene` (packed when loaded, then wake the web pad) and `wait_scene` (at most 240 frames).
- `flow_hub.gd` owns the hub preload list, loader milestones (`loader_weights.gd` shares) and the warm-up; the web build leaves hub music out of the list because the browser plays it.
- `begin_run` resets run state, sets the seed (`--wdb-seed` fixes it) and the weapon, and resets telemetry unless a live playtest runs.
- A live playtest already in the dungeon skips covers and waits; the perf sweep and the campaign series take the same cover as a player.
