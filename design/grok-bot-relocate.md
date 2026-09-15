# Grok Bot — folder relocate

Status: protocol  
Read when: Grok Bot Job table → parked or named folder relocate  
See also: `design/grok-bot-session.md`, `design/refactor.md`

`See also:` is an index, not a read list. Open the door first. Then this file.

Binding for **Grok Bot** when the User names a folder move / relocate cluster. Do not fold this into a size sweep, extract, reuse-map brief, or doc facade PR.

## Mandate

Move an existing facade + stem siblings to a new folder. No behavior change. No wrappers unless the User asked for `-Wrapper` or external refs are too many to retarget in the same PR.

Out of scope: inventing a new cluster to move, archives, art, features.

## Read set

1. `AGENTS.md`
2. `design/grok-bot-session.md`
3. This file
4. `design/refactor.md` (Parked folder moves)
5. The `design/README.md` **code map** rows that name the cluster
6. At ship: `scripts/data/version.json` + `design/versioning.md` body shape

Do not open `design/reuse-map.md`. Do not read every caller first — run the mover, then open only paths the summary says changed.

## Pass

1. User names the source facade and destination folder. Stop and ask if either is missing.
2. From repo root: `powershell -File tools/move_script_cluster.ps1` (or `python tools/move_script_cluster.py`). Optional `-DryRun`, `-Wrapper` (leave `extends "res://..."` stubs at old paths).
3. The tool `git mv`s the facade + stem siblings (+ `.uid`), rewrites `res://` and bare paths under `scripts/`, `design/`, scenes, and `project.godot`, and writes `_logs/move-cluster/summary.txt`.
4. Prefer updating call sites over wrappers when external refs are few.
5. Update `design/README.md` code map rows in the same PR.
6. Run the editor import check (`design/pc-offload.md`). Ship per the door.
