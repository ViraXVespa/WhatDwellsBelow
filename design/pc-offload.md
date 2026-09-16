# PC offload (Bot + Build)

Status: binding for agents on a local checkout
Read when: measuring size, inventorying live files, running a listed runner, reading that runner's _logs summary, or proposing a new local runner
Folder relocate, Bot/Build runners, and sprite tools live in this catalog, not on the live code map.

Run heavy inventory / Godot / smoke work on the **User's PC** via these tools. Agents should **read only the `_logs/*/summary.txt` files** those tools write - not raw Godot logs, not whole script bodies just to measure or inventory.

`_logs/` is gitignored. Tools may write summaries there. Do not commit `_logs/`. Optional Bot notes may still go in `_logs/grok-bot-sweep.md`.

The repo skill `.grok/skills/pc-offload/SKILL.md` is the early intercept for Build and Bot. Imagine / I2V skills stay Build-only. A skill is copied into `.cursor/skills/` only when its frontmatter has `cursor-copy: true`.

## Rules

1. Prefer filesystem `Length` (dir / Get-Item / Get-ChildItem) over reading file contents to measure size.
2. After a preferred runner finishes, open **only** its summary path below.
3. Do not dump whole `.gd` files into chat unless editing them or the User asked.
4. Steam Godot under redirected IO often leaves Process `ExitCode` null - runners treat null as 0. Headless smokes need `--display-driver headless --audio-driver Dummy`. Compile check needs `--headless --editor --import --path <WDB_ROOT> --quit`.
5. ASCII hyphens only inside PowerShell `.ps1` double-quoted strings (no em dashes).
6. Housekeeping: summaries overwrite in place each run. Raw Godot `*.log` under `_logs/` are disposable - run `tools/clean_agent_logs.ps1` (or let smoke runner drop orphan phase logs). `_logs/` stays gitignored; do not commit it.
7. **Windows / PowerShell bodies:** never put markdown or multi-line Python through PowerShell double-quoted strings or `python -c`. Backticks and `\x` escapes get mangled. Write the body with a single-quoted here-string piped into `tools/write_utf8_file.py` (or `--b64` in a single-quoted string), then run the file.
8. **Ephemeral agent Python:** put throwaway scripts under `_logs/agent-py/` and run them with `powershell -File tools/run_agent_py.ps1 -Script _logs/agent-py/....`. That runner deletes the script after exit by default. Do not `-Cleanup` paths outside `_logs/agent-py/`. Permanent edits (design docs, checked-in tools) write straight to their real paths - they are not cleaned up.
9. **Web / chat Phase 7 runner:** `tools/_scratch.py` is the gitignored paste target for documentation slices. The User runs `python tools/_scratch.py` from repo root. Do not put that runner under `_logs/agent-py/` (those scripts are deleted after exit). The runner must import `tools/doc_patch.py` instead of copying replace helpers.
10. **New runner:** if the next step would open many untouched files, ingest a raw Godot log, grep the tree into chat, or hand-count bytes, stop. Use a catalog row when one exists. If none exists, propose a runner (name, command, summary path, what tokens it saves) and wait. Grok Build may implement an approved runner. Grok Bot may implement one only after the User approves that runner in-session.

## Catalog

| Job | Command (from repo root) | Summary (read only this) |
|-----|--------------------------|--------------------------|
| Housekeep `_logs/` | `powershell -File tools/clean_agent_logs.ps1` (optional `-KeepRaw`, `-MaxAgeHours 24`) | `_logs/clean/summary.txt` |
| Design doc sizes | `powershell -File tools/list_oversize_docs.ps1` (optional `-OverKb 8`) | `_logs/oversize-docs/summary.txt` |
| Load-graph / routes.yaml | `python tools/check_load_graph.py` (optional `--root .`) | (stdout PASS/FAIL; no summary) |
| Write UTF-8 body (no PS expansion) | pipe single-quoted here-string to `python tools/write_utf8_file.py --path ...` (optional `--bom`, `--b64`) | (writes the path; no summary) |
| Run ephemeral agent Python | `powershell -File tools/run_agent_py.ps1 -Script _logs/agent-py/foo.py` (optional `-KeepScript`) | `_logs/agent-py/summary.txt` |
| Bake 3D texture mipmaps | `python tools/enable_texture_mips.py` (optional `--root`, `--dry-run`) | (stdout counts; rewrites `.import` under `assets/sprites|tiles|props|fx`) |
| Oversize inventory | `powershell -File tools/list_oversize_scripts.ps1` (optional `-OverKb 5` or `10`) | `_logs/oversize/summary.txt` |
| Func-level inventory | `powershell -File tools/summarize_scripts.ps1` (optional `-OverKb 5`, `-TopFuncs 8`, `-Path scripts/...`) | `_logs/script-summary/summary.txt` |
| Facade + siblings by size | `powershell -File tools/list_facade_cluster.ps1 -Facade scripts/combat/enemy.gd` | `_logs/facade-cluster/summary.txt` |
| Script cap gate | `powershell -File tools/check_script_cap.ps1` (optional `-OverKb 10`, `-GitChanged`, `-Path ...`) | `_logs/script-cap/summary.txt` |
| Changed-path inventory | `powershell -File tools/list_changed.ps1` (optional `-Scope scripts,tools`) | `_logs/changed/summary.txt` |
| Capped xref / search | `powershell -File tools/list_xref.ps1 -Pattern "needle"` (optional `-Path design`, `-Include *.gd`, `-MaxHits 30`) | `_logs/xref/summary.txt` |
| One code-map row | `python tools/list_code_map_row.py --path scripts/app.gd` | `_logs/code-map-row/summary.txt` |
| Scene node / script list | `powershell -File tools/list_scenes.ps1` (optional `-Path scenes/dungeon.tscn`) | `_logs/scenes/summary.txt` |
| Next changelog label | `python tools/next_changelog_label.py` | `_logs/changelog-label/summary.txt` |
| Sync Cursor skills | `powershell -File tools/sync_agent_skills.ps1` (optional `-DryRun`) | `_logs/skill-sync/summary.txt` |
| Relocate facade cluster | `powershell -File tools/move_script_cluster.ps1` (or `python tools/move_script_cluster.py`) | (tool stdout; no summary) |
| Editor import / compile | `powershell -File tools/run_godot_import_check.ps1` | `_logs/godot-import-check/summary.txt` |
| Phase smokes | Prefer `& .\tools\run_smokes.ps1 -Phases @(4,5)` (avoid `-File ... -Phases 4,5` binding as phase 45) | `_logs/smokes/summary.txt` |
| Hostify lint (advisory) | `powershell -File tools/lint_hostify.ps1` | `_logs/hostify-lint/summary.txt` |
| Post-split gate (Bot) | `powershell -File tools/run_post_split_gate.ps1` (optional `-WithSmokes`, `-Force`) | `_logs/post-split-gate/summary.txt` |
| Build gate (Build) | `powershell -File tools/run_build_gate.ps1` (optional `-SkipImport`, `-OverKb 10`, `-Force`) | `_logs/build-gate/summary.txt` |

`tools/export_web.ps1` runs `enable_texture_mips.py` before Godot `--import`. Do not invent a second bake step after the PCK is packed.

Ship floor vs Bot 5KB sweep: the script-split recipe. Do not restate those caps here.

## Who uses what

### Grok Bot

- Load the pc-offload skill when measuring, inventorying, searching, or verifying. Then this catalog. Read summaries only.
- Inventory / sweep planning: changed-path and oversize list, then `summarize_scripts` / `list_facade_cluster` before opening bodies. Code-map row instead of the whole live map. Scene list instead of raw `.tscn`.
- Doc / multi-line script edits on Windows: `write_utf8_file.py` + `run_agent_py.ps1` for ephemeral runners (auto-clean under `_logs/agent-py/`).
- After each size cluster: import check or `run_post_split_gate.ps1`; hostify lint advisory; smokes when behavior risk warrants.
- Relocate: `move_script_cluster` from this catalog.
- Next changelog label: `next_changelog_label.py`. Do not read `design/changelog/` to invent the number.
- May **propose** a new catalog runner at any time. May **implement** it only after the User approves that runner in-session.
- After adding or editing a `cursor-copy: true` skill, run `sync_agent_skills.ps1`. Do not copy Imagine / I2V skills.

### Grok Build

- Same skill + catalog intercept before measuring size or opening many untouched siblings.
- While editing: `check_script_cap.ps1` (full tree or `-Path` / `-GitChanged`). Prefer Length summaries over reading untouched siblings.
- After a slice that touched `.gd`: `run_build_gate.ps1` unless the User says skip.
- Do **not** run a full-repo Bot size sweep.
- Writing tool summaries under `_logs/` is allowed and preferred. Do not commit that folder. Optional Bot-only notes file remains Bot's concern.
- May implement an approved new runner without a Bot flow.

### Web / chat

- No requirement to run the Godot / smoke runners. Cap timing lives in the agents file and the path session file.
- Phase 7 documentation slices emit `tools/_scratch.py`. The User runs it locally; it must import `tools/doc_patch.py` and may call `python tools/check_load_graph.py`.
- Mip bake is export-side (`enable_texture_mips.py`); the User runs `export_web.ps1` when shipping Pages.
