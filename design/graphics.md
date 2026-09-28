# Graphics

Status: binding design + live snapshot
Read when: cel-look owner, dual-palette atmosphere
Code: `scripts/graphics/`

This file is the door. Open the Job-table sibling only when that row matches.

World presentation owner. Hub and dungeon share one env kit, one ground shader, one light RT (render target: a small texture lights are drawn into, then sampled), and one actor policy (sprite tint + two-foot-pinned squash).

Live helpers already exist: `env_kit.gd`, `nearest_mat.gd`, `wrap_shader.gd`, `mm_emit.gd`. Minimap is `dungeon_minimap.gd`. Foundation smoke calls the env kit only.

Hub: warm kit, wide sun fill in the RT, floor crystal as a local bump. Hub squash follows the sun as parallel light. Dungeon: cold kit, no sun in the RT, walkable dim fill plus wall torches, crystals, and campfires. Pits stay black. Characters tint from the RT. Promo is before/after wherever it reads.

Does not own: dungeon carve, hall segments, authored rims, solid bake, stream rings, map reveal, camera zoom, Sprite3D filter modes. Gen writes outline_spans and solid. Volume skins the provided spans only. Buffer stamps the light RT and mounts torches on those spans. Occupancy reads solid only. Hitboxes stay stream boxes on solid, not a third grid.

Out this week: engine shadow maps, unique atlas, hex-tile, player lantern, shop/gate/stair lights, foundation pretty-pass.

Build Imagine stills this week, isolated, one unit per job: grass field, packed dirt, dungeon floor, wall brick, and the unlit 4-facing torch-and-bracket bible. Flame is generated code VFX on a Y-billboard and it flickers. Never a flame sheet. Crystal and campfire keep live meshes.
When a job Imagines, the User names the Imagine / isolated-media owner in that Build session's first message. Job files do not name that owner.
If the week slips: drop extra shader tints, then extra light discs. Do not drop ground, the light RT, or player squash.

Jobs after the reuse PR, one session each, forked from this door:

1. ground — shared shader, world-xz hash variants, RT sample (white until buffer)
2. volume — provided ribbon, span UV, wall samples RT
3. buffer — four-texel radiance buffer, disc blobs, fine occupancy
4. actor — RT tint at feet, two-foot-pinned squash (player current frame, others still; sun on hub, up to three local sources in dungeon)

Env fog and void ride the kit, not a fifth owner.

| Job | Open |
|-----|------|
| hearth-warm hole-cold Environment, abyss-plinth, caller redirect | `design/graphics-env.md` |
| hashed field albedo, shared spatial shader, turf quilts, carved planes | `design/graphics-ground.md` |
| exposed coplanar brick runs, BoxMesh retirement, BoxShape on welded mass, provided ribbon | `design/graphics-volume.md` |
| four-texel radiance buffer, disc blobs, fine occupancy | `design/graphics-buffer.md` |
| billboard-alpha squash quads, player yard-mannequin foes, source-offset | `design/graphics-actor.md` |
