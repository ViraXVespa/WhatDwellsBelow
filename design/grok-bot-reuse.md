# Grok Bot — staged reuse-map PR

Status: protocol  
Read when: Grok Bot Job table → staged reuse-map brief  

Binding for **Grok Bot** when the User names the staged reuse PR / reuse-map / quota reset with a brief ready.

## Mandate

Confirm `reuse_brief count` from `python3 tools/bot_status.py`. The current body of `design/reuse-map.md` is **one** PR goal. Implement that brief. Do not take a subset. Do not invent rows. Do not start a size sweep, extract hunt, relocate, or doc facade pass in the same session.

Web / chat writes that file in a Phase 4 emit. The Bot clears the completed Brief items from `design/reuse-map.md` on the same PR (keep the how-to headers). Do not add Ready / Done columns. After the User squash-merges, stop.

If `design/reuse-map.md` is missing the how-to header only, or the body under the how-to is the empty template (no brief), stop and report empty. Do not invent work.

Still refactor-shaped unless a row the User wrote is explicit and legal. No invented skills, rarities, hub upgrades, meta-progression, co-op, or tunables. No `Entity.gd` / UI framework / ECS. Touched live scripts ship under 10KB (`design/refactor.md`, recipe only). Do not keep splitting toward 5KB in this flow.

## Read set

1. `design/reuse-map.md` (the brief)
2. `design/refactor.md` when a touched file must split (recipe only)
3. One `design/code-map.md` **system row** for each cluster the brief names
   (Finding new candidates is a separate User-named sweep: `python3 tools/list_dupes.py --md PATH`, then tier the groups; only near-identical bodies move to a shared module.)
4. After that: only the live `.gd` files in the active cluster

Do not walk the live tree to rediscover copies the brief does not name.

## Pass

1. Show the brief back to the User as the PR mandate. Do not edit yet if the brief is ambiguous — ask once.
2. Implement the brief as one branch / one PR.
3. Update `design/code-map.md` when a new public helper path appears. Hot paths (gen, shaders, pixel loops, tool output): capture a golden BEFORE (gen result md5, camp/dungeon shots with `shot_diff.py`, old-vs-new bytes for tools) and revert any item that is not identical; keep GLSL text textually identical.
4. Clear the completed Brief items from `design/reuse-map.md` in the same PR. Leave the how-to headers. No Ready / Done columns.
5. Prove: `BOT.md`.
