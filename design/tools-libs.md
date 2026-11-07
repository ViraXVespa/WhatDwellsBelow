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
| `lib/agent_log.py` | Common parser, root resolution, bounded stdout, RESULT/summary writers, guarded operations and generator run helpers. |
| `lib/md_format_lib.py` | Text I/O for every tool: `read_text`, `write_text` (BOM and EOL kept), `detect_eol`; markdown format checks |
| `lib/repo_lib.py` | Git/version/allowlist helpers, branch classification and diff bases; isolated git test fixtures. |
| `lib/godot_lib.py` | Pinned binary resolution, display choice and per-project launch locks; kills only its own process. |
| `lib/godot_slots.py` | Shared box-only Godot launch slots across checkouts; dead holders free automatically. `WDB_GODOT_SLOTS` configures the cap. Not enabled on CI/User PCs; `--selftest`. |
| `lib/gd_lib.py` | `.gd` func parser shared by `split_funcs`, `summarize_scripts`, `show_func`, `doc_patch` |
| `lib/run_log_lib.py` | Run-log layout: one `<stamp>-<job>.txt` per run, `index.txt` newest first, keep the last 20, `clear` for the weekly clean |
| `lib/slice/retry_lib.py` | Red-prove instructions in the original Build session; one small corrective edit and rerun. Empty off Build. Does not launch or fork a session; `--selftest`. |
| `lib/checks/prove_scope.py` | Scope/cache relevant Bot checks. Visual changes require a tip-compatible wide/detail review covering touched areas and observed findings, not bare answers. `--full` bypasses the pass cache. |
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
| `lib/docs/task_lib.py` | Task header/lifecycle/index validation and dependency updates. |
| `lib/docs/task_compact.py` | Collapse completed units while preserving owner decisions and open work; fixture selftest. |
| `lib/slice/slice_lib.py` | Startup card and fixture tests for main/worktree, survey/job, saved progress, other-session detection, retries and queues. |
| `lib/slice/slice_state.py` | Local slice progress/session/task state and concise resume instructions; this is observed state, not a claim of completed proof. |
| `lib/session/session_lib.py` | Find Build session facts and failed tool results since the last question; used by startup and failed-step reporting. |
| `lib/slice/handoff_lib.py` | Build task skeleton/validation, saved survey edits and resume summary; launch validation for a survey handoff. |
| `lib/slice/unit_lib.py` | Route/task unit queues, completion state, unit doc/files/flows and routing lint. |
| `lib/load_routes.py` | Load design/routes.yaml (constrained YAML subset, stdlib only) |
| `lib/perf/bench_report.py` | Shared bench reports and summary output; `perf.py dungeon --selftest` tests assembly without a game launch. |
| `lib/perf/bench_env.py` | One `env:` line (machine, CPU, GPU, RAM, OS, browser, Godot, renderer, vsync, cap, resolution, headless) for benchmark summaries (`perf.py web`, `perf.py hub`, `gate.py bot-smokes` open timing) |
| `lib/perf/web_perf_lib.py` | Browser side of `perf.py web` (init script, flow replay, one page load) |
| `lib/shots/shot_clip_lib.py` | Clipboard paste and open-in-viewer helpers for `shots.py capture` |
| `lib/shots/review_rounds.py` | ZOOM round protocol for `shots.py review`: parse/validate/clamp child requests, follow-up job text, round/crop/turn caps |
