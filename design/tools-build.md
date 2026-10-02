# Tools catalog: Windows, release, session tools

Status: binding  
Read when: running a `.ps1` runner, a Pages/release tool, or a session report (User PC / Build only)  

Rules, the CLI contract and the surface key are in `tools.md` (single copy). The Bot does not use this file. Runner habits (Length, Godot flags, here-strings): `pc-offload.md`. Summary paths are `_logs/<job>/summary.txt`; `read_summary.py --job <name>` reads one.

### Runners and Windows tools (Python; `python tools/X.py`)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `godot_lib.py` | Godot launch + per-path lock library (kills only its own pid, never godot*). CLI: lock probe. | D | module docstring (no `--help`) | N |
| `run_build_gate.py` | Post-slice gate: editor import check; `--script-cap` opt-in. Summary: `build-gate`. | WD | `python tools/run_build_gate.py` (`--skip-import`, `--over-kb 10`, `--force`) | N |
| `run_godot_import_check.py` | Editor import / script-reload check. RESULT `clean=true|false`. Summary: `godot-import-check`. | WD | `python tools/run_godot_import_check.py` | N |
| `run_post_split_gate.py` | Import check, then optional smokes. Summary: `post-split-gate`. | D | `python tools/run_post_split_gate.py` (`--with-smokes`, `--phases 1,2,6`, `--force`) | N |
| `run_smokes.py` | Phase smokes on the PC (Bot VM: `bot_smokes.py`). `--door D` / `--job door.job` pick the phases mapped in `routes.yaml` `smokes`. Summary: `smokes`. | D | `python tools/run_smokes.py --phases 4,5` | N |
| `run_load_timing.py` | Title -> Placeholdia load-timing smoke. Summary: `load-timing`. | WD | `python tools/run_load_timing.py` (`--timeout-sec 180`) | N |
| `run_dungeon_load_timing.py` | Placeholdia -> Dungeon load-timing smoke. Summary: `dungeon-load-timing`. | WD | `python tools/run_dungeon_load_timing.py` | N |
| `run_dungeon_map.py` | Dungeon generation map smoke. Summary: `dungeon-map`. | WD | `python tools/run_dungeon_map.py` (`--seed 42 --floor 1 --scale 8`) | N |
| `run_dungeon_map_sweep.py` | Map smoke over seeds. Summary: `dungeon-map-sweep`. | D | `python tools/run_dungeon_map_sweep.py` (`--count 10` or `--seed-list 42,7`) | N |
| `run_bake_camp.py` | Bake `camp.tscn` headless. RESULT `clean=`. Summary: `bake-camp`. | D | `python tools/run_bake_camp.py` | N |
| `export_web.py` | Export the GitHub Pages build (Godot Web, no threads); `--archives` adds the combined `_pages/` site. Logs: `_logs/export-web/`. | D | `python tools/export_web.py` (`--archives`) | N |
| `run_agent_py.py` | Run an ephemeral script from `_logs/agent-py/` and delete it after. Prefer a real tool. Summary: `agent-py`. | D | `python tools/run_agent_py.py --script _logs/agent-py/foo.py` | N |
| `clean_agent_logs.py` | Delete raw logs under `_logs/` (`--new-week` also old summaries). Summary: `clean`. | D | `python tools/clean_agent_logs.py` (`--keep-raw`, `--max-age-hours 24`, `--dry-run`) | N |
| `read_summary.py` | Print `_logs/<job>/summary.txt` (no args lists jobs). | WD | `python tools/read_summary.py --job xref` | N |
| `list_changed.py` | Git-changed paths with on-disk bytes. Summary: `changed`. | D | `python tools/list_changed.py` (`--scope scripts,tools`, `--head`) | N |
| `list_xref.py` | Capped text search (case-insensitive). Summary: `xref`. | D | `python tools/list_xref.py --pattern needle` (`--path design`, `--include *.gd`, `--regex`) | N |
| `list_scenes.py` | `.tscn` nodes and scripts without dumping scenes. Summary: `scenes`. | D | `python tools/list_scenes.py` (`--path scenes/dungeon.tscn`) | N |
| `list_oversize_scripts.py` | Live `.gd` by bytes. Summary: `oversize`. | D | `python tools/list_oversize_scripts.py` (`--over-kb 5`) | N |
| `list_facade_cluster.py` | A facade + sibling helpers by bytes. Summary: `facade-cluster`. | D | `python tools/list_facade_cluster.py --facade scripts/combat/enemy/enemy.gd` | N |
| `start_build_slice.py` | Resolve a route and print the `grok --worktree` fork argv (`--launch` spawns it). Session id optional (`--session` or `$GROK_SESSION_ID`; else placeholder, RESULT INFO). Prints the mapped smoke phases. Summary: `slice-boot`. | D | `python tools/start_build_slice.py --door dungeon` (or `--job`, `--area`, `--dry-run`) | N |
| `week_start.py` | Week pin, changelog archive, log clean. **Human-only (QUARANTINE).** Agents must not run it. | D | `python tools/week_start.py` (`--dry-run`) | N |

### PowerShell shims (kept one release)

Each forwards its arguments to the Python twin, so CI and muscle memory keep working; new work uses `python tools/X.py`. Windows proof of the shims is pending a User run.

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `agent_log.ps1` | Shim -> `agent_log.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/agent_log.ps1` | N |
| `archive_prior_changelogs.ps1` | Shim -> `archive_prior_changelogs.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/archive_prior_changelogs.ps1` | N |
| `check_script_cap.ps1` | Shim -> `check_script_cap.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/check_script_cap.ps1` | N |
| `clean_agent_logs.ps1` | Shim -> `clean_agent_logs.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/clean_agent_logs.ps1` | N |
| `export_web.ps1` | Shim -> `export_web.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/export_web.ps1` | N |
| `file_stat.ps1` | Shim -> `file_stat.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/file_stat.ps1` | N |
| `godot_lock.ps1` | Shim -> `godot_lib.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/godot_lock.ps1` | N |
| `invoke_godot.ps1` | Shim -> `godot_lib.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/invoke_godot.ps1` | N |
| `lint_hostify.ps1` | Shim -> `lint_hostify.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/lint_hostify.ps1` | N |
| `list_changed.ps1` | Shim -> `list_changed.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_changed.ps1` | N |
| `list_facade_cluster.ps1` | Shim -> `list_facade_cluster.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_facade_cluster.ps1` | N |
| `list_oversize_docs.ps1` | Shim -> `list_oversize_docs.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_oversize_docs.ps1` | N |
| `list_oversize_scripts.ps1` | Shim -> `list_oversize_scripts.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_oversize_scripts.ps1` | N |
| `list_route.ps1` | Shim -> `list_route.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_route.ps1` | N |
| `list_scenes.ps1` | Shim -> `list_scenes.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_scenes.ps1` | N |
| `list_xref.ps1` | Shim -> `list_xref.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/list_xref.ps1` | N |
| `move_script_cluster.ps1` | Shim -> `move_script_cluster.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/move_script_cluster.ps1` | N |
| `pack_grok_sessions.ps1` | Shim -> `pack_grok_sessions.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/pack_grok_sessions.ps1` | N |
| `read_summary.ps1` | Shim -> `read_summary.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/read_summary.ps1` | N |
| `report_grok_sessions.ps1` | Shim -> `report_grok_sessions.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/report_grok_sessions.ps1` | N |
| `run_agent_py.ps1` | Shim -> `run_agent_py.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_agent_py.ps1` | N |
| `run_bake_camp.ps1` | Shim -> `run_bake_camp.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_bake_camp.ps1` | N |
| `run_build_gate.ps1` | Shim -> `run_build_gate.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_build_gate.ps1` | N |
| `run_dungeon_load_timing.ps1` | Shim -> `run_dungeon_load_timing.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_dungeon_load_timing.ps1` | N |
| `run_dungeon_map.ps1` | Shim -> `run_dungeon_map.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_dungeon_map.ps1` | N |
| `run_dungeon_map_sweep.ps1` | Shim -> `run_dungeon_map_sweep.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_dungeon_map_sweep.ps1` | N |
| `run_godot_import_check.ps1` | Shim -> `run_godot_import_check.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_godot_import_check.ps1` | N |
| `run_load_timing.ps1` | Shim -> `run_load_timing.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_load_timing.ps1` | N |
| `run_post_split_gate.ps1` | Shim -> `run_post_split_gate.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_post_split_gate.ps1` | N |
| `run_smokes.ps1` | Shim -> `run_smokes.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/run_smokes.ps1` | N |
| `start_build_slice.ps1` | Shim -> `start_build_slice.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/start_build_slice.ps1` | N |
| `summarize_scripts.ps1` | Shim -> `summarize_scripts.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/summarize_scripts.ps1` | N |
| `week_start.ps1` | Shim -> `week_start.py`, one release. Old `-Flag` spellings work. | D | `powershell -File tools/week_start.ps1` | N |

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
| `list_tunable.py` | Shim -> `tunables.py get`, one release | D | `--help` | N |
| `load_routes.py` | Load design/routes.yaml (constrained YAML subset, stdlib only) | D | module docstring (no `--help`) | N |
| `pages_game_hash.py` | Hash game-affecting paths so Pages can skip a full Godot export | D | `--help` | N |
| `patch_tunables.py` | Shim -> `tunables.py set`, one release | D | `--help` | N |
| `publish_notes_site.py` | Copy baked version/changelog JSON onto the Pages site as loose /data files | D | `--help` | N |
| `run_shots.py` | Posed-camera postcard tool (`--mode web/build/user`). Not a numbered smoke. Summary: `shots`. | WD | `--help` | N |
| `show_func.py` | Extract one func/const/var (`--path`, `--name`). Summary: `show-func`. | D | `--help` | N |
| `tunables.py` | `get --key K` / `set --key K --value V` on `design/tunables.md` (`design/tunables.md` is deny-listed for the Bot). Summaries: `tunable-row`, `tunable-patch`. | D | `--help` | N |
| `tunables_lib.py` | Tunables row parser used by the two tunables tools | D | module docstring (no `--help`) | N |
| `wdb_scratch_server.py` | Token-protected local HTTP runner for web/chat scratch. User setup only; needs `WDB_SCRATCH_TOKEN` and `WDB_ROOT`. | WD | `--help` | N |
| `web_postexport.py` | Stamp a Godot Web export. Cache id follows the binary, not the notes label | D | `--help` | N |
| `web_shell.html` | Web export HTML shell | D | - | N |
| `week_pin.py` | Add a `grok_web_wN` catalog row for HEAD. Human week ritual. | D | `--help` | N |
