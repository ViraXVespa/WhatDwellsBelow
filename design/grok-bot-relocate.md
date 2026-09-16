# Grok Bot — folder relocate

Status: protocol  
Read when: Grok Bot Job table → parked or named folder relocate  

Binding for **Grok Bot** when the User names a folder move / relocate cluster. Do not fold this into a size sweep, extract, reuse-map brief, or doc facade PR.


## Mandate

Move an existing facade + stem siblings to a new folder. No behavior change. No wrappers unless the User asked for `-Wrapper` or external refs are too many to retarget in the same PR.

Out of scope: inventing a new cluster to move, archives, art, features.

## Read set

1. This file
2. `design/refactor.md` (Parked folder moves; recipe only)
3. The `design/code-map.md` **system rows** that name the cluster
4. At ship: `scripts/data/version.json` + `design/versioning-log.md` body shape — not the changelog tree

Do not reopen the agents file unless types, warnings, tabs, or the 10KB cap left context. Do not open the staged reuse brief. Do not read every caller first — run the mover, then open only paths the summary says changed.

## Pass

1. User names the source facade and destination folder. Stop and ask if either is missing.
2. From repo root: `powershell -File tools/move_script_cluster.ps1` (or `python tools/move_script_cluster.py`). Optional `-DryRun`, `-Wrapper` (leave `extends "res://..."` stubs at old paths).
3. The tool `git mv`s the facade + stem siblings (+ `.uid`), rewrites `res://` and bare paths under `scripts/`, `design/`, scenes, and `project.godot`, and writes `_logs/move-cluster/summary.txt`.
4. Prefer updating call sites over wrappers when external refs are few.
5. Update `design/code-map.md` rows in the same PR.
6. Run the editor import check (`design/pc-offload.md`). Ship per the door.
