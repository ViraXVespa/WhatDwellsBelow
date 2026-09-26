# Graphics

Status: binding design + live snapshot
Read when: cel-look owner, dual-palette atmosphere
Code: `scripts/graphics/`

This file is the door. Open the Job-table sibling only when that row matches.

World presentation owner. Hub and dungeon share one env kit, one ground shader contract, one small light RT, and one actor-shadow policy. Live play path and the foundation smoke arena must call the same kit.

Does not own: dungeon gen, stream rings, wall collision merge, map reveal, camera zoom, Sprite3D filter modes, art sheet harvest.

Bot reuse lands `scripts/graphics/` and extracts env kit, nearest-mat, wrap shader, shared emit, and the minimap cluster out of `dungeon_geo.gd`. Bot does not implement this door.

Build jobs after that PR, one session each, forked from this door:

1. ground — shared shader, hashed 2-4 field variants, hub pads/yard and dungeon floors
2. volume — exposed or greedy wall visuals, world-UV bricks
3. buffer — 256-512 XZ RT, discs, tile occupancy. No engine shadow maps
4. actor — sprite-mask floor quads, nearest light, player plus dummy plus enemies

Env fog and void are a short add on the kit, not a fifth owner. Field sheets are isolated Imagine plus a wire-up.

Anti-tile v1 is the shader plus field variants. Unique atlas and hex-tile are later. Promo is before/after wherever it reads.

| Job | Open |
|-----|------|
| hearth-warm hole-cold Environment, abyss-plinth, caller redirect | `design/graphics-env.md` |
| hashed field albedo, shared spatial shader, turf quilts, carved planes | `design/graphics-ground.md` |
| exposed coplanar brick runs, BoxMesh retirement, hitbox-untouched | `design/graphics-volume.md` |
| 256-512 xz radiance buffer, disc blobs, tile occupancy | `design/graphics-buffer.md` |
| billboard-alpha squash quads, player yard-mannequin foes, source-offset | `design/graphics-actor.md` |
