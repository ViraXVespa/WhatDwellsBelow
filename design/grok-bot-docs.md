# Grok Bot — documentation facades

Status: protocol  
Read when: Grok Bot Job table → doc facade / sibling split  
See also: `design/grok-bot-session.md`, `design/doc-refactor.md`

`See also:` is an index, not a read list. Open the door first. Then this file. Recipe: `design/doc-refactor.md`.

Binding for **Grok Bot** documentation facade sweeps only. No binding-meaning change. No live `.gd` size sweep in this PR unless a touched script path in a code map row must stay accurate.

## Mandate

Split fat topic `design/*.md` files to the art-pipeline door + siblings layout.

- Door: prefer under **4KB** — Job table + non-negotiables. No live-snapshot dumps.
- Sibling: prefer under **8KB**. Split again if one `##` section dominates.
- Hard stop: do not leave a **touched** topic file above **~12KB** if a legal section split exists.
- Callers keep linking the **facade path** unless they need one sibling.
- One facade plus its new siblings per editing focus. Show the worklist; do not edit yet.

Out of scope: rewriting `design/changelog/**` history, `docs/` Pages export, mixing this sweep into a live script size sweep without User go, inventing systems.

## Read set

1. `AGENTS.md`
2. `design/grok-bot-session.md`
3. This file
4. `design/doc-refactor.md`
5. The `design/README.md` topic index row for the door
6. After inventory: that one door and only the sibling for the active job
7. At ship: `scripts/data/version.json` + `design/versioning.md` body shape

Do not concatenate all siblings into context. Do not open `design/reuse-map.md`. Prefer Length / heading lists over pasting whole markdown bodies. Oversize list: `tools/list_oversize_docs.ps1` (skip `design/changelog/`).

## Pass

1. Inventory topic files by Length. Rank over ~12KB, then over ~8KB. Show worklist.
2. Split the named door first. Move existing prose. Fix links and README index rows.
3. Job table must cover every former top-level `##` cluster (or route to an existing sibling topic).
4. Live snapshots travel with the matching job sibling, not the door.
5. Sibling `See also` points back to the facade + peers as an **index**, not a read list.
6. Grep for stale “read the whole of X” wording; point at the Job table.
7. Ship per the door. One `design/changelog/{label}.md` for the PR.
