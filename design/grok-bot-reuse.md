# Grok Bot — staged reuse-map PR

Status: protocol  
Read when: Grok Bot Job table → staged reuse-map brief  
See also: `design/grok-bot-session.md`, `design/reuse-map.md`, `design/refactor.md`

`See also:` is an index, not a read list. Open the door first. Then this file. Then `design/reuse-map.md` only if that brief is not the empty template.

Binding for **Grok Bot** when the User names the staged reuse PR / reuse-map / quota reset with a brief ready.

## Mandate

The current body of `design/reuse-map.md` is **one** PR goal. Implement that brief. Do not take a subset. Do not invent rows. Do not mark rows done. Do not start a size sweep, extract hunt, relocate, or doc facade pass in the same session.

Web / chat Phase 7 owns that file. After squash-merge, stop. Clearing or replacing the brief is the next web session, not this flow.

If `design/reuse-map.md` is missing the how-to header only, or the body under the how-to is the empty template (no brief), stop and report empty. Do not invent work.

Still refactor-shaped unless a row the User wrote is explicit and legal. No invented skills, rarities, hub upgrades, meta-progression, co-op, or tunables. No `Entity.gd` / UI framework / ECS. Touched live scripts ship under 10KB (`design/refactor.md`). Do not keep splitting toward 5KB in this flow.

## Read set

1. `AGENTS.md`
2. `design/grok-bot-session.md`
3. This file
4. `design/reuse-map.md` (the brief)
5. `design/refactor.md` when a touched file must split
6. The `design/README.md` **code map** row for each cluster the brief names
7. After that: only the live `.gd` files in the active cluster
8. At ship: `scripts/data/version.json` + `design/versioning.md` body shape

Do not walk the live tree to rediscover copies the brief does not name.

## Pass

1. Show the brief back to the User as the PR mandate. Do not edit yet if the brief is ambiguous — ask once.
2. Implement the brief as one branch / one PR.
3. Update `design/README.md` code map when a new public helper path appears.
4. Do not rewrite `design/reuse-map.md` except a compile-safe typo fix the User already named. No Ready / Done columns.
5. Verify with `design/pc-offload.md` runners as needed. Ship per the door.
