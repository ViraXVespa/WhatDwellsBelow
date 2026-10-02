# Tools catalog

Status: binding  
Read when: running, adding, or documenting a tool (Bot, web/chat, or Build)  

Single source for what each tool is, which surface runs it, and its gotchas. Other docs say "run X at step N" and point here. Inventory, size, dupe and dead-code tools: `tools-lint.md`. Windows runners and release tools: `tools-build.md`. Media pipeline: `tools-media.md`. Build-only rules (Length, here-strings, locks): `pc-offload.md`. `python3 tools/check_tool_docs.py` keeps these tables in step with `tools/` and `tools/bot_allow.txt`.

Surf: **B** Bot (Linux VM), **W** web/chat, **D** Build (User PC). **A**: Y if the Bot may run the tool (its `tools/` path must be allowed by `tools/bot_allow.txt`, globs such as `tools/*` count; A=N is fine either way).

## Rules

1. **Allowlist.** `tools/bot_allow.txt` is the authority for the Bot: it runs only tools marked `A=Y` here and changes only allowlisted paths (CI `bot-gate.yml` and `bot_status.py --prove` read it). Anything else is for the User, Build or web.
2. **Platform.** Every tool is Python: `python3 tools/X.py` (Windows PC: `python`). A `.ps1` is a one-release shim that forwards its arguments to the `.py` twin; old `-OverKb` and new `--over-kb` spellings both work. Quoting and Godot rules for Windows: `pc-offload.md`.
3. **Usage truth.** `python3 tools/X.py --help` for every CLI tool (`check_tool_cli.py` keeps that true); `*_lib.py` files have a module docstring. Docs do not repeat flags.
4. **Summaries.** Runners write `_logs/<job>/summary.txt` (gitignored, one dir per job; no session keys). Read the final `RESULT` line, then the summary once, not raw logs or script bodies.
5. **New tool.** Propose first (name, command, what it saves) and implement after approval. Add its row here (and the allowlist line if the Bot may run it), then run `check_tool_docs.py` and `check_tool_cli.py`.
6. **Duplicates are shims.** A renamed or folded tool stays as a shim (docstring starts `"""Shim`) for one release, then goes. New logic goes in the owner: `agent_log` (run helpers), `repo_lib` (git, allowlist, version), `gd_lib` (`.gd` funcs), `md_format_lib` (text write), `doc_patch` (doc edits).
7. **Tools, not scratches.** If you would need it again, update the tool or propose a new one. A scratch is for a niche one-off, in temp. Web doc edits: `doc_patch.py` CLI (`doc-library.md`).
8. **Fix the tool.** If a tool does not work intuitively, it is designed wrong: fix it (or propose the fix), do not work around it.
9. **Rough edges (end of every task).** List the rough edges you hit (a guessed flag, output re-run, a scratch you wrote, a doc that lied) and fix them in the same PR when the allowlist and task allow, else name them in the report. This is the one copy of the rule; the Bot, Build and web entry docs point here.
10. **No loops (gates and fixes).** One copy of the rule; entry docs, jobs and skills point here.
    - Batch all same-kind fixes into one edit pass (every rename, every cast, every path), then run the gates once for the batch, not after each small edit.
    - No prove or re-verify cycles on unchanged results. If a check reports nothing new, stop.
    - A failed gate gets one diagnosis, then one batched fix, then one rerun. Still failing: stop and report to the User with the log path; do not loop.
    - Cap: at most 2 gate reruns per task (a full sweep such as `bot_warnscan` or `bot_smokes` counts as one). Anything not trivial becomes a question with options, not more iterations.

## Contract (enforced by `check_tool_cli.py`)

- Shebang `#!/usr/bin/env python3`, `argparse` (`agent_log.std_parser`), a working non-mutating `--help`, ASCII output.
- Ops tools take `--root`, writers take `--dry-run`, reports may take `--json`. Errors go to stderr as `error: ...`. Exit 0 ok, 1 findings, 2 usage.
- Last line is `RESULT <PASS|FAIL|INFO> k=v ... summary=<repo-relative path>`; a `Summary -> <abs>` line also prints unless the runner opts out (`legacy=False` in `agent_log.finish`). Exempt: printers (their stdout is the payload) and `wdb_scratch_server`.
- Read and write text through `md_format_lib` (BOM and line endings kept). Paths printed are repo-relative POSIX.

## Run when

- **Bot:** boot with `bot_status.py`, then the one flow doc from `BOT.md` (size, extract, reuse, relocate, docs, opt). Prove and smokes: `BOT.md` (single copy). Never open the Build docs (`pc-offload.md`, `tools-build.md`, `tools-media.md`) or Imagine/I2V skills.
- **Web/chat:** documentation slices go through the `doc_patch.py` CLI or import (`doc-library.md`); `check_load_graph.py`; `run_shots.py --mode web` (prints its RESULT line, no scratch needed); scripted flows `run_shot_flow.py` (`shot-tool.md`). Godot runners are the User's: `web-session.md` names them.
- **Build (User PC):** measure with `file_stat.py` (not `python -c`), `list_xref.py`, `list_changed.py`, `list_oversize_scripts.py`; after a `.gd` slice `run_build_gate.py`; edit one code-map row with `code_map.py patch`; park opt items with `bot_opt.py`. Runner rules: `pc-offload.md`. Do not run a full-repo Bot size sweep.

## Catalog: shared and Bot tools

### Gates and Bot flows

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `bot_status.py` | Punch list: over-10KB/5KB, reuse brief, opt queue; `--prove` = script cap + allowlist + load graph; `--sweep` lists 5-10KB | BD | `--help` | Y |
| `check_script_cap.py` | Script size cap + duplicate-basename check (`dupes=`): `--git-changed`, `--path`, `--over-kb 5` for the sweep | BWD | `--help` | Y |
| `check_load_graph.py` | Doc routing vs `design/routes.yaml` (prints PASS/FAIL, no summary) | BWD | `--help` | Y |
| `code_map.py` | Code map: `check` (live `.gd` vs `design/code-map.md` ticks; exits 1 on new UNMAPPED or missing, older UNMAPPED are expected), `row --path P`, `patch --system S --add/--remove/--rename`. Summaries: `code-map-check`, `code-map-row`, `code-map-patch`. | BD | `--help` | Y |
| `check_code_map.py` | Shim -> `code_map.py check`, one release | BD | `--help` | Y |
| `bot_smokes.py` | Headless phase smokes on the Linux VM (`--phases 1,2,6`, or `--door` / `--job` for the `routes.yaml` `smokes` map). Also runs `check_shot_gaps.py --changed` as a required gate (`--no-gaps` skips). Pin, install and `.uid` import: BOT.md Smokes. | B | `--help` | Y |
| `bot_warnscan.py` | Warning sweep by area; `--save-baseline P` before, `--non-leak-diff P` after (same `--areas`); `--findings-md P` writes the findings grouped by kind with counts. Procedure: BOT.md Smokes. | B | `--help` | Y |
| `run_build_gate.py` | One batch gate: editor import (restores `assets/*.import` churn), `--script-cap` (changed) or `--batch` (import + `check_load_graph` + whole-tree script cap and dupes), `--warnscan-baseline B [--areas A]` adds the non-leak diff. Shot gaps: `--shot-gaps required|advisory|off` (default `routes.yaml` `shot_gaps`: required with `--batch`, advisory otherwise). Run once per batch (rule 10). Summary: `build-gate`. | BWD | `--help` | Y |
| `bot_warnscan_lib.py` | Log parser for `bot_warnscan.py` | B | module docstring (no `--help`) | Y |
| `bot_opt.py` | Opt queue: `--list`, `--id`, `--status opt-N=done`, `--add`, `--remove`. Never hand-edit the queue block. Summary: `bot-opt`. | BD | `--help` | Y |
| `bot_allow.txt` | Allowlist: the paths the Bot may change; read by CI and `bot_status --prove`. Deny lines first. Authority for Bot scope. | BWD | - | Y |
| `check_tool_cli.py` | CLI contract check over `tools/` (see Contract above) plus the `.ps1` shim check. Run after adding or editing a tool. | BWD | `--help` | Y |
| `check_tool_docs.py` | Catalog check: every `tools/` file has a row, `A=Y` rows are allowed by `bot_allow.txt` (glob-aware), rows name real files. Run it after adding or renaming a tool. `--stale-refs` scans docs, root md and the four workflow skills for dead backticked paths and `Class.member` names (fails) and, with `--narration`, will-be-added / legacy / formerly / no-longer lines (advisory); run it on every doc sweep | BWD | `--help` | Y |

### Split, code map and doc edits

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `split_funcs.py` | Split a GDScript into the facade + helpers in its stem folder (trimmed unique names; `--dry-run` shows them): `FILE --list`, then `--plan plan.json [--dry-run] [--in-folder]` (`{<stem>_<rest>: [names]}`); node funcs move host-first; runs `facade_requal.py` and a line-multiset check. Flow: grok-bot-size.md. | B | `--help` | Y |
| `facade_requal.py` | Qualify names that moved to helpers (same folder or the facade's stem folder; `FILE`, `--check`, `--dry-run`, `--sym NAME=Mod`). `split_funcs.py` runs it itself. | B | `--help` | Y |
| `doc_patch.py` | Idempotent doc edits. CLI: `replace`, `ensure-line`, `set-read-when`, `changelog`, `next-label`, `write`, `apply plan.json`, `check` (`--dry-run`, `--eol keep\|crlf\|lf`); also importable (`write_changelog`, `replace_once`, `replace_func`, `upsert_func`). Keeps each file's BOM and line endings. Detail: `doc-library.md`. | BWD | `--help` | Y |
| `md_format_lib.py` | Text I/O for every tool: `read_text`, `write_text` (BOM and EOL kept), `detect_eol`; markdown format checks | BWD | module docstring (no `--help`) | Y |
| `patch_code_map.py` | Shim -> `code_map.py patch`, one release | BD | `--help` | Y |
| `code_map_lib.py` | Code-map row parser/writer used by `code_map.py` | BD | module docstring (no `--help`) | Y |
| `list_code_map_row.py` | Shim -> `code_map.py row`, one release | BD | `--help` | Y |
| `list_oversize_docs.py` | List `design/*.md` by size, OVER at `--over-kb` (default 8) | BD | `--help` | Y |
| `list_route.py` | Print one `routes.yaml` door or job card (`--job door.job`), incl. its smoke phases | BD | `--help` | Y |

### Inventory and lint

Moved to `tools-lint.md` (same columns): `file_stat`, `summarize_scripts`, `lint_hostify`, `list_dupes`, `list_unused_funcs`, `move_script_cluster`, and the shared libs `repo_lib`, `gd_lib`, `agent_log`, plus the two shims.
