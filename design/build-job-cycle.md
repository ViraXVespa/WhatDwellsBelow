# Build job cycle

Status: protocol
Read when: Grok Build gather, change, or prove

For **Grok Build** only. Web / chat and Grok Bot do not load this file.

Intent: Vira owns design; Build implements it and defers to her on design, asking whenever that helps; the docs are the living plan, not a fixed route (`grok-build.md`).

A **job** is one cycle: gather, change, prove. Report when the work is done. Ask as many questions as the job needs, in as many rounds as it needs, and ask again whenever a discovery changes what the User will see or what was assumed. No limit on count or rounds. **Multi-system job:** before the first change, list every system it touches and read each one's doc and `code_map.py row`.

Gather is planned `list_xref` plus planned `show_func` plus one `code_map.py row` when a live script is in the slice. `summarize_scripts` is not gather. `list_route` and `list_changed` stay outside the gather set (`list_route` is slice boot; `list_changed` is git inventory).

Name a **planned gather list** (distinct xref patterns and show-func names, as long as the systems need) before the first catalog call. Those planned calls are one gather phase; add to the list when a new system turns up. Do not repeat the same command with the same args.

Change is one slice in a Grok worktree cut from the week branch `grok-build-w{N}`. The User starts it with `python tools/open_slice.py [AREA]`, which runs `grok --worktree=NAME --ref grok-build-w{N}` (a NEW session whose directory is the worktree). A Grok worktree is a full clone under `.grok/worktrees/<repo>/<name>`: `.git` is a directory and HEAD is the week branch itself, not detached; `start_build_slice.py` recognises it by that place, and also a true linked worktree. Gather and change run in that session; it starts with `start_build_slice.py` (IN A WORKTREE). The first message to the User says whether the agents file and the project skills loaded; if not, it says so and reads the agents file and `grok-build.md` by hand. Fallback from a main-checkout session: `start_build_slice.py` prints the START lines (worktree, then `cd` + `grok`), the User runs them and that session stops with nothing else done. Do not edit the main checkout. A worktree the User already named is the slice. When gather is done, `python tools/start_build_slice.py --checkpoint` saves this session's id (`$GROK_SESSION_ID`) as the checkpoint. If it fails (not a worktree, or an empty id), the next message to the User starts `Did not work: --checkpoint ...` and asks her for the id (`/session-info` in grok, or `grok sessions list` in the worktree), then reruns with `--session ID`. **Only `open_slice.py`, run by the User, launches grok; Build never does** (no fork, no headless run, no `--prompt-file`, no `--max-turns`; the isolated-media runner is the one exception). No brief or prompt for another session or process may forbid questions, and Build sets no run limits (turns, permissions) for one.

**Restate first.** A visual job first imports (`check_gd_load.py` once, then `run_godot_import_check.py`: a fresh worktree has nothing imported and new textures are not imported until then), then shoots and OPENS the baseline picture of the screen it will change (no flow for that screen yet: the flow is step 0, below). A baseline with `band=fail` or script errors is invalid: find the cause, re-shoot, and never use it as the "before" shot or call its errors pre-existing without proof. Then it writes the restate as visible text in the message, not only in reasoning: what was asked, what would be visible or observable if it worked, and what it does not yet know. Then it asks. The question set opens with a category, not a design choice: the outcome (what should it look like), whether the User has a reference (a picture, a game, a screen), and what is out of bounds (what must not change). Then ask the User about anything else unclear, including look, layout, material or texture and what counts as done (hers to decide); you write the questions, then wait for the answers, and ask again when an answer or a discovery changes what she will see. A word the User used (a name, a metaphor) is not yet an answer to what it means here. Until answered change nothing, except shot-flow files (`tools/shot-flows/`) and the `routes.yaml` mapping: creating them is part of the work.

**Every stop-and-ask message** carries two short lists for her to overrule: "Decisions I made that were yours" (each with the alternative) and "Assumptions carried from memory or docs". The first list also names every new asset, font, dependency and generated image (with the alternative, and its size). A generated image gets the one-line User confirm of Access (`grok-build.md`) before it is used. A font or asset must work in the web export (the agents file: the live path stays web-exportable); if one cannot, say so there. The message says whether the baseline PNG is the screen being changed, and the ask text itself holds every PNG path it refers to and what is on each, on repeat passes too. After a second rejection of the same thing, the next question offers "send me a reference (a picture, a game, a screen)" before more options.

**Did not work.** After ANY failed or skipped tool step (a failed `--checkpoint`, import or shot, a baseline taken with errors, a check you could not run), the next message to the User starts with `Did not work: <command> <one line of its output>`, even when you worked past it. It does not wait for her to ask.

**Step 0, a missing shot flow.** `start_build_slice.py` prints a STEP 0 note for a visual job with no flow mapped to it (exit 0; not a stop). Creating or adjusting the flow for the exact screen is the first job step (`shot-flows.md`, New UI state checklist); a job never borrows its door's flows as if they were its own. The end gates stay: the after-shot must exist and be opened, no missing or stale frame, and a new uncovered UI state needs a flow before the prove passes.

**Visual unit.** Baseline first (`run_shot_flow.py --flow N`; `--save-baseline DIR` keeps it), opened. Change one unit or screen. Open the before and after PNGs and say what is on each. Then stop and ask the User, putting the PNG paths in the ask text. Do not start the next unit. After a rejection the next step is a question about what was wrong, not an edit. Do not commit or push the slice's work until the User confirms the final shot: ask "Settled? commit?" (unless she said to commit now). Iterating one unit with the User is exempt from the rerun counts (`tools.md` rule 10).

**Every pass.** After each small batch of edits (a few files, never a sweep), run `python tools/check_gd_load.py`: it loads every changed and untracked `.gd` inside the project with its autoloads, so a stray `)` or a bad reference fails. The import check, a smoke and a standalone `--script` parse do not load every script, so none of them is evidence that the scripts compile. A multi-line splice gets its own check before the next edit.

**Read what you run.** Open stderr and every check result before you describe it; output you did not read is not harmless, and a passing check that does not cover the claim is not evidence of it. The playtest confirm is asked only after the compile check passed, the output is read, and (visual) the frames are opened and described. The question carries a short summary of what changed.

Prove matches the change, once at the end: the compile check each pass; a visual change adds its door's shot flow (opened and described) and that door's UI load check; then `run_build_gate.py --batch`. Do not import, then smoke, then import.

Smokes at prove: the phases mapped to the door or job in `routes.yaml` `smokes` (printed by `list_route` and `start_build_slice`; `run_smokes.py --door D` or `--job door.job` runs them). A system the slice implements or changes gets its asserts updated in the mapped phase helper (`debug-smokes.md`), or a new assert there, in the same change job. Unit runners (run the runner; do not open smoke helpers just to pick the command):

| Unit | Runner |
|------|--------|
| floor map / gen silhouette / placement specs | `tools/run_dungeon_map.py` `--seed 42 --floor 1` |
| Placeholdia to dungeon timing | `tools/run_dungeon_load_timing.py` |
| named phase asserts | `tools/run_smokes.py` `--door D` / `--job door.job` / `--phases N` |
| changed `.gd` load with autoloads (every pass) | `tools/check_gd_load.py` (`--files`, `--all`, `--base REF`) |
| import + load graph + names / unnamed prove | `tools/run_build_gate.py` |
| exported web build load, frame time, heap, asset sizes (advisory) | `tools/web_perf.py` (`--flow`, `--baseline`) after `export_web.py --out DIR` (`--site DIR`, baseline `tools/web-perf-baseline.json`) |

A new numbered phase, `--wdb-*-smoke` flag, or host scene is allowed only when the feature is new and no mapped phase fits (add it with the feature; name it in the report). A new catalog runner is fine when it would reasonably help future tasks (`tools.md` rule 5). A postcard or shot flow (`shot-tool.md`) is a deliverable or a visual check, not the build gate or a smoke; the headless flow asserts (`bot_smokes.py --flows`) may be named in the prove step. When a task needs a picture the tool cannot stage, extend the tool inside the change job (`shot-flows.md` gap process); do not hand-drive Godot or edit a PNG. A red postcard (`fail` band) gets one same-command rerun only for `truncated`, timeout or `busy`; otherwise fix the tool or script.

## New feature flow

1. Owner: `python tools/list_route.py --door <door>`. No door or doc owns it (or it needs a second door) = a new system: plan it (door, doc name, save keys, entry events, smokes), ask every open question, again as answers raise more; wait.
2. Design doc first: write or extend the owning topic via `tools/doc_patch.py`, then implement.
3. Prove, matched to the change (`prove.md`): `check_gd_load.py` each pass; a visual change adds its `shot_flows` (`check_shot_gaps.py --changed` failing fails the prove).
4. Ship notes: `code_map.py patch` for touched live scripts, `tunables.md` for any number, `check_load_graph.py` when routes or docs moved. No changelog files from Build (commit message: `versioning.md`).

## Slice messages (visual work)

The full form of the rules in the session flow doc.

- **First command and statement.** `start_build_slice.py` is the first command of a slice, before any file read. In a worktree it prints the first-message statement from the session's own files: whether the agents file was auto-loaded or read by hand, and whether the skills were listed at the start or found by path. When the session files cannot be read it prints "not verified" and points at `/session-info`; say that, do not guess. An unknown `--area` prints a WARN with the valid doors (free area names are allowed).
- **Order.** `check_gd_load.py` once, `run_godot_import_check.py`, baseline shots opened, then the survey or restate as text, then Q0. Baseline shots are always allowed; a brief that says "shoot nothing" never covers them.
- **Q0** is asked in every slice, even when the brief names a look: result look, reference, out of bounds. A frame, layout or look already built in the repo is inherited: it is a Q0 item for her to keep, change or drop, never only an assumptions-ledger line.
- **An ask is preceded by its message.** The message holds the survey or restate, each PNG path with a line saying what is on it, the ledger and any `Did not work:`. The option labels of `ask_user_question` are not that message. If an ask went out without it, send the message before the next tool call. For several surfaces: survey first, then which group, then the order, then what she wants for each surface, as separate questions.
- **Ledger** (three short lines, each overrulable): "Decisions I made that were yours" (with the alternative), "Assumptions carried from memory or docs", "Also changed". Also changed lists: shared scripts touched with the screens that use them (`python tools/list_xref.py <name>`), states that were not shot, writes outside the worktree (Grok memory files included), windows opened on her PC.
- **Outside the worktree.** Build writes there only through `tools/run_isolated_grok.py` and the checkpoint file. Anything else, a memory-file edit included, is a ledger entry.
- **Showing.** A shot is shown when its path and a description are in the message. Opening a file or folder on her PC (explorer, `Start-Process`) is not showing it and goes in the ledger.
- **Failed step.** Any non-zero exit or `RESULT FAIL`, exploratory runs included, and any skipped step. The next message starts `Did not work: <command> <one line>`. `python tools/did_not_work.py` lists a session's failed steps and which were not reported.
- **Shared tools.** `python tools/list_xref.py --texts <word>` searches the words in shot-flow text dumps (after a `run_shot_flow.py`).

## Next-session brief

A brief for a new Build session is lean. It has: the task in her words; where the last result and its handoff notes live (commit, docs); "first message: the statement `start_build_slice.py` prints"; "Q0 first"; baseline shots are allowed and expected; run `start_build_slice.py --checkpoint` when the gather is done; commit and push only after she confirms ("Settled? commit?"). It never forbids questions, never sets limits on the run, and does not restate rules the session flow doc already holds.

## Red prove and merge-back

**Retry** (one diagnosis, one fix: `tools.md` rule 10). The checkpoint (the worktree's gather session) is the point a retry returns to. A red prove prints a RETRY block: the command `grok -r <checkpoint> --fork-session` for the User to run from the worktree directory (a fork keeps the directory of the session it forks, which is the worktree; no `--cwd`, never `--worktree`; gather context kept), and a paste-ready prompt: which prove failed, the red output in a line or two, the files in `git diff grok-build-w{N}` (working tree, so uncommitted edits show; untracked files are listed too) to look at first, and the ask for one diagnosis and one fix. The forked session does not re-gather: it reads only the changed files, diagnoses once, fixes once and reruns once. No checkpoint saved for this worktree: the block says so and forks nothing; run `--checkpoint` in the gather session, or ask the User for its id (`grok sessions list` in the worktree). Still red: stop and report. The worktree's git history holds the code.

**Merge-back** on a green prove, after the User confirms the final shot. A Grok worktree is a full clone on the week branch itself: commit there, then `git push origin grok-build-w{N}` (plain push, no force, never main); there is no separate commit to merge by hand, and the main checkout pulls it. A true linked worktree (HEAD detached): commit, then `git merge --no-ff <that commit>` in the checkout that holds `grok-build-w{N}` (never main). Put a short note in the commit message; resolve conflicts yourself. Anything the User would check by hand (game balance, audio, visuals / art, controls) first needs a question prompt asking whether the playtest looks good, with the change summary (and PNG paths); wait for approval before the merge. Refactors, tools, docs and tests merge automatically on green. Build writes no changelog files (the week-close `0.N.0.md` is a web session's: `versioning.md`).

Read each job summary once via `python tools/read_summary.py --job <name>` (index first, newest run). Do not open summary files directly.

A same-command rerun is valid only for `truncated`, crash, `busy` lock, or wrong scene, and then the same command once. A follow-up job with a new field named from a summary key does not need a User wait; questions still follow the rules above.

Proof recipes by change kind: `prove.md`. A proof that needs a check no tool does: extend the library (`imglib`, shot tools) in the change job and add the recipe there; do not work around it.

Concurrent agents share catalog tools. They do not share logs: each worktree has its own `_logs/`, cleared weekly.
