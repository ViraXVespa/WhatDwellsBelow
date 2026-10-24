# Tools

Status: protocol  
Read when: running, adding, or documenting a tool (Bot, web/chat, or Build)  

The door for every tool under `tools/`: which tool for which job, the rules, and the CLI contract. Open the one sibling the job names; each holds exact commands (Jobs) and the catalog rows. `check_tool_docs.py` keeps the rows in step with `tools/`.

Commands: `python tools/X.py` (the Bot's box: `python3`). Flags: `python tools/X.py --help`. Surf: **B** Bot (Linux box), **W** web/chat, **D** Build (User PC). **A**: Y if the Bot may run it.

## Which tool for which job

| Job | Start with | Sibling |
|---|---|---|
| Prove a change, commit a Build slice | `check_gd_load.py`, then `run_build_gate.py --batch [--visual door.job]`, then `commit_slice.py`; Bot: BOT.md Prove list | `tools-gates.md` |
| Compile errors, import, warnings | `check_gd_load.py`; `run_godot_import_check.py`; `bot_warnscan.py --save-baseline B` then `--non-leak-diff B` | `tools-gates.md` |
| Smokes | `run_smokes.py --door D` (PC); `bot_smokes.py --phases 1,2,6` or `--for FILE` (Bot) | `tools-gates.md` |
| Screenshots, before/after, image facts | `run_shot_flow.py --job door.job`; `shot_diff.py A B --out OUT`; `img_inspect.py diff A B`; `shot_crop.py SHOT --box X,Y,W,H` | `tools-shots.md` |
| Light, ground wear, frame art bakes | `run_bake_camp.py`, `check_hub_bake.py`, `bake_frame_art.py --check` | `tools-shots.md` |
| Frame time, hitches, load time, web perf | `run_hub_bench.py --leg desktop`; `web_perf.py --site DIR --flow F`; `run_load_timing.py --leg hub` | `tools-perf.md` |
| Find code, a function, a route, a tunable, a last run | `list_xref.py TEXT`; `show_func.py PATH NAME`; `list_route.py --job door.job`; `tunables.py get KEY`; `read_summary.py JOB` | `tools-lookup.md` |
| Size, duplicates, dead code, splits, doc edits | `check_script_cap.py --bot --sweep`; `list_dupes.py`; `list_unused_funcs.py`; `split_funcs.py FILE --list`; `doc_patch.py` | `tools-lint.md` |
| Tasks, code map, routing docs | `task.py list`; `code_map.py row --path P`; `check_load_graph.py` | `tools-gates.md` |
| Localization (keys, copy on screen) | No dedicated tool: `list_xref.py KEY` (code and `en.po`), `list_xref.py TEXT --texts` after a shot flow, `img_inspect.py contrast` | `tools-lookup.md` |
| Art, stills, I2V, rekey, audio | `run_isolated_grok.py --kind K --brief "..." --out DIR`; `rekey_all_stills.py --only PATH`; `anim_review.py`; `make_sfx.py` | `tools-media.md` |
| Start a slice, logs, export, week, Pages | `open_slice.py` (User), `start_build_slice.py`, `clean_agent_logs.py`, `export_web.py` | `tools-build.md` |
| Write or change a tool | `check_tool_cli.py --only STEM --smoke-run`, `check_tool_docs.py`; owners in `tools-libs.md` | `tools-libs.md` |

Runner habits on the User PC: `pc-offload.md`. Retired one-off tools: `tools/retired/README.md` (not run, not catalogued).

By surface: the **Bot** follows `BOT.md` (boot, prove, smokes, which docs it never opens). **Web/chat** edits docs through `doc_patch.py` (`doc-library.md`); its scratch may call any tool, and the User runs only `python tools/_scratch.py` (`web-emit.md`). **Build** measures with tools (`file_stat.py`, not `python -c`) and runs `check_load_graph.py` after any design doc, agents file or `BOT.md` edit.

## Rules

1. **Bot scope.** The Bot runs only `A=Y` tools and changes only the paths its scope allows (`BOT.md`; CI `bot-gate.yml`).
2. **Platform.** Every tool is Python. Windows and Godot rules: `pc-offload.md`.
3. **Usage truth.** `--help` for every CLI tool; `*_lib.py` files have a module docstring. Docs give the job's exact command, not every flag.
4. **Summaries.** Every run writes `_logs/<job>/<stamp>-<job>.txt` (gitignored, never overwritten, last 20 kept, `index.txt` newest first). Read the `RESULT` line, then the summary once (`read_summary.py JOB`), not raw logs or script bodies. Every root `_*/` folder carries a committed `.gdignore`, so tool output never enters an import or a `.pck`.
5. **New tool.** Build and Web add a tool when it would help future tasks (not a one-off) and tell the User afterward: name, command, what it saves. Add its row to the right sibling, then `check_tool_docs.py` and `check_tool_cli.py`. The Bot adds a tool only when the User approved it this session. Asset generators live in `tools/`; their durable sources in `_src/`.
6. **One owner, no parallel copies.** Fold overlapping tools into one tool with subcommands or flags; shared code goes in the owner lib (`tools-libs.md`). A renamed flag keeps its old name as an alias. A tool nobody needs moves to `tools/retired/` with a README line.
7. **Tools, not scratches.** If you or the next session would run it again, update or add a tool. A scratch is a niche one-off: `run_agent_py.py` deletes it after the run. Web doc edits: `doc_patch.py` (`doc-library.md`). A proof with no tool: extend the library in the same job (`prove.md`).
8. **Fix the tool.** A tool that is not intuitive is designed wrong: fix it in the same session (or park a Bot task), do not work around it.
9. **Rough edges (end of every task).** List what you hit (a guessed flag, a re-run, a scratch, a doc that lied); fix it in the same change when you can, else name it in the report.
10. **No loops (gates and fixes).**
    - Batch same-kind fixes into one edit pass, then run the gates once.
    - No re-verify cycles on unchanged results.
    - **Prove is final verification.** Diagnosis and the fix are finished before the prove (Gather, Prepare, Change). A red prove allows one small corrective edit and one re-run; still red: stop and report the log path. Build's retry uses the original session id (`build-job-cycle.md`).
    - Two fixes that do not move the metric mean the cause is unnamed: Prepare improves the instrumentation, not a third fix.
    - At most 2 gate reruns per task (a full `bot_warnscan` or `bot_smokes` sweep counts as one).
    - Exempt: iterating one visual unit with the User; each pass still runs `check_gd_load.py`.
11. **Python image deps.** `pip install -r tools/requirements.txt` (Pillow, numpy, OpenCV; all required). Shared image code: `tools/imglib/` (`tools-media.md`).

## Contract (enforced by `check_tool_cli.py`)

- Shebang `#!/usr/bin/env python3`, `agent_log.std_parser`, a non-mutating `--help`, ASCII output, `help=` on every option.
- Ops tools take `--root`, writers `--dry-run`, every tool `--json` (stdout is then one JSON object). Errors go to stderr as `error: ...`. Exit 0 ok, 1 findings, 2 usage.
- Stdout is a short summary, at most 30 lines (a `--list` run 60): long lists fold to the first rows plus a count (`agent_log.fold`), `--verbose` prints all. The last line is always `RESULT <PASS|FAIL|INFO> k=v ... summary=<repo-relative path>`. Exempt: printers and `wdb_scratch_server`.
- Output paths are `--out` (one file or folder) or `--out-<kind>` (`--out-md`, `--out-json`); older names stay only as aliases.
- Text goes through `md_format_lib` (BOM and line endings kept). Printed paths are repo-relative POSIX. Project scanners print a WARN line only when the scanned root is not the current directory's project.
