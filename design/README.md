# Design database

Status: index  
Read when: starting any session, or when you do not know which file to open  
See also: `AGENTS.md`, `design/protocol.md`

This folder is the documentation database for humans and agents.  
It is not one Game Design Document.

`docs/` is the GitHub Pages web export. Never store design notes there.

## How to use

1. Agents read `design/protocol.md` and `design/constraints.md` first.  
2. Open only the topic files that match the requested work.  
3. Use `design/tunables.md` for numbers.  
4. Use the code map below for live scripts.  
5. After a behavior change, update the matching topic file in the same slice.

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
| Must / must-not, checklist | `constraints.md` | Hard constraints, success, App. B |
| Vision, scope, lore | `overview.md` | §§1–3 |
| Gamepad, KB/M, web pad | `input.md` | §4 input |
| Camera, renderer | `camera.md` | §4 camera / renderer |
| Avatar, move, facing | `player.md` | §5 |
| Weapons, dash, crits, adrenaline | `combat.md` | §6 |
| Eleven skills, XP, combat level | `skills.md` | §7 |
| Bag, gear, artifacts, extract | `inventory.md` | §8 |
| Shared inventory / loadout board | `gear-ui.md` | §8 / §13 |
| Placeholdia | `hub.md` | §9 |
| Gen, floors, stream, doors | `dungeon.md` | §10 |
| Roster, AI, named, pressure | `enemies.md` | §11 |
| Mine, wood, shrine, puzzles | `interactables.md` | §12 |
| HUD, pause, recap, maps, UIs | `ui.md` | §13 player UI |
| Secret debug, playtest, anim browser | `debug.md` | §13 debug |
| Music, SFX, art rules, splash | `audio-visual.md` | §14, App. E |
| Save, web export, perf | `save-tech.md` | §15 |
| Time targets, polish, a11y | `feel.md` | §16 |
| Failure modes | `edge-cases.md` | §17 |
| Phase 1–9 checklist | `coverage.md` | §18 |
| Sprite / paper-doll pipeline | `art-pipeline.md` | §19, App. C–D |
| Frozen archives | `archives.md` | §20 |
| Suggested starts + live defaults | `tunables.md` | App. A + live `balance.gd` |

## Code map (live path)

Every live `scripts/**/*.gd` file must stay under **10KB**. Facades keep the original public path; helpers take `host` / `pt` / `ui` / `p`. See `AGENTS.md` → Script size cap.

| System | Live files |
|--------|------------|
| Autoload / flow | `scripts/app.gd`, `app_flow.gd`, `app_run.gd`, `boot.gd`, `title.gd`, `web_pad.gd` |
| Scenes | `scenes/boot.tscn`, `splash.tscn`, `title.tscn`, `camp.tscn`, `dungeon.tscn`, `foundation.tscn` |
| Player | `scripts/world/player.gd` + `player_anim.gd`, `player_act.gd`, `player_lock.gd`, `player_combat.gd`, `facing.gd`, `camera_rig.gd` |
| Combat | `scripts/combat/combat.gd`, `enemy.gd`, `enemy_ai.gd`, `enemy_atk.gd`, `enemy_setup.gd`, `projectile.gd`, `roster.gd`, `aim_line.gd`, `telegraph.gd`, `player_hit.gd`, `threat.gd` |
| Skills / save | `scripts/data/progress.gd` + `progress_gear.gd`, `progress_make.gd`, `progress_extract.gd`, `progress_quest.gd`, `progress_town.gd`, `progress_combat.gd`, `gear_rules.gd`, `save_store.gd`, `catalog.gd` |
| Numbers | `scripts/data/balance.gd`, `balance_schema.gd`, `tunables.gd` |
| Dungeon | `scripts/dungeon/gen.gd` + `gen_carve.gd`, `gen_rooms.gd`, `gen_doors.gd`; `scripts/world/dungeon.gd` + `dungeon_boot.gd`, `dungeon_geo.gd`, `dungeon_cells.gd`, `dungeon_stream.gd`, `dungeon_props.gd`, `dungeon_pack.gd` |
| Hub | `scripts/world/camp.gd`, `interact.gd`, `interact_fx.gd` |
| Gather | `scripts/world/gather_node.gd`, `breakable.gd`, `pickup.gd` |
| UI | `scripts/ui/hud.gd`; `pause_menu.gd` + `pause_inv.gd`, `pause_skills.gd`, `pause_system.gd`; `gear_board.gd` + `gear_board_floor.gd`, `gear_board_tip.gd`, `gear_board_text.gd`, `gear_board_stats.gd`, `gear_board_act.gd`, `gear_board_sub.gd`, `gear_board_anvil.gd`; `progress_ui.gd`, `progress_ui_hub.gd`, `progress_ui_inv.gd`, `progress_ui_shop.gd`; `recap.gd`, `recap_bars.gd`, `loader.gd`, `present.gd`, `theme.gd` |
| Input | `scripts/input/binds.gd`, `pad.gd`, `scripts/web_pad.gd` |
| Debug | `scripts/combat/debug_menu.gd`; `scripts/debug/playtest.gd` extends `playtest_api.gd` + `playtest_ai.gd`, `playtest_nav.gd`, `playtest_los.gd`, `playtest_path.gd`, `playtest_goals.gd`, `playtest_sim.gd`, `playtest_recs.gd`; `smoke.gd` + `smoke_early.gd`, `smoke_late.gd`, `smoke_p5.gd`, `smoke_p6.gd`, `smoke_p7.gd`, `smoke_p8.gd`, `smoke_p9.gd`, `smoke_p79.gd`; `anim_browser.gd`, `telemetry.gd` |
| Audio | `scripts/audio/music.gd`, `scripts/combat/sfx.gd` |
| Archives UI | `scripts/ui/archives_ui.gd`, `scripts/ui/present.gd` |

Public entry points that must not change when a helper is split: `App.playtest`, `PauseInv.*`, `Gen.generate` / `Gen.make_opening`, `EnemyAI.tick`, `SmokeLate.p5`–`p9`, `ProgressGear.make_*`.

## House rules for editing these files

- Keep one concern per file.  
- Put numbers in `tunables.md`, not buried in paragraphs.  
- Mark live-only behavior under **Live snapshot**.  
- Do not reintroduce a single 100KB GDD.  
- When live scripts are split under the 10KB cap, update this code map in the same slice.