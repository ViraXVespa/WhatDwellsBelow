---
name: pc-offload
description: >
  Run local PC inventory, size, search, scene, code-map, changelog-label,
  Godot import, smoke, and gate tools for What Dwells Below. Use when about
  to measure file size, list changed paths, search the tree, open many
  untouched scripts or scenes, write multi-line files on Windows, or run
  import/smokes/gates. Do not use for Imagine stills or I2V
  (those stay Build-only and must not be copied to Cursor).
when-to-use: >
  measure size, inventory scripts, list changed files, git inventory,
  repo search (list_xref, not grep), code-map row, patch code-map row,
  check code-map coverage, scene nodes, changelog label, Godot import,
  smokes, load timing, dungeon map, build gate, post-split gate, Windows write_utf8_file,
  run_agent_py, show_func, bot-opt queue, propose a new local runner
user-invocable: true
cursor-copy: true
metadata:
  short-description: Offload inventory and verify to the local PC
  cursor-copy: true
---

# PC offload

Read `design/pc-offload.md` and follow it. That file is binding.

You are on a local checkout. Do not measure size by reading file bodies.
Do not paste raw Godot logs, whole `.gd` files, whole `.tscn` files, or
unbounded search output into the session.

MUST: if the next call would be the grep tool on `scripts/` / `design/` /
`tools/` / `scenes/`, or `git status` / `git log` into chat, or `python -c`,
or a full-file read only to inventory, stop and run the catalog row instead
(`list_xref`, `list_changed`, `run_agent_py` / `write_utf8_file`,
`summarize_scripts` / `show_func`).

1. Pick the catalog row that matches the job.
2. Run that command from the repo root.
3. Read **only** that row's `_logs/*/summary.txt` (or stdout when the catalog
   says there is no summary).
4. If no row exists and the work would be expensive in-session, propose a
   new runner and wait. Implement it only when the User has approved that
   runner.

Imagine-isolated and i2v-isolated must stay skipped. Cursor skill copies are
a symlink; do not run `sync_agent_skills.ps1` after a skill edit.
