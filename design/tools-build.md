# Tools catalog: Windows, release, session tools

Status: binding  
Read when: running a `.ps1` runner, a Pages/release tool, or a session report (User PC / Build only)  

Rules, CLI contract, surface key: `tools.md`. Runner habits: `pc-offload.md`. Summaries: `_logs/<job>/summary.txt`. Not for the Bot.

### Runners and Windows tools (Python; `python3 tools/X.py`)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `godot_lib.py` | Godot launch + per-path lock library (kills only its own pid, never godot*). `gui=True` runs pick a display (`$DISPLAY`, a live X socket, else `xvfb-run`). | BD | module docstring (no `--help`) | Y |
| `run_godot_import_check.py` | Editor import / script-reload check. RESULT `clean=true|false`. Summary: `godot-import-check`. | WD | `--help` | N |
| `run_post_split_gate.py` | Import check, then optional smokes. Summary: `post-split-gate`. | D | `--help` | N |
| `run_smokes.py` | Phase smokes on the PC (Bot VM: `bot_smokes.py`); `--door` / `--job` pick the `routes.yaml` `smokes` phases. Prints `check_shot_gaps.py --changed --advisory`. Summary: `smokes`. | D | `--help` | N |
| `run_load_timing.py` | Title -> Placeholdia load-timing smoke. Summary: `load-timing`. | WD | `--help` | N |
| `run_dungeon_load_timing.py` | Placeholdia -> Dungeon load-timing smoke. Summary: `dungeon-load-timing`. | WD | `--help` | N |
| `run_dungeon_map.py` | Dungeon generation map smoke. Summary: `dungeon-map`. | WD | `--help` | N |
| `run_dungeon_map_sweep.py` | Map smoke over seeds. Summary: `dungeon-map-sweep`. | D | `--help` | N |
| `run_bake_camp.py` | Bake `hub_light.png` through `--wdb-bake-camp` on a real renderer (auto display; `--headless` gives the same atlas; `shadow_px=0` FAILs). Never rewrites `camp.tscn`. Summary: `bake-camp`. | BD | `--help` | Y |
| `export_web.py` | Export the GitHub Pages build (Godot Web, no threads; runs `enable_texture_mips.py` before `--import`, no second bake after the PCK). `--archives` adds the `_pages/` site; `--out DIR` exports to a scratch dir (for `web_perf.py`). | D | `--help` | N |
| `run_agent_py.py` | Run an ephemeral script from `_logs/agent-py/` and delete it after. Prefer a real tool. Summary: `agent-py`. | D | `--help` | N |
| `clean_agent_logs.py` | Delete raw logs under `_logs/` (`--new-week` also old summaries). Summary: `clean`. | D | `--help` | N |
| `read_summary.py` | Print `_logs/<job>/summary.txt` (no args lists jobs). | WD | `--help` | N |
| `list_changed.py` | Git-changed paths with on-disk bytes. Summary: `changed`. | D | `--help` | N |
| `list_xref.py` | Capped text search (case-insensitive). Summary: `xref`. | D | `--help` | N |
| `list_scenes.py` | `.tscn` nodes and scripts without dumping scenes. Summary: `scenes`. | D | `--help` | N |
| `list_oversize_scripts.py` | Live `.gd` by bytes. Summary: `oversize`. | D | `--help` | N |
| `list_facade_cluster.py` | A facade + its stem-folder helpers by bytes. Summary: `facade-cluster`. | D | `--help` | N |
| `start_build_slice.py` | Resolve a route and print the `grok --worktree` fork argv. Session id optional (`--session`, `$GROK_SESSION_ID`). Echoes the door/job card, smoke phases and shot flows. Summary: `slice-boot`. | D | `--help` | N |
| `week_start.py` | Week pin, changelog archive, log clean. **Human-only (QUARANTINE).** Agents must not run it. | D | `--help` | N |

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
| `build_changelog.py` | Rewrite `scripts/data/changelog.json` from `design/changelog/*.md`. Stamp territory: the Bot writes entries with `doc_patch`, not this. | BD | `--help` | Y |
| `enable_texture_mips.py` | Turn on mipmaps for 3D world PNGs (`--dry-run`). Rewrites `.import` under `assets/`; `export_web.ps1` runs it. | D | `--help` | N |
| `export_archives.py` | Export pinned catalog archives into a Pages site directory | D | `--help` | N |
| `load_routes.py` | Load design/routes.yaml (constrained YAML subset, stdlib only) | D | module docstring (no `--help`) | N |
| `pages_game_hash.py` | Hash game-affecting paths so Pages can skip a full Godot export | D | `--help` | N |
| `publish_notes_site.py` | Copy baked version/changelog JSON onto the Pages site as loose /data files | D | `--help` | N |
| `run_shots.py` | Posed-camera postcard tool (`--mode web/build/user`) or one scripted flow. Not a numbered smoke. Summary: `shots`. | BWD | `--help` | Y |
| `run_shot_flow.py` | Scripted shot flows (`tools/shot-flows/*.json`), baseline diff, `--publish` (to `_out/shots/<flow>/`, refuses `assets/`). Summary: `shot-flow`. | BWD | `--help` | Y |
| `shot_diff.py` | Before/after diff of shot PNGs (files or dirs): changed pixels, bbox, `*.diff.png`. Summary: `shot-diff`. | BWD | `--help` | Y |
| `check_shot_gaps.py` | UI states with no shot flow (`--changed`: new since a ref; FAIL for Bot, `--advisory` for Build), flow and published-shot problems. Summary: `shot-gaps`. | BWD | `--help` | Y |
| `shot_clip_lib.py` | Clipboard paste and open-in-viewer helpers for `run_shots.py` | WD | module docstring (no `--help`) | Y |
| `show_func.py` | Extract one func/const/var (`--path`, `--name`). Summary: `show-func`. | D | `--help` | N |
| `tunables.py` | `get` / `set` / `add` on a row of `design/tunables.md` and `tunables-world.md`; a code key like `move_speed` matches a prose row ("Base move speed") when all its words appear; `set` needs exactly one hit. Summaries: `tunable-row`, `tunable-patch`. | D | `--help` | N |
| `tunables_lib.py` | Tunables row parser used by the two tunables tools | D | module docstring (no `--help`) | N |
| `wdb_scratch_server.py` | Token-protected local HTTP runner for web/chat scratch. User setup only; needs `WDB_SCRATCH_TOKEN` and `WDB_ROOT`. | WD | `--help` | N |
| `web_postexport.py` | Stamp a Godot Web export. Cache id follows the binary, not the notes label | D | `--help` | N |
| `web_shell.html` | Web export HTML shell | D | - | N |
| `web-perf-baseline.json` | `--save-baseline` numbers (box, 0.5.20, median of 3). Re-save per machine. | BD | - | N |
| `web-perf-flows.json` | Flows for `web_perf.py` (`_boot` is the shared prefix). `dungeon-fight` runs the playtester: compare its fps only with itself; INVALID runs are never baselined; `expect_change` pairs must differ (else STUCK). Keyboard only. | BD | - | N |
| `web_perf.py` | Advisory perf run of the EXPORTED web build in headless Chrome via playwright (`pip install playwright`; system Chrome). Default `--site docs/` may be stale: export with `export_web.py --out DIR` (needs the 4.7.2 `web_*` templates in `~/.local/share/godot/export_templates/4.7.2.stable/`). `--baseline` (`tools/web-perf-baseline.json`) flags WORSE (INFO; `--strict` exits 1). Never a gate; software GL; dungeon flows use `?wdb-seed=42` (`debug-playtest.md`). Summary: `web-perf`. | BD | `--help` | Y |
| `web_perf_lib.py` | Browser side of `web_perf.py` (init script, flow replay, one page load). Library. | BD | docstring | Y |
| `week_pin.py` | Add a `grok_web_wN` catalog row for HEAD. Human week ritual. | D | `--help` | N |
