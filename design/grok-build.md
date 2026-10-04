# Grok Build session flow

Status: protocol
Read when: Grok Build (CLI) path; every CLI instance after a gap

**Intent.** Vira is the conduit for design; Build is the conduit for implementation. Make her vision real with little friction. The design docs are a living plan, not a fixed route. Defer to her on design; suggest improvements and ask in the moment with a question prompt. Hard rules: gates before a PR, no gate loops, never push `main`.

You can write the live tree. Second topic door: read it when the job touches that system; ask the User to name the owner before adding a new cross-system owner. Do not fold in another role unless named.

## Design: Vira decides

A design or product question the docs do not settle (what a feature does, where it lives, who owns it, a new door or doc, copy and lore, save or entry behavior, scope splits, which of two valid routes) goes to the User with `ask_user_question`, before the design doc or any code. Improvements go the same way. One batched call; each question gets 2-4 concrete options you write. Mark one recommended only for code shape or process, never for a look, a feel or a scope. Plain-text questions do not count.
Always-allow covers permissions only (Access), never a design question. A dismissed or timed-out question is not an answer: stop and report. No subagent deliberation; the User chooses. With no `ask_user_question` tool, ask in one plain message and stop.
Build decides code shape inside one system and starts open numbers coherent (debug menu, `tunables.md`).
Doc and code disagree: trust the newer (`list_changed.py --history`), ask if unclear.

## Restate, then change

Before any edit, write the ask in your own words: what was asked, and what would be visible or observable if it worked. Ask the User whatever is unclear (you write the questions). Wait for the answer. A word the User used is not yet an answer to what it means here.

Visual work: shoot the current state first (baseline). Finish one unit or screen, open the before and after PNGs and say what is on them, then stop and ask the User with the PNG paths. After a rejection the next step is a question, not an edit.

Every pass, in small batches: `python tools/check_gd_load.py` (loads each changed `.gd` with its autoloads). Read every output you run: unread stderr or check results are not harmless, and a check that does not cover the claim is not evidence. Detail: `build-job-cycle.md`.

## First (once, before anything else)

Classify the request: **new feature / new system** (something the game lacks, or a rework of a player-facing system) or **change to what exists** (fix, tune, refactor, same-system API), from the User's wording. If unclear, ask once.

New feature flow (chain the steps and report at the end):
1. Owner: `python tools/list_route.py --door <door>`. No door or doc owns it (or it needs a second door) = a new system: plan it (door, doc name, save keys, entry events, smokes), ask every open question in one batch; wait.
2. Design doc first: write or extend the owning topic via `tools/doc_patch.py`, then implement.
3. Prove, matched to the change (`prove.md`): `check_gd_load.py` each pass; a visual change adds the door's `shot_flows` (`check_shot_gaps.py --changed` failing is a failed prove). Packing and image tools may write under `assets/` when that is their job.
4. Ship notes: `code_map.py patch` for touched live scripts, `tunables.md` for any number, `check_load_graph.py` when routes or docs moved. Build writes no changelog files (notes go in the commit message; the week-close `0.N.0.md` is a web session's: `versioning.md`). Merge back (below); report rough edges.

## Read

Agents file once, then this file. Plan pair only if missing. Then the named topic. **A job that touches more than one system: read first** (each one's doc and `code_map.py row`, before changing anything). Imagine: `design/isolated-media.md` first. Gather / change / prove: `design/build-job-cycle.md`.

Git inventory (not gather): `tools/list_changed.py`. Search: `tools/list_xref.py`, not grep. Extract: `python tools/show_func.py --path <script> --name <func>`. No `python -c`. Do not archive the live path first or resume unnamed work from git status.

## Work

First message names the area. In the main checkout run `python tools/start_build_slice.py --door <door>` (or `--job` / `--area`): it prints the door card, smoke phases, shot flows and the START lines (the worktree, then a NEW session in it). A visual door, job or area with no `shot_flows` fails there: ask the User or create the flow. Worktrees come from the week branch `grok-build-w{N}` (`--ref` overrides), never main; no week branch and no `--ref`: no START line, ask the User (question prompt) whether to start a new week (`python tools/week_start.py`). Then this session stops: no gather, no edits. A fork keeps its parent's directory and `--fork-session` cannot be combined with `--worktree`, so only a session started fresh in the worktree works there. The User runs START and pastes the task; restate, gather and change happen in that session. A named worktree is the slice; do not cut a second. When gather is done run `python tools/start_build_slice.py --checkpoint` (saves `$GROK_SESSION_ID`; empty: ask the User, `/session-info`) so a red prove can be forked later. **Build never launches grok**: no fork, no headless run, no `--prompt-file` / `--max-turns`; print the command, the User runs it (the isolated-media runner is the one exception).

Access (permission, not design): if a task needs something outside Build's normal reach (a new asset location, an external tool or network, files outside the allowed set), show the User a one-line confirm first.

Just do: a User-named script rename/move (`move_script_cluster.py --dry-run`, then run), helpers and APIs inside one system (`refactor.md` for placement), and a tool that would help future tasks (`tools.md` rule 5; tell the User after). Ask first: a new cross-system owner, a named live-module replace, a greenfield rewrite, or copying archive scenes over live.

## Red prove, merge-back

Red prove, merge-back, the playtest confirm: `build-job-cycle.md`. One diagnosis and one fix per retry (`tools.md` rule 10). Never merge into main.

## Other roles in this instance

- Bot notes: park with `python tools/bot_opt.py`; do not implement them or open a Bot PR.
- Tools: `design/tools.md`; PC offload: `design/pc-offload.md`. You may edit or add a tool in the same task.
- Smoke tests: Build updates or adds the asserts for what it implements (`build-job-cycle.md`; `debug-smokes.md`).
- I2V: isolated-media gate, in the slice thread. Archive pins are CI-only (`versioning.md`); do not invent them.

## After a job

Proof rules (`prove.md`): one-line intended outcome before a behavior change; a missing required asset fails loudly (no fallback without the User's OK); report "gates pass", not "proved". Do not ask the User for the playtest confirm until the compile check passed, every output was read, and (visual) the before and after PNGs were opened and described. The confirm question carries a summary of what changed, plus the PNG paths. Look and sound stay unverified until confirmed.

Gates: `design/tools.md` rule 10 (batch, once, at most 2 reruns; iterating one visual unit with the User is exempt). Code: `check_gd_load.py` each pass, then `python tools/run_build_gate.py` and `python tools/read_summary.py --job build-gate` once. A visual change adds `run_shot_flow.py` and the door's UI load check; a missing or stale frame fails the prove. Never hand-edit `version.json` or commit `_logs/`. Report rough edges (rule 9) and fix tool ones in the same task.
