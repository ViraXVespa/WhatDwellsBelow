# Design-doc facades (Grok Bot)

Status: protocol  
Read when: Grok Bot documentation refactor / routing sweep; splitting a large `design/*.md` topic  
See also: `design/grok-bot-session.md`, `design/refactor.md`, `design/art-pipeline.md`, `design/README.md`

Grok Bot may refactor **topic design markdown** the same way it facades scripts: one **door** file plus siblings opened only when the job matches. Goal: cut routing tokens without losing binding comprehension.

This is **not** a feature rewrite. Do not change binding meaning. Move existing prose; fix links / See also / README index rows.

## Model (match art-pipeline)

`design/art-pipeline.md` is the template:

1. Facade keeps Status / Read when / See also / Code (if any).
2. Facade states it is the door and has a **Job → Open** table.
3. Sibling files hold the heavy sections.
4. Callers keep linking the **facade path** (`design/ui.md`) unless they need one sibling.

## Caps (soft)

| Kind | Target | Rule |
|------|--------|------|
| Facade (door) | Prefer under **4KB** | Job table + non-negotiables only; no live-snapshot dumps |
| Sibling | Prefer under **8KB** | One job cluster; split again if a single `##` section dominates |
| Hard stop | **~12KB** | Do not leave a touched topic file above ~12KB if a legal section split exists |

Sizes use filesystem Length (same spirit as scripts). Prefer `tools/list_oversize_docs.ps1` when present.

## In scope

- Topic files under `design/*.md` (and later `design/<area>/` if a cluster earns a folder)
- Protocol family updates required by the split (`grok-bot-session.md`, this file, `README.md` index rows, See also pointers)
- One `design/changelog/{label}.md` per shipping PR

## Out of scope

- Changing binding rules, tunables, or player-facing meaning
- Rewriting `design/changelog/**` history (archiving prior series is separate: `design/versioning.md`)
- `docs/` Pages export tree
- Mixing a doc sweep into a live script size sweep without User go

## Pass order

1. Inventory topic files by Length; rank over ~12KB, then over ~8KB.
2. Show worklist; do not edit yet.
3. Split doors first (ui, debug, input, inventory, then other fat topics).
4. Update README "How to use" / topic index so agents open the facade, then only the named sibling.
5. Grep for stale "read the whole of X" wording; point at the job table.

## Facade checklist

- [ ] Job table covers every former top-level `##` cluster (or explicitly routes to an existing sibling topic such as `gear-ui.md`)
- [ ] Preamble non-negotiables that apply to every job stay on the facade
- [ ] Live snapshots travel with the matching job sibling (not the door)
- [ ] See also on siblings points back to the facade + peers
- [ ] No behavior / binding change

## Token rules

- After inventory, open **one** facade and **only** the sibling for the active job.
- Do not concatenate all siblings into chat "for context."
- Prefer Length summaries / headings lists over pasting whole markdown bodies.
