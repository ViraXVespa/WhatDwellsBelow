# Graphics

Status: binding design + live snapshot
Read when: cel-look owner, dual-palette atmosphere
Code: `scripts/graphics/`

This file is the door. Open the Job-table sibling only when that row matches.

World presentation owner. Hub and dungeon share one env kit, one ground shader, one light RT (render target: a small texture lights are drawn into, then sampled), and one actor policy (sprite tint + floor squash).

Live helpers already exist: `env_kit.gd`, `nearest_mat.gd`, `wrap_shader.gd`, `mm_emit.gd`. Minimap is `dungeon_minimap.gd`. Foundation smoke calls the env kit only.

Hub: warm kit, wide sun disc in the RT, floor crystal as a local source. Dungeon: cold kit, no sun in the RT, wall torches plus crystals plus campfires. Halls stay dark except junctions. Characters tint from the RT. Promo is before/after wherever it reads.

Does not own: dungeon gen, stream rings, wall collision merge, map reveal, camera zoom, Sprite3D filter modes.

Out this week: engine shadow maps, unique atlas, hex-tile, player lantern, shop/gate/stair lights, foundation pretty-pass, flicker system.

Build Imagine makes field sheets and the unlit 4-facing torch bible plus flame VFX (same harvest style as character stills). Isolated, one unit per job.
When a job Imagines, the User names the Imagine / isolated-media owner in that Build session's first message. Job files do not name that owner.
If the week slips: drop extra variants, then extra light discs. Do not drop ground, the light RT, or player squash.

Jobs after the reuse PR, one session each, forked from this door:

1. ground — shared shader, world-xz hash variants, RT sample (white until buffer)
2. volume — exposed greedy wall faces, world-UV, wall samples RT
3. buffer — 1 texel per tile on the stream ring, occupancy, sources
4. actor — RT tint at feet, squash from nearest source

Env fog and void ride the kit, not a fifth owner.

| Job | Open |
|-----|------|
| hearth-warm hole-cold Environment, abyss-plinth, caller redirect | `design/graphics-env.md` |
| hashed field albedo, shared spatial shader, turf quilts, carved planes | `design/graphics-ground.md` |
| exposed coplanar brick runs, BoxMesh retirement, hitbox-untouched | `design/graphics-volume.md` |
| 256-512 xz radiance buffer, disc blobs, tile occupancy | `design/graphics-buffer.md` |
| billboard-alpha squash quads, player yard-mannequin foes, source-offset | `design/graphics-actor.md` |
