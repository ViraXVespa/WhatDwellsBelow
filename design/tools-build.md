# Tools: Build session, release and Pages

Status: protocol  
Read when: starting or ending a Build slice, cleaning logs, the week ritual, or a Pages / release tool (User PC / Build only)  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Runner habits: `pc-offload.md`. Not for the Bot.

Entries here: `slice.py`, `session.py`, `release.py`; their code: `tools/lib/release/`, `tools/lib/session/`, `tools/lib/slice/`.

## Jobs

- **Start a slice:** the User runs `python tools/slice.py open AREA` (or `--task ID`); inside the worktree Build runs `python tools/slice.py start` first. That start writes `session-plan.md` when a door or job is named and the file is missing. `python tools/slice.py plan` rebuilds a missing file. Build trims the gathered half to this unit in the same turn the working set is known, and writes the four sections above the marker as facts land. `--refresh` replaces that half and erases a trim; use it only when the gather is stale.
- **Necessary visual references:** `slice.py references export`, explicit `grant`, then direct image reads; `status`/`revoke` control the temporary scope.
- **A one-off script:** `session.py py --script _logs/agent-py/x.py` (deleted after the run); prefer a tool.
- **Logs:** `session.py clean` (raw logs), `--new-week` (everything).
- **Web export:** `release.py export-web` (Pages build), `release.py export-web --debug --out DIR` (debug build for perf or hitch work).
- **Week and pins:** `release.py week-start` (Build, `build-week-start.md`), `release.py week-pin --web N` / `--build N`; CI runs `release.py ci-archive`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `slice.py open` | **User-run launcher** (PowerShell), never run by Build: `python tools/slice.py open [AREA] [--task ID \| --prompt TEXT \| --prompt-file PATH] [--ref REF] [--dry-run]` creates a worktree from `grok-build-w{N}` (`grok worktree create`) and starts `grok --cwd PATH --trust [PROMPT]` there (a new worktree is its own checkout). After create, junctions `worktree/addons` to this checkout's gitignored `addons/` (the Godot AI Asset Library install) so the plugin loads. Copies only if the junction cannot be created. A missing `addons/` is reported and the launch still proceeds. Remove the worktree with `grok worktree rm` or `git worktree remove`, which drops the junction and leaves the checkout install. Prints the commands first; no grok on PATH: prints them to copy, exit 1. AREA is checked against the doors. `--selftest`. Summary: `open-slice`. | D | `--help` | N |
| `slice.py references` | Necessary direct visual references for an active Build task: `export --task ID --bible FILE [--walk-dir DIR] [--out DIR]`, `grant --task ID --reason TEXT --path FILE` (repeat) or `--manifest FILE`, `status`, `revoke`. Exact content-bound read-only images, original session/unit, 2-hour expiry; no shell or generation exception. `--selftest` uses synthetic fixtures. Summary: `reference-access`. | D | `--help` | N |
| `slice.py start` | First command inside a slice worktree: the door card (phases, shot flows, STEP 0 note, job cycle, first-message rules, session facts). First run writes `_logs/slice-state.json` and records the original session id for a retry; a later run prints `SLICE ALREADY STARTED` (`--full` reprints). A named door or job also writes `session-plan.md` in the worktree root when that file is missing (the opening gather). `--door D` / `--job door.job` / `--task ID`; a `unit_queue` door starts its next unit, `--unit-done` marks it. Survey -> implement: `--handoff`, then `--from-handoff PATH` or `--from-task ID`. `--failed` prints `Did not work:` lines. In a main checkout it only points to `slice.py open`. `--selftest`. Summary: `slice-boot`. | D | `--help` | N |
| `slice.py plan` | Opening gather for a named door or job: writes gitignored `session-plan.md` in the worktree root (card, code-map key paths, door doc, job doc, function names). Reads slice state when `--door` / `--job` are omitted. Existing file is kept; `--refresh` replaces the gathered half and keeps Outcome, Open questions, Changed files, and Latest results. Build then trims that half to this unit; `--refresh` undoes the trim. Not a worktree: fails. `--dry-run` prints a line count and does not write. `--selftest`. Summary: `session-plan`. | D | `--help` | N |
| `session.py py` | Run a one-off script from `_logs/agent-py/` (`--script PATH [args]`) and delete it after (`--keep-script` keeps it). Prefer a real tool. Summary: `agent-py`. | D | `--help` | N |
| `session.py clean` | Delete raw logs under `_logs/` (`--max-age-hours`, `--keep-raw`); `--new-week` also every stamped summary and index. Summary: `clean`. | D | `--help` | N |
| `release.py export-web` | Export the GitHub Pages build (Godot Web, no threads; runs `release.py mips` before `--import`). `--archives` adds the `_pages/` site; `--out DIR` exports to a scratch dir; `--debug --out DIR` uses preset `Web Debug` (keeps `scripts/debug/`; release `Web` excludes it). | D | `--help` | N |
| `release.py week-start` | Week start from main: seed `epoch.N.0`, branch `grok-build-w{N}` + seed commit, `grok worktree gc`, locks, logs; pins a missing closing-week row. A seed-commit failure returns `RESULT FAIL reason=seed-commit` before gc and clean. Off `main`, `RESULT FAIL reason=not-main`: check out `main` and resume at step 1; do not read the other branch to diagnose it. Build only, at a new week (`build-week-start.md`). | D | `--help` | N |
| `release.py week-pin` | Catalog row, notes, local tag: `--web N`, `--build N`, `--id`. Idempotent. | D | `--help` | N |
| `release.py ci-archive` | CI: a merge adding `design/changelog/0.N.0.md` pins web + build week N (tags, rows, docs) and pushes. `--dry-run`, `--selftest`. | D | `--help` | N |
| `release.py changelog` | Rewrite `scripts/data/changelog.json` from the current series' flat `design/changelog/*.md`. The Bot writes entries with `doc_patch`, not this. | BD | `--help` | Y |
| `release.py mips` | Turn on mipmaps for 3D world PNGs (`--dry-run`). | D | `--help` | N |
| `release.py archives` | Export pinned catalog archives into a Pages site directory | D | `--help` | N |
| `release.py pages-hash` | Hash game-affecting paths so Pages can skip a full Godot export | D | `--help` | N |
| `release.py notes-site` | Copy baked version/changelog JSON onto the Pages site as loose /data files | D | `--help` | N |
| `release.py postexport` | Stamp a Godot Web export. Cache id follows the binary, not the notes label | D | `--help` | N |
| `session.py scratch-server` | Token-protected local HTTP runner for web/chat scratch. User setup only. | WD | `--help` | N |

## Libs and data

No CLI of their own; new code goes into the owner (`tools.md` rule 6).

| File (under `tools/`) | Owns |
|---|---|
| `data/web_shell.html` | Web export HTML shell |
| `lib/slice/reference_access.py` | Task-scoped reference CLI, `slice.py references` |
| `lib/slice/reference_policy.py` | Shared CLI/hook grant validation: task, session, unit, path, content and expiry |
| `lib/slice/reference_export.py` | Native Bible cells and walk copies with source/crop provenance |
| `lib/slice/reference_access_test.py` | Synthetic grant, export and hook fixtures |
| `lib/slice/build_docs_test.py` | Build operating-doc consistency, context rule, reference guidance and size regressions; run by start selftest |
