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

One reuse PR. Same look. No new numbers. No light RT. No greedy wall visuals. No sprite shadows. No new game systems beyond moving code into `scripts/graphics/`.

Create `scripts/graphics/` if missing. Update the Graphics row in `design/code-map.md` to the public paths you add.

Clusters:

1. Env kit. Extract the WorldEnvironment plus DirectionalLight3D blocks from `scripts/world/camp_build.gd` (`world`), `scripts/world/dungeon_geo.gd` (`world`), and `scripts/world/foundation.gd` into one helper under `scripts/graphics/`. Keep every existing color and energy literal. `shadow_enabled` stays false. Point all three callers at the helper.

2. Nearest-mat helper. Extract `make_mat` in `scripts/world/dungeon_geo.gd` and the StandardMaterial3D setup in `scripts/world/camp_build_mesh.gd` `tile_layer` and `grass_pad` into one helper under `scripts/graphics/`. Same nearest filter and unshaded flag. Callers keep current textures and fallback colors.

3. Minimap out of `dungeon_geo.gd`. Move `make_map`, `redraw_map`, `reveal_around`, `paint_cell`, `cell_color`, `_map_input`, and `dot` (whatever that file uses for the 2D map / fog-of-war atlas) to an existing live map module or a new facade next to `dungeon_map_act.gd`. `dungeon.gd` / `dungeon_boot.gd` keep the same public calls. Do not change reveal rules.

4. Shared emit. Extract `make_mm` from `scripts/world/dungeon_geo_stream.gd`. If `mm_planes` and `mm_boxes` in `scripts/world/dungeon_geo.gd` have no live callers besides the stream path, delete them or point them at the helper. Do not change CHUNK / RING / PER_FRAME or collision merge.

5. Wrap shader. Move `wrap_shader` (and the cached shader) out of `scripts/world/camp_build_mesh.gd` into `scripts/graphics/`. Roof / awning / tarp callers keep the same parameters.

Do not start a size sweep. If a touched file goes over 10KB, leave it for the later size job. Prove per BOT.md.
