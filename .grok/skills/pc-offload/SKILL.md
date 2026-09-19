---
name: pc-offload
description: >
  Run local PC inventory, size, search, scene, code-map, changelog-label,
  Godot import, smoke, gate, route-card, summary-read, and Grok session
  pack/report tools for What Dwells Below. Use when about to measure file
  size, list changed paths, search the tree, open many untouched scripts
  or scenes, write multi-line files on Windows, or run import/smokes/gates.
  Do not use for Imagine stills or I2V (those stay Build-only and must not
  be copied to Cursor).
when-to-use: >
  measure size, inventory scripts, list changed files, git inventory,
  repo search (list_xref, not grep), code-map row, patch code-map row,
  check code-map coverage, scene nodes, changelog label, Godot import,
  smokes, load timing, dungeon map, build gate, post-split gate,
  Windows write_utf8_file, run_agent_py, show_func, bot-opt queue,
  read_summary, list_route, pack_grok_sessions, report_grok_sessions,
  propose a new local runner. If this session already opened this skill
  or design/pc-offload.md, do not open them again.
user-invocable: true
cursor-copy: true
metadata:
  short-description: Offload inventory and verify to the local PC
  cursor-copy: true
---

# PC offload

Read design/pc-offload.md once per session and follow it. That file is binding.
Do not reopen this skill or that file after compact.

You are on a local checkout. Do not measure size by reading file bodies.
Do not paste raw Godot logs, whole .gd files, whole .tscn files, or
unbounded search output into the session.

Intercept (raw tool is a failed lookup, not a fallback):
- grep / rg on scripts/, design/, tools/, scenes/ -> tools/list_xref.ps1
- list_dir of those trees -> list_xref.ps1 or list_scenes.ps1
- git status / git log / git diff in chat -> tools/list_changed.ps1
- open whole design/code-map.md -> list_code_map_row.py / patch_code_map.py / check_code_map.py
- size a .gd by reading it -> list_oversize_scripts.ps1
- python -c / double-quoted PowerShell body / echo Set-Content of a script ->
  single-quoted here-string piped to tools/write_utf8_file.py, then
  tools/run_agent_py.ps1
- open tools/*.ps1 or tools/*.py to learn flags -> catalog row only
- read the same _logs/*/summary.txt again this slice -> stop;
  one read via tools/read_summary.ps1 -Job <name>
- check_load_graph.py after every markdown edit -> only at ship,
  or named routing work
- door or job routing by opening README / load-graph / memory topics ->
  tools/list_route.ps1 -Door <name> or -Job door.job

1. Pick the catalog row that matches the job.
2. Run that command from the repo root.
3. Read only that row's summary with read_summary.ps1 -Job <name> (or stdout
   when the catalog says there is no summary). Once per runner per slice.
4. If no row exists and the work would be expensive in-session, propose a
   new runner and wait. Implement it only when the User has approved that
   runner.

Two compacts on the same slice: stop and start a new session in this instance.
Do not reload this skill or the law set because compact fired.

Imagine-isolated and i2v-isolated must stay skipped. Cursor skill copies are
