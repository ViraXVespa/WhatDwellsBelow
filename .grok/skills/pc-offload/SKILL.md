---
name: pc-offload
description: >
  Default workflow for every Grok Build task in What Dwells Below on the User PC.
  Load once after the startup command; use the existing repository inventory,
  search, code-map, task, Windows-write, gate and summary tools throughout.
  Not for Grok Bot, web/chat or isolated media/review children. This skill grants
  no new machine, runtime or network permissions and does not perform Imagine/I2V.
when-to-use: >
  Every Grok Build task: startup/resume, implementation, tools/docs work and release
  routines. Reuse the loaded skill; do not reload for every command or after compact.
user-invocable: true
metadata:
  short-description: Default repository-tool workflow for Grok Build
---

# Default Build tool workflow

Use this repository skill for every Grok Build task. Run the opening prompt's `slice.py start` command first, then load this skill once; reuse it after context breaks. A named door or job makes that start write `session-plan.md` in the worktree root. Read that file next and do not repeat the lookups it holds. A post-compact turn in the same worktree reads `session-plan.md` first and does not re-run start. A User-requested new-week routine follows its own entry procedure instead. This is not for Bot, web/chat or isolated children.

Choose the existing command from design/tools.md; design/pc-offload.md owns Windows writing, bounded summaries and runner habits. Use `--help` for flags, not tool source. Common commands are `find.py route`, `find.py xref`, `find.py func`, `find.py scripts --names`, `find.py changed`, `docs.py code-map row`, `docs.py task`, `slice.py plan` and `session.py summary`. `slice.py plan` rebuilds a missing or stale `session-plan.md`; `--refresh` replaces only its gathered half.

Read relevant source for the edit, not entire trees for inventory. Function and const names missing from the plan are `python tools/find.py scripts --names --path PATH` or `--all-names` (one `--path`). Do not inventory them with `find.py xref --regex ^func`. Read each distinct run once with `python tools/session.py summary JOB`, where `JOB` is the `_logs/<job>/` folder on the RESULT line. Never open `_logs/` with a file read or a shell reader. Do not repeat unchanged lookups. Design/agent-doc changes require the load-graph check. Extend the owning tool when a reusable capability is missing.

Images default to isolated review. Necessary direct references require the explicit task/session grant; text questions use OCR first. Do not use shell readers, cwd changes or this skill to bypass the hook. Generation remains isolated.

The Build job cycle owns questions, context breaks, verification and finish. Save unfinished work in the task, not a session-fork recipe. This skill adds no machine/runtime/network permission and does not automatically substitute MCPs for repository tools.
