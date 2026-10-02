# Grok Build session flow

Status: protocol
Read when: Grok Build (CLI) path; every CLI instance after a gap

You can write the live tree.
Second topic door: ask the User to name the owner first. If `conflicts_with` lists the pair, do not open the second door in this slice.

Concurrent CLI chats: Slice, Bot notes, PC offload, Smoke tests. Do not fold another role into this thread unless the User names it here. Pins are User-only.

## Design decisions: ask, never decide

Any design or product decision, open question, or ambiguity the docs do not settle goes to the User with the `ask_user_question` tool (Grok Build's question card), right away and before the design doc or any code. Covers: what a feature does, where it lives, who owns it, a new door or doc, copy and lore, save or entry behavior, scope splits, and which of two valid routes to take. Batch the questions into one call; give each 2-4 concrete options with the recommended one first and marked. Plain-text questions in the transcript do not count.
Always-allow / always-approve covers permissions only (Access, below). It never answers, skips, or defaults a design question. A dismissed or timed-out question is not an answer: stop and report, do not pick. No committee, subagents or multi-agent deliberation to choose; the User chooses. If this session has no `ask_user_question` tool, ask in one plain message and stop.
Build still decides code shape inside one system and starts open numbers coherent (exposed in the debug menu and `tunables.md`).

## First (once, before anything else)

Classify the request: **new feature / new system** (something the game does not have yet, or a rework of a player-facing system), or **change to what exists** (fix, tune, refactor, same-system API). Decide from the User's language ("add", "new", "rework", "system" vs "fix", "tweak", "rename"). If it is not clear, ask with `ask_user_question` (options: new feature / change to existing; recommend the one the wording leans to). Do not ask again this session.

New feature flow (in order, one job each; pause and report after every job):
1. Owner: `python tools/list_route.py --door <door>`. If no door or doc owns it, or it needs a second door, stop and propose through `ask_user_question` (Design decisions): door, doc name, and every open question in one batch with options. Do not guess canon, copy, or design choices; wait for the answers.
2. Design doc first: write or extend the owning topic via `tools/doc_patch.py` (what, where it lives, save keys, entry events), then implement.
3. Prove: the smoke phases mapped to the door (`routes.yaml` `smokes`, printed by `start_build_slice.py`) plus any assert or phase this feature needs (update or add; see `build-job-cycle.md`). Pictures and UI-state proof: `shot-tool.md` (scripted flows via `run_shot_flow.py`, `routes.yaml` `shot_flows` printed by `start_build_slice.py`; `check_shot_gaps.py --changed` for new UI states; extend the tool when it cannot stage the state).
4. Ship notes: `code_map.py patch` for touched live scripts, `tunables.md` for any number, `doc_patch.py changelog --bullet` for the player-visible change, `check_load_graph.py` when routes or docs moved. Then stop and report with rough edges.

## Read

Agents file once, then this file. Law pair only if missing. Then the named topic. Imagine: `design/isolated-media.md` before any Imagine call. Gather / change / prove: `design/build-job-cycle.md`.

Git inventory (not gather): `tools/list_changed.py`. Search: `tools/list_xref.py`, not grep. Extract: `python tools/show_func.py --path <script> --name <func>`. No `python -c`. Do not start by archiving the live path. Do not resume unnamed work from git status.

## Work

First message names the area. `python tools/start_build_slice.py --door <door>` (or `--job` / `--area`); it prints the route and the mapped smoke phases. Session id is optional (`--session` or `$GROK_SESSION_ID`); without it FORK/RETRY carry a `<gather-session-id>` placeholder for the User. Change only in the FORK worktree. Red prove: RETRY line, not another patch on the guilty transcript.

Access (permission, not design): if a task needs something outside Build's normal reach (a new asset location, an external tool or network, files outside the allowed set), show the User a one-line confirm first, or proceed when the User has set always-allow. Design questions are never covered by always-allow.

Just do: helpers and APIs inside one system (new helper files go in the facade's stem folder, `refactor.md` Cluster folders). Stop and ask (Design decisions): a new cross-system owner (a new `routes.yaml` door owner), a named live-module replace, a greenfield rewrite, or copying archive scenes over live.

## Other roles in this instance

- Bot notes: park with `python tools/bot_opt.py`. Do not implement those items or open a Bot PR.
- Tools: `design/tools.md` (catalog); PC offload habits: `design/pc-offload.md`. New runner: ask and wait (Design decisions; catalog rule 5). Tools, not scratches: if you would need it again, update the tool or propose a new one; scratches only for niche one-offs, in temp. You may edit a tool in the same task.
- Smoke tests: Build runs the mapped phases at prove and updates or adds the asserts for any system it implements (`build-job-cycle.md`). The dedicated smoke session is `debug-smokes.md`. Bot limits stay in `BOT.md`.
- I2V: this path, isolated-media gate, stay in the slice thread.

Do not cap-split. Size lives in `design/gdscript-law.md`.
Archives are pinned commits in `scripts/data/archive_catalog.json`. Do not invent pin SHAs.

## After a slice

No loops: batch fixes, gate once per batch, at most 2 reruns, then report (`design/tools.md` rule 10). Prefer `python tools/run_build_gate.py` and `_logs/build-gate/summary.txt`. That gate is an import check. Script-cap is opt-in `--script-cap`. Stop and report. Two reds: stop. Add the changelog bullet for any player-visible change (`python tools/doc_patch.py changelog --bullet "..."`; never hand-edit `scripts/data/version.json`). Do not commit `_logs/`. Report the rough edges you hit (rule 9 in the catalog) and fix tool ones in the same task.
