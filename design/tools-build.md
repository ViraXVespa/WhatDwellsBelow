# Tools catalog: Windows, release, session tools

Status: binding  
Read when: running a `.ps1` runner, a Pages/release tool, or a session report (User PC / Build only)  

Rules, the CLI contract and the surface key are in `tools.md` (single copy). The Bot does not use this file. Runner habits (Length, Godot flags, here-strings): `pc-offload.md`. Summary paths are `_logs/<job>/summary.txt`; `read_summary.py --job <name>` reads one.

### Runners and Windows tools (Python; `python3 tools/X.py`)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `godot_lib.py` | Godot launch + per-path lock library (kills only its own pid, never godot*). `gui=True` runs pick a display (`$DISPLAY`, a live X socket, else `xvfb-run`). CLI: lock probe, `--display` shows the pick. | BD | module docstring (no `--help`) | Y |
| `run_godot_import_check.py` | Editor import / script-reload check. RESULT `clean=true|false`. Summary: `godot-import-check`. | WD | `python3 tools/run_godot_import_check.py` | N |
| `run_post_split_gate.py` | Import check, then optional smokes. Summary: `post-split-gate`. | D | `python3 tools/run_post_split_gate.py` (`--with-smokes`, `--phases 1,2,6`, `--force`) | N |
| `run_smokes.py` | Phase smokes on the PC (Bot VM: `bot_smokes.py`). `--door D` / `--job door.job` pick the phases mapped in `routes.yaml` `smokes`. Prints `check_shot_gaps.py --changed --advisory` (never fails Build; `--no-gaps` skips). Summary: `smokes`. | D | `python3 tools/run_smokes.py --phases 4,5` | N |
| `run_load_timing.py` | Title -> Placeholdia load-timing smoke. Summary: `load-timing`. | WD | `python3 tools/run_load_timing.py` (`--timeout-sec 180`) | N |
| `run_dungeon_load_timing.py` | Placeholdia -> Dungeon load-timing smoke. Summary: `dungeon-load-timing`. | WD | `python3 tools/run_dungeon_load_timing.py` | N |
| `run_dungeon_map.py` | Dungeon generation map smoke. Summary: `dungeon-map`. | WD | `python3 tools/run_dungeon_map.py` (`--seed 42 --floor 1 --scale 8`) | N |
| `run_dungeon_map_sweep.py` | Map smoke over seeds. Summary: `dungeon-map-sweep`. | D | `python3 tools/run_dungeon_map_sweep.py` (`--count 10` or `--seed-list 42,7`) | N |
| `run_bake_camp.py` | Bake `hub_light.png` through `--wdb-bake-camp` on a real renderer (auto display; `--headless` forces the headless driver, same atlas; `shadow_px=0` FAILs). Never rewrites `camp.tscn`. RESULT `clean=`, `shadow_px=`, `display=`. Summary: `bake-camp`. | BD | `--help` | Y |
| `export_web.py` | Export the GitHub Pages build (Godot Web, no threads); `--archives` adds the combined `_pages/` site. Logs: `_logs/export-web/`. | D | `python3 tools/export_web.py` (`--archives`) | N |
| `run_agent_py.py` | Run an ephemeral script from `_logs/agent-py/` and delete it after. Prefer a real tool. Summary: `agent-py`. | D | `python3 tools/run_agent_py.py --script _logs/agent-py/foo.py` | N |
| `clean_agent_logs.py` | Delete raw logs under `_logs/` (`--new-week` also old summaries). Summary: `clean`. | D | `python3 tools/clean_agent_logs.py` (`--keep-raw`, `--max-age-hours 24`, `--dry-run`) | N |
| `read_summary.py` | Print `_logs/<job>/summary.txt` (no args lists jobs). | WD | `python3 tools/read_summary.py --job xref` | N |
| `list_changed.py` | Git-changed paths with on-disk bytes. Summary: `changed`. | D | `python3 tools/list_changed.py` (`--scope scripts,tools`, `--head`) | N |
| `list_xref.py` | Capped text search (case-insensitive). Summary: `xref`. | D | `python3 tools/list_xref.py --pattern needle` (`--path design`, `--include *.gd`, `--regex`) | N |
| `list_scenes.py` | `.tscn` nodes and scripts without dumping scenes. Summary: `scenes`. | D | `python3 tools/list_scenes.py` (`--path scenes/dungeon.tscn`) | N |
| `list_oversize_scripts.py` | Live `.gd` by bytes. Summary: `oversize`. | D | `python3 tools/list_oversize_scripts.py` (`--over-kb 5`) | N |
| `list_facade_cluster.py` | A facade + its stem-folder helpers by bytes (a helper path or a cluster folder also works). Summary: `facade-cluster`. | D | `python3 tools/list_facade_cluster.py --facade scripts/combat/enemy.gd` | N |
| `start_build_slice.py` | Resolve a route and print the `grok --worktree` fork argv (`--launch` spawns it). Session id optional (`--session` or `$GROK_SESSION_ID`; else placeholder, RESULT INFO). Echoes the door/job card, smoke phases and shot flows (route failure shows the valid doors and no FORK). Summary: `slice-boot`. | D | `python3 tools/start_build_slice.py --door dungeon` (or `--job`, `--area`, `--dry-run`) | N |
| `week_start.py` | Week pin, changelog archive, log clean. **Human-only (QUARANTINE).** Agents must not run it. | D | `python3 tools/week_start.py` (`--dry-run`) | N |

### PowerShell shims

The `.ps1` twins of the Python tools are listed in `tools-shims.md`.

### Session reports (User)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `grok_session_lib.py` | Parse Grok CLI session signals / updates for pack and report runners | D | module docstring (no `--help`) | N |
| `pack_grok_sessions.py` | Pack the costliest Grok CLI sessions in a time window for paste-over | D | `--help` | N |
| `report_grok_sessions.py` | Paste-sized reports from a grok-sessions pack or live session root | D | `--help` | N |
| `report_grok_week.py` | Pack and report What Dwells Below Grok sessions in a week window | D | `--help` | N |

### Release, Pages and other

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `archive_prior_changelogs.py` | Move non-current-series changelogs into `archive/`. Human week ritual. | D | `--help` | N |
| `build_changelog.py` | Rewrite `scripts/data/changelog.json` from `design/changelog/*.md` (takes no args). Stamp territory: the Bot writes changelog entries with `doc_patch`, not this. | BD | `--help` | Y |
| `enable_texture_mips.py` | Turn on mipmaps for 3D world PNGs (`--dry-run`). Rewrites `.import` under `assets/`; `export_web.ps1` runs it. | D | `--help` | N |
| `export_archives.py` | Export pinned catalog archives into a Pages site directory | D | `--help` | N |
| `load_routes.py` | Load design/routes.yaml (constrained YAML subset, stdlib only) | D | module docstring (no `--help`) | N |
| `pages_game_hash.py` | Hash game-affecting paths so Pages can skip a full Godot export | D | `--help` | N |
| `publish_notes_site.py` | Copy baked version/changelog JSON onto the Pages site as loose /data files | D | `--help` | N |
| `run_shots.py` | Posed-camera postcard tool (`--mode web/build/user`), or one scripted flow (`--steps`, `--no-pixels`). Not a numbered smoke. Summary: `shots`. | BWD | `--help` | Y |
| `run_shot_flow.py` | Scripted shot flows (`tools/shot-flows/*.json`): `--list`, `--flow/--all/--smoke`, `--baseline/--save-baseline` diff, `--publish` (to `_out/shots/<flow>/`, refuses `assets/`), `--check-published`. Summary: `shot-flow`. | BWD | `--help` | Y |
| `shot_diff.py` | Before/after diff of shot PNGs (files or dirs): changed pixels, bbox, `*.diff.png`. Summary: `shot-diff`. | BWD | `--help` | Y |
| `check_shot_gaps.py` | UI states with no shot flow, new uncovered states since a ref (`--changed`; FAIL for Bot, `--advisory` for Build), flow and published-shot problems. Summary: `shot-gaps`. | BWD | `--help` | Y |
| `shot_clip_lib.py` | Clipboard paste and open-in-viewer helpers for `run_shots.py` | WD | module docstring (no `--help`) | Y |
| `show_func.py` | Extract one func/const/var (`--path`, `--name`). Summary: `show-func`. | D | `--help` | N |
| `tunables.py` | `get --key K` / `set --key K --value V` on `design/tunables.md` and `tunables-world.md`; a code key like `move_speed` matches a prose row ("Base move speed") when all its words appear; `set` needs exactly one hit. Summaries: `tunable-row`, `tunable-patch`. | D | `--help` | N |
| `tunables_lib.py` | Tunables row parser used by the two tunables tools | D | module docstring (no `--help`) | N |
| `wdb_scratch_server.py` | Token-protected local HTTP runner for web/chat scratch. User setup only; needs `WDB_SCRATCH_TOKEN` and `WDB_ROOT`. | WD | `--help` | N |
| `web_postexport.py` | Stamp a Godot Web export. Cache id follows the binary, not the notes label | D | `--help` | N |
| `web_shell.html` | Web export HTML shell | D | - | N |
| `week_pin.py` | Add a `grok_web_wN` catalog row for HEAD. Human week ritual. | D | `--help` | N |
