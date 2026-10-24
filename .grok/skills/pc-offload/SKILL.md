---
name: pc-offload
description: >
  Run local PC inventory, search, scene, code-map, Godot import, smoke,
  gate, route-card and summary-read tools for What Dwells Below. Use when about to measure files, list changed paths,
  search the tree, open many untouched scripts
  or scenes, write multi-line files on Windows, or run import/smokes/gates.
  Do not use for Imagine stills or I2V (those stay Build-only).
when-to-use: >
  measure files (find.py stat; not python -c), inventory scripts, list changed files, git inventory,
  docs-vs-code history (list_changed --history),
  repo search (list_xref, not grep), code-map row, patch code-map row,
  check code-map coverage, scene nodes, Godot import,
  smokes, load timing, dungeon map, build gate, post-split gate,
  Windows write (docs.py patch write), run_agent_py, show_func, task files (docs.py task),
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
- grep / rg on scripts/, design/, tools/, scenes/ -> tools/find.py xref
- list_dir of those trees -> find.py xref or find.py scenes
- git status / git log / git diff in chat -> tools/find.py changed
- open whole design/code-map.md -> tools/docs.py code-map (row / patch / check)
- list_dir of the repo root -> tools/find.py route (lists the doors)
- open a whole script of the system being edited -> tools/find.py func
- bytes / newlines / indent / BOM on a live path -> tools/find.py stat (not python -c)
- python -c for bytes, newlines, tabs, or indent -> tools/find.py stat
- python -c / double-quoted PowerShell body / echo Set-Content of a script ->
  single-quoted here-string piped to tools/docs.py patch write FILE, then
  tools/session.py py. A script this session or the next one will run again
  is FILE under tools/ with a catalog row. session.py py deletes FILE when
  it is under _logs/agent-py/
- open tools/*.py to learn flags -> catalog row only
- read the same job summary again this slice -> stop;
  one read via tools/session.py summary --job <name> (index first, newest run;
  every run has its own stamped file, never open _logs files directly)
- a design doc, the agents file, or BOT.md edit -> python tools/check.py load-graph
  before the change is reported done. RESULT PASS is required. Do not defer it to ship
- door or job routing by opening README / load-graph / memory topics ->
  tools/find.py route --door <name> or --job door.job

1. Pick the catalog row that matches the job.
2. Run that command from the repo root.
3. Read only that row's summary with session.py summary --job <name> (or stdout
   when the catalog says there is no summary). Once per runner per slice.
4. If no row exists and the work would be expensive in-session, write the
   runner yourself when it would help future tasks (design/tools.md rule 5)
   and tell the User afterward.
5. Build slices: the first command is python tools/slice.py start,
   before any file read or memory topic. Pass --job <door.job> or --door <name>, then run python tools/docs.py task show <id> and read that task file whole. It prints the slice rules (session facts, Q0,
   ledger, "Did not work:" from slice.py start --failed, shots.py show for
   pictures she should see, handoff, slice.py commit, merge-back) and the docs
   to read, the single source. A later
   run says where the slice stands. A door with a unit queue (ui) is worked one
   unit at a time: slice.py start --unit-done at each Complete; finish what
   fits one session, a task file keeps the rest, no new survey. A committed task resumes with
   slice.py start --door D --from-task ID (docs.py task list). Only the User launches grok.

Two compacts on the same slice: write the notes into the task file, commit, and push the branch, including live stills, so the next session can continue. She opens the next session. Then write the handoff (slice.py start --handoff)
and start a fresh session.

Imagine-isolated and i2v-isolated must stay skipped.
