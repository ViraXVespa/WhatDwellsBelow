# Tools: prove, gates, smokes and warnings

Status: protocol  
Read when: proving a change before a commit or push, running a gate, smoke or warning sweep, committing a Build slice, or a task file  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Read the last `RESULT` line, then `read_summary.py JOB` once; never raw logs.

## Jobs

- **Build slice prove (User PC):** `python tools/check_gd_load.py` (read every error) -> `python tools/run_build_gate.py --batch` (`--visual door.job` for a visual change) -> `python tools/commit_slice.py`. Red: one corrective edit, one re-run (`tools.md` rule 10).
- **Bot prove:** the BOT.md Prove list (`bot_status.py --bot --prove`, `check_script_cap.py --bot --git-changed`, `check_load_graph.py --bot`, `code_map.py check`, ...).
- **Docs or routing changed:** `check_load_graph.py`. Tool rows or doc paths: `check_tool_docs.py`, then `check_tool_docs.py --stale-refs`.
- **A tool changed:** `check_tool_cli.py --only STEM --smoke-run` (default: every uncommitted or unpushed tool).
- **Smokes:** PC `run_smokes.py --door D` (or `--job door.job`, `--phases 1 2`). Bot box `bot_smokes.py --phases 1,2,6` (or `--door D`); `bot_smokes.py --for FILE` names the covering phases without running.
- **Compile or import errors:** `check_gd_load.py` (`--files A.gd B.gd`, `--all`); editor import and script reload: `run_godot_import_check.py`.
- **Warnings before/after a change:** `bot_warnscan.py --save-baseline B --areas A1,A2`, change, then `bot_warnscan.py --non-leak-diff B --areas A1,A2`. In one gate call: `run_build_gate.py --batch --warnscan-baseline B --areas A1,A2`.
- **Release build safety:** `run_release_smoke.py` (`--pck DIR` / `--pck-debug DIR` on an export).
- **Task files:** `task.py list`, `task.py show ID`, `task.py new ID --owner build --title T --done-when D --resume R`, `task.py update ID --status S`, `task.py done ID`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `run_build_gate.py` | The one batch gate. `--batch`: editor import (restores `.import` churn) + `check_load_graph` + script-name check + `run_release_smoke.py --modes stripped` + `check_hub_bake`; `--visual JOB` adds the job's shot flows; `--warnscan-baseline B --areas ...` adds the non-leak diff; `--shot-gaps required\|advisory\|off`. A red result prints the RETRY prompt. Once per batch. Summary: `build-gate`. | BWD | `--help` | Y |
| `check_gd_load.py` | Compile check: loads each changed or untracked `.gd` (default vs the week branch; `--files A.gd ...`, `--all`, `--base REF`) inside the real project with its autoloads. Lists every failing file with Godot's error lines; imports first if `.godot` is missing. `--selftest`. Summary: `gd-load-check`. | D | `--help` | N |
| `run_godot_import_check.py` | Editor import / script-reload check. RESULT `clean=true|false`. Summary: `godot-import-check`. | WD | `--help` | N |
| `commit_slice.py` | Commit the slice after the gates: needs a passing `run_build_gate.py` summary newer than every change, else stops. `--gate-skipped WHY` (gate never ran) or `--red-gate LOGPATH` (ran red at Complete) commit with that noted. Leaves Godot-only `.import` churn uncommitted. Message from `_logs/commit-msg.txt` (`--message-file`). Never pushes. `--dry-run`, `--selftest`. | D | `--help` | N |
| `run_smokes.py` | Phase smokes on the PC (Bot box: `bot_smokes.py`): `--door D` / `--job door.job` pick the `routes.yaml` `smokes` phases, `--phases 1 2 6` by number. Prints `check_shot_gaps.py --changed --advisory` (the required gap check is in `run_build_gate.py`). Summary: `smokes`. | D | `--help` | N |
| `bot_smokes.py` | Headless smokes on the Linux box: `--phases 1,2,6`, or `--door` / `--job` for the `routes.yaml` `smokes` map; `--for FILE` prints the covering phases and warnscan areas and runs nothing; `--flows` adds the door's shot flows; `--release` adds `run_release_smoke.py`. Runs `check_shot_gaps.py --changed` as a gate (`--no-gaps` skips). `--doctor` / `--setup` check and fetch the pinned Godot. Pin, install, `.uid` import: BOT.md Smokes. | B | `--help` | Y |
| `run_release_smoke.py` | Release-mode proof (`debug.md`): scratch project copy runs title, hub, dungeon with `--wdb-release` and with `scripts/debug/` deleted (no debug node, no script error); `--pck DIR` / `--pck-debug DIR` check an export PCK for `scripts/debug/`. Wired: `bot_smokes.py --release` (both modes, ~20 s) and `run_build_gate.py --batch` (stripped, ~10 s). Summary: `release-smoke`. | BD | `--help` | Y |
| `bot_warnscan.py` | Warning sweep by area (`--list`; leak / run-fail areas are rechecked and tagged stable / flaky). Before/after: `--save-baseline B` then `--non-leak-diff B` with the same `--areas` (exit 1 only on NEW). `--changed` is the quick run; `--renderer real\|both` adds box-display runs; reports `--out`, `--out-md`, `--out-json`. Procedure: BOT.md Smokes. | B | `--help` | Y |
| `bot_status.py` | Bot punch list (reuse brief, open opt tasks); `--prove` adds the Bot checks. Bot/CI only; elsewhere it prints "not run". | B | `--help` | Y |
| `check_script_cap.py` | Duplicate script-name check (`dupes=`): `--git-changed`, `--path`. The Bot's own checks run only with `--bot` (`BOT.md`). | BWD | `--help` | Y |
| `check_load_graph.py` | Doc routing vs `design/routes.yaml` (PASS/FAIL, no summary): `smokes`/`shot_flows` keys, phases and flow files; the Bot adds boot budgets (`--bot`) | BWD | `--help` | Y |
| `code_map.py` | Code map: `check` (live `.gd` vs `design/code-map.md` ticks; exits 1 on new UNMAPPED or missing), `row --path P` (the one row for a file), `patch --system S --add P [--remove P] [--rename OLD=NEW]`, `sweep [--system NAME]` (coverage checklist). Summaries: `code-map-check` / `-row` / `-patch`. | BD | `--help` | Y |
| `check_tool_cli.py` | CLI contract check over `tools/` (Contract in `tools.md`): help text, `--out` names, RESULT last, line budget. Default: tools with uncommitted or unpushed changes; `--only STEM`, `--full`; `--smoke-run` runs the SMOKE cases in a throwaway copy (`--full --smoke-run` about a minute). | BWD | `--help` | Y |
| `check_tool_docs.py` | Tool catalog gate: every `tools/` file has exactly one row in `design/tools-*.md` that matches `bot_allow.txt`; `--stale-refs` lists dead doc paths and members (`--narration` adds stale wording). Summary: `tool-docs` / `stale-refs`. | BD | `--help` | Y |
| `check_hub_bake.py` | Committed `hub_light.png` pixel hash vs `HUB_BAKE_STAMP` in `hub_bake.gd` (the game crashes on a mismatch), and `ground_wear.png` vs `GROUND_WEAR_STAMP`. Run by `run_build_gate.py --batch`. Summary: `hub-bake`. | BWD | `--help` | Y |
| `bot_load_audit.py` | Audit of one Grok Build session's reads before its first ask (`--session DIR` / `--file chat_history.jsonl`, `--selftest`). Bot/CI only; elsewhere it prints "not run". | B | `--help` | Y |
| `task.py` | Task files in `design/tasks/` for Web, Build and Bot: `list`, `show`, `new` (`opt-next` for a Bot opt item), `update`, `done`, `index`, `check`. Summary: `task`. | BWD | `--help` | Y |
| `bot_allow.txt` | Bot scope: the paths the Bot may change; read by CI. Deny lines first. | BWD | - | Y |
