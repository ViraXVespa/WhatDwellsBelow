# Grok Bot — optimization queue

Status: protocol  
Read when: Grok Bot Job table → named optimization item  

For **Grok Bot** optimization sessions only. Grok Build parks items with `tools/bot_opt.py`. Bot does not invent items.

## Mandate

Execute **one** User-named item (or the next `pending` item the User named). One PR. No new game systems.

- Same-system extracts, fewer loads, cache / hot-path helpers, defer work off Title→Play, drop unused preload paths — when the named item says so.
- Timing / preload / cache listed on that item is in scope. Player-facing design is not.
- Do not keep splitting toward 5KB in this flow.
- Dead-code items: inventory with `python3 tools/list_unused_funcs.py --limit 30` (report only; its `--apply` warning is in design/tools.md). Prove and doc edits: BOT.md and design/tools.md.
- Do not invent items, numbers, or extra clusters.

The Bot-notes Grok Build CLI is the usual parker. It may expand the User's wording from a thin layout check (one code-map row and/or one `list_xref`) and must ask once if an obvious gap is missing. Do not inventory the tree or write a pass plan into the item. Grok Bot investigates, plans, and implements. Park with `python3 tools/bot_opt.py` (read `_logs/bot-opt/<stamp>-bot-opt.txt` only). Print pending ids with `python3 tools/bot_status.py`. Bot loads this mandate, then `--id opt-NNN` for the named item instead of scanning the Queue by hand. Do not add a JSON queue file.

## Read set

1. `design/refactor.md` (recipe only) when a split is required
2. One `design/code-map.md` **system row** for the named cluster
3. After the User names the item: only those live `.gd` bodies

Do not open the other Bot flow siblings. Do not walk the whole live tree.

## Pass

1. User names an item id (or the next pending item). Inventory that cluster with VM prove commands in `BOT.md`. Do not edit yet.
2. Implement only that item. Mark it `done` in the same PR with `python3 tools/bot_opt.py --status opt-NNN=done`.
3. Prove: `BOT.md`.

## Queue

Parked items sit between the markers. Agents must not hand-edit this section.

<!-- bot-opt:begin -->
<!-- bot-opt:next=5 -->

### opt-003 (pending)
- Title: Shared helper for Title/Placeholdia/Dungeon load legs
- Cluster: Autoload / flow
- Files: `scripts/app.gd`, `scripts/app/app_flow.gd`, `scripts/app/app_run.gd`, `scripts/app/app_boot.gd`, `scripts/app/app_set.gd`

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
