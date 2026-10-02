# Tools catalog: Windows, release, session tools

Status: binding  
Read when: running a `.ps1` runner, a Pages/release tool, or a session report (User PC / Build only)  

Rules and the surface key are in `design/tools.md` (single copy). The Bot does not use this file. Runner habits (Length, Godot flags, here-strings): `pc-offload.md`. Summary paths are `_logs/sess/<session>/<job>/summary.txt`; `read_summary.ps1 -Job <name>` reads one.

### PowerShell runners (Windows PC, `powershell -File`)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `agent_log.ps1` | PowerShell twin of `agent_log.py` | D | dot-source `tools/agent_log.ps1` or `import agent_log` | N |
| `archive_prior_changelogs.ps1` | PowerShell twin of `archive_prior_changelogs.py`. Human week ritual. | D | `powershell -File tools/archive_prior_changelogs.ps1` | N |
| `check_script_cap.ps1` | Fail if live scripts exceed the size cap (filesystem Length). Summary: `script-cap`. | D | `powershell -File tools/check_script_cap.ps1` (optional `-OverKb 10`, `-GitChanged`, `-Path ...`) | N |
| `clean_agent_logs.ps1` | Housekeep _logs so agent runners do not clog the disk. Summary: `clean`. | D | `powershell -File tools/clean_agent_logs.ps1` (optional `-KeepRaw`, `-MaxAgeHours 24`, `-NewWeek`, `-WhatIf`) | N |
| `export_web.ps1` | Export the GitHub Pages build (Godot Web, no threads) | D | `powershell -File tools/export_web.ps1` | N |
| `file_stat.ps1` | PowerShell twin of `file_stat.py` | D | `powershell -File tools/file_stat.ps1` | N |
| `godot_lock.ps1` | Per-Godot --path lock. Dot-source from runners | D | `powershell -File tools/godot_lock.ps1` | N |
| `invoke_godot.ps1` | Shared Godot start. Dot-source from runners | D | `powershell -File tools/invoke_godot.ps1` | N |
| `lint_hostify.ps1` | Advisory hostify / := lint. Always exits 0; read RESULT hits= in the summary. Summary: `hostify-lint`. | D | `powershell -File tools/lint_hostify.ps1` | N |
| `list_changed.ps1` | List git-changed paths with on-disk Length (not ReadAllText). Summary: `changed`. | D | `powershell -File tools/list_changed.ps1` (optional `-Scope scripts,tools`, `-Head`) | N |
| `list_facade_cluster.ps1` | List a facade + same-folder sibling helpers by Length (no body reads). Summary: `facade-cluster`. | D | `powershell -File tools/list_facade_cluster.ps1 -Facade scripts/combat/enemy.gd` | N |
| `list_oversize_docs.ps1` | List design/*.md by filesystem Length. Agents read _logs/oversize-docs/summary.txt only. Summary: `oversize-docs`. | D | `powershell -File tools/list_oversize_docs.ps1` (optional `-OverKb 8`) | N |
| `list_oversize_scripts.ps1` | List live oversize GDScript files by on-disk Length (not ReadAllText). Summary: `oversize`. | D | `powershell -File tools/list_oversize_scripts.ps1` (optional `-OverKb 5` or `10`) | N |
| `list_route.ps1` | PowerShell twin of `list_route.py`. Summary: `route`. | D | `powershell -File tools/list_route.ps1 -Door dungeon` (or `-Job debug.smokes`) | N |
| `list_scenes.ps1` | List .tscn nodes and attached scripts without dumping scene files into chat. Summary: `scenes`. | D | `powershell -File tools/list_scenes.ps1` (optional `-Path scenes/dungeon.tscn`) | N |
| `list_xref.ps1` | Capped text search. Writes a short hit list instead of dumping ripgrep into chat. Summary: `xref`. | D | `powershell -File tools/list_xref.ps1 -Pattern "needle"` (optional `-Path design`, `-Include *.gd`, `-MaxHits 30`) | N |
| `move_script_cluster.ps1` | PowerShell twin of `move_script_cluster.py`. Same relocate-only rule. | D | `powershell -File tools/move_script_cluster.ps1` (or `python tools/move_script_cluster.py`) | N |
| `pack_grok_sessions.ps1` | PowerShell twin of `pack_grok_sessions.py` | D | `powershell -File tools/pack_grok_sessions.ps1` | N |
| `read_summary.ps1` | read_summary.ps1 | D | `powershell -File tools/read_summary.ps1 -Job xref` | N |
| `report_grok_sessions.ps1` | PowerShell twin of `report_grok_sessions.py` | D | `powershell -File tools/report_grok_sessions.ps1` | N |
| `run_agent_py.ps1` | Run an ephemeral agent script from `_logs/agent-py/` and delete it after. Not for `tools/_scratch.py` (the Phase 7 paste target; see web-session.md). Summary: `agent-py`. | D | `powershell -File tools/run_agent_py.ps1 -Script _logs/agent-py/foo.py` (optional `-KeepScript`) | N |
| `run_bake_camp.ps1` | run_bake_camp.ps1 | D | `powershell -File tools/run_bake_camp.ps1` | N |
| `run_build_gate.ps1` | Grok Build post-slice gate: editor import check. Summary: `build-gate`. | WD | `powershell -File tools/run_build_gate.ps1` (optional `-SkipImport`, `-OverKb 10`, `-Force`) | N |
| `run_dungeon_load_timing.ps1` | Placeholdia -> Dungeon load-timing smoke. Writes a short summary agents can read. Summary: `dungeon-load-timing`. | WD | `powershell -File tools/run_dungeon_load_timing.ps1` (optional `-TimeoutSec 180`) | N |
| `run_dungeon_map.ps1` | Dungeon generation map smoke. Writes a short summary agents can read. Summary: `dungeon-map`. | WD | `powershell -File tools/run_dungeon_map.ps1` (optional `-Seed 42`, `-Floor 1`, `-Scale 8`, `-TimeoutSec 180`) | N |
| `run_dungeon_map_sweep.ps1` | run_dungeon_map_sweep.ps1 | D | `powershell -File tools/run_dungeon_map_sweep.ps1` | N |
| `run_godot_import_check.ps1` | Editor import / script-reload check. Per-path lock; never kills godot*. Summary: `godot-import-check`. | WD | `powershell -File tools/run_godot_import_check.ps1` | N |
| `run_load_timing.ps1` | Title -> Placeholdia load-timing smoke. Per-path lock; never kills godot*. Summary: `load-timing`. | WD | `powershell -File tools/run_load_timing.ps1` (optional `-TimeoutSec 180`) | N |
| `run_post_split_gate.ps1` | Post-split gate: import check, then optional smokes. One summary for agents. Summary: `post-split-gate`. | D | `powershell -File tools/run_post_split_gate.ps1` (optional `-WithSmokes`, `-Force`) | N |
| `run_smokes.ps1` | Phase smoke runner, per-path Godot lock. Call as `& .\tools\run_smokes.ps1 -Phases @(4,5)` (not `-File ... -Phases 4,5`). | D | `powershell -File tools/run_smokes.ps1` | N |
| `start_build_slice.ps1` | Slice boot for Grok Build. From repo root, inside a Grok session. Summary: `slice-boot`. | D | `powershell -File tools/start_build_slice.ps1 -Door dungeon` (or `-Job`, `-Area`, `-WhatIf`, `-Launch`) | N |
| `summarize_scripts.ps1` | Func-level script inventory. Agents read _logs/script-summary/summary.txt only. Summary: `script-summary`. | D | `powershell -File tools/summarize_scripts.ps1` (optional `-OverKb 5`, `-TopFuncs 8`, `-Path scripts/...`) | N |
| `week_start.ps1` | Week pin, changelog archive, log clean. **Human-only (QUARANTINE).** Agents must not run it. | D | `powershell -File tools/week_start.ps1` | N |

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
| `list_tunable.py` | Print one `design/tunables.md` row (`--key`) | D | `--help` | N |
| `load_routes.py` | Load design/routes.yaml (constrained YAML subset, stdlib only) | D | module docstring (no `--help`) | N |
| `pages_game_hash.py` | Hash game-affecting paths so Pages can skip a full Godot export | D | `--help` | N |
| `patch_tunables.py` | Set the Live cell of one tunables row (`--key`, `--set`). `design/tunables.md` is deny-listed for the Bot. | D | `--help` | N |
| `publish_notes_site.py` | Copy baked version/changelog JSON onto the Pages site as loose /data files | D | `--help` | N |
| `run_shots.py` | Posed-camera postcard tool (`--mode web/build/user`). Not a numbered smoke. Summary: `shots`. | WD | `--help` | N |
| `show_func.py` | Extract one func/const/var (`--path`, `--name`). Summary: `show-func`. | D | `--help` | N |
| `tunables_lib.py` | Tunables row parser used by the two tunables tools | D | module docstring (no `--help`) | N |
| `wdb_scratch_server.py` | Token-protected local HTTP runner for web/chat scratch. User setup only; needs `WDB_SCRATCH_TOKEN` and `WDB_ROOT`. | WD | module docstring (no `--help`) | N |
| `web_postexport.py` | Stamp a Godot Web export. Cache id follows the binary, not the notes label | D | module docstring (no `--help`) | N |
| `web_shell.html` | Web export HTML shell | D | - | N |
| `week_pin.py` | Add a `grok_web_wN` catalog row for HEAD. Human week ritual. | D | `--help` | N |
