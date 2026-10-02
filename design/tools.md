# Tools catalog

Status: binding  
Read when: running, adding, or documenting a tool (Bot, web/chat, or Build)  

Single source for what each tool is, which surface runs it, and its gotchas. Other docs say "run X at step N" and point here. Windows runners and release tools: `tools-build.md`. Media pipeline: `tools-media.md`. Build-only rules (Length, here-strings, locks): `pc-offload.md`. `python3 tools/check_tool_docs.py` keeps these tables in step with `tools/` and `tools/bot_allow.txt`.

Surf: **B** Bot (Linux VM), **W** web/chat, **D** Build (User PC). **A**: Y if the tool is on `tools/bot_allow.txt`.

## Rules

1. **Allowlist.** `tools/bot_allow.txt` is the authority for the Bot: it runs only tools marked `A=Y` here and changes only allowlisted paths (CI `bot-gate.yml` and `bot_status.py --prove` read it). Anything else is for the User, Build or web.
2. **Platform.** `.py` tools run as `python3 tools/X.py` (there is no bare `python` on the Bot box). `.ps1` tools need PowerShell on the User's PC (no pwsh on the Bot box); many have a `.py` twin. Write-file and quoting rules for Windows: `pc-offload.md`.
3. **Usage truth.** `.py`: `python3 tools/X.py --help` (a tool marked "module docstring" has no `--help`: read its header). `.ps1`: the Use column. Docs do not repeat flags.
4. **Summaries.** Runners that write `_logs/sess/<session>/<job>/summary.txt` (gitignored): read that file once, not raw logs or script bodies.
5. **New tool.** Propose first (name, command, what it saves) and implement after approval. Add its row here (and the allowlist line if the Bot may run it), then run `python3 tools/check_tool_docs.py`.
6. **Duplicates.** `next_changelog_label.py` and `write_utf8_file.py` duplicate `doc_patch.py`; prefer `doc_patch`.

## Run when

- **Bot:** boot with `bot_status.py`, then the one flow doc from `BOT.md` (size, extract, reuse, relocate, docs, opt). Prove and smokes: `BOT.md` (single copy). Never open the Build docs (`pc-offload.md`, `tools-build.md`, `tools-media.md`) or Imagine/I2V skills.
- **Web/chat:** documentation slices go through `tools/_scratch.py` importing `doc_patch` (`web-session.md`); `check_load_graph.py`; `run_shots.py --mode web`; the prove table in `web-session.md` names the `run_*.ps1` runners the User runs. No Godot runners from the chat itself.
- **Build (User PC):** measure with `file_stat.py` (not `python -c`), `list_xref.ps1`, `list_changed.ps1`, `list_oversize_scripts.ps1`; after a `.gd` slice `run_build_gate.ps1`; edit one code-map row with `patch_code_map.py`; park opt items with `bot_opt.py`. Runner rules: `pc-offload.md`. Do not run a full-repo Bot size sweep.

## Catalog: shared and Bot tools

### Gates and Bot flows

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `bot_status.py` | Punch list: over-10KB/5KB, reuse brief, opt queue; `--prove` = script cap + allowlist + load graph; `--sweep` lists 5-10KB | BD | `--help` | Y |
| `check_script_cap.py` | Script size cap: `--git-changed`, `--path`, `--over-kb 5` for the sweep | BWD | `--help` | Y |
| `check_load_graph.py` | Doc routing vs `design/routes.yaml` (prints PASS/FAIL, no summary) | BWD | `--help` | Y |
| `check_code_map.py` | Live `.gd` vs `design/code-map.md` ticks. Rule: no new UNMAPPED for files you touched (older ones are expected). Summary: `code-map-check`. | BD | `--help` | Y |
| `bot_smokes.py` | Headless phase smokes on the Linux VM (`--phases 1,2,6`). Pin, install and `.uid` import: BOT.md Smokes. | B | `--help` | Y |
| `bot_warnscan.py` | Warning sweep by area; `--save-baseline P` before, `--non-leak-diff P` after (same `--areas`). Procedure: BOT.md Smokes. | B | `--help` | Y |
| `bot_warnscan_lib.py` | Log parser for `bot_warnscan.py` | B | module docstring (no `--help`) | Y |
| `bot_opt.py` | Opt queue: `--list`, `--id`, `--status opt-N=done`, `--add`, `--remove`. Never hand-edit the queue block. Summary: `bot-opt`. | BD | `--help` | Y |
| `bot_allow.txt` | Allowlist: the paths the Bot may change; read by CI and `bot_status --prove`. Deny lines first. Authority for Bot scope. | BWD | - | Y |
| `check_tool_docs.py` | Catalog check: every `tools/` file has a row, `A` matches `bot_allow.txt`, rows name real files. Run it after adding or renaming a tool | BWD | `--help` | Y |

### Split, code map and doc edits

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `split_funcs.py` | Split a GDScript into facade + sibling helpers: `FILE --list`, then `--plan plan.json [--dry-run]` (`{helper_stem: [names]}`); node funcs move host-first; runs `facade_requal.py` and a line-multiset check. Flow: grok-bot-size.md. | B | `--help` | Y |
| `facade_requal.py` | Qualify names that moved to sibling helpers (`FILE`, `--check`, `--dry-run`, `--sym NAME=Mod`). `split_funcs.py` runs it itself. | B | `--help` | Y |
| `doc_patch.py` | Idempotent doc edits: `write_changelog`, `replace_once`, `ensure_line`, `replace_func`, `upsert_func`, `set_read_when`; import it from a scratch runner. Writes CRLF; do not point it at LF files outside the repo. | BWD | module docstring (no `--help`) | Y |
| `md_format_lib.py` | Markdown/UTF-8 write helpers behind `doc_patch.py` | BWD | module docstring (no `--help`) | Y |
| `patch_code_map.py` | Add/remove/rename ticks on one code-map row: `--system NAME --add PATH`. Summary: `code-map-patch`. | BD | `--help` | Y |
| `code_map_lib.py` | Code-map row parser/writer used by `patch_code_map.py` | BD | module docstring (no `--help`) | Y |
| `list_code_map_row.py` | Print the one code-map row naming `--path`. Summary: `code-map-row`. | BD | `--help` | Y |
| `list_oversize_docs.py` | List `design/*.md` by size, OVER at `--over-kb` (default 8) | BD | `--help` | Y |
| `list_route.py` | Print one `routes.yaml` door or job card (`--job door.job`) | BD | `--help` | Y |

### Inventory and lint

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `file_stat.py` | Bytes, BOM, CRLF/LF, indent for a path or glob (verify a split kept them). Summary: `file-stat`. | BD | `--help` | Y |
| `summarize_scripts.py` | Func inventory per `.gd` (`--over-kb`, `--top-funcs`) | BD | `--help` | Y |
| `lint_hostify.py` | Advisory scan for `:=`/load inference and host pitfalls; always exits 0 | BD | module docstring (no `--help`) | Y |
| `list_unused_funcs.py` | Dead-code report (`--limit N`). **`--apply` DELETES funcs**: only when the opt item says so; check `call_deferred`/string refs first. | B | `--help` | Y |
| `move_script_cluster.py` | `git mv` a facade + siblings and rewrite `res://` repo-wide (`--to-dir`, `--dry-run`, `--wrapper`). Only for a user-named relocate job; can touch non-allowlisted docs. | BD | `--help` | Y |
| `agent_log.py` | Session-keyed `_logs/sess/<session>/<job>` paths (library) | BD | module docstring (no `--help`) | Y |
| `next_changelog_label.py` | Print the next changelog label. Duplicates `doc_patch.next_label`; prefer `doc_patch`. Summary: `changelog-label`. | BD | `--help` | N |
| `write_utf8_file.py` | Write a UTF-8 file from stdin (`--path`, `--bom`, `--b64`). Windows: pipe a single-quoted here-string. Duplicates `doc_patch.write_text` on Linux. | BD | `--help` | Y |
