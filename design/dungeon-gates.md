# Dungeon — gates, stairs, fog

Status: binding design + live snapshot  
Read when: PREPARE plaque, extraction clerks, stair hold, reveal disk


## Boss / guardian rules

- Each Floor Guardian and the Gate Master spawns behind a special boss door that the player can see and prepare in front of.
- Stairs remain locked until the guardian / Gate Master is defeated.
- On death the boss drops a chest containing guaranteed equipment (including the possibility of blue rarity) plus one Artifact.

## Fog of war

- Reveal radius starts at a 5-tile baseline disk. Visited tiles stay revealed for the run.
- 3D floor, wall, and prop meshes are not gated on fog. Streaming draws complete nearby chunks.
- Large map overlay (View button) shows discovered tiles and important markers while the game continues running. Markers on unseen tiles stay hidden (`need_seen`).
- Large map starts at fit-to-frame. Zoom and pan live in `dungeon_map_act.gd` (wheel / pinch / look-mode RS). World camera zoom is unchanged. Bindings: input and ui.

## Extraction Gate limits

- Maximum one ghost shop per floor.
- Exactly three Extraction Gates per floor (tunable cap `max_clerks`, default 3).
- Gate rooms MUST be spread across the floor (minimum separation 28 cells).

Mail-legal goods and one-use visit rules: inventory.meta and interactables.

## Stairs

- Stairs only permit travel deeper.
- Stairs are locked behind boss until the guardian / Gate Master is killed.
- Stairs remain the only way to push `prog.deepest` to a floor the player has not yet reached.

Prompt / confirm copy: interactables.

## Live snapshot — boss doors

`boss_door.gd`: collision + “PREPARE” label; interact opens; linked doors open together; door tweens up, disables collision, frees grid cells, label becomes “OPEN”. Stairs still wait for `App.notify_boss_dead()`.

`scenes/foundation.tscn` is the combat sandbox / smoke host, not the player hub.

`--wdb-dungeon-map-smoke` loads a live floor (`App.begin_run`, pinned seed/floor) and dumps rooms, placed objects, spawn jobs, spec checks, and a downsampled ASCII occupancy map. Helper `scripts/debug/dungeon_map.gd`; runner `tools/run_dungeon_map.ps1`. Does not `stream_all`.

Enter dungeon covers immediately (`present.cover_enter` on the Floor Crystal press), waits until that sheet has presented (`wait_painted`: always-timer + two `frame_post_draw`), then saves and changes scene. It fades for 1.05s after floor `_ready` (`release_enter`). `--wdb-dungeon-load-timing-smoke` times Placeholdia → Dungeon (`go_camp`, then `begin_run` / `go_dungeon` / `dungeon_boot.ready_floor`). Runner `tools/run_dungeon_load_timing.ps1`. Clock starts after Camp is ready. Seed 42 / floor 1. Gear UI (`progress_ui`) is not const-preloaded in `dungeon_boot`; `world_ui()` / `ensure_ui()` load it on first extract / shop / anvil. Floor crystals load `crystal_ui` on interact, not at spawn. Dead-end crystal spur checks stop at `crystal_deadend_len` (hub-cell set, not a full-floor BFS). The large map overlay builds on first map-view, not at floor boot. World props, ambushes, and extra crystals queue after boot and instantiate on the 0.2s stream pulse inside `STREAM_IN` (P5 still eager-spawns the full dump). The Floor Guardian is a stream job. Boot builds nearby geo only. `stream_all` / `force_all` dumps enemies, queues ambushes, and flushes props.
