# Event-driven minimap with fog reveal mask and separate layers

id: map-rework
owner: build
status: open
done-when: the minimap base is built once when dungeon generation finishes; fog is a reveal mask; the base is redrawn only when newly revealed cells actually change it; crystals and the player marker are separate event-driven layers; no per-frame map painting remains; User confirms; gates pass
resume: python tools/slice.py open dungeon --task map-rework

## Background
`scripts/world/dungeon/minimap.gd` keeps a single Image. Unvisited cells are painted dark; visited cells are painted with floor/wall colors via `set_pixel`. Fog is not a separate layer—it is the pixel color. Redraws happen whenever `fog_dirty` is set or the map layer is visible, including on player movement.

This is pure CPU image work and produces hitches.

## Required outcome
- Build the base map image (or equivalent) once when dungeon generation completes.
- Represent fog as a lightweight reveal mask (shader or second texture) so revealing cells does not require repainting the base.
- Redraw or update the base only if the set of revealed cells has actually changed the underlying data.
- Crystals (active/inactive) and the player position marker live on separate layers or overlays and are updated by events (crystal state change, player cell change), not by a process loop.
- Remove the map work from `process_floor` except for any truly unavoidable one-shot.

## Acceptance
- Map looks correct, fog reveal feels the same or better, no per-frame `set_pixel` cost.
- User confirms visuals and responsiveness.
