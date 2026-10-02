# Grok Build session flow

Status: protocol
Read when: Grok Build (CLI) path; every CLI instance after a gap

You can write the live tree.
Second topic door: ask the User to name the owner first. If `conflicts_with` lists the pair, do not open the second door in this slice.

Concurrent CLI chats: Slice, Bot notes, PC offload, Smoke tests. Do not fold another role into this thread unless the User names it here. Pins are User-only.

## First (once, before anything else)

Classify the request: **new feature / new system** (something the game does not have yet, or a rework of a player-facing system), or **change to what exists** (fix, tune, refactor, same-system API). Decide from the User's language ("add", "new", "rework", "system" vs "fix", "tweak", "rename"). If it is not clear, ask the User one line: "New feature or change to existing?" Do not ask again this session.

New feature flow (in order, one job each; pause and report after every job):
1. Owner: `python tools/list_route.py --door <door>`. If no door or doc owns it, or it needs a second door, stop and propose (door, doc name, open questions). Do not guess canon, copy, or design choices; list them as questions.
2. Design doc first: write or extend the owning topic via `tools/doc_patch.py` (what, where it lives, save keys, entry events), then implement.
3. Prove: the smoke phases mapped to the door (`routes.yaml` `smokes`, printed by `start_build_slice.py`) plus any assert or phase this feature needs (update or add; see `build-job-cycle.md`). Pictures: `shot-tool.md` (extend the tool when it cannot stage the state).
4. Ship notes: `code_map.py patch` for touched live scripts, `tunables.md` for any number, `doc_patch.py changelog --bullet` for the player-visible change, `check_load_graph.py` when routes or docs moved. Then stop and report with rough edges.

## Read

Agents file once, then this file. Law pair only if missing. Then the named topic. Imagine: `design/isolated-media.md` before any Imagine call. Gather / change / prove: `design/build-job-cycle.md`.

Git inventory (not gather): `tools/list_changed.py`. Search: `tools/list_xref.py`, not grep. Extract: `python tools/show_func.py --path <script> --name <func>`. No `python -c`. Do not start by archiving the live path. Do not resume unnamed work from git status.

## Work

First message names the area. `python tools/start_build_slice.py --door <door>` (or `--job` / `--area`); it prints the route and the mapped smoke phases. Session id is optional (`--session` or `$GROK_SESSION_ID`); without it FORK/RETRY carry a `<gather-session-id>` placeholder for the User. Change only in the FORK worktree. Red prove: RETRY line, not another patch on the guilty transcript.

Access: if a task needs something outside Build's normal reach (a new asset location, an external tool or network, files outside the allowed set), show the User a one-line confirm for permission first, or proceed when the User has set always-allow.

Just do: helpers and APIs inside one system. Stop and propose: a new cross-system owner (a new `routes.yaml` door owner), a named live-module replace, a greenfield rewrite, or copying archive scenes over live.

## Other roles in this instance

- Bot notes: park with `python tools/bot_opt.py`. Do not implement those items or open a Bot PR.
- Tools: `design/tools.md` (catalog); PC offload habits: `design/pc-offload.md`. New runner: propose and wait (catalog rule 5). Tools, not scratches: if you would need it again, update the tool or propose a new one; scratches only for niche one-offs, in temp. You may edit a tool in the same task.
- Smoke tests: Build runs the mapped phases at prove and updates or adds the asserts for any system it implements (`build-job-cycle.md`). The dedicated smoke session is `debug-smokes.md`. Bot limits stay in `BOT.md`.
- I2V: this path, isolated-media gate, stay in the slice thread.

Do not cap-split. Size lives in `design/gdscript-law.md`.
Archives are pinned commits in `scripts/data/archive_catalog.json`. Do not invent pin SHAs.

## After a slice

Prefer `python tools/run_build_gate.py` and `_logs/build-gate/summary.txt`. That gate is an import check. Script-cap is opt-in `--script-cap`. Stop and report. Two reds: stop. Add the changelog bullet for any player-visible change (`python tools/doc_patch.py changelog --bullet "..."`; never hand-edit `scripts/data/version.json`). Do not commit `_logs/`. Report the rough edges you hit (rule 9 in the catalog) and fix tool ones in the same task.
