# Tools: prove, gates, smokes and warnings

Status: protocol  
Read when: proving a change before a commit or push, running a gate, smoke or warning sweep, committing a Build slice, or a task file  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. Read the last `RESULT` line, then `session.py summary JOB` once; never raw logs.

Entries here: `gate.py`, `slice.py`, `bot_status.py`, `check.py`, `docs.py`, `bake.py`; their code: `tools/lib/bake/`, `tools/lib/checks/`, `tools/lib/docs/`, `tools/lib/gates/`, `tools/lib/slice/`.

## Jobs

- **Build slice prove (User PC):** `python tools/gate.py gd-load` (read every error) -> `python tools/gate.py build --batch` (`--visual door.job` for a visual change) -> `python tools/slice.py commit`. Red: one corrective edit, one re-run (`tools.md` rule 10).
- **Bot prove:** `check.py prove` (BOT.md Prove).
- **Docs or routing changed:** `check.py load-graph`. Tool rows or doc paths: `check.py tool-docs`, then `check.py tool-docs --stale-refs`.
- **A tool changed:** `check.py tool-cli --only STEM --smoke-run` (default: every uncommitted or unpushed tool).
- **Smokes:** PC `gate.py smokes --door D` (or `--job door.job`, `--phases 1 2`). Bot box `gate.py bot-smokes --phases 1,2,6` (or `--door D`); `gate.py bot-smokes --for FILE` names the covering phases without running.
- **Compile or import errors:** `gate.py gd-load` (`--files A.gd B.gd`, `--all`); editor import and script reload: `gate.py import`.
- **Warnings before/after a change:** `gate.py warnscan --save-baseline B --areas A1,A2`, change, then `gate.py warnscan --non-leak-diff B --areas A1,A2`. In one gate call: `gate.py build --batch --warnscan-baseline B --areas A1,A2`.
- **Release build safety:** `gate.py release` (`--pck DIR` / `--pck-debug DIR` on an export).
- **Task files:** `docs.py task list`, `docs.py task show ID`, `docs.py task new ID --owner build --title T --done-when D --resume R`, `docs.py task update ID --status S`, `docs.py task done ID`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `gate.py build` | The one batch gate. `--batch`: editor import (restores `.import` churn) + `check_load_graph` + script-name check + `gate.py release --modes stripped` + `check_hub_bake`; `--visual JOB` adds the job's shot flows; `--warnscan-baseline B --areas ...` adds the non-leak diff; `--shot-gaps required\|advisory\|off`. A red result prints the RETRY prompt on a Build branch only. Once per batch. Summary: `build-gate`. | BWD | `--help` | Y |
| `gate.py gd-load` | Compile check: loads each changed or untracked `.gd` (default vs the week branch; `--files A.gd ...`, `--all`, `--base REF`) inside the real project with its autoloads. Lists every failing file with Godot's error lines; imports first if `.godot` is missing. `--selftest`. Summary: `gd-load-check`. | D | `--help` | N |
| `gate.py import` | Editor import / script-reload check, then the static compile of every live .gd and scene (`--import` alone parses no script; `--no-static` skips). RESULT `clean=true|false`. Summary: `godot-import-check`. | WD | `--help` | N |
| `slice.py commit` | Commit the slice after the gates: needs a passing `gate.py build` summary newer than every change, else stops. `--gate-skipped WHY` (gate never ran) or `--red-gate LOGPATH` (ran red at Complete) commit with that noted. Leaves Godot-only `.import` churn uncommitted. Message from `_logs/commit-msg.txt` (`--message-file`). Never pushes. `--dry-run`, `--selftest`. | D | `--help` | N |
| `gate.py smokes` | Phase smokes on the PC (Bot box: `gate.py bot-smokes`): `--door D` / `--job door.job` pick the `routes.yaml` `smokes` phases, `--phases 1 2 6` by number. Prints `shots.py gaps --changed --advisory` (the required gap check is in `gate.py build`). Summary: `smokes`. | D | `--help` | N |
| `gate.py bot-smokes` | Headless smokes on the Linux box: `--phases 1,2,6`, or `--door` / `--job` for the `routes.yaml` `smokes` map; `--for FILE` prints the covering phases and warnscan areas and runs nothing; `--flows` adds the door's shot flows; `--release` adds `gate.py release`. Runs `shots.py gaps --changed` as a gate (`--no-gaps` skips) and, with phases, a static compile of every script and scene that fails on errors only (`--no-static` skips); a phase fails on SCRIPT ERROR, `SMOKE FAIL` or any `P<n>: ... ok=false` flag and prints its first errors. `--doctor` / `--setup` check and fetch the pinned Godot. Pin, install, `.uid` import: BOT.md Smokes. | B | `--help` | Y |
| `gate.py release` | Release-mode proof (`debug.md`): scratch project copy runs title, hub, dungeon with `--wdb-release` and with `scripts/debug/` deleted (no script error, no node in the tree running a `scripts/debug/` script; `--selftest` plants one); `--pck DIR` / `--pck-debug DIR` check an export PCK for `scripts/debug/`. Wired: `gate.py bot-smokes --release` (both modes, ~20 s) and `gate.py build --batch` (stripped, ~10 s). Summary: `release-smoke`. | BD | `--help` | Y |
| `gate.py warnscan` | Warning sweep by area (`--list`; leak / run-fail areas are rechecked and tagged stable / flaky). Before/after: `--save-baseline B` then `--non-leak-diff B` with the same `--areas` (exit 1 only on NEW; a newly leaking area is NEW, rows from areas not run are not FIXED). `--changed` is the quick run (base `repo_lib.diff_base`); static compiles every live .gd (`scripts/`, `tools/data/`) and scene; `--renderer real\|both` adds box-display runs; reports `--out`, `--out-md`, `--out-json`. Procedure: BOT.md Smokes. | B | `--help` | Y |
| `bot_status.py` | Bot punch list (reuse brief, open opt tasks); `--prove` adds the Bot checks (allowlist on uncommitted and unpushed paths), diff drift and textsize --gate when UI scripts changed. Bot/CI only; elsewhere it prints "not run". | B | `--help` | Y |
| `check.py script-cap` | Duplicate script-name check, any casing (`dupes=`), and `.gd` outside `scripts/` (`stray=`; `tools/`, `addons/` excepted): `--git-changed`, `--path`. The Bot's own checks run only with `--bot` (`BOT.md`). | BWD | `--help` | Y |
| `check.py load-graph` | Doc routing vs `design/routes.yaml` (PASS/FAIL, no summary): `smokes`/`shot_flows` keys, phases and flow files; the Bot adds boot budgets (`--bot`) | BWD | `--help` | Y |
| `docs.py code-map` | Code map: `check` (live `.gd` vs `design/code-map.md` ticks; exits 1 on new UNMAPPED or missing), `row --path P` (the one row for a file), `patch --system S --add P [--remove P] [--rename OLD=NEW]`, `sweep [--system NAME]` (coverage checklist). Summaries: `code-map-check` / `-row` / `-patch`. | BD | `--help` | Y |
| `check.py tool-cli` | CLI contract check over `tools/` (Contract in `tools.md`): help text, `--out` names, RESULT last, line budget. Default: tools with uncommitted or unpushed changes; `--only STEM`, `--full`; `--smoke-run` runs the SMOKE cases in a throwaway copy (`--full --smoke-run` about a minute). | BWD | `--help` | Y |
| `check.py tool-docs` | Tool catalog gate: every `tools/` file has exactly one row in `design/tools-*.md` that matches `bot_allow.txt`; `--stale-refs` lists dead doc paths and members, plus repo-wide tool commands with dead flags, subcommands or paths, and BRANCH rows: a hand-rolled branch test or Build-only retry text a shared tool can print off Build (`lib/checks/stale_cmds.py`; `--narration` adds stale wording). Summary: `tool-docs` / `stale-refs`. | BD | `--help` | Y |
| `check.py prove` | Exploratory prove: diff vs merge-base(origin/main) plus uncommitted, the files that name each changed file, the checks those paths need (`data/prove_rules.json`; selftests and smoke phases built in), each printed with why; FAILs on DRIFT (removed path, subcommand, flag, function, top-level const/var/signal, node or data key still named), CLAIM (new comment about an untouched tool) and STALE (untouched line repeating a changed docstring); comment-only `.gd` skips Godot checks. `--plan`, `--all`, `--base`/`--head` replay; `--base @{u}` per cluster. Summary: `prove`. | B | `--help` | Y |
| `bake.py check` | Committed `hub_light.png` pixel hash vs `HUB_BAKE_STAMP` in `hub_bake.gd` (the game crashes on a mismatch), and `ground_wear.png` vs `GROUND_WEAR_STAMP`. Run by `gate.py build --batch`. Summary: `hub-bake`. | BWD | `--help` | Y |
| `check.py load-audit` | Audit of one Grok Build session's reads before its first ask (`--session DIR` / `--file chat_history.jsonl`, `--selftest`). Bot/CI only; elsewhere it prints "not run". | B | `--help` | Y |
| `docs.py task` | Task files in `design/tasks/` for Web, Build and Bot: `list`, `show`, `new` (`opt-next` for a Bot opt item), `update`, `done`, `index`, `check`. Summary: `task`. | BWD | `--help` | Y |

## Libs and data

No CLI of their own; new code goes into the owner (`tools.md` rule 6).

| File (under `tools/`) | Owns |
|---|---|
| `lib/checks/prove_graph.py`, `lib/checks/prove_selftest.py` | `check.py prove` change set, reference graph, drift; its selftest repo |
| `bot_allow.txt` | Bot scope: the paths the Bot may change; read by CI. Deny lines first. |
| `data/release_smoke/` | `release_drive.gd`: the autoload `gate.py release` adds to its scratch project copy (never in the game) |
