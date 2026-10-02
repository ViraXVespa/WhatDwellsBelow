# Staged Bot reuse brief

Status: protocol
Read when: web / chat is staging this brief, or Grok Bot Job table -> design/grok-bot-reuse.md and this body is not the empty template

This file is a User-authored staging brief for the next Grok Bot reuse work. It is not an owners encyclopedia, not a standing BOT list, and not default Bot context.

Web / chat writes or replaces the whole file in a Phase 4 emit. Grok Bot implements this entire Brief on the current open Bot PR (design/grok-bot-reuse.md), including every cluster named under Brief. Do not take a subset. Do not open a second PR only because a later heading exists. Bot does not invent rows and adds no Ready / Done columns; it clears the completed Brief items from this file on the same PR.

## How to fill (web / chat)

Replace Brief with the full mandate. Multiple clusters in one body still ride the current open Bot PR. Leave Brief empty when nothing is staged.

## How to run (Grok Bot)

If Brief is empty, stop and report empty. Do not start a size sweep. If Brief has any content, implement all of it on the current open Bot PR (create that PR if none exists).

## Brief

Open reuse findings (`python3 tools/list_dupes.py --lang all`; regenerate the ranked list with `--md PATH`). Shared homes already in the tree: `ScrollBox` (pause/recap scroll + tip), `Balance.f` and `App.gear` readers, `Pick.nearest` (playtest goals), `mesh_commit.gd`, `ThemeS.fill`, `UiSession.status`, `Prompts.verb_lines`, `split_menu_view._ring`, `chrome._pane`, `GroundShader.TAP_BODY` / `TAP_MIX`, `gen._result`; tools: `sprite_lib` (chroma, flood, pockets, fit), `repo_lib.under` / `write_text_nl`, `anim_review_lib.brief_args`, `audio_lib._write`, `load_routes._str_lists`. Hot paths (gen, shaders, pixel loops, tool output) need a golden compare before and after (`design/grok-bot-reuse.md`). The rest needs a design call, a web run, or touches a hot pixel loop, so Bot does not take it without a User go:

| Rank | Where (copies) | Shape | Why left |
|---|---|---|---|
| B11 | `display_mode/mode_desk.gd` JS wrappers | 2-3 near-identical JS eval strings | web-only; needs a browser export run to prove |
| B12 | `fs_gate` string tables | tiny table twins | below the line-count bar |
| B13 | gear slot buttons, icons, tips, focus closures | UI behavior closures | pad/touch focus behavior; needs a hands-on pass |
| B14 | stream span headers | 7-line header twins | hot geo-stream path |
| B15 | `hub_cast`, `hub_shadow`, `stamp_grid`, `crystal_place`, `geo_stream` loop twins | per-pixel / per-cell loops | perf-critical; gain is a few lines |
| B16 | shop, `gear_bag`, `forge_act`, `ui_flow`, `sim` preludes | 7-10 line setup twins | each reads differently; unify only with a Bot-level UI call |
| B17 | camp `mesh_mat` wrappers | 3 thin wrappers | one-liners that name intent |
| B18 | `val_sb` / `val_spin_sb` | StyleBox builders | different palettes; shared builder would need a palette arg |
| B22 | `cover` geom twins | combat hit path | needs a combat feel pass |
| C5 | `run_bake_camp`, `run_dungeon_map`, `run_godot_import_check`, `export_web`, `run_build_gate`, `run_post_split_gate` Godot-run heads | 8-12 line argument/launch twins | each prints its own `RESULT` line; fold into `godot_lib` only with a runner-wide pass |
| C7 | `i2v_seeds` prompt text, `web_postexport`, other in-file twins | text/data twins | prompt data; not code |
| C-key | `pack_*` / `process_*` per-pixel `key()` loops | key rules differ per asset class | merging changes art output |
