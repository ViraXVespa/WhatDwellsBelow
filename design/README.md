# Design database

Status: index  
Read when: starting any session, or when you do not know which file to open  
See also: `AGENTS.md`, `design/protocol.md`, `design/web-session.md`, `design/grok-build.md`, `design/grok-bot-session.md`, `design/refactor.md`, `design/versioning.md`

This folder is the documentation database for humans and agents.  
It is not one Game Design Document.

`docs/` is the GitHub Pages web export. Never store design notes there. Player-facing changelog pages are built in CI to `/changelog/` on Pages from flat `design/changelog/*.md` plus `design/changelog/archive/*/*.md`, not stored in `docs/` on `main`. Prior series are parked under `design/changelog/archive/{epoch}.{series}/` via `tools/archive_prior_changelogs.py`.

`_logs/` holds local agent tool summaries (and optional Bot sweep notes). It is gitignored. Do not store design there and do not commit it. Catalog: `design/pc-offload.md`.

## How to use

1. Grok agents read `design/protocol.md` and `design/constraints.md` first. Grok Bot does not — after `AGENTS.md` it follows `design/grok-bot-session.md` only.
2. On a fresh Grok Build instance after a gap, follow `design/grok-build.md`: read `design/sessions.md` (leave-off), then every `design/changelog/{current epoch}.{current series}.*.md`, then inspect git / the live tree from the code map below. Do not pin unless the User said **new week**. Do not follow git commit links into web-session conversations. The User works between sessions.
3. Web / chat: after the repo-review message, follow `design/web-session.md`. `design/sessions.md` is context only. Do not read `design/session-log.md`. Do not read `design/changelog/` in Phase 1–3 unless the named work is versioning, a named past build, or a revert.
4. Grok Bot: follow `design/grok-bot-session.md`, `design/refactor.md`, and `design/doc-refactor.md`. For scripts, do not read unrelated topic files. For doc facades, open the topic door then only the named sibling. Do not read `design/sessions.md`, `design/session-log.md`, or older `design/changelog/` entries.
5. Open only the topic files that match the requested work.
6. Use `design/tunables.md` for numbers.
7. Use the code map below for live scripts. Do not walk `assets/` unless the task names sprites or audio.
8. After a behavior change, update the matching topic file in the same slice. End of a Grok Build session: update `design/sessions.md`, prepend `design/session-log.md`, and write the series-open changelog file when the User commits `0.N.0`. End of a web / chat goal: finish Phase 7 in `design/web-session.md`, including one `design/changelog/{label}.md` when the goal shipped a visible change. Grok Bot does not write those files; optional notes go in `_logs/grok-bot-sweep.md` only.

Sprite / I2V / paper-doll work starts at `design/art-pipeline.md`.

Design doors (open sibling only when the job matches): `design/art-pipeline.md`, `design/ui.md`, `design/debug.md`, `design/input.md`, `design/inventory.md`. Rules: `design/doc-refactor.md`. Inventory fat docs: `tools/list_oversize_docs.ps1`.
 Open only the sibling that file names for the job (`art-i2v.md`, `art-pack.md`, `art-review.md`). Prompts live in `tools/i2v_seeds.py`. Off-magenta plates go through `tools/plate_remap.py` before I2V. Walk packing is `tools/pack_locomotion.py`. One-shot packing is `tools/pack_oneshot.py`. I2V and complex animation packing stay in Grok Build sessions unless the User says otherwise. Animation Browser review briefs and the regen tree are `tools/anim_review_*.py`; output under `tools/anim_review/` is gitignored.

## Document kinds

| Marker | Meaning |
|--------|---------|
| Binding design | Required behavior unless the User overrides it |
| Live snapshot | What the current live path actually does |
| Protocol | How agents must work |

## Topic map

| When the work is about… | File | Old GDD home |
|-------------------------|------|----------------|
| Agent workflow | `protocol.md` | Front matter |
| Web / chat session flow | `web-session.md` | — |
| Grok Build session flow | `grok-build.md` | — |
| Grok Bot session flow | `grok-bot-session.md` | — |
| Refactor recipe | `refactor.md` | — |
| Grok Build leave-off | `sessions.md` | — |
| Grok Build session log | `session-log.md` | — |
| Version scheme, changelog, week pins | `versioning.md` | — |
| Must / must-not, checklist | `constraints.md` | Hard constraints, success, App. B |
| Vision, scope, lore | `overview.md` | §§1–3 |
| Gamepad, KB/M, web pad, web touch, menu binds | `input.md` | §4 input |
| Camera, renderer | `camera.md` | §4 camera / renderer |
| Avatar, move, facing | `player.md` | §5 |
| Weapons, dash, crits, adrenaline, hit coverage | `combat.md` | §6 |
| Eleven skills, XP, combat level | `skills.md` | §7 |
| Bag, gear, artifacts, extract, analyze / forge | `inventory.md` | §8 |
| Shared inventory / loadout / anvil board | `gear-ui.md` | §8 / §13 |
| Placeholdia | `hub.md` | §9 |
| Gen, floors, stream, doors, crystals | `dungeon.md` | §10 |
| Roster, AI, named, pressure | `enemies.md` | §11 |
| Mine, wood, shrine, puzzles, crystals | `interactables.md` | §12 |
| HUD, pause, recap, maps, UIs | `ui.md` | §13 player UI |
| Secret debug, playtest, anim browser | `debug.md` | §13 debug |
| Music, SFX, art rules, splash | `audio-visual.md` | §14, App. E |
| Save, web export, perf | `save-tech.md` | §15 |
| Time targets, polish, a11y | `feel.md` | §16 |
| Failure modes | `edge-cases.md` | §17 |
| Phase 1–9 checklist | `coverage.md` | §18 |
| Sprite / paper-doll door | `art-pipeline.md` | §19, App. C–D |
| I2V unit + seed + prompt | `art-i2v.md` | §19.2 |
| Harvest, pack, cleanup | `art-pack.md` | §19.4 |
| Animation Browser briefs | `art-review.md` | §19.6 |
| Pinned archive commits | `archives.md` | §20 |
| Suggested starts + live defaults | `tunables.md` | App. A + live `balance.gd` |
| Anvil leftovers for the next session | `handoff-anvil.md` | — |

Per-build player notes for the **current series** are flat `design/changelog/{label}.md`. Prior series live under `design/changelog/archive/{epoch}.{series}/`. They are not topic files. Do not open them unless `versioning.md` says to.

## House rules for editing these files

- Keep one concern per file.
- Put numbers in `tunables.md`, not buried in paragraphs.
- Mark live-only behavior under **Live snapshot**.
- Do not reintroduce a single 100KB GDD.
- When live scripts are split under the 10KB cap, update this code map in the same slice.

## Code map (live path)

Every live `scripts/**/*.gd` file must stay under **10KB** when it ships. Facades keep the original public path; helpers take `host` / `pt` / `ui` / `p`. Split mechanics: `design/refactor.md`. Web / chat applies the 10KB cap in Phase 6 of `design/web-session.md`, not while drafting. Grok Bot’s under-5KB sweep target is only in `design/grok-bot-session.md`.

| System | Live files |
|--------|------------|
| Autoload / flow | `scripts/app.gd` + `app_set.gd`, `app_flow.gd`, `app_run.gd`, `boot.gd`, `title.gd` + `title_news.gd`, `web_pad.gd` |
| Display | `scripts/display_mode.gd`, `scripts/ui/fs_gate.gd` |
| Scenes | `scenes/boot.tscn`, `fs_gate.tscn`, `splash.tscn`, `title.tscn`, `camp.tscn`, `dungeon.tscn`, `foundation.tscn` |
| Player | `scripts/world/player.gd` + `player_anim.gd`, `player_setup.gd`, `player_tick.gd`, `player_act.gd`, `player_lock.gd`, `player_combat.gd`, `facing.gd`, `camera_rig.gd`, `sprite_filter.gd` |
| Combat | `scripts/combat/combat.gd`, `cover.gd`, `player_hit.gd`, `enemy.gd` + `enemy_ready.gd`, `enemy_hit.gd`, `enemy_present.gd`, `enemy_ai.gd`, `enemy_atk.gd`, `enemy_setup.gd`, `projectile.gd`, `roster.gd`, `aim_line.gd`, `telegraph.gd`, `float_num.gd`, `hp_bar.gd`, `dummy.gd`, `threat.gd` |
| Skills / save | `scripts/data/progress.gd` + `progress_gear.gd`, `progress_gear_req.gd`, `progress_make.gd`, `progress_extract.gd`, `progress_quest.gd` + quest helpers, `progress_town.gd`, `progress_combat.gd`, `progress_forge.gd` + forge helpers, `affixes.gd`, `gear_roll.gd`, `gear_rules.gd`, `save_store.gd` + `save_store_io.gd` / collect / data, `catalog.gd` |
| Numbers | `scripts/data/balance.gd`, `balance_schema.gd`, `tunables.gd` |
| Version / changelog | `scripts/data/version.json`, `scripts/data/changelog.json`, `scripts/data/game_ver.gd`; `tools/build_changelog.py` |
| Web export | `tools/export_web.ps1`, `tools/web_postexport.py`; `.github/workflows/version.yml`, `.github/workflows/pages.yml` |
| Dungeon | `scripts/dungeon/gen.gd` + `gen_carve.gd`, `gen_rooms.gd`, `gen_doors.gd`; `scripts/world/dungeon.gd` + `dungeon_boot.gd`, `dungeon_geo.gd`, `dungeon_geo_stream.gd`, `dungeon_map_act.gd`, `dungeon_cells.gd`, `dungeon_stream.gd`, `dungeon_props.gd`, `dungeon_pack.gd`, `crystal_net.gd`, `floor_crystal.gd` |
| Hub | `scripts/world/camp.gd` + `camp_build.gd`, `camp_view.gd`; `interact.gd`, `interact_fx.gd`; `scripts/combat/dummy.gd` |
| Gather | `scripts/world/gather_node.gd`, `gather_rules.gd`, `breakable.gd`, `pickup.gd` |
| UI | `scripts/ui/hud.gd` + `hud_view.gd`, `hud_act.gd`; `touch_hud.gd`; `ui_text.gd`; `menu_pad.gd`; `step_row.gd`; `prompt_view.gd`; `confirm_dlg.gd`; `pause_menu.gd` + `pause_menu_view.gd`, `pause_menu_util.gd`, `pause_inv.gd`, `pause_skills.gd`, `pause_settings.gd`, `pause_settings_pages.gd`, `pause_system.gd`; `split_menu.gd` + `split_menu_view.gd`, `split_menu_chrome.gd`; `binds_page.gd`; `scripts/ui/gear_board/gear_board.gd` + helpers in `scripts/ui/gear_board/` (`gear_board_build.gd`, `gear_board_floor.gd`, `gear_board_tip.gd`, `gear_board_text.gd`, `gear_board_opts.gd`, `gear_board_text_fmt.gd`, `gear_board_stats.gd`, `gear_board_act.gd`, `gear_board_sub.gd`, `gear_board_host.gd`, `gear_board_anvil.gd`, `gear_board_anvil_view.gd`, `gear_board_anvil_forge.gd` + forge helpers), `gear_icons.gd`; `progress_ui.gd`, `progress_ui_hub.gd`, `progress_ui_inv.gd`, `progress_ui_shop.gd`, `crystal_ui.gd`; `recap.gd`, `recap_bars.gd`, `loader.gd`, `present.gd`, `theme.gd`, `splash.gd`, `fs_gate.gd` |
| Input | `scripts/input/binds.gd` + `binds_pool.gd`, `binds_defaults.gd`, `prompts.gd`; `pad.gd`, `touch_pad.gd`, `look_ctrl.gd`; `scripts/ui/binds_page.gd`, `prompt_view.gd`, `menu_pad.gd`; `scripts/web_pad.gd`; `scripts/display_mode.gd` |
| Debug | `scripts/debug/debug_menu/debug_menu.gd` + folder helpers (`debug_menu_input.gd`, `debug_menu_pages.gd`, `debug_menu_profile.gd`, `debug_menu_settings.gd`, `debug_menu_val.gd`, `debug_menu_val_grid.gd`, `debug_menu_val_page.gd`); `scripts/debug/playtest.gd` extends `playtest_api.gd` + `playtest_ai.gd`, `playtest_nav.gd`, `playtest_los.gd`, `playtest_path.gd`, `playtest_goals.gd`, `playtest_sim.gd`, `playtest_recs.gd`; `smoke.gd` + `smoke_early.gd`, `smoke_late.gd`, `smoke_p5.gd`, `smoke_p6.gd`, `smoke_p7.gd`, `smoke_p8.gd`, `smoke_p9.gd`, `smoke_p79.gd`; `anim_browser.gd` + `anim_browser_nav.gd`, `anim_browser_review.gd`, `anim_review.gd`, `anim_scan.gd`, `telemetry.gd` |
| Audio | `scripts/audio/music.gd`, `scripts/audio/sfx.gd` |
| Archives UI | `scripts/ui/archives_ui.gd` + `archives_ui_view.gd`, `archives_ui_act.gd`; `scripts/data/archives_catalog.gd`, `archives_launch.gd`, `archives_docs.gd`, `archive_catalog.json` |
| PC offload (Bot + Build) | `design/pc-offload.md`; `tools/list_oversize_scripts.ps1`, `summarize_scripts.ps1` / `.py`, `list_facade_cluster.ps1`, `check_script_cap.ps1`, `run_godot_import_check.ps1`, `run_smokes.ps1`, `lint_hostify.ps1` / `lint_hostify.py`, `run_post_split_gate.ps1`, `run_build_gate.ps1`, `clean_agent_logs.ps1` |
| Folder relocate | `tools/move_script_cluster.ps1` / `.py` (see `design/refactor.md` Parked folder moves) |
| Grok Bot PC tools | `tools/list_oversize_scripts.ps1`, `run_godot_import_check.ps1`, `run_smokes.ps1`, `lint_hostify.ps1` / `lint_hostify.py`, `run_post_split_gate.ps1` |
| Sprite tools | `tools/sprite_pipeline.py`, `tools/i2v_seeds.py`, `tools/plate_remap.py`, `tools/process_*.py`, `tools/process_world_pass.py`, `tools/pack_locomotion.py`, `tools/pack_oneshot.py`, `tools/pack_*.py`, `tools/anim_review_lib.py`, `tools/anim_review_pack.py`, `tools/anim_review_regen.py`, `tools/anim_review_tree.py` |

Public entry points that must not change when a helper is split: `App.playtest`, `App.set_zoom` / `App.set_hud_scale` / `App.set_volume`, `PauseInv.*`, `Gen.generate` / `Gen.make_opening`, `EnemyAI.tick`, `SmokeLate.p5`–`p9`, `ProgressGear.make_*`.

Live `player_anim.gd` still plays baked per-weapon sheets and has no `idle_to_walk` / `walk_to_idle` clips. Binding is `design/player.md` + `design/art-pipeline.md`.
