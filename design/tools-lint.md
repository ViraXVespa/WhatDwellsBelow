# Tools catalog: inventory and lint

Status: binding  
Read when: running a size, dupe, dead-code or stat tool (Bot sweeps, reuse, extract)  

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
| `next_changelog_label.py` | Shim -> `doc_patch.py next-label`, one release. Summary: `changelog-label`. | BD | `--help` | N |
| `write_utf8_file.py` | Shim -> `doc_patch.py write` (`--path`, `--bom`, `--b64`), one release | BD | `--help` | Y |
