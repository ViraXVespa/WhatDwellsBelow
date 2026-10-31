# Tools: shared libraries and data

Status: protocol  
Read when: writing or changing a tool, or looking up which shared lib owns a helper  

Door, rules, the CLI contract and the Surf / A key: `tools.md`. New logic goes into the owner below (`tools.md` rule 6); never a parallel helper. Media libs (`audio_lib`, `anim_review_lib`, `imglib/`) are in `tools-media.md`.

## Layout

- `tools/<entry>.py`: thin entry tools. Each holds only a `COMMANDS` table (subcommand, module, one line) and calls `lib/boot.py`; `bot_status.py` forwards to one module (`MODULE`). No logic in an entry.
- `tools/lib/<area>/<module>.py`: one module per subcommand plus that area's libs (`shots/`, `bake/`, `perf/`, `gates/`, `checks/`, `lookup/`, `lint/`, `session/`, `slice/`, `release/`, `media/`, `docs/`). Shared libs sit in `tools/lib/`; data files in `tools/data/`.
- `lib/boot.py` puts `tools/lib` and every area dir on `sys.path` (modules import each other by stem), runs a module as `__main__` and builds child commands: `boot.cmd("run_shots", ...)` gives `[python, tools/shots.py, capture, ...]`. Never call a module file directly from another tool.
- A module starts with `sys.path.insert(0, str(Path(__file__).resolve().parents[1]))` then `import boot`. Repo root is `parents[3]`.

## Add a subcommand

1. Put the module in its area dir (`agent_log.std_parser`, RESULT via `agent_log.finish`; `fold` long lists).
2. Add one `COMMANDS` row to the entry tool, and one catalog row (`entry.py sub`) to the area doc.
3. Run `check.py tool-docs` and `check.py tool-cli --only STEM --smoke-run`.

Owners: run helpers, flags, RESULT, `_logs/`: `agent_log`. Text I/O (BOM, EOL): `md_format_lib`. Git, version, allowlist, selftest repos: `repo_lib`. Godot binary, pin, launch, locks: `godot_lib`. `.gd` parsing: `gd_lib`. Doc edits: `docs.py patch`.

## Libs and data

No CLI of their own; new code goes into the owner (`tools.md` rule 6).

| File (under `tools/`) | Owns |
|---|---|
| `lib/boot.py` | Entry dispatch: `entries()` (every entry's table), `cmd(stem, *args)` child argv, `display(stem)` (`shots.py capture`), area dirs on `sys.path` |
| `lib/agent_log.py` | Run helpers for every tool: `std_parser(writes=, verbose=)` (`--root`, `--json`, `--dry-run`, `--verbose`), `resolve_root`, `finish` / `emit_result` (RESULT last; `echo=` replaces the stdout body; `retry=` for the red-prove prompt), `fold` (first rows + count), `run_writer` (one-shot art generators), `guarded`, stamped `_logs/<job>` paths. `--selftest`. |
| `lib/md_format_lib.py` | Text I/O for every tool: `read_text`, `write_text` (BOM and EOL kept), `detect_eol`; markdown format checks |
| `lib/repo_lib.py` | Git, allowlist, version and changelog-label helpers (`under`, `write_text_nl`); branch kind (`branch_kind`/`head_kind`: grok-build-wN Build, grok-web-wN Web, main, every other named branch Bot; `diff_base`); selftest fixtures `git_test`, `selftest_repo`. |
| `lib/godot_lib.py` | Godot launch + per-path lock (kills only its own pid, never godot*); `gui=True` picks a display (`--display`). Owns the engine pin: `VERSION`, `resolve_bin` (`GODOT_BIN`, pin file, Steam, box path), `pin_path`; `timing_job` for the load-timing smokes. |
| `lib/gd_lib.py` | `.gd` func parser shared by `split_funcs`, `summarize_scripts`, `show_func`, `doc_patch` |
| `lib/run_log_lib.py` | Run-log layout: one `<stamp>-<job>.txt` per run, `index.txt` newest first, keep the last 20, `clear` for the weekly clean |
| `lib/slice/retry_lib.py` | Red-prove RETRY block: `grok -r <original-session-id> --fork-session` for the User (the id the first `slice.py start` run recorded) plus the paste-ready prompt (failed prove, red lines, one small corrective edit); empty off Build (`repo_lib.head_kind`). `--selftest` |
| `lib/checks/prove_scope.py` | Scoping for `bot_status.py --bot --prove`: dupes, stale-refs, bake repro and textsize print `SKIP untouched` when no branch path matches their globs (`prove_rules.json` rule + `SCOPE`), `SKIP cached pass` when their inputs hash the same as at their last pass (`_logs/prove-cache.json`); `--full` runs all. `--selftest` |
| `lib/bot_gate_lib.py` | Bot-mode switch for the Bot's own checks (`--bot`, `WDB_BOT`, CI) and the Bot budgets in `bot_budgets.json` |
| `data/bot_budgets.json` | Budgets and the `no_budget` boot files, read by `bot_gate_lib` in Bot mode |
| `lib/gates/bot_warnscan_lib.py` | Log parser for `gate.py warnscan` |
| `lib/gates/phase_loads.py` | Which smoke phases load each live file (`tools/data/phase_loads.json`, written by `gate.py bot-smokes --record-loads`); `changed_areas` picks phases from it |
| `lib/bake/bake_inputs.py` | Hub bake inputs (`tools/data/hub_bake_inputs.json`): `bake.py check` fails when a light code file or `layout_spec.gd` const changed since the bake; `bake.py camp` records it |
| `lib/bake/bake_leak.py` | Light-leak check (`tools/data/hub_bake_feet.json`, recorded by `bake.py camp`): a lit rim round a footprint fails `bake.py check` |
| `lib/bake/bake_roof.py` | Roof-slope check: a guild roof footprint whose front half is not darker than its back (no `hub_roof.gd slopes`) fails `bake.py check` |
| `lib/bake/bake_repro.py` | `bake.py check --rebake`: rebakes from the committed sources, restores the files, fails unless the stamp matches and lamps bake |
| `lib/docs/code_map_lib.py` | Code-map row parser/writer used by `docs.py code-map` |
| `lib/docs/tunables_lib.py` | Tunables row parser and writer used by `docs.py tunable` |
| `lib/docs/balance_src.py` | Balance source model for `docs.py tunable`: `vars_*.gd` defaults, slider rows, enemy stats, `val_cat_map.gd` categories; in-memory edits, 10 KB cap check before any write |
| `lib/docs/tunables_code.py` | `docs.py tunable list`, `diff`, `range` and the code side of `set KEY VALUE` / `add KEY --default` |
| `lib/docs/tunables_selftest.py` | `docs.py tunable --selftest`: set/range/add/diff on a scratch copy |
| `lib/docs/task_lib.py` | Task files in `design/tasks/`: header fields, the README index, `done` (delete, unblock dependants, changelog line), next opt id, and the `check.py load-graph` lint |
| `lib/slice/slice_lib.py` | `slice.py start` card text (survey / implementation / handoff ORDER), `--selftest` cases (main checkout, Grok clone, second run, forked session, retry block, survey vs job, unit queue) and the `slice.py open` area check |
| `lib/slice/slice_state.py` | `_logs/slice-state.json` and the `SLICE ALREADY STARTED` text of `slice.py start` (steps: import, baseline shots, original session, forked, handoff; resume at Gather or Prepare / Change / Prove / Complete) |
| `lib/session/session_lib.py` | Finds a Grok session folder and reads `prompt_context.json`, the early skills reminder, `prompt_history.jsonl` and `chat_history.jsonl` for the session facts of `slice.py start` and the `Did not work:` lines (`failed_block`: failed tool results since the last ask) |
| `lib/slice/handoff_lib.py` | The survey -> implement handoff, a Build task file (`ID.md` in `design/tasks/`; `units:` / `done:` header lines carry a unit queue): skeleton, validation, saved survey edits and the compact start summary for `slice.py start --handoff` / `--from-handoff` / `--from-task`; `slice.py open` validates a `# Handoff:` prompt |
| `lib/slice/unit_lib.py` | Unit queue of a door (`unit_queue`, `unit_docs`, `unit_files`, `shot_states` in `routes.yaml`): the unit block of a card (position, flow and state, doc line ranges, files), the queue plan from the slice state or a handoff's `units:` / `done:`, and the `check.py load-graph` lint for those keys |
| `lib/load_routes.py` | Load design/routes.yaml (constrained YAML subset, stdlib only) |
| `lib/perf/bench_env.py` | One `env:` line (machine, CPU, GPU, RAM, OS, browser, Godot, renderer, vsync, cap, resolution, headless) for benchmark summaries (`perf.py web`, `perf.py hub`, `gate.py bot-smokes` open timing) |
| `lib/perf/web_perf_lib.py` | Browser side of `perf.py web` (init script, flow replay, one page load) |
| `lib/shots/shot_clip_lib.py` | Clipboard paste and open-in-viewer helpers for `shots.py capture` |
