# Grok Bot — optimization queue

Status: protocol  
Read when: Grok Bot Job table → named optimization item  

For **Grok Bot** optimization sessions only. Items are task files named `opt-N` in `design/tasks/`, owner bot (`python tools/task.py list --owner bot`). Bot does not invent items.

## Mandate

Execute **one** User-named item (or the next open opt item the User named). One PR. No new game systems.

- Same-system extracts, fewer loads, cache / hot-path helpers, defer work off Title→Play, drop unused preload paths — when the named item says so.
- Timing / preload / cache listed on that item is in scope. Player-facing design is not.
- Do not keep splitting toward 5KB in this flow.
- Dead-code items: inventory with `python tools/list_unused_funcs.py --limit 30` (report only; its `--apply` warning is in design/tools.md). Prove and doc edits: BOT.md and design/tools.md.
- Do not invent items, numbers, or extra clusters.

The Bot-notes Grok Build CLI is the usual parker. It may expand the User's wording from a thin layout check (one code-map row and/or one `list_xref`) and must ask once if an obvious gap is missing. Do not inventory the tree or write a pass plan into the item. Grok Bot investigates, plans, and implements. Park with `python tools/task.py new opt-next --owner bot ...` (it picks the next unused id). Print open ids with `python tools/bot_status.py`. Bot loads this mandate, then `python tools/task.py show opt-N` and that one file. Do not add a JSON queue file.

## Read set

1. `design/refactor.md` (recipe only) when a split is required
2. One `design/code-map.md` **system row** for the named cluster
3. After the User names the item: only those live `.gd` bodies

Do not open the other Bot flow siblings. Do not walk the whole live tree.

## Pass

1. User names an item id (or the next open item). Inventory that cluster with VM prove commands in `BOT.md`. Do not edit yet.
2. Implement only that item. Finish it in the same PR with `python tools/task.py done opt-N`.
3. Prove: `BOT.md`.
