# Tools catalog

Status: protocol  
Read when: running, adding, or documenting a tool (Bot, web/chat, or Build)  

Single source for what each tool is, which surface runs it, and its gotchas. Siblings: `tools-lint.md` (inventory, dupe, dead code, doc edits), `tools-build.md` (Windows runners, release), `tools-media.md` (media pipeline), `pc-offload.md` (Build-only rules). `check_tool_docs.py` keeps the tables in step with `tools/`.

Surf: **B** Bot (Linux VM), **W** web/chat, **D** Build (User PC). **A**: Y if the Bot may run the tool (A=N is fine either way).

## Rules

1. **Bot scope.** The Bot runs only tools marked `A=Y` here and changes only the paths its scope allows (`BOT.md`; CI `bot-gate.yml`).
2. **Platform.** Every tool is Python: `python3 tools/X.py` (Windows PC: `python`). Windows and Godot rules: `pc-offload.md`.
3. **Usage truth.** `python3 tools/X.py --help` for every CLI tool; `*_lib.py` files have a module docstring. Docs do not repeat flags.
4. **Summaries.** Every run writes its own `_logs/<job>/<stamp>-<job>.txt` (gitignored, never overwritten) and lists it in that folder's `index.txt`, newest first; the last 20 runs are kept. `read_summary.py --job <name>` prints the index, then the newest. Worktrees have their own `_logs/`, cleared weekly. Read the final `RESULT` line, then the summary once, not raw logs or script bodies. Lookup tools (`list_xref.py`, `code_map.py row`, `tunables.py get`, `list_route.py`) print their rows.
5. **New tool.** Build and Web create a tool on their own when it would reasonably help future tasks (not a one-off), then tell the User afterward: name, command, what it saves. Add its row here, then run `check_tool_docs.py` and `check_tool_cli.py`. The Bot adds a tool only when the User approved it this session.
6. **Duplicates are shims.** A renamed or folded tool stays a shim (docstring starts `"""Shim`) for one release. New logic goes in the owner: `agent_log` (run helpers), `repo_lib` (git, version), `gd_lib` (`.gd` funcs), `md_format_lib` (text write), `doc_patch` (doc edits).
7. **Tools, not scratches.** Would you need it again? Update the tool or add one; a scratch is only for a niche one-off, in temp. Web doc edits: `doc_patch.py` CLI (`doc-library.md`). A proof with no tool: extend the library in the same job (`prove.md`).
8. **Fix the tool.** A tool that does not work intuitively is designed wrong: fix it, do not work around it.
9. **Rough edges (end of every task).** List the rough edges you hit (a guessed flag, a re-run, a scratch, a doc that lied) and fix them in the same change when you can, else name them in the report.
10. **No loops (gates and fixes).** One copy of the rule; entry docs, jobs and skills point here.
    - Batch all same-kind fixes into one edit pass (every rename, every cast, every path), then run the gates once for the batch, not after each small edit.
    - No prove or re-verify cycles on unchanged results. If a check reports nothing new, stop.
    - **Red prove: one diagnosis and one fix per retry.** Diagnose once, fix once (batched), rerun once. Still red: stop and report the log path; do not loop. This is the only statement of the rule; Build's retry session is in `build-job-cycle.md`.
    - Cap: at most 2 gate reruns per task (a full sweep such as `bot_warnscan` or `bot_smokes` counts as one). Anything not trivial becomes a question with options.

11. **Python image deps.** `pip install -r tools/requirements.txt` (Pillow, numpy; opencv-python-headless optional). Shared image code is `tools/imglib/` (`tools-media.md`).

## Contract (enforced by `check_tool_cli.py`)

- Shebang `#!/usr/bin/env python3`, `argparse` (`agent_log.std_parser`), a non-mutating `--help`, ASCII output.
- Ops tools take `--root`, writers take `--dry-run`, every `std_parser` tool takes `--json` (stdout is then one JSON object). Errors go to stderr as `error: ...`. Exit 0 ok, 1 findings, 2 usage.
- Last line is `RESULT <PASS|FAIL|INFO> k=v ... summary=<repo-relative path>`; no `Summary -> <abs>` line. Exempt: printers and `wdb_scratch_server`.
- Read and write text through `md_format_lib` (BOM and line endings kept). Paths printed are repo-relative POSIX.

## Run when

- **Bot:** `BOT.md` (boot, prove, smokes, Build-doc ban).
- **Web/chat:** docs go through `doc_patch.py` (`doc-library.md`); `check_load_graph.py`; `run_shots.py --mode web`; scripted flows `run_shot_flow.py` (`shot-tool.md`). Godot runners are the User's (`web-session.md`).
- **Build (User PC):** `file_stat.py` to measure (not `python -c`), `list_xref.py`, `list_changed.py`; `run_build_gate.py` after a `.gd` slice; `list_changed.py --history` when a doc and its code disagree (`prove.md`); `web_perf.py` after a fresh `export_web.py --out DIR` (advisory, `tools-build.md`); `code_map.py patch` for one row; `bot_opt.py` to park opt items. Runner rules: `pc-offload.md`.

## Catalog: shared and Bot tools

### Gates and Bot flows

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `bot_status.py` | Bot punch list (reuse brief, opt queue); `--prove` adds the Bot checks. Bot/CI only; elsewhere it prints "not run". | B | `--help` | Y |
| `check_script_cap.py` | Duplicate script-name check (`dupes=`): `--git-changed`, `--path`. The Bot's own checks run only with `--bot` (`BOT.md`). | BWD | `--help` | Y |
| `check_load_graph.py` | Doc routing vs `design/routes.yaml` (PASS/FAIL, no summary): `smokes`/`shot_flows` keys, phases and flow files; the Bot adds boot budgets (`--bot`) | BWD | `--help` | Y |
| `code_map.py` | Code map: `check` (live `.gd` vs `design/code-map.md` ticks; exits 1 on new UNMAPPED or missing, older UNMAPPED are expected), `row --path P`, `patch --system S ...`. | BD | `--help` | Y |
| `check_code_map.py` | Shim -> `code_map.py check`, one release | BD | `--help` | Y |
| `bot_smokes.py` | Headless smokes on the Linux VM (`--phases`, or `--door` / `--job` for the `routes.yaml` `smokes` map; `--for FILE` prints the covering phases and warnscan areas, runs nothing). Also runs `check_shot_gaps.py --changed` as a required gate (`--no-gaps` skips). Pin, install, `.uid` import: BOT.md Smokes. | B | `--help` | Y |
| `bot_warnscan.py` | Warning sweep by area (leak / run-fail areas are rechecked and tagged stable / flaky). `--save-baseline` before, `--non-leak-diff` after (same `--areas`); `--changed` is the quick run; `--renderer real\|both` adds box-display runs. Procedure: BOT.md Smokes. | B | `--help` | Y |
| `run_build_gate.py` | One batch gate: editor import (restores `assets/*.import` churn), `--batch` (import + `check_load_graph` + script-name check + `check_hub_bake`), `--warnscan-baseline B` adds the non-leak diff. A red result prints the RETRY prompt. Once per batch. Summary: `build-gate`. | BWD | `--help` | Y |
| `bot_warnscan_lib.py` | Log parser for `bot_warnscan.py` | B | module docstring (no `--help`) | Y |
| `bot_opt.py` | Opt queue: `--list`, `--id`, `--status opt-N=done`, `--add`, `--remove`. Never hand-edit the queue block. Summary: `bot-opt`. | BD | `--help` | Y |
| `bot_allow.txt` | Bot scope: the paths the Bot may change; read by CI. Deny lines first. | BWD | - | Y |
| `check_tool_cli.py` | CLI contract check over `tools/` (see Contract above); `--smoke-run` runs every tool in a throwaway copy. | BWD | `--help` | Y |
| `check_tool_docs.py` | Catalog check: every `tools/` file has a row, `A=Y` rows are allowed by `bot_allow.txt` (glob-aware), rows name real files. `--stale-refs` fails on dead paths, identifiers and Godot version drift; `--narration` is advisory. | BWD | `--help` | Y |

### Split, code map, doc edits, inventory and lint

`tools-lint.md` (same columns) lists dupe inventory, split, `doc_patch`, `list_route` and the shared libs (`repo_lib`, `gd_lib`, `agent_log`, `run_log_lib`, `retry_lib`, `bot_gate_lib`).
