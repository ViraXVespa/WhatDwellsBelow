# Tools: Build session, release and Pages

Status: protocol  
Read when: starting or ending a Build slice, cleaning logs, the week ritual, or a Pages / release tool (User PC / Build only)  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Runner habits: `pc-offload.md`. Not for the Bot.

## Jobs

- **Start a slice:** the User runs `python tools/open_slice.py AREA` (or `--task ID`); inside the worktree Build runs `python tools/start_build_slice.py` first.
- **A one-off script:** `run_agent_py.py --script _logs/agent-py/x.py` (deleted after the run); prefer a tool.
- **Logs:** `clean_agent_logs.py` (raw logs), `--new-week` (everything).
- **Web export:** `export_web.py` (Pages build), `export_web.py --debug --out DIR` (debug build for perf or hitch work).
- **Week and pins (human ritual):** `week_start.py`, `week_pin.py --web N` / `--build N`; CI runs `ci_archive.py`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `open_slice.py` | **User-run launcher** (PowerShell), never run by Build: `python tools/open_slice.py [AREA] [--task ID \| --prompt TEXT \| --prompt-file PATH] [--ref REF] [--dry-run]` creates a worktree from `grok-build-w{N}` (`grok worktree create`) and starts `grok --cwd PATH --trust [PROMPT]` there (a new worktree is its own checkout). Prints the commands first; no grok on PATH: prints them to copy, exit 1. AREA is checked against the doors. `--selftest`. Summary: `open-slice`. | D | `--help` | N |
| `start_build_slice.py` | First command inside a slice worktree: the door card (phases, shot flows, STEP 0 note, job cycle, first-message rules, session facts). First run writes `_logs/slice-state.json` and records the original session id for a retry; a later run prints `SLICE ALREADY STARTED` (`--full` reprints). `--door D` / `--job door.job` / `--task ID`; a `unit_queue` door starts its next unit, `--unit-done` marks it. Survey -> implement: `--handoff`, then `--from-handoff PATH` or `--from-task ID`. `--failed` prints `Did not work:` lines. In a main checkout it only points to `open_slice.py`. `--selftest`. Summary: `slice-boot`. | D | `--help` | N |
| `run_agent_py.py` | Run a one-off script from `_logs/agent-py/` (`--script PATH [args]`) and delete it after (`--keep-script` keeps it). Prefer a real tool. Summary: `agent-py`. | D | `--help` | N |
| `clean_agent_logs.py` | Delete raw logs under `_logs/` (`--max-age-hours`, `--keep-raw`); `--new-week` also every stamped summary and index. Summary: `clean`. | D | `--help` | N |
| `export_web.py` | Export the GitHub Pages build (Godot Web, no threads; runs `enable_texture_mips.py` before `--import`). `--archives` adds the `_pages/` site; `--out DIR` exports to a scratch dir; `--debug --out DIR` uses preset `Web Debug` (keeps `scripts/debug/`; release `Web` excludes it). | D | `--help` | N |
| `week_start.py` | Week start from main: seed `epoch.N.0`, park changelogs, branch `grok-build-w{N}` + seed commit, `grok worktree gc`, locks, logs; pins a missing closing-week row. **Human-only.** | D | `--help` | N |
| `week_pin.py` | Catalog row, notes, local tag: `--web N`, `--build N`, `--id`. Idempotent. | D | `--help` | N |
| `ci_archive.py` | CI: a merge adding `design/changelog/0.N.0.md` pins web + build week N (tags, rows, docs) and pushes. `--dry-run`, `--selftest`. | D | `--help` | N |
| `archive_prior_changelogs.py` | Move non-current-series changelogs into `archive/`. Human week ritual. | D | `--help` | N |
| `build_changelog.py` | Rewrite `scripts/data/changelog.json` from `design/changelog/*.md`. The Bot writes entries with `doc_patch`, not this. | BD | `--help` | Y |
| `enable_texture_mips.py` | Turn on mipmaps for 3D world PNGs (`--dry-run`). | D | `--help` | N |
| `export_archives.py` | Export pinned catalog archives into a Pages site directory | D | `--help` | N |
| `pages_game_hash.py` | Hash game-affecting paths so Pages can skip a full Godot export | D | `--help` | N |
| `publish_notes_site.py` | Copy baked version/changelog JSON onto the Pages site as loose /data files | D | `--help` | N |
| `web_postexport.py` | Stamp a Godot Web export. Cache id follows the binary, not the notes label | D | `--help` | N |
| `web_shell.html` | Web export HTML shell | D | - | N |
| `wdb_scratch_server.py` | Token-protected local HTTP runner for web/chat scratch. User setup only. | WD | `--help` | N |
