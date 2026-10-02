# Grok Bot — folder relocate

Status: protocol  
Read when: Grok Bot Job table → parked or named folder relocate  

Boot `BOT.md` + `python3 tools/bot_status.py` first. Binding for **Grok Bot** when the User names a folder move / relocate cluster. Do not fold this into a size sweep, extract, reuse-map brief, or doc facade PR.


## Mandate

Size, prove, changelog, and `version.json` rules live in `BOT.md`.

Move an existing facade + helpers to a new location or rename them (placement and naming convention: refactor.md, Cluster folders; tool modes there). No behavior change. No wrappers unless the User asked for `-Wrapper` or external refs are too many to retarget in the same PR.

Out of scope: inventing a new cluster to move, archives, art, features.

## Read set

1. This file
2. `design/refactor.md` (Parked folder moves; recipe only)
3. The `design/code-map.md` **system rows** that name the cluster
4. At ship: `design/versioning-log.md` body shape — not the changelog tree and not `scripts/data/version.json`

Do not open the staged reuse brief. Do not read every caller first — run the mover, then open only paths the summary says changed.

## Pass

1. User names the source facade and destination folder. Stop and ask if either is missing.
2. From repo root: `python3 tools/move_script_cluster.py` (`--dry-run`, `--plan plan.json` for a batch, `--wrapper` leaves `extends "res://..."` stubs at old paths; design/tools.md).
3. The tool `git mv`s the facade + helpers (+ `.uid`; `--map` for renames), rewrites `res://`, bare paths and renamed basenames under `scripts/`, `design/`, scenes, and `project.godot`, and writes `_logs/move-cluster/summary.txt`.
4. Prefer updating call sites over wrappers when external refs are few.
5. Update `design/code-map.md` rows in the same PR. Do the manual checks from refactor.md Cluster folders (prose globs, old basenames of renamed files, string-built paths, the four wdb-* skills).
6. Prove per BOT.md.

## Verify

Prove per BOT.md.
