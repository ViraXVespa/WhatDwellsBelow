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

Extract the greedy wall-rectangle merge from `scripts/world/dungeon_geo_stream.gd` (`add_collision`) into `scripts/world/wall_rects.gd`.

Public API: `WallRects.merge(walls: Array[Vector2i]) -> Array[Rect2i]`. Each rect is tile cells `(x, y, w, h)` using the live scan: grow +x from the seed cell, then +y while every cell on that next row is in the unused set. Empty input returns an empty array.

`add_collision` still creates the `StaticBody3D`, `BoxShape3D`s, collision layer `1` / mask `0`, and world positions with `T.WALL_H`. It only calls `merge` for the rectangles. Collision look and behavior stay identical.

Do not change BoxMesh wall visuals, floor MultiMesh, stream rings, `CHUNK`, `wall_faces_floor`, occupancy, torches, shaders, the light RT, or squash. No new numbers. No second cluster.

Add `scripts/world/wall_rects.gd` to the Dungeon row in `design/code-map.md`. Same look.
