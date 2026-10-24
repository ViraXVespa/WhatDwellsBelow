# Tools

Status: protocol  
Read when: running, adding, or documenting a tool (Bot, web/chat, or Build)  

The door for every tool under `tools/`: which command for which job, the rules, and the CLI contract. Open the one sibling the job names; it holds exact commands (Jobs) and the catalog rows. `check.py tool-docs` keeps the rows in step with the entry tools.

**Layout.** 13 entry tools at `tools/` top level, each a list of subcommands: `shots` `bake` `perf` `gate` `check` `find` `lint` `docs` `media` `release` `session` `slice`, plus `bot_status`. The work lives in `tools/lib/<area>/` (one module per subcommand); data in `tools/data/`. You never need to open a module to run it (`tools-libs.md`).

Commands: `python tools/E.py SUB ...` (the Bot's box: `python3`). `python tools/E.py` lists the subcommands; `python tools/E.py SUB --help` gives the flags. Surf: **B** Bot (Linux box), **W** web/chat, **D** Build (User PC). **A**: Y if the Bot may run it.

## Which tool for which job

| Job | Start with | Sibling |
|---|---|---|
| Prove a change, commit a Build slice | `gate.py gd-load`, then `gate.py build --batch [--visual door.job]`, then `slice.py commit`; Bot: BOT.md Prove list | `tools-gates.md` |
| Compile errors, import, warnings | `gate.py gd-load`; `gate.py import`; `gate.py warnscan --save-baseline B` then `--non-leak-diff B` | `tools-gates.md` |
| Smokes | `gate.py smokes --door D` (PC); `gate.py bot-smokes --phases 1,2,6` or `--for FILE` (Bot) | `tools-gates.md` |
| Screenshots, before/after, image facts | `shots.py flow --job door.job`; `shots.py diff A B --out OUT`; `shots.py inspect diff A B`; `shots.py crop SHOT --box X,Y,W,H` | `tools-shots.md` |
| Light, ground wear, frame art bakes | `bake.py camp`, `bake.py check`, `bake.py frames --check` | `tools-shots.md` |
| Frame time, hitches, load time, web perf | `perf.py hub --leg desktop`; `perf.py web --site DIR --flow F`; `perf.py load --leg hub` | `tools-perf.md` |
| Find code, a function, a route, a tunable, a last run | `find.py xref TEXT`; `find.py func PATH NAME`; `find.py route --job door.job`; `docs.py tunable get KEY`; `session.py summary JOB` | `tools-lookup.md` |
| Size, duplicates, dead code, splits, doc edits | `check.py script-cap --bot --sweep`; `lint.py dupes`; `lint.py unused`; `lint.py split FILE --list`; `docs.py patch` | `tools-lint.md` |
| Tasks, code map, routing docs | `docs.py task list`; `docs.py code-map row --path P`; `check.py load-graph` | `tools-gates.md` |
| Localization (keys, copy on screen) | No dedicated tool: `find.py xref KEY` (code and `en.po`), `find.py xref TEXT --texts` after a shot flow, `shots.py inspect contrast` | `tools-lookup.md` |
| Art, stills, I2V, rekey, audio | `media.py grok --kind K --brief "..." --out DIR`; `media.py rekey --only PATH`; `media.py anim-review`; `media.py sfx` | `tools-media.md` |
| Start a slice, logs, export, week, Pages | `slice.py open` (User), `slice.py start`, `session.py clean`, `release.py export-web` | `tools-build.md` |
| Write or change a tool | `check.py tool-cli --only STEM --smoke-run`, `check.py tool-docs`; owners in `tools-libs.md` | `tools-libs.md` |

Runner habits on the User PC: `pc-offload.md`. Retired one-off tools: `tools/retired/README.md` (not run, not catalogued).

By surface: the **Bot** follows `BOT.md` (boot, prove, smokes, which docs it never opens). **Web/chat** edits docs through `docs.py patch` (`doc-library.md`); its scratch may call any tool, and the User runs only `python tools/_scratch.py` (`web-emit.md`). **Build** measures with tools (`find.py stat`, not `python -c`) and runs `check.py load-graph` after any design doc, agents file or `BOT.md` edit.

## Rules

1. **Bot scope.** The Bot runs only `A=Y` commands and changes only the paths its scope allows (`BOT.md`; CI `bot-gate.yml`).
2. **Platform.** Every tool is Python. Windows and Godot rules: `pc-offload.md`.
3. **Usage truth.** `--help` on every subcommand; libs carry a module docstring. Docs give the job's exact command, not every flag.
4. **Summaries.** Every run writes `_logs/<job>/<stamp>-<job>.txt` (gitignored, last 20 kept, `index.txt` newest first). Read the `RESULT` line, then the summary once (`session.py summary JOB`), not raw logs or module bodies. Every root `_*/` folder carries a committed `.gdignore`.
5. **New tool.** Add one when it helps future tasks (not a one-off), as a subcommand of the entry that owns the area (`tools-libs.md` Add a subcommand); a new entry only for a new area. Tell the User afterward: command and what it saves. The Bot adds one only when the User approved it this session. Asset generators live in `tools/lib/media/`; their sources in `_src/`.
6. **One owner, no parallel copies.** Fold overlapping commands into one subcommand with flags; shared code goes in the owner lib (`tools-libs.md`). A renamed flag keeps its old name as an alias. A command nobody needs moves to `tools/retired/` with a README line.
7. **Tools, not scratches.** If you or the next session would run it again, update or add a command. A scratch is a one-off: `session.py py` deletes it after the run. Web doc edits: `docs.py patch` (`doc-library.md`). A proof with no tool: extend the library in the same job (`prove.md`).
8. **Fix the tool.** A command that is not intuitive is designed wrong: fix it in the same session (or park a Bot task), do not work around it.
9. **Rough edges (end of every task).** List what you hit (a guessed flag, a re-run, a scratch, a doc that lied); fix it in the same change when you can, else name it in the report.
10. **No loops.** Batch same-kind fixes, then run the gates once; no re-verify on unchanged results. **Prove is final verification:** diagnosis and fix come first; a red prove allows one small corrective edit and one re-run, then stop and report the log path (Build retries with the original session id, `build-job-cycle.md`). Two fixes that do not move the metric mean the cause is unnamed: improve the instrumentation, not a third fix. At most 2 gate reruns per task (a full `gate.py warnscan` or `gate.py bot-smokes` sweep counts as one). Exempt: iterating one visual unit with the User; each pass still runs `gate.py gd-load`.
11. **Python image deps.** `pip install -r tools/requirements.txt` (Pillow, numpy, OpenCV). Shared image code: `tools/lib/imglib/` (`tools-media.md`).

## Contract (enforced by `check.py tool-cli`)

- Entry tools: a shebang, a docstring and one `COMMANDS` table, no logic; bare / `--help` list the subcommands, an unknown one exits 2.
- Modules: `agent_log.std_parser`, a non-mutating `--help`, ASCII output, `help=` on every option.
- Ops tools take `--root`, writers `--dry-run`, every tool `--json` (stdout is then one JSON object). Errors go to stderr as `error: ...`. Exit 0 ok, 1 findings, 2 usage.
- Stdout is a short summary, at most 30 lines (a `--list` run 60): long lists fold to the first rows plus a count (`agent_log.fold`), `--verbose` prints all. The last line is always `RESULT <PASS|FAIL|INFO> k=v ... summary=<repo-relative path>`. Exempt: printers and `session.py scratch-server`.
- Output paths are `--out` (one file or folder) or `--out-<kind>` (`--out-md`, `--out-json`); older names stay only as aliases.
- Text goes through `md_format_lib` (BOM and line endings kept). Printed paths are repo-relative POSIX. Project scanners print a WARN line only when the scanned root is not the current directory's project.
