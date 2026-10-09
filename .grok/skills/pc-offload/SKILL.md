---
name: pc-offload
description: >
  Run local PC inventory, search, scene, code-map, Godot import, smoke,
  gate, route-card and summary-read tools for What Dwells Below. Use when about to measure files, list changed paths,
  search the tree, open many untouched scripts
  or scenes, write multi-line files on Windows, or run import/smokes/gates.
  Do not use for Imagine stills or I2V (those stay Build-only).
when-to-use: >
  measure files (file_stat.py; not python -c), inventory scripts, list changed files, git inventory,
  docs-vs-code history (list_changed --history),
  repo search (list_xref, not grep), code-map row, patch code-map row,
  check code-map coverage, scene nodes, Godot import,
  smokes, load timing, dungeon map, build gate, post-split gate,
  Windows write (doc_patch.py write), run_agent_py, show_func, task files (task.py),
  read_summary, list_route, show_png, add a new local runner. If this session already opened this skill
  or design/pc-offload.md, do not open them again.
user-invocable: true
metadata:
  short-description: Offload inventory and verify to the local PC
---

# PC offload

Open design/pc-offload.md only for inventory, verify, a Windows write or a new local runner, and design/tools.md only when running, adding or documenting a tool (design/load-graph.md); each once per session.

You are on a local checkout. Do not measure files by reading their bodies.
Do not paste raw Godot logs, whole .gd files, whole .tscn files, or
unbounded search output into the session.

Intercept (raw tool is a failed lookup, not a fallback):
- grep / rg on scripts/, design/, tools/, scenes/ -> tools/list_xref.py
- list_dir of those trees -> list_xref.py or list_scenes.py
- git status / git log / git diff in chat -> tools/list_changed.py
- open whole design/code-map.md -> tools/code_map.py (row / patch / check)
- list_dir of the repo root -> tools/list_route.py (lists the doors)
- open a whole script of the system being edited -> tools/show_func.py
- bytes / newlines / indent / BOM on a live path -> tools/file_stat.py (not python -c)
- python -c for bytes, newlines, tabs, or indent -> tools/file_stat.py
- python -c / double-quoted PowerShell body / echo Set-Content of a script ->
  single-quoted here-string piped to tools/doc_patch.py write FILE, then
  tools/run_agent_py.py. A script this session or the next one will run again
  is FILE under tools/ with a catalog row. run_agent_py.py deletes FILE when
  it is under _logs/agent-py/
- open tools/*.py to learn flags -> catalog row only
- read the same job summary again this slice -> stop;
  one read via tools/read_summary.py --job <name> (index first, newest run;
  every run has its own stamped file, never open _logs files directly)
- a design doc, the agents file, or BOT.md edit -> python tools/check_load_graph.py
  before the change is reported done. RESULT PASS is required. Do not defer it to ship
- door or job routing by opening README / load-graph / memory topics ->
  tools/list_route.py --door <name> or --job door.job

1. Pick the catalog row that matches the job.
2. Run that command from the repo root.
3. Read only that row's summary with read_summary.py --job <name> (or stdout
   when the catalog says there is no summary). Once per runner per slice.
4. If no row exists and the work would be expensive in-session, write the
   runner yourself when it would help future tasks (design/tools.md rule 5)
   and tell the User afterward.
5. Build slices: the first command is python tools/start_build_slice.py,
   before any memory topic; it prints the slice rules (session facts, Q0,
   ledger, "Did not work:" from start_build_slice.py --failed, show_png.py for
   pictures she should see, handoff, commit_slice.py, merge-back) and the docs
   to read, the single source. A later
   run says where the slice stands. A door with a unit queue (ui) is worked one
   unit at a time: start_build_slice.py --next after each committed unit prints the
   next unit's card, no new survey. A committed task resumes with
   start_build_slice.py --door D --from-task ID (task.py list). Only the User launches grok.

Two compacts on the same slice: write the handoff (start_build_slice.py --handoff)
and start a fresh session.

Imagine-isolated and i2v-isolated must stay skipped.
