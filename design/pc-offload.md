# PC offload (Build rules)

Status: binding for agents on a local checkout
Read when: measuring size, inventorying live files, running a listed runner, reading that runner's _logs summary, or proposing a new local runner
The tool catalog (what each tool is, surfaces, allowlist, gotchas) is `design/tools.md`; this file keeps only the Build / Windows habits.

The cloud Refactorer does not use this file (BOT.md). Python twins of many runners are listed in the catalog. Run heavy inventory / Godot / smoke work on the **User's PC** via these tools. Agents should **read only the session summary (`_logs/sess/<session>/<job>/summary.txt`)** those tools write - not raw Godot logs, not whole script bodies just to measure or inventory.

`_logs/` is gitignored. Tools may write summaries there. Do not commit `_logs/`. Do not treat `_logs/grok-bot-sweep.md` as a Bot door from this catalog.

The repo skill `.grok/skills/pc-offload/SKILL.md` is the early intercept for Grok Build on the User PC. Imagine / I2V skills stay Build-only. Grok Build on the User PC may use repo skills. That is not the cloud Bot library.

## Rules

1. Prefer filesystem `Length` (dir / Get-Item / Get-ChildItem) over reading file contents to measure size.
2. After a preferred runner finishes, run `powershell -File tools/read_summary.ps1 -Job <name>` once and stop. Once per job and once per slice are the same rule: one read of that job's session summary, except a planned gather list may read it once after each distinct planned call (Job cycle). Do not open `tools/*.ps1` / `tools/*.py` to learn flags; the catalog row (`.ps1`) or `--help` (`.py`) is the usage.
3. Do not dump whole `.gd` files into chat unless editing them or the User asked.
4. Steam Godot under redirected IO often leaves Process `ExitCode` null - runners treat null as 0. Headless smokes need `--display-driver headless --audio-driver Dummy`. Compile check needs `--headless --editor --import --path <WDB_ROOT> --quit`.
5. ASCII hyphens only inside PowerShell `.ps1` double-quoted strings (no em dashes).
6. Housekeeping: summaries overwrite in place each run. Raw Godot `*.log` under `_logs/` are disposable - run `tools/clean_agent_logs.ps1` (or let smoke runner drop orphan phase logs). `_logs/` stays gitignored; do not commit it.
7. **Windows / PowerShell bodies:** never put markdown or multi-line Python through PowerShell double-quoted strings or `python -c`. Backticks and `\x` escapes get mangled. Write the body with a single-quoted here-string piped into `tools/write_utf8_file.py` (or `--b64` in a single-quoted string), then run the file. A double-quoted pipe or `python -c` is a failed lookup, not a fallback.
8. **Ephemeral agent Python:** put throwaway scripts under `_logs/agent-py/` and run them with `powershell -File tools/run_agent_py.ps1 -Script _logs/agent-py/....`. That runner deletes the script after exit by default. Do not `-Cleanup` paths outside `_logs/agent-py/`. Permanent edits (design docs, checked-in tools) write straight to their real paths - they are not cleaned up.
9. **Web / chat Phase 7 runner:** `tools/_scratch.py` (gitignored paste target) imports `doc_patch`; never put it under `_logs/agent-py/`. Details: web-session.md.
10. **New runner:** (catalog rule 5) if the next step would open many untouched files, ingest a raw Godot log, grep the tree into chat, or hand-count bytes, stop. Use a catalog row when one exists. If none exists, propose a runner (name, command, summary path, what tokens it saves) and wait. Grok Build may implement an approved runner. Grok Build may implement one only after the User approves that runner in-session.
11. **Tree search / git / one-liners:** built-in grep is only for a file already in this slice's edit set. Repo search is `list_xref.ps1`. Git inventory is `list_changed.ps1` (optional `-Head`); do not paste porcelain or `git log` into the thread. No `python -c`.
12. **Cursor skills:** `.cursor/skills/` is a symlink to `.grok/skills/`. 
## Catalog

Moved to `design/tools.md` (shared and Bot tools) and `tools-build.md` (`.ps1` runners with their `_logs` summary job names, Pages/release, session reports). `tools-media.md` has the art pipeline. `export_web.ps1` runs `enable_texture_mips.py` before Godot `--import`; do not invent a second bake step after the PCK is packed.

Ship floor vs Bot 5KB sweep: the script-split recipe. Do not restate those caps here.

## Build habits

- Same skill + catalog intercept before measuring size or opening many untouched siblings. Tool choice per job: `design/tools.md` (Run when). Do not open `design/code-map.md` or the opt queue file for row/queue jobs; use the catalog tools.
- While editing: `check_script_cap.ps1` (full tree or `-Path` / `-GitChanged`). Prefer Length summaries over reading untouched siblings.
- After a slice that touched `.gd`: `run_build_gate.ps1` unless the User says skip.
- Do **not** run a full-repo Bot size sweep.
- Writing tool summaries under `_logs/` is allowed and preferred. Do not commit that folder. Optional Bot-only notes file remains Bot's concern.
- May implement an approved new runner without a Bot flow.
- Dedicated PC-offload CLI: see **Dedicated Grok Build session** below. Other Grok Build roles use this catalog; they do not rewrite those habits.

## Dedicated catalog session

One Build session owns catalog / runner / skill optimizations. Keep the session thin enough to last about one quota (catalog summaries, not tool bodies in chat). Slice, Bot-notes, and Smoke-tests chats must not rewrite these habits.

- Purpose: When the User names a catalog / runner / skill job, implement that one optimization (catalog row, `tools/` runner, skill when-to-use). Catalog summaries only. Not a game-slice CLI.
- Typical slice: one named runner. Propose if new, wait for Go. Edit that runner / catalog row / skill when-to-use. Read that row via `tools/read_summary.ps1 -Job <name>`. Stop after the report.
- Just do: same-catalog shared helper; skill `when-to-use` tokens; summary shape matching sibling rows; catalog line next to the existing job.
- Stop and propose: a new catalog runner (already binding). A generic markdown or pickup writer; a suite of extra doc runners; putting runners on the live code map; a skill rewrite that pastes the catalog into every Build boot.
- Do not: Imagine / I2V; Grok Bot PRs; week pin ritual; tree dumps or whole tool bodies in chat; parking Bot opt notes; folding slice work into this thread.
- Stop after the report. Pickup is git plus `_logs/sess/` postcards.
- Overlap: Bot-notes parks queue items with `bot_opt.py`; Smoke-tests writes phase coverage; Slice sessions consume this catalog. This session does not park Bot notes or add smoke assertions unless the User names that. Slice sessions do not add runners unless named in that thread.
