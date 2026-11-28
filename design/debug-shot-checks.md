# Shot-flow check scripts

Status: current plan
Read when: planted faults, unit probes
Code: `scripts/debug/*_check.gd`, `scripts/debug/hub_shadow_check/`, `scripts/debug/hub_light_spread.gd`, `scripts/debug/hub_mark_light.gd`, `scripts/debug/shot_views.gd`, `scripts/debug/drop_stage.gd`

A shot flow (`tools/data/shot-flows/*.json`, gate `shot_flows`) calls these through `script:debug/<file>.<func>` steps. Each check asserts one look or layout rule and has a planted fault that must FAIL. They are white-box tests: a check may preload the helpers of the system it checks (light_rt, actor_lit, camp, binds, HUD). Live code never loads them.

| Script | Flow | Checks |
|---|---|---|
| `hub_shadow_check.gd` + `hub_shadow_check/` (`mark_matrix`, `fly_matrix`, `mark_mask`, `feet_px`, `edge_px`, `mark_px`, `flat_px`) | camp-prop-shadows, camp-mark-matrix | yard prop marks, dumpster wheels, per-foot mark pins, flyer marks (hub door `hub-bake.md`) |
| `hub_face_check.gd`, `hub_shade_check.gd`, `hub_bond_check.gd`, `hub_awning_check.gd`, `hub_pool_check.gd`, `hub_light_spread.gd`, `hub_mark_light.gd` | camp-prop-shadows | face light, shade caps, running bond, awning hem, lantern pools, light spread, player mark light |
| `hub_stall_check.gd` | vendor-stall | stall layout |
| `dungeon_mark_check.gd`, `dungeon_wall_check.gd` | dungeon-marks | dungeon marks, wall light and FOV |
| `torch_pop_check.gd` | dungeon-torch-pop, dungeon-torch-walls | torch spans and pop-in |
| `map_marks_check.gd` | dungeon-map-marks | big map marks |
| `menu_fade_check.gd` | camp-menu-fade, dungeon-map-fade | menu fade |
| `layout_check.gd` | camp-pause-menu, camp-pause-phone, camp-menu-fade, dungeon-touch-controls | pause layout |
| `touch_layout_check.gd` | dungeon-touch-controls | touch HUD layout |
| `controls_check.gd`, `keycap_check.gd` | camp-controls | binds table, keycaps |
| `bow_mode_check.gd` | dungeon-bow-mode | bow mode |
| `shot_views.gd`, `drop_stage.gd` | movies, dungeon-pickups | staging, not checks |
