# Park: dungeon feel

Status: parked
Read when: the User names dungeon_feel or says colony hybrid / stacked tubes / unused stone

Not a boot file. Not a dungeon job.

## Mandate

An expansive dungeon that can lose you. Exploration is the goal, not solving a lattice.

Occupancy is the dungeon. The cleaned 1 m FLOOR/WALL grid is walk, fog, minimap, default collision, and stream index. Rooms stay axis-aligned chambers. Halls are 2-4 m, mostly cardinal, winding, with forks and real dead-end stubs. Unused stone is simply never carved. Dark mass is the gap, not a second silhouette.

Angled corridors (27 / 33 / 45) are rare local packets on long two-axis links. They are seasoning, not the feel. One carved corridor is one wall pair. Collision and torch mounts follow that published run. No floor-wide polyline. No whole-map maze grow. Do not merge hall spans across gaps.

## Frozen decisions

- Revert the 2026-09-29 gen / outline / stream / mesh / spec / balance thrash.
- Hitch-log junk skip and scratch dump_job / changelog layout are not this park.
- Live angled corridor cap of 4 is too scarce for the target. Raise it only with the carve slice.
- Do not stamp rim_closed OK to hide holes on hall-local spans.
- Extra loops may run near another hall. They must not hug it. Count unused cells between the two floors. Minimum legal gap is 3. First live default is 4. A hug candidate is rejected. Do not weld the two runs.
- Dead-end stubs are aborted colony tunnels: a small hall-leaf budget, on the order of extra loops, not on the order of rooms. Leaf rooms stay chambers. Short stubs stay dark. Long-spur crystals keep crystal_deadend_len.
- Torches stay somewhat common but sparse. Halls at doorways, junctions, and dead ends; at most one per room unless a crystal or campfire is already there. Usually at least one flame in a fully zoomed-out frame. Do not retune range or energy to fake coverage.
- Publish is one-way. Gen writes hall runs (and rare angled packets). Stream instances those runs. Volume paints those runs. Buffer hangs lights on those interior faces. Outline bake is gen. Volume does not own gen_outline. Stream does not invent a lip.
- Fillet and jag are not rim operators. Wear is shader-side.

## Open questions

- None from the park packet. Stub count stays a tunable after the first map walk.

## Paths

- Source: scripts/dungeon/gen.gd, scripts/dungeon/gen/carve.gd, scripts/dungeon/gen/outline.gd, scripts/world/dungeon_geo/geo_stream.gd, scripts/graphics/wall_mesh.gd
- Docs: dungeon owner, gen job, stream job, volume job, buffer job
- Tests: tools/run_dungeon_map.py. Walk spawn for one corridor = two faces.

## Why parked

Session diagnosis is usable. Live implementation lost the playable look. User reverted and asked to park before another carve slice. Live code has not yet caught this spec.
