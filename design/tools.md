# Tools catalog

Status: binding  
Read when: running, adding, or documenting a tool (Bot, web/chat, or Build)  

Single source for what each tool is, which surface runs it, and its gotchas. Inventory, size, dupe and dead-code tools: `tools-lint.md`. Windows runners and release tools: `tools-build.md` (`.ps1` twins: `tools-shims.md`). Media pipeline: `tools-media.md`. Build-only rules (Length, here-strings, locks): `pc-offload.md`. `python3 tools/check_tool_docs.py` keeps these tables in step with `tools/` and `tools/bot_allow.txt`.

Surf: **B** Bot (Linux VM), **W** web/chat, **D** Build (User PC). **A**: Y if the Bot may run the tool (its `tools/` path must be allowed by `tools/bot_allow.txt`, globs such as `tools/*` count; A=N is fine either way).

## Rules

1. **Allowlist.** `tools/bot_allow.txt` is the authority for the Bot: it runs only tools marked `A=Y` here and changes only allowlisted paths (CI `bot-gate.yml` and `bot_status.py --prove` read it). 
2. **Platform.** Every tool is Python: `python3 tools/X.py` (Windows PC: `python`). A `.ps1` is a one-release shim that forwards its arguments to the `.py` twin; old `-OverKb` and new `--over-kb` spellings both work. Quoting and Godot rules for Windows: `pc-offload.md`.
3. **Usage truth.** `python3 tools/X.py --help` for every CLI tool (`check_tool_cli.py` keeps that true); `*_lib.py` files have a module docstring. Docs do not repeat flags.
4. **Summaries.** Runners write `_logs/<job>/summary.txt` (gitignored, one dir per job). Read the final `RESULT` line, then the summary once, not raw logs or script bodies. Lookups (`list_xref.py`, `code_map.py row`, `tunables.py get`, `list_route.py`) print their rows on stdout: no second read.
5. **New tool.** Propose first (Build: through `ask_user_question`; name, command, what it saves) and implement after approval. Add its row here (and the allowlist line if the Bot may run it), then run `check_tool_docs.py` and `check_tool_cli.py`.
6. **Duplicates are shims.** A renamed or folded tool stays as a shim (docstring starts `"""Shim`) for one release, then goes. New logic goes in the owner: `agent_log` (run helpers), `repo_lib` (git, allowlist, version), `gd_lib` (`.gd` funcs), `md_format_lib` (text write), `doc_patch` (doc edits).
7. **Tools, not scratches.** Would you need it again? Update the tool or propose a new one; a scratch is only for a niche one-off, in temp. Web doc edits: `doc_patch.py` CLI (`doc-library.md`).
8. **Fix the tool.** A tool that does not work intuitively is designed wrong: fix it, do not work around it.
9. **Rough edges (end of every task).** List the rough edges you hit (a guessed flag, output re-run, a scratch you wrote, a doc that lied) and fix them in the same PR when the allowlist and task allow, else name them in the report. This is the one copy of the rule; the Bot, Build and web entry docs point here.
10. **No loops (gates and fixes).** One copy of the rule; entry docs, jobs and skills point here.
    - Batch all same-kind fixes into one edit pass (every rename, every cast, every path), then run the gates once for the batch, not after each small edit.
    - No prove or re-verify cycles on unchanged results. If a check reports nothing new, stop.
    - A failed gate gets one diagnosis, then one batched fix, then one rerun. Still failing: stop and report to the User with the log path; do not loop.
    - Cap: at most 2 gate reruns per task (a full sweep such as `bot_warnscan` or `bot_smokes` counts as one). Anything not trivial becomes a question with options, not more iterations.

## Contract (enforced by `check_tool_cli.py`)

- Shebang `#!/usr/bin/env python3`, `argparse` (`agent_log.std_parser`), a working non-mutating `--help`, ASCII output.
- Ops tools take `--root`, writers take `--dry-run`, every `std_parser` tool takes `--json` (stdout is then one JSON object). Errors go to stderr as `error: ...`. Exit 0 ok, 1 findings, 2 usage.
- Last line is `RESULT <PASS|FAIL|INFO> k=v ... summary=<repo-relative path>`; no `Summary -> <abs>` line prints (RESULT carries the relative `summary=`; `agent_log.finish(legacy=True)` restores it for a payload printer). Exempt: printers (their stdout is the payload) and `wdb_scratch_server`.
- Read and write text through `md_format_lib` (BOM and line endings kept). Paths printed are repo-relative POSIX.

## Run when

- **Bot:** `BOT.md` (boot, prove, smokes, Build-doc ban).
- **Web/chat:** documentation slices go through the `doc_patch.py` CLI or import (`doc-library.md`); `check_load_graph.py`; `run_shots.py --mode web` (prints its RESULT line, no scratch needed); scripted flows `run_shot_flow.py` (`shot-tool.md`). Godot runners are the User's: `web-session.md` names them.
- **Build (User PC):** `file_stat.py` to measure (not `python -c`), `list_xref.py`, `list_changed.py`, `list_oversize_scripts.py`; `run_build_gate.py` after a `.gd` slice; `web_perf.py --site DIR --flow all --baseline tools/web-perf-baseline.json` after a fresh `export_web.py --out DIR` (advisory, `tools-build.md`); `code_map.py patch` for one row; `bot_opt.py` to park opt items. Runner rules: `pc-offload.md`. No full-repo Bot size sweep.

## Catalog: shared and Bot tools

### Gates and Bot flows

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `bot_status.py` | Punch list: over-10KB/5KB, reuse brief, opt queue; `--prove` = script cap + allowlist + load graph; `--sweep` lists 5-10KB | BD | `--help` | Y |
| `check_script_cap.py` | Script size cap + duplicate-basename check (`dupes=`): `--git-changed`, `--path`, `--over-kb 5` for the sweep | BWD | `--help` | Y |
| `check_load_graph.py` | Doc routing vs `design/routes.yaml` (prints PASS/FAIL, no summary); also FAILs a boot file over its `boot_bytes` budget | BWD | `--help` | Y |
| `code_map.py` | Code map: `check` (live `.gd` vs `design/code-map.md` ticks; exits 1 on new UNMAPPED or missing, older UNMAPPED are expected), `row --path P`, `patch --system S ...`. Summaries: `code-map-*`. | BD | `--help` | Y |
| `check_code_map.py` | Shim -> `code_map.py check`, one release | BD | `--help` | Y |
| `bot_smokes.py` | Headless phase smokes on the Linux VM (`--phases 1,2,6`, or `--door` / `--job` for the `routes.yaml` `smokes` map; `--for FILE` prints the phases and warnscan areas covering a script, runs nothing). Also runs `check_shot_gaps.py --changed` as a required gate (`--no-gaps` skips). Pin, install and `.uid` import: BOT.md Smokes. | B | `--help` | Y |
| `bot_warnscan.py` | Warning sweep by area; `--save-baseline P` before, `--non-leak-diff P` after (same `--areas`); `--findings-md P` writes the findings grouped by kind with counts. Cheap by default (1 run/area, `--jobs 3` parallel with per-run user://, whole sweep ~10 s headless, ~1 min with `--renderer both`; leak/run-fail areas get `--recheck 2` runs and are tagged stable/flaky). Quick: `--changed [BASE]` = static + areas for changed paths. `--renderer real\|both` adds the box display runs (`@gui`; xvfb V-Sync warning is kind env-artifact, never fails). Procedure: BOT.md Smokes. | B | `--help` | Y |
| `run_build_gate.py` | One batch gate: editor import (restores `assets/*.import` churn), `--script-cap` (changed) or `--batch` (import + `check_load_graph` + whole-tree script cap and dupes), `--warnscan-baseline B [--areas A]` adds the non-leak diff. Shot gaps: `--shot-gaps required|advisory|off` (default `routes.yaml` `shot_gaps`: required with `--batch`, advisory otherwise). Run once per batch (rule 10). Summary: `build-gate`. | BWD | `--help` | Y |
| `bot_warnscan_lib.py` | Log parser for `bot_warnscan.py` | B | module docstring (no `--help`) | Y |
| `bot_opt.py` | Opt queue: `--list`, `--id`, `--status opt-N=done`, `--add`, `--remove`. Never hand-edit the queue block. Summary: `bot-opt`. | BD | `--help` | Y |
| `bot_allow.txt` | Allowlist: the paths the Bot may change; read by CI and `bot_status --prove`. Deny lines first. Authority for Bot scope. | BWD | - | Y |
| `check_tool_cli.py` | CLI contract check over `tools/` (see Contract above) plus the `.ps1` shim check; `--smoke-run` runs every tool in a throwaway copy (crash, noise, `--json`, dry-run purity; ~1 min). Run after adding or editing a tool. | BWD | `--help` | Y |
| `check_tool_docs.py` | Catalog check: every `tools/` file has a row, `A=Y` rows are allowed by `bot_allow.txt` (glob-aware), rows name real files. Run it after adding or renaming a tool. `--stale-refs` scans docs, root md and the four workflow skills for dead backticked paths and `Class.member` names (fails; gitignored paths such as `tools/anim_review/*` are skipped); `--narration` adds history-sounding lines (advisory). Run both on every doc sweep | BWD | `--help` | Y |

### Split, code map, doc edits, inventory and lint

These tools are cataloged in `tools-lint.md` (same columns): size and dupe inventory, `split_funcs`, `facade_requal`, `doc_patch`, `patch_code_map`, `list_route`, and the shared libs `repo_lib`, `gd_lib`, `agent_log`.
