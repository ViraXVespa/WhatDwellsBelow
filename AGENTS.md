# What Dwells Below — agent rules

Godot **4.7.2**. Live path must stay gamepad-first and web-exportable.

## Path

| Path | Recognize | Deliver |
|------|-----------|---------|
| **Grok Build (CLI)** | You can write the checkout | Follow `design/grok-build.md`. Edit live files. Implementation is unconstrained there (same-system APIs just do; cross-system / named-architecture replace is propose-first). Do not dump whole files unless asked. Do not apply web / Bot leashes to this path. |
| **Web / chat** | You cannot write the repo | Follow `design/web-session.md`. Never assume a disk write landed. |
| **Grok Bot** | Grok Bot / Cursor desktop assistant writing via GitHub PR (cloud agent when available, or GitHub connector), or the User named a Grok Bot path / Grok Bot refactor sweep | Follow `design/grok-bot-session.md` only (door). That Job table names the one flow sibling. Recipes: `design/refactor.md` / `design/doc-refactor.md`. Ship via branch + PR. Refactor only, except a new `tools/` runner the User approved this session. |

If unsure: ask once, then use **web / chat** if still uncertain. A missed full-file emit is worse than an extra one.

## Shared

Design lives in `design/`. Do not collapse `design/` into one document.
Never open `notes/`. Files there are human scratch, not binding, not a door.

Navigation is only `design/routes.yaml`. Do not treat `See also:` as a load list; that field is forbidden. Open a file when this Path table, a routes.yaml door / job / gate, or the User names that work.

| Need | File |
|------|------|
| Law (web / Build) | `design/protocol.md` + `design/constraints.md` |
| GDScript types / warnings / tabs / 10KB | `design/gdscript-law.md` |
| Live code map (one system row) | `design/code-map.md` |
| Numbers (when the work changes them) | `design/tunables.md` |
| Local inventory / verify / Windows write | pc-offload skill + `design/pc-offload.md` |

**Local lookup:** tree search under `scripts/`, `design/`, `tools/`, `scenes/` is `tools/list_xref.ps1`, not the grep tool, unless that file is already open for edit in this slice. Git inventory is `tools/list_changed.ps1` — do not paste `git status` / `git log` into the thread. One door or job card is `tools/list_route.ps1` (`-Door` / `-Job`); do not open the topic index or load-graph for that. Windows bodies: single-quoted here-string into `tools/write_utf8_file.py`, then `tools/run_agent_py.ps1`; no `python -c` and no double-quoted PowerShell bodies. After a runner, run `powershell -File tools/read_summary.ps1 -Job <name>` once for that job (session-keyed `_logs/sess/<session>/<job>/summary.txt` when present); do not read that summary again in the job and do not open `tools/*.ps1` to learn flags. Job-cycle and planned-gather rules: `design/protocol.md`.

Path procedures live in the Path table session file. Do not open the topic index or the load-graph sketch unless the User named the index or routing work.

**Load cap (soft):** this file + the path session file + (web / Build only) `design/protocol.md` and `design/constraints.md` + one topic door + one Job-table sibling. Gates whose `when` matches, including `design/gdscript-law.md` when editing GDScript and `design/pc-offload.md` when measuring, inventorying, or writing on Windows. `design/tunables.md` when numbers change. `design/versioning.md` at ship only. `design/code-map.md` is one system row. A second topic door only when the User names the owner. Law / gates / one code-map row are not topic doors.

Web / Build: the path file loads the law pair if they are missing, then only the topic door for named work. Bot: this file, then `design/grok-bot-session.md` only. Do not fetch this file again.

`design/sessions.md` is the Grok Build leave-off only — not a web or Bot hand-off. Fresh Build instance: this file, then `design/grok-build.md`. Leave-off is not a boot list.

Build Imagine: `design/isolated-media.md` before any Imagine call. Details stay on the Build path file. Web / chat and Grok Bot do not run Imagine.

After a slice: stop and report.
