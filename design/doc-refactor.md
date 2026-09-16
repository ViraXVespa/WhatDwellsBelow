# Design-doc facades

Status: protocol  
Read when: splitting topic `design/*.md` into a door + siblings; Grok Bot doc facade flow  


## Goal

Cut routing tokens without losing binding comprehension. Do not change binding meaning. Move existing prose; fix links / README index rows.

## Model (match art-pipeline)

- `design/art-pipeline.md` is the template.
- Facade keeps: Status, Read when, See also, Code (if any).
- Facade states it is the door and has a **Job → Open** table.
- Sibling files hold the heavy sections.
- Callers keep linking the **facade path** (`design/ui.md`) unless they need one sibling.

## Caps (soft)

- **Facade (door):** prefer under **4KB** — Job table + non-negotiables only; no live-snapshot dumps.
- **Sibling:** prefer under **8KB** — one job cluster; split again if a single `##` section dominates.
- **Hard stop:** **~12KB** — do not leave a touched topic file above ~12KB if a legal section split exists.
- Sizes use filesystem Length (same spirit as scripts). Prefer `tools/list_oversize_docs.ps1` when present.

## In scope

- Topic files under `design/*.md` (and later `design/<area>/` if a cluster earns a folder).
- Protocol family updates required by the split (Bot door Job table, this file, `design/README.md` index rows, `design/code-map.md` only if a script path must stay accurate).
- One `design/changelog/{label}.md` per shipping PR.

## Out of scope

- Changing binding rules, tunables, or player-facing meaning.
- Rewriting `design/changelog/**` history (archiving prior series is separate: `design/versioning.md`).
- `docs/` Pages export tree.
- Mixing a doc sweep into a live script size sweep without User go.
- Treating `See also:` as a file the agent must open.

## Pass order

1. Inventory topic files by Length; rank over ~12KB, then over ~8KB.
2. Show worklist; do not edit yet.
3. Split doors first (ui, debug, input, inventory, then other fat topics).
4. Update README "How to use" / topic index so agents open the facade, then only the named sibling.
5. Grep for stale "read the whole of X" wording; point at the job table.

## Facade checklist

- [ ] Job table covers every former top-level `##` cluster (or explicitly routes to an existing sibling topic such as `gear-ui.md`).
- [ ] Preamble non-negotiables that apply to every job stay on the facade.
- [ ] Live snapshots travel with the matching job sibling (not the door).
- [ ] Sibling `See also` may name boundary **topic doors** only. It must not name the parent already open, siblings of the current door, path/session files, or a path that does not exist.
- [ ] No behavior / binding change.

## Token rules

- After inventory, open **one** facade and **only** the sibling for the active job.
- Do not concatenate all siblings into chat "for context."
- Prefer Length summaries / headings lists over pasting whole markdown bodies.

## Door + siblings layout

- One **door** (facade) file with a **Job → Open** table.
- Siblings contain heavy sections tied to specific jobs.
- Callers link to the facade unless a specific sibling is required.
