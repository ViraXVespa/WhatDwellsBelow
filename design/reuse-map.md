# Staged Bot reuse brief

Status: protocol
Read when: web / chat Phase 7 is writing this brief, or Grok Bot Job table -> design/grok-bot-reuse.md and this body is not the empty template

This file is a User-authored staging brief for the next Grok Bot reuse work. It is not an owners encyclopedia, not a standing BOT list, and not default Bot context.

Web / chat writes or replaces the whole file in Phase 7. Grok Bot implements this entire Brief on the current open Bot PR (design/grok-bot-reuse.md), including every cluster named under Brief. Do not take a subset. Do not open a second PR only because a later heading exists. Bot does not invent rows and adds no Ready / Done columns; it clears the completed Brief items from this file on the same PR.

## How to fill (web / chat)

Replace Brief with the full mandate. Multiple clusters in one body still ride the current open Bot PR. Leave Brief empty when nothing is staged.

## How to run (Grok Bot)

If Brief is empty, stop and report empty. Do not start a size sweep. If Brief has any content, implement all of it on the current open Bot PR (create that PR if none exists).

## Brief

Open reuse findings from the 2026-10-02 sweep (`python3 tools/list_dupes.py --lang all`; regenerate the ranked list with `--md PATH`). Done in that PR and cleared from here: profile page triple, dead `think.gd`, `step_row` focus twins, `CliArgs`, `_albedo`, web pad JS probe, JSON payload read, touch reset, wipe loop, double bake pass, torch room stamp, recap lock-in, store prefs, clerk cargo. Remaining items need a design call or touch a hot path, so Bot does not take them without a User go:

| Rank | Where (copies) | Shape | Home |
|---|---|---|---|
| B1 | `dungeon/gen.gd` x2, `gen/rooms.gd` | result Dictionary literal x19 lines | Gen result builder (map-dump golden compare) |
| B2 | `playtest_goals/goals_best.gd`, `goals_near.gd`, `playtest_ai/util_move.gd` (5) | nearest-by-dist loop | `Util.nearest(pt, p, nodes, pred)` |
| B3 | `pause_menu_view.gd`, `recap_ui.gd` | scroll + box + `make_tip` | ScrollBox helper (copies differ: look change) |
| B4 | `ground_shader.gd`, `wall_shader.gd` | GLSL light tap | shared GLSL const (shot compare) |
| B5 | `split_menu_view.wire_vert/wire_horiz` | focus ring wiring | `_wire(btns, a, b)` |
| B6 | `split_menu/chrome.gd` (2 pairs) | scroll pane build | local `_pane()` |
| B7 | `anvil.hint_line`, `board_text.hint_line` | verb_line join | `Prompts.verb_lines(parts)` |
| B8 | `archives_ui`, `pause_menu`, `progress_ui` `_st` | status + sfx | `UiSession.status` |
| B9 | `fs_gate`/`splash` `_fill` + 26 full-rect sites | anchors | `ThemeS.fill` |
| B10 | `_gear` x2, `_bal` x2, `_num` x2 | App-bound readers | App/Balance API (tunables-adjacent) |
| B11-B22 | `mode_desk.gd` JS wrappers, `fs_gate` string tables, gear slot buttons and tips, stream span headers, in-file loop twins (carve_near, spans, stamp_grid, crystal_place, geo_stream, hub_cast/hub_shadow), shop/gear_bag/forge_act/ui_flow/sim preludes, camp wrap_mat wrappers, `val_sb`, wall_mesh/stream_emit ArrayMesh, cover geom | in-file or same-folder twins, 7-14 lines each | local helpers |
| B23 | `graphics/nearest_mat.gd` | unreferenced helper that docs call live | decide: use or delete |
| C1-C10 | `tools/*.py`: plate_remap/sprite_pipeline, pack_*/process_* art loops, anim_review_*, run_*_load_timing, godot runner heads, load_routes sections, in-file twins, tiny helpers | 5-20 line twins; art pipelines cannot run on the Bot box | `sprite_lib.py`, `anim_review_lib.py`, `godot_lib.py`, `repo_lib.py` |
