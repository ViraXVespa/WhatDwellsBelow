# Grok Bot — documentation facades

Status: protocol  
Read when: Grok Bot Job table → doc facade / sibling split  

Binding for **Grok Bot** documentation facade sweeps only. Recipe: `design/doc-refactor.md`. No binding-meaning change. No live `.gd` size sweep in this PR unless a touched script path in a code map row must stay accurate.


## Mandate

Split fat topic `design/*.md` files to the art-pipeline door + siblings layout. Caps, pass order, and facade checklist live in `design/doc-refactor.md`.

- Door: prefer under **4KB** — Job table + non-negotiables. No live-snapshot dumps.
- Sibling: prefer under **8KB**. Split again if one `##` section dominates.
- Hard stop: do not leave a **touched** topic file above **~12KB** if a legal section split exists.
- Callers keep linking the **facade path** unless they need one sibling.
- One facade plus its new siblings per editing focus. Show the worklist; do not edit yet.

Out of scope: rewriting `design/changelog/**` history, `docs/` Pages export, mixing this sweep into a live script size sweep without User go, inventing systems.

## Read set

1. This file
2. `design/doc-refactor.md`
3. The `design/README.md` topic index row for the door
4. After inventory: that one door and only the sibling for the active job
5. At ship: `scripts/data/version.json` + `design/versioning-log.md` body shape — not the changelog tree

Do not reopen the agents file unless types, warnings, tabs, or the 10KB cap left context. Do not concatenate all siblings into context. Do not open the staged reuse brief. Prefer Length / heading lists over pasting whole markdown bodies. Oversize list: `tools/list_oversize_docs.ps1` (skip `design/changelog/`).

## Pass

1. Inventory topic files by Length. Rank over ~12KB, then over ~8KB. Show worklist.
2. Split the named door first. Move existing prose. Fix links and README index rows. Update `design/code-map.md` only if a script path in a row must stay accurate.
3. Job table must cover every former top-level `##` cluster (or route to an existing sibling topic).
4. Live snapshots travel with the matching job sibling, not the door.
5. Sibling `See also` may name boundary **topic doors** only. It must not name the parent already open, siblings of the current door, path/session files, or a path that does not exist. See also is never a read list.
6. Grep for stale “read the whole of X” wording; point at the Job table.
7. Ship per the door. One `design/changelog/{label}.md` for the PR.
