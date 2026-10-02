# PC offload (Build rules)

Status: binding for agents on a local checkout
Read when: measuring size, inventorying live files, running a listed runner, reading that runner's _logs summary, or proposing a new local runner
The tool catalog (what each tool is, surfaces, allowlist, gotchas) is `design/tools.md`; this file keeps only the Build / Windows habits.

The cloud Refactorer does not use this file (BOT.md). Every runner is Python (`.ps1` files are shims). Run heavy inventory / Godot / smoke work on the **User's PC** via these tools. Agents should **read only the job summary (`_logs/<job>/summary.txt`, then the final `RESULT` line)** those tools write - not raw Godot logs, not whole script bodies just to measure or inventory.

`_logs/` is gitignored: tools write summaries there; never commit it. `_logs/grok-bot-sweep.md` is not a Bot door.

The repo skill `.grok/skills/pc-offload/SKILL.md` is the early intercept for Grok Build on the User PC. Imagine / I2V skills stay Build-only. Grok Build on the User PC may use repo skills. That is not the cloud Bot library.

## Rules

1. Prefer filesystem `Length` (dir / Get-Item / Get-ChildItem) over reading file contents to measure size.
2. After a preferred runner finishes, run `python tools/read_summary.py --job <name>` once and stop. Once per job and once per slice are the same rule: one read of that job's summary, except a planned gather list may read it once after each distinct planned call (Job cycle). Do not open `tools/*.ps1` / `tools/*.py` to learn flags; `--help` is the usage.
3. Do not dump whole `.gd` files into chat unless editing them or the User asked.
4. Steam Godot under redirected IO often leaves Process `ExitCode` null - runners treat null as 0. Headless smokes need `--display-driver headless --audio-driver Dummy`. Compile check needs `--headless --editor --import --path <WDB_ROOT> --quit`.
5. ASCII hyphens only in tool output and PowerShell double-quoted strings (no em dashes).
6. Housekeeping: summaries overwrite in place each run. Raw Godot `*.log` under `_logs/` are disposable: `tools/clean_agent_logs.py` (or the smoke runner drops orphan phase logs).
7. **Windows / PowerShell bodies:** never put markdown or multi-line Python through PowerShell double-quoted strings or `python -c`. Backticks and `\x` escapes get mangled. Write the body with a single-quoted here-string piped into `tools/write_utf8_file.py` (or `--b64` in a single-quoted string), then run the file. A double-quoted pipe or `python -c` is a failed lookup, not a fallback.
8. **Ephemeral agent Python:** put throwaway scripts under `_logs/agent-py/` and run them with `python tools/run_agent_py.py --script _logs/agent-py/....`. That runner deletes the script after exit by default. Do not `--cleanup` paths outside `_logs/agent-py/`. Permanent edits (design docs, checked-in tools) write straight to their real paths - they are not cleaned up.
9. **New runner:** (catalog rule 5) if the next step would open many untouched files, ingest a raw Godot log, grep the tree into chat, or hand-count bytes, stop. Use a catalog row when one exists. If none exists, propose a runner (name, command, summary path, what tokens it saves) and wait. Grok Build implements one only after the User approves that runner in-session.
10. **Tree search / git / one-liners:** built-in grep is only for a file already in this slice's edit set. Repo search is `list_xref.py`. Git inventory is `list_changed.py` (optional `--head`); do not paste porcelain or `git log` into the thread. No `python -c`.
11. **Cursor skills:** `.cursor/skills/` is a symlink to `.grok/skills/`.

## Build habits

- Skill + catalog intercept before measuring size or opening many untouched siblings. Tool choice: `design/tools.md` (Run when). Do not open `design/code-map.md` or the opt queue file for row/queue jobs; use the catalog tools.
- While editing: `check_script_cap.py` (full tree or `-Path` / `-GitChanged`). Prefer Length summaries over reading untouched siblings.
- After a slice that touched `.gd`: `run_build_gate.py` unless the User says skip.
- Do **not** run a full-repo Bot size sweep.
- Dedicated PC-offload CLI: see **Dedicated Grok Build session** below. Other Grok Build roles use this catalog; they do not rewrite those habits.

## Dedicated catalog session

One Build session owns catalog / runner / skill optimizations. Keep the session thin enough to last about one quota (catalog summaries, not tool bodies in chat). Slice, Bot-notes, and Smoke-tests chats must not rewrite these habits.

- Purpose: When the User names a catalog / runner / skill job, implement that one optimization (catalog row, `tools/` runner, skill when-to-use). Catalog summaries only. Not a game-slice CLI.
- Typical slice: one named runner. Propose if new, wait for Go. Edit that runner / catalog row / skill when-to-use. Read that row via `tools/read_summary.py --job <name>`. Stop after the report.
- Just do: same-catalog shared helper; skill `when-to-use` tokens; summary shape matching sibling rows; catalog line next to the existing job.
- Stop and propose: a new catalog runner (already binding). A generic markdown or pickup writer; a suite of extra doc runners; putting runners on the live code map; a skill rewrite that pastes the catalog into every Build boot.
- Do not: Imagine / I2V; Grok Bot PRs; week pin ritual; tree dumps or whole tool bodies in chat; parking Bot opt notes; folding slice work into this thread.
- Stop after the report. Pickup is git plus the `_logs/<job>/` postcards.
- Overlap: Bot-notes parks queue items with `bot_opt.py`; Smoke-tests writes phase coverage; Slice sessions consume this catalog. This session does not park Bot notes or add smoke assertions unless the User names that. Slice sessions do not add runners unless named in that thread.
