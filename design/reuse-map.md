# Staged Bot reuse brief

Status: protocol
Read when: web / chat Phase 7 is writing this brief, or Grok Bot Job table -> design/grok-bot-reuse.md and this body is not the empty template

This file is a User-authored staging brief for the next Grok Bot reuse work. It is not an owners encyclopedia, not a standing BOT list, and not default Bot context.

Web / chat writes or replaces the whole file in Phase 7. Grok Bot implements this entire Brief on the current open Bot PR (design/grok-bot-reuse.md), including every cluster named under Brief. Do not take a subset. Do not open a second PR only because a later heading exists. Bot does not mark rows done and does not invent rows. After the User merges that PR, the next web session clears or replaces this file.

## How to fill (web / chat)

Replace Brief with the full mandate. Multiple clusters in one body still ride the current open Bot PR. Leave Brief empty when nothing is staged.

## How to run (Grok Bot)

If Brief is empty, stop and report empty. Do not start a size sweep. If Brief has any content, implement all of it on the current open Bot PR (create that PR if none exists).

## Brief
1. Add `WallRects.faces(grid: PackedByteArray, w: int, h: int, cells: Array[Vector2i]) -> Array[Dictionary]` on `scripts/world/wall_rects.gd`. Each dictionary is `{ "origin": Vector2i, "size": Vector2i, "normal": Vector2i }` in tile cells. `normal` is one of `(1,0), (-1,0), (0,1), (0,-1)`.
2. A face exists only when the neighbor cell across that normal is `Gen.FLOOR` (same index math as `dungeon_geo_stream.wall_faces_floor`). Out of bounds is not a face.
3. Greedy-merge collinear faces that share a normal. Seed order follows `cells`. Same used-mark style as `merge`. Empty cells returns an empty array.
4. Do not create meshes, materials, torches, or lights. Do not change `add_collision` or `merge`. BoxMesh walls stay until the volume job. No new numbers.
5. Leave the Dungeon code-map row naming `wall_rects.gd`. Same look.