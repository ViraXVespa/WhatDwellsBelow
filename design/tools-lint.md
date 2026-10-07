# Tools catalog: inventory, lint, split and doc edits

Status: protocol  
Read when: running a dupe, dead-code, stat, split, code-map or doc-edit tool, or reading a shared lib row  

Rules, the CLI contract and the surface key (Surf, A) are in `tools.md`. Same table shape; `check_tool_docs.py` reads this file too.

### Inventory and lint

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `file_stat.py` | Bytes, BOM, CRLF/LF, indent for a path or glob (verify a split kept them); prints the absolute root it read. Summary: `file-stat`. | BD | `--help` | Y |
| `summarize_scripts.py` | Func inventory per `.gd` (`--path`, `--top-funcs`) | BD | `--help` | Y |
| `lint_hostify.py` | Advisory scan for `:=`/load inference and host pitfalls; always exits 0 (RESULT INFO) | BD | `--help` | Y |
| `list_dupes.py` | Duplicate finder (read-only): exact / shape / near function clones and verbatim or literal-masked line blocks across `scripts/**/*.gd` and `tools/*.py`, ranked by (copies-1) x lines. `--lang gd\|py\|all`, `--min-lines`, `--min-block`, `--md PATH`. Feeds `design/reuse-map.md`. Summary: `dupes`. | B | `--help` | Y |
| `list_unused_funcs.py` | Dead-code report (`--limit N`): `unused` funcs, `shadowed` (name defined in 2+ files, nothing resolves to that def: alias/class_name/extends aware), `decl` (unused const/signal/preload alias; `tunables.gd` knobs never listed), `maybe` (bare-name string only: check by hand). Funcs named in `call_deferred`/`call`/`connect`/`Callable`, scenes, flow json or web shells are `dynamic` (live, summary only). **`--apply` DELETES** unused+shadowed+decl, repeating until nothing is left: only when the opt item says so. | B | `--help` | Y |
| `move_script_cluster.py` | `git mv` a facade + helpers and rewrite `res://`, bare paths and renamed basenames repo-wide, incl. tools, skills, root docs (`--to-dir`, `--plan plan.json` batch, `--map map.json` exact old->new, `--list-cluster FACADE`, `--dry-run`, `--wrapper`). Only for a user-named relocate job; can touch non-allowlisted docs. | BD | `--help` | Y |
| `repo_lib.py` | Git, allowlist, version and changelog-label helpers shared by tools (`under`, `write_text_nl` for path guard and LF text writes) | BWD | module docstring (no `--help`) | Y |
| `gd_lib.py` | `.gd` func parser shared by `split_funcs`, `summarize_scripts`, `show_func`, `doc_patch` | BD | module docstring (no `--help`) | Y |
| `agent_log.py` | Run helpers: `std_parser`, `resolve_root`, `finish`/`emit_result` (RESULT line, `retry=` for the red-prove prompt), stamped `_logs/<job>` paths. `--selftest` checks the log layout. | BD | `--help` | Y |
| `run_log_lib.py` | Run-log layout: one `<stamp>-<job>.txt` per run, `index.txt` newest first, keep the last 20, `clear` for the weekly clean | BD | module docstring (no `--help`) | Y |
| `retry_lib.py` | Red-prove RETRY block: `grok -r CHECKPOINT --fork-session` for the User to run from the worktree, plus the paste-ready prompt (failed prove, red lines, files in the diff from the week branch); saves/reads the checkpoint (gather session id). `--selftest` | BD | module docstring (no `--help`) | Y |
| `unit_lib.py` | Unit queue of a door (`unit_queue`, `unit_docs`, `unit_files`, `shot_states` in `routes.yaml`): the unit block of a card (position, flow and state, doc line ranges, files), the queue plan from the slice state or a handoff's `units:` / `done:`, and the `check_load_graph.py` lint for those keys | D | module docstring (no `--help`) | Y |
| `handoff_lib.py` | The survey -> implement handoff file (`_logs/handoff/handoff.md`; `units:` / `done:` header lines carry a unit queue): skeleton, validation, saved survey edits and the compact start summary for `start_build_slice.py --handoff` / `--from-handoff`; `open_slice.py` validates a `# Handoff:` prompt | D | module docstring (no `--help`) | Y |
| `session_lib.py` | Finds a Grok session folder and reads `prompt_context.json`, the early skills reminder, `prompt_history.jsonl` and `chat_history.jsonl` for the session facts of `start_build_slice.py` and the `Did not work:` lines (`failed_block`: failed tool results since the last ask) | D | module docstring (no `--help`) | Y |
| `slice_state.py` | `_logs/slice-state.json` and the `SLICE ALREADY STARTED` text of `start_build_slice.py` (steps read from disk: import, baseline shots, checkpoint, handoff) | D | module docstring (no `--help`) | Y |
| `slice_lib.py` | `start_build_slice.py` card text (survey / implementation / handoff ORDER), `--selftest` cases (main checkout, Grok clone, second run, survey vs job, checkpoint) and the `open_slice.py` area check | D | module docstring (no `--help`) | Y |
| `bot_gate_lib.py` | Bot-mode switch for the Bot's own checks (`--bot`, `WDB_BOT`, CI) and the Bot budgets in `bot_budgets.json` | BWD | module docstring (no `--help`) | Y |
| `bot_budgets.json` | Budgets read by `bot_gate_lib` in Bot mode | B | - | Y |

### Split, code map and doc edits

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `split_funcs.py` | Split a GDScript into the facade + helpers in its stem folder (trimmed unique names; `--dry-run` shows them): `FILE --list`, then `--plan plan.json [--dry-run] [--in-folder]` (`{<stem>_<rest>: [names]}`); node funcs move host-first; runs `facade_requal.py` and a line-multiset check. Flow: grok-bot-size.md. | B | `--help` | Y |
| `facade_requal.py` | Qualify names that moved to helpers (same folder or the facade's stem folder; `FILE`, `--check`, `--dry-run`, `--sym NAME=Mod`). `split_funcs.py` runs it itself. | B | `--help` | Y |
| `doc_patch.py` | Idempotent doc edits. CLI: `replace`, `ensure-line`, `set-read-when`, `changelog`, `next-label`, `write`, `replace-file`, `apply plan.json`, `check` (`--dry-run`, `--eol keep\|crlf\|lf`); also importable (`write_changelog`, `replace_once`, `replace_func`, `upsert_func`). Keeps each file's BOM and line endings. Detail: `doc-library.md`. | BWD | `--help` | Y |
| `check_hub_bake.py` | Committed `hub_light.png` pixel hash vs `HUB_BAKE_STAMP` in `hub_bake.gd` (the game crashes on a mismatch). Run by `run_build_gate.py --batch`. Summary: `hub-bake`. | BWD | `--help` | Y |
| `md_format_lib.py` | Text I/O for every tool: `read_text`, `write_text` (BOM and EOL kept), `detect_eol`; markdown format checks | BWD | module docstring (no `--help`) | Y |
| `code_map_lib.py` | Code-map row parser/writer used by `code_map.py` | BD | module docstring (no `--help`) | Y |
| `list_oversize_docs.py` | Bot-only doc sweep (runs with `--bot`): `design/*.md` by size, `--boot` boot-chain bytes, `--dupes` sentences repeated across docs | B | `--help` | Y |
| `list_route.py` | Print one `routes.yaml` door or job card (`--job door.job`) with its read list (the one doc to read, others only on their trigger; `--digest --door D` prints one line per doc, `--digest --job J` that doc's headings with line numbers; a door with several jobs lists the flows per job), incl. smoke phases and shot flows; gates print as a count (`--gates` lists names and triggers), `flows: none` when empty (a job shows only its own key); no args lists the doors | BD | `--help` | Y |
