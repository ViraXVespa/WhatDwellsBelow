# Grok Build session flow

Status: protocol
Read when: Grok Build (CLI) path; every CLI instance after a gap

You can write the live tree.
Second topic door: ask the User to name the owner first.

Concurrent CLI chats: Slice, Bot notes, PC offload, Smoke tests. Do not fold another role into this thread unless the User names it here. Pins are User-only.

## Design decisions: ask, never decide

Any design or product decision, open question, or ambiguity the docs do not settle goes to the User with `ask_user_question`, right away and before the design doc or any code (what a feature does, where it lives, who owns it, a new door or doc, copy and lore, save or entry behavior, scope splits, which of two valid routes). One batched call; each question gets 2-4 concrete options, recommended first and marked. Plain-text questions in the transcript do not count.
Always-allow covers permissions only (Access, below), never a design question. A dismissed or timed-out question is not an answer: stop and report. No subagent or committee deliberation; the User chooses. With no `ask_user_question` tool, ask in one plain message and stop.
Build still decides code shape inside one system and starts open numbers coherent (exposed in the debug menu and `tunables.md`).

## First (once, before anything else)

Classify the request: **new feature / new system** (something the game lacks, or a rework of a player-facing system) or **change to what exists** (fix, tune, refactor, same-system API), from the User's wording ("add", "new", "rework" vs "fix", "tweak", "rename"). If unclear, ask once (options: new feature / change to existing; recommend the one the wording leans to).

New feature flow (in order, one job each; pause and report after every job):
1. Owner: `python3 tools/list_route.py --door <door>`. No door or doc owns it (or it needs a second door) = a new or undocumented system, also for a change that finds no door: stop, plan it (door, doc name, save keys, entry events, smokes) and ask every open question in one batch (Design decisions); wait.
2. Design doc first: write or extend the owning topic via `tools/doc_patch.py` (what, where it lives, save keys, entry events), then implement.
3. Prove: the smoke phases mapped to the door (`routes.yaml` `smokes`, printed by `start_build_slice.py`) plus any assert or phase this feature needs (update or add; see `build-job-cycle.md`). Pictures and UI-state proof: `shot-flows.md` (scripted flows via `run_shot_flow.py`, `routes.yaml` `shot_flows` printed by `start_build_slice.py`; `check_shot_gaps.py --changed` for new UI states (advisory for Build: it prints, never fails; Bot fails on it); published frames go to `_out/shots/<flow>/` and Build places any asset copy itself, tooling never writes under `assets/`; extend the tool when it cannot stage the state).
4. Ship notes: `code_map.py patch` for touched live scripts, `tunables.md` for any number, `doc_patch.py changelog --bullet` for the player-visible change, `check_load_graph.py` when routes or docs moved. Then stop and report with rough edges.

## Read

Agents file once, then this file. Law pair only if missing. Then the named topic. Imagine: `design/isolated-media.md` before any Imagine call. Gather / change / prove: `design/build-job-cycle.md`.

Git inventory (not gather): `tools/list_changed.py`. Search: `tools/list_xref.py`, not grep. Extract: `python3 tools/show_func.py --path <script> --name <func>`. No `python -c`. Do not start by archiving the live path. Do not resume unnamed work from git status.

## Work

First message names the area. `python3 tools/start_build_slice.py --door <door>` (or `--job` / `--area`); it prints the door/job card (gates one line; open one only when its `when` matches), smoke phases and shot flows. `--area` has no route: name a door or job to get smokes. Session id is optional (`--session` or `$GROK_SESSION_ID`); without it FORK/RETRY carry a `<gather-session-id>` placeholder for the User. Change only in the FORK worktree. Red prove: RETRY line, not another patch on the guilty transcript. Web build load/frame/heap checks are advisory: `tools/web_perf.py` on an exported site (`run_shots.py --mode web` is for web sessions, not Build).

Access (permission, not design): if a task needs something outside Build's normal reach (a new asset location, an external tool or network, files outside the allowed set), show the User a one-line confirm first, or proceed when the User has set always-allow. Design questions are never covered by always-allow.

Just do: a User-named script rename/move (`move_script_cluster.py --dry-run`, then run; it rewrites refs), helpers and APIs inside one system (new helper files go in the facade's stem folder, `refactor.md` Cluster folders). Stop and ask (Design decisions): a new cross-system owner (a new `routes.yaml` door owner), a named live-module replace, a greenfield rewrite, or copying archive scenes over live.

## Other roles in this instance

- Bot notes: park with `python3 tools/bot_opt.py`. Do not implement those items or open a Bot PR.
- Tools: `design/tools.md` (catalog, new-runner rule 5, tools-not-scratches rule 7); PC offload habits: `design/pc-offload.md`. You may edit a tool in the same task.
- Smoke tests: Build runs the mapped phases at prove and updates or adds the asserts for any system it implements (`build-job-cycle.md`). The dedicated smoke session is `debug-smokes.md`. Bot limits stay in `BOT.md`.
- I2V: this path, isolated-media gate, stay in the slice thread.

Do not cap-split. Size lives in `design/gdscript-law.md`.
Archives are pinned commits in `scripts/data/archive_catalog.json`. Do not invent pin SHAs.

## After a slice

Gates: `design/tools.md` rule 10 (batch, once, at most 2 reruns; two reds: stop). Prefer `python3 tools/run_build_gate.py` and `_logs/build-gate/summary.txt` (import check plus an advisory `check_shot_gaps.py --changed` print; script-cap is opt-in `--script-cap`). Add the changelog bullet for any player-visible change (`python3 tools/doc_patch.py changelog --bullet "..."`; never hand-edit `scripts/data/version.json`). Do not commit `_logs/`. Report the rough edges you hit (rule 9) and fix tool ones in the same task.
