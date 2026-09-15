# Live code map

Status: index  
Read when: you need a live script, scene, or tool path for a named system  
See also: `design/README.md`

This file is the live-path map. It is not a boot file and not a topic index.

Open **only the matching system row**. Do not read the rest of the table “for context.” Do not open `design/README.md` from here unless you need a topic-index row. Do not walk `assets/` unless the task names sprites or audio.

Topic index: `design/README.md`. Split recipe: `design/refactor.md`. Cap timing: `AGENTS.md`. Numbers: `design/tunables.md`.

When live scripts are split under the 10KB cap, update **this** file in the same slice. Do not treat `design/reuse-map.md` as an owners encyclopedia.

Every live `scripts/**/*.gd` file must stay under **10KB** when it ships. Facades keep the original public path; helpers take `host` / `pt` / `ui` / `p`.

| System | Live files |
|--------|------------|
| Autoload / flow | `scripts/app.gd` + `app_set.gd`, `app_flow.gd`, `app_run.gd`, `boot.gd`, `title.gd` + `title_news.gd`, `web_pad.gd` |
| Display | `scripts/display_mode.gd`, `scripts/ui/fs_gate.gd` |
| Scenes | `scenes/boot.tscn`, `fs_gate.tscn`, `splash.tscn`, `title.tscn`, `camp.tscn`, `dungeon.tscn`, `foundation.tscn` |
| Player | `scripts/world/player.gd` + `player_anim.gd`, `player_anim_load.gd`, `player_anim_loco.gd`, `player_setup.gd`, `player_tick.gd`, `player_act.gd`, `player_lock.gd`, `player_combat.gd`, `facing.gd`, `camera_rig.gd`, `sprite_filter.gd` |
| Combat | `scripts/combat/combat.gd`, `cover.gd`, `player_hit.gd`, `enemy.gd` + `enemy_ready.gd`, `enemy_hit.gd`, `enemy_present.gd`, `enemy_ai.gd`, `enemy_atk.gd`, `enemy_setup.gd`, `projectile.gd`, `roster.gd`, `aim_line.gd`, `telegraph.gd`, `float_num.gd`, `hp_bar.gd`, `dummy.gd`, `threat.gd` |
| Skills / save | `scripts/data/progress.gd` + `progress_gear.gd`, `progress_gear_req.gd`, `progress_make.gd`, `progress_extract.gd`, `progress_quest.gd` + quest helpers, `progress_town.gd`, `progress_combat.gd`, `progress_forge.gd` + forge helpers, `affixes.gd`, `gear_roll.gd`, `gear_rules.gd`, `save_store.gd` + `save_store_io.gd` / collect / data, `catalog.gd` |
| Numbers | `scripts/data/balance.gd`, `balance_schema.gd`, `tunables.gd` |
| Version / changelog | `scripts/data/version.json`, `scripts/data/changelog.json`, `scripts/data/game_ver.gd`; `tools/build_changelog.py` |
| Web export | `tools/web_shell.html`, `tools/export_web.ps1`, `tools/enable_texture_mips.py`, `tools/web_postexport.py`; `export_presets.cfg`; `.github/workflows/version.yml`, `.github/workflows/pages.yml` |
| Dungeon | `scripts/dungeon/gen.gd` + `gen_carve.gd`, `gen_rooms.gd`, `gen_doors.gd`; `scripts/world/dungeon.gd` + `dungeon_boot.gd`, `dungeon_geo.gd`, `dungeon_geo_stream.gd`, `dungeon_map_act.gd`, `dungeon_cells.gd`, `dungeon_stream.gd`, `dungeon_props.gd`, `dungeon_pack.gd`, `crystal_net.gd`, `floor_crystal.gd` |
| Hub | `scripts/world/camp.gd` + `camp_warm.gd`, `camp_build.gd`, `camp_view.gd`; `interact.gd`, `interact_fx.gd`; `scripts/combat/dummy.gd` |
| Gather | `scripts/world/gather_node.gd`, `gather_rules.gd`, `breakable.gd`, `pickup.gd` |
| UI | `scripts/ui/hud.gd` + `hud_view.gd`, `hud_act.gd`; `touch_hud.gd`; `ui_text.gd`; `menu_pad.gd`; `step_row.gd`; `prompt_view.gd`; `confirm_dlg.gd`; `pause_menu.gd` + `pause_menu_view.gd`, `pause_menu_util.gd`, `pause_inv.gd`, `pause_skills.gd`, `pause_settings.gd`, `pause_settings_pages.gd`, `pause_system.gd`; `split_menu.gd` + `split_menu_view.gd`, `split_menu_chrome.gd`; `binds_page.gd`; `scripts/ui/gear_board/gear_board.gd` + helpers in `scripts/ui/gear_board/` (`gear_board_build.gd`, `gear_board_floor.gd`, `gear_board_tip.gd`, `gear_board_text.gd`, `gear_board_opts.gd`, `gear_board_text_fmt.gd`, `gear_board_stats.gd`, `gear_board_act.gd`, `gear_board_sub.gd`, `gear_board_host.gd`, `gear_board_anvil.gd`, `gear_board_anvil_view.gd`, `gear_board_anvil_forge.gd` + forge helpers), `gear_icons.gd`; `progress_ui.gd`, `progress_ui_hub.gd`, `progress_ui_inv.gd`, `progress_ui_shop.gd`; `crystal_ui.gd`; `recap.gd`, `recap_bars.gd`, `loader.gd`, `present.gd`, `theme.gd`, `splash.gd`, `fs_gate.gd` |
| Input | `scripts/input/binds.gd` + `binds_pool.gd`, `binds_defaults.gd`, `prompts.gd`; `pad.gd`, `touch_pad.gd`, `look_ctrl.gd`; `scripts/ui/binds_page.gd`, `prompt_view.gd`, `menu_pad.gd`; `scripts/web_pad.gd`; `scripts/display_mode.gd` |
| Debug | `scripts/debug/debug_menu/debug_menu.gd` + folder helpers (`debug_menu_input.gd`, `debug_menu_pages.gd`, `debug_menu_profile.gd`, `debug_menu_settings.gd`, `debug_menu_val.gd`, `debug_menu_val_grid.gd`, `debug_menu_val_page.gd`); `scripts/debug/playtest.gd` extends `playtest_api.gd` + `playtest_ai.gd`, `playtest_nav.gd`, `playtest_los.gd`, `playtest_path.gd`, `playtest_goals.gd`, `playtest_sim.gd`, `playtest_recs.gd`; `smoke.gd` + `smoke_early.gd`, `smoke_late.gd`, `smoke_p5.gd`, `smoke_p6.gd`, `smoke_p7.gd`, `smoke_p8.gd`, `smoke_p9.gd`, `smoke_p79.gd`; `anim_browser.gd` + `anim_browser_nav.gd`, `anim_browser_review.gd`, `anim_review.gd`, `anim_scan.gd`, `telemetry.gd` |
| Audio | `scripts/audio/music.gd`, `scripts/audio/sfx.gd` |
| Archives UI | `scripts/ui/archives_ui.gd` + `archives_ui_view.gd`, `archives_ui_act.gd`; `scripts/data/archives_catalog.gd`, `archives_launch.gd`, `archives_docs.gd`, `archive_catalog.json` |
| Plate chrome tokens | `scripts/ui/plate_chrome.gd` |
| Tip place geometry | `scripts/ui/tip_place.gd` |
| Y-billboard Sprite3D | `scripts/world/billboard_spr.gd` |
| Staged Bot reuse brief | `design/reuse-map.md` |
| Isolated media (CLI) | `design/isolated-media.md`; `tools/run_isolated_grok.py`; `.grok/skills/imagine-isolated/SKILL.md`, `.grok/skills/i2v-isolated/SKILL.md` |
| PC offload (Bot + Build) | `design/pc-offload.md`; `tools/list_oversize_scripts.ps1`, `summarize_scripts.ps1` / `.py`, `list_facade_cluster.ps1`, `check_script_cap.ps1`, `run_godot_import_check.ps1`, `run_smokes.ps1`, `lint_hostify.ps1` / `lint_hostify.py`, `run_post_split_gate.ps1`, `run_build_gate.ps1`, `clean_agent_logs.ps1` |
| Folder relocate | `tools/move_script_cluster.ps1` / `.py` (see `design/refactor.md` Parked folder moves; Bot flow `design/grok-bot-relocate.md`) |
| Grok Bot PC tools | `tools/list_oversize_scripts.ps1`, `run_godot_import_check.ps1`, `run_smokes.ps1`, `lint_hostify.ps1` / `lint_hostify.py`, `run_post_split_gate.ps1` |
| Sprite tools | `tools/enable_texture_mips.py`, `tools/sprite_pipeline.py`, `tools/i2v_seeds.py`, `tools/run_isolated_grok.py`, `tools/attack_keyframes.py`, `tools/plate_remap.py`, `tools/process_*.py`, `tools/process_world_pass.py`, `tools/pack_locomotion.py`, `tools/pack_oneshot.py`, `tools/pack_*.py`, `tools/anim_review_lib.py`, `tools/anim_review_pack.py`, `tools/anim_review_regen.py`, `tools/anim_review_tree.py` |

Public entry points that must not change when a helper is split: `App.playtest`, `App.set_zoom` / `App.set_hud_scale` / `App.set_volume`, `PauseInv.*`, `Gen.generate` / `Gen.make_opening`, `EnemyAI.tick`, `SmokeLate.p5`–`p9`, `ProgressGear.make_*`.

Live `player_anim.gd` plays unarmed idle stills plus `idle_to_walk` / looping `walk` / `walk_to_idle` from the locked Bible harvest. Binding is `design/player.md` + `design/art-pipeline.md`. Title → Play warms those loco frames and frames the full yard under the solid loader (`design/hub.md`).
