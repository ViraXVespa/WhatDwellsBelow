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

Use this repository skill for every Grok Build task. Do the opening prompt's first step (after `slice.py open` that is one `wdb__lookup action=packet all=true`, not a file read and not a page; otherwise its `slice.py start` command), then load this skill once; reuse it after context breaks. Do not re-lookup a body the packet holds. The Approach is a hypothesis: trust the inlined code when they disagree, then `slice.py adjust approach`. A post-compact turn in the same worktree is that same full packet read (live expand includes the Approach and any adjusts) and does not re-run start. A symbol the packet lacks is one lookup of that symbol plus `slice.py adjust` in the same turn. A User-requested new-week routine follows its own entry procedure instead. This is not for Bot, web/chat or isolated children.

Choose the existing command from design/tools.md; design/pc-offload.md owns Windows writing, bounded summaries, session-plan upkeep, and runner habits. Use `--help` for flags, not tool source. When the wdb MCP is connected, use `wdb__lookup`, `wdb__check` and `wdb__protocol` (`all=true` or `reads` for a whole result; `action=packet` returns the whole packet even without `all=true`). When it is not, run the `tools/` command those wrap. Common commands are `find.py route`, `find.py xref`, `find.py func`, `find.py changed`, `docs.py code-map row`, `docs.py task`, `slice.py adjust` and `session.py summary`. Change the `session-plan.md` index and the Approach only with `slice.py adjust`.

Read relevant source for the edit, not entire trees for inventory. A symbol the packet does not contain is one lookup of that symbol plus `slice.py adjust` (add-func, add-doc, or promote) in the same turn. Do not inventory the tree with `action=names` or `find.py xref --regex ^func` to rebuild a plan the Approach already states. Read each distinct run once with `python tools/session.py summary JOB`, where `JOB` is the `_logs/<job>/` folder on the RESULT line. Never open `_logs/` with a file read or a shell reader. Do not repeat unchanged lookups. Design/agent-doc changes require the load-graph check. Extend the owning tool when a reusable capability is missing.

Images default to isolated review. Necessary direct references require the explicit task/session grant; text questions use OCR first. Do not use shell readers, cwd changes or this skill to bypass the hook. Generation remains isolated.

The Build job cycle owns questions, context breaks, verification and finish. Save unfinished work in the task, not a session-fork recipe. This skill adds no machine/runtime/network permission; the repo `wdb` MCP wraps the repository tools, and no other MCP substitutes for them.
