# Park: dungeon feel

Status: parked
Read when: the User names dungeon_feel or says colony hybrid / stacked tubes / unused stone

Not a boot file. Not a dungeon job.

## Mandate

An expansive dungeon that can lose you. Exploration is the goal, not solving a lattice.

Rooms stay chambers. Halls are 2-4 m, mostly cardinal, winding, with forks and real dead-end stubs. Unused stone stays dark. Angled corridors (27 / 33 / 45) are seasoning on long two-axis links, not the silhouette and not four tokens on a 432 map.

One carved corridor is one wall pair. Collision and torch mounts follow that mesh. The 1 m grid is occupancy, rooms, fog, minimap, and default walk. No floor-wide polyline. No whole-map maze grow. Do not merge hall spans across gaps.

## Frozen decisions

- Revert the 2026-09-29 gen / outline / stream / mesh / spec / balance thrash.
- Hitch-log junk skip and scratch dump_job / changelog layout are not this park.
- Live angled corridor cap of 4 is too scarce for the target. Raise it only with the carve slice.
- Do not stamp rim_closed OK to hide holes on hall-local spans.

## Open questions

- Extra loops that hug an existing hall still draw a second tube. Skip or reuse the open run.
- How many dead-end stubs read as turned-around without a puzzle maze.
- Torch density once a single wall pair exists per hall.

## Paths

- Source: scripts/dungeon/gen.gd, scripts/dungeon/gen_carve.gd, scripts/dungeon/gen_outline.gd, scripts/world/dungeon_geo_stream.gd, scripts/graphics/wall_mesh.gd
- Docs: dungeon owner, gen job, stream job, volume job
- Tests: tools/run_dungeon_map.ps1. Walk spawn for one corridor = two faces.

## Why parked

Session diagnosis is usable. Live implementation lost the playable look. User reverted and asked to park before another carve slice.
