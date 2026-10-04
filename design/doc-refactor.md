# Design-doc facades

Status: protocol  
Read when: splitting topic `design/*.md` into a door + siblings; Grok Bot doc facade flow

## Goal

Cut routing tokens without losing comprehension. Do not change what the docs say. Move existing prose; fix links / README index rows.

## Model (match art-pipeline)

- art_pipeline is the template. One **door** (facade) keeps Status, Read when, Code (if any), and a **Job → Open** table; siblings hold the heavy sections tied to one job.
- Callers keep linking the **facade path** unless they need one sibling.

## Caps

The Bot's doc size targets live in `grok-bot-docs.md`; `tools/list_oversize_docs.py --bot` lists sizes.

## Scope

In: topic files under `design/*.md`; protocol-family updates the split needs (the Bot Job file, this file, `design/README.md` index rows, `design/code-map.md` only if a script path must stay accurate); one `design/changelog/{label}.md` per shipping PR.
Out: changing rules, tunables or player-facing meaning; rewriting `design/changelog/**` history (archiving: `design/versioning.md`); the `docs/` Pages tree; mixing a doc sweep into a live script size sweep without User go; treating a sibling list as a file the agent must open.

## Pass order

1. Inventory by Length, largest first (targets: `grok-bot-docs.md`). Show the worklist; do not edit yet.
2. Split doors first (ui, debug, input, inventory, then other fat topics).
3. Update README "How to use" / topic index so agents open the facade, then only the named sibling.
4. Grep for stale "read the whole of X" wording; point at the Job table.

## Facade checklist

- [ ] Job table covers every former top-level `##` cluster (or routes to an existing sibling topic such as `gear-ui.md`).
- [ ] Preamble rules that apply to every job stay on the door; live snapshots travel with the matching sibling.
- [ ] Sibling bodies name no `design/*.md` paths (job targets stay on the door Job table and in `design/routes.yaml`).
- [ ] No behavior or rule change.

## Token rules

After inventory open **one** door and only the sibling for the active job. Do not concatenate siblings into chat; prefer Length summaries and heading lists over whole bodies.
