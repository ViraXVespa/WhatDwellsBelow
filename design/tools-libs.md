# Tools: shared libraries and data

Status: protocol  
Read when: writing or changing a tool, or looking up which shared lib owns a helper  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. New logic goes into the owner below (`tools.md` rule 6); never a parallel helper. Media libs (`audio_lib`, `anim_review_lib`, `imglib/`) are in `tools-media.md`.

## Owners

- Run helpers, flags, RESULT, `_logs/` paths: `agent_log`. Text read/write (BOM, EOL): `md_format_lib`. Git, version, allowlist, selftest repos: `repo_lib`. Godot binary, pin, launch, locks: `godot_lib`. `.gd` parsing: `gd_lib`. Doc edits: `doc_patch`.
- A new tool: `std_parser(desc, writes=True, verbose=True)`, do the work, `agent_log.finish(job, root, body, status, args=args, echo=short_text, **counts)`; long lists through `agent_log.fold`.

## Catalog

| Tool | Does | Surf | Use | A |
|---|---|---|---|---|
| `agent_log.py` | Run helpers for every tool: `std_parser(writes=, verbose=)` (`--root`, `--json`, `--dry-run`, `--verbose`), `resolve_root`, `finish` / `emit_result` (RESULT last; `echo=` replaces the stdout body; `retry=` for the red-prove prompt), `fold` (first rows + count), `run_writer` (one-shot art generators), `guarded`, stamped `_logs/<job>` paths. `--selftest`. | BD | `--help` | Y |
| `md_format_lib.py` | Text I/O for every tool: `read_text`, `write_text` (BOM and EOL kept), `detect_eol`; markdown format checks | BWD | docstring | Y |
| `repo_lib.py` | Git, allowlist, version and changelog-label helpers (`under`, `write_text_nl`); selftest fixtures `git_test`, `selftest_repo`. | BWD | docstring | Y |
| `godot_lib.py` | Godot launch + per-path lock (kills only its own pid, never godot*); `gui=True` picks a display (`--display`). Owns the engine pin: `VERSION`, `resolve_bin` (`GODOT_BIN`, pin file, Steam, box path), `pin_path`; `timing_job` for the load-timing smokes. | BD | docstring | Y |
| `gd_lib.py` | `.gd` func parser shared by `split_funcs`, `summarize_scripts`, `show_func`, `doc_patch` | BD | docstring | Y |
| `run_log_lib.py` | Run-log layout: one `<stamp>-<job>.txt` per run, `index.txt` newest first, keep the last 20, `clear` for the weekly clean | BD | docstring | Y |
| `retry_lib.py` | Red-prove RETRY block: `grok -r <original-session-id> --fork-session` for the User (the id the first `start_build_slice.py` run recorded) plus the paste-ready prompt (failed prove, red lines, one small corrective edit). `--selftest` | BD | docstring | Y |
| `bot_gate_lib.py` | Bot-mode switch for the Bot's own checks (`--bot`, `WDB_BOT`, CI) and the Bot budgets in `bot_budgets.json` | BWD | docstring | Y |
| `bot_budgets.json` | Budgets and the `no_budget` boot files, read by `bot_gate_lib` in Bot mode | B | - | Y |
| `bot_warnscan_lib.py` | Log parser for `bot_warnscan.py` | B | docstring | Y |
| `code_map_lib.py` | Code-map row parser/writer used by `code_map.py` | BD | docstring | Y |
| `tunables_lib.py` | Tunables row parser and writer used by `tunables.py` | D | docstring | N |
| `task_lib.py` | Task files in `design/tasks/`: header fields, the README index, `done` (delete, unblock dependants, changelog line), next opt id, and the `check_load_graph.py` lint | BWD | docstring | Y |
| `slice_lib.py` | `start_build_slice.py` card text (survey / implementation / handoff ORDER), `--selftest` cases (main checkout, Grok clone, second run, forked session, retry block, survey vs job, unit queue) and the `open_slice.py` area check | D | docstring | Y |
| `slice_state.py` | `_logs/slice-state.json` and the `SLICE ALREADY STARTED` text of `start_build_slice.py` (steps: import, baseline shots, original session, forked, handoff; resume at Gather or Prepare / Change / Prove / Complete) | D | docstring | Y |
| `session_lib.py` | Finds a Grok session folder and reads `prompt_context.json`, the early skills reminder, `prompt_history.jsonl` and `chat_history.jsonl` for the session facts of `start_build_slice.py` and the `Did not work:` lines (`failed_block`: failed tool results since the last ask) | D | docstring | Y |
| `handoff_lib.py` | The survey -> implement handoff, a Build task file (`ID.md` in `design/tasks/`; `units:` / `done:` header lines carry a unit queue): skeleton, validation, saved survey edits and the compact start summary for `start_build_slice.py --handoff` / `--from-handoff` / `--from-task`; `open_slice.py` validates a `# Handoff:` prompt | D | docstring | Y |
| `unit_lib.py` | Unit queue of a door (`unit_queue`, `unit_docs`, `unit_files`, `shot_states` in `routes.yaml`): the unit block of a card (position, flow and state, doc line ranges, files), the queue plan from the slice state or a handoff's `units:` / `done:`, and the `check_load_graph.py` lint for those keys | D | docstring | Y |
| `load_routes.py` | Load design/routes.yaml (constrained YAML subset, stdlib only) | D | docstring | N |
| `bench_env.py` | One `env:` line (machine, CPU, GPU, RAM, OS, browser, Godot, renderer, vsync, cap, resolution, headless) for benchmark summaries (`web_perf.py`, `run_hub_bench.py`, `bot_smokes.py` open timing) | BWD | docstring | Y |
| `web_perf_lib.py` | Browser side of `web_perf.py` (init script, flow replay, one page load) | BD | docstring | Y |
| `shot_clip_lib.py` | Clipboard paste and open-in-viewer helpers for `run_shots.py` | WD | docstring | Y |
