# Grok Bot — optimization queue

Status: protocol  
Read when: Grok Bot Job table → named optimization item  

Binding for **Grok Bot** optimization sessions only. Grok Build parks items with `tools/bot_opt.py`. Bot does not invent items.


## Mandate

Size, prove, changelog, and `version.json` rules live in `BOT.md`.

Execute **one** User-named item (or the next `pending` item the User named). One PR. No new game systems.

- Same-system extracts, fewer loads, cache / hot-path helpers, defer work off Title→Play, drop unused preload paths — when the named item says so.
- Timing / preload / cache listed on that item is in scope. Player-facing design is not.
- Do not keep splitting toward 5KB in this flow.
- Do not invent items, numbers, or extra clusters.

The Bot-notes Grok Build CLI is the usual parker. It may expand the User's wording from a thin layout check (one code-map row and/or one `list_xref`) and must ask once if an obvious gap is missing. Do not inventory the tree or write a pass plan into the item. Grok Bot investigates, plans, and implements. Park with `python tools/bot_opt.py` (read `_logs/bot-opt/summary.txt` only). Print pending ids with `python tools/bot_status.py`. Bot loads this mandate, then `--id opt-NNN` for the named item instead of scanning the Queue by hand. Do not add a JSON queue file.


## Read set

1. This file — mandate plus one named item via `python tools/bot_opt.py --id opt-NNN`
2. `design/refactor.md` (recipe only) when a split is required
3. One `design/code-map.md` **system row** for the named cluster
4. After the User names the item: only those live `.gd` bodies
5. At ship: baked `design/versioning-log.md` body shape — not the changelog tree and not `scripts/data/version.json`

Do not open the other Bot flow siblings. Do not walk the whole live tree.


## Pass

1. User names an item id (or the next pending item). Inventory that cluster with VM prove commands in `BOT.md`. Do not edit yet.
2. Implement only that item. Mark it `done` in the same PR with `python tools/bot_opt.py --status opt-NNN=done`.
3. 


## Queue

Parked items sit between the markers. Agents must not hand-edit this section.

<!-- bot-opt:begin -->
<!-- bot-opt:next=5 -->

### opt-001 (pending)
- Title: Extract reusable markdown formatting library from md-editing tools
- Cluster: Tools
- Files: `tools/bot_opt.py`, `tools/code_map_lib.py`, `tools/patch_code_map.py`, `tools/doc_patch.py`, `tools/write_utf8_file.py`

Inventory first. Do not edit until the duplication is real and listed.

Look at tools that surgically edit markdown (not summary.txt dumps) and ask whether the formatting work in tools/bot_opt.py plus existing helpers can become one small reusable library.

Start with:
- tools/bot_opt.py — marker blocks, item headings, meta list fields, tick-wrapped paths, LF, trailing newline, parse/render roundtrip
- tools/code_map_lib.py and tools/patch_code_map.py — table-row rewrite, tick tokens, ` + ` / `, ` / `; ` separators, newline preservation
- tools/doc_patch.py — write_text newline=LF, replace_once, design-path tick variants, ensure_line, set_read_when
- tools/write_utf8_file.py — generic UTF-8 write (not markdown-specific)

Also inspect, but do not fold in unless a shared write helper is one function: anim_review_lib.py / pack / regen briefs, archive_prior_changelogs.py, export_archives.py, build_changelog.py (reads md, writes json).

Extract only shared formatting. Allowed: UTF-8 write, force LF, trailing newline, tick wrap/unwrap, replace-once with path-tick variants, HTML-comment marker block splice, one table-row rewrite helper.

Do not build a markdown engine, CommonMark parser, HTML sanitizer, or doc framework. Do not change queue semantics, code-map patch results, or web Phase 7 doc_patch behavior.

A new tools/ module is in scope because this item names it. Prefer one library imported by the existing runners. New catalog row only if a new command appears. One PR. Mark this item done in the same PR.

### opt-002 (pending)
- Title: Centralize preload literals on Autoload/flow facades
- Cluster: Autoload / flow
- Files: `scripts/app.gd`, `scripts/app_boot.gd`, `scripts/app_flow.gd`, `scripts/app_run.gd`, `scripts/app_set.gd`

Inventory first. Do not edit until the shape is listed.

GDScript preload() only accepts a string literal. Do not use preload(variable) or Res.script("data/balance.gd") as a preload stand-in.

This item is option 2 only: per-API static / const preload owner on the Autoload/flow facades. The preload("res://...") literal stays on app.gd / app_boot.gd / app_flow.gd / app_run.gd / app_set.gd. Other files in that cluster use those consts (or a thin static that returns the already-preloaded resource). App remains the autoload. Do not add ResourceBus / Entity.gd / a second autoload.

Do not change what loads or when. Do not convert const preload to load() to hide res://.

Out of this item: wav/png catalogs, gear_board / pause_menu / playtest, tree-wide class_name, ResourceLoader / threaded hub preload, a Res.balance() helper library.

Touched live scripts stay under 10KB. Land on the current open Bot PR. Mark this item done when the cluster convert is in that PR.

### opt-003 (pending)
- Title: Shared helper for Title/Placeholdia/Dungeon load legs
- Cluster: Autoload / flow
- Files: `scripts/app.gd`, `scripts/app_flow.gd`, `scripts/app_run.gd`, `scripts/app_boot.gd`, `scripts/app_set.gd`

Inventory first. Do not edit until shared enter/exit logic is listed as real duplication (not three similar-looking calls that already go through one function).

User ask: investigate loading for Title/Play -> Placeholdia, Placeholdia -> Dungeon, and Dungeon -> Placeholdia. If those legs share orchestration, offload it to one helper/API.

Owner is Autoload / flow (`app.gd` + `app_flow.gd` / `app_run.gd` / `app_boot.gd` / `app_set.gd`). Camp and dungeon_boot are callers, not a second owner. Do not add a second autoload.

Likely entry points (confirm, do not treat as the worklist):
- Title/Play -> Placeholdia: `title.gd` Play -> `App.play_from_menu` -> `AppFlow.play_from_menu` / `play_from_menu_async` (loader sheet, hub preload, `go_camp`, warmup). Smoke: `--wdb-load-timing-smoke`.
- Placeholdia -> Dungeon: live enter (`save_now`, `_after_enter` / `begin_run` / `go_dungeon` / `dungeon_boot.ready_floor`). Smoke: `--wdb-dungeon-load-timing-smoke`.
- Dungeon -> Placeholdia: inventory every live return to camp (extract-wake, recap, death/abort if those call `go_camp`). Do not assume extract is the only path.

Also inspect `scripts/world/camp.gd` enter/wake and dummy defer only as callers of flow. `scripts/debug/load_timing.gd` is marks, not the logic to extract. Keep those smokes green; do not invent a new numbered phase.

Look for shared steps: scene change, loader overlay, preload vs `load()`, dummy/NPC spawn defer, camera warmup, seed/floor pin, save-before-enter. Extract only what is duplicated. A thin `AppFlow` static helper (or one module imported by `app_flow` / `app_run`) is in scope. Do not build a generic scene manager, loading framework, or new game system.

Keep player-facing order and timing unless a listed extract is a no-op move. Same paths after the extract. Do not fold this into opt-002 (res:// path helper) and do not rewrite wav/png catalogs.

Touched live `scripts/**/*.gd` under 10KB. One PR. Mark this item done in the same PR.

<!-- bot-opt:end -->
