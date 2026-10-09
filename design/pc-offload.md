# PC offload (Build rules)

Status: protocol for agents on a local checkout
Read when: inventorying live files, running a listed runner, reading that runner's _logs summary, or adding a new local runner
The tool catalog (what each tool is, surfaces, gotchas) is `design/tools.md`; this file keeps only the Build / Windows habits.

The cloud Refactorer does not use this file (BOT.md). Every runner is Python. Run heavy inventory / Godot / smoke work on the **User's PC** via these tools. Agents should **read only the job summary (`python tools/read_summary.py --job <name>`, then the final `RESULT` line)** those tools write - not raw Godot logs, not whole script bodies just to inventory.

`_logs/` is gitignored: tools write summaries there; never commit it. `_logs/grok-bot-sweep.md` is not a Bot door.

The repo skill `.grok/skills/pc-offload/SKILL.md` is the early intercept for Grok Build on the User PC. Imagine / I2V skills stay Build-only. Grok Build on the User PC may use repo skills. That is not the cloud Bot library.

## Rules

1. Prefer filesystem `Length` (dir / Get-Item / Get-ChildItem) over reading file contents to measure size.
2. After a preferred runner finishes, run `python tools/read_summary.py --job <name>` once and stop. Once per job and once per slice are the same rule: one read of that job's summary, except a planned gather list may read it once after each distinct planned call (Job cycle). Do not open `tools/*.py` to learn flags; `--help` is the usage.
3. Do not dump whole `.gd` files into chat unless editing them or the User asked.
4. Steam Godot under redirected IO often leaves Process `ExitCode` null - runners treat null as 0. Headless smokes need `--display-driver headless --audio-driver Dummy`. Compile check needs `--headless --editor --import --path <WDB_ROOT> --quit`.
5. ASCII hyphens only in tool output and PowerShell double-quoted strings (no em dashes).
6. Housekeeping: every run writes its own stamped summary and `index.txt` (newest first, last 20 kept; `tools.md` rule 4). Raw Godot `*.log` under `_logs/` are disposable: `tools/clean_agent_logs.py` (or the smoke runner drops orphan phase logs).
7. **Windows / PowerShell bodies:** never put markdown or multi-line Python through PowerShell double-quoted strings or `python -c`. Backticks and `\x` escapes get mangled. Write the body with a single-quoted here-string piped into `python tools/doc_patch.py write FILE` (or `--b64` in a single-quoted string), then run the file. A double-quoted pipe or `python -c` is a failed lookup, not a fallback.
8. **Ephemeral agent Python:** a script you will not run again may live under `_logs/agent-py/` and run with `python tools/run_agent_py.py --script _logs/agent-py/....`. That runner deletes the script after exit by default. `--keep-script` still leaves it gitignored, so the next session cannot see it. A script this session or the next one will run again is a file under `tools/` with a catalog row (`tools.md` rule 7). Do not `--cleanup` paths outside `_logs/agent-py/`. Permanent edits (design docs, checked-in tools) write straight to their real paths.
9. **New runner:** (catalog rule 5) if the next step would open many untouched files, ingest a raw Godot log, grep the tree into chat, or hand-measure files, stop. Use a catalog row when one exists. If none exists, write the runner yourself when it would help future tasks (name, command, summary, what tokens it saves) and tell the User afterward.
10. **Tree search / git / one-liners:** built-in grep is only for a file already in this slice's edit set. Repo search is `list_xref.py`. Git inventory is `list_changed.py` (optional `--head`); do not paste porcelain or `git log` into the thread. No `python -c`.
11. **Cursor skills:** `.cursor/skills/` is a symlink to `.grok/skills/`.

## Build habits

- Skill + catalog intercept before opening many untouched siblings. Tool choice: `design/tools.md` (Run when). Do not open `design/code-map.md` or a list of task files for row/task jobs; use the catalog tools (`task.py list`).
- While editing: prefer `file_stat.py` and Length summaries over reading untouched siblings.
- After a slice that touched `.gd`: `run_build_gate.py` unless the User says skip.
- After an edit of a design doc, the agents file, or `BOT.md`: `check_load_graph.py`. RESULT PASS is required before the change is reported done. It is not deferred to ship.
- Dedicated PC-offload CLI: see **Dedicated Grok Build session** below. Other Grok Build roles use this catalog; they do not rewrite those habits.

## Dedicated catalog session

One Build session owns catalog / runner / skill optimizations. Keep the session thin enough to last about one quota (catalog summaries, not tool bodies in chat). Slice, Bot-notes, and Smoke-tests chats must not rewrite these habits.

- Purpose: When the User names a catalog / runner / skill job, implement that one optimization (catalog row, `tools/` runner, skill when-to-use). Catalog summaries only. Not a game-slice CLI.
- Typical slice: one named runner (a new one is fine). Edit that runner / catalog row / skill when-to-use. Read that row via `tools/read_summary.py --job <name>`. Report when done.
- Just do: same-catalog shared helper; skill `when-to-use` tokens; summary shape matching sibling rows; catalog line next to the existing job.
- Ask first: a generic markdown or pickup writer; a suite of extra doc runners; a skill rewrite that pastes the catalog into every Build boot.
- Do not: Imagine / I2V; Grok Bot PRs; week pin ritual; tree dumps or whole tool bodies in chat; parking Bot opt notes; folding slice work into this thread.
- Report when done. Pickup is git plus the `_logs/<job>/` postcards.
- Overlap: Bot-notes parks opt items with `task.py new opt-next --owner bot`; Smoke-tests writes phase coverage; Slice sessions consume this catalog. This session does not park Bot notes or add smoke assertions unless the User names that.
