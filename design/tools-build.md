# Tools catalog: Windows, release, session tools

Status: protocol  
Read when: running a Windows runner, a Pages/release tool, or a session report (User PC / Build only)  

Rules, CLI contract, surface key: `tools.md`. Runner habits: `pc-offload.md`. Summaries: `_logs/<job>/<stamp>-<job>.txt` plus `index.txt`. Not for the Bot.

### Runners and Windows tools (Python; `python tools/X.py`)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `godot_lib.py` | Godot launch + per-path lock library (kills only its own pid, never godot*). `gui=True` runs pick a display. | BD | module docstring (no `--help`) | Y |
| `run_godot_import_check.py` | Editor import / script-reload check. RESULT `clean=true|false`. Summary: `godot-import-check`. | WD | `--help` | N |
| `check_gd_load.py` | Compile check: loads each changed or untracked `.gd` (`--files`, `--all`, `--base`) inside the real project with its autoloads, so a stray `)` or a bad reference fails. Lists every failing file with Godot's error lines; prints stderr size and leading lines to read. Imports first if `.godot` is missing. `--selftest` (throwaway project). Summary: `gd-load-check`. | D | `--help` | N |
| `run_post_split_gate.py` | Import check, then optional smokes. Summary: `post-split-gate`. | D | `--help` | N |
| `run_smokes.py` | Phase smokes on the PC (Bot VM: `bot_smokes.py`); `--door` / `--job` pick the `routes.yaml` `smokes` phases. Prints `check_shot_gaps.py --changed --advisory` mid-slice (the END gate, `run_build_gate.py`, is required). Summary: `smokes`. | D | `--help` | N |
| `run_load_timing.py` | Title -> Placeholdia load-timing smoke. Summary: `load-timing`. | WD | `--help` | N |
| `run_dungeon_load_timing.py` | Placeholdia -> Dungeon load-timing smoke. Summary: `dungeon-load-timing`. | WD | `--help` | N |
| `run_dungeon_map.py` | Dungeon generation map smoke. Summary: `dungeon-map`. | WD | `--help` | N |
| `run_dungeon_map_sweep.py` | Map smoke over seeds. Summary: `dungeon-map-sweep`. | D | `--help` | N |
| `run_bake_camp.py` | Bake `hub_light.png` through `--wdb-bake-camp` on a real renderer (auto display; prints `stamp=`; `shadow_px=0` FAILs). Never rewrites `camp.tscn`. Summary: `bake-camp`. | BD | `--help` | Y |
| `export_web.py` | Export the GitHub Pages build (Godot Web, no threads; runs `enable_texture_mips.py` before `--import`). `--archives` adds the `_pages/` site; `--out DIR` exports to a scratch dir. | D | `--help` | N |
| `run_agent_py.py` | Run an ephemeral script from `_logs/agent-py/` and delete it after. Prefer a real tool. Summary: `agent-py`. | D | `--help` | N |
| `clean_agent_logs.py` | Delete raw logs under `_logs/` (`--new-week` also every stamped summary and index). Summary: `clean`. | D | `--help` | N |
| `read_summary.py` | Print the absolute root it read, a job's `index.txt` (newest first), then its newest summary (`--run N`, `--index`, `--path`; no args lists jobs). | WD | `--help` | N |
| `list_changed.py` | Git-changed paths (first line: the absolute root scanned) with on-disk bytes; `--history PATH...` shows each path's recent commits and which is newer (docs vs code); `--head` puts HEAD and the log in the stdout echo. Summary: `changed`. | D | `--help` | N |
| `list_xref.py` | Text search (case-insensitive) in the project holding the current directory; prints the absolute root it scanned; the Bot's own docs (`BOT.md`, `design/grok-bot-*.md`) are not searched; many hits print as a per-file index (`--expand FILE` for one file's hits); `--texts` searches the shot-flow text dumps (`_logs/shot-flow/**/*.texts.json`, after `run_shot_flow.py`). Summary: `xref`. | D | `--help` | N |
| `list_scenes.py` | `.tscn` nodes and scripts without dumping scenes. Summary: `scenes`. | D | `--help` | N |
| `list_facade_cluster.py` | A facade + its stem-folder helpers by bytes. Summary: `facade-cluster`. | D | `--help` | N |
| `open_slice.py` | **User-run launcher** (PowerShell): `python tools/open_slice.py [AREA] [--prompt TEXT \| --prompt-file PATH] [--ref REF] [--dry-run]` runs `grok --worktree=NAME --ref grok-build-w{N} [PROMPT]` from the repo root with a plain args list and hands the terminal over; the worktree name is generated. Prints the command first; no grok on PATH or a failed launch: prints it to copy, exit 1. With AREA resolves it first (an unknown area WARNs and lists the doors); prints the prompt as `prompt: N chars, starts '...', sha256 ...` (or `none`); a visual area with no `shot_flows` prints a STEP 0 note (creating the flow is the first job step) and still launches. No week branch and no `--ref`: fails. Never `--fork-session`, `-p`, `--prompt-file` or `--max-turns` for grok. The only launcher of Build slices; Build never runs it. `--selftest` (dry-run only). Summary: `open-slice`. | D | `--help` | N |
| `show_png.py` | `PATH[=one-line description] ...`: opens the PNGs in her default viewer on Windows (in order) and prints `path - description` lines for the message; elsewhere prints only and passes. Once per ask that refers to pictures, after you looked at them. Also prints the `Did not work:` lines built from this session's failed tool results since your last ask. `--selftest`. | D | `--help` | N |
| `shot_crop.py` | `PNG --box X,Y,W,H [--zoom N] [--out P]` crops and enlarges a shot to a PNG (open it with `show_png.py`); `--probe X,Y ...` prints RGBA and hex; `--near HEX [--tol N]` and `--dark N` count pixels and print their bounding box. Replaces one-off pixel scripts. `--selftest`. | D | `--help` | N |
| `commit_slice.py` | Commit the slice after her yes: needs a passing `run_build_gate.py` summary newer than every change, else stops; `--gate-skipped WHY` commits and prints `Did not work: gate not run (WHY)`. Stages everything except `.import` sidecars Godot only modified (counted, left uncommitted). Message from `_logs/commit-msg.txt`. Never pushes. `--dry-run`, `--selftest`. | D | `--help` | N |
| `start_build_slice.py` | First command inside the slice worktree (a Grok full clone under `.grok/worktrees/<repo>/<name>`): the door card, phases, shot flows, the STEP 0 note, the merge-back line and the first-message rules (order, Q0, a message before every ask, the three ledger lines, `Did not work:`, `show_png.py`), with the session facts it read from the session's own files (`session_lib.py`; unreadable: "not verified"). The first run writes `_logs/slice-state.json`; a later run prints `SLICE ALREADY STARTED` (steps found, next step) and `--full` reprints the card. A door with several jobs is a survey (text ORDER, ends in `--handoff`); a door with `unit_queue` in `routes.yaml` (ui) is not: `--door D` starts the first unit not done and prints only that unit's flow and state, doc line ranges and files, and `--next` (unit committed) marks it done and prints the next unit's card with no new survey. In a main checkout it only points to `open_slice.py`. Never starts grok. A ui / theme / visual job with no `shot_flows` of its own: a STEP 0 note, exit 0, not a stop. `--checkpoint` (implementation session, after gather) saves `$GROK_SESSION_ID` (else `--session ID`; empty fails with the `Did not work:` rule and where to get the id) so a red prove prints `grok -r ID --fork-session` to run from the worktree. `--failed` prints the `Did not work:` lines from this session's failed tool results since your last ask. `--handoff` (survey session, after her answers to the first ask; the door comes from `_logs/slice-state.json`: skeleton, then validation, then the `open_slice.py --prompt-file` command; the session stops) and `--from-handoff PATH` (the fresh session's first command) are for survey -> implement and do not need the checkpoint. `--selftest`. Summary: `slice-boot`. | D | `--help` | N |
| `week_start.py` | Week start from main: seed `epoch.N.0`, park changelogs, branch `grok-build-w{N}` + seed commit, `grok worktree gc`, locks, logs. Pins only a missing closing-week row (catch-up). **Human-only (QUARANTINE).** | D | `--help` | N |

### Session reports (User)

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|

### Release, Pages and other

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `archive_prior_changelogs.py` | Move non-current-series changelogs into `archive/`. Human week ritual. | D | `--help` | N |
| `build_changelog.py` | Rewrite `scripts/data/changelog.json` from `design/changelog/*.md`. The Bot writes entries with `doc_patch`, not this. | BD | `--help` | Y |
| `enable_texture_mips.py` | Turn on mipmaps for 3D world PNGs (`--dry-run`). | D | `--help` | N |
| `export_archives.py` | Export pinned catalog archives into a Pages site directory | D | `--help` | N |
| `load_routes.py` | Load design/routes.yaml (constrained YAML subset, stdlib only) | D | module docstring (no `--help`) | N |
| `pages_game_hash.py` | Hash game-affecting paths so Pages can skip a full Godot export | D | `--help` | N |
| `publish_notes_site.py` | Copy baked version/changelog JSON onto the Pages site as loose /data files | D | `--help` | N |
| `run_shots.py` | Posed-camera postcard tool (`--mode web/build/user`) one scripted flow, or `--full-map` (whole floor in one PNG); `--scene` dungeon / camp / hub, or the menu screens title / splash / fs_gate on an isolated save. Not a numbered smoke. Summary: `shots`. | BWD | `--help` | Y |
| `run_shot_flow.py` | Scripted shot flows (`tools/shot-flows/*.json`): `--flow A,B`, `--job J` (every flow routes.yaml maps to the job, one call, one summary with the frame lists; a unit job with a `shot_states` entry re-shoots only that state; a flow with `covered_by` another picked flow is skipped), `--changed`, `--flow N --state NAME` (re-shoot one state; says changed or same); `--survey` prints a text line per flow: about, states, last shot, band; `--sheet FLOW` tiles its frames into one labeled image; baseline diff; `--publish` (to `_out/shots/<flow>/`, refuses `assets/`). Summary: `shot-flow`. | BWD | `--help` | Y |
| `shot_diff.py` | Before/after diff of shot PNGs (files or dirs): changed pixels, bbox, `*.diff.png`. Summary: `shot-diff`. | BWD | `--help` | Y |
| `check_shot_gaps.py` | UI states with no shot flow (`--changed`: new since a ref; at the END, FAIL for Bot and for a Build UI or theme prove: required per `routes.yaml` `shot_gaps`), flow and published-shot problems. Summary: `shot-gaps`. | BWD | `--help` | Y |
| `shot_clip_lib.py` | Clipboard paste and open-in-viewer helpers for `run_shots.py` | WD | module docstring (no `--help`) | Y |
| `show_func.py` | Extract one func/const/var (`--path`, `--name`); prints the absolute root it read; a missing file or name prints a hint (`list_xref.py`). Summary: `show-func`. | D | `--help` | N |
| `tunables.py` | `get` / `set` / `add` on a row of `design/tunables.md` and `tunables-world.md`; `set` needs exactly one hit. Summaries: `tunable-row`, `tunable-patch`. | D | `--help` | N |
| `tunables_lib.py` | Tunables row parser used by the two tunables tools | D | module docstring (no `--help`) | N |
| `wdb_scratch_server.py` | Token-protected local HTTP runner for web/chat scratch. User setup only. | WD | `--help` | N |
| `web_postexport.py` | Stamp a Godot Web export. Cache id follows the binary, not the notes label | D | `--help` | N |
| `web_shell.html` | Web export HTML shell | D | - | N |
| `web-perf-baseline.json` | `--save-baseline` numbers (box, 0.5.20, median of 3). Re-save per machine. | BD | - | N |
| `web-perf-flows.json` | Flows for `web_perf.py` (`_boot` is the shared prefix). `dungeon-fight` runs the playtester: compare its fps only with itself; INVALID runs are never baselined; `expect_change` pairs must differ (else STUCK). | BD | - | N |
| `web_perf.py` | Advisory perf run of the EXPORTED web build in headless Chrome via playwright (`pip install playwright`; system Chrome). Default `--site docs/` may be stale: export with `export_web.py --out DIR`. `--baseline` (`tools/web-perf-baseline.json`) flags WORSE (INFO; `--strict` exits 1). Never a gate; software GL; `camp-idle` is the no-UI reference for `camp-pause`/`camp-shop`; `hub-load` / `dungeon-load` print the engine load marks (not diffed); dungeon flows use `?wdb-seed=42`. Summary: `web-perf`. | BD | `--help` | Y |
| `web_perf_lib.py` | Browser side of `web_perf.py` (init script, flow replay, one page load). | BD | docstring | Y |
| `week_pin.py` | Catalog row, notes, local tag: `--web N`, `--build N`, `--id`. Idempotent. | D | `--help` | N |
| `ci_archive.py` | CI: a merge adding `design/changelog/0.N.0.md` pins web + build week N (tags, rows, docs) and pushes. `--dry-run`, `--selftest`. | D | `--help` | N |
