# Grok Build session flow

Status: protocol
Read when: Grok Build (CLI) path; every CLI instance after a gap

**Intent.** Vira is the conduit for design; Build is the conduit for implementation. Make her vision real with little friction. The design docs are a living plan, not a fixed route. Defer to her on design; suggest improvements and ask in the moment with a question prompt. Hard rules: gates before a PR, no hand-edited PNGs, no gate loops, never push `main`.

You can write the live tree. Second topic door: read it when the job touches that system (read-first, below); ask the User to name the owner before adding a new cross-system owner. Concurrent CLI chats: Slice, Bot notes, PC offload, Smoke tests. Do not fold in another role unless named.

## Design: Vira decides

A design or product question the docs do not settle (what a feature does, where it lives, who owns it, a new door or doc, copy and lore, save or entry behavior, scope splits, which of two valid routes) goes to the User with `ask_user_question`, before the design doc or any code. You may offer an improvement the same way. One batched call; each question gets 2-4 concrete options, recommended first and marked. Plain-text questions do not count.
Always-allow covers permissions only (Access, below), never a design question. A dismissed or timed-out question is not an answer: stop and report. No subagent deliberation; the User chooses. With no `ask_user_question` tool, ask in one plain message and stop.
Build decides code shape inside one system and starts open numbers coherent (debug menu, `tunables.md`).
Doc and code disagree: compare their change history, trust the newer, ask if unclear (`prove.md`, `list_changed.py --history`).

## First (once, before anything else)

Classify the request: **new feature / new system** (something the game lacks, or a rework of a player-facing system) or **change to what exists** (fix, tune, refactor, same-system API), from the User's wording ("add", "new", "rework" vs "fix", "tweak", "rename"). If unclear, ask once (options: new feature / change to existing; recommend the one the wording leans to).

New feature flow (in order; chain the steps and report at the end):
1. Owner: `python tools/list_route.py --door <door>`. No door or doc owns it (or it needs a second door) = a new or undocumented system: plan it (door, doc name, save keys, entry events, smokes) and ask every open question in one batch (Design: Vira decides); wait.
2. Design doc first: write or extend the owning topic via `tools/doc_patch.py` (what, where it lives, save keys, entry events), then implement.
3. Prove: the smoke phases mapped to the door (`routes.yaml` `smokes`, printed by `start_build_slice.py`) plus any assert or phase this feature needs (update or add: `build-job-cycle.md`). Pictures and UI-state proof: `shot-flows.md` (scripted flows via `run_shot_flow.py`, `routes.yaml` `shot_flows` printed by `start_build_slice.py`; `check_shot_gaps.py --changed` for new UI states, advisory: it prints, never fails; published frames go to `_out/shots/<flow>/` and Build places any asset copy itself, tooling never writes under `assets/`; extend the tool when it cannot stage the state).
4. Ship notes: `code_map.py patch` for touched live scripts, `tunables.md` for any number, `check_load_graph.py` when routes or docs moved. Build writes no changelog files (notes go in the commit message; the week-close `0.N.0.md` is a web session's: `versioning.md`). Then merge back (below) and report with rough edges.

## Read

Agents file once, then this file. Plan pair only if missing. Then the named topic. **A job that touches more than one system: read first.** List every system it touches, then read each one's doc and `code_map.py row` before changing anything. Imagine: `design/isolated-media.md` before any Imagine call. Gather / change / prove: `design/build-job-cycle.md`.

Git inventory (not gather): `tools/list_changed.py`. Search: `tools/list_xref.py`, not grep. Extract: `python tools/show_func.py --path <script> --name <func>`. No `python -c`. Do not archive the live path first or resume unnamed work from git status.

## Work

First message names the area. `python tools/start_build_slice.py --door <door>` (or `--job` / `--area`); it prints the door/job card (gates one line; open one only when its `when` matches), smoke phases, shot flows and the FORK line. `--area` has no route: name a door or job for smokes. Worktrees come from the week branch `grok-build-w{N}` (`--ref` overrides), never main. No week branch and no `--ref`: the tool fails with no FORK line; ask the User (question prompt) whether to start a new week (`python tools/week_start.py`). The gather session id (`--session` / `$GROK_SESSION_ID`) is saved; retries return to it; without one START warns. Change only in the worktree. Web build load/frame/heap checks are advisory: `tools/web_perf.py` on an exported site (`run_shots.py --mode web` is for web sessions, not Build).

Access (permission, not design): if a task needs something outside Build's normal reach (a new asset location, an external tool or network, files outside the allowed set), show the User a one-line confirm first (skipped under always-allow).

Just do: a User-named script rename/move (`move_script_cluster.py --dry-run`, then run; it rewrites refs), helpers and APIs inside one system (new helper files go in the facade's stem folder, `refactor.md` Cluster folders), and a tool that would reasonably help future tasks (`tools.md` rule 5; tell the User after). Ask first (Design: Vira decides): a new cross-system owner (a new `routes.yaml` door owner), a named live-module replace, a greenfield rewrite, or copying archive scenes over live.

## Red prove, merge-back

Red prove: one diagnosis and one fix per retry (`tools.md` rule 10). The prove tool prints a fork of the gather session into this worktree (`grok --cwd PATH -r ID --fork-session`): gather context kept, read `git diff grok-build-w{N}...HEAD` (`build-job-cycle.md`).
Green prove: commit in the worktree (HEAD is detached), then `git merge --no-ff <commit>` in the checkout holding `grok-build-w{N}` (never main), short note in the message; resolve conflicts yourself. A change the User would check by hand (balance, audio, visuals / art, controls) needs a question prompt on whether the playtest looks good, and approval, before the merge. Refactors, tools, docs and tests merge on green.

## Other roles in this instance

- Bot notes: park with `python tools/bot_opt.py`. Do not implement those items or open a Bot PR.
- Tools: `design/tools.md` (catalog, new-tool rule 5, tools-not-scratches rule 7); PC offload: `design/pc-offload.md`. You may edit or add a tool in the same task.
- Smoke tests: Build runs the mapped phases at prove and updates or adds the asserts for any system it implements (`build-job-cycle.md`). The dedicated smoke session is `debug-smokes.md`.
- I2V: this path, isolated-media gate, stay in the slice thread.

Archive pins are CI-only (`versioning.md`, `archive_catalog.json`); do not invent pin SHAs.

## After a job

Proof rules (`prove.md`): one-line intended outcome before a behavior change; a missing required asset fails loudly (no fallback without the User's OK); report "gates pass", not "proved"; look and sound are unverified until the User confirms.

Gates: `design/tools.md` rule 10 (batch, once, at most 2 reruns). Prefer `python tools/run_build_gate.py` and `python tools/read_summary.py --job build-gate` (import check plus an advisory `check_shot_gaps.py --changed` print). Never hand-edit `version.json`. Do not commit `_logs/`. Report rough edges (rule 9) and fix tool ones in the same task.
