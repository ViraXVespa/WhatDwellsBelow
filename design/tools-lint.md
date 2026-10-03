# Tools catalog: inventory, lint, split and doc edits

Status: binding  
Read when: running a size, dupe, dead-code, stat, split, code-map or doc-edit tool (Bot sweeps, reuse, extract)  

Rules, the CLI contract and the surface key (Surf, A) are in `tools.md`. Same table shape; `check_tool_docs.py` reads this file too.

### Inventory and lint

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `file_stat.py` | Bytes, BOM, CRLF/LF, indent for a path or glob (verify a split kept them). Summary: `file-stat`. | BD | `--help` | Y |
| `summarize_scripts.py` | Func inventory per `.gd` (`--over-kb`, `--top-funcs`) | BD | `--help` | Y |
| `lint_hostify.py` | Advisory scan for `:=`/load inference and host pitfalls; always exits 0 (RESULT INFO) | BD | `--help` | Y |
| `list_dupes.py` | Duplicate finder (read-only): exact / shape / near function clones and verbatim or literal-masked line blocks across `scripts/**/*.gd` and `tools/*.py`, ranked by (copies-1) x lines. `--lang gd\|py\|all`, `--min-lines`, `--min-block`, `--md PATH`. Feeds `design/reuse-map.md`. Summary: `dupes`. | B | `--help` | Y |
| `list_unused_funcs.py` | Dead-code report (`--limit N`). **`--apply` DELETES funcs**: only when the opt item says so; check `call_deferred`/string refs first. | B | `--help` | Y |
| `move_script_cluster.py` | `git mv` a facade + helpers and rewrite `res://`, bare paths and renamed basenames repo-wide, incl. tools, skills, root docs (`--to-dir`, `--plan plan.json` batch, `--map map.json` exact old->new, `--list-cluster FACADE`, `--dry-run`, `--wrapper`). Only for a user-named relocate job; can touch non-allowlisted docs. | BD | `--help` | Y |
| `repo_lib.py` | Git, allowlist, version and changelog-label helpers shared by tools (`under`, `write_text_nl` for path guard and LF text writes) | BWD | module docstring (no `--help`) | Y |
| `gd_lib.py` | `.gd` func parser shared by `split_funcs`, `summarize_scripts`, `show_func`, `doc_patch` | BD | module docstring (no `--help`) | Y |
| `agent_log.py` | Run helpers: `std_parser`, `resolve_root`, `finish`/`emit_result` (RESULT line), `_logs/<job>` paths. CLI prints a job dir. | BD | `--help` | Y |
| `write_utf8_file.py` | Shim -> `doc_patch.py write` (`--path`, `--bom`, `--b64`), one release | BD | `--help` | Y |

### Split, code map and doc edits

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `split_funcs.py` | Split a GDScript into the facade + helpers in its stem folder (trimmed unique names; `--dry-run` shows them): `FILE --list`, then `--plan plan.json [--dry-run] [--in-folder]` (`{<stem>_<rest>: [names]}`); node funcs move host-first; runs `facade_requal.py` and a line-multiset check. Flow: grok-bot-size.md. | B | `--help` | Y |
| `facade_requal.py` | Qualify names that moved to helpers (same folder or the facade's stem folder; `FILE`, `--check`, `--dry-run`, `--sym NAME=Mod`). `split_funcs.py` runs it itself. | B | `--help` | Y |
| `doc_patch.py` | Idempotent doc edits. CLI: `replace`, `ensure-line`, `set-read-when`, `changelog`, `next-label`, `write`, `replace-file`, `apply plan.json`, `check` (`--dry-run`, `--eol keep\|crlf\|lf`); also importable (`write_changelog`, `replace_once`, `replace_func`, `upsert_func`). Keeps each file's BOM and line endings. Detail: `doc-library.md`. | BWD | `--help` | Y |
| `md_format_lib.py` | Text I/O for every tool: `read_text`, `write_text` (BOM and EOL kept), `detect_eol`; markdown format checks | BWD | module docstring (no `--help`) | Y |
| `patch_code_map.py` | Shim -> `code_map.py patch`, one release | BD | `--help` | Y |
| `code_map_lib.py` | Code-map row parser/writer used by `code_map.py` | BD | module docstring (no `--help`) | Y |
| `list_oversize_docs.py` | List `design/*.md` by size, OVER at `--over-kb` (default 8); `--boot` boot-chain bytes, `--dupes` sentences repeated across docs (doc SNR sweep) | BD | `--help` | Y |
| `list_route.py` | Print one `routes.yaml` door or job card (`--job door.job`), incl. smoke phases and shot flows; gates print as a count (`--gates` lists names and triggers), `flows: none` when empty; no args lists the doors | BD | `--help` | Y |
