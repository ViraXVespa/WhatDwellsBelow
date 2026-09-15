# Grok Bot — documentation facades

Status: protocol  
Read when: Grok Bot Job table → doc facade / sibling split  
See also: `design/grok-bot-session.md`

Binding for **Grok Bot** documentation facade sweeps only. Recipe: `design/doc-refactor.md`. No binding-meaning change. No live `.gd` size sweep in this PR unless a touched script path in a code map row must stay accurate.

## Mandate

Split fat topic `design/*.md` files to the art-pipeline door + siblings layout. Caps, pass order, and facade checklist live in `design/doc-refactor.md`.

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

Follow `design/doc-refactor.md`. Sibling `See also` is the door only. Ship per `design/grok-bot-session.md`. One `design/changelog/{label}.md` for the PR.
