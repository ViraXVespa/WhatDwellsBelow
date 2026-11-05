# Wall merge with smooth edges + physics and occlusion correctness

id: wall-merge-physics
owner: build
status: open
done-when: wall ribbons and floor lips are merged per chunk with natural continuous edges (no strange caps); missing-wall map exits are eliminated; enemies no longer snag on edges; light and shadow marks are occluded by walls rather than by black ground regions; User confirms look and behavior; gates pass
resume: python tools/slice.py open dungeon --task wall-merge-physics

## Background
Dungeon geometry streaming (`scripts/world/dungeon_geo/geo_stream.gd` + `stream_emit.gd`):
- Floors: already one MultiMeshInstance3D per chunk (good).
- Walls: one MeshInstance3D per ribbon (`_ensure_wall_mesh`).
- Floor lips: one MeshInstance3D per clipped polygon piece.
- Collision: separate ribbon-box StaticBody3D + BoxShape3D, not attached to the visual wall meshes.
- Light occlusion: `light_stamp` uses a solid mask derived from gen solid cells, not from the final wall geometry.

Known problems:
- Existing merging leaves strange caps that look gross.
- Rare dungeons generate with walls missing, letting the player walk out of the playable area and causing follow-on bugs.
- Enemies snag on edges while pathing to the player.
- Light appears occluded by black areas of the ground instead of by the walls themselves.
- Shadow marks appear around corners that should be fully occluded.

These are consistent with walls not being first-class physics and occlusion objects. The greedy merge in `wall_rects.gd` and the face-emission rules (faces only where a wall cell has a floor neighbor) are likely contributors to gaps.

## Required outcome
- Merge wall ribbons and floor lips into one mesh or MultiMesh per chunk.
- Joins must be natural and smooth; no strange caps or obvious seams.
- Walls (or a tightly coupled solid representation) must act as proper physics bodies so:
  - there are no missing-wall exits,
  - pathing does not snag on edges,
  - the solid mask / light stamp occludes on the actual walls,
  - shadow marks respect real corners.
- Generation must be robust against the current gap cases.

## Acceptance
- Multiple generated dungeons show continuous walls, no escape holes, clean light occlusion, and no edge-snagging.
- User confirms both the visual merge quality and the gameplay fixes.
